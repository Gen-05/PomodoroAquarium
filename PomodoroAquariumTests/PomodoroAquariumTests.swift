//
//  PomodoroAquariumTests.swift
//  PomodoroAquariumTests
//
//  Created by 阿部弦生 on 2026/07/02.
//

import Testing
@testable import PomodoroAquarium

struct PomodoroAquariumTests {

    @Test func rarityProbabilitiesAtZeroMinutesUseBaseRates() {
        let probabilities = FishRewardService.rarityProbabilities(for: 0)

        #expect(probabilities.common == 70)
        #expect(probabilities.rare == 20)
        #expect(probabilities.epic == 8)
        #expect(probabilities.legendary == 2)
        #expect(probabilities.total == 100)
    }

    @Test func rarityProbabilitiesAt90MinutesAreHalfway() {
        let probabilities = FishRewardService.rarityProbabilities(for: 90)

        #expect(probabilities.common == 64)
        #expect(probabilities.rare == 22.5)
        #expect(probabilities.epic == 10.5)
        #expect(probabilities.legendary == 3)
        #expect(probabilities.total == 100)
    }

    @Test func rarityProbabilitiesAt180MinutesUseMaximumBonus() {
        let probabilities = FishRewardService.rarityProbabilities(for: 180)

        #expect(probabilities.common == 58)
        #expect(probabilities.rare == 25)
        #expect(probabilities.epic == 13)
        #expect(probabilities.legendary == 4)
        #expect(probabilities.total == 100)
    }

    @Test func rarityProbabilitiesAreCappedAt180Minutes() {
        let at180Minutes = FishRewardService.rarityProbabilities(for: 180)
        let at300Minutes = FishRewardService.rarityProbabilities(for: 300)

        #expect(at300Minutes.common == at180Minutes.common)
        #expect(at300Minutes.rare == at180Minutes.rare)
        #expect(at300Minutes.epic == at180Minutes.epic)
        #expect(at300Minutes.legendary == at180Minutes.legendary)
        #expect(at300Minutes.total == 100)
    }

    @Test func rarityProbabilitiesAlwaysTotal100Percent() {
        for minutes in [0, 1, 47, 90, 179, 180, 300] {
            let probabilities = FishRewardService.rarityProbabilities(for: minutes)

            #expect(abs(probabilities.total - 100) < 0.000_001)
        }
    }

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

    @Test func playerCanOwnMultipleFishOfTheSameSpecies() {
        let firstClownfish = PlayerFish(species: .clownfish)
        let secondClownfish = PlayerFish(species: .clownfish)
        let player = Player()

        player.ownedFish.append(firstClownfish)
        player.ownedFish.append(secondClownfish)

        #expect(firstClownfish.id != secondClownfish.id)
        #expect(player.ownedFish.count == 2)
        #expect(player.ownedFish.count { $0.species == .clownfish } == 2)
    }

    @Test func bookOwnedCountCountsOnlyMatchingSpecies() {
        let player = Player(ownedFish: [
            PlayerFish(species: .clownfish),
            PlayerFish(species: .clownfish),
            PlayerFish(species: .pufferfish)
        ])

        #expect(BookView.ownedCount(for: .clownfish, in: player) == 2)
        #expect(BookView.ownedCount(for: .pufferfish, in: player) == 1)
        #expect(BookView.ownedCount(for: .seahorse, in: player) == 0)
    }

    @Test func bookOwnedCountIsZeroWithoutPlayer() {
        #expect(BookView.ownedCount(for: .clownfish, in: nil) == 0)
    }

    @Test func ownedFishCanBeSetAsFavorite() {
        let clownfish = PlayerFish(species: .clownfish)
        let player = Player(ownedFish: [clownfish])

        let didSetFavorite = BookView.setFavorite(.clownfish, for: player)

        #expect(didSetFavorite)
        #expect(player.favoriteFish?.id == clownfish.id)
    }

    @Test func selectingAnotherFishUpdatesFavorite() {
        let clownfish = PlayerFish(species: .clownfish)
        let pufferfish = PlayerFish(species: .pufferfish)
        let player = Player(ownedFish: [clownfish, pufferfish])

        BookView.setFavorite(.clownfish, for: player)
        BookView.setFavorite(.pufferfish, for: player)

        #expect(player.favoriteFish?.id == pufferfish.id)
    }

    @Test func unownedSpeciesCannotBeSetAsFavorite() {
        let clownfish = PlayerFish(species: .clownfish)
        let player = Player(ownedFish: [clownfish], favoriteFish: clownfish)

        let didSetFavorite = BookView.setFavorite(.whaleShark, for: player)

        #expect(!didSetFavorite)
        #expect(player.favoriteFish?.id == clownfish.id)
    }

}
