import Foundation
import SwiftData
import Testing
@testable import PomodoroAquarium

@MainActor
struct CrossDayFocusSessionTests {
    @Test(arguments: [25, 30, 130])
    func completedSessionBelongsEntirelyToItsStartDay(minutes: Int) throws {
        let fixture = try CrossDayFixture()
        let start = fixture.date
        let model = fixture.timer(.countdown, minutes: minutes)
        model.resumeTimer()
        fixture.date += TimeInterval(minutes * 60)
        model.tick()
        let record = try #require(fixture.records.first)
        #expect(record.sessionStartedAt == start)
        #expect(record.completedAt == fixture.date)
        #expect(record.validFocusSeconds == minutes * 60)
        #expect(record.sessionDay(calendar: fixture.calendar) == fixture.day(5))
        let previous = FocusStatisticsService.dailySummary(containing: start, from: fixture.records, calendar: fixture.calendar)
        let today = FocusStatisticsService.dailySummary(containing: fixture.date, from: fixture.records, calendar: fixture.calendar)
        #expect(previous.totalMinutes == 10)
        #expect(previous.buckets[23].minutes == 10)
        #expect(today.totalMinutes == minutes - 10)
        let dailyRecords = try fixture.context.fetch(FetchDescriptor<StudyDailyRecord>())
        #expect(StudyHistoryService.minutes(on: start, from: dailyRecords, calendar: fixture.calendar) == minutes)
        #expect(StudyHistoryService.minutes(on: fixture.date, from: dailyRecords, calendar: fixture.calendar) == 0)
        try StudyHistoryService.synchronizeCurrentDayTotals(for: fixture.player, at: fixture.date,
                                                          calendar: fixture.calendar, in: fixture.context)
        #expect(fixture.player.todayStudyMinutes == 0)
        #expect(fixture.player.yesterdayStudyMinutes == minutes)
        #expect(fixture.player.dailyGrantedFishDate == fixture.day(5))
        #expect(fixture.player.dailyFishProgressSeconds == minutes * 60 % 1500)
        #expect(fixture.player.dailyPointProgressDate == fixture.day(5))
        #expect(record.pointReward == minutes / 5 * 2)
    }

    @Test func crossDayFishUsesThePreviousDaysClaimLimitAndPendingRights() throws {
        let fixture = try CrossDayFixture()
        try fixture.complete(start: fixture.day(5).addingTimeInterval(12 * 3600), seconds: 3000)
        #expect(fixture.player.dailyClaimedFishCount == 2)
        #expect(fixture.player.dailyFishLimit == 3)
        let result = try fixture.complete(start: fixture.date, seconds: 3000)
        #expect(result.fishEarnedCount == 2)
        #expect(fixture.player.dailyEarnedFishCount == 4)
        #expect(fixture.player.dailyClaimedFishCount == 3)
        #expect(fixture.player.dailyPendingFishCount == 1)
        #expect(fixture.player.pendingFishEarnedCount == 1)
        #expect(fixture.player.dailyGrantedFishDate == fixture.day(5))
        #expect(fixture.player.ownedFish.count == 3)
        #expect(try fixture.context.fetchCount(FetchDescriptor<RewardHistoryEntry>()) == 3)
    }

