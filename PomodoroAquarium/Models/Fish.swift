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
    case jellyfish
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
        case .jellyfish:
            "ミズクラゲ"
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

    /// 水槽・図鑑・獲得画面で共通利用する正式画像（右向きのside画像）。
    /// 未対応魚はnilとし、表示側で既存の魚シンボルへフォールバックする。
    var imageName: String? {
        switch self {
        case .clownfish:
            "fish_clownfish_side"
        case .jellyfish:
            "fish_moon_jellyfish"
        case .manta:
            "fish_reef_manta"
        case .pufferfish, .seahorse, .whaleShark:
            nil
        }
    }

    /// 移動方向に応じた画像切替・左右反転を行う魚種かどうか。
    var usesDirectionalSwimmingSprites: Bool {
        self == .clownfish
    }

    /// 右向きのside素材を、水平方向の進行に合わせて左右反転する魚種。
    var usesHorizontalSwimmingFlip: Bool {
        self == .clownfish || self == .manta
    }

    /// side方向の泳ぎフレーム候補。実在する画像が2枚以上ある時だけアニメーションする。
    /// 現在の静止画imageNameは、未追加・不足時の互換fallbackとして維持する。
    var swimmingImageNames: [String] {
        swimmingImageNames(for: .right)
    }

    func swimmingImageNames(for direction: FishFacingDirection) -> [String] {
        switch self {
        case .clownfish:
            let stem: String
            switch direction {
            case .right, .left:
                stem = "fish_clownfish_side"
            case .upRight, .upLeft:
                stem = "fish_clownfish_diagonal_up"
            case .up:
                stem = "fish_clownfish_up"
            case .downRight, .downLeft:
                stem = "fish_clownfish_diagonal_down"
            case .down:
                stem = "fish_clownfish_down"
            case .front:
                // front素材は現在の遊泳表示では使用せず、sideへ安全にフォールバックする。
                stem = "fish_clownfish_side"
            }
            return (1...3).map { "\(stem)_\($0)" }
        case .jellyfish:
            return (1...5).map { "fish_moon_jellyfish_\($0)" }
        case .manta:
            return (1...7).map { "fish_reef_manta_side_\($0)" }
        case .pufferfish, .seahorse, .whaleShark:
            return []
        }
    }

    func swimmingImageNames(for pose: FishSpritePose) -> [String] {
        guard usesDirectionalSwimmingSprites else {
            return swimmingImageNames
        }
        return switch pose {
        case .facing(let direction):
            swimmingImageNames(for: direction)
        case .sideToDiagonalUp15:
            switch self {
            case .clownfish:
                (1...3).map { "fish_clownfish_side_to_diagonal_up_15_\($0)" }
            case .jellyfish, .pufferfish, .seahorse, .manta, .whaleShark:
                []
            }
        case .sideToDiagonalDown15:
            switch self {
            case .clownfish:
                (1...3).map { "fish_clownfish_side_to_diagonal_down_15_\($0)" }
            case .jellyfish, .pufferfish, .seahorse, .manta, .whaleShark:
                []
            }
        }
    }

    /// 共通基準サイズに対する魚種ごとの表示倍率。
    var displayScale: CGFloat {
        switch self {
        case .clownfish:
            1
        case .manta:
            4.05
        case .jellyfish, .pufferfish, .seahorse, .whaleShark:
            1
        }
    }

    var rarity: FishRarity {
        switch self {
        case .clownfish, .jellyfish, .pufferfish:
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
