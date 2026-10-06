import Foundation

/// Playerの日次値は表示用のcurrent projection。日付を切り替える前に保存し、
/// 日跨ぎ/再送されたsessionも開始日のclaimed・解放枠・端数で確定できるようにする。
enum DailyRewardStateStore {
    private struct FishState: Codable {
        let day: Date
        let remainder: Int
        let earned: Int
        let claimed: Int
        let limit: Int
    }

    private struct PointState: Codable {
        let day: Date
        let normalRemainder: Int
        let reducedRemainder: Int
    }

    private struct States: Codable {
        var fish: [FishState] = []
        var points: [PointState] = []
    }

    @discardableResult
    static func activateFishDay(for player: Player, on date: Date, calendar: Calendar) -> Bool {
        let day = calendar.startOfDay(for: date)
        guard player.dailyFishProgressDate.map({ calendar.isDate($0, inSameDayAs: day) }) != true ||
                player.dailyGrantedFishDate.map({ calendar.isDate($0, inSameDayAs: day) }) != true else {
            return false
        }
        var states = load(for: player)
        if let previous = player.dailyGrantedFishDate ?? player.dailyFishProgressDate {
            states.fish.removeAll { calendar.isDate($0.day, inSameDayAs: previous) }
            states.fish.append(FishState(
                day: previous, remainder: player.dailyFishProgressSeconds,
                earned: player.dailyEarnedFishCount, claimed: player.dailyClaimedFishCount,
                limit: player.dailyFishLimit
            ))
        }
        let restored = states.fish.first { calendar.isDate($0.day, inSameDayAs: day) }
        player.dailyFishProgressDate = day
        player.dailyGrantedFishDate = day
        player.dailyFishProgressSeconds = restored?.remainder ?? 0
        player.dailyEarnedFishCount = restored?.earned ?? 0
        player.dailyClaimedFishCount = restored?.claimed ?? 0
        player.dailyFishLimit = restored?.limit ?? DailyFishAcquisitionPolicy.basicLimit
        player.pendingFishEarnedCount = player.dailyPendingFishCount
        save(states, for: player)
        return true
    }

    @discardableResult
    static func activatePointDay(for player: Player, on date: Date, calendar: Calendar) -> Bool {
        let day = calendar.startOfDay(for: date)
        guard player.dailyPointProgressDate.map({ calendar.isDate($0, inSameDayAs: day) }) != true else {
            return false
        }
        var states = load(for: player)
        if let previous = player.dailyPointProgressDate {
            states.points.removeAll { calendar.isDate($0.day, inSameDayAs: previous) }
            states.points.append(PointState(day: previous, normalRemainder: player.normalPointProgressSeconds,
                                            reducedRemainder: player.reducedPointProgressUnits))
        }
        let restored = states.points.first { calendar.isDate($0.day, inSameDayAs: day) }
        player.dailyPointProgressDate = day
        player.normalPointProgressSeconds = restored?.normalRemainder ?? 0
        player.reducedPointProgressUnits = restored?.reducedRemainder ?? 0
        save(states, for: player)
        return true
    }

    private static func load(for player: Player) -> States {
        guard let data = player.dailyRewardStatesData,
              let states = try? JSONDecoder().decode(States.self, from: data) else { return States() }
        return states
    }

    private static func save(_ states: States, for player: Player) {
        player.dailyRewardStatesData = try? JSONEncoder().encode(states)
    }
}
