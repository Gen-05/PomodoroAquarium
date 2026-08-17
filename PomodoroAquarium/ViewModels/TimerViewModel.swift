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

    private var hasHandledCurrentSessionCompletion = false
    
    var onStudyFinished: (() -> Void)?
    
    var timeRemaining: Int
    var isRunning = false
    var isStudyTime = true
    private(set) var endDate: Date?
    
    init(
        studyTime: Int,
        breakTime: Int,
        now: @escaping () -> Date = Date.init
    ) {
        self.studyTime = studyTime
        self.breakTime = breakTime
        self.now = now
        timeRemaining = studyTime * 60
    }
    
    func startStopTimer() {
        if isRunning {
            synchronizeTime()

            // 同期時に終了した場合は、既に次のセッションへ切り替わっている。
            guard isRunning else { return }

            isRunning = false
            endDate = nil
        } else {
            hasHandledCurrentSessionCompletion = false
            endDate = now().addingTimeInterval(TimeInterval(timeRemaining))
            isRunning = true
        }
    }
    
    func resetTimer() {
        isRunning = false
        isStudyTime = true
        timeRemaining = studyTime * 60
        endDate = nil
        hasHandledCurrentSessionCompletion = false
    }
    
    func tick() {
        synchronizeTime()
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

    private func finishCurrentSession() {
        guard !hasHandledCurrentSessionCompletion else { return }
        hasHandledCurrentSessionCompletion = true

        if isStudyTime {
            onStudyFinished?()
        }

        isStudyTime.toggle()
        timeRemaining = isStudyTime ? studyTime * 60 : breakTime * 60
        isRunning = false
        endDate = nil
    }
}
