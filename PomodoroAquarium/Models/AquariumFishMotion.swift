import CoreGraphics
import Foundation

struct FishMovementProfile {
    let baseSpeedRange: ClosedRange<CGFloat>
    let hoverProbability: CGFloat
    let burstProbability: CGFloat
    let gatheringProbability: CGFloat
    let wanderingRadiusX: ClosedRange<CGFloat>
    let wanderingRadiusY: ClosedRange<CGFloat>
    let turnResponsivenessRange: ClosedRange<CGFloat>
    let depthRange: ClosedRange<CGFloat>
    let depthScaleRange: ClosedRange<CGFloat>
    let depthOpacityRange: ClosedRange<CGFloat>
    let depthSpeedRange: ClosedRange<CGFloat>
    let depthChangeProbability: CGFloat
    let depthChangeResponse: CGFloat
    let directionHoldDurationRange: ClosedRange<TimeInterval>
    let burstSpeedMultiplierRange: ClosedRange<CGFloat>
    let burstDurationRange: ClosedRange<TimeInterval>
    let burstCooldownRange: ClosedRange<TimeInterval>
    let hoverDurationRange: ClosedRange<TimeInterval>
    let steeringNoiseMultiplier: CGFloat
    let verticalDirectionBias: CGFloat
    let accelerationResponseRange: ClosedRange<CGFloat>
    let brakingResponseRange: ClosedRange<CGFloat>
    let swimPhaseSpeedMultiplier: CGFloat

    static let clownfish = FishMovementProfile(
        baseSpeedRange: 0.020...0.032,
        hoverProbability: 0.34,
        burstProbability: 0.24,
        gatheringProbability: 0.15,
        wanderingRadiusX: 0.16...0.35,
        wanderingRadiusY: 0.13...0.30,
        turnResponsivenessRange: 0.62...1.02,
        depthRange: 0.12...0.92,
        depthScaleRange: 1.0...1.0,
        depthOpacityRange: 0.76...1.0,
        depthSpeedRange: 0.82...1.10,
        depthChangeProbability: 0.58,
        depthChangeResponse: 0.34,
        directionHoldDurationRange: 4.0...8.0,
        burstSpeedMultiplierRange: 1.8...2.6,
        burstDurationRange: 0.4...0.9,
        burstCooldownRange: 8.0...20.0,
        hoverDurationRange: 1.0...5.0,
        steeringNoiseMultiplier: 1.0,
        verticalDirectionBias: 0.5,
        accelerationResponseRange: 5.2...7.4,
        brakingResponseRange: 3.2...5.0,
        swimPhaseSpeedMultiplier: 1.0
    )

    /// クラゲなど、水中をゆっくり上下に漂う魚種向けの基準profile。
    static let jellyfish = FishMovementProfile(
        baseSpeedRange: 0.008...0.015,
        hoverProbability: 0.55,
        burstProbability: 0,
        gatheringProbability: 0.08,
        wanderingRadiusX: 0.08...0.16,
        wanderingRadiusY: 0.14...0.28,
        turnResponsivenessRange: 0.30...0.55,
        depthRange: 0.18...0.86,
        depthScaleRange: 1.0...1.0,
        depthOpacityRange: 0.80...1.0,
        depthSpeedRange: 0.90...1.02,
        depthChangeProbability: 0.40,
        depthChangeResponse: 0.18,
        directionHoldDurationRange: 5.0...10.0,
        burstSpeedMultiplierRange: 1.0...1.0,
        burstDurationRange: 0.4...0.4,
        burstCooldownRange: 20.0...20.0,
        hoverDurationRange: 2.0...5.0,
        steeringNoiseMultiplier: 0.30,
        verticalDirectionBias: 1.6,
        accelerationResponseRange: 0.9...1.6,
        brakingResponseRange: 0.8...1.4,
        swimPhaseSpeedMultiplier: 0.55
    )

    func depthScale(at depth: CGFloat) -> CGFloat {
        interpolate(depthScaleRange, at: depth)
    }

    func depthOpacity(at depth: CGFloat) -> CGFloat {
        interpolate(depthOpacityRange, at: depth)
    }

    func depthSpeedMultiplier(at depth: CGFloat) -> CGFloat {
        interpolate(depthSpeedRange, at: depth)
    }

