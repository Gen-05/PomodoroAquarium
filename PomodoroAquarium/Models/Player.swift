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
    /// 水槽へ出している個体ID。魚種単位ではなくPlayerFish単位で永続化する。
    var activeAquariumFishIDs: [UUID] = []
    /// `activeAquariumFishIDs.isEmpty`を「未移行」と「0匹選択済み」の判定に兼用しないためのフラグ。
    var hasInitializedActiveAquariumFish = false
    /// Core Tutorial報酬は通常抽選と独立し、同一トランザクションで重複を防ぐ。
    var hasGrantedCoreTutorialReward = false
    var coreTutorialRewardFishID: UUID?
    var hasGrantedCoreTutorialPoints = false
    var hasSavedCoreTutorialAquarium = false
    
    var totalStudyMinutes = 0
    var todayStudyMinutes = 0
    var yesterdayStudyMinutes = 0
    var coins = 0
    var studyStreakDays = 0
    var lastStudyCompletionDate: Date?
    var hasClaimedSevenDayStreakReward = false
    var hasClaimedThirtyDayStreakReward = false
    var hasClaimedYearStreakReward = false
    /// Calendar.currentの日付ごとの、次の魚までの未使用秒数（0..<1500）。
    var dailyFishProgressSeconds = 0
    var dailyFishProgressDate: Date?
    /// 当日の未受取権の保存値。dailyEarned - dailyClaimedと同期し、翌日失効する。
    var pendingFishEarnedCount = 0
    /// Homeの獲得数表示用。付与済みsessionと同じトランザクションで保存する。
    var dailyGrantedFishCount = 0
    var dailyGrantedFishDate: Date?
    var dailyEarnedFishCount = 0
    var dailyFishLimit = 3
    /// ポイント用端数のみ日次リセット。所持coinsや魚進捗とは独立。
    var dailyPointProgressDate: Date?
    var normalPointProgressSeconds = 0
    var reducedPointProgressUnits = 0
    /// 開始日へ遅延確定するsession用の日別snapshot。過去日の枠を翌日へ移さない。
    var dailyRewardStatesData: Data?

    /// 既存の永続受取数を再利用し、二つのclaimedカウンターを持たない。
    var dailyClaimedFishCount: Int {
        get { dailyGrantedFishCount }
        set { dailyGrantedFishCount = newValue }
    }

    var dailyPendingFishCount: Int { max(0, dailyEarnedFishCount - dailyClaimedFishCount) }
    
    init(
        ownedFish: [PlayerFish] = [],
        favoriteFish: PlayerFish? = nil,
        activeAquariumFishIDs: [UUID] = [],
        hasInitializedActiveAquariumFish: Bool = false,
        hasGrantedCoreTutorialReward: Bool = false,
        coreTutorialRewardFishID: UUID? = nil,
        hasGrantedCoreTutorialPoints: Bool = false,
        hasSavedCoreTutorialAquarium: Bool = false,
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
        self.activeAquariumFishIDs = activeAquariumFishIDs
        self.hasInitializedActiveAquariumFish = hasInitializedActiveAquariumFish
        self.hasGrantedCoreTutorialReward = hasGrantedCoreTutorialReward
        self.coreTutorialRewardFishID = coreTutorialRewardFishID
        self.hasGrantedCoreTutorialPoints = hasGrantedCoreTutorialPoints
        self.hasSavedCoreTutorialAquarium = hasSavedCoreTutorialAquarium
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
