//
//  HomeView.swift
//  PomodoroAquarium
//
//  Created by 阿部弦生 on 2026/07/11.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    
    @AppStorage("studyTime") private var studyTime = "25"
    @AppStorage("breakTime") private var breakTime = "5"
    @AppStorage("lastStudyDate") private var lastStudyDate = ""
    
    @Environment(\.modelContext) private var modelContext
    
    @Query private var players: [Player]
    @State private var showsInterruptionBanner = false
    @State private var resumesPersistedTimer = false
    @State private var isEditingAquarium = false
    @State private var isEditingDecoration = false
    
    private var player: Player? {
        players.first
    }

    var body: some View {
        NavigationStack{
            ZStack {
                AquariumView(
                    player: player,
                    isEditing: isEditingAquarium,
                    onDecorationEditingChanged: updateDecorationEditingState
                )
                
                VStack(spacing: 20) {
                    if showsInterruptionBanner {
                        interruptionBanner
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    Spacer()

                    if isEditingAquarium {
                        if !isEditingDecoration {
                            Group {
                                Text("水草や岩をドラッグして移動できます")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 10)
                                    .aquariumGlass(cornerRadius: 16)

                                Button("完了") {
                                    withAnimation { isEditingAquarium = false }
                                }
                                .buttonStyle(AquariumPrimaryButtonStyle())
                            }
                            .transition(.opacity)
                        }
                    } else {
                        VStack(spacing: 8) {
                            Text("今日の勉強時間")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.8))
                            Text("\((player?.todayStudyMinutes ?? 0) / 60)時間\((player?.todayStudyMinutes ?? 0) % 60)分")
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .aquariumGlass(cornerRadius: 18)

                        Button {
                            withAnimation { isEditingAquarium = true }
                        } label: {
                            Label("水槽編集", systemImage: "move.3d")
                        }
                        .buttonStyle(AquariumSecondaryButtonStyle())

                        NavigationLink {
                            TimerView(
                                studyTime: Int(studyTime) ?? 25,
                                breakTime: Int(breakTime) ?? 5,
                                player: player
                            )
                        } label: {
                            Label("勉強をはじめる", systemImage: "timer")
                        }
                        .buttonStyle(AquariumPrimaryButtonStyle())
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .navigationTitle("ポモドーロ水族館")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        BookView()
                    } label: {
                        Image(systemName: "book.closed.fill")
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(.black.opacity(0.16), in: Circle())
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView(
                            studyTime: $studyTime,
                            breakTime: $breakTime
                        )
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(.black.opacity(0.16), in: Circle())
                    }
                }
            }
            .navigationDestination(isPresented: $resumesPersistedTimer) {
                TimerView(
                    studyTime: Int(studyTime) ?? 25,
                    breakTime: Int(breakTime) ?? 5,
                    player: player
                )
            }
        }
        .onAppear {
            inspectPersistedTimerSession()
            let now = Date()
            let calendar = Calendar.current
            let today = DateFormatter.yyyyMMdd.string(from: now)

            let currentPlayer: Player
            if let player {
                currentPlayer = player
            } else {
                let newPlayer = Player()
                modelContext.insert(newPlayer)
                currentPlayer = newPlayer
            }

            if lastStudyDate.isEmpty {
                lastStudyDate = today
            } else if let lastDate = DateFormatter.yyyyMMdd.date(from: lastStudyDate),
                      !calendar.isDate(lastDate, inSameDayAs: now) {
                let yesterday = calendar.date(byAdding: .day, value: -1, to: now)

                if let yesterday,
                   calendar.isDate(lastDate, inSameDayAs: yesterday) {
                    currentPlayer.yesterdayStudyMinutes = currentPlayer.todayStudyMinutes
                } else {
                    currentPlayer.yesterdayStudyMinutes = 0
                }

                currentPlayer.todayStudyMinutes = 0
                lastStudyDate = today
            } else if DateFormatter.yyyyMMdd.date(from: lastStudyDate) == nil {
                currentPlayer.yesterdayStudyMinutes = 0
                currentPlayer.todayStudyMinutes = 0
                lastStudyDate = today
            }
        }
    }

    private var interruptionBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            VStack(alignment: .leading, spacing: 3) {
                Text("前回の勉強は中断されました")
                    .font(.subheadline.weight(.semibold))
                Text("勉強時間と魚獲得には反映されません")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
            Spacer()
            Button {
                withAnimation { showsInterruptionBanner = false }
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(.white)
        .padding(14)
        .background(.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 16))
    }

    private func inspectPersistedTimerSession() {
        switch TimerSessionStore.shared.launchStatus(at: Date()) {
        case .recoverable:
            resumesPersistedTimer = true
        case .interrupted, .none, .sameProcess:
            break
        }

        if TimerSessionStore.shared.consumeInterruptionBanner() {
            withAnimation { showsInterruptionBanner = true }
        }
    }

    private func updateDecorationEditingState(isEditing: Bool) {
        withAnimation(.easeInOut(duration: 0.15)) {
            isEditingDecoration = isEditing
        }
    }

}

extension DateFormatter {
    static let yyyyMMdd: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter
    }()
}


#Preview {
    TimerView(
        studyTime: 25,
        breakTime: 5,
        player: nil
    )
}
