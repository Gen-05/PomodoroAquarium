import Foundation

enum FocusStatisticsPeriod: String, CaseIterable, Identifiable {
    case day
    case week
    case month
    case year

    var id: Self { self }

    var title: String {
        switch self {
        case .day: "日間"
        case .week: "週間"
        case .month: "月間"
        case .year: "年間"
        }
    }

    /// 年間は将来Plus entitlementを接続した時に追加する。
    static let currentlySelectable: [FocusStatisticsPeriod] = [.day, .week, .month]
}

struct FocusStatisticsBucket: Identifiable, Equatable {
    let start: Date
    let minutes: Int

    var id: Date { start }
}

struct FocusMethodStatisticsBucket: Identifiable, Equatable {
    struct ID: Hashable {
        let start: Date
        let focusMethod: FocusMethod
    }

    let start: Date
    let focusMethod: FocusMethod
    let minutes: Int

    var id: ID { ID(start: start, focusMethod: focusMethod) }
}

struct FocusPeriodSummary: Equatable {
    let period: FocusStatisticsPeriod
    let interval: DateInterval
    let buckets: [FocusStatisticsBucket]
    let methodBuckets: [FocusMethodStatisticsBucket]
    let totalMinutes: Int
}

struct FocusCategorySummary: Identifiable {
    let category: FocusCategory
    let minutes: Int

    var id: String { category.id }

    func percentage(of totalMinutes: Int) -> Int {
        guard totalMinutes > 0 else { return 0 }
        return Int((Double(max(0, minutes)) / Double(totalMinutes) * 100).rounded())
    }
}

struct FocusMethodSummary: Identifiable {
    let method: FocusMethod
    let minutes: Int

    var id: FocusMethod { method }
}

struct FocusSessionDetail: Identifiable {
    let record: FocusSessionRecord
    let category: FocusCategory
    let method: FocusMethod

    var id: UUID { record.id }
    var completedAt: Date { record.completedAt }
    var durationMinutes: Int { record.durationMinutes }
    var startedAt: Date {
        record.completedAt.addingTimeInterval(-TimeInterval(record.durationMinutes) * 60)
    }
}

struct FocusBucketDetail {
    let bucket: FocusStatisticsBucket
    let period: FocusStatisticsPeriod
    let methodSummary: [FocusMethodSummary]
    let categorySummary: [FocusCategorySummary]
    let sessions: [FocusSessionDetail]

    var totalMinutes: Int { bucket.minutes }
}

struct MonthlyFocusDay: Identifiable, Equatable {
    let date: Date
    let dayNumber: Int
    let minutes: Int

    var id: Date { date }
}

struct MonthlyFocusSummary: Equatable {
    let monthStart: Date
    let days: [MonthlyFocusDay]
    let totalMinutes: Int
}

enum FocusStatisticsService {
    private static let displayedFocusMethods: [FocusMethod] = [
        .pomodoro,
        .timer,
        .stopwatch
    ]

    static let dailyAxisHours: [Double] = [0, 6, 12, 18, 23]
    static let dailyAxisDomain: ClosedRange<Double> = -0.5...23.5

    static func monthlyAxisDays(dayCount: Int) -> [Double] {
        guard dayCount > 0 else { return [] }
        return Array(Set([1, 5, 10, 15, 20, 25, dayCount].filter { $0 <= dayCount }))
            .sorted()
            .map(Double.init)
    }

    static func monthlyAxisDomain(dayCount: Int) -> ClosedRange<Double> {
        0.0...(Double(max(1, dayCount)) + 1.0)
    }

    static func summary(
        for period: FocusStatisticsPeriod,
        containing date: Date,
        from records: [FocusSessionRecord],
        calendar: Calendar = .current
    ) -> FocusPeriodSummary {
        switch period {
        case .day:
            dailySummary(containing: date, from: records, calendar: calendar)
        case .week:
            weeklySummary(containing: date, from: records, calendar: calendar)
        case .month:
            genericMonthlySummary(containing: date, from: records, calendar: calendar)
        case .year:
            yearlySummary(containing: date, from: records, calendar: calendar)
        }
    }

