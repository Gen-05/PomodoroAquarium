//
//  HomeView.swift
//  PomodoroAquarium
//
//  Created by 阿部弦生 on 2026/07/11.
//

import SwiftUI

struct HomeView: View {
    
    @AppStorage("studyTime") private var studyTime = "25"
    @AppStorage("breakTime") private var breakTime = "5"
    @AppStorage("todayStudyTime") private var todayStudyTime = 0
    @AppStorage("lastStudyDate") private var lastStudyDate = ""
    
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
                        todayStudyTime: $todayStudyTime
                    )
                }
                .buttonStyle(.borderedProminent)
                
                VStack {
                    Text("今日の勉強時間")
                    Text("\(todayStudyTime / 60)時間\(todayStudyTime % 60)分")
                        .font(.title2)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("ポモドーロ水族館")
            .toolbar {
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
            let today = DateFormatter.yyyyMMdd.string(from: Date())
            
            if lastStudyDate != today {
                todayStudyTime = 0
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
    HomeView()
}
