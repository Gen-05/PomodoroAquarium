import Foundation
import SwiftData
import Testing
import UIKit
import SwiftUI
@testable import PomodoroAquarium

@MainActor
struct AquariumTreasureChestTests {
    @Test func definitionAssetsAndDebugOwnershipUseExistingRules() throws {
        let kind = AquariumDecorationKind.treasureChest
        #expect(kind.displayName == "宝箱" && kind.stars == 3 && kind.plannedPrice == 500)
        #expect(kind.category == .object && kind.renderLayer == .object)
        #expect(kind.animationFrameNames.isEmpty && kind.supportsFacingDirection)
        #expect(!AquariumDecorationService.defaultDecorations.contains { $0.kind == kind })
        #expect(!ShopCatalog.items.contains { $0.content == .decoration(kind) })
        for theme in AquariumBackgroundTheme.allCases {
            for direction in AquariumDecorationFacingDirection.allCases {
                let name = try #require(kind.assetImageName(for: theme, facingDirection: direction))
                let image = try #require(UIImage(named: name))
                #expect(image.size == CGSize(width: 1254, height: 1254))
                #expect(kind.groundAnchorY(facingDirection: direction) == (direction == .right ? 1239.0 : 1228.0) / 1254)
            }
        }
        #expect(abs(kind.displaySize.width * 1115 / 1254 - 126) < 0.000001)
        #expect(kind.displaySize.height == kind.displaySize.width)
        #expect(abs(kind.displaySize.width - AquariumTreasureChestEffects.canvasSide) < 0.000001)
        for other in AquariumDecorationKind.allCases where other != kind { #expect(!other.supportsFacingDirection) }
        let container = try ModelContainer(for: AquariumDecorationPlacement.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        try AquariumDeveloperDecorations.seedIfNeeded(in: context)
        let chests = try context.fetch(FetchDescriptor<AquariumDecorationPlacement>()).filter { $0.kind == kind }
        #if DEBUG
        #expect(chests.count == AquariumDeveloperDecorations.ownedCountPerDecoration)
        #expect(chests.allSatisfy { !$0.isPlaced })
        let first = try #require(chests.first)
        first.isPlaced = true; first.facingDirection = .left; try context.save()
        #expect(try AquariumDeveloperDecorations.seedIfNeeded(in: context) == false)
        #expect(first.facingDirection == .left && first.isPlaced)
        #else
        #expect(chests.isEmpty && AquariumDeveloperDecorations.developerOwnedDecorationIDs.isEmpty)
        #endif
    }

    @Test func bubblePNGKeepsTransparentCenterAtFullDisplayOpacity() throws {
        let cg = try #require(UIImage(named: AquariumTreasureChestEffects.bubbleAsset)?.cgImage)
        var pixels = [UInt8](repeating: 0, count: cg.width * cg.height * 4)
        try pixels.withUnsafeMutableBytes { data in
            let context = try #require(CGContext(data: data.baseAddress, width: cg.width, height: cg.height,
                bitsPerComponent: 8, bytesPerRow: cg.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
        }
        #expect(pixels[(cg.height / 2 * cg.width + cg.width / 2) * 4 + 3] == 0)
        #expect(pixels[3] == 0)
        #expect(pixels.enumerated().contains { $0.offset % 4 == 3 && $0.element > 100 })
        #expect(AquariumTreasureChestEffects.bubbleOpacity(age: 0.7, lifetime: 2.8) == 1)
        #expect(AquariumTreasureChestEffects.bubbleOpacity(age: 0, lifetime: 2.8) == 0)
        #expect(abs(AquariumTreasureChestEffects.bubbleOpacity(age: 0.115, lifetime: 2.8) - 0.5) < 0.000001)
        #expect(AquariumTreasureChestEffects.bubbleOpacity(age: 2.39, lifetime: 2.8) == 1)
        #expect(abs(AquariumTreasureChestEffects.bubbleOpacity(age: 2.6, lifetime: 2.8) - 0.5) < 0.000001)
        #expect(AquariumTreasureChestEffects.bubbleOpacity(age: 2.8, lifetime: 2.8) == 0)
    }

    @Test func directionSurvivesStorageDraftHistoryCancelAndCommit() throws {
        let fish = PlayerFish(species: .clownfish)
        let official = Player(ownedFish: [fish], activeAquariumFishIDs: [fish.id], hasInitializedActiveAquariumFish: true, coins: 500)
        let chest = AquariumDecorationPlacement(kind: .treasureChest, relativeX: 0.5, relativeY: 0.92, scale: 1, isPlaced: false)
        let initial = AquariumEditorDraft(player: official, placements: [chest], background: .aquarium)
        let work = AquariumEditorWorkingState(official: official, placements: [chest], draft: initial)
        var history = AquariumEditorHistory(initial: initial)
        let context = try ModelContainer(for: AquariumDecorationPlacement.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)).mainContext
        try AquariumDecorationService.confirmPlacement(work.placements[0], at: CGPoint(x: 0.4, y: 0.9), in: context, persistChanges: false)
        history.record(AquariumEditorDraft(player: work.player, placements: work.placements, background: .aquarium))
        try AquariumDecorationService.toggleFacing(work.placements[0], in: context, persistChanges: false)
        var rotated = AquariumEditorDraft(player: work.player, placements: work.placements, background: .aquarium)
        let didRecord = history.record(rotated)
        #expect(didRecord)
        let undo = history.undo(); work.apply(try #require(undo))
        #expect(work.placements[0].facingDirection == .right && work.placements[0].isPlaced)
        let redo = history.redo(); work.apply(try #require(redo))
        #expect(work.placements[0].facingDirection == .left)
        rotated.history = history
        let store = AquariumEditorDraftStore(url: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        defer { try? store.remove() }
        try store.save(rotated)
        let loaded = try #require(try store.load())
        let resumed = AquariumEditorWorkingState(official: official, placements: [chest], draft: loaded)
        #expect(resumed.placements[0].facingDirection == .left && loaded.history?.isValid(for: loaded) == true)
        #expect(chest.facingDirection == .right && !chest.isPlaced && official.coins == 500)
        let stored = try #require(AquariumEditorBulkStorage.decorations.applying(to: loaded))
        resumed.apply(stored)
        #expect(!resumed.placements[0].isPlaced && resumed.placements[0].facingDirection == .left)
        #expect(resumed.placements[0].decorationID == chest.decorationID)
        #expect(AquariumDecorationEditorPresentation.inventory(from: resumed.placements).first?.ownedCount == 1)
        let changed = AquariumEditorSessionSnapshot.capture(player: resumed.player, decorationPlacements: resumed.placements, backgroundTheme: .aquarium)
        #expect(throws: (any Error).self) {
            try AquariumEditorCommit.apply(changed, to: official, placements: [chest], background: .aquarium) { throw CocoaError(.fileWriteUnknown) }
        }
        #expect(chest.facingDirection == .right)
        try AquariumEditorCommit.apply(changed, to: official, placements: [chest], background: .aquarium) {}
        #expect(chest.facingDirection == .left && !chest.isPlaced && official.coins == 500 && official.ownedFish.count == 1)
    }

    @Test func legacyDraftWithoutDirectionStillLoads() throws {
        let placement = AquariumDecorationPlacement(kind: .smallRockA, relativeX: 0.2, relativeY: 0.8, scale: 1)
        let draft = AquariumEditorDraft(player: Player(), placements: [placement], background: .aquarium)
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(draft)) as? [String: Any])
        var placements = try #require(json["placements"] as? [[String: Any]])
        placements[0].removeValue(forKey: "facingDirection"); json["placements"] = placements
        let decoded = try JSONDecoder().decode(AquariumEditorDraft.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(decoded.isValid && decoded.placements[0].facingDirection == .right)
        #expect(decoded.snapshot == draft.snapshot)
    }

    @Test func oldSwiftDataStoreMigratesAndDirectionPersistsAfterReload() throws {
        let source = try #require(Bundle(for: TestBundleMarker.self).url(forResource: "legacy-decoration", withExtension: "store"))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("store")
        try FileManager.default.copyItem(at: source, to: url)
        var container: ModelContainer? = try ModelContainer(for: AquariumDecorationPlacement.self, configurations: ModelConfiguration(url: url))
        let id: String
        do {
            let context = ModelContext(try #require(container))
            let old = try context.fetch(FetchDescriptor<AquariumDecorationPlacement>())
            #expect(old.count == 2)
            let seaweed = try #require(old.first { $0.decorationID == "legacy-seaweed" })
            #expect(seaweed.kind == .seaweedA && !seaweed.isPlaced && seaweed.relativeX == 0.25 && seaweed.scale == 1.1)
            #expect(seaweed.facingDirectionRawValue == nil && seaweed.facingDirection == .right)
            let chest = try AquariumDecorationService.addPlacement(kind: .treasureChest, isPlaced: true, in: context)
            id = chest.decorationID
            try AquariumDecorationService.toggleFacing(chest, in: context)
        }
        container = nil
        let reopened = try ModelContainer(for: AquariumDecorationPlacement.self, configurations: ModelConfiguration(url: url))
        let values = try reopened.mainContext.fetch(FetchDescriptor<AquariumDecorationPlacement>())
        #expect(values.count == 3)
        let chest = try #require(values.first { $0.decorationID == id })
        #expect(chest.facingDirection == .left && chest.isPlaced)
        #expect(values.first { $0.decorationID == "legacy-rock" }?.relativeX == 0.7)
    }

    @Test func effectPatternsAreIndependentBoundedAndDoNotCutOffAtTheImageTop() {
        let a = AquariumTreasureChestEffects.Pattern(placementID: "one")
        let b = AquariumTreasureChestEffects.Pattern(placementID: "two")
        #expect(a == AquariumTreasureChestEffects.Pattern(placementID: "one") && a != b)
        #expect(a.bubbles.count == 15 && a.sparkles.count == 24)
        #expect(Set(a.sparkles.map(\.spot)).count == 8)
        for direction in AquariumDecorationFacingDirection.allCases {
            for time in stride(from: 0.0, through: 40, by: 0.1) {
                let frame = AquariumTreasureChestEffects.frame(pattern: a, elapsed: time, direction: direction)
                #expect(frame.bubbles.count <= 16 && frame.sparkles.count <= 3)
                for bubble in frame.bubbles {
                    #expect((0...1).contains(bubble.opacity) && (5.17...11.5).contains(bubble.diameter))
                    #expect(AquariumTreasureChestEffects.overflowTop + bubble.point.y * AquariumTreasureChestEffects.canvasSide - bubble.diameter / AquariumTreasureChestEffects.bubbleVisibleFraction / 2 >= 0)
                }
            }
        }
        let instances = (0..<100).map { AquariumTreasureChestEffects.Instance(id: "chest-\($0)", direction: .right) }
        let patterns = Dictionary(uniqueKeysWithValues: instances.map { ($0.id, AquariumTreasureChestEffects.Pattern(placementID: $0.id)) })
        for time in [0.0, 1.0, 5.0, 10.0] {
            let frames = AquariumTreasureChestEffects.frames(instances: instances, patterns: patterns, elapsed: time)
            #expect(frames.values.reduce(0) { $0 + $1.bubbles.count } <= 80)
            #expect(frames.values.reduce(0) { $0 + $1.sparkles.count } <= 16)
        }
        #expect(AquariumTreasureChestEffects.frames(instances: [], patterns: patterns, elapsed: 1).isEmpty)
    }

    /// Actual SwiftUI/Canvas rasterization on iOS; does not require Mac UI automation.
    @Test func renderChecksOnThreeBackgrounds() throws {
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("treasure-chest-render-checks")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let pattern = AquariumTreasureChestEffects.Pattern(placementID: "developer-owned-treasure_chest")
        for (theme, asset, suffix) in [(AquariumBackgroundTheme.aquarium, "basic_ocean_00", "basic"),
                                      (.tropical, "coral_ocean_00", "coral"), (.deepSea, "deep_ocean_00", "deep")] {
            for direction in AquariumDecorationFacingDirection.allCases {
                for corrected in [false, true] {
                    let frame = AquariumTreasureChestEffects.frame(pattern: pattern, elapsed: 3, direction: direction)
                    let scene = ZStack {
                        Image(asset).resizable().scaledToFill().frame(width: 400, height: 600).clipped()
                        AquariumTreasureChestView(direction: direction, frame: frame, backgroundTheme: theme,
                            isSelected: false, bodyOpacity: 1, appliesColorCorrection: corrected)
                            .offset(y: AquariumDecorationKind.treasureChest.groundAnchorOffset(facingDirection: direction))
                            .position(x: 200, y: 552)
                }.frame(width: 400, height: 600)
                let renderer = ImageRenderer(content: scene)
                renderer.scale = 2
                let data = try #require(renderer.uiImage?.pngData())
                try data.write(to: folder.appendingPathComponent("\(suffix)-\(direction.rawValue)-\(corrected ? "after" : "before").png"))
                }
            }
        }
    }

    @Test func pausedClockDoesNotAdvanceOrGenerateCatchUpParticles() {
        var clock = AquariumTreasureChestClock()
        let start = Date(timeIntervalSinceReferenceDate: 100)
        clock.setRunning(true, at: start)
        clock.setRunning(false, at: start.addingTimeInterval(5))
        #expect(clock.elapsed(at: start.addingTimeInterval(1000)) == 5)
        clock.setRunning(true, at: start.addingTimeInterval(1000))
        #expect(clock.elapsed(at: start.addingTimeInterval(1002)) == 7)
    }
}

private final class TestBundleMarker: NSObject {}
