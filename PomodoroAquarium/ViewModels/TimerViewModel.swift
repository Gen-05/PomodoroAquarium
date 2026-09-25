//
//  TimerViewModel.swift
//  PomodoroAquarium
//
//  Created by 阿部弦生 on 2026/07/17.
//

import Foundation
import Observation

enum TimerState: Equatable {
    case idle
    case running
    case paused
    case completed
}

enum TimerMode: String, CaseIterable, Identifiable {
    case pomodoro
    case countdown
    case stopwatch

    var id: Self { self }

    var displayName: String {
        switch self {
        case .pomodoro: "ポモドーロ"
        case .countdown: "タイマー"
        case .stopwatch: "ストップウォッチ"
        }
    }

    var showsTimeSettings: Bool {
        self != .stopwatch
    }
}

enum StudySessionEndReason: Equatable {
    case completed
    case userEnded
    case interrupted
    case backgroundLimitExceeded

    var isNormalCompletion: Bool { self == .completed }
}

enum PomodoroSessionPhase: Equatable {
    case study
    case breakTime
    case awaitingNextSet
    case finished
}

enum BackgroundStudyLimit {
    static let warningInterval: TimeInterval = 3 * 60
    static let failureInterval: TimeInterval = 5 * 60
}

@Observable
final class TimerViewModel {
    
    private var studyTime: Int
    private var breakTime: Int
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let sessionStore: TimerSessionStore
    @ObservationIgnored private let notificationService: TimerNotificationScheduling

    private var hasHandledCurrentSessionCompletion = false
    private var hasAttemptedRestore = false
    private var lastHeartbeatDate: Date?
    private(set) var backgroundEnteredAt: Date?
    private(set) var lastBackgroundDuration: TimeInterval?
    private(set) var didExceedBackgroundLimit = false
    private(set) var shouldPresentBackgroundFailureAlert = false
    private var backgroundNotificationSessionIdentifier: String?
    private var stopwatchRunStartDate: Date?
    private var stopwatchElapsedAtRunStart = 0
    
    var onStudyFinished: (() -> Void)?
    var onBreakFinished: (() -> Void)?
    
    var timeRemaining: Int
    private(set) var mode: TimerMode = .pomodoro
    private(set) var selectedCategoryID = FocusCategoryDefaults.studyID
    private(set) var stopwatchElapsedSeconds = 0
    private(set) var state: TimerState = .idle
    var isRunning: Bool { state == .running }
    private(set) var phase: PomodoroSessionPhase = .study
    var isStudyTime: Bool { phase != .breakTime }
    private(set) var currentSet = 1
    private(set) var totalSets: Int
    private(set) var endDate: Date?
    private(set) var lastCompletedStudyMinutes = 0
    private(set) var lastStudySessionEndReason: StudySessionEndReason?

    var shouldBeginPomodoroBreak: Bool {
        mode == .pomodoro &&
            phase == .breakTime &&
            state == .completed &&
            lastStudySessionEndReason?.isNormalCompletion == true
    }

    var shouldConfirmNextSet: Bool {
        mode == .pomodoro && phase == .awaitingNextSet && currentSet < totalSets
    }

    var locksMainTabNavigation: Bool {
        phase == .study && (state == .running || state == .paused)
    }

    /// 端末の自動ロックを止める必要があるのは、実際にrunning中のstudyだけ。
    /// app lifecycleとPreview除外は、UIApplicationへ反映するMainTab側で加味する。
    var requiresIdleTimerDisabled: Bool {
        phase == .study && state == .running
    }

    var elapsedStudySeconds: Int {
        guard isStudyTime else { return 0 }
        if mode == .stopwatch {
            return stopwatchElapsedSeconds
        }
        return max(0, studyTime * 60 - timeRemaining)
    }

    var elapsedStudyMinutes: Int {
        elapsedStudySeconds / 60
    }

    var displayedSeconds: Int {
        isStudyTime && mode == .stopwatch ? stopwatchElapsedSeconds : timeRemaining
    }

    var canConfigureSession: Bool {
        (phase == .study || phase == .finished) &&
            (state == .idle || state == .completed)
    }

