import Foundation
import SwiftData
import Testing
@testable import PomodoroAquarium

@MainActor
struct RewardHistoryTests {
    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Player.self,
            PlayerFish.self,
            RewardHistoryEntry.self,
            configurations: configuration
        )
    }

    @Test func recordingRewardPersistsItsDisplaySnapshotAsUnacknowledged() throws {
        let context = ModelContext(try makeContainer())
        let fish = PlayerFish(species: .seahorse)
        let result = FishAcquisitionResult(
            fish: fish,
            previousOwnedCount: 0,
            currentOwnedCount: 1
        )

        let entry = try RewardHistoryService.record(
            result: result,
            pointDelta: 10,
            acquiredAt: Date(timeIntervalSince1970: 100),
            in: context
        )
        let saved = try #require(context.fetch(FetchDescriptor<RewardHistoryEntry>()).first)

        #expect(saved.id == entry.id)
        #expect(saved.fishID == fish.id)
        #expect(saved.fishName == FishSpecies.seahorse.name)
        #expect(saved.rarityRawValue == FishRarity.rare.rawValue)
        #expect(saved.fishCountDelta == 1)
        #expect(saved.pointDelta == 10)
        #expect(!saved.isAcknowledged)
        #expect(saved.wasNewFish)
    }

    @Test func replayUsesSavedNewStateWithoutGrantingAgain() throws {
        let context = ModelContext(try makeContainer())
        let ownedFish = PlayerFish(species: .clownfish)
        let player = Player(ownedFish: [ownedFish], coins: 40)
        context.insert(player)
        try context.save()
        let entry = RewardHistoryEntry(
            fishID: ownedFish.id,
            fishSpecies: .clownfish,
            fishName: "保存済みクマノミ",
            rarity: .common,
            fishCountDelta: 1,
            pointDelta: 10,
            isAcknowledged: false,
            wasNewFish: true,
            previousOwnedCount: 0,
            currentOwnedCount: 1
        )
        context.insert(entry)
        try context.save()
        let fishCountBefore = player.ownedFish.count
        let pointsBefore = player.coins

        let replay = RewardHistorySnapshot(entry: entry).replayResult()

        #expect(replay.fishName == "保存済みクマノミ")
        #expect(replay.rarity == .common)
        #expect(replay.showsNewBadge)
        #expect(player.ownedFish.count == fishCountBefore)
        #expect(player.coins == pointsBefore)
        #expect(try context.fetchCount(FetchDescriptor<PlayerFish>()) == fishCountBefore)
    }

    @Test func acknowledgementRemovesEntryFromPendingLookup() throws {
        let context = ModelContext(try makeContainer())
        let result = FishAcquisitionResult(
            fish: PlayerFish(species: .manta),
            previousOwnedCount: 0,
            currentOwnedCount: 1
        )
        let entry = try RewardHistoryService.record(
            result: result,
            pointDelta: 10,
            in: context
        )

        #expect(try RewardHistoryService.latestUnacknowledged(in: context)?.id == entry.id)
        try RewardHistoryService.acknowledge(id: entry.id, in: context)

        #expect(entry.isAcknowledged)
        #expect(try RewardHistoryService.latestUnacknowledged(in: context) == nil)
    }

    @Test func newestUnacknowledgedEntryIsReturned() throws {
        let context = ModelContext(try makeContainer())
        let older = RewardHistoryEntry(
            fishID: UUID(),
            fishSpecies: .clownfish,
            fishName: FishSpecies.clownfish.name,
            rarity: .common,
            fishCountDelta: 1,
            pointDelta: 10,
            acquiredAt: Date(timeIntervalSince1970: 100),
            isAcknowledged: false,
            wasNewFish: true,
            previousOwnedCount: 0,
            currentOwnedCount: 1
        )
        let newer = RewardHistoryEntry(
            fishID: UUID(),
            fishSpecies: .whaleShark,
            fishName: FishSpecies.whaleShark.name,
            rarity: .legendary,
            fishCountDelta: 1,
            pointDelta: 10,
            acquiredAt: Date(timeIntervalSince1970: 200),
            isAcknowledged: false,
            wasNewFish: true,
            previousOwnedCount: 0,
            currentOwnedCount: 1
        )
        context.insert(older)
        context.insert(newer)
        try context.save()

        #expect(try RewardHistoryService.latestUnacknowledged(in: context)?.id == newer.id)
    }

    @Test func historyKeepsOnlyTheLatestTenEntries() throws {
        let context = ModelContext(try makeContainer())
        var ids: [UUID] = []
        for index in 0..<12 {
            let result = FishAcquisitionResult(
                fish: PlayerFish(species: .pufferfish),
                previousOwnedCount: index,
                currentOwnedCount: index + 1
            )
            let entry = try RewardHistoryService.record(
                result: result,
                pointDelta: 10,
                acquiredAt: Date(timeIntervalSince1970: TimeInterval(index)),
                in: context
            )
            ids.append(entry.id)
        }

        let recent = try RewardHistoryService.recent(in: context)
        #expect(recent.count == RewardHistoryService.maximumEntryCount)
        #expect(recent.first?.id == ids[11])
        #expect(recent.last?.id == ids[2])
        #expect(!recent.contains { $0.id == ids[0] || $0.id == ids[1] })
    }

#if DEBUG
    @Test func previewHistoryAndReplayDoNotMutateProductionModels() throws {
        let context = ModelContext(try makeContainer())
        let fish = PlayerFish(species: .clownfish)
        let player = Player(
            ownedFish: [fish],
            activeAquariumFishIDs: [fish.id],
            hasGrantedCoreTutorialReward: true,
            totalStudyMinutes: 120,
            todayStudyMinutes: 50,
            coins: 90
        )
        context.insert(player)
        try context.save()
        let fishIDsBefore = player.ownedFish.map(\.id)
        let activeFishIDsBefore = player.activeAquariumFishIDs
        let pointsBefore = player.coins
        let todayMinutesBefore = player.todayStudyMinutes
        let tutorialRewardBefore = player.hasGrantedCoreTutorialReward
        let suiteName = "RewardHistoryPreviewTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(3, forKey: DailyFishAcquisitionStorageKey.count)

        let preview = try #require(RewardPreviewCatalog.historyItems.first)
        _ = preview.replayResult()

        #expect(player.ownedFish.map(\.id) == fishIDsBefore)
        #expect(player.activeAquariumFishIDs == activeFishIDsBefore)
        #expect(player.coins == pointsBefore)
        #expect(player.todayStudyMinutes == todayMinutesBefore)
        #expect(player.hasGrantedCoreTutorialReward == tutorialRewardBefore)
        #expect(defaults.integer(forKey: DailyFishAcquisitionStorageKey.count) == 3)
        #expect(try context.fetchCount(FetchDescriptor<RewardHistoryEntry>()) == 0)
    }
#endif
}
