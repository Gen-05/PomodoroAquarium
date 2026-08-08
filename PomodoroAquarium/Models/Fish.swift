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

@Model
class Fish {
    var id: UUID
    var name: String
    var imageName: String
    var rarity: FishRarity
    
    init(
        id: UUID = UUID(),
        name: String,
        imageName: String,
        rarity: FishRarity
    ) {
        self.id = id
        self.name = name
        self.imageName = imageName
        self.rarity = rarity
    }
}
