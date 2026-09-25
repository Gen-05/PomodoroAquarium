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
    private let usesInMemoryUITestStore: Bool

    init() {
        TimerConfigurationStorage.migrateLegacyValuesIfNeeded()
#if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        usesInMemoryUITestStore = arguments.contains("-core-tutorial-ui-test") ||
            arguments.contains("-core-tutorial-in-memory")
        // UI Test専用。Releaseの起動・保存フローには影響しない。
        if arguments.contains("-reset-onboarding") {
            UserDefaults.standard.removeObject(forKey: OnboardingStore.storageKey)
        }
        if arguments.contains("-core-tutorial-ui-test") {
            let defaults = UserDefaults.standard
            defaults.set(true, forKey: OnboardingStore.storageKey)
            for key in [
                CoreTutorialStorageKey.hasCompleted,
                CoreTutorialStorageKey.step,
                CoreTutorialStorageKey.hasGrantedReward,
                CoreTutorialStorageKey.hasGrantedPoints,
                CoreTutorialStorageKey.hasSavedAquarium,
                DailyFishAcquisitionStorageKey.count,
                DailyFishAcquisitionStorageKey.dayIdentifier
            ] {
                defaults.removeObject(forKey: key)
            }
        }
#else
        usesInMemoryUITestStore = false
#endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: [
                    Player.self,
                    PlayerFish.self,
                    AquariumDecorationPlacement.self,
                    StudyDailyRecord.self,
                    RewardHistoryEntry.self
                ], inMemory: usesInMemoryUITestStore)
        }
    }
}
