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

    /// 棒グラフとbucket選択の合計表示は、年間を含めすべて無料。
    var isPlusFeature: Bool { FocusStatisticsFeature.barChart.requiresPlus }

    static let currentlySelectable: [FocusStatisticsPeriod] = [.day, .week, .month, .year]
}

/// 将来のentitlement接続点。現時点では分類のみで、表示をロックしない。
enum FocusStatisticsFeature {
    case barChart
    case categoryChart
    case sessionDetail

    var requiresPlus: Bool {
        switch self {
        case .barChart: false
        case .categoryChart, .sessionDetail: true
        }
    }
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

/// 永続recordには触れず、日間の表示範囲だけを切り出した値。
struct FocusSessionDisplaySlice {
    let startedAt: Date
    let completedAt: Date
    let durationSeconds: Int
    let continuesFromPreviousDay: Bool
    let continuesIntoNextDay: Bool

    var continuationText: String? {
        switch (continuesFromPreviousDay, continuesIntoNextDay) {
        case (true, true): "前日から継続・翌日まで継続"
        case (true, false): "前日から継続"
        case (false, true): "翌日まで継続"
        case (false, false): nil
        }
    }
}

struct FocusSessionDetail: Identifiable {
    let record: FocusSessionRecord
    let category: FocusCategory
    let method: FocusMethod
    let displaySlice: FocusSessionDisplaySlice?

    var id: UUID { record.id }
    var completedAt: Date { displaySlice?.completedAt ?? record.completedAt }
    var durationSeconds: Int { displaySlice?.durationSeconds ?? record.validFocusSeconds }
    var durationMinutes: Int { durationSeconds / 60 }
    var startedAt: Date {
        displaySlice?.startedAt ?? record.sessionStartedAt
            ?? record.completedAt.addingTimeInterval(-TimeInterval(record.validFocusSeconds))
    }
}

struct FocusSessionDaySection: Identifiable {
    let day: Date
    let sessions: [FocusSessionDetail]

    var id: Date { day }
}

struct FocusBucketDetail {
    let bucket: FocusStatisticsBucket
    let period: FocusStatisticsPeriod
    let methodSummary: [FocusMethodSummary]
    let categorySummary: [FocusCategorySummary]
    let sessions: [FocusSessionDetail]
    let sessionDaySections: [FocusSessionDaySection]

    var totalMinutes: Int { bucket.minutes }
    var sessionCount: Int { sessions.count }
    var focusedDayCount: Int {
        sessionDaySections.filter { $0.sessions.contains { $0.durationSeconds > 0 } }.count
    }
    var requiresPlus: Bool { FocusStatisticsFeature.sessionDetail.requiresPlus }
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
    nonisolated private static let displayedFocusMethods: [FocusMethod] = [
        .pomodoro,
        .timer,
        .stopwatch
    ]

    static let dailyAxisHours: [Double] = [0, 6, 12, 18, 23]
    static let dailyAxisDomain: ClosedRange<Double> = -0.5...23.5
    static let yearlyAxisMonths = Array(1...12).map(Double.init)
    static let yearlyAxisDomain: ClosedRange<Double> = 0.5...12.5

    /// セッション行の分表示。期間集計は秒を合算してから分に換算する。
    static func displayMinutes(for record: FocusSessionRecord) -> Int {
        record.validFocusSeconds / 60
    }

    static func yearlyYAxisDomain(for summary: FocusPeriodSummary) -> ClosedRange<Double> {
        let maximum = summary.buckets.map(\.minutes).max() ?? 0
        return 0...(maximum > 0 ? Double(maximum) * 1.15 : 60)
    }

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
            bucketStarts: periodSummary.buckets.map(\.start),
            from: records,
            categories: categories,
            dailyBucketMinutes: periodSummary.period == .day
                ? periodSummary.buckets.map(\.minutes) : nil
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
            .compactMap { record -> FocusSessionDetail? in
                let slice: FocusSessionDisplaySlice?
                if period == .day {
                    guard let visibleSlice = dailyDisplaySlice(for: record, in: interval, calendar: calendar),
                          visibleSlice.durationSeconds > 0 else { return nil }
                    slice = visibleSlice
                } else {
                    guard record.attributionDate >= interval.start && record.attributionDate < interval.end else {
                        return nil
                    }
                    slice = nil
                }
                let method: FocusMethod = record.focusMethod == .legacy
                    ? .pomodoro
                    : record.focusMethod
                return FocusSessionDetail(
                    record: record,
                    category: categoriesByID[record.resolvedCategoryID] ?? studyCategory,
                    method: method,
                    displaySlice: slice
                )
            }
            .sorted { lhs, rhs in
                if lhs.startedAt != rhs.startedAt { return lhs.startedAt < rhs.startedAt }
                if lhs.completedAt != rhs.completedAt { return lhs.completedAt < rhs.completedAt }
                return lhs.id.uuidString < rhs.id.uuidString
            }

