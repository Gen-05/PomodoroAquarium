import Foundation
import SwiftData
import Testing
@testable import PomodoroAquarium

@MainActor
struct DailyFishProgressTests {
    @Test func tenPlusFifteenMinutesEarnsOneFish() throws {
        let fixture = try FishProgressFixture()
        #expect(try fixture.add(600).newFishEarnedCount == 0)
        let result = try fixture.add(900)
        #expect(result.newFishEarnedCount == 1)
        #expect(result.remainderSeconds == 0)
        #expect(fixture.player.pendingFishEarnedCount == 1)
        #expect(fixture.player.ownedFish.isEmpty)
    }

    @Test func twentyPlusTwentyLeavesFifteenMinutes() throws {
        let fixture = try FishProgressFixture()
        try fixture.add(1200)
        let result = try fixture.add(1200)
        #expect(result.newFishEarnedCount == 1)
        #expect(result.remainderSeconds == 900)
        #expect(fixture.player.dailyFishProgressSeconds == 900)
    }

    @Test(arguments: [4500, 6000])
    func oneLongSessionEarnsMultipleUnitsWithoutGeneratingFish(seconds: Int) throws {
        let fixture = try FishProgressFixture()
        let result = try fixture.add(seconds, method: seconds == 4500 ? .timer : .stopwatch)
        #expect(result.newFishEarnedCount == seconds / 1500)
        #expect(result.remainderSeconds == 0)
        #expect(fixture.player.pendingFishEarnedCount == seconds / 1500)
        #expect(fixture.player.ownedFish.isEmpty)
        #expect(fixture.player.coins == 80)
    }

    @Test func boundary1499PlusOneSecondDoesNotRoundMinutes() throws {
        let fixture = try FishProgressFixture()
        #expect(try fixture.add(1499).newFishEarnedCount == 0)
        #expect(fixture.player.dailyFishProgressSeconds == 1499)
        let result = try fixture.add(1)
        #expect(result.newFishEarnedCount == 1)
        #expect(result.remainderSeconds == 0)
        let records = try fixture.context.fetch(FetchDescriptor<FocusSessionRecord>())
        #expect(records.map(\.validFocusSeconds).sorted() == [1, 1499])
        #expect(records.reduce(0) { $0 + $1.durationMinutes } == 24)
    }

    @Test func previousRemainderCombinesWithNextSession() throws {
        let fixture = try FishProgressFixture()
        try fixture.add(1000)
        #expect(try fixture.add(500).newFishEarnedCount == 1)
        try fixture.add(600)
        let result = try fixture.add(2400)
        #expect(result.newFishEarnedCount == 2)
        #expect(result.remainderSeconds == 0)
        #expect(fixture.player.pendingFishEarnedCount == 3)
    }

