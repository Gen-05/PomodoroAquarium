import SwiftUI

struct StudyCompletionRewardView: View {
    let reward: StudyCompletionReward

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 22) {
            Text("🎉 勉強完了！")
                .font(.largeTitle.bold())

            rewardRow(
                icon: "🪙",
                title: "今日の勉強報酬",
                amount: reward.studyReward
            )

            if reward.hasStreakReward {
                rewardRow(
                    icon: "🔥",
                    title: "\(reward.streakDays)日連続ボーナス",
                    amount: reward.streakReward
                )
            }

            Divider()

            VStack(spacing: 6) {
                Text("合計")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text("+\(reward.totalReward)コイン")
                    .font(.title.bold())
                    .foregroundStyle(.yellow)
            }

            Button("閉じる") {
                dismiss()
            }
            .buttonStyle(AquariumPrimaryButtonStyle())
        }
        .padding(28)
        .presentationDetents([.medium])
    }

    private func rewardRow(icon: String, title: String, amount: Int) -> some View {
        HStack(spacing: 14) {
            Text(icon)
                .font(.title)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text("+\(amount)コイン")
                    .font(.title3.bold())
            }

            Spacer()
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}
