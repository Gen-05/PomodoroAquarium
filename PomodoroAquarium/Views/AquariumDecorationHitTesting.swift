import SwiftUI
import UIKit

/// 小さなalphaマスクを素材ごとに一度作成。海藻は全frameの可視領域を合成する。
@MainActor
enum AquariumDecorationHitTesting {
    private static var masks: [String: [UInt8]] = [:]
    private static let resolution = 96

    static func selectedID(at point: CGPoint, decorations: [AquariumDecoration],
                           aquariumSize: CGSize, theme: AquariumBackgroundTheme) -> String? {
        let ordered = decorations.enumerated().sorted {
            let left = AquariumDecorationDepthPresentation(kind: $0.element.kind, relativeY: $0.element.relativeY).zIndex
            let right = AquariumDecorationDepthPresentation(kind: $1.element.kind, relativeY: $1.element.relativeY).zIndex
            return left == right ? $0.offset > $1.offset : left > right
        }.map(\.element)
        // 透明部分は後ろへ通す。余裕判定は全候補の可視領域判定後に行う。
        for tolerance in [CGFloat(0), CGFloat(6)] {
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
                             y: root.y * aquariumSize.height - (decoration.kind.groundAnchorY ?? 0.5) * height)
        let names = decoration.kind.animationFrameNames.isEmpty
            ? [decoration.kind.assetImageName(for: theme)].compactMap { $0 }
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