    /// 開始前の設定変更を現在の表示へ反映する。実行中・一時停止中のセッションは変更しない。
    func updateConfiguration(studyTime: Int, breakTime: Int, totalSets: Int? = nil) {
        guard canConfigureSession else { return }
        self.studyTime = studyTime
        self.breakTime = breakTime
        if let totalSets {
            self.totalSets = max(totalSets, 1)
        }
        currentSet = 1
        phase = .study
        timeRemaining = studyTime * 60
    }

    func selectMode(_ newMode: TimerMode) {
        guard canConfigureSession else { return }
        mode = newMode
        stopwatchElapsedSeconds = 0
        stopwatchElapsedAtRunStart = 0
        stopwatchRunStartDate = nil
        currentSet = 1
        phase = .study
        timeRemaining = studyTime * 60
    }

    func selectCategory(_ categoryID: String) {
        guard canConfigureSession, !categoryID.isEmpty else { return }
        selectedCategoryID = categoryID
    }
    
    convenience init(
        studyTime: Int,
        breakTime: Int,
        totalSets: Int = 3,
        now: @escaping () -> Date = Date.init,
        sessionStore: TimerSessionStore = .shared
    ) {
        self.init(
            studyTime: studyTime,
            breakTime: breakTime,
            totalSets: totalSets,
            now: now,
            sessionStore: sessionStore,
            notificationService: NotificationService.appDefault
        )
    }

    init(
        studyTime: Int,
        breakTime: Int,
        totalSets: Int = 3,
        now: @escaping () -> Date,
        sessionStore: TimerSessionStore,
        notificationService: TimerNotificationScheduling
    ) {
        self.studyTime = studyTime
        self.breakTime = breakTime
        self.totalSets = max(totalSets, 1)
        self.now = now
        self.sessionStore = sessionStore
        self.notificationService = notificationService
        timeRemaining = studyTime * 60
    }
    
    func startStopTimer() {
        if isRunning {
            pauseTimer()
        } else {
            resumeTimer()
        }
    }

    func pauseTimer() {
        guard isRunning else { return }
        synchronizeTime()

        // 同期時に終了した場合は、既に次のセッションへ切り替わっている。
        guard isRunning else { return }

        if mode != .stopwatch {
            notificationService.cancelCurrentSessionNotification()
        }
        notificationService.cancelBackgroundLimitNotifications(
            for: backgroundNotificationSessionIdentifier
        )
        backgroundEnteredAt = nil
        state = .paused
        endDate = nil
        if mode == .stopwatch && isStudyTime {
            stopwatchElapsedAtRunStart = stopwatchElapsedSeconds
            stopwatchRunStartDate = nil
        }
        persistSession(at: now())
    }

    func resumeTimer() {
        guard state != .running else { return }
        guard phase != .awaitingNextSet else { return }
        if phase == .finished {
            currentSet = 1
            phase = .study
            state = .idle
            timeRemaining = studyTime * 60
            lastStudySessionEndReason = nil
            lastBackgroundDuration = nil
            didExceedBackgroundLimit = false
            shouldPresentBackgroundFailureAlert = false
        }
        hasHandledCurrentSessionCompletion = false
        let currentDate = now()
        if isStudyTime, backgroundNotificationSessionIdentifier == nil {
            backgroundNotificationSessionIdentifier = UUID().uuidString
            didExceedBackgroundLimit = false
        }
        if mode == .stopwatch && isStudyTime {
            stopwatchElapsedAtRunStart = stopwatchElapsedSeconds
            stopwatchRunStartDate = currentDate
            endDate = nil
        } else {
            endDate = currentDate.addingTimeInterval(TimeInterval(timeRemaining))
        }
        state = .running
        scheduleCurrentSessionNotificationIfNeeded()
        persistSession(at: currentDate)
    }

    /// Core Tutorial専用。通常sessionをrunningへせず、疑似study完了を一度だけ通知する。
    /// 通常設定を変えず、通知をscheduleせず、pause/stop可能な中間状態を作らない。
    @discardableResult
    func completeCoreTutorialStudyWithoutStartingSession() -> Bool {
        guard state == .idle,
              phase == .study,
              !hasHandledCurrentSessionCompletion else { return false }
        selectedCategoryID = FocusCategoryDefaults.studyID
        finishCurrentSession(
            completedStudyMinutes: FishRewardService.minimumStudyMinutes,
            studyEndReason: .completed,
            forceFinishPomodoro: true
        )
        return true
    }

