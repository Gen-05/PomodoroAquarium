import Foundation
import SwiftUI
import UIKit
import Testing
@testable import PomodoroAquarium

@MainActor
struct LionfishTests {
    @Test func registrationAndAssets() throws {
        let species = FishSpecies.lionfish
        #expect(species.rawValue == "lionfish")
        #expect(species.name == "ミノカサゴ" && species.rarity == .rare)
        #expect(species.imageName == "fish_lionfish_side_4")
        #expect(species.swimmingImageNames == (1...7).map { "fish_lionfish_side_\($0)" })
        let data = try JSONEncoder().encode(species)
        #expect(try JSONDecoder().decode(FishSpecies.self, from: data) == species)
        for name in species.swimmingImageNames {
            let image = try #require(UIImage(named: name)?.cgImage)
            #expect(image.width == 1254 && image.height == 1254)
            #expect(image.alphaInfo != .none && image.alphaInfo != .noneSkipFirst && image.alphaInfo != .noneSkipLast)
        }
    }

    @Test func rareCandidatesAreUniformWithoutChangingRarityProbabilities() {
        let rare = FishSpecies.allCases.filter { $0.rarity == .rare }
        #expect(rare == [.seahorse, .lionfish, .porcupinefish, .mandarinfish])
        for (minutes, expected) in [(0, 20.0 / 4), (180, 25.0 / 4), (300, 25.0 / 4)] {
            let probabilities = FishRewardService.rarityProbabilities(for: minutes)
            #expect(probabilities.total == 100)
            for species in rare {
                #expect(probabilities.probability(for: species.rarity) / Double(rare.count) == expected)
            }
        }
    }

