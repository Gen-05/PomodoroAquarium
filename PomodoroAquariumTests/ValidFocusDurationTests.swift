import Foundation
import SwiftData
import Testing
@testable import PomodoroAquarium

@MainActor
struct ValidFocusDurationTests {
    @Test(arguments: [TimerMode.pomodoro, .countdown])
    func normalCompletionRecordsTenMinutes(mode: TimerMode) throws {
        let fixture = FocusDurationFixture(mode: mode, studyMinutes: 10)
        fixture.model.resumeTimer()
        fixture.advance(600)
        fixture.model.tick()
        let result = try #require(fixture.results.first)
        #expect(result.validFocusSeconds == 600)
        #expect(result.durationMinutes == 10)
        #expect(result.endReason == .completed)
        #expect(result.completedAt == fixture.date)
        fixture.model.tick()
        #expect(fixture.results.count == 1)
    }

    @Test(arguments: [TimerMode.pomodoro, .countdown, .stopwatch])
    func manualStopPreservesTenMinutes(mode: TimerMode) throws {
        let fixture = FocusDurationFixture(mode: mode)
        fixture.model.resumeTimer()
        fixture.advance(600)
        fixture.stop()
        #expect(fixture.results.first?.validFocusSeconds == 600)
        #expect(fixture.results.first?.endReason == .userEnded)
        #expect(!fixture.model.endCurrentSession())
        #expect(fixture.results.count == 1)
    }

    @Test(arguments: [TimerMode.pomodoro, .countdown, .stopwatch])
    func shortBackgroundAbsenceCountsTowardThirtyThreeMinutes(mode: TimerMode) {
        let fixture = FocusDurationFixture(mode: mode)
        fixture.model.resumeTimer()
        fixture.advance(20 * 60)
        fixture.model.recordLastActiveTime()
        fixture.advance(3 * 60)
        fixture.model.recordActiveReturn()
        fixture.advance(10 * 60)
        fixture.stop()
        #expect(fixture.results.first?.validFocusSeconds == 33 * 60)
    }

    @Test(arguments: [TimerMode.pomodoro, .countdown, .stopwatch])
    func failureKeepsOneHundredMinutesWithoutRewardCallback(mode: TimerMode) {
        let fixture = FocusDurationFixture(mode: mode)
        var rewards = 0
        fixture.model.onStudyFinished = { rewards += 1 }
        fixture.model.resumeTimer()
        fixture.advance(100 * 60)
        fixture.model.recordLastActiveTime()
        fixture.advance(300)
        fixture.model.recordActiveReturn()
        #expect(fixture.results.first?.validFocusSeconds == 100 * 60)
        #expect(fixture.results.first?.endReason == .backgroundLimitExceeded)
        #expect(fixture.model.lastValidFocusSeconds == 100 * 60)
        #expect(rewards == 0)
        // The legacy reward input remains unchanged; duration has its own result.
        #expect(fixture.model.lastCompletedStudyMinutes == 0)
        fixture.model.tick()
        fixture.model.recordActiveReturn()
        #expect(fixture.results.count == 1)
    }

    @Test(arguments: [TimerMode.pomodoro, .countdown, .stopwatch])
    func returningAt299SecondsIncludesEverySecond(mode: TimerMode) {
        let fixture = FocusDurationFixture(mode: mode)
        fixture.model.resumeTimer()
        fixture.advance(61)
        fixture.model.recordLastActiveTime()
        fixture.advance(299)
        fixture.model.recordActiveReturn()
        #expect(fixture.model.isRunning)
        fixture.stop()
        #expect(fixture.results.first?.validFocusSeconds == 360)
    }

    @Test(arguments: [TimerMode.pomodoro, .countdown, .stopwatch])
    func reaching300SecondsExcludesFinalAbsence(mode: TimerMode) {
        let fixture = FocusDurationFixture(mode: mode)
        fixture.model.resumeTimer()
        fixture.advance(61)
        fixture.model.recordLastActiveTime()
        fixture.advance(300)
        // Also exercise failure from a tick rather than active-return.
        fixture.model.tick()
        #expect(!fixture.model.isRunning)
        #expect(fixture.results.first?.validFocusSeconds == 61)
        #expect(fixture.results.first?.endReason == .backgroundLimitExceeded)
    }

