import SwiftUI

/// 配置形状だけをキーにキャッシュ。順序・魚・粒子・アニメーション時刻は判定に含めない。
@MainActor
enum AquariumDecorationOverlapGroups {
    private struct Geometry: Equatable {
        let id: String
        let kind: AquariumDecorationKind
        let x, y, scale: CGFloat
        let direction: AquariumDecorationFacingDirection
    }
    private struct Key: Equatable {
        let size: CGSize
        let theme: AquariumBackgroundTheme
        let items: [Geometry]
    }
    private static var lastKey: Key?
    private static var cached: [String: Set<String>] = [:]

    static func members(of id: String, placements: [AquariumDecorationPlacement],
                        size: CGSize, theme: AquariumBackgroundTheme) -> Set<String> {
        let placed = placements.filter(\.isPlaced).map(\.decoration).sorted { $0.id < $1.id }
        let key = Key(size: size, theme: theme, items: placed.map {
            Geometry(id: $0.id, kind: $0.kind, x: $0.relativeX, y: $0.relativeY, scale: $0.scale, direction: $0.facingDirection)
        })
        if key != lastKey {
            let shapes = placed.map { AquariumDecorationHitTesting.overlapShape(for: $0, aquariumSize: size, theme: theme) }
            var edges = Array(repeating: [Int](), count: placed.count)
            for a in placed.indices {
                for b in placed.indices where b > a {
                    if shapes[a].overlaps(shapes[b]) { edges[a].append(b); edges[b].append(a) }
                }
            }
            var result: [String: Set<String>] = [:]
            // 連結成分ではなく、選択個体自身と直接交差する隣接個体だけ。
            for index in placed.indices {
                result[placed[index].id] = Set([placed[index].id] + edges[index].map { placed[$0].id })
            }
            lastKey = key; cached = result
        }
        return cached[id] ?? []
    }
}
