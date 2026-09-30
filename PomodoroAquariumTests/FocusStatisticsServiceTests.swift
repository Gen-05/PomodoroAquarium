import Foundation
import Testing
@testable import PomodoroAquarium

struct FocusStatisticsServiceTests {
    @Test func chartSelectionMapsDailyHourToBucket() {
        #expect(FocusChartBucketSelection.bucketIndex(
            for: 13.1,
            period: .day,
            bucketCount: 24
        ) == 13)
    }

    @Test func chartSelectionMapsWeeklyDayOffsetToBucket() {
        #expect(FocusChartBucketSelection.bucketIndex(
            for: 1.2,
            period: .week,
            bucketCount: 7
        ) == 1)
    }

    @Test func chartSelectionMapsMonthlyDayToZeroBasedBucket() {
        #expect(FocusChartBucketSelection.bucketIndex(
            for: 29.0,
            period: .month,
            bucketCount: 30
        ) == 28)
    }

    @Test @MainActor func multipleSessionsOnTheSameDayAreSummed() throws {
        let calendar = statisticsCalendar
        let month = statisticsDate(year: 2026, month: 9, day: 1)
        let records = [
            FocusSessionRecord(
                completedAt: statisticsDate(year: 2026, month: 9, day: 3, hour: 9),
                durationMinutes: 25,
                categoryID: FocusCategoryDefaults.studyID
            ),
            FocusSessionRecord(
                completedAt: statisticsDate(year: 2026, month: 9, day: 3, hour: 18),
                durationMinutes: 50,
                categoryID: FocusCategoryDefaults.readingID
            )
        ]

        let summary = FocusStatisticsService.monthlySummary(
            containing: month,
            from: records,
            calendar: calendar
        )

        #expect(summary.days[2].minutes == 75)
        #expect(summary.totalMinutes == 75)
    }

    @Test @MainActor func sessionsAreSeparatedByCalendarDay() {
        let summary = FocusStatisticsService.monthlySummary(
            containing: statisticsDate(year: 2026, month: 9, day: 1),
            from: [
                FocusSessionRecord(
                    completedAt: statisticsDate(year: 2026, month: 9, day: 1, hour: 23),
                    durationMinutes: 25
                ),
                FocusSessionRecord(
                    completedAt: statisticsDate(year: 2026, month: 9, day: 2, hour: 0),
                    durationMinutes: 40
                )
            ],
            calendar: statisticsCalendar
        )

        #expect(summary.days[0].minutes == 25)
        #expect(summary.days[1].minutes == 40)
    }

    @Test @MainActor func legacySessionWithoutCategoryIsIncludedAndOtherMonthIsExcluded() {
        let summary = FocusStatisticsService.monthlySummary(
            containing: statisticsDate(year: 2026, month: 9, day: 1),
            from: [
                FocusSessionRecord(
                    completedAt: statisticsDate(year: 2026, month: 9, day: 10),
                    durationMinutes: 45,
                    categoryID: nil
                ),
                FocusSessionRecord(
                    completedAt: statisticsDate(year: 2026, month: 8, day: 31),
                    durationMinutes: 90,
                    categoryID: nil
                ),
                FocusSessionRecord(
                    completedAt: statisticsDate(year: 2026, month: 10, day: 1),
                    durationMinutes: 120,
                    categoryID: FocusCategoryDefaults.studyID
                )
            ],
            calendar: statisticsCalendar
        )

        #expect(summary.days[9].minutes == 45)
        #expect(summary.totalMinutes == 45)
    }

    @Test @MainActor func monthDayCountsHandleLeapAndCommonYears() {
        let cases = [
            (2026, 2, 28),
            (2024, 2, 29),
            (2026, 4, 30),
            (2026, 1, 31)
        ]

        for (year, month, expectedDays) in cases {
            let summary = FocusStatisticsService.monthlySummary(
                containing: statisticsDate(year: year, month: month, day: 15),
                from: [],
                calendar: statisticsCalendar
            )

            #expect(summary.days.count == expectedDays)
            #expect(summary.days.first?.dayNumber == 1)
            #expect(summary.days.last?.dayNumber == expectedDays)
        }
    }

    @Test @MainActor func monthlyTotalIncludesAllDaysInRequestedMonth() {
        let summary = FocusStatisticsService.monthlySummary(
            containing: statisticsDate(year: 2026, month: 9, day: 15),
            from: [
                FocusSessionRecord(
                    completedAt: statisticsDate(year: 2026, month: 9, day: 1),
                    durationMinutes: 30
                ),
                FocusSessionRecord(
                    completedAt: statisticsDate(year: 2026, month: 9, day: 15),
                    durationMinutes: 60
                ),
                FocusSessionRecord(
                    completedAt: statisticsDate(year: 2026, month: 9, day: 30),
                    durationMinutes: 90
                )
            ],
            calendar: statisticsCalendar
        )

        #expect(summary.totalMinutes == 180)
    }

    @Test @MainActor func dailySummaryGroupsSuccessfulSessionsByCompletionHour() {
        let summary = FocusStatisticsService.dailySummary(
            containing: statisticsDate(year: 2026, month: 9, day: 29),
            from: [
                FocusSessionRecord(
                    completedAt: statisticsDate(year: 2026, month: 9, day: 29, hour: 9),
                    durationMinutes: 25
                ),
                FocusSessionRecord(
                    completedAt: statisticsDate(year: 2026, month: 9, day: 29, hour: 9),
                    durationMinutes: 15
                ),
                FocusSessionRecord(
                    completedAt: statisticsDate(year: 2026, month: 9, day: 29, hour: 18),
                    durationMinutes: 50
                ),
                FocusSessionRecord(
                    completedAt: statisticsDate(year: 2026, month: 9, day: 28, hour: 23),
                    durationMinutes: 90
                )
            ],
            calendar: statisticsCalendar
        )

        #expect(summary.buckets.count == 24)
        #expect(statisticsCalendar.component(.hour, from: summary.buckets.first!.start) == 0)
        #expect(statisticsCalendar.component(.hour, from: summary.buckets.last!.start) == 23)
        #expect(summary.buckets[9].minutes == 40)
        #expect(summary.buckets[18].minutes == 50)
        #expect(summary.totalMinutes == 90)
        #expect(FocusStatisticsService.dailyAxisHours == [0, 6, 12, 18, 23])
        #expect(FocusStatisticsService.dailyAxisDomain == -0.5...23.5)
    }

    @Test func monthlyAxisUsesTheActualLastDayWithoutDuplicateTicks() {
        #expect(FocusStatisticsService.monthlyAxisDays(dayCount: 28) == [1, 5, 10, 15, 20, 25, 28])
        #expect(FocusStatisticsService.monthlyAxisDays(dayCount: 29) == [1, 5, 10, 15, 20, 25, 29])
        #expect(FocusStatisticsService.monthlyAxisDays(dayCount: 30) == [1, 5, 10, 15, 20, 25, 30])
        #expect(FocusStatisticsService.monthlyAxisDays(dayCount: 31) == [1, 5, 10, 15, 20, 25, 31])
        #expect(Set(FocusStatisticsService.monthlyAxisDays(dayCount: 25)).count
            == FocusStatisticsService.monthlyAxisDays(dayCount: 25).count)
        #expect(FocusStatisticsService.monthlyAxisDomain(dayCount: 28) == 0.0...29.0)
        #expect(FocusStatisticsService.monthlyAxisDomain(dayCount: 29) == 0.0...30.0)
        #expect(FocusStatisticsService.monthlyAxisDomain(dayCount: 30) == 0.0...31.0)
        #expect(FocusStatisticsService.monthlyAxisDomain(dayCount: 31) == 0.0...32.0)
    }

    @Test @MainActor func monthlyChartUsesCalendarDayForEveryStackedMonthEndSegment() {
        let cases = [
            (2026, 2, 28),
            (2024, 2, 29),
            (2026, 9, 30),
            (2026, 7, 31)
        ]

        for (year, month, lastDay) in cases {
            var records: [FocusSessionRecord] = []
            for day in max(1, lastDay - 2)...lastDay {
                for method in [FocusMethod.pomodoro, .timer, .stopwatch] {
                    records.append(FocusSessionRecord(
                        completedAt: statisticsDate(year: year, month: month, day: day),
                        durationMinutes: 10,
                        focusMethod: method
                    ))
                }
            }
            let summary = FocusStatisticsService.summary(
                for: .month,
                containing: statisticsDate(year: year, month: month, day: 15),
                from: records,
                calendar: statisticsCalendar
            )

            #expect(summary.buckets.count == lastDay)
            #expect(FocusStatisticsService.monthlyAxisDays(dayCount: lastDay).last == Double(lastDay))
            for index in 0..<lastDay {
                let day = index + 1
                let bucket = summary.buckets[index]
                let x = MonthlyFocusChartPosition.xValue(
                    for: bucket.start,
                    calendar: statisticsCalendar
                )
                #expect(x == Double(day))

                let segments = summary.methodBuckets.filter { $0.start == bucket.start }
                #expect(segments.count == 3)
                #expect(segments.allSatisfy {
                    MonthlyFocusChartPosition.xValue(
                        for: $0.start,
                        calendar: statisticsCalendar
                    ) == x
                })
                if day >= lastDay - 2 {
                    #expect(bucket.minutes == 30)
                }
            }
            if lastDay >= 29 {
                #expect(MonthlyFocusChartPosition.xValue(
                    for: summary.buckets[28].start,
                    calendar: statisticsCalendar
                ) == 29)
            }
            if lastDay >= 30 {
                #expect(MonthlyFocusChartPosition.xValue(
                    for: summary.buckets[29].start,
                    calendar: statisticsCalendar
                ) == 30)
            }
            if lastDay == 31 {
                #expect(MonthlyFocusChartPosition.xValue(
                    for: summary.buckets[30].start,
                    calendar: statisticsCalendar
                ) == 31)
            }
        }
    }

    @Test func monthlyMonthEndTapSelectsTheMatchingZeroBasedBucket() {
        for lastDay in [28, 29, 30, 31] {
            for day in max(1, lastDay - 2)...lastDay {
                for chartX in [Double(day) - 0.3, Double(day), Double(day) + 0.3] {
                    #expect(FocusChartBucketSelection.bucketIndex(
                        for: chartX,
                        period: .month,
                        bucketCount: lastDay
                    ) == day - 1)
                }
            }
            #expect(FocusChartBucketSelection.bucketIndex(
                for: Double(lastDay) + 0.51,
                period: .month,
                bucketCount: lastDay
            ) == nil)
        }
    }

    @Test @MainActor func monthlyNonzeroDataRemainsInNumericDayBuckets() {
        let summary = FocusStatisticsService.summary(
            for: .month,
            containing: statisticsDate(year: 2026, month: 9, day: 15),
            from: [
                FocusSessionRecord(
                    completedAt: statisticsDate(year: 2026, month: 9, day: 13),
                    durationMinutes: 270
                ),
                FocusSessionRecord(
                    completedAt: statisticsDate(year: 2026, month: 9, day: 14),
                    durationMinutes: 182
                )
            ],
            calendar: statisticsCalendar
        )

        #expect(summary.totalMinutes == 452)
        #expect(summary.buckets[12].minutes == 270)
        #expect(summary.buckets[13].minutes == 182)
        #expect(summary.buckets.filter { $0.minutes > 0 }.count == 2)
    }

    @Test @MainActor func weeklySummaryUsesCalendarWeekAndCombinesEachDay() throws {
        var calendar = statisticsCalendar
        calendar.firstWeekday = 2
        let selectedDate = statisticsDate(year: 2026, month: 9, day: 30)
        let interval = try #require(calendar.dateInterval(of: .weekOfYear, for: selectedDate))
        let secondDay = try #require(calendar.date(byAdding: .day, value: 1, to: interval.start))
        let lastDay = try #require(calendar.date(byAdding: .day, value: 6, to: interval.start))
        let previousDay = try #require(calendar.date(byAdding: .day, value: -1, to: interval.start))

        let summary = FocusStatisticsService.weeklySummary(
            containing: selectedDate,
            from: [
                FocusSessionRecord(completedAt: secondDay, durationMinutes: 25),
                FocusSessionRecord(completedAt: secondDay, durationMinutes: 35),
                FocusSessionRecord(completedAt: lastDay, durationMinutes: 45),
                FocusSessionRecord(completedAt: previousDay, durationMinutes: 120)
            ],
            calendar: calendar
        )

        #expect(summary.buckets.count == 7)
        #expect(summary.buckets[1].minutes == 60)
        #expect(summary.buckets[6].minutes == 45)
        #expect(summary.totalMinutes == 105)
    }

    @Test @MainActor func dailyMethodBucketsStackToTheOriginalTotal() {
        let date = statisticsDate(year: 2026, month: 9, day: 29)
        let summary = FocusStatisticsService.dailySummary(
            containing: date,
            from: [
                FocusSessionRecord(
                    completedAt: statisticsDate(year: 2026, month: 9, day: 29, hour: 9),
                    durationMinutes: 25,
                    focusMethod: .pomodoro
                ),
                FocusSessionRecord(
                    completedAt: statisticsDate(year: 2026, month: 9, day: 29, hour: 9),
                    durationMinutes: 15,
                    focusMethod: .timer
                ),
                FocusSessionRecord(
                    completedAt: statisticsDate(year: 2026, month: 9, day: 29, hour: 9),
                    durationMinutes: 10,
                    focusMethod: .stopwatch
                )
            ],
            calendar: statisticsCalendar
        )

        #expect(summary.buckets[9].minutes == 50)
        #expect(methodMinutes(in: summary, at: summary.buckets[9].start, method: .pomodoro) == 25)
        #expect(methodMinutes(in: summary, at: summary.buckets[9].start, method: .timer) == 15)
        #expect(methodMinutes(in: summary, at: summary.buckets[9].start, method: .stopwatch) == 10)
        #expect(summary.methodBuckets.reduce(0) { $0 + $1.minutes } == summary.totalMinutes)
    }

    @Test @MainActor func weeklyMethodBucketsUseMondayThroughSundayAndExcludeOtherWeeks() throws {
        let selectedDate = statisticsDate(year: 2026, month: 9, day: 30)
        let monday = statisticsDate(year: 2026, month: 9, day: 28)
        let sunday = statisticsDate(year: 2026, month: 10, day: 4)
        let previousSunday = statisticsDate(year: 2026, month: 9, day: 27)
        let summary = FocusStatisticsService.weeklySummary(
            containing: selectedDate,
            from: [
                FocusSessionRecord(completedAt: monday, durationMinutes: 50, focusMethod: .pomodoro),
                FocusSessionRecord(completedAt: monday, durationMinutes: 20, focusMethod: .timer),
                FocusSessionRecord(completedAt: sunday, durationMinutes: 15, focusMethod: .stopwatch),
                FocusSessionRecord(completedAt: previousSunday, durationMinutes: 120, focusMethod: .timer)
            ],
            calendar: statisticsCalendar
        )

        #expect(statisticsCalendar.component(.weekday, from: summary.interval.start) == 2)
        #expect(summary.buckets.count == 7)
        #expect(summary.buckets[0].minutes == 70)
        #expect(summary.buckets[6].minutes == 15)
        #expect(summary.totalMinutes == 85)
        #expect(methodMinutes(in: summary, at: monday, method: .pomodoro) == 50)
        #expect(methodMinutes(in: summary, at: monday, method: .timer) == 20)
        #expect(methodMinutes(in: summary, at: sunday, method: .stopwatch) == 15)
        #expect(summary.methodBuckets.reduce(0) { $0 + $1.minutes } == summary.totalMinutes)
    }

    @Test @MainActor func monthlyMethodBucketsStackToTheOriginalTotalAndRenderLegacyAsPomodoro() {
        let day = statisticsDate(year: 2026, month: 9, day: 13)
        let summary = FocusStatisticsService.summary(
            for: .month,
            containing: day,
            from: [
                FocusSessionRecord(completedAt: day, durationMinutes: 75, focusMethod: .pomodoro),
                FocusSessionRecord(completedAt: day, durationMinutes: 30, focusMethod: .timer),
                FocusSessionRecord(completedAt: day, durationMinutes: 15, focusMethod: .stopwatch),
                FocusSessionRecord(completedAt: day, durationMinutes: 5)
            ],
            calendar: statisticsCalendar
        )

        #expect(summary.buckets[12].minutes == 125)
        #expect(methodMinutes(in: summary, at: day, method: .pomodoro) == 80)
        #expect(methodMinutes(in: summary, at: day, method: .timer) == 30)
        #expect(methodMinutes(in: summary, at: day, method: .stopwatch) == 15)
        #expect(!summary.methodBuckets.contains { $0.focusMethod == .legacy })
        #expect(summary.methodBuckets.reduce(0) { $0 + $1.minutes } == summary.totalMinutes)
    }

    @Test @MainActor func dailyCategorySummaryCombinesSessionsAndMatchesBarTotal() {
        let study = FocusCategory(
            id: FocusCategoryDefaults.studyID,
            name: "勉強",
            color: .studyBlue,
            isDefault: true
        )
        let reading = FocusCategory(
            id: FocusCategoryDefaults.readingID,
            name: "読書",
            color: .readingCoral,
            isDefault: true
        )
        let records = [
            FocusSessionRecord(
                completedAt: statisticsDate(year: 2026, month: 9, day: 30, hour: 9),
                durationMinutes: 50,
                categoryID: study.id
            ),
            FocusSessionRecord(
                completedAt: statisticsDate(year: 2026, month: 9, day: 30, hour: 13),
                durationMinutes: 25,
                categoryID: study.id
            ),
            FocusSessionRecord(
                completedAt: statisticsDate(year: 2026, month: 9, day: 30, hour: 16),
                durationMinutes: 25,
                categoryID: reading.id
            ),
            FocusSessionRecord(
                completedAt: statisticsDate(year: 2026, month: 9, day: 29),
                durationMinutes: 90,
                categoryID: reading.id
            )
        ]
        let summary = FocusStatisticsService.summary(
            for: .day,
            containing: statisticsDate(year: 2026, month: 9, day: 30),
            from: records,
            calendar: statisticsCalendar
        )
        let categories = FocusStatisticsService.categorySummary(
            for: summary,
            from: records,
            categories: [study, reading]
        )

        #expect(categories.map(\.id) == [study.id, reading.id])
        #expect(categories.map(\.minutes) == [75, 25])
        #expect(categories[0].category.colorKey == .studyBlue)
        #expect(categories[1].category.colorKey == .readingCoral)
        #expect(categories.reduce(0) { $0 + $1.minutes } == summary.totalMinutes)
        #expect(categories.map { $0.percentage(of: summary.totalMinutes) } == [75, 25])
    }

    @Test @MainActor func categoryPercentageRoundsAndAvoidsDivisionByZero() {
        let category = FocusCategory(
            id: FocusCategoryDefaults.studyID,
            name: "勉強",
            color: .studyBlue,
            isDefault: true
        )

        #expect(FocusCategorySummary(category: category, minutes: 50).percentage(of: 100) == 50)
        #expect(FocusCategorySummary(category: category, minutes: 546).percentage(of: 1_000) == 55)
        #expect(FocusCategorySummary(category: category, minutes: 0).percentage(of: 0) == 0)
    }

    @Test @MainActor func weeklyCategorySummaryIncludesArchivedCustomColorAndLegacyFallback() {
        let study = FocusCategory(
            id: FocusCategoryDefaults.studyID,
            name: "勉強",
            color: .studyBlue,
            isDefault: true
        )
        let reading = FocusCategory(
            id: FocusCategoryDefaults.readingID,
            name: "読書",
            color: .readingCoral,
            isDefault: true
        )
        let archived = FocusCategory(
            id: "focus-category.custom.qualification",
            name: "資格勉強",
            color: .oceanTeal,
            customHex: "12b886",
            isDefault: false,
            isArchived: true
        )
        let records = [
            FocusSessionRecord(
                completedAt: statisticsDate(year: 2026, month: 9, day: 28),
                durationMinutes: 120,
                categoryID: study.id
            ),
            FocusSessionRecord(
                completedAt: statisticsDate(year: 2026, month: 9, day: 30),
                durationMinutes: 20,
                categoryID: nil
            ),
            FocusSessionRecord(
                completedAt: statisticsDate(year: 2026, month: 9, day: 30),
                durationMinutes: 60,
                categoryID: reading.id
            ),
            FocusSessionRecord(
                completedAt: statisticsDate(year: 2026, month: 10, day: 4),
                durationMinutes: 90,
                categoryID: archived.id
            ),
            FocusSessionRecord(
                completedAt: statisticsDate(year: 2026, month: 10, day: 5),
                durationMinutes: 100,
                categoryID: archived.id
            )
        ]
        let summary = FocusStatisticsService.summary(
            for: .week,
            containing: statisticsDate(year: 2026, month: 9, day: 30),
            from: records,
            calendar: statisticsCalendar
        )
        let categories = FocusStatisticsService.categorySummary(
            for: summary,
            from: records,
            categories: [study, reading, archived]
        )

        #expect(categories.map(\.id) == [study.id, archived.id, reading.id])
        #expect(categories.map(\.minutes) == [140, 90, 60])
        #expect(categories[1].category.isArchived)
        #expect(categories[1].category.name == "資格勉強")
        #expect(categories[1].category.resolvedCustomHex == "#12B886")
        #expect(categories.reduce(0) { $0 + $1.minutes } == summary.totalMinutes)
    }

    @Test @MainActor func monthlyCategorySummaryUsesMonthBoundsAndMatchesBarTotal() {
        let study = FocusCategory(
            id: FocusCategoryDefaults.studyID,
            name: "勉強",
            color: .studyBlue,
            isDefault: true
        )
        let reading = FocusCategory(
            id: FocusCategoryDefaults.readingID,
            name: "読書",
            color: .readingCoral,
            isDefault: true
        )
        let records = [
            FocusSessionRecord(
                completedAt: statisticsDate(year: 2026, month: 9, day: 1),
                durationMinutes: 30,
                categoryID: study.id
            ),
            FocusSessionRecord(
                completedAt: statisticsDate(year: 2026, month: 9, day: 29),
                durationMinutes: 40,
                categoryID: reading.id
            ),
            FocusSessionRecord(
                completedAt: statisticsDate(year: 2026, month: 9, day: 30),
                durationMinutes: 20,
                categoryID: study.id
            ),
            FocusSessionRecord(
                completedAt: statisticsDate(year: 2026, month: 10, day: 1),
                durationMinutes: 100,
                categoryID: reading.id
            )
        ]
        let summary = FocusStatisticsService.summary(
            for: .month,
            containing: statisticsDate(year: 2026, month: 9, day: 15),
            from: records,
            calendar: statisticsCalendar
        )
        let categories = FocusStatisticsService.categorySummary(
            for: summary,
            from: records,
            categories: [study, reading]
        )

        #expect(categories.map(\.minutes) == [50, 40])
        #expect(categories.reduce(0) { $0 + $1.minutes } == summary.totalMinutes)
    }

    @Test @MainActor func zeroMinutePeriodHasNoCategorySlices() {
        let study = FocusCategory(
            id: FocusCategoryDefaults.studyID,
            name: "勉強",
            color: .studyBlue,
            isDefault: true
        )
        let records = [FocusSessionRecord(
            completedAt: statisticsDate(year: 2026, month: 9, day: 30),
            durationMinutes: 0,
            categoryID: study.id
        )]
        let summary = FocusStatisticsService.summary(
            for: .day,
            containing: statisticsDate(year: 2026, month: 9, day: 30),
            from: records,
            calendar: statisticsCalendar
        )

        #expect(FocusStatisticsService.categorySummary(
            for: summary,
            from: records,
            categories: [study]
        ).isEmpty)
        #expect(summary.totalMinutes == 0)
    }

    @Test @MainActor func yearlySummaryGroupsSessionsIntoTwelveMonths() {
        let summary = FocusStatisticsService.yearlySummary(
            containing: statisticsDate(year: 2026, month: 6, day: 1),
            from: [
                FocusSessionRecord(
                    completedAt: statisticsDate(year: 2026, month: 1, day: 10),
                    durationMinutes: 30
                ),
                FocusSessionRecord(
                    completedAt: statisticsDate(year: 2026, month: 1, day: 20),
                    durationMinutes: 45
                ),
                FocusSessionRecord(
                    completedAt: statisticsDate(year: 2026, month: 12, day: 31),
                    durationMinutes: 90
                ),
                FocusSessionRecord(
                    completedAt: statisticsDate(year: 2025, month: 12, day: 31),
                    durationMinutes: 120
                )
            ],
            calendar: statisticsCalendar
        )

        #expect(summary.buckets.count == 12)
        #expect(summary.buckets[0].minutes == 75)
        #expect(summary.buckets[11].minutes == 90)
        #expect(summary.totalMinutes == 165)
    }

    @Test @MainActor func currentStreakCountsTodayAndYesterday() {
        let today = statisticsDate(year: 2026, month: 9, day: 29)
        let records = [
            FocusSessionRecord(completedAt: today, durationMinutes: 25),
            FocusSessionRecord(
                completedAt: statisticsDate(year: 2026, month: 9, day: 28),
                durationMinutes: 25
            )
        ]

        #expect(FocusStatisticsService.currentStreak(
            at: today,
            from: records,
            calendar: statisticsCalendar
        ) == 2)
    }

    @Test @MainActor func currentStreakKeepsYesterdayRunWhenTodayIsStillEmpty() {
        let today = statisticsDate(year: 2026, month: 9, day: 29)
        let records = [
            FocusSessionRecord(
                completedAt: statisticsDate(year: 2026, month: 9, day: 28),
                durationMinutes: 25
            ),
            FocusSessionRecord(
                completedAt: statisticsDate(year: 2026, month: 9, day: 27),
                durationMinutes: 25
            )
        ]

        #expect(FocusStatisticsService.currentStreak(
            at: today,
            from: records,
            calendar: statisticsCalendar
        ) == 2)
    }

    @Test @MainActor func currentStreakIsZeroWhenYesterdayWasEmpty() {
        let today = statisticsDate(year: 2026, month: 9, day: 30)
        let records = [
            FocusSessionRecord(
                completedAt: statisticsDate(year: 2026, month: 9, day: 28),
                durationMinutes: 25
            )
        ]

        #expect(FocusStatisticsService.currentStreak(
            at: today,
            from: records,
            calendar: statisticsCalendar
        ) == 0)
    }

    @Test @MainActor func currentStreakStopsAtFirstBlankDay() {
        let today = statisticsDate(year: 2026, month: 9, day: 29)
        let records = [
            FocusSessionRecord(completedAt: today, durationMinutes: 25),
            FocusSessionRecord(
                completedAt: statisticsDate(year: 2026, month: 9, day: 27),
                durationMinutes: 25
            )
        ]

        #expect(FocusStatisticsService.currentStreak(
            at: today,
            from: records,
            calendar: statisticsCalendar
        ) == 1)
    }

    @Test @MainActor func currentStreakContinuesAcrossMonthBoundary() {
        let today = statisticsDate(year: 2026, month: 10, day: 1)
        let records = [
            FocusSessionRecord(completedAt: today, durationMinutes: 25),
            FocusSessionRecord(
                completedAt: statisticsDate(year: 2026, month: 9, day: 30),
                durationMinutes: 25
            )
        ]

        #expect(FocusStatisticsService.currentStreak(
            at: today,
            from: records,
            calendar: statisticsCalendar
        ) == 2)
    }

    @Test @MainActor func currentStreakContinuesAcrossYearBoundary() {
        let today = statisticsDate(year: 2027, month: 1, day: 1)
        let records = [
            FocusSessionRecord(completedAt: today, durationMinutes: 25),
            FocusSessionRecord(
                completedAt: statisticsDate(year: 2026, month: 12, day: 31),
                durationMinutes: 25
            )
        ]

        #expect(FocusStatisticsService.currentStreak(
            at: today,
            from: records,
            calendar: statisticsCalendar
        ) == 2)
    }

    @Test @MainActor func newSuccessfulDayStartsStreakAtOneAfterGap() {
        let today = statisticsDate(year: 2026, month: 9, day: 29)
        let records = [
            FocusSessionRecord(completedAt: today, durationMinutes: 1),
            FocusSessionRecord(
                completedAt: statisticsDate(year: 2026, month: 9, day: 20),
                durationMinutes: 120
            ),
            FocusSessionRecord(
                completedAt: statisticsDate(year: 2026, month: 9, day: 28),
                durationMinutes: 0
            )
        ]

        #expect(FocusStatisticsService.currentStreak(
            at: today,
            from: records,
            calendar: statisticsCalendar
        ) == 1)
    }

    @Test @MainActor func hourlyBucketDetailMatchesMethodsCategoriesAndSortedSessions() {
        let study = FocusCategory(
            id: FocusCategoryDefaults.studyID,
            name: "勉強",
            color: .studyBlue,
            isDefault: true
        )
        let reading = FocusCategory(
            id: FocusCategoryDefaults.readingID,
            name: "読書",
            color: .readingCoral,
            isDefault: true
        )
        let archived = FocusCategory(
            id: "archived-detail-category",
            name: "資格勉強",
            color: .oceanTeal,
            customHex: "#12B886",
            isDefault: false,
            isArchived: true
        )
        let day = statisticsDate(year: 2026, month: 9, day: 30)
        let early = FocusSessionRecord(
            completedAt: statisticsDate(year: 2026, month: 9, day: 30, hour: 13)
                .addingTimeInterval(5 * 60),
            durationMinutes: 15,
            categoryID: study.id,
            focusMethod: .pomodoro
        )
        let archivedSession = FocusSessionRecord(
            completedAt: statisticsDate(year: 2026, month: 9, day: 30, hour: 13)
                .addingTimeInterval(40 * 60),
            durationMinutes: 10,
            categoryID: archived.id,
            focusMethod: .stopwatch
        )
        let readingSession = FocusSessionRecord(
            completedAt: statisticsDate(year: 2026, month: 9, day: 30, hour: 13)
                .addingTimeInterval(50 * 60),
            durationMinutes: 20,
            categoryID: reading.id,
            focusMethod: .timer
        )
        let legacy = FocusSessionRecord(
            completedAt: statisticsDate(year: 2026, month: 9, day: 30, hour: 13)
                .addingTimeInterval(55 * 60),
            durationMinutes: 5,
            categoryID: nil
        )
        let outsideHour = FocusSessionRecord(
            completedAt: statisticsDate(year: 2026, month: 9, day: 30, hour: 14),
            durationMinutes: 30,
            categoryID: reading.id,
            focusMethod: .timer
        )
        let records = [outsideHour, readingSession, early, legacy, archivedSession]
        let summary = FocusStatisticsService.summary(
            for: .day,
            containing: day,
            from: records,
            calendar: statisticsCalendar
        )
        let bucket = summary.buckets[13]
        let detail = FocusStatisticsService.bucketDetail(
            for: bucket,
            period: .day,
            from: records,
            categories: [study, reading, archived],
            calendar: statisticsCalendar
        )

        #expect(detail.totalMinutes == 50)
        #expect(detail.totalMinutes == bucket.minutes)
        #expect(detail.methodSummary.map(\.method) == [.pomodoro, .timer, .stopwatch])
        #expect(detail.methodSummary.map(\.minutes) == [20, 20, 10])
        #expect(detail.methodSummary.reduce(0) { $0 + $1.minutes } == bucket.minutes)
        #expect(Dictionary(uniqueKeysWithValues: detail.categorySummary.map { ($0.id, $0.minutes) }) == [
            study.id: 20,
            reading.id: 20,
            archived.id: 10
        ])
        #expect(detail.categorySummary.map(\.minutes) == [20, 20, 10])
        #expect(detail.categorySummary.reduce(0) { $0 + $1.minutes } == bucket.minutes)
        #expect(detail.categorySummary.first { $0.id == archived.id }?.category.isArchived == true)
        #expect(detail.categorySummary.first { $0.id == archived.id }?.category.resolvedCustomHex == "#12B886")
        #expect(detail.sessions.map(\.id) == [early.id, archivedSession.id, readingSession.id, legacy.id])
        #expect(detail.sessions.first?.startedAt == early.completedAt.addingTimeInterval(-15 * 60))
        #expect(detail.sessions[0].startedAt < bucket.start)
        #expect(detail.sessions.last?.method == .pomodoro)
        #expect(detail.sessions.reduce(0) { $0 + $1.durationMinutes } == bucket.minutes)
    }

    @Test @MainActor func weeklyAndMonthlyDayDetailsUseTheSameDayRecords() {
        let study = FocusCategory(
            id: FocusCategoryDefaults.studyID,
            name: "勉強",
            color: .studyBlue,
            isDefault: true
        )
        let targetDay = statisticsDate(year: 2026, month: 9, day: 29)
        let first = FocusSessionRecord(
            completedAt: statisticsDate(year: 2026, month: 9, day: 29, hour: 9),
            durationMinutes: 25,
            categoryID: study.id,
            focusMethod: .pomodoro
        )
        let second = FocusSessionRecord(
            completedAt: statisticsDate(year: 2026, month: 9, day: 29, hour: 18),
            durationMinutes: 40,
            categoryID: study.id,
            focusMethod: .timer
        )
        let nextDay = FocusSessionRecord(
            completedAt: statisticsDate(year: 2026, month: 9, day: 30, hour: 10),
            durationMinutes: 60,
            categoryID: study.id
        )
        let records = [nextDay, second, first]

        for period in [FocusStatisticsPeriod.week, .month] {
            let summary = FocusStatisticsService.summary(
                for: period,
                containing: targetDay,
                from: records,
                calendar: statisticsCalendar
            )
            let bucket = summary.buckets.first {
                statisticsCalendar.isDate($0.start, inSameDayAs: targetDay)
            }!
            let detail = FocusStatisticsService.bucketDetail(
                for: bucket,
                period: period,
                from: records,
                categories: [study],
                calendar: statisticsCalendar
            )

            #expect(detail.sessions.map(\.id) == [first.id, second.id])
            #expect(detail.totalMinutes == 65)
            #expect(detail.methodSummary.map(\.minutes) == [25, 40])
            #expect(detail.categorySummary.map(\.minutes) == [65])
            #expect(detail.sessions.reduce(0) { $0 + $1.durationMinutes } == bucket.minutes)
        }
    }

    @Test @MainActor func emptyBucketDetailHasNoBreakdownOrSessions() {
        let bucket = FocusStatisticsBucket(
            start: statisticsDate(year: 2026, month: 9, day: 28, hour: 0),
            minutes: 0
        )
        let detail = FocusStatisticsService.bucketDetail(
            for: bucket,
            period: .month,
            from: [],
            categories: [],
            calendar: statisticsCalendar
        )

        #expect(detail.totalMinutes == 0)
        #expect(detail.methodSummary.isEmpty)
        #expect(detail.categorySummary.isEmpty)
        #expect(detail.sessions.isEmpty)
    }
}

private var statisticsCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
}

private func statisticsDate(
    year: Int,
    month: Int,
    day: Int,
    hour: Int = 12
) -> Date {
    statisticsCalendar.date(from: DateComponents(
        year: year,
        month: month,
        day: day,
        hour: hour
    ))!
}

@MainActor
private func methodMinutes(
    in summary: FocusPeriodSummary,
    at date: Date,
    method: FocusMethod
) -> Int {
    summary.methodBuckets.first {
        statisticsCalendar.isDate($0.start, equalTo: date, toGranularity: summary.period == .day ? .hour : .day)
            && $0.focusMethod == method
    }?.minutes ?? 0
}
