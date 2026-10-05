import Foundation
import Testing
@testable import PomodoroAquarium

@MainActor
struct PomodoroNotificationFlowTests {
    @Test func manualStudyAndBreakKeepUserActionNotifications() throws {
        let fixture = NotificationFlowFixture(auto: false)
        fixture.model.resumeTimer()
        let study = try #require(fixture.notifications.messages.last?.message)
        #expect(study.title == "集中終了！")
        #expect(study.body == "おつかれさまでした。報酬を確認しましょう。")
        fixture.advance(1500)
        #expect(fixture.model.shouldBeginPomodoroBreak)
        fixture.model.beginPomodoroBreak()
        let rest = try #require(fixture.notifications.messages.last?.message)
        #expect(rest.title == "休憩終了！")
        #expect(rest.body == "次の集中セットを始められます。")
        fixture.advance(300)
        #expect(fixture.model.shouldConfirmNextSet)
        #expect(!fixture.model.isRunning)
        #expect(!fixture.model.awaitsAutomaticStudyStart)
    }

    @Test func automaticStudySchedulesBreakNotRewardAndVisibleBreakStartsStudy() throws {
        let fixture = NotificationFlowFixture()
        fixture.model.resumeTimer()
        #expect(fixture.notifications.messages.last?.message == .studyStartsBreak)
        #expect(fixture.notifications.messages.last?.message.body == "休憩を開始します。")
        fixture.advance(1500)
        #expect(fixture.notifications.messages.last?.message == .breakStartsStudy)
        #expect(fixture.notifications.messages.last?.message.body == "集中を再開します。")
        fixture.advance(300)
        #expect(fixture.model.phase == .study)
        #expect(fixture.model.isRunning)
        #expect(fixture.model.currentSet == 2)
        #expect(!fixture.model.awaitsAutomaticStudyStart)
    }

    @Test func leavingBreakReplacesMessageAtSameDeadlineAndKeepsNotificationOnExpiry() throws {
        let fixture = NotificationFlowFixture()
        fixture.model.resumeTimer()
        fixture.advance(1500)
        let deadline = fixture.model.endDate
        let flowID = fixture.model.pomodoroFlowID
        fixture.model.setTimerScreenVisible(false)
        let notification = try #require(fixture.notifications.messages.last)
        #expect(notification.date == deadline)
        #expect(notification.message.title == "休憩終了！")
        #expect(notification.message.body == "集中画面に戻ると次のセットを開始します。")
        let cancellations = fixture.notifications.cancellations
        fixture.advance(300)
        #expect(fixture.notifications.cancellations == cancellations)
        #expect(fixture.model.awaitsAutomaticStudyStart)
        #expect(fixture.model.phase == .awaitingNextSet)
        #expect(fixture.model.state == .completed)
        #expect(!fixture.model.shouldConfirmNextSet)
        #expect(!fixture.model.isRunning)
        #expect(fixture.model.currentSet == 1)
        #expect(fixture.model.pomodoroFlowID == flowID)
        #expect(fixture.model.defersPomodoroRewards)
        #expect(fixture.finishedFlows == 0)
        #expect(try #require(fixture.store.load()).awaitsAutomaticStudyStart == true)
    }

    @Test func returningStartsPendingStudyNowExactlyOnceWithoutCountingWait() {
        let fixture = NotificationFlowFixture()
        fixture.model.resumeTimer()
        fixture.advance(1500)
        fixture.model.setTimerScreenVisible(false)
        fixture.advance(300)
        fixture.advance(600)
        fixture.model.setTimerScreenVisible(true)
        let deadline = fixture.model.endDate
        #expect(fixture.model.currentSet == 2)
        #expect(fixture.model.isRunning)
        #expect(fixture.model.timeRemaining == 1500)
        #expect(fixture.model.validFocusSeconds == 0)
        fixture.model.setTimerScreenVisible(true)
        fixture.model.setAppActive(true)
        fixture.model.setAppActive(true)
        #expect(!fixture.model.resumeAutomaticStudyIfReady())
        fixture.model.recordActiveReturn()
        #expect(fixture.model.currentSet == 2)
        #expect(fixture.model.endDate == deadline)
        #expect(fixture.results.map(\.validFocusSeconds) == [1500])
        fixture.advance(60)
        #expect(fixture.model.validFocusSeconds == 60)
    }

