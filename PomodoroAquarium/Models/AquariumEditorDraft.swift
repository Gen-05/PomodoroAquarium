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
                      y: $0.relativeY, scale: $0.scale, isPlaced: $0.isPlaced)
        }
        self.background = background.rawValue
    }
    var snapshot: Self {
        var copy = self
        copy.history = nil
        copy.placements.sort { $0.id < $1.id }
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
        let draft = try JSONDecoder().decode(AquariumEditorDraft.self, from: Data(contentsOf: url))
        guard draft.isValid else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return draft
    }
    func save(_ draft: AquariumEditorDraft) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(draft).write(to: url, options: .atomic)
    }
    func remove() throws {
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }
}

@MainActor @Observable
final class AquariumEditorWorkingState {
    let player: Player
    let placements: [AquariumDecorationPlacement]
    init(official: Player, placements: [AquariumDecorationPlacement], draft: AquariumEditorDraft) {
        // Every model is detached; no relationship points into the official context.
        player = Player(ownedFish: official.ownedFish.map { PlayerFish(id: $0.id, species: $0.species) },
                        activeAquariumFishIDs: draft.fishIDs.filter { id in official.ownedFish.contains { $0.id == id } },
                        hasInitializedActiveAquariumFish: true,
                        coreTutorialRewardFishID: official.coreTutorialRewardFishID)
        let states = Dictionary(uniqueKeysWithValues: draft.placements.map { ($0.id, $0) })
        self.placements = placements.map { original in
            let state = states[original.decorationID]
            return AquariumDecorationPlacement(decorationID: original.decorationID, kind: original.kind,
                relativeX: state?.x ?? original.relativeX, relativeY: state?.y ?? original.relativeY,
                scale: state?.scale ?? original.scale, isPlaced: state?.isPlaced ?? original.isPlaced)
        }
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