        let methodSeconds = displayedFocusMethods.map { method in
            sessions.reduce(0) { total, session in
                session.method == method
                    ? safeSum(total, session.durationSeconds)
                    : total
            }
        }
        let methodMinutes = displayMinutes(
            from: methodSeconds, totalMinutes: period == .day ? bucket.minutes : nil
        )
        let methodSummary = displayedFocusMethods.enumerated().compactMap { index, method -> FocusMethodSummary? in
            let minutes = methodMinutes[index]
            return minutes > 0 ? FocusMethodSummary(method: method, minutes: minutes) : nil
        }

        return FocusBucketDetail(
            bucket: bucket,
            period: period,
            methodSummary: methodSummary,
            categorySummary: categorySummary(
                in: interval,
                bucketStarts: [interval.start],
                from: records,
                categories: categories,
                dailyBucketMinutes: period == .day ? [bucket.minutes] : nil
            ),
            sessions: sessions,
            sessionDaySections: sessionDaySections(
                from: sessions, calendar: calendar, oldestFirst: period == .year
            )
        )
    }

    /// 日間sliceは表示日、その他の詳細はsession開始日基準。年間だけ古い順。
    private static func sessionDaySections(
        from sessions: [FocusSessionDetail],
        calendar: Calendar,
        oldestFirst: Bool
    ) -> [FocusSessionDaySection] {
        let sessionsByDay = Dictionary(grouping: sessions) {
            $0.displaySlice.map { calendar.startOfDay(for: $0.startedAt) }
                ?? $0.record.sessionDay(calendar: calendar)
        }
        return sessionsByDay.keys.sorted(by: { oldestFirst ? $0 < $1 : $0 > $1 }).map { day in
            let sortedSessions = (sessionsByDay[day] ?? []).sorted { lhs, rhs in
                if lhs.startedAt != rhs.startedAt {
                    return oldestFirst ? lhs.startedAt < rhs.startedAt : lhs.startedAt > rhs.startedAt
                }
                if lhs.completedAt != rhs.completedAt {
                    return oldestFirst ? lhs.completedAt < rhs.completedAt : lhs.completedAt > rhs.completedAt
                }
                return lhs.id.uuidString < rhs.id.uuidString
            }
            return FocusSessionDaySection(day: day, sessions: sortedSessions)
        }
    }

