import CoreGraphics
import Foundation
import Testing
@testable import PomodoroAquarium

@MainActor
struct ClownfishThreeFrameTests {
    private let side = (1...3).map { "fish_clownfish_side_\($0)" }

    @Test func everyAquariumDirectionReferencesExactlyThreeSideAssets() {
        #expect(FishSpecies.clownfish.imageName == "fish_clownfish_side_2")
        let used = Set(FishFacingDirection.allCases.flatMap {
            FishSpecies.clownfish.swimmingImageNames(for: $0)
        })
        #expect(used == Set(side))
        for direction in FishFacingDirection.allCases {
            #expect(FishSpecies.clownfish.swimmingImageNames(for: direction) == side)
        }
        #expect(FishSpecies.clownfish.swimmingImageNames(
            for: .sideToDiagonalUp15(isLeftFacing: false)
        ) == side)
        #expect(FishSpecies.clownfish.swimmingImageNames(
            for: .sideToDiagonalDown15(isLeftFacing: true)
        ) == side)
    }

    @Test func noDedicatedDirectionOrRigAssetsAreReferenced() {
        let used = Set(FishFacingDirection.allCases.flatMap {
            FishSpecies.clownfish.swimmingImageNames(for: $0)
        })
        let unusedStems = [
            "fish_clownfish_diagonal_", "fish_clownfish_up_", "fish_clownfish_down_",
            "fish_clownfish_front_", "fish_clownfish_side_to_diagonal_", "fish_clownfish_rig_"
        ]
        #expect(!used.contains { name in unusedStems.contains { name.hasPrefix($0) } })
    }

    @Test func sideFramesKeepThreeFramePingPong() {
        let duration: TimeInterval = 0.2
        let indices = (0...4).map {
            FishSpriteAnimation.pingPongFrameIndex(
                frameCount: side.count,
                elapsedTime: Double($0) * duration,
                frameDuration: duration
            )
        }
        #expect(indices == [0, 1, 2, 1, 0])
    }

    @Test func rotationAndFlipCoverEightDirections() {
        let expectedRotation: [FishFacingDirection: Double] = [
            .right: 0, .upRight: -45, .up: -90, .upLeft: 45,
            .left: 0, .downLeft: -45, .down: 90, .downRight: 45
        ]
        for (direction, rotation) in expectedRotation {
            #expect(FishSpecies.clownfish.swimmingImageRotation(for: direction) == rotation)
        }
        #expect(FishSpecies.clownfish.usesHorizontalSwimmingFlip)
        #expect(!FishFacingDirection.right.isLeftFacing)
        #expect(!FishFacingDirection.upRight.isLeftFacing)
        #expect(!FishFacingDirection.up.isLeftFacing)
        #expect(FishFacingDirection.upLeft.isLeftFacing)
        #expect(FishFacingDirection.left.isLeftFacing)
        #expect(FishFacingDirection.downLeft.isLeftFacing)
        #expect(!FishFacingDirection.down.isLeftFacing)
        #expect(!FishFacingDirection.downRight.isLeftFacing)
    }

    @Test func frameDurationsAndClownfishMovementGeometryStayStable() {
        let baseSpeed: CGFloat = 0.026
        let cases: [(AquariumFishMotion.Behavior, CGFloat, TimeInterval)] = [
            (.hovering, 0.1, 0.30), (.wandering, 0.6, 0.215),
            (.cruising, 1.0, 0.155), (.burst, 2.0, 0.09), (.turning, 0.4, 0.26)
        ]
        for (behavior, ratio, duration) in cases {
            #expect(AquariumFishMotion.spriteFrameDuration(
                for: .clownfish, behavior: behavior,
                currentSpeed: baseSpeed * ratio, baseSpeed: baseSpeed
            ) == duration)
        }

        let profile = AquariumFishMotion.movementProfile(for: .clownfish)
        #expect(profile.baseSpeedRange == 0.020...0.032)
        #expect(profile.directionHoldDurationRange == 4.0...8.0)
        #expect(profile.wanderingRadiusX == 0.16...0.35)
        #expect(profile.wanderingRadiusY == 0.13...0.30)
        #expect(profile.turnResponsivenessRange == 0.62...1.02)
        #expect(profile.burstProbability == 0.24)
        #expect(profile.hoverProbability == 0.34)
        #expect(profile.gatheringProbability == 0.15)
        #expect(FishSpecies.clownfish.displayScale == 0.40)
    }

    @Test func clownfishBehaviorSpeedTargetsMatchAnimationTempo() {
        let expected: [(AquariumFishMotion.Behavior, CGFloat)] = [
            (.hovering, 0.62), (.wandering, 0.95), (.cruising, 1.22),
            (.burst, 1.90), (.turning, 0.85)
        ]
        for (behavior, multiplier) in expected {
            #expect(AquariumFishMotion.behaviorTargetSpeedMultiplier(
                for: .clownfish, behavior: behavior
            ) == multiplier)
        }
        #expect(AquariumFishMotion.behaviorTargetSpeedMultiplier(
            for: .clownfish, behavior: .braking
        ) == nil)
    }

    @Test func behaviorSpeedTargetUsesExistingAccelerationAndBraking() {
        var motion = AquariumFishMotion.initialState(for: UUID(), profile: .clownfish)
        motion.behavior = .burst
        motion.behaviorTimeRemaining = 10
        motion.directionChangeTimeRemaining = 10
        motion.currentSpeed = motion.baseSpeed * 0.62
        motion.targetSpeed = motion.baseSpeed * 2.6
        let initialSpeed = motion.currentSpeed
        let targetSpeed = motion.baseSpeed * 1.90

        motion.advance(
            deltaTime: 1.0 / 30, elapsedTime: 1,
            behaviorTargetSpeedMultiplier: 1.90
        )
        #expect(motion.currentSpeed > initialSpeed)
        #expect(motion.currentSpeed < targetSpeed)

        motion.behavior = .hovering
        motion.behaviorTimeRemaining = 10
        let beforeBraking = motion.currentSpeed
        motion.advance(
            deltaTime: 1.0 / 30, elapsedTime: 2,
            behaviorTargetSpeedMultiplier: 0.62
        )
        #expect(motion.currentSpeed < beforeBraking)
        #expect(motion.currentSpeed > motion.baseSpeed * 0.62)
    }

    @Test func otherFishKeepTheirExistingMovementTargets() {
        for species in FishSpecies.allCases where species != .clownfish {
            for behavior in AquariumFishMotion.Behavior.allCases {
                #expect(AquariumFishMotion.behaviorTargetSpeedMultiplier(
                    for: species, behavior: behavior
                ) == nil)
            }
        }
        #expect(FishSpecies.jellyfish.swimmingImageNames.count == 5)
        #expect(FishSpecies.manta.swimmingImageNames.count == 7)
        #expect(FishSpecies.whaleShark.swimmingImageNames.count == 7)
    }
}
