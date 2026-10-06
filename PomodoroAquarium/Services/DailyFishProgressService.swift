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
        // durationMinutesから魚を再計算しない。Tutorial/旧履歴も累積の対象外。
        guard let seconds = record.durationSeconds, seconds > 0,
              record.fishEarnedCount == nil else {
            // 前回save失敗でcontextに変更が残っている場合も、保存成功を確認してから返す。
            try context.save()
            return Progress(newFishEarnedCount: 0, remainderSeconds: player.dailyFishProgressSeconds)
        }

        let processingDate = record.sessionStartedAt == nil ? date : record.attributionDate
        resetProgressDay(for: player, on: processingDate, calendar: calendar)
        let day = record.sessionDay(calendar: calendar)
        let sameDay = FetchDescriptor<FocusSessionRecord>(predicate: #Predicate {
            $0.fishEarnedCount != nil
        })
        // 処理済み記録を根拠にするため、復元順序や過去日の再送に依存しない。
        let previousRemainder = try context.fetch(sameDay)
            .filter { calendar.isDate($0.attributionDate, inSameDayAs: day) }
            .reduce(0) { remainder, processed in
            progress(adding: processed.durationSeconds ?? 0, to: remainder).remainderSeconds
        }
        let result = progress(adding: seconds, to: previousRemainder)
        record.fishEarnedCount = result.newFishEarnedCount
        if calendar.isDate(record.attributionDate, inSameDayAs: processingDate) {
            player.dailyFishProgressSeconds = result.remainderSeconds
        }
        try refreshDailyEntitlements(for: player, on: processingDate, calendar: calendar, in: context)
        try context.save()
        return result
    }

    @discardableResult
    private static func resetProgressDay(for player: Player, on date: Date, calendar: Calendar) -> Bool {
        DailyRewardStateStore.activateFishDay(for: player, on: date, calendar: calendar)
    }

    /// 保存済みsession IDを根拠に日次権利を再構築。旧Step 2の未付与分にも対応する。
    /// 過去日の遅延復元は今日へ持ち越さず、集中履歴そのものは一切削除しない。
    static func refreshDailyEntitlements(
        for player: Player, on date: Date = Date(), calendar: Calendar = .current, in context: ModelContext
    ) throws {
        resetProgressDay(for: player, on: date, calendar: calendar)
        let day = calendar.startOfDay(for: date)
        let records = try context.fetch(FetchDescriptor<FocusSessionRecord>(predicate: #Predicate {
            $0.fishEarnedCount != nil
        })).filter { calendar.isDate($0.attributionDate, inSameDayAs: day) }
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
