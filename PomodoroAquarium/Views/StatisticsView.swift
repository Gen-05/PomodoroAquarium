import Charts
import SwiftData
import SwiftUI

private struct NumericFocusChartPoint: Identifiable {
    struct ID: Hashable {
        let x: Double
        let focusMethod: FocusMethod
    }

    let x: Double
    let minutes: Int
    let bucketStart: Date
    let focusMethod: FocusMethod

    var id: ID { ID(x: x, focusMethod: focusMethod) }
}

enum FocusChartBucketSelection {
    static func bucketIndex(
        for chartX: Double,
        period: FocusStatisticsPeriod,
        bucketCount: Int
    ) -> Int? {
        guard chartX.isFinite, bucketCount > 0 else { return nil }

        let roundedValue = Int(chartX.rounded())
        let index = switch period {
        case .day, .week:
            roundedValue
        case .month, .year:
            roundedValue - 1
        }
        return (0..<bucketCount).contains(index) ? index : nil
    }
}

enum MonthlyFocusChartPosition {
    static func xValue(for bucketStart: Date, calendar: Calendar = .current) -> Double {
        Double(calendar.component(.day, from: bucketStart))
    }
}

struct StatisticsView: View {
    let player: Player?

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \StudyDailyRecord.day) private var dailyRecords: [StudyDailyRecord]
    @Query(sort: \FocusCategory.name) private var focusCategories: [FocusCategory]
    @Query(sort: \FocusSessionRecord.completedAt) private var focusSessionRecords: [FocusSessionRecord]
    @State private var selectedPeriod: FocusStatisticsPeriod = .month
    @State private var selectedBucket: FocusStatisticsBucket?
    @State private var presentedDetailBucket: FocusStatisticsBucket?

    private var todayMinutes: Int {
        let historyMinutes = StudyHistoryService.minutes(on: Date(), from: dailyRecords)
        return dailyRecords.contains { Calendar.current.isDateInToday($0.day) }
            ? historyMinutes
            : max(0, player?.todayStudyMinutes ?? 0)
    }

    private var yesterdayMinutes: Int {
        guard let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) else {
            return 0
        }
        let historyMinutes = StudyHistoryService.minutes(on: yesterday, from: dailyRecords)
        return dailyRecords.contains { Calendar.current.isDate($0.day, inSameDayAs: yesterday) }
            ? historyMinutes
            : max(0, player?.yesterdayStudyMinutes ?? 0)
    }

    private var currentStreak: Int {
        FocusStatisticsService.currentStreak(from: focusSessionRecords)
    }

    private var selectedSummary: FocusPeriodSummary {
#if DEBUG
        let referenceDate = selectedPeriod == .month ? monthEndUITestDate ?? Date() : Date()
#else
        let referenceDate = Date()
#endif
        return FocusStatisticsService.summary(
            for: selectedPeriod,
            containing: referenceDate,
            from: focusSessionRecords
        )
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: 18) {
                summaryCards

                VStack(alignment: .leading, spacing: 14) {
                    Picker("表示期間", selection: $selectedPeriod) {
                        ForEach(FocusStatisticsPeriod.currentlySelectable) { period in
                            Text(period.title).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("statistics.periodPicker")

                    Text(periodTitle(for: selectedSummary))
                        .font(.headline)

                    HStack(alignment: .top, spacing: 16) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(summaryLabel)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(durationText(selectedSummary.totalMinutes))
                                .font(.title2.bold())
                                .monospacedDigit()
                        }

                        Spacer(minLength: 8)
                        focusMethodLegend
                    }

                    selectedBucketDisplay
                    focusChart
                }
                .padding(14)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))

                categoryChartSection

                Color.clear
                    .frame(height: 1)
                    .accessibilityElement()
                    .accessibilityIdentifier("statistics.scrollEnd")
            }
            .padding(.horizontal)
            .padding(.top)
            .padding(.bottom, 80)
        }
        .background(Color.cyan.opacity(0.08).ignoresSafeArea())
        .navigationTitle("統計")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedPeriod) { _, _ in
            selectedBucket = nil
            presentedDetailBucket = nil
        }
        .sheet(item: $presentedDetailBucket) { bucket in
            StatisticsDetailView(detail: FocusStatisticsService.bucketDetail(
                for: bucket,
                period: selectedPeriod,
                from: focusSessionRecords,
                categories: focusCategories
            ))
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
#if DEBUG
        .task {
            seedTapUITestDataIfNeeded()
            seedMonthEndUITestDataIfNeeded()
        }
#endif
    }

    private var summaryCards: some View {
        HStack(spacing: 12) {
            VStack(spacing: 10) {
                compactSummaryCard(
                    title: "今日",
                    value: durationText(todayMinutes),
                    icon: "sun.max.fill"
                )
                compactSummaryCard(
                    title: "昨日",
                    value: durationText(yesterdayMinutes),
                    icon: "clock.arrow.circlepath"
                )
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 10) {
                Image(systemName: "flame.fill")
                    .font(.title2)
                    .foregroundStyle(.cyan)
                Text("連続")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(currentStreak)日")
                    .font(.title2.bold())
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
            .accessibilityElement(children: .combine)
        }
        .frame(height: 154)
    }

    @ViewBuilder
    private var focusChart: some View {
        switch selectedPeriod {
        case .day:
            chartChrome(dailyChart)
        case .week:
            chartChrome(weeklyChart)
        case .month:
            chartChrome(monthlyChart)
        case .year:
            chartChrome(yearlyChart)
        }
    }

    private var categoryChartSection: some View {
        let summary = selectedSummary
        let categories = FocusStatisticsService.categorySummary(
            for: summary,
            from: focusSessionRecords,
            categories: focusCategories
        )

        return VStack(alignment: .leading, spacing: 16) {
            Text("カテゴリ別")
                .font(.headline)

            if categories.isEmpty {
                Text("この期間の記録はまだありません")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 140)
            } else {
                ZStack {
                    Chart(categories) { item in
                        SectorMark(
                            angle: .value("集中時間（分）", item.minutes),
                            innerRadius: .ratio(0.62),
                            angularInset: 2
                        )
                        .foregroundStyle(item.category.swiftUIColor)
                    }
                    .chartLegend(.hidden)
                    .frame(width: 200, height: 200)

                    VStack(spacing: 3) {
                        Text("合計")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(durationText(summary.totalMinutes))
                            .font(.subheadline.bold())
                            .minimumScaleFactor(0.8)
                            .lineLimit(1)
                    }
                    .frame(width: 116)
                }
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("statistics.categoryDonutChart")

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(categories) { item in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(item.category.swiftUIColor)
                                .frame(width: 10, height: 10)
                            Text(item.category.name)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 8)
                            Text("\(item.percentage(of: summary.totalMinutes))%")
                                .monospacedDigit()
                                .fixedSize(horizontal: true, vertical: false)
                        }
                    }
                }
                .accessibilityIdentifier("statistics.categoryLegend")
            }
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .accessibilityIdentifier("statistics.categorySection")
    }

    private var dailyChart: some View {
        let points = selectedSummary.methodBuckets.map {
            NumericFocusChartPoint(
                x: Double(Calendar.current.component(.hour, from: $0.start)),
                minutes: $0.minutes,
                bucketStart: $0.start,
                focusMethod: $0.focusMethod
            )
        }

        return Chart(points) { point in
            BarMark(
                x: .value("時", point.x),
                y: .value("集中時間（分）", point.minutes),
                stacking: .standard
            )
            .foregroundStyle(focusMethodColor(point.focusMethod))
            .opacity(barOpacity(for: point.bucketStart))
            .cornerRadius(3)
        }
        .chartXScale(domain: FocusStatisticsService.dailyAxisDomain)
        .chartXAxis {
            AxisMarks(values: FocusStatisticsService.dailyAxisHours) { value in
                AxisTick()
                if let hour = value.as(Double.self) {
                    AxisValueLabel(
                        anchor: endpointLabelAnchor(value: hour, first: 0, last: 23),
                        collisionResolution: .disabled
                    ) {
                        Text("\(Int(hour))")
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }
            }
        }
    }

    private var weeklyChart: some View {
        let calendar = Calendar.current
        let points = selectedSummary.methodBuckets.compactMap { bucket -> NumericFocusChartPoint? in
            guard let dayOffset = calendar.dateComponents(
                [.day],
                from: selectedSummary.interval.start,
                to: bucket.start
            ).day else {
                return nil
            }
            return NumericFocusChartPoint(
                x: Double(dayOffset),
                minutes: bucket.minutes,
                bucketStart: bucket.start,
                focusMethod: bucket.focusMethod
            )
        }
        let weekdayLabels = ["月", "火", "水", "木", "金", "土", "日"]

        return Chart(points) { point in
            BarMark(
                x: .value("曜日", point.x),
                y: .value("集中時間（分）", point.minutes),
                width: .fixed(18),
                stacking: .standard
            )
            .foregroundStyle(focusMethodColor(point.focusMethod))
            .opacity(barOpacity(for: point.bucketStart))
            .cornerRadius(3)
        }
        .chartXScale(domain: -0.5...6.5)
        .chartXAxis {
            AxisMarks(values: Array(0...6).map(Double.init)) { value in
                AxisTick()
                if let day = value.as(Double.self),
                   weekdayLabels.indices.contains(Int(day)) {
                    AxisValueLabel(
                        anchor: endpointLabelAnchor(value: day, first: 0, last: 6),
                        collisionResolution: .disabled
                    ) {
                        Text(weekdayLabels[Int(day)])
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }
            }
        }
    }

    private var monthlyChart: some View {
        let points = selectedSummary.methodBuckets.map {
            NumericFocusChartPoint(
                x: MonthlyFocusChartPosition.xValue(for: $0.start),
                minutes: $0.minutes,
                bucketStart: $0.start,
                focusMethod: $0.focusMethod
            )
        }
        let lastDay = selectedSummary.buckets.count

        return Chart(points) { point in
            BarMark(
                x: .value("日", point.x),
                y: .value("集中時間（分）", point.minutes),
                width: .fixed(6),
                stacking: .standard
            )
            .foregroundStyle(focusMethodColor(point.focusMethod))
            .opacity(barOpacity(for: point.bucketStart))
            .cornerRadius(3)
        }
        .chartXScale(domain: FocusStatisticsService.monthlyAxisDomain(dayCount: lastDay))
        .chartXAxis {
            AxisMarks(values: FocusStatisticsService.monthlyAxisDays(dayCount: lastDay)) { value in
                AxisTick()
                if let day = value.as(Double.self) {
                    AxisValueLabel(
                        anchor: .top,
                        collisionResolution: .disabled
                    ) {
                        Text("\(Int(day))")
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }
            }
        }
    }

    private var yearlyChart: some View {
        let points = selectedSummary.methodBuckets.map {
            NumericFocusChartPoint(
                x: Double(Calendar.current.component(.month, from: $0.start)),
                minutes: $0.minutes,
                bucketStart: $0.start,
                focusMethod: $0.focusMethod
            )
        }

        return Chart(points) { point in
            BarMark(
                x: .value("月", point.x),
                y: .value("集中時間（分）", point.minutes),
                stacking: .standard
            )
            .foregroundStyle(focusMethodColor(point.focusMethod))
            .opacity(barOpacity(for: point.bucketStart))
            .cornerRadius(3)
        }
        .chartXScale(domain: 0.0...13.0)
        .chartXAxis {
            AxisMarks(values: Array(1...12).map(Double.init)) { value in
                AxisTick()
                AxisValueLabel {
                    if let month = value.as(Double.self) {
                        Text("\(Int(month))月")
                    }
                }
            }
        }
    }

    private func chartChrome<Content: View>(_ content: Content) -> some View {
        content
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                    .foregroundStyle(.white.opacity(0.12))
                AxisValueLabel {
                    if let minutes = value.as(Int.self) {
                        Text(axisDurationText(minutes))
                    } else if let minutes = value.as(Double.self) {
                        Text(axisDurationText(Int(minutes.rounded())))
                    }
                }
            }
        }
        .chartPlotStyle { plotArea in
            plotArea
                .background(.white.opacity(0.035))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(Color.white.opacity(0.001))
                    .contentShape(Rectangle())
                    .onTapGesture(coordinateSpace: .local) { location in
                        selectBucket(
                            at: location,
                            proxy: proxy,
                            geometry: geometry
                        )
                    }
            }
        }
        .frame(height: 260)
        .accessibilityIdentifier("focusPeriodBarChart")
    }

    private var selectedBucketDisplay: some View {
        HStack {
            if let selectedBucket {
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedBucketTitle(selectedBucket))
                        .font(.subheadline.weight(.semibold))
                    Text(durationText(selectedBucket.minutes))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.cyan.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                    "\(selectedBucketTitle(selectedBucket)), \(durationText(selectedBucket.minutes))"
                )
                .accessibilityIdentifier("statistics.selectedBucket")
                Spacer(minLength: 8)
                detailEntryButton(for: selectedBucket)
            }
        }
        .frame(height: 48, alignment: .leading)
    }

    private func detailEntryButton(for bucket: FocusStatisticsBucket) -> some View {
        Button("詳細を見る") {
            presentedDetailBucket = bucket
        }
        .buttonStyle(.bordered)
        .tint(.cyan)
        .accessibilityIdentifier("statistics.detailButton")
    }

    private func selectBucket(
        at location: CGPoint,
        proxy: ChartProxy,
        geometry: GeometryProxy
    ) {
        guard let plotFrame = proxy.plotFrame else {
            selectedBucket = nil
            return
        }

        let plotRect = geometry[plotFrame]
        guard plotRect.contains(location) else {
            selectedBucket = nil
            return
        }

        let plotX = location.x - plotRect.minX
        guard let chartX: Double = proxy.value(atX: plotX),
              let bucketIndex = FocusChartBucketSelection.bucketIndex(
                for: chartX,
                period: selectedPeriod,
                bucketCount: selectedSummary.buckets.count
              ) else {
            selectedBucket = nil
            return
        }

        let bucket = selectedSummary.buckets[bucketIndex]
        guard bucket.minutes > 0 else {
            selectedBucket = nil
            return
        }
        selectedBucket = bucket
    }

    private func endpointLabelAnchor(value: Double, first: Double, last: Double) -> UnitPoint {
        if value == first {
            return .topLeading
        }
        if value == last {
            return .topTrailing
        }
        return .top
    }

    private var focusMethodLegend: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach([FocusMethod.pomodoro, .timer, .stopwatch]) { method in
                HStack(spacing: 5) {
                    Circle()
                        .fill(focusMethodColor(method))
                        .frame(width: 8, height: 8)
                    Text(method.displayName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityIdentifier("statistics.focusMethodLegend")
    }

    private var summaryLabel: String {
        switch selectedPeriod {
        case .day: "今日の集中時間"
        case .week: "今週の集中時間"
        case .month: "今月の集中時間"
        case .year: "今年の集中時間"
        }
    }

    private func periodTitle(for summary: FocusPeriodSummary) -> String {
        switch summary.period {
        case .day:
            return formatted(summary.interval.start, pattern: "yyyy年M月d日")
        case .week:
            let lastDay = Calendar.current.date(
                byAdding: .day,
                value: -1,
                to: summary.interval.end
            ) ?? summary.interval.end
            let startYear = Calendar.current.component(.year, from: summary.interval.start)
            let endYear = Calendar.current.component(.year, from: lastDay)
            if startYear == endYear {
                return "\(formatted(summary.interval.start, pattern: "M月d日"))〜\(formatted(lastDay, pattern: "M月d日"))"
            }
            return "\(formatted(summary.interval.start, pattern: "yyyy年M月d日"))〜\(formatted(lastDay, pattern: "yyyy年M月d日"))"
        case .month:
            return formatted(summary.interval.start, pattern: "yyyy年M月")
        case .year:
            return formatted(summary.interval.start, pattern: "yyyy年")
        }
    }

    private func focusMethodColor(_ method: FocusMethod) -> Color {
        switch method {
        case .pomodoro: .cyan
        case .timer: .orange
        case .stopwatch: .purple
        case .legacy: .cyan
        }
    }

    private func barOpacity(for bucketStart: Date) -> Double {
        let baseOpacity = bucketStart > Date() ? 0.25 : 0.9
        guard let selectedBucket else { return baseOpacity }
        return selectedBucket.start == bucketStart ? 1 : baseOpacity * 0.45
    }

    private func selectedBucketTitle(_ bucket: FocusStatisticsBucket) -> String {
        switch selectedPeriod {
        case .day:
            return "\(Calendar.current.component(.hour, from: bucket.start))時台"
        case .week:
            return formatted(bucket.start, pattern: "EEEE M/d")
        case .month:
            return formatted(bucket.start, pattern: "M月d日")
        case .year:
            return formatted(bucket.start, pattern: "M月")
        }
    }

    private func durationText(_ minutes: Int) -> String {
        let safeMinutes = max(0, minutes)
        let hours = safeMinutes / 60
        let remainingMinutes = safeMinutes % 60
        if hours == 0 {
            return "\(remainingMinutes)分"
        }
        if remainingMinutes == 0 {
            return "\(hours)時間"
        }
        return "\(hours)時間\(remainingMinutes)分"
    }

    private func axisDurationText(_ minutes: Int) -> String {
        guard minutes >= 60, minutes.isMultiple(of: 60) else {
            return "\(minutes)分"
        }
        return "\(minutes / 60)時間"
    }

    private func formatted(_ date: Date, pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.calendar = .current
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }

    private func compactSummaryCard(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.cyan)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.headline)
                    .monospacedDigit()
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .combine)
    }

