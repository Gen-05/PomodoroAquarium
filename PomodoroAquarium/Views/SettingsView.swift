//
//  settingView.swift
//  PomodoroAquarium
//
//  Created by 阿部弦生 on 2026/07/21.
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        Form {}
            .navigationTitle("設定")
    }
}
#Preview {
    NavigationStack {
        SettingsView()
    }
}
