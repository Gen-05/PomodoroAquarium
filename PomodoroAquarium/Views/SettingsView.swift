//
//  settingView.swift
//  PomodoroAquarium
//
//  Created by 阿部弦生 on 2026/07/21.
//

import SwiftUI

struct SettingsView: View {
    
    @Binding var studyTime: String
    @Binding var breakTime: String
    
    var body: some View {
        Form {
            Section("勉強時間") {
                TextField("勉強時間", text: $studyTime)
                    .keyboardType(.numberPad)
            }
            
            Section("休憩時間") {
                TextField("休憩時間", text: $breakTime)
                    .keyboardType(.numberPad)
            }
            .navigationTitle("設定")
        }
    }
}
#Preview {
    NavigationStack {
        SettingsView(
            studyTime: .constant("25"),
            breakTime: .constant("5")
        )
    }
}
