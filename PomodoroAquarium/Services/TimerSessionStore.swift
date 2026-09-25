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
    /// セッション開始時に選ばれた集中カテゴリ。旧保存データは「勉強」へfallbackする。
    let selectedCategoryID: String?
    /// 離脱通知を同じ集中セッション単位で予約・解除するための識別子。
    /// 旧保存データとの互換性のためOptional。
    let backgroundNotificationSessionIdentifier: String?
    let lastHeartbeatDate: Date
    /// running中のstudyで、アプリがbackgroundへ入った最初の時刻。
    /// 旧保存データとの互換性のためOptional。
    let backgroundEnteredAt: Date?
    let studyTime: Int
    let breakTime: Int
    /// 旧保存データとの互換性を保ちながら、複数セット中のstudy位置を復元する。
    let currentSet: Int?
    let totalSets: Int?
    let processIdentifier: String
}

enum TimerSessionLaunchStatus: Equatable {
    case none
    case sameProcess(PersistedTimerSession)
    case recoverable(PersistedTimerSession)
    case interrupted(PersistedTimerSession)
}

final class TimerSessionStore {
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
        selectedCategoryID: String,
        backgroundNotificationSessionIdentifier: String?,
        lastHeartbeatDate: Date,
        backgroundEnteredAt: Date?,
        studyTime: Int,
        breakTime: Int,
        currentSet: Int,
        totalSets: Int
    ) -> PersistedTimerSession {
        PersistedTimerSession(
            sessionIsActive: true,
            endDate: endDate,
            isStudyTime: isStudyTime,
            isRunning: isRunning,
            timeRemaining: timeRemaining,
            elapsedStudySeconds: elapsedStudySeconds,
            timerModeRawValue: timerModeRawValue,
            selectedCategoryID: selectedCategoryID,
            backgroundNotificationSessionIdentifier: backgroundNotificationSessionIdentifier,
            lastHeartbeatDate: lastHeartbeatDate,
            backgroundEnteredAt: backgroundEnteredAt,
            studyTime: studyTime,
            breakTime: breakTime,
            currentSet: currentSet,
            totalSets: totalSets,
            processIdentifier: processIdentifier
        )
    }

    func launchStatus(at _: Date) -> TimerSessionLaunchStatus {
        guard let session = load(), session.sessionIsActive else { return .none }
        guard session.isStudyTime else {
            clearSession()
            return .none
        }

        if session.processIdentifier == processIdentifier {
            return .sameProcess(session)
        }

        // pause中、またはbackground突入時刻を保存済みのsessionだけを復元する。
        // 旧保存データや不整合sessionを正常完了へ救済すると報酬が誤付与されるため、
        // runningなのにbackgroundEnteredAtがない別processのsessionは安全側で中断する。
        if !session.isRunning || session.backgroundEnteredAt != nil {
            return .recoverable(session)
        }

        return .interrupted(session)
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
