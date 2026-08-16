//
//  FishRewardView.swift
//  PomodoroAquarium
//

import SwiftUI
import UIKit

struct FishRewardView: View {
    let fish: PlayerFish

    @Environment(\.dismiss) private var dismiss

    private var species: FishSpecies {
        fish.species
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("新しい魚を発見！")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)

            fishImage
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .background(Color.cyan.opacity(0.12), in: RoundedRectangle(cornerRadius: 24))

            VStack(spacing: 10) {
                Text(species.name)
                    .font(.title.bold())

                Text(species.rarity.rawValue)
                    .font(.headline)
                    .foregroundStyle(rarityColor)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(rarityColor.opacity(0.14), in: Capsule())

                Text("水族館に追加しました")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("閉じる") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
        }
        .padding(24)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
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
        case .common:
            .secondary
        case .rare:
            .blue
        case .epic:
            .purple
        case .legendary:
            .orange
        }
    }
}

#Preview {
    FishRewardView(fish: PlayerFish(species: .clownfish))
}
