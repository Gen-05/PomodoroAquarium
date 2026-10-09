import CoreGraphics
import SwiftData
import Testing
import UIKit
@testable import PomodoroAquarium

@MainActor
struct AquariumDeveloperDecorationTests {
    @Test func seaweedADefinitionAndAssets() {
        let kind = AquariumDecorationKind.seaweedA
        #expect(kind.rawValue == "seaweed-a")
        #expect(kind.displayName == "海藻A")
        #expect(kind.decorationType == .seaweed)
        #expect(kind.stars == 1)
        #expect(kind.plannedPrice == 30)
        #expect(kind.animationFrameNames == [
            "seaweed_a_01", "seaweed_a_02", "seaweed_a_03", "seaweed_a_04",
            "seaweed_a_05", "seaweed_a_06", "seaweed_a_07", "seaweed_a_08"
        ])
        #expect(kind.animationFrameDuration == 0.25)
        #expect(kind.animationCrossFadeDuration == 0.1)
        #expect(kind.displaySize == CGSize(width: 84, height: 126))
        for name in kind.animationFrameNames {
            #expect(UIImage(named: name)?.size == CGSize(width: 512, height: 768))
        }
        #expect(!AquariumDecorationService.defaultDecorations.contains { $0.kind == kind })
        #expect(!ShopCatalog.items.contains { $0.content == .decoration(kind) })
    }

    @Test func seaweedBDefinitionAndAssetsReuseSeaweedAPlayback() {
        let kind = AquariumDecorationKind.seaweedB
        let a = AquariumDecorationKind.seaweedA
        #expect(kind.rawValue == "seaweed-b")
        #expect(kind.displayName == "海藻B")
        #expect(kind.decorationType == .seaweed)
        #expect(kind.category == .plant)
        #expect(kind.stars == 1)
        #expect(kind.plannedPrice == 30)
        #expect(kind.animationFrameNames == [
            "seaweed_b_01", "seaweed_b_02", "seaweed_b_03", "seaweed_b_04",
            "seaweed_b_05", "seaweed_b_06", "seaweed_b_07", "seaweed_b_08"
        ])
        #expect(kind.animationFrameDuration == a.animationFrameDuration)
        #expect(kind.animationCrossFadeDuration == a.animationCrossFadeDuration)
        #expect(kind.displaySize == CGSize(width: 88, height: 176))
        #expect((1.3...1.5).contains(kind.displaySize.height / a.displaySize.height))
        #expect(kind.groundAnchorY == 0.978)
        #expect(kind.groundAnchorOffset() < 0)
        for name in kind.animationFrameNames {
            #expect(UIImage(named: name)?.size == CGSize(width: 512, height: 1024))
        }
        let ids = ["developer-owned-seaweed-b"] + (2...5).map { "developer-owned-seaweed-b-\($0)" }
        let offsets = ids.map { AquariumDecorationFramePlayback.startFrameOffset(placementID: $0, frameCount: 8) }
        #expect(Set(offsets).count > 1)
        for (id, offset) in zip(ids, offsets) {
            #expect(AquariumDecorationFramePlayback.startFrameOffset(placementID: id, frameCount: 8) == offset)
            let cycle = (0...8).map { AquariumDecorationFramePlayback.frameIndex(step: $0 + offset, frameCount: 8) }
            #expect(cycle.first == cycle.last)
            #expect(Set(cycle).count == 8)
        }
        #expect(!AquariumDecorationService.defaultDecorations.contains { $0.kind == kind })
        #expect(!ShopCatalog.items.contains { $0.content == .decoration(kind) })
    }

    @Test func seaweedCDefinitionAssetsAndPlaybackPreserveAspectRatio() {
        let kind = AquariumDecorationKind.seaweedC
        #expect(kind.rawValue == "seaweed_c")
        #expect(kind.displayName == "海藻C")
        #expect(kind.decorationType == .seaweed)
        #expect(kind.category == .plant)
        #expect(kind.stars == 1)
        #expect(kind.plannedPrice == 30)
        #expect(kind.animationFrameNames == [
            "seaweed_c_01", "seaweed_c_02", "seaweed_c_03", "seaweed_c_04",
            "seaweed_c_05", "seaweed_c_06", "seaweed_c_07", "seaweed_c_08"
        ])
        #expect(kind.assetImageName == "seaweed_c_01")
        #expect(kind.animationFrameDuration == 0.25)
        #expect(kind.animationCrossFadeDuration == 0.1)
        #expect(kind.displaySize == CGSize(width: 126, height: 84))
        #expect(kind.displaySize.width / kind.displaySize.height == 1.5)
        #expect(kind.groundAnchorY == 0.955)
        #expect(kind.groundAnchorOffset() < 0)
        for name in kind.animationFrameNames {
            #expect(UIImage(named: name)?.size == CGSize(width: 768, height: 512))
        }
        // 全frameのalpha占有範囲で比較。画像キャンバスの大きさとは区別する。
        let a = AquariumDecorationKind.seaweedA.displaySize
        #expect((0.65...0.80).contains((463.0 / 512 * kind.displaySize.height) / (679.0 / 768 * a.height)))
        #expect((1.3...1.6).contains((651.0 / 768 * kind.displaySize.width) / (411.0 / 512 * a.width)))
        let ids = ["developer-owned-seaweed_c"] + (2...5).map { "developer-owned-seaweed_c-\($0)" }
        let offsets = ids.map { AquariumDecorationFramePlayback.startFrameOffset(placementID: $0, frameCount: 8) }
        #expect(Set(offsets).count > 1)
        for (id, offset) in zip(ids, offsets) {
            #expect(AquariumDecorationFramePlayback.startFrameOffset(placementID: id, frameCount: 8) == offset)
            let cycle = (0...8).map { kind.animationFrameNames[AquariumDecorationFramePlayback.frameIndex(step: $0 + offset, frameCount: 8)] }
            #expect(cycle == (0...8).map { kind.animationFrameNames[($0 + offset) % 8] })
        }
        #expect(!AquariumDecorationService.defaultDecorations.contains { $0.kind == kind })
        #expect(!ShopCatalog.items.contains { $0.content == .decoration(kind) })
    }

    @Test(arguments: [AquariumDecorationKind.mediumRockA, .mediumRockB, .mediumRockC])
    func mediumRocksHaveStableDefinitionsAndMatchingStaticAssets(kind: AquariumDecorationKind) throws {
        let expected: (String, String, CGSize, CGSize)
        switch kind {
        case .mediumRockA: expected = ("medium_rock_a", "中岩A", CGSize(width: 1024, height: 448), CGSize(width: 176, height: 77))
        case .mediumRockB: expected = ("medium_rock_b", "中岩B", CGSize(width: 1024, height: 576), CGSize(width: 168, height: 94.5))
        default: expected = ("medium_rock_c", "中岩C", CGSize(width: 768, height: 928), CGSize(width: 120, height: 145))
        }
        #expect(kind.rawValue == expected.0)
        #expect(kind.displayName == expected.1)
        #expect(kind.stars == 2 && kind.plannedPrice == 80)
        #expect(kind.decorationType == .rock && kind.category == .rock)
        #expect(kind.renderLayer == .rock)
        #expect(kind.animationFrameNames.isEmpty && kind.animationCrossFadeDuration == 0)
        #expect(kind.displaySize == expected.3)
        #expect(abs(kind.displaySize.width / kind.displaySize.height - expected.2.width / expected.2.height) < 0.000_001)
        #expect(kind.groundAnchorOffset() < 0)
        for (theme, suffix) in [(AquariumBackgroundTheme.aquarium, "basic"), (.tropical, "coral"), (.deepSea, "deep")] {
            let name = try #require(kind.assetImageName(for: theme))
            #expect(name == "\(expected.0)_\(suffix)")
            #expect(UIImage(named: name)?.size == expected.2)
        }
        #expect(AquariumDecorationKind.mediumRockC.displaySize.height > AquariumDecorationKind.mediumRockB.displaySize.height)
        #expect(AquariumDecorationKind.mediumRockB.displaySize.height > AquariumDecorationKind.mediumRockA.displaySize.height)
        #expect(!AquariumDecorationService.defaultDecorations.contains { $0.kind == kind })
        #expect(!ShopCatalog.items.contains { $0.content == .decoration(kind) })
    }

    @Test(arguments: [AquariumDecorationKind.smallRockA, .smallRockB, .smallRockC])
    func smallRocksHaveStableDefinitionsAndMatchingStaticAssets(kind: AquariumDecorationKind) throws {
        let expected: (String, String, CGSize, CGSize)
        switch kind {
        case .smallRockA: expected = ("small_rock_a", "小岩A", CGSize(width: 768, height: 448), CGSize(width: 96, height: 56))
        case .smallRockB: expected = ("small_rock_b", "小岩B", CGSize(width: 768, height: 272), CGSize(width: 112, height: CGFloat(112) * 272 / 768))
        default: expected = ("small_rock_c", "小岩C", CGSize(width: 768, height: 400), CGSize(width: 108, height: 56.25))
        }
        #expect(kind.rawValue == expected.0)
        #expect(kind.displayName == expected.1)
        #expect(kind.stars == 1 && kind.plannedPrice == 30)
        #expect(kind.decorationType == .rock && kind.category == .rock)
        #expect(kind.animationFrameNames.isEmpty)
        #expect(kind.animationCrossFadeDuration == 0)
        #expect(kind.displaySize == expected.3)
        #expect(abs(kind.displaySize.width / kind.displaySize.height - expected.2.width / expected.2.height) < 0.000_001)
        #expect(kind.displaySize.height < AquariumDecorationKind.seaweedC.displaySize.height)
        #expect(kind.groundAnchorY != nil)
        for (theme, suffix) in [(AquariumBackgroundTheme.aquarium, "basic"), (.tropical, "coral"), (.deepSea, "deep")] {
            let name = try #require(kind.assetImageName(for: theme))
            #expect(name == "\(expected.0)_\(suffix)")
            let image = try #require(UIImage(named: name))
            #expect(image.size == expected.2)
        }
        #expect(!AquariumDecorationService.defaultDecorations.contains { $0.kind == kind })
        #expect(!ShopCatalog.items.contains { $0.content == .decoration(kind) })
    }

    @Test(arguments: [AquariumDecorationKind.smallRockA, .smallRockB, .smallRockC, .mediumRockA, .mediumRockB, .mediumRockC])
    func changingBackgroundOnlyRecalculatesRockImageAndPreservesSavedPlacement(kind: AquariumDecorationKind) throws {
        let container = try makeContainer()
        let context = container.mainContext
        let first = try AquariumDecorationService.addPlacement(kind: kind, at: CGPoint(x: 0.25, y: 0.84), scale: 1.1, isPlaced: true, in: context)
        let second = try AquariumDecorationService.addPlacement(kind: kind, at: CGPoint(x: 0.75, y: 0.92), isPlaced: true, in: context)
        #expect(first.decorationID != second.decorationID)
        let id = first.decorationID
        let baseSize = kind.displaySize
        for theme in [AquariumBackgroundTheme.aquarium, .tropical, .deepSea] {
            #expect(first.kind.assetImageName(for: theme) != nil)
            let restored = try #require(ModelContext(container).fetch(FetchDescriptor<AquariumDecorationPlacement>()).first { $0.decorationID == id })
            #expect(restored.kindRawValue == kind.rawValue)
            #expect(restored.relativeX == 0.25 && restored.relativeY == 0.84)
            #expect(restored.scale == 1.1 && restored.isPlaced)
            #expect(restored.kind.displaySize == baseSize)
            let inventory = AquariumDecorationEditorPresentation.inventory(from: [restored, second])
            #expect(inventory.first?.ownedCount == 2)
            #expect(inventory.first?.placedCount == 2)
        }
        #expect(try context.fetchCount(FetchDescriptor<AquariumDecorationPlacement>()) == 2)
        for seaweed in [AquariumDecorationKind.seaweedA, .seaweedB, .seaweedC] {
            #expect(seaweed.assetImageName(for: .aquarium) == seaweed.assetImageName(for: .deepSea))
            #expect(seaweed.assetImageName(for: .tropical) == seaweed.animationFrameNames.first)
        }
    }

    @Test func defaultPlaceholderRockIsHiddenOnlyWhenPlacedAndSmallRocksAreOwned() {
        let legacy = AquariumDecorationPlacement(decorationID: "default-rock", kind: .rock, relativeX: 0.82, relativeY: 0.88, scale: 1.1)
        let small = AquariumDecorationPlacement(kind: .smallRockA, relativeX: 0.5, relativeY: 0.92, scale: 1, isPlaced: false)
        #expect(AquariumDecorationEditorPresentation.inventory(from: [legacy]).map(\.kind) == [.rock])
        #expect(AquariumDecorationEditorPresentation.inventory(from: [legacy, small]).map(\.kind) == [.smallRockA])
        #expect(legacy.kindRawValue == "rock" && legacy.isPlaced && legacy.scale == 1.1)
        legacy.isPlaced = false
        #expect(AquariumDecorationEditorPresentation.inventory(from: [legacy, small]).map(\.kind) == [.rock, .smallRockA])
        legacy.isPlaced = true
        let ownedLegacy = AquariumDecorationPlacement(kind: .rock, relativeX: 0.5, relativeY: 0.84, scale: 1)
        #expect(AquariumDecorationEditorPresentation.inventory(from: [legacy, ownedLegacy, small]).first?.ownedCount == 2)
    }

    @Test func decorationLayerPriorityPrecedesYAndDraggingTemporarilyOverridesIt() {
        let rocks: [AquariumDecorationKind] = [.rock, .smallRockA, .smallRockB, .smallRockC, .mediumRockA, .mediumRockB, .mediumRockC]
        let plants: [AquariumDecorationKind] = [.seaweed, .seaweedA, .seaweedB, .seaweedC]
        for rock in rocks {
            #expect(rock.renderLayer == .rock)
            let back = AquariumDecorationDepthPresentation(kind: rock, relativeY: 0.72)
            let front = AquariumDecorationDepthPresentation(kind: rock, relativeY: 0.96)
            #expect(back.zIndex < front.zIndex)
            for plant in plants {
                #expect(plant.renderLayer == .vegetation)
                let vegetationBack = AquariumDecorationDepthPresentation(kind: plant, relativeY: 0.72)
                let vegetationFront = AquariumDecorationDepthPresentation(kind: plant, relativeY: 0.96)
                #expect(vegetationBack.zIndex < vegetationFront.zIndex)
                #expect(front.zIndex < vegetationBack.zIndex)
                #expect(back.renderZIndex(isDragging: true) > vegetationFront.zIndex)
                #expect(back.renderZIndex(isDragging: false) == back.zIndex)
            }
        }
        // 種類の優先度は、配置帯を外れた旧保存座標でも逆転しない。
        #expect(AquariumDecorationDepthPresentation(kind: .smallRockA, relativeY: 100).zIndex < AquariumDecorationDepthPresentation(kind: .seaweedA, relativeY: -100).zIndex)
    }

    @Test func restoredDecorationOrderUsesDefinitionWithoutNewSavedFields() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let rock = try AquariumDecorationService.addPlacement(kind: .smallRockA, at: CGPoint(x: 0.5, y: 0.96), isPlaced: true, in: context)
        let plant = try AquariumDecorationService.addPlacement(kind: .seaweedA, at: CGPoint(x: 0.5, y: 0.72), isPlaced: true, in: context)
        let reloaded = try ModelContext(container).fetch(FetchDescriptor<AquariumDecorationPlacement>())
        let savedRock = try #require(reloaded.first { $0.decorationID == rock.decorationID })
        let savedPlant = try #require(reloaded.first { $0.decorationID == plant.decorationID })
        #expect(savedRock.relativeX == 0.5 && savedRock.relativeY == 0.96)
        #expect(savedPlant.relativeX == 0.5 && savedPlant.relativeY == 0.72)
        #expect(AquariumDecorationDepthPresentation(kind: savedRock.kind, relativeY: CGFloat(savedRock.relativeY)).zIndex < AquariumDecorationDepthPresentation(kind: savedPlant.kind, relativeY: CGFloat(savedPlant.relativeY)).zIndex)
    }

    @Test func seaweedFramePlaybackLoopsInAssetOrderWithStablePlacementOffsets() {
        let frames = (0..<11).map { AquariumDecorationFramePlayback.frameIndex(step: $0, frameCount: 8) }
        #expect(frames == [0, 1, 2, 3, 4, 5, 6, 7, 0, 1, 2])
        #expect(AquariumDecorationFramePlayback.frameIndex(step: 7, frameCount: 1) == 0)
        #expect(AquariumDecorationFramePlayback.frameIndex(step: 7, frameCount: 0) == 0)
        let ids = ["developer-owned-seaweed-a"] + (2...5).map { "developer-owned-seaweed-a-\($0)" }
        let offsets = ids.map { AquariumDecorationFramePlayback.startFrameOffset(placementID: $0, frameCount: 8) }
        #expect(Set(offsets).count > 1)
        for (id, offset) in zip(ids, offsets) {
            #expect((0..<8).contains(offset))
            #expect(AquariumDecorationFramePlayback.startFrameOffset(placementID: id, frameCount: 8) == offset)
            #expect(AquariumDecorationFramePlayback.frameIndex(step: offset + 8, frameCount: 8) == offset)
        }
        #expect(AquariumDecorationFramePlayback.startFrameOffset(placementID: nil, frameCount: 8) == 0)
    }


    @Test func developmentOwnershipSeedsFiveIndependentPlacementsWithoutDuplicates() throws {
        let container = try makeContainer()
        let context = container.mainContext
#if DEBUG
        #expect(AquariumDeveloperDecorations.developerOwnedDecorationIDs.contains("seaweed-a"))
        #expect(AquariumDeveloperDecorations.developerOwnedDecorationIDs.contains("seaweed-b"))
        #expect(AquariumDeveloperDecorations.developerOwnedDecorationIDs.contains("seaweed_c"))
        #expect(AquariumDeveloperDecorations.ownedCountPerDecoration == 5)
        #expect(try AquariumDeveloperDecorations.seedIfNeeded(in: context))
        #expect(!(try AquariumDeveloperDecorations.seedIfNeeded(in: context)))
        let placementContext = ModelContext(container)
        let placements = try placementContext.fetch(FetchDescriptor<AquariumDecorationPlacement>())
        #expect(placements.count == 45)
        #expect(Set(placements.map(\.decorationID)).count == 45)
        #expect(Set(placements.map(\.definitionID)) == ["seaweed-a", "seaweed-b", "seaweed_c", "small_rock_a", "small_rock_b", "small_rock_c", "medium_rock_a", "medium_rock_b", "medium_rock_c"])
        #expect(placements.allSatisfy { !$0.isPlaced })
        let inventory = AquariumDecorationEditorPresentation.inventory(from: placements)
        #expect(inventory.map(\.kind) == [.seaweedA, .seaweedB, .seaweedC, .smallRockA, .smallRockB, .smallRockC, .mediumRockA, .mediumRockB, .mediumRockC])
        #expect(inventory.allSatisfy { $0.ownedCount == 5 && $0.canPlaceAnother })
        for (index, placement) in placements.enumerated() {
            try AquariumEditorDropCoordinator.placeDecoration(
                from: .decoration(id: placement.decorationID),
                placement: placement,
                at: CGPoint(x: CGFloat(60 + index * 40), y: 720),
                aquariumSize: CGSize(width: 300, height: 800),
                in: placementContext
            )
        }
        let reloadContext = ModelContext(container)
        let reloaded = try reloadContext.fetch(FetchDescriptor<AquariumDecorationPlacement>())
        #expect(reloaded.count == 45)
        #expect(reloaded.allSatisfy { $0.isPlaced })
        let placedInventory = AquariumDecorationEditorPresentation.inventory(from: reloaded)
        #expect(placedInventory.count == 9)
        #expect(placedInventory.allSatisfy { $0.placedCount == 5 && !$0.canPlaceAnother })
        #expect(!(try AquariumDeveloperDecorations.seedIfNeeded(in: context)))
#else
        #expect(AquariumDeveloperDecorations.developerOwnedDecorationIDs.isEmpty)
        #expect(AquariumDeveloperDecorations.ownedCountPerDecoration == 0)
        #expect(!(try AquariumDeveloperDecorations.seedIfNeeded(in: context)))
        #expect(try context.fetchCount(FetchDescriptor<AquariumDecorationPlacement>()) == 0)
#endif
    }

    @Test func disabledDevelopmentSeedingLeavesProductionInitialDataUnchanged() throws {
        let container = try makeContainer()
        let context = container.mainContext
        try AquariumDecorationService.createDefaultsIfNeeded(in: context)
        #expect(!(try AquariumDeveloperDecorations.seedIfNeeded(in: context, enabled: false)))
        let placements = try context.fetch(FetchDescriptor<AquariumDecorationPlacement>())
        #expect(Set(placements.map(\.decorationID)) == Set(["default-seaweed", "default-rock"]))
        #expect(!placements.contains { $0.kind.stars != nil })
    }

    @Test(arguments: [AquariumDecorationKind.seaweedA, .seaweedB, .seaweedC, .smallRockA, .smallRockB, .smallRockC, .mediumRockA, .mediumRockB, .mediumRockC])
    func seaweedDropIsGroundedAndUsesExistingPlacementPersistence(kind: AquariumDecorationKind) throws {
        let container = try makeContainer()
        let context = container.mainContext
        let placement = try AquariumDecorationService.addPlacement(kind: kind, in: context)
        try AquariumEditorDropCoordinator.placeDecoration(
            from: .decoration(id: placement.decorationID),
            placement: placement,
            at: CGPoint(x: 150, y: 200),
            aquariumSize: CGSize(width: 300, height: 800),
            in: context
        )
        let reloaded = try #require(ModelContext(container).fetch(
            FetchDescriptor<AquariumDecorationPlacement>()
        ).first)
        #expect(reloaded.isPlaced)
        #expect(reloaded.relativeX == 0.5)
        #expect(reloaded.relativeY == 0.72)
        #expect(reloaded.kind == kind)
        #expect(reloaded.kind.groundAnchorY == kind.groundAnchorY)
        let dragged = AquariumDecorationEditor.relativePosition(
            originalX: 0.5, originalY: 0.92,
            translation: CGSize(width: 30, height: -500),
            aquariumSize: CGSize(width: 300, height: 800),
            kind: kind, isEditing: true
        )
        #expect(dragged.x == 0.6)
        #expect(dragged.y == 0.72)
    }

    @Test func upgradingDevelopmentOwnershipPreservesThePreviouslyPlacedItem() throws {
#if DEBUG
        let container = try makeContainer()
        let context = container.mainContext
        let original = AquariumDecorationPlacement(
            decorationID: "developer-owned-seaweed-a", kind: .seaweedA,
            relativeX: 0.23, relativeY: 0.92, scale: 1.1, isPlaced: true
        )
        context.insert(original)
        try context.save()
        #expect(try AquariumDeveloperDecorations.seedIfNeeded(in: context))
        #expect(original.relativeX == 0.23)
        #expect(original.relativeY == 0.92)
        #expect(original.scale == 1.1)
        #expect(original.isPlaced)
        #expect(try context.fetchCount(FetchDescriptor<AquariumDecorationPlacement>()) == 45)
#endif
    }

    @Test(arguments: [CGFloat(240), CGFloat(393), CGFloat(800)], [AquariumDecorationKind.seaweedA, .seaweedB, .seaweedC, .smallRockA, .smallRockB, .smallRockC, .mediumRockA, .mediumRockB, .mediumRockC])
    func groundBoundsUseWideHorizontalRangeAndScaledContentMargins(width: CGFloat, kind: AquariumDecorationKind) {
        let size = CGSize(width: width, height: 852)
        for scale in [CGFloat(1), CGFloat(1.5)] {
            let bounds = AquariumDecorationEditor.placementBounds(for: kind, aquariumSize: size, scale: scale)
            let left = AquariumDecorationEditor.relativePosition(
                forDropLocation: CGPoint(x: -1000, y: -1000),
                aquariumSize: size, kind: kind, scale: scale
            )
            let right = AquariumDecorationEditor.relativePosition(
                forDropLocation: CGPoint(x: 10000, y: 10000),
                aquariumSize: size, kind: kind, scale: scale
            )
            #expect(left.x == bounds.x.lowerBound)
            #expect(right.x == bounds.x.upperBound)
            #expect(left.y == 0.72)
            #expect(right.y == 0.96)
            let content = kind.placementHorizontalContentBounds
            let leftContentWidth = kind.displaySize.width * scale * (0.5 - content.lowerBound)
            let rightContentWidth = kind.displaySize.width * scale * (content.upperBound - 0.5)
            let rootY = kind.groundAnchorY ?? 1
            // 拡大後の実幅が小さい画面を超えた場合は、左右へ均等に分配する。
            let overflow = max(0, (leftContentWidth + rightContentWidth - width) / 2)
            #expect(left.x * width - leftContentWidth >= -overflow - 0.000_001)
            #expect(right.x * width + rightContentWidth <= width + overflow + 0.000_001)
            if overflow > 0 {
                #expect(left.x == 0.5 && right.x == 0.5)
            }
            #expect(left.y * size.height - kind.displaySize.height * scale * rootY >= 0)
            #expect(right.y * size.height + kind.displaySize.height * scale * (1 - rootY) <= size.height)
        }
        let bounds = AquariumDecorationEditor.placementBounds(for: kind, aquariumSize: size)
        if width == 393 && (kind == .seaweedA || kind == .seaweedB) {
            #expect(bounds.x.lowerBound < 0.10)
            #expect(bounds.x.upperBound > 0.90)
        } else if width == 800 && (kind == .seaweedA || kind == .seaweedB) {
            #expect(bounds.x.lowerBound == 0.05)
            #expect(bounds.x.upperBound == 0.95)
        }
        let back = AquariumDecorationEditor.relativePosition(
            forDropLocation: CGPoint(x: width / 2, y: size.height * 0.82),
            aquariumSize: size, kind: kind
        )
        let front = AquariumDecorationEditor.relativePosition(
            originalX: back.x, originalY: back.y,
            translation: CGSize(width: 0, height: size.height * 0.12),
            aquariumSize: size, kind: kind, isEditing: true
        )
        #expect(abs(back.y - 0.82) < 0.000_001)
        #expect(abs(front.y - 0.94) < 0.000_001)
    }

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: AquariumDecorationPlacement.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @Test func groundedDropsAndPreviewsCanUseTheFrontOfTheSeabedWithoutChangingFishOrRockRules() {
        let size = CGSize(width: 393, height: 852)
        let location = CGPoint(x: 196.5, y: size.height * 0.95)
        #expect(AquariumEditorDropCoordinator.acceptsDecorationDrop(at: location, in: size, kind: .seaweedA))
        #expect(!AquariumSideEditorLayout.acceptsDrop(at: location, in: size))
        #expect(!AquariumEditorDropCoordinator.acceptsDecorationDrop(at: location, in: size, kind: .rock))
        let preview = AquariumDecorationEditor.dragPreviewPosition(
            forDropLocation: location, aquariumSize: size, kind: .seaweedA
        )
        #expect(preview == location)
        let center = AquariumDecorationEditor.dragPreviewPosition(
            forDropLocation: CGPoint(x: 196.5, y: 300), aquariumSize: size, kind: .seaweedA
        )
        #expect(center.y == size.height * 0.72)
        #expect(AquariumDecorationKind.seaweedA.groundAnchorOffset() < 0)
    }

    @Test(arguments: [AquariumDecorationKind.seaweedA, .seaweedB, .seaweedC, .smallRockA, .smallRockB, .smallRockC, .mediumRockA, .mediumRockB, .mediumRockC])
    func groundDepthInterpolatesSizeOpacityAndOrderingWithoutChangingStoredScale(kind: AquariumDecorationKind) throws {
        #expect(kind.movementBounds.y.lowerBound < 0.78)
        let back = AquariumDecorationDepthPresentation(kind: kind, relativeY: 0.72)
        let middle = AquariumDecorationDepthPresentation(kind: kind, relativeY: 0.84)
        let front = AquariumDecorationDepthPresentation(kind: kind, relativeY: 0.96)
        #expect(back.depthProgress == 1)
        #expect(front.depthProgress == 0)
        #expect(abs(middle.depthProgress - 0.5) < 0.000_001)
        #expect(back.scale == 0.76)
        #expect(front.scale == 1)
        #expect(abs(middle.scale - 0.88) < 0.000_001)
        #expect(back.opacity == 0.80)
        #expect(front.opacity == 1)
        #expect(back.zIndex < middle.zIndex && middle.zIndex < front.zIndex)
        #expect(AquariumDecorationDepthPresentation(kind: kind, relativeY: 0).scale == back.scale)
        let legacy = AquariumDecorationDepthPresentation(kind: .rock, relativeY: 0.84)
        #expect(legacy.scale == 1 && legacy.opacity == 1)
        let container = try makeContainer()
        let placement = try AquariumDecorationService.addPlacement(kind: kind, scale: 1.1, in: container.mainContext)
        try AquariumDecorationService.confirmPlacement(placement, at: CGPoint(x: 0.5, y: 0.72), in: container.mainContext)
        let restoredContext = ModelContext(container)
        let restored = try #require(restoredContext.fetch(FetchDescriptor<AquariumDecorationPlacement>()).first)
        #expect(restored.scale == 1.1)
        #expect(AquariumDecorationDepthPresentation(kind: restored.kind, relativeY: CGFloat(restored.relativeY)).scale == back.scale)
    }

    @Test func decorationFocusUsesSelectionRatherThanDragLifetimeAndSharesTheChromeVisibilitySignal() {
        // drag終了/別個体への選択切替でも選択は残り、同じ判定で両方のbarを隠す。
        let selected = AquariumDecorationEditingPresentation.isFocused(
            isEditing: true, isDecorationCategory: true, hasSelection: true
        )
        #expect(selected)
        #expect(!AquariumDecorationEditingPresentation.isFocused(
            isEditing: true, isDecorationCategory: true, hasSelection: false
        )) // 空いている水槽をtapして選択解除。
        #expect(!AquariumDecorationEditingPresentation.isFocused(
            isEditing: false, isDecorationCategory: true, hasSelection: true
        ))
        #expect(!AquariumDecorationEditingPresentation.isFocused(
            isEditing: true, isDecorationCategory: false, hasSelection: true
        ))
        var preference = AquariumDecorationEditingPreferenceKey.defaultValue
        AquariumDecorationEditingPreferenceKey.reduce(value: &preference) { selected }
        AquariumDecorationEditingPreferenceKey.reduce(value: &preference) { false }
        #expect(preference)
    }
}
