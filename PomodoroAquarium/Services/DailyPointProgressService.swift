import Foundation
import SwiftData

/// 確定した有効秒数だけを使用する。魚抽選・広告枠・カテゴリ・終了理由には関与しない。
enum DailyPointProgressService {
    static let normalSecondsPerReward = 300
    static let reducedUnitsPerPoint = 1500
    // 現在の受取枠（無料3匹等）ではなく、当日の最大魚獲得条件を使う。
    static var normalRateCapacitySeconds: Int {
        DailyFishAcquisitionPolicy.maximumLimit * DailyFishProgressService.secondsPerFish
    }

    struct Progress: Equatable {
        let awardedPoints: Int
        let normalSeconds: Int
        let normalRemainderSeconds: Int
        let reducedRemainderUnits: Int
    }

    enum ProcessingError: Error { case missingSession }

    static func progress(
        adding validSeconds: Int,
        after dailyValidSeconds: Int,
        normalRemainderSeconds: Int = 0,
        reducedRemainderUnits: Int = 0
    ) -> Progress {
        let seconds = max(0, validSeconds)
        let normal = min(seconds, max(0, normalRateCapacitySeconds - min(
            normalRateCapacitySeconds, max(0, dailyValidSeconds)
        )))
        let normalTotal = normal + max(0, normalRemainderSeconds) % normalSecondsPerReward
        let reduced = seconds - normal
        // 2 units/秒。先に商・余りに分け、巨大な秒数でも乗算overflowしない。
        let reducedPartial = (reduced % 750) * 2
            + max(0, reducedRemainderUnits) % reducedUnitsPerPoint
        let reducedPoints = reduced / 750 + reducedPartial / reducedUnitsPerPoint
        let points = (normalTotal / normalSecondsPerReward) * 2 + reducedPoints
        return Progress(
            awardedPoints: points,
            normalSeconds: normal,
            normalRemainderSeconds: normalTotal % normalSecondsPerReward,
            reducedRemainderUnits: reducedPartial % reducedUnitsPerPoint
        )
    }

    @discardableResult
    static func resetIfNeeded(
        for player: Player, on date: Date = Date(), calendar: Calendar = .current,
        in context: ModelContext
    ) throws -> Bool {
        guard player.dailyPointProgressDate.map({ calendar.isDate($0, inSameDayAs: date) }) != true else {
            return false
        }
        player.dailyPointProgressDate = calendar.startOfDay(for: date)
        player.normalPointProgressSeconds = 0
        player.reducedPointProgressUnits = 0
        try context.save()
        return true
    }

    /// 魚進捗処理より先に呼ぶ。旧方式で魚処理済みの履歴は遡及付与しない。
    /// 保存失敗時は残高・端数・処理印を戻し、TimerSessionStoreから安全に再送できる。
    @discardableResult
    static func process(
        sessionID: UUID, for player: Player, on date: Date = Date(), calendar: Calendar = .current,
        in context: ModelContext
    ) throws -> Int {
        let descriptor = FetchDescriptor<FocusSessionRecord>(predicate: #Predicate { $0.id == sessionID })
        guard let record = try context.fetch(descriptor).first else { throw ProcessingError.missingSession }
        guard record.pointReward == nil, record.fishEarnedCount == nil,
              let seconds = record.durationSeconds, seconds > 0 else {
            return 0
        }

        let day = calendar.startOfDay(for: record.completedAt)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: day) ?? day.addingTimeInterval(86_400)
        let records = try context.fetch(FetchDescriptor<FocusSessionRecord>(predicate: #Predicate {
            $0.completedAt >= day && $0.completedAt < nextDay
        })).filter { $0.id != sessionID }
        var priorSeconds = 0
        var normalRemainder = 0
        var reducedRemainder = 0
        for prior in records {
            // 旧付与分は上限到達の判定には含むが、ポイントを再付与/端数再利用しない。
            if prior.pointReward != nil || prior.fishEarnedCount != nil {
                priorSeconds = min(normalRateCapacitySeconds,
                    priorSeconds + min(normalRateCapacitySeconds, max(0, prior.durationSeconds ?? 0)))
            }
            if prior.pointReward != nil, let normal = prior.normalPointSeconds {
                normalRemainder = (normalRemainder + normal % normalSecondsPerReward) % normalSecondsPerReward
                let reduced = max(0, (prior.durationSeconds ?? 0) - normal)
                reducedRemainder = (reducedRemainder + (reduced % 750) * 2) % reducedUnitsPerPoint
            }
        }
        let result = progress(adding: seconds, after: priorSeconds,
                              normalRemainderSeconds: normalRemainder, reducedRemainderUnits: reducedRemainder)
        let oldCoins = player.coins
        let oldDay = player.dailyPointProgressDate
        let oldNormal = player.normalPointProgressSeconds
        let oldReduced = player.reducedPointProgressUnits
        do {
            CurrencyService.creditWithoutSaving(result.awardedPoints, to: player)
            record.pointReward = result.awardedPoints
            record.normalPointSeconds = result.normalSeconds
            if calendar.isDate(record.completedAt, inSameDayAs: date) {
                player.dailyPointProgressDate = calendar.startOfDay(for: date)
                player.normalPointProgressSeconds = result.normalRemainderSeconds
                player.reducedPointProgressUnits = result.reducedRemainderUnits
            }
            try context.save()
            return result.awardedPoints
        } catch {
            player.coins = oldCoins
            player.dailyPointProgressDate = oldDay
            player.normalPointProgressSeconds = oldNormal
            player.reducedPointProgressUnits = oldReduced
            record.pointReward = nil
            record.normalPointSeconds = nil
            throw error
        }
    }

    /// 保存済み履歴と魚処理の間で終了しても、起動時にポイントを先に確定する。
    static func processPending(
        for player: Player, on date: Date = Date(), calendar: Calendar = .current, in context: ModelContext
    ) throws {
        let records = try context.fetch(FetchDescriptor<FocusSessionRecord>(
            sortBy: [SortDescriptor(\FocusSessionRecord.completedAt)]
        ))
        for record in records where record.pointReward == nil && record.fishEarnedCount == nil {
            try process(sessionID: record.id, for: player, on: date, calendar: calendar, in: context)
        }
        try resetIfNeeded(for: player, on: date, calendar: calendar, in: context)
    }
}
