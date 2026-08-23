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
    // 仮価格はここだけを変更すれば、表示・購入判定の両方へ反映される。
    static let items: [ShopItem] = [
        ShopItem(
            id: "decoration-seaweed",
            name: AquariumDecorationKind.seaweed.displayName,
            price: 100,
            category: .decoration,
            content: .decoration(.seaweed)
        ),
        ShopItem(
            id: "decoration-rock",
            name: AquariumDecorationKind.rock.displayName,
            price: 120,
            category: .decoration,
            content: .decoration(.rock)
        ),
        ShopItem(
            id: "background-aquarium",
            name: AquariumBackgroundTheme.aquarium.displayName,
            price: 200,
            category: .background,
            content: .background(.aquarium)
        ),
        ShopItem(
            id: "background-deep-sea",
            name: AquariumBackgroundTheme.deepSea.displayName,
            price: 300,
            category: .background,
            content: .background(.deepSea)
        ),
        ShopItem(
            id: "background-tropical",
            name: AquariumBackgroundTheme.tropical.displayName,
            price: 300,
            category: .background,
            content: .background(.tropical)
        )
    ]

    static func items(in category: ShopCategory) -> [ShopItem] {
        items.filter { $0.category == category }
    }
}
