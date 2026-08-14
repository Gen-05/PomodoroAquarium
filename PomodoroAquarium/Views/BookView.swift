//
//  BookView.swift
//  PomodoroAquarium
//
//  Created by 阿部弦生 on 2026/07/31.
//

import SwiftUI
import SwiftData

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
                    Image(systemName: "fish")
                        .font(.title2)

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