    private func interpolate(_ range: ClosedRange<CGFloat>, at depth: CGFloat) -> CGFloat {
        let progress = normalizedDepth(depth)
        return range.lowerBound + progress * (range.upperBound - range.lowerBound)
    }

    private func normalizedDepth(_ depth: CGFloat) -> CGFloat {
        min(max(depth, 0), 1)
    }
}

enum AquariumFishMotion {
    enum Behavior: CaseIterable {
        case cruising
        case wandering
        case hovering
        case burst
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
        var localTarget: CGPoint
        var currentDepth: CGFloat
        var targetDepth: CGFloat
        var depthVelocity: CGFloat
        var depthChangeTimeRemaining: TimeInterval

        let movementProfile: FishMovementProfile
        let baseSpeed: CGFloat
        var currentSpeed: CGFloat
        var targetSpeed: CGFloat
        let accelerationResponse: CGFloat
        let brakingResponse: CGFloat
        let turnResponsiveness: CGFloat
        let hoverRadius: CGFloat
        let burstProbability: CGFloat
        let hoverProbability: CGFloat
        let gatheringProbability: CGFloat
        let wanderingRadiusX: CGFloat
        let wanderingRadiusY: CGFloat

        var directionChangeTimeRemaining: TimeInterval
        var burstCooldownRemaining: TimeInterval
        var noisePhaseX: CGFloat
        var noisePhaseY: CGFloat
        var swimPhase: CGFloat
        var accelerationMagnitude: CGFloat

        var facingSign: CGFloat
        var facingWidth: CGFloat
        var visualTurnTargetSign: CGFloat?
        var visualTurnProgress: CGFloat
        var visualTurnDuration: TimeInterval
        var facingDirection: FishFacingDirection
        var pendingFacingDirection: FishFacingDirection
        var pendingFacingDirectionDuration: TimeInterval
        var presentationMotionIntensity: CGFloat
        var presentationDirectionScale: CGFloat

        var randomState: UInt64

        mutating func advance(
            deltaTime rawDeltaTime: TimeInterval,
            elapsedTime: TimeInterval,
            neighborPositions: [CGPoint] = []
        ) {
            let deltaTime = min(max(rawDeltaTime, 0), AquariumFishMotion.maximumDeltaTime)
            guard deltaTime > 0 else { return }

            behaviorTimeRemaining -= deltaTime
            directionChangeTimeRemaining -= deltaTime
            burstCooldownRemaining = max(0, burstCooldownRemaining - deltaTime)
            depthChangeTimeRemaining -= deltaTime
            if behaviorTimeRemaining <= 0 {
                transitionBehavior(neighborPositions: neighborPositions)
            } else if directionChangeTimeRemaining <= 0, behavior != .burst, behavior != .braking {
                updateLocalCourse(neighborPositions: neighborPositions)
            }

            updatePresentationMotionIntensity(deltaTime: deltaTime)

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
            let headingWeight: CGFloat
            switch behavior {
            case .hovering: headingWeight = 0.06
            case .wandering: headingWeight = 0.42
            case .cruising: headingWeight = 0.66
            case .burst: headingWeight = 1
            case .braking: headingWeight = 0.32
            case .turning: headingWeight = 0.48
            }
            let targetDirection = AquariumFishMotion.normalized(CGVector(
                dx: desiredDirection.dx * headingWeight + behaviorSteering.dx + wallForce.dx,
                dy: desiredDirection.dy * headingWeight + behaviorSteering.dy + wallForce.dy
            ))

            let stateTurnMultiplier: CGFloat = behavior == .turning ? 2.2 : (behavior == .burst ? 0.72 : 1)
            let steeringAmount = 1 - exp(-turnResponsiveness * stateTurnMultiplier * CGFloat(deltaTime))
            let currentDirection = AquariumFishMotion.normalized(velocity)
            let blendedDirection = AquariumFishMotion.normalized(CGVector(
                dx: currentDirection.dx + (targetDirection.dx - currentDirection.dx) * steeringAmount,
                dy: currentDirection.dy + (targetDirection.dy - currentDirection.dy) * steeringAmount
            ))
            updateSpeed(deltaTime: deltaTime)
            velocity = CGVector(dx: blendedDirection.dx * currentSpeed, dy: blendedDirection.dy * currentSpeed)
            updateDepth(deltaTime: deltaTime)
            let depthSpeed = movementProfile.depthSpeedMultiplier(at: currentDepth)
            position.x += velocity.dx * CGFloat(deltaTime) * depthSpeed
            position.y += velocity.dy * CGFloat(deltaTime) * depthSpeed
            position.x = min(max(position.x, horizontalRange.lowerBound), horizontalRange.upperBound)
            position.y = min(max(position.y, verticalRange.lowerBound), verticalRange.upperBound)

            updateFacing(deltaTime: deltaTime)
            updateSwimPhase(deltaTime: deltaTime)
        }

