import Foundation
import Testing
@testable import PomodoroAquarium

@MainActor
struct WhaleSharkAnimationTempoTests {
    private typealias Tempo = AquariumWhaleSharkAnimationTempo
    private let ids = (1...5).map {
        UUID(uuidString: String(format: "A11E5A40-0000-4000-8000-%012d", $0))!
    }

    @Test func settingsAndRandomDrawsAreLimitedToPhaseBoundaries() {
        #expect(AquariumFishMotion.whaleSharkSpriteFrameDuration == 0.24)
        #expect(Tempo.normalDuration == 5...12 && Tempo.slowDuration == 3...7)
        #expect(Tempo.transitionDuration == 1.5...3 && Tempo.slowSpeed == 0.60...0.75)
        var state = Tempo.State(id: ids[0])
        var durations: [Double] = []
        let phases: [Tempo.State.Phase] = [.normal, .slowing, .slow, .returning]
        for index in 0..<40 {
            #expect(state.phase == phases[index % 4])
            let range = state.phase == .normal ? Tempo.normalDuration
                : state.phase == .slow ? Tempo.slowDuration : Tempo.transitionDuration
            #expect(range.contains(state.phaseDuration))
            if state.phase != .normal { #expect(Tempo.slowSpeed.contains(state.slowSpeedMultiplier)) }
            let random = state.randomState, rate = state.speedMultiplier
            let step = state.phaseDuration / 4
            state.advance(deltaTime: step)
            #expect(state.randomState == random)
            let atEnd = state.phase == .slowing ? state.slowSpeedMultiplier : state.phase == .slow ? state.slowSpeedMultiplier : 1
            state.advance(deltaTime: state.phaseDuration - state.phaseElapsed)
            #expect(abs(state.speedMultiplier - atEnd) < 0.000000001)
            #expect(rate > 0 && rate <= 1)
            #expect(state.randomState != random)
            if state.phase == .normal { durations.append(state.phaseDuration) }
        }
        #expect(Set(durations).count == durations.count)
    }

    @Test func independentFishNeverExceedBaseSpeedAndAlwaysAdvanceForward() {
        var initialWaits: [Double] = []
        var schedules: [[Double]] = []
        for id in ids {
            var state = Tempo.State(id: id), repeated = Tempo.State(id: id)
            initialWaits.append(state.phaseDuration)
            var changes: [Double] = []
            var frame = Int(floor(AquariumFishMotion.spriteAnimationPhase(for: id)
                / (0.24 * AquariumFishMotion.spriteTempoMultiplier(for: id))))
            let dt = 1.0 / 60
            for _ in 0..<7_200 {
                let previous = state
                state.advance(deltaTime: dt)
                repeated.advance(deltaTime: dt)
                #expect(state == repeated)
                #expect(state.speedMultiplier >= 0.60 - 0.000000001 && state.speedMultiplier <= 1)
                let progress = state.playbackTime - previous.playbackTime
                #expect(progress >= dt * 0.60 - 0.000000001 && progress <= dt + 0.000000001)
                #expect(abs(state.speedMultiplier - previous.speedMultiplier) < 0.007)
                if state.phase == previous.phase { #expect(state.randomState == previous.randomState) }
                else { changes.append(state.playbackTime) }
                let next = Int(floor((state.playbackTime + AquariumFishMotion.spriteAnimationPhase(for: id))
                    / (0.24 * AquariumFishMotion.spriteTempoMultiplier(for: id))))
                #expect(next >= frame && next - frame <= 1)
                frame = next
            }
            #expect(changes.count >= 16)
            schedules.append(changes)
        }
        #expect(Set(initialWaits).count == ids.count)
        for index in 1..<schedules.count { #expect(schedules[index] != schedules[0]) }
    }

    @Test func integratedPlaybackDoesNotDependOnTickPartitionOrResetAtTransitions() {
        for id in ids {
            var single = Tempo.State(id: id, playbackTime: 42)
            var partitioned = single
            single.advance(deltaTime: 120)
            for _ in 0..<7_200 { partitioned.advance(deltaTime: 1.0 / 60) }
            #expect(single.phase == partitioned.phase && single.randomState == partitioned.randomState)
            #expect(abs(single.phaseElapsed - partitioned.phaseElapsed) < 0.0000001)
            #expect(abs(single.playbackTime - partitioned.playbackTime) < 0.0000001)
            #expect(single.playbackTime >= 42 + 120 * 0.60 && single.playbackTime <= 162)
            let before = single
            for invalid in [0, -1, Double.nan, Double.infinity] { single.advance(deltaTime: invalid) }
            #expect(single == before)
        }
    }

    @Test func sessionHandoffEditingAndStoragePreserveOrDiscardOnlyTheCorrectTempo() throws {
        let id = ids[0], owner = UUID(), nextOwner = UUID()
        let session = AquariumFishViewingSession()
        let motion = AquariumFishMotion.initialState(for: id, profile: .whaleShark)
        var tempo = Tempo.State(id: id)
        tempo.advance(deltaTime: tempo.phaseDuration + 0.8)
        let initial = AquariumFishViewingSession.Snapshot(motion: motion,
            direction: .init(direction: motion.facingDirection), whaleSharkTempo: tempo)
        var saved = session.claim(id, owner: owner, initial: initial, bounds: .legacy)
        saved.whaleSharkTempo?.advance(deltaTime: 0.2)
        #expect(session.update(id, owner: owner, snapshot: saved))
        let resumed = session.claim(id, owner: nextOwner, initial: initial, bounds: .legacy)
        #expect(resumed.whaleSharkTempo == saved.whaleSharkTempo)
        #expect(!session.update(id, owner: owner, snapshot: initial))
        session.release(id, owner: owner)
        #expect(session.isOwner(id, owner: nextOwner))

        session.beginEditing()
        let edit = try #require(session.editingSession)
        var draft = edit.claim(id, owner: owner, initial: initial, bounds: .legacy)
        draft.whaleSharkTempo?.advance(deltaTime: 10)
        #expect(edit.update(id, owner: owner, snapshot: draft))
        session.finishEditing()
        #expect(session.snapshot(for: id)?.whaleSharkTempo == saved.whaleSharkTempo)
        session.beginEditing()
        let commit = try #require(session.editingSession)
        _ = commit.claim(id, owner: owner, initial: draft, bounds: .legacy)
        #expect(commit.update(id, owner: owner, snapshot: draft))
        session.finishEditing(commit: [id])
        #expect(session.snapshot(for: id)?.whaleSharkTempo == draft.whaleSharkTempo)
        session.stopInflation(except: [])
        #expect(session.snapshot(for: id) == nil)
    }
}
