import Foundation
import SwiftData

/// レア率補正の唯一の時間source。方法・カテゴリ・終了理由では絞り込まない。
enum PreviousDayFocusDurationService {
    static func minutes(
        before date: Date = Date(), calendar: Calendar = .current, in context: ModelContext
    ) throws -> Int {
        // 永続記録を持たない旧helper用の小さなcontainerは、前日記録なしとして扱う。
        guard context.container.schema.entitiesByName[String(describing: FocusSessionRecord.self)] != nil else {
            return 0
        }
        let today = calendar.startOfDay(for: date)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return 0 }
        let records = try context.fetch(FetchDescriptor<FocusSessionRecord>()).filter {
            $0.attributionDate >= yesterday && $0.attributionDate < today
        }
        // 端数秒は各recordで捨てず、全秒数を合計してから既存確率APIの整数分へ換算。
        let seconds = records.reduce(0) { sum, record in
            let (next, overflowed) = sum.addingReportingOverflow(record.validFocusSeconds)
            return overflowed ? Int.max : next
        }
        return seconds / 60
    }

    /// 旧property名は維持するが、Player値を集計に足さず、記録から置き換えるだけ。
    @discardableResult
    static func synchronizeMinutes(
        for player: Player, before date: Date = Date(), calendar: Calendar = .current, in context: ModelContext
    ) throws -> Int {
        let result = try minutes(before: date, calendar: calendar, in: context)
        player.yesterdayStudyMinutes = result
        return result
    }
}
