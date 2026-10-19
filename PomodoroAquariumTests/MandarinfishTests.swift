import Foundation
import SwiftUI
import UIKit
import Testing
@testable import PomodoroAquarium

@MainActor
struct MandarinfishTests {
    @Test func registrationAssetsAndNeutralImage() throws {
        let species = FishSpecies.mandarinfish
        #expect(species.rawValue == "mandarinfish")
        #expect(species.name == "ニシキテグリ" && species.rarity == .rare)
        #expect(species.imageName == "fish_mandarinfish_side_3")
        #expect(species.swimmingImageNames == (1...5).map { "fish_mandarinfish_side_\($0)" })
        #expect(try JSONDecoder().decode(FishSpecies.self, from: JSONEncoder().encode(species)) == species)
        for name in species.swimmingImageNames {
            let image = try #require(UIImage(named: name)?.cgImage)
            #expect(image.width == 1254 && image.height == 1254)
            #expect(image.alphaInfo == .premultipliedLast || image.alphaInfo == .premultipliedFirst || image.alphaInfo == .last || image.alphaInfo == .first)
        }
        #expect(FishImageView(species: species).interactionImage?.pngData() == UIImage(named: "fish_mandarinfish_side_3")?.pngData())
        for direction in FishFacingDirection.allCases {
            #expect(species.swimmingImageNames(for: direction) == species.swimmingImageNames)
            #expect(abs(species.swimmingImageRotation(for: direction)) <= 22.5)
        }
        #expect(FishImageView(species: species, facingHorizontalScale: -1).resolvedHorizontalScale == -1)
    }

    @Test func rarePoolAndProbabilitiesPreserveRarityWeights() {
        let rare = FishSpecies.allCases.filter { $0.rarity == .rare }
        #expect(rare == [.seahorse, .lionfish, .porcupinefish, .mandarinfish])
        for (minutes, expected) in [(0, [70.0, 20, 8, 2]), (180, [58.0, 25, 13, 4]), (300, [58.0, 25, 13, 4])] {
            let p = FishRewardService.rarityProbabilities(for: minutes)
            #expect([p.common, p.rare, p.epic, p.legendary] == expected && p.total == 100)
            #expect(p.rare / Double(rare.count) == (minutes == 0 ? 5 : 6.25))
        }
        let sortedRare = AquariumFishEditorPresentation.speciesInRarityOrder.filter { $0.rarity == .rare }
        #expect(sortedRare == rare)
    }