    func beginPomodoroBreak() {
        guard shouldBeginPomodoroBreak else { return }
        if timeRemaining <= 0 {
            hasHandledCurrentSessionCompletion = false
            finishCurrentSession()
            return
        }
        resumeTimer()
    }

    /// 休憩終了確認後、次セットを開始前のstudy状態へ進める。
    @discardableResult
    func prepareNextSet() -> Bool {
        guard shouldConfirmNextSet else { return false }
        currentSet += 1
        phase = .study
        state = .idle
        timeRemaining = studyTime * 60
        endDate = nil
        hasHandledCurrentSessionCompletion = false
        lastStudySessionEndReason = nil
        notificationService.cancelCurrentSessionNotification()
        notificationService.cancelBackgroundLimitNotifications(
            for: backgroundNotificationSessionIdentifier
        )
        backgroundNotificationSessionIdentifier = nil
        sessionStore.clearSession()
        return true
    }

    /// 休憩終了確認から次セットを1回だけ進め、既存の開始処理で直ちにstudyを開始する。
    @discardableResult
    func startNextSet() -> Bool {
        guard prepareNextSet() else { return false }
        resumeTimer()
        return true
    }

    /// 既に完了したstudy報酬を維持したまま、残りセットを行わず終了する。
    func finishPomodoroSessionAfterBreak() {
        guard phase == .awaitingNextSet else { return }
        phase = .finished
        state = .completed
        timeRemaining = studyTime * 60
        endDate = nil
        hasHandledCurrentSessionCompletion = true
        notificationService.cancelCurrentSessionNotification()
        notificationService.cancelBackgroundLimitNotifications(
            for: backgroundNotificationSessionIdentifier
        )
        backgroundNotificationSessionIdentifier = nil
        sessionStore.clearSession()
    }

    /// 許可ダイアログの完了後などに、現在の終了予定時刻へ通知を合わせ直す。
    func rescheduleCurrentSessionNotification() {
        guard isRunning else { return }
        scheduleCurrentSessionNotificationIfNeeded()
    }

    @discardableResult
    func endCurrentStudySession() -> Bool {
        guard isStudyTime else { return false }
        return endCurrentSession()
    }

    /// 一時停止中の勉強・休憩を、ユーザー操作で現在位置までとして終了する。
    @discardableResult
    func endCurrentSession() -> Bool {
        guard state == .paused, !hasHandledCurrentSessionCompletion else {
            return false
        }
        finishCurrentSession(
            completedStudyMinutes: isStudyTime ? elapsedStudyMinutes : nil,
            studyEndReason: .userEnded
        )
        return true
    }
    
    func resetTimer() {
        state = .idle
        phase = .study
        currentSet = 1
        timeRemaining = studyTime * 60
        endDate = nil
        hasHandledCurrentSessionCompletion = false
        lastHeartbeatDate = nil
        backgroundEnteredAt = nil
        lastBackgroundDuration = nil
        didExceedBackgroundLimit = false
        shouldPresentBackgroundFailureAlert = false
        stopwatchElapsedSeconds = 0
        stopwatchElapsedAtRunStart = 0
        stopwatchRunStartDate = nil
        lastStudySessionEndReason = nil
        notificationService.cancelCurrentSessionNotification()
        notificationService.cancelBackgroundLimitNotifications(
            for: backgroundNotificationSessionIdentifier
        )
        backgroundNotificationSessionIdentifier = nil
        sessionStore.clearSession()
    }
    
    func tick() {
        synchronizeTime()
        updateHeartbeatIfNeeded()
    }

