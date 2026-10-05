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

    var focusMethod: FocusMethod {
        switch self {
        case .pomodoro: .pomodoro
        case .countdown: .timer
        case .stopwatch: .stopwatch
        }
    }
}

enum StudySessionEndReason: String, Codable, Equatable {
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
    private var validFocusElapsed: TimeInterval = 0
    private var validFocusRunStartedAt: Date?
    private var focusSessionID: UUID?
    private(set) var lastValidFocusSeconds = 0
    private var configuredAutoStartNextSet = false
    private(set) var isAutomaticPomodoroFlow = false
    private(set) var pomodoroFlowID: UUID?
    private var autoFlowBackgroundEnteredAt: Date?
    private(set) var isTimerScreenVisible = false
    private(set) var isAppActive = false
    private var isRestoringSession = false
    private var automaticStudyEnvironmentReady: Bool {
        isAppActive && isTimerScreenVisible && !isRestoringSession
    }
    var awaitsAutomaticStudyStart: Bool {
        isAutomaticPomodoroFlow && phase == .awaitingNextSet && currentSet < totalSets
    }
    var canAutoStartNextStudy: Bool {
        awaitsAutomaticStudyStart && automaticStudyEnvironmentReady && !isRunning
    }
    var defersPomodoroRewards: Bool { isAutomaticPomodoroFlow && phase != .finished }
    var hasPersistedAutomaticPomodoroFlow: Bool { sessionStore.load()?.autoStartNextSet == true }
    var onPomodoroFlowFinished: (() -> Void)?

    func configureAutoStartNextSet(_ enabled: Bool) {
        guard canConfigureSession else { return }
        configuredAutoStartNextSet = enabled
    }

    func setAppActive(_ active: Bool) {
        // activeにする前に、inactive中に過ぎたbreakだけを確定する。
        if active, isAutomaticPomodoroFlow { synchronizeTime() }
        let changed = isAppActive != active
        isAppActive = active
        if !active, isAutomaticPomodoroFlow { synchronizeTime() }
        if active { resumeAutomaticStudyIfReady() }
        if (changed || active), isAutomaticPomodoroFlow, phase == .breakTime, isRunning {
            scheduleCurrentSessionNotificationIfNeeded()
        }
        if isAutomaticPomodoroFlow && (isRunning || state == .paused || awaitsAutomaticStudyStart) {
            persistSession(at: now())
        }
    }

    /// Navigationの表示状態だけ。app backgroundはこの値を変更しない。
    func setTimerScreenVisible(_ visible: Bool) {
        if visible {
            // 画面外で過ぎたbreakを、画面外の状態のまま先に終了させる。
            synchronizeTime()
        }
        let changed = isTimerScreenVisible != visible
        isTimerScreenVisible = visible
        if !visible { synchronizeTime() }
        if visible { resumeAutomaticStudyIfReady() }
        if changed, isAutomaticPomodoroFlow, phase == .breakTime, isRunning {
            scheduleCurrentSessionNotificationIfNeeded()
        }
        if isAutomaticPomodoroFlow && (isRunning || state == .paused || awaitsAutomaticStudyStart) {
            persistSession(at: now())
        }
    }

    /// phaseを同期的に消費するため、onAppear/activeが重なっても1回だけ開始する。
    @discardableResult
    func resumeAutomaticStudyIfReady() -> Bool {
        startPendingAutomaticStudy(at: now())
    }

    private func startPendingAutomaticStudy(at date: Date) -> Bool {
        guard canAutoStartNextStudy, prepareNextSet() else { return false }
        autoFlowBackgroundEnteredAt = nil
        resumeTimer(at: date)
        return true
    }
    
    var onStudyFinished: (() -> Void)?
    var onBreakFinished: (() -> Void)?
    /// 記録専用。trueは永続保存済みを意味する。報酬callbackは従来の終了条件を維持。
    var onFocusSessionFinalized: ((FinalizedFocusSession) -> Bool)?

