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
            "トラフグ"
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
            "fish_clownfish_side_2"
        case .jellyfish:
            "fish_moon_jellyfish"
        case .manta:
            "fish_reef_manta"
        case .whaleShark:
            "fish_whale_shark"
        case .pufferfish:
            "fish_tiger_puffer_side_3"
        case .seahorse:
            "fish_seahorse_side_3"
        }
    }

    /// 移動方向に応じた画像切替・左右反転を行う魚種かどうか。
    var usesDirectionalSwimmingSprites: Bool {
        self == .clownfish || self == .pufferfish || self == .seahorse
    }

    /// 右向きのside素材を、水平方向の進行に合わせて左右反転する魚種。
    var usesHorizontalSwimmingFlip: Bool {
        self == .clownfish || self == .pufferfish || self == .seahorse
            || self == .manta || self == .whaleShark
    }

    /// side方向の泳ぎフレーム候補。実在する画像が2枚以上ある時だけアニメーションする。
    /// 現在の静止画imageNameは、未追加・不足時の互換fallbackとして維持する。
    var swimmingImageNames: [String] {
        swimmingImageNames(for: .right)
    }

    func swimmingImageNames(for direction: FishFacingDirection) -> [String] {
        switch self {
        case .clownfish:
            return (1...3).map { "fish_clownfish_side_\($0)" }
        case .pufferfish:
            return (1...5).map { "fish_tiger_puffer_side_\($0)" }
        case .seahorse:
            return (1...5).map { "fish_seahorse_side_\($0)" }
        case .jellyfish:
            return (1...5).map { "fish_moon_jellyfish_\($0)" }
        case .manta:
            return (1...7).map { "fish_reef_manta_side_\($0)" }
        case .whaleShark:
            return (1...7).map { "fish_whale_shark_side_\($0)" }
        }
    }

    func swimmingImageNames(for pose: FishSpritePose) -> [String] {
        guard usesDirectionalSwimmingSprites else {
            return swimmingImageNames
        }
        return switch pose {
        case .facing(let direction):
            swimmingImageNames(for: direction)
        case .sideToDiagonalUp15, .sideToDiagonalDown15:
            switch self {
            case .clownfish, .pufferfish, .seahorse:
                // 小魚型は中間方向でも専用Assetへ切り替えず、魚種ごとのsideフレームを共用する。
                swimmingImageNames
            case .jellyfish, .manta, .whaleShark:
                []
            }
        }
    }

    /// 小魚型の右向きside素材を、horizontal flip後に進行方向へ回転する角度。
    func swimmingImageRotation(for direction: FishFacingDirection) -> Double {
        guard usesDirectionalSwimmingSprites else { return 0 }
        let rotation: Double = switch direction {
        case .right, .left, .front:
            0
        case .upRight:
            -45
        case .up:
            -90
        case .upLeft:
            45
        case .downRight:
            45
        case .down:
            90
        case .downLeft:
            -45
        }
        // 縦長のタツノオトシゴは、進行方向へ完全に倒さず立ち姿を残す。
        return rotation * (self == .seahorse ? 0.28 : 1)
    }

    /// 共通基準サイズに対する魚種ごとの表示倍率。
    var displayScale: CGFloat {
        switch self {
        case .clownfish:
            0.60
        case .pufferfish, .seahorse:
            0.75
        case .jellyfish:
            0.90
        case .manta:
            4.0
        case .whaleShark:
            6.00
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