    /// backgroundへ入った時刻と、その時点までの経過時間を保存する。
    /// running中のstudyでは、最初のbackground遷移時刻も保持する。
    func recordLastActiveTime() {
        guard sessionStore.load()?.sessionIsActive == true else { return }
        synchronizeTime()
        guard state == .running || state == .paused else { return }
        let currentDate = now()
        if state == .running, isStudyTime {
            if backgroundEnteredAt == nil {
                backgroundEnteredAt = currentDate
            }
            if backgroundNotificationSessionIdentifier == nil {
                backgroundNotificationSessionIdentifier = UUID().uuidString
            }
            didExceedBackgroundLimit = false
            if let backgroundEnteredAt, let backgroundNotificationSessionIdentifier {
                let warningDate = backgroundEnteredAt.addingTimeInterval(
                    BackgroundStudyLimit.warningInterval
                )
                let failureDate = backgroundEnteredAt.addingTimeInterval(
                    BackgroundStudyLimit.failureInterval
                )
                let normalEndDate = mode == .stopwatch ? nil : endDate
                let warningAt: Date?
                let failureAt: Date?
                if let normalEndDate {
                    warningAt = warningDate < normalEndDate ? warningDate : nil
                    failureAt = failureDate <= normalEndDate ? failureDate : nil
                } else {
                    warningAt = warningDate
                    failureAt = failureDate
                }

                // 5分離脱失敗が先に成立するsessionでは、後から通常終了通知を出さない。
                if failureAt != nil {
                    notificationService.cancelCurrentSessionNotification()
                }
                notificationService.scheduleBackgroundLimitNotifications(
                    warningAt: warningAt,
                    failureAt: failureAt,
                    sessionIdentifier: backgroundNotificationSessionIdentifier
                )
            }
        }
        persistSession(at: currentDate)
    }

    /// active復帰時に直前の離脱時間を確定し、永続セッションの開始時刻を消費する。
    @discardableResult
    func recordActiveReturn() -> TimeInterval? {
        let currentDate = now()
        let shouldFailSession = shouldFailForBackgroundLimit(at: currentDate)
        guard let duration = consumeBackgroundDuration(at: currentDate) else { return nil }

        notificationService.cancelBackgroundLimitNotifications(
            for: backgroundNotificationSessionIdentifier
        )

        if shouldFailSession {
            finishStudySessionForBackgroundLimit()
        } else if sessionStore.load()?.sessionIsActive == true,
           (state == .running || state == .paused) {
            if state == .running,
               endDate.map({ $0 > currentDate }) ?? true {
                scheduleCurrentSessionNotificationIfNeeded()
            }
            persistSession(at: currentDate)
        }
        return duration
    }

    func acknowledgeBackgroundFailure() {
        shouldPresentBackgroundFailureAlert = false
    }

    func restorePersistedSessionIfNeeded() {
        guard !hasAttemptedRestore else { return }
        hasAttemptedRestore = true

        let currentDate = now()
        switch sessionStore.launchStatus(at: currentDate) {
        case .sameProcess(let session), .recoverable(let session):
            restore(session, at: currentDate)
        case .interrupted(let session):
            finishInterruptedSession(session)
        case .none:
            break
        }
    }

    /// Timer.publishの受信回数ではなく、終了予定時刻との差から残り時間を補正する。
    func synchronizeTime() {
        guard isRunning else { return }

        let currentDate = now()
        if shouldFailForBackgroundLimit(at: currentDate) {
            _ = consumeBackgroundDuration(at: currentDate)
            finishStudySessionForBackgroundLimit()
            return
        }

        if mode == .stopwatch && isStudyTime {
            guard let stopwatchRunStartDate else { return }
            let currentRunSeconds = max(
                0,
                Int(currentDate.timeIntervalSince(stopwatchRunStartDate).rounded(.down))
            )
            stopwatchElapsedSeconds = stopwatchElapsedAtRunStart + currentRunSeconds
            return
        }

        guard let endDate else { return }

        let interval = endDate.timeIntervalSince(currentDate)
        guard interval > 0 else {
            finishCurrentSession(studyEndReason: .completed)
            return
        }

        timeRemaining = Int(ceil(interval))
    }

