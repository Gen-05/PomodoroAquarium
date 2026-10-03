import Foundation
import SwiftData
import Testing
@testable import PomodoroAquarium

@MainActor
struct FishRewardBatchTests {
    @Test(arguments: [0, 1, 3, 8])
    func earnedCountDrivesIndependentDrawsAndSavedFish(count: Int) throws {
        let fixture = try BatchFixture()
        let sessionID = try fixture.process(seconds: count == 0 ? 600 : count * 1500)
        let species: [FishSpecies] = [.clownfish, .seahorse, .manta, .whaleShark]
        var draws = 0
        // Playerの古い77分ではなく、前日FocusSessionRecordなし=0分を使う。
        let expected = FishRewardService.rarityProbabilities(for: 0)
        let batch = try fixture.grant(sessionID) { probabilities in
            #expect(probabilities.common == expected.common)
            #expect(probabilities.legendary == expected.legendary)
            defer { draws += 1 }
            return species[draws % species.count]
        }
        let claimed = min(count, DailyFishAcquisitionPolicy.basicLimit)
        #expect(draws == claimed)
        #expect(fixture.player.ownedFish.count == claimed)
        #expect(try fixture.context.fetchCount(FetchDescriptor<PlayerFish>()) == claimed)
        #expect(try fixture.context.fetchCount(FetchDescriptor<RewardHistoryEntry>()) == claimed)
        #expect(batch?.results.count == (claimed == 0 ? nil : claimed))
        #expect(fixture.player.pendingFishEarnedCount == count - claimed)
        #expect(fixture.player.coins == 80)
        #expect(fixture.player.dailyGrantedFishCount == claimed)
        #expect(fixture.defaults.integer(forKey: DailyFishAcquisitionStorageKey.count) == claimed)
        if let batch {
            #expect(batch.results.map(\.species) == (0..<claimed).map { species[$0 % species.count] })
            #expect(batch.historyIDs.count == claimed)
        }
    }

    @Test func repeatedSpeciesAddsOwnedInstancesAndOnlyFirstIsNew() throws {
        let fixture = try BatchFixture()
        let id = try fixture.process(seconds: 4500)
        let batch = try #require(try fixture.grant(id) { _ in .clownfish })
        #expect(batch.results.map(\.isNewFish) == [true, false, false])
        #expect(batch.results.map(\.previousOwnedCount) == [0, 1, 2])
        #expect(batch.results.map(\.currentOwnedCount) == [1, 2, 3])
        #expect(Set(fixture.player.ownedFish.map(\.id)).count == 3)
        let history = try fixture.context.fetch(FetchDescriptor<RewardHistoryEntry>(
            sortBy: [SortDescriptor(\RewardHistoryEntry.rewardBatchIndex)]
        ))
        #expect(history.map(\.wasNewFish) == [true, false, false])
        #expect(history.map(\.fishCountDelta) == [1, 1, 1])
        #expect(history.allSatisfy { $0.rewardSessionID == id })
    }

    @Test func previouslyOwnedFishCountGoesFromOneToThree() throws {
        let fixture = try BatchFixture()
        fixture.player.ownedFish.append(PlayerFish(species: .clownfish))
        try fixture.context.save()
        let id = try fixture.process(seconds: 3000)
        let batch = try #require(try fixture.grant(id) { _ in .clownfish })
        #expect(batch.results.allSatisfy { !$0.isNewFish })
        #expect(batch.results.first?.previousOwnedCount == 1)
        #expect(batch.results.last?.currentOwnedCount == 3)
        #expect(fixture.player.ownedFish.count == 3)
    }

    @Test func tenPlusFifteenMinutesAwardsOneFish() throws {
        let fixture = try BatchFixture()
        let first = try fixture.process(seconds: 600)
        #expect(try fixture.grant(first) { _ in .clownfish } == nil)
        let second = try fixture.process(seconds: 900)
        #expect(try fixture.grant(second) { _ in .clownfish }?.results.count == 1)
        #expect(fixture.player.dailyFishProgressSeconds == 0)
    }

    @Test func sameSessionAndRecoveryReplayNeverGrantTwice() throws {
        let fixture = try BatchFixture()
        let id = try fixture.process(seconds: 4500)
        let batch = try #require(try fixture.grant(id) { _ in .seahorse })
        // 新しいcontextでapp復元・callback再送を模擬する。
        let context = ModelContext(fixture.container)
        let player = try #require(context.fetch(FetchDescriptor<Player>()).first)
        try DailyFishProgressService.process(sessionID: id, for: player, in: context)
        var redraws = 0
        let duplicate = try FishRewardBatchService.grant(
            sessionID: id, to: player, defaults: fixture.defaults, in: context,
            draw: { _ in redraws += 1; return .whaleShark }
        )
        #expect(duplicate == nil)
        #expect(redraws == 0)
        #expect(player.ownedFish.count == 3)
        #expect(player.pendingFishEarnedCount == 0)
        #expect(player.dailyGrantedFishCount == 3)
        let replay = try #require(try FishRewardBatchService.latestUnacknowledgedBatch(in: context))
        #expect(replay.id == id)
        #expect(replay.results.map(\.isNewFish) == [true, false, false])
        #expect(replay.historyIDs == batch.historyIDs)
        #expect(try context.fetchCount(FetchDescriptor<PlayerFish>()) == 3)
        #expect(try context.fetchCount(FetchDescriptor<RewardHistoryEntry>()) == 3)
        try FishRewardBatchService.acknowledge(replay.historyIDs, in: context)
        #expect(try FishRewardBatchService.latestUnacknowledgedBatch(in: context) == nil)
    }

