//
//  ContentView.swift
//  PomodoroAquarium
//
//  Created by 阿部弦生 on 2026/07/02.
//

import SwiftUI

struct ContentView: View {
    @AppStorage(OnboardingStore.storageKey) private var hasCompletedOnboarding = false

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                MainTabView()
                    .transition(.opacity)
            } else {
                OnboardingView {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        hasCompletedOnboarding = true
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
