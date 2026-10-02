import Foundation

/// A one-shot presentation gate. It never measures time or starts a session itself.
struct StudyStartPresentation {
    enum Effect {
        case ripple
        case fade

        var runningUIFadeDuration: TimeInterval { self == .ripple ? 0.25 : 0 }
        var startDelay: TimeInterval {
            self == .ripple ? WaterRippleView.Variant.startDuration + runningUIFadeDuration : 0.2
        }
        var duration: TimeInterval { startDelay }
    }

    private(set) var requestID: UUID?
    private(set) var effect: Effect = .ripple
    private(set) var deadline: Date?
    private(set) var startDeadline: Date?
    private(set) var hasStarted = false
    var isPresenting: Bool { requestID != nil }

    static func canStart(state: TimerState, phase: PomodoroSessionPhase) -> Bool {
        (state == .idle || state == .completed) && (phase == .study || phase == .finished)
    }

    mutating func begin(
        state: TimerState,
        phase: PomodoroSessionPhase,
        reduceMotion: Bool,
        isTutorial: Bool,
        now: Date = .now
    ) {
        guard !isPresenting, Self.canStart(state: state, phase: phase) else { return }
        effect = reduceMotion || isTutorial ? .fade : .ripple
        requestID = UUID()
        hasStarted = false
        startDeadline = now.addingTimeInterval(effect.startDelay)
        deadline = now.addingTimeInterval(effect.duration)
    }

    /// Start measuring only after the ripple and the running-controls fade have finished.
    mutating func start(id: UUID, now: Date = .now) -> Bool {
        guard requestID == id, !hasStarted, let startDeadline, now >= startDeadline else { return false }
        hasStarted = true
        return true
    }

    func canContinue(state: TimerState, phase: PomodoroSessionPhase) -> Bool {
        Self.canStart(state: state, phase: phase) ||
            (hasStarted && state == .running && phase == .study)
    }

    mutating func complete(id: UUID, now: Date = .now) -> Bool {
        guard requestID == id, hasStarted, let deadline, now >= deadline else { return false }
        reset()
        return true
    }

    mutating func reset() {
        requestID = nil
        deadline = nil
        startDeadline = nil
        hasStarted = false
    }
}
