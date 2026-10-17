import Foundation
import SwiftUI
import UIKit
import Testing
@testable import PomodoroAquarium

@MainActor
struct BlueGreenChromisTests {
    @Test func registrationAndAssets() throws {
        let species = FishSpecies.blueGreenChromis
        #expect(species.rawValue == "blueGreenChromis")
        #expect(species.name == "デバスズメダイ" && species.rarity == .common)
        #expect(species.imageName == "fish_blue_green_chromis_side_2")
        #expect(species.swimmingImageNames == (1...3).map { "fish_blue_green_chromis_side_\($0)" })
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
        let chromis = AquariumFishMotion.initialState(for: id, profile: AquariumFishMotion.movementProfile(for: .blueGreenChromis))
        let blue = AquariumFishMotion.initialState(for: id, profile: AquariumFishMotion.movementProfile(for: .blueTang))
        #expect(chromis.position == blue.position && chromis.velocity == blue.velocity)
        #expect(chromis.baseSpeed == blue.baseSpeed && chromis.facingDirection == blue.facingDirection)
        #expect(chromis.movementProfile.roamingStyle == .small)
        for behavior in AquariumFishMotion.Behavior.allCases {
            #expect(AquariumFishMotion.behaviorTargetSpeedMultiplier(for: .blueGreenChromis, behavior: behavior)
                == AquariumFishMotion.behaviorTargetSpeedMultiplier(for: .blueTang, behavior: behavior))
            #expect(AquariumFishMotion.spriteFrameDuration(for: .blueGreenChromis, behavior: behavior, currentSpeed: 1, baseSpeed: 1) == 0.20)
        }
        for direction in FishFacingDirection.allCases {
            #expect(FishSpecies.blueGreenChromis.swimmingImageRotation(for: direction) == FishSpecies.blueTang.swimmingImageRotation(for: direction))
            #expect(FishSpecies.blueGreenChromis.swimmingImageNames(for: direction) == FishSpecies.blueGreenChromis.swimmingImageNames)
        }
        #expect(FishImageView(species: .blueGreenChromis, facingHorizontalScale: -1).resolvedHorizontalScale == -1)
        #expect((0..<8).map { FishSpriteAnimation.pingPongFrameIndex(frameCount: 3, elapsedTime: Double($0) * 0.20 + 0.001, frameDuration: 0.20) }
            == [0, 1, 2, 1, 0, 1, 2, 1])
    }

    @Test func renderedWidthMatchesClownfishWithoutCroppingFins() throws {
        func visibleWidth(_ species: FishSpecies, frame: CGSize? = nil) throws -> Int {
            let size = AquariumFishSizing.displaySize(for: species, isFavorite: false)
            let frame = frame ?? CGSize(width: size, height: size)
            let renderer = ImageRenderer(content: FishImageView(species: species).frame(width: frame.width, height: frame.height))
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
        #expect(FishSpecies.blueGreenChromis.displayScale == 0.429)
        let chromis = try visibleWidth(.blueGreenChromis), clown = try visibleWidth(.clownfish)
        #expect(abs(Double(chromis) / Double(clown) - 1) < 0.03)
        print("Neutral visible width: blueGreenChromis \(Double(chromis) / 3)pt, clownfish \(Double(clown) / 3)pt")
        let bookChromis = try visibleWidth(.blueGreenChromis, frame: BookFishThumbnailLayout.imageSize(for: .blueGreenChromis))
        let bookClown = try visibleWidth(.clownfish, frame: BookFishThumbnailLayout.imageSize(for: .clownfish))
        #expect(abs(Double(bookChromis) / Double(bookClown) - 1) < 0.03)
        let ratio = FishDetailImageLayout.visibleContentRatio(for: .blueGreenChromis)
        #expect(ratio == CGSize(width: 0.916, height: 0.486))
        let available = FishDetailImageLayout.availableSize(in: CGSize(width: 320, height: 240))
        let size = FishDetailImageLayout.displaySize(for: .blueGreenChromis, availableSize: available)
        #expect(size * ratio.width <= available.width && size * ratio.height <= available.height)
    }
}
