//
//  FishRewardService.swift
//  PomodoroAquarium
//

import Foundation

struct FishRewardService {
    static let minimumStudyMinutes = 25

    @discardableResult
    static func awardFish(
        for studyMinutes: Int,
        to player: Player
    ) -> PlayerFish? {
        guard studyMinutes >= minimumStudyMinutes,
              let selectedSpecies = FishSpecies.allCases.randomElement() else {
            return nil
        }

        let newFish = PlayerFish(species: selectedSpecies)
        player.ownedFish.append(newFish)
        return newFish
    }
}
