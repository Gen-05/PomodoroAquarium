import SwiftUI
import UIKit

struct StudyCompletionRewardView: View {
    let reward: StudyCompletionReward

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var showsProbability = false
    @State private var probabilityAnimationStep = 0
    @State private var probabilityDate = Date()
    @State private var showsStudyReward = false
    @State private var showsStreakReward = false
    @State private var showsTotalReward = false
    @State private var displayedStudyReward = 0
    @State private var displayedStreakReward = 0
    @State private var displayedTotalReward = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Text("🎉 集中完了！")
                    .font(.largeTitle.bold())

                rewardRow(
                    icon: "📘",
                    title: "今日の集中報酬",
                    amount: displayedStudyReward
                )
                .opacity(showsStudyReward ? 1 : 0)
                .offset(y: showsStudyReward ? 0 : 12)

                if !reward.didEarnFish {
                    Label("獲得魚なし", systemImage: "fish")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("noFishReward")
                }

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
                        Text(StudyCompletionRewardPresentation.amountText(displayedTotalReward))
                            .font(.title.bold())
                            .foregroundStyle(.yellow)
                            .contentTransition(.numericText())
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                if showsProbability, let change = reward.probabilityChange {
                    probabilityRow(change)
                        .transition(.opacity)
                }

                Button("閉じる") {
                    dismiss()
                }
                .buttonStyle(AquariumPrimaryButtonStyle())
            }
            .padding(28)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .presentationDetents(reward.probabilityChange == nil ? [.medium] : [.large])
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { probabilityDate = .now }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            probabilityDate = .now
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            probabilityDate = .now
        }
        .task {
            await playRewardAnimation()
        }
    }

    private func probabilityRow(_ change: FishProbabilityChange) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("明日の獲得確率")
                .font(.headline)
            if change.isCurrent(on: probabilityDate) {
                Grid(alignment: .trailing, horizontalSpacing: 6, verticalSpacing: 10) {
                    ForEach(Array(FishProbabilityProjection.increasingRarities.enumerated()), id: \.element) { index, rarity in
                        let increases = change.showsIncrease(for: rarity, on: probabilityDate)
                        let progress = min(1, max(0, Double(probabilityAnimationStep - index * 6) / 40))
                        let value = increases
                            ? change.before(for: rarity) + (change.after(for: rarity) - change.before(for: rarity)) * progress
                            : change.after(for: rarity)
                        GridRow {
                            HStack(spacing: 4) {
                                Circle().fill(rarity.rewardColor).frame(width: 5, height: 5)
                                Text(rarity.rawValue).font(.caption.weight(.semibold))
                            }
                            .gridColumnAlignment(.leading)
                            Text(increases ? FishProbabilityProjection.percentageText(change.before(for: rarity)) : "")
                                .foregroundStyle(.secondary)
                            Text(increases ? "→" : "").accessibilityHidden(true)
                            Text(FishProbabilityProjection.percentageText(value))
                                .fontWeight(.bold)
                                .contentTransition(.numericText())
                                .accessibilityIdentifier("reward.tomorrowProbability.\(rarity.rawValue)")
                            Text(increases && progress >= 1 ? "↑UP" : "")
                                .font(.caption.bold()).foregroundStyle(.green)
                                .frame(width: 30)
                                .accessibilityIdentifier("reward.probabilityUp.\(rarity.rawValue)")
                        }
                    }
                }
                .font(.subheadline)
                .monospacedDigit()
            }
            Text(change.status(on: probabilityDate))
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("reward.probabilityChange")
    }

    private func rewardRow(icon: String, title: String, amount: Int) -> some View {
        HStack(spacing: 14) {
            Text(icon)
                .font(.title)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(StudyCompletionRewardPresentation.amountText(amount))
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
        await playProbabilityAnimation()
    }

    private func playProbabilityAnimation() async {
        guard !Task.isCancelled, let change = reward.probabilityChange else { return }
        probabilityDate = .now
        probabilityAnimationStep = 0
        if reduceMotion {
            showsProbability = true
        } else {
            withAnimation(.easeOut(duration: 0.2)) { showsProbability = true }
        }
        // One existing presentation Task drives all three rows, staggered by 0.12s.
        // Only display progress changes; fixed receipt values and session times are untouched.
        guard change.hasIncrease(on: probabilityDate), !reduceMotion else {
            probabilityAnimationStep = 52
            return
        }
        for step in 1...52 {
            guard !Task.isCancelled else { return }
            withAnimation(.linear(duration: 0.02)) { probabilityAnimationStep = step }
            do { try await Task.sleep(for: .milliseconds(20)) } catch { return }
        }
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

enum StudyCompletionRewardPresentation {
    static func amountText(_ amount: Int) -> String {
        let safeAmount = max(0, amount)
        return safeAmount == 0 ? "0コイン" : "+\(safeAmount)コイン"
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
