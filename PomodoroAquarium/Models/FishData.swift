//
//  FishData.swift
//  PomodoroAquarium
//
//  Created by 阿部弦生 on 2026/07/31.
//

import SwiftUI

let sampleFish: [Fish] = [
    Fish(
        id: UUID(),
        name: "クマノミ",
        imageName: "clownfish",
        rarity: .common
    ),
    Fish(
        id: UUID(),
        name: "フグ",
        imageName: "pufferfish",
        rarity: .common
    ),
    Fish(
        id: UUID(),
        name: "タツノオトシゴ",
        imageName: "seahorse",
        rarity: .rare
    ),
    Fish(
        id: UUID(),
        name: "マンタ",
        imageName: "manta",
        rarity: .epic
    ),
    Fish(
        id: UUID(),
        name: "ジンベエザメ",
        imageName: "whaleshark",
        rarity: .legendary
    )
]
