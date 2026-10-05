import Foundation

/// Navigation回帰テスト専用。Releaseには存在せず、通常の計測・通知には介入しない。
#if DEBUG
@MainActor
enum TimerNavigationDiagnostics {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-pomodoro-navigation-ui-test")
    }
    private static var timeOffset: TimeInterval = 0

    static func now() -> Date { Date().addingTimeInterval(isEnabled ? timeOffset : 0) }

    static func advancePhase(of model: TimerViewModel) {
        guard isEnabled, model.isRunning else { return }
        timeOffset += TimeInterval(model.timeRemaining)
        model.tick()
        record("test.advancePhase", model: model)
    }

    static func record(_ event: String, model: TimerViewModel) {
        guard isEnabled else { return }
        let line = "[TimerNavigation] \(event) model=\(ObjectIdentifier(model)) " +
            "phase=\(model.phase) state=\(model.state) set=\(model.currentSet)/\(model.totalSets) " +
            "auto=\(model.isAutomaticPomodoroFlow) flow=\(model.pomodoroFlowID?.uuidString ?? "nil") " +
            "persisted=\(model.hasPersistedAutomaticPomodoroFlow)\n"
        print(line, terminator: "")
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("pomodoro-navigation-trace.log")
        guard let data = line.data(using: .utf8) else { return }
        if FileManager.default.fileExists(atPath: file.path),
           let handle = try? FileHandle(forWritingTo: file) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else { try? data.write(to: file) }
    }
}
#endif
