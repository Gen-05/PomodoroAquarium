import Foundation
import SwiftData
import Testing
@testable import PomodoroAquarium

@MainActor
struct DailyPointProgressTests {
    @Test(arguments: [FocusMethod.pomodoro, .timer, .stopwatch])
    func fiveMinutesAndTwentyFiveMinutesUseTheSameRate(method: FocusMethod) throws {
        let fixture = try PointFixture()
        #expect(try fixture.add(300, method: method) == 2)
        #expect(try fixture.add(1500, method: method, category: "my-category") == 10)
        #expect(fixture.player.coins == 92)
    }

    @Test func normalRemainderCarriesExactSecondsAndCategoriesDoNotMatter() throws {
        let fixture = try PointFixture()
        #expect(try fixture.add(180) == 0)
        #expect(fixture.player.normalPointProgressSeconds == 180)
        #expect(try fixture.add(120, category: FocusCategoryDefaults.readingID) == 2)
        #expect(fixture.player.normalPointProgressSeconds == 0)
        #expect(try fixture.add(480) == 2)
        #expect(fixture.player.normalPointProgressSeconds == 180)
        #expect(try fixture.add(119) == 0)
        #expect(try fixture.add(1) == 2)
    }

    @Test func reducedThirteenThenTwelveMinutesPayOnePointEach() throws {
        let fixture = try PointFixture()
        try fixture.seedFishMaximum()
        #expect(try fixture.add(780) == 1)
        #expect(fixture.player.reducedPointProgressUnits == 60)
        #expect(try fixture.add(720) == 1)
        #expect(fixture.player.reducedPointProgressUnits == 0)
        #expect(try fixture.add(1500) == 2)
        #expect(fixture.player.coins == 84)
    }

    @Test func rateChangesAtEightEarnedRightsNotThreeClaimedFishOrUnlockedLimit() throws {
        let fixture = try PointFixture()
        fixture.player.dailyClaimedFishCount = 3
        fixture.player.dailyFishLimit = 3
        #expect(try fixture.add(4500) == 30)
        #expect(try fixture.add(7200) == 48)
        // 残り通常300秒 + 低レート780秒。8匹到達をまたぐ1session。
        #expect(try fixture.add(1080) == 3)
        #expect(fixture.player.reducedPointProgressUnits == 60)
        #expect(try fixture.add(720) == 1)
        #expect(fixture.player.dailyFishLimit == 3)
        #expect(fixture.player.dailyClaimedFishCount == 3)
        #expect(fixture.player.ownedFish.isEmpty) // ポイント処理自体は魚を触らない。
    }

