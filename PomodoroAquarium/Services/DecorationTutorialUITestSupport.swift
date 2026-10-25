#if DEBUG
import Foundation
import SwiftData

/// 装飾の商品登録とは独立した、メモリ内ストアを使うUIテスト専用の商品。
enum DecorationTutorialUITestSupport {
    static var isEnabled: Bool {
        let args = ProcessInfo.processInfo.arguments
        return args.contains("-decoration-purchase-tutorial-ui-test") && args.contains("-core-tutorial-in-memory")
    }
    static var products: [ShopItem]? {
        guard isEnabled else { return nil }
        let kinds: [AquariumDecorationKind] = [.seaweedA, .treasureChest, .shipwreck, .smallRockA, .coralCPurple]
        return kinds.map { kind in
            ShopItem(id: "tutorial-test-\(kind.rawValue)", name: kind.displayName,
                price: kind == .smallRockA ? 999_999 : 10, category: .decoration, content: .decoration(kind))
        } + ShopCatalog.items
    }
    static func prepareLaunch() {
        guard isEnabled, ProcessInfo.processInfo.arguments.contains("-reset-decoration-purchase-tutorial") else { return }
        UserDefaults.standard.removeObject(forKey: DecorationPurchaseTutorial.storageKey)
    }
    static func prepare(_ result: HomePlayerInitializationResult, in context: ModelContext) throws {
        guard isEnabled, result.didCreatePlayer else { return }
        result.player.coins = 100
        try context.save()
    }
}
#endif
