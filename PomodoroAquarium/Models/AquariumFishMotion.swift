import CoreGraphics
import Foundation

enum AquariumFishMotion {
    enum Behavior: CaseIterable {
        case hovering
        case cruising
        case darting
        case braking
        case turning
    }

    static let horizontalRange: ClosedRange<CGFloat> = 0.18...0.82
    static let verticalRange: ClosedRange<CGFloat> = 0.16...0.62
    static let maximumDeltaTime: TimeInterval = 1.0 / 15.0

    struct State {
        var position: CGPoint
        var velocity: CGVector
        var desiredDirection: CGVector
        var behavior: Behavior
        var behaviorTimeRemaining: TimeInterval
        var anchorPosition: CGPoint

        let baseSpeed: CGFloat
        var currentSpeed: CGFloat
        var targetSpeed: CGFloat
        let accelerationResponse: CGFloat
        let brakingResponse: CGFloat
        let turnResponsiveness: CGFloat
        let hoverRadius: CGFloat
        let dashTendency: CGFloat

        var directionChangeTimeRemaining: TimeInterval
        var noisePhaseX: CGFloat
        var noisePhaseY: CGFloat
        var swimPhase: CGFloat
        var accelerationMagnitude: CGFloat

        var facingSign: CGFloat
        var facingWidth: CGFloat
        var pendingFacingSign: CGFloat
        var pendingFacingDuration: TimeInterval
        var visualTurnTargetSign: CGFloat?
        var visualTurnProgress: CGFloat
        var visualTurnDuration: TimeInterval

        var randomState: UInt64

        mutating func advance(deltaTime rawDeltaTime: TimeInterval, elapsedTime: TimeInterval) {
            let deltaTime = min(max(rawDeltaTime, 0), AquariumFishMotion.maximumDeltaTime)
            guard deltaTime > 0 else { return }

            behaviorTimeRemaining -= deltaTime
            directionChangeTimeRemaining -= deltaTime
            if behaviorTimeRemaining <= 0 {
                transitionBehavior()
            } else if directionChangeTimeRemaining <= 0, behavior != .darting, behavior != .braking {
                wanderDirection()
            }

            let noise = AquariumFishMotion.smoothNoise(
                time: elapsedTime,
                phaseX: noisePhaseX,
                phaseY: noisePhaseY
            )
            let behaviorSteering = steeringForCurrentBehavior(noise: noise)
            let speedRatio = currentSpeed / max(baseSpeed, 0.001)
            let wallStrength = AquariumFishMotion.wallStrength(
                behavior: behavior,
                speedRatio: speedRatio
            )
            let wallForce = AquariumFishMotion.wallSteering(at: position, strength: wallStrength)
            let targetDirection = AquariumFishMotion.normalized(CGVector(
                dx: desiredDirection.dx + behaviorSteering.dx + wallForce.dx,
                dy: desiredDirection.dy + behaviorSteering.dy + wallForce.dy
            ))

            let stateTurnMultiplier: CGFloat = behavior == .turning ? 2.2 : (behavior == .darting ? 0.72 : 1)
            let steeringAmount = 1 - exp(-turnResponsiveness * stateTurnMultiplier * CGFloat(deltaTime))
            let currentDirection = AquariumFishMotion.normalized(velocity)
            let blendedDirection = AquariumFishMotion.normalized(CGVector(
                dx: currentDirection.dx + (targetDirection.dx - currentDirection.dx) * steeringAmount,
                dy: currentDirection.dy + (targetDirection.dy - currentDirection.dy) * steeringAmount
            ))

            updateSpeed(deltaTime: deltaTime)
            velocity = CGVector(dx: blendedDirection.dx * currentSpeed, dy: blendedDirection.dy * currentSpeed)
            position.x += velocity.dx * CGFloat(deltaTime)
            position.y += velocity.dy * CGFloat(deltaTime)
            position.x = min(max(position.x, horizontalRange.lowerBound), horizontalRange.upperBound)
            position.y = min(max(position.y, verticalRange.lowerBound), verticalRange.upperBound)

            updateFacing(deltaTime: deltaTime)
            updateSwimPhase(deltaTime: deltaTime)
        }

