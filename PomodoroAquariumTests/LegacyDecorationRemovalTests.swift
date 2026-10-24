import Foundation
import SwiftData
import SwiftUI
import UIKit
import Testing
@testable import PomodoroAquarium

@MainActor
struct LegacyDecorationRemovalTests {
    private struct PlacementValues: Equatable {
        let id: String, kind: String
        let x: Double, y: Double, scale: Double
        let placed: Bool, facing: String?, z: Int, foreground: Bool, initialized: Bool
        init(_ p: AquariumDecorationPlacement) {
            id = p.decorationID; kind = p.kindRawValue; x = p.relativeX; y = p.relativeY; scale = p.scale
            placed = p.isPlaced; facing = p.facingDirectionRawValue; z = p.zOrder
            foreground = p.rockIsForeground; initialized = p.isStackingOrderInitialized
        }
    }

    private func formalPlacements() -> [AquariumDecorationPlacement] {
        AquariumDecorationKind.availableKinds.enumerated().flatMap { index, kind in
            [true, false].map { placed in
                AquariumDecorationPlacement(decorationID: "formal-\(kind.rawValue)-\(placed)", kind: kind,
                    relativeX: -0.1 + Double(index) * 0.06, relativeY: 0.75 + Double(index) * 0.01,
                    scale: 0.8 + Double(index) * 0.03, isPlaced: placed, facingDirection: .left,
                    zOrder: 100 + index * 3, rockIsForeground: index.isMultiple(of: 2), isStackingOrderInitialized: true)
            }
        }
    }

    private func legacyPlacements() -> [AquariumDecorationPlacement] {
        [AquariumDecorationKind.seaweed, .rock].flatMap { kind in
            [true, false].map { placed in
                AquariumDecorationPlacement(decorationID: placed ? "default-\(kind.rawValue)" : "stored-\(kind.rawValue)",
                    kind: kind, relativeX: 0.15, relativeY: 0.84, scale: 1.1, isPlaced: placed)
            }
        }
    }

    private func unknownPlacement() -> AquariumDecorationPlacement {
        let p = AquariumDecorationPlacement(decorationID: "future", kind: .unsupported,
            relativeX: 0.3, relativeY: 0.77, scale: 1.4, zOrder: 77, isStackingOrderInitialized: true)
        p.kindRawValue = "future-decoration-kind"; p.facingDirectionRawValue = "left"
        return p
    }

    @Test func freshInitializationAndDeveloperSeedingNeverGenerateRetiredKinds() throws {
        let container = try ModelContainer(for: AquariumDecorationPlacement.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        for _ in 0..<3 {
            #expect(try AquariumDecorationService.removeLegacyPlaceholders(in: context) == false)
            #expect(try context.fetchCount(FetchDescriptor<AquariumDecorationPlacement>()) == 0)
        }
        _ = try AquariumDeveloperDecorations.seedIfNeeded(in: context)
        let seeded = try context.fetch(FetchDescriptor<AquariumDecorationPlacement>())
        #expect(seeded.allSatisfy { $0.kind.isAvailable })
        #expect(!seeded.contains { $0.decorationID == "default-seaweed" || $0.decorationID == "default-rock" })
#if DEBUG
        #expect(seeded.count == 100)
#else
        #expect(seeded.isEmpty)
#endif
        #expect(try AquariumDeveloperDecorations.seedIfNeeded(in: context) == false)
    }

    @Test func repeatedStoreReadsDeleteOnlyExactLegacyKindsAndKeepEveryFormalValue() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("RetireDecorations-\(UUID()).store")
        defer { for suffix in ["", "-shm", "-wal"] { try? FileManager.default.removeItem(atPath: url.path + suffix) } }
        let config = ModelConfiguration(url: url)
        var expected: [PlacementValues] = []
        let fishID = UUID()
        do {
            let container = try ModelContainer(for: Player.self, PlayerFish.self, AquariumDecorationPlacement.self,
                configurations: config)
            let context = ModelContext(container); context.autosaveEnabled = false
            let formal = formalPlacements(), unknown = unknownPlacement()
            for p in formal + [unknown] + legacyPlacements() { context.insert(p) }
            let fish = PlayerFish(id: fishID, species: .clownfish)
            context.insert(Player(ownedFish: [fish], activeAquariumFishIDs: [fishID],
                hasInitializedActiveAquariumFish: true, totalStudyMinutes: 153, todayStudyMinutes: 28, coins: 321))
            expected = (formal + [unknown]).map(PlacementValues.init).sorted { $0.id < $1.id }
            try context.save()
        }
        for index in 0..<3 {
            let container = try ModelContainer(for: Player.self, PlayerFish.self, AquariumDecorationPlacement.self,
                configurations: config)
            let context = ModelContext(container); context.autosaveEnabled = false
            #expect(try AquariumDecorationService.removeLegacyPlaceholders(in: context) == (index == 0))
            let remaining = try context.fetch(FetchDescriptor<AquariumDecorationPlacement>())
            #expect(remaining.map(PlacementValues.init).sorted { $0.id < $1.id } == expected)
            #expect(remaining.first { $0.decorationID == "future" }?.kind == .unsupported)
            let player = try #require(context.fetch(FetchDescriptor<Player>()).first)
            #expect(player.activeAquariumFishIDs == [fishID] && player.ownedFish.first?.id == fishID)
            #expect(player.coins == 321 && player.totalStudyMinutes == 153 && player.todayStudyMinutes == 28)
        }
    }

