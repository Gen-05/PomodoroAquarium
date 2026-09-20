//
//  PomodoroAquariumApp.swift
//  PomodoroAquarium
//
//  Created by 阿部弦生 on 2026/07/02.
//

import SwiftUI
import SwiftData

@main
struct PomodoroAquariumApp: App {
    init() {
#if DEBUG
        // UI Test専用。Releaseの起動・保存フローには影響しない。
        if ProcessInfo.processInfo.arguments.contains("-reset-onboarding") {
            UserDefaults.standard.removeObject(forKey: OnboardingStore.storageKey)
        }
#endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: [
                    Player.self,
                    PlayerFish.self,
                    AquariumDecorationPlacement.self,
                    StudyDailyRecord.self
                ])
        }
    }
}
