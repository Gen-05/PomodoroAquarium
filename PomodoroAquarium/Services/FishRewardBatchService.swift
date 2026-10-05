import Foundation
import SwiftData

/// 確定済みの表示データ。Viewは抽選・付与を行わない。
struct FishRewardBatch: Identifiable {
    let id: UUID
    let results: [FishAcquisitionResult]
    let historyIDs: [UUID]
}

@MainActor
enum FishRewardBatchService {
    enum GrantError: Error { case missingSession, drawFailed }

    /// sessionの即時受取。残りの権利は日次pendingへ保持し、先に抽選しない。
    static func grant(
        sessionID: UUID,
        to player: Player,
        pomodoroFlowID: UUID? = nil,
        on date: Date = Date(),
        calendar: Calendar = .current,
        defaults: UserDefaults = .standard,
        in context: ModelContext,
        draw: @MainActor (FishRewardService.RarityProbabilities) -> FishSpecies? = FishRewardService.drawSpecies
    ) throws -> FishRewardBatch? {
        let descriptor = FetchDescriptor<FocusSessionRecord>(predicate: #Predicate { $0.id == sessionID })
        guard let record = try context.fetch(descriptor).first else { throw GrantError.missingSession }
        try DailyFishProgressService.refreshDailyEntitlements(for: player, on: date, calendar: calendar, in: context)
        guard let count = record.fishEarnedCount, !record.hasGrantedFishReward else {
            try context.save()
            synchronizeDailyCount(for: player, on: date, calendar: calendar, defaults: defaults)
            return nil
        }
        let grantNow = calendar.isDate(record.completedAt, inSameDayAs: date)
            ? min(max(0, count), claimableCount(for: player)) : 0
        return try performClaim(
            count: grantNow, batchID: sessionID, record: record, to: player,
            on: date, calendar: calendar, defaults: defaults, in: context, draw: draw,
            pomodoroFlowID: pomodoroFlowID
        )
    }

    static func claimableCount(for player: Player) -> Int {
        DailyFishAcquisitionPolicy.claimableCount(
            earned: player.dailyEarnedFishCount, claimed: player.dailyClaimedFishCount, limit: player.dailyFishLimit
        )
    }

    /// 確定済み権利の受取。再評価してもclaimedとの差分以上は付与しない。
    static func claimAvailable(
        to player: Player, on date: Date = Date(), calendar: Calendar = .current,
        defaults: UserDefaults = .standard, in context: ModelContext,
        draw: @MainActor (FishRewardService.RarityProbabilities) -> FishSpecies? = FishRewardService.drawSpecies
    ) throws -> FishRewardBatch? {
        try DailyFishProgressService.refreshDailyEntitlements(for: player, on: date, calendar: calendar, in: context)
        return try performClaim(
            count: claimableCount(for: player), batchID: UUID(), record: nil, to: player,
            on: date, calendar: calendar, defaults: defaults, in: context, draw: draw
        )
    }

    /// 広告完了相当。現在はDEBUG導線からのみ呼ぶ。SDK/entitlementには接続しない。
    /// 枠の保存と受取を分離し、抽選失敗でも解放済み枠は次回受取に利用できる。
    static func unlockOneFishSlot(
        for player: Player, on date: Date = Date(), calendar: Calendar = .current,
        defaults: UserDefaults = .standard, in context: ModelContext,
        draw: @MainActor (FishRewardService.RarityProbabilities) -> FishSpecies? = FishRewardService.drawSpecies
    ) throws -> FishRewardBatch? {
        try DailyFishProgressService.refreshDailyEntitlements(for: player, on: date, calendar: calendar, in: context)
        let previousLimit = player.dailyFishLimit
        player.dailyFishLimit = DailyFishAcquisitionPolicy.unlockedLimit(from: previousLimit)
        do { try context.save() } catch {
            player.dailyFishLimit = previousLimit
            throw error
        }
        return try claimAvailable(to: player, on: date, calendar: calendar, defaults: defaults, in: context, draw: draw)
    }

    private static func performClaim(
        count: Int, batchID: UUID, record: FocusSessionRecord?, to player: Player,
        on date: Date, calendar: Calendar, defaults: UserDefaults, in context: ModelContext,
        draw: @MainActor (FishRewardService.RarityProbabilities) -> FishSpecies?,
        pomodoroFlowID: UUID? = nil
    ) throws -> FishRewardBatch? {
        // 呼び出し元の保存済み時間・進捗をrollbackの対象にしない。
        let previousDayMinutes = try PreviousDayFocusDurationService.synchronizeMinutes(
            for: player, before: date, calendar: calendar, in: context
        )
        try context.save()
        let probabilities = FishRewardService.rarityProbabilities(for: previousDayMinutes)
        // 抽選失敗で部分的な所持追加を残さない。抽選自体は各枠で独立。
        let speciesDraws = try (0..<max(0, count)).map { _ -> FishSpecies in
            guard let species = draw(probabilities) else { throw GrantError.drawFailed }
            return species
        }
        let ownedBefore = player.ownedFish
        let pendingBefore = player.pendingFishEarnedCount
        let dailyCountBefore = player.dailyGrantedFishCount
        let dailyDateBefore = player.dailyGrantedFishDate
        var results: [FishAcquisitionResult] = []
        var historyIDs: [UUID] = []
        do {
            for (index, species) in speciesDraws.enumerated() {
                let previousCount = player.ownedFish.count { $0.species == species }
                let fish = PlayerFish(species: species)
                context.insert(fish)
                player.ownedFish.append(fish)
                let result = FishAcquisitionResult(
                    fish: fish, previousOwnedCount: previousCount, currentOwnedCount: previousCount + 1
                )
                results.append(result)
                let history = try RewardHistoryService.record(
                    result: result, pointDelta: 0, acquiredAt: date,
                    sessionID: batchID, batchIndex: index, pomodoroFlowID: pomodoroFlowID,
                    saveImmediately: false, in: context
                )
                historyIDs.append(history.id)
            }
            player.dailyClaimedFishCount += results.count
            player.pendingFishEarnedCount = player.dailyPendingFishCount
            record?.hasGrantedFishReward = true
            try RewardHistoryService.pruneIfNeeded(in: context)
            try context.save()
        } catch {
            // 抽選途中/保存失敗では、魚・履歴・付与印を一緒に戻して再試行可能にする。
            context.rollback()
            // SwiftDataのto-many配列cacheはrollbackだけで戻らない場合がある。
            player.ownedFish = ownedBefore
            player.pendingFishEarnedCount = pendingBefore
            player.dailyGrantedFishCount = dailyCountBefore
            player.dailyGrantedFishDate = dailyDateBefore
            record?.hasGrantedFishReward = false
            throw error
        }
        synchronizeDailyCount(for: player, on: date, calendar: calendar, defaults: defaults)
        return results.isEmpty ? nil : FishRewardBatch(id: batchID, results: results, historyIDs: historyIDs)
    }

    /// Step 2だけで保存された記録や、進捗保存後に終了したappもここから再開する。
    static func grantPending(
        to player: Player, on date: Date = Date(), calendar: Calendar = .current,
        defaults: UserDefaults = .standard, in context: ModelContext
    ) throws {
        let records = try context.fetch(FetchDescriptor<FocusSessionRecord>(
            predicate: #Predicate { $0.fishEarnedCount != nil && !$0.hasGrantedFishReward },
            sortBy: [SortDescriptor(\FocusSessionRecord.completedAt)]
        ))
        for record in records {
            _ = try grant(sessionID: record.id, to: player, on: date, calendar: calendar, defaults: defaults, in: context)
        }
        // 解放枠の保存後・claim前にappが終了したケースも、未受取権だけから再開する。
        _ = try claimAvailable(to: player, on: date, calendar: calendar, defaults: defaults, in: context)
        synchronizeDailyCount(for: player, on: date, calendar: calendar, defaults: defaults)
    }

    /// 保存後のUserDefaultsはHome用のprojection。再起動時も再構築して二重加算しない。
    static func synchronizeDailyCount(
        for player: Player, on date: Date = Date(), calendar: Calendar = .current,
        defaults: UserDefaults = .standard
    ) {
        guard let day = player.dailyGrantedFishDate, calendar.isDate(day, inSameDayAs: date) else { return }
        defaults.set(DailyFishAcquisitionStore.dayIdentifier(for: date, calendar: calendar),
                     forKey: DailyFishAcquisitionStorageKey.dayIdentifier)
        defaults.set(player.dailyGrantedFishCount, forKey: DailyFishAcquisitionStorageKey.count)
    }

    /// 同じ確定結果の再表示だけを行う。抽選・所持数更新は一切しない。
    static func latestUnacknowledgedBatch(in context: ModelContext) throws -> FishRewardBatch? {
        guard let latest = try RewardHistoryService.latestUnacknowledged(in: context) else { return nil }
        if let flowID = latest.pomodoroFlowID {
            return try batch(forPomodoroFlow: flowID, in: context)
        }
        let entries: [RewardHistoryEntry]
        if let sessionID = latest.rewardSessionID {
            entries = try context.fetch(FetchDescriptor<RewardHistoryEntry>(
                predicate: #Predicate { $0.rewardSessionID == sessionID },
                sortBy: [SortDescriptor(\RewardHistoryEntry.rewardBatchIndex)]
            ))
        } else {
            entries = [latest]
        }
        return FishRewardBatch(
            id: latest.rewardSessionID ?? latest.id,
            results: entries.map { RewardHistorySnapshot(entry: $0).replayResult() },
            historyIDs: entries.map(\.id)
        )
    }

    /// 保存済みの魚をflow全体で表示するだけ。再抽選・再付与はしない。
    static func batch(forPomodoroFlow flowID: UUID, in context: ModelContext) throws -> FishRewardBatch? {
        let entries = try context.fetch(FetchDescriptor<RewardHistoryEntry>(
            predicate: #Predicate { $0.pomodoroFlowID == flowID && !$0.isAcknowledged },
            sortBy: [SortDescriptor(\RewardHistoryEntry.acquiredAt),
                     SortDescriptor(\RewardHistoryEntry.rewardBatchIndex)]
        ))
        guard !entries.isEmpty else { return nil }
        return FishRewardBatch(id: flowID,
                               results: entries.map { RewardHistorySnapshot(entry: $0).replayResult() },
                               historyIDs: entries.map(\.id))
    }

    static func acknowledge(_ ids: [UUID], in context: ModelContext) throws {
        for id in ids {
            let descriptor = FetchDescriptor<RewardHistoryEntry>(predicate: #Predicate { $0.id == id })
            try context.fetch(descriptor).first?.isAcknowledged = true
        }
        try context.save()
    }

    /// ポイントはsessionで一度だけ付与済み。履歴の先頭にだけ記載し、魚数倍にしない。
    static func recordPoints(_ points: Int, for batch: FishRewardBatch, in context: ModelContext) throws {
        guard let id = batch.historyIDs.first else { return }
        let descriptor = FetchDescriptor<RewardHistoryEntry>(predicate: #Predicate { $0.id == id })
        try context.fetch(descriptor).first?.pointDelta = max(0, points)
        try context.save()
    }
}