    @Test(arguments: [false, true])
    func midnightKeepsTheActiveDaysRemaindersAndNextSessionStartsFresh(reduced: Bool) throws {
        let fixture = try CrossDayFixture()
        try fixture.complete(start: fixture.day(5).addingTimeInterval(8 * 3600), seconds: reduced ? 12780 : 3180)
        let fishRemainder = fixture.player.dailyFishProgressSeconds
        let normalRemainder = fixture.player.normalPointProgressSeconds
        let reducedRemainder = fixture.player.reducedPointProgressUnits
        let claimed = fixture.player.dailyClaimedFishCount
        let model = fixture.timer(.stopwatch)
        model.resumeTimer()
        fixture.date += 600 // Midnight while the same session is running.
        let pinnedDate = model.dailyRewardReferenceDate(at: fixture.date)
        #expect(fixture.calendar.isDate(pinnedDate, inSameDayAs: fixture.day(5)))
        try DailyFishProgressService.resetIfNeeded(for: fixture.player, on: pinnedDate, calendar: fixture.calendar, in: fixture.context)
        try DailyPointProgressService.resetIfNeeded(for: fixture.player, on: pinnedDate, calendar: fixture.calendar, in: fixture.context)
        #expect(fixture.player.dailyFishProgressSeconds == fishRemainder)
        #expect(fixture.player.normalPointProgressSeconds == normalRemainder)
        #expect(fixture.player.reducedPointProgressUnits == reducedRemainder)
        #expect(fixture.player.dailyClaimedFishCount == claimed)
        #expect(fixture.player.dailyFishLimit == 3)
        model.pauseTimer()
        model.endCurrentSession()
        #expect(fixture.player.dailyGrantedFishDate == fixture.day(5))
        fixture.date += 60
        model.resetTimer()
        model.resumeTimer()
        let nextDate = model.dailyRewardReferenceDate(at: fixture.date)
        #expect(fixture.calendar.isDate(nextDate, inSameDayAs: fixture.day(6)))
        try DailyFishProgressService.resetIfNeeded(for: fixture.player, on: nextDate, calendar: fixture.calendar, in: fixture.context)
        try DailyPointProgressService.resetIfNeeded(for: fixture.player, on: nextDate, calendar: fixture.calendar, in: fixture.context)
        #expect(fixture.player.dailyEarnedFishCount == 0)
        #expect(fixture.player.dailyClaimedFishCount == 0)
        #expect(fixture.player.dailyFishLimit == 3)
        #expect(fixture.player.dailyFishProgressSeconds == 0)
        #expect(fixture.player.normalPointProgressSeconds == 0)
        #expect(fixture.player.reducedPointProgressUnits == 0)
        fixture.date += 300
        model.pauseTimer()
        model.endCurrentSession()
        #expect(fixture.records.last?.sessionDay(calendar: fixture.calendar) == fixture.day(6))
        #expect(fixture.records.last?.pointReward == 2)
        #expect(fixture.player.dailyFishProgressSeconds == 300)
    }

    @Test func annualDetailUsesTheStartDaySectionAndPreviousDayRarityIncludesTheWholeSession() throws {
        let fixture = try CrossDayFixture()
        let start = fixture.date
        let record = try fixture.complete(start: start, seconds: 7800)
        let summary = FocusStatisticsService.yearlySummary(for: 2026, from: fixture.records, calendar: fixture.calendar)
        let detail = FocusStatisticsService.bucketDetail(for: summary.buckets[9], period: .year,
                                                       from: fixture.records, categories: [], calendar: fixture.calendar)
        #expect(detail.sessionDaySections.map(\.day) == [fixture.day(5)])
        #expect(detail.sessions.first?.startedAt == start)
        #expect(detail.sessions.first?.completedAt == record.completedAt)
        #expect(detail.totalMinutes == 130)
        let next = fixture.day(6).addingTimeInterval(3 * 3600)
        #expect(try PreviousDayFocusDurationService.minutes(before: next, calendar: fixture.calendar, in: fixture.context) == 130)
        var received: FishRewardService.RarityProbabilities?
        let newSession = FinalizedFocusSession(id: UUID(), completedAt: next.addingTimeInterval(1500),
                                             validFocusSeconds: 1500, endReason: .completed,
                                             categoryID: FocusCategoryDefaults.studyID, focusMethod: .timer,
                                             sessionStartedAt: next)
        try fixture.saveAndProcess(newSession, draw: { probabilities in received = probabilities; return .clownfish })
        let expected = FishRewardService.rarityProbabilities(for: 130)
        #expect(received?.common == expected.common)
        #expect(received?.rare == expected.rare)
        #expect(received?.epic == expected.epic)
        #expect(received?.legendary == expected.legendary)
    }

