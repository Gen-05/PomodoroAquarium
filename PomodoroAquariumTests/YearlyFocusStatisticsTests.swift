import Foundation
import Testing
@testable import PomodoroAquarium

@MainActor
struct YearlyFocusStatisticsTests {
    @Test func pickerIncludesYearWithoutApplyingAnEntitlementLock() {
        #expect(FocusStatisticsPeriod.currentlySelectable == [.day, .week, .month, .year])
        #expect(FocusStatisticsPeriod.year.title == "年間")
        #expect(FocusStatisticsPeriod.currentlySelectable.allSatisfy { !$0.isPlusFeature })
        #expect(!FocusStatisticsFeature.barChart.requiresPlus)
        #expect(FocusStatisticsFeature.categoryChart.requiresPlus)
        #expect(FocusStatisticsFeature.sessionDetail.requiresPlus)
    }

    @Test(arguments: [2024, 2026, 2027])
    func emptyYearStillContainsAllTwelveMonths(year: Int) {
        let summary = FocusStatisticsService.yearlySummary(
            for: year, from: [], calendar: yearlyCalendar
        )
        #expect(summary.period == .year)
        #expect(summary.buckets.count == 12)
        #expect(summary.buckets.map { yearlyCalendar.component(.month, from: $0.start) } == Array(1...12))
        #expect(summary.buckets.allSatisfy { yearlyCalendar.component(.year, from: $0.start) == year })
        #expect(summary.buckets.allSatisfy { $0.minutes == 0 })
        #expect(summary.methodBuckets.count == 36)
        #expect(summary.methodBuckets.allSatisfy { $0.minutes == 0 })
        #expect(summary.totalMinutes == 0)
        #expect(FocusStatisticsService.yearlyAxisMonths == Array(1...12).map(Double.init))
        #expect(FocusStatisticsService.yearlyAxisDomain == 0.5...12.5)
        #expect(FocusStatisticsService.yearlyYAxisDomain(for: summary).upperBound > 0)
    }