    @Test func pendingStepTwoUnitsAreRecoveredOnce() throws {
        let fixture = try BatchFixture()
        try fixture.process(seconds: 6000)
        try FishRewardBatchService.grantPending(to: fixture.player, defaults: fixture.defaults, in: fixture.context)
        #expect(fixture.player.ownedFish.count == 3)
        try FishRewardBatchService.grantPending(to: fixture.player, defaults: fixture.defaults, in: fixture.context)
        #expect(fixture.player.ownedFish.count == 3)
        #expect(fixture.player.pendingFishEarnedCount == 1)
        #expect(try fixture.context.fetchCount(FetchDescriptor<RewardHistoryEntry>()) == 3)
    }

    @Test func failedBatchRollsBackFishHistoryAndGrantMarker() throws {
        let fixture = try BatchFixture()
        let id = try fixture.process(seconds: 4500)
        var draws = 0
        do {
            _ = try fixture.grant(id) { _ in
                defer { draws += 1 }
                return draws == 1 ? nil : .clownfish
            }
            Issue.record("抽選失敗が返されるべき")
        } catch FishRewardBatchService.GrantError.drawFailed { }
        #expect(fixture.player.ownedFish.isEmpty)
        #expect(fixture.player.pendingFishEarnedCount == 3)
        #expect(try fixture.context.fetchCount(FetchDescriptor<RewardHistoryEntry>()) == 0)
        #expect(try fixture.context.fetch(FetchDescriptor<FocusSessionRecord>()).first?.hasGrantedFishReward == false)
        #expect(try fixture.grant(id) { _ in .clownfish }?.results.count == 3)
    }

    @Test(arguments: [StudySessionEndReason.completed, .userEnded, .backgroundLimitExceeded])
    func everyEndReasonUsesPersistedValidSeconds(reason: StudySessionEndReason) throws {
        let fixture = try BatchFixture()
        let id = try fixture.process(seconds: 4500, reason: reason)
        #expect(try fixture.grant(id) { _ in .clownfish }?.results.count == 3)
    }

    @Test func pointsRemainSessionBasedNotMultipliedByFishCount() throws {
        let fixture = try BatchFixture()
        let id = try fixture.process(seconds: 4500)
        let batch = try #require(try fixture.grant(id) { _ in .clownfish })
        try FishRewardBatchService.recordPoints(10, for: batch, in: fixture.context)
        let entries = try fixture.context.fetch(FetchDescriptor<RewardHistoryEntry>())
        #expect(entries.reduce(0) { $0 + $1.pointDelta } == 10)
        #expect(fixture.player.coins == 80)
    }
}

@MainActor
private final class BatchFixture {
    let container: ModelContainer
    let context: ModelContext
    let player: Player
    let defaults: UserDefaults
    let suite = "FishRewardBatch-\(UUID())"

    init() throws {
        container = try ModelContainer(
            for: Player.self, PlayerFish.self, FocusSessionRecord.self, StudyDailyRecord.self, RewardHistoryEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = ModelContext(container)
        defaults = UserDefaults(suiteName: suite)!
        player = Player(yesterdayStudyMinutes: 77, coins: 80)
        context.insert(player)
        try context.save()
    }

    deinit { defaults.removePersistentDomain(forName: suite) }

    @discardableResult
    func process(seconds: Int, reason: StudySessionEndReason = .completed) throws -> UUID {
        let session = FinalizedFocusSession(
            id: UUID(), completedAt: Date(), validFocusSeconds: seconds, endReason: reason,
            categoryID: FocusCategoryDefaults.studyID, focusMethod: .timer
        )
        try StudyHistoryService.recordValidFocusSession(session, in: context)
        try DailyFishProgressService.process(sessionID: session.id, for: player, in: context)
        return session.id
    }

    func grant(_ id: UUID, draw: @MainActor (FishRewardService.RarityProbabilities) -> FishSpecies?) throws -> FishRewardBatch? {
        try FishRewardBatchService.grant(sessionID: id, to: player, defaults: defaults, in: context, draw: draw)
    }
}