        var depthScale: CGFloat {
            movementProfile.depthScale(at: currentDepth)
        }

        var depthOpacity: CGFloat {
            movementProfile.depthOpacity(at: currentDepth)
        }

        var depthSpeedMultiplier: CGFloat {
            movementProfile.depthSpeedMultiplier(at: currentDepth)
        }

        var facingHorizontalScale: CGFloat {
            switch facingDirection {
            case .right, .upRight, .downRight, .up, .down, .front:
                abs(facingWidth)
            case .left, .upLeft, .downLeft:
                -abs(facingWidth)
            }
        }

        private mutating func updateDepth(deltaTime: TimeInterval) {
            if depthChangeTimeRemaining <= 0 {
                chooseNextDepth()
            }

            let behaviorMultiplier: CGFloat
            switch behavior {
            case .hovering: behaviorMultiplier = 0.14
            case .wandering: behaviorMultiplier = 0.72
            case .cruising: behaviorMultiplier = 1
            case .burst: behaviorMultiplier = 0.24
            case .braking: behaviorMultiplier = 0.38
            case .turning: behaviorMultiplier = 0.25
            }
            let amount = 1 - exp(
                -movementProfile.depthChangeResponse
                    * behaviorMultiplier
                    * CGFloat(deltaTime)
            )
            let previousDepth = currentDepth
            currentDepth += (targetDepth - currentDepth) * amount
            currentDepth = min(max(currentDepth, 0), 1)
            depthVelocity = (currentDepth - previousDepth) / max(CGFloat(deltaTime), 0.001)
        }

        private mutating func chooseNextDepth() {
            guard behavior != .turning else {
                depthChangeTimeRemaining = random(in: 0.5...1.2)
                return
            }

            let probabilityMultiplier: CGFloat
            let maximumChange: CGFloat
            let interval: ClosedRange<TimeInterval>
            switch behavior {
            case .hovering:
                probabilityMultiplier = 0.24
                maximumChange = 0.05
                interval = 2.5...5.5
            case .wandering:
                probabilityMultiplier = 1
                maximumChange = 0.24
                interval = 2.0...5.0
            case .cruising:
                probabilityMultiplier = 0.86
                maximumChange = 0.34
                interval = 2.8...6.2
            case .burst:
                probabilityMultiplier = 0.22
                maximumChange = 0.08
                interval = 1.2...2.8
            case .braking:
                probabilityMultiplier = 0.34
                maximumChange = 0.10
                interval = 1.5...3.2
            case .turning:
                return
            }

            if chance(movementProfile.depthChangeProbability * probabilityMultiplier) {
                let proposedDepth = currentDepth + random(in: -maximumChange...maximumChange)
                targetDepth = min(
                    max(proposedDepth, movementProfile.depthRange.lowerBound),
                    movementProfile.depthRange.upperBound
                )

                // 手前へ来る時は少し下、奥へ抜ける時は少し上へ向く傾向だけを加える。
                let depthDelta = targetDepth - currentDepth
                desiredDirection = AquariumFishMotion.normalized(CGVector(
                    dx: desiredDirection.dx,
                    dy: desiredDirection.dy + depthDelta * 0.45
                ))
            }
            depthChangeTimeRemaining = random(in: interval)
        }

