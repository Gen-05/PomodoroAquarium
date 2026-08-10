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
            VStack(spacing: 30) {
                
                Text("🐠ポモドーロ水族館")
                    .font(.largeTitle)
                    .bold()
                
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.blue.opacity(0.2))
                    .frame(height: 250)
                    .overlay {
                        Text("水槽エリア")
                            .font(.title2)
                    }
                
                Text("25:00")
                    .font(.system(size: 50,weight: .bold))
                
                NavigationLink("勉強開始") {
                    TimerView(
                        studyTime: Int(studyTime) ?? 25,
                        breakTime: Int(breakTime) ?? 5,
                        player: player
                    )
                }
                .buttonStyle(.borderedProminent)
                
                VStack {
                    Text("今日の勉強時間")
                    Text("\((player?.todayStudyMinutes ?? 0) / 60)時間\((player?.todayStudyMinutes ?? 0) % 60)分")
                        .font(.title2)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("ポモドーロ水族館")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        BookView()
                    } label: {
                        Image(systemName: "book")
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView(
                            studyTime: $studyTime,
                            breakTime: $breakTime
                        )
                    } label: {
                        Image(systemName: "gearshape")
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
