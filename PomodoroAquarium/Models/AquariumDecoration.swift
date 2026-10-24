//
//  AquariumDecoration.swift
//  PomodoroAquarium
//

import CoreGraphics
import Foundation
import SwiftData

enum AquariumDecorationKind: String, Codable, CaseIterable {
    // 旧保存値の読み込み専用。通常の一覧・生成・描画には使用しない。
    case seaweed
    case rock
    case unsupported
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
    case treasureChest = "treasure_chest"
    case shipwreck = "shipwreck_distant"
}

enum AquariumDecorationType: String {
    case object
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
    // 沈没船はこの帯を使用せず、左右の遠景固定位置を使う。
    static let commonGround = AquariumDecorationMovementBounds(x: -1...2, y: 0.66...0.995)
}

/// 装飾ZStack内の優先度。Y順序（0〜1）で種類間の順序は逆転しない。
enum AquariumDecorationRenderLayer: Double {
    case rock = 0
    case object = 1
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
    var isLegacyPlaceholder: Bool { self == .seaweed || self == .rock }
    var isAvailable: Bool { !isLegacyPlaceholder && self != .unsupported }
    static var availableKinds: [Self] { allCases.filter(\.isAvailable) }
    static func isLegacyPlaceholder(rawValue: String) -> Bool {
        Self(rawValue: rawValue)?.isLegacyPlaceholder == true
    }
    /// 将来の中岩はrock、サンゴ等はvegetationを同じカテゴリ規則で利用できる。
    var renderLayer: AquariumDecorationRenderLayer {
        self == .treasureChest ? .object : (category == .rock ? .rock : .vegetation)
    }

    var supportsFacingDirection: Bool { self == .treasureChest || self == .shipwreck }

    var category: AquariumDecorationCategory {
        switch self {
        case .treasureChest, .shipwreck, .unsupported: .object
        case .coralAPink, .coralAOrange, .coralAPurple, .coralBPink, .coralBOrange, .coralBPurple, .coralCPink, .coralCOrange, .coralCPurple: .coral
        case .seaweed, .seaweedA, .seaweedB, .seaweedC: .plant
        case .rock, .smallRockA, .smallRockB, .smallRockC, .mediumRockA, .mediumRockB, .mediumRockC: .rock
        }
    }

    var decorationType: AquariumDecorationType {
        switch self {
        case .treasureChest, .shipwreck, .unsupported: .object
        case .coralAPink, .coralAOrange, .coralAPurple, .coralBPink, .coralBOrange, .coralBPurple, .coralCPink, .coralCOrange, .coralCPurple: .coral
        case .seaweed, .seaweedA, .seaweedB, .seaweedC: .seaweed
        case .rock, .smallRockA, .smallRockB, .smallRockC, .mediumRockA, .mediumRockB, .mediumRockC: .rock
        }
    }

    /// 装飾のstable IDはkindのrawValue。価格は将来用の定義のみで購入処理には未接続。
    var stars: Int? {
        switch self {
        case .treasureChest, .shipwreck: 3
        case .coralAPink, .coralAOrange, .coralAPurple, .coralBPink, .coralBOrange, .coralBPurple, .coralCPink, .coralCOrange, .coralCPurple: 2
        case .mediumRockA, .mediumRockB, .mediumRockC: 2
        default: (self == .seaweedA || self == .seaweedB || self == .seaweedC || usesBackgroundVariants) ? 1 : nil
        }
    }
    var plannedPrice: Int? {
        switch self {
        case .shipwreck: 1000
        case .treasureChest: 500
        case .coralAPink, .coralAOrange, .coralAPurple, .coralBPink, .coralBOrange, .coralBPurple, .coralCPink, .coralCOrange, .coralCPurple: 130
        case .mediumRockA, .mediumRockB, .mediumRockC: 80
        default: (self == .seaweedA || self == .seaweedB || self == .seaweedC || usesBackgroundVariants) ? 30 : nil
        }
    }

    var animationFrameNames: [String] {
        switch self {
        case .treasureChest, .shipwreck: []
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
        case .seaweed, .rock, .unsupported, .smallRockA, .smallRockB, .smallRockC, .mediumRockA, .mediumRockB, .mediumRockC:
            []
        }
    }

