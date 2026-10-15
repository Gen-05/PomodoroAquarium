import SwiftUI
import SwiftData
import Testing
@testable import PomodoroAquarium

@MainActor
struct AquariumShipwreckTests {
    private func ship(_ id: String) -> AquariumDecorationPlacement {
        AquariumDecorationPlacement(decorationID: id, kind: .shipwreck, relativeX: 0.29, relativeY: 0.438, scale: 1, isPlaced: false)
    }
    @Test func threeBakedAssetsKeepAlphaAndRenderBothSidesWithoutExtraProcessing() throws {
        #expect(AquariumDecorationKind.shipwreck.stars == 3)
        #expect(AquariumDecorationKind.shipwreck.plannedPrice == 1000)
        let assets: [(AquariumBackgroundTheme, String)] = [(.aquarium, "shipwreck_distant"),
            (.tropical, "shipwreck_distant_coral"), (.deepSea, "shipwreck_distant_deep")]
        func pixels(_ image: CGImage) -> [UInt8] {
            var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
            bytes.withUnsafeMutableBytes { raw in
                let c = CGContext(data: raw.baseAddress, width: image.width, height: image.height,
                    bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                c.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            }
            return bytes
        }
        let size = CGSize(width: 393, height: 852)
        for (theme, name) in assets {
            let source = try #require(UIImage(named: name))
            let original = try #require(source.cgImage)
            #expect(original.width == 1600 && original.height == 1088)
            let sourceBytes = pixels(original)
            #expect(stride(from: 3, to: sourceBytes.count, by: 4).contains { sourceBytes[$0] > 0 && sourceBytes[$0] < 255 })
            let setting = AquariumShipwreckPresentation.settings(for: theme)
            #expect(setting.assetName == name)
            for side in AquariumDecorationFacingDirection.allCases {
                #expect(setting.point(CGPoint(x: 0.5, y: 0.5), side: side, size: size) == setting.center(side: side, size: size))
                let width = size.width * setting.widthRatio
                // Preserve the native PNG colors and baked alpha without extra processing.
                let reference = Image(uiImage: source).resizable().scaledToFit()
                    .frame(width: width, height: width * 1088 / 1600)
                    .scaleEffect(x: side == .right ? -1 : 1, y: 1)
                    .rotationEffect(.degrees(side == .left ? -setting.rotationDegrees : setting.rotationDegrees))
                    .position(setting.center(side: side, size: size))
                    .frame(width: size.width, height: size.height).clipped()
                let expectedRenderer = ImageRenderer(content: reference)
                let actualRenderer = ImageRenderer(content: AquariumShipwreckView(side: side, theme: theme, size: size)
                    .frame(width: size.width, height: size.height).clipped())
                expectedRenderer.scale = 1; actualRenderer.scale = 1
                let expected = pixels(try #require(expectedRenderer.cgImage))
                let actual = pixels(try #require(actualRenderer.cgImage))
                #expect(actual == expected)
            }
        }
    }
    @Test func oneShipUsesSameOwnedIDAndDoesNotEnterStackingOrDrag() throws {
        let a = ship("a"), b = ship("b")
        let rock = AquariumDecorationPlacement(decorationID: "rock", kind: .smallRockA, relativeX: 0.5, relativeY: 0.8, scale: 1, zOrder: 5, isStackingOrderInitialized: true)
        let all = [a,b,rock]
        #expect(AquariumShipwreckEditing.place(id: "a", side: .left, among: all)?.decorationID == "a")
        #expect(AquariumShipwreckEditing.place(id: "b", side: .right, among: all)?.decorationID == "a")
        #expect(a.isPlaced && !b.isPlaced && a.facingDirection == .right)
        #expect(AquariumShipwreckEditing.place(id: "b", side: .right, among: all) == nil)
        #expect(!AquariumDecorationStacking.canMove(a, action: .front, among: all, within: ["a","rock"]))
        AquariumDecorationStacking.insertNew(a, among: all)
        #expect(rock.zOrder == 5)
        #expect(!AquariumEditorDropCoordinator.acceptsDecorationDrop(at: CGPoint(x: 100, y: 700), in: CGSize(width: 393, height: 852), kind: .shipwreck))
        #expect(AquariumDecorationEditorPresentation.inventory(from: all).first { $0.kind == .shipwreck }?.canPlaceAnother == false)
    }
    @Test func draftHistoryBulkStorageAndFormalPersistenceRetainSideAndIDs() throws {
        let container = try ModelContainer(for: Player.self, PlayerFish.self, AquariumDecorationPlacement.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let player = Player(), official = ship("owned-ship")
        context.insert(player); context.insert(official); try context.save()
        let initial = AquariumEditorDraft(player: player, placements: [official], background: .aquarium)
        let work = AquariumEditorWorkingState(official: player, placements: [official], draft: initial)
        var history = AquariumEditorHistory(initial: initial)
        _ = AquariumShipwreckEditing.place(id: "owned-ship", side: .left, among: work.placements)
        let added = AquariumEditorDraft(player: work.player, placements: work.placements, background: .aquarium)
        let r1 = history.record(added); #expect(r1)
        _ = AquariumShipwreckEditing.place(id: "owned-ship", side: .right, among: work.placements)
        let changed = AquariumEditorDraft(player: work.player, placements: work.placements, background: .deepSea)
        let r2 = history.record(changed); #expect(r2)
        let undone = history.undo(); work.apply(try #require(undone))
        #expect(work.placements[0].facingDirection == .left && !official.isPlaced)
        var saved = AquariumEditorDraft(player: work.player, placements: work.placements, background: .aquarium)
        saved.history = history
        let decoded = try JSONDecoder().decode(AquariumEditorDraft.self, from: JSONEncoder().encode(saved))
        var restored = try #require(decoded.history)
        let redo = restored.redo(); work.apply(try #require(redo))
        #expect(work.placements[0].facingDirection == .right)
        let bulk = try #require(AquariumEditorBulkStorage.decorations.applying(to: changed))
        let rb = restored.record(bulk); #expect(rb)
        work.apply(bulk); #expect(!work.placements[0].isPlaced)
        let back = restored.undo(); work.apply(try #require(back))
        #expect(work.placements[0].decorationID == official.decorationID && work.placements[0].isPlaced)
        // キャンセル相当: 正式データはまだ変わらない。完了時だけ既存値コピーを反映。
        #expect(!official.isPlaced)
        AquariumDecorationEditorState(work.placements[0]).restore(to: official)
        try context.save()
        let reloaded = try ModelContext(container).fetch(FetchDescriptor<AquariumDecorationPlacement>())
        #expect(reloaded.count == 1 && reloaded[0].facingDirection == .right && reloaded[0].isPlaced)
    }
}
