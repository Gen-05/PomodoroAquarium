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

@Observable
final class TimerViewModel {
    
    private let studyTime : Int
    private let breakTime : Int
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let sessionStore: TimerSessionStore

    private var hasHandledCurrentSessionCompletion = false
    private var hasAttemptedRestore = false
    private var lastHeartbeatDate: Date?
    
    var onStudyFinished: (() -> Void)?
    
    var timeRemaining: Int
    private(set) var state: TimerState = .idle
    var isRunning: Bool { state == .running }
    var isStudyTime = true
    private(set) var endDate: Date?
    private(set) var lastCompletedStudyMinutes = 0

    var elapsedStudySeconds: Int {
        guard isStudyTime else { return 0 }
        return max(0, studyTime * 60 - timeRemaining)
    }

    var elapsedStudyMinutes: Int {
        elapsedStudySeconds / 60
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
        persistSession(at: now())
    }

    func resumeTimer() {
        guard state != .running else { return }
        hasHandledCurrentSessionCompletion = false
        let currentDate = now()
        endDate = currentDate.addingTimeInterval(TimeInterval(timeRemaining))
        state = .running
        persistSession(at: currentDate)
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
        sessionStore.clearSession()
    }
    
    func tick() {
        synchronizeTime()
        updateHeartbeatIfNeeded()
    }

    func restorePersistedSessionIfNeeded() {
        guard !hasAttemptedRestore else { return }
        hasAttemptedRestore = true

        let currentDate = now()
        switch sessionStore.launchStatus(at: currentDate) {
        case .sameProcess(let session), .recoverable(let session):
            restore(session, at: currentDate)
        case .none, .interrupted:
            break
        }
    }

    /// Timer.publishの受信回数ではなく、終了予定時刻との差から残り時間を補正する。
    func synchronizeTime() {
        guard isRunning, let endDate else { return }

        let interval = endDate.timeIntervalSince(now())
        guard interval > 0 else {
            finishCurrentSession()
            return
        }

        timeRemaining = Int(ceil(interval))
    }

    private func restore(_ session: PersistedTimerSession, at currentDate: Date) {
        isStudyTime = session.isStudyTime
        state = session.isRunning ? .running : .paused
        timeRemaining = session.timeRemaining
        endDate = session.isRunning ? session.endDate : nil
        lastHeartbeatDate = session.lastHeartbeatDate
        hasHandledCurrentSessionCompletion = false

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
        lastHeartbeatDate = date
        sessionStore.save(sessionStore.makeSession(
            endDate: endDate,
            isStudyTime: isStudyTime,
            isRunning: isRunning,
            timeRemaining: timeRemaining,
            elapsedStudySeconds: elapsedStudySeconds,
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

        if isStudyTime {
            lastCompletedStudyMinutes = completedStudyMinutes ?? studyTime
            onStudyFinished?()
        }

        isStudyTime.toggle()
        timeRemaining = isStudyTime ? studyTime * 60 : breakTime * 60
    }
}
