import Foundation
import SwiftData

/// 有効秒数から獲得権を確定する。魚種の抽選・生成・ポイントには関与しない。
enum DailyFishProgressService {
    static let secondsPerFish = 1500

    struct Progress: Equatable {
        let newFishEarnedCount: Int
        let remainderSeconds: Int
    }

    enum ProcessingError: Error {
        case missingSession
    }

    static func progress(adding validSeconds: Int, to remainderSeconds: Int) -> Progress {
        let seconds = max(0, validSeconds)
        let remainder = max(0, remainderSeconds) % secondsPerFish
        // 先に商・余りへ分け、Int.max秒でも加算のoverflowを避ける。
        let partialSeconds = remainder + seconds % secondsPerFish
        return Progress(
            newFishEarnedCount: seconds / secondsPerFish + partialSeconds / secondsPerFish,
            remainderSeconds: partialSeconds % secondsPerFish
        )
    }

    @discardableResult
    static func resetIfNeeded(
        for player: Player,
        on date: Date = Date(),
        calendar: Calendar = .current,
        in context: ModelContext
    ) throws -> Bool {
        guard resetProgressDay(for: player, on: date, calendar: calendar) else { return false }
        try context.save()
        return true
    }

    /// 保存済みの同一IDを必ず取得し、進捗・獲得数・処理印を同じSwiftData saveで確定する。
    /// 過去日の遅延保存もその日だけで計算し、今日の余りへ混入させない。
    @discardableResult
    static func process(
        sessionID: UUID,
        for player: Player,
        on date: Date = Date(),
        calendar: Calendar = .current,
        in context: ModelContext
    ) throws -> Progress {
        let descriptor = FetchDescriptor<FocusSessionRecord>(predicate: #Predicate { $0.id == sessionID })
        guard let record = try context.fetch(descriptor).first else {
            throw ProcessingError.missingSession
        }
        resetProgressDay(for: player, on: date, calendar: calendar)

        // durationMinutesから魚を再計算しない。Tutorial/旧履歴も累積の対象外。
        guard let seconds = record.durationSeconds, seconds > 0,
              record.fishEarnedCount == nil else {
            // 前回save失敗でcontextに変更が残っている場合も、保存成功を確認してから返す。
            try context.save()
            return Progress(newFishEarnedCount: 0, remainderSeconds: player.dailyFishProgressSeconds)
        }

        let day = calendar.startOfDay(for: record.completedAt)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: day) ?? day.addingTimeInterval(86_400)
        let sameDay = FetchDescriptor<FocusSessionRecord>(predicate: #Predicate {
            $0.completedAt >= day && $0.completedAt < nextDay && $0.fishEarnedCount != nil
        })
        // 処理済み記録を根拠にするため、復元順序や過去日の再送に依存しない。
        // 日をまたいだsessionは既存履歴と同じcompletedAtの日へ所属する。
        let previousRemainder = try context.fetch(sameDay).reduce(0) { remainder, processed in
            progress(adding: processed.durationSeconds ?? 0, to: remainder).remainderSeconds
        }
        let result = progress(adding: seconds, to: previousRemainder)
        record.fishEarnedCount = result.newFishEarnedCount
        if calendar.isDate(record.completedAt, inSameDayAs: date) {
            player.dailyFishProgressSeconds = result.remainderSeconds
        }
        try refreshDailyEntitlements(for: player, on: date, calendar: calendar, in: context)
        try context.save()
        return result
    }

    @discardableResult
    private static func resetProgressDay(for player: Player, on date: Date, calendar: Calendar) -> Bool {
        let day = calendar.startOfDay(for: date)
        var changed = false
        if player.dailyFishProgressDate.map({ calendar.isDate($0, inSameDayAs: day) }) != true {
            player.dailyFishProgressDate = day
            player.dailyFishProgressSeconds = 0
            changed = true
        }
        if player.dailyGrantedFishDate.map({ calendar.isDate($0, inSameDayAs: day) }) != true {
            player.dailyGrantedFishDate = day
            player.dailyEarnedFishCount = 0
            player.dailyClaimedFishCount = 0
            player.dailyFishLimit = DailyFishAcquisitionPolicy.basicLimit
            player.pendingFishEarnedCount = 0
            changed = true
        }
        return changed
    }

    /// 保存済みsession IDを根拠に日次権利を再構築。旧Step 2の未付与分にも対応する。
    /// 過去日の遅延復元は今日へ持ち越さず、集中履歴そのものは一切削除しない。
    static func refreshDailyEntitlements(
        for player: Player, on date: Date = Date(), calendar: Calendar = .current, in context: ModelContext
    ) throws {
        resetProgressDay(for: player, on: date, calendar: calendar)
        let day = calendar.startOfDay(for: date)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: day) ?? day.addingTimeInterval(86_400)
        let records = try context.fetch(FetchDescriptor<FocusSessionRecord>(predicate: #Predicate {
            $0.completedAt >= day && $0.completedAt < nextDay && $0.fishEarnedCount != nil
        }))
        let earned = records.reduce(0) { sum, record in
            min(DailyFishAcquisitionPolicy.maximumLimit,
                sum + min(DailyFishAcquisitionPolicy.maximumLimit, max(0, record.fishEarnedCount ?? 0)))
        }
        // 旧付与済み魚は消さず、claimedの事実も保持する。
        player.dailyEarnedFishCount = min(DailyFishAcquisitionPolicy.maximumLimit,
                                         max(earned, player.dailyClaimedFishCount))
        player.dailyFishLimit = min(DailyFishAcquisitionPolicy.maximumLimit,
                                   max(DailyFishAcquisitionPolicy.basicLimit, player.dailyFishLimit))
        player.pendingFishEarnedCount = player.dailyPendingFishCount
    }
}