        private mutating func steeringForCurrentBehavior(noise: CGVector) -> CGVector {
            switch behavior {
            case .hovering:
                let offset = CGVector(dx: anchorPosition.x - position.x, dy: anchorPosition.y - position.y)
                let distance = hypot(offset.dx, offset.dy)
                let restoringStrength = min(distance / max(hoverRadius, 0.001), 1) * 0.85
                return CGVector(
                    dx: offset.dx / max(hoverRadius, 0.001) * restoringStrength + noise.dx * 0.34,
                    dy: offset.dy / max(hoverRadius, 0.001) * restoringStrength + noise.dy * 0.42
                )
            case .cruising:
                return CGVector(dx: noise.dx * 0.18, dy: noise.dy * 0.25)
            case .darting:
                return CGVector(dx: noise.dx * 0.045, dy: noise.dy * 0.06)
            case .braking:
                return CGVector(dx: noise.dx * 0.16, dy: noise.dy * 0.22)
            case .turning:
                return CGVector(dx: noise.dx * 0.24, dy: noise.dy * 0.30)
            }
        }

        private mutating func updateSpeed(deltaTime: TimeInterval) {
            let previousSpeed = currentSpeed
            let response = targetSpeed > currentSpeed ? accelerationResponse : brakingResponse
            let amount = 1 - exp(-response * CGFloat(deltaTime))
            currentSpeed += (targetSpeed - currentSpeed) * amount
            accelerationMagnitude = abs(currentSpeed - previousSpeed) / max(CGFloat(deltaTime), 0.001)
        }

        private mutating func updateSwimPhase(deltaTime: TimeInterval) {
            let speedRatio = currentSpeed / max(baseSpeed, 0.001)
            let phaseVelocity = 2.0 + min(speedRatio, 3) * 3.2 + min(accelerationMagnitude * 24, 3)
            swimPhase += phaseVelocity * CGFloat(deltaTime)
            if swimPhase > .pi * 2 { swimPhase.formTruncatingRemainder(dividingBy: .pi * 2) }
        }

        private mutating func updateFacing(deltaTime: TimeInterval) {
            if let targetSign = visualTurnTargetSign {
                visualTurnProgress = min(visualTurnProgress + CGFloat(deltaTime / visualTurnDuration), 1)
                let distanceFromMiddle = abs(visualTurnProgress - 0.5) * 2
                facingWidth = 0.55 + 0.45 * distanceFromMiddle
                if visualTurnProgress >= 0.5, facingSign != targetSign {
                    facingSign = targetSign
                }
                if visualTurnProgress >= 1 {
                    facingWidth = 1
                    visualTurnTargetSign = nil
                    visualTurnProgress = 0
                }
                return
            }

            let threshold = max(baseSpeed * 0.24, 0.008)
            let intendedSign: CGFloat?
            if velocity.dx > threshold {
                intendedSign = -1 // 現在の1枚素材は左向きが基準。
            } else if velocity.dx < -threshold {
                intendedSign = 1
            } else {
                intendedSign = nil
            }

            guard let intendedSign else {
                pendingFacingDuration = max(0, pendingFacingDuration - deltaTime * 0.5)
                return
            }
            if intendedSign != pendingFacingSign {
                pendingFacingSign = intendedSign
                pendingFacingDuration = 0
            } else {
                pendingFacingDuration += deltaTime
            }

            if pendingFacingDuration >= 0.38, intendedSign != facingSign {
                visualTurnTargetSign = intendedSign
                visualTurnDuration = random(in: 0.55...0.9)
                visualTurnProgress = 0
                pendingFacingDuration = 0
            }
        }

        private mutating func transitionBehavior() {
            let next: Behavior
            switch behavior {
            case .hovering:
                next = chance(dashTendency) ? .darting : .cruising
            case .cruising:
                let roll = randomUnit()
                if roll < dashTendency {
                    next = .darting
                } else if roll < 0.52 {
                    next = .hovering
                } else {
                    next = .turning
                }
            case .darting:
                next = .braking
            case .braking:
                next = chance(0.58) ? .hovering : .cruising
            case .turning:
                next = chance(0.28) ? .hovering : .cruising
            }
            enter(next)
        }