    @Test(arguments: [TimerMode.pomodoro, .countdown, .stopwatch])
    func pausedMinutesAreExcludedAndFractionalSecondsSurvive(mode: TimerMode) {
        let fixture = FocusDurationFixture(mode: mode)
        fixture.model.resumeTimer()
        fixture.advance(30.6)
        fixture.model.pauseTimer()
        fixture.advance(300)
        #expect(fixture.model.validFocusSeconds == 30)
        fixture.model.resumeTimer()
        fixture.advance(29.6)
        fixture.stop()
        #expect(fixture.results.first?.validFocusSeconds == 60)
    }

    @Test func breakDoesNotAddTimeOrCreateAnotherRecord() {
        let fixture = FocusDurationFixture(mode: .pomodoro, studyMinutes: 1)
        fixture.model.resumeTimer()
        fixture.advance(60)
        fixture.model.tick()
        #expect(fixture.model.phase == .breakTime)
        fixture.model.beginPomodoroBreak()
        fixture.advance(300)
        fixture.model.tick()
        #expect(fixture.model.phase == .awaitingNextSet)
        #expect(fixture.model.lastValidFocusSeconds == 60)
        #expect(fixture.results.count == 1)
        fixture.model.startNextSet()
        fixture.advance(60)
        fixture.model.tick()
        #expect(fixture.results.map(\.validFocusSeconds) == [60, 60])
        #expect(fixture.results[0].id != fixture.results[1].id)
    }

    @Test func normalEndBeforeFailureUsesScheduledEndEvenWhenReturnIsLate() throws {
        let fixture = FocusDurationFixture(mode: .pomodoro, studyMinutes: 10)
        fixture.model.resumeTimer()
        fixture.advance(8 * 60)
        fixture.model.recordLastActiveTime()
        let normalEnd = try #require(fixture.model.endDate)
        fixture.advance(12 * 60)
        let restored = fixture.restoredModel()
        restored.restorePersistedSessionIfNeeded()
        #expect(fixture.results.first?.endReason == .completed)
        #expect(fixture.results.first?.validFocusSeconds == 600)
        #expect(fixture.results.first?.completedAt == normalEnd)
        #expect(restored.shouldBeginPomodoroBreak)
    }

    @Test func equalNormalAndFailureDeadlinesStillPreferExistingFailureRule() {
        let fixture = FocusDurationFixture(mode: .countdown, studyMinutes: 5)
        fixture.model.resumeTimer()
        fixture.advance(1)
        // The normal deadline is one second before the failure deadline.
        fixture.model.recordLastActiveTime()
        fixture.advance(300)
        fixture.model.tick()
        #expect(fixture.results.first?.endReason == .completed)
        #expect(fixture.results.first?.validFocusSeconds == 300)

        let equal = FocusDurationFixture(mode: .countdown, studyMinutes: 5)
        equal.model.resumeTimer()
        equal.model.recordLastActiveTime()
        equal.advance(300)
        equal.model.tick()
        #expect(equal.model.lastStudySessionEndReason == .backgroundLimitExceeded)
        #expect(equal.model.lastValidFocusSeconds == 0)
        #expect(equal.results.isEmpty)
    }

    @Test(arguments: [TimerMode.pomodoro, .countdown, .stopwatch])
    func relaunchedFailureExcludesAbsenceBeyondFiveMinutes(mode: TimerMode) throws {
        let fixture = FocusDurationFixture(mode: mode)
        fixture.model.resumeTimer()
        fixture.advance(100 * 60)
        fixture.model.recordLastActiveTime()
        let backgroundEntry = fixture.date
        let id = try #require(fixture.store.load()?.focusSessionID)
        fixture.advance(40 * 60)
        let restored = fixture.restoredModel()
        restored.restorePersistedSessionIfNeeded()
        restored.restorePersistedSessionIfNeeded()
        #expect(restored.lastValidFocusSeconds == 100 * 60)
        #expect(fixture.results.first?.id == id)
        #expect(fixture.results.first?.completedAt == backgroundEntry.addingTimeInterval(300))
        #expect(fixture.results.count == 1)
    }

