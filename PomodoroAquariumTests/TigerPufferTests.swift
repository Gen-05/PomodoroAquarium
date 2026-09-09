import CoreGraphics
import Foundation
import Testing
@testable import PomodoroAquarium

@MainActor
struct TigerPufferTests {
    private let frames = (1...5).map { "fish_tiger_puffer_side_\($0)" }

    @Test func existingIdentifierNowRepresentsTigerPuffer() throws {
        #expect(FishSpecies.pufferfish.rawValue == "pufferfish")
        #expect(FishSpecies.pufferfish.name == "トラフグ")
        #expect(FishSpecies.pufferfish.name != "フグ")

        let persistedValue = try JSONEncoder().encode(FishSpecies.pufferfish)
        #expect(String(decoding: persistedValue, as: UTF8.self) == "\"pufferfish\"")
        #expect(try JSONDecoder().decode(FishSpecies.self, from: persistedValue) == .pufferfish)
    }

    @Test func tigerPufferKeepsExistingCatalogMetadata() {
        #expect(FishSpecies.pufferfish.imageName == "fish_tiger_puffer_side_3")
        #expect(frames[2] == FishSpecies.pufferfish.imageName)
        #expect(FishSpecies.pufferfish.rarity == .common)
        #expect(FishSpecies.pufferfish.displayScale == 0.75)
        #expect(FishSpecies.allCases.filter { $0 == .pufferfish }.count == 1)
    }

    @Test func aquariumUsesOnlyFiveTigerPufferSideFrames() {
        #expect(FishSpecies.pufferfish.swimmingImageNames == frames)
        for direction in FishFacingDirection.allCases {
            #expect(FishSpecies.pufferfish.swimmingImageNames(for: direction) == frames)
        }
        #expect(FishSpecies.pufferfish.swimmingImageNames(
            for: .sideToDiagonalUp15(isLeftFacing: false)
        ) == frames)
        #expect(FishSpecies.pufferfish.swimmingImageNames(
            for: .sideToDiagonalDown15(isLeftFacing: true)
        ) == frames)
        #expect(!frames.contains { name in
            ["front", "diagonal", "up", "down", "rig"].contains { name.contains($0) }
        })
    }

    @Test func tigerPufferFramesUseFiveFramePingPong() {
        let duration: TimeInterval = 0.2
        let indices = (0...8).map { step in
            FishSpriteAnimation.pingPongFrameIndex(
                frameCount: frames.count,
                elapsedTime: Double(step) * duration,
                frameDuration: duration
            )
        }
        #expect(indices == [0, 1, 2, 3, 4, 3, 2, 1, 0])
    }

    @Test func tigerPufferUsesFasterBehaviorFrameDurationsWithoutChangingOtherFish() {
        let baseSpeed: CGFloat = 0.026
        let cases: [(AquariumFishMotion.Behavior, CGFloat, TimeInterval, TimeInterval)] = [
            (.hovering, 0.1, 0.30, 0.135),
            (.wandering, 0.6, 0.215, 0.09675),
            (.cruising, 1.0, 0.155, 0.06975),
            (.burst, 2.0, 0.09, 0.06),
            (.turning, 0.4, 0.26, 0.117)
        ]
        for (behavior, ratio, existingDuration, tigerPufferDuration) in cases {
            let currentSpeed = baseSpeed * ratio
            #expect(abs(AquariumFishMotion.spriteFrameDuration(
                for: .pufferfish,
                behavior: behavior,
                currentSpeed: currentSpeed,
                baseSpeed: baseSpeed
            ) - tigerPufferDuration) < 0.000_001)
            #expect(AquariumFishMotion.spriteFrameDuration(
                for: .clownfish,
                behavior: behavior,
                currentSpeed: currentSpeed,
                baseSpeed: baseSpeed
            ) == existingDuration)
        }
        #expect(AquariumFishMotion.spriteFrameDuration(
            for: .whaleShark,
            behavior: .cruising,
            currentSpeed: baseSpeed,
            baseSpeed: baseSpeed
        ) == 0.30)

        let slowBraking = AquariumFishMotion.spriteFrameDuration(
            for: .pufferfish,
            behavior: .braking,
            currentSpeed: 0,
            baseSpeed: baseSpeed
        )
        let fastBraking = AquariumFishMotion.spriteFrameDuration(
            for: .pufferfish,
            behavior: .braking,
            currentSpeed: baseSpeed * 1.5,
            baseSpeed: baseSpeed
        )
        #expect(abs(slowBraking - 0.1215) < 0.000_001)
        #expect(abs(fastBraking - 0.072) < 0.000_001)
    }

    @Test func tigerPufferReusesSmallFishRotationAndFlip() {
        let expectedRotation: [FishFacingDirection: Double] = [
            .right: 0, .upRight: -45, .up: -90, .upLeft: 45,
            .left: 0, .downLeft: -45, .down: 90, .downRight: 45,
            .front: 0
        ]
        for (direction, rotation) in expectedRotation {
            #expect(FishSpecies.pufferfish.swimmingImageRotation(for: direction) == rotation)
        }
        #expect(FishSpecies.pufferfish.usesDirectionalSwimmingSprites)
        #expect(FishSpecies.pufferfish.usesHorizontalSwimmingFlip)
    }

    @Test func tigerPufferKeepsExistingSmallFishMovementProfile() {
        let profile = AquariumFishMotion.movementProfile(for: .pufferfish)
        #expect(profile.baseSpeedRange == 0.020...0.032)
        #expect(profile.directionHoldDurationRange == 4.0...8.0)
        #expect(profile.wanderingRadiusX == 0.16...0.35)
        #expect(profile.wanderingRadiusY == 0.13...0.30)
        #expect(profile.turnResponsivenessRange == 0.62...1.02)
        #expect(profile.hoverProbability == 0.34)
        #expect(profile.burstProbability == 0.24)
        #expect(AquariumFishMotion.behaviorTargetSpeedMultiplier(
            for: .pufferfish,
            behavior: .burst
        ) == nil)
    }

    @Test func persistedPufferOwnershipBecomesTigerPufferWithoutChangingCount() throws {
        let storedIdentifier = Data("\"pufferfish\"".utf8)
        let restoredSpecies = try JSONDecoder().decode(FishSpecies.self, from: storedIdentifier)
        let existingFish = PlayerFish(species: restoredSpecies)
        let player = Player(ownedFish: [existingFish, PlayerFish(species: restoredSpecies)])

        #expect(restoredSpecies.name == "トラフグ")
        #expect(BookView.ownedCount(for: .pufferfish, in: player) == 2)
    }

    @Test func rewardCatalogKeepsTheExistingCommonSlot() {
        let commonSpecies = FishSpecies.allCases.filter { $0.rarity == .common }
        #expect(commonSpecies.filter { $0 == .pufferfish }.count == 1)
        #expect(commonSpecies.count == 3)
        #expect(FishRewardService.rarityProbabilities(for: 0).common == 70)
        #expect(FishRewardService.rarityProbabilities(for: 180).common == 58)
    }
}
