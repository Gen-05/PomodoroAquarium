import SwiftData

enum CurrencyService {
    static func balance(of player: Player?) -> Int {
        max(0, player?.coins ?? 0)
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