    @Test(arguments: [TimerMode.pomodoro, .countdown, .stopwatch])
    func relaunchedShortAbsenceContinuesWithSavedConfiguration(mode: TimerMode) {
        let fixture = FocusDurationFixture(mode: mode)
        fixture.model.resumeTimer()
        fixture.advance(20 * 60)
        fixture.model.recordLastActiveTime()
        fixture.advance(299)
        let restored = fixture.restoredModel()
        restored.restorePersistedSessionIfNeeded()
        #expect(restored.isRunning)
        #expect(restored.validFocusSeconds == 20 * 60 + 299)
        fixture.advance(60)
        restored.pauseTimer()
        restored.endCurrentSession()
        #expect(fixture.results.first?.validFocusSeconds == 20 * 60 + 359)
    }

    @Test(arguments: [TimerMode.pomodoro, .countdown, .stopwatch])
    func persistedHeartbeatDuringBackgroundDoesNotLeakFailedSeconds(mode: TimerMode) {
        let fixture = FocusDurationFixture(mode: mode)
        fixture.model.resumeTimer()
        fixture.advance(600)
        fixture.model.recordLastActiveTime()
        fixture.advance(180)
        fixture.model.tick() // Persisted anchor is now later than backgroundEnteredAt.
        fixture.advance(600)
        let restored = fixture.restoredModel()
        restored.restorePersistedSessionIfNeeded()
        #expect(fixture.results.first?.validFocusSeconds == 600)
    }

    @Test(arguments: [TimerMode.pomodoro, .countdown, .stopwatch])
    func relaunchedPauseExcludesOfflineTimeAndRetainsFractions(mode: TimerMode) {
        let fixture = FocusDurationFixture(mode: mode)
        fixture.model.resumeTimer()
        fixture.advance(30.6)
        fixture.model.pauseTimer()
        fixture.advance(3600)
        let restored = fixture.restoredModel()
        restored.restorePersistedSessionIfNeeded()
        #expect(restored.state == .paused)
        restored.resumeTimer()
        fixture.advance(29.6)
        restored.pauseTimer()
        restored.endCurrentSession()
        #expect(fixture.results.first?.validFocusSeconds == 60)
    }

