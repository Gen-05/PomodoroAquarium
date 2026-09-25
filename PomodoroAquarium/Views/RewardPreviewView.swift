#if DEBUG
import SwiftUI
import SwiftData

struct RewardPreviewCatalog {
    struct Item: Identifiable {
        let rarity: FishRarity
        let species: FishSpecies

        var id: String { rarity.rawValue }
    }

    static let items: [Item] = [
        Item(rarity: .common, species: .clownfish),
        Item(rarity: .rare, species: .seahorse),
        Item(rarity: .epic, species: .manta),
        Item(rarity: .legendary, species: .whaleShark)
    ]

    static func item(for rarity: FishRarity) -> Item? {
        items.first { $0.rarity == rarity }
    }

    /// 永続化されているPlayerを受け取らず、演出表示専用の結果だけを生成する。
    @MainActor
    static func previewResult(for item: Item, isNewFish: Bool = true) -> FishAcquisitionResult {
        FishAcquisitionResult(
            fish: PlayerFish(species: item.species),
            previousOwnedCount: isNewFish ? 0 : 1,
            currentOwnedCount: isNewFish ? 1 : 2
        )
    }

    static let historyItems: [RewardHistorySnapshot] = [
        RewardHistorySnapshot(
            fishSpecies: .clownfish,
            pointDelta: 10,
            acquiredAt: Date().addingTimeInterval(-300),
            isAcknowledged: false,
            wasNewFish: true,
            previousOwnedCount: 0,
            currentOwnedCount: 1
        ),
        RewardHistorySnapshot(
            fishSpecies: .seahorse,
            pointDelta: 10,
            acquiredAt: Date().addingTimeInterval(-3_600),
            isAcknowledged: true,
            wasNewFish: true,
            previousOwnedCount: 0,
            currentOwnedCount: 1
        ),
        RewardHistorySnapshot(
            fishSpecies: .manta,
            pointDelta: 10,
            acquiredAt: Date().addingTimeInterval(-86_400),
            isAcknowledged: true,
            wasNewFish: true,
            previousOwnedCount: 0,
            currentOwnedCount: 1
        ),
        RewardHistorySnapshot(
            fishSpecies: .whaleShark,
            pointDelta: 10,
            acquiredAt: Date().addingTimeInterval(-172_800),
            isAcknowledged: false,
            wasNewFish: true,
            previousOwnedCount: 0,
            currentOwnedCount: 1
        )
    ]
}

private struct RewardPreviewPresentation: Identifiable {
    let id = UUID()
    let result: FishAcquisitionResult
    let historyID: UUID?
}

struct RewardPreviewView: View {
    @State private var presentation: RewardPreviewPresentation?
    @State private var previewsNewFish = true
    @State private var showsOnboardingPreview = false
    @State private var onboardingPreviewSessionID = UUID()
    @State private var showsCoreTutorialPreview = false
    @State private var coreTutorialPreviewSessionID = UUID()
    @State private var previewHistory = RewardPreviewCatalog.historyItems
    @State private var replayedPreviewHistoryID: UUID?

