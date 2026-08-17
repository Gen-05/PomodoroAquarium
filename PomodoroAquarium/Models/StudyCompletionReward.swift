struct StudyCompletionReward: Equatable {
    let studyReward: Int
    let streakReward: Int
    let streakDays: Int

    static func shouldPresent(forStudyMinutes minutes: Int) -> Bool {
        minutes >= 25
    }

    init(studyReward: Int, streakReward: Int, streakDays: Int) {
        self.studyReward = max(0, studyReward)
        self.streakReward = max(0, streakReward)
        self.streakDays = max(0, streakDays)
    }

    var totalReward: Int {
        let (total, overflowed) = studyReward.addingReportingOverflow(streakReward)
        return overflowed ? Int.max : total
    }

    var hasStreakReward: Bool {
        streakReward > 0
    }

    /// 将来のリワード広告では通常の勉強報酬だけに倍率を適用する。
    func applyingStudyRewardMultiplier(_ multiplier: Int) -> StudyCompletionReward {
        guard multiplier > 1 else { return self }
        let (multipliedReward, overflowed) = studyReward.multipliedReportingOverflow(by: multiplier)
        return StudyCompletionReward(
            studyReward: overflowed ? Int.max : multipliedReward,
            streakReward: streakReward,
            streakDays: streakDays
        )
    }
}