    @MainActor
    static func categorySummary(
        for periodSummary: FocusPeriodSummary,
        from records: [FocusSessionRecord],
        categories: [FocusCategory]
    ) -> [FocusCategorySummary] {
        categorySummary(
            in: periodSummary.interval,
            from: records,
            categories: categories
        )
    }

    @MainActor
    static func bucketDetail(
        for bucket: FocusStatisticsBucket,
        period: FocusStatisticsPeriod,
        from records: [FocusSessionRecord],
        categories: [FocusCategory],
        calendar: Calendar = .current
    ) -> FocusBucketDetail {
        let component: Calendar.Component = period == .day ? .hour :
            (period == .year ? .month : .day)
        let end = calendar.date(byAdding: component, value: 1, to: bucket.start)
            ?? bucket.start
        let interval = DateInterval(start: bucket.start, end: end)
        let categoriesByID = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
        let studyCategory = categoriesByID[FocusCategoryDefaults.studyID] ?? FocusCategory(
            id: FocusCategoryDefaults.studyID,
            name: "勉強",
            color: .studyBlue,
            isDefault: true
        )
        let sessions = records
            .filter { $0.completedAt >= interval.start && $0.completedAt < interval.end }
            .map { record in
                let method: FocusMethod = record.focusMethod == .legacy
                    ? .pomodoro
                    : record.focusMethod
                return FocusSessionDetail(
                    record: record,
                    category: categoriesByID[record.resolvedCategoryID] ?? studyCategory,
                    method: method
                )
            }
            .sorted { lhs, rhs in
                if lhs.startedAt != rhs.startedAt { return lhs.startedAt < rhs.startedAt }
                if lhs.completedAt != rhs.completedAt { return lhs.completedAt < rhs.completedAt }
                return lhs.id.uuidString < rhs.id.uuidString
            }

        let methodSummary = displayedFocusMethods.compactMap { method -> FocusMethodSummary? in
            let minutes = sessions.reduce(0) { total, session in
                session.method == method
                    ? safeSum(total, session.durationMinutes)
                    : total
            }
            return minutes > 0 ? FocusMethodSummary(method: method, minutes: minutes) : nil
        }

        return FocusBucketDetail(
            bucket: bucket,
            period: period,
            methodSummary: methodSummary,
            categorySummary: categorySummary(
                in: interval,
                from: records,
                categories: categories
            ),
            sessions: sessions
        )
    }

    @MainActor
    private static func categorySummary(
        in interval: DateInterval,
        from records: [FocusSessionRecord],
        categories: [FocusCategory]
    ) -> [FocusCategorySummary] {
        let categoriesByID = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
        let studyCategory = categoriesByID[FocusCategoryDefaults.studyID] ?? FocusCategory(
            id: FocusCategoryDefaults.studyID,
            name: "勉強",
            color: .studyBlue,
            isDefault: true
        )
        var minutesByCategoryID: [String: Int] = [:]

        for record in records
        where record.completedAt >= interval.start &&
            record.completedAt < interval.end &&
            record.durationMinutes > 0 {
            let categoryID = categoriesByID[record.resolvedCategoryID]?.id
                ?? studyCategory.id
            minutesByCategoryID[categoryID] = safeSum(
                minutesByCategoryID[categoryID] ?? 0,
                record.durationMinutes
            )
        }

        return minutesByCategoryID.map { categoryID, minutes in
            FocusCategorySummary(
                category: categoriesByID[categoryID] ?? studyCategory,
                minutes: minutes
            )
        }
        .sorted { lhs, rhs in
            if lhs.minutes != rhs.minutes { return lhs.minutes > rhs.minutes }
            let nameOrder = lhs.category.name.localizedStandardCompare(rhs.category.name)
            return nameOrder == .orderedSame
                ? lhs.id < rhs.id
                : nameOrder == .orderedAscending
        }
    }

    /// 完了日時の「時」を使い、選択日の成功セッションを24個の時間帯へ集計する。
    static func dailySummary(
        containing date: Date,
        from records: [FocusSessionRecord],
        calendar: Calendar = .current
    ) -> FocusPeriodSummary {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)
            ?? start.addingTimeInterval(86_400)
        var methodMinutes = emptyMethodMinutes(bucketCount: 24)

