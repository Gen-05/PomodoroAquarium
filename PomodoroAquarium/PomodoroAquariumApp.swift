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
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: [Player.self, PlayerFish.self, AquariumDecorationPlacement.self])
        }
    }
}
