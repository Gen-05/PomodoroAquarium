//
//  TimerViewModel.swift
//  PomodoroAquarium
//
//  Created by 阿部弦生 on 2026/07/17.
//

import Foundation
import Observation

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
    var isRunning = false
    var isStudyTime = true
    private(set) var endDate: Date?
    
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
            synchronizeTime()

            // 同期時に終了した場合は、既に次のセッションへ切り替わっている。
            guard isRunning else { return }

            isRunning = false
            endDate = nil
            persistSession(at: now())
        } else {
            hasHandledCurrentSessionCompletion = false
            let currentDate = now()
            endDate = currentDate.addingTimeInterval(TimeInterval(timeRemaining))
            isRunning = true
            persistSession(at: currentDate)
        }
    }
    
    func resetTimer() {
        isRunning = false
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
        isRunning = session.isRunning
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
            lastHeartbeatDate: date,
            studyTime: studyTime,
            breakTime: breakTime
        ))
    }

    private func finishCurrentSession() {
        guard !hasHandledCurrentSessionCompletion else { return }
        hasHandledCurrentSessionCompletion = true
        isRunning = false
        endDate = nil
        lastHeartbeatDate = nil
        sessionStore.clearSession()

        if isStudyTime {
            onStudyFinished?()
        }

        isStudyTime.toggle()
        timeRemaining = isStudyTime ? studyTime * 60 : breakTime * 60
    }
}
