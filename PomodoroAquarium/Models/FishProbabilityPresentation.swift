import Foundation

/// Immutable, display-only projection. Percentages always come from the real draw API.
struct FishProbabilityProjection {
    let today: FishRewardService.RarityProbabilities
    let tomorrow: FishRewardService.RarityProbabilities

    static func make(on date: Date, records: [FocusSessionRecord], calendar: Calendar = .current) -> Self {
        let yesterday = calendar.date(byAdding: .day, value: -1, to: date) ?? date
        return Self(
            today: FishRewardService.rarityProbabilities(for: StudyHistoryService.focusMinutes(on: yesterday, from: records, calendar: calendar)),
            tomorrow: FishRewardService.rarityProbabilities(for: StudyHistoryService.focusMinutes(on: date, from: records, calendar: calendar))
        )
    }

    static let rarities: [FishRarity] = [.common, .rare, .epic, .legendary]
    static let increasingRarities: [FishRarity] = [.rare, .epic, .legendary]
    static func percentageText(_ value: Double, compact: Bool = false) -> String {
        let rounded = (value * 10).rounded() / 10
        return compact && rounded == rounded.rounded()
            ? String(format: "%.0f%%", rounded) : String(format: "%.1f%%", rounded)
    }
    static let explanation = "今日の獲得確率は、昨日の確定した集中記録から計算します。計測中の時間は含みません。"
}

/// Fixed values belonging to the finalized sessions, never recomputed when a reward opens.
struct FishProbabilityChange: Codable, Equatable {
    let sessionIDs: [UUID]
    let referenceDay: Date
    let beforeSeconds: Int
    let afterSeconds: Int

    func before(for rarity: FishRarity) -> Double {
        FishRewardService.rarityProbabilities(for: max(0, beforeSeconds) / 60).probability(for: rarity)
    }
    func after(for rarity: FishRarity) -> Double {
        FishRewardService.rarityProbabilities(for: max(0, afterSeconds) / 60).probability(for: rarity)
    }
    var isAtMaximum: Bool { afterSeconds / 60 >= FishRewardService.maximumBonusStudyMinutes }
    func isCurrent(on date: Date, calendar: Calendar = .current) -> Bool {
        calendar.isDate(referenceDay, inSameDayAs: date)
    }
    func showsIncrease(for rarity: FishRarity, on date: Date, calendar: Calendar = .current) -> Bool {
        rarity != .common && isCurrent(on: date, calendar: calendar) && after(for: rarity) > before(for: rarity)
    }
    func hasIncrease(on date: Date, calendar: Calendar = .current) -> Bool {
        FishProbabilityProjection.increasingRarities.contains { showsIncrease(for: $0, on: date, calendar: calendar) }
    }
    func status(on date: Date, calendar: Calendar = .current) -> String {
        if !isCurrent(on: date, calendar: calendar) { return "過去日の記録です。明日の確率アップはありません" }
        if hasIncrease(on: date, calendar: calendar) { return "今日の確定した集中記録を反映しました" }
        return isAtMaximum ? "明日の確率は上限です" : "今回の記録による確率の変化はありません"
    }

    /// Aggregate seconds, not percentages. Only the latest projection day can affect its tomorrow.
    static func combined(_ changes: [Self]) -> Self? {
        guard let day = changes.map(\.referenceDay).max() else { return nil }
        var ids = Set<UUID>()
        var selected: [Self] = []
        for change in changes where change.referenceDay == day {
            guard ids.isDisjoint(with: change.sessionIDs) else { continue }
            ids.formUnion(change.sessionIDs)
            selected.append(change)
        }
        guard let after = selected.map(\.afterSeconds).max() else { return nil }
        let contributed = selected.reduce(0) { total, change in
            let (sum, overflow) = total.addingReportingOverflow(max(0, change.afterSeconds - change.beforeSeconds))
            return overflow ? Int.max : sum
        }
        return Self(sessionIDs: ids.sorted { $0.uuidString < $1.uuidString }, referenceDay: day,
                    beforeSeconds: max(0, after - contributed), afterSeconds: after)
    }
}
