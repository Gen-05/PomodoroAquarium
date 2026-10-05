import Foundation

enum PomodoroAutoStartSettings {
    static let storageKey = "pomodoroAutoStartNextSet"
    static let explanation = "オンにすると、集中と休憩を確認なしで自動的に切り替えます。魚の獲得演出は最後にまとめて表示します。"

    static func isEnabled(in defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: storageKey)
    }

    static func save(_ enabled: Bool, in defaults: UserDefaults = .standard) {
        defaults.set(enabled, forKey: storageKey)
    }
}

/// 表示だけを保留する。ポイント・魚の付与は従来の冪等な保存処理で先に確定する。
struct PomodoroFlowRewardSummary: Codable {
    let flowID: UUID
    var sessions: [UUID] = []
    var minutes = 0
    var studyPoints = 0
    var streakPoints = 0
    var streakDays = 0
    var didEarnFish = false

    var completionReward: StudyCompletionReward {
        .init(studyReward: studyPoints, streakReward: streakPoints,
              streakDays: streakDays, didEarnFish: didEarnFish)
    }
}

enum PomodoroFlowRewardStore {
    private static let key = "pomodoroFlowRewardSummary"

    static func load(flowID: UUID, defaults: UserDefaults) -> PomodoroFlowRewardSummary? {
        guard let data = defaults.data(forKey: key),
              let summary = try? JSONDecoder().decode(PomodoroFlowRewardSummary.self, from: data),
              summary.flowID == flowID else { return nil }
        return summary
    }

    static func append(_ reward: StudyCompletionReward, minutes: Int, sessionID: UUID,
                       flowID: UUID, defaults: UserDefaults) {
        var summary = load(flowID: flowID, defaults: defaults) ?? .init(flowID: flowID)
        guard !summary.sessions.contains(sessionID) else { return }
        summary.sessions.append(sessionID)
        summary.minutes += max(0, minutes)
        summary.studyPoints += reward.studyReward
        summary.streakPoints += reward.streakReward
        summary.streakDays = reward.streakDays
        summary.didEarnFish = summary.didEarnFish || reward.didEarnFish
        if let data = try? JSONEncoder().encode(summary) { defaults.set(data, forKey: key) }
    }

    static func clear(flowID: UUID, defaults: UserDefaults) {
        guard load(flowID: flowID, defaults: defaults) != nil else { return }
        defaults.removeObject(forKey: key)
    }
}
