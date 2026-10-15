import CoreGraphics
import Testing
@testable import PomodoroAquarium

@MainActor
struct AquariumDecorationControlLayoutTests {
    @Test func visibleSilhouettesStayClearOfBarAndHeaderAcrossPhoneSizes() {
        for size in [CGSize(width: 375, height: 667), CGSize(width: 393, height: 874), CGSize(width: 440, height: 956)] {
            for (kind, x, y) in [(AquariumDecorationKind.smallRockA, 0.05, 0.93),
                                  (.coralAPink, 0.95, 0.93), (.smallRockB, 0.5, 0.6),
                                  (.seaweedC, 0.5, 0.92), (.treasureChest, 0.5, 0.92)] {
                let placement = AquariumDecorationPlacement(decorationID: "fixture", kind: kind, relativeX: x, relativeY: y, scale: 1)
                for direction in AquariumDecorationFacingDirection.allCases {
                    placement.facingDirection = direction
                    let shape = AquariumDecorationHitTesting.overlapShape(for: placement.decoration, aquariumSize: size, theme: .aquarium)
                    let center = AquariumDecorationControlLayout.center(bounds: shape.visibleBounds, canvas: size, topInset: 210)
                    let bar = CGRect(x: center.x - 165, y: center.y - 30, width: 330, height: 60)
                    #expect(bar.minX >= 12 && bar.maxX <= size.width - 12)
                    #expect(bar.minY >= 210 && bar.maxY <= size.height - 24)
                    #expect(!bar.intersects(shape.visibleBounds))
                }
            }
        }
    }
    @Test func prefersSixteenPointGapAboveAndFallsBelowHeaderObstruction() {
        let canvas = CGSize(width: 393, height: 874)
        let body = CGRect(x: 140, y: 600, width: 100, height: 120)
        let above = AquariumDecorationControlLayout.center(bounds: body, canvas: canvas, topInset: 210)
        #expect(above.y + 30 == body.minY - 16)
        let high = body.offsetBy(dx: 0, dy: -380)
        let below = AquariumDecorationControlLayout.center(bounds: high, canvas: canvas, topInset: 210)
        #expect(below.y - 30 == high.maxY + 16)
    }
}
