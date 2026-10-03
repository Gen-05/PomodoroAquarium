#if DEBUG
import Observation
import SwiftData
import SwiftUI

/// 本番のstate管理・抽選・表示を、独立したin-memory環境だけで確認する。
struct DailyFishClaimPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var store: DailyFishClaimPreviewStore?
    @State private var errorMessage: String?
    @State private var reward: FishRewardBatch?
    @State private var presentedHistoryIDs: [UUID] = []

    var body: some View {
        NavigationStack {
            Form {
                if let store {
                    Section("当日の状態") {
                        LabeledContent("日付", value: store.date.formatted(date: .abbreviated, time: .omitted))
                        LabeledContent("earned", value: "\(store.player.dailyEarnedFishCount)")
                        LabeledContent("claimed", value: "\(store.player.dailyClaimedFishCount)")
                        LabeledContent("limit", value: "\(store.player.dailyFishLimit)")
                        LabeledContent("pending", value: "\(store.player.dailyPendingFishCount)")
                        LabeledContent("余り秒数", value: "\(store.player.dailyFishProgressSeconds)")
                    }
                    Section {
                        Button("100分を追加（4匹分）") { perform { try $0.add(seconds: 6000) } }
                        Button("200分を追加（8匹分）") { perform { try $0.add(seconds: 12000) } }
                        Button("広告を見た扱いで+1枠") { perform { try $0.unlock() } }
                            .disabled(store.player.dailyFishLimit >= DailyFishAcquisitionPolicy.maximumLimit)
                        Button("受取可能な権利を再評価") { perform { try $0.claim() } }
                        Button("翌日へ（権利・枠・余りをリセット）") {
                            perform { try $0.nextDay(); return nil }
                        }
                    } footer: {
                        Text("DEBUG専用。魚・履歴・集中記録は独立したメモリ内だけへ保存します。本番データと広告SDKには接続しません。")
                    }
                }
                if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
            }
            .navigationTitle("日次魚上限 Preview")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("閉じる") { dismiss() } } }
        }
        .task {
            guard store == nil else { return }
            do { store = try DailyFishClaimPreviewStore() } catch { errorMessage = error.localizedDescription }
        }
        .fullScreenCover(item: $reward, onDismiss: {
            if let store {
                try? FishRewardBatchService.acknowledge(presentedHistoryIDs, in: store.context)
            }
            presentedHistoryIDs = []
        }) { reward in
            if reward.results.count == 1, let result = reward.results.first {
                FishRewardView(result: result)
            } else {
                MultipleFishRewardView(results: reward.results)
            }
        }
    }

    private func perform(_ action: (DailyFishClaimPreviewStore) throws -> FishRewardBatch?) {
        guard let store, reward == nil else { return }
        do {
            errorMessage = nil
            let batch = try action(store)
            presentedHistoryIDs = batch?.historyIDs ?? []
            reward = batch
        } catch { errorMessage = error.localizedDescription }
    }
}

@MainActor
@Observable
private final class DailyFishClaimPreviewStore {
    let container: ModelContainer
    let context: ModelContext
    let player: Player
    let defaults: UserDefaults
    let suite = "DailyFishClaimPreview-\(UUID())"
    var date = Date()

    init() throws {
        container = try ModelContainer(
            for: Player.self, PlayerFish.self, FocusSessionRecord.self, StudyDailyRecord.self, RewardHistoryEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = ModelContext(container)
        defaults = UserDefaults(suiteName: suite)!
        player = Player()
        context.insert(player)
        try DailyFishProgressService.resetIfNeeded(for: player, on: date, in: context)
    }

    deinit { defaults.removePersistentDomain(forName: suite) }

    func add(seconds: Int) throws -> FishRewardBatch? {
        let session = FinalizedFocusSession(
            id: UUID(), completedAt: date, validFocusSeconds: seconds, endReason: .completed,
            categoryID: FocusCategoryDefaults.studyID, focusMethod: .timer
        )
        try StudyHistoryService.recordValidFocusSession(session, in: context)
        try DailyFishProgressService.process(sessionID: session.id, for: player, on: date, in: context)
        return try FishRewardBatchService.grant(sessionID: session.id, to: player, on: date, defaults: defaults, in: context)
    }

    func unlock() throws -> FishRewardBatch? {
        try FishRewardBatchService.unlockOneFishSlot(for: player, on: date, defaults: defaults, in: context)
    }

    func claim() throws -> FishRewardBatch? {
        try FishRewardBatchService.claimAvailable(to: player, on: date, defaults: defaults, in: context)
    }

    func nextDay() throws {
        date = Calendar.current.date(byAdding: .day, value: 1, to: date) ?? date.addingTimeInterval(86400)
        try DailyFishProgressService.resetIfNeeded(for: player, on: date, in: context)
    }
}
#endif