        private mutating func steeringForCurrentBehavior(noise: CGVector) -> CGVector {
            let noise = CGVector(
                dx: noise.dx * movementProfile.steeringNoiseMultiplier,
                dy: noise.dy * movementProfile.steeringNoiseMultiplier
            )
            switch behavior {
            case .wandering:
                let towardTarget = AquariumFishMotion.direction(from: position, to: localTarget)
                return CGVector(
                    dx: towardTarget.dx * 0.58 + noise.dx * 0.20,
                    dy: towardTarget.dy * 0.66 + noise.dy * 0.27
                )
            case .hovering:
                let offset = CGVector(dx: anchorPosition.x - position.x, dy: anchorPosition.y - position.y)
                let distance = hypot(offset.dx, offset.dy)
                let restoringStrength = min(distance / max(hoverRadius, 0.001), 1) * 0.85
                return CGVector(
                    dx: offset.dx / max(hoverRadius, 0.001) * restoringStrength + noise.dx * 0.34,
                    dy: offset.dy / max(hoverRadius, 0.001) * restoringStrength + noise.dy * 0.42
                )
            case .cruising:
                let towardTarget = AquariumFishMotion.direction(from: position, to: localTarget)
                return CGVector(
                    dx: towardTarget.dx * 0.30 + noise.dx * 0.11,
                    dy: towardTarget.dy * 0.40 + noise.dy * 0.17
                )
            case .burst:
                return CGVector(dx: noise.dx * 0.045, dy: noise.dy * 0.06)
            case .braking:
                return CGVector(dx: noise.dx * 0.16, dy: noise.dy * 0.22)
            case .turning:
                return CGVector(dx: noise.dx * 0.07, dy: noise.dy * 0.09)
            }
        }

        private mutating func updatePresentationMotionIntensity(deltaTime: TimeInterval) {
            let target: CGFloat = behavior == .turning ? 0.30 : 1
            let amount = 1 - exp(-9 * CGFloat(deltaTime))
            presentationMotionIntensity += (target - presentationMotionIntensity) * amount
            let scaleAmount = 1 - exp(-14 * CGFloat(deltaTime))
            presentationDirectionScale += (
                facingDirection.directionScale - presentationDirectionScale
            ) * scaleAmount
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
            swimPhase += phaseVelocity
                * movementProfile.swimPhaseSpeedMultiplier
                * CGFloat(deltaTime)
            if swimPhase > .pi * 2 { swimPhase.formTruncatingRemainder(dividingBy: .pi * 2) }
        }

        private mutating func updateFacing(deltaTime: TimeInterval) {
            updateFacingWidth(deltaTime: deltaTime)

            let speedThreshold = max(baseSpeed * 0.18, 0.005)
            let planarSpeed = hypot(velocity.dx, velocity.dy)
            if behavior == .hovering, planarSpeed < baseSpeed * 0.55 {
                pendingFacingDirectionDuration = max(0, pendingFacingDirectionDuration - deltaTime)
                return
            }
            guard planarSpeed >= speedThreshold || abs(depthVelocity) >= speedThreshold * 0.45 else {
                pendingFacingDirectionDuration = max(0, pendingFacingDirectionDuration - deltaTime)
                return
            }

            let candidate = FishFacingDirection.quantized(
                velocity: velocity,
                depthVelocity: depthVelocity,
                frontPlanarSpeedThreshold: speedThreshold,
                retaining: facingDirection
            )
            guard candidate != facingDirection else {
                pendingFacingDirection = candidate
                pendingFacingDirectionDuration = 0
                return
            }

            if candidate != pendingFacingDirection {
                pendingFacingDirection = candidate
                pendingFacingDirectionDuration = 0
            } else {
                pendingFacingDirectionDuration += deltaTime
            }

            // 約0.2秒同じ方向が続いた場合だけ表示を変え、小さな揺れによる切替を抑える。
            guard pendingFacingDirectionDuration >= 0.20 else { return }
            facingDirection = candidate
            pendingFacingDirectionDuration = 0

            let targetSign: CGFloat?
            switch candidate {
            case .right, .upRight, .downRight:
                targetSign = -1
            case .left, .upLeft, .downLeft:
                targetSign = 1
            case .up, .down, .front:
                targetSign = nil
            }
            if let targetSign {
                facingSign = targetSign
            }
        }

        private mutating func updateFacingWidth(deltaTime: TimeInterval) {
            if let targetSign = visualTurnTargetSign {
                visualTurnProgress = min(visualTurnProgress + CGFloat(deltaTime / visualTurnDuration), 1)
                let distanceFromMiddle = abs(visualTurnProgress - 0.5) * 2
                facingWidth = 0.30 + 0.70 * distanceFromMiddle
                if visualTurnProgress >= 0.5, facingSign != targetSign {
                    facingSign = targetSign
                }
                if visualTurnProgress >= 1 {
                    facingWidth = 1
                    visualTurnTargetSign = nil
                    visualTurnProgress = 0
                }
            }
        }

