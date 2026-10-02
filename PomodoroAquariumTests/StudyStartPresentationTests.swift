import Foundation
import Testing
@testable import PomodoroAquarium

@MainActor
struct StudyStartPresentationTests {
    private let start = Date(timeIntervalSince1970: 1_000)
    private var crest: Date { start.addingTimeInterval(StudyStartPresentation.Effect.ripple.startDelay) }
    private var finish: Date { start.addingTimeInterval(StudyStartPresentation.Effect.ripple.duration) }

    @Test func repeatedStartAndCompletionCannotStartTwice() throws {
        var presentation = StudyStartPresentation()
        presentation.begin(state: .idle, phase: .study, reduceMotion: false, isTutorial: false, now: start)
        let id = try #require(presentation.requestID)
        presentation.begin(state: .idle, phase: .study, reduceMotion: true, isTutorial: false, now: start)
        #expect(presentation.requestID == id)
        #expect(presentation.effect == .ripple)
        #expect(presentation.startDeadline == crest)
        #expect(presentation.deadline == finish)
        let tooEarly = presentation.start(id: id, now: crest.addingTimeInterval(-0.01))
        #expect(!tooEarly)
        let started = presentation.start(id: id, now: crest)
        #expect(started)
        #expect(presentation.isPresenting)
        #expect(presentation.hasStarted)
        #expect(presentation.canContinue(state: .running, phase: .study))
        let repeatedStart = presentation.start(id: id, now: crest.addingTimeInterval(0.1))
        #expect(!repeatedStart)
        presentation.begin(state: .idle, phase: .study, reduceMotion: false, isTutorial: false, now: start)
        #expect(presentation.requestID == id)
        let stillReceding = presentation.complete(id: id, now: finish.addingTimeInterval(-0.01))
        #expect(!stillReceding)
        let completed = presentation.complete(id: id, now: finish)
        #expect(completed)
        let repeated = presentation.complete(id: id, now: finish.addingTimeInterval(0.1))
        #expect(!repeated)
        #expect(!presentation.isPresenting)
    }

    @Test func rippleDelayStartsAllModesWithoutCountingTheInitialAnimationTime() throws {
        for mode in TimerMode.allCases {
            let suite = "StudyStartTests.\(UUID().uuidString)"
            let defaults = try #require(UserDefaults(suiteName: suite))
            defer { defaults.removePersistentDomain(forName: suite) }
            var now = start
            let timer = TimerViewModel(
                studyTime: 25, breakTime: 5, now: { now },
                sessionStore: TimerSessionStore(defaults: defaults),
                notificationService: DisabledTimerNotificationService()
            )
            timer.selectMode(mode)
            var presentation = StudyStartPresentation()
            presentation.begin(state: timer.state, phase: timer.phase,
                               reduceMotion: false, isTutorial: false, now: now)
            let id = try #require(presentation.requestID)
            now = crest
            #expect(timer.state == .idle)
            #expect(timer.elapsedStudySeconds == 0)
            let started = presentation.start(id: id, now: now)
            if started { timer.resumeTimer() }
            #expect(started)
            #expect(timer.state == .running)
            #expect(timer.elapsedStudySeconds == 0)
            if mode != .stopwatch {
                #expect(timer.endDate == now.addingTimeInterval(25 * 60))
            }
            #expect(presentation.isPresenting)
            #expect(presentation.canContinue(state: timer.state, phase: timer.phase))
            now = finish
            let completed = presentation.complete(id: id, now: now)
            #expect(completed)
            #expect(!presentation.isPresenting)
            #expect(timer.state == .running)
            timer.pauseTimer()
        }
    }

    @Test func resumeRunningAndBreakDoNotPresentAnEffect() {
        for (state, phase) in [(TimerState.paused, PomodoroSessionPhase.study),
                               (.running, .study), (.idle, .breakTime),
                               (.completed, .breakTime), (.idle, .awaitingNextSet)] {
            var presentation = StudyStartPresentation()
            presentation.begin(state: state, phase: phase, reduceMotion: false, isTutorial: false, now: start)
            #expect(!presentation.isPresenting)
        }
    }

    @Test func reduceMotionAndTutorialUseOnlyAShortFade() throws {
        for (reduceMotion, tutorial) in [(true, false), (false, true)] {
            var presentation = StudyStartPresentation()
            presentation.begin(state: .idle, phase: .study, reduceMotion: reduceMotion,
                               isTutorial: tutorial, now: start)
            #expect(presentation.effect == .fade)
            #expect(presentation.deadline == start.addingTimeInterval(0.2))
            let id = try #require(presentation.requestID)
            let started = presentation.start(id: id, now: start.addingTimeInterval(0.2))
            #expect(started)
            let completed = presentation.complete(id: id, now: start.addingTimeInterval(0.2))
            #expect(completed)
        }
    }

    @Test func cancellationInvalidatesOldStartCompletion() throws {
        var presentation = StudyStartPresentation()
        presentation.begin(state: .idle, phase: .study, reduceMotion: false, isTutorial: false, now: start)
        let id = try #require(presentation.requestID)
        presentation.reset()
        let cancelled = presentation.complete(id: id, now: start.addingTimeInterval(2))
        #expect(!cancelled)
        #expect(!presentation.isPresenting)
        #expect(presentation.deadline == nil)
        #expect(presentation.startDeadline == nil)
        #expect(!presentation.hasStarted)
        presentation.begin(state: .idle, phase: .study, reduceMotion: false, isTutorial: false, now: start)
        let stale = presentation.complete(id: id, now: start.addingTimeInterval(2))
        #expect(!stale)
        #expect(presentation.isPresenting)
    }

    @Test func cancellationWhileRingsFadeDoesNotStartAgain() throws {
        var presentation = StudyStartPresentation()
        presentation.begin(state: .idle, phase: .study, reduceMotion: false, isTutorial: false, now: start)
        let id = try #require(presentation.requestID)
        let started = presentation.start(id: id, now: crest)
        #expect(started)
        #expect(!presentation.canContinue(state: .paused, phase: .study))
        #expect(!presentation.canContinue(state: .running, phase: .breakTime))
        presentation.reset()
        let repeated = presentation.start(id: id, now: start.addingTimeInterval(2))
        let completed = presentation.complete(id: id, now: start.addingTimeInterval(2))
        #expect(!repeated)
        #expect(!completed)
        #expect(!presentation.isPresenting)
    }

    @Test func focusDisplayCountdownStartsWithRunningWhileTheRippleRemains() throws {
        var presentation = StudyStartPresentation()
        presentation.begin(state: .idle, phase: .study, reduceMotion: false, isTutorial: false, now: start)
        let id = try #require(presentation.requestID)
        let started = presentation.start(id: id, now: crest)
        #expect(started)
        var display = FocusDisplayState()
        let runningContext = FocusDisplayState.Context(
            timerState: .running, phase: .study, isActive: true,
            isVisible: !presentation.isPresenting || presentation.hasStarted, isTutorial: false
        )
        display.update(context: runningContext, now: crest)
        #expect(display.deadline == crest.addingTimeInterval(10))
        let completed = presentation.complete(id: id, now: finish)
        #expect(completed)
        let finishedContext = FocusDisplayState.Context(
            timerState: .running, phase: .study, isActive: true,
            isVisible: !presentation.isPresenting || presentation.hasStarted, isTutorial: false
        )
        // TimerView's onChange must not restart the timeout when only the ripple disappears.
        #expect(finishedContext == runningContext)
        #expect(display.deadline == crest.addingTimeInterval(10))
    }

}