    @Test func nextDayResetsUnusedSecondsAndUnclaimedRightsButNotHistory() throws {
        let fixture = try FishProgressFixture()
        try fixture.add(2700) // One unit + twenty minutes remainder.
        let before = try fixture.context.fetch(FetchDescriptor<FocusSessionRecord>()).map(\.validFocusSeconds)
        fixture.date = fixture.calendar.date(byAdding: .day, value: 1, to: fixture.date)!
        #expect(try DailyFishProgressService.resetIfNeeded(
            for: fixture.player, on: fixture.date, calendar: fixture.calendar, in: fixture.context
        ))
        #expect(fixture.player.dailyFishProgressSeconds == 0)
        #expect(fixture.player.pendingFishEarnedCount == 0)
        #expect(try fixture.add(300).newFishEarnedCount == 0)
        #expect(fixture.player.dailyFishProgressSeconds == 300)
        let records = try fixture.context.fetch(FetchDescriptor<FocusSessionRecord>())
        #expect(records.map(\.validFocusSeconds).sorted() == (before + [300]).sorted())
        #expect(records.reduce(0) { $0 + $1.durationMinutes } == 50)
    }

    @Test func sameSessionReevaluationDoesNotIncreaseProgressOrPendingUnits() throws {
        let fixture = try FishProgressFixture()
        try fixture.add(2400)
        let id = try #require(fixture.lastSessionID)
        // A fresh ModelContext represents a new View/model read of the same persisted ID.
        let context = ModelContext(fixture.container)
        let player = try #require(context.fetch(FetchDescriptor<Player>()).first)
        let result = try DailyFishProgressService.process(
            sessionID: id, for: player, on: fixture.date,
            calendar: fixture.calendar, in: context
        )
        #expect(result.newFishEarnedCount == 0)
        #expect(player.pendingFishEarnedCount == 1)
        #expect(player.dailyFishProgressSeconds == 900)
        #expect(try context.fetchCount(FetchDescriptor<FocusSessionRecord>()) == 1)
    }

    @Test(arguments: [false, true])
    func realStoreReopenRetainsSameDayProgressAndResetsNextDay(nextDay: Bool) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("DailyFishProgress-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("progress.store")
        let calendar = fishProgressCalendar
        let today = fishProgressDate
        do {
            let fixture = try FishProgressFixture(container: makeFishProgressContainer(url: url))
            try fixture.add(900)
            #expect(fixture.player.dailyFishProgressSeconds == 900)
        }
        let container = try makeFishProgressContainer(url: url)
        let context = ModelContext(container)
        let player = try #require(context.fetch(FetchDescriptor<Player>()).first)
        let date = nextDay ? calendar.date(byAdding: .day, value: 1, to: today)! : today
        try DailyFishProgressService.resetIfNeeded(for: player, on: date, calendar: calendar, in: context)
        #expect(player.dailyFishProgressSeconds == (nextDay ? 0 : 900))
        let session = FinalizedFocusSession(
            id: UUID(), completedAt: date, validFocusSeconds: 600, endReason: .userEnded,
            categoryID: FocusCategoryDefaults.studyID, focusMethod: .timer
        )
        try StudyHistoryService.recordValidFocusSession(session, calendar: calendar, in: context)
        let result = try DailyFishProgressService.process(
            sessionID: session.id, for: player, on: date, calendar: calendar, in: context
        )
        #expect(result.newFishEarnedCount == (nextDay ? 0 : 1))
        #expect(result.remainderSeconds == (nextDay ? 600 : 0))
        #expect(try context.fetchCount(FetchDescriptor<FocusSessionRecord>()) == 2)
    }

    @Test(arguments: [FocusMethod.pomodoro, .timer, .stopwatch])
    func everyMethodAndEndReasonUsesOnlyValidSeconds(method: FocusMethod) throws {
        let fixture = try FishProgressFixture()
        try fixture.add(500, reason: .completed, method: method)
        try fixture.add(500, reason: .userEnded, method: method)
        let result = try fixture.add(500, reason: .backgroundLimitExceeded, method: method)
        #expect(result.newFishEarnedCount == 1)
        #expect(fixture.player.pendingFishEarnedCount == 1)
        #expect(fixture.player.dailyFishProgressSeconds == 0)
    }

    @Test(arguments: [TimerMode.pomodoro, .countdown, .stopwatch])
    func backgroundFailureFeedsStepOneDurationWithoutAddingExcludedFiveMinutes(mode: TimerMode) throws {
        let fixture = try FishProgressFixture()
        let defaults = UserDefaults(suiteName: "DailyFishProgressTimer-\(UUID())")!
        let model = TimerViewModel(
            studyTime: 150, breakTime: 5, now: { fixture.date },
            sessionStore: TimerSessionStore(defaults: defaults),
            notificationService: DisabledTimerNotificationService.shared
        )
        model.selectMode(mode)
        var rewards = 0
        model.onStudyFinished = { rewards += 1 }
        model.onFocusSessionFinalized = { result in
            do {
                try StudyHistoryService.recordValidFocusSession(result, calendar: fixture.calendar, in: fixture.context)
                try DailyFishProgressService.process(
                    sessionID: result.id, for: fixture.player, on: fixture.date,
                    calendar: fixture.calendar, in: fixture.context
                )
                return true
            } catch {
                Issue.record(error)
                return false
            }
        }
        model.resumeTimer()
        fixture.date = fixture.date.addingTimeInterval(1200)
        model.recordLastActiveTime()
        fixture.date = fixture.date.addingTimeInterval(300)
        model.recordActiveReturn()
        #expect(model.lastValidFocusSeconds == 1200)
        #expect(fixture.player.pendingFishEarnedCount == 0)
        #expect(fixture.player.dailyFishProgressSeconds == 1200)
        #expect(rewards == 0)
        #expect(fixture.player.coins == 80)
    }

    @Test func delayedYesterdayRecordNeverCarriesItsRemainderIntoToday() throws {
        let fixture = try FishProgressFixture()
        let yesterday = fixture.calendar.date(byAdding: .day, value: -1, to: fixture.date)!
        try fixture.add(1200, completedAt: yesterday)
        #expect(fixture.player.dailyFishProgressSeconds == 0)
        #expect(try fixture.add(300).newFishEarnedCount == 0)
        // A second delayed record can complete yesterday's unit, but not today's progress.
        #expect(try fixture.add(300, completedAt: yesterday).newFishEarnedCount == 1)
        #expect(fixture.player.dailyFishProgressSeconds == 300)
        #expect(fixture.player.pendingFishEarnedCount == 0)
    }

    @Test func minuteOnlyLegacyHistoryDoesNotGrantFishRetroactively() throws {
        let fixture = try FishProgressFixture()
        let record = FocusSessionRecord(completedAt: fixture.date, durationMinutes: 100)
        fixture.context.insert(record)
        try fixture.context.save()
        let result = try DailyFishProgressService.process(
            sessionID: record.id, for: fixture.player, on: fixture.date,
            calendar: fixture.calendar, in: fixture.context
        )
        #expect(result.newFishEarnedCount == 0)
        #expect(fixture.player.pendingFishEarnedCount == 0)
        #expect(record.durationMinutes == 100)
        #expect(record.durationSeconds == nil)
    }

    @Test func arithmeticHandlesZeroAndLargeDurationsWithoutOverflow() {
        #expect(DailyFishProgressService.progress(adding: -1, to: 0) == .init(newFishEarnedCount: 0, remainderSeconds: 0))
        let result = DailyFishProgressService.progress(adding: Int.max, to: 1499)
        #expect(result.newFishEarnedCount == Int.max / 1500 + (Int.max % 1500 + 1499) / 1500)
        #expect(result.remainderSeconds == (Int.max % 1500 + 1499) % 1500)
    }
}

