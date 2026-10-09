import SwiftUI
import UIKit
import Testing
@testable import PomodoroAquarium

@MainActor
struct AquariumFishColorCorrectionTests {
    @Test func otherThemesRemainUnchangedAndBasicUsesLightResponseGroups() {
        for species in FishSpecies.allCases {
            let deep = AquariumFishColorCorrection.correction(for: .deepSea, species: species)
            #expect(deep.saturation == (species == .jellyfish ? 0.94 : 0.88))
            #expect(deep.brightness == (species == .jellyfish ? -0.03 : -0.06))
            #expect(deep.red == (species == .jellyfish ? 0.91 : 0.82))
            #expect(deep.green == (species == .jellyfish ? 0.955 : 0.91))
            #expect(deep.blue == 1)
            let basic = AquariumFishColorCorrection.correction(for: .aquarium, species: species)
            let coral = AquariumFishColorCorrection.correction(for: .tropical, species: species)
            #expect(deep.contrast == 1)
            #expect(coral.saturation == 0.94 && coral.brightness == 0.008)
            #expect(coral.red == 0.96 && coral.green == 1 && coral.blue == 1 && coral.contrast == 1)
            let isWarm = species == .clownfish || species == .seahorse
            #expect(basic.saturation == (isWarm ? 0.84 : species == .jellyfish ? 0.92 : 0.88))
            #expect(basic.contrast == (species == .jellyfish ? 0.98 : 0.96))
            #expect(basic.brightness == (species == .jellyfish ? -0.005 : -0.015))
        }
    }

    @Test func correctionPreservesSpriteAlphaAndDimensionsIncludingJellyfish() throws {
        for species in FishSpecies.allCases {
            for frame in Set([0, max(species.swimmingImageNames.count - 1, 0)]) {
                let source = FishImageView(species: species, fixedAnimationFrameIndex: frame).frame(width: 128, height: 128)
                let original = ImageRenderer(content: source)
                let image = try #require(original.uiImage?.cgImage)
                let alpha = alphaValues(image)
                for theme in AquariumBackgroundTheme.allCases {
                    let renderer = ImageRenderer(content: source.modifier(AquariumFishColorCorrection.correction(for: theme, species: species)))
                    let result = try #require(renderer.uiImage?.cgImage)
                    #expect(result.width == image.width && result.height == image.height)
                    let correctedAlpha = alphaValues(result)
                    #expect(zip(alpha, correctedAlpha).allSatisfy { abs(Int($0.0) - Int($0.1)) <= 1 })
                }
            }
        }
    }

    @Test func otherThemesKeepThePreviousRenderedPixels() throws {
        for species in FishSpecies.allCases {
            let source = FishImageView(species: species, fixedAnimationFrameIndex: 0).frame(width: 128, height: 128)
            for theme in [AquariumBackgroundTheme.tropical, .deepSea] {
                let correction = AquariumFishColorCorrection.correction(for: theme, species: species)
                let previous = ImageRenderer(content: source.saturation(correction.saturation)
                    .colorMultiply(Color(red: correction.red, green: correction.green, blue: correction.blue))
                    .brightness(correction.brightness))
                let current = ImageRenderer(content: source.modifier(correction))
                #expect(pixelValues(try #require(previous.uiImage?.cgImage)) == pixelValues(try #require(current.uiImage?.cgImage)))
            }
        }
    }

    @Test func renderBasicBeforeAndAfterAtIdenticalPositions() throws {
        let previousBasic = AquariumFishColorCorrection(saturation: 0.96, brightness: -0.005, red: 0.98, green: 0.995, blue: 1)
        let renderer = ImageRenderer(content: VStack(spacing: 0) {
            ForEach(FishSpecies.allCases, id: \.self) { species in
                HStack(spacing: 0) {
                    ForEach([false, true], id: \.self) { after in
                        ZStack {
                            Image(AquariumBackgroundTheme.aquarium.imageName).resizable().scaledToFill()
                                .frame(width: 270, height: 170).clipped()
                            FishImageView(species: species, fixedAnimationFrameIndex: 0)
                                .frame(width: 140, height: 140)
                                .modifier(after ? AquariumFishColorCorrection.correction(for: .aquarium, species: species) : previousBasic)
                            VStack {
                                Text("\(species.name) / \(after ? "変更後" : "変更前")").font(.caption).foregroundStyle(.white)
                                Spacer()
                            }.padding(.top, 8)
                        }.frame(width: 270, height: 170)
                    }
                }
            }
        })
        renderer.scale = 2
        try #require(renderer.uiImage?.pngData()).write(to: URL(fileURLWithPath: "/private/tmp/PomodoroBasicFishColorComparison.png"))
    }

    private func alphaValues(_ image: CGImage) -> [UInt8] {
        let pixels = pixelValues(image)
        return stride(from: 3, to: pixels.count, by: 4).map { pixels[$0] }
    }

    private func pixelValues(_ image: CGImage) -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        pixels.withUnsafeMutableBytes { bytes in
            let context = CGContext(data: bytes.baseAddress, width: image.width, height: image.height,
                bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return pixels
    }
}
