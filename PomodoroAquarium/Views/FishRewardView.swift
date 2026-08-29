import SwiftUI
import UIKit

struct FishRewardView: View {
    let result: FishAcquisitionResult

    @Environment(\.dismiss) private var dismiss
    @State private var isRevealed = false

    private var species: FishSpecies { result.species }

    var body: some View {
        ZStack {
            if result.isNewFish {
                RadialGradient(
                    colors: [rarityColor.opacity(0.24), .clear],
                    center: .center,
                    startRadius: 10,
                    endRadius: 270
                )
                .ignoresSafeArea()
            }

            VStack(spacing: 22) {
                Spacer()

                if result.showsNewBadge {
                    Text("NEW!")
                        .font(.title.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 8)
                        .background(rarityColor.gradient, in: Capsule())
                        .shadow(color: rarityColor.opacity(0.45), radius: 12)
                        .accessibilityIdentifier("newFishBadge")
                }

                Text(result.isNewFish ? "新しい魚を発見しました！" : "\(species.name)を獲得！")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)

                fishImage
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .background(Color.cyan.opacity(0.12), in: RoundedRectangle(cornerRadius: 24))
                    .scaleEffect(isRevealed ? 1 : 0.78)
                    .opacity(isRevealed ? 1 : 0)

                VStack(spacing: 10) {
                    Text(species.name)
                        .font(.title.bold())

                    Text(species.rarity.rawValue)
                        .font(.headline)
                        .foregroundStyle(rarityColor)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(rarityColor.opacity(0.14), in: Capsule())
                        .accessibilityIdentifier("fishRarity")

                    if result.isNewFish {
                        Label("図鑑に登録されました", systemImage: "book.closed.fill")
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(spacing: 5) {
                            Text("所持数")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("\(result.previousOwnedCount)匹 → \(result.currentOwnedCount)匹")
                                .font(.title2.bold())
                                .monospacedDigit()
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("所持数 \(result.previousOwnedCount)匹から\(result.currentOwnedCount)匹")
                        .accessibilityIdentifier("ownedCountChange")
                    }
                }

                Spacer()

                Button("閉じる") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
            }
            .padding(24)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) {
                isRevealed = true
            }
            AppFeedbackService.shared.playFishAcquisition(isNewFish: result.isNewFish)
        }
    }

    @ViewBuilder
    private var fishImage: some View {
        if let image = UIImage(named: species.imageName) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .padding(24)
        } else {
            Image(systemName: "fish.fill")
                .font(.system(size: 110))
                .foregroundStyle(.cyan, .blue)
        }
    }

    private var rarityColor: Color {
        switch species.rarity {
        case .common: .secondary
        case .rare: .blue
        case .epic: .purple
        case .legendary: .orange
        }
    }
}

#Preview("初獲得") {
    FishRewardView(result: FishAcquisitionResult(
        fish: PlayerFish(species: .clownfish),
        previousOwnedCount: 0,
        currentOwnedCount: 1
    ))
}

#Preview("重複") {
    FishRewardView(result: FishAcquisitionResult(
        fish: PlayerFish(species: .clownfish),
        previousOwnedCount: 4,
        currentOwnedCount: 5
    ))
}
