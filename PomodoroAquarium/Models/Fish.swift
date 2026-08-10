//
//  Fish.swift
//  PomodoroAquarium
//
//  Created by 阿部弦生 on 2026/07/29.
//

import Foundation
import SwiftData

enum FishRarity: String, Codable {
    case common = "Common"
    case rare = "Rare"
    case epic = "Epic"
    case legendary = "Legendary"
}

enum FishSpecies: String, Codable, CaseIterable, Identifiable {
    case clownfish
    case pufferfish
    case seahorse
    case manta
    case whaleShark

    var id: String {
        rawValue
    }

    var name: String {
        switch self {
        case .clownfish:
            "クマノミ"
        case .pufferfish:
            "フグ"
        case .seahorse:
            "タツノオトシゴ"
        case .manta:
            "マンタ"
        case .whaleShark:
            "ジンベエザメ"
        }
    }

    var imageName: String {
        switch self {
        case .clownfish:
            "clownfish"
        case .pufferfish:
            "pufferfish"
        case .seahorse:
            "seahorse"
        case .manta:
            "manta"
        case .whaleShark:
            "whaleshark"
        }
    }

    var rarity: FishRarity {
        switch self {
        case .clownfish, .pufferfish:
            .common
        case .seahorse:
            .rare
        case .manta:
            .epic
        case .whaleShark:
            .legendary
        }
    }
}

@Model
class PlayerFish {
    var id: UUID
    var species: FishSpecies
    
    init(
        id: UUID = UUID(),
        species: FishSpecies
    ) {
        self.id = id
        self.species = species
    }
}