    @Test func stationKeepingUsesIndependentFiveFrameTempoWithoutWholeBodySway() {
        let profile = AquariumFishMotion.movementProfile(for: .mandarinfish)
        #expect(profile.usesStationKeeping)
        #expect(AquariumFishMotion.presentationAmplitude(for: .mandarinfish) == 0)
        for direction in FishFacingDirection.allCases {
            #expect(FishSpecies.mandarinfish.swimmingImageRotation(for: direction) == 0)
        }
        for behavior in AquariumFishMotion.Behavior.allCases {
            for speed: CGFloat in [0, 0.01, 1] {
                #expect(AquariumFishMotion.spriteFrameDuration(for: .mandarinfish, behavior: behavior,
                    currentSpeed: speed, baseSpeed: 0.015) == 0.20)
            }
            #expect(AquariumFishMotion.behaviorTargetSpeedMultiplier(for: .mandarinfish, behavior: behavior) == nil)
        }
        let expected = [0, 1, 2, 3, 4, 3, 2, 1]
        #expect((0..<16).map { FishSpriteAnimation.pingPongFrameIndex(frameCount: 5,
            elapsedTime: Double($0) * 0.20 + 0.001, frameDuration: 0.20) } == expected + expected)
        for species in FishSpecies.allCases where species != .mandarinfish {
            #expect(!AquariumFishMotion.movementProfile(for: species).usesStationKeeping)
        }
    }

    private func pixels(_ image: CGImage) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        bytes.withUnsafeMutableBytes {
            CGContext(data: $0.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8,
                bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                .draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return bytes
    }

    @Test func renderedVisibleLengthIsOnePointTwoTimesClownfishAndFinsRemainSelectable() throws {
        func visibleWidth(_ species: FishSpecies) throws -> CGFloat {
            let size = AquariumFishSizing.displaySize(for: species, isFavorite: false)
            let renderer = ImageRenderer(content: FishImageView(species: species).frame(width: size, height: size))
            renderer.scale = 8
            let image = try #require(renderer.uiImage?.cgImage), bytes = pixels(image)
            var low = image.width, high = -1
            for y in 0..<image.height { for x in 0..<image.width where bytes[(y * image.width + x) * 4 + 3] > 16 {
                low = min(low, x); high = max(high, x)
            } }
            return CGFloat(high - low + 1) / 8
        }
        let clown = try visibleWidth(.clownfish), mandarin = try visibleWidth(.mandarinfish)
        #expect(abs(mandarin / clown - 1.20) < 0.02)
        #expect(FishSpecies.clownfish.displayScale == 0.40)
        #expect(AquariumFishSizing.displaySize(for: .clownfish, isFavorite: false) == 78 * 0.40)
        print("Mandarinfish visible length \(mandarin)pt / clownfish \(clown)pt = \(mandarin / clown)")
        let size = AquariumFishSizing.displaySize(for: .mandarinfish, isFavorite: false)
        for frame in 0..<5 {
            let sprite = FishImageView(species: .mandarinfish, fixedAnimationFrameIndex: frame)
            let renderer = ImageRenderer(content: sprite.frame(width: size, height: size))
            renderer.scale = 4
            let image = try #require(renderer.uiImage?.cgImage), bytes = pixels(image)
            let path = AquariumFishHitTesting.path(image: sprite.interactionImage, canvasSize: size + 20, fishSize: size)
            var samples = 0
            for y in 0..<image.height { for x in 0..<image.width where bytes[(y * image.width + x) * 4 + 3] > 128 {
                #expect(x > 0 && x < image.width - 1 && y > 0 && y < image.height - 1)
                if x.isMultiple(of: 6) && y.isMultiple(of: 6) {
                    #expect(path.contains(CGPoint(x: 10 + CGFloat(x) / CGFloat(image.width) * size,
                        y: 10 + CGFloat(y) / CGFloat(image.height) * size)))
                    samples += 1
                }
            } }
            #expect(samples > 10)
        }
        for viewport in [CGSize(width: 320, height: 568), CGSize(width: 393, height: 852), CGSize(width: 1024, height: 768)] {
            let bounds = AquariumFishMotion.movementProfile(for: .mandarinfish).roamingStyle.bounds(in: viewport, fishSize: size)
            #expect(bounds.horizontal.lowerBound * viewport.width >= size * 0.72 + 5.9)
            #expect(bounds.vertical.lowerBound * viewport.height >= size * 0.72 + 5.9)
        }
    }

    @Test func renderThreeBackgroundComparisonsAtAquariumAndDetailSizes() throws {
        for theme in AquariumBackgroundTheme.allCases {
            for detail in [false, true] {
                let size: CGFloat = detail ? 128 : AquariumFishSizing.displaySize(for: .mandarinfish, isFavorite: false)
                let renderer = ImageRenderer(content: HStack(spacing: 0) {
                    ForEach([false, true], id: \.self) { corrected in
                        ZStack {
                            AquariumBackground(theme: theme)
                            ForEach([0.18, 0.5, 0.82], id: \.self) { y in
                                FishImageView(species: .mandarinfish)
                                    .frame(width: size, height: size)
                                    .modifier(corrected ? AquariumFishColorCorrection.correction(for: theme, species: .mandarinfish)
                                        : .init(saturation: 1, brightness: 0, red: 1, green: 1, blue: 1))
                                    .opacity(FishMovementProfile.mandarinfish.depthOpacity(at: 0.5))
                                    .position(x: 196.5, y: 746 * y)
                            }
                            VStack {
                                Text(corrected ? "水中補正" : "原画像").font(.caption).foregroundStyle(.white)
                                    .padding(6).background(.black.opacity(0.65))
                                Spacer()
                            }
                        }.frame(width: 393, height: 746).clipped()
                    }
                })
                renderer.scale = 2
                try #require(renderer.uiImage?.pngData()).write(to: URL(fileURLWithPath:
                    "/private/tmp/Mandarinfish-\(theme.rawValue)-\(detail ? "detail" : "actual").png"))
            }
        }
    }
}