    var body: some View {
        List {
            Section {
                Toggle("初獲得（NEW!）", isOn: $previewsNewFish)
                    .accessibilityIdentifier("rewardPreview.newFish")
            }
            Section {
                ForEach(RewardPreviewCatalog.items) { item in
                    Button {
                        presentation = RewardPreviewPresentation(
                            result: RewardPreviewCatalog.previewResult(
                                for: item,
                                isNewFish: previewsNewFish
                            ),
                            historyID: nil
                        )
                    } label: {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(item.rarity.rewardColor)
                                .frame(width: 12, height: 12)

                            Text(item.rarity.rawValue)
                                .foregroundStyle(.primary)

                            Spacer()

                            Text(item.species.name)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Image(systemName: "play.fill")
                                .font(.caption)
                                .foregroundStyle(item.rarity.rewardColor)
                        }
                    }
                    .accessibilityLabel("\(item.rarity.rawValue)の報酬演出を再生")
                    .accessibilityIdentifier(
                        "rewardPreview.\(item.rarity.rawValue.lowercased())"
                    )
                }
            } header: {
                Text("Reward Preview")
            } footer: {
                Text("演出だけを再生します。所持魚、今日の獲得数、コイン、勉強記録は変更されません。")
            }
            Section {
                ForEach(previewHistory) { history in
                    Button {
                        presentReplay(history)
                    } label: {
                        HStack(spacing: 10) {
                            Circle()
                                .fill(history.rarity.rewardColor)
                                .frame(width: 10, height: 10)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("\(history.fishName) ・ \(history.rarity.rawValue)")
                                    .foregroundStyle(.primary)
                                Text(history.acquiredAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 3) {
                                Text("+\(history.pointDelta)pt")
                                    .font(.caption.monospacedDigit())
                                Label(
                                    history.isAcknowledged ? "確認済み" : "未確認",
                                    systemImage: history.isAcknowledged
                                        ? "checkmark.circle.fill"
                                        : "exclamationmark.circle.fill"
                                )
                                .font(.caption2)
                                .foregroundStyle(
                                    history.isAcknowledged ? Color.secondary : Color.orange
                                )
                            }
                        }
                    }
                    .accessibilityLabel(
                        "\(history.fishName)、\(history.isAcknowledged ? "確認済み" : "未確認")"
                    )
                }
            } header: {
                Text("最近の獲得履歴（in-memory）")
            } footer: {
                Text("この一覧はPreview内だけのダミー履歴です。本番のSwiftDataへ保存されません。")
            }
            Section {
                Button {
                    onboardingPreviewSessionID = UUID()
                    showsOnboardingPreview = true
                } label: {
                    Label("Onboarding Preview", systemImage: "rectangle.on.rectangle")
                }
                .accessibilityIdentifier("rewardPreview.onboarding")

                Button {
                    coreTutorialPreviewSessionID = UUID()
                    showsCoreTutorialPreview = true
                } label: {
                    Label("Core Tutorial Preview", systemImage: "arrow.trianglehead.2.clockwise.rotate.90")
                }
                .accessibilityIdentifier("rewardPreview.coreTutorial")
            } footer: {
                Text("OnboardingとCore Tutorialを確認できます。本番の完了状態やPlayerDataは変更しません。")
            }
        }
        .navigationTitle("Reward Preview")
        .fullScreenCover(item: $presentation, onDismiss: acknowledgePreviewReplay) { presentation in
            FishRewardView(result: presentation.result)
        }
        .fullScreenCover(isPresented: $showsOnboardingPreview) {
            OnboardingView(completionButtonTitle: "プレビュー終了") {
                showsOnboardingPreview = false
            }
            .id(onboardingPreviewSessionID)
        }
        .fullScreenCover(isPresented: $showsCoreTutorialPreview) {
            CoreTutorialPreviewHost {
                showsCoreTutorialPreview = false
            }
            .id(coreTutorialPreviewSessionID)
        }
    }

    private func presentReplay(_ history: RewardHistorySnapshot) {
        replayedPreviewHistoryID = history.id
        presentation = RewardPreviewPresentation(
            result: history.replayResult(),
            historyID: history.id
        )
    }

    private func acknowledgePreviewReplay() {
        guard let replayedPreviewHistoryID,
              let index = previewHistory.firstIndex(where: { $0.id == replayedPreviewHistoryID })
        else {
            self.replayedPreviewHistoryID = nil
            return
        }
        previewHistory[index].isAcknowledged = true
        self.replayedPreviewHistoryID = nil
    }
}

private struct CoreTutorialPreviewHost: View {
    let onFinish: () -> Void

    private let suiteName: String
    private let defaults: UserDefaults
    private let sessionStore: TimerSessionStore

    init(onFinish: @escaping () -> Void) {
        let suiteName = "CoreTutorialPreview.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? UserDefaults()
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set("25", forKey: TimerConfigurationStorageKey.pomodoroStudyDuration)
        defaults.set("5", forKey: TimerConfigurationStorageKey.pomodoroBreakDuration)
        defaults.set("25", forKey: TimerConfigurationStorageKey.timerDuration)
        defaults.set(
            PomodoroBreakConfiguration.defaultSetCount,
            forKey: TimerConfigurationStorageKey.pomodoroSetCount
        )
        defaults.set(true, forKey: OnboardingStore.storageKey)

        self.onFinish = onFinish
        self.suiteName = suiteName
        self.defaults = defaults
        self.sessionStore = TimerSessionStore(
            defaults: defaults,
            processIdentifier: "core-tutorial-preview"
        )
    }

    var body: some View {
        MainTabView(
            coreTutorialMode: .preview,
            defaults: defaults,
            timerSessionStore: sessionStore,
            notificationService: DisabledTimerNotificationService.shared,
            onCoreTutorialPreviewFinished: finish
        )
        .defaultAppStorage(defaults)
        .modelContainer(
            for: [
                Player.self,
                PlayerFish.self,
                AquariumDecorationPlacement.self,
                StudyDailyRecord.self,
                FocusCategory.self,
                FocusSessionRecord.self,
                RewardHistoryEntry.self
            ],
            inMemory: true
        )
        .overlay(alignment: .top) {
            Button(action: finish) {
                Label("プレビュー終了", systemImage: "xmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.regularMaterial, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
            .accessibilityIdentifier("coreTutorialPreview.exit")
        }
        .onDisappear(perform: clearTemporaryDefaults)
    }

    private func finish() {
        clearTemporaryDefaults()
        onFinish()
    }

    private func clearTemporaryDefaults() {
        defaults.removePersistentDomain(forName: suiteName)
    }
}

#Preview {
    NavigationStack {
        RewardPreviewView()
    }
}
#endif
