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
    case smallRockA = "small_rock_a"
    case smallRockB = "small_rock_b"
    case smallRockC = "small_rock_c"
    case mediumRockA = "medium_rock_a"
    case mediumRockB = "medium_rock_b"
    case mediumRockC = "medium_rock_c"
    case coralAPink = "coral_a_pink"
    case coralAOrange = "coral_a_orange"
    case coralAPurple = "coral_a_purple"
    case coralBPink = "coral_b_pink"
    case coralBOrange = "coral_b_orange"
    case coralBPurple = "coral_b_purple"
    case coralCPink = "coral_c_pink"
    case coralCOrange = "coral_c_orange"
    case coralCPurple = "coral_c_purple"
}

enum AquariumDecorationType: String {
    case coral
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
    static let commonGround = AquariumDecorationMovementBounds(x: -1...2, y: 0.66...0.995)
}

/// 装飾ZStack内の優先度。Y順序（0〜1）で種類間の順序は逆転しない。
enum AquariumDecorationRenderLayer: Double {
    case rock = 0
    case vegetation = 2
}

/// 保存済みの位置から都度算出する、水中の距離感。個体のscaleは上書きしない。
struct AquariumDecorationDepthPresentation {
    let depthProgress: CGFloat
    let scale: CGFloat
    let opacity: Double
    let layerPriority: Double
    let depthOrder: Double
    var zIndex: Double { layerPriority + depthOrder }

    /// 操作中だけ装飾内の最前面へ。魚とのZStackの関係は変えない。
    func renderZIndex(isDragging: Bool) -> Double {
        (isDragging ? 4 : layerPriority) + depthOrder
    }

    init(kind: AquariumDecorationKind, relativeY: CGFloat) {
        layerPriority = kind.renderLayer.rawValue
        let orderBounds: ClosedRange<CGFloat> = kind.groundAnchorY == nil ? 0...1 : kind.movementBounds.y
        depthOrder = Double(min(max(relativeY, orderBounds.lowerBound), orderBounds.upperBound))
        guard kind.groundAnchorY != nil else {
            depthProgress = 0
            scale = 1
            opacity = 1
            return
        }
        let band = kind.movementBounds.y
        let y = min(max(relativeY, band.lowerBound), band.upperBound)
        let span = band.upperBound - band.lowerBound
        let depth = span > 0 ? (band.upperBound - y) / span : 0
        depthProgress = depth
        scale = 1 - 0.24 * depth
        opacity = Double(1 - 0.20 * depth)
    }
}

extension AquariumDecorationKind {
    /// 将来の中岩はrock、サンゴ等はvegetationを同じカテゴリ規則で利用できる。
    var renderLayer: AquariumDecorationRenderLayer {
        category == .rock ? .rock : .vegetation
    }

    var category: AquariumDecorationCategory {
        switch self {
        case .coralAPink, .coralAOrange, .coralAPurple, .coralBPink, .coralBOrange, .coralBPurple, .coralCPink, .coralCOrange, .coralCPurple: .coral
        case .seaweed, .seaweedA, .seaweedB, .seaweedC: .plant
        case .rock, .smallRockA, .smallRockB, .smallRockC, .mediumRockA, .mediumRockB, .mediumRockC: .rock
        }
    }

    var decorationType: AquariumDecorationType {
        switch self {
        case .coralAPink, .coralAOrange, .coralAPurple, .coralBPink, .coralBOrange, .coralBPurple, .coralCPink, .coralCOrange, .coralCPurple: .coral
        case .seaweed, .seaweedA, .seaweedB, .seaweedC: .seaweed
        case .rock, .smallRockA, .smallRockB, .smallRockC, .mediumRockA, .mediumRockB, .mediumRockC: .rock
        }
    }

    /// 装飾のstable IDはkindのrawValue。価格は将来用の定義のみで購入処理には未接続。
    var stars: Int? {
        switch self {
        case .coralAPink, .coralAOrange, .coralAPurple, .coralBPink, .coralBOrange, .coralBPurple, .coralCPink, .coralCOrange, .coralCPurple: 2
        case .mediumRockA, .mediumRockB, .mediumRockC: 2
        default: (self == .seaweedA || self == .seaweedB || self == .seaweedC || usesBackgroundVariants) ? 1 : nil
        }
    }
    var plannedPrice: Int? {
        switch self {
        case .coralAPink, .coralAOrange, .coralAPurple, .coralBPink, .coralBOrange, .coralBPurple, .coralCPink, .coralCOrange, .coralCPurple: 130
        case .mediumRockA, .mediumRockB, .mediumRockC: 80
        default: (self == .seaweedA || self == .seaweedB || self == .seaweedC || usesBackgroundVariants) ? 30 : nil
        }
    }