    @Test func sessionsInTheSameMonthStackAllMethodsAtTheSameMonthPosition() {
        let records = [
            yearlyRecord(month: 9, day: 1, minutes: 25, method: .pomodoro),
            yearlyRecord(month: 9, day: 30, minutes: 50, method: .pomodoro),
            yearlyRecord(month: 9, minutes: 40, method: .timer),
            yearlyRecord(month: 9, minutes: 15, method: .stopwatch)
        ]
        let summary = FocusStatisticsService.yearlySummary(for: 2026, from: records, calendar: yearlyCalendar)
        let month = summary.buckets[8]
        let segments = summary.methodBuckets.filter { $0.start == month.start }
        #expect(month.minutes == 130)
        #expect(segments.map(\.focusMethod) == [.pomodoro, .timer, .stopwatch])
        #expect(segments.map(\.minutes) == [75, 40, 15])
        #expect(segments.reduce(0) { $0 + $1.minutes } == month.minutes)
        #expect(segments.allSatisfy {
            YearlyFocusChartPosition.xValue(for: $0.start, calendar: yearlyCalendar) == 9
        })
        #expect(summary.totalMinutes == 130)
        #expect(FocusStatisticsService.yearlyYAxisDomain(for: summary).lowerBound == 0)
        #expect(FocusStatisticsService.yearlyYAxisDomain(for: summary).upperBound > 130)
    }

    @Test func yearIntervalIsHalfOpenAndChangesCorrectlyAcrossNewYear() {
        let records = [
            yearlyRecord(year: 2025, month: 12, day: 31, minutes: 100),
            FocusSessionRecord(completedAt: yearlyDate(2026, 1, 1, hour: 0), durationMinutes: 10),
            yearlyRecord(month: 12, day: 31, minutes: 20),
            FocusSessionRecord(completedAt: yearlyDate(2027, 1, 1, hour: 0), durationMinutes: 30)
        ]
        let current = FocusStatisticsService.yearlySummary(for: 2026, from: records, calendar: yearlyCalendar)
        #expect(current.interval.start == yearlyDate(2026, 1, 1, hour: 0))
        #expect(current.interval.end == yearlyDate(2027, 1, 1, hour: 0))
        #expect(current.buckets[0].minutes == 10)
        #expect(current.buckets[11].minutes == 20)
        #expect(current.totalMinutes == 30)
        let next = FocusStatisticsService.yearlySummary(for: 2027, from: records, calendar: yearlyCalendar)
        #expect(next.totalMinutes == 30)
        #expect(next.buckets[0].minutes == 30)
        #expect(next.buckets.dropFirst().allSatisfy { $0.minutes == 0 })
    }

    @Test(arguments: FocusStatisticsPeriod.currentlySelectable)
    func allPeriodsPreferValidSecondsAndSupportLegacyMinutes(period: FocusStatisticsPeriod) {
        let records = [
            yearlyRecord(month: 9, day: 29, minutes: 99, seconds: 130),
            yearlyRecord(month: 9, day: 29, minutes: 15, method: .timer),
            yearlyRecord(month: 9, day: 29, minutes: 50, seconds: 0)
        ]
        let summary = FocusStatisticsService.summary(
            for: period, containing: yearlyDate(2026, 9, 29),
            from: records, calendar: yearlyCalendar
        )
        #expect(summary.totalMinutes == 17)
        #expect(summary.methodBuckets.reduce(0) { $0 + $1.minutes } == 17)
    }

    @Test func annualTotalEqualsTheSumOfAllTwelveMonthlyBuckets() {
        let records = (1...12).map { yearlyRecord(month: $0, minutes: $0 * 13) }
        let summary = FocusStatisticsService.yearlySummary(for: 2026, from: records, calendar: yearlyCalendar)
        #expect(summary.buckets.map(\.minutes) == (1...12).map { $0 * 13 })
        #expect(summary.totalMinutes == 1014)
        #expect(summary.totalMinutes == summary.buckets.reduce(0) { $0 + $1.minutes })
        #expect(summary.totalMinutes == summary.methodBuckets.reduce(0) { $0 + $1.minutes })
    }

    @Test func secondsAreAccumulatedBeforeConvertingMonthlyBucketsToMinutes() {
        let study = FocusCategory(id: FocusCategoryDefaults.studyID, name: "勉強", color: .studyBlue, isDefault: true)
        let records = [
            yearlyRecord(month: 9, day: 1, minutes: 0, seconds: 30),
            yearlyRecord(month: 9, day: 2, minutes: 0, seconds: 30, method: .timer)
        ]
        let summary = FocusStatisticsService.yearlySummary(for: 2026, from: records, calendar: yearlyCalendar)
        let categories = FocusStatisticsService.categorySummary(for: summary, from: records, categories: [study])
        #expect(summary.buckets[8].minutes == 1)
        #expect(summary.totalMinutes == 1)
        #expect(summary.methodBuckets.reduce(0) { $0 + $1.minutes } == 1)
        #expect(categories.reduce(0) { $0 + $1.minutes } == 1)
        let detail = FocusStatisticsService.bucketDetail(
            for: summary.buckets[8], period: .year, from: records,
            categories: [study], calendar: yearlyCalendar
        )
        #expect(detail.methodSummary.reduce(0) { $0 + $1.minutes } == 1)
        #expect(detail.categorySummary.reduce(0) { $0 + $1.minutes } == 1)
    }

    @Test func januaryAndDecemberCoordinatesSelectTheCorrectBuckets() {
        let summary = FocusStatisticsService.yearlySummary(for: 2026, from: [], calendar: yearlyCalendar)
        for month in [1, 12] {
            let x = YearlyFocusChartPosition.xValue(for: summary.buckets[month - 1].start, calendar: yearlyCalendar)
            #expect(x == Double(month))
            for nearbyX in [x - 0.3, x, x + 0.3] {
                #expect(FocusChartBucketSelection.bucketIndex(for: nearbyX, period: .year, bucketCount: 12) == month - 1)
            }
        }
        #expect(FocusChartBucketSelection.bucketIndex(for: 0.49, period: .year, bucketCount: 12) == nil)
        #expect(FocusChartBucketSelection.bucketIndex(for: 12.51, period: .year, bucketCount: 12) == nil)
    }

    @Test func annualCategoryTotalsAndMonthlyDetailUseTheSameSource() {
        let study = FocusCategory(id: FocusCategoryDefaults.studyID, name: "勉強", color: .studyBlue, isDefault: true)
        let reading = FocusCategory(id: "archived-reading", name: "読書", color: .readingCoral, isDefault: false, isArchived: true)
        let records = [
            yearlyRecord(month: 9, minutes: 90, seconds: 120),
            FocusSessionRecord(completedAt: yearlyDate(2026, 9, 30), durationMinutes: 15,
                               categoryID: reading.id, focusMethod: .timer),
            yearlyRecord(year: 2025, month: 9, minutes: 300)
        ]
        let summary = FocusStatisticsService.yearlySummary(for: 2026, from: records, calendar: yearlyCalendar)
        let categories = FocusStatisticsService.categorySummary(for: summary, from: records, categories: [study, reading])
        #expect(categories.map(\.minutes) == [15, 2])
        #expect(categories.reduce(0) { $0 + $1.minutes } == summary.totalMinutes)
        #expect(categories.first?.category.isArchived == true)
        let detail = FocusStatisticsService.bucketDetail(
            for: summary.buckets[8], period: .year, from: records,
            categories: [study, reading], calendar: yearlyCalendar
        )
        #expect(detail.totalMinutes == 17)
        #expect(detail.methodSummary.map(\.minutes) == [2, 15])
        #expect(detail.sessions.count == 2)
        #expect(detail.sessions.reduce(0) { $0 + $1.durationMinutes } == 17)
        #expect(detail.sessions.first?.startedAt == records[0].completedAt.addingTimeInterval(-120))
        let empty = FocusStatisticsService.bucketDetail(
            for: summary.buckets[0], period: .year, from: records,
            categories: [study, reading], calendar: yearlyCalendar
        )
        #expect(empty.totalMinutes == 0)
        #expect(empty.sessions.isEmpty)
        #expect(empty.sessionDaySections.isEmpty)
        #expect(empty.focusedDayCount == 0)
        #expect(empty.sessionCount == 0)
        #expect(empty.requiresPlus)
    }

    @Test func annualMonthDetailUsesOnlyTheSelectedMonthsHalfOpenInterval() {
        let first = FocusSessionRecord(completedAt: yearlyDate(2026, 9, 1, hour: 0), durationMinutes: 10)
        let last = FocusSessionRecord(
            completedAt: yearlyDate(2026, 10, 1, hour: 0).addingTimeInterval(-1), durationMinutes: 20
        )
        let records = [
            first, last,
            yearlyRecord(month: 8, day: 31, minutes: 100),
            FocusSessionRecord(completedAt: yearlyDate(2026, 10, 1, hour: 0), durationMinutes: 200),
            yearlyRecord(year: 2025, month: 9, minutes: 300),
            yearlyRecord(year: 2027, month: 9, minutes: 400)
        ]
        let summary = FocusStatisticsService.yearlySummary(for: 2026, from: records, calendar: yearlyCalendar)
        let detail = FocusStatisticsService.bucketDetail(
            for: summary.buckets[8], period: .year, from: records, categories: [], calendar: yearlyCalendar
        )
        #expect(detail.bucket.start == yearlyDate(2026, 9, 1, hour: 0))
        #expect(detail.sessions.map(\.id) == [first.id, last.id])
        #expect(detail.totalMinutes == 30)
        #expect(detail.sessionCount == 2)
        #expect(detail.focusedDayCount == 2)
        #expect(detail.requiresPlus)
    }

    @Test func annualMonthSectionsOrderDaysAndSessionsOldestFirst() {
        let early = FocusSessionRecord(completedAt: yearlyDate(2026, 9, 29, hour: 10), durationMinutes: 25)
        let late = FocusSessionRecord(completedAt: yearlyDate(2026, 9, 29, hour: 15), durationMinutes: 45, focusMethod: .timer)
        let previousDay = yearlyRecord(month: 9, day: 28, minutes: 10, method: .stopwatch)
        let zero = yearlyRecord(month: 9, day: 27, minutes: 0)
        let records = [early, zero, late, previousDay]
        let summary = FocusStatisticsService.yearlySummary(for: 2026, from: records, calendar: yearlyCalendar)
        let detail = FocusStatisticsService.bucketDetail(
            for: summary.buckets[8], period: .year, from: records, categories: [], calendar: yearlyCalendar
        )
        #expect(detail.sessionDaySections.map { yearlyCalendar.component(.day, from: $0.day) } == [27, 28, 29])
        #expect(detail.sessionDaySections[0].sessions.map(\.id) == [zero.id])
        #expect(detail.sessionDaySections[1].sessions.map(\.id) == [previousDay.id])
        #expect(detail.sessionDaySections[2].sessions.map(\.id) == [early.id, late.id])
        #expect(detail.sessionDaySections.flatMap(\.sessions).count == detail.sessionCount)
        #expect(detail.focusedDayCount == 2)
        #expect(detail.sessionCount == 4)
        #expect(detail.totalMinutes == 80)
        // 既存の詳細用配列は開始時刻の昇順を維持する。
        #expect(detail.sessions.map(\.id) == [zero.id, previousDay.id, early.id, late.id])
    }

    @Test func annualSessionDetailsPreserveCategoriesMethodsAndValidSeconds() {
        let study = FocusCategory(id: FocusCategoryDefaults.studyID, name: "勉強", color: .studyBlue, isDefault: true)
        let custom = FocusCategory(id: "custom-math", name: "数学", color: .oceanTeal, customHex: "#12B886", isDefault: false)
        let archived = FocusCategory(id: "archived-language", name: "語学", color: .readingCoral, isDefault: false, isArchived: true)
        let precise = yearlyRecord(month: 9, day: 25, minutes: 99, seconds: 130)
        let legacy = FocusSessionRecord(completedAt: yearlyDate(2026, 9, 26), durationMinutes: 15, categoryID: custom.id, focusMethod: .timer)
        let archivedRecord = FocusSessionRecord(completedAt: yearlyDate(2026, 9, 27), durationMinutes: 99,
                                               categoryID: archived.id, focusMethod: .stopwatch, durationSeconds: 180)
        let missingCategory = FocusSessionRecord(completedAt: yearlyDate(2026, 9, 28), durationMinutes: 1, categoryID: "deleted-category")
        let records = [precise, legacy, archivedRecord, missingCategory]
        let summary = FocusStatisticsService.yearlySummary(for: 2026, from: records, calendar: yearlyCalendar)
        let detail = FocusStatisticsService.bucketDetail(
            for: summary.buckets[8], period: .year, from: records,
            categories: [study, custom, archived], calendar: yearlyCalendar
        )
        #expect(detail.sessions.map(\.category.id) == [study.id, custom.id, archived.id, study.id])
        #expect(detail.sessions.map(\.method) == [.pomodoro, .timer, .stopwatch, .pomodoro])
        #expect(detail.sessions.map(\.durationSeconds) == [130, 900, 180, 60])
        #expect(detail.sessions.map(\.durationMinutes) == [2, 15, 3, 1])
        #expect(detail.sessions[0].startedAt == precise.completedAt.addingTimeInterval(-130))
        #expect(detail.sessions[1].category.resolvedCustomHex == "#12B886")
        #expect(detail.sessions[2].category.isArchived)
        #expect(detail.totalMinutes == 21)
        #expect(detail.methodSummary.map(\.minutes) == [3, 15, 3])
        #expect(detail.categorySummary.reduce(0) { $0 + $1.minutes } == detail.totalMinutes)
    }
}

private var yearlyCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
    return calendar
}

private func yearlyDate(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
    yearlyCalendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
}

@MainActor
private func yearlyRecord(year: Int = 2026, month: Int, day: Int = 15, minutes: Int,
                          seconds: Int? = nil, method: FocusMethod = .pomodoro) -> FocusSessionRecord {
    FocusSessionRecord(completedAt: yearlyDate(year, month, day), durationMinutes: minutes,
                       focusMethod: method, durationSeconds: seconds)
}
