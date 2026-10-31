import CoreGraphics
import Foundation
import Testing
@testable import PomodoroAquarium

@MainActor
struct AquariumMovementSpeedTests {
    private let id = UUID(uuidString: "B10E7A60-6A60-4A60-8A60-000000000001")!
    private let size = CGSize(width: 393, height: 852)
    private let bounds = FishRoamingBounds(horizontal: -10...10, vertical: 0.1...0.9,
        horizontalWallMargin: 0.01, verticalWallMargin: 0.01)
    private let dt = 1.0 / 60

    private func initial(_ species: FishSpecies) -> AquariumFishMotion.State {
        AquariumFishMotion.initialState(for: id, profile: AquariumFishMotion.movementProfile(for: species),
            roamingBounds: bounds, initialPosition: CGPoint(x: 0.5, y: 0.7), aquariumSize: size,
            fishSize: AquariumFishSizing.referenceSize(for: species))
    }

    private let smallSpecies: Set<FishSpecies> = [.clownfish, .blueTang, .yellowTang, .blueGreenChromis,
        .orientalButterflyfish, .pennantCoralfish, .pufferfish, .jellyfish, .seahorse,
        .mandarinfish, .lionfish, .porcupinefish]

    @Test func speedGroupsMatchTheTwelveSmallFishAndFiveLargeFishWithoutCompounding() {
        #expect(smallSpecies.count == 12)
        for species in FishSpecies.allCases {
            let isSmall = smallSpecies.contains(species)
            let profile = AquariumFishMotion.movementProfile(for: species)
            #expect(profile.movementSpeedMultiplier == (isSmall ? 1.25 : 1.10))
            let sizeRatio = AquariumFishSizing.displaySize(for: species, isFavorite: false)
                / AquariumFishSizing.referenceSize(for: species)
            #expect(abs(sizeRatio - (isSmall ? 0.85 : 1)) < 0.000000001)
        }
        #expect(FishSpecies.allCases.count - smallSpecies.count == 5)
    }

    @Test func ordinaryProfilesScaleActualDisplacementWhileBehaviorClocksKeepRealTime() {
        for species in FishSpecies.allCases where species != .manta && species != .mandarinfish {
            for phaseSpeed: CGFloat in [0.6, 1.2] { // 膨張・滑走・推進などの既存倍率も保持する。
                var state = initial(species)
                state.behaviorTimeRemaining = 100
                state.directionChangeTimeRemaining = 100
                state.depthChangeTimeRemaining = 100
                let start = state.position
                state.advance(deltaTime: dt, elapsedTime: dt, speedMultiplier: phaseSpeed)
                let expected: CGFloat = smallSpecies.contains(species) ? 1.25 : 1.10
                let base = state.velocity
                let actual = state.translationVelocity
                #expect(abs(actual.dx - base.dx * expected) < 0.000000001)
                #expect(abs(actual.dy - base.dy * expected) < 0.000000001)
                #expect(abs(state.position.x - start.x - actual.dx * state.depthSpeedMultiplier * dt) < 0.000000001)
                #expect(abs(state.position.y - start.y - actual.dy * state.depthSpeedMultiplier * dt) < 0.000000001)
                #expect(abs(state.behaviorTimeRemaining - (100 - dt)) < 0.000000001)
                #expect(abs(state.depthChangeTimeRemaining - (100 - dt)) < 0.000000001)
            }
        }
    }

    @Test func stationKeepingKeepsHoverDurationAndDistanceButShortensOnlyTheTravel() throws {
        var state = initial(.mandarinfish)
        let hover = try #require(state.stationKeeping)
        #expect((1...3).contains(hover.duration))
        for tick in 1...240 {
            state.advance(deltaTime: dt, elapsedTime: Double(tick) * dt)
            if state.stationKeeping?.phase == .moving { break }
        }
        let travel = try #require(state.stationKeeping)
        let isMoving = travel.phase == .moving
        #expect(isMoving)
        #expect((0.75...1.875).contains(travel.duration * 1.25))
        let distance = hypot((travel.target.x - travel.start.x) * size.width,
                             (travel.target.y - travel.start.y) * size.height)
        let length = AquariumFishSizing.referenceSize(for: .mandarinfish) * AquariumMandarinfishMotion.visibleLengthRatio
        #expect(distance >= length * 0.3 - 0.0001 && distance <= length * 0.8 + 0.0001)
        // 表示の先読みも、実際の専用経路の速度と一致する（深度や共通倍率の二重適用なし）。
        #expect(abs(state.translationVelocity.dx * state.depthSpeedMultiplier - travel.velocity.dx) < 0.000000001)
        #expect(abs(state.translationVelocity.dy * state.depthSpeedMultiplier - travel.velocity.dy) < 0.000000001)
    }

    @Test func tunaUsesTheSameScaleAndReportsItsRealVelocityDuringHeightChanges() throws {
        var state = initial(.manta)
        state.bluefinCruise?.direction = 1
        state.bluefinCruise?.levelTimeRemaining = 0
        state.bluefinCruise?.levelCrossingsRemaining = 0
        state.behaviorTimeRemaining = 100
        state.directionChangeTimeRemaining = 100
        state.advance(deltaTime: dt, elapsedTime: dt)
        let cruise = try #require(state.bluefinCruise)
        #expect(cruise.heightTarget != nil)
        #expect(abs(cruise.heightElapsed - dt) < 0.000000001)
        let unscaledTime = cruise.heightTime * 1.10
        #expect(unscaledTime >= 5 && unscaledTime <= 8)
        for tick in 2...500 {
            let start = state.position
            state.advance(deltaTime: dt, elapsedTime: Double(tick) * dt)
            let actual = state.translationVelocity
            #expect(abs(state.position.x - start.x - actual.dx * state.depthSpeedMultiplier * dt) < 0.000000001)
            #expect(abs(state.position.y - start.y - actual.dy * state.depthSpeedMultiplier * dt) < 0.000000001)
            #expect(abs(state.position.y - start.y) * size.height / dt <= 11.000001)
            #expect(bounds.horizontal.contains(state.position.x) && bounds.vertical.contains(state.position.y))
        }
    }
}
