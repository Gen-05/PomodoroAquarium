import Foundation
import SwiftUI
import UIKit
import Testing
@testable import PomodoroAquarium

@MainActor
struct PorcupinefishTests {
    private typealias Inflation = AquariumPorcupinefishInflation
    private var ids: [UUID] {
        (1...5).map { UUID(uuidString: String(format: "B0C0F15A-6A60-4A60-8A60-%012d", $0))! }
    }

    private func neutralState(id: UUID? = nil) -> Inflation.State {
        var state = Inflation.State(id: id ?? ids[0])
        for _ in 0..<100 where state.swimmingFrameIndex != 1 { state.advance(deltaTime: 0.01) }
        return state
    }

    @Test func registrationAndThirteenAssetsUseTheSameNeutralConnection() throws {
        let species = FishSpecies.porcupinefish
        #expect(species.rawValue == "porcupinefish" && species.name == "ハリセンボン" && species.rarity == .rare)
        #expect(species.imageName == "fish_porcupinefish_side_2")
        #expect(species.swimmingImageNames == (1...3).map { "fish_porcupinefish_side_\($0)" })
        #expect(try JSONDecoder().decode(FishSpecies.self, from: JSONEncoder().encode(species)) == species)
        for name in species.swimmingImageNames + Inflation.inflationImageNames {
            let image = try #require(UIImage(named: name)?.cgImage)
            #expect(image.width == 1254 && image.height == 1254)
            #expect(image.alphaInfo == .premultipliedLast || image.alphaInfo == .premultipliedFirst || image.alphaInfo == .last || image.alphaInfo == .first)
        }
        #expect(UIImage(named: species.imageName!)?.pngData() == UIImage(named: Inflation.inflationImageNames[0])?.pngData())
        #expect(FishImageView(species: species).interactionImage?.pngData() == UIImage(named: species.imageName!)?.pngData())
        #expect(AquariumFishMotion.spriteFrameDuration(for: species, behavior: .cruising, currentSpeed: 0.5, baseSpeed: 0.01) == 0.30)
        #expect((0..<8).map { FishSpriteAnimation.pingPongFrameIndex(frameCount: 3,
            elapsedTime: Double($0) * 0.30 + 0.001, frameDuration: 0.30) } == [0, 1, 2, 1, 0, 1, 2, 1])
    }

    @Test func fullCycleHasExactDurationsNoRepeatedRequestsAndReturnsToNeutral() {
        var state = neutralState()
        let accepted = state.request()
        #expect(accepted)
        #expect(state.phase == .inflating && state.imageName == Inflation.inflationImageNames[0])
        var seen: [String] = [state.imageName]
        for _ in 0..<120 {
            let repeated = state.request()
            #expect(!repeated)
            state.advance(deltaTime: 0.01)
            if seen.last != state.imageName { seen.append(state.imageName) }
        }
        #expect(state.phase == .holding)
        #expect(seen == Inflation.inflationImageNames)
        #expect(abs(state.speedMultiplier - 0.60) < 0.000001)
        state.advance(deltaTime: 0.799)
        let holdTap = state.request()
        #expect(state.phase == .holding && !holdTap)
        state.advance(deltaTime: 0.001)
        #expect(state.phase == .deflating && state.imageName == Inflation.inflationImageNames[9])
        seen = [state.imageName]
        for _ in 0..<179 {
            let repeated = state.request()
            #expect(!repeated)
            state.advance(deltaTime: 0.01)
            if seen.last != state.imageName { seen.append(state.imageName) }
        }
        #expect(state.phase == .deflating)
        #expect(seen == Array(Inflation.inflationImageNames.reversed()))
        state.advance(deltaTime: 0.01)
        #expect(state.phase == .swimming && state.imageName == "fish_porcupinefish_side_2")
        #expect(state.speedMultiplier == 1 && state.canRequest)
        #expect((25...45).contains(state.waitingTime))
        let next = state.waitingTime
        state.advance(deltaTime: 5)
        #expect(abs(state.waitingTime - (next - 5)) < 0.000001)
    }

    @Test func tapsWaitForNeutralAndAutoSchedulesAfterContractionWithIndependentTiming() {
        var timings: [Double] = [], frames: [Double] = []
        for id in ids {
            var state = Inflation.State(id: id)
            #expect(state == Inflation.State(id: id))
            #expect((25...45).contains(state.waitingTime))
            timings.append(state.waitingTime)
            frames.append(state.swimmingTime)
            let wait = state.waitingTime
            state.advance(deltaTime: wait - 0.001)
            #expect(state.phase == .swimming && !state.requested)
            state.advance(deltaTime: 0.001)
            #expect(state.requested || state.phase == .inflating)
            state.advance(deltaTime: state.frameDuration * 2 + 0.001)
            #expect(state.phase == .inflating)
            state.advance(deltaTime: 3.8)
            #expect(state.phase == .swimming && (24...45).contains(state.waitingTime))
        }
        #expect(Set(timings).count == 5 && Set(frames).count == 5)
        var pending = Inflation.State(id: ids[0])
        while pending.swimmingFrameIndex != 0 { pending.advance(deltaTime: 0.01) }
        let pendingAccepted = pending.request()
        #expect(pendingAccepted)
        #expect(pending.phase == .swimming && pending.requested)
        let pendingRepeated = pending.request()
        #expect(!pendingRepeated)
        pending.advance(deltaTime: pending.frameDuration + 0.001)
        #expect(pending.phase == .inflating)
    }

    @Test func inflationSpeedIsContinuousAndExistingMotionDoesNotResetAtPhaseBoundaries() {
        var state = neutralState()
        _ = state.request()
        var motion = AquariumFishMotion.initialState(for: ids[0],
            profile: AquariumFishMotion.movementProfile(for: .porcupinefish))
        let original = motion.position
        var previousSpeed: CGFloat = 1
        for tick in 1...150 {
            let before = motion.position
            state.advance(deltaTime: 1.0 / 30)
            #expect(abs(state.speedMultiplier - previousSpeed) < 0.025)
            previousSpeed = state.speedMultiplier
            motion.advance(deltaTime: 1.0 / 30, elapsedTime: Double(tick) / 30,
                speedMultiplier: state.speedMultiplier,
                behaviorTargetSpeedMultiplier: AquariumFishMotion.behaviorTargetSpeedMultiplier(for: .porcupinefish, behavior: motion.behavior))
            #expect(hypot(motion.position.x - before.x, motion.position.y - before.y) < 0.005)
        }
        #expect(motion.position != original && state.phase == .swimming)
        let profile = AquariumFishMotion.movementProfile(for: .porcupinefish)
        #expect(profile.baseSpeedRange == FishMovementProfile.lionfish.baseSpeedRange)
        #expect(profile.burstProbability == 0 && profile.turnResponsivenessRange == FishMovementProfile.lionfish.turnResponsivenessRange)
    }

    @Test func sessionTransfersInflationAndRejectsOldOwnersAndRepeatedCommands() throws {
        let session = AquariumFishViewingSession(), id = ids[0], a = UUID(), b = UUID()
        let profile = AquariumFishMotion.movementProfile(for: .porcupinefish)
        let bounds = profile.roamingStyle.bounds(in: CGSize(width: 393, height: 852), fishSize: 67)
        let motion = AquariumFishMotion.initialState(for: id, profile: profile, roamingBounds: bounds)
        var initial = AquariumFishViewingSession.Snapshot(motion: motion,
            direction: .init(direction: motion.facingDirection), inflation: neutralState())
        _ = session.claim(id, owner: a, initial: initial, bounds: bounds)
        #expect(session.requestInflation(for: id) && !session.requestInflation(for: id))
        _ = session.claim(id, owner: b, initial: initial, bounds: bounds)
        #expect(!session.takeInflationRequest(for: id, owner: a))
        #expect(session.takeInflationRequest(for: id, owner: b))
        initial.inflation?.request()
        initial.inflation?.advance(deltaTime: 1.5)
        #expect(session.update(id, owner: b, snapshot: initial))
        #expect(!session.update(id, owner: a, snapshot: initial))
        session.release(id, owner: a)
        #expect(session.isOwner(id, owner: b))
        session.release(id, owner: b)
        let resumed = session.claim(id, owner: a, initial: initial, bounds: bounds)
        #expect(resumed.inflation == initial.inflation && resumed.motion.position == initial.motion.position)
        #expect(resumed.inflation?.phase == .holding)
        #expect(!session.requestInflation(for: id))
        session.beginEditing()
        let edit = try #require(session.editingSession)
        var draft = edit.claim(id, owner: b, initial: initial, bounds: bounds)
        draft.inflation?.advance(deltaTime: 1)
        _ = edit.update(id, owner: b, snapshot: draft)
        session.finishEditing()
        #expect(session.snapshot(for: id)?.inflation == initial.inflation)
        session.beginEditing()
        let committed = try #require(session.editingSession)
        _ = committed.claim(id, owner: b, initial: draft, bounds: bounds)
        _ = committed.update(id, owner: b, snapshot: draft)
        session.finishEditing(commit: [id])
        #expect(session.snapshot(for: id)?.inflation == draft.inflation)
        // 収納・Undo再配置は新しいState。通常の画面離脱releaseとは区別する。
        session.stopInflation(except: [])
        #expect(session.snapshot(for: id) == nil && !session.requestInflation(for: id))
        let fresh = session.claim(id, owner: a, initial: initial, bounds: bounds)
        #expect(fresh.inflation == initial.inflation)
    }

    private func pixels(_ image: CGImage) -> [UInt8] {
        var result = [UInt8](repeating: 0, count: image.width * image.height * 4)
        result.withUnsafeMutableBytes {
            CGContext(data: $0.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8,
                bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                .draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return result
    }

    @Test func allFramesKeepCanvasAlphaAndSelectableSpinesAndVisibleLengthMatchesPuffer() throws {
        let side = AquariumFishSizing.displaySize(for: .porcupinefish, isFavorite: false)
        func visibleWidth(_ species: FishSpecies) throws -> CGFloat {
            let size = AquariumFishSizing.displaySize(for: species, isFavorite: false)
            let renderer = ImageRenderer(content: FishImageView(species: species).frame(width: size, height: size))
            renderer.scale = 4
            let image = try #require(renderer.uiImage?.cgImage), data = pixels(image)
            var low = image.width, high = -1
            for y in 0..<image.height { for x in 0..<image.width where data[(y * image.width + x) * 4 + 3] > 16 {
                low = min(low, x); high = max(high, x)
            } }
            return CGFloat(high - low + 1) / 4
        }
        let actual = try visibleWidth(.porcupinefish), reference = try visibleWidth(.pufferfish)
        #expect(abs(actual - reference) < 0.8)
        print("Porcupinefish: canvas \(side)pt, visible length \(actual)pt; tiger puffer \(reference)pt")
        for name in FishSpecies.porcupinefish.swimmingImageNames + Inflation.inflationImageNames {
            let sprite = FishImageView(species: .porcupinefish, runtimeImageName: name)
            let source = sprite.frame(width: 128, height: 128)
            let original = try #require(ImageRenderer(content: source).uiImage?.cgImage)
            let sourcePixels = pixels(original)
            for theme in AquariumBackgroundTheme.allCases {
                let corrected = try #require(ImageRenderer(content: source.modifier(
                    AquariumFishColorCorrection.correction(for: theme, species: .porcupinefish))).uiImage?.cgImage)
                #expect(corrected.width == original.width && corrected.height == original.height)
                let rendered = pixels(corrected)
                #expect(stride(from: 3, to: rendered.count, by: 4).allSatisfy { abs(Int(rendered[$0]) - Int(sourcePixels[$0])) <= 1 })
            }
            let path = AquariumFishHitTesting.path(image: sprite.interactionImage, canvasSize: side + 20, fishSize: side)
            #expect(!path.isEmpty)
            for size in [CGSize(width: 320, height: 568), CGSize(width: 393, height: 852), CGSize(width: 1024, height: 768)] {
                let bounds = AquariumFishMotion.movementProfile(for: .porcupinefish).roamingStyle.bounds(in: size, fishSize: side)
                // 全キャンバスの回転・揺れの余裕も既存の回遊境界に収まる。
                #expect(bounds.horizontal.lowerBound * size.width > side / 2 + 2)
                #expect(bounds.vertical.lowerBound * size.height > side / 2 + 2)
            }
        }
    }

    @Test func renderNormalAndInflatedOnThreeActualBackgrounds() throws {
        let side = AquariumFishSizing.displaySize(for: .porcupinefish, isFavorite: false)
        for theme in AquariumBackgroundTheme.allCases {
            let renderer = ImageRenderer(content: HStack(spacing: 0) {
                ForEach(["fish_porcupinefish_side_2", "fish_porcupinefish_inflate_10"], id: \.self) { name in
                    ZStack {
                        AquariumBackground(theme: theme)
                        ForEach([0.18, 0.5, 0.82], id: \.self) { y in
                            FishImageView(species: .porcupinefish, runtimeImageName: name)
                                .frame(width: side, height: side)
                                .modifier(AquariumFishColorCorrection.correction(for: theme, species: .porcupinefish))
                                .opacity(FishMovementProfile.lionfish.depthOpacity(at: 0.5))
                                .position(x: 196.5, y: 746 * y)
                        }
                    }.frame(width: 393, height: 746).clipped()
                }
            })
            renderer.scale = 2
            try #require(renderer.uiImage?.pngData()).write(to: URL(fileURLWithPath: "/private/tmp/Porcupinefish-\(theme.rawValue).png"))
        }
    }
}