    @Test func returningBeforeNextTickStillResolvesExpiredBreakOutsideScreen() {
        let fixture = NotificationFlowFixture()
        fixture.model.resumeTimer()
        fixture.advance(1500)
        fixture.model.setTimerScreenVisible(false)
        fixture.date = fixture.date.addingTimeInterval(500) // deadline expired without tick
        fixture.model.setTimerScreenVisible(true)
        #expect(fixture.model.currentSet == 2)
        #expect(fixture.model.timeRemaining == 1500)
        #expect(fixture.model.validFocusSeconds == 0)
        #expect(fixture.finishedFlows == 0)
    }

    @Test func pendingStudySurvivesRelaunchAndRetainsFlowRewards() throws {
        let fixture = NotificationFlowFixture()
        fixture.model.resumeTimer()
        fixture.advance(1500)
        let flowID = try #require(fixture.model.pomodoroFlowID)
        let sessionID = try #require(fixture.results.first?.id)
        PomodoroFlowRewardStore.append(.init(studyReward: 10, streakReward: 0, streakDays: 1),
                                      minutes: 25, sessionID: sessionID, flowID: flowID,
                                      defaults: fixture.defaults)
        fixture.model.setTimerScreenVisible(false)
        fixture.advance(300)
        fixture.advance(3600)
        let restored = fixture.restoredModel()
        restored.restorePersistedSessionIfNeeded()
        #expect(restored.awaitsAutomaticStudyStart)
        #expect(!restored.isRunning)
        #expect(!restored.shouldPresentBackgroundFailureAlert)
        #expect(restored.pomodoroFlowID == flowID)
        #expect(PomodoroFlowRewardStore.load(flowID: flowID, defaults: fixture.defaults)?.minutes == 25)
        restored.setTimerScreenVisible(true)
        #expect(!restored.isRunning)
        restored.setAppActive(true)
        #expect(restored.currentSet == 2)
        #expect(restored.isRunning)
        #expect(restored.validFocusSeconds == 0)
        #expect(restored.defersPomodoroRewards)
    }

    @Test func backgroundIsIndependentFromNavigationAndBreakNeverFails() {
        let inside = NotificationFlowFixture()
        inside.model.resumeTimer()
        inside.advance(1500)
        inside.model.recordLastActiveTime()
        #expect(inside.notifications.messages.last?.message == .breakAwaitsTimerScreen)
        inside.advance(420)
        #expect(inside.model.awaitsAutomaticStudyStart)
        #expect(!inside.model.isRunning)
        #expect(inside.model.currentSet == 1)
        #expect(!inside.model.canAutoStartNextStudy)
        inside.model.recordActiveReturn()
        #expect(inside.model.isTimerScreenVisible)
        #expect(inside.model.currentSet == 2)
        #expect(inside.model.isRunning)
        #expect(inside.model.validFocusSeconds == 0)
        #expect(inside.model.timeRemaining == 1500)

        let outside = NotificationFlowFixture()
        outside.model.resumeTimer()
        outside.advance(1500)
        outside.model.setTimerScreenVisible(false)
        outside.model.recordLastActiveTime()
        outside.advance(600)
        outside.model.recordActiveReturn()
        #expect(outside.model.awaitsAutomaticStudyStart)
        #expect(outside.model.isAppActive)
        #expect(!outside.model.isRunning)
        #expect(!outside.model.canAutoStartNextStudy)
        #expect(!outside.model.shouldPresentBackgroundFailureAlert)
        #expect(outside.results.map(\.validFocusSeconds) == [1500])
        outside.model.setTimerScreenVisible(true)
        let deadline = outside.model.endDate
        #expect(outside.model.isRunning)
        #expect(outside.model.currentSet == 2)
        #expect(outside.model.validFocusSeconds == 0)
        outside.model.setAppActive(true)
        outside.model.setTimerScreenVisible(true)
        outside.model.recordActiveReturn()
        #expect(outside.model.currentSet == 2)
        #expect(outside.model.endDate == deadline)
        #expect(!outside.model.resumeAutomaticStudyIfReady())
    }

