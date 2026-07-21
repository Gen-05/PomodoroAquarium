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
    
    
    var timeRemaining: Int
    var isRunning = false
    var isStudyTime = true
    
    init(studyTime: Int, breakTime: Int) {
        self.studyTime = studyTime
        self.breakTime = breakTime
        timeRemaining = studyTime * 60
    }
    
    func startStopTimer() {
        isRunning.toggle()
    }
    
    func resetTimer() {
        isRunning = false
        isStudyTime = true
        timeRemaining = isStudyTime ? studyTime * 60 : breakTime * 60
    }
    
    func tick() {
        guard isRunning else { return }
        
        if timeRemaining > 0 {
            timeRemaining -= 1
        } else {
            isStudyTime.toggle()
            
            timeRemaining = isStudyTime ? studyTime * 60 : breakTime * 60
            
            isRunning = false
        }
    }
}
