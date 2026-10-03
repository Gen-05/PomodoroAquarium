#if DEBUG
import SwiftUI

/// Previewは未保存のダミー結果を共通表示Viewへ渡すだけ。本番サービスには接続しない。
struct MultipleFishRewardPreviewView: View {
    @State private var results: [FishAcquisitionResult]

    init(fish: [RewardPreviewCatalog.MultipleFishEntry]) {
        _results = State(initialValue: fish.map {
            RewardPreviewCatalog.previewResult(for: $0.item, isNewFish: $0.isNewFish)
        })
    }

    var body: some View { MultipleFishRewardView(results: results) }
}

#Preview("3匹（Common既取得 / Rare NEW / Legendary既取得）") {
    MultipleFishRewardPreviewView(fish: RewardPreviewCatalog.multipleFishItems[1].fish)
}

#Preview("4匹（Epic NEW）") {
    MultipleFishRewardPreviewView(fish: RewardPreviewCatalog.multipleFishItems[2].fish)
}

#Preview("8匹（全rarity / NEW 3匹 / 4×2）") {
    MultipleFishRewardPreviewView(fish: RewardPreviewCatalog.multipleFishItems[6].fish)
}
#endif