    var animationFrameNames: [String] {
        switch self {
        case .coralAPink, .coralAOrange, .coralAPurple, .coralBPink, .coralBOrange, .coralBPurple, .coralCPink, .coralCOrange, .coralCPurple: []
        case .seaweedA:
            ["seaweed_a_01", "seaweed_a_02", "seaweed_a_03", "seaweed_a_04",
             "seaweed_a_05", "seaweed_a_06", "seaweed_a_07", "seaweed_a_08"]
        case .seaweedB:
            ["seaweed_b_01", "seaweed_b_02", "seaweed_b_03", "seaweed_b_04",
             "seaweed_b_05", "seaweed_b_06", "seaweed_b_07", "seaweed_b_08"]
        case .seaweedC:
            ["seaweed_c_01", "seaweed_c_02", "seaweed_c_03", "seaweed_c_04",
             "seaweed_c_05", "seaweed_c_06", "seaweed_c_07", "seaweed_c_08"]
        case .seaweed, .rock, .smallRockA, .smallRockB, .smallRockC, .mediumRockA, .mediumRockB, .mediumRockC:
            []
        }
    }

    /// frame間隔にはcross fade時間を含む。
    var animationFrameDuration: TimeInterval { (self == .seaweedA || self == .seaweedB || self == .seaweedC) ? 0.25 : 0.9 }
    var animationCrossFadeDuration: TimeInterval { (self == .seaweedA || self == .seaweedB || self == .seaweedC) ? 0.1 : 0 }

    var displaySize: CGSize {
        // 新素材は512×768。比率を保ち、広がった葉も★1装飾として控えめな大きさにする。
        switch self {
        case .coralCPink, .coralCOrange, .coralCPurple: CGSize(width: 124.8, height: 132.6)
        case .coralAPink, .coralAOrange, .coralAPurple: CGSize(width: 100, height: 100)
        case .coralBPink, .coralBOrange, .coralBPurple: CGSize(width: 140.8, height: 70.4)
        case .seaweedA: CGSize(width: 84, height: 126)
        // Bは512×1024。Aの約1.4倍の高さで、横幅は控えめに維持する。
        case .seaweedB: CGSize(width: 88, height: 176)
        // Cは768×512。透過余白を除いた見た目はAの高さ約68%、幅約1.58倍。
        case .seaweedC: CGSize(width: 126, height: 84)
        // 元画像はA=768×448、B=768×272、C=768×400。
        case .smallRockA: CGSize(width: 96, height: 56)
        case .smallRockB: CGSize(width: 112, height: CGFloat(112) * 272 / 768)
        case .smallRockC: CGSize(width: 108, height: 56.25)
        // 中岩の素材比率を維持し、Cの縦長シルエットを残す。
        case .mediumRockA: CGSize(width: 176, height: 77)
        case .mediumRockB: CGSize(width: 168, height: 94.5)
        case .mediumRockC: CGSize(width: 120, height: 145)
        case .seaweed, .rock: CGSize(width: 120, height: 120)
        }
    }

    /// 画像内の根元。配置座標を根元として描画するためのアンカー（上端=0、下端=1）。
    var groundAnchorY: CGFloat? {
        switch self {
        case .coralCPink, .coralCOrange, .coralCPurple: 0.995
        case .coralAPink, .coralAOrange, .coralAPurple: 0.995
        case .coralBPink, .coralBOrange, .coralBPurple: 0.992
        case .seaweedA: 0.965
        // Bの透過余白を除いた根元（約1001/1024）を地面へ合わせる。
        case .seaweedB: 0.978
        // Cの根元は全frame共通で約489/512。
        case .seaweedC: 0.955
        case .smallRockA: 0.995
        case .smallRockB: 0.99
        case .smallRockC: 0.993
        // 3背景共通のalpha底面に根元を合わせる。
        case .mediumRockA: 0.991
        case .mediumRockB: 0.993
        case .mediumRockC: 0.995
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
        case .coralAPink, .coralAOrange, .coralAPurple, .coralBPink, .coralBOrange, .coralBPurple, .coralCPink, .coralCOrange, .coralCPurple: 0.015...0.985
        case .seaweedA, .seaweedB: 0.07...0.89
        // Cの全frameの占有範囲（x=41〜691/768）を余裕を持って包含。
        case .seaweedC: 0.05...0.91
        // 3背景共通のalpha占有範囲x=16〜751/768を包含。
        case .smallRockA, .smallRockB, .smallRockC: 0.02...0.98
        // A/Bはx=17〜1006/1024、Cはx=17〜750/768を余裕を持って包含。
        case .mediumRockA, .mediumRockB: 0.015...0.985
        case .mediumRockC: 0.02...0.98
        case .seaweed, .rock: 0...1
        }
    }