    @Test func pauseDoesNotChangeTheOriginalStartTimestamp() throws {
        let fixture = try CrossDayFixture()
        let start = fixture.date
        let model = fixture.timer(.stopwatch)
        model.resumeTimer()
        fixture.date += 300
        model.pauseTimer()
        fixture.date += 1200
        model.resumeTimer()
        fixture.date += 300
        model.pauseTimer()
        model.endCurrentSession()
        #expect(fixture.records.first?.sessionStartedAt == start)
        #expect(fixture.records.first?.validFocusSeconds == 600)
        #expect(fixture.records.first?.sessionDay(calendar: fixture.calendar) == fixture.day(5))
    }

    @Test func aNewStudyUsesItsOwnDayEvenIfAnOlderFinalizationIsPending() throws {
        let fixture = try CrossDayFixture()
        let pending = FinalizedFocusSession(id: UUID(), completedAt: fixture.day(6), validFocusSeconds: 600,
                                            endReason: .userEnded, categoryID: FocusCategoryDefaults.studyID,
                                            focusMethod: .timer, sessionStartedAt: fixture.date)
        let store = TimerSessionStore(defaults: fixture.defaults)
        store.enqueueFocusSession(pending)
        fixture.date = fixture.day(6).addingTimeInterval(3 * 3600)
        let model = fixture.timer(.stopwatch)
        model.resumeTimer()
        #expect(model.dailyRewardReferenceDate(at: fixture.date) == fixture.date)
        #expect(store.pendingFocusSessions().map(\.id) == [pending.id])
    }

    @Test(arguments: [120, 300])
    func restartRetainsTheOriginalDayAndTheExistingBackgroundDurationRules(absence: Int) throws {
        let fixture = try CrossDayFixture()
        let start = fixture.date
        let model = fixture.timer(.stopwatch)
        model.resumeTimer()
        fixture.date += 600
        model.recordLastActiveTime()
        fixture.date += TimeInterval(absence)
        let restored = fixture.timer(.stopwatch, process: "relaunch")
        restored.restorePersistedSessionIfNeeded()
        if absence == 300 {
            #expect(restored.lastStudySessionEndReason == .backgroundLimitExceeded)
        } else {
            #expect(restored.isRunning)
            restored.recordActiveReturn()
            restored.pauseTimer()
            restored.endCurrentSession()
        }
        #expect(fixture.records.first?.sessionStartedAt == start)
        #expect(fixture.records.first?.durationSeconds == (absence == 300 ? 600 : 720))
        #expect(fixture.records.first?.sessionDay(calendar: fixture.calendar) == fixture.day(5))
        #expect(fixture.records.first?.pointReward == 4)
    }

    @Test func automaticPomodoroAssignsEachStudyItsOwnStartDayRatherThanTheFlowDay() throws {
        let fixture = try CrossDayFixture()
        fixture.date -= 900 // 23:35 -> first study completes exactly at midnight.
        let model = fixture.timer(.pomodoro, minutes: 25)
        model.updateConfiguration(studyTime: 25, breakTime: 5, totalSets: 2)
        model.configureAutoStartNextSet(true)
        model.setAppActive(true)
        model.setTimerScreenVisible(true)
        model.resumeTimer()
        fixture.date += 1500
        model.tick()
        #expect(model.phase == .breakTime)
        #expect(fixture.records.first?.sessionDay(calendar: fixture.calendar) == fixture.day(5))
        fixture.date += 300
        model.tick()
        #expect(model.phase == .study)
        #expect(model.sessionStartedAt == fixture.date)
        fixture.date += 1500
        model.tick()
        #expect(model.phase == .finished)
        #expect(fixture.records.count == 2)
        #expect(fixture.records.map { $0.sessionDay(calendar: fixture.calendar) } == [fixture.day(5), fixture.day(6)])
        #expect(fixture.records.map(\.pointReward) == [10, 10])
        #expect(fixture.player.dailyClaimedFishCount == 1)
        #expect(fixture.player.ownedFish.count == 2)
    }

