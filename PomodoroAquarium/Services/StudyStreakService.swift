import Foundation
import SwiftData

struct StudyStreakUpdate: Equatable {
    let streakDays: Int
    let awardedCoins: Int
    let didAdvance: Bool
}

enum StudyStreakService {
    static let sevenDayReward = 70
    static let thirtyDayReward = 200
    static let yearReward = 2_000

    /// 正常な勉強完了を日付単位で記録し、該当する継続報酬を付与する。
    @discardableResult
    static func recordStudyCompletion(
        for player: Player,
        at date: Date = Date(),
        calendar: Calendar = .current,
        in context: ModelContext
    ) throws -> StudyStreakUpdate {
        let completionDay = calendar.startOfDay(for: date)

        if let lastCompletionDate = player.lastStudyCompletionDate,
           calendar.isDate(lastCompletionDate, inSameDayAs: completionDay) {
            return StudyStreakUpdate(
                streakDays: max(0, player.studyStreakDays),
                awardedCoins: 0,
                didAdvance: false
            )
        }

        let previousDay = calendar.date(byAdding: .day, value: -1, to: completionDay)
        if let lastCompletionDate = player.lastStudyCompletionDate,
           let previousDay,
           calendar.isDate(lastCompletionDate, inSameDayAs: previousDay) {
            let (incrementedDays, overflowed) = max(0, player.studyStreakDays)
                .addingReportingOverflow(1)
            player.studyStreakDays = overflowed ? Int.max : incrementedDays
        } else {
            player.studyStreakDays = 1
        }
        player.lastStudyCompletionDate = completionDay

        let reward = rewardForCurrentStreak(for: player)
        if reward > 0 {
            _ = try CurrencyService.addCoins(reward, to: player, in: context)
        } else {
            try context.save()
        }

        return StudyStreakUpdate(
            streakDays: player.studyStreakDays,
            awardedCoins: reward,
            didAdvance: true
        )
    }

    private static func rewardForCurrentStreak(for player: Player) -> Int {
        var reward = player.studyStreakDays.isMultiple(of: 7) ? sevenDayReward : 0

        if player.studyStreakDays.isMultiple(of: 30) {
            reward += thirtyDayReward
        }
        if player.studyStreakDays.isMultiple(of: 365) {
            reward += yearReward
        }

        return reward
    }
}
