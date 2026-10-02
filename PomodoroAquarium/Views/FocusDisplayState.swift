import Foundation

/// Presentation only: never changes session timing or aquarium simulation.
struct FocusDisplayState {
    static let inactivityInterval: TimeInterval = 10
    static let fadeDuration: TimeInterval = 0.3

    struct Context: Equatable {
        let timerState: TimerState
        let phase: PomodoroSessionPhase
        let isActive: Bool
        let isVisible: Bool
        let isTutorial: Bool

        var canAutoHide: Bool {
            timerState == .running && phase == .study &&
                isActive && isVisible && !isTutorial
        }
    }

    private(set) var isFocusDisplayMode = false
    private(set) var timeoutID: UUID?
    private(set) var deadline: Date?
    private var canAutoHide = false

    mutating func update(context: Context, now: Date = .now) {
        reset()
        canAutoHide = context.canAutoHide
        if canAutoHide { userInteracted(now: now) }
    }

    mutating func userInteracted(now: Date = .now) {
        guard canAutoHide else { return }
        isFocusDisplayMode = false
        deadline = now.addingTimeInterval(Self.inactivityInterval)
        timeoutID = UUID()
    }

    mutating func timeout(id: UUID, now: Date = .now) {
        guard canAutoHide, timeoutID == id, let deadline, now >= deadline else { return }
        isFocusDisplayMode = true
        timeoutID = nil
        self.deadline = nil
    }

    mutating func reset() {
        canAutoHide = false
        isFocusDisplayMode = false
        timeoutID = nil
        deadline = nil
    }
}
