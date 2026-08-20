import Foundation

struct PersistedTimerSession: Codable, Equatable {
    let sessionIsActive: Bool
    let endDate: Date?
    let isStudyTime: Bool
    let isRunning: Bool
    let timeRemaining: Int
    /// 勉強セッションで実際に経過した秒数。旧保存データとの互換性のためOptional。
    let elapsedStudySeconds: Int?
    /// 旧保存データはカウントダウンとして復元する。
    let timerModeRawValue: String?
    let lastHeartbeatDate: Date
    let studyTime: Int
    let breakTime: Int
    let processIdentifier: String
}

enum TimerSessionLaunchStatus: Equatable {
    case none
    case sameProcess(PersistedTimerSession)
    case recoverable(PersistedTimerSession)
    case expired(PersistedTimerSession)
}

final class TimerSessionStore {
    static let gracePeriod: TimeInterval = 10 * 60
    static let heartbeatInterval: TimeInterval = 20
    static let shared = TimerSessionStore()

    private enum Key {
        static let session = "timerSessionState"
        static let interruptionBannerPending = "timerInterruptionBannerPending"
    }

    private let defaults: UserDefaults
    private let processIdentifier: String

    init(
        defaults: UserDefaults = .standard,
        processIdentifier: String = ProcessInfo.processInfo.globallyUniqueString
    ) {
        self.defaults = defaults
        self.processIdentifier = processIdentifier
    }

    func save(_ session: PersistedTimerSession) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        defaults.set(data, forKey: Key.session)
    }

    func makeSession(
        endDate: Date?,
        isStudyTime: Bool,
        isRunning: Bool,
        timeRemaining: Int,
        elapsedStudySeconds: Int,
        timerModeRawValue: String,
        lastHeartbeatDate: Date,
        studyTime: Int,
        breakTime: Int
    ) -> PersistedTimerSession {
        PersistedTimerSession(
            sessionIsActive: true,
            endDate: endDate,
            isStudyTime: isStudyTime,
            isRunning: isRunning,
            timeRemaining: timeRemaining,
            elapsedStudySeconds: elapsedStudySeconds,
            timerModeRawValue: timerModeRawValue,
            lastHeartbeatDate: lastHeartbeatDate,
            studyTime: studyTime,
            breakTime: breakTime,
            processIdentifier: processIdentifier
        )
    }

    func launchStatus(at date: Date) -> TimerSessionLaunchStatus {
        guard let session = load(), session.sessionIsActive else { return .none }
        guard session.isStudyTime else {
            clearSession()
            return .none
        }

        if session.processIdentifier == processIdentifier {
            return .sameProcess(session)
        }

        if date.timeIntervalSince(session.lastHeartbeatDate) <= Self.gracePeriod {
            return .recoverable(session)
        }

        // TimerViewModelが保存済み経過時間で途中終了処理を行ってから削除する。
        return .expired(session)
    }

    func clearSession() {
        defaults.removeObject(forKey: Key.session)
    }

    func consumeInterruptionBanner() -> Bool {
        guard defaults.bool(forKey: Key.interruptionBannerPending) else { return false }
        defaults.removeObject(forKey: Key.interruptionBannerPending)
        return true
    }

    func load() -> PersistedTimerSession? {
        guard let data = defaults.data(forKey: Key.session) else { return nil }
        return try? JSONDecoder().decode(PersistedTimerSession.self, from: data)
    }
}
