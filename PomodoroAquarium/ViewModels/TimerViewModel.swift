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
    
    private let studyTime = 10
    private let breakTime = 5
    
    
    var timeRemaining: Int
    var isRunning = false
    var isStudyTime = true
    
    init() {
        timeRemaining = studyTime
    }
    
    func startStopTimer() {
        isRunning.toggle()
    }
    
    func resetTimer() {
        isRunning = false
        isStudyTime = true
        timeRemaining = isStudyTime ? studyTime : breakTime
    }
    
    func tick() {
        guard isRunning else { return }
        
        if timeRemaining > 0 {
            timeRemaining -= 1
        } else {
            isStudyTime.toggle()
            
            timeRemaining = isStudyTime ? studyTime : breakTime
            
            isRunning = false
        }
    }
}