    /// frame間隔にはcross fade時間を含む。
    var animationFrameDuration: TimeInterval { (self == .seaweedA || self == .seaweedB || self == .seaweedC) ? 0.25 : 0.9 }
    var animationCrossFadeDuration: TimeInterval { (self == .seaweedA || self == .seaweedB || self == .seaweedC) ? 0.1 : 0 }

    var displaySize: CGSize {
        // 新素材は512×768。比率を保ち、広がった葉も★1装飾として控えめな大きさにする。
        switch self {
        case .unsupported: .zero
        case .shipwreck: CGSize(width: 150, height: 100) // 一覧専用。水槽は遠景設定から算出。
        case .treasureChest: CGSize(width: AquariumTreasureChestEffects.canvasSide, height: AquariumTreasureChestEffects.canvasSide)
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
        case .shipwreck: nil
        case .treasureChest: 1239.0 / 1254
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
        case .seaweed, .rock, .unsupported: nil
        }
    }

    func groundAnchorY(facingDirection: AquariumDecorationFacingDirection) -> CGFloat? {
        self == .treasureChest ? (facingDirection == .right ? 1239.0 : 1228.0) / 1254 : groundAnchorY
    }

    func groundAnchorOffset(scale: CGFloat = 1, facingDirection: AquariumDecorationFacingDirection = .right) -> CGFloat {
        groundAnchorY(facingDirection: facingDirection).map { (0.5 - $0) * displaySize.height * scale } ?? 0
    }

