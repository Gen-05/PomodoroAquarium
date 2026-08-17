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
}

extension AquariumDecorationKind {
    var category: AquariumDecorationCategory {
        switch self {
        case .seaweed: .plant
        case .rock: .rock
        }
    }

    /// 本番素材導入後は種類ごとのAssets名をここへ設定する。
    var assetImageName: String? {
        nil
    }

    var displayName: String {
        switch self {
        case .seaweed: "水草"
        case .rock: "岩"
        }
    }

    var storageIconName: String {
        switch self {
        case .seaweed: "leaf.fill"
        case .rock: "mountain.2.fill"
        }
    }

    var restorationPosition: CGPoint {
        switch self {
        case .seaweed: CGPoint(x: 0.5, y: 0.80)
        case .rock: CGPoint(x: 0.5, y: 0.84)
        }
    }

    /// 種類ごとの配置可能範囲。将来の浮遊装飾はここで別の範囲を指定できる。
    var movementBounds: AquariumDecorationMovementBounds {
        switch self {
        case .seaweed:
            AquariumDecorationMovementBounds(x: 0.10...0.90, y: 0.68...0.90)
        case .rock:
            AquariumDecorationMovementBounds(x: 0.10...0.90, y: 0.72...0.92)
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
