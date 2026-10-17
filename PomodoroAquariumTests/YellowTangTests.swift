import Foundation
import SwiftUI
import UIKit
import Testing
@testable import PomodoroAquarium

@MainActor
struct YellowTangTests {
    @Test func registrationAndAssets() throws {
        let species = FishSpecies.yellowTang
        #expect(species.rawValue == "yellowTang")
        #expect(species.name == "キイロハギ" && species.rarity == .common)
        #expect(species.imageName == "fish_yellow_tang_side_2")
        #expect(species.swimmingImageNames == (1...3).map { "fish_yellow_tang_side_\($0)" })
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
        let yellow = AquariumFishMotion.initialState(for: id, profile: AquariumFishMotion.movementProfile(for: .yellowTang))
        let blue = AquariumFishMotion.initialState(for: id, profile: AquariumFishMotion.movementProfile(for: .blueTang))
        #expect(yellow.position == blue.position && yellow.velocity == blue.velocity)
        #expect(yellow.baseSpeed == blue.baseSpeed && yellow.facingDirection == blue.facingDirection)
        #expect(yellow.movementProfile.roamingStyle == .small)
        for behavior in AquariumFishMotion.Behavior.allCases {
            #expect(AquariumFishMotion.behaviorTargetSpeedMultiplier(for: .yellowTang, behavior: behavior)
                == AquariumFishMotion.behaviorTargetSpeedMultiplier(for: .blueTang, behavior: behavior))
            #expect(AquariumFishMotion.spriteFrameDuration(for: .yellowTang, behavior: behavior, currentSpeed: 1, baseSpeed: 1) == 0.20)
        }
        for direction in FishFacingDirection.allCases {
            #expect(FishSpecies.yellowTang.swimmingImageRotation(for: direction) == FishSpecies.blueTang.swimmingImageRotation(for: direction))
            #expect(FishSpecies.yellowTang.swimmingImageNames(for: direction) == FishSpecies.yellowTang.swimmingImageNames)
        }
        #expect(FishImageView(species: .yellowTang, facingHorizontalScale: -1).resolvedHorizontalScale == -1)
        #expect((0..<8).map { FishSpriteAnimation.pingPongFrameIndex(frameCount: 3, elapsedTime: Double($0) * 0.20 + 0.001, frameDuration: 0.20) }
            == [0, 1, 2, 1, 0, 1, 2, 1])
    }

    @Test func renderedWidthKeepsItsPreviousSizeWhileBlueTangGrows() throws {
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
        #expect(FishSpecies.yellowTang.displayScale == 0.636)
        let yellow = try visibleWidth(.yellowTang), blue = try visibleWidth(.blueTang)
        #expect(abs(Double(yellow) / Double(blue) - 1 / 1.10) < 0.03)
        print("Neutral visible width: yellowTang \(Double(yellow) / 3)pt, blueTang \(Double(blue) / 3)pt")
        let bookYellow = try visibleWidth(.yellowTang, frame: BookFishThumbnailLayout.imageSize(for: .yellowTang))
        let bookBlue = try visibleWidth(.blueTang, frame: BookFishThumbnailLayout.imageSize(for: .blueTang))
        #expect(abs(Double(bookYellow) / Double(bookBlue) - 1) < 0.03)
        let ratio = FishDetailImageLayout.visibleContentRatio(for: .yellowTang)
        #expect(ratio == CGSize(width: 0.928, height: 0.716))
        let available = FishDetailImageLayout.availableSize(in: CGSize(width: 320, height: 240))
        let size = FishDetailImageLayout.displaySize(for: .yellowTang, availableSize: available)
        #expect(size * ratio.width <= available.width && size * ratio.height <= available.height)
    }
}