    @Test(arguments: [9, 12])
    func monthAndYearBoundaryStatisticsUseTheStartDate(month: Int) {
        let fixtureCalendar: Calendar = {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
            return calendar
        }()
        let lastDay = month == 9 ? 30 : 31
        let start = fixtureCalendar.date(from: DateComponents(year: 2026, month: month, day: lastDay, hour: 23, minute: 50))!
        let record = FocusSessionRecord(completedAt: start.addingTimeInterval(1800), durationMinutes: 30,
                                        durationSeconds: 1800, sessionStartedAt: start)
        let startMonth = FocusStatisticsService.monthlySummary(containing: start, from: [record], calendar: fixtureCalendar)
        let endMonth = FocusStatisticsService.monthlySummary(containing: record.completedAt, from: [record], calendar: fixtureCalendar)
        #expect(startMonth.days.last?.minutes == 30)
        #expect(endMonth.totalMinutes == 0)
        #expect(FocusStatisticsService.yearlySummary(for: 2026, from: [record], calendar: fixtureCalendar).buckets[month - 1].minutes == 30)
        #expect(FocusStatisticsService.yearlySummary(for: 2027, from: [record], calendar: fixtureCalendar).totalMinutes == 0)
    }

    @Test func delayedCrossDaySaveRestoresOldSlotsAndReprocessingNeverCreditsTwice() throws {
        let fixture = try CrossDayFixture()
        try fixture.complete(start: fixture.day(5).addingTimeInterval(12 * 3600), seconds: 3000)
        _ = try FishRewardBatchService.unlockOneFishSlot(for: fixture.player, on: fixture.day(5),
                                                       calendar: fixture.calendar, defaults: fixture.defaults, in: fixture.context)
        try DailyFishProgressService.resetIfNeeded(for: fixture.player, on: fixture.day(6), calendar: fixture.calendar, in: fixture.context)
        try DailyPointProgressService.resetIfNeeded(for: fixture.player, on: fixture.day(6), calendar: fixture.calendar, in: fixture.context)
        // A new context represents reopening persisted day snapshots before a delayed callback.
        let context = ModelContext(fixture.container)
        let player = try #require(context.fetch(FetchDescriptor<Player>()).first)
        let session = FinalizedFocusSession(id: UUID(), completedAt: fixture.date.addingTimeInterval(3000),
                                           validFocusSeconds: 3000, endReason: .userEnded,
                                           categoryID: FocusCategoryDefaults.studyID, focusMethod: .timer,
                                           sessionStartedAt: fixture.date)
        try StudyHistoryService.recordValidFocusSession(session, for: player, calendar: fixture.calendar, in: context)
        try DailyPointProgressService.process(sessionID: session.id, for: player, on: fixture.day(6), calendar: fixture.calendar, in: context)
        try DailyFishProgressService.process(sessionID: session.id, for: player, on: fixture.day(6), calendar: fixture.calendar, in: context)
        let batch = try FishRewardBatchService.grant(sessionID: session.id, to: player, on: fixture.day(6),
                                                   calendar: fixture.calendar, defaults: fixture.defaults, in: context, draw: { _ in .clownfish })
        #expect(batch?.results.count == 2)
        #expect(player.dailyGrantedFishDate == fixture.day(5))
        #expect(player.dailyClaimedFishCount == 4)
        #expect(player.dailyFishLimit == 4)
        let coins = player.coins
        let fish = player.ownedFish.count
        let total = player.totalStudyMinutes
        try DailyFishProgressService.resetIfNeeded(for: player, on: fixture.day(6), calendar: fixture.calendar, in: context)
        try DailyPointProgressService.resetIfNeeded(for: player, on: fixture.day(6), calendar: fixture.calendar, in: context)
        try StudyHistoryService.recordValidFocusSession(session, for: player, calendar: fixture.calendar, in: context)
        #expect(try DailyPointProgressService.process(sessionID: session.id, for: player, on: fixture.day(6), calendar: fixture.calendar, in: context) == 0)
        #expect(try DailyFishProgressService.process(sessionID: session.id, for: player, on: fixture.day(6), calendar: fixture.calendar, in: context).newFishEarnedCount == 0)
        #expect(try FishRewardBatchService.grant(sessionID: session.id, to: player, on: fixture.day(6),
                                              calendar: fixture.calendar, defaults: fixture.defaults, in: context) == nil)
        #expect(player.coins == coins)
        #expect(player.ownedFish.count == fish)
        #expect(player.totalStudyMinutes == total)
        #expect(player.dailyGrantedFishDate == fixture.day(6))
        #expect(player.dailyClaimedFishCount == 0)
        #expect(try context.fetchCount(FetchDescriptor<FocusSessionRecord>()) == 2)
    }
}

