import Foundation
import SwiftData
import Testing
@testable import PomodoroAquarium

@MainActor
struct DailyFocusIntersectionTests {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return value
    }

    private func date(_ day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    private func crossDayRecord(method: FocusMethod = .pomodoro) -> FocusSessionRecord {
        FocusSessionRecord(
            completedAt: date(6, hour: 2), durationMinutes: 125,
            categoryID: FocusCategoryDefaults.readingID, focusMethod: method,
            durationSeconds: 7500, sessionStartedAt: date(5, hour: 23, minute: 55)
        )
    }

    private func daily(_ day: Int, records: [FocusSessionRecord]) -> FocusPeriodSummary {
        FocusStatisticsService.dailySummary(containing: date(day), from: records, calendar: calendar)
    }

    @Test(arguments: [FocusMethod.pomodoro, .timer, .stopwatch])
    func crossMidnightIsSplitOnlyForDailyDisplay(method: FocusMethod) {
        let record = crossDayRecord(method: method)
        let firstDay = daily(5, records: [record])
        let secondDay = daily(6, records: [record])
        #expect(firstDay.totalMinutes == 5)
        #expect(firstDay.buckets[23].minutes == 5)
        #expect(secondDay.totalMinutes == 120)
        #expect(secondDay.buckets[0].minutes == 60)
        #expect(secondDay.buckets[1].minutes == 60)
        #expect(secondDay.buckets[2].minutes == 0)
        #expect(secondDay.methodBuckets.filter { $0.focusMethod == method }.map(\.minutes).reduce(0, +) == 120)
        #expect(secondDay.methodBuckets.filter { $0.focusMethod != method }.allSatisfy { $0.minutes == 0 })
        #expect(record.validFocusSeconds == 7500)
        #expect(record.sessionDay(calendar: calendar) == date(5))
    }

    @Test func longerPeriodsKeepTheWholeSessionOnItsStartDay() {
        let record = crossDayRecord()
        let week = FocusStatisticsService.weeklySummary(containing: date(5), from: [record], calendar: calendar)
        #expect(week.totalMinutes == 125)
        #expect(week.buckets.first { $0.start == date(5) }?.minutes == 125)
        #expect(week.buckets.first { $0.start == date(6) }?.minutes == 0)
        let month = FocusStatisticsService.monthlySummary(containing: date(6), from: [record], calendar: calendar)
        #expect(month.totalMinutes == 125)
        #expect(month.days[4].minutes == 125)
        #expect(month.days[5].minutes == 0)
        let year = FocusStatisticsService.yearlySummary(for: 2026, from: [record], calendar: calendar)
        #expect(year.totalMinutes == 125)
        #expect(year.buckets[9].minutes == 125)
    }

    @Test func annualDetailKeepsWholeRecordWhileDailyDetailUsesVisibleSlices() {
        let record = crossDayRecord()
        let year = FocusStatisticsService.yearlySummary(for: 2026, from: [record], calendar: calendar)
        let detail = FocusStatisticsService.bucketDetail(
            for: year.buckets[9], period: .year, from: [record], categories: [], calendar: calendar
        )
        #expect(detail.totalMinutes == 125)
        #expect(detail.sessions.map(\.id) == [record.id])
        #expect(detail.sessionDaySections.map(\.day) == [date(5)])
        #expect(detail.sessions.first?.startedAt == record.sessionStartedAt)
        #expect(detail.sessions.first?.completedAt == record.completedAt)
        let startDay = daily(5, records: [record])
        let hourlyDetail = FocusStatisticsService.bucketDetail(
            for: startDay.buckets[23], period: .day, from: [record], categories: [], calendar: calendar
        )
        #expect(hourlyDetail.totalMinutes == 5)
        #expect(hourlyDetail.methodSummary.map(\.minutes).reduce(0, +) == 5)
        #expect(hourlyDetail.categorySummary.map(\.minutes).reduce(0, +) == 5)
        #expect(hourlyDetail.sessions.first?.durationSeconds == 300)
        let nextDay = daily(6, records: [record])
        let nextDetail = FocusStatisticsService.bucketDetail(
            for: nextDay.buckets[0], period: .day, from: [record], categories: [], calendar: calendar
        )
        #expect(nextDetail.sessions.map(\.id) == [record.id])
        #expect(nextDetail.totalMinutes == 60)
        #expect(nextDetail.sessions.first?.startedAt == date(6))
        #expect(nextDetail.sessions.first?.completedAt == date(6, hour: 1))
    }

    @Test func sameDaySessionAndEmptyDayRemainCorrect() {
        let record = FocusSessionRecord(
            completedAt: date(5, hour: 23, minute: 30), durationMinutes: 30,
            focusMethod: .timer, durationSeconds: 1800, sessionStartedAt: date(5, hour: 23)
        )
        #expect(daily(5, records: [record]).buckets[23].minutes == 30)
        #expect(daily(5, records: [record]).totalMinutes == 30)
        #expect(daily(6, records: [record]).totalMinutes == 0)
        #expect(daily(6, records: []).buckets.count == 24)
    }

    @Test func dayCategoryTotalsUseTheSameVisibleTimeAndOriginalCategory() {
        let record = crossDayRecord()
        let category = FocusCategory(id: FocusCategoryDefaults.readingID, name: "読書", color: .studyBlue, isDefault: true)
        for day in [5, 6] {
            let summary = daily(day, records: [record])
            let categories = FocusStatisticsService.categorySummary(for: summary, from: [record], categories: [category])
            #expect(categories.map(\.minutes).reduce(0, +) == summary.totalMinutes)
            #expect(categories.first?.id == record.categoryID)
        }
    }

    @Test func fractionalHoursDoNotLoseMinutesAndKeepStackAndCategoryTotalsEqual() {
        let start = date(6, minute: 59).addingTimeInterval(30)
        let record = FocusSessionRecord(
            completedAt: start.addingTimeInterval(90), durationMinutes: 1,
            categoryID: FocusCategoryDefaults.readingID, focusMethod: .timer,
            durationSeconds: 90, sessionStartedAt: start
        )
        let summary = daily(6, records: [record])
        #expect(summary.totalMinutes == 1)
        #expect(summary.buckets[1].minutes == 1)
        #expect(summary.methodBuckets.map(\.minutes).reduce(0, +) == 1)
        let categories = FocusStatisticsService.categorySummary(for: summary, from: [record], categories: [])
        #expect(categories.map(\.minutes).reduce(0, +) == 1)
    }

    @Test func validSecondsNotWallClockDurationRemainTheDisplayBudget() {
        let record = crossDayRecord()
        record.durationSeconds = 1500 // pause/失敗で有効時間が短い記録。
        #expect(daily(5, records: [record]).totalMinutes == 1)
        #expect(daily(6, records: [record]).totalMinutes == 24)
        #expect(record.durationSeconds == 1500)
        record.durationSeconds = nil
        #expect(daily(5, records: [record]).totalMinutes == 5)
        #expect(daily(6, records: [record]).totalMinutes == 120)
    }

    @Test func legacyRecordWithoutStartKeepsItsExistingHourAndStreakDoesNotSplit() {
        let legacy = FocusSessionRecord(completedAt: date(6, hour: 2), durationMinutes: 125)
        #expect(daily(6, records: [legacy]).buckets[2].minutes == 125)
        #expect(daily(5, records: [legacy]).totalMinutes == 0)
        #expect(FocusStatisticsService.currentStreak(at: date(6), from: [crossDayRecord()], calendar: calendar) == 1)
        #expect(FocusStatisticsService.currentStreak(at: date(7), from: [crossDayRecord()], calendar: calendar) == 0)
    }

    @Test func dailyDisplayDoesNotSplitSavedDataOrChangeFishPointsAndRarity() throws {
        let container = try ModelContainer(
            for: Player.self, PlayerFish.self, FocusSessionRecord.self, RewardHistoryEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let player = Player()
        let record = crossDayRecord(method: .timer)
        context.insert(player)
        context.insert(record)
        try context.save()
        let defaults = UserDefaults(suiteName: "DailyIntersection-\(UUID())")!
        #expect(try DailyPointProgressService.process(sessionID: record.id, for: player, on: record.completedAt,
                                                    calendar: calendar, in: context) == 50)
        let fish = try DailyFishProgressService.process(sessionID: record.id, for: player, on: record.completedAt,
                                                       calendar: calendar, in: context)
        #expect(fish.newFishEarnedCount == 5)
        let batch = try FishRewardBatchService.grant(sessionID: record.id, to: player, on: record.completedAt,
                                                   calendar: calendar, defaults: defaults, in: context, draw: { _ in .clownfish })
        #expect(batch?.results.count == 3)
        #expect(player.dailyEarnedFishCount == 5)
        #expect(player.dailyClaimedFishCount == 3)
        #expect(player.dailyFishLimit == 3)
        #expect(player.dailyPendingFishCount == 2)
        #expect(player.dailyGrantedFishDate == date(5))
        #expect(player.dailyPointProgressDate == date(5))
        let coins = player.coins
        for _ in 0..<2 {
            #expect(daily(5, records: [record]).totalMinutes == 5)
            #expect(daily(6, records: [record]).totalMinutes == 120)
            let detail = FocusStatisticsService.bucketDetail(
                for: daily(6, records: [record]).buckets[0], period: .day,
                from: [record], categories: [], calendar: calendar
            )
            #expect(detail.sessions.first?.durationSeconds == 3600)
            #expect(detail.totalMinutes == 60)
        }
        #expect(try context.fetchCount(FetchDescriptor<FocusSessionRecord>()) == 1)
        #expect(record.validFocusSeconds == 7500)
        #expect(try PreviousDayFocusDurationService.minutes(before: date(6), calendar: calendar, in: context) == 125)
        #expect(try DailyPointProgressService.process(sessionID: record.id, for: player, on: record.completedAt,
                                                    calendar: calendar, in: context) == 0)
        #expect(try DailyFishProgressService.process(sessionID: record.id, for: player, on: record.completedAt,
                                                   calendar: calendar, in: context).newFishEarnedCount == 0)
        #expect(try FishRewardBatchService.grant(sessionID: record.id, to: player, on: record.completedAt,
                                              calendar: calendar, defaults: defaults, in: context) == nil)
        #expect(player.coins == coins)
        #expect(player.dailyClaimedFishCount == 3)
    }

    @Test func midnightDetailShowsFiveAndThirtySevenMinutesWithContinuationLabels() throws {
        let record = FocusSessionRecord(
            completedAt: date(6, minute: 37), durationMinutes: 42,
            categoryID: FocusCategoryDefaults.readingID, focusMethod: .timer,
            durationSeconds: 2520, sessionStartedAt: date(5, hour: 23, minute: 55)
        )
        let first = FocusStatisticsService.bucketDetail(
            for: daily(5, records: [record]).buckets[23], period: .day,
            from: [record], categories: [], calendar: calendar
        )
        let second = FocusStatisticsService.bucketDetail(
            for: daily(6, records: [record]).buckets[0], period: .day,
            from: [record], categories: [], calendar: calendar
        )
        let firstSession = try #require(first.sessions.first)
        let secondSession = try #require(second.sessions.first)
        #expect(firstSession.startedAt == date(5, hour: 23, minute: 55))
        #expect(firstSession.completedAt == date(6)) // UIは24:00として表示。
        #expect(firstSession.durationMinutes == 5)
        #expect(firstSession.displaySlice?.continuationText == "翌日まで継続")
        #expect(secondSession.startedAt == date(6))
        #expect(secondSession.completedAt == date(6, minute: 37))
        #expect(secondSession.durationMinutes == 37)
        #expect(secondSession.displaySlice?.continuationText == "前日から継続")
        #expect(first.totalMinutes == 5)
        #expect(second.totalMinutes == 37)
        #expect(second.methodSummary.map(\.minutes) == [37])
        #expect(second.categorySummary.map(\.minutes) == [37])
        #expect(second.sessionDaySections.map(\.day) == [date(6)])
        #expect(daily(6, records: [record]).totalMinutes == 37)
        let daySlice = try #require(FocusStatisticsService.dailyDisplaySlice(
            for: record, in: DateInterval(start: date(6), end: date(7)), calendar: calendar
        ))
        #expect(daySlice.durationSeconds == 37 * 60)
        #expect(record.sessionStartedAt == date(5, hour: 23, minute: 55))
        #expect(record.durationSeconds == 2520)
    }

    @Test(arguments: [FocusMethod.pomodoro, .timer, .stopwatch])
    func eachHourDetailClipsSameDaySessionsAndPreservesCategoryAndMethod(method: FocusMethod) throws {
        let category = FocusCategory(id: "custom-reading", name: "読書", color: .oceanTeal,
                                     customHex: "#12B886", isDefault: false, isArchived: true)
        let record = FocusSessionRecord(
            completedAt: date(6, hour: 12, minute: 20), durationMinutes: 100,
            categoryID: category.id, focusMethod: method,
            durationSeconds: 6000, sessionStartedAt: date(6, hour: 10, minute: 40)
        )
        let summary = daily(6, records: [record])
        let starts = [date(6, hour: 10, minute: 40), date(6, hour: 11), date(6, hour: 12)]
        let ends = [date(6, hour: 11), date(6, hour: 12), date(6, hour: 12, minute: 20)]
        for (index, hour) in [10, 11, 12].enumerated() {
            let detail = FocusStatisticsService.bucketDetail(
                for: summary.buckets[hour], period: .day, from: [record], categories: [category], calendar: calendar
            )
            let session = try #require(detail.sessions.first)
            #expect(session.startedAt == starts[index])
            #expect(session.completedAt == ends[index])
            #expect(session.durationMinutes == [20, 60, 20][index])
            #expect(session.method == method)
            #expect(session.category.id == category.id)
            #expect(session.category.isArchived)
            #expect(session.category.resolvedCustomHex == "#12B886")
            #expect(session.displaySlice?.continuationText == nil)
            #expect(detail.totalMinutes == summary.buckets[hour].minutes)
            #expect(detail.methodSummary.map(\.minutes) == [session.durationMinutes])
            #expect(detail.categorySummary.map(\.minutes) == [session.durationMinutes])
        }
        #expect(summary.totalMinutes == 100)
        let empty = FocusStatisticsService.bucketDetail(
            for: summary.buckets[13], period: .day, from: [record], categories: [category], calendar: calendar
        )
        #expect(empty.sessions.isEmpty)
        #expect(empty.totalMinutes == 0)
    }

    @Test(arguments: [FocusStatisticsPeriod.week, .month, .year])
    func nonDailyDetailsKeepTheWholeCrossDaySession(period: FocusStatisticsPeriod) throws {
        let record = FocusSessionRecord(
            completedAt: date(6, minute: 37), durationMinutes: 42,
            focusMethod: .pomodoro, durationSeconds: 2520,
            sessionStartedAt: date(5, hour: 23, minute: 55)
        )
        let summary = FocusStatisticsService.summary(for: period, containing: date(5), from: [record], calendar: calendar)
        let bucket = try #require(summary.buckets.first { $0.minutes > 0 })
        let detail = FocusStatisticsService.bucketDetail(
            for: bucket, period: period, from: [record], categories: [], calendar: calendar
        )
        #expect(detail.sessions.count == 1)
        #expect(detail.sessions.first?.id == record.id)
        #expect(detail.sessions.first?.displaySlice == nil)
        #expect(detail.sessions.first?.startedAt == record.sessionStartedAt)
        #expect(detail.sessions.first?.completedAt == record.completedAt)
        #expect(detail.sessions.first?.durationSeconds == 2520)
        #expect(detail.totalMinutes == 42)
        #expect(detail.sessionDaySections.map(\.day) == [date(5)])
    }

    @Test func fractionalAndReducedValidDurationsUseTheSameBudgetAsDailyBars() throws {
        let record = crossDayRecord()
        record.durationSeconds = 1500
        for (day, hour) in [(5, 23), (6, 0), (6, 1)] {
            let summary = daily(day, records: [record])
            let detail = FocusStatisticsService.bucketDetail(
                for: summary.buckets[hour], period: .day, from: [record], categories: [], calendar: calendar
            )
            #expect(detail.totalMinutes == summary.buckets[hour].minutes)
            #expect(detail.sessions.map(\.durationSeconds).reduce(0, +) == detail.totalMinutes * 60)
            #expect(detail.methodSummary.map(\.minutes).reduce(0, +) == detail.totalMinutes)
            #expect(detail.categorySummary.map(\.minutes).reduce(0, +) == detail.totalMinutes)
        }
        let start = date(6, minute: 59).addingTimeInterval(30)
        let fractional = FocusSessionRecord(
            completedAt: start.addingTimeInterval(90), durationMinutes: 1,
            focusMethod: .stopwatch, durationSeconds: 90, sessionStartedAt: start
        )
        let summary = daily(6, records: [fractional])
        for hour in [0, 1] {
            let detail = FocusStatisticsService.bucketDetail(
                for: summary.buckets[hour], period: .day, from: [fractional], categories: [], calendar: calendar
            )
            #expect(detail.totalMinutes == summary.buckets[hour].minutes)
            #expect(detail.methodSummary.map(\.minutes).reduce(0, +) == detail.totalMinutes)
            #expect(detail.categorySummary.map(\.minutes).reduce(0, +) == detail.totalMinutes)
        }
    }
}
