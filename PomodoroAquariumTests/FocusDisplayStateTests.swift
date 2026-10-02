import Foundation
import Testing
@testable import PomodoroAquarium

@MainActor
struct FocusDisplayStateTests {
    private let start = Date(timeIntervalSince1970: 1_000)

    private func context(
        state: TimerState = .running,
        phase: PomodoroSessionPhase = .study,
        active: Bool = true,
        visible: Bool = true,
        tutorial: Bool = false
    ) -> FocusDisplayState.Context {
        .init(timerState: state, phase: phase, isActive: active, isVisible: visible, isTutorial: tutorial)
    }

    @Test func runningHidesOnlyAfterTenSecondsAndTapRestartsTimeout() throws {
        var display = FocusDisplayState()
        display.update(context: context(), now: start)
        let first = try #require(display.timeoutID)
        #expect(display.deadline == start.addingTimeInterval(10))
        display.timeout(id: first, now: start.addingTimeInterval(9.99))
        #expect(!display.isFocusDisplayMode)
        display.timeout(id: first, now: start.addingTimeInterval(10))
        #expect(display.isFocusDisplayMode)
        #expect(display.timeoutID == nil)

        display.userInteracted(now: start.addingTimeInterval(11))
        #expect(!display.isFocusDisplayMode)
        let second = try #require(display.timeoutID)
        #expect(second != first)
        #expect(display.deadline == start.addingTimeInterval(21))
        display.timeout(id: second, now: start.addingTimeInterval(21))
        #expect(display.isFocusDisplayMode)
    }

    @Test func normalInteractionInvalidatesOldTimeout() throws {
        var display = FocusDisplayState()
        display.update(context: context(), now: start)
        let old = try #require(display.timeoutID)
        display.userInteracted(now: start.addingTimeInterval(8))
        display.timeout(id: old, now: start.addingTimeInterval(10))
        #expect(!display.isFocusDisplayMode)
        #expect(display.deadline == start.addingTimeInterval(18))
    }

    @Test func pauseAndResumeStartFromVisibleControls() throws {
        var display = FocusDisplayState()
        display.update(context: context(), now: start)
        let old = try #require(display.timeoutID)
        display.timeout(id: old, now: start.addingTimeInterval(10))
        display.update(context: context(state: .paused), now: start.addingTimeInterval(11))
        #expect(!display.isFocusDisplayMode)
        #expect(display.timeoutID == nil)
        display.userInteracted(now: start.addingTimeInterval(30))
        display.timeout(id: old, now: start.addingTimeInterval(30))
        #expect(!display.isFocusDisplayMode)
        #expect(display.timeoutID == nil)

        display.update(context: context(), now: start.addingTimeInterval(31))
        #expect(!display.isFocusDisplayMode)
        #expect(display.deadline == start.addingTimeInterval(41))
        display.timeout(id: try #require(display.timeoutID), now: start.addingTimeInterval(41))
        #expect(display.isFocusDisplayMode)
    }

    @Test func completedResetBreakAndDisappearanceCancelTimeout() throws {
        for next in [context(state: .completed), context(state: .idle),
                     context(phase: .breakTime), context(phase: .awaitingNextSet),
                     context(phase: .finished), context(visible: false)] {
            var display = FocusDisplayState()
            display.update(context: context(), now: start)
            let old = try #require(display.timeoutID)
            display.timeout(id: old, now: start.addingTimeInterval(10))
            display.update(context: next, now: start.addingTimeInterval(11))
            #expect(!display.isFocusDisplayMode)
            #expect(display.timeoutID == nil)
            #expect(display.deadline == nil)
            display.timeout(id: old, now: start.addingTimeInterval(30))
            #expect(!display.isFocusDisplayMode)
        }
        var display = FocusDisplayState()
        display.update(context: context(), now: start)
        display.reset()
        #expect(!display.isFocusDisplayMode)
        #expect(display.timeoutID == nil)
        #expect(display.deadline == nil)
    }

    @Test func backgroundCancelsAndForegroundRestartsFromNormalUI() throws {
        var display = FocusDisplayState()
        display.update(context: context(), now: start)
        let old = try #require(display.timeoutID)
        display.update(context: context(active: false), now: start.addingTimeInterval(5))
        display.timeout(id: old, now: start.addingTimeInterval(15))
        #expect(!display.isFocusDisplayMode)
        #expect(display.timeoutID == nil)
        display.update(context: context(), now: start.addingTimeInterval(20))
        #expect(!display.isFocusDisplayMode)
        #expect(display.deadline == start.addingTimeInterval(30))
    }

    @Test func tutorialNeverAutomaticallyHidesControls() {
        var display = FocusDisplayState()
        display.update(context: context(tutorial: true), now: start)
        display.userInteracted(now: start.addingTimeInterval(30))
        #expect(!display.isFocusDisplayMode)
        #expect(display.timeoutID == nil)
        #expect(display.deadline == nil)
    }
}
