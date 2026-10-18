import Foundation
import SwiftUI
import UIKit
import Testing
@testable import PomodoroAquarium

@MainActor
struct OrientalButterflyfishTests {
    @Test func registrationAndAssets() throws {
        let species = FishSpecies.orientalButterflyfish
        #expect(species.rawValue == "orientalButterflyfish")
        #expect(species.name == "チョウチョウウオ" && species.rarity == .common)
        #expect(species.imageName == "fish_oriental_butterflyfish_side_2")
        #expect(species.swimmingImageNames == (1...3).map { "fish_oriental_butterflyfish_side_\($0)" })
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
        let butterfly = AquariumFishMotion.initialState(for: id, profile: AquariumFishMotion.movementProfile(for: .orientalButterflyfish))
        let blue = AquariumFishMotion.initialState(for: id, profile: AquariumFishMotion.movementProfile(for: .blueTang))
        #expect(butterfly.position == blue.position && butterfly.velocity == blue.velocity)
        #expect(butterfly.baseSpeed == blue.baseSpeed && butterfly.facingDirection == blue.facingDirection)
        #expect(butterfly.movementProfile.roamingStyle == .small)
        for behavior in AquariumFishMotion.Behavior.allCases {
            #expect(AquariumFishMotion.behaviorTargetSpeedMultiplier(for: .orientalButterflyfish, behavior: behavior)
                == AquariumFishMotion.behaviorTargetSpeedMultiplier(for: .blueTang, behavior: behavior))
            #expect(AquariumFishMotion.spriteFrameDuration(for: .orientalButterflyfish, behavior: behavior, currentSpeed: 1, baseSpeed: 1) == 0.20)
        }
        for direction in FishFacingDirection.allCases {
            #expect(FishSpecies.orientalButterflyfish.swimmingImageRotation(for: direction) == FishSpecies.blueTang.swimmingImageRotation(for: direction))
            #expect(FishSpecies.orientalButterflyfish.swimmingImageNames(for: direction) == FishSpecies.orientalButterflyfish.swimmingImageNames)
        }
        #expect(FishImageView(species: .orientalButterflyfish, facingHorizontalScale: -1).resolvedHorizontalScale == -1)
        #expect((0..<8).map { FishSpriteAnimation.pingPongFrameIndex(frameCount: 3, elapsedTime: Double($0) * 0.20 + 0.001, frameDuration: 0.20) }
            == [0, 1, 2, 1, 0, 1, 2, 1])
    }

    @Test func renderedWidthMatchesYellowTangWithoutCroppingFins() throws {
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
            for y in 0..<image.height { for x in 0..<image.width where bytes[(y * image.width + x) * 4 + 3] > 16 {
                minX = min(minX, x); maxX = max(maxX, x)
            } }
            return maxX - minX + 1
        }
        #expect(FishSpecies.orientalButterflyfish.displayScale == 0.636)
        let butterfly = try visibleWidth(.orientalButterflyfish), yellow = try visibleWidth(.yellowTang)
        #expect(abs(Double(butterfly) / Double(yellow) - 1) < 0.03)
        print("Neutral visible width: orientalButterflyfish \(Double(butterfly) / 3)pt, yellowTang \(Double(yellow) / 3)pt")
        let bookButterfly = try visibleWidth(.orientalButterflyfish, frame: BookFishThumbnailLayout.imageSize(for: .orientalButterflyfish))
        let bookYellow = try visibleWidth(.yellowTang, frame: BookFishThumbnailLayout.imageSize(for: .yellowTang))
        #expect(abs(Double(bookButterfly) / Double(bookYellow) - 1) < 0.03)
        let ratio = FishDetailImageLayout.visibleContentRatio(for: .orientalButterflyfish)
        #expect(ratio == CGSize(width: 0.951, height: 0.686))
        let available = FishDetailImageLayout.availableSize(in: CGSize(width: 320, height: 240))
        let size = FishDetailImageLayout.displaySize(for: .orientalButterflyfish, availableSize: available)
        #expect(size * ratio.width <= available.width && size * ratio.height <= available.height)
    }

    @Test func renderActualBackgroundComparisons() throws {
        let species = FishSpecies.orientalButterflyfish
        for theme in AquariumBackgroundTheme.allCases {
            let previous: AquariumFishColorCorrection
            switch theme {
            case .aquarium:
                previous = .init(saturation: 0.88, brightness: -0.015, red: 0.97, green: 0.99, blue: 1, contrast: 0.96)
            case .tropical:
                previous = .init(saturation: 0.94, brightness: 0.008, red: 0.96, green: 1, blue: 1)
            case .deepSea:
                previous = .init(saturation: 0.88, brightness: -0.06, red: 0.82, green: 0.91, blue: 1)
            }
            for enlarged in [false, true] {
                let side = enlarged ? 160 : AquariumFishSizing.displaySize(for: species, isFavorite: false)
                let renderer = ImageRenderer(content: HStack(spacing: 0) {
                    ForEach([false, true], id: \.self) { after in
                        ZStack {
                            AquariumBackground(theme: theme)
                            ForEach([0.18, 0.5, 0.82], id: \.self) { y in
                                FishImageView(species: species, fixedAnimationFrameIndex: 1)
                                    .frame(width: side, height: side)
                                    .modifier(after ? AquariumFishColorCorrection.correction(for: theme, species: species) : previous)
                                    .opacity(AquariumFishMotion.movementProfile(for: species).depthOpacity(at: 0.5))
                                    .position(x: 196.5, y: y * 746)
                            }
                            VStack {
                                Text("\(theme.displayName) / \(after ? "AFTER" : "BEFORE")")
                                    .font(.caption).foregroundStyle(.white).padding(6).background(.black.opacity(0.65))
                                Spacer()
                            }
                        }.frame(width: 393, height: 746).clipped()
                    }
                })
                renderer.scale = 2
                let filename = "/private/tmp/Butterflyfish-\(theme.rawValue)-\(enlarged ? "detail" : "actual").png"
                try #require(renderer.uiImage?.pngData()).write(to: URL(fileURLWithPath: filename))
            }
        }
    }
}
