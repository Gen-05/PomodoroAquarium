import CoreGraphics
import Testing
@testable import PomodoroAquarium

@MainActor
struct AquariumDecorationSizingTests {
    @Test func viewportRatioUsesShortSideAndLeavesShipwreckAlone() {
        let examples: [(CGSize, CGFloat)] = [
            (CGSize(width: 393, height: 746), 1),
            (CGSize(width: 744, height: 1000), 1.8),
            (CGSize(width: 1133, height: 650), 650.0 / 393),
            (CGSize(width: 1024, height: 1260), 1.8)
        ]
        for (canvas, expected) in examples {
            #expect(abs(AquariumDecorationSizing.viewportScale(for: .seaweedA, in: canvas) - expected) < 0.000_001)
            #expect(AquariumDecorationSizing.viewportScale(for: .seaweedA, in: canvas)
                == AquariumDecorationSizing.viewportScale(for: .seaweedA, in: CGSize(width: canvas.height, height: canvas.width)))
            #expect(AquariumDecorationSizing.viewportScale(for: .shipwreck, in: canvas) == 1)
        }
        #expect(AquariumDecorationSizing.viewportScale(for: .seaweedA, in: .zero) == 1)
        #expect(AquariumDecorationSizing.viewportScale(for: .seaweedA, in: CGSize(width: 320, height: 600)) == 1)
    }

    @Test func scaledImageFrameAndAlphaHitTestingKeepTheSameGroundAnchor() throws {
        let phone = CGSize(width: 393, height: 746)
        for kind in [AquariumDecorationKind.seaweedA, .mediumRockC, .treasureChest] {
            for direction in AquariumDecorationFacingDirection.allCases {
                let item = AquariumDecoration(id: "sizing", kind: kind, relativeX: 0.5, relativeY: 0.85,
                    scale: 1.2, facingDirection: direction)
                let root = CGPoint(x: item.relativeX, y: item.relativeY)
                let baseline = AquariumDecorationSizing.frame(for: item, in: phone)
                for canvas in [phone, CGSize(width: 744, height: 1000), CGSize(width: 1133, height: 650)] {
                    let frame = AquariumDecorationSizing.frame(for: item, in: canvas)
                    let shape = AquariumDecorationHitTesting.overlapShape(for: item, aquariumSize: canvas, theme: .aquarium)
                    #expect(frame == shape.rect)
                    let ratio = AquariumDecorationSizing.viewportScale(for: kind, in: canvas)
                    #expect(abs(frame.width / baseline.width - ratio) < 0.000_001)
                    #expect(abs(frame.height / baseline.height - ratio) < 0.000_001)
                    let anchor = try #require(kind.groundAnchorY(facingDirection: direction))
                    #expect(abs(frame.minY + anchor * frame.height - root.y * canvas.height) < 0.000_001)
                    var opaqueCount = 0, transparentCount = 0
                    // マスクのセル境界ぴったりを避け、浮動小数点の丸めで隣のpixelを比較しない。
                    for y in stride(from: CGFloat(0.053), through: 0.953, by: 0.1) {
                        for x in stride(from: CGFloat(0.053), through: 0.953, by: 0.1) {
                            let originalPoint = CGPoint(x: baseline.minX + x * baseline.width, y: baseline.minY + y * baseline.height)
                            let scaledPoint = CGPoint(x: frame.minX + x * frame.width, y: frame.minY + y * frame.height)
                            let originalHit = AquariumDecorationHitTesting.contains(originalPoint, decoration: item, root: root, aquariumSize: phone, theme: .aquarium)
                            let scaledHit = AquariumDecorationHitTesting.contains(scaledPoint, decoration: item, root: root, aquariumSize: canvas, theme: .aquarium)
                            #expect(originalHit == scaledHit)
                            if scaledHit { opaqueCount += 1 } else { transparentCount += 1 }
                        }
                    }
                    #expect(opaqueCount > 0 && transparentCount > 0)
                    let moved = AquariumDecorationEditor.relativePosition(forDropLocation: CGPoint(x: -1000, y: 10000),
                        aquariumSize: canvas, kind: kind, scale: item.scale)
                    let movedFrame = AquariumDecorationSizing.frame(for: item, root: moved, in: canvas)
                    let content = kind.placementHorizontalContentBounds
                    let contentLeft = movedFrame.minX + content.lowerBound * movedFrame.width
                    let contentRight = movedFrame.minX + content.upperBound * movedFrame.width
                    let visibleWidth = max(0, min(canvas.width, contentRight) - max(0, contentLeft))
                    #expect(visibleWidth + 0.000_001 >= min((contentRight - contentLeft) * 0.25, canvas.width))
                    // 従来どおり左右は一部を画面外へ置ける。根元と上端は画面内へ保つ。
                    #expect(movedFrame.minY >= -0.000_001 && moved.y >= 0 && moved.y <= 1)
                }
            }
        }
    }
}