    @Test func gracefulFloatingProfileAndIndependentSevenFrameTempo() {
        let profile = AquariumFishMotion.movementProfile(for: .lionfish)
        let clown = FishMovementProfile.clownfish
        #expect(profile.baseSpeedRange.lowerBound == clown.baseSpeedRange.lowerBound * 0.55)
        #expect(profile.baseSpeedRange.upperBound == clown.baseSpeedRange.upperBound * 0.55)
        #expect(profile.burstProbability == 0 && profile.gatheringProbability == 0)
        #expect(profile.turnResponsivenessRange.upperBound < clown.turnResponsivenessRange.lowerBound)
        #expect(profile.directionHoldDurationRange.lowerBound > clown.directionHoldDurationRange.lowerBound)
        #expect(profile.accelerationResponseRange.upperBound < clown.accelerationResponseRange.lowerBound)
        #expect(profile.steeringNoiseMultiplier < clown.steeringNoiseMultiplier)
        #expect(AquariumFishMotion.presentationAmplitude(for: .lionfish) == 0.45)
        for species in FishSpecies.allCases where species != .lionfish && species != .porcupinefish && species != .mandarinfish && species != .seaTurtle && species != .dolphin && species != .manta {
            #expect(AquariumFishMotion.presentationAmplitude(for: species) == 1)
        }
        for direction in FishFacingDirection.allCases {
            #expect(abs(FishSpecies.lionfish.swimmingImageRotation(for: direction)) <= 22.5)
            #expect(FishSpecies.lionfish.swimmingImageNames(for: direction).count == 7)
        }
        for behavior in AquariumFishMotion.Behavior.allCases {
            for speed: CGFloat in [0, 0.01, 1] {
                #expect(AquariumFishMotion.spriteFrameDuration(for: .lionfish, behavior: behavior, currentSpeed: speed, baseSpeed: 0.015) == 0.20)
            }
        }
        let expected = [0, 1, 2, 3, 4, 5, 6, 5, 4, 3, 2, 1]
        #expect((0..<24).map {
            FishSpriteAnimation.pingPongFrameIndex(frameCount: 7, elapsedTime: Double($0) * 0.20 + 0.001, frameDuration: 0.20)
        } == expected + expected)
        #expect(FishImageView(species: .lionfish, facingHorizontalScale: -1).resolvedHorizontalScale == -1)
        #expect(FishImageView(species: .lionfish).interactionImage?.pngData() == UIImage(named: "fish_lionfish_side_4")?.pngData())
    }

    @Test func renderedBodyWidthUsesTheUpdatedAquariumScaleWithoutCroppingFins() throws {
        func visibleWidth(_ species: FishSpecies, frame: CGSize? = nil) throws -> Int {
            let size = AquariumFishSizing.displaySize(for: species, isFavorite: false)
            let frame = frame ?? CGSize(width: size, height: size)
            let renderer = ImageRenderer(content: FishImageView(species: species, fixedAnimationFrameIndex: species == .lionfish ? 3 : 1).frame(width: frame.width, height: frame.height))
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
            // 基準フレームの尾柄から鼻先。大きなひれや尾びれの外縁は含めない。
            let bodyStart: CGFloat = species == .lionfish ? 315 : 275
            let fromX = Int((bodyStart / 1254 * CGFloat(image.width)).rounded(.up))
            for y in 0..<image.height { for x in fromX..<image.width where bytes[(y * image.width + x) * 4 + 3] > 16 {
                minX = min(minX, x); maxX = max(maxX, x)
            } }
            return maxX - minX + 1
        }
        #expect(FishSpecies.lionfish.displayScale == 0.636)
        let butterfly = try visibleWidth(.lionfish), yellow = try visibleWidth(.yellowTang)
        #expect(abs(Double(butterfly) / Double(yellow) - 1.6332875) < 0.03)
        print("Neutral visible width: lionfish \(Double(butterfly) / 3)pt, yellowTang \(Double(yellow) / 3)pt")
        let ratio = FishDetailImageLayout.visibleContentRatio(for: .lionfish)
        #expect(ratio == CGSize(width: 0.867, height: 0.747))
        let available = FishDetailImageLayout.availableSize(in: CGSize(width: 320, height: 240))
        let size = FishDetailImageLayout.displaySize(for: .lionfish, availableSize: available)
        #expect(size * ratio.width <= available.width && size * ratio.height <= available.height)
    }

    @Test func finsFitAndRemainSelectableAcrossAllSevenFrames() throws {
        let side = AquariumFishSizing.displaySize(for: .lionfish, isFavorite: false)
        for frame in 0..<7 {
            let view = FishImageView(species: .lionfish, fixedAnimationFrameIndex: frame)
            let image = try #require(view.interactionImage)
            let canvas = side + 20
            let path = AquariumFishHitTesting.path(image: image, canvasSize: canvas, fishSize: side)
            let renderer = ImageRenderer(content: view.frame(width: side, height: side))
            renderer.scale = 3
            let cg = try #require(renderer.uiImage?.cgImage)
            var pixels = [UInt8](repeating: 0, count: cg.width * cg.height * 4)
            pixels.withUnsafeMutableBytes {
                CGContext(data: $0.baseAddress, width: cg.width, height: cg.height, bitsPerComponent: 8,
                    bytesPerRow: cg.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                    .draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
            }
            var selectableFinSamples = 0
            for y in 0..<cg.height { for x in 0..<cg.width where pixels[(y * cg.width + x) * 4 + 3] > 128 {
                #expect(x > 0 && x < cg.width - 1 && y > 0 && y < cg.height - 1)
                if y < cg.height / 3 && x.isMultiple(of: 3) && y.isMultiple(of: 3) {
                    #expect(path.contains(CGPoint(x: 10 + CGFloat(x) / CGFloat(cg.width) * side,
                                                 y: 10 + CGFloat(y) / CGFloat(cg.height) * side)))
                    selectableFinSamples += 1
                }
            } }
            #expect(selectableFinSamples > 0)
        }
    }

    @Test func actualSwimmingViewUsesTheUncappedSize() async throws {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = try #require(scenes.first { $0.activationState == .foregroundActive } ?? scenes.first)
        let maximumSize: CGFloat = 89.30533781498258 * 0.85
        for (size, depth) in [(CGSize(width: 320, height: 568), CGFloat(0)),
                              (CGSize(width: 393, height: 852), CGFloat(0.5)),
                              (CGSize(width: 393, height: 852), CGFloat(1))] {
            let id = UUID(), session = AquariumFishViewingSession()
            let profile = AquariumFishMotion.movementProfile(for: .lionfish)
            let expected = maximumSize * profile.depthScale(at: depth)
            let bounds = profile.roamingStyle.bounds(in: size, fishSize: maximumSize)
            var motion = AquariumFishMotion.initialState(for: id, profile: profile,
                roamingBounds: bounds, initialPosition: CGPoint(x: 0.5, y: 0.5))
            motion.currentDepth = depth
            motion.targetDepth = depth
            // 揺れ・旋回を固定し、通常のSwimmingFishViewの描画枠そのものを測る。
            motion.facingDirection = .right
            motion.swimPhase = 0
            motion.presentationMotionIntensity = 0
            _ = session.claim(id, owner: UUID(), initial: .init(motion: motion,
                direction: FishSpriteDirectionTransition(direction: .right)), bounds: bounds)
            var rendered: CGRect?
            var fish = SwimmingFishView(fishID: id, viewingSession: session,
                species: .lionfish, backgroundTheme: .aquarium, isFavorite: false, aquariumSize: size,
                updateDate: Date(timeIntervalSince1970: 100), isSimulationPaused: true,
                isSelectionEnabled: true, isSelected: false, neighborPositions: .empty,
                reportPosition: { _ in }, select: {})
            fish.onRenderedFrames = { ring, frame in if !ring { rendered = frame } }
            let host = UIHostingController(rootView: fish.frame(width: size.width, height: size.height).ignoresSafeArea())
            let window = UIWindow(windowScene: scene)
            window.frame = CGRect(origin: .zero, size: size)
            window.rootViewController = host
            window.makeKeyAndVisible()
            defer { window.isHidden = true }
            host.view.layoutIfNeeded()
            try await Task.sleep(for: .milliseconds(60))
            host.view.layoutIfNeeded()
            let frame = try #require(rendered)
            #expect(abs(frame.width - expected) < 0.5)
            #expect(abs(frame.height - expected) < 0.5)
            #expect(abs(frame.width / 94.00561875261324 - 0.95 * 0.85 * profile.depthScale(at: depth)) < 0.01)
        }
    }

    @Test func renderActualBackgroundComparisons() throws {
        let species = FishSpecies.lionfish
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
                                FishImageView(species: species, fixedAnimationFrameIndex: 3)
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
                let filename = "/private/tmp/Lionfish-\(theme.rawValue)-\(enlarged ? "detail" : "actual").png"
                try #require(renderer.uiImage?.pngData()).write(to: URL(fileURLWithPath: filename))
            }
        }
    }

    @Test func renderBodySizeComparison() throws {
        let renderer = ImageRenderer(content: HStack(spacing: 24) {
            ForEach([FishSpecies.yellowTang, .lionfish], id: \.self) { species in
                VStack {
                    FishImageView(species: species).frame(
                        width: AquariumFishSizing.displaySize(for: species, isFavorite: false),
                        height: AquariumFishSizing.displaySize(for: species, isFavorite: false))
                        .frame(width: 100, height: 100)
                    Text(species.name).font(.caption)
                }
            }
        }.padding().background(.white))
        renderer.scale = 3
        try #require(renderer.uiImage?.pngData()).write(to: URL(fileURLWithPath: "/private/tmp/Lionfish-body-size.png"))
    }
}
