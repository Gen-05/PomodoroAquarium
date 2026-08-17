import SwiftData

enum CurrencyService {
    static let baseStudyCompletionReward = 10
    static let reducedStudyCompletionReward = 2
    static let dailyStudyRewardReductionThreshold = 200

    static func balance(of player: Player?) -> Int {
        max(0, player?.coins ?? 0)
    }

    /// 今回の完了分を加算する前の今日累計を基準に報酬を計算する。
    static func studyCompletionReward(
        for minutes: Int,
        todayStudyMinutesBeforeCompletion: Int
    ) -> Int {
        guard minutes >= 25 else { return 0 }
        return todayStudyMinutesBeforeCompletion >= dailyStudyRewardReductionThreshold
            ? reducedStudyCompletionReward
            : baseStudyCompletionReward
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
}
