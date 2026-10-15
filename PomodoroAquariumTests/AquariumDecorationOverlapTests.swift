import Foundation
import CoreGraphics
import Testing
@testable import PomodoroAquarium

@MainActor
struct AquariumDecorationOverlapTests {
    private let size = CGSize(width: 393, height: 874)
    private func item(_ id: String, x: Double, y: Double = 0.78, z: Int, kind: AquariumDecorationKind = .smallRockB, scale: Double = 1) -> AquariumDecorationPlacement {
        AquariumDecorationPlacement(decorationID: id, kind: kind, relativeX: x, relativeY: y,
            scale: scale, zOrder: z, isStackingOrderInitialized: true)
    }
    private func members(_ id: String, _ items: [AquariumDecorationPlacement], size: CGSize? = nil) -> Set<String> {
        AquariumDecorationOverlapGroups.members(of: id, placements: items, size: size ?? self.size, theme: .aquarium)
    }
    @Test func thirtyItemsOnlyDirectNeighborsMoveAndDistantSlotsStayUntouched() {
        let a = item("a", x: 0.25, z: 1), b = item("b", x: 0.40, z: 5), c = item("c", x: 0.55, z: 9)
        let distantRanks = Array(1...30).filter { ![1,5,9].contains($0) }
        let distant = distantRanks.enumerated().map { index, rank in item("d-\(index)", x: 0.86 + Double(index % 3 - 1) * 0.012, y: 0.94 + Double((index / 3) % 3) * 0.012, z: rank) }
        let all = [a,b,c] + distant
        #expect(all.count == 30)
        #expect(members("a", all) == ["a","b"])
        #expect(members("b", all) == ["a","b","c"])
        #expect(members("c", all) == ["b","c"])
        let shapeA = AquariumDecorationHitTesting.overlapShape(for: a.decoration, aquariumSize: size, theme: .aquarium)
        let shapeC = AquariumDecorationHitTesting.overlapShape(for: c.decoration, aquariumSize: size, theme: .aquarium)
        #expect(!shapeA.overlaps(shapeC)) // Bを介した連結。
        let before = distant.map(\.zOrder)
        #expect(AquariumDecorationStacking.move(a, action: .front, among: all, within: members("a", all)))
        #expect(a.zOrder == 5 && b.zOrder == 1 && c.zOrder == 9)
        #expect(!AquariumDecorationStacking.move(a, action: .forward, among: all, within: members("a", all)))
        for action in [AquariumDecorationStacking.Action.forward, .front, .backward, .back] {
            #expect(AquariumDecorationStacking.move(b, action: action, among: all, within: members("b", all)))
            #expect(distant.map(\.zOrder) == before)
            #expect([a,b,c].map(\.zOrder).sorted() == [1,5,9])
        }
        for other in distant {
            #expect(members(other.decorationID, all).isDisjoint(with: ["a","b","c"]))
        }
    }
    @Test func movingStoringAndRestoringRecomputeConnectivityWithoutChangingOrder() {
        let a = item("a", x: 0.25, z: 1), b = item("b", x: 0.40, z: 2), c = item("c", x: 0.55, z: 3)
        let all = [a,b,c]
        #expect(members("a", all) == ["a","b"])
        b.relativeX = 0.95
        #expect(members("a", all) == ["a"] && members("c", all) == ["c"])
        for action in AquariumDecorationStacking.Action.allCases {
            #expect(!AquariumDecorationStacking.canMove(a, action: action, among: all, within: members("a", all)))
        }
        b.relativeX = 0.40
        #expect(members("a", all) == ["a","b"])
        b.isPlaced = false
        #expect(members("a", all) == ["a"])
        b.isPlaced = true
        #expect(members("a", all) == ["a","b"])
        #expect(all.map(\.zOrder) == [1,2,3])
    }
    @Test func chestTransparentCanvasDoesNotConnectAndMeaningfulBodyOverlapDoes() {
        let canvas = CGSize(width: 500, height: 900)
        let chest = item("chest", x: 0.5, y: 0.9, z: 1, kind: .treasureChest)
        let small = item("small", x: 0.5, y: 0.9, z: 2, kind: .smallRockA, scale: 0.2)
        for direction in AquariumDecorationFacingDirection.allCases {
            chest.facingDirection = direction
            let shape = AquariumDecorationHitTesting.overlapShape(for: chest.decoration, aquariumSize: canvas, theme: .aquarium)
            small.relativeX = (shape.rect.minX + shape.rect.width * 0.05) / canvas.width
            small.relativeY = (shape.rect.minY + shape.rect.height * 0.10) / canvas.height
            let tiny = AquariumDecorationHitTesting.overlapShape(for: small.decoration, aquariumSize: canvas, theme: .aquarium)
            #expect(!shape.rect.intersection(tiny.rect).isNull)
            #expect(members("chest", [chest, small], size: canvas) == ["chest"])
            small.relativeX = (shape.rect.minX + shape.rect.width * 0.5) / canvas.width
            small.relativeY = (shape.rect.minY + shape.rect.height * 0.8) / canvas.height
            #expect(members("chest", [chest, small], size: canvas) == ["chest","small"])
        }
        let mask = [UInt8](repeating: 255, count: 96 * 96)
        let rect = CGRect(x: 0,y: 0,width: 100,height: 100)
        let a = AquariumDecorationHitTesting.OverlapShape(rect: rect, visibleBounds: rect, mask: mask, visibleArea: 10000)
        let touching = rect.offsetBy(dx: 99.5, dy: 0)
        let b = AquariumDecorationHitTesting.OverlapShape(rect: touching, visibleBounds: touching, mask: mask, visibleArea: 10000)
        #expect(!a.overlaps(b))
    }
    @Test func localOrderUndoRedoAndSavedHistoryPreserveDistantPlacement() throws {
        let official = [item("a",x: 0.25,z: 1), item("b",x: 0.40,z: 5), item("c",x: 0.55,z: 9), item("far",x: 0.95,z: 3)]
        let player = Player()
        let initial = AquariumEditorDraft(player: player, placements: official, background: .aquarium)
        let work = AquariumEditorWorkingState(official: player, placements: official, draft: initial)
        var history = AquariumEditorHistory(initial: initial)
        let a = work.placements[0]
        #expect(AquariumDecorationStacking.move(a, action: .front, among: work.placements, within: members("a", work.placements)))
        let changed = AquariumEditorDraft(player: work.player, placements: work.placements, background: .aquarium)
        let recorded = history.record(changed); #expect(recorded && history.position == 1)
        #expect(official[0].zOrder == 1 && work.placements[3].zOrder == 3)
        let undone = history.undo(); work.apply(try #require(undone)); #expect(a.zOrder == 1)
        var saved = AquariumEditorDraft(player: work.player, placements: work.placements, background: .aquarium)
        saved.history = history
        let restored = try JSONDecoder().decode(AquariumEditorDraft.self, from: JSONEncoder().encode(saved))
        var restoredHistory = try #require(restored.history)
        #expect(restoredHistory.isValid(for: restored))
        let redone = restoredHistory.redo(); work.apply(try #require(redone))
        #expect(a.zOrder == 5 && work.placements[3].zOrder == 3)
        #expect(members("a", work.placements) == ["a","b"])
        #expect(work.placements.map(\.decorationID) == official.map(\.decorationID))
    }
}
