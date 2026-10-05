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
    @State private var hasPreparedLaunch = false

    var body: some View {
        ZStack {
            if hasPreparedLaunch {
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
            } else {
                AquariumLoadingView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .task {
            guard !hasPreparedLaunch else { return }
            // Loadingを先に構築し、既存の初期化完了を待つ。固定秒数は待たせない。
            await Task.yield()
            guard !Task.isCancelled else { return }
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
            if hasCompletedOnboarding {
                // Homeと同じ冪等な準備処理を再利用し、Playerの重複生成を避ける。
                _ = try? HomePlayerInitialization.prepare(in: modelContext)
            }
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.25)) {
                hasPreparedLaunch = true
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