    /// 透過余白を除いた横方向の占有範囲（画像幅=0〜1）。配置時の安全marginに使う。
    var placementHorizontalContentBounds: ClosedRange<CGFloat> {
        // 透過余白を見込んだ既存の配置marginを維持する。
        switch self {
        case .shipwreck: 0...1
        case .treasureChest: 0.01...0.99
        case .coralAPink, .coralAOrange, .coralAPurple, .coralBPink, .coralBOrange, .coralBPurple, .coralCPink, .coralCOrange, .coralCPurple: 0.015...0.985
        case .seaweedA, .seaweedB: 0.07...0.89
        // Cの全frameの占有範囲（x=41〜691/768）を余裕を持って包含。
        case .seaweedC: 0.05...0.91
        // 3背景共通のalpha占有範囲x=16〜751/768を包含。
        case .smallRockA, .smallRockB, .smallRockC: 0.02...0.98
        // A/Bはx=17〜1006/1024、Cはx=17〜750/768を余裕を持って包含。
        case .mediumRockA, .mediumRockB: 0.015...0.985
        case .mediumRockC: 0.02...0.98
        case .seaweed, .rock, .unsupported: 0...1
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
    func assetImageName(for backgroundTheme: AquariumBackgroundTheme, facingDirection: AquariumDecorationFacingDirection = .right) -> String? {
        if self == .shipwreck { return rawValue }
        if self == .treasureChest { return facingDirection == .right ? "treasure_chest_right_open" : "treasure_chest_left_open" }
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
        case .unsupported: "未対応の装飾"
        case .shipwreck: "沈没船"
        case .treasureChest: "宝箱"
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
        case .unsupported: "questionmark"
        case .shipwreck: "sailboat.fill"
        case .treasureChest: "shippingbox.fill"
        case .coralAPink, .coralAOrange, .coralAPurple, .coralBPink, .coralBOrange, .coralBPurple, .coralCPink, .coralCOrange, .coralCPurple: "tree.fill"
        case .seaweed, .seaweedA, .seaweedB, .seaweedC: "leaf.fill"
        case .rock, .smallRockA, .smallRockB, .smallRockC, .mediumRockA, .mediumRockB, .mediumRockC: "mountain.2.fill"
        }
    }

    var restorationPosition: CGPoint {
        switch self {
        case .unsupported: CGPoint(x: 0.5, y: 0.5)
        case .shipwreck: CGPoint(x: 0.29, y: 0.438)
        case .treasureChest: CGPoint(x: 0.5, y: 0.92)
        case .coralAPink, .coralAOrange, .coralAPurple, .coralBPink, .coralBOrange, .coralBPurple, .coralCPink, .coralCOrange, .coralCPurple: CGPoint(x: 0.5, y: 0.92)
        case .seaweed: CGPoint(x: 0.5, y: 0.80)
        case .rock: CGPoint(x: 0.5, y: 0.84)
        case .seaweedA, .seaweedB, .seaweedC, .smallRockA, .smallRockB, .smallRockC, .mediumRockA, .mediumRockB, .mediumRockC: CGPoint(x: 0.5, y: 0.92)
        }
    }

    /// 種類ごとの配置可能範囲。将来の浮遊装飾はここで別の範囲を指定できる。
    var movementBounds: AquariumDecorationMovementBounds {
        switch self {
        case .shipwreck, .unsupported: AquariumDecorationMovementBounds(x: 0...1, y: 0...1)
        case .treasureChest: .commonGround
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

nonisolated enum AquariumDecorationFacingDirection: String, Codable, CaseIterable {
    case right, left
    var opposite: Self { self == .right ? .left : .right }
}

struct AquariumDecoration: Identifiable, Codable {
    let id: String
    let kind: AquariumDecorationKind

    /// 画面サイズに依存しない相対座標。左右の一部はみ出しは0未満・1超も保存する。
    let relativeX: CGFloat
    let relativeY: CGFloat
    let scale: CGFloat
    var facingDirection: AquariumDecorationFacingDirection = .right
    var zOrder: Int = 0
    var rockIsForeground: Bool = false
    var isStackingOrderInitialized: Bool = false

    private enum CodingKeys: String, CodingKey { case id, kind, relativeX, relativeY, scale, facingDirection, zOrder, rockIsForeground, isStackingOrderInitialized }
    init(id: String, kind: AquariumDecorationKind, relativeX: CGFloat, relativeY: CGFloat, scale: CGFloat,
         facingDirection: AquariumDecorationFacingDirection = .right, zOrder: Int = 0, rockIsForeground: Bool = false, isStackingOrderInitialized: Bool = false) {
        self.id = id; self.kind = kind; self.relativeX = relativeX; self.relativeY = relativeY
        self.scale = scale; self.facingDirection = facingDirection
        self.zOrder = zOrder; self.rockIsForeground = rockIsForeground
        self.isStackingOrderInitialized = isStackingOrderInitialized
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        kind = try c.decode(AquariumDecorationKind.self, forKey: .kind)
        relativeX = try c.decode(CGFloat.self, forKey: .relativeX)
        relativeY = try c.decode(CGFloat.self, forKey: .relativeY)
        scale = try c.decode(CGFloat.self, forKey: .scale)
        facingDirection = try c.decodeIfPresent(AquariumDecorationFacingDirection.self, forKey: .facingDirection) ?? .right
        zOrder = try c.decodeIfPresent(Int.self, forKey: .zOrder) ?? 0
        rockIsForeground = try c.decodeIfPresent(Bool.self, forKey: .rockIsForeground) ?? false
        isStackingOrderInitialized = try c.decodeIfPresent(Bool.self, forKey: .isStackingOrderInitialized) ?? false
    }
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
    /// Optional追加で旧SwiftDataレコードを保持。旧レコードのnilは右側面として表示。
    var facingDirectionRawValue: String? = nil
    var zOrder: Int = 0
    var rockIsForeground: Bool = false
    var isStackingOrderInitialized: Bool = false

    init(
        decorationID: String = UUID().uuidString,
        kind: AquariumDecorationKind,
        relativeX: Double,
        relativeY: Double,
        scale: Double,
        isPlaced: Bool = true,
        facingDirection: AquariumDecorationFacingDirection = .right,
        zOrder: Int = 0, rockIsForeground: Bool = false, isStackingOrderInitialized: Bool = false
    ) {
        self.decorationID = decorationID
        self.kindRawValue = kind.rawValue
        self.relativeX = relativeX
        self.relativeY = relativeY
        self.scale = scale
        self.isPlaced = isPlaced
        self.zOrder = zOrder; self.rockIsForeground = rockIsForeground
        self.isStackingOrderInitialized = isStackingOrderInitialized
        self.facingDirectionRawValue = kind.supportsFacingDirection ? facingDirection.rawValue : nil
    }

    var kind: AquariumDecorationKind {
        AquariumDecorationKind(rawValue: kindRawValue) ?? .unsupported
    }

    var definitionID: String { kind.rawValue }

    var facingDirection: AquariumDecorationFacingDirection {
        get { facingDirectionRawValue.flatMap(AquariumDecorationFacingDirection.init(rawValue:)) ?? .right }
        set { if kind.supportsFacingDirection { facingDirectionRawValue = newValue.rawValue } }
    }

    var decoration: AquariumDecoration {
        AquariumDecoration(
            id: decorationID,
            kind: kind,
            relativeX: CGFloat(relativeX),
            relativeY: CGFloat(relativeY),
            scale: CGFloat(scale),
            facingDirection: facingDirection, zOrder: zOrder, rockIsForeground: rockIsForeground, isStackingOrderInitialized: isStackingOrderInitialized
        )
    }
}

/// 重なり順序だけを管理。地面のY・scale・opacityや魚のレイヤーは変更しない。
enum AquariumDecorationStacking {
    enum Action: String, CaseIterable {
        case front, forward, backward, back
        var title: String {
            switch self {
            case .front: "一番手前へ"
            case .forward: "1つ手前へ"
            case .backward: "1つ奥へ"
            case .back: "一番奥へ"
            }
        }
    }
    /// 旧データの表示を保持するためだけの分類。補完済みの装飾には種類別制限を設けない。
    static func group(_ decoration: AquariumDecoration) -> Int {
        !decoration.isStackingOrderInitialized && decoration.kind.category == .rock && !decoration.rockIsForeground ? 0 : 1
    }
    static func isBehind(_ lhs: AquariumDecoration, _ rhs: AquariumDecoration) -> Bool {
        let a = group(lhs), b = group(rhs)
        if a != b { return a < b }
        if lhs.zOrder != rhs.zOrder { return lhs.zOrder < rhs.zOrder }
        if !lhs.isStackingOrderInitialized || !rhs.isStackingOrderInitialized {
            let left = AquariumDecorationDepthPresentation(kind: lhs.kind, relativeY: lhs.relativeY).zIndex
            let right = AquariumDecorationDepthPresentation(kind: rhs.kind, relativeY: rhs.relativeY).zIndex
            if left != right { return left < right }
        }
        return lhs.id < rhs.id
    }
    @MainActor
    private static func ordered(_ placements: [AquariumDecorationPlacement]) -> [AquariumDecorationPlacement] {
        placements.filter { $0.isPlaced && $0.kind != .shipwreck }.sorted { isBehind($0.decoration, $1.decoration) }
    }
    private static func destination(_ action: Action, index: Int, count: Int) -> Int {
        switch action {
        case .front: count - 1
        case .forward: min(count - 1, index + 1)
        case .backward: max(0, index - 1)
        case .back: 0
        }
    }
    @MainActor
    static func canMove(_ placement: AquariumDecorationPlacement, action: Action,
                        among placements: [AquariumDecorationPlacement], within members: Set<String>) -> Bool {
        let items = ordered(placements).filter { members.contains($0.decorationID) }
        guard Set(items.map(\.zOrder)).count == items.count else { return false }
        guard let index = items.firstIndex(where: { $0.decorationID == placement.decorationID }) else { return false }
        return destination(action, index: index, count: items.count) != index
    }
    @MainActor @discardableResult
    static func move(_ placement: AquariumDecorationPlacement, action: Action,
                     among placements: [AquariumDecorationPlacement], within members: Set<String>) -> Bool {
        var items = ordered(placements).filter { members.contains($0.decorationID) }
        guard let index = items.firstIndex(where: { $0.decorationID == placement.decorationID }) else { return false }
        let target = destination(action, index: index, count: items.count)
        guard target != index else { return false }
        let slots = items.map(\.zOrder)
        guard Set(slots).count == slots.count else { return false }
        items.remove(at: index)
        items.insert(placement, at: target)
        for (index, item) in items.enumerated() {
            item.zOrder = slots[index]
        }
        return true
    }
    @MainActor
    static func insertNew(_ placement: AquariumDecorationPlacement, among placements: [AquariumDecorationPlacement]) {
        guard placement.kind != .shipwreck else { return }
        var items = ordered(placements).filter { $0.decorationID != placement.decorationID }
        items.insert(placement, at: placement.kind.category == .rock ? 0 : items.count)
        assignOrder(items)
    }
    @MainActor
    private static func assignOrder(_ items: [AquariumDecorationPlacement]) {
        for (index, item) in items.enumerated() {
            item.zOrder = index + 1
            item.isStackingOrderInitialized = true
        }
    }
}
