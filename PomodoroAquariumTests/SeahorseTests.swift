import CoreGraphics
import Foundation
import Testing
import UIKit
@testable import PomodoroAquarium

@MainActor
struct SeahorseTests {
    private let frames = (1...5).map { "fish_seahorse_side_\($0)" }

    private func motion(for id: UUID) -> AquariumFishMotion.State {
        AquariumFishMotion.initialState(
            for: id,
            profile: AquariumFishMotion.movementProfile(for: .seahorse),
            speedVariationProfile: AquariumFishMotion.speedVariationProfile(for: .seahorse)
        )
    }

    @Test func existingSpeciesUsesNeutralThirdFrameWithoutChangingMetadata() throws {
        #expect(FishSpecies.seahorse.rawValue == "seahorse")
        #expect(FishSpecies.seahorse.name == "タツノオトシゴ")
        #expect(FishSpecies.seahorse.imageName == "fish_seahorse_side_3")
        #expect(FishSpecies.seahorse.rarity == .rare)
        #expect(FishSpecies.seahorse.displayScale == 1.20)

        let persistedValue = try JSONEncoder().encode(FishSpecies.seahorse)
        #expect(try JSONDecoder().decode(FishSpecies.self, from: persistedValue) == .seahorse)
    }

    @Test func aquariumUsesAllFiveSideAssets() {
        #expect(FishSpecies.seahorse.swimmingImageNames == frames)
        #expect(frames[2] == FishSpecies.seahorse.imageName)
        for name in frames {
            #expect(UIImage(named: name) != nil)
        }
        for direction in FishFacingDirection.allCases {
            #expect(FishSpecies.seahorse.swimmingImageNames(for: direction) == frames)
        }
    }

    @Test func swimPhaseDrivesFiveFramePingPong() {
        let duration: TimeInterval = 0.28
        let phases = (0...8).map { CGFloat($0) * .pi / 4 }
        let indices = phases.map { phase in
            FishSpriteAnimation.pingPongFrameIndex(
                frameCount: frames.count,
                elapsedTime: AquariumFishMotion.seahorseSpriteAnimationTime(
                    swimPhase: phase,
                    frameCount: frames.count,
                    frameDuration: duration
                ),
                frameDuration: duration
            )
        }
        #expect(indices == [0, 1, 2, 3, 4, 3, 2, 1, 0])
    }

