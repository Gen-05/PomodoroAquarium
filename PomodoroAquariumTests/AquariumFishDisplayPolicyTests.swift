import Foundation
import Testing
@testable import PomodoroAquarium

@MainActor
struct AquariumFishDisplayPolicyTests {
    @Test func displayCountIsLimitedWithoutChangingOwnership() {
        for ownedCount in [0, 1, 5, 10, 11, 30, 100] {
            let ownedFish = makeFish(count: ownedCount)
            let selected = AquariumFishDisplayPolicy.displayedFish(
                from: ownedFish,
                favoriteFish: nil
            )

            #expect(selected.count == min(ownedCount, AquariumDisplayLimits.maxFishCount))
            #expect(ownedFish.count == ownedCount)
            #expect(selected.map(\.id) == Array(
                ownedFish.prefix(AquariumDisplayLimits.maxFishCount)
            ).map(\.id))
        }
    }

    @Test func favoriteOutsideFirstTenIsAlwaysIncluded() {
        let ownedFish = makeFish(count: 30)
        let favoriteFish = ownedFish[25]

        let selected = AquariumFishDisplayPolicy.displayedFish(
            from: ownedFish,
            favoriteFish: favoriteFish
        )

        #expect(selected.count == AquariumDisplayLimits.maxFishCount)
        #expect(selected.first?.id == favoriteFish.id)
        #expect(selected.contains { $0.id == favoriteFish.id })
        #expect(selected.dropFirst().map(\.id) == ownedFish
            .prefix(AquariumDisplayLimits.maxFishCount - 1)
            .map(\.id))
    }

    @Test func duplicateSpeciesUseSeparateIndividualSlotsAndBookCountIsUnchanged() {
        let ownedFish = (0..<20).map { _ in PlayerFish(species: .clownfish) }
        let player = Player(ownedFish: ownedFish)

        let selected = AquariumFishDisplayPolicy.displayedFish(
            from: player.ownedFish,
            favoriteFish: player.favoriteFish
        )

        #expect(selected.count == AquariumDisplayLimits.maxFishCount)
        #expect(Set(selected.map(\.id)).count == AquariumDisplayLimits.maxFishCount)
        #expect(BookView.ownedCount(for: .clownfish, in: player) == 20)
        #expect(player.ownedFish.count == 20)
    }

    @Test func repeatedSelectionIsStableAndAppendedFishDoesNotDisplaceExistingTen() {
        let ownedFish = makeFish(count: 10)
        let initialIDs = AquariumFishDisplayPolicy.displayedFish(
            from: ownedFish,
            favoriteFish: nil
        ).map(\.id)

        #expect(AquariumFishDisplayPolicy.displayedFish(
            from: ownedFish,
            favoriteFish: nil
        ).map(\.id) == initialIDs)

        let newlyAcquiredFish = PlayerFish(species: .whaleShark)
        let afterAcquisition = AquariumFishDisplayPolicy.displayedFish(
            from: ownedFish + [newlyAcquiredFish],
            favoriteFish: nil
        )

        #expect(afterAcquisition.map(\.id) == initialIDs)
        #expect(!afterAcquisition.contains { $0.id == newlyAcquiredFish.id })
    }

    private func makeFish(count: Int) -> [PlayerFish] {
        (0..<count).map { index in
            PlayerFish(species: FishSpecies.allCases[index % FishSpecies.allCases.count])
        }
    }
}
