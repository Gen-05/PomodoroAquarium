//
//  AquariumDecoration.swift
//  PomodoroAquarium
//

import CoreGraphics
import Foundation
import SwiftData

enum AquariumDecorationKind: String, Codable, CaseIterable {
    case seaweed
    case rock
    case seaweedA = "seaweed-a"
    case seaweedB = "seaweed-b"
    case seaweedC = "seaweed_c"
}

enum AquariumDecorationType: String {
    case seaweed
    case rock
}

enum AquariumDecorationCategory: String, Codable, CaseIterable, Identifiable {
    case plant
    case rock
    case coral
    case object

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .plant: "水草"
        case .rock: "岩"
        case .coral: "サンゴ"
        case .object: "その他"
        }
    }
}

struct AquariumDecorationMovementBounds {
    let x: ClosedRange<CGFloat>
    let y: ClosedRange<CGFloat>

    /// 3背景共通の海底帯。将来は背景ごとの帯を配置helperへ渡せる。
    // TODO: ★3沈没船はこの帯に含めず、更に奥の遠景レイヤーで左/中央/右の3固定位置を予定。
    static let commonGround = AquariumDecorationMovementBounds(x: 0.05...0.95, y: 0.72...0.96)
}

/// 保存済みの位置から都度算出する、水中の距離感。個体のscaleは上書きしない。
struct AquariumDecorationDepthPresentation {
    let depthProgress: CGFloat
    let scale: CGFloat
    let opacity: Double
    let zIndex: Double

    init(kind: AquariumDecorationKind, relativeY: CGFloat) {
        guard kind.groundAnchorY != nil else {
            depthProgress = 0
            scale = 1
            opacity = 1
            zIndex = 0
            return
        }
        let band = kind.movementBounds.y
        let y = min(max(relativeY, band.lowerBound), band.upperBound)
        let span = band.upperBound - band.lowerBound
        let depth = span > 0 ? (band.upperBound - y) / span : 0
        depthProgress = depth
        scale = 1 - 0.24 * depth
        opacity = Double(1 - 0.20 * depth)
        // 装飾レイヤー内だけの順序。魚とのレイヤー関係は変更しない。
        zIndex = Double(y)
    }
}

extension AquariumDecorationKind {
    var category: AquariumDecorationCategory {
        switch self {
        case .seaweed, .seaweedA, .seaweedB, .seaweedC: .plant
        case .rock: .rock
        }
    }

    var decorationType: AquariumDecorationType {
        switch self {
        case .seaweed, .seaweedA, .seaweedB, .seaweedC: .seaweed
        case .rock: .rock
        }
    }

    /// 装飾のstable IDはkindのrawValue。価格は将来用の定義のみで購入処理には未接続。
    var stars: Int? { (self == .seaweedA || self == .seaweedB || self == .seaweedC) ? 1 : nil }
    var plannedPrice: Int? { (self == .seaweedA || self == .seaweedB || self == .seaweedC) ? 30 : nil }

    var animationFrameNames: [String] {
        switch self {
        case .seaweedA:
            ["seaweed_a_01", "seaweed_a_02", "seaweed_a_03", "seaweed_a_04",
             "seaweed_a_05", "seaweed_a_06", "seaweed_a_07", "seaweed_a_08"]
        case .seaweedB:
            ["seaweed_b_01", "seaweed_b_02", "seaweed_b_03", "seaweed_b_04",
             "seaweed_b_05", "seaweed_b_06", "seaweed_b_07", "seaweed_b_08"]
        case .seaweedC:
            ["seaweed_c_01", "seaweed_c_02", "seaweed_c_03", "seaweed_c_04",
             "seaweed_c_05", "seaweed_c_06", "seaweed_c_07", "seaweed_c_08"]
        case .seaweed, .rock:
            []
        }
    }

    /// frame間隔にはcross fade時間を含む。
    var animationFrameDuration: TimeInterval { (self == .seaweedA || self == .seaweedB || self == .seaweedC) ? 0.25 : 0.9 }
    var animationCrossFadeDuration: TimeInterval { (self == .seaweedA || self == .seaweedB || self == .seaweedC) ? 0.1 : 0 }