        private mutating func transitionBehavior(neighborPositions: [CGPoint]) {
            let next: Behavior
            let canBurst = burstCooldownRemaining <= 0
            switch behavior {
            case .hovering:
                let roll = randomUnit()
                next = canBurst && roll < burstProbability
                    ? .burst
                    : (roll < 0.72 ? .wandering : .cruising)
            case .cruising:
                let roll = randomUnit()
                if canBurst && roll < burstProbability {
                    next = .burst
                } else if roll < burstProbability + hoverProbability {
                    next = .hovering
                } else if roll < 0.84 {
                    next = .wandering
                } else {
                    next = .turning
                }
            case .wandering:
                let roll = randomUnit()
                if roll < hoverProbability {
                    next = .hovering
                } else if canBurst && roll < hoverProbability + burstProbability {
                    next = .burst
                } else if roll < 0.82 {
                    next = .wandering
                } else {
                    next = .cruising
                }
            case .burst:
                next = .braking
            case .braking:
                next = chance(0.62) ? .hovering : .wandering
            case .turning:
                next = chance(0.38) ? .hovering : .wandering
            }
            enter(next, neighborPositions: neighborPositions)
        }

        private mutating func enter(_ next: Behavior, neighborPositions: [CGPoint]) {
            behavior = next
            switch next {
            case .wandering:
                behaviorTimeRemaining = random(in: 2.0...6.0)
                targetSpeed = baseSpeed * random(in: 0.40...0.82)
                chooseLocalTarget(neighborPositions: neighborPositions, permitsGathering: true)
                directionChangeTimeRemaining = random(in: movementProfile.directionHoldDurationRange)
            case .hovering:
                behaviorTimeRemaining = random(in: movementProfile.hoverDurationRange)
                anchorPosition = position
                localTarget = position
                targetSpeed = baseSpeed * random(in: 0.04...0.20)
                directionChangeTimeRemaining = random(in: 0.8...1.8)
            case .cruising:
                behaviorTimeRemaining = random(in: 3.0...8.0)
                targetSpeed = baseSpeed * random(in: 0.68...1.05)
                chooseLocalTarget(neighborPositions: neighborPositions, permitsGathering: true)
                directionChangeTimeRemaining = random(in: movementProfile.directionHoldDurationRange)
            case .burst:
                behaviorTimeRemaining = random(in: movementProfile.burstDurationRange)
                targetSpeed = baseSpeed * random(in: movementProfile.burstSpeedMultiplierRange)
                directionChangeTimeRemaining = behaviorTimeRemaining
                burstCooldownRemaining = random(in: movementProfile.burstCooldownRange)
                desiredDirection = perturbedDirection(maxAngle: 0.08)
            case .braking:
                behaviorTimeRemaining = random(in: 0.3...0.8)
                targetSpeed = baseSpeed * random(in: 0.55...0.82)
                directionChangeTimeRemaining = behaviorTimeRemaining
            case .turning:
                behaviorTimeRemaining = random(in: 0.7...1.55)
                targetSpeed = baseSpeed * random(in: 0.38...0.68)
                directionChangeTimeRemaining = behaviorTimeRemaining
                let turnAngle = random(in: 0.75...1.5) * (chance(0.5) ? 1 : -1)
                desiredDirection = AquariumFishMotion.rotated(desiredDirection, by: turnAngle)
            }
        }

        private mutating func updateLocalCourse(neighborPositions: [CGPoint]) {
            if behavior == .wandering || behavior == .cruising {
                chooseLocalTarget(neighborPositions: neighborPositions, permitsGathering: true)
            }
            let maxAngle: CGFloat = behavior == .hovering ? 0.55 : 0.09
            let targetDirection = AquariumFishMotion.direction(from: position, to: localTarget)
            desiredDirection = AquariumFishMotion.rotated(
                targetDirection,
                by: random(in: -maxAngle...maxAngle)
            )
            directionChangeTimeRemaining = behavior == .hovering
                ? random(in: 1.2...2.4)
                : random(in: movementProfile.directionHoldDurationRange)
        }

