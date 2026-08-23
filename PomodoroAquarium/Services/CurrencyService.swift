import SwiftData

enum CurrencyService {
    static let baseStudyCompletionReward = 10
    static let reducedStudyCompletionReward = 2
    static let dailyStudyRewardReductionThreshold = 200

    static func balance(of player: Player?) -> Int {
        max(0, player?.coins ?? 0)
    }

    /// 完了前後の今日累計に対応する報酬差分を25分単位で計算する。
    static func studyCompletionReward(
        for minutes: Int,
        todayStudyMinutesBeforeCompletion: Int
    ) -> Int {
        guard minutes >= 25 else { return 0 }

        let beforeMinutes = max(0, todayStudyMinutesBeforeCompletion)
        let (addedMinutes, overflowed) = beforeMinutes.addingReportingOverflow(minutes)
        let afterMinutes = overflowed ? Int.max : addedMinutes
        let beforeReward = cumulativeStudyReward(for: beforeMinutes)
        let afterReward = cumulativeStudyReward(for: afterMinutes)
        return max(0, afterReward - beforeReward)
    }

    private static func cumulativeStudyReward(for minutes: Int) -> Int {
        let safeMinutes = max(0, minutes)
        let regularUnits = min(safeMinutes, dailyStudyRewardReductionThreshold) / 25
        let regularReward = regularUnits * baseStudyCompletionReward
        let reducedUnits = max(0, safeMinutes - dailyStudyRewardReductionThreshold) / 25
        let (reducedReward, reducedOverflowed) = reducedUnits
            .multipliedReportingOverflow(by: reducedStudyCompletionReward)
        guard !reducedOverflowed else { return Int.max }

        let (totalReward, totalOverflowed) = regularReward.addingReportingOverflow(reducedReward)
        return totalOverflowed ? Int.max : totalReward
    }

    /// 正の値だけを加算し、オーバーフロー時はInt.maxで停止する。
    @discardableResult
    static func addCoins(
        _ amount: Int,
        to player: Player,
        in context: ModelContext
    ) throws -> Int {
        let currentBalance = balance(of: player)

        guard amount > 0 else {
            if player.coins != currentBalance {
                player.coins = currentBalance
                try context.save()
            }
            return currentBalance
        }

        let (newBalance, overflowed) = currentBalance.addingReportingOverflow(amount)
        player.coins = overflowed ? Int.max : newBalance
        try context.save()
        return player.coins
    }

    /// 将来のショップ購入判定で共通利用するための残高確認。
    static func canAfford(_ amount: Int, player: Player?) -> Bool {
        amount >= 0 && balance(of: player) >= amount
    }

    /// ショップ等から共通利用する安全なコイン消費。報酬計算には影響しない。
    @discardableResult
    static func spendCoins(
        _ amount: Int,
        from player: Player,
        in context: ModelContext
    ) throws -> Bool {
        guard amount > 0, canAfford(amount, player: player) else { return false }
        player.coins = balance(of: player) - amount
        try context.save()
        return true
    }
}
