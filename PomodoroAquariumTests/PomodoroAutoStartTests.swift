import Foundation
import SwiftData
import Testing
@testable import PomodoroAquarium

@MainActor
struct PomodoroAutoStartTests {
    @Test(arguments: [true, false])
    func completedMultipleSetPresentationLeavesSharedModelReadyForNewEntry(auto: Bool) throws {
        let fixture = AutoStartFixture(auto: auto, sets: 2)
        fixture.model.selectCategory("last-used-category")
        PomodoroAutoStartSettings.save(auto, in: fixture.defaults)
        fixture.model.resumeTimer()
        fixture.advance(1500)
        if !auto { fixture.model.beginPomodoroBreak() }
        fixture.advance(300)
        if !auto { #expect(fixture.model.startNextSet()) }
        fixture.advance(1500)
        let oldFlowID = fixture.model.pomodoroFlowID
        #expect(fixture.model.phase == .finished)
        #expect(fixture.model.finishCompletedSessionPresentation())
        #expect(fixture.model.state == .idle)
        #expect(fixture.model.phase == .study)
        #expect(fixture.model.currentSet == 1)
        #expect(fixture.model.timeRemaining == 1500)
        #expect(!fixture.model.isAutomaticPomodoroFlow)
        #expect(fixture.model.pomodoroFlowID == nil)
        #expect(fixture.model.lastStudySessionEndReason == nil)
        #expect(fixture.model.lastCompletedStudyMinutes == 0)
        #expect(fixture.model.onPomodoroFlowFinished == nil)
        #expect(fixture.store.load() == nil)
        #expect(fixture.model.selectedCategoryID == "last-used-category")
        #expect(PomodoroAutoStartSettings.isEnabled(in: fixture.defaults) == auto)
        // 再入場と古いonDismissの再実行は、新sessionを閉じる/終了する条件を持たない。
        #expect(!fixture.model.finishCompletedSessionPresentation())
        fixture.model.restorePersistedSessionIfNeeded()
        #expect(fixture.model.phase == .study)
        #expect(fixture.model.state == .idle)
        fixture.model.resumeTimer()
        #expect(fixture.model.isRunning)
        #expect(fixture.model.isAutomaticPomodoroFlow == auto)
        if auto { #expect(fixture.model.pomodoroFlowID != oldFlowID) }
    }

    @Test func cleanupDoesNotDiscardActiveBreakOrGrantedFishAndHistory() throws {
        let fixture = AutoStartFixture()
        let rewards = try AutoFlowRewardFixture(timer: fixture)
        fixture.model.resumeTimer()
        fixture.advance(1500)
        #expect(!fixture.model.finishCompletedSessionPresentation())
        #expect(fixture.model.phase == .breakTime)
        fixture.advance(300)
        fixture.advance(1500)
        fixture.advance(300)
        fixture.advance(1500)
        let batch = try #require(rewards.presented)
        try FishRewardBatchService.acknowledge(batch.historyIDs, in: rewards.context)
        #expect(fixture.model.finishCompletedSessionPresentation())
        #expect(rewards.player.ownedFish.count == 3)
        #expect(rewards.player.dailyClaimedFishCount == 3)
        #expect(try rewards.context.fetchCount(FetchDescriptor<RewardHistoryEntry>()) == 3)
        #expect(try FishRewardBatchService.latestUnacknowledgedBatch(in: rewards.context) == nil)
        #expect(fixture.model.pomodoroFlowID == nil)
    }

    @Test func defaultOffAndSavedOnSurvivesNewDefaultsInstance() {
        let fixture = AutoStartFixture()
        #expect(!PomodoroAutoStartSettings.isEnabled(in: fixture.defaults))
        PomodoroAutoStartSettings.save(true, in: fixture.defaults)
        let reopened = UserDefaults(suiteName: fixture.suite)!
        #expect(PomodoroAutoStartSettings.isEnabled(in: reopened))
        PomodoroAutoStartSettings.save(false, in: reopened)
        #expect(!PomodoroAutoStartSettings.isEnabled(in: fixture.defaults))
    }

    @Test func offKeepsManualStudyAndBreakConfirmation() {
        let fixture = AutoStartFixture(auto: false)
        fixture.model.resumeTimer()
        fixture.advance(1500)
        #expect(fixture.model.shouldBeginPomodoroBreak)
        #expect(fixture.model.state == .completed)
        fixture.model.beginPomodoroBreak()
        fixture.advance(300)
        #expect(fixture.model.shouldConfirmNextSet)
        #expect(fixture.model.state == .completed)
        #expect(fixture.model.currentSet == 1)
    }

    @Test func onStartsBreakThenNextStudyWithoutUserAction() {
        let fixture = AutoStartFixture()
        fixture.model.resumeTimer()
        fixture.advance(1500)
        #expect(fixture.model.phase == .breakTime)
        #expect(fixture.model.isRunning)
        #expect(!fixture.model.shouldBeginPomodoroBreak)
        #expect(fixture.model.defersPomodoroRewards)
        fixture.advance(300)
        #expect(fixture.model.phase == .study)
        #expect(fixture.model.isRunning)
        #expect(fixture.model.currentSet == 2)
        #expect(fixture.model.timeRemaining == 1500)
        #expect(fixture.results.map(\.validFocusSeconds) == [1500])
        #expect(fixture.model.validFocusSeconds == 0)
    }

    @Test func finalStudyEndsFlowExactlyOnceWithoutAnotherBreak() {
        let fixture = AutoStartFixture(sets: 2)
        fixture.model.resumeTimer()
        fixture.advance(1500)
        fixture.advance(300)
        fixture.advance(1500)
        #expect(fixture.model.phase == .finished)
        #expect(fixture.model.state == .completed)
        #expect(fixture.model.currentSet == 2)
        #expect(!fixture.model.defersPomodoroRewards)
        #expect(fixture.finishedFlows == 1)
        fixture.advance(3000)
        #expect(fixture.finishedFlows == 1)
        #expect(fixture.results.count == 2)
        #expect(fixture.store.load() == nil)
    }

    @Test func confirmedBreakSkipStartsNextStudyOnlyOnce() {
        let fixture = AutoStartFixture()
        fixture.model.resumeTimer()
        fixture.advance(1500)
        fixture.advance(30)
        #expect(fixture.model.endPomodoroBreak())
        #expect(fixture.model.phase == .study)
        #expect(fixture.model.currentSet == 2)
        #expect(fixture.model.isRunning)
        #expect(!fixture.model.endPomodoroBreak())
        #expect(fixture.results.count == 1)
    }

    @Test func skipAtNaturalBreakDeadlineDoesNotStopNewStudy() {
        let fixture = AutoStartFixture()
        fixture.model.resumeTimer()
        fixture.advance(1500)
        fixture.date = fixture.date.addingTimeInterval(300) // no tick before tap
        #expect(fixture.model.endPomodoroBreak())
        #expect(fixture.model.currentSet == 2)
        #expect(fixture.model.isRunning)
        #expect(fixture.model.phase == .study)
    }

    @Test func activeFlowFreezesSettingAndResumeDoesNotRestartFlow() {
        let fixture = AutoStartFixture()
        fixture.model.resumeTimer()
        let flowID = fixture.model.pomodoroFlowID
        fixture.advance(60)
        fixture.model.pauseTimer()
        fixture.model.configureAutoStartNextSet(false)
        fixture.model.resumeTimer()
        #expect(fixture.model.pomodoroFlowID == flowID)
        fixture.advance(1440)
        #expect(fixture.model.phase == .breakTime)
        #expect(fixture.model.isRunning)
    }

    @Test(arguments: [TimerMode.countdown, .stopwatch])
    func otherModesIgnoreSetting(mode: TimerMode) {
        let fixture = AutoStartFixture()
        fixture.model.selectMode(mode)
        fixture.model.resumeTimer()
        #expect(!fixture.model.isAutomaticPomodoroFlow)
        #expect(fixture.model.pomodoroFlowID == nil)
        fixture.advance(1500)
        if mode == .countdown {
            #expect(fixture.model.phase == .finished)
        } else {
            #expect(fixture.model.isRunning)
            #expect(fixture.model.stopwatchElapsedSeconds == 1500)
        }
        #expect(fixture.finishedFlows == 0)
    }

    @Test func tutorialKeepsManualPseudoCompletion() {
        let fixture = AutoStartFixture()
        #expect(fixture.model.completeCoreTutorialStudyWithoutStartingSession())
        #expect(fixture.model.phase == .finished)
        #expect(!fixture.model.isAutomaticPomodoroFlow)
        #expect(fixture.finishedFlows == 0)
        #expect(fixture.results.isEmpty)
    }

    @Test(arguments: [0, 5])
    func zeroBreakAndSingleSetHaveNoExtraUserWait(breakMinutes: Int) {
        let fixture = AutoStartFixture(sets: breakMinutes == 0 ? 2 : 1, breakMinutes: breakMinutes)
        fixture.model.resumeTimer()
        fixture.advance(1500)
        if breakMinutes == 0 {
            #expect(fixture.model.currentSet == 2)
            #expect(fixture.model.isRunning)
        } else {
            #expect(fixture.model.phase == .finished)
        }
    }

    @Test func relaunchInBreakRetainsSnapshotEvenIfPreferenceNowOff() throws {
        let fixture = AutoStartFixture()
        fixture.model.resumeTimer()
        let flowID = fixture.model.pomodoroFlowID
        fixture.advance(1500)
        fixture.model.recordLastActiveTime()
        fixture.date = fixture.date.addingTimeInterval(180)
        let restored = fixture.restoredModel()
        restored.restorePersistedSessionIfNeeded()
        #expect(restored.isAutomaticPomodoroFlow)
        #expect(restored.pomodoroFlowID == flowID)
        #expect(restored.phase == .breakTime)
        #expect(restored.timeRemaining == 120)
        restored.setAppActive(true)
        fixture.date = fixture.date.addingTimeInterval(120)
        restored.tick()
        #expect(restored.phase == .study)
        #expect(restored.currentSet == 2)
        #expect(restored.isRunning)
        #expect(try #require(fixture.store.load()).autoStartNextSet == true)
    }

    @Test func relaunchResolvesBreakDeadlineWithoutCountingBreakAsFocus() {
        let fixture = AutoStartFixture()
        fixture.model.resumeTimer()
        fixture.advance(1500)
        fixture.model.recordLastActiveTime()
        fixture.date = fixture.date.addingTimeInterval(420)
        let restored = fixture.restoredModel()
        restored.restorePersistedSessionIfNeeded()
        #expect(restored.awaitsAutomaticStudyStart)
        #expect(!restored.isRunning)
        #expect(restored.currentSet == 1)
        restored.setAppActive(true)
        #expect(restored.phase == .study)
        #expect(restored.currentSet == 2)
        #expect(restored.validFocusSeconds == 0)
        #expect(restored.timeRemaining == 1500)
        #expect(restored.backgroundEnteredAt == nil)
    }

    @Test func longBackgroundBreakWaitsWithoutStartingOrFailingNextStudy() {
        let fixture = AutoStartFixture()
        fixture.model.resumeTimer()
        fixture.advance(1500)
        fixture.model.recordLastActiveTime()
        fixture.date = fixture.date.addingTimeInterval(600)
        let restored = fixture.restoredModel()
        restored.restorePersistedSessionIfNeeded()
        #expect(restored.awaitsAutomaticStudyStart)
        #expect(!restored.isRunning)
        #expect(!restored.shouldPresentBackgroundFailureAlert)
        // 休憩後に待った時間は集中にも失敗にも扱わない。
        #expect(fixture.results.map(\.validFocusSeconds) == [1500])
        #expect(fixture.finishedFlows == 0)
        restored.setAppActive(true)
        #expect(restored.isRunning)
        #expect(restored.currentSet == 2)
        #expect(restored.validFocusSeconds == 0)
    }

    @Test func rewardsAreSavedEachSetButDisplayedTogetherOnlyAfterFlow() throws {
        let fixture = AutoStartFixture()
        let rewardFixture = try AutoFlowRewardFixture(timer: fixture)
        fixture.model.resumeTimer()
        fixture.advance(1500)
        #expect(rewardFixture.player.ownedFish.count == 1)
        #expect(rewardFixture.presented == nil)
        fixture.advance(300)
        fixture.advance(1500)
        #expect(rewardFixture.player.ownedFish.count == 2)
        #expect(rewardFixture.presented == nil)
        fixture.advance(300)
        fixture.advance(1500)
        let batch = try #require(rewardFixture.presented)
        #expect(batch.results.count == 3)
        #expect(batch.results.map(\.isNewFish) == [true, false, false])
        #expect(try rewardFixture.context.fetchCount(FetchDescriptor<RewardHistoryEntry>()) == 3)
        let recovered = try #require(try FishRewardBatchService.latestUnacknowledgedBatch(in: rewardFixture.context))
        #expect(recovered.historyIDs == batch.historyIDs)
        #expect(rewardFixture.player.dailyClaimedFishCount == 3)
        // 再表示は保存済み結果だけを使う。
        #expect(rewardFixture.player.ownedFish.count == 3)
    }

    @Test func manualStopPreservesPreviouslySavedFishAndAccumulatedPoints() throws {
        let fixture = AutoStartFixture()
        let rewardFixture = try AutoFlowRewardFixture(timer: fixture)
        fixture.model.resumeTimer()
        fixture.advance(1500)
        let flowID = try #require(fixture.model.pomodoroFlowID)
        let firstID = try #require(fixture.results.first?.id)
        let reward = StudyCompletionReward(studyReward: 10, streakReward: 0, streakDays: 1)
        PomodoroFlowRewardStore.append(reward, minutes: 25, sessionID: firstID,
                                      flowID: flowID, defaults: fixture.defaults)
        PomodoroFlowRewardStore.append(reward, minutes: 25, sessionID: firstID,
                                      flowID: flowID, defaults: fixture.defaults)
        fixture.advance(300)
        fixture.advance(600)
        fixture.model.pauseTimer()
        #expect(fixture.model.endCurrentSession())
        #expect(rewardFixture.presented?.results.count == 1)
        #expect(rewardFixture.player.ownedFish.count == 1)
        #expect(fixture.results.map(\.validFocusSeconds) == [1500, 600])
        let reopened = UserDefaults(suiteName: fixture.suite)!
        let saved = try #require(PomodoroFlowRewardStore.load(flowID: flowID, defaults: reopened))
        #expect(saved.completionReward.studyReward == 10)
        #expect(saved.minutes == 25)
        #expect(saved.sessions.count == 1)
    }
}

@MainActor
private final class AutoStartFixture {
    var date = Calendar.current.startOfDay(for: Date()).addingTimeInterval(3600)
    let suite = "PomodoroAutoStart-\(UUID())"
    lazy var defaults = UserDefaults(suiteName: suite)!
    lazy var store = TimerSessionStore(defaults: defaults, processIdentifier: "original")
    lazy var model: TimerViewModel = {
        let model = makeModel(store: store)
        model.configureAutoStartNextSet(auto)
        return model
    }()
    var results: [FinalizedFocusSession] = []
    var finishedFlows = 0
    let auto: Bool
    let sets: Int
    let breakMinutes: Int

    init(auto: Bool = true, sets: Int = 3, breakMinutes: Int = 5) {
        self.auto = auto
        self.sets = sets
        self.breakMinutes = breakMinutes
    }

    func makeModel(store: TimerSessionStore) -> TimerViewModel {
        let model = TimerViewModel(studyTime: 25, breakTime: breakMinutes, totalSets: sets,
                                   now: { self.date }, sessionStore: store,
                                   notificationService: DisabledTimerNotificationService.shared)
        model.setTimerScreenVisible(true)
        model.setAppActive(true)
        model.onFocusSessionFinalized = { session in self.results.append(session); return true }
        model.onPomodoroFlowFinished = { self.finishedFlows += 1 }
        return model
    }

    func restoredModel() -> TimerViewModel {
        makeModel(store: TimerSessionStore(defaults: defaults, processIdentifier: UUID().uuidString))
    }

    func advance(_ seconds: TimeInterval) { date = date.addingTimeInterval(seconds); model.tick() }
}

@MainActor
private final class AutoFlowRewardFixture {
    let container: ModelContainer
    let context: ModelContext
    let player = Player()
    var presented: FishRewardBatch?

    init(timer: AutoStartFixture) throws {
        container = try ModelContainer(for: Player.self, PlayerFish.self, FocusSessionRecord.self,
                                        StudyDailyRecord.self, RewardHistoryEntry.self,
                                        configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        context = ModelContext(container)
        context.insert(player)
        try context.save()
        timer.model.onFocusSessionFinalized = { session in
            do {
                timer.results.append(session)
                try StudyHistoryService.recordValidFocusSession(session, in: self.context)
                try DailyFishProgressService.process(sessionID: session.id, for: self.player,
                                                      on: timer.date, in: self.context)
                _ = try FishRewardBatchService.grant(sessionID: session.id, to: self.player,
                                                     pomodoroFlowID: session.pomodoroFlowID,
                                                     on: timer.date, defaults: timer.defaults,
                                                     in: self.context, draw: { _ in .clownfish })
                #expect(timer.model.defersPomodoroRewards)
                return true
            } catch { Issue.record(error); return false }
        }
        timer.model.onPomodoroFlowFinished = {
            timer.finishedFlows += 1
            #expect(!timer.model.defersPomodoroRewards)
            if let id = timer.model.pomodoroFlowID {
                self.presented = try? FishRewardBatchService.batch(forPomodoroFlow: id, in: self.context)
            }
        }
    }
}
