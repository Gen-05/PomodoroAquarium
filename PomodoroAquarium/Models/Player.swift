//
//  Player.swift
//  PomodoroAquarium
//
//  Created by 阿部弦生 on 2026/08/01.
//

import SwiftData

@Model
class Player {
    var ownedFish: [PlayerFish] = []
    var favoriteFish: PlayerFish?
    
    var totalStudyMinutes = 0
    var todayStudyMinutes = 0
    var yesterdayStudyMinutes = 0
    var coins = 0
    
    init(
        ownedFish: [PlayerFish] = [],
        favoriteFish: PlayerFish? = nil,
        totalStudyMinutes: Int = 0,
        todayStudyMinutes: Int = 0,
        yesterdayStudyMinutes: Int = 0,
        coins: Int = 0
    ) {
        self.ownedFish = ownedFish
        self.favoriteFish = favoriteFish
        self.totalStudyMinutes = totalStudyMinutes
        self.todayStudyMinutes = todayStudyMinutes
        self.yesterdayStudyMinutes = yesterdayStudyMinutes
        self.coins = max(0, coins)
    }
}
