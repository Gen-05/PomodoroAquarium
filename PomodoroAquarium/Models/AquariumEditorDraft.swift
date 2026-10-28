import Foundation
import Observation

/// Only aquarium presentation state is persisted; ownership remains in SwiftData.
struct AquariumEditorDraft: Codable, Equatable {
    struct Placement: Codable, Equatable {
        var id: String
        var kind: String
        var x: Double
        var y: Double
        var scale: Double
        var isPlaced: Bool
        var facingDirection: AquariumDecorationFacingDirection = .right
        var zOrder: Int = 0
        var rockIsForeground: Bool = false
        var isStackingOrderInitialized: Bool = false

        init(id: String, kind: String, x: Double, y: Double, scale: Double, isPlaced: Bool,
             facingDirection: AquariumDecorationFacingDirection = .right, zOrder: Int = 0, rockIsForeground: Bool = false, isStackingOrderInitialized: Bool = false) {
            self.id = id; self.kind = kind; self.x = x; self.y = y; self.scale = scale
            self.isPlaced = isPlaced; self.facingDirection = facingDirection
            self.zOrder = zOrder; self.rockIsForeground = rockIsForeground
            self.isStackingOrderInitialized = isStackingOrderInitialized
        }
        private enum CodingKeys: String, CodingKey { case id, kind, x, y, scale, isPlaced, facingDirection, zOrder, rockIsForeground, isStackingOrderInitialized }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(String.self, forKey: .id); kind = try c.decode(String.self, forKey: .kind)
            x = try c.decode(Double.self, forKey: .x); y = try c.decode(Double.self, forKey: .y)
            scale = try c.decode(Double.self, forKey: .scale); isPlaced = try c.decode(Bool.self, forKey: .isPlaced)
            facingDirection = try c.decodeIfPresent(AquariumDecorationFacingDirection.self, forKey: .facingDirection) ?? .right
            zOrder = try c.decodeIfPresent(Int.self, forKey: .zOrder) ?? 0
            rockIsForeground = try c.decodeIfPresent(Bool.self, forKey: .rockIsForeground) ?? false
            isStackingOrderInitialized = try c.decodeIfPresent(Bool.self, forKey: .isStackingOrderInitialized) ?? false
        }
    }
    var history: AquariumEditorHistory?
    var version = 1
    var fishIDs: [UUID]
    var placements: [Placement]
    var background: String

    @MainActor
    init(player: Player, placements: [AquariumDecorationPlacement], background: AquariumBackgroundTheme) {
        fishIDs = player.activeAquariumFishIDs
        self.placements = placements.map {
            Placement(id: $0.decorationID, kind: $0.kindRawValue, x: $0.relativeX,
                      y: $0.relativeY, scale: $0.scale, isPlaced: $0.isPlaced, facingDirection: $0.facingDirection, zOrder: $0.zOrder, rockIsForeground: $0.rockIsForeground, isStackingOrderInitialized: $0.isStackingOrderInitialized)
        }
        self.background = background.rawValue
        normalizeLegacyStacking()
        self.placements.removeAll { AquariumDecorationKind.isLegacyPlaceholder(rawValue: $0.kind) }
    }
    /// 旧データは従来の見た目順に一度だけ番号を補完。過去の履歴も同じ規則で読み込む。
    private mutating func normalizeLegacyStacking() {
        guard placements.contains(where: { $0.isPlaced && !$0.isStackingOrderInitialized
            && $0.kind != AquariumDecorationKind.shipwreck.rawValue
            && AquariumDecorationKind(rawValue: $0.kind)?.isAvailable == true }) else { return }
        let ordered = placements.indices.filter {
            placements[$0].isPlaced && placements[$0].kind != AquariumDecorationKind.shipwreck.rawValue
                && AquariumDecorationKind(rawValue: placements[$0].kind)?.isAvailable == true
        }.sorted { a, b in
            func decoration(_ index: Int) -> AquariumDecoration {
                let p = placements[index]
                return AquariumDecoration(id: p.id, kind: AquariumDecorationKind(rawValue: p.kind) ?? .unsupported,
                    relativeX: p.x, relativeY: p.y, scale: p.scale, zOrder: p.zOrder,
                    rockIsForeground: p.rockIsForeground, isStackingOrderInitialized: p.isStackingOrderInitialized)
            }
            return AquariumDecorationStacking.isBehind(decoration(a), decoration(b))
        }
        for (rank, index) in ordered.enumerated() {
            placements[index].zOrder = rank + 1
            placements[index].isStackingOrderInitialized = true
        }
    }

    var snapshot: Self {
        var copy = self
        copy.history = nil
        copy.placements.removeAll { AquariumDecorationKind.isLegacyPlaceholder(rawValue: $0.kind) }
        copy.placements.sort { $0.id < $1.id }
        return copy
    }
    /// 魚・背景・正式装飾の値と履歴位置は保持し、旧2種だけを各snapshotから取り除く。
    func removingLegacyPlaceholders() -> Self {
        var copy = self
        copy.placements.removeAll { AquariumDecorationKind.isLegacyPlaceholder(rawValue: $0.kind) }
        copy.history = history?.removingLegacyPlaceholders()
        return copy
    }
    var isValid: Bool {
        version == 1 && AquariumBackgroundTheme(rawValue: background) != nil &&
        Set(fishIDs).count == fishIDs.count && Set(placements.map(\.id)).count == placements.count &&
        placements.allSatisfy { $0.x.isFinite && $0.y.isFinite && $0.scale.isFinite && $0.scale > 0 }
    }
    private enum CodingKeys: String, CodingKey { case version, fishIDs, placements, background, history }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        version = try values.decode(Int.self, forKey: .version)
        fishIDs = try values.decode([UUID].self, forKey: .fishIDs)
        placements = try values.decode([Placement].self, forKey: .placements)
        background = try values.decode(String.self, forKey: .background)
        // Broken history must never prevent recovery of the current draft.
        history = try? values.decodeIfPresent(AquariumEditorHistory.self, forKey: .history)
        normalizeLegacyStacking()
    }

}

