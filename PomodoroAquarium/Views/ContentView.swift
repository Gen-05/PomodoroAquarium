//
//  ContentView.swift
//  PomodoroAquarium
//
//  Created by 阿部弦生 on 2026/07/02.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @AppStorage(OnboardingStore.storageKey) private var hasCompletedOnboarding = false
    @Environment(\.modelContext) private var modelContext

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
        .task {
            _ = try? FocusCategoryService.createDefaultsIfNeeded(in: modelContext)
            try? FocusSessionHistoryMigration.migrateLegacyDailyRecordsIfNeeded(
                in: modelContext
            )
            do {
                let result = try FocusSessionHistoryMigration
                    .migrateLegacyFocusMethodsToPomodoroIfNeeded(in: modelContext)
#if DEBUG
                if result.migratedRecordCount > 0 {
                    print(
                        "Focus method migration: legacy=\(result.legacyRecordCount), " +
                        "migrated=\(result.migratedRecordCount), " +
                        "migratedMinutes=\(result.migratedMinutes), " +
                        "minutes=\(result.totalMinutesBefore)->\(result.totalMinutesAfter)"
                    )
                }
#endif
            } catch {
#if DEBUG
                print("Focus method migration failed: \(error)")
#endif
            }
        }
    }
}
#Preview {
    ContentView()
        .modelContainer(
            for: [
                Player.self,
                PlayerFish.self,
                AquariumDecorationPlacement.self,
                StudyDailyRecord.self,
                FocusCategory.self,
                FocusSessionRecord.self,
                RewardHistoryEntry.self
            ],
            inMemory: true
        )
}
