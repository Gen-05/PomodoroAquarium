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
    // 保存互換枠。旧マンタのrawValue/個体参照を保ったままクロマグロとして表示する。
    case manta
    case whaleShark
    case blueTang
    case yellowTang
    case blueGreenChromis
    case orientalButterflyfish
    case pennantCoralfish
    case lionfish
    case porcupinefish
    case mandarinfish
    case seaTurtle
    case dolphin
    case orca

    var id: String {
        rawValue
    }

    var name: String {
        switch self {
        case .orca:
            "シャチ"
        case .dolphin:
            "イルカ"
        case .seaTurtle:
            "ウミガメ"
        case .mandarinfish:
            "ニシキテグリ"
        case .porcupinefish:
            "ハリセンボン"
        case .lionfish:
            "ミノカサゴ"
        case .pennantCoralfish:
            "ハタタテダイ"
        case .orientalButterflyfish:
            "チョウチョウウオ"
        case .blueGreenChromis:
            "デバスズメダイ"
        case .yellowTang:
            "キイロハギ"
        case .blueTang:
            "ナンヨウハギ"
        case .clownfish:
            "クマノミ"
        case .jellyfish:
            "ミズクラゲ"
        case .pufferfish:
            "トラフグ"
        case .seahorse:
            "タツノオトシゴ"
        case .manta:
            "クロマグロ"
        case .whaleShark:
            "ジンベエザメ"
        }
    }

    /// 水槽・図鑑・獲得画面で共通利用する正式画像（右向きのside画像）。
    /// 未対応魚はnilとし、表示側で既存の魚シンボルへフォールバックする。
    var imageName: String? {
        switch self {
        case .orca:
            "fish_orca"
        case .dolphin:
            "fish_dolphin_side_5"
        case .seaTurtle:
            "fish_sea_turtle_side_4"
        case .mandarinfish:
            "fish_mandarinfish_side_3"
        case .porcupinefish:
            "fish_porcupinefish_side_2"
        case .lionfish:
            "fish_lionfish_side_4"
        case .pennantCoralfish:
            "fish_pennant_coralfish_side_2"
        case .orientalButterflyfish:
            "fish_oriental_butterflyfish_side_2"
        case .blueGreenChromis:
            "fish_blue_green_chromis_side_2"
        case .yellowTang:
            "fish_yellow_tang_side_2"
        case .blueTang:
            "fish_blue_tang_side_2"
        case .clownfish:
            "fish_clownfish_side_2"
        case .jellyfish:
            "fish_moon_jellyfish"
        case .manta:
            "fish_bluefin_tuna"
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
        self == .clownfish || self == .blueTang || self == .yellowTang || self == .blueGreenChromis || self == .orientalButterflyfish || self == .pennantCoralfish || self == .lionfish || self == .porcupinefish || self == .mandarinfish || self == .pufferfish || self == .seahorse
    }

    /// 右向きのside素材を、水平方向の進行に合わせて左右反転する魚種。
    var usesHorizontalSwimmingFlip: Bool {
        self == .clownfish || self == .blueTang || self == .yellowTang || self == .blueGreenChromis || self == .orientalButterflyfish || self == .pennantCoralfish || self == .lionfish || self == .porcupinefish || self == .mandarinfish || self == .pufferfish || self == .seahorse
            || self == .manta || self == .whaleShark || self == .seaTurtle || self == .dolphin || self == .orca
    }

    /// 素材が1周期として制作されている魚。ほかの魚は既存の往復再生を維持する。
    var usesForwardSwimmingLoop: Bool { self == .manta || self == .whaleShark || self == .orca }

    /// side方向の泳ぎフレーム候補。実在する画像が2枚以上ある時だけアニメーションする。
    /// 現在の静止画imageNameは、未追加・不足時の互換fallbackとして維持する。
    var swimmingImageNames: [String] {
        swimmingImageNames(for: .right)
    }

    func swimmingImageNames(for direction: FishFacingDirection) -> [String] {
        switch self {
        case .orca:
            return (1...16).map { "fish_orca_side_\($0)" }
        case .dolphin:
            return (1...9).map { "fish_dolphin_side_\($0)" }
        case .seaTurtle:
            return (1...7).map { "fish_sea_turtle_side_\($0)" }
        case .mandarinfish:
            return (1...5).map { "fish_mandarinfish_side_\($0)" }
        case .porcupinefish:
            return (1...3).map { "fish_porcupinefish_side_\($0)" }
        case .lionfish:
            return (1...7).map { "fish_lionfish_side_\($0)" }
        case .pennantCoralfish:
            return (1...3).map { "fish_pennant_coralfish_side_\($0)" }
        case .orientalButterflyfish:
            return (1...3).map { "fish_oriental_butterflyfish_side_\($0)" }
        case .blueGreenChromis:
            return (1...3).map { "fish_blue_green_chromis_side_\($0)" }
        case .yellowTang:
            return (1...3).map { "fish_yellow_tang_side_\($0)" }
        case .blueTang:
            return (1...3).map { "fish_blue_tang_side_\($0)" }
        case .clownfish:
            return (1...3).map { "fish_clownfish_side_\($0)" }
        case .pufferfish:
            return (1...5).map { "fish_tiger_puffer_side_\($0)" }
        case .seahorse:
            return (1...5).map { "fish_seahorse_side_\($0)" }
        case .jellyfish:
            return (1...5).map { "fish_moon_jellyfish_\($0)" }
        case .manta:
            return (1...8).map { "fish_bluefin_tuna_side_\($0)" }
        case .whaleShark:
            return (1...12).map { "fish_whale_shark_side_\($0)" }
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
            case .clownfish, .blueTang, .yellowTang, .blueGreenChromis, .orientalButterflyfish, .pennantCoralfish, .lionfish, .porcupinefish, .mandarinfish, .pufferfish, .seahorse:
                // 小魚型は中間方向でも専用Assetへ切り替えず、魚種ごとのsideフレームを共用する。
                swimmingImageNames
            case .jellyfish, .manta, .whaleShark, .seaTurtle, .dolphin, .orca:
                []
            }
        }
    }

    /// 小魚型の右向きside素材を、horizontal flip後に進行方向へ回転する角度。
    func swimmingImageRotation(for direction: FishFacingDirection) -> Double {
        guard usesDirectionalSwimmingSprites, self != .mandarinfish else { return 0 }
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
        return rotation * (self == .seahorse ? 0.28 : (self == .lionfish || self == .porcupinefish) ? 0.25 : 1)
    }

    /// 共通基準サイズに対する魚種ごとの表示倍率。
    var displayScale: CGFloat {
        switch self {
        case .orca:
            0.96
        case .dolphin:
            0.80
        case .seaTurtle:
            0.80
        case .mandarinfish:
            0.48
        case .porcupinefish:
            0.90
        case .lionfish:
            0.636
        case .pennantCoralfish:
            0.636
        case .orientalButterflyfish:
            0.636
        case .blueGreenChromis:
            // neutralの可視横幅（1149/1254）を補正し、クマノミ程度にする。
            0.429
        case .yellowTang:
            // neutral画像の可視横幅（1164/1254）を補正し、ナンヨウハギと揃える。
            0.636
        case .blueTang:
            0.64
        case .clownfish:
            0.40
        case .pufferfish:
            0.90
        case .seahorse:
            1.20
        case .jellyfish:
            0.80
        case .manta:
            2.25
        case .whaleShark:
            6.00
        }
    }

    var rarity: FishRarity {
        switch self {
        case .clownfish, .blueTang, .yellowTang, .blueGreenChromis, .orientalButterflyfish, .pennantCoralfish, .jellyfish, .pufferfish:
            .common
        case .seahorse, .lionfish, .porcupinefish, .mandarinfish:
            .rare
        case .manta, .seaTurtle, .dolphin:
            .epic
        case .whaleShark, .orca:
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
