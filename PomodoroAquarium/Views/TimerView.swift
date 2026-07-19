//
//  TimerView.swift
//  PomodoroAquarium
//
//  Created by 阿部弦生 on 2026/07/13.
//

import SwiftUI
import Combine

struct TimerView: View {
    
    @State private var viewModel = TimerViewModel()
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 30) {
            
            Text("🐠")
                .font(.system(size: 80))
            
            Text(formatTime(viewModel.timeRemaining))
                .font(.system(size: 60, weight: .bold))
            
            Text(viewModel.isStudyTime ? "📚 勉強時間" : "☕️ 休憩時間")
                .font(.title2)
            
            Button(viewModel.isRunning ? "一時停止" : "勉強開始") {
                viewModel.startStopTimer()
            }
            .buttonStyle(.borderedProminent)
            
            Button("リセット") {
                viewModel.resetTimer()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .navigationTitle("タイマー")
        .onReceive(timer) { _ in
            viewModel.tick()
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