    @Test func seahorseUsesSlowDedicatedFrameDuration() {
        for behavior in AquariumFishMotion.Behavior.allCases {
            #expect(AquariumFishMotion.spriteFrameDuration(
                for: .seahorse,
                behavior: behavior,
                currentSpeed: 0.01,
                baseSpeed: 0.012
            ) == 0.28)
        }
    }

    @Test func visualFloatSharesAnimationPhaseWithoutMutatingMovementPosition() {
        let position = CGPoint(x: 0.4, y: 0.3)
        let offsets = [CGFloat.zero, .pi / 2, .pi, .pi * 1.5].map {
            AquariumFishMotion.seahorseVisualOffsetY(swimPhase: $0)
        }
        #expect(abs(offsets[0]) < 0.000_001)
        #expect(abs(offsets[1] + 1.2) < 0.000_001)
        #expect(abs(offsets[2]) < 0.000_001)
        #expect(abs(offsets[3] - 1.2) < 0.000_001)
        #expect(position == CGPoint(x: 0.4, y: 0.3))
    }

    @Test func seahorseKeepsJellyfishDriftingTraitsAtDoubleBaseSpeed() {
        let seahorse = AquariumFishMotion.movementProfile(for: .seahorse)
        let jellyfish = FishMovementProfile.jellyfish
        #expect(seahorse.baseSpeedRange == 0.016...0.030)
        #expect(seahorse.baseSpeedRange.lowerBound == jellyfish.baseSpeedRange.lowerBound * 2)
        #expect(seahorse.baseSpeedRange.upperBound == jellyfish.baseSpeedRange.upperBound * 2)
        #expect(seahorse.wanderingRadiusX == jellyfish.wanderingRadiusX)
        #expect(seahorse.wanderingRadiusY == jellyfish.wanderingRadiusY)
        #expect(seahorse.directionHoldDurationRange == jellyfish.directionHoldDurationRange)
        #expect(seahorse.turnResponsivenessRange == jellyfish.turnResponsivenessRange)
        #expect(seahorse.accelerationResponseRange == jellyfish.accelerationResponseRange)
        #expect(seahorse.brakingResponseRange == jellyfish.brakingResponseRange)
        #expect(seahorse.hoverProbability == 0.55)
        #expect(seahorse.burstProbability == 0)
        #expect(seahorse.verticalDirectionBias == 1.6)
        #expect(seahorse.swimPhaseSpeedMultiplier == 0.55)
    }

    @Test func otherFishBaseSpeedsRemainUnchanged() {
        #expect(AquariumFishMotion.movementProfile(for: .clownfish).baseSpeedRange == 0.020...0.032)
        #expect(AquariumFishMotion.movementProfile(for: .pufferfish).baseSpeedRange == 0.020...0.032)
        #expect(AquariumFishMotion.movementProfile(for: .jellyfish).baseSpeedRange == 0.008...0.015)
        #expect(AquariumFishMotion.movementProfile(for: .manta).baseSpeedRange == 0.042...0.066)
        #expect(AquariumFishMotion.movementProfile(for: .whaleShark).baseSpeedRange == 0.026...0.040)
    }

    @Test func speedVariationTargetsMatchEachBehaviorAndUpdateEveryTwoToSixSeconds() throws {
        let profile = try #require(AquariumFishMotion.speedVariationProfile(for: .seahorse))
        #expect(profile.changeIntervalRange == 2.0...6.0)
        #expect(profile.multiplierRange(for: .hovering) == 0.60...0.75)
        #expect(profile.multiplierRange(for: .wandering) == 0.75...1.20)
        #expect(profile.multiplierRange(for: .cruising) == 1.10...1.35)
        #expect(profile.multiplierRange(for: .turning) == 0.70...0.90)
        #expect(profile.multiplierRange(for: .braking) == 0.70...0.90)
    }

    @Test func targetSpeedVariationIsHeldInsteadOfRandomizedEveryFrame() {
        let id = UUID(uuid: (20, 80, 3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 13, 14, 15, 16))
        var seahorse = motion(for: id)
        seahorse.behavior = .wandering
        seahorse.behaviorTimeRemaining = 100
        seahorse.directionChangeTimeRemaining = 100
        seahorse.depthChangeTimeRemaining = 100
        seahorse.speedVariationTimeRemaining = 1.5
        let target = seahorse.targetSpeedVariationMultiplier

        for frame in 1...30 {
            seahorse.advance(deltaTime: 1.0 / 30.0, elapsedTime: Double(frame) / 30)
            #expect(seahorse.targetSpeedVariationMultiplier == target)
        }
        #expect(seahorse.speedVariationTimeRemaining > 0.49)
        #expect(seahorse.speedVariationTimeRemaining < 0.51)
    }

    @Test func targetSpeedVariationRefreshesThenUsesExistingSmoothSpeedResponse() {
        let id = UUID(uuid: (120, 180, 3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 13, 14, 15, 16))
        var seahorse = motion(for: id)
        seahorse.behavior = .cruising
        seahorse.behaviorTimeRemaining = 100
        seahorse.directionChangeTimeRemaining = 100
        seahorse.depthChangeTimeRemaining = 100
        seahorse.targetSpeed = seahorse.baseSpeed
        seahorse.currentSpeed = seahorse.baseSpeed * 0.75
        seahorse.speedVariationTimeRemaining = 0
        let previousSpeed = seahorse.currentSpeed

        seahorse.advance(deltaTime: 1.0 / 30.0, elapsedTime: 1)

        #expect((1.10...1.35).contains(seahorse.targetSpeedVariationMultiplier))
        #expect((2.0...6.0).contains(seahorse.speedVariationTimeRemaining))
        #expect(seahorse.currentSpeed > previousSpeed)
        #expect(seahorse.currentSpeed < seahorse.baseSpeed * seahorse.targetSpeedVariationMultiplier)
    }

    @Test func hoverVariationKeepsAContinuousNonzeroDrift() {
        let id = UUID(uuid: (40, 140, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16))
        var seahorse = motion(for: id)
        seahorse.behavior = .hovering
        seahorse.behaviorTimeRemaining = 100
        seahorse.directionChangeTimeRemaining = 100
        seahorse.depthChangeTimeRemaining = 100
        seahorse.anchorPosition = seahorse.position
        seahorse.localTarget = seahorse.position
        seahorse.targetSpeed = seahorse.baseSpeed * 0.12
        seahorse.currentSpeed = seahorse.baseSpeed * 0.12

        for frame in 1...240 {
            seahorse.advance(deltaTime: 1.0 / 30.0, elapsedTime: Double(frame) / 30)
            #expect(seahorse.currentSpeed > 0)
        }
        #expect((0.60...0.75).contains(seahorse.targetSpeedVariationMultiplier))
    }

    @Test func individualsStartWithDifferentVariationTargetsAndTimings() {
        let first = motion(for: UUID(uuid: (10, 20, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16)))
        let second = motion(for: UUID(uuid: (220, 240, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16)))
        #expect(first.targetSpeedVariationMultiplier != second.targetSpeedVariationMultiplier)
        #expect(first.speedVariationTimeRemaining != second.speedVariationTimeRemaining)
    }

    @Test func speedVariationIsExclusiveToSeahorseAndDoesNotAddBurst() {
        #expect(AquariumFishMotion.speedVariationProfile(for: .seahorse) != nil)
        for species in FishSpecies.allCases where species != .seahorse {
            #expect(AquariumFishMotion.speedVariationProfile(for: species) == nil)
        }
        #expect(AquariumFishMotion.movementProfile(for: .seahorse).burstProbability == 0)
    }

    @Test func seahorseKeepsVerticalPostureWhileUsingSharedFlip() {
        let expectedRotation: [FishFacingDirection: Double] = [
            .right: 0, .upRight: -12.6, .up: -25.2, .upLeft: 12.6,
            .left: 0, .downLeft: -12.6, .down: 25.2, .downRight: 12.6,
            .front: 0
        ]
        for (direction, rotation) in expectedRotation {
            #expect(abs(FishSpecies.seahorse.swimmingImageRotation(for: direction) - rotation) < 0.000_001)
        }
        #expect(FishSpecies.seahorse.usesDirectionalSwimmingSprites)
        #expect(FishSpecies.seahorse.usesHorizontalSwimmingFlip)
    }

    @Test func existingFrameCountsRemainUnchanged() {
        #expect(FishSpecies.clownfish.swimmingImageNames.count == 3)
        #expect(FishSpecies.pufferfish.swimmingImageNames.count == 5)
        #expect(FishSpecies.jellyfish.swimmingImageNames.count == 5)
        #expect(FishSpecies.manta.swimmingImageNames.count == 7)
        #expect(FishSpecies.whaleShark.swimmingImageNames.count == 7)
    }

    @Test func existingOwnershipUsesTheSameSpeciesIdentifier() throws {
        let restoredSpecies = try JSONDecoder().decode(
            FishSpecies.self,
            from: Data("\"seahorse\"".utf8)
        )
        let player = Player(ownedFish: [
            PlayerFish(species: restoredSpecies),
            PlayerFish(species: restoredSpecies)
        ])
        #expect(BookView.ownedCount(for: .seahorse, in: player) == 2)
    }
}
