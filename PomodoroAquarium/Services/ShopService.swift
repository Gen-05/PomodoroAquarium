import SwiftData

enum ShopPurchaseError: Error, Equatable {
    case playerUnavailable
    case insufficientCoins
    case unsupportedProduct
    case soldOut
    case alreadyOwned
    case backgroundOwnershipUnavailable
}

enum ShopService {
    static func purchaseBackground(_ item: ShopItem, for player: Player?, in context: ModelContext,
                                   save: (() throws -> Void)? = nil) throws {
        guard let player else { throw ShopPurchaseError.playerUnavailable }
        guard case let .background(theme) = item.content, theme != .aquarium else { throw ShopPurchaseError.unsupportedProduct }
        // 移行未完了の旧データを未所持と誤認して課金しない。
        guard let owned = player.ownedBackgroundRawValues else { throw ShopPurchaseError.backgroundOwnershipUnavailable }
        guard !AquariumBackgroundOwnership.canUse(theme, player: player) else { throw ShopPurchaseError.alreadyOwned }
        let oldCoins = player.coins
        guard CurrencyService.debitWithoutSaving(item.price, from: player) else { throw ShopPurchaseError.insufficientCoins }
        player.ownedBackgroundRawValues = owned + [theme.rawValue]
        do {
            if let save { try save() } else { try context.save() }
        } catch {
            // 共有Context全体をrollbackせず、購入の2項目だけ戻す。後のautosaveでも片方だけ残らない。
            player.coins = oldCoins
            player.ownedBackgroundRawValues = owned
            throw error
        }
    }

    /// 配置・収納の状態を問わず、正式な所持個体がある沈没船だけを売り切れとする。
    static func isSoldOut(_ kind: AquariumDecorationKind, among placements: [AquariumDecorationPlacement]) -> Bool {
        kind == .shipwreck && placements.contains { $0.kind == kind }
    }

    @discardableResult
    static func purchaseDecoration(
        _ item: ShopItem,
        for player: Player?,
        in context: ModelContext
    ) throws -> AquariumDecorationPlacement {
        guard let player else { throw ShopPurchaseError.playerUnavailable }
        guard case let .decoration(kind) = item.content, kind.isAvailable else {
            throw ShopPurchaseError.unsupportedProduct
        }
        let placements = try context.fetch(FetchDescriptor<AquariumDecorationPlacement>())
        guard !isSoldOut(kind, among: placements) else { throw ShopPurchaseError.soldOut }
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
