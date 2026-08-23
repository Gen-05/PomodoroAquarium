//
//  ContentView.swift
//  PomodoroAquarium
//
//  Created by 阿部弦生 on 2026/07/02.
//

import SwiftUI

struct ContentView: View {
    @State private var hasStarted = false

    var body: some View {
        Group {
            if hasStarted {
                MainTabView()
                    .transition(.opacity)
            } else {
                StartView {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        hasStarted = true
                    }
                }
                .transition(.opacity)
            }
        }
    }
}
#Preview {
    ContentView()
}
