import CoreGraphics
import SwiftData

enum AquariumDecorationService {
    static let defaultDecorations: [AquariumDecoration] = [
        AquariumDecoration(
            id: "default-seaweed",
            kind: .seaweed,
            relativeX: 0.14,
            relativeY: 0.82,
            scale: 1.0
        ),
        AquariumDecoration(
            id: "default-rock",
            kind: .rock,
            relativeX: 0.82,
            relativeY: 0.88,
            scale: 1.1
        )
    ]

    @discardableResult
    static func createDefaultsIfNeeded(in context: ModelContext) throws -> Bool {
        let descriptor = FetchDescriptor<AquariumDecorationPlacement>()
        let existingIDs = Set(try context.fetch(descriptor).map(\.decorationID))
        let missingDefaults = defaultDecorations.filter { !existingIDs.contains($0.id) }
        guard !missingDefaults.isEmpty else { return false }

        for decoration in missingDefaults {
            context.insert(AquariumDecorationPlacement(
                decorationID: decoration.id,
                kind: decoration.kind,
                relativeX: Double(decoration.relativeX),
                relativeY: Double(decoration.relativeY),
                scale: Double(decoration.scale)
            ))
        }
        try context.save()
        return true
    }

    /// ショップ等で装飾を1個入手する際に利用できる個体単位の追加処理。
    /// 同じkindでも毎回異なるUUIDを持つため、独立して配置・収納できる。
    @discardableResult
    static func addPlacement(
        kind: AquariumDecorationKind,
        at position: CGPoint? = nil,
        scale: Double = 1,
        isPlaced: Bool = false,
        in context: ModelContext
    ) throws -> AquariumDecorationPlacement {
        let initialPosition = position ?? kind.restorationPosition
        let placement = AquariumDecorationPlacement(
            kind: kind,
            relativeX: Double(initialPosition.x),
            relativeY: Double(initialPosition.y),
            scale: scale,
            isPlaced: isPlaced
        )
        context.insert(placement)
        try context.save()
        return placement
    }

    static func storedPlacements(
        from placements: [AquariumDecorationPlacement],
        category: AquariumDecorationCategory? = nil
    ) -> [AquariumDecorationPlacement] {
        placements.filter { placement in
            !placement.isPlaced && (category == nil || placement.kind.category == category)
        }
    }

    static func confirmPlacement(
        _ placement: AquariumDecorationPlacement,
        at position: CGPoint,
        in context: ModelContext,
        persistChanges: Bool = true
    ) throws {
        placement.relativeX = Double(position.x)
        placement.relativeY = Double(position.y)
        placement.isPlaced = true
        if persistChanges {
            try context.save()
        }
    }

    static func store(
        _ placement: AquariumDecorationPlacement,
        in context: ModelContext,
        persistChanges: Bool = true
    ) throws {
        placement.isPlaced = false
        if persistChanges {
            try context.save()
        }
    }
}

enum AquariumDecorationEditor {
    static func dragPreviewPosition(
        forDropLocation location: CGPoint,
        aquariumSize: CGSize,
        kind: AquariumDecorationKind,
        scale: CGFloat = 1
    ) -> CGPoint {
        guard kind.groundAnchorY != nil,
              aquariumSize.width > 0, aquariumSize.height > 0,
              location.x >= 0, location.x <= aquariumSize.width else { return location }
        let relative = relativePosition(
            forDropLocation: location, aquariumSize: aquariumSize, kind: kind, scale: scale
        )
        return CGPoint(x: relative.x * aquariumSize.width, y: relative.y * aquariumSize.height)
    }

    static func relativePosition(
        forDropLocation location: CGPoint,
        aquariumSize: CGSize,
        kind: AquariumDecorationKind,
        scale: CGFloat = 1,
        groundBand: AquariumDecorationMovementBounds? = nil
    ) -> CGPoint {
        guard aquariumSize.width > 0, aquariumSize.height > 0 else {
            return kind.restorationPosition
        }

        let bounds = placementBounds(for: kind, aquariumSize: aquariumSize, scale: scale, groundBand: groundBand)
        let proposedX = location.x / aquariumSize.width
        let proposedY = location.y / aquariumSize.height
        return CGPoint(
            x: min(max(proposedX, bounds.x.lowerBound), bounds.x.upperBound),
            y: min(max(proposedY, bounds.y.lowerBound), bounds.y.upperBound)
        )
    }

    static func relativePosition(
        originalX: CGFloat,
        originalY: CGFloat,
        translation: CGSize,
        aquariumSize: CGSize,
        kind: AquariumDecorationKind,
        isEditing: Bool,
        scale: CGFloat = 1,
        groundBand: AquariumDecorationMovementBounds? = nil
    ) -> CGPoint {
        guard isEditing, aquariumSize.width > 0, aquariumSize.height > 0 else {
            return CGPoint(x: originalX, y: originalY)
        }

        let bounds = placementBounds(for: kind, aquariumSize: aquariumSize, scale: scale, groundBand: groundBand)
        let proposedX = originalX + translation.width / aquariumSize.width
        let proposedY = originalY + translation.height / aquariumSize.height

        return CGPoint(
            x: min(max(proposedX, bounds.x.lowerBound), bounds.x.upperBound),
            y: min(max(proposedY, bounds.y.lowerBound), bounds.y.upperBound)
        )
    }

    /// dropと配置済み個体のdragで同じroot基準のclampを使用する。
    static func placementBounds(
        for kind: AquariumDecorationKind,
        aquariumSize: CGSize,
        scale: CGFloat = 1,
        groundBand: AquariumDecorationMovementBounds? = nil
    ) -> AquariumDecorationMovementBounds {
        guard let rootY = kind.groundAnchorY,
              aquariumSize.width > 0, aquariumSize.height > 0 else {
            return kind.movementBounds // 既存の水草・岩の配置仕様は維持。
        }
        let band = groundBand ?? kind.movementBounds
        let content = kind.placementHorizontalContentBounds
        let width = kind.displaySize.width * max(scale, 0)
        let height = kind.displaySize.height * max(scale, 0)
        let leftMargin = max(0, 0.5 - content.lowerBound) * width / aquariumSize.width
        let rightMargin = max(0, content.upperBound - 0.5) * width / aquariumSize.width
        let topMargin = rootY * height / aquariumSize.height
        let bottomMargin = (1 - rootY) * height / aquariumSize.height
        return AquariumDecorationMovementBounds(
            x: safeRange(max(band.x.lowerBound, leftMargin), min(band.x.upperBound, 1 - rightMargin)),
            y: safeRange(max(band.y.lowerBound, topMargin), min(band.y.upperBound, 1 - bottomMargin))
        )
    }

    private static func safeRange(_ lower: CGFloat, _ upper: CGFloat) -> ClosedRange<CGFloat> {
        // 表示領域より装飾が大きい場合でも逆転rangeを作らず、rootを画面内に保つ。
        guard lower <= upper else { return 0.5...0.5 }
        return lower...upper
    }
}
