//
//  TimerView.swift
//  PomodoroAquarium
//
//  Created by 阿部弦生 on 2026/07/13.
//

import SwiftUI
import Combine

struct TimerView: View {
    
    private let initialTime = 25 * 60
    
    @State private var viewModel = TimerViewModel()
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 30) {
            
            Text("🐠")
                .font(.system(size: 80))
            
            Text(formatTime(viewModel.timeRemaining))
                .font(.system(size: 60, weight: .bold))
            
            Text("勉強中")
                .font(.title2)
            
            Button(viewModel.isRunning ? "一時停止" : "勉強開始") {
                viewModel.isRunning.toggle()
            }
            .buttonStyle(.borderedProminent)
            
            Button("リセット") {
                viewModel.isRunning = false
                viewModel.timeRemaining = 25 * 60
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .navigationTitle("タイマー")
        .onReceive(timer) { _ in
            guard viewModel.isRunning else { return }
            
            if viewModel.timeRemaining > 0 {
                viewModel.timeRemaining -= 1
            } else {
                viewModel.isRunning = false
            }
        }
    }
}

func formatTime(_ seconds: Int) -> String {
    let minutes = seconds / 60
    let seconds = seconds % 60
    
    return String(format: "%02d:%02d", minutes, seconds)
}

#Preview {
    TimerView()
}
