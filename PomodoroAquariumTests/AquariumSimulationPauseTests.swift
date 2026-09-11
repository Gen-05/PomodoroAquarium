import Foundation
import Testing
@testable import PomodoroAquarium

@MainActor
struct AquariumSimulationPauseTests {
    @Test func normalSimulationProducesDeltaTimesAfterItsInitialBaseline() throws {
        var timing = AquariumSimulationTiming()
        let start = Date(timeIntervalSinceReferenceDate: 1_000)

        #expect(timing.nextDeltaTime(at: start, isPaused: false) == nil)

        let nextDeltaTime = timing.nextDeltaTime(
            at: start.addingTimeInterval(1.0 / 30.0),
            isPaused: false
        )
        let deltaTime = try #require(nextDeltaTime)
        #expect(abs(deltaTime - 1.0 / 30.0) < 0.000_001)
    }

    @Test func pausedSimulationDoesNotProduceMovementDeltaTime() {
        var timing = AquariumSimulationTiming()
        let start = Date(timeIntervalSinceReferenceDate: 2_000)

        #expect(timing.nextDeltaTime(at: start, isPaused: false) == nil)
        #expect(timing.nextDeltaTime(
            at: start.addingTimeInterval(1),
            isPaused: true
        ) == nil)
        #expect(timing.lastUpdateDate == nil)
    }

    @Test func resumeDropsPausedElapsedTimeAndContinuesFromANewBaseline() throws {
        var timing = AquariumSimulationTiming()
        let start = Date(timeIntervalSinceReferenceDate: 3_000)

        #expect(timing.nextDeltaTime(at: start, isPaused: false) == nil)
        timing.pause()

        let resumeDate = start.addingTimeInterval(30)
        #expect(timing.nextDeltaTime(at: resumeDate, isPaused: false) == nil)

        let nextDeltaTime = timing.nextDeltaTime(
            at: resumeDate.addingTimeInterval(1.0 / 30.0),
            isPaused: false
        )
        let deltaTime = try #require(nextDeltaTime)
        #expect(abs(deltaTime - 1.0 / 30.0) < 0.000_001)
    }

    @Test func pauseKeepsFishPositionUntilARegularPostResumeTick() throws {
        let fishID = try #require(UUID(uuidString: "6A7D251F-A05B-4A6A-B704-6BC92A35F50D"))
        var motion = AquariumFishMotion.initialState(for: fishID)
        var timing = AquariumSimulationTiming()
        let start = Date(timeIntervalSinceReferenceDate: 4_000)

        #expect(timing.nextDeltaTime(at: start, isPaused: false) == nil)
        let positionBeforePause = motion.position

        if let deltaTime = timing.nextDeltaTime(
            at: start.addingTimeInterval(10),
            isPaused: true
        ) {
            motion.advance(deltaTime: deltaTime, elapsedTime: deltaTime)
        }
        #expect(motion.position == positionBeforePause)

        let resumeDate = start.addingTimeInterval(30)
        if let deltaTime = timing.nextDeltaTime(at: resumeDate, isPaused: false) {
            motion.advance(deltaTime: deltaTime, elapsedTime: deltaTime)
        }
        #expect(motion.position == positionBeforePause)

        let nextDeltaTime = timing.nextDeltaTime(
            at: resumeDate.addingTimeInterval(1.0 / 30.0),
            isPaused: false
        )
        let deltaTime = try #require(nextDeltaTime)
        motion.advance(deltaTime: deltaTime, elapsedTime: deltaTime)
        #expect(motion.position != positionBeforePause)
    }
}
