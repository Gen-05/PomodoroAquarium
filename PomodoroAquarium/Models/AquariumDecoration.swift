//
//  AquariumDecoration.swift
//  PomodoroAquarium
//

import CoreGraphics
import SwiftData

enum AquariumDecorationKind: String, Codable, CaseIterable {
    case seaweed
    case rock
}

struct AquariumDecorationMovementBounds {
    let x: ClosedRange<CGFloat>
    let y: ClosedRange<CGFloat>
}

extension AquariumDecorationKind {
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
        decorationID: String,
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
