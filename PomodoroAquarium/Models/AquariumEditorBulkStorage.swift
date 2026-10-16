import Foundation

/// A value-only edit. One result can be recorded as one existing history operation.
enum AquariumEditorBulkStorage: Equatable, Identifiable {
    case fish, decorations
    case decorationCategory(AquariumDecorationCategory)

    var id: String {
        switch self {
        case .fish: "fish"
        case .decorations: "decorations"
        case .decorationCategory(let category): "decorations.\(category.rawValue)"
        }
    }

    var itemName: String {
        switch self {
        case .fish: "魚"
        case .decorations: "装飾"
        case .decorationCategory(.plant): "海藻"
        case .decorationCategory(let category): category.displayName
        }
    }
    var buttonTitle: String { "\(itemName)を全部しまう" }
    var confirmationTitle: String { "\(itemName)を全部しまいますか？" }

    /// 一覧・件数・Draft更新が同じ既存カテゴリー定義を使用する。
    func includes(_ kind: AquariumDecorationKind?) -> Bool {
        guard case .decorationCategory(let category) = self else { return true }
        return kind?.category == category
    }

    func applying(to draft: AquariumEditorDraft) -> AquariumEditorDraft? {
        var result = draft.snapshot
        switch self {
        case .fish:
            guard !result.fishIDs.isEmpty else { return nil }
            result.fishIDs.removeAll()
        case .decorations, .decorationCategory:
            let indices = result.placements.indices.filter {
                result.placements[$0].isPlaced && includes(AquariumDecorationKind(rawValue: result.placements[$0].kind))
            }
            guard !indices.isEmpty else { return nil }
            for index in indices { result.placements[index].isPlaced = false }
        }
        return result
    }
}
