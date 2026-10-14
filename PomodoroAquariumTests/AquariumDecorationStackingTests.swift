import Foundation
import SwiftData
import Testing
@testable import PomodoroAquarium

@MainActor
struct AquariumDecorationStackingTests {
    private func placed(_ kind: AquariumDecorationKind, id: String, y: Double = 0.9) -> AquariumDecorationPlacement {
        AquariumDecorationPlacement(decorationID: id, kind: kind, relativeX: 0.5, relativeY: y, scale: 1)
    }
    private func ids(_ items: [AquariumDecorationPlacement]) -> [String] {
        items.filter(\.isPlaced).sorted { AquariumDecorationStacking.isBehind($0.decoration, $1.decoration) }.map(\.decorationID)
    }
    @Test func fourActionsCrossKindsAndEndpointNoOps() {
        let rock = placed(.smallRockA, id: "rock")
        let seaweed = placed(.seaweedA, id: "seaweed")
        let coral = placed(.coralAPink, id: "coral")
        let chest = placed(.treasureChest, id: "chest")
        let all = [rock, seaweed, coral, chest]
        for item in all { AquariumDecorationStacking.insertNew(item, among: all.filter { $0 === item || $0.isStackingOrderInitialized }) }
        #expect(ids(all) == ["rock", "seaweed", "coral", "chest"])
        #expect(AquariumDecorationStacking.move(seaweed, action: .forward, among: all))
        #expect(ids(all) == ["rock", "coral", "seaweed", "chest"])
        #expect(AquariumDecorationStacking.move(seaweed, action: .backward, among: all))
        #expect(ids(all) == ["rock", "seaweed", "coral", "chest"])
        #expect(AquariumDecorationStacking.move(rock, action: .front, among: all))
        #expect(ids(all) == ["seaweed", "coral", "chest", "rock"])
        let front = all.map(\.zOrder)
        #expect(!AquariumDecorationStacking.canMove(rock, action: .forward, among: all))
        #expect(!AquariumDecorationStacking.move(rock, action: .front, among: all))
        #expect(all.map(\.zOrder) == front)
        #expect(AquariumDecorationStacking.move(rock, action: .back, among: all))
        #expect(AquariumDecorationStacking.move(seaweed, action: .back, among: all))
        #expect(ids(all).first == "seaweed")
        #expect(!AquariumDecorationStacking.move(seaweed, action: .backward, among: all))
        let duplicate = placed(.smallRockA, id: "rock2")
        let extended = all + [duplicate]
        AquariumDecorationStacking.insertNew(duplicate, among: extended)
        #expect(ids(extended).first == "rock2")
        #expect(AquariumDecorationStacking.move(duplicate, action: .front, among: extended))
        #expect(ids(extended).last == "rock2" && rock.decorationID == "rock")
        let stable = ids(extended)
        rock.relativeY = 0.7; coral.relativeY = 0.99
        #expect(ids(extended) == stable)
    }
    @Test func historyDraftCommitAndBulkStorageKeepOrderAndIDs() throws {
        let player = Player()
        let official = [placed(.mediumRockB, id: "rock"), placed(.treasureChest, id: "chest")]
        let start = AquariumEditorDraft(player: player, placements: official, background: .aquarium)
        let work = AquariumEditorWorkingState(official: player, placements: official, draft: start)
        var history = AquariumEditorHistory(initial: start)
        let rock = work.placements[0]
        #expect(AquariumDecorationStacking.move(rock, action: .front, among: work.placements))
        let changed = AquariumEditorDraft(player: work.player, placements: work.placements, background: .aquarium)
        let recorded = history.record(changed); #expect(recorded)
        #expect(official[0].zOrder == 0 && !official[0].isStackingOrderInitialized)
        let undone = history.undo(); work.apply(try #require(undone))
        #expect(ids(work.placements) == ["rock", "chest"])
        let redone = history.redo(); work.apply(try #require(redone))
        #expect(ids(work.placements) == ["chest", "rock"])
        let stored = try #require(AquariumEditorBulkStorage.decorations.applying(to: changed))
        let recordedStorage = history.record(stored); #expect(recordedStorage)
        work.apply(stored)
        #expect(work.placements.allSatisfy { !$0.isPlaced })
        let unstored = history.undo(); work.apply(try #require(unstored))
        #expect(ids(work.placements) == ["chest", "rock"] && rock.relativeY == 0.9)
        var persisted = changed; persisted.history = history
        let restored = try JSONDecoder().decode(AquariumEditorDraft.self, from: JSONEncoder().encode(persisted))
        #expect(restored == persisted && restored.history?.isValid(for: restored) == true)
        let snapshot = AquariumEditorSessionSnapshot.capture(player: work.player, decorationPlacements: work.placements, backgroundTheme: .aquarium)
        try AquariumEditorCommit.apply(snapshot, to: player, placements: official, background: .aquarium, save: {})
        #expect(ids(official) == ["chest", "rock"] && official[0].isStackingOrderInitialized)
    }
    @Test func legacyOrderIsFrozenWithoutChangingGeometryOrBreakingHistory() throws {
        let rock = placed(.smallRockA, id: "old-rock", y: 0.98)
        let seaweed = placed(.seaweedA, id: "old-seaweed", y: 0.8)
        let chest = placed(.treasureChest, id: "old-chest", y: 0.7)
        let all = [chest, rock, seaweed]
        let before = ids(all)
        let draft = AquariumEditorDraft(player: Player(), placements: all, background: .aquarium)
        let work = AquariumEditorWorkingState(official: Player(), placements: all, draft: draft)
        #expect(ids(work.placements) == before && draft.placements.allSatisfy(\.isStackingOrderInitialized))
        #expect(work.placements.map(\.relativeY) == all.map(\.relativeY))
        for item in work.placements { item.relativeY = 1 - item.relativeY }
        #expect(ids(work.placements) == before)
        // Simulate an old session including old history states without the new metadata.
        var saved = draft; saved.history = AquariumEditorHistory(initial: draft)
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(saved)) as? [String: Any])
        func legacy(_ p: [String: Any]) -> [String: Any] {
            var copy = p; copy.removeValue(forKey: "isStackingOrderInitialized"); copy.removeValue(forKey: "zOrder"); return copy
        }
        json["placements"] = (json["placements"] as! [[String: Any]]).map(legacy)
        var h = json["history"] as! [String: Any]
        var states = h["states"] as! [[String: Any]]
        states[0]["placements"] = (states[0]["placements"] as! [[String: Any]]).map(legacy)
        h["states"] = states; json["history"] = h
        let restored = try JSONDecoder().decode(AquariumEditorDraft.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(restored.history?.isValid(for: restored) == true)
    }
    @Test func stableTieAndSwiftDataRoundTrip() throws {
        let a = placed(.smallRockA, id: "a"), b = placed(.smallRockA, id: "b")
        for p in [a,b] { p.zOrder = 7; p.isStackingOrderInitialized = true }
        #expect(ids([b,a]) == ["a", "b"])
        let container = try ModelContainer(for: AquariumDecorationPlacement.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        container.mainContext.insert(a); try container.mainContext.save()
        let restored = try #require(ModelContext(container).fetch(FetchDescriptor<AquariumDecorationPlacement>()).first)
        #expect(restored.zOrder == 7 && restored.isStackingOrderInitialized && restored.decorationID == "a")
    }
}
