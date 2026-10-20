import CoreGraphics
import Foundation
import SwiftUI
import UIKit
import Testing
@testable import PomodoroAquarium

@MainActor
struct SeaTurtleTests {
    @Test func registrationAssetsNeutralFrameAndEndpointFreeLoop() throws {
        let species = FishSpecies.seaTurtle
        #expect(species.rawValue == "seaTurtle" && species.name == "ウミガメ" && species.rarity == .epic)
        #expect(species.imageName == "fish_sea_turtle_side_4")
        #expect(species.swimmingImageNames == (1...7).map { "fish_sea_turtle_side_\($0)" })
        #expect(try JSONDecoder().decode(FishSpecies.self, from: JSONEncoder().encode(species)) == species)
        for name in species.swimmingImageNames {
            let cg = try #require(UIImage(named: name)?.cgImage)
            #expect(cg.width == 1254 && cg.height == 1254)
            #expect(cg.alphaInfo != .none && cg.alphaInfo != .noneSkipFirst && cg.alphaInfo != .noneSkipLast)
        }
        #expect(FishImageView(species: species).interactionImage?.pngData() == UIImage(named: "fish_sea_turtle_side_4")?.pngData())
        #expect(!species.usesDirectionalSwimmingSprites && species.usesHorizontalSwimmingFlip)
        for direction in FishFacingDirection.allCases {
            #expect(species.swimmingImageRotation(for: direction) == 0)
            #expect(species.swimmingImageNames(for: direction) == species.swimmingImageNames)
        }
        let expected = [0, 1, 2, 3, 4, 5, 6, 5, 4, 3, 2, 1]
        #expect((0..<24).map { FishSpriteAnimation.pingPongFrameIndex(frameCount: 7,
            elapsedTime: Double($0) * 0.22 + 0.001, frameDuration: 0.22) } == expected + expected)
        for behavior in AquariumFishMotion.Behavior.allCases {
            for speed: CGFloat in [0, 0.01, 1] {
                #expect(AquariumFishMotion.spriteFrameDuration(for: species, behavior: behavior,
                    currentSpeed: speed, baseSpeed: 0.05) == 0.22)
            }
        }
    }

    @Test func epicPoolIsUniformWithoutChangingRarityWeights() {
        let epic = FishSpecies.allCases.filter { $0.rarity == .epic }
        #expect(epic == [.manta, .seaTurtle])
        for (minutes, expected) in [(0, [70.0, 20, 8, 2]), (180, [58.0, 25, 13, 4]), (300, [58.0, 25, 13, 4])] {
            let p = FishRewardService.rarityProbabilities(for: minutes)
            #expect([p.common, p.rare, p.epic, p.legendary] == expected && p.total == 100)
            #expect(p.epic / Double(epic.count) == (minutes == 0 ? 4 : 6.5))
        }
        #expect(AquariumFishEditorPresentation.speciesInRarityOrder.filter { $0.rarity == .epic } == epic)
    }

    @Test func mantaTemplateIsPreservedAndTurtleHasIndependentCalmSettings() {
        let manta = FishMovementProfile.manta
        let turtle = AquariumFishMotion.movementProfile(for: .seaTurtle)
        #expect(manta.baseSpeedRange == 0.042...0.066 && manta.directionHoldDurationRange == 7...11)
        #expect(manta.hoverProbability == 0.08 && manta.gatheringProbability == 0.04)
        #expect(turtle.baseSpeedRange.lowerBound == manta.baseSpeedRange.lowerBound * 0.64)
        #expect(turtle.baseSpeedRange.upperBound == manta.baseSpeedRange.upperBound * 0.64)
        #expect(turtle.turnResponsivenessRange == manta.turnResponsivenessRange)
        #expect(turtle.accelerationResponseRange == manta.accelerationResponseRange)
        #expect(turtle.brakingResponseRange == manta.brakingResponseRange)
        #expect(turtle.depthSpeedRange == manta.depthSpeedRange)
        #expect(turtle.hoverProbability == 0 && turtle.burstProbability == 0 && turtle.gatheringProbability == 0)
        #expect(turtle.directionHoldDurationRange == 9...14 && turtle.roamingStyle == .small)
        #expect(AquariumFishMotion.wingSwimmingProfile(for: .seaTurtle) == nil)
        #expect(AquariumFishMotion.wingSwimmingProfile(for: .manta)?.flapSpeedMultiplier == 2.2)
        #expect(AquariumFishMotion.wingSwimmingProfile(for: .manta)?.glideSpeedMultiplier == 2.0)
        #expect(AquariumFishMotion.presentationAmplitude(for: .seaTurtle) == 0.20)
    }

    @Test func gentlePropulsionMatchesDownstrokeAndMantaEffectiveSpeedReference() {
        let reference = (WingSwimmingProfile.manta.flapSpeedMultiplier + WingSwimmingProfile.manta.glideSpeedMultiplier) / 2
        let atTop = AquariumFishMotion.seaTurtlePropulsionMultiplier(elapsedTime: 0, frameDuration: 0.22, phase: 0)
        let atBottom = AquariumFishMotion.seaTurtlePropulsionMultiplier(elapsedTime: 6 * 0.22, frameDuration: 0.22, phase: 0)
        #expect(abs(atTop / reference - 0.96) < 0.000001)
        #expect(abs(atBottom / reference - 1.04) < 0.000001)
        var sum: CGFloat = 0
        var previous = atTop
        for tick in 0..<264 {
            let value = AquariumFishMotion.seaTurtlePropulsionMultiplier(elapsedTime: Double(tick) / 100,
                frameDuration: 0.22, phase: 0)
            #expect(value > 0 && abs(value - previous) < 0.003)
            sum += value
            previous = value
        }
        #expect(abs((sum / 264) / reference * 0.64 - 0.64) < 0.000001)
        // 同一個体・奥行き・巡航条件で、実際の加減速計算も基準マンタの約64%。
        let id = UUID(uuidString: "7A271E50-6A60-4A60-8A60-000000000001")!
        var manta = AquariumFishMotion.initialState(for: id, profile: .manta)
        var turtle = AquariumFishMotion.initialState(for: id, profile: .seaTurtle)
        for tick in 1...300 {
            manta.behavior = .cruising; turtle.behavior = .cruising
            manta.behaviorTimeRemaining = 100; turtle.behaviorTimeRemaining = 100
            manta.directionChangeTimeRemaining = 100; turtle.directionChangeTimeRemaining = 100
            manta.targetSpeed = manta.baseSpeed; turtle.targetSpeed = turtle.baseSpeed
            manta.advance(deltaTime: 1.0 / 30, elapsedTime: Double(tick) / 30, speedMultiplier: reference)
            turtle.advance(deltaTime: 1.0 / 30, elapsedTime: Double(tick) / 30,
                speedMultiplier: AquariumFishMotion.seaTurtlePropulsionMultiplier(elapsedTime: Double(tick) / 30, frameDuration: 0.22, phase: 0))
            if tick > 150 { #expect(abs(turtle.currentSpeed / manta.currentSpeed - 0.64) < 0.04) }
        }
    }

    private func pixels(_ cg: CGImage) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: cg.width * cg.height * 4)
        bytes.withUnsafeMutableBytes {
            CGContext(data: $0.baseAddress, width: cg.width, height: cg.height, bitsPerComponent: 8,
                bytesPerRow: cg.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                .draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
        }
        return bytes
    }

    @Test func visibleNoseToTailUsesEnlargedAquariumSizeAndShellStaysRegisteredAcrossAllFrames() throws {
        func length(_ species: FishSpecies, frame: Int? = nil) throws -> CGFloat {
            let side = AquariumFishSizing.displaySize(for: species, isFavorite: false)
            let renderer = ImageRenderer(content: FishImageView(species: species, fixedAnimationFrameIndex: frame).frame(width: side, height: side))
            renderer.scale = 8
            let image = try #require(renderer.uiImage?.cgImage), bytes = pixels(image)
            var left = image.width, right = -1
            for y in 0..<image.height { for x in 0..<image.width where bytes[(y * image.width + x) * 4 + 3] > 16 {
                right = max(right, x)
                if species == .seaTurtle {
                    // 後足を除き、尾先のあるROI（全7枚で固定）から左端を測る。
                    let sx = CGFloat(x) / CGFloat(image.width) * 1254
                    let sy = CGFloat(y) / CGFloat(image.height) * 1254
                    if (180...340).contains(sx) && (530...575).contains(sy) { left = min(left, x) }
                } else { left = min(left, x) }
            } }
            return CGFloat(right - left + 1) / 8
        }
        let clown = try length(.clownfish)
        var neutralShell: [UInt8] = []
        for frame in 0..<7 {
            let visible = try length(.seaTurtle, frame: frame)
            #expect(abs(visible / clown - 3.9) < 0.03)
            let image = try #require(UIImage(named: FishSpecies.seaTurtle.swimmingImageNames[frame])?.cgImage)
            let bytes = pixels(image)
            // frame2の前足が覆うx540以降を避け、全7枚で露出している甲羅を比較。
            let patch = (475..<540).flatMap { y in (420..<530).flatMap { x in Array(bytes[((y * 1254 + x) * 4)..<((y * 1254 + x) * 4 + 4)]) } }
            if frame == 0 { neutralShell = patch }
            else { #expect(patch == neutralShell) }
            if frame == 3 { print("Sea turtle nose-tail \(visible)pt / clownfish \(clown)pt = \(visible / clown); canvas \(AquariumFishSizing.displaySize(for: .seaTurtle, isFavorite: false))pt") }
        }
    }

    @Test func everyFlipperFrameFitsBoundsAndRemainsSelectable() throws {
        let side = AquariumFishSizing.displaySize(for: .seaTurtle, isFavorite: false)
        for frame in 0..<7 {
            let sprite = FishImageView(species: .seaTurtle, fixedAnimationFrameIndex: frame)
            let renderer = ImageRenderer(content: sprite.frame(width: side, height: side))
            renderer.scale = 3
            let image = try #require(renderer.uiImage?.cgImage), bytes = pixels(image)
            let path = AquariumFishHitTesting.path(image: sprite.interactionImage, canvasSize: side + 20, fishSize: side)
            var samples = 0
            for y in 0..<image.height { for x in 0..<image.width where bytes[(y * image.width + x) * 4 + 3] > 128 {
                #expect(x > 0 && y > 0 && x < image.width - 1 && y < image.height - 1)
                if x.isMultiple(of: 6) && y.isMultiple(of: 6) {
                    #expect(path.contains(CGPoint(x: 10 + CGFloat(x) / CGFloat(image.width) * side,
                        y: 10 + CGFloat(y) / CGFloat(image.height) * side)))
                    samples += 1
                }
            } }
            #expect(samples > 10)
        }
        for size in [CGSize(width: 320, height: 568), CGSize(width: 393, height: 852), CGSize(width: 1024, height: 768)] {
            let bounds = FishMovementProfile.seaTurtle.roamingStyle.bounds(in: size, fishSize: side)
            #expect(bounds.horizontal.lowerBound * size.width >= side * 0.72 + 5.9)
            #expect(bounds.vertical.lowerBound * size.height >= side * 0.72 + 5.9)
        }
    }

    @Test func renderAllThreeBackgroundsWithRaisedNeutralAndLoweredFlippers() throws {
        let size = AquariumFishSizing.displaySize(for: .seaTurtle, isFavorite: false)
        for theme in AquariumBackgroundTheme.allCases {
            let renderer = ImageRenderer(content: HStack(spacing: 0) {
                ForEach([false, true], id: \.self) { corrected in
                    ZStack {
                        AquariumBackground(theme: theme)
                        ForEach(Array([0, 3, 6].enumerated()), id: \.offset) { item in
                            FishImageView(species: .seaTurtle, fixedAnimationFrameIndex: item.element)
                                .frame(width: size, height: size)
                                .modifier(corrected ? AquariumFishColorCorrection.correction(for: theme, species: .seaTurtle)
                                    : .init(saturation: 1, brightness: 0, red: 1, green: 1, blue: 1))
                                .opacity(FishMovementProfile.seaTurtle.depthOpacity(at: 0.5))
                                .position(x: 196.5, y: 746 * [0.18, 0.5, 0.82][item.offset])
                        }
                        VStack {
                            Text(corrected ? "水中補正" : "原画像").font(.caption).foregroundStyle(.white)
                                .padding(6).background(.black.opacity(0.6))
                            Spacer()
                        }
                    }.frame(width: 393, height: 746).clipped()
                }
            })
            renderer.scale = 2
            try #require(renderer.uiImage?.pngData()).write(to: URL(fileURLWithPath: "/private/tmp/SeaTurtle-\(theme.rawValue).png"))
        }
    }
}