        mutating func chooseLocalTarget(
            neighborPositions: [CGPoint],
            permitsGathering: Bool
        ) {
            let center: CGPoint
            let isGathering: Bool
            if permitsGathering,
               !neighborPositions.isEmpty,
               chance(gatheringProbability) {
                let index = min(Int(randomUnit() * CGFloat(neighborPositions.count)), neighborPositions.count - 1)
                center = neighborPositions[index]
                isGathering = true
            } else {
                center = position
                isGathering = false
            }

            let xRadius = behavior == .cruising ? wanderingRadiusX * 1.65 : wanderingRadiusX
            let yRadius = behavior == .cruising ? wanderingRadiusY * 1.45 : wanderingRadiusY
            let xOffset: CGFloat
            if isGathering {
                // 同じ場所を目指しても画像が完全には重ならない距離を残す。
                xOffset = random(in: 0.10...0.16) * (chance(0.5) ? 1 : -1)
            } else {
                xOffset = random(in: -xRadius...xRadius)
            }
            localTarget = AquariumFishMotion.clampedPoint(CGPoint(
                x: center.x + xOffset,
                y: center.y + random(in: -yRadius...yRadius)
            ))
            desiredDirection = AquariumFishMotion.direction(from: position, to: localTarget)
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

    static func initialState(
        for id: UUID,
        profile: FishMovementProfile = .clownfish
    ) -> State {
        let bytes = withUnsafeBytes(of: id.uuid) { Array($0) }
        let angle = CGFloat(bytes[4]) / 255 * .pi * 2
        let baseSpeed = interpolated(profile.baseSpeedRange, byte: bytes[5])
        let direction = normalized(CGVector(
            dx: cos(angle),
            dy: sin(angle) * profile.verticalDirectionBias
        ))
        let facingSign: CGFloat = direction.dx >= 0 ? -1 : 1
        let facingDirection = FishFacingDirection.quantized(velocity: direction)
        let initialBehavior: Behavior = bytes[11].isMultiple(of: 3) ? .hovering : .wandering
        let initialPosition = initialPosition(for: id)
        let wanderingRadiusX = interpolated(profile.wanderingRadiusX, byte: bytes[12])
        let wanderingRadiusY = interpolated(profile.wanderingRadiusY, byte: bytes[13])
        let initialDepth = interpolated(profile.depthRange, byte: bytes[14])
        let initialTargetDepth = min(
            max(
                initialDepth + (CGFloat(bytes[15]) / 255 - 0.5) * 0.24,
                profile.depthRange.lowerBound
            ),
            profile.depthRange.upperBound
        )
        let initialBurstCooldown = profile.burstCooldownRange.lowerBound
            + Double(bytes[10]) / 255
                * (profile.burstCooldownRange.upperBound - profile.burstCooldownRange.lowerBound)

        return State(
            position: initialPosition,
            velocity: CGVector(dx: direction.dx * baseSpeed, dy: direction.dy * baseSpeed),
            desiredDirection: direction,
            behavior: initialBehavior,
            behaviorTimeRemaining: 1.5 + Double(bytes[9]) / 255 * 3.0,
            anchorPosition: initialPosition,
            localTarget: clampedPoint(CGPoint(
                x: initialPosition.x + direction.dx * wanderingRadiusX,
                y: initialPosition.y + direction.dy * wanderingRadiusY
            )),
            currentDepth: initialDepth,
            targetDepth: initialTargetDepth,
            depthVelocity: 0,
            depthChangeTimeRemaining: 1.5 + Double(bytes[10]) / 255 * 3.5,
            movementProfile: profile,
            baseSpeed: baseSpeed,
            currentSpeed: initialBehavior == .hovering ? baseSpeed * 0.25 : baseSpeed,
            targetSpeed: initialBehavior == .hovering ? baseSpeed * 0.25 : baseSpeed,
            accelerationResponse: interpolated(profile.accelerationResponseRange, byte: bytes[6]),
            brakingResponse: interpolated(profile.brakingResponseRange, byte: bytes[7]),
            turnResponsiveness: interpolated(profile.turnResponsivenessRange, byte: bytes[8]),
            hoverRadius: 0.025 + CGFloat(bytes[12]) / 255 * 0.03,
            burstProbability: profile.burstProbability * (0.78 + CGFloat(bytes[13]) / 255 * 0.44),
            hoverProbability: profile.hoverProbability * (0.82 + CGFloat(bytes[10]) / 255 * 0.36),
            gatheringProbability: profile.gatheringProbability,
            wanderingRadiusX: wanderingRadiusX,
            wanderingRadiusY: wanderingRadiusY,
            directionChangeTimeRemaining: profile.directionHoldDurationRange.lowerBound
                + Double(bytes[10]) / 255
                    * (profile.directionHoldDurationRange.upperBound
                        - profile.directionHoldDurationRange.lowerBound),
            burstCooldownRemaining: initialBurstCooldown,
            noisePhaseX: CGFloat(bytes[14]) / 255 * .pi * 2,
            noisePhaseY: CGFloat(bytes[15]) / 255 * .pi * 2,
            swimPhase: CGFloat(bytes[3]) / 255 * .pi * 2,
            accelerationMagnitude: 0,
            facingSign: facingSign,
            facingWidth: 1,
            visualTurnTargetSign: nil,
            visualTurnProgress: 0,
            visualTurnDuration: 0.35,
            facingDirection: facingDirection,
            pendingFacingDirection: facingDirection,
            pendingFacingDirectionDuration: 0,
            presentationMotionIntensity: 1,
            presentationDirectionScale: facingDirection.directionScale,
            randomState: seed(from: bytes)
        )
    }

    static func movementProfile(for species: FishSpecies) -> FishMovementProfile {
        switch species {
        case .clownfish:
            .clownfish
        case .jellyfish:
            .jellyfish
        case .pufferfish, .seahorse, .manta, .whaleShark:
            .clownfish
        }
    }

    static func spriteFrameDuration(
        for species: FishSpecies,
        behavior: Behavior,
        currentSpeed: CGFloat,
        baseSpeed: CGFloat
    ) -> TimeInterval {
        guard species != .jellyfish else { return 0.30 }
        return spriteFrameDuration(
            for: behavior,
            currentSpeed: currentSpeed,
            baseSpeed: baseSpeed
        )
    }

    static func spriteFrameDuration(
        for behavior: Behavior,
        currentSpeed: CGFloat,
        baseSpeed: CGFloat
    ) -> TimeInterval {
        switch behavior {
        case .hovering:
            return 0.30
        case .wandering:
            return 0.215
        case .cruising:
            return 0.155
        case .burst:
            return 0.09
        case .braking:
            // 減速に合わせ、約0.16秒から0.27秒へ徐々に遅くする。
            return 0.27 - TimeInterval(
                min(max(currentSpeed / max(baseSpeed, 0.001), 0), 1.5) / 1.5
            ) * 0.11
        case .turning:
            return 0.26
        }
    }

    static func spriteAnimationPhase(for id: UUID) -> TimeInterval {
        let bytes = withUnsafeBytes(of: id.uuid) { Array($0) }
        return Double(bytes[6]) / 255 * 1.7
    }

    static func spriteTempoMultiplier(for id: UUID) -> TimeInterval {
        let bytes = withUnsafeBytes(of: id.uuid) { Array($0) }
        return 0.90 + Double(bytes[7]) / 255 * 0.20
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
        case .wandering: behaviorScale = 0.92
        case .burst: behaviorScale = 1.35
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

    static func direction(from start: CGPoint, to end: CGPoint) -> CGVector {
        normalized(CGVector(dx: end.x - start.x, dy: end.y - start.y))
    }

    static func clampedPoint(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: min(max(point.x, horizontalRange.lowerBound), horizontalRange.upperBound),
            y: min(max(point.y, verticalRange.lowerBound), verticalRange.upperBound)
        )
    }

    private static func edgeForce(_ distance: CGFloat, margin: CGFloat) -> CGFloat {
        guard distance < margin else { return 0 }
        let proximity = min(max((margin - distance) / margin, 0), 1)
        return proximity * proximity
    }

    private static func seed(from bytes: [UInt8]) -> UInt64 {
        bytes.reduce(14_695_981_039_346_656_037) { ($0 ^ UInt64($1)) &* 1_099_511_628_211 }
    }

    private static func interpolated(_ range: ClosedRange<CGFloat>, byte: UInt8) -> CGFloat {
        range.lowerBound + CGFloat(byte) / 255 * (range.upperBound - range.lowerBound)
    }
}
