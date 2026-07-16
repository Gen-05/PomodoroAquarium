//
//  HomeView.swift
//  PomodoroAquarium
//
//  Created by 阿部弦生 on 2026/07/11.
//

import SwiftUI

struct HomeView: View {
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
                    TimerView()
                }
                .buttonStyle(.borderedProminent)
                
                VStack {
                    Text("今日の勉強時間")
                    Text("0時間0分")
                        .font(.title2)
                }
                
                Spacer()
            }
            .padding()
        }
    }
}


#Preview {
    HomeView()
}
