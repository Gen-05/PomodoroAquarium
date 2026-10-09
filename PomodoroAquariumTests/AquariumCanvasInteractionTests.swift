import CoreGraphics
import Testing
@testable import PomodoroAquarium

@MainActor
struct AquariumCanvasInteractionTests {
    @Test(arguments: [AquariumDecorationKind.seaweedA, .seaweedC, .coralAPink, .coralCPink, .mediumRockA])
    func alphaHitTestingIgnoresTransparentCanvasAndFindsVisibleDetails(kind: AquariumDecorationKind) {
        let size = CGSize(width: 393, height: 852)
        let root = CGPoint(x: 0.5, y: 0.90)
        let decoration = AquariumDecoration(id: "test", kind: kind, relativeX: root.x, relativeY: root.y, scale: 1)
        let depth = AquariumDecorationDepthPresentation(kind: kind, relativeY: root.y)
        let width = kind.displaySize.width * depth.scale
        let height = kind.displaySize.height * depth.scale
        let origin = CGPoint(x: root.x * size.width - width / 2, y: root.y * size.height - kind.groundAnchorY! * height)
        #expect(!AquariumDecorationHitTesting.contains(origin, decoration: decoration, root: root, aquariumSize: size, theme: .aquarium))
        var found = false, transparent = false
        for row in 0..<20 {
            for column in 0..<20 {
                let point = CGPoint(x: origin.x + (CGFloat(column) + 0.5) / 20 * width,
                                    y: origin.y + (CGFloat(row) + 0.5) / 20 * height)
                let hit = AquariumDecorationHitTesting.contains(point, decoration: decoration, root: root, aquariumSize: size, theme: .aquarium)
                found = found || hit
                transparent = transparent || !hit
                if hit {
                    #expect(AquariumDecorationHitTesting.contains(point, decoration: decoration, root: root, aquariumSize: size, theme: .aquarium, tolerance: 6))
                }
            }
        }
        #expect(found && transparent)
    }

    @Test func overlapSelectsFrontVisiblePixelsAndPassesThroughTransparentBranches() {
        let size = CGSize(width: 393, height: 852)
        let root = CGPoint(x: 0.5, y: 0.9)
        let rock = AquariumDecoration(id: "rock", kind: .mediumRockA, relativeX: root.x, relativeY: root.y, scale: 1)
        let coral = AquariumDecoration(id: "coral", kind: .coralCPink, relativeX: root.x, relativeY: root.y, scale: 1)
        var visibleOverlap = false, transparentOverlap = false
        for y in stride(from: CGFloat(700), through: 760, by: 3) {
            for x in stride(from: CGFloat(140), through: 250, by: 3) {
                let point = CGPoint(x: x, y: y)
                let rockHit = AquariumDecorationHitTesting.contains(point, decoration: rock, root: root, aquariumSize: size, theme: .aquarium)
                let coralHit = AquariumDecorationHitTesting.contains(point, decoration: coral, root: root, aquariumSize: size, theme: .aquarium)
                guard rockHit else { continue }
                let selected = AquariumDecorationHitTesting.selectedID(at: point, decorations: [coral, rock], aquariumSize: size, theme: .aquarium)
                #expect(selected == (coralHit ? "coral" : "rock"))
                visibleOverlap = visibleOverlap || coralHit
                transparentOverlap = transparentOverlap || !coralHit
            }
        }
        #expect(visibleOverlap && transparentOverlap)
    }

    @Test func nudgeAndZeroTranslationKeepExpandedRangeAndGrounding() {
        let size = CGSize(width: 393, height: 852)
        let root = CGPoint(x: -0.02, y: 0.90)
        let unmoved = AquariumDecorationEditor.relativePosition(originalX: root.x, originalY: root.y,
            translation: .zero, aquariumSize: size, kind: .mediumRockA, isEditing: true)
        #expect(unmoved == root)
        let moved = AquariumDecorationEditor.relativePosition(originalX: root.x, originalY: root.y,
            translation: CGSize(width: 8, height: -8), aquariumSize: size, kind: .mediumRockA, isEditing: true)
        #expect(abs(moved.x - root.x - 8 / size.width) < 0.000_001)
        #expect(abs(moved.y - root.y + 8 / size.height) < 0.000_001)
        #expect(AquariumDecorationDepthPresentation(kind: .mediumRockA, relativeY: moved.y).scale < AquariumDecorationDepthPresentation(kind: .mediumRockA, relativeY: root.y).scale)
    }
}
