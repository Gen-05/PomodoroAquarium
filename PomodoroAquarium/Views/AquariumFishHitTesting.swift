import SwiftUI
import UIKit

/// 現在フレームのalphaを小さなマスクへ変換。画像とともに保持してIDの再利用を防ぐ。
@MainActor
enum AquariumFishHitTesting {
    private static var cache: [ObjectIdentifier: (CGImage, [CGRect])] = [:]
    private static let resolution = 96

    static func path(image: UIImage?, canvasSize: CGFloat, fishSize: CGFloat,
                     horizontalScale: CGFloat = 1) -> Path {
        let center = canvasSize / 2
        guard let image, let cgImage = image.cgImage else {
            return Path(ellipseIn: CGRect(x: center - 22, y: center - 22, width: 44, height: 44))
        }
        let fit = fishSize / max(image.size.width, image.size.height)
        let width = image.size.width * fit, height = image.size.height * fit
        // 大型魚は2ptのみ。小型魚は最小44ptの操作余裕を残す。
        let padding = fishSize < 80 ? max(6, (44 - fishSize) / 2) : 2
        var path = Path()
        for span in spans(cgImage) {
            path.addRect(CGRect(x: center - width / 2 + span.minX * width,
                                y: center - height / 2 + span.minY * height,
                                width: span.width * width, height: span.height * height)
                .insetBy(dx: -padding, dy: -padding))
        }
        return path.applying(CGAffineTransform(a: horizontalScale, b: 0, c: 0, d: 1,
                                              tx: center * (1 - horizontalScale), ty: 0))
    }

    private static func spans(_ image: CGImage) -> [CGRect] {
        let key = ObjectIdentifier(image)
        if let cached = cache[key] { return cached.1 }
        var rgba = [UInt8](repeating: 0, count: resolution * resolution * 4)
        rgba.withUnsafeMutableBytes { bytes in
            guard let context = CGContext(data: bytes.baseAddress, width: resolution, height: resolution,
                bitsPerComponent: 8, bytesPerRow: resolution * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
            context.draw(image, in: CGRect(x: 0, y: 0, width: resolution, height: resolution))
        }
        var result: [CGRect] = []
        for y in 0..<resolution {
            var x = 0
            while x < resolution {
                if rgba[(y * resolution + x) * 4 + 3] <= 12 { x += 1; continue }
                let start = x
                while x < resolution && rgba[(y * resolution + x) * 4 + 3] > 12 { x += 1 }
                result.append(CGRect(x: CGFloat(start) / CGFloat(resolution), y: CGFloat(y) / CGFloat(resolution),
                    width: CGFloat(x - start) / CGFloat(resolution), height: 1 / CGFloat(resolution)))
            }
        }
        cache[key] = (image, result)
        return result
    }
}
