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

    @AppStorage(AquariumThemeStore.storageKey)
    private var backgroundThemeRawValue = AquariumBackgroundTheme.aquarium.rawValue

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    
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
        self._viewModel = State(initialValue: tempViewModel)
        self._awardedFish = State(initialValue: nil)
        self._pendingAwardedFish = State(initialValue: nil)
        self._completionReward = State(initialValue: nil)
    }
    
    @State private var viewModel: TimerViewModel
    @State private var awardedFish: PlayerFish?
    @State private var pendingAwardedFish: PlayerFish?
    @State private var completionReward: StudyCompletionReward?
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            AquariumView(
                player: player,
                backgroundTheme: AquariumThemeStore.theme(from: backgroundThemeRawValue)
            )

            VStack(spacing: 22) {
                Spacer()

                Text(viewModel.isStudyTime ? "FOCUS" : "BREAK")
                    .font(.caption.weight(.bold))
                    .tracking(3)
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.16), in: Capsule())

                Text(formatTime(viewModel.timeRemaining))
                    .font(.system(size: 72, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.25), radius: 10, y: 4)

                Text(viewModel.isStudyTime ? "📚 勉強時間" : "☕️ 休憩時間")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.9))

                Button(viewModel.isRunning ? "一時停止" : (viewModel.isStudyTime ? "勉強開始" : "休憩開始")) {
                    viewModel.startStopTimer()
                }
                .buttonStyle(AquariumPrimaryButtonStyle())

                Button("リセット") {
                    viewModel.resetTimer()
                }
                .buttonStyle(AquariumSecondaryButtonStyle())

                Spacer()
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
        }
        .navigationTitle("タイマー")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            configureStudyCompletion()
            viewModel.restorePersistedSessionIfNeeded()
        }
        .onReceive(timer) { _ in
            viewModel.tick()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                viewModel.synchronizeTime()
            }
        }
        .sheet(
            isPresented: Binding(
                get: { completionReward != nil },
                set: { isPresented in
                    if !isPresented {
                        completionReward = nil
                    }
                }
            ),
            onDismiss: presentPendingFishReward
        ) {
            if let completionReward {
                StudyCompletionRewardView(reward: completionReward)
            }
        }
        .sheet(
            isPresented: Binding(
                get: { awardedFish != nil },
                set: { isPresented in
                    if !isPresented {
                        awardedFish = nil
                    }
                }
            )
        ) {
            if let awardedFish {
                FishRewardView(fish: awardedFish)
            }
        }
    }

    private func configureStudyCompletion() {
        viewModel.onStudyFinished = {
            guard let player else { return }

            let coinReward = CurrencyService.studyCompletionReward(
                for: studyTime,
                todayStudyMinutesBeforeCompletion: player.todayStudyMinutes
            )
            player.todayStudyMinutes += studyTime
            player.totalStudyMinutes += studyTime
            pendingAwardedFish = FishRewardService.awardFish(for: studyTime, to: player)

            var awardedStudyReward = 0
            if coinReward > 0 {
                if (try? CurrencyService.addCoins(
                    coinReward,
                    to: player,
                    in: modelContext
                )) != nil {
                    awardedStudyReward = coinReward
                }
            }

            let streakUpdate = try? StudyStreakService.recordStudyCompletion(
                for: player,
                in: modelContext
            )

            if StudyCompletionReward.shouldPresent(forStudyMinutes: studyTime) {
                completionReward = StudyCompletionReward(
                    studyReward: awardedStudyReward,
                    streakReward: streakUpdate?.awardedCoins ?? 0,
                    streakDays: streakUpdate?.streakDays ?? player.studyStreakDays
                )
            } else {
                presentPendingFishReward()
            }
        }
    }

    private func presentPendingFishReward() {
        awardedFish = pendingAwardedFish
        pendingAwardedFish = nil
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