@MainActor
private final class FishProgressFixture {
    let container: ModelContainer
    let context: ModelContext
    let player: Player
    var date = fishProgressDate
    let calendar = fishProgressCalendar
    var lastSessionID: UUID?

    init(container: ModelContainer? = nil) throws {
        self.container = try container ?? makeFishProgressContainer()
        context = ModelContext(self.container)
        player = Player(coins: 80)
        context.insert(player)
        try context.save()
    }

    @discardableResult
    func add(
        _ seconds: Int,
        reason: StudySessionEndReason = .completed,
        method: FocusMethod = .pomodoro,
        completedAt: Date? = nil
    ) throws -> DailyFishProgressService.Progress {
        let result = FinalizedFocusSession(
            id: UUID(), completedAt: completedAt ?? date, validFocusSeconds: seconds,
            endReason: reason, categoryID: FocusCategoryDefaults.studyID, focusMethod: method
        )
        lastSessionID = result.id
        try StudyHistoryService.recordValidFocusSession(result, calendar: calendar, in: context)
        return try DailyFishProgressService.process(
            sessionID: result.id, for: player, on: date, calendar: calendar, in: context
        )
    }
}

@MainActor
private func makeFishProgressContainer(url: URL? = nil) throws -> ModelContainer {
    let schema = Schema([Player.self, PlayerFish.self, FocusSessionRecord.self, StudyDailyRecord.self])
    let configuration = url.map { ModelConfiguration(schema: schema, url: $0) }
        ?? ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    return try ModelContainer(for: schema, configurations: configuration)
}

private var fishProgressCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
    return calendar
}

private var fishProgressDate: Date {
    fishProgressCalendar.date(from: DateComponents(year: 2026, month: 10, day: 3, hour: 10))!
}
