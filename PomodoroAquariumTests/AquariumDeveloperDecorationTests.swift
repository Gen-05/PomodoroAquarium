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
        #expect(AquariumDeveloperDecorations.ownedCountPerDecoration == 5)
        #expect(try AquariumDeveloperDecorations.seedIfNeeded(in: context))
        #expect(!(try AquariumDeveloperDecorations.seedIfNeeded(in: context)))
        let placementContext = ModelContext(container)
        let placements = try placementContext.fetch(FetchDescriptor<AquariumDecorationPlacement>())
        #expect(placements.count == 10)
        #expect(Set(placements.map(\.decorationID)).count == 10)
        #expect(Set(placements.map(\.definitionID)) == ["seaweed-a", "seaweed-b"])
        #expect(placements.allSatisfy { !$0.isPlaced })
        let inventory = AquariumDecorationEditorPresentation.inventory(from: placements)
        #expect(inventory.map(\.kind) == [.seaweedA, .seaweedB])
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
        #expect(reloaded.count == 10)
        #expect(reloaded.allSatisfy { $0.isPlaced })
        let placedInventory = AquariumDecorationEditorPresentation.inventory(from: reloaded)
        #expect(placedInventory.count == 2)
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
        #expect(!placements.contains { $0.kind == .seaweedA || $0.kind == .seaweedB })
    }

    @Test(arguments: [AquariumDecorationKind.seaweedA, .seaweedB])
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
        #expect(try context.fetchCount(FetchDescriptor<AquariumDecorationPlacement>()) == 10)
#endif
    }

    @Test(arguments: [CGFloat(240), CGFloat(393), CGFloat(800)], [AquariumDecorationKind.seaweedA, .seaweedB])
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
            #expect(left.x * width - leftContentWidth >= -0.000_001)
            #expect(right.x * width + rightContentWidth <= width + 0.000_001)
            #expect(left.y * size.height - kind.displaySize.height * scale * rootY >= 0)
            #expect(right.y * size.height + kind.displaySize.height * scale * (1 - rootY) <= size.height)
        }
        let bounds = AquariumDecorationEditor.placementBounds(for: kind, aquariumSize: size)
        if width == 393 {
            #expect(bounds.x.lowerBound < 0.10)
            #expect(bounds.x.upperBound > 0.90)
        } else if width == 800 {
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

    @Test(arguments: [AquariumDecorationKind.seaweedA, .seaweedB])
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
