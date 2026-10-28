import Foundation
import SwiftData

/// 公開用の試し置き。正式配置の必要な部分だけを切り離し、購入・下書き・本番Contextを持たない。
@MainActor
final class ShopDecorationPreviewSession: Identifiable {
    enum SetupError: Error { case unsupportedProduct }

    let id = UUID()
    let item: ShopItem
    let backgroundTheme: AquariumBackgroundTheme
    let working: AquariumEditorWorkingState
    let trial: AquariumDecorationPlacement
    let fishViewingSession: AquariumFishViewingSession
    let modelContainer: ModelContainer

    var placements: [AquariumDecorationPlacement] {
        // 沈没船は遠景1隻分を比較する。既存個体の所持・配置状態はコピー上でも書き換えない。
        working.placements.filter { trial.kind != .shipwreck || $0.kind != .shipwreck } + [trial]
    }

    init(item: ShopItem, official: Player, placements: [AquariumDecorationPlacement],
         backgroundTheme: AquariumBackgroundTheme, fishViewingSession: AquariumFishViewingSession?) throws {
        guard case let .decoration(kind) = item.content, kind.isAvailable else { throw SetupError.unsupportedProduct }
        self.item = item
        self.backgroundTheme = backgroundTheme
        working = AquariumEditorWorkingState(official: official,
            placements: placements.filter { $0.isPlaced && $0.kind.isAvailable })
        let fishIDs = Set(working.player.activeAquariumFishIDs)
        self.fishViewingSession = fishViewingSession?.independentPreview(for: fishIDs) ?? AquariumFishViewingSession()
        let point = kind.restorationPosition
        trial = AquariumDecorationPlacement(decorationID: "shop-trial-\(UUID())", kind: kind,
            relativeX: point.x, relativeY: point.y, scale: 1, isPlaced: true,
            isStackingOrderInitialized: true)
        let (frontOrder, overflowed) = (working.placements.map(\.zOrder).max() ?? 0).addingReportingOverflow(1)
        trial.zOrder = overflowed ? Int.max : frontOrder
        // AquariumViewのQuery・操作用Contextも本番から分離する。モデルはinsertせず、保存もしない。
        modelContainer = try ModelContainer(for: Player.self, PlayerFish.self, AquariumDecorationPlacement.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        modelContainer.mainContext.autosaveEnabled = false
    }

    func changeFacing() {
        guard trial.kind.supportsFacingDirection, trial.kind != .shipwreck else { return }
        _ = try? AquariumDecorationService.toggleFacing(trial, in: modelContainer.mainContext, persistChanges: false)
    }

    func placeShipwreck(on side: AquariumDecorationFacingDirection) {
        guard trial.kind == .shipwreck else { return }
        AquariumShipwreckEditing.place(id: trial.decorationID, side: side, among: [trial])
    }
}
