import SwiftData
import SwiftUI

struct StatisticsView: View {
    let player: Player?

    @Query(sort: \StudyDailyRecord.day) private var dailyRecords: [StudyDailyRecord]
    @State private var selectedMonth = Date()

    private let weekdaySymbols = ["日", "月", "火", "水", "木", "金", "土"]

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

    private var monthCells: [MonthlyStudyDay] {
        StudyHistoryService.monthlyCalendar(containing: selectedMonth, from: dailyRecords)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                HStack(spacing: 12) {
                    statisticCard(title: "今日", value: "\(todayMinutes)分", icon: "sun.max.fill")
                    statisticCard(title: "昨日", value: "\(yesterdayMinutes)分", icon: "clock.arrow.circlepath")
                    statisticCard(title: "連続", value: "\(max(0, player?.studyStreakDays ?? 0))日", icon: "flame.fill")
                }

                VStack(spacing: 12) {
                    HStack {
                        Button {
                            selectedMonth = StudyHistoryService.adjacentMonth(from: selectedMonth, offset: -1)
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                        .accessibilityLabel("前月")

                        Spacer()
                        Text(selectedMonth, format: .dateTime.year().month(.wide))
                            .font(.headline)
                            .accessibilityIdentifier("selectedMonthLabel")
                        Spacer()

                        Button {
                            selectedMonth = StudyHistoryService.adjacentMonth(from: selectedMonth, offset: 1)
                        } label: {
                            Image(systemName: "chevron.right")
                        }
                        .accessibilityLabel("翌月")
                    }

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 6) {
                        ForEach(weekdaySymbols, id: \.self) { symbol in
                            Text(symbol)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }

                        ForEach(monthCells) { cell in
                            calendarCell(cell)
                        }
                    }
                    .accessibilityIdentifier("monthlyStudyCalendar")
                }
                .padding(14)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
            }
            .padding()
        }
        .background(Color.cyan.opacity(0.08).ignoresSafeArea())
        .navigationTitle("統計")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func calendarCell(_ cell: MonthlyStudyDay) -> some View {
        VStack(spacing: 4) {
            if let date = cell.date {
                Text(date, format: .dateTime.day())
                    .font(.subheadline.weight(.semibold))
                Text("\(cell.minutes)分")
                    .font(.caption2)
                    .foregroundStyle(cell.minutes > 0 ? .primary : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 50)
        .background(
            cell.date == nil ? Color.clear : Color.cyan.opacity(cell.minutes > 0 ? 0.18 : 0.05),
            in: RoundedRectangle(cornerRadius: 8)
        )
    }

    private func statisticCard(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(.cyan)
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline).monospacedDigit()
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
