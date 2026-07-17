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
    
    var timeRemaining = 25 * 60
    var isRunning = false
}
