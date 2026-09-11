import Foundation

enum AquariumDisplayLimits {
    static let maxFishCount = 10
}

enum AquariumFishDisplayPolicy {
    /// 将来、保存済みの「水槽へ出している魚」をcandidatesへ渡せるよう、所持配列とは分離して選ぶ。
    static func displayedFish(
        from candidates: [PlayerFish],
        favoriteFish: PlayerFish?
    ) -> [PlayerFish] {
        guard !candidates.isEmpty || favoriteFish != nil else { return [] }

        var result: [PlayerFish] = []
        result.reserveCapacity(min(
            AquariumDisplayLimits.maxFishCount,
            candidates.count + (favoriteFish == nil ? 0 : 1)
        ))

        if let favoriteFish {
            result.append(favoriteFish)
        }

        for fish in candidates where fish.id != favoriteFish?.id {
            guard result.count < AquariumDisplayLimits.maxFishCount else { break }
            result.append(fish)
        }

        return result
    }
}
