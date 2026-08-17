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
        in context: ModelContext
    ) throws {
        placement.relativeX = Double(position.x)
        placement.relativeY = Double(position.y)
        placement.isPlaced = true
        try context.save()
    }

    static func store(
        _ placement: AquariumDecorationPlacement,
        in context: ModelContext
    ) throws {
        placement.isPlaced = false
        try context.save()
    }
}

enum AquariumDecorationEditor {
    static func relativePosition(
        originalX: CGFloat,
        originalY: CGFloat,
        translation: CGSize,
        aquariumSize: CGSize,
        kind: AquariumDecorationKind,
        isEditing: Bool
    ) -> CGPoint {
        guard isEditing, aquariumSize.width > 0, aquariumSize.height > 0 else {
            return CGPoint(x: originalX, y: originalY)
        }

        let bounds = kind.movementBounds
        let proposedX = originalX + translation.width / aquariumSize.width
        let proposedY = originalY + translation.height / aquariumSize.height

        return CGPoint(
            x: min(max(proposedX, bounds.x.lowerBound), bounds.x.upperBound),
            y: min(max(proposedY, bounds.y.lowerBound), bounds.y.upperBound)
        )
    }
}