    @Test @MainActor func savedSecondsStatisticsAndRetryAreIdempotent() throws {
        let container = try ModelContainer(
            for: FocusSessionRecord.self, StudyDailyRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let fixture = FocusDurationFixture(mode: .stopwatch)
        // Simulate unavailable storage at completion, then replay after a new process.
        fixture.model.onFocusSessionFinalized = { _ in false }
        fixture.model.resumeTimer()
        fixture.advance(601)
        fixture.stop()
        let pending = try #require(fixture.store.pendingFocusSessions().first)
        #expect(fixture.store.load() == nil)
        let restored = fixture.restoredModel()
        restored.onFocusSessionFinalized = { session in
            do {
                try StudyHistoryService.recordValidFocusSession(session, in: context)
                return true
            } catch {
                Issue.record(error)
                return false
            }
        }
        restored.restorePersistedSessionIfNeeded()
        // Simulate a crash between SwiftData commit and queue acknowledgement.
        fixture.store.enqueueFocusSession(pending)
        restored.restorePersistedSessionIfNeeded()
        let records = try context.fetch(FetchDescriptor<FocusSessionRecord>())
        let days = try context.fetch(FetchDescriptor<StudyDailyRecord>())
        #expect(records.count == 1)
        #expect(records.first?.durationSeconds == 601)
        #expect(records.first?.durationMinutes == 10)
        #expect(records.first?.validFocusSeconds == 601)
        #expect(days.first?.studyMinutes == 10)
        #expect(fixture.store.pendingFocusSessions().isEmpty)
        #expect(FocusStatisticsService.summary(for: .day, containing: fixture.date, from: records).totalMinutes == 10)
    }

    @Test @MainActor func subMinuteRecordAndLegacyMinuteFallback() throws {
        let container = try ModelContainer(
            for: FocusSessionRecord.self, StudyDailyRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let session = FinalizedFocusSession(
            id: UUID(), completedAt: Date(), validFocusSeconds: 59,
            endReason: .backgroundLimitExceeded,
            categoryID: FocusCategoryDefaults.readingID, focusMethod: .timer
        )
        try StudyHistoryService.recordValidFocusSession(session, in: container.mainContext)
        let saved = try #require(container.mainContext.fetch(FetchDescriptor<FocusSessionRecord>()).first)
        #expect(saved.durationMinutes == 0)
        #expect(saved.validFocusSeconds == 59)
        #expect(saved.categoryID == FocusCategoryDefaults.readingID)
        #expect(saved.focusMethod == .timer)
        let legacy = FocusSessionRecord(completedAt: Date(), durationMinutes: 10)
        #expect(legacy.durationSeconds == nil)
        #expect(legacy.validFocusSeconds == 600)
    }

    @Test func oldPersistedSessionWithoutNewFieldsStillRestores() throws {
        let fixture = FocusDurationFixture(mode: .countdown)
        fixture.model.resumeTimer()
        fixture.advance(600)
        fixture.model.recordLastActiveTime()
        let saved = try #require(fixture.store.load())
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(saved)) as? [String: Any])
        json.removeValue(forKey: "validFocusElapsed")
        json.removeValue(forKey: "validFocusUpdatedAt")
        json.removeValue(forKey: "focusSessionID")
        let legacy = try JSONDecoder().decode(
            PersistedTimerSession.self, from: JSONSerialization.data(withJSONObject: json)
        )
        fixture.store.save(legacy)
        fixture.advance(300)
        let restored = fixture.restoredModel()
        restored.restorePersistedSessionIfNeeded()
        #expect(restored.lastValidFocusSeconds == 600)
        #expect(fixture.results.first?.validFocusSeconds == 600)
    }
}

@MainActor
private final class FocusDurationFixture {
    var date = Date(timeIntervalSinceReferenceDate: 1_000_000)
    let defaults = UserDefaults(suiteName: "ValidFocusDuration-\(UUID())")!
    lazy var store = TimerSessionStore(defaults: defaults, processIdentifier: "original")
    lazy var model: TimerViewModel = {
        let model = TimerViewModel(
            studyTime: studyMinutes, breakTime: 5, now: { self.date },
            sessionStore: store, notificationService: DisabledTimerNotificationService.shared
        )
        model.selectMode(mode)
        model.onFocusSessionFinalized = { result in
            self.results.append(result)
            return true
        }
        return model
    }()
    var results: [FinalizedFocusSession] = []
    let mode: TimerMode
    let studyMinutes: Int

    init(mode: TimerMode, studyMinutes: Int = 150) {
        self.mode = mode
        self.studyMinutes = studyMinutes
    }

    func advance(_ seconds: TimeInterval) { date = date.addingTimeInterval(seconds) }

    func stop() {
        model.pauseTimer()
        #expect(model.endCurrentSession())
    }

    func restoredModel() -> TimerViewModel {
        let restored = TimerViewModel(
            // Deliberately differ from persisted configuration to catch incorrect duration restoration.
            studyTime: 25, breakTime: 5, now: { self.date },
            sessionStore: TimerSessionStore(defaults: defaults, processIdentifier: UUID().uuidString),
            notificationService: DisabledTimerNotificationService.shared
        )
        restored.onFocusSessionFinalized = { result in
            self.results.append(result)
            return true
        }
        return restored
    }
}
