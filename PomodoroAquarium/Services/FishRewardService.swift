//
//  FishRewardService.swift
//  PomodoroAquarium
//

import Foundation

struct FishRewardService {
    static let minimumStudyMinutes = 25
    static let maximumBonusStudyMinutes = 180

    struct RarityProbabilities {
        let common: Double
        let rare: Double
        let epic: Double
        let legendary: Double

        var total: Double {
            common + rare + epic + legendary
        }

        func probability(for rarity: FishRarity) -> Double {
            switch rarity {
            case .common: common
            case .rare: rare
            case .epic: epic
            case .legendary: legendary
            }
        }
    }

    static func rarityProbabilities(
        for yesterdayStudyMinutes: Int
    ) -> RarityProbabilities {
        let cappedMinutes = min(max(yesterdayStudyMinutes, 0), maximumBonusStudyMinutes)
        let progress = Double(cappedMinutes) / Double(maximumBonusStudyMinutes)

        return RarityProbabilities(
            common: interpolate(from: 70, to: 58, progress: progress),
            rare: interpolate(from: 20, to: 25, progress: progress),
            epic: interpolate(from: 8, to: 13, progress: progress),
            legendary: interpolate(from: 2, to: 4, progress: progress)
        )
    }

    @discardableResult
    static func awardFish(
        for studyMinutes: Int,
        to player: Player
    ) -> PlayerFish? {
        guard studyMinutes >= minimumStudyMinutes,
              let selectedRarity = selectRarity(
                using: rarityProbabilities(for: player.yesterdayStudyMinutes)
              ),
              let selectedSpecies = FishSpecies.allCases
                .filter({ $0.rarity == selectedRarity })
                .randomElement() else {
            return nil
        }

        let newFish = PlayerFish(species: selectedSpecies)
        player.ownedFish.append(newFish)
        return newFish
    }

    private static func interpolate(
        from start: Double,
        to end: Double,
        progress: Double
    ) -> Double {
        start + (end - start) * progress
    }

    private static func selectRarity(
        using probabilities: RarityProbabilities
    ) -> FishRarity? {
        let weightedRarities: [(FishRarity, Double)] = [
            (.common, probabilities.common),
            (.rare, probabilities.rare),
            (.epic, probabilities.epic),
            (.legendary, probabilities.legendary)
        ]
        let roll = Double.random(in: 0..<probabilities.total)
        var cumulativeProbability = 0.0

        for (rarity, probability) in weightedRarities {
            cumulativeProbability += probability
            if roll < cumulativeProbability {
                return rarity
            }
        }

        return nil
    }
}
