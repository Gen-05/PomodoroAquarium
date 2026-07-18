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
    
    let initialTime = 25 * 60
    
    var timeRemaining = 25 * 60
    var isRunning = false
    
    
    func startStopTimer() {
        isRunning.toggle()
    }
    
    func resetTimer() {
        isRunning = false
        timeRemaining = initialTime
    }
    
    func tick() {
        guard isRunning else { return }
        
        if timeRemaining > 0 {
            timeRemaining -= 1
        } else {
            isRunning = false
        }
    }
}
