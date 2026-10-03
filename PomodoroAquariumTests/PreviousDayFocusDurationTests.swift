import Foundation
import SwiftData
import Testing
@testable import PomodoroAquarium

@MainActor
struct PreviousDayFocusDurationTests {
    @Test func pomodoroOnlyUsesValidSeconds() throws {
        let fixture = try PreviousFocusFixture()
        fixture.record(minutes: 999, seconds: 25 * 60, method: .pomodoro)
        #expect(try fixture.minutes() == 25)
    }

    @Test func everyMethodAndCategoryIsIncluded() throws {
        let fixture = try PreviousFocusFixture()
        fixture.record(minutes: 50, seconds: 3000, method: .pomodoro, category: FocusCategoryDefaults.studyID)
        fixture.record(minutes: 40, seconds: 2400, method: .timer, category: FocusCategoryDefaults.readingID)
        fixture.record(minutes: 30, seconds: 1800, method: .stopwatch, category: "custom-archived-category")
        #expect(try fixture.minutes() == 120)
        fixture.player.yesterdayStudyMinutes = 777
        fixture.player.todayStudyMinutes = 888
        #expect(try PreviousDayFocusDurationService.synchronizeMinutes(
            for: fixture.player, before: fixture.today, calendar: fixture.calendar, in: fixture.context
        ) == 120)
        #expect(fixture.player.yesterdayStudyMinutes == 120)
        #expect(fixture.player.todayStudyMinutes == 888)
    }

    @Test func manualStopAndNormalCompletionCountButPauseDoesNot() throws {
        let fixture = try PreviousFocusFixture()
        let timer = fixture.timer(mode: .countdown, studyMinutes: 25)
        timer.resumeTimer()
        fixture.clock = fixture.clock.addingTimeInterval(1200)
        timer.pauseTimer()
        fixture.clock = fixture.clock.addingTimeInterval(300)
        #expect(timer.endCurrentSession())
        let pomodoro = fixture.timer(mode: .pomodoro, studyMinutes: 25)
        pomodoro.resumeTimer()
        fixture.clock = fixture.clock.addingTimeInterval(1500)
        pomodoro.tick()
        #expect(try fixture.minutes() == 45)
        let records = try fixture.context.fetch(FetchDescriptor<FocusSessionRecord>())
        #expect(records.compactMap(\.durationSeconds).sorted() == [1200, 1500])
    }

    @Test func backgroundFailureUsesSavedHundredMinutesNotFinalFive() throws {
        let fixture = try PreviousFocusFixture()
        let timer = fixture.timer(mode: .stopwatch)
        timer.resumeTimer()
        fixture.clock = fixture.clock.addingTimeInterval(6000)
        timer.recordLastActiveTime()
        fixture.clock = fixture.clock.addingTimeInterval(300)
        timer.recordActiveReturn()
        #expect(timer.lastStudySessionEndReason == .backgroundLimitExceeded)
        #expect(timer.lastValidFocusSeconds == 6000)
        #expect(try fixture.minutes() == 100)
    }

    @Test func shortBackgroundCountsAndBreakDoesNot() throws {
        let fixture = try PreviousFocusFixture()
        let timer = fixture.timer(mode: .stopwatch)
        timer.resumeTimer()
        fixture.clock = fixture.clock.addingTimeInterval(1200)
        timer.recordLastActiveTime()
        fixture.clock = fixture.clock.addingTimeInterval(180)
        timer.recordActiveReturn()
        fixture.clock = fixture.clock.addingTimeInterval(600)
        timer.pauseTimer()
        #expect(timer.endCurrentSession())
        #expect(try fixture.minutes() == 33)
        let pomodoro = fixture.timer(mode: .pomodoro, studyMinutes: 1)
        pomodoro.resumeTimer()
        fixture.clock = fixture.clock.addingTimeInterval(60)
        pomodoro.tick()
        pomodoro.beginPomodoroBreak()
        fixture.clock = fixture.clock.addingTimeInterval(300)
        pomodoro.tick()
        #expect(try fixture.minutes() == 34)
        #expect(try fixture.context.fetchCount(FetchDescriptor<FocusSessionRecord>()) == 2)
    }

    @Test func previousDayIsHalfOpenAndMovesAtMidnight() throws {
        let fixture = try PreviousFocusFixture()
        let yesterday = fixture.calendar.startOfDay(for: fixture.clock)
        let today = fixture.calendar.startOfDay(for: fixture.today)
        fixture.record(minutes: 900, date: yesterday.addingTimeInterval(-1))
        fixture.record(minutes: 10, date: yesterday)
        fixture.record(minutes: 20, date: today.addingTimeInterval(-1))
        fixture.record(minutes: 40, date: today)
        #expect(try fixture.minutes(before: today) == 30)
        let tomorrow = fixture.calendar.date(byAdding: .day, value: 1, to: today)!
        #expect(try fixture.minutes(before: tomorrow) == 40)
    }

    @Test func legacyMinutesFallbackAndFractionalSecondsAreSummedOnce() throws {
        let fixture = try PreviousFocusFixture()
        fixture.record(minutes: 42, category: nil)
        fixture.record(minutes: 99, seconds: 30, method: .timer)
        fixture.record(minutes: 99, seconds: 30, method: .stopwatch)
        fixture.record(minutes: 99, seconds: 0)
        #expect(try fixture.minutes() == 43)
    }

    @Test func sumDoesNotOverflowForCorruptHugeLegacyDurations() throws {
        let fixture = try PreviousFocusFixture()
        fixture.record(minutes: Int.max)
        fixture.record(minutes: Int.max, seconds: Int.max)
        #expect(try fixture.minutes() == Int.max / 60)
        let probabilities = FishRewardService.rarityProbabilities(for: try fixture.minutes())
        #expect(probabilities.common == 58)
        #expect(probabilities.legendary == 4)
    }

    @Test func immediateAndUnlockedClaimsUseRecordsNotPlayerOrToday() throws {
        let fixture = try PreviousFocusFixture()
        fixture.record(minutes: 50, seconds: 3000, method: .pomodoro)
        fixture.record(minutes: 40, seconds: 2400, method: .timer, category: FocusCategoryDefaults.readingID)
        fixture.record(minutes: 30, seconds: 1800, method: .stopwatch, category: "my-category")
        fixture.record(minutes: 300, date: fixture.clock.addingTimeInterval(-86400))
        fixture.player.yesterdayStudyMinutes = 777
        let session = FinalizedFocusSession(
            id: UUID(), completedAt: fixture.today, validFocusSeconds: 6000, endReason: .completed,
            categoryID: FocusCategoryDefaults.studyID, focusMethod: .timer
        )
        try StudyHistoryService.recordValidFocusSession(session, calendar: fixture.calendar, in: fixture.context)
        try DailyFishProgressService.process(
            sessionID: session.id, for: fixture.player, on: fixture.today, calendar: fixture.calendar, in: fixture.context
        )
        let expected = FishRewardService.rarityProbabilities(for: 120)
        var draws = 0
        let batch = try FishRewardBatchService.grant(
            sessionID: session.id, to: fixture.player, on: fixture.today, calendar: fixture.calendar,
            defaults: fixture.defaults, in: fixture.context, draw: { probabilities in
                #expect(probabilities.common == expected.common)
                #expect(probabilities.rare == expected.rare)
                #expect(probabilities.epic == expected.epic)
                #expect(probabilities.legendary == expected.legendary)
                draws += 1
                return .clownfish
            }
        )
        #expect(draws == 3)
        #expect(batch?.results.count == 3)
        #expect(fixture.player.yesterdayStudyMinutes == 120)
        #expect(fixture.player.dailyPendingFishCount == 1)
        fixture.player.yesterdayStudyMinutes = 999
        let unlocked = try FishRewardBatchService.unlockOneFishSlot(
            for: fixture.player, on: fixture.today, calendar: fixture.calendar, defaults: fixture.defaults,
            in: fixture.context, draw: { probabilities in
                #expect(probabilities.common == expected.common)
                #expect(probabilities.legendary == expected.legendary)
                return .seahorse
            }
        )
        #expect(unlocked?.results.count == 1)
        #expect(fixture.player.yesterdayStudyMinutes == 120)
        #expect(fixture.player.dailyClaimedFishCount == 4)
        #expect(fixture.player.coins == 80)
    }

    @Test func legacySingleHelperAlsoUsesRecordSource() throws {
        let fixture = try PreviousFocusFixture()
        fixture.record(minutes: 120, seconds: 7200, method: .stopwatch)
        fixture.player.yesterdayStudyMinutes = 999
        #expect(FishRewardService.awardFish(
            for: 25, to: fixture.player, on: fixture.today, calendar: fixture.calendar, in: fixture.context
        ) != nil)
        #expect(fixture.player.yesterdayStudyMinutes == 120)
    }
}