struct AquariumEditorDraftStore {
    let url: URL
    static var standard: Self {
        Self(url: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("aquarium-editor-draft.json"))
    }
    func load() throws -> AquariumEditorDraft? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let decoded = try JSONDecoder().decode(AquariumEditorDraft.self, from: Data(contentsOf: url))
        let draft = decoded.removingLegacyPlaceholders()
        guard draft.isValid else {
            throw CocoaError(.fileReadCorruptFile)
        }
        if decoded != draft { try save(draft) }
        return draft
    }
    func save(_ draft: AquariumEditorDraft) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(draft.removingLegacyPlaceholders()).write(to: url, options: .atomic)
    }
    func remove() throws {
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }
}

@MainActor @Observable
final class AquariumEditorWorkingState {
    let player: Player
    private(set) var placements: [AquariumDecorationPlacement]
    init(official: Player, placements: [AquariumDecorationPlacement], draft: AquariumEditorDraft? = nil) {
        // Every model is detached; no relationship points into the official context.
        // 下書きを渡さない試し置きでは、正式な表示対象だけをコピーし、保存値をそのまま使う。
        let fish = draft == nil ? official.activeAquariumFish : official.ownedFish
        player = Player(ownedFish: fish.map { PlayerFish(id: $0.id, species: $0.species) },
                        activeAquariumFishIDs: (draft?.fishIDs ?? fish.map(\.id)).filter { id in fish.contains { $0.id == id } },
                        hasInitializedActiveAquariumFish: true,
                        coreTutorialRewardFishID: official.coreTutorialRewardFishID)
        let states = Dictionary(uniqueKeysWithValues: (draft?.placements ?? []).map { ($0.id, $0) })
        self.placements = placements.filter { !$0.kind.isLegacyPlaceholder }.map { original in
            let state = states[original.decorationID]
            let copy = AquariumDecorationPlacement(decorationID: original.decorationID, kind: original.kind,
                relativeX: state?.x ?? original.relativeX, relativeY: state?.y ?? original.relativeY,
                scale: state?.scale ?? original.scale, isPlaced: state?.isPlaced ?? original.isPlaced,
                facingDirection: state?.facingDirection ?? original.facingDirection,
                zOrder: state?.zOrder ?? original.zOrder, rockIsForeground: state?.rockIsForeground ?? original.rockIsForeground,
                isStackingOrderInitialized: state?.isStackingOrderInitialized ?? original.isStackingOrderInitialized)
            // 未対応種別も保存値は保持する。仮岩や正式素材へ置換しない。
            copy.kindRawValue = original.kindRawValue
            if original.kind == .unsupported { copy.facingDirectionRawValue = original.facingDirectionRawValue }
            return copy
        }
    }
    /// 編集中の購入は所有データの追加。既存の配置・魚・履歴を変更せず、未配置のコピーだけを取り込む。
    func includeNewlyOwnedDecorations(_ official: [AquariumDecorationPlacement]) -> [AquariumEditorDraft.Placement] {
        let existingIDs = Set(placements.map(\.decorationID))
        let added = official.filter { $0.kind.isAvailable && !existingIDs.contains($0.decorationID) }
        guard !added.isEmpty else { return [] }
        let baseline = AquariumEditorDraft(player: player, placements: added, background: .aquarium)
        let detached = AquariumEditorWorkingState(official: player, placements: added, draft: baseline)
        placements.append(contentsOf: detached.placements)
        return baseline.placements
    }

    func apply(_ draft: AquariumEditorDraft) {
        let ownedIDs = Set(player.ownedFish.map(\.id))
        player.activeAquariumFishIDs = draft.fishIDs.filter { ownedIDs.contains($0) }
        let byID = Dictionary(uniqueKeysWithValues: draft.placements.map { ($0.id, $0) })
        for placement in placements {
            guard let state = byID[placement.decorationID], state.kind == placement.kindRawValue else { continue }
            placement.relativeX = state.x
            placement.relativeY = state.y
            placement.scale = state.scale
            placement.isPlaced = state.isPlaced
            placement.facingDirection = state.facingDirection
            placement.zOrder = state.zOrder
            placement.rockIsForeground = state.rockIsForeground
            placement.isStackingOrderInitialized = state.isStackingOrderInitialized
        }
    }

}

/// A single commit boundary; a future history stack can operate on draft values above it.
@MainActor
enum AquariumEditorCommit {
    static func apply(_ updated: AquariumEditorSessionSnapshot, to official: Player,
                      placements: [AquariumDecorationPlacement], background: AquariumBackgroundTheme,
                      save: () throws -> Void) throws {
        let previous = AquariumEditorSessionSnapshot.capture(player: official,
            decorationPlacements: placements, backgroundTheme: background)
        updated.restore(player: official, decorationPlacements: placements)
        do { try save() }
        catch {
            previous.restore(player: official, decorationPlacements: placements)
            throw error
        }
    }
}
