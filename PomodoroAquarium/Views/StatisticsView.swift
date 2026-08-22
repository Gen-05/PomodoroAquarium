import Charts
import SwiftData
import SwiftUI

struct StatisticsView: View {
    let player: Player?

    @Query(sort: \StudyDailyRecord.day) private var dailyRecords: [StudyDailyRecord]

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

    private var recentThirtyDays: [DailyStudySummary] {
        StudyHistoryService.recentDays(count: 30, from: dailyRecords)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                HStack(spacing: 12) {
                    statisticCard(title: "今日", value: "\(todayMinutes)分", icon: "sun.max.fill")
                    statisticCard(title: "昨日", value: "\(yesterdayMinutes)分", icon: "clock.arrow.circlepath")
                    statisticCard(title: "連続", value: "\(max(0, player?.studyStreakDays ?? 0))日", icon: "flame.fill")
                }

                VStack(alignment: .leading, spacing: 14) {
                    Text("過去30日")
                        .font(.headline)

                    Chart(recentThirtyDays) { summary in
                        BarMark(
                            x: .value("日付", summary.date, unit: .day),
                            y: .value("勉強時間", summary.minutes)
                        )
                        .foregroundStyle(.cyan.gradient)
                    }
                    .chartYAxisLabel("分")
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day, count: 5)) { value in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel(format: .dateTime.month().day())
                        }
                    }
                    .frame(height: 260)
                    .accessibilityIdentifier("studyHistoryChart")
                }
                .padding(18)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
            }
            .padding()
        }
        .background(Color.cyan.opacity(0.08).ignoresSafeArea())
        .navigationTitle("統計")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func statisticCard(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.cyan)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}

#Preview {
    NavigationStack {
        StatisticsView(player: Player(todayStudyMinutes: 50, yesterdayStudyMinutes: 75, studyStreakDays: 6))
    }
    .modelContainer(for: StudyDailyRecord.self, inMemory: true)
}