@MainActor
private final class PreviousFocusFixture {
    let container: ModelContainer
    let context: ModelContext
    let player: Player
    let defaults: UserDefaults
    let suite = "PreviousDayFocusDuration-\(UUID())"
    let calendar: Calendar
    let today: Date
    var clock: Date

    init() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        self.calendar = calendar
        today = calendar.date(from: DateComponents(year: 2026, month: 10, day: 3, hour: 12))!
        clock = calendar.date(from: DateComponents(year: 2026, month: 10, day: 2, hour: 1))!
        container = try ModelContainer(
            for: Player.self, PlayerFish.self, FocusSessionRecord.self, StudyDailyRecord.self, RewardHistoryEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = ModelContext(container)
        defaults = UserDefaults(suiteName: suite)!
        player = Player(coins: 80)
        context.insert(player)
        try context.save()
    }

    deinit { defaults.removePersistentDomain(forName: suite) }

    func record(minutes: Int, seconds: Int? = nil, method: FocusMethod = .pomodoro,
                category: String? = nil, date: Date? = nil) {
        context.insert(FocusSessionRecord(
            completedAt: date ?? clock, durationMinutes: minutes, categoryID: category,
            focusMethod: method, durationSeconds: seconds
        ))
    }

    func minutes(before date: Date? = nil) throws -> Int {
        try context.save()
        return try PreviousDayFocusDurationService.minutes(before: date ?? today, calendar: calendar, in: context)
    }

    func timer(mode: TimerMode, studyMinutes: Int = 150) -> TimerViewModel {
        let model = TimerViewModel(
            studyTime: studyMinutes, breakTime: 5, totalSets: 2, now: { self.clock },
            sessionStore: TimerSessionStore(defaults: defaults), notificationService: DisabledTimerNotificationService.shared
        )
        model.selectMode(mode)
        model.onFocusSessionFinalized = { session in
            do {
                try StudyHistoryService.recordValidFocusSession(session, calendar: self.calendar, in: self.context)
                return true
            } catch { Issue.record(error); return false }
        }
        return model
    }
}