    var validFocusSeconds: Int { Int(validFocusDuration(at: now()).rounded(.down)) }
    
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
        canPrepareNextSet && !isAutomaticPomodoroFlow
    }

    private var canPrepareNextSet: Bool {
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
        let previousPhase = phase
        let previousSet = currentSet
        synchronizeTime()

        // 同期時に終了した場合は、既に次のセッションへ切り替わっている。
        guard isRunning, phase == previousPhase, currentSet == previousSet else { return }

        if phase == .study {
            validFocusElapsed = validFocusDuration(at: now())
            validFocusRunStartedAt = nil
        }
        if mode != .stopwatch {
            notificationService.cancelCurrentSessionNotification()
        }
        notificationService.cancelBackgroundLimitNotifications(
            for: backgroundNotificationSessionIdentifier
        )
        backgroundEnteredAt = nil
        autoFlowBackgroundEnteredAt = nil
        state = .paused
        endDate = nil
        if mode == .stopwatch && isStudyTime {
            stopwatchElapsedAtRunStart = stopwatchElapsedSeconds
            stopwatchRunStartDate = nil
        }
        persistSession(at: now())
    }

    func resumeTimer() {
        resumeTimer(at: now())
    }

    private func resumeTimer(at currentDate: Date) {
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
        if phase == .study, state == .idle, currentSet == 1 {
            isAutomaticPomodoroFlow = mode == .pomodoro && configuredAutoStartNextSet
            pomodoroFlowID = isAutomaticPomodoroFlow ? UUID() : nil
        }
        hasHandledCurrentSessionCompletion = false
        if phase == .study {
            if state == .idle {
                validFocusElapsed = 0
                focusSessionID = UUID()
                lastValidFocusSeconds = 0
            }
            validFocusRunStartedAt = currentDate
        }
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
        if isAutomaticPomodoroFlow, phase == .study, let absence = autoFlowBackgroundEnteredAt {
            backgroundEnteredAt = max(absence, currentDate)
        }
        scheduleCurrentSessionNotificationIfNeeded()
        if backgroundEnteredAt != nil { scheduleBackgroundLimitNotifications() }
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
        isAutomaticPomodoroFlow = false
        pomodoroFlowID = nil
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

    /// running中の休憩だけを短縮する。自動設定OFFなら従来の次セット確認待ち。
    @discardableResult
    func endPomodoroBreak() -> Bool {
        guard mode == .pomodoro, phase == .breakTime, isRunning else { return false }
        pauseTimer()
        // pause時の時刻同期で自然終了した場合は、重ねて終了しない。
        if phase != .breakTime { return true }
        return endCurrentSession()
    }

    /// 休憩終了確認後、次セットを開始前のstudy状態へ進める。
    @discardableResult
    func prepareNextSet() -> Bool {
        guard canPrepareNextSet else { return false }
        currentSet += 1
        phase = .study
        state = .idle
        validFocusElapsed = 0
        validFocusRunStartedAt = nil
        focusSessionID = nil
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
        isAutomaticPomodoroFlow = false
        pomodoroFlowID = nil
        autoFlowBackgroundEnteredAt = nil
        validFocusElapsed = 0
        validFocusRunStartedAt = nil
        focusSessionID = nil
        lastValidFocusSeconds = 0
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

    /// 終了結果の表示が済んだ時だけ、共有modelを次の開始前状態へ戻す。
    /// 設定・カテゴリ・報酬保存には触れず、実行中/休憩待ちのflowは破棄しない。
    @discardableResult
    func finishCompletedSessionPresentation() -> Bool {
        guard phase == .finished, state == .completed else { return false }
        resetTimer()
        lastCompletedStudyMinutes = 0
        onPomodoroFlowFinished = nil
        onStudyFinished = nil
        onBreakFinished = nil
        onFocusSessionFinalized = nil
        return true
    }
    
    func tick() {
        synchronizeTime()
        updateHeartbeatIfNeeded()
    }

    /// backgroundへ入った時刻と、その時点までの経過時間を保存する。
    /// running中のstudyでは、最初のbackground遷移時刻も保持する。
    func recordLastActiveTime() {
        setAppActive(false)
        guard sessionStore.load()?.sessionIsActive == true else { return }
        synchronizeTime()
        guard state == .running || state == .paused else { return }
        let currentDate = now()
        if isAutomaticPomodoroFlow, isRunning, autoFlowBackgroundEnteredAt == nil {
            autoFlowBackgroundEnteredAt = currentDate
        }
        if state == .running, isStudyTime {
            if backgroundEnteredAt == nil {
                backgroundEnteredAt = currentDate
            }
            if backgroundNotificationSessionIdentifier == nil {
                backgroundNotificationSessionIdentifier = UUID().uuidString
            }
            didExceedBackgroundLimit = false
            scheduleBackgroundLimitNotifications()
        }
        persistSession(at: currentDate)
    }

    private func scheduleBackgroundLimitNotifications() {
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

    /// active復帰時に直前の離脱時間を確定し、永続セッションの開始時刻を消費する。
    @discardableResult
    func recordActiveReturn() -> TimeInterval? {
        defer { setAppActive(true) }
        // inactive中のdeadlineを先に確定し、break後のstudyはactive確認まで保留。
        // すでにrunning中のstudyには従来の5分ルールを適用する。
        if isAutomaticPomodoroFlow { synchronizeTime() }
        autoFlowBackgroundEnteredAt = nil
        let currentDate = now()
        let shouldFailSession = shouldFailForBackgroundLimit(at: currentDate)
        let failureFocusEnd = backgroundEnteredAt
        guard let duration = consumeBackgroundDuration(at: currentDate) else {
            if isAutomaticPomodoroFlow && (state == .running || state == .paused) {
                persistSession(at: currentDate)
            }
            return nil
        }

        notificationService.cancelBackgroundLimitNotifications(
            for: backgroundNotificationSessionIdentifier
        )

        if shouldFailSession {
            finishStudySessionForBackgroundLimit(focusEndedAt: failureFocusEnd ?? currentDate)
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
        deliverPendingFocusSessions()
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
        // 自動flowだけは、background中に過ぎたphaseのdeadlineも順に解決する。
        // セット数は有限で、常時Timerや新しい計測方式を追加しない。
        var didTransition: Bool
        repeat {
            let previousPhase = phase
            let previousSet = currentSet
            synchronizeCurrentPhase()
            didTransition = phase != previousPhase || currentSet != previousSet
        } while isAutomaticPomodoroFlow && isRunning &&
            (didTransition || endDate.map({ $0 <= now() }) == true)
    }

    private func synchronizeCurrentPhase() {
        guard isRunning else { return }

        let currentDate = now()
        if shouldFailForBackgroundLimit(at: currentDate) {
            let failureFocusEnd = backgroundEnteredAt ?? currentDate
            _ = consumeBackgroundDuration(at: currentDate)
            finishStudySessionForBackgroundLimit(focusEndedAt: failureFocusEnd)
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
        // 保存時の画面位置や過去のdeadlineから、現在activeであるとは推測しない。
        isRestoringSession = true
        defer { isRestoringSession = false }
        studyTime = session.studyTime
        breakTime = session.breakTime
        phase = session.awaitsAutomaticStudyStart == true ? .awaitingNextSet
            : (session.isStudyTime ? .study : .breakTime)
        totalSets = max(session.totalSets ?? totalSets, 1)
        currentSet = min(max(session.currentSet ?? 1, 1), totalSets)
        mode = TimerMode(rawValue: session.timerModeRawValue ?? "") ?? .pomodoro
        isAutomaticPomodoroFlow = mode == .pomodoro && session.autoStartNextSet == true
        // 離脱前の画面位置だけを復元する。自動開始は現在のactive/表示確認後。
        isTimerScreenVisible = session.isTimerScreenVisible ?? true
        pomodoroFlowID = session.pomodoroFlowID
        autoFlowBackgroundEnteredAt = session.autoFlowBackgroundEnteredAt ?? session.backgroundEnteredAt
        selectedCategoryID = FocusCategoryDefaults.resolvedCategoryID(session.selectedCategoryID)
        backgroundNotificationSessionIdentifier = session.backgroundNotificationSessionIdentifier
        state = session.awaitsAutomaticStudyStart == true ? .completed
            : (session.isRunning ? .running : .paused)
        timeRemaining = session.timeRemaining
        let savedElapsed = max(0, session.elapsedStudySeconds ?? 0)
        validFocusElapsed = max(0, session.validFocusElapsed ?? TimeInterval(
            session.elapsedStudySeconds ?? max(0, session.studyTime * 60 - session.timeRemaining)
        ))
        validFocusRunStartedAt = session.isRunning && phase == .study
            ? (session.validFocusUpdatedAt ?? session.lastHeartbeatDate) : nil
        focusSessionID = session.focusSessionID ?? UUID()
        stopwatchElapsedSeconds = mode == .stopwatch ? savedElapsed : 0
        stopwatchElapsedAtRunStart = stopwatchElapsedSeconds
        stopwatchRunStartDate = nil
        endDate = session.isRunning && mode != .stopwatch ? session.endDate : nil
        lastHeartbeatDate = session.lastHeartbeatDate
        backgroundEnteredAt = session.backgroundEnteredAt
        hasHandledCurrentSessionCompletion = false
        let shouldFailSession = shouldFailForBackgroundLimit(at: currentDate)
        let failureFocusEnd = backgroundEnteredAt
        if !isAutomaticPomodoroFlow && consumeBackgroundDuration(at: currentDate) != nil {
            notificationService.cancelBackgroundLimitNotifications(
                for: backgroundNotificationSessionIdentifier
            )
        }

        if shouldFailSession {
            finishStudySessionForBackgroundLimit(focusEndedAt: failureFocusEnd ?? currentDate)
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
            if isAutomaticPomodoroFlow {
                _ = consumeBackgroundDuration(at: currentDate)
                autoFlowBackgroundEnteredAt = nil
                notificationService.cancelBackgroundLimitNotifications(for: backgroundNotificationSessionIdentifier)
            }
            if isRunning {
                scheduleCurrentSessionNotificationIfNeeded()
                // 復元した状態を現在のプロセス所有として直ちに保存する。
                persistSession(at: currentDate)
            }
        } else {
            autoFlowBackgroundEnteredAt = nil
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

        studyTime = session.studyTime
        breakTime = session.breakTime
        phase = .finished
        totalSets = max(session.totalSets ?? totalSets, 1)
        currentSet = min(max(session.currentSet ?? 1, 1), totalSets)
        mode = TimerMode(rawValue: session.timerModeRawValue ?? "") ?? .pomodoro
        isAutomaticPomodoroFlow = mode == .pomodoro && session.autoStartNextSet == true
        pomodoroFlowID = session.pomodoroFlowID
        selectedCategoryID = FocusCategoryDefaults.resolvedCategoryID(session.selectedCategoryID)
        focusSessionID = session.focusSessionID ?? UUID()
        // 不明な再起動後の時間は推測せず、最後に保存された有効時間だけを保持する。
        validFocusElapsed = max(0, session.validFocusElapsed ?? TimeInterval(
            session.elapsedStudySeconds ?? max(0, session.studyTime * 60 - session.timeRemaining)
        ))
        validFocusRunStartedAt = nil
        finalizeFocusSession(at: session.lastHeartbeatDate, reason: .interrupted)
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
        if isAutomaticPomodoroFlow { onPomodoroFlowFinished?() }
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
        guard isStudyTime || isAutomaticPomodoroFlow else {
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
            totalSets: totalSets,
            validFocusElapsed: validFocusDuration(at: date),
            validFocusUpdatedAt: isRunning ? date : nil,
            focusSessionID: focusSessionID,
            autoStartNextSet: isAutomaticPomodoroFlow,
            pomodoroFlowID: pomodoroFlowID,
            autoFlowBackgroundEnteredAt: autoFlowBackgroundEnteredAt,
            isTimerScreenVisible: isTimerScreenVisible,
            awaitsAutomaticStudyStart: awaitsAutomaticStudyStart
        ))
    }

    private func finishCurrentSession(
        completedStudyMinutes: Int? = nil,
        studyEndReason: StudySessionEndReason = .completed,
        forceFinishPomodoro: Bool = false
    ) {
        guard !hasHandledCurrentSessionCompletion else { return }
        let transitionDate = studyEndReason == .completed ? (endDate ?? now()) : now()
        let waitsOutsideTimer = isAutomaticPomodoroFlow && phase == .breakTime && !automaticStudyEnvironmentReady
        hasHandledCurrentSessionCompletion = true
        if phase == .study {
            if forceFinishPomodoro {
                // Tutorialは既存の疑似報酬・履歴経路だけを使う。
                lastValidFocusSeconds = (completedStudyMinutes ?? studyTime) * 60
            } else {
                let completionDate = studyEndReason == .completed ? (endDate ?? now()) : now()
                finalizeFocusSession(at: completionDate, reason: studyEndReason)
            }
        }
        state = .completed
        endDate = nil
        lastHeartbeatDate = nil
        backgroundEnteredAt = nil
        didExceedBackgroundLimit = false
        // 画面外のbreak完了では、予約済みの「戻ると開始」通知を消さない。
        if !waitsOutsideTimer { notificationService.cancelCurrentSessionNotification() }
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
        if isAutomaticPomodoroFlow && !forceFinishPomodoro {
            switch phase {
            case .breakTime:
                if timeRemaining <= 0 {
                    phase = .awaitingNextSet
                    onBreakFinished?()
                    advanceAutomaticStudy(after: transitionDate)
                } else {
                    resumeTimer(at: transitionDate)
                }
            case .awaitingNextSet:
                advanceAutomaticStudy(after: transitionDate)
            case .finished:
                autoFlowBackgroundEnteredAt = nil
                onPomodoroFlowFinished?()
            case .study: break
            }
        }
    }

    private func advanceAutomaticStudy(after transitionDate: Date) {
        if !startPendingAutomaticStudy(at: transitionDate) {
            // セット位置・flow ID・報酬はそのまま保持。集中計測はまだ開始しない。
            autoFlowBackgroundEnteredAt = nil
            persistSession(at: now())
        }
    }

    /// 報酬callbackは通さず、最後の離脱を除外した記録だけを確定する。
    private func finishStudySessionForBackgroundLimit(focusEndedAt: Date) {
        guard state == .running,
              phase == .study,
              !hasHandledCurrentSessionCompletion else { return }

        hasHandledCurrentSessionCompletion = true
        finalizeFocusSession(
            at: focusEndedAt.addingTimeInterval(BackgroundStudyLimit.failureInterval),
            reason: .backgroundLimitExceeded,
            focusEndedAt: focusEndedAt
        )
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
        autoFlowBackgroundEnteredAt = nil
        if isAutomaticPomodoroFlow { onPomodoroFlowFinished?() }
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
        if mode == .pomodoro {
            let message: PomodoroEndNotification
            if phase == .study {
                message = isAutomaticPomodoroFlow && currentSet < totalSets
                    ? .studyStartsBreak : .studyCompleted
            } else {
                message = !isAutomaticPomodoroFlow ? .breakCompleted
                    : (automaticStudyEnvironmentReady ? .breakStartsStudy : .breakAwaitsTimerScreen)
            }
            notificationService.schedulePomodoroEnd(at: endDate, message: message)
        } else if isStudyTime {
            notificationService.scheduleStudyEnd(at: endDate)
        } else {
            notificationService.scheduleBreakEnd(at: endDate)
        }
    }

    private func validFocusDuration(at date: Date) -> TimeInterval {
        var seconds = validFocusElapsed
        if let validFocusRunStartedAt {
            // 復元後にbackgroundEnteredAtまで巻き戻す場合は保存後の離脱秒を差し引く。
            seconds += date.timeIntervalSince(validFocusRunStartedAt)
        }
        return max(0, seconds)
    }

    private func finalizeFocusSession(
        at completedAt: Date,
        reason: StudySessionEndReason,
        focusEndedAt: Date? = nil
    ) {
        lastValidFocusSeconds = Int(validFocusDuration(at: focusEndedAt ?? completedAt).rounded(.down))
        validFocusElapsed = TimeInterval(lastValidFocusSeconds)
        validFocusRunStartedAt = nil
        guard lastValidFocusSeconds > 0 else { return }
        sessionStore.enqueueFocusSession(FinalizedFocusSession(
            id: focusSessionID ?? UUID(),
            completedAt: completedAt,
            validFocusSeconds: lastValidFocusSeconds,
            endReason: reason,
            categoryID: selectedCategoryID,
            focusMethod: mode.focusMethod,
            pomodoroFlowID: pomodoroFlowID
        ))
        deliverPendingFocusSessions()
    }

    private func deliverPendingFocusSessions() {
        guard let onFocusSessionFinalized else { return }
        for result in sessionStore.pendingFocusSessions() {
            if onFocusSessionFinalized(result) {
                sessionStore.acknowledgeFocusSession(id: result.id)
            }
        }
    }
}
