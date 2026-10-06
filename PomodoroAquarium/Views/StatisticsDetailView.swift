import SwiftUI

/// 全期間のbucket詳細を共通表示する。detail.requiresPlusを将来の入口判定へ接続できる。
struct StatisticsDetailView: View {
    let detail: FocusBucketDetail

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(detailTitle)
                            .font(.title2.bold())
                        Text("合計")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(durationText(detail.totalMinutes))
                            .font(.title.bold())
                            .monospacedDigit()
                        if detail.period == .year {
                            HStack(spacing: 20) {
                                Text("集中した日 \(detail.focusedDayCount)日")
                                Text("セッション \(detail.sessionCount)回")
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        }
                    }

                    if detail.sessions.isEmpty {
                        Divider()
                        Text("この期間の詳細記録はありません")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 120)
                    } else {
                        Divider()
                        detailSection("集中方法") {
                            ForEach(detail.methodSummary) { item in
                                summaryRow(
                                    name: item.method.displayName,
                                    minutes: item.minutes,
                                    color: methodColor(item.method)
                                )
                            }
                        }

                        Divider()
                        detailSection("カテゴリ") {
                            ForEach(detail.categorySummary) { item in
                                summaryRow(
                                    name: item.category.name,
                                    minutes: item.minutes,
                                    color: item.category.swiftUIColor
                                )
                            }
                        }

                        Divider()
                        detailSection("セッション") {
                            if detail.period == .year {
                                ForEach(detail.sessionDaySections) { section in
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text(dateText(section.day, pattern: "M月d日"))
                                            .font(.subheadline.bold())
                                        ForEach(section.sessions) { session in
                                            sessionRow(session)
                                        }
                                    }
                                    Divider()
                                }
                            } else {
                                ForEach(detail.sessions) { session in
                                    sessionRow(session)
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            .background(Color.cyan.opacity(0.08).ignoresSafeArea())
            .navigationTitle("詳細")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
        .accessibilityIdentifier("statistics.detailSheet")
    }

    private var detailTitle: String {
        switch detail.period {
        case .day:
            "\(Calendar.current.component(.hour, from: detail.bucket.start))時台の詳細"
        case .week:
            "\(dateText(detail.bucket.start, pattern: "M月d日（E）"))の詳細"
        case .month:
            "\(dateText(detail.bucket.start, pattern: "M月d日"))の詳細"
        case .year:
            dateText(detail.bucket.start, pattern: "yyyy年M月")
        }
    }

    private func sessionRow(_ session: FocusSessionDetail) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(sessionTimeRange(session))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                Spacer(minLength: 8)
                Text(sessionDurationText(session))
                    .monospacedDigit()
            }
            HStack(spacing: 6) {
                Circle()
                    .fill(session.category.swiftUIColor)
                    .frame(width: 8, height: 8)
                Text(session.category.name)
                Text("・")
                if detail.period == .year {
                    Circle()
                        .fill(methodColor(session.method))
                        .frame(width: 6, height: 6)
                }
                Text(session.method.displayName)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            if let continuationText = session.displaySlice?.continuationText {
                Text(continuationText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func sessionTimeRange(_ session: FocusSessionDetail) -> String {
        if detail.period == .day, session.record.sessionStartedAt != nil {
            let dayStart = Calendar.current.startOfDay(for: detail.bucket.start)
            let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart)
            let endText = session.completedAt == dayEnd ? "24:00" : timeText(session.completedAt)
            return "\(timeText(session.startedAt))–\(endText)"
        }
        // 日をまたぐsessionも、日付Sectionに対して開始日時が曖昧にならないようにする。
        if !Calendar.current.isDate(session.startedAt, inSameDayAs: session.completedAt) {
            return "\(dateText(session.startedAt, pattern: "M/d HH:mm"))–\(dateText(session.completedAt, pattern: "M/d HH:mm"))"
        }
        return "\(timeText(session.startedAt))–\(timeText(session.completedAt))"
    }

    private func sessionDurationText(_ session: FocusSessionDetail) -> String {
        guard detail.period == .year || detail.period == .day else { return durationText(session.durationMinutes) }
        let seconds = session.durationSeconds % 60
        guard seconds > 0 else { return durationText(session.durationMinutes) }
        return session.durationMinutes > 0
            ? "\(durationText(session.durationMinutes))\(seconds)秒"
            : "\(seconds)秒"
    }

    private func detailSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content()
        }
    }

    private func summaryRow(name: String, minutes: Int, color: Color) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(name)
            Spacer(minLength: 8)
            Text(durationText(minutes))
                .monospacedDigit()
        }
    }

    private func methodColor(_ method: FocusMethod) -> Color {
        switch method {
        case .pomodoro, .legacy: .cyan
        case .timer: .orange
        case .stopwatch: .purple
        }
    }

    private func durationText(_ minutes: Int) -> String {
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if hours == 0 { return "\(remainingMinutes)分" }
        if remainingMinutes == 0 { return "\(hours)時間" }
        return "\(hours)時間\(remainingMinutes)分"
    }

    private func timeText(_ date: Date) -> String {
        dateText(date, pattern: "HH:mm")
    }

    private func dateText(_ date: Date, pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.calendar = .current
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
}
