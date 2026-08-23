struct FishAcquisitionResult {
    let fish: PlayerFish
    let previousOwnedCount: Int
    let currentOwnedCount: Int

    var species: FishSpecies { fish.species }
    var isNewFish: Bool { previousOwnedCount == 0 }
    var showsNewBadge: Bool { isNewFish }

    /// 抽選・追加が行われる前に種類別所持数を記録し、追加後の結果と組み合わせる。
    static func capture(
        for player: Player,
        award: () -> PlayerFish?
    ) -> FishAcquisitionResult? {
        let countsBefore = Dictionary(grouping: player.ownedFish, by: \.species)
            .mapValues(\.count)

        guard let fish = award() else { return nil }
        let previousCount = countsBefore[fish.species] ?? 0
        let currentCount = player.ownedFish.count { $0.species == fish.species }

        return FishAcquisitionResult(
            fish: fish,
            previousOwnedCount: previousCount,
            currentOwnedCount: currentCount
        )
    }
}
