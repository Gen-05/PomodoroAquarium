#if DEBUG
import SwiftUI

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
}

private struct RewardPreviewPresentation: Identifiable {
    let id = UUID()
    let result: FishAcquisitionResult
}

struct RewardPreviewView: View {
    @State private var presentation: RewardPreviewPresentation?
    @State private var previewsNewFish = true
    @State private var showsOnboardingPreview = false
    @State private var onboardingPreviewSessionID = UUID()

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
                            result: RewardPreviewCatalog.previewResult(for: item, isNewFish: previewsNewFish)
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
                Button {
                    onboardingPreviewSessionID = UUID()
                    showsOnboardingPreview = true
                } label: {
                    Label("Onboarding Preview", systemImage: "rectangle.on.rectangle")
                }
                .accessibilityIdentifier("rewardPreview.onboarding")
            } footer: {
                Text("全3ページを確認できます。初回起動の完了状態は変更しません。")
            }
        }
        .navigationTitle("Reward Preview")
        .fullScreenCover(item: $presentation) { presentation in
            FishRewardView(result: presentation.result)
        }
        .fullScreenCover(isPresented: $showsOnboardingPreview) {
            OnboardingView(completionButtonTitle: "プレビュー終了") {
                showsOnboardingPreview = false
            }
            .id(onboardingPreviewSessionID)
        }
    }
}

#Preview {
    NavigationStack {
        RewardPreviewView()
    }
}
#endif
