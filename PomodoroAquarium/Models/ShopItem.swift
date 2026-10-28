import Foundation

enum ShopCategory: String, CaseIterable, Identifiable {
    case decoration
    case background

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .decoration: "装飾"
        case .background: "背景"
        }
    }
}

enum ShopItemContent: Hashable {
    case decoration(AquariumDecorationKind)
    case background(AquariumBackgroundTheme)
}

struct ShopItem: Identifiable, Hashable {
    let id: String
    let name: String
    let price: Int
    let category: ShopCategory
    let content: ShopItemContent
}

enum ShopCatalog {
    // 正式装飾は既存の定義順・表示名・価格を共有する。IDは並び順に依存しない。
    static let items: [ShopItem] = AquariumDecorationKind.availableKinds.compactMap { kind -> ShopItem? in
        guard let price = kind.plannedPrice else { return nil }
        return ShopItem(id: "decoration-\(kind.rawValue)", name: kind.displayName, price: price,
                        category: .decoration, content: .decoration(kind))
    } + [
        ShopItem(
            id: "background-deep-sea",
            name: AquariumBackgroundTheme.deepSea.displayName,
            price: 3_000,
            category: .background,
            content: .background(.deepSea)
        ),
        ShopItem(
            id: "background-tropical",
            name: AquariumBackgroundTheme.tropical.displayName,
            price: 3_000,
            category: .background,
            content: .background(.tropical)
        )
    ]

    static func items(in category: ShopCategory) -> [ShopItem] {
        items.filter { $0.category == category }
    }
}