    @Test func nextDayResetsBothRemaindersWithoutChangingBalanceOrHistory() throws {
        let fixture = try PointFixture()
        #expect(try fixture.add(180) == 0)
        try fixture.seedFishMaximum()
        #expect(try fixture.add(780) == 1)
        #expect(fixture.player.normalPointProgressSeconds == 180)
        #expect(fixture.player.reducedPointProgressUnits == 60)
        fixture.date = fixture.calendar.date(byAdding: .day, value: 1, to: fixture.date)!
        #expect(try DailyPointProgressService.resetIfNeeded(
            for: fixture.player, on: fixture.date, calendar: fixture.calendar, in: fixture.context
        ))
        #expect(fixture.player.normalPointProgressSeconds == 0)
        #expect(fixture.player.reducedPointProgressUnits == 0)
        #expect(fixture.player.coins == 81)
        #expect(try fixture.add(120) == 0)
        #expect(try fixture.context.fetchCount(FetchDescriptor<FocusSessionRecord>()) == 4)
    }

    @Test(arguments: [false, true])
    func reopenedContextPreservesRemainderAndSessionIDPreventsDuplicatePoints(reduced: Bool) throws {
        let fixture = try PointFixture()
        if reduced { try fixture.seedFishMaximum() }
        let record = fixture.insert(reduced ? 780 : 180)
        #expect(try fixture.process(record.id) == (reduced ? 1 : 0))
        let context = ModelContext(fixture.container)
        let player = try #require(context.fetch(FetchDescriptor<Player>()).first)
        #expect(player.normalPointProgressSeconds == (reduced ? 0 : 180))
        #expect(player.reducedPointProgressUnits == (reduced ? 60 : 0))
        #expect(try DailyPointProgressService.process(
            sessionID: record.id, for: player, on: fixture.date, calendar: fixture.calendar, in: context
        ) == 0)
        let next = FocusSessionRecord(completedAt: fixture.date, durationMinutes: 0,
                                      durationSeconds: reduced ? 720 : 120)
        context.insert(next)
        #expect(try DailyPointProgressService.process(
            sessionID: next.id, for: player, on: fixture.date, calendar: fixture.calendar, in: context
        ) == (reduced ? 1 : 2))
        #expect(player.coins == 82)
        #expect(try DailyPointProgressService.process(
            sessionID: next.id, for: player, on: fixture.date, calendar: fixture.calendar, in: context
        ) == 0)
        #expect(player.coins == 82)
    }

    @Test func legacyAwardsAreNotRecreditedAndPendingProcessingRunsBeforeFish() throws {
        let fixture = try PointFixture()
        let old = fixture.insert(1500)
        old.fishEarnedCount = 1 // 旧callbackで付与済み。新方式からの遡及加算なし。
        let legacy = FocusSessionRecord(completedAt: fixture.date, durationMinutes: 25)
        fixture.context.insert(legacy)
        let new = fixture.insert(300)
        try fixture.context.save()
        try DailyPointProgressService.processPending(
            for: fixture.player, on: fixture.date, calendar: fixture.calendar, in: fixture.context
        )
        #expect(fixture.player.coins == 82)
        #expect(old.pointReward == nil)
        #expect(legacy.pointReward == nil)
        #expect(new.pointReward == 2)
        try DailyPointProgressService.processPending(
            for: fixture.player, on: fixture.date, calendar: fixture.calendar, in: fixture.context
        )
        #expect(fixture.player.coins == 82)
    }

    @Test func delayedYesterdaySessionDoesNotMixWithTodaysRemainder() throws {
        let fixture = try PointFixture()
        #expect(try fixture.add(180) == 0)
        let yesterday = fixture.calendar.date(byAdding: .day, value: -1, to: fixture.date)!
        let record = FocusSessionRecord(completedAt: yesterday, durationMinutes: 2, durationSeconds: 120)
        fixture.context.insert(record)
        #expect(try fixture.process(record.id) == 0)
        #expect(fixture.player.normalPointProgressSeconds == 180)
        #expect(try fixture.add(120) == 2)
    }

    @Test(arguments: [TimerMode.pomodoro, .countdown, .stopwatch])
    func pausedTimeIsNotPaidAndManualStopIsPaid(mode: TimerMode) throws {
        let fixture = try PointFixture()
        let model = fixture.timer(mode)
        model.resumeTimer()
        fixture.advance(180)
        model.pauseTimer()
        fixture.advance(300)
        #expect(fixture.player.coins == 80)
        model.resumeTimer()
        fixture.advance(120)
        model.pauseTimer()
        model.endCurrentSession()
        #expect(fixture.player.coins == 82)
        #expect(try fixture.context.fetch(FetchDescriptor<FocusSessionRecord>()).first?.durationSeconds == 300)
    }

    @Test(arguments: [TimerMode.pomodoro, .countdown, .stopwatch])
    func backgroundFailurePaysOnlyValidTime(mode: TimerMode) throws {
        let fixture = try PointFixture()
        let model = fixture.timer(mode)
        model.resumeTimer()
        fixture.advance(6000)
        model.recordLastActiveTime()
        fixture.advance(300)
        model.recordActiveReturn()
        #expect(fixture.player.coins == 120) // 100分、最後の5分は不算入。
        #expect(try fixture.context.fetch(FetchDescriptor<FocusSessionRecord>()).first?.durationSeconds == 6000)
        model.tick()
        #expect(fixture.player.coins == 120)
    }

    @Test func pomodoroBreakIsNotPaidAndNormalCompletionIsPaid() throws {
        let fixture = try PointFixture()
        let model = fixture.timer(.pomodoro, studyMinutes: 5)
        model.updateConfiguration(studyTime: 5, breakTime: 5, totalSets: 2)
        model.resumeTimer()
        fixture.advance(300)
        model.tick()
        #expect(fixture.player.coins == 82)
        model.beginPomodoroBreak()
        fixture.advance(300)
        model.tick()
        #expect(fixture.player.coins == 82)
        #expect(try fixture.context.fetchCount(FetchDescriptor<FocusSessionRecord>()) == 1)
    }

    @Test func hugeDurationsDoNotOverflow() {
        let result = DailyPointProgressService.progress(adding: Int.max, after: 0)
        #expect(result.awardedPoints > 0)
        #expect(result.normalSeconds == DailyPointProgressService.normalRateCapacitySeconds)
        #expect((0..<1500).contains(result.reducedRemainderUnits))
    }
}

@MainActor
private final class PointFixture {
    let container: ModelContainer
    let context: ModelContext
    let player = Player(coins: 80)
    var date = Date(timeIntervalSince1970: 1_791_000_000)
    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    init() throws {
        container = try ModelContainer(for: Player.self, PlayerFish.self, FocusSessionRecord.self,
                                       StudyDailyRecord.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        context = ModelContext(container)
        context.insert(player)
        try context.save()
    }

    func insert(_ seconds: Int, method: FocusMethod = .timer, category: String? = nil) -> FocusSessionRecord {
        let record = FocusSessionRecord(completedAt: date, durationMinutes: seconds / 60,
                                        categoryID: category ?? FocusCategoryDefaults.studyID, focusMethod: method, durationSeconds: seconds)
        context.insert(record)
        return record
    }

    func process(_ id: UUID) throws -> Int {
        try DailyPointProgressService.process(sessionID: id, for: player, on: date, calendar: calendar, in: context)
    }

    func add(_ seconds: Int, method: FocusMethod = .timer, category: String? = nil) throws -> Int {
        try process(insert(seconds, method: method, category: category).id)
    }

    func seedFishMaximum() throws {
        let record = insert(DailyPointProgressService.normalRateCapacitySeconds)
        record.fishEarnedCount = 8
        try context.save()
    }

    func advance(_ seconds: TimeInterval) { date = date.addingTimeInterval(seconds) }

    func timer(_ mode: TimerMode, studyMinutes: Int = 150) -> TimerViewModel {
        let defaults = UserDefaults(suiteName: "DailyPoints-\(UUID())")!
        let model = TimerViewModel(studyTime: studyMinutes, breakTime: 5, now: { self.date },
                                   sessionStore: TimerSessionStore(defaults: defaults),
                                   notificationService: DisabledTimerNotificationService.shared)
        model.selectMode(mode)
        model.onFocusSessionFinalized = { session in
            do {
                try StudyHistoryService.recordValidFocusSession(session, calendar: self.calendar, in: self.context)
                _ = try self.process(session.id)
                return true
            } catch {
                Issue.record(error)
                return false
            }
        }
        return model
    }
}