    var displaySize: CGSize {
        // 新素材は512×768。比率を保ち、広がった葉も★1装飾として控えめな大きさにする。
        switch self {
        case .seaweedA: CGSize(width: 84, height: 126)
        // Bは512×1024。Aの約1.4倍の高さで、横幅は控えめに維持する。
        case .seaweedB: CGSize(width: 88, height: 176)
        // Cは768×512。透過余白を除いた見た目はAの高さ約68%、幅約1.58倍。
        case .seaweedC: CGSize(width: 126, height: 84)
        case .seaweed, .rock: CGSize(width: 120, height: 120)
        }
    }

    /// 画像内の根元。配置座標を根元として描画するためのアンカー（上端=0、下端=1）。
    var groundAnchorY: CGFloat? {
        switch self {
        case .seaweedA: 0.965
        // Bの透過余白を除いた根元（約1001/1024）を地面へ合わせる。
        case .seaweedB: 0.978
        // Cの根元は全frame共通で約489/512。
        case .seaweedC: 0.955
        case .seaweed, .rock: nil
        }
    }

    func groundAnchorOffset(scale: CGFloat = 1) -> CGFloat {
        groundAnchorY.map { (0.5 - $0) * displaySize.height * scale } ?? 0
    }

    /// 透過余白を除いた横方向の占有範囲（画像幅=0〜1）。配置時の安全marginに使う。
    var placementHorizontalContentBounds: ClosedRange<CGFloat> {
        // 透過余白を見込んだ既存の配置marginを維持する。
        switch self {
        case .seaweedA, .seaweedB: 0.07...0.89
        // Cの全frameの占有範囲（x=41〜691/768）を余裕を持って包含。
        case .seaweedC: 0.05...0.91
        case .seaweed, .rock: 0...1
        }
    }

    var assetImageName: String? {
        animationFrameNames.first
    }

    var displayName: String {
        switch self {
        case .seaweed: "水草"
        case .rock: "岩"
        case .seaweedA: "海藻A"
        case .seaweedB: "海藻B"
        case .seaweedC: "海藻C"
        }
    }

    var storageIconName: String {
        switch self {
        case .seaweed, .seaweedA, .seaweedB, .seaweedC: "leaf.fill"
        case .rock: "mountain.2.fill"
        }
    }

    var restorationPosition: CGPoint {
        switch self {
        case .seaweed: CGPoint(x: 0.5, y: 0.80)
        case .rock: CGPoint(x: 0.5, y: 0.84)
        case .seaweedA, .seaweedB, .seaweedC: CGPoint(x: 0.5, y: 0.92)
        }
    }

    /// 種類ごとの配置可能範囲。将来の浮遊装飾はここで別の範囲を指定できる。
    var movementBounds: AquariumDecorationMovementBounds {
        switch self {
        case .seaweed:
            AquariumDecorationMovementBounds(x: 0.10...0.90, y: 0.68...0.90)
        case .rock:
            AquariumDecorationMovementBounds(x: 0.10...0.90, y: 0.72...0.92)
        case .seaweedA, .seaweedB, .seaweedC:
            .commonGround
        }
    }
}

struct AquariumDecoration: Identifiable, Codable {
    let id: String
    let kind: AquariumDecorationKind

    /// 画面サイズに依存しない0〜1の相対座標。
    let relativeX: CGFloat
    let relativeY: CGFloat
    let scale: CGFloat
}

@Model
final class AquariumDecorationPlacement {
    /// 既存の保存名はdecorationIDだが、これは個体ごとのPlacement ID。定義IDとは別。
    @Attribute(.unique) var decorationID: String
    var kindRawValue: String
    var relativeX: Double
    var relativeY: Double
    var scale: Double
    var isPlaced: Bool = true

    init(
        decorationID: String = UUID().uuidString,
        kind: AquariumDecorationKind,
        relativeX: Double,
        relativeY: Double,
        scale: Double,
        isPlaced: Bool = true
    ) {
        self.decorationID = decorationID
        self.kindRawValue = kind.rawValue
        self.relativeX = relativeX
        self.relativeY = relativeY
        self.scale = scale
        self.isPlaced = isPlaced
    }

    var kind: AquariumDecorationKind {
        AquariumDecorationKind(rawValue: kindRawValue) ?? .rock
    }

    var definitionID: String { kind.rawValue }

    var decoration: AquariumDecoration {
        AquariumDecoration(
            id: decorationID,
            kind: kind,
            relativeX: CGFloat(relativeX),
            relativeY: CGFloat(relativeY),
            scale: CGFloat(scale)
        )
    }
}
