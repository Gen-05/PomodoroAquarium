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
        guard draft.version == 1, AquariumBackgroundTheme(rawValue: draft.background) != nil,
              Set(draft.fishIDs).count == draft.fishIDs.count,
              Set(draft.placements.map(\.id)).count == draft.placements.count,
              draft.placements.allSatisfy({ $0.x.isFinite && $0.y.isFinite && $0.scale.isFinite && $0.scale > 0 }) else {
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