        for record in records where record.completedAt >= start && record.completedAt < end {
            let hour = calendar.component(.hour, from: record.completedAt)
            add(record, toBucket: hour, in: &methodMinutes)
        }

        let bucketStarts = (0..<24).compactMap { hour in
            calendar.date(byAdding: .hour, value: hour, to: start)
        }
        return makeSummary(
            period: .day,
            start: start,
            end: end,
            bucketStarts: bucketStarts,
            methodMinutes: methodMinutes
        )
    }

    /// Calendarの週境界に従い、現在週を7日の日別合計へ集計する。
    static func weeklySummary(
        containing date: Date,
        from records: [FocusSessionRecord],
        calendar: Calendar = .current
    ) -> FocusPeriodSummary {
        guard let interval = mondayWeekInterval(containing: date, calendar: calendar) else {
            return emptySummary(period: .week, containing: date)
        }
        var methodMinutes = emptyMethodMinutes(bucketCount: 7)

        for record in records where interval.contains(record.completedAt) {
            let recordDay = calendar.startOfDay(for: record.completedAt)
            guard let offset = calendar.dateComponents(
                [.day],
                from: interval.start,
                to: recordDay
            ).day,
                  (0..<7).contains(offset) else {
                continue
            }
            add(record, toBucket: offset, in: &methodMinutes)
        }

        let bucketStarts = (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: interval.start)
        }
        return makeSummary(
            period: .week,
            start: interval.start,
            end: interval.end,
            bucketStarts: bucketStarts,
            methodMinutes: methodMinutes
        )
    }

    /// Step 1との互換を保つ月別日次集計。
    static func monthlySummary(
        containing date: Date,
        from records: [FocusSessionRecord],
        calendar: Calendar = .current
    ) -> MonthlyFocusSummary {
        let summary = genericMonthlySummary(
            containing: date,
            from: records,
            calendar: calendar
        )
        let days = summary.buckets.map {
            MonthlyFocusDay(
                date: $0.start,
                dayNumber: calendar.component(.day, from: $0.start),
                minutes: $0.minutes
            )
        }
        return MonthlyFocusSummary(
            monthStart: summary.interval.start,
            days: days,
            totalMinutes: summary.totalMinutes
        )
    }

    /// 将来のPlus年間表示向けに、指定年を1〜12月の月別合計へ集計する。
    static func yearlySummary(
        containing date: Date,
        from records: [FocusSessionRecord],
        calendar: Calendar = .current
    ) -> FocusPeriodSummary {
        guard let interval = calendar.dateInterval(of: .year, for: date) else {
            return emptySummary(period: .year, containing: date)
        }
        var methodMinutes = emptyMethodMinutes(bucketCount: 12)

        for record in records where interval.contains(record.completedAt) {
            let monthIndex = calendar.component(.month, from: record.completedAt) - 1
            add(record, toBucket: monthIndex, in: &methodMinutes)
        }

        let bucketStarts = (0..<12).compactMap { monthIndex in
            calendar.date(
                byAdding: .month,
                value: monthIndex,
                to: interval.start
            )
        }
        return makeSummary(
            period: .year,
            start: interval.start,
            end: interval.end,
            bucketStarts: bucketStarts,
            methodMinutes: methodMinutes
        )
    }

    /// 今日に記録がなければ昨日を起点にすることで、今日の途中では連続記録を失効させない。
    static func currentStreak(
        at date: Date = Date(),
        from records: [FocusSessionRecord],
        calendar: Calendar = .current
    ) -> Int {
        let successfulDays = Set(records.compactMap { record -> Date? in
            guard record.durationMinutes >= 1 else { return nil }
            return calendar.startOfDay(for: record.completedAt)
        })

        let today = calendar.startOfDay(for: date)
        var cursor: Date
        if successfulDays.contains(today) {
            cursor = today
        } else {
            cursor = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        }

        var streak = 0
        while successfulDays.contains(cursor) {
            let (nextStreak, overflowed) = streak.addingReportingOverflow(1)
            streak = overflowed ? Int.max : nextStreak
            guard !overflowed,
                  let previousDay = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                break
            }
            cursor = previousDay
        }
        return streak
    }

    private static func genericMonthlySummary(
        containing date: Date,
        from records: [FocusSessionRecord],
        calendar: Calendar
    ) -> FocusPeriodSummary {
        guard let interval = calendar.dateInterval(of: .month, for: date),
              let dayRange = calendar.range(of: .day, in: .month, for: interval.start) else {
            return emptySummary(period: .month, containing: date)
        }
        var methodMinutes = emptyMethodMinutes(bucketCount: dayRange.count)

        for record in records where interval.contains(record.completedAt) {
            let dayIndex = calendar.component(.day, from: record.completedAt) - dayRange.lowerBound
            add(record, toBucket: dayIndex, in: &methodMinutes)
        }

        let bucketStarts = methodMinutes.indices.compactMap { dayIndex in
            calendar.date(byAdding: .day, value: dayIndex, to: interval.start)
        }
        return makeSummary(
            period: .month,
            start: interval.start,
            end: interval.end,
            bucketStarts: bucketStarts,
            methodMinutes: methodMinutes
        )
    }

    private static func makeSummary(
        period: FocusStatisticsPeriod,
        start: Date,
        end: Date,
        bucketStarts: [Date],
        methodMinutes: [[Int]]
    ) -> FocusPeriodSummary {
        let buckets = bucketStarts.enumerated().map { index, bucketStart in
            var total = 0
            for minutes in methodMinutes[index] {
                total = safeSum(total, minutes)
            }
            return FocusStatisticsBucket(
                start: bucketStart,
                minutes: total
            )
        }
        let methodBuckets = bucketStarts.enumerated().flatMap { index, bucketStart in
            displayedFocusMethods.enumerated().map { methodIndex, method in
                FocusMethodStatisticsBucket(
                    start: bucketStart,
                    focusMethod: method,
                    minutes: methodMinutes[index][methodIndex]
                )
            }
        }
        return FocusPeriodSummary(
            period: period,
            interval: DateInterval(start: start, end: end),
            buckets: buckets,
            methodBuckets: methodBuckets,
            totalMinutes: buckets.reduce(0) { safeSum($0, $1.minutes) }
        )
    }

    private static func emptySummary(
        period: FocusStatisticsPeriod,
        containing date: Date
    ) -> FocusPeriodSummary {
        FocusPeriodSummary(
            period: period,
            interval: DateInterval(start: date, duration: 0),
            buckets: [],
            methodBuckets: [],
            totalMinutes: 0
        )
    }

    private static func mondayWeekInterval(
        containing date: Date,
        calendar: Calendar
    ) -> DateInterval? {
        let day = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: day)
        let daysSinceMonday = (weekday + 5) % 7
        guard let start = calendar.date(byAdding: .day, value: -daysSinceMonday, to: day),
              let end = calendar.date(byAdding: .day, value: 7, to: start) else {
            return nil
        }
        return DateInterval(start: start, end: end)
    }

    private static func emptyMethodMinutes(bucketCount: Int) -> [[Int]] {
        Array(
            repeating: Array(repeating: 0, count: displayedFocusMethods.count),
            count: bucketCount
        )
    }

    private static func add(
        _ record: FocusSessionRecord,
        toBucket bucketIndex: Int,
        in methodMinutes: inout [[Int]]
    ) {
        let displayedMethod: FocusMethod = record.focusMethod == .legacy
            ? .pomodoro
            : record.focusMethod
        guard methodMinutes.indices.contains(bucketIndex),
              let methodIndex = displayedFocusMethods.firstIndex(of: displayedMethod) else {
            return
        }
        methodMinutes[bucketIndex][methodIndex] = safeSum(
            methodMinutes[bucketIndex][methodIndex],
            record.durationMinutes
        )
    }

    private static func safeSum(_ lhs: Int, _ rhs: Int) -> Int {
        let (sum, overflowed) = lhs.addingReportingOverflow(max(0, rhs))
        return overflowed ? Int.max : sum
    }
}