    private func restore(_ session: PersistedTimerSession, at currentDate: Date) {
        phase = session.isStudyTime ? .study : .breakTime
        totalSets = max(session.totalSets ?? totalSets, 1)
        currentSet = min(max(session.currentSet ?? 1, 1), totalSets)
        mode = TimerMode(rawValue: session.timerModeRawValue ?? "") ?? .pomodoro
        selectedCategoryID = FocusCategoryDefaults.resolvedCategoryID(session.selectedCategoryID)
        backgroundNotificationSessionIdentifier = session.backgroundNotificationSessionIdentifier
        state = session.isRunning ? .running : .paused
        timeRemaining = session.timeRemaining
        let savedElapsed = max(0, session.elapsedStudySeconds ?? 0)
        stopwatchElapsedSeconds = mode == .stopwatch ? savedElapsed : 0
        stopwatchElapsedAtRunStart = stopwatchElapsedSeconds
        stopwatchRunStartDate = nil
        endDate = session.isRunning && mode != .stopwatch ? session.endDate : nil
        lastHeartbeatDate = session.lastHeartbeatDate
        backgroundEnteredAt = session.backgroundEnteredAt
        hasHandledCurrentSessionCompletion = false
        let shouldFailSession = shouldFailForBackgroundLimit(at: currentDate)
        if consumeBackgroundDuration(at: currentDate) != nil {
            notificationService.cancelBackgroundLimitNotifications(
                for: backgroundNotificationSessionIdentifier
            )
        }

        if shouldFailSession {
            finishStudySessionForBackgroundLimit()
            return
        }

        if isRunning && mode == .stopwatch {
            let elapsedSinceHeartbeat = max(0, Int(currentDate.timeIntervalSince(session.lastHeartbeatDate).rounded(.down)))
            stopwatchElapsedSeconds += elapsedSinceHeartbeat
            stopwatchElapsedAtRunStart = stopwatchElapsedSeconds
            stopwatchRunStartDate = currentDate
        }

        if isRunning {
            synchronizeTime()
            if isRunning {
                scheduleCurrentSessionNotificationIfNeeded()
                // 復元した状態を現在のプロセス所有として直ちに保存する。
                persistSession(at: currentDate)
            }
        } else {
            persistSession(at: currentDate)
        }
    }

    /// 旧保存データなど、background突入時刻を持たない不整合sessionを報酬なしで破棄する。
    private func finishInterruptedSession(_ session: PersistedTimerSession) {
        notificationService.cancelCurrentSessionNotification()
        notificationService.cancelBackgroundLimitNotifications(
            for: session.backgroundNotificationSessionIdentifier
        )
        guard session.isStudyTime else {
            sessionStore.clearSession()
            return
        }

        phase = .finished
        totalSets = max(session.totalSets ?? totalSets, 1)
        currentSet = min(max(session.currentSet ?? 1, 1), totalSets)
        mode = TimerMode(rawValue: session.timerModeRawValue ?? "") ?? .pomodoro
        state = .completed
        timeRemaining = session.studyTime * 60
        endDate = nil
        lastHeartbeatDate = nil
        backgroundEnteredAt = nil
        lastBackgroundDuration = nil
        didExceedBackgroundLimit = false
        shouldPresentBackgroundFailureAlert = false
        lastCompletedStudyMinutes = 0
        lastStudySessionEndReason = .interrupted
        hasHandledCurrentSessionCompletion = true
        backgroundNotificationSessionIdentifier = nil
        stopwatchElapsedSeconds = 0
        stopwatchElapsedAtRunStart = 0
        stopwatchRunStartDate = nil
        sessionStore.clearSession()
    }

    private func updateHeartbeatIfNeeded() {
        guard sessionStore.load()?.sessionIsActive == true else { return }
        let currentDate = now()
        guard lastHeartbeatDate == nil ||
                currentDate.timeIntervalSince(lastHeartbeatDate!) >= TimerSessionStore.heartbeatInterval else {
            return
        }
        persistSession(at: currentDate)
    }

    private func persistSession(at date: Date) {
        guard isStudyTime else {
            lastHeartbeatDate = nil
            sessionStore.clearSession()
            return
        }

        lastHeartbeatDate = date
        sessionStore.save(sessionStore.makeSession(
            endDate: endDate,
            isStudyTime: isStudyTime,
            isRunning: isRunning,
            timeRemaining: timeRemaining,
            elapsedStudySeconds: elapsedStudySeconds,
            timerModeRawValue: mode.rawValue,
            selectedCategoryID: selectedCategoryID,
            backgroundNotificationSessionIdentifier: backgroundNotificationSessionIdentifier,
            lastHeartbeatDate: date,
            backgroundEnteredAt: backgroundEnteredAt,
            studyTime: studyTime,
            breakTime: breakTime,
            currentSet: currentSet,
            totalSets: totalSets
        ))
    }

