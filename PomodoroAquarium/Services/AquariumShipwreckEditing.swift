import SwiftData

@MainActor
enum AquariumShipwreckEditing {
    /// 所持個体を使い回し、左右変更も同じDraftの1操作として記録する。
    @discardableResult
    static func place(id: String, side: AquariumDecorationFacingDirection,
                      among placements: [AquariumDecorationPlacement]) -> AquariumDecorationPlacement? {
        guard let owned = placements.first(where: { $0.decorationID == id && $0.kind == .shipwreck }) else { return nil }
        let active = placements.filter { $0.kind == .shipwreck && $0.isPlaced }.sorted { $0.decorationID < $1.decorationID }
        let target = active.first ?? owned
        guard !target.isPlaced || target.facingDirection != side || active.count > 1 else { return nil }
        for other in active where other.decorationID != target.decorationID { other.isPlaced = false }
        target.facingDirection = side
        target.isPlaced = true
        target.isStackingOrderInitialized = true
        return target
    }
}
