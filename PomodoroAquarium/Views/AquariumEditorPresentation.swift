import SwiftUI

/// 新規追加時だけ渡す一時的な演出。保存データや復元処理には含めない。
struct AquariumFishAppearance {
    static let duration: TimeInterval = 1
    let startedAt: Date

    func progress(at date: Date) -> CGFloat {
        min(max(date.timeIntervalSince(startedAt) / Self.duration, 0), 1)
    }

    func fishProgress(at date: Date) -> CGFloat {
        let value = min(max((progress(at: date) - 0.12) / 0.68, 0), 1)
        return value * value * (3 - 2 * value)
    }
}

struct AquariumFishAppearanceRing: View {
    let progress: CGFloat
    var body: some View {
        Circle()
            .stroke(Color.white.opacity(0.9), lineWidth: 1.5)
            .background(Circle().stroke(Color.cyan, lineWidth: 3).blur(radius: 2))
            .frame(width: 28 + 52 * progress, height: 28 + 52 * progress)
            .opacity(Double(min(progress / 0.12, 1) * (1 - progress)))
            .shadow(color: .cyan.opacity(0.8), radius: 3)
            .allowsHitTesting(false)
            .accessibilityIdentifier("aquariumEditor.fishAppearanceRing")
    }
}

enum AquariumEditorInitialPlacement {
    static func fish(species: FishSpecies, size: CGSize, neighbors: [CGPoint]) -> CGPoint {
        let bounds = AquariumFishMotion.movementProfile(for: species).roamingStyle.bounds(
            in: size, fishSize: AquariumFishSizing.displaySize(for: species, isFavorite: false))
        let candidates = [CGPoint(x: 0.5, y: 0.4), CGPoint(x: 0.3, y: 0.4),
                          CGPoint(x: 0.7, y: 0.4), CGPoint(x: 0.35, y: 0.55), CGPoint(x: 0.65, y: 0.55)]
            .map { AquariumFishMotion.clampedPoint($0, bounds: bounds) }
        return candidates.max { score($0, neighbors: neighbors) < score($1, neighbors: neighbors) } ?? CGPoint(x: 0.5, y: 0.4)
    }

    private static func score(_ point: CGPoint, neighbors: [CGPoint]) -> CGFloat {
        let separation = neighbors.map { hypot(point.x - $0.x, point.y - $0.y) }.min() ?? 1
        return separation - hypot(point.x - 0.5, point.y - 0.4) * 0.1
    }

    static func decoration(kind: AquariumDecorationKind, scale: CGFloat, size: CGSize,
                           existing: [AquariumDecoration]) -> CGPoint {
        guard size.width > 0, size.height > 0 else { return kind.restorationPosition }
        let band = kind.movementBounds.y
        let menu = CGRect(x: (size.width - 260) / 2, y: size.height - 95, width: 260, height: 60)
        let canvas = CGRect(origin: .zero, size: size)
        let occupied = existing.map { rect(kind: $0.kind, scale: $0.scale, root: CGPoint(x: $0.relativeX, y: $0.relativeY), size: size) }
        var best = kind.restorationPosition
        var bestScore = -CGFloat.infinity
        for fraction in [CGFloat(0.3), 0.5, 0.7] {
            for x in [CGFloat(0.25), 0.75, 0.5, 0.15, 0.85] {
                let root = AquariumDecorationEditor.relativePosition(
                    forDropLocation: CGPoint(x: x * size.width, y: (band.lowerBound + (band.upperBound - band.lowerBound) * fraction) * size.height),
                    aquariumSize: size, kind: kind, scale: scale)
                let frame = rect(kind: kind, scale: scale, root: root, size: size)
                let area = max(frame.width * frame.height, 1)
                let overlap = occupied.reduce(CGFloat.zero) { $0 + intersectionArea(frame, $1) }
                let value = intersectionArea(frame, canvas) / area
                    - 4 * intersectionArea(frame, menu) / area - overlap / area
                if value > bestScore { bestScore = value; best = root }
            }
        }
        return best
    }

    private static func intersectionArea(_ first: CGRect, _ second: CGRect) -> CGFloat {
        let result = first.intersection(second)
        return result.isNull ? 0 : result.width * result.height
    }

    private static func rect(kind: AquariumDecorationKind, scale: CGFloat, root: CGPoint, size: CGSize) -> CGRect {
        let depth = AquariumDecorationDepthPresentation(kind: kind, relativeY: root.y)
        let width = kind.displaySize.width * scale * depth.scale
        let height = kind.displaySize.height * scale * depth.scale
        let content = kind.placementHorizontalContentBounds
        return CGRect(x: root.x * size.width + (content.lowerBound - 0.5) * width,
                      y: root.y * size.height - (kind.groundAnchorY ?? 0.5) * height,
                      width: (content.upperBound - content.lowerBound) * width, height: height)
    }
}
