import Foundation
import SwiftData
import Testing
@testable import PomodoroAquarium

@MainActor
struct DailyFishClaimTests {
    @Test(arguments: [1, 3, 4, 8, 10])
    func initialClaimHonorsFreeLimitAndKeepsOnlyRightsPending(units: Int) throws {
        let fixture = try ClaimFixture()
        let id = try fixture.process(seconds: units * 1500)
        #expect(fixture.player.dailyEarnedFishCount == min(8, units))
        #expect(fixture.player.ownedFish.isEmpty)
        #expect(try fixture.context.fetchCount(FetchDescriptor<RewardHistoryEntry>()) == 0)
        var draws = 0
        let batch = try fixture.grant(id) { _ in draws += 1; return .clownfish }
        let claimed = min(3, units)
        #expect(draws == claimed)
        #expect(batch?.results.count == claimed)
        #expect(fixture.player.dailyClaimedFishCount == claimed)
        #expect(fixture.player.dailyFishLimit == 3)
        #expect(fixture.player.dailyPendingFishCount == min(8, units) - claimed)
        #expect(fixture.player.pendingFishEarnedCount == fixture.player.dailyPendingFishCount)
        #expect(try fixture.context.fetchCount(FetchDescriptor<PlayerFish>()) == claimed)
        #expect(try fixture.context.fetchCount(FetchDescriptor<RewardHistoryEntry>()) == claimed)
        // capするのは獲得権のみ。Statistics用の有効秒数はすべて保持。
        #expect(try fixture.context.fetch(FetchDescriptor<FocusSessionRecord>()).first?.durationSeconds == units * 1500)
    }

    @Test func oneSlotUnlockClaimsTheFourthFishAtUnlockTime() throws {
        let fixture = try ClaimFixture()
        let id = try fixture.process(seconds: 6000)
        _ = try fixture.grant(id) { _ in .clownfish }
        #expect(fixture.player.dailyPendingFishCount == 1)
        var draws = 0
        let batch = try fixture.unlock { _ in draws += 1; return .whaleShark }
        #expect(draws == 1)
        #expect(fixture.player.dailyFishLimit == 4)
        #expect(fixture.player.dailyClaimedFishCount == 4)
        #expect(fixture.player.dailyPendingFishCount == 0)
        #expect(batch?.results.map(\.species) == [.whaleShark])
        #expect(batch?.results.first?.isNewFish == true)
        #expect(fixture.player.coins == 80)
    }

    @Test func fiveUnlocksClaimEightAndNeverReachNine() throws {
        let fixture = try ClaimFixture()
        let id = try fixture.process(seconds: 15000) // 10 thresholds; v1 rights cap is 8.
        _ = try fixture.grant(id) { _ in .clownfish }
        #expect(fixture.player.dailyEarnedFishCount == 8)
        #expect(fixture.player.dailyPendingFishCount == 5)
        for limit in 4...8 {
            #expect(try fixture.unlock { _ in .seahorse }?.results.count == 1)
            #expect(fixture.player.dailyFishLimit == limit)
            #expect(fixture.player.dailyClaimedFishCount == limit)
        }
        var furtherDraws = 0
        for _ in 0..<3 {
            #expect(try fixture.unlock { _ in furtherDraws += 1; return .manta } == nil)
        }
        #expect(furtherDraws == 0)
        #expect(fixture.player.dailyFishLimit == 8)
        #expect(fixture.player.dailyEarnedFishCount == 8)
        #expect(fixture.player.dailyClaimedFishCount == 8)
        #expect(fixture.player.ownedFish.count == 8)
        #expect(try fixture.context.fetchCount(FetchDescriptor<RewardHistoryEntry>()) == 8)
        #expect(DailyFishAcquisitionPolicy.unlockedLimit(from: Int.max) == 8)
    }

    @Test func nextDayExpiresRightsUnlocksAndRemainderWithoutDeletingFishOrStatistics() throws {
        let fixture = try ClaimFixture()
        let id = try fixture.process(seconds: 13200) // 8 units + 20-minute remainder.
        _ = try fixture.grant(id) { _ in .clownfish }
        _ = try fixture.unlock { _ in .seahorse }
        #expect(fixture.player.dailyPendingFishCount == 4)
        #expect(fixture.player.dailyFishProgressSeconds == 1200)
        let nextDay = fixture.calendar.date(byAdding: .day, value: 1, to: fixture.date)!
        let context = ModelContext(fixture.container)
        let player = try #require(context.fetch(FetchDescriptor<Player>()).first)
        try DailyFishProgressService.resetIfNeeded(for: player, on: nextDay, calendar: fixture.calendar, in: context)
        #expect(player.dailyEarnedFishCount == 0)
        #expect(player.dailyClaimedFishCount == 0)
        #expect(player.dailyFishLimit == 3)
        #expect(player.dailyPendingFishCount == 0)
        #expect(player.pendingFishEarnedCount == 0)
        #expect(player.dailyFishProgressSeconds == 0)
        #expect(player.ownedFish.count == 4)
        try FishRewardBatchService.grantPending(
            to: player, on: nextDay, calendar: fixture.calendar, defaults: fixture.defaults, in: context
        )
        #expect(player.ownedFish.count == 4)
        #expect(player.dailyEarnedFishCount == 0)
        #expect(try context.fetch(FetchDescriptor<FocusSessionRecord>()).first?.durationSeconds == 13200)
        #expect(try context.fetchCount(FetchDescriptor<RewardHistoryEntry>()) == 4)
    }

