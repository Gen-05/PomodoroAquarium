import Foundation
import Testing
import SwiftUI
import UIKit
@testable import PomodoroAquarium

@MainActor
struct AquariumTreasureChestTapTests {
    @Test func cooldownIndependentIDsAndCleanup() {
        var state = AquariumTreasureChestEffects.TapState()
        let disabled = state.trigger(id: "a", elapsed: 0, enabled: false); #expect(!disabled)
        #expect(state.bursts.isEmpty)
        let first = state.trigger(id: "a", elapsed: 0, enabled: true); #expect(first)
        let baseline = state.bursts["a"]
        for time in [0.1, 0.5, 1, 2.7] {
            let repeated = state.trigger(id: "a", elapsed: time, enabled: true)
            #expect(!repeated && state.bursts["a"] == baseline)
        }
        let other = state.trigger(id: "b", elapsed: 0.5, enabled: true); #expect(other)
        #expect(state.bursts["a"] == baseline && state.bursts["b"]?.count == 1)
        let restarted = state.trigger(id: "a", elapsed: 2.8, enabled: true); #expect(restarted)
        #expect(state.bursts["a", default: []].count <= 2)
        state.prune(elapsed: 2.8, visibleIDs: ["a"])
        #expect(state.bursts["b"] == nil)
        state.prune(elapsed: 7, visibleIDs: ["a"])
        #expect(state.bursts.isEmpty)
    }
    @Test func staggeredBubblesAndSequentialSparklesUseBothDirectionAnchors() {
        let burst = AquariumTreasureChestEffects.TapBurst(start: 0, seed: 7)
        #expect(burst.bubbles.count == 7)
        #expect(Set(burst.bubbles.map(\.birth)).count == 7)
        #expect(burst.bubbles.first?.birth == 0.08 && burst.bubbles.last?.birth == 0.88)
        #expect(burst.bubbles.allSatisfy { $0.opacity == 1 })
        #expect(burst.sparkles.first?.spot == 0 && burst.sparkles[1].spot == 1)
        for direction in AquariumDecorationFacingDirection.allCases {
            let initial = AquariumTreasureChestEffects.tapFrame(bursts: [burst], elapsed: 0.08, direction: direction)
            #expect(initial.bubbles.count == 1)
            #expect(initial.bubbles[0].point == AquariumTreasureChestEffects.bubbleOrigins(direction)[0])
            for time in stride(from: 0.0, through: 3.2, by: 0.03) {
                let frame = AquariumTreasureChestEffects.tapFrame(bursts: [burst], elapsed: time, direction: direction)
                #expect(frame.bubbles.count <= 8 && frame.sparkles.count <= 4)
                for bubble in frame.bubbles {
                    #expect((0...1).contains(bubble.opacity))
                    #expect(AquariumTreasureChestEffects.overflowTop + bubble.point.y * AquariumTreasureChestEffects.canvasSide - bubble.diameter / AquariumTreasureChestEffects.bubbleVisibleFraction / 2 >= 0)
                }
                #expect(frame.sparkles.allSatisfy { AquariumTreasureChestEffects.sparklePoints(direction).contains($0.point) })
            }
            #expect(AquariumTreasureChestEffects.tapFrame(bursts: [burst], elapsed: 3.2, direction: direction) == .empty)
        }
    }
    @Test func ordinaryFramesRemainIntactAndSceneAdditionsAreBounded() {
        let instances = (0..<40).map { AquariumTreasureChestEffects.Instance(id: "chest-\($0)", direction: .right) }
        let patterns = Dictionary(uniqueKeysWithValues: instances.map { ($0.id, AquariumTreasureChestEffects.Pattern(placementID: $0.id)) })
        let bursts = Dictionary(uniqueKeysWithValues: instances.map { ($0.id, [AquariumTreasureChestEffects.TapBurst(start: 0, seed: 1)]) })
        for time in [0.2, 0.9, 1.4, 3.2] {
            let base = AquariumTreasureChestEffects.frames(instances: instances, patterns: patterns, elapsed: time)
            let tapped = AquariumTreasureChestEffects.frames(instances: instances, patterns: patterns, elapsed: time, bursts: bursts)
            var bubbleCount = 0, sparkleCount = 0
            for (id, original) in base {
                let frame = tapped[id]!
                #expect(Array(frame.bubbles.prefix(original.bubbles.count)) == original.bubbles)
                #expect(Array(frame.sparkles.prefix(original.sparkles.count)) == original.sparkles)
                bubbleCount += frame.bubbles.count - original.bubbles.count
                sparkleCount += frame.sparkles.count - original.sparkles.count
            }
            #expect(bubbleCount <= AquariumTreasureChestEffects.sceneTapBubbleLimit)
            #expect(sparkleCount <= AquariumTreasureChestEffects.sceneTapSparkleLimit)
            if time == 3.2 { #expect(tapped == base) }
        }
    }
    @Test func strictSilhouetteAndFrontDecorationPreventFalseChestTaps() throws {
        var chest = AquariumDecoration(id: "chest", kind: .treasureChest, relativeX: 0.5, relativeY: 0.9, scale: 1,
            zOrder: 1, isStackingOrderInitialized: true)
        let size = CGSize(width: 400, height: 600)
        for direction in AquariumDecorationFacingDirection.allCases {
            chest.facingDirection = direction
            let depth = AquariumDecorationDepthPresentation(kind: .treasureChest, relativeY: chest.relativeY)
            let side = AquariumTreasureChestEffects.canvasSide * depth.scale
            let origin = CGPoint(x: 200 - side / 2, y: 540 - side * (chest.kind.groundAnchorY(facingDirection: direction) ?? 0.5))
            let blank = CGPoint(x: origin.x + 1, y: origin.y + 1)
            #expect(AquariumDecorationHitTesting.selectedID(at: blank, decorations: [chest], aquariumSize: size,
                theme: .aquarium, allowsTouchPadding: false) == nil)
            let body = CGPoint(x: origin.x + side * 0.5, y: origin.y + side * 0.75)
            #expect(AquariumDecorationHitTesting.selectedID(at: body, decorations: [chest], aquariumSize: size,
                theme: .aquarium, allowsTouchPadding: false) == "chest")
            let front = AquariumDecoration(id: "front", kind: .coralBPink, relativeX: 0.5, relativeY: 0.9, scale: 1,
                zOrder: 2, isStackingOrderInitialized: true)
            let overlap = (0..<100).compactMap { index -> CGPoint? in
                let p = CGPoint(x: 160 + CGFloat(index % 10) * 8, y: 505 + CGFloat(index / 10) * 3)
                return AquariumDecorationHitTesting.contains(p, decoration: chest, root: CGPoint(x: 0.5,y: 0.9), aquariumSize: size, theme: .aquarium)
                    && AquariumDecorationHitTesting.contains(p, decoration: front, root: CGPoint(x: 0.5,y: 0.9), aquariumSize: size, theme: .aquarium) ? p : nil
            }.first
            let point = try #require(overlap)
            #expect(AquariumDecorationHitTesting.selectedID(at: point, decorations: [chest, front], aquariumSize: size,
                theme: .aquarium, allowsTouchPadding: false) == "front")
        }
    }
    @Test func actualSwiftUIBurstRendering() throws {
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("treasure-chest-tap-checks")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let pattern = AquariumTreasureChestEffects.Pattern(placementID: "render")
        let burst = AquariumTreasureChestEffects.TapBurst(start: 0, seed: 7)
        for direction in AquariumDecorationFacingDirection.allCases {
            for time in [0.2, 0.6, 1.1, 2.0, 3.2] {
                var frame = AquariumTreasureChestEffects.frame(pattern: pattern, elapsed: time, direction: direction)
                let extra = AquariumTreasureChestEffects.tapFrame(bursts: [burst], elapsed: time, direction: direction)
                frame.bubbles += extra.bubbles; frame.sparkles += extra.sparkles; frame.interiorLight = extra.interiorLight
                let scene = ZStack {
                    Image("basic_ocean_00").resizable().scaledToFill().frame(width: 400, height: 600).clipped()
                    AquariumTreasureChestView(direction: direction, frame: frame, backgroundTheme: .aquarium, isSelected: false, bodyOpacity: 1)
                        .offset(y: AquariumDecorationKind.treasureChest.groundAnchorOffset(facingDirection: direction))
                        .position(x: 200, y: 540)
                }.frame(width: 400,height: 600)
                let renderer = ImageRenderer(content: scene); renderer.scale = 2
                try #require(renderer.uiImage?.pngData()).write(to: folder.appendingPathComponent("\(direction.rawValue)-\(time).png"))
            }
        }
    }
}
