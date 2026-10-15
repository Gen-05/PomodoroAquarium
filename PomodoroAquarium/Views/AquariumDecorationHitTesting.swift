import SwiftUI
import UIKit

/// 小さなalphaマスクを素材ごとに一度作成。海藻は全frameの可視領域を合成する。
@MainActor
enum AquariumDecorationHitTesting {
    private static var masks: [String: [UInt8]] = [:]
    private static let resolution = 96
    private static var silhouettes: [String: [UInt8]] = [:]

    static func selectedID(at point: CGPoint, decorations: [AquariumDecoration],
                           aquariumSize: CGSize, theme: AquariumBackgroundTheme, allowsTouchPadding: Bool = true) -> String? {
        let ordered = decorations.enumerated().sorted {
            AquariumDecorationStacking.isBehind($1.element, $0.element)
        }.map(\.element)
        // 透明部分は後ろへ通す。余裕判定は全候補の可視領域判定後に行う。
        for tolerance in (allowsTouchPadding ? [CGFloat(0), CGFloat(6)] : [CGFloat(0)]) {
            if let hit = ordered.first(where: {
                contains(point, decoration: $0, root: CGPoint(x: $0.relativeX, y: $0.relativeY),
                         aquariumSize: aquariumSize, theme: theme, tolerance: tolerance)
            }) { return hit.id }
        }
        return nil
    }

    static func contains(_ point: CGPoint, decoration: AquariumDecoration, root: CGPoint,
                         aquariumSize: CGSize, theme: AquariumBackgroundTheme, tolerance: CGFloat = 0) -> Bool {
        let depth = AquariumDecorationDepthPresentation(kind: decoration.kind, relativeY: root.y)
        let scale = decoration.scale * depth.scale
        let width = decoration.kind.displaySize.width * scale
        let height = decoration.kind.displaySize.height * scale
        guard width > 0, height > 0 else { return false }
        let origin = CGPoint(x: root.x * aquariumSize.width - width / 2,
                             y: root.y * aquariumSize.height - (decoration.kind.groundAnchorY(facingDirection: decoration.facingDirection) ?? 0.5) * height)
        let names = decoration.kind.animationFrameNames.isEmpty
            ? [decoration.kind.assetImageName(for: theme, facingDirection: decoration.facingDirection)].compactMap { $0 }
            : decoration.kind.animationFrameNames
        guard !names.isEmpty else {
            return CGRect(origin: origin, size: CGSize(width: width, height: height)).insetBy(dx: -tolerance, dy: -tolerance).contains(point)
        }
        let px = (point.x - origin.x) / width * CGFloat(resolution)
        let py = (point.y - origin.y) / height * CGFloat(resolution)
        let rx = Int(ceil(tolerance / width * CGFloat(resolution)))
        let ry = Int(ceil(tolerance / height * CGFloat(resolution)))
        let left = max(0, Int(floor(px)) - rx), right = min(resolution - 1, Int(floor(px)) + rx)
        let top = max(0, Int(floor(py)) - ry), bottom = min(resolution - 1, Int(floor(py)) + ry)
        guard left <= right, top <= bottom else { return false }
        for name in names {
            let mask = alphaMask(name)
            for y in top...bottom {
                for x in left...right where mask[y * resolution + x] > 24 { return true }
            }
        }
        return false
    }

    struct OverlapShape {
        let rect: CGRect
        let visibleBounds: CGRect
        let mask: [UInt8]
        let visibleArea: CGFloat
        private func covers(_ point: CGPoint) -> Bool {
            let x = Int((point.x - rect.minX) / rect.width * CGFloat(resolution))
            let y = Int((point.y - rect.minY) / rect.height * CGFloat(resolution))
            return x >= 0 && x < resolution && y >= 0 && y < resolution && mask[y * resolution + x] > 40
        }
        func overlaps(_ other: Self) -> Bool {
            let intersection = visibleBounds.intersection(other.visibleBounds)
            guard !intersection.isNull, intersection.width > 0, intersection.height > 0 else { return false }
            // 輪郭の接触だけを除外。小さい側の可視面積の1%以上、最低12pt²を必要とする。
            let threshold = max(12, min(visibleArea, other.visibleArea) * 0.01)
            guard intersection.width * intersection.height >= threshold else { return false }
            let step = max(0.75, min(rect.width, rect.height, other.rect.width, other.rect.height) / CGFloat(resolution))
            var area: CGFloat = 0
            for y in stride(from: intersection.minY + step / 2, to: intersection.maxY, by: step) {
                for x in stride(from: intersection.minX + step / 2, to: intersection.maxX, by: step) {
                    let p = CGPoint(x: x, y: y)
                    if covers(p) && other.covers(p) {
                        area += step * step
                        if area >= threshold { return true }
                    }
                }
            }
            return false
        }
    }

