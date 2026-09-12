import Foundation
import SwiftData
import Testing
@testable import PomodoroAquarium

@MainActor
struct AquariumFishSelectionTests {
    @Test func firstInitializationMigratesThePreviousStableSelection() {
        let fish = makeFish(count: 15)
        let player = Player(ownedFish: fish, favoriteFish: fish[12])
        let expectedIDs = AquariumFishDisplayPolicy.displayedFish(
            from: fish,
            favoriteFish: fish[12]
        ).map(\.id)

        #expect(AquariumFishSelection.initializeIfNeeded(for: player))
        #expect(player.hasInitializedActiveAquariumFish)
        #expect(player.activeAquariumFishIDs == expectedIDs)
        #expect(player.activeAquariumFish.map(\.id) == expectedIDs)
        #expect(!AquariumFishSelection.initializeIfNeeded(for: player))
    }

    @Test func initializedEmptySelectionRemainsEmptyAfterAcquisition() {
        let player = Player(
            ownedFish: [],
            activeAquariumFishIDs: [],
            hasInitializedActiveAquariumFish: true
        )

        player.ownedFish.append(PlayerFish(species: .clownfish))

        #expect(player.activeAquariumFish.isEmpty)
        #expect(player.activeAquariumFishIDs.isEmpty)
    }

    @Test func fishRewardDoesNotAutomaticallyActivateNewFish() throws {
        let player = Player(
            ownedFish: [],
            activeAquariumFishIDs: [],
            hasInitializedActiveAquariumFish: true
        )

        let awardedFish = try #require(FishRewardService.awardFish(for: 25, to: player))

        #expect(player.ownedFish.contains { $0.id == awardedFish.id })
        #expect(player.activeAquariumFishIDs.isEmpty)
        #expect(player.activeAquariumFish.isEmpty)
    }

    @Test func speciesControlsAddDistinctIndividualsAndRespectOwnedCount() {
        let clownfish = (0..<3).map { _ in PlayerFish(species: .clownfish) }
        let player = Player(
            ownedFish: clownfish,
            activeAquariumFishIDs: [],
            hasInitializedActiveAquariumFish: true
        )

        #expect(player.addOneFishToAquarium(species: .clownfish))
        #expect(player.addOneFishToAquarium(species: .clownfish))
        #expect(player.addOneFishToAquarium(species: .clownfish))
        #expect(!player.addOneFishToAquarium(species: .clownfish))
        #expect(player.aquariumCount(for: .clownfish) == 3)
        #expect(Set(player.activeAquariumFishIDs).count == 3)
    }

    @Test func individualAPIsRejectInvalidAndDuplicateIDs() {
        let fish = PlayerFish(species: .pufferfish)
        let player = Player(
            ownedFish: [fish],
            activeAquariumFishIDs: [],
            hasInitializedActiveAquariumFish: true
        )
        let unknownID = UUID()

        #expect(!player.addFishToAquarium(playerFishID: unknownID))
        #expect(player.addFishToAquarium(playerFishID: fish.id))
        #expect(!player.addFishToAquarium(playerFishID: fish.id))
        #expect(!player.removeFishFromAquarium(playerFishID: unknownID))
        #expect(player.removeFishFromAquarium(playerFishID: fish.id))
        #expect(!player.removeFishFromAquarium(playerFishID: fish.id))
    }

    @Test func maximumTenFishRejectsTheEleventh() {
        let fish = makeFish(count: 11)
        let player = Player(
            ownedFish: fish,
            activeAquariumFishIDs: [],
            hasInitializedActiveAquariumFish: true
        )

        for candidate in fish.prefix(AquariumDisplayLimits.maxFishCount) {
            #expect(player.addFishToAquarium(playerFishID: candidate.id))
        }

        #expect(!player.addFishToAquarium(playerFishID: fish[10].id))
        #expect(player.activeAquariumFish.count == AquariumDisplayLimits.maxFishCount)
    }

    @Test func removingActiveFishDoesNotRemoveOwnership() {
        let fish = PlayerFish(species: .seahorse)
        let player = Player(
            ownedFish: [fish],
            activeAquariumFishIDs: [fish.id],
            hasInitializedActiveAquariumFish: true
        )

        #expect(player.removeOneFishFromAquarium(species: .seahorse))
        #expect(player.activeAquariumFish.isEmpty)
        #expect(player.ownedFish.count == 1)
        #expect(player.ownedFish.first?.id == fish.id)
    }

    @Test func removingTappedIndividualKeepsAnotherFishOfTheSameSpeciesActive() {
        let tappedFish = PlayerFish(species: .clownfish)
        let otherFish = PlayerFish(species: .clownfish)
        let player = Player(
            ownedFish: [tappedFish, otherFish],
            activeAquariumFishIDs: [tappedFish.id, otherFish.id],
            hasInitializedActiveAquariumFish: true
        )

        #expect(player.removeFishFromAquarium(playerFishID: tappedFish.id))
        #expect(player.activeAquariumFishIDs == [otherFish.id])
        #expect(player.activeAquariumFish.map(\.id) == [otherFish.id])
        #expect(player.ownedFish.map(\.id) == [tappedFish.id, otherFish.id])
    }

    @Test func favoriteAndActiveSelectionsAreIndependentAfterMigration() {
        let first = PlayerFish(species: .clownfish)
        let second = PlayerFish(species: .manta)
        let player = Player(
            ownedFish: [first, second],
            favoriteFish: first,
            activeAquariumFishIDs: [second.id],
            hasInitializedActiveAquariumFish: true
        )

        player.favoriteFish = second
        #expect(player.activeAquariumFish.map(\.id) == [second.id])

        player.favoriteFish = first
        #expect(player.activeAquariumFish.map(\.id) == [second.id])
    }

    @Test func activeIDsAndExplicitZeroSelectionPersistAcrossContexts() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let activeFish = PlayerFish(species: .jellyfish)
        let inactiveFish = PlayerFish(species: .manta)
        let selectedPlayer = Player(
            ownedFish: [activeFish, inactiveFish],
            activeAquariumFishIDs: [activeFish.id],
            hasInitializedActiveAquariumFish: true
        )
        let emptyPlayer = Player(
            ownedFish: [PlayerFish(species: .clownfish)],
            activeAquariumFishIDs: [],
            hasInitializedActiveAquariumFish: true
        )
        context.insert(selectedPlayer)
        context.insert(emptyPlayer)
        try context.save()

        let restoredContext = ModelContext(container)
        let restoredPlayers = try restoredContext.fetch(FetchDescriptor<Player>())
        let restoredSelected = try #require(restoredPlayers.first {
            $0.ownedFish.contains { $0.id == activeFish.id }
        })
        let restoredEmpty = try #require(restoredPlayers.first {
            $0.ownedFish.count == 1 && $0.ownedFish.first?.species == .clownfish
        })

        #expect(restoredSelected.activeAquariumFishIDs == [activeFish.id])
        #expect(restoredSelected.activeAquariumFish.map(\.id) == [activeFish.id])
        #expect(restoredEmpty.hasInitializedActiveAquariumFish)
        #expect(restoredEmpty.activeAquariumFishIDs.isEmpty)
        #expect(restoredEmpty.activeAquariumFish.isEmpty)
    }

    private func makeFish(count: Int) -> [PlayerFish] {
        (0..<count).map { index in
            PlayerFish(species: FishSpecies.allCases[index % FishSpecies.allCases.count])
        }
    }

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Player.self, PlayerFish.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }
}