        private mutating func enter(_ next: Behavior) {
            behavior = next
            switch next {
            case .hovering:
                behaviorTimeRemaining = random(in: 1.8...4.8)
                anchorPosition = position
                targetSpeed = baseSpeed * random(in: 0.18...0.32)
                directionChangeTimeRemaining = random(in: 1.1...2.4)
            case .cruising:
                behaviorTimeRemaining = random(in: 3.0...7.5)
                targetSpeed = baseSpeed * random(in: 0.82...1.18)
                directionChangeTimeRemaining = random(in: 1.5...3.8)
                desiredDirection = perturbedDirection(maxAngle: 0.34)
            case .darting:
                behaviorTimeRemaining = random(in: 0.15...0.6)
                targetSpeed = baseSpeed * random(in: 1.8...3.0)
                directionChangeTimeRemaining = behaviorTimeRemaining
                desiredDirection = perturbedDirection(maxAngle: 0.22)
            case .braking:
                behaviorTimeRemaining = random(in: 0.2...0.8)
                targetSpeed = baseSpeed * random(in: 0.08...0.24)
                directionChangeTimeRemaining = behaviorTimeRemaining
            case .turning:
                behaviorTimeRemaining = random(in: 0.7...1.55)
                targetSpeed = baseSpeed * random(in: 0.38...0.68)
                directionChangeTimeRemaining = behaviorTimeRemaining
                let turnAngle = random(in: 0.75...1.5) * (chance(0.5) ? 1 : -1)
                desiredDirection = AquariumFishMotion.rotated(desiredDirection, by: turnAngle)
            }
        }

        private mutating func wanderDirection() {
            let maxAngle: CGFloat = behavior == .hovering ? 0.5 : 0.28
            desiredDirection = perturbedDirection(maxAngle: maxAngle)
            directionChangeTimeRemaining = random(in: 1.3...3.9)
        }

        private mutating func perturbedDirection(maxAngle: CGFloat) -> CGVector {
            AquariumFishMotion.rotated(desiredDirection, by: random(in: -maxAngle...maxAngle))
        }

        private mutating func chance(_ probability: CGFloat) -> Bool {
            randomUnit() < probability
        }

        private mutating func random(in range: ClosedRange<CGFloat>) -> CGFloat {
            range.lowerBound + randomUnit() * (range.upperBound - range.lowerBound)
        }

        private mutating func random(in range: ClosedRange<TimeInterval>) -> TimeInterval {
            range.lowerBound + Double(randomUnit()) * (range.upperBound - range.lowerBound)
        }

        private mutating func randomUnit() -> CGFloat {
            // 魚個体が保持する軽量PRNG。毎フレーム生成せず、状態遷移時だけ進める。
            randomState = randomState &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return CGFloat((randomState >> 40) & 0xFF_FFFF) / CGFloat(0xFF_FFFF)
        }
    }

    static func initialState(for id: UUID) -> State {
        let bytes = withUnsafeBytes(of: id.uuid) { Array($0) }
        let angle = CGFloat(bytes[4]) / 255 * .pi * 2
        let baseSpeed = 0.027 + CGFloat(bytes[5]) / 255 * 0.013
        let direction = normalized(CGVector(dx: cos(angle), dy: sin(angle) * 0.5))
        let facingSign: CGFloat = direction.dx >= 0 ? -1 : 1
        let initialBehavior: Behavior = bytes[11].isMultiple(of: 3) ? .hovering : .cruising

        return State(
            position: initialPosition(for: id),
            velocity: CGVector(dx: direction.dx * baseSpeed, dy: direction.dy * baseSpeed),
            desiredDirection: direction,
            behavior: initialBehavior,
            behaviorTimeRemaining: 1.5 + Double(bytes[9]) / 255 * 3.0,
            anchorPosition: initialPosition(for: id),
            baseSpeed: baseSpeed,
            currentSpeed: initialBehavior == .hovering ? baseSpeed * 0.25 : baseSpeed,
            targetSpeed: initialBehavior == .hovering ? baseSpeed * 0.25 : baseSpeed,
            accelerationResponse: 5.2 + CGFloat(bytes[6]) / 255 * 2.2,
            brakingResponse: 6.5 + CGFloat(bytes[7]) / 255 * 3.0,
            turnResponsiveness: 0.7 + CGFloat(bytes[8]) / 255 * 0.5,
            hoverRadius: 0.025 + CGFloat(bytes[12]) / 255 * 0.03,
            dashTendency: 0.08 + CGFloat(bytes[13]) / 255 * 0.09,
            directionChangeTimeRemaining: 1.2 + Double(bytes[10]) / 255 * 2.7,
            noisePhaseX: CGFloat(bytes[14]) / 255 * .pi * 2,
            noisePhaseY: CGFloat(bytes[15]) / 255 * .pi * 2,
            swimPhase: CGFloat(bytes[3]) / 255 * .pi * 2,
            accelerationMagnitude: 0,
            facingSign: facingSign,
            facingWidth: 1,
            pendingFacingSign: facingSign,
            pendingFacingDuration: 0,
            visualTurnTargetSign: nil,
            visualTurnProgress: 0,
            visualTurnDuration: 0.7,
            randomState: seed(from: bytes)
        )
    }