    static func overlapShape(for decoration: AquariumDecoration, aquariumSize: CGSize,
                             theme: AquariumBackgroundTheme) -> OverlapShape {
        let depth = AquariumDecorationDepthPresentation(kind: decoration.kind, relativeY: decoration.relativeY)
        let scale = decoration.scale * depth.scale
        let width = decoration.kind.displaySize.width * scale, height = decoration.kind.displaySize.height * scale
        let rect = CGRect(x: decoration.relativeX * aquariumSize.width - width / 2,
            y: decoration.relativeY * aquariumSize.height - height * (decoration.kind.groundAnchorY(facingDirection: decoration.facingDirection) ?? 0.5),
            width: width, height: height)
        let names = decoration.kind.animationFrameNames.isEmpty
            ? [decoration.kind.assetImageName(for: theme, facingDirection: decoration.facingDirection)].compactMap { $0 }
            : decoration.kind.animationFrameNames
        let key = names.joined(separator: "|")
        let mask: [UInt8]
        if names.isEmpty {
            // 素材を持たない旧仮置き装飾のみ、中央の楕円による近似を使う。
            mask = (0..<(resolution * resolution)).map { index in
                let x = (Double(index % resolution) + 0.5) / Double(resolution) * 2 - 1
                let y = (Double(index / resolution) + 0.5) / Double(resolution) * 2 - 1
                return x * x + y * y < 1 ? 255 : 0
            }
        } else if let cached = silhouettes[key] { mask = cached }
        else {
            var combined = [UInt8](repeating: 0, count: resolution * resolution)
            for name in names {
                let alpha = alphaMask(name)
                for index in combined.indices { combined[index] = max(combined[index], alpha[index]) }
            }
            silhouettes[key] = combined; mask = combined
        }
        let occupied = mask.indices.filter { mask[$0] > 40 }
        guard width > 0, height > 0, let minX = occupied.map({ $0 % resolution }).min(),
              let maxX = occupied.map({ $0 % resolution }).max(), let minY = occupied.map({ $0 / resolution }).min(),
              let maxY = occupied.map({ $0 / resolution }).max() else {
            return OverlapShape(rect: rect, visibleBounds: .null, mask: mask, visibleArea: 0)
        }
        let bounds = CGRect(x: rect.minX + CGFloat(minX) / CGFloat(resolution) * width,
            y: rect.minY + CGFloat(minY) / CGFloat(resolution) * height,
            width: CGFloat(maxX - minX + 1) / CGFloat(resolution) * width,
            height: CGFloat(maxY - minY + 1) / CGFloat(resolution) * height)
        return OverlapShape(rect: rect, visibleBounds: bounds.intersection(CGRect(origin: .zero, size: aquariumSize)), mask: mask,
            visibleArea: CGFloat(occupied.count) / CGFloat(resolution * resolution) * width * height)
    }

    private static func alphaMask(_ name: String) -> [UInt8] {
        if let mask = masks[name] { return mask }
        guard let image = UIImage(named: name)?.cgImage else { return Array(repeating: 0, count: resolution * resolution) }
        var rgba = [UInt8](repeating: 0, count: resolution * resolution * 4)
        rgba.withUnsafeMutableBytes { bytes in
            guard let context = CGContext(data: bytes.baseAddress, width: resolution, height: resolution,
                bitsPerComponent: 8, bytesPerRow: resolution * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
            context.translateBy(x: 0, y: CGFloat(resolution))
            context.scaleBy(x: 1, y: -1)
            context.draw(image, in: CGRect(x: 0, y: 0, width: resolution, height: resolution))
        }
        let mask = (0..<(resolution * resolution)).map { rgba[$0 * 4 + 3] }
        masks[name] = mask
        return mask
    }
}
