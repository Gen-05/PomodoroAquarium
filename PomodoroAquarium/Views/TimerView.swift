//
//  TimerView.swift
//  PomodoroAquarium
//
//  Created by 阿部弦生 on 2026/07/13.
//

import SwiftUI
import Combine
import SwiftData

struct TimerView: View {
    
    let studyTime: Int
    let breakTime: Int
    let player: Player?
    
    init(
        studyTime: Int,
        breakTime: Int,
        player: Player?
    ) {
        self.studyTime = studyTime
        self.breakTime = breakTime
        self.player = player
        
        let tempViewModel = TimerViewModel(
            studyTime: studyTime,
            breakTime: breakTime
        )
        
        tempViewModel.onStudyFinished = {
            if let player {
                player.todayStudyMinutes += studyTime
                player.totalStudyMinutes += studyTime
                FishRewardService.awardFish(for: studyTime, to: player)
            }
        }
        self._viewModel = State(initialValue: tempViewModel)
    }
    
    @State private var viewModel: TimerViewModel
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            AquariumView(player: player)

            VStack(spacing: 30) {
                Text(formatTime(viewModel.timeRemaining))
                    .font(.system(size: 60, weight: .bold))

                Text(viewModel.isStudyTime ? "📚 勉強時間" : "☕️ 休憩時間")
                    .font(.title2)

                Button(viewModel.isRunning ? "一時停止" : (viewModel.isStudyTime ? "勉強開始" : "休憩開始")) {
                    viewModel.startStopTimer()
                }
                .buttonStyle(.borderedProminent)

                Button("リセット") {
                    viewModel.resetTimer()
                }
                .buttonStyle(.bordered)
            }
            .padding(30)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
            .padding()
        }
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
    TimerView(
        studyTime: 25,
        breakTime: 5,
        player: nil
    )
}