    static func initialPosition(for id: UUID) -> CGPoint {
        let bytes = withUnsafeBytes(of: id.uuid) { Array($0) }
        let xFraction = CGFloat(Int(bytes[0]) * 256 + Int(bytes[1])) / 65_535
        let yFraction = CGFloat(Int(bytes[2]) * 256 + Int(bytes[3])) / 65_535
        return point(xFraction: xFraction, yFraction: yFraction)
    }

    static func point(xFraction: CGFloat, yFraction: CGFloat) -> CGPoint {
        let x = horizontalRange.lowerBound
            + min(max(xFraction, 0), 1) * (horizontalRange.upperBound - horizontalRange.lowerBound)
        let y = verticalRange.lowerBound
            + min(max(yFraction, 0), 1) * (verticalRange.upperBound - verticalRange.lowerBound)
        return CGPoint(
            x: min(max(x, horizontalRange.lowerBound), horizontalRange.upperBound),
            y: min(max(y, verticalRange.lowerBound), verticalRange.upperBound)
        )
    }

    static func smoothNoise(time: TimeInterval, phaseX: CGFloat, phaseY: CGFloat) -> CGVector {
        let time = CGFloat(time)
        // 周期と位相の異なる成分を重ね、単一sin波の規則的な往復を避ける。
        let x = sin(time * 0.37 + phaseX) * 0.55
            + sin(time * 0.19 + phaseY * 1.7) * 0.30
            + sin(time * 0.071 + phaseX * 0.43) * 0.15
        let y = sin(time * 0.31 + phaseY) * 0.50
            + sin(time * 0.137 + phaseX * 1.3) * 0.32
            + sin(time * 0.053 + phaseY * 0.61) * 0.18
        return CGVector(dx: x, dy: y)
    }

    static func wallSteering(at position: CGPoint, strength: CGFloat = 1) -> CGVector {
        let horizontalMargin: CGFloat = 0.15
        let verticalMargin: CGFloat = 0.12
        var force = CGVector.zero
        force.dx += edgeForce(position.x - horizontalRange.lowerBound, margin: horizontalMargin)
        force.dx -= edgeForce(horizontalRange.upperBound - position.x, margin: horizontalMargin)
        force.dy += edgeForce(position.y - verticalRange.lowerBound, margin: verticalMargin)
        force.dy -= edgeForce(verticalRange.upperBound - position.y, margin: verticalMargin)
        return CGVector(dx: force.dx * 1.8 * strength, dy: force.dy * 1.45 * strength)
    }

    static func wallStrength(behavior: Behavior, speedRatio: CGFloat) -> CGFloat {
        let behaviorScale: CGFloat
        switch behavior {
        case .hovering: behaviorScale = 0.8
        case .cruising: behaviorScale = 1
        case .darting: behaviorScale = 1.35
        case .braking: behaviorScale = 1.1
        case .turning: behaviorScale = 1.2
        }
        return behaviorScale * min(max(0.8 + speedRatio * 0.22, 0.8), 1.5)
    }

    static func normalized(_ vector: CGVector) -> CGVector {
        let length = hypot(vector.dx, vector.dy)
        guard length > 0.0001 else { return CGVector(dx: 1, dy: 0) }
        return CGVector(dx: vector.dx / length, dy: vector.dy / length)
    }

    static func rotated(_ vector: CGVector, by angle: CGFloat) -> CGVector {
        normalized(CGVector(
            dx: vector.dx * cos(angle) - vector.dy * sin(angle),
            dy: vector.dx * sin(angle) + vector.dy * cos(angle)
        ))
    }

    private static func edgeForce(_ distance: CGFloat, margin: CGFloat) -> CGFloat {
        guard distance < margin else { return 0 }
        let proximity = min(max((margin - distance) / margin, 0), 1)
        return proximity * proximity
    }

    private static func seed(from bytes: [UInt8]) -> UInt64 {
        bytes.reduce(14_695_981_039_346_656_037) { ($0 ^ UInt64($1)) &* 1_099_511_628_211 }
    }
}
