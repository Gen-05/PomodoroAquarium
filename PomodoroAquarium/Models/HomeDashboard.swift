import Foundation

enum DailyFishAcquisitionPolicy {
    /// 将来の広告追加枠やAquarium Plusに差し替えられる、無料ユーザー向けの基本表示上限。
    static let basicLimit = 3
    static let maximumLimit = 8
    /// 将来のentitlement接続時も、初期枠の決定をここへ集約する。
    static let plusInitialLimit = maximumLimit

    static func unlockedLimit(from current: Int) -> Int {
        min(min(max(current, basicLimit), maximumLimit) + 1, maximumLimit)
    }

    static func claimableCount(earned: Int, claimed: Int, limit: Int) -> Int {
        let earned = min(max(0, earned), maximumLimit)
        let claimed = max(0, claimed)
        let limit = min(max(0, limit), maximumLimit)
        return min(max(0, earned - claimed), max(0, limit - claimed))
    }
}

enum DailyFishAcquisitionStorageKey {
    static let count = "dailyFishAcquisitionCount"
    static let dayIdentifier = "dailyFishAcquisitionDayIdentifier"
}

enum DailyFishAcquisitionStore {
    static func todayCount(
        storedCount: Int,
        storedDayIdentifier: String,
        on date: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        guard storedDayIdentifier == dayIdentifier(for: date, calendar: calendar) else {
            return 0
        }
        return max(0, storedCount)
    }

    static func resetIfNeeded(
        on date: Date = Date(),
        calendar: Calendar = .current,
        defaults: UserDefaults = .standard
    ) {
        let identifier = dayIdentifier(for: date, calendar: calendar)
        guard defaults.string(forKey: DailyFishAcquisitionStorageKey.dayIdentifier) != identifier else {
            return
        }
        defaults.set(identifier, forKey: DailyFishAcquisitionStorageKey.dayIdentifier)
        defaults.set(0, forKey: DailyFishAcquisitionStorageKey.count)
    }

    /// 魚の抽選・上限判定には関与せず、獲得に成功した事実だけをHome表示用に記録する。
    static func recordAcquisition(
        on date: Date = Date(),
        calendar: Calendar = .current,
        defaults: UserDefaults = .standard
    ) {
        resetIfNeeded(on: date, calendar: calendar, defaults: defaults)
        let currentCount = max(0, defaults.integer(forKey: DailyFishAcquisitionStorageKey.count))
        let (nextCount, overflowed) = currentCount.addingReportingOverflow(1)
        defaults.set(
            overflowed ? Int.max : nextCount,
            forKey: DailyFishAcquisitionStorageKey.count
        )
    }

    static func dayIdentifier(
        for date: Date,
        calendar: Calendar = .current
    ) -> String {
        let components = calendar.dateComponents([.era, .year, .month, .day], from: date)
        return [components.era, components.year, components.month, components.day]
            .map { String($0 ?? 0) }
            .joined(separator: "-")
    }
}

enum HomeDashboardPresentation {
    static func studyDurationText(minutes: Int) -> String {
        let safeMinutes = max(0, minutes)
        let hours = safeMinutes / 60
        let remainingMinutes = safeMinutes % 60

        if hours == 0 {
            return "\(remainingMinutes)分"
        }
        return "\(hours)時間\(remainingMinutes)分"
    }
}
