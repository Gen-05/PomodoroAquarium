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
            }
        }
    }

    static func ownedCount(for species: FishSpecies, in player: Player?) -> Int {
        player?.ownedFish.count { $0.species == species } ?? 0
    }
}

#Preview {
    BookView()
}
