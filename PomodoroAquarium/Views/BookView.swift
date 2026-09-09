//
//  BookView.swift
//  PomodoroAquarium
//
//  Created by 阿部弦生 on 2026/07/31.
//

import SwiftUI
import SwiftData

enum BookFishThumbnailLayout {
    static let frameSize = CGSize(width: 48, height: 38)

    /// Asset内の透明余白を補正し、図鑑一覧での視覚的な存在感を揃える。
    /// 水槽用のdisplayScaleとは独立した一覧専用値。
    static func imageScale(for species: FishSpecies) -> CGFloat {
        switch species {
        case .clownfish:
            0.75
        case .jellyfish:
            1.00
        case .pufferfish:
            1.20
        case .seahorse:
            1.40
        case .manta:
            1.10
        case .whaleShark:
            1.32
        }
    }

    static func imageSize(for species: FishSpecies) -> CGSize {
        let scale = imageScale(for: species)
        return CGSize(width: frameSize.width * scale, height: frameSize.height * scale)
    }
}

struct BookView: View {
    @Query private var players: [Player]

    private var player: Player? {
        players.first
    }

    var body: some View {
        List(FishSpecies.allCases) { species in
            let ownedCount = Self.ownedCount(for: species, in: player)
            let isFavorite = player?.favoriteFish?.species == species

            NavigationLink {
                FishDetailView(species: species, player: player)
            } label: {
                HStack {
                    if ownedCount > 0 {
                        let imageSize = BookFishThumbnailLayout.imageSize(for: species)

                        FishImageView(species: species)
                            .frame(width: imageSize.width, height: imageSize.height)
                            .frame(
                                width: BookFishThumbnailLayout.frameSize.width,
                                height: BookFishThumbnailLayout.frameSize.height
                            )
                            .clipped()
                    } else {
                        Image(systemName: "fish")
                            .font(.title2)
                            .frame(
                                width: BookFishThumbnailLayout.frameSize.width,
                                height: BookFishThumbnailLayout.frameSize.height
                            )
                    }

                    VStack(alignment: .leading) {
                        Text(ownedCount > 0 ? species.name : "？？？")
                            .font(.headline)

                        if ownedCount > 0 {
                            Text(species.rarity.rawValue)
                                .font(.caption)
                                .foregroundStyle(.gray)

                            Text("所持数：\(ownedCount)")
                                .font(.caption)
                        } else {
                            Text("未所持")
                                .font(.caption)
                                .foregroundStyle(.gray)
                        }
                    }

                    Spacer()

                    if isFavorite {
                        Label("お気に入り", systemImage: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    }
                }
            }
            .disabled(ownedCount == 0)
        }
        .navigationTitle("魚図鑑")
    }

    static func ownedCount(for species: FishSpecies, in player: Player?) -> Int {
        player?.ownedFish.count { $0.species == species } ?? 0
    }

    @discardableResult
    static func setFavorite(_ species: FishSpecies, for player: Player) -> Bool {
        guard let fish = player.ownedFish.first(where: { $0.species == species }) else {
            return false
        }

        player.favoriteFish = fish
        return true
    }
}

#Preview {
    BookView()
}
