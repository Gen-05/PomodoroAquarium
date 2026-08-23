import Foundation
import SwiftData

enum StudyHistoryService {
    /// 既存の当日累計を移行用の下限として使い、完了した勉強時間を日別履歴へ加算する。
    static func addStudyMinutes(
        _ minutes: Int,
        on date: Date = Date(),
        existingTodayMinutesBeforeCompletion: Int = 0,
        calendar: Calendar = .current,
        in context: ModelContext
    ) throws {
        guard minutes > 0 else { return }

        let day = calendar.startOfDay(for: date)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: day) ?? day.addingTimeInterval(86_400)
        let descriptor = FetchDescriptor<StudyDailyRecord>(
            predicate: #Predicate { $0.day >= day && $0.day < nextDay }
        )
        let existingRecord = try context.fetch(descriptor).first
        let baseline = max(existingRecord?.studyMinutes ?? 0, existingTodayMinutesBeforeCompletion)
        let (updatedMinutes, overflowed) = baseline.addingReportingOverflow(minutes)
        let safeMinutes = overflowed ? Int.max : updatedMinutes

        if let existingRecord {
            existingRecord.studyMinutes = safeMinutes
        } else {
            context.insert(StudyDailyRecord(day: day, studyMinutes: safeMinutes))
        }
        try context.save()
    }

    static func minutes(
        on date: Date,
        from records: [StudyDailyRecord],
        calendar: Calendar = .current
    ) -> Int {
        records
            .filter { calendar.isDate($0.day, inSameDayAs: date) }
            .reduce(0) { partialResult, record in
                let (sum, overflowed) = partialResult.addingReportingOverflow(max(0, record.studyMinutes))
                return overflowed ? Int.max : sum
            }
    }

    static func recentDays(
        count: Int,
        endingAt date: Date = Date(),
        from records: [StudyDailyRecord],
        calendar: Calendar = .current
    ) -> [DailyStudySummary] {
        guard count > 0 else { return [] }
        let endDay = calendar.startOfDay(for: date)

        return (0..<count).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: endDay) else {
                return nil
            }
            return DailyStudySummary(
                date: day,
                minutes: minutes(on: day, from: records, calendar: calendar)
            )
        }
    }

    static func monthlyCalendar(
        containing date: Date,
        from records: [StudyDailyRecord],
        calendar: Calendar = .current
    ) -> [MonthlyStudyDay] {
        let components = calendar.dateComponents([.year, .month], from: date)
        guard let firstDay = calendar.date(from: components),
              let dayRange = calendar.range(of: .day, in: .month, for: firstDay) else {
            return []
        }

        let weekday = calendar.component(.weekday, from: firstDay)
        let leadingEmptyCount = (weekday - calendar.firstWeekday + 7) % 7
        var cells = (0..<leadingEmptyCount).map {
            MonthlyStudyDay(id: $0, date: nil, minutes: 0)
        }

        for dayNumber in dayRange {
            guard let day = calendar.date(byAdding: .day, value: dayNumber - 1, to: firstDay) else {
                continue
            }
            cells.append(MonthlyStudyDay(
                id: cells.count,
                date: day,
                minutes: minutes(on: day, from: records, calendar: calendar)
            ))
        }

        let trailingEmptyCount = (7 - cells.count % 7) % 7
        cells.append(contentsOf: (0..<trailingEmptyCount).map {
            MonthlyStudyDay(id: cells.count + $0, date: nil, minutes: 0)
        })
        return cells
    }

    static func adjacentMonth(
        from date: Date,
        offset: Int,
        calendar: Calendar = .current
    ) -> Date {
        let startOfMonth = calendar.date(
            from: calendar.dateComponents([.year, .month], from: date)
        ) ?? date
        return calendar.date(byAdding: .month, value: offset, to: startOfMonth) ?? startOfMonth
    }
}