#if DEBUG
    private var monthEndUITestDate: Date? {
        let arguments = ProcessInfo.processInfo.arguments
        let month: Int
        if arguments.contains("-statistics-month-end-30") {
            month = 9
        } else if arguments.contains("-statistics-month-end-31") {
            month = 7
        } else {
            return nil
        }
        return Calendar.current.date(from: DateComponents(year: 2026, month: month, day: 15))
    }

    private func seedMonthEndUITestDataIfNeeded() {
        guard monthEndUITestDate != nil, focusSessionRecords.isEmpty else { return }
        let methodMinutes: [(FocusMethod, Int)] = [
            (.pomodoro, 20), (.timer, 15), (.stopwatch, 10)
        ]
        for (month, lastDay) in [(9, 30), (7, 31)] {
            for day in (lastDay - 2)...lastDay {
                guard let completedAt = Calendar.current.date(from: DateComponents(
                    year: 2026, month: month, day: day, hour: 12
                )) else { continue }
                for (method, minutes) in methodMinutes {
                    modelContext.insert(FocusSessionRecord(
                        completedAt: completedAt,
                        durationMinutes: minutes,
                        focusMethod: method
                    ))
                }
            }
        }
        try? modelContext.save()
    }

    private func seedTapUITestDataIfNeeded() {
        guard ProcessInfo.processInfo.arguments.contains("-statistics-tap-ui-test"),
              focusSessionRecords.isEmpty,
              let firstBucket = Calendar.current.date(
                bySettingHour: 13,
                minute: 0,
                second: 0,
                of: Date()
              ),
              let secondBucket = Calendar.current.date(
                bySettingHour: 15,
                minute: 0,
                second: 0,
                of: Date()
              ) else {
            return
        }

        for (method, minutes) in [
            (FocusMethod.pomodoro, 50),
            (.timer, 45),
            (.stopwatch, 40)
        ] {
            modelContext.insert(FocusSessionRecord(
                completedAt: firstBucket,
                durationMinutes: minutes,
                focusMethod: method
            ))
        }
        modelContext.insert(FocusSessionRecord(
            completedAt: secondBucket,
            durationMinutes: 30,
            focusMethod: .timer
        ))
        try? modelContext.save()
    }
#endif

}

#Preview {
    NavigationStack {
        StatisticsView(player: Player(todayStudyMinutes: 50, yesterdayStudyMinutes: 75, studyStreakDays: 6))
    }
    .modelContainer(
        for: [StudyDailyRecord.self, FocusCategory.self, FocusSessionRecord.self],
        inMemory: true
    )
}
