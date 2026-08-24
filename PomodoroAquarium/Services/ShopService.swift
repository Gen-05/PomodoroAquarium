import SwiftData

enum ShopPurchaseError: Error, Equatable {
    case playerUnavailable
    case insufficientCoins
    case unsupportedProduct
}

enum ShopService {
    @discardableResult
    static func purchaseDecoration(
        _ item: ShopItem,
        for player: Player?,
        in context: ModelContext
    ) throws -> AquariumDecorationPlacement {
        guard let player else { throw ShopPurchaseError.playerUnavailable }
        guard case let .decoration(kind) = item.content else {
            throw ShopPurchaseError.unsupportedProduct
        }
        guard CurrencyService.canAfford(item.price, player: player) else {
            throw ShopPurchaseError.insufficientCoins
        }

        try CurrencyService.spendCoins(item.price, from: player, in: context)
        do {
            return try AquariumDecorationService.addPlacement(
                kind: kind,
                isPlaced: false,
                in: context
            )
        } catch {
            // 装飾追加に失敗した場合は、消費済みコインを戻して残高だけ失う状態を防ぐ。
            _ = try? CurrencyService.addCoins(item.price, to: player, in: context)
            throw error
        }
    }
}
