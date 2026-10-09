import Foundation
import Testing
@testable import PomodoroAquarium

@MainActor
struct AquariumEditorDraftTests {
    private func fixture() -> (Player, AquariumDecorationPlacement) {
        let fish = PlayerFish(species: .clownfish)
        return (Player(ownedFish: [fish], activeAquariumFishIDs: [fish.id], hasInitializedActiveAquariumFish: true, coins: 123),
                AquariumDecorationPlacement(kind: .seaweed, relativeX: 0.2, relativeY: 0.8, scale: 1.1))
    }

    @Test func editsAreIndependentAndRoundTripWithoutDuplicatingIndividuals() throws {
        let (official, placement) = fixture()
        let initial = AquariumEditorDraft(player: official, placements: [placement], background: .aquarium)
        let work = AquariumEditorWorkingState(official: official, placements: [placement], draft: initial)
        work.player.activeAquariumFishIDs = []
        work.placements[0].relativeX = -0.1
        work.placements[0].relativeY = 0.72
        work.placements[0].scale = 1.3
        #expect(official.activeAquariumFishIDs == initial.fishIDs)
        #expect(placement.relativeX == 0.2)
        #expect(official.coins == 123)
        #expect(work.player.ownedFish[0] !== official.ownedFish[0])
        let store = AquariumEditorDraftStore(url: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("draft.json"))
        defer { try? FileManager.default.removeItem(at: store.url.deletingLastPathComponent()) }
        let changed = AquariumEditorDraft(player: work.player, placements: work.placements, background: .deepSea)
        try store.save(changed)
        let loaded = try #require(try store.load())
        #expect(loaded == changed)
        let resumed = AquariumEditorWorkingState(official: official, placements: [placement], draft: loaded)
        #expect(resumed.placements.count == 1)
        #expect(resumed.placements[0].decorationID == placement.decorationID)
        #expect(resumed.placements[0].relativeX == -0.1)
        #expect(resumed.player.activeAquariumFishIDs.isEmpty)
        try store.remove()
        #expect(try store.load() == nil)
        #expect(official.ownedFish.count == 1 && official.coins == 123)
    }

    @Test func corruptDraftAndWriteFailureDoNotChangeOfficialData() throws {
        let (official, placement) = fixture()
        let original = AquariumEditorDraft(player: official, placements: [placement], background: .aquarium)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("broken".utf8).write(to: url)
        let store = AquariumEditorDraftStore(url: url)
        #expect(throws: (any Error).self) { try store.load() }
        let impossible = AquariumEditorDraftStore(url: url.appendingPathComponent("draft.json"))
        #expect(throws: (any Error).self) { try impossible.save(original) }
        #expect(AquariumEditorDraft(player: official, placements: [placement], background: .aquarium) == original)
    }

    @Test func commitCopiesOnlyAquariumState() throws {
        let (official, placement) = fixture()
        let draft = AquariumEditorDraft(player: official, placements: [placement], background: .aquarium)
        let work = AquariumEditorWorkingState(official: official, placements: [placement], draft: draft)
        work.player.activeAquariumFishIDs = []
        work.placements[0].isPlaced = false
        AquariumEditorSessionSnapshot.capture(player: work.player, decorationPlacements: work.placements, backgroundTheme: .tropical)
            .restore(player: official, decorationPlacements: [placement])
        #expect(official.activeAquariumFishIDs.isEmpty)
        #expect(!placement.isPlaced)
        #expect(official.ownedFish.count == 1 && official.coins == 123)
    }
    @Test func failedCommitRestoresOfficialValuesAndKeepsWorkingCopy() throws {
        let (official, placement) = fixture()
        let draft = AquariumEditorDraft(player: official, placements: [placement], background: .aquarium)
        let work = AquariumEditorWorkingState(official: official, placements: [placement], draft: draft)
        work.player.activeAquariumFishIDs = []
        work.placements[0].relativeY = 0.7
        let updated = AquariumEditorSessionSnapshot.capture(player: work.player,
            decorationPlacements: work.placements, backgroundTheme: .deepSea)
        #expect(throws: (any Error).self) {
            try AquariumEditorCommit.apply(updated, to: official, placements: [placement], background: .aquarium) {
                throw CocoaError(.fileWriteUnknown)
            }
        }
        #expect(official.activeAquariumFishIDs == draft.fishIDs)
        #expect(placement.relativeY == 0.8)
        #expect(work.player.activeAquariumFishIDs.isEmpty)
        #expect(work.placements[0].relativeY == 0.7)
    }

}
