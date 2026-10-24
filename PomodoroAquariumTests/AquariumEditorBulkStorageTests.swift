import Foundation
import Testing
@testable import PomodoroAquarium

@MainActor
struct AquariumEditorBulkStorageTests {
    private func fixture() -> (Player, [AquariumDecorationPlacement], AquariumEditorDraft) {
        let fish = [FishSpecies.clownfish, .clownfish, .clownfish, .whaleShark, .manta, .manta].map { PlayerFish(species: $0) }
        let player = Player(ownedFish: fish, activeAquariumFishIDs: fish.map(\.id), hasInitializedActiveAquariumFish: true, coins: 130)
        let placements = [AquariumDecorationKind.seaweedA, .smallRockA, .mediumRockC, .coralAPink, .smallRockB].enumerated().map { index, kind in
            AquariumDecorationPlacement(kind: kind, relativeX: -0.1 + Double(index) * 0.2,
                relativeY: 0.7 + Double(index) * 0.04, scale: 1 + Double(index) * 0.1, isPlaced: index != 4)
        }
        return (player, placements, AquariumEditorDraft(player: player, placements: placements, background: .deepSea))
    }
    @Test(arguments: AquariumDecorationCategory.allCases)
    func categoryStoragePreservesOtherKindsOwnershipAndOneStepHistory(category: AquariumDecorationCategory) throws {
        let official = Player(ownedFish: [PlayerFish(species: .clownfish)], coins: 130)
        let placements = AquariumDecorationKind.availableKinds.flatMap { kind in
            [AquariumDecorationPlacement(kind: kind, relativeX: 0.3, relativeY: 0.8,
                scale: 1.2, isPlaced: true),
             AquariumDecorationPlacement(kind: kind, relativeX: 0.6, relativeY: 0.9,
                scale: 0.8, isPlaced: false)]
        }
        let before = AquariumEditorDraft(player: official, placements: placements, background: .deepSea)
        let work = AquariumEditorWorkingState(official: official, placements: placements, draft: before)
        let target = AquariumEditorBulkStorage.decorationCategory(category)
        let expectedKinds: Set<AquariumDecorationKind>
        let expectedTitle: String
        switch category {
        case .plant:
            expectedKinds = [.seaweedA, .seaweedB, .seaweedC]
            expectedTitle = "海藻を全部しまう"
        case .rock:
            expectedKinds = [.smallRockA, .smallRockB, .smallRockC, .mediumRockA, .mediumRockB, .mediumRockC]
            expectedTitle = "岩を全部しまう"
        case .coral:
            expectedKinds = [.coralAPink, .coralAOrange, .coralAPurple, .coralBPink, .coralBOrange,
                .coralBPurple, .coralCPink, .coralCOrange, .coralCPurple]
            expectedTitle = "サンゴを全部しまう"
        case .object:
            expectedKinds = [.treasureChest, .shipwreck]
            expectedTitle = "その他を全部しまう"
        }
        #expect(target.buttonTitle == expectedTitle)
        #expect(AquariumEditorBulkStorage.decorations.buttonTitle == "装飾を全部しまう")
        let after = try #require(target.applying(to: before))
        for original in before.snapshot.placements {
            var expected = original
            if expectedKinds.contains(AquariumDecorationKind(rawValue: original.kind)!) {
                expected.isPlaced = false
            }
            #expect(after.placements.first { $0.id == original.id } == expected)
        }
        #expect(after.fishIDs == before.fishIDs && after.background == before.background)
        #expect(target.applying(to: after) == nil)
        work.apply(after)
        var history = AquariumEditorHistory(initial: before)
        let recorded = history.record(after)
        #expect(recorded)
        #expect(history.states.count == 2 && history.position == 1)
        let undoResult = history.undo()
        let undone = try #require(undoResult)
        work.apply(undone)
        #expect(AquariumEditorDraft(player: work.player, placements: work.placements, background: .deepSea).snapshot == before.snapshot)
        let redoResult = history.redo()
        let redone = try #require(redoResult)
        work.apply(redone)
        #expect(AquariumEditorDraft(player: work.player, placements: work.placements, background: .deepSea).snapshot == after)
        // 編集内容はdetachedのWorkingStateだけ。キャンセルで破棄しても正式データは元のまま。
        #expect(AquariumEditorDraft(player: official, placements: placements, background: .deepSea).snapshot == before.snapshot)
        #expect(work.placements.count == placements.count)
        #expect(work.placements.filter { !$0.isPlaced }.allSatisfy { placement in
            AquariumDecorationEditorPresentation.inventory(from: work.placements).contains { $0.kind == placement.kind }
        })
        var persisted = after
        persisted.history = history
        let store = AquariumEditorDraftStore(url: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        defer { try? store.remove() }
        try store.save(persisted)
        let loaded = try #require(try store.load())
        var restoredHistory = try #require(loaded.history)
        #expect(restoredHistory.isValid(for: loaded))
        let restoredUndo = restoredHistory.undo()
        let restoredRedo = restoredHistory.redo()
        #expect(restoredUndo?.snapshot == before.snapshot)
        #expect(restoredRedo?.snapshot == after)
        let updated = AquariumEditorSessionSnapshot.capture(player: work.player,
            decorationPlacements: work.placements, backgroundTheme: .deepSea)
        try AquariumEditorCommit.apply(updated, to: official, placements: placements, background: .deepSea) {}
        #expect(AquariumEditorDraft(player: official, placements: placements, background: .deepSea).snapshot == after)
        #expect(official.coins == 130 && official.ownedFish.count == 1)
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
