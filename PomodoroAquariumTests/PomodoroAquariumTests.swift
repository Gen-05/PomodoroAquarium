//
//  PomodoroAquariumTests.swift
//  PomodoroAquariumTests
//
//  Created by 阿部弦生 on 2026/07/02.
//

import Testing
@testable import PomodoroAquarium

struct PomodoroAquariumTests {

    @Test func studySessionUnder25MinutesDoesNotAwardFish() {
        let player = Player()

        let awardedFish = FishRewardService.awardFish(for: 24, to: player)

        #expect(awardedFish == nil)
        #expect(player.ownedFish.isEmpty)
    }

    @Test func studySessionOf25MinutesAwardsOneFish() {
        let player = Player()

        let awardedFish = FishRewardService.awardFish(for: 25, to: player)

        #expect(awardedFish != nil)
        #expect(player.ownedFish.count == 1)
        #expect(player.ownedFish.first === awardedFish)
    }

    @Test func repeatedEligibleSessionsAwardOneFishEach() {
        let player = Player()

        FishRewardService.awardFish(for: 25, to: player)
        FishRewardService.awardFish(for: 30, to: player)
        FishRewardService.awardFish(for: 60, to: player)

        #expect(player.ownedFish.count == 3)
    }

}
