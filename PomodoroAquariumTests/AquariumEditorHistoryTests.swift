import Foundation
import Testing
@testable import PomodoroAquarium

@MainActor
struct AquariumEditorHistoryTests {
    private func initial() -> AquariumEditorDraft {
        AquariumEditorDraft(player: Player(), placements: [], background: .aquarium)
    }
    @Test func branchingNoOpsAndThirtyOperationLimit() {
        let start = initial()
        var history = AquariumEditorHistory(initial: start)
        #expect(!history.canUndo && !history.canRedo)
        let result1 = !history.record(start); #expect(result1)
        var state = start
        for i in 0..<35 {
            state.fishIDs.append(UUID())
            let result2 = history.record(state); #expect(result2)
            #expect(history.position == min(i + 1, 30))
        }
        #expect(history.states.count == 31)
        for _ in 0..<30 { let result3 = history.undo() != nil; #expect(result3) }
        let result4 = history.undo() == nil; #expect(result4)
        #expect(history.current.fishIDs.count == 5)
        for _ in 0..<30 { let result5 = history.redo() != nil; #expect(result5) }
        let result6 = history.redo() == nil; #expect(result6)
        let result7 = history.undo() != nil; #expect(result7)
        var branch = history.current
        branch.background = AquariumBackgroundTheme.deepSea.rawValue
        let result8 = history.record(branch); #expect(result8)
        #expect(!history.canRedo)
        let result9 = !history.record(branch); #expect(result9)
    }
    @Test func IDsCoordinatesDepthScaleAndOwnershipSurviveUndoRedo() {
        let fish = PlayerFish(species: .clownfish)
        let official = Player(ownedFish: [fish], coins: 80)
        let rock = AquariumDecorationPlacement(kind: .rock, relativeX: 0.2, relativeY: 0.8, scale: 1, isPlaced: false)
        let start = AquariumEditorDraft(player: official, placements: [rock], background: .aquarium)
        let work = AquariumEditorWorkingState(official: official, placements: [rock], draft: start)
        var history = AquariumEditorHistory(initial: start)
        work.player.activeAquariumFishIDs = [fish.id]
        work.placements[0].isPlaced = true
        let added = AquariumEditorDraft(player: work.player, placements: work.placements, background: .aquarium)
        history.record(added) // One grouped operation also supports future bulk storage.
        work.placements[0].relativeX = -0.1
        work.placements[0].relativeY = 0.7
        work.placements[0].scale = 1.2
        let moved = AquariumEditorDraft(player: work.player, placements: work.placements, background: .deepSea)
        history.record(moved)
        work.apply(history.undo()!)
        #expect(work.placements[0].relativeX == 0.2 && work.placements[0].relativeY == 0.8)
        work.apply(history.undo()!)
        #expect(work.player.activeAquariumFishIDs.isEmpty && !work.placements[0].isPlaced)
        work.apply(history.redo()!)
        #expect(work.player.activeAquariumFishIDs == [fish.id])
        work.apply(history.redo()!)
        #expect(work.placements[0].decorationID == rock.decorationID)
        #expect(work.placements[0].relativeX == -0.1 && work.placements[0].relativeY == 0.7 && work.placements[0].scale == 1.2)
        #expect(official.activeAquariumFishIDs.isEmpty && !rock.isPlaced)
        #expect(official.ownedFish.count == 1 && official.coins == 80)
    }
    @Test func atomicHistoryRoundTripAndBrokenHistoryKeepCurrentDraft() throws {
        var draft = initial()
        var history = AquariumEditorHistory(initial: draft)
        draft.background = AquariumBackgroundTheme.tropical.rawValue
        history.record(draft)
        draft.background = AquariumBackgroundTheme.deepSea.rawValue
        history.record(draft)
        draft = history.undo()!
        draft.history = history
        let store = AquariumEditorDraftStore(url: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        defer { try? store.remove() }
        try store.save(draft)
        var loaded = try #require(try store.load())
        #expect(loaded.history?.isValid(for: loaded) == true)
        let result10 = loaded.history?.redo()?.background == AquariumBackgroundTheme.deepSea.rawValue; #expect(result10)
        var object = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: store.url)) as? [String: Any])
        object["history"] = ["bad": true]
        try JSONSerialization.data(withJSONObject: object).write(to: store.url, options: .atomic)
        loaded = try #require(try store.load())
        #expect(loaded.snapshot == draft.snapshot && loaded.history == nil)
        object.removeValue(forKey: "history")
        try JSONSerialization.data(withJSONObject: object).write(to: store.url)
        #expect(try store.load()?.history == nil) // Stage 1 file remains readable.
        var inconsistent = history
        _ = inconsistent.undo()
        #expect(!inconsistent.isValid(for: draft))
        try store.remove()
        #expect(try store.load() == nil)
    }
}
