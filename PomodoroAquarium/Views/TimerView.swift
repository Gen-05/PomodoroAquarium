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
    @Environment(\.dismiss) private var dismiss
    
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
        self._pendingCompletionReward = State(initialValue: nil)
    }
    
    @State private var viewModel: TimerViewModel
    @State private var awardedFish: PlayerFish?
    @State private var pendingAwardedFish: PlayerFish?
    @State private var completionReward: StudyCompletionReward?
    @State private var pendingCompletionReward: StudyCompletionReward?
    @State private var studyFinishedMinutes: Int?
    @State private var showsEndConfirmation = false
    @State private var showsNextSetConfirmation = false
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            AquariumView(
                player: player,
                backgroundTheme: AquariumThemeStore.theme(from: backgroundThemeRawValue)
            )

            VStack(spacing: 22) {
                Spacer()

                if viewModel.isStudyTime && (viewModel.state == .idle || viewModel.state == .completed) {
                    Picker("計測方法", selection: Binding(
                        get: { viewModel.mode },
                        set: { viewModel.selectMode($0) }
                    )) {
                        ForEach(TimerMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(5)
                    .background(.black.opacity(0.14), in: RoundedRectangle(cornerRadius: 12))
                }

                Text(viewModel.isStudyTime ? "FOCUS" : "BREAK")
                    .font(.caption.weight(.bold))
                    .tracking(3)
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.16), in: Capsule())

                Text(formatTime(viewModel.displayedSeconds))
                    .font(.system(size: 72, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.25), radius: 10, y: 4)

                Text(sessionDescription)
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.9))

                if viewModel.state == .paused {
                    Button("再開する") {
                        viewModel.resumeTimer()
                    }
                    .buttonStyle(AquariumPrimaryButtonStyle())

                    Button("終了する") {
                        showsEndConfirmation = true
                    }
                    .buttonStyle(AquariumSecondaryButtonStyle())
                } else {
                    Button(viewModel.isRunning ? "一時停止" : (viewModel.isStudyTime ? "勉強開始" : "休憩開始")) {
                        viewModel.startStopTimer()
                    }
                    .buttonStyle(AquariumPrimaryButtonStyle())
                }

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
            } else {
                viewModel.recordLastActiveTime()
            }
        }
        .alert(viewModel.isStudyTime ? "勉強を終了しますか？" : "休憩を終了しますか？", isPresented: $showsEndConfirmation) {
            Button("キャンセル", role: .cancel) {}
            Button("終了する", role: .destructive) {
                viewModel.endCurrentSession()
            }
        } message: {
            if viewModel.isStudyTime {
                Text("現在の勉強時間を報酬計算します。\n\n今回の勉強時間: \(viewModel.elapsedStudyMinutes)分")
            } else {
                Text("現在の休憩を終了して、次の勉強へ進みます。")
            }
        }
        .alert("次のセットを開始しますか？", isPresented: $showsNextSetConfirmation) {
            Button("終了する", role: .cancel) {
                dismiss()
            }
            Button("続ける") {
                viewModel.resumeTimer()
            }
        } message: {
            Text("休憩が終了しました。")
        }
        .sheet(
            isPresented: Binding(
                get: { studyFinishedMinutes != nil },
                set: { isPresented in
                    if !isPresented {
                        studyFinishedMinutes = nil
                    }
                }
            ),
            onDismiss: presentPendingCompletionReward
        ) {
            if let studyFinishedMinutes {
                StudyFinishedView(studyMinutes: studyFinishedMinutes)
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
            ),
            onDismiss: finishStudyFlow
        ) {
            if let awardedFish {
                FishRewardView(fish: awardedFish)
            }
        }
    }

    private func configureStudyCompletion() {
        viewModel.onStudyFinished = {
            let completedStudyMinutes = viewModel.lastCompletedStudyMinutes
            studyFinishedMinutes = completedStudyMinutes
            guard let player else { return }

            let coinReward = CurrencyService.studyCompletionReward(
                for: completedStudyMinutes,
                todayStudyMinutesBeforeCompletion: player.todayStudyMinutes
            )
            player.todayStudyMinutes += completedStudyMinutes
            player.totalStudyMinutes += completedStudyMinutes

            guard StudyCompletionReward.shouldPresent(forStudyMinutes: completedStudyMinutes) else {
                return
            }

            pendingAwardedFish = FishRewardService.awardFish(for: completedStudyMinutes, to: player)

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

            pendingCompletionReward = StudyCompletionReward(
                studyReward: awardedStudyReward,
                streakReward: streakUpdate?.awardedCoins ?? 0,
                streakDays: streakUpdate?.streakDays ?? player.studyStreakDays
            )
        }
        viewModel.onBreakFinished = {
            showsNextSetConfirmation = true
        }
    }

    private var sessionDescription: String {
        if !viewModel.isStudyTime {
            return "☕️ 休憩時間"
        }
        return viewModel.mode == .stopwatch ? "⏱️ ストップウォッチ" : "📚 勉強時間"
    }

    private func presentPendingCompletionReward() {
        if let pendingCompletionReward {
            completionReward = pendingCompletionReward
            self.pendingCompletionReward = nil
        } else {
            presentPendingFishReward()
        }
    }

    private func presentPendingFishReward() {
        if let pendingAwardedFish {
            awardedFish = pendingAwardedFish
            self.pendingAwardedFish = nil
        } else {
            finishStudyFlow()
        }
    }

    private func finishStudyFlow() {
        if viewModel.mode == .pomodoro {
            viewModel.beginPomodoroBreak()
        } else {
            dismiss()
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
