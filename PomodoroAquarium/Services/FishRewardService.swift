//
//  FishRewardService.swift
//  PomodoroAquarium
//

import Foundation
import SwiftData

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
        to player: Player,
        on date: Date = Date(),
        calendar: Calendar = .current,
        in context: ModelContext? = nil
    ) -> PlayerFish? {
        guard studyMinutes >= minimumStudyMinutes else { return nil }
        let previousDayMinutes: Int
        if let context = context ?? player.modelContext {
            guard let minutes = try? PreviousDayFocusDurationService.synchronizeMinutes(
                for: player, before: date, calendar: calendar, in: context
            ) else { return nil }
            previousDayMinutes = minutes
        } else {
            // 未保存の単匹Preview/helperには前日記録がない。古いPlayerキャッシュへ戻らない。
            previousDayMinutes = 0
        }
        guard let selectedSpecies = drawSpecies(using: rarityProbabilities(for: previousDayMinutes)) else { return nil }

        let newFish = PlayerFish(species: selectedSpecies)
        player.ownedFish.append(newFish)
        return newFish
    }

    /// 閾値判定は日次進捗側へ分離。各呼び出しで既存の抽選を独立に行う。
    static func drawSpecies(using probabilities: RarityProbabilities) -> FishSpecies? {
        guard let rarity = selectRarity(using: probabilities) else { return nil }
        return FishSpecies.allCases.filter { $0.rarity == rarity }.randomElement()
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
