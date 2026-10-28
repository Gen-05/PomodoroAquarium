import SwiftUI
import UIKit
import Testing
@testable import PomodoroAquarium

@MainActor
struct AquariumFishDepthBlurTests {
    @Test func radiusChangesContinuouslyOnlyBehindTheMiddle() {
        for (depth, expected) in [(CGFloat(-1), CGFloat(0.4)), (0, 0.4), (0.25, 0.2),
                                  (0.49, 0.008), (0.5, 0), (0.75, 0), (1, 0)] {
            #expect(abs(AquariumFishDepthBlur.radius(at: depth) - expected) < 0.000_001)
        }
        #expect(AquariumFishDepthBlur.radius(at: 0.4999) < 0.001)
        #expect(AquariumFishDepthBlur.radius(at: 0.5001) == 0)
    }

    @Test func imageBlurPreservesLayoutAndCanExtendPastTheImageEdge() throws {
        let source = Rectangle().fill(.white).frame(width: 40, height: 40)
        func render(_ radius: CGFloat) throws -> CGImage {
            let renderer = ImageRenderer(content: source
                .modifier(AquariumSelectionGlow(isSelected: false, imageBlurRadius: radius))
                .padding(8))
            renderer.scale = 2
            return try #require(renderer.uiImage?.cgImage)
        }
        let original = try render(0)
        let blurred = try render(AquariumFishDepthBlur.radius(at: 0))
        #expect(original.width == blurred.width && original.height == blurred.height)
        func alpha(_ image: CGImage, x: Int, y: Int) -> UInt8 {
            var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
            bytes.withUnsafeMutableBytes {
                CGContext(data: $0.baseAddress, width: image.width, height: image.height,
                    bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                    .draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            }
            return bytes[(y * image.width + x) * 4 + 3]
        }
        // 右端48ptの直外（pixel中心48.25pt）にも広がり、画像枠で切られていないことを確認する。
        #expect(alpha(original, x: 96, y: 56) == 0)
        #expect(alpha(blurred, x: 96, y: 56) > 0)
        // ぼかしはViewへの効果。元画像による透明部分のタップ判定はそのまま使う。
        let raw = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100)).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 35, y: 35, width: 30, height: 30))
        }
        let path = AquariumFishHitTesting.path(image: raw, canvasSize: 100, fishSize: 100)
        #expect(path.contains(CGPoint(x: 50, y: 50)))
        #expect(!path.contains(CGPoint(x: 10, y: 10)))
    }
}