    @Test func returningBeforeBreakDeadlineContinuesBreakThenStartsStudy() {
        let fixture = NotificationFlowFixture()
        fixture.model.resumeTimer()
        fixture.advance(1500)
        fixture.model.recordLastActiveTime()
        fixture.advance(180)
        fixture.model.recordActiveReturn()
        #expect(fixture.model.phase == .breakTime)
        #expect(fixture.model.isRunning)
        #expect(fixture.model.timeRemaining == 120)
        #expect(!fixture.model.awaitsAutomaticStudyStart)
        #expect(fixture.notifications.messages.last?.message == .breakStartsStudy)
        fixture.advance(120)
        #expect(fixture.model.phase == .study)
        #expect(fixture.model.currentSet == 2)
        #expect(fixture.model.isRunning)
        #expect(fixture.model.validFocusSeconds == 0)
    }

    @Test func finalSetFinishesAnywhereWithoutAnotherBreakOrPendingStudy() {
        let fixture = NotificationFlowFixture(sets: 1)
        fixture.model.resumeTimer()
        #expect(fixture.notifications.messages.last?.message == .studyCompleted)
        fixture.model.setTimerScreenVisible(false)
        fixture.advance(1500)
        #expect(fixture.model.phase == .finished)
        #expect(!fixture.model.awaitsAutomaticStudyStart)
        #expect(!fixture.model.defersPomodoroRewards)
        #expect(fixture.finishedFlows == 1)
        fixture.model.setTimerScreenVisible(true)
        #expect(!fixture.model.isRunning)
        #expect(fixture.finishedFlows == 1)
    }

    @Test(arguments: [TimerMode.countdown, .stopwatch])
    func timerAndStopwatchKeepOriginalNotificationAndCompletion(mode: TimerMode) {
        let fixture = NotificationFlowFixture()
        fixture.model.selectMode(mode)
        fixture.model.resumeTimer()
        #expect(fixture.notifications.messages.isEmpty)
        #expect(fixture.notifications.legacyStudyEnds.count == (mode == .countdown ? 1 : 0))
        fixture.model.setTimerScreenVisible(false)
        fixture.advance(1500)
        #expect(!fixture.model.awaitsAutomaticStudyStart)
        #expect(mode == .stopwatch ? fixture.model.isRunning : fixture.model.phase == .finished)
    }
}

@MainActor
private final class NotificationFlowFixture {
    var date = Date()
    let defaults = UserDefaults(suiteName: "PomodoroNotificationFlow-\(UUID())")!
    lazy var store = TimerSessionStore(defaults: defaults, processIdentifier: "original")
    let notifications = PomodoroNotificationSpy()
    lazy var model: TimerViewModel = {
        let model = makeModel(store: store)
        model.setTimerScreenVisible(true)
        model.setAppActive(true)
        model.configureAutoStartNextSet(auto)
        return model
    }()
    var results: [FinalizedFocusSession] = []
    var finishedFlows = 0
    let auto: Bool
    let sets: Int

    init(auto: Bool = true, sets: Int = 3) { self.auto = auto; self.sets = sets }
    func advance(_ seconds: TimeInterval) { date = date.addingTimeInterval(seconds); model.tick() }
    func makeModel(store: TimerSessionStore) -> TimerViewModel {
        let model = TimerViewModel(studyTime: 25, breakTime: 5, totalSets: sets,
                                   now: { self.date }, sessionStore: store, notificationService: notifications)
        model.onFocusSessionFinalized = { self.results.append($0); return true }
        model.onPomodoroFlowFinished = { self.finishedFlows += 1 }
        return model
    }
    func restoredModel() -> TimerViewModel {
        makeModel(store: TimerSessionStore(defaults: defaults, processIdentifier: UUID().uuidString))
    }
}

private final class PomodoroNotificationSpy: TimerNotificationScheduling {
    var notificationsEnabled = true
    var messages: [(date: Date, message: PomodoroEndNotification)] = []
    var legacyStudyEnds: [Date] = []
    var cancellations = 0
    func schedulePomodoroEnd(at date: Date, message: PomodoroEndNotification) {
        messages.append((date, message))
    }
    func scheduleStudyEnd(at date: Date) { legacyStudyEnds.append(date) }
    func scheduleBreakEnd(at date: Date) {}
    func cancelCurrentSessionNotification() { cancellations += 1 }
    func scheduleBackgroundLimitNotifications(warningAt: Date?, failureAt: Date?, sessionIdentifier: String) {}
    func cancelBackgroundLimitNotifications(for sessionIdentifier: String?) {}
    func authorizationStatus(_ completion: @escaping @Sendable (NotificationAuthorizationState) -> Void) {
        completion(.authorized)
    }
    func requestAuthorization(_ completion: @escaping @Sendable (Bool) -> Void) { completion(true) }
}