    @MainActor
    private static func categorySummary(
        in interval: DateInterval,
        bucketStarts: [Date],
        from records: [FocusSessionRecord],
        categories: [FocusCategory],
        dailyBucketMinutes: [Int]? = nil
    ) -> [FocusCategorySummary] {
        let categoriesByID = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
        let studyCategory = categoriesByID[FocusCategoryDefaults.studyID] ?? FocusCategory(
            id: FocusCategoryDefaults.studyID,
            name: "勉強",
            color: .studyBlue,
            isDefault: true
        )
        var minutesByCategoryID: [String: Int] = [:]

        // 棒と同じbucket境界で秒を合算し、分表示の端数も同じ単位で処理する。
        for (index, start) in bucketStarts.enumerated() {
            let end = index + 1 < bucketStarts.count ? bucketStarts[index + 1] : interval.end
            var secondsByCategoryID: [String: Int] = [:]
            for record in records {
                let seconds: Int
                if dailyBucketMinutes != nil {
                    seconds = dailyVisibleSeconds(for: record, in: DateInterval(start: start, end: end))
                } else {
                    seconds = record.attributionDate >= start && record.attributionDate < end
                        ? record.validFocusSeconds : 0
                }
                guard seconds > 0 else { continue }
                let categoryID = categoriesByID[record.resolvedCategoryID]?.id ?? studyCategory.id
                secondsByCategoryID[categoryID] = safeSum(
                    secondsByCategoryID[categoryID] ?? 0,
                    seconds
                )
            }
            let categoryIDs = secondsByCategoryID.keys.sorted()
            let minutes = displayMinutes(
                from: categoryIDs.map { secondsByCategoryID[$0] ?? 0 },
                totalMinutes: dailyBucketMinutes?[index]
            )
            for (categoryIndex, categoryID) in categoryIDs.enumerated() where minutes[categoryIndex] > 0 {
                minutesByCategoryID[categoryID] = safeSum(
                    minutesByCategoryID[categoryID] ?? 0,
                    minutes[categoryIndex]
                )
            }
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

    /// 日間だけはカレンダー日の各時間帯との重なりを表示する。recordは変更しない。
    static func dailySummary(
        containing date: Date,
        from records: [FocusSessionRecord],
        calendar: Calendar = .current
    ) -> FocusPeriodSummary {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)
            ?? start.addingTimeInterval(86_400)
        var methodSeconds = emptyMethodSeconds(bucketCount: 24)

        let bucketStarts = (0..<24).compactMap { hour in
            calendar.date(byAdding: .hour, value: hour, to: start)
        }
        for (hour, bucketStart) in bucketStarts.enumerated() {
            let bucketEnd = min(end, calendar.date(byAdding: .hour, value: 1, to: bucketStart) ?? end)
            let interval = DateInterval(start: bucketStart, end: bucketEnd)
            for record in records {
                let seconds = dailyVisibleSeconds(for: record, in: interval)
                guard seconds > 0 else { continue }
                add(record, toBucket: hour, in: &methodSeconds, seconds: seconds)
            }
        }
        return makeSummary(
            period: .day,
            start: start,
            end: end,
            bucketStarts: bucketStarts,
            methodSeconds: methodSeconds,
            roundAcrossBuckets: true
        )
    }

    /// 日間の棒・詳細・カテゴリ・上部カードに共通の表示用intersection。
    /// pause区間は保存されていないため、壁時計より短い有効秒数は区間へ比例配分する。
    /// 累積値の差を取ることで、時間帯ごとの丸めによる秒の欠落を防ぐ。
    private static func dailyVisibleSeconds(
        for record: FocusSessionRecord,
        in interval: DateInterval
    ) -> Int {
        dailyDisplaySlice(for: record, in: interval)?.durationSeconds ?? 0
    }

    static func dailyDisplaySlice(
        for record: FocusSessionRecord,
        in interval: DateInterval,
        calendar: Calendar = .current
    ) -> FocusSessionDisplaySlice? {
        guard record.validFocusSeconds > 0 else { return nil }
        guard let sessionStart = record.sessionStartedAt else {
            // 開始日時がない旧recordの所属時間帯は、既存のcompletion基準を維持する。
            guard record.completedAt >= interval.start && record.completedAt < interval.end else { return nil }
            return FocusSessionDisplaySlice(
                startedAt: record.completedAt.addingTimeInterval(-TimeInterval(record.validFocusSeconds)),
                completedAt: record.completedAt,
                durationSeconds: record.validFocusSeconds,
                continuesFromPreviousDay: false,
                continuesIntoNextDay: false
            )
        }
        let sessionEnd = record.completedAt
        let visibleStart = max(sessionStart, interval.start)
        let visibleEnd = min(sessionEnd, interval.end)
        guard visibleEnd > visibleStart else { return nil }
        let wallSeconds = sessionEnd.timeIntervalSince(sessionStart)
        let validSeconds = min(Double(record.validFocusSeconds), wallSeconds)
        // 微小な浮動小数誤差で、ちょうど分/時境界の1秒が落ちないようにする。
        let before = floor(validSeconds * visibleStart.timeIntervalSince(sessionStart) / wallSeconds + 0.0000001)
        let through = floor(validSeconds * visibleEnd.timeIntervalSince(sessionStart) / wallSeconds + 0.0000001)
        let dayStart = calendar.startOfDay(for: interval.start)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)
            ?? dayStart.addingTimeInterval(86_400)
        return FocusSessionDisplaySlice(
            startedAt: visibleStart,
            completedAt: visibleEnd,
            durationSeconds: Int(max(0, through - before)),
            continuesFromPreviousDay: sessionStart < dayStart,
            continuesIntoNextDay: sessionEnd > dayEnd
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
        var methodSeconds = emptyMethodSeconds(bucketCount: 7)

        for record in records where record.attributionDate >= interval.start && record.attributionDate < interval.end {
            let recordDay = record.sessionDay(calendar: calendar)
            guard let offset = calendar.dateComponents(
                [.day],
                from: interval.start,
                to: recordDay
            ).day,
                  (0..<7).contains(offset) else {
                continue
            }
            add(record, toBucket: offset, in: &methodSeconds)
        }

        let bucketStarts = (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: interval.start)
        }
        return makeSummary(
            period: .week,
            start: interval.start,
            end: interval.end,
            bucketStarts: bucketStarts,
            methodSeconds: methodSeconds
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

    /// 指定年を1〜12月の月別合計へ集計する。UIは現在年、serviceは任意年に対応。
    static func yearlySummary(
        for year: Int,
        from records: [FocusSessionRecord],
        calendar: Calendar = .current
    ) -> FocusPeriodSummary {
        guard let date = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) else {
            return emptySummary(period: .year, containing: Date())
        }
        return yearlySummary(containing: date, from: records, calendar: calendar)
    }

    static func yearlySummary(
        containing date: Date,
        from records: [FocusSessionRecord],
        calendar: Calendar = .current
    ) -> FocusPeriodSummary {
        guard let interval = calendar.dateInterval(of: .year, for: date) else {
            return emptySummary(period: .year, containing: date)
        }
        var methodSeconds = emptyMethodSeconds(bucketCount: 12)

        for record in records where record.attributionDate >= interval.start && record.attributionDate < interval.end {
            let monthIndex = calendar.component(.month, from: record.attributionDate) - 1
            add(record, toBucket: monthIndex, in: &methodSeconds)
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
            methodSeconds: methodSeconds
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
            return record.sessionDay(calendar: calendar)
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
        var methodSeconds = emptyMethodSeconds(bucketCount: dayRange.count)

        for record in records where record.attributionDate >= interval.start && record.attributionDate < interval.end {
            let dayIndex = calendar.component(.day, from: record.attributionDate) - dayRange.lowerBound
            add(record, toBucket: dayIndex, in: &methodSeconds)
        }

        let bucketStarts = methodSeconds.indices.compactMap { dayIndex in
            calendar.date(byAdding: .day, value: dayIndex, to: interval.start)
        }
        return makeSummary(
            period: .month,
            start: interval.start,
            end: interval.end,
            bucketStarts: bucketStarts,
            methodSeconds: methodSeconds
        )
    }

    private static func makeSummary(
        period: FocusStatisticsPeriod,
        start: Date,
        end: Date,
        bucketStarts: [Date],
        methodSeconds: [[Int]],
        roundAcrossBuckets: Bool = false
    ) -> FocusPeriodSummary {
        let bucketMinutes = roundAcrossBuckets
            ? displayMinutes(from: methodSeconds.map { $0.reduce(0, safeSum) }) : nil
        let methodMinutes = methodSeconds.enumerated().map { index, seconds in
            displayMinutes(from: seconds, totalMinutes: bucketMinutes?[index])
        }
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

    nonisolated private static func mondayWeekInterval(
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

    nonisolated private static func emptyMethodSeconds(bucketCount: Int) -> [[Int]] {
        Array(
            repeating: Array(repeating: 0, count: displayedFocusMethods.count),
            count: bucketCount
        )
    }

    private static func add(
        _ record: FocusSessionRecord,
        toBucket bucketIndex: Int,
        in methodSeconds: inout [[Int]],
        seconds: Int? = nil
    ) {
        let displayedMethod: FocusMethod = record.focusMethod == .legacy
            ? .pomodoro
            : record.focusMethod
        guard methodSeconds.indices.contains(bucketIndex),
              let methodIndex = displayedFocusMethods.firstIndex(of: displayedMethod) else {
            return
        }
        methodSeconds[bucketIndex][methodIndex] = safeSum(
            methodSeconds[bucketIndex][methodIndex],
            seconds ?? record.validFocusSeconds
        )
    }

    /// bucket全体の切り捨て分数を維持しつつ、内訳へ最大剰余順で配分する。
    /// 秒の端数をsessionごとに失わず、棒・mode・カテゴリの表示合計を一致させる。
    nonisolated private static func displayMinutes(from seconds: [Int], totalMinutes: Int? = nil) -> [Int] {
        let nonnegativeSeconds = seconds.map { max(0, $0) }
        var minutes = nonnegativeSeconds.map { $0 / 60 }
        let remainingMinutes = totalMinutes.map { max(0, $0 - minutes.reduce(0, safeSum)) }
            ?? (nonnegativeSeconds.reduce(0) { safeSum($0, $1 % 60) } / 60)
        let remainderOrder = nonnegativeSeconds.indices.sorted { lhs, rhs in
            let lhsRemainder = nonnegativeSeconds[lhs] % 60
            let rhsRemainder = nonnegativeSeconds[rhs] % 60
            return lhsRemainder == rhsRemainder ? lhs < rhs : lhsRemainder > rhsRemainder
        }
        for index in remainderOrder.prefix(remainingMinutes) {
            minutes[index] = safeSum(minutes[index], 1)
        }
        return minutes
    }

    nonisolated private static func safeSum(_ lhs: Int, _ rhs: Int) -> Int {
        let (sum, overflowed) = lhs.addingReportingOverflow(max(0, rhs))
        return overflowed ? Int.max : sum
    }
}
