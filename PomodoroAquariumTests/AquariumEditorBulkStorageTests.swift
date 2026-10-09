import Foundation
import Testing
@testable import PomodoroAquarium

@MainActor
struct AquariumEditorBulkStorageTests {
    private func fixture() -> (Player, [AquariumDecorationPlacement], AquariumEditorDraft) {
        let fish = [FishSpecies.clownfish, .clownfish, .clownfish, .whaleShark, .manta, .manta].map { PlayerFish(species: $0) }
        let player = Player(ownedFish: fish, activeAquariumFishIDs: fish.map(\.id), hasInitializedActiveAquariumFish: true, coins: 130)
        let placements = [AquariumDecorationKind.seaweedA, .smallRockA, .mediumRockC, .coralAPink, .rock].enumerated().map { index, kind in
            AquariumDecorationPlacement(kind: kind, relativeX: -0.1 + Double(index) * 0.2,
                relativeY: 0.7 + Double(index) * 0.04, scale: 1 + Double(index) * 0.1, isPlaced: index != 4)
        }
        return (player, placements, AquariumEditorDraft(player: player, placements: placements, background: .deepSea))
    }
    @Test(arguments: [AquariumEditorBulkStorage.fish, .decorations])
    func eachBulkEditIsIndependentAndOneUndoRestoresAll(target: AquariumEditorBulkStorage) throws {
        let (official, placements, before) = fixture()
        let work = AquariumEditorWorkingState(official: official, placements: placements, draft: before)
        let after = try #require(target.applying(to: before))
        work.apply(after)
        var history = AquariumEditorHistory(initial: before)
        let recorded = history.record(after)
        #expect(recorded && history.states.count == 2 && history.position == 1)
        #expect(target.applying(to: after) == nil)
        #expect(after.background == before.background)
        if target == .fish {
            #expect(work.player.activeAquariumFish.isEmpty)
            #expect(after.placements == before.snapshot.placements)
        } else {
            #expect(!work.placements.contains { $0.isPlaced })
            #expect(after.fishIDs == before.fishIDs)
        }
        let undone = history.undo()
        work.apply(try #require(undone))
        #expect(AquariumEditorDraft(player: work.player, placements: work.placements, background: .deepSea).snapshot == before.snapshot)
        let redone = history.redo()
        work.apply(try #require(redone))
        #expect(AquariumEditorDraft(player: work.player, placements: work.placements, background: .deepSea).snapshot == after)
        #expect(work.player.ownedFish.map(\.id) == official.ownedFish.map(\.id))
        #expect(work.placements.map(\.decorationID) == placements.map(\.decorationID))
        #expect(official.activeAquariumFishIDs == before.fishIDs && official.coins == 130)
        #expect(placements.filter(\.isPlaced).count == 4)
    }
    @Test(arguments: [AquariumEditorBulkStorage.fish, .decorations])
    func savedBulkEditRestoresUndoAfterRestart(target: AquariumEditorBulkStorage) throws {
        let (official, placements, before) = fixture()
        var after = try #require(target.applying(to: before))
        var history = AquariumEditorHistory(initial: before)
        history.record(after)
        after.history = history
        let store = AquariumEditorDraftStore(url: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        defer { try? store.remove() }
        try store.save(after)
        let loaded = try #require(try store.load())
        var resumedHistory = try #require(loaded.history)
        #expect(resumedHistory.isValid(for: loaded))
        let work = AquariumEditorWorkingState(official: official, placements: placements, draft: loaded)
        let undone = resumedHistory.undo()
        work.apply(try #require(undone))
        #expect(AquariumEditorDraft(player: work.player, placements: work.placements, background: .deepSea).snapshot == before.snapshot)
        let redone = resumedHistory.redo()
        work.apply(try #require(redone))
        #expect(AquariumEditorDraft(player: work.player, placements: work.placements, background: .deepSea).snapshot == after.snapshot)
        // Existing formal commit accepts an empty aquarium without deleting ownership.
        AquariumEditorSessionSnapshot.capture(player: work.player, decorationPlacements: work.placements, backgroundTheme: .deepSea)
            .restore(player: official, decorationPlacements: placements)
        #expect(official.ownedFish.count == 6 && official.coins == 130)
        #expect(placements.count == 5)
        if target == .fish { #expect(official.activeAquariumFishIDs.isEmpty) }
        else { #expect(!placements.contains { $0.isPlaced }) }
    }
}