@MainActor
private final class CrossDayFixture {
    let container: ModelContainer
    let context: ModelContext
    let player = Player()
    let defaults: UserDefaults
    var date: Date
    var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return value
    }
    var records: [FocusSessionRecord] {
        do { return try context.fetch(FetchDescriptor<FocusSessionRecord>(sortBy: [SortDescriptor(\.completedAt)])) }
        catch { Issue.record(error); return [] }
    }

    init() throws {
        container = try ModelContainer(for: Player.self, PlayerFish.self, FocusSessionRecord.self,
                                       StudyDailyRecord.self, RewardHistoryEntry.self,
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        context = ModelContext(container)
        defaults = UserDefaults(suiteName: "CrossDay-\(UUID())")!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        date = calendar.date(from: DateComponents(year: 2026, month: 10, day: 5, hour: 23, minute: 50))!
        context.insert(player)
        try context.save()
    }

    func day(_ day: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day))!
    }

    func timer(_ mode: TimerMode, minutes: Int = 150, process: String = "initial") -> TimerViewModel {
        let model = TimerViewModel(studyTime: minutes, breakTime: 5, totalSets: 1, now: { self.date },
                                   sessionStore: TimerSessionStore(defaults: defaults, processIdentifier: process),
                                   notificationService: DisabledTimerNotificationService.shared)
        model.selectMode(mode)
        model.onFocusSessionFinalized = { session in
            do { try self.saveAndProcess(session); return true }
            catch { Issue.record(error); return false }
        }
        return model
    }

    @discardableResult
    func complete(start: Date, seconds: Int) throws -> FocusSessionRecord {
        let session = FinalizedFocusSession(id: UUID(), completedAt: start.addingTimeInterval(TimeInterval(seconds)),
                                           validFocusSeconds: seconds, endReason: .completed,
                                           categoryID: FocusCategoryDefaults.studyID, focusMethod: .timer,
                                           sessionStartedAt: start)
        try saveAndProcess(session)
        return try #require(records.first { $0.id == session.id })
    }

    func saveAndProcess(_ session: FinalizedFocusSession,
                        draw: @MainActor (FishRewardService.RarityProbabilities) -> FishSpecies? = { _ in .clownfish }) throws {
        try StudyHistoryService.recordValidFocusSession(session, for: player, calendar: calendar, in: context)
        try DailyPointProgressService.process(sessionID: session.id, for: player, on: session.completedAt, calendar: calendar, in: context)
        try DailyFishProgressService.process(sessionID: session.id, for: player, on: session.completedAt, calendar: calendar, in: context)
        _ = try FishRewardBatchService.grant(sessionID: session.id, to: player, on: session.completedAt,
                                           calendar: calendar, defaults: defaults, in: context, draw: draw)
    }
}
