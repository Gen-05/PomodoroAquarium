import Foundation
import SwiftData
import Testing
@testable import PomodoroAquarium

@MainActor
struct AquariumFishSelectionTests {
    @Test func firstInitializationMigratesThePreviousStableSelection() {
        let fish = makeFish(count: 30)
        let player = Player(ownedFish: fish, favoriteFish: fish[25])
        let expectedIDs = [fish[25].id] + fish.prefix(9).map(\.id)

        // 初期化前の描画と初期化後の保存で、どちらも従来の10匹を維持する。
        #expect(AquariumDisplayLimits.maxFishCount == 20)
        #expect(player.activeAquariumFish.map(\.id) == expectedIDs)
        #expect(AquariumFishSelection.initializeIfNeeded(for: player))
        #expect(player.hasInitializedActiveAquariumFish)
        #expect(player.activeAquariumFishIDs == expectedIDs)
        #expect(player.activeAquariumFish.map(\.id) == expectedIDs)
        #expect(!AquariumFishSelection.initializeIfNeeded(for: player))
    }

    @Test func initializedTenFishStayUnchangedWhenCapacityAndOwnershipGrow() {
        let fish = makeFish(count: 25)
        let ids = fish.prefix(10).map(\.id)
        let player = Player(ownedFish: fish, activeAquariumFishIDs: ids, hasInitializedActiveAquariumFish: true)
        player.ownedFish.append(PlayerFish(species: .whaleShark))
        #expect(!AquariumFishSelection.initializeIfNeeded(for: player))
        #expect(player.activeAquariumFishIDs == ids)
        #expect(player.activeAquariumFish.map(\.id) == ids)
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

    @Test func maximumTwentySameSpeciesRejectsTheTwentyFirst() {
        let fish = (0..<21).map { _ in PlayerFish(species: .clownfish) }
        let player = Player(
            ownedFish: fish,
            activeAquariumFishIDs: [],
            hasInitializedActiveAquariumFish: true
        )

        for _ in 0..<20 {
            #expect(player.addOneFishToAquarium(species: .clownfish))
        }

        #expect(!player.addFishToAquarium(playerFishID: fish[20].id))
        #expect(!player.addOneFishToAquarium(species: .clownfish))
        #expect(player.activeAquariumFish.map(\.id) == fish.prefix(20).map(\.id))
        #expect(player.ownedFish.count == 21)
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

    @Test func twentyFishPersistAfterStoreReloadAndDraftUndoRedo() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("TwentyFish-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("Player.store")
        let ownedIDs = (0..<21).map { _ in UUID() }
        let activeIDs = Array(ownedIDs.prefix(20))
        do {
            let container = try ModelContainer(for: Player.self, PlayerFish.self,
                configurations: ModelConfiguration(url: url))
            let context = ModelContext(container)
            let player = Player(ownedFish: ownedIDs.map { PlayerFish(id: $0, species: .clownfish) },
                activeAquariumFishIDs: activeIDs, hasInitializedActiveAquariumFish: true, coins: 432)
            context.insert(player)
            try context.save()
        }

        let reopened = try ModelContainer(for: Player.self, PlayerFish.self,
            configurations: ModelConfiguration(url: url))
        let context = ModelContext(reopened)
        let player = try #require(context.fetch(FetchDescriptor<Player>()).first)
        #expect(player.activeAquariumFishIDs == activeIDs)
        #expect(player.activeAquariumFish.map(\.id) == activeIDs)
        #expect(Set(player.ownedFish.map(\.id)) == Set(ownedIDs))
        #expect(!AquariumFishSelection.initializeIfNeeded(for: player))
        #expect(!player.addFishToAquarium(playerFishID: ownedIDs[20]))
        #expect(player.activeAquariumFishIDs == activeIDs && player.coins == 432)

        let initial = AquariumEditorDraft(player: player, placements: [], background: .aquarium)
        let work = AquariumEditorWorkingState(official: player, placements: [], draft: initial)
        var history = AquariumEditorHistory(initial: initial)
        #expect(work.player.removeFishFromAquarium(playerFishID: activeIDs[19]))
        let recorded = history.record(AquariumEditorDraft(player: work.player, placements: [], background: .aquarium))
        #expect(recorded)
        let undo = history.undo()
        work.apply(try #require(undo))
        #expect(work.player.activeAquariumFish.map(\.id) == activeIDs)

        var draft = history.current
        draft.history = history
        let store = AquariumEditorDraftStore(url: directory.appendingPathComponent("draft.json"))
        try store.save(draft)
        let loaded = try #require(try store.load())
        #expect(loaded.fishIDs == activeIDs)
        var restoredHistory = try #require(loaded.history)
        #expect(restoredHistory.isValid(for: loaded))
        let redo = restoredHistory.redo()
        work.apply(try #require(redo))
        #expect(work.player.activeAquariumFish.count == 19)
        let undoAgain = restoredHistory.undo()
        work.apply(try #require(undoAgain))
        #expect(work.player.activeAquariumFish.map(\.id) == activeIDs)
        // 作業コピーの変更・復元は、正式な配置へ漏れない（キャンセル時も同じ）。
        #expect(player.activeAquariumFishIDs == activeIDs && player.ownedFish.count == 21)
    }

    @Test func homePlayerInitializationCanRunRepeatedlyWithoutDuplicates() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let first = try HomePlayerInitialization.prepare(in: context)
        let second = try HomePlayerInitialization.prepare(in: context)

        #expect(first.didCreatePlayer)
        #expect(first.didInitializeAquariumSelection)
        #expect(!second.didCreatePlayer)
        #expect(!second.didInitializeAquariumSelection)
        #expect(first.player.persistentModelID == second.player.persistentModelID)
        #expect(try context.fetchCount(FetchDescriptor<Player>()) == 1)
        #expect(first.player.hasInitializedActiveAquariumFish)
    }

    @Test func homePlayerInitializationRemainsSaveableAfterTutorialRewardChanges() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let first = try HomePlayerInitialization.prepare(in: context)
        let tutorialFish = PlayerFish(species: .clownfish)
        first.player.ownedFish.append(tutorialFish)
        first.player.activeAquariumFishIDs = [tutorialFish.id]
        first.player.hasGrantedCoreTutorialReward = true
        first.player.hasSavedCoreTutorialAquarium = true
        try context.save()

        let afterTutorial = try HomePlayerInitialization.prepare(in: context)
        try context.save()

        #expect(!afterTutorial.didCreatePlayer)
        #expect(!afterTutorial.didInitializeAquariumSelection)
        #expect(afterTutorial.player.ownedFish.map(\.id) == [tutorialFish.id])
        #expect(afterTutorial.player.activeAquariumFishIDs == [tutorialFish.id])
        #expect(try context.fetchCount(FetchDescriptor<Player>()) == 1)
    }

    @Test func previewPlayerInitializationCannotMutateProductionContainer() throws {
        let productionContainer = try makeContainer()
        let productionContext = ModelContext(productionContainer)
        let production = try HomePlayerInitialization.prepare(in: productionContext)

        let previewContainer = try makeContainer()
        let previewContext = ModelContext(previewContainer)
        let preview = try HomePlayerInitialization.prepare(in: previewContext)
        preview.player.coins = 10
        preview.player.ownedFish.append(PlayerFish(species: .clownfish))
        try previewContext.save()

        let restoredProduction = try #require(
            productionContext.fetch(FetchDescriptor<Player>()).first
        )
        #expect(restoredProduction.persistentModelID == production.player.persistentModelID)
        #expect(restoredProduction.coins == 0)
        #expect(restoredProduction.ownedFish.isEmpty)
        #expect(try productionContext.fetchCount(FetchDescriptor<Player>()) == 1)
        #expect(try previewContext.fetchCount(FetchDescriptor<Player>()) == 1)
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
