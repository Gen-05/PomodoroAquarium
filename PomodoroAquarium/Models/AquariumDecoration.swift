//
//  AquariumDecoration.swift
//  PomodoroAquarium
//

import CoreGraphics

enum AquariumDecorationKind: String, Codable, CaseIterable {
    case seaweed
    case rock
}

struct AquariumDecoration: Identifiable, Codable {
    let id: String
    let kind: AquariumDecorationKind

    /// 画面サイズに依存しない0〜1の相対座標。
    let relativeX: CGFloat
    let relativeY: CGFloat
    let scale: CGFloat
}
