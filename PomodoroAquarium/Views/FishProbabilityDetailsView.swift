import SwiftUI

struct FishProbabilityDetailsView: View {
    let projection: FishProbabilityProjection
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(FishProbabilityProjection.explanation)
                    HStack {
                        Text("レアリティ")
                        Spacer()
                        Text("今日").frame(width: 80)
                    }
                    .font(.caption).foregroundStyle(.secondary)
                    ForEach(FishProbabilityProjection.rarities, id: \.self) { rarity in
                        HStack {
                            Circle().fill(rarity.rewardColor).frame(width: 7, height: 7)
                            Text(rarity.rawValue)
                            Spacer()
                            Text(FishProbabilityProjection.percentageText(projection.today.probability(for: rarity), compact: true))
                                .frame(width: 80)
                        }
                        .monospacedDigit()
                    }
                }
                Section {
                    Text("180分で上限になります。集中時間は「統計」から確認できます。")
                }
                .font(.subheadline)
            }
            .navigationTitle("今日の獲得確率")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }.accessibilityIdentifier("fishProbability.close")
                }
            }
        }
    }
}
