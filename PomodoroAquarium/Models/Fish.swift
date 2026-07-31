//
//  Fish.swift
//  PomodoroAquarium
//
//  Created by 阿部弦生 on 2026/07/29.
//

import SwiftUI

enum FishRarity: String {
    case common = "Common"
    case rare = "Rare"
    case epic = "Epic"
    case legendary = "Legendary"
}

struct Fish: Identifiable {
    let id: UUID
    let name: String
    let imageName: String
    let rarity: FishRarity
}