    private func finishCurrentSession(
        completedStudyMinutes: Int? = nil,
        studyEndReason: StudySessionEndReason = .completed,
        forceFinishPomodoro: Bool = false
    ) {
        guard !hasHandledCurrentSessionCompletion else { return }
        hasHandledCurrentSessionCompletion = true
        state = .completed
        endDate = nil
        lastHeartbeatDate = nil
        backgroundEnteredAt = nil
        didExceedBackgroundLimit = false
        notificationService.cancelCurrentSessionNotification()
        notificationService.cancelBackgroundLimitNotifications(
            for: backgroundNotificationSessionIdentifier
        )
        backgroundNotificationSessionIdentifier = nil
        sessionStore.clearSession()

        let completedStudySession = phase == .study
        if completedStudySession {
            lastCompletedStudyMinutes = completedStudyMinutes ?? studyTime
            lastStudySessionEndReason = studyEndReason
            onStudyFinished?()
        }

        if completedStudySession &&
            !forceFinishPomodoro &&
            mode == .pomodoro &&
            studyEndReason.isNormalCompletion &&
            currentSet < totalSets {
            phase = .breakTime
            timeRemaining = breakTime * 60
        } else {
            phase = completedStudySession ? .finished : .awaitingNextSet
            timeRemaining = studyTime * 60
            if !completedStudySession {
                onBreakFinished?()
            }
        }
        stopwatchElapsedSeconds = 0
        stopwatchElapsedAtRunStart = 0
        stopwatchRunStartDate = nil
    }

    /// 通常の完了callbackを通さず、離脱超過したstudyを失敗として一度だけ破棄する。
    /// 記録・魚・ポイント・日次獲得数はすべてonStudyFinished側にあるため、ここでは更新しない。
    private func finishStudySessionForBackgroundLimit() {
        guard state == .running,
              phase == .study,
              !hasHandledCurrentSessionCompletion else { return }

        hasHandledCurrentSessionCompletion = true
        state = .completed
        phase = .finished
        timeRemaining = studyTime * 60
        endDate = nil
        lastHeartbeatDate = nil
        backgroundEnteredAt = nil
        lastCompletedStudyMinutes = 0
        lastStudySessionEndReason = .backgroundLimitExceeded
        shouldPresentBackgroundFailureAlert = true

        notificationService.cancelCurrentSessionNotification()
        notificationService.cancelBackgroundLimitNotifications(
            for: backgroundNotificationSessionIdentifier
        )
        backgroundNotificationSessionIdentifier = nil
        sessionStore.clearSession()

        didExceedBackgroundLimit = false
        stopwatchElapsedSeconds = 0
        stopwatchElapsedAtRunStart = 0
        stopwatchRunStartDate = nil
    }

    /// 5分離脱と通常終了予定のうち、先に成立する方を優先する。
    /// endDateより先に5分期限へ達するrunning studyだけを離脱失敗にする。
    private func shouldFailForBackgroundLimit(at currentDate: Date) -> Bool {
        guard state == .running,
              phase == .study,
              !hasHandledCurrentSessionCompletion,
              let backgroundEnteredAt else { return false }

        let failureDate = backgroundEnteredAt.addingTimeInterval(
            BackgroundStudyLimit.failureInterval
        )
        guard currentDate >= failureDate else { return false }

        if mode != .stopwatch,
           let endDate,
           endDate < failureDate {
            return false
        }
        return true
    }

    @discardableResult
    private func consumeBackgroundDuration(at currentDate: Date) -> TimeInterval? {
        guard let backgroundEnteredAt else { return nil }
        let duration = max(0, currentDate.timeIntervalSince(backgroundEnteredAt))
        self.backgroundEnteredAt = nil
        lastBackgroundDuration = duration
        didExceedBackgroundLimit = duration >= BackgroundStudyLimit.failureInterval
#if DEBUG
        print(String(format: "Background duration: %.1f seconds", duration))
        print("Background limit exceeded: \(didExceedBackgroundLimit)")
#endif
        return duration
    }

    private func scheduleCurrentSessionNotificationIfNeeded() {
        guard notificationService.notificationsEnabled,
              mode != .stopwatch,
              let endDate else { return }
        if isStudyTime {
            notificationService.scheduleStudyEnd(at: endDate)
        } else {
            notificationService.scheduleBreakEnd(at: endDate)
        }
    }
}
