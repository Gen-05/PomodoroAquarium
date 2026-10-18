import Foundation
import SwiftUI
import UIKit
import Testing
@testable import PomodoroAquarium

@MainActor
struct PennantCoralfishTests {
    @Test func registrationAndAssets() throws {
        let species = FishSpecies.pennantCoralfish
        #expect(species.rawValue == "pennantCoralfish")
        #expect(species.name == "ハタタテダイ" && species.rarity == .common)
        #expect(species.imageName == "fish_pennant_coralfish_side_2")
        #expect(species.swimmingImageNames == (1...3).map { "fish_pennant_coralfish_side_\($0)" })
        let data = try JSONEncoder().encode(species)
        #expect(try JSONDecoder().decode(FishSpecies.self, from: data) == species)
        for name in species.swimmingImageNames {
            let image = try #require(UIImage(named: name)?.cgImage)
            #expect(image.width == 1254 && image.height == 1254)
            #expect(image.alphaInfo != .none && image.alphaInfo != .noneSkipFirst && image.alphaInfo != .noneSkipLast)
        }
    }

    @Test func smallFishMotionAndPointTwoSecondPingPong() {
        let id = UUID()
        let pennant = AquariumFishMotion.initialState(for: id, profile: AquariumFishMotion.movementProfile(for: .pennantCoralfish))
        let blue = AquariumFishMotion.initialState(for: id, profile: AquariumFishMotion.movementProfile(for: .blueTang))
        #expect(pennant.position == blue.position && pennant.velocity == blue.velocity)
        #expect(pennant.baseSpeed == blue.baseSpeed && pennant.facingDirection == blue.facingDirection)
        #expect(pennant.movementProfile.roamingStyle == .small)
        for behavior in AquariumFishMotion.Behavior.allCases {
            #expect(AquariumFishMotion.behaviorTargetSpeedMultiplier(for: .pennantCoralfish, behavior: behavior)
                == AquariumFishMotion.behaviorTargetSpeedMultiplier(for: .blueTang, behavior: behavior))
            #expect(AquariumFishMotion.spriteFrameDuration(for: .pennantCoralfish, behavior: behavior, currentSpeed: 1, baseSpeed: 1) == 0.20)
        }
        for direction in FishFacingDirection.allCases {
            #expect(FishSpecies.pennantCoralfish.swimmingImageRotation(for: direction) == FishSpecies.blueTang.swimmingImageRotation(for: direction))
            #expect(FishSpecies.pennantCoralfish.swimmingImageNames(for: direction) == FishSpecies.pennantCoralfish.swimmingImageNames)
        }
        #expect(FishImageView(species: .pennantCoralfish, facingHorizontalScale: -1).resolvedHorizontalScale == -1)
        #expect((0..<8).map { FishSpriteAnimation.pingPongFrameIndex(frameCount: 3, elapsedTime: Double($0) * 0.20 + 0.001, frameDuration: 0.20) }
            == [0, 1, 2, 1, 0, 1, 2, 1])
    }

    @Test func renderedBodyWidthIsTenPercentLargerWithoutCroppingPennant() throws {
        func visibleWidth(_ species: FishSpecies, frame: CGSize? = nil) throws -> Int {
            let size = AquariumFishSizing.displaySize(for: species, isFavorite: false)
            let frame = frame ?? CGSize(width: size, height: size)
            let renderer = ImageRenderer(content: FishImageView(species: species, fixedAnimationFrameIndex: 1).frame(width: frame.width, height: frame.height))
            renderer.scale = 3
            let image = try #require(renderer.uiImage?.cgImage)
            var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
            bytes.withUnsafeMutableBytes {
                let context = CGContext(data: $0.baseAddress, width: image.width, height: image.height,
                    bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            }
            var minX = image.width, maxX = -1
            // 基準PNGの上部400pxは長い背びれのみ。胴体・鼻先・尾は残す。
            let startY = species == .pennantCoralfish ? Int(Double(image.height) * 400 / 1254) : 0
            for y in startY..<image.height { for x in 0..<image.width where bytes[(y * image.width + x) * 4 + 3] > 16 {
                minX = min(minX, x); maxX = max(maxX, x)
            } }
            return maxX - minX + 1
        }
        #expect(FishSpecies.pennantCoralfish.displayScale == 0.636)
        let pennant = try visibleWidth(.pennantCoralfish), butterfly = try visibleWidth(.orientalButterflyfish)
        #expect(abs(Double(pennant) / Double(butterfly) - 1.10) < 0.03)
        print("Neutral visible width: pennantCoralfish \(Double(pennant) / 3)pt, orientalButterflyfish \(Double(butterfly) / 3)pt")
        let ratio = FishDetailImageLayout.visibleContentRatio(for: .pennantCoralfish)
        #expect(ratio == CGSize(width: 0.876, height: 0.874))
        let available = FishDetailImageLayout.availableSize(in: CGSize(width: 320, height: 240))
        let size = FishDetailImageLayout.displaySize(for: .pennantCoralfish, availableSize: available)
        #expect(size * ratio.width <= available.width && size * ratio.height <= available.height)
    }

    @Test func pennantIsInsideCanvasAndSelectableForEveryFrameAndFlip() throws {
        let species = FishSpecies.pennantCoralfish
        let side = AquariumFishSizing.displaySize(for: species, isFavorite: false)
        for name in species.swimmingImageNames {
            let image = try #require(UIImage(named: name))
            let cg = try #require(image.cgImage)
            var rgba = [UInt8](repeating: 0, count: cg.width * cg.height * 4)
            rgba.withUnsafeMutableBytes {
                CGContext(data: $0.baseAddress, width: cg.width, height: cg.height, bitsPerComponent: 8,
                    bytesPerRow: cg.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                    .draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
            }
            let canvas = side + 20
            for flip: CGFloat in [-1, 1] {
                let path = AquariumFishHitTesting.path(image: image, canvasSize: canvas, fishSize: side, horizontalScale: flip)
                var pennantSamples = 0
                for y in stride(from: 0, to: 400, by: 16) {
                    for x in stride(from: 0, to: cg.width, by: 16) where rgba[(y * cg.width + x) * 4 + 3] > 128 {
                        let px = 10 + CGFloat(x) / CGFloat(cg.width) * side
                        let py = 10 + CGFloat(y) / CGFloat(cg.height) * side
                        #expect(path.contains(CGPoint(x: flip == 1 ? px : canvas - px, y: py)))
                        pennantSamples += 1
                    }
                }
                #expect(pennantSamples > 0)
            }
            // scaledToFitの全身枠が編集カードと詳細枠にも収まることを確認する。
            let thumbnail = AquariumEditorFishThumbnailLayout.imageSize(for: species)
            #expect(thumbnail.width < AquariumEditorFishThumbnailLayout.viewport.width)
            #expect(thumbnail.height < AquariumEditorFishThumbnailLayout.viewport.height)
            let renderer = ImageRenderer(content: FishImageView(species: species, fixedAnimationFrameIndex: species.swimmingImageNames.firstIndex(of: name))
                .frame(width: side, height: side))
            renderer.scale = 3
            let rendered = try #require(renderer.uiImage?.cgImage)
            var pixels = [UInt8](repeating: 0, count: rendered.width * rendered.height * 4)
            pixels.withUnsafeMutableBytes {
                CGContext(data: $0.baseAddress, width: rendered.width, height: rendered.height, bitsPerComponent: 8,
                    bytesPerRow: rendered.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                    .draw(rendered, in: CGRect(x: 0, y: 0, width: rendered.width, height: rendered.height))
            }
            for y in 0..<rendered.height { for x in 0..<rendered.width where pixels[(y * rendered.width + x) * 4 + 3] > 16 {
                #expect(x > 0 && x < rendered.width - 1 && y > 0 && y < rendered.height - 1)
            } }
        }
    }

    @Test func renderActualBackgroundComparisons() throws {
        let species = FishSpecies.pennantCoralfish
        for theme in AquariumBackgroundTheme.allCases {
            let previous: AquariumFishColorCorrection
            switch theme {
            case .aquarium:
                previous = .init(saturation: 0.86, brightness: -0.025, red: 0.97, green: 0.99, blue: 1)
            case .tropical:
                previous = .init(saturation: 0.84, brightness: -0.035, red: 0.98, green: 0.99, blue: 0.98)
            case .deepSea:
                previous = .init(saturation: 0.88, brightness: -0.040, red: 0.93, green: 0.96, blue: 1)
            }
            // 色だけを旧サイズで比較。サイズだけの比較は両側に新しい補正を使用。
            for comparison in ["color", "color-detail", "size"] {
                let previousSize: CGFloat = 54.21944788732395
                let rendererSize: CGFloat = comparison == "color-detail" ? 160 : previousSize
                let renderer = ImageRenderer(content: HStack(spacing: 0) {
                    ForEach([false, true], id: \.self) { after in
                        let side = comparison == "size" && after
                            ? AquariumFishSizing.displaySize(for: species, isFavorite: false) : rendererSize
                        ZStack {
                            AquariumBackground(theme: theme)
                            ForEach([0.18, 0.5, 0.82], id: \.self) { y in
                                FishImageView(species: species, fixedAnimationFrameIndex: 1)
                                    .frame(width: side, height: side)
                                    .modifier(after || comparison == "size" ? AquariumFishColorCorrection.correction(for: theme, species: species) : previous)
                                    .opacity(AquariumFishMotion.movementProfile(for: species).depthOpacity(at: 0.5))
                                    .position(x: 196.5, y: y * 746)
                            }
                            VStack {
                                Text("\(theme.displayName) / \(comparison) / \(after ? "AFTER" : "BEFORE")")
                                    .font(.caption).foregroundStyle(.white).padding(6).background(.black.opacity(0.65))
                                Spacer()
                            }
                        }.frame(width: 393, height: 746).clipped()
                    }
                })
                renderer.scale = 2
                let filename = "/private/tmp/PennantTune-\(theme.rawValue)-\(comparison).png"
                try #require(renderer.uiImage?.pngData()).write(to: URL(fileURLWithPath: filename))
            }
        }
    }
}
