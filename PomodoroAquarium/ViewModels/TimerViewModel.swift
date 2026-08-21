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

@Observable
final class TimerViewModel {
    
    private var studyTime: Int
    private var breakTime: Int
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let sessionStore: TimerSessionStore

    private var hasHandledCurrentSessionCompletion = false
    private var hasAttemptedRestore = false
    private var lastHeartbeatDate: Date?
    private var stopwatchRunStartDate: Date?
    private var stopwatchElapsedAtRunStart = 0
    
    var onStudyFinished: (() -> Void)?
    var onBreakFinished: (() -> Void)?
    
    var timeRemaining: Int
    private(set) var mode: TimerMode = .pomodoro
    private(set) var stopwatchElapsedSeconds = 0
    private(set) var state: TimerState = .idle
    var isRunning: Bool { state == .running }
    var isStudyTime = true
    private(set) var endDate: Date?
    private(set) var lastCompletedStudyMinutes = 0

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
        isStudyTime && (state == .idle || state == .completed)
    }

    /// 開始前の設定変更を現在の表示へ反映する。実行中・一時停止中のセッションは変更しない。
    func updateConfiguration(studyTime: Int, breakTime: Int) {
        guard canConfigureSession else { return }
        self.studyTime = studyTime
        self.breakTime = breakTime
        timeRemaining = studyTime * 60
    }

    func selectMode(_ newMode: TimerMode) {
        guard isStudyTime, state == .idle || state == .completed else { return }
        mode = newMode
        stopwatchElapsedSeconds = 0
        stopwatchElapsedAtRunStart = 0
        stopwatchRunStartDate = nil
        timeRemaining = studyTime * 60
    }
    
    init(
        studyTime: Int,
        breakTime: Int,
        now: @escaping () -> Date = Date.init,
        sessionStore: TimerSessionStore = .shared
    ) {
        self.studyTime = studyTime
        self.breakTime = breakTime
        self.now = now
        self.sessionStore = sessionStore
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
        hasHandledCurrentSessionCompletion = false
        let currentDate = now()
        if mode == .stopwatch && isStudyTime {
            stopwatchElapsedAtRunStart = stopwatchElapsedSeconds
            stopwatchRunStartDate = currentDate
            endDate = nil
        } else {
            endDate = currentDate.addingTimeInterval(TimeInterval(timeRemaining))
        }
        state = .running
        persistSession(at: currentDate)
    }

    func beginPomodoroBreak() {
        guard mode == .pomodoro, !isStudyTime, state == .completed else { return }
        resumeTimer()
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
        finishCurrentSession(completedStudyMinutes: isStudyTime ? elapsedStudyMinutes : nil)
        return true
    }
    
    func resetTimer() {
        state = .idle
        isStudyTime = true
        timeRemaining = studyTime * 60
        endDate = nil
        hasHandledCurrentSessionCompletion = false
        lastHeartbeatDate = nil
        stopwatchElapsedSeconds = 0
        stopwatchElapsedAtRunStart = 0
        stopwatchRunStartDate = nil
        sessionStore.clearSession()
    }
    
    func tick() {
        synchronizeTime()
        updateHeartbeatIfNeeded()
    }

    /// 非アクティブになる直前の時刻と、その時点までの経過時間を保存する。
    func recordLastActiveTime() {
        guard sessionStore.load()?.sessionIsActive == true else { return }
        synchronizeTime()
        guard state == .running || state == .paused else { return }
        persistSession(at: now())
    }

    func restorePersistedSessionIfNeeded() {
        guard !hasAttemptedRestore else { return }
        hasAttemptedRestore = true

        let currentDate = now()
        switch sessionStore.launchStatus(at: currentDate) {
        case .sameProcess(let session), .recoverable(let session):
            restore(session, at: currentDate)
        case .expired(let session):
            finishExpiredSession(session)
        case .none:
            break
        }
    }

    /// Timer.publishの受信回数ではなく、終了予定時刻との差から残り時間を補正する。
    func synchronizeTime() {
        guard isRunning else { return }

        if mode == .stopwatch && isStudyTime {
            guard let stopwatchRunStartDate else { return }
            let currentRunSeconds = max(0, Int(now().timeIntervalSince(stopwatchRunStartDate).rounded(.down)))
            stopwatchElapsedSeconds = stopwatchElapsedAtRunStart + currentRunSeconds
            return
        }

        guard let endDate else { return }

        let interval = endDate.timeIntervalSince(now())
        guard interval > 0 else {
            finishCurrentSession()
            return
        }

        timeRemaining = Int(ceil(interval))
    }

    private func restore(_ session: PersistedTimerSession, at currentDate: Date) {
        isStudyTime = session.isStudyTime
        mode = TimerMode(rawValue: session.timerModeRawValue ?? "") ?? .pomodoro
        state = session.isRunning ? .running : .paused
        timeRemaining = session.timeRemaining
        let savedElapsed = max(0, session.elapsedStudySeconds ?? 0)
        stopwatchElapsedSeconds = mode == .stopwatch ? savedElapsed : 0
        stopwatchElapsedAtRunStart = stopwatchElapsedSeconds
        stopwatchRunStartDate = nil
        endDate = session.isRunning && mode != .stopwatch ? session.endDate : nil
        lastHeartbeatDate = session.lastHeartbeatDate
        hasHandledCurrentSessionCompletion = false

        if isRunning && mode == .stopwatch {
            let elapsedSinceHeartbeat = max(0, Int(currentDate.timeIntervalSince(session.lastHeartbeatDate).rounded(.down)))
            stopwatchElapsedSeconds += elapsedSinceHeartbeat
            stopwatchElapsedAtRunStart = stopwatchElapsedSeconds
            stopwatchRunStartDate = currentDate
        }

        if isRunning {
            synchronizeTime()
            if isRunning {
                // 復元した状態を現在のプロセス所有として直ちに保存する。
                persistSession(at: currentDate)
            }
        } else {
            persistSession(at: currentDate)
        }
    }

    private func finishExpiredSession(_ session: PersistedTimerSession) {
        guard session.isStudyTime else {
            sessionStore.clearSession()
            return
        }

        isStudyTime = session.isStudyTime
        mode = TimerMode(rawValue: session.timerModeRawValue ?? "") ?? .pomodoro
        state = .paused
        endDate = nil
        lastHeartbeatDate = session.lastHeartbeatDate
        hasHandledCurrentSessionCompletion = false

        let fallbackElapsed = max(0, session.studyTime * 60 - session.timeRemaining)
        let savedElapsed = max(0, session.elapsedStudySeconds ?? fallbackElapsed)
        let timeSinceLastActive = max(0, now().timeIntervalSince(session.lastHeartbeatDate))
        let allowedBackgroundTime = min(
            Int(timeSinceLastActive.rounded(.down)),
            Int(TimerSessionStore.gracePeriod)
        )
        let elapsedAtTermination = session.isRunning
            ? savedElapsed + allowedBackgroundTime
            : savedElapsed
        let creditedElapsed: Int
        if mode == .stopwatch {
            creditedElapsed = elapsedAtTermination
            stopwatchElapsedSeconds = creditedElapsed
            stopwatchElapsedAtRunStart = creditedElapsed
            stopwatchRunStartDate = nil
        } else {
            creditedElapsed = min(elapsedAtTermination, studyTime * 60)
            timeRemaining = max(0, studyTime * 60 - creditedElapsed)
        }

        _ = endCurrentSession()
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
            lastHeartbeatDate: date,
            studyTime: studyTime,
            breakTime: breakTime
        ))
    }

    private func finishCurrentSession(completedStudyMinutes: Int? = nil) {
        guard !hasHandledCurrentSessionCompletion else { return }
        hasHandledCurrentSessionCompletion = true
        state = .completed
        endDate = nil
        lastHeartbeatDate = nil
        sessionStore.clearSession()

        let completedStudySession = isStudyTime
        if completedStudySession {
            lastCompletedStudyMinutes = completedStudyMinutes ?? studyTime
            onStudyFinished?()
        }

        if completedStudySession && mode == .pomodoro {
            isStudyTime = false
            timeRemaining = breakTime * 60
        } else {
            isStudyTime = true
            timeRemaining = studyTime * 60
            if !completedStudySession {
                onBreakFinished?()
            }
        }
        stopwatchElapsedSeconds = 0
        stopwatchElapsedAtRunStart = 0
        stopwatchRunStartDate = nil
    }
}