    var usesBackgroundVariants: Bool {
        switch self {
        case .smallRockA, .smallRockB, .smallRockC, .mediumRockA, .mediumRockB, .mediumRockC: true
        default: false
        }
    }

    /// Asset名は定義IDと現在の背景から都度計算し、Placementへ保存しない。
    /// 中岩等も背景別素材を持つkindとして追加すれば同じ規則を利用できる。
    func assetImageName(for backgroundTheme: AquariumBackgroundTheme) -> String? {
        if decorationType == .coral { return rawValue }
        guard usesBackgroundVariants else { return animationFrameNames.first }
        let suffix: String
        switch backgroundTheme {
        case .aquarium: suffix = "basic"
        case .tropical: suffix = "coral"
        case .deepSea: suffix = "deep"
        }
        return "\(rawValue)_\(suffix)"
    }

    var assetImageName: String? {
        assetImageName(for: .aquarium)
    }

    var displayName: String {
        switch self {
        case .coralAPink: "枝サンゴ（ピンク）"
        case .coralAOrange: "枝サンゴ（オレンジ）"
        case .coralAPurple: "枝サンゴ（パープル）"
        case .coralBPink: "丸サンゴ（ピンク）"
        case .coralBOrange: "丸サンゴ（オレンジ）"
        case .coralBPurple: "丸サンゴ（パープル）"
        case .coralCPink: "トゲサンゴ（ピンク）"
        case .coralCOrange: "トゲサンゴ（オレンジ）"
        case .coralCPurple: "トゲサンゴ（パープル）"
        case .seaweed: "水草"
        case .rock: "岩"
        case .seaweedA: "海藻A"
        case .seaweedB: "海藻B"
        case .seaweedC: "海藻C"
        case .smallRockA: "小岩A"
        case .smallRockB: "小岩B"
        case .smallRockC: "小岩C"
        case .mediumRockA: "中岩A"
        case .mediumRockB: "中岩B"
        case .mediumRockC: "中岩C"
        }
    }

    var storageIconName: String {
        switch self {
        case .coralAPink, .coralAOrange, .coralAPurple, .coralBPink, .coralBOrange, .coralBPurple, .coralCPink, .coralCOrange, .coralCPurple: "tree.fill"
        case .seaweed, .seaweedA, .seaweedB, .seaweedC: "leaf.fill"
        case .rock, .smallRockA, .smallRockB, .smallRockC, .mediumRockA, .mediumRockB, .mediumRockC: "mountain.2.fill"
        }
    }

    var restorationPosition: CGPoint {
        switch self {
        case .coralAPink, .coralAOrange, .coralAPurple, .coralBPink, .coralBOrange, .coralBPurple, .coralCPink, .coralCOrange, .coralCPurple: CGPoint(x: 0.5, y: 0.92)
        case .seaweed: CGPoint(x: 0.5, y: 0.80)
        case .rock: CGPoint(x: 0.5, y: 0.84)
        case .seaweedA, .seaweedB, .seaweedC, .smallRockA, .smallRockB, .smallRockC, .mediumRockA, .mediumRockB, .mediumRockC: CGPoint(x: 0.5, y: 0.92)
        }
    }

    /// 種類ごとの配置可能範囲。将来の浮遊装飾はここで別の範囲を指定できる。
    var movementBounds: AquariumDecorationMovementBounds {
        switch self {
        case .coralAPink, .coralAOrange, .coralAPurple, .coralBPink, .coralBOrange, .coralBPurple, .coralCPink, .coralCOrange, .coralCPurple: .commonGround
        case .seaweed:
            AquariumDecorationMovementBounds(x: 0.10...0.90, y: 0.68...0.90)
        case .rock:
            AquariumDecorationMovementBounds(x: 0.10...0.90, y: 0.72...0.92)
        case .seaweedA, .seaweedB, .seaweedC, .smallRockA, .smallRockB, .smallRockC, .mediumRockA, .mediumRockB, .mediumRockC:
            .commonGround
        }
    }
}

struct AquariumDecoration: Identifiable, Codable {
    let id: String
    let kind: AquariumDecorationKind

    /// 画面サイズに依存しない相対座標。左右の一部はみ出しは0未満・1超も保存する。
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
