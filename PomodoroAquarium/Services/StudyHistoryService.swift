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
}