    @Test func normalInventoryRenderingAndAcquisitionRejectRetiredAndUnknownKinds() throws {
        #expect(AquariumDecorationKind.availableKinds.count == 20)
        #expect(!AquariumDecorationKind.availableKinds.contains { $0.isLegacyPlaceholder || $0 == .unsupported })
        #expect(try JSONDecoder().decode(AquariumDecorationKind.self, from: Data("\"seaweed\"".utf8)) == .seaweed)
        #expect(try JSONDecoder().decode(AquariumDecorationKind.self, from: Data("\"rock\"".utf8)) == .rock)
        let formal = formalPlacements(), retired = legacyPlacements(), unknown = unknownPlacement()
        let all = formal + retired + [unknown]
        #expect(AquariumDecorationEditorPresentation.inventory(from: all).map(\.kind) == AquariumDecorationKind.availableKinds)
        #expect(AquariumDecorationService.storedPlacements(from: all).count == 20)
        for item in ShopCatalog.items {
            if case .decoration(let kind) = item.content { #expect(kind.isAvailable) }
        }
        let container = try ModelContainer(for: Player.self, PlayerFish.self, AquariumDecorationPlacement.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let player = Player(coins: 900); container.mainContext.insert(player)
        for kind in [AquariumDecorationKind.seaweed, .rock, .unsupported] {
            #expect(throws: AquariumDecorationPlacementError.self) {
                try AquariumDecorationService.addPlacement(kind: kind, in: container.mainContext)
            }
            let item = ShopItem(id: "cached-\(kind.rawValue)", name: "cached", price: 100,
                category: .decoration, content: .decoration(kind))
            #expect(throws: ShopPurchaseError.unsupportedProduct) {
                try ShopService.purchaseDecoration(item, for: player, in: container.mainContext)
            }
            let renderer = ImageRenderer(content: AquariumDecorationView(decoration: .init(id: "test", kind: kind,
                relativeX: 0.5, relativeY: 0.8, scale: 1)).frame(width: 160, height: 160))
            let image = try #require(renderer.uiImage?.cgImage)
            #expect(nontransparentPixels(image) == 0)
        }
        #expect(player.coins == 900)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<AquariumDecorationPlacement>()) == 0)
        for kind in [AquariumDecorationKind.seaweedA, .smallRockA] {
            let renderer = ImageRenderer(content: AquariumDecorationView(decoration: .init(id: "formal", kind: kind,
                relativeX: 0.5, relativeY: 0.8, scale: 1)).frame(width: 240, height: 240))
            #expect(nontransparentPixels(try #require(renderer.uiImage?.cgImage)) > 0)
        }
    }

