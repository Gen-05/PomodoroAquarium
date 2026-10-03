import Foundation
import SwiftData

enum StudyHistoryService {
    /// 終了理由に関係なく有効時間を保存する。同一sessionの再送で累計を二重加算しない。
    static func recordValidFocusSession(
        _ session: FinalizedFocusSession,
        existingTodayMinutesBeforeCompletion: Int = 0,
        calendar: Calendar = .current,
        in context: ModelContext
    ) throws {
        guard session.validFocusSeconds > 0 else { return }
        let id = session.id
        let descriptor = FetchDescriptor<FocusSessionRecord>(predicate: #Predicate { $0.id == id })
        if try context.fetch(descriptor).first != nil {
            // 前回saveが失敗し、同じcontextに未保存insertが残っている場合も再試行する。
            try context.save()
            return
        }
        try addStudyMinutes(
            session.durationMinutes,
            on: session.completedAt,
            existingTodayMinutesBeforeCompletion: existingTodayMinutesBeforeCompletion,
            categoryID: session.categoryID,
            focusMethod: session.focusMethod,
            calendar: calendar,
            in: context,
            sessionID: session.id,
            durationSeconds: session.validFocusSeconds
        )
    }

    /// 既存の当日累計を移行用の下限として使い、完了した勉強時間を日別履歴へ加算する。
    static func addStudyMinutes(
        _ minutes: Int,
        on date: Date = Date(),
        existingTodayMinutesBeforeCompletion: Int = 0,
        categoryID: String? = FocusCategoryDefaults.studyID,
        focusMethod: FocusMethod = .pomodoro,
        calendar: Calendar = .current,
        in context: ModelContext,
        sessionID: UUID = UUID(),
        durationSeconds: Int? = nil
    ) throws {
        guard minutes > 0 || (durationSeconds ?? 0) > 0 else { return }

        let day = calendar.startOfDay(for: date)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: day) ?? day.addingTimeInterval(86_400)
        let descriptor = FetchDescriptor<StudyDailyRecord>(
            predicate: #Predicate { $0.day >= day && $0.day < nextDay }
        )
        let existingRecord = try context.fetch(descriptor).first
        if let existingRecord,
           existingRecord.categoryHistoryMigratedAt == nil {
            if existingRecord.studyMinutes > 0 {
                context.insert(FocusSessionRecord(
                    completedAt: existingRecord.day,
                    durationMinutes: existingRecord.studyMinutes,
                    categoryID: FocusCategoryDefaults.studyID,
                    focusMethod: .pomodoro
                ))
            }
            existingRecord.categoryHistoryMigratedAt = date
        }
        let baseline = max(existingRecord?.studyMinutes ?? 0, existingTodayMinutesBeforeCompletion)
        let (updatedMinutes, overflowed) = baseline.addingReportingOverflow(minutes)
        let safeMinutes = overflowed ? Int.max : updatedMinutes

        if let existingRecord {
            existingRecord.studyMinutes = safeMinutes
        } else {
            context.insert(StudyDailyRecord(day: day, studyMinutes: safeMinutes))
        }
        context.insert(FocusSessionRecord(
            id: sessionID,
            completedAt: date,
            durationMinutes: minutes,
            categoryID: FocusCategoryDefaults.resolvedCategoryID(categoryID),
            focusMethod: focusMethod,
            durationSeconds: durationSeconds
        ))
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
