import SwiftUI
import UIKit
import Testing
@testable import PomodoroAquarium

@MainActor
struct AquariumFishColorCorrectionTests {
    @Test func otherThemesRemainUnchangedAndBasicUsesLightResponseGroups() {
        for species in FishSpecies.allCases.filter({ !targetSpecies.contains($0) }) {
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
            let frames = species == .seaTurtle ? Set(0..<7) : species == .mandarinfish ? Set(0..<5) : species == .lionfish ? Set(0..<7)
                : Set([0, species.swimmingImageNames.count / 2, max(species.swimmingImageNames.count - 1, 0)])
            for frame in frames {
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

    @Test func existingSixSpeciesKeepExactlyThePreviousRenderedPixelsForEveryBackground() throws {
        for species in FishSpecies.allCases.filter({ !targetSpecies.contains($0) }) {
            let source = FishImageView(species: species, fixedAnimationFrameIndex: 1).frame(width: 128, height: 128)
            for theme in AquariumBackgroundTheme.allCases {
                let previous = ImageRenderer(content: source.modifier(legacy(theme, species)))
                let current = ImageRenderer(content: source.modifier(AquariumFishColorCorrection.correction(for: theme, species: species)))
                #expect(pixelValues(try #require(previous.uiImage?.cgImage)) == pixelValues(try #require(current.uiImage?.cgImage)))
            }
        }
    }

    private let targetSpecies: [FishSpecies] = [.blueTang, .yellowTang, .blueGreenChromis, .orientalButterflyfish, .pennantCoralfish, .lionfish, .porcupinefish, .mandarinfish, .seaTurtle]

    // 今回の変更前の値を独立して保持。比較・回帰検証に現在の値を流用しない。
    private func legacy(_ theme: AquariumBackgroundTheme, _ species: FishSpecies) -> AquariumFishColorCorrection {
        switch theme {
        case .aquarium:
            if species == .jellyfish {
                return .init(saturation: 0.92, brightness: -0.005, red: 0.98, green: 0.995, blue: 1, contrast: 0.98)
            }
            return .init(saturation: species == .clownfish || species == .seahorse ? 0.84 : 0.88,
                         brightness: -0.015, red: 0.97, green: 0.99, blue: 1, contrast: 0.96)
        case .tropical:
            return .init(saturation: 0.94, brightness: 0.008, red: 0.96, green: 1, blue: 1)
        case .deepSea:
            return .init(saturation: species == .jellyfish ? 0.94 : 0.88,
                         brightness: species == .jellyfish ? -0.03 : -0.06,
                         red: species == .jellyfish ? 0.91 : 0.82, green: species == .jellyfish ? 0.955 : 0.91, blue: 1)
        }
    }

    @Test func renderThreeFishOnAllActualBackgroundsAtMatchedPositionsAndSizes() throws {
        for theme in [AquariumBackgroundTheme.aquarium, .tropical, .deepSea] {
            // ハタタテダイは専用テストで別画像へ出力し、縦連結が描画上限を超えないようにする。
            let speciesList = targetSpecies.filter { $0 != .pennantCoralfish && $0 != .lionfish && $0 != .porcupinefish && $0 != .mandarinfish && $0 != .seaTurtle } + [.clownfish]
            let full = ImageRenderer(content: VStack(spacing: 0) {
                ForEach(speciesList, id: \.self) { species in
                    HStack(spacing: 0) {
                        comparisonScene(theme, species, after: false)
                        comparisonScene(theme, species, after: true)
                    }
                }
            })
            full.scale = 2
            try #require(full.uiImage?.pngData()).write(to: URL(fileURLWithPath: "/private/tmp/FishColor-\(theme.rawValue)-actual.png"))
            let zoom = ImageRenderer(content: VStack(spacing: 0) {
                ForEach(speciesList, id: \.self) { species in
                    VStack(spacing: 4) {
                        Text("\(theme.displayName) / \(species.name) / 上部：前・後 ｜ 下部：前・後").font(.caption).foregroundStyle(.black).zIndex(1)
                        HStack(spacing: 4) {
                            ForEach([0.18, 0.82], id: \.self) { y in
                                ForEach([false, true], id: \.self) { after in
                                    comparisonScene(theme, species, after: after, labels: false)
                                        .offset(y: CGFloat(0.5 - y) * 746)
                                        .frame(width: 72, height: 76).clipped()
                                        .scaleEffect(3).frame(width: 216, height: 228).clipped()
                                }
                            }
                        }
                    }.padding(.vertical, 8)
                }
            }.background(.white))
            zoom.scale = 2
            try #require(zoom.uiImage?.pngData()).write(to: URL(fileURLWithPath: "/private/tmp/FishColor-\(theme.rawValue)-detail.png"))
        }
    }

    private func comparisonScene(_ theme: AquariumBackgroundTheme, _ species: FishSpecies,
                                 after: Bool, labels: Bool = true) -> some View {
        let size = AquariumFishSizing.displaySize(for: species, isFavorite: false)
        return ZStack {
            // 本番の00＋光01のscreen合成。ImageRendererの初期描画で光フレームを揃える。
            AquariumBackground(theme: theme)
            ForEach([0.18, 0.5, 0.82], id: \.self) { y in
                FishImageView(species: species, fixedAnimationFrameIndex: 1)
                    .frame(width: size, height: size)
                    .modifier(after ? AquariumFishColorCorrection.correction(for: theme, species: species) : legacy(theme, species))
                    .opacity(AquariumFishMotion.movementProfile(for: species).depthOpacity(at: 0.5))
                    .position(x: 393 / 2, y: CGFloat(y) * 746)
            }
            if labels {
                VStack {
                    Text("\(species.name) / \(after ? "AFTER" : "BEFORE") / \(theme.displayName)")
                        .font(.caption).foregroundStyle(.white).padding(6).background(.black.opacity(0.65))
                    Spacer()
                }
            }
        }.frame(width: 393, height: 746).clipped()
    }

    @Test func targetMatrixSwitchesByBackgroundAndLeavesTheTwoBasicCombinationsUnchanged() {
        let expected: [(AquariumBackgroundTheme, FishSpecies, [Double])] = [
            (.aquarium, .blueTang, [0.88, -0.015, 0.97, 0.99, 1, 0.96]),
            (.aquarium, .yellowTang, [0.88, -0.015, 0.97, 0.99, 1, 0.96]),
            (.aquarium, .blueGreenChromis, [0.94, -0.012, 0.98, 1, 0.99, 1.03]),
            (.tropical, .blueTang, [0.90, -0.012, 0.98, 0.995, 1, 1.08]),
            (.tropical, .yellowTang, [0.86, -0.020, 1, 0.99, 0.97, 1.02]),
            (.tropical, .blueGreenChromis, [0.96, -0.025, 0.99, 1, 0.96, 1.12]),
            (.deepSea, .blueTang, [0.90, -0.040, 0.90, 0.95, 1, 1.04]),
            (.deepSea, .yellowTang, [0.86, -0.045, 0.94, 0.94, 0.98, 1]),
            (.deepSea, .blueGreenChromis, [0.92, -0.045, 0.92, 0.97, 1, 1.04]),
            (.aquarium, .orientalButterflyfish, [0.86, -0.015, 0.97, 0.99, 1, 1.02]),
            (.tropical, .orientalButterflyfish, [0.84, -0.020, 1, 0.99, 0.97, 1.03]),
            (.deepSea, .orientalButterflyfish, [0.86, -0.045, 0.94, 0.94, 0.98, 1.02]),
            (.aquarium, .pennantCoralfish, [0.86, -0.025, 0.91, 0.95, 0.99, 0.98]),
            (.tropical, .pennantCoralfish, [0.84, -0.035, 0.92, 0.95, 0.97, 0.97]),
            (.deepSea, .pennantCoralfish, [0.88, -0.040, 0.86, 0.92, 1, 0.98]),
            (.aquarium, .seaTurtle, [0.88, -0.015, 0.96, 0.99, 1, 1.02]),
            (.tropical, .seaTurtle, [0.86, -0.020, 0.99, 0.99, 0.97, 1.04]),
            (.deepSea, .seaTurtle, [0.88, -0.035, 0.94, 0.97, 1, 1.04]),
            (.aquarium, .mandarinfish, [0.90, -0.008, 0.99, 0.99, 1, 1.03]),
            (.tropical, .mandarinfish, [0.91, -0.010, 1, 0.99, 0.98, 1.06]),
            (.deepSea, .mandarinfish, [0.92, -0.015, 0.97, 0.98, 1, 1.02]),
            (.aquarium, .porcupinefish, [0.86, -0.025, 0.95, 0.98, 1, 1.01]),
            (.tropical, .porcupinefish, [0.84, -0.035, 0.97, 0.98, 0.96, 1.03]),
            (.deepSea, .porcupinefish, [0.88, -0.045, 0.90, 0.95, 1, 1.02]),
            (.aquarium, .lionfish, [0.88, -0.020, 0.96, 0.98, 1, 1.02]),
            (.tropical, .lionfish, [0.90, -0.025, 0.99, 0.98, 0.96, 1.06]),
            (.deepSea, .lionfish, [0.88, -0.045, 0.91, 0.95, 1, 1.02])
        ]
        for (theme, species, values) in expected {
            let c = AquariumFishColorCorrection.correction(for: theme, species: species)
            #expect([c.saturation, c.brightness, c.red, c.green, c.blue, c.contrast] == values)
        }
    }

    @Test func neutralSpritesRetainTonalRangeAndDoNotIntroduceBroadClipping() throws {
        func levels(_ image: CGImage) -> [Int] {
            let bytes = pixelValues(image)
            return stride(from: 0, to: bytes.count, by: 4).compactMap { i in
                guard bytes[i + 3] >= 250 else { return nil }
                return Int((Double(bytes[i]) * 0.2126 + Double(bytes[i + 1]) * 0.7152 + Double(bytes[i + 2]) * 0.0722).rounded())
            }.sorted()
        }
        for species in targetSpecies {
            let source = FishImageView(species: species, fixedAnimationFrameIndex: 1).frame(width: 256, height: 256)
            for theme in AquariumBackgroundTheme.allCases {
                let before = levels(try #require(ImageRenderer(content: source.modifier(legacy(theme, species))).uiImage?.cgImage))
                let after = levels(try #require(ImageRenderer(content: source.modifier(AquariumFishColorCorrection.correction(for: theme, species: species))).uiImage?.cgImage))
                #expect(!before.isEmpty && before.count == after.count)
                let rangeBefore = before[before.count * 9 / 10] - before[before.count / 10]
                let rangeAfter = after[after.count * 9 / 10] - after[after.count / 10]
                #expect(Double(rangeAfter) >= Double(rangeBefore) * 0.8)
                #expect(Double(Set(after).count) >= Double(Set(before).count) * 0.8)
                let highBefore = Double(before.count { $0 >= 250 }) / Double(before.count)
                let highAfter = Double(after.count { $0 >= 250 }) / Double(after.count)
                let lowBefore = Double(before.count { $0 <= 5 }) / Double(before.count)
                let lowAfter = Double(after.count { $0 <= 5 }) / Double(after.count)
                #expect(highAfter <= highBefore + 0.02)
                #expect(lowAfter <= lowBefore + 0.03)
                print("Tones \(species.rawValue) \(theme.rawValue): p10-p90 \(rangeBefore)→\(rangeAfter), levels \(Set(before).count)→\(Set(after).count), high \(highBefore)→\(highAfter), low \(lowBefore)→\(lowAfter)")
            }
        }
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
