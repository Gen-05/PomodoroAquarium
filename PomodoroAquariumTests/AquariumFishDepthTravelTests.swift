import Foundation
import Testing
@testable import PomodoroAquarium

@MainActor
struct AquariumFishDepthTravelTests {
    private let id = UUID(uuidString: "B10E7A60-6A60-4A60-8A60-000000000001")!
    private let dt = 1.0 / 30

    private func advance(_ state: inout AquariumFishMotion.State, seconds: Double) {
        for frame in 1...Int((seconds / dt).rounded()) {
            state.advance(deltaTime: dt, elapsedTime: Double(frame) * dt)
        }
    }

    @Test func holdsThenTravelsToOneDistantTargetAndStaysAfterArrival() throws {
        var state = AquariumFishMotion.initialState(for: id)
        let start = state.currentDepth
        let initialWait = state.depthChangeTimeRemaining
        #expect((20...40).contains(initialWait))
        #expect(state.targetDepth == start)
        advance(&state, seconds: initialWait - 0.1)
        #expect(state.currentDepth == start)
        #expect(state.depthTravel == nil)
        advance(&state, seconds: 0.2)
        let travel = try #require(state.depthTravel)
        let target = state.targetDepth
        let random = state.depthRandomState
        let range = state.movementProfile.depthRange
        #expect((6...10).contains(travel.duration))
        #expect(abs(target - start) >= (range.upperBound - range.lowerBound) * 0.4 - 0.000001)
        #expect(abs(state.currentDepth - start) < 0.0001) // 滑らかな出発。
        advance(&state, seconds: 3)
        #expect(state.targetDepth == target)
        #expect(state.depthRandomState == random) // 移動中は抽選・目標更新をしない。
        #expect(state.depthTravel?.start == start)
        advance(&state, seconds: 7)
        #expect(state.depthTravel == nil)
        #expect(state.currentDepth == target)
        let arrivalWait = state.depthChangeTimeRemaining
        advance(&state, seconds: 5)
        #expect(state.currentDepth == target)
        #expect(abs(state.depthChangeTimeRemaining - (arrivalWait - 5)) < 0.000001)
    }

    @Test func everySpeciesStaysInRangeAndIndividualsHaveStaggeredRepeatableWaits() {
        var waits: Set<Double> = []
        for number in 1...20 {
            let individual = UUID(uuidString: String(format: "B10E7A60-6A60-4A60-8A60-%012d", number))!
            let first = AquariumFishMotion.initialState(for: individual)
            let repeated = AquariumFishMotion.initialState(for: individual)
            waits.insert(first.depthChangeTimeRemaining)
            #expect(first.depthRandomState == repeated.depthRandomState)
            #expect(first.depthChangeTimeRemaining == repeated.depthChangeTimeRemaining)
        }
        #expect(waits.count > 10)
        for species in FishSpecies.allCases {
            let profile = AquariumFishMotion.movementProfile(for: species)
            var state = AquariumFishMotion.initialState(for: id, profile: profile)
            var arrived = 0
            var inRange = true
            var stableTarget = true
            var meaningfulDistance = true
            var longestStep: CGFloat = 0
            for frame in 1...4_800 { // 実時間待機なしで160秒分。専用遊泳経路も通す。
                let old = state
                state.advance(deltaTime: dt, elapsedTime: Double(frame) * dt)
                inRange = inRange && profile.depthRange.contains(state.currentDepth)
                    && profile.depthRange.contains(state.targetDepth)
                longestStep = max(longestStep, abs(state.currentDepth - old.currentDepth))
                if old.depthTravel != nil {
                    stableTarget = stableTarget && old.targetDepth == state.targetDepth
                    if state.depthTravel == nil { arrived += 1 }
                } else if state.depthTravel != nil {
                    meaningfulDistance = meaningfulDistance && abs(state.targetDepth - old.currentDepth)
                        >= (profile.depthRange.upperBound - profile.depthRange.lowerBound) * 0.4 - 0.000001
                }
            }
            #expect(inRange, "\(species)")
            #expect(stableTarget && meaningfulDistance, "\(species)")
            #expect(arrived >= 3, "\(species)")
            #expect(longestStep < 0.01, "\(species)")
        }
    }

    @Test func movingDepthSurvivesHandoffPauseAndEditingCancelOrSave() throws {
        let session = AquariumFishViewingSession()
        let home = UUID(), timer = UUID(), editor = UUID()
        var motion = AquariumFishMotion.initialState(for: id)
        advance(&motion, seconds: motion.depthChangeTimeRemaining + 3)
        #expect(motion.depthTravel != nil)
        let snapshot = AquariumFishViewingSession.Snapshot(motion: motion,
            direction: FishSpriteDirectionTransition(direction: motion.facingDirection))
        _ = session.claim(id, owner: home, initial: snapshot, bounds: .legacy)
        let transferred = session.claim(id, owner: timer, initial: snapshot, bounds: .legacy)
        #expect(transferred.motion.depthTravel == motion.depthTravel)
        #expect(transferred.motion.currentDepth == motion.currentDepth)
        #expect(!session.update(id, owner: home, snapshot: snapshot))
        var clock = AquariumSimulationTiming()
        let date = Date(timeIntervalSince1970: 100)
        #expect(clock.nextDeltaTime(at: date, isPaused: false) == nil)
        clock.pause()
        #expect(clock.nextDeltaTime(at: date.addingTimeInterval(3600), isPaused: false) == nil)
        #expect(abs((clock.nextDeltaTime(at: date.addingTimeInterval(3600 + dt), isPaused: false) ?? 0) - dt) < 0.000001)
        session.beginEditing()
        let editing = try #require(session.editingSession)
        var edited = editing.claim(id, owner: editor, initial: snapshot, bounds: .legacy)
        advance(&edited.motion, seconds: 1)
        #expect(editing.update(id, owner: editor, snapshot: edited))
        session.finishEditing() // キャンセルで編集中の深度は正式な水槽へ漏れない。
        #expect(session.snapshot(for: id)?.motion.depthTravel == motion.depthTravel)
        session.beginEditing()
        let saving = try #require(session.editingSession)
        _ = saving.claim(id, owner: editor, initial: snapshot, bounds: .legacy)
        #expect(saving.update(id, owner: editor, snapshot: edited))
        session.finishEditing(commit: [id])
        #expect(session.snapshot(for: id)?.motion.depthTravel == edited.motion.depthTravel)
        #expect(session.snapshot(for: id)?.motion.currentDepth == edited.motion.currentDepth)
        // 保存した途中状態から進めても、連続更新した場合と同じ深度になる。
        var resumed = try #require(session.snapshot(for: id)).motion
        advance(&resumed, seconds: 1)
        advance(&edited.motion, seconds: 1)
        #expect(resumed.currentDepth == edited.motion.currentDepth)
        #expect(resumed.depthTravel == edited.motion.depthTravel)
        #expect(resumed.depthRandomState == edited.motion.depthRandomState)
    }
}
