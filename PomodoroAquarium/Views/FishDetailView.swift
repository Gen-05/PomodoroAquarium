//
//  FishDetailView.swift
//  PomodoroAquarium
//

import SwiftUI
import UIKit

struct FishDetailView: View {
    let species: FishSpecies
    let player: Player?

    private var ownedCount: Int {
        BookView.ownedCount(for: species, in: player)
    }

    private var isFavorite: Bool {
        player?.favoriteFish?.species == species
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                fishImage
                    .frame(maxWidth: .infinity)
                    .frame(height: 240)
                    .background(Color.cyan.opacity(0.12), in: RoundedRectangle(cornerRadius: 24))

                VStack(spacing: 16) {
                    detailRow(title: "魚の名前", value: species.name)
                    Divider()
                    detailRow(title: "レアリティ", value: species.rarity.rawValue)
                    Divider()
                    detailRow(title: "所持数", value: "\(ownedCount)匹")
                }
                .padding(20)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))

                if isFavorite {
                    Label("現在の水槽表示魚", systemImage: "star.fill")
                        .font(.headline)
                        .foregroundStyle(.yellow)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Color.yellow.opacity(0.12), in: Capsule())
                } else {
                    Button {
                        if let player {
                            BookView.setFavorite(species, for: player)
                        }
                    } label: {
                        Label("お気に入りに設定", systemImage: "star")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(player == nil || ownedCount == 0)
                }
            }
            .padding()
        }
        .navigationTitle(species.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var fishImage: some View {
        if let image = UIImage(named: species.imageName) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .padding(24)
        } else {
            Image(systemName: "fish")
                .font(.system(size: 100))
                .foregroundStyle(.blue)
        }
    }

    private func detailRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
    }
}

#Preview {
    NavigationStack {
        FishDetailView(species: .clownfish, player: nil)
    }
}
