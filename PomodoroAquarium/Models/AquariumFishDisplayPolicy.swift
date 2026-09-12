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

enum AquariumFishSelection {
    /// 既存ユーザーだけ、従来の表示ポリシーを初期選択として一度採用する。
    @discardableResult
    static func initializeIfNeeded(for player: Player) -> Bool {
        guard !player.hasInitializedActiveAquariumFish else { return false }

        player.activeAquariumFishIDs = AquariumFishDisplayPolicy.displayedFish(
            from: player.ownedFish,
            favoriteFish: player.favoriteFish
        ).map(\.id)
        player.hasInitializedActiveAquariumFish = true
        return true
    }

    static func activeFish(for player: Player) -> [PlayerFish] {
        if !player.hasInitializedActiveAquariumFish {
            // onAppearで保存する前の初回描画も、従来どおり空にしない。
            return AquariumFishDisplayPolicy.displayedFish(
                from: player.ownedFish,
                favoriteFish: player.favoriteFish
            )
        }

        let fishByID = Dictionary(uniqueKeysWithValues: player.ownedFish.map { ($0.id, $0) })
        var seenIDs = Set<UUID>()
        return player.activeAquariumFishIDs.compactMap { id in
            guard seenIDs.insert(id).inserted else { return nil }
            return fishByID[id]
        }
        .prefix(AquariumDisplayLimits.maxFishCount)
        .map { $0 }
    }

    static func aquariumCount(for species: FishSpecies, in player: Player) -> Int {
        activeFish(for: player).count { $0.species == species }
    }

    @discardableResult
    static func addFishToAquarium(playerFishID: UUID, in player: Player) -> Bool {
        initializeIfNeeded(for: player)
        normalizeStoredSelection(for: player)

        guard player.activeAquariumFishIDs.count < AquariumDisplayLimits.maxFishCount,
              player.ownedFish.contains(where: { $0.id == playerFishID }),
              !player.activeAquariumFishIDs.contains(playerFishID) else {
            return false
        }

        player.activeAquariumFishIDs = player.activeAquariumFishIDs + [playerFishID]
        return true
    }

    @discardableResult
    static func removeFishFromAquarium(playerFishID: UUID, in player: Player) -> Bool {
        initializeIfNeeded(for: player)
        guard player.ownedFish.contains(where: { $0.id == playerFishID }),
              player.activeAquariumFishIDs.contains(playerFishID) else {
            return false
        }

        player.activeAquariumFishIDs = player.activeAquariumFishIDs.filter {
            $0 != playerFishID
        }
        return true
    }

    @discardableResult
    static func addOneFishToAquarium(species: FishSpecies, in player: Player) -> Bool {
        initializeIfNeeded(for: player)
        let activeIDs = Set(player.activeAquariumFishIDs)
        guard let fish = player.ownedFish.first(where: {
            $0.species == species && !activeIDs.contains($0.id)
        }) else { return false }

        return addFishToAquarium(playerFishID: fish.id, in: player)
    }

    @discardableResult
    static func removeOneFishFromAquarium(species: FishSpecies, in player: Player) -> Bool {
        initializeIfNeeded(for: player)
        let fishByID = Dictionary(uniqueKeysWithValues: player.ownedFish.map { ($0.id, $0) })
        guard let id = player.activeAquariumFishIDs.reversed().first(where: {
            fishByID[$0]?.species == species
        }) else { return false }

        return removeFishFromAquarium(playerFishID: id, in: player)
    }

    private static func normalizeStoredSelection(for player: Player) {
        let ownedIDs = Set(player.ownedFish.map(\.id))
        var seenIDs = Set<UUID>()
        let normalizedIDs = player.activeAquariumFishIDs.filter { id in
            ownedIDs.contains(id) && seenIDs.insert(id).inserted
        }
        .prefix(AquariumDisplayLimits.maxFishCount)
        .map { $0 }

        if normalizedIDs != player.activeAquariumFishIDs {
            player.activeAquariumFishIDs = normalizedIDs
        }
    }
}

extension Player {
    var activeAquariumFish: [PlayerFish] {
        AquariumFishSelection.activeFish(for: self)
    }

    func aquariumCount(for species: FishSpecies) -> Int {
        AquariumFishSelection.aquariumCount(for: species, in: self)
    }

    @discardableResult
    func addFishToAquarium(playerFishID: UUID) -> Bool {
        AquariumFishSelection.addFishToAquarium(playerFishID: playerFishID, in: self)
    }

    @discardableResult
    func removeFishFromAquarium(playerFishID: UUID) -> Bool {
        AquariumFishSelection.removeFishFromAquarium(playerFishID: playerFishID, in: self)
    }

    @discardableResult
    func addOneFishToAquarium(species: FishSpecies) -> Bool {
        AquariumFishSelection.addOneFishToAquarium(species: species, in: self)
    }

    @discardableResult
    func removeOneFishFromAquarium(species: FishSpecies) -> Bool {
        AquariumFishSelection.removeOneFishFromAquarium(species: species, in: self)
    }
}
