import Foundation
import Testing
@testable import PomodoroAquarium

struct HomeDashboardTests {
    @Test func selectedHomeTabCanResetNavigationOnlyBeforeStudyLock() {
        #expect(MainTabNavigationPolicy.shouldResetHomeNavigation(
            currentTab: .home,
            requestedTab: .home,
            whileStudyLocked: false
        ))
        #expect(!MainTabNavigationPolicy.shouldResetHomeNavigation(
            currentTab: .home,
            requestedTab: .home,
            whileStudyLocked: true
        ))
        #expect(!MainTabNavigationPolicy.shouldResetHomeNavigation(
            currentTab: .shop,
            requestedTab: .home,
            whileStudyLocked: false
        ))
    }

    @Test func basicDailyFishLimitIsIsolatedBehindPolicy() {
        #expect(DailyFishAcquisitionPolicy.basicLimit == 5)
    }

    @Test func dailyFishCountIncrementsAndResetsOnANewDay() throws {
        let suiteName = "HomeDashboardTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let firstDay = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 14)))
        let nextDay = try #require(calendar.date(byAdding: .day, value: 1, to: firstDay))

        DailyFishAcquisitionStore.recordAcquisition(
            on: firstDay,
            calendar: calendar,
            defaults: defaults
        )
        DailyFishAcquisitionStore.recordAcquisition(
            on: firstDay,
            calendar: calendar,
            defaults: defaults
        )
        #expect(defaults.integer(forKey: DailyFishAcquisitionStorageKey.count) == 2)

        DailyFishAcquisitionStore.resetIfNeeded(
            on: nextDay,
            calendar: calendar,
            defaults: defaults
        )
        #expect(defaults.integer(forKey: DailyFishAcquisitionStorageKey.count) == 0)
    }

    @Test func staleDailyFishCountIsNotShownAsTodaysCount() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let today = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 14)))

        #expect(DailyFishAcquisitionStore.todayCount(
            storedCount: 4,
            storedDayIdentifier: "stale-day",
            on: today,
            calendar: calendar
        ) == 0)
    }

    @Test func studyDurationUsesCompactHourAndMinuteText() {
        #expect(HomeDashboardPresentation.studyDurationText(minutes: 0) == "0分")
        #expect(HomeDashboardPresentation.studyDurationText(minutes: 45) == "45分")
        #expect(HomeDashboardPresentation.studyDurationText(minutes: 120) == "2時間0分")
        #expect(HomeDashboardPresentation.studyDurationText(minutes: -1) == "0分")
    }
}
