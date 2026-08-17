import SwiftUI

struct StudyCompletionRewardView: View {
    let reward: StudyCompletionReward

    @Environment(\.dismiss) private var dismiss
    @State private var showsStudyReward = false
    @State private var showsStreakReward = false
    @State private var showsTotalReward = false
    @State private var displayedStudyReward = 0
    @State private var displayedStreakReward = 0
    @State private var displayedTotalReward = 0

    var body: some View {
        VStack(spacing: 22) {
            Text("🎉 勉強完了！")
                .font(.largeTitle.bold())

            rewardRow(
                icon: "📘",
                title: "今日の勉強報酬",
                amount: displayedStudyReward
            )
            .opacity(showsStudyReward ? 1 : 0)
            .offset(y: showsStudyReward ? 0 : 12)

            if reward.hasStreakReward && showsStreakReward {
                rewardRow(
                    icon: "🔥",
                    title: "\(reward.streakDays)日連続ボーナス",
                    amount: displayedStreakReward
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if showsTotalReward {
                Divider()
                    .transition(.opacity)

                VStack(spacing: 6) {
                    Text("合計")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("+\(displayedTotalReward)コイン")
                        .font(.title.bold())
                        .foregroundStyle(.yellow)
                        .contentTransition(.numericText())
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            Button("閉じる") {
                dismiss()
            }
            .buttonStyle(AquariumPrimaryButtonStyle())
        }
        .padding(28)
        .presentationDetents([.medium])
        .task {
            await playRewardAnimation()
        }
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
                    .contentTransition(.numericText())
            }

            Spacer()
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private func playRewardAnimation() async {
        await MainActor.run {
            withAnimation(.easeOut(duration: 0.2)) {
                showsStudyReward = true
            }
        }
        await animateCount(to: reward.studyReward, target: .study)
        guard await waitForNextReward() else { return }

        if reward.hasStreakReward {
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.2)) {
                    showsStreakReward = true
                }
            }
            await animateCount(to: reward.streakReward, target: .streak)
            guard await waitForNextReward() else { return }
        }

        await MainActor.run {
            withAnimation(.easeOut(duration: 0.2)) {
                showsTotalReward = true
            }
        }
        await animateCount(to: reward.totalReward, target: .total)
    }

    private func animateCount(to amount: Int, target: RewardCountTarget) async {
        let values = RewardCountAnimation.values(to: amount)
        let stepCount = max(1, values.count - 1)
        let delay = UInt64(RewardCountAnimation.durationNanoseconds / UInt64(stepCount))

        for value in values.dropFirst() {
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.linear(duration: Double(delay) / 1_000_000_000)) {
                    switch target {
                    case .study: displayedStudyReward = value
                    case .streak: displayedStreakReward = value
                    case .total: displayedTotalReward = value
                    }
                }
            }
            try? await Task.sleep(nanoseconds: delay)
        }
    }

    private func waitForNextReward() async -> Bool {
        try? await Task.sleep(nanoseconds: 140_000_000)
        return !Task.isCancelled
    }
}

private enum RewardCountTarget {
    case study
    case streak
    case total
}

enum RewardCountAnimation {
    static let maximumSteps = 40
    static let durationNanoseconds: UInt64 = 420_000_000

    static func values(to amount: Int) -> [Int] {
        let target = max(0, amount)
        guard target > 0 else { return [0] }

        let quotient = target / maximumSteps
        let step = max(1, quotient + (target.isMultiple(of: maximumSteps) ? 0 : 1))
        var values = [0]
        var current = 0
        while current < target {
            current += min(step, target - current)
            values.append(current)
        }
        return values
    }
}