    @Test func sameSessionAfterReopenDoesNotIncreaseEarnedOrClaimed() throws {
        let fixture = try ClaimFixture()
        let id = try fixture.process(seconds: 6000)
        _ = try fixture.grant(id) { _ in .clownfish }
        let context = ModelContext(fixture.container)
        let player = try #require(context.fetch(FetchDescriptor<Player>()).first)
        try DailyFishProgressService.process(
            sessionID: id, for: player, on: fixture.date, calendar: fixture.calendar, in: context
        )
        #expect(try FishRewardBatchService.grant(
            sessionID: id, to: player, on: fixture.date, calendar: fixture.calendar, defaults: fixture.defaults,
            in: context, draw: { _ in Issue.record("同一sessionを再抽選しない"); return .manta }
        ) == nil)
        #expect(player.dailyEarnedFishCount == 4)
        #expect(player.dailyClaimedFishCount == 3)
        #expect(player.dailyPendingFishCount == 1)
        #expect(player.dailyFishLimit == 3)
        #expect(try context.fetchCount(FetchDescriptor<PlayerFish>()) == 3)
    }

    @Test func failedUnlockedClaimKeepsRightsAndUnlockedSlotForRetry() throws {
        let fixture = try ClaimFixture()
        let id = try fixture.process(seconds: 6000)
        _ = try fixture.grant(id) { _ in .clownfish }
        do {
            _ = try fixture.unlock { _ in nil }
            Issue.record("抽選失敗を返すべき")
        } catch FishRewardBatchService.GrantError.drawFailed { }
        #expect(fixture.player.dailyFishLimit == 4)
        #expect(fixture.player.dailyClaimedFishCount == 3)
        #expect(fixture.player.dailyPendingFishCount == 1)
        let batch = try FishRewardBatchService.claimAvailable(
            to: fixture.player, on: fixture.date, calendar: fixture.calendar, defaults: fixture.defaults,
            in: fixture.context, draw: { _ in .manta }
        )
        #expect(batch?.results.count == 1)
        #expect(fixture.player.dailyClaimedFishCount == 4)
        #expect(fixture.player.dailyFishLimit == 4)
    }

    @Test func delayedPreviousDaySessionDoesNotGrantOrCarryRights() throws {
        let fixture = try ClaimFixture()
        let yesterday = fixture.calendar.date(byAdding: .day, value: -1, to: fixture.date)!
        let id = try fixture.process(seconds: 6000, completedAt: yesterday)
        #expect(try fixture.grant(id) { _ in Issue.record("前日の失効権を抽選しない"); return .clownfish } == nil)
        #expect(fixture.player.dailyEarnedFishCount == 0)
        #expect(fixture.player.dailyClaimedFishCount == 0)
        #expect(fixture.player.dailyPendingFishCount == 0)
        #expect(fixture.player.ownedFish.isEmpty)
        #expect(try fixture.context.fetch(FetchDescriptor<FocusSessionRecord>()).first?.durationSeconds == 6000)
    }
}

@MainActor
private final class ClaimFixture {
    let container: ModelContainer
    let context: ModelContext
    let player: Player
    let defaults: UserDefaults
    let suite = "DailyFishClaimTests-\(UUID())"
    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
    let date = Date(timeIntervalSince1970: 1791021600)

    init() throws {
        container = try ModelContainer(
            for: Player.self, PlayerFish.self, FocusSessionRecord.self, StudyDailyRecord.self, RewardHistoryEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = ModelContext(container)
        defaults = UserDefaults(suiteName: suite)!
        player = Player(coins: 80)
        context.insert(player)
        try context.save()
    }

    deinit { defaults.removePersistentDomain(forName: suite) }

    func process(seconds: Int, completedAt: Date? = nil) throws -> UUID {
        let session = FinalizedFocusSession(
            id: UUID(), completedAt: completedAt ?? date, validFocusSeconds: seconds, endReason: .completed,
            categoryID: FocusCategoryDefaults.studyID, focusMethod: .timer
        )
        try StudyHistoryService.recordValidFocusSession(session, calendar: calendar, in: context)
        try DailyFishProgressService.process(sessionID: session.id, for: player, on: date, calendar: calendar, in: context)
        return session.id
    }

    func grant(_ id: UUID, draw: @MainActor (FishRewardService.RarityProbabilities) -> FishSpecies?) throws -> FishRewardBatch? {
        try FishRewardBatchService.grant(
            sessionID: id, to: player, on: date, calendar: calendar, defaults: defaults, in: context, draw: draw
        )
    }

    func unlock(draw: @MainActor (FishRewardService.RarityProbabilities) -> FishSpecies?) throws -> FishRewardBatch? {
        try FishRewardBatchService.unlockOneFishSlot(
            for: player, on: date, calendar: calendar, defaults: defaults, in: context, draw: draw
        )
    }
}
