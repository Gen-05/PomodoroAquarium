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
    
    private var player: Player? {
        players.first
    }

    var body: some View {
        NavigationStack{
            ZStack {
                AquariumView(player: player)
                
                VStack(spacing: 20) {
                    Spacer()

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
        }
        .onAppear {
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
