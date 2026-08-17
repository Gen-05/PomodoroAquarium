//
//  Player.swift
//  PomodoroAquarium
//
//  Created by 阿部弦生 on 2026/08/01.
//

import SwiftData
import Foundation

@Model
class Player {
    var ownedFish: [PlayerFish] = []
    var favoriteFish: PlayerFish?
    
    var totalStudyMinutes = 0
    var todayStudyMinutes = 0
    var yesterdayStudyMinutes = 0
    var coins = 0
    var studyStreakDays = 0
    var lastStudyCompletionDate: Date?
    var hasClaimedSevenDayStreakReward = false
    var hasClaimedThirtyDayStreakReward = false
    var hasClaimedYearStreakReward = false
    
    init(
        ownedFish: [PlayerFish] = [],
        favoriteFish: PlayerFish? = nil,
        totalStudyMinutes: Int = 0,
        todayStudyMinutes: Int = 0,
        yesterdayStudyMinutes: Int = 0,
        coins: Int = 0,
        studyStreakDays: Int = 0,
        lastStudyCompletionDate: Date? = nil,
        hasClaimedSevenDayStreakReward: Bool = false,
        hasClaimedThirtyDayStreakReward: Bool = false,
        hasClaimedYearStreakReward: Bool = false
    ) {
        self.ownedFish = ownedFish
        self.favoriteFish = favoriteFish
        self.totalStudyMinutes = totalStudyMinutes
        self.todayStudyMinutes = todayStudyMinutes
        self.yesterdayStudyMinutes = yesterdayStudyMinutes
        self.coins = max(0, coins)
        self.studyStreakDays = max(0, studyStreakDays)
        self.lastStudyCompletionDate = lastStudyCompletionDate
        self.hasClaimedSevenDayStreakReward = hasClaimedSevenDayStreakReward
        self.hasClaimedThirtyDayStreakReward = hasClaimedThirtyDayStreakReward
        self.hasClaimedYearStreakReward = hasClaimedYearStreakReward
    }
}
