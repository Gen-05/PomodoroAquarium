import CoreGraphics
import Foundation

enum FishFacingDirection: Int, CaseIterable {
    case right = 0
    case downRight = 1
    case down = 2
    case downLeft = 3
    case left = 4
    case upLeft = 5
    case up = 6
    case upRight = 7
    case front = 8

    var isLeftFacing: Bool {
        switch self {
        case .left, .upLeft, .downLeft:
            true
        case .right, .upRight, .up, .downRight, .down, .front:
            false
        }
    }

    var angle: CGFloat? {
        guard self != .front else { return nil }
        return CGFloat(rawValue) * .pi / 4
    }

    /// side画像を1.0とした見かけサイズ補正。方向素材のキャンバス占有率差をここへ集約する。
    var directionScale: CGFloat {
        1.0
    }

    static func quantized(
        velocity: CGVector,
        depthVelocity: CGFloat = 0,
        frontPlanarSpeedThreshold: CGFloat = 0
    ) -> FishFacingDirection {
        let planarSpeed = hypot(velocity.dx, velocity.dy)
        guard planarSpeed > 0.0001 else { return .right }
        var angle = atan2(velocity.dy, velocity.dx)
        if angle < 0 { angle += .pi * 2 }
        let sector = Int((angle + .pi / 8) / (.pi / 4)) % 8
        return FishFacingDirection(rawValue: sector) ?? .right
    }

    static func quantized(
        velocity: CGVector,
        depthVelocity: CGFloat,
        frontPlanarSpeedThreshold: CGFloat,
        retaining current: FishFacingDirection,
        angularHysteresis: CGFloat = .pi / 18
    ) -> FishFacingDirection {
        let candidate = quantized(
            velocity: velocity,
            depthVelocity: depthVelocity,
            frontPlanarSpeedThreshold: frontPlanarSpeedThreshold
        )
        guard current != .front,
              let currentAngle = current.angle else {
            return candidate
        }

        var heading = atan2(velocity.dy, velocity.dx)
        if heading < 0 { heading += .pi * 2 }
        let difference = abs(heading - currentAngle)
        let distanceFromCurrentCenter = min(difference, .pi * 2 - difference)
        return distanceFromCurrentCenter <= .pi / 8 + angularHysteresis ? current : candidate
    }

    static func angularDistance(from lhs: FishFacingDirection, to rhs: FishFacingDirection) -> CGFloat {
        guard let lhsAngle = lhs.angle, let rhsAngle = rhs.angle else {
            return lhs == rhs ? 0 : .pi
        }
        let difference = abs(lhsAngle - rhsAngle)
        return min(difference, .pi * 2 - difference)
    }

}

/// 8方向の判定結果とは分離した、表示専用のスプライト姿勢。
/// sideとdiagonal方向間の表示専用中間姿勢を表す。
enum FishSpritePose: Hashable {
    case facing(FishFacingDirection)
    case sideToDiagonalUp15(isLeftFacing: Bool)
    case sideToDiagonalDown15(isLeftFacing: Bool)
}

struct FishSpriteDirectionTransition {
    static let intermediateDuration: TimeInterval = 0.18

    private(set) var displayedDirection: FishFacingDirection
    private(set) var intermediatePose: FishSpritePose?
    private(set) var targetDirection: FishFacingDirection?
    private(set) var remainingDuration: TimeInterval = 0

    init(direction: FishFacingDirection) {
        displayedDirection = direction
    }

    var pose: FishSpritePose {
        intermediatePose ?? .facing(displayedDirection)
    }

    var isTransitioning: Bool {
        targetDirection != nil
    }

    mutating func update(
        toward candidate: FishFacingDirection,
        deltaTime: TimeInterval
    ) {
        if let targetDirection {
            remainingDuration -= max(deltaTime, 0)
            if remainingDuration <= 0 {
                displayedDirection = targetDirection
                intermediatePose = nil
                self.targetDirection = nil
                remainingDuration = 0
            }
            return
        }

        guard candidate != displayedDirection else { return }
        if let pose = Self.intermediatePose(from: displayedDirection, to: candidate) {
            intermediatePose = pose
            targetDirection = candidate
            remainingDuration = Self.intermediateDuration
        } else {
            displayedDirection = candidate
        }
    }

    static func intermediatePose(
        from source: FishFacingDirection,
        to target: FishFacingDirection
    ) -> FishSpritePose? {
        switch (source, target) {
        case (.right, .upRight), (.upRight, .right):
            .sideToDiagonalUp15(isLeftFacing: false)
        case (.left, .upLeft), (.upLeft, .left):
            .sideToDiagonalUp15(isLeftFacing: true)
        case (.right, .downRight), (.downRight, .right):
            .sideToDiagonalDown15(isLeftFacing: false)
        case (.left, .downLeft), (.downLeft, .left):
            .sideToDiagonalDown15(isLeftFacing: true)
        default:
            nil
        }
    }
}
