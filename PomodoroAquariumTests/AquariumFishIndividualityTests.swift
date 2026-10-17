import Foundation
import CoreGraphics
import Testing
@testable import PomodoroAquarium

struct AquariumFishIndividualityTests {
    // 保存済みの開発用IDそのもの。Releaseでも同じデータで検証する。
    private func ids(for species: FishSpecies) -> [UUID] {
        let prefix = species == .blueTang ? "B10E7A60" : "E1107A60"
        return (1...5).map { UUID(uuidString: String(format: "\(prefix)-6A60-4A60-8A60-%012d", $0))! }
    }

    private func fingerprint(_ state: AquariumFishMotion.State) -> [Double] {
        [Double(state.position.x), Double(state.position.y),
         Double(state.velocity.dx), Double(state.velocity.dy),
         state.behaviorTimeRemaining, state.directionChangeTimeRemaining,
         Double(state.baseSpeed), Double(state.currentDepth), Double(state.targetDepth),
         Double(state.noisePhaseX), Double(state.noisePhaseY), Double(state.swimPhase),
         Double(state.accelerationResponse), Double(state.brakingResponse),
         Double(state.turnResponsiveness), Double(state.wanderingRadiusX), Double(state.wanderingRadiusY)]
    }

    @Test(arguments: [FishSpecies.blueTang, .yellowTang])
    func fixedIDsStartIndependentlyAndReplayTheSameFirstFiveSeconds(species: FishSpecies) {
        let ids = ids(for: species)
        let profile = AquariumFishMotion.movementProfile(for: species)
        for size in [CGSize(width: 320, height: 568), CGSize(width: 393, height: 852), CGSize(width: 1024, height: 768)] {
            let bounds = profile.roamingStyle.bounds(in: size,
                fishSize: AquariumFishSizing.displaySize(for: species, isFavorite: false))
            func makeStates() -> [AquariumFishMotion.State] {
                ids.map { AquariumFishMotion.initialState(for: $0, profile: profile,
                    speedVariationProfile: AquariumFishMotion.speedVariationProfile(for: species), roamingBounds: bounds) }
            }
            var states = makeStates()
            var reopened = makeStates()
            #expect(states.map(fingerprint) == reopened.map(fingerprint))
            #expect(Set(states.map { "\($0.position.x),\($0.position.y)" }).count == 5)
            #expect(Set(states.map(\.facingDirection)).count > 1)
            #expect(Set(states.map(\.baseSpeed)).count > 1)
            #expect(Set(states.map(\.behaviorTimeRemaining)).count > 1)
            #expect(Set(states.map(\.directionChangeTimeRemaining)).count > 1)
            #expect(Set(states.map(\.noisePhaseX)).count > 1)
            #expect(Set(states.map(\.swimPhase)).count > 1)
            #expect(Set(ids.map { AquariumFishMotion.spriteAnimationPhase(for: $0) }).count > 1)
            #expect(Set(ids.map { AquariumFishMotion.spriteTempoMultiplier(for: $0) }).count > 1)
            for (id, state) in zip(ids, states) {
                #expect(state.position == AquariumFishMotion.initialPosition(for: id, bounds: bounds))
                #expect(bounds.horizontal.contains(state.position.x) && bounds.vertical.contains(state.position.y))
                #expect(profile.baseSpeedRange.contains(state.baseSpeed))
            }
            let initial = states.map(\.position)
            // 通常の描画更新と同じ30fpsで5秒間。再表示時にも同じ初期値・軌跡を再現する。
            for frame in 1...150 {
                for index in states.indices {
                    let multiplier = AquariumFishMotion.behaviorTargetSpeedMultiplier(for: species, behavior: states[index].behavior)
                    states[index].advance(deltaTime: 1.0 / 30, elapsedTime: Double(frame) / 30,
                        behaviorTargetSpeedMultiplier: multiplier)
                    reopened[index].advance(deltaTime: 1.0 / 30, elapsedTime: Double(frame) / 30,
                        behaviorTargetSpeedMultiplier: multiplier)
                    #expect(fingerprint(states[index]) == fingerprint(reopened[index]))
                    #expect(states[index].randomState == reopened[index].randomState)
                    #expect(bounds.horizontal.contains(states[index].position.x) && bounds.vertical.contains(states[index].position.y))
                }
                if frame.isMultiple(of: 30) {
                    #expect(Set(states.map { "\($0.position.x),\($0.position.y)" }).count == 5)
                }
            }
            let displacements = zip(states, initial).map { CGPoint(x: $0.position.x - $1.x, y: $0.position.y - $1.y) }
            #expect(Set(displacements.map { "\($0.x),\($0.y)" }).count == 5)
            print("Individuality \(species.rawValue) \(size): initial \(initial), facing \(makeStates().map(\.facingDirection))")
        }
    }

    @Test(arguments: [FishSpecies.blueTang, .yellowTang])
    func explicitSpawnAlwaysTakesPriorityOverIndividualPosition(species: FishSpecies) {
        let profile = AquariumFishMotion.movementProfile(for: species)
        for id in ids(for: species) {
            for spawn in [CGPoint(x: 0.5, y: 0.5), CGPoint(x: 0.47, y: 0.54)] {
                let state = AquariumFishMotion.initialState(for: id, profile: profile, initialPosition: spawn)
                #expect(state.position == spawn && state.anchorPosition == spawn)
            }
        }
    }

    @Test func everyUUIDByteContributesToStableInitialValues() {
        let original = UUID(uuidString: "B10E7A60-6A60-4A60-8A60-000000000001")!
        let baseline = fingerprint(AquariumFishMotion.initialState(for: original))
        for byte in 0..<16 {
            var hex = original.uuidString.replacingOccurrences(of: "-", with: "")
            let offset = hex.index(hex.startIndex, offsetBy: byte * 2)
            hex.replaceSubrange(offset...offset, with: hex[offset] == "0" ? "1" : "0")
            let parts = [0..<8, 8..<12, 12..<16, 16..<20, 20..<32].map { range in
                String(hex[hex.index(hex.startIndex, offsetBy: range.lowerBound)..<hex.index(hex.startIndex, offsetBy: range.upperBound)])
            }
            let id = UUID(uuidString: parts.joined(separator: "-"))!
            #expect(fingerprint(AquariumFishMotion.initialState(for: id)) != baseline)
        }
    }
}