    @Test func draftAndEveryUndoRedoStateAreCleanedWithoutResettingHistoryOrFormalFields() throws {
        let formal = formalPlacements(), unknown = unknownPlacement()
        let fish = PlayerFish(species: .whaleShark)
        let player = Player(ownedFish: [fish], activeAquariumFishIDs: [fish.id], hasInitializedActiveAquariumFish: true)
        let start = AquariumEditorDraft(player: player, placements: formal + [unknown], background: .aquarium)
        var edited = start
        edited.placements[0].x = 0.42; edited.placements[0].scale = 1.31
        var history = AquariumEditorHistory(initial: start)
        let first = history.record(edited); #expect(first)
        var later = edited; later.background = AquariumBackgroundTheme.deepSea.rawValue
        let second = history.record(later); #expect(second)
        _ = history.undo()
        var stored = history.current; stored.history = history
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(stored)) as? [String: Any])
        let old = [["id": "default-seaweed", "kind": "seaweed", "x": 0.14, "y": 0.82, "scale": 1.0, "isPlaced": true],
                   ["id": "stored-old-rock", "kind": "rock", "x": 0.82, "y": 0.88, "scale": 1.1, "isPlaced": false]] as [[String: Any]]
        object["placements"] = (object["placements"] as! [[String: Any]]) + old
        var h = object["history"] as! [String: Any], states = h["states"] as! [[String: Any]]
        for index in states.indices { states[index]["placements"] = (states[index]["placements"] as! [[String: Any]]) + old }
        h["states"] = states; object["history"] = h
        let store = AquariumEditorDraftStore(url: FileManager.default.temporaryDirectory.appendingPathComponent("LegacyDraft-\(UUID()).json"))
        defer { try? store.remove() }
        try JSONSerialization.data(withJSONObject: object).write(to: store.url)
        let loaded = try #require(try store.load())
        #expect(loaded == stored)
        #expect(loaded.history?.states.count == 3 && loaded.history?.position == 1)
        #expect(loaded.history?.isValid(for: loaded) == true)
        let persisted = try JSONDecoder().decode(AquariumEditorDraft.self, from: Data(contentsOf: store.url))
        #expect(persisted == stored)
        for _ in 0..<3 { #expect(try store.load() == loaded) }
        var recovered = try #require(loaded.history)
        let undo = recovered.undo(); #expect(undo == start.snapshot)
        let redo = recovered.redo(); #expect(redo == edited.snapshot)
        let redoAgain = recovered.redo(); #expect(redoAgain == later.snapshot)
        let work = AquariumEditorWorkingState(official: player, placements: formal + [unknown] + legacyPlacements(), draft: loaded)
        #expect(work.placements.count == 41)
        #expect(work.placements.first { $0.decorationID == "future" }?.kindRawValue == unknown.kindRawValue)
        #expect(work.placements.first { $0.decorationID == "future" }?.facingDirectionRawValue == "left")
        let beforeOfficial = formal.map(PlacementValues.init)
        work.apply(try #require(undo)); work.apply(try #require(redoAgain))
        #expect(formal.map(PlacementValues.init) == beforeOfficial) // キャンセルなら正式側はそのまま。
        let snapshot = AquariumEditorSessionSnapshot.capture(player: work.player,
            decorationPlacements: work.placements, backgroundTheme: .deepSea)
        snapshot.restore(player: player, decorationPlacements: formal + [unknown])
        #expect(formal[0].relativeX == 0.42 && formal[0].scale == 1.31)
        #expect(!work.placements.contains { $0.kind.isLegacyPlaceholder })
    }

    private func nontransparentPixels(_ image: CGImage) -> Int {
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        pixels.withUnsafeMutableBytes {
            CGContext(data: $0.baseAddress, width: image.width, height: image.height,
                bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                .draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return stride(from: 3, to: pixels.count, by: 4).count { pixels[$0] > 0 }
    }

    @Test func actualAquariumAppearanceRemovesOldRecordsAndNeverRecreatesThem() async throws {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = try #require(scenes.first { $0.activationState == .foregroundActive } ?? scenes.first)
        let container = try ModelContainer(for: Player.self, PlayerFish.self, AquariumDecorationPlacement.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let formal = AquariumDecorationPlacement(decorationID: "visible-formal", kind: .smallRockA,
            relativeX: 0.45, relativeY: 0.86, scale: 1.17, zOrder: 82, isStackingOrderInitialized: true)
        let expected = PlacementValues(formal)
        context.insert(formal)
        for p in legacyPlacements() { context.insert(p) }
        let player = Player(ownedFish: [PlayerFish(species: .clownfish)], coins: 321)
        context.insert(player); try context.save()
        let size = CGSize(width: 393, height: 746)
        for pass in 0..<3 {
            let root = AquariumView(player: player, isEditing: pass == 1)
                .modelContainer(container).environment(\.scenePhase, .active)
            let host = UIHostingController(rootView: root)
            let window = UIWindow(windowScene: scene); window.frame = CGRect(origin: .zero, size: size)
            window.rootViewController = host; window.makeKeyAndVisible()
            defer { window.isHidden = true }
            host.view.layoutIfNeeded(); try await Task.sleep(for: .milliseconds(180)); host.view.layoutIfNeeded()
            let records = try context.fetch(FetchDescriptor<AquariumDecorationPlacement>())
            #expect(!records.contains { $0.kind.isLegacyPlaceholder })
            #expect(PlacementValues(formal) == expected && player.coins == 321)
            if pass == 2 {
                let format = UIGraphicsImageRendererFormat(); format.scale = 1
                let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
                    host.view.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
                }
                try #require(image.pngData()).write(to: URL(fileURLWithPath: "/private/tmp/LegacyDecorationRemovedWater.png"))
            }
            window.isHidden = true
        }
    }
}
