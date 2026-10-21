import CoreGraphics
import Foundation
import AVFoundation
import SwiftUI
import UIKit
import Testing
@testable import PomodoroAquarium

@MainActor
struct MandarinfishMotionTests {
    private func initial(_ index: Int, size: CGSize, spawn: CGPoint? = nil) -> AquariumFishMotion.State {
        let id = UUID(uuidString: String(format: "A4DAF15A-6A60-4A60-8A60-%012d", index))!
        let fishSize = AquariumFishSizing.displaySize(for: .mandarinfish, isFavorite: false)
        let profile = AquariumFishMotion.movementProfile(for: .mandarinfish)
        return AquariumFishMotion.initialState(for: id, profile: profile,
            roamingBounds: profile.roamingStyle.bounds(in: size, fishSize: fishSize), initialPosition: spawn,
            viewingSessionID: UUID(uuidString: "00000000-0000-4000-8000-000000000001"),
            aquariumSize: size, fishSize: fishSize)
    }

    @Test func unresolvedGeometryDoesNotChooseOrAdvanceTheFirstTargetAcrossOneHundredSeeds() throws {
        let size = CGSize(width: 393, height: 746), fishSize: CGFloat = 40.2
        let bounds = FishMovementProfile.mandarinfish.roamingStyle.bounds(in: size, fishSize: fishSize)
        var maximum: CGFloat = 0
        for seed in 1...100 {
            for invalidSize in [CGSize.zero, CGSize(width: 0, height: 746), CGSize(width: 393, height: 0)] {
                let origin = CGPoint(x: 0.5, y: 0.7)
                var action = AquariumMandarinfishMotion.State(seed: UInt64(seed), position: origin,
                    facingRight: true, bounds: bounds, aquariumSize: invalidSize, fishSize: fishSize, startNearBottom: false)
                #expect(!action.isGeometryReady && action.target == origin && action.start == origin)
                action.advance(deltaTime: 100)
                #expect(action.position == origin && action.elapsed == 0 && action.randomState == UInt64(seed))
                action.updateGeometry(bounds: bounds, size: size, fishSize: fishSize)
                let direct = AquariumMandarinfishMotion.State(seed: UInt64(seed), position: origin,
                    facingRight: true, bounds: bounds, aquariumSize: size, fishSize: fishSize, startNearBottom: false)
                #expect(String(reflecting: action) == String(reflecting: direct))
                let distance = hypot((action.target.x - origin.x) * size.width, (action.target.y - origin.y) * size.height)
                maximum = max(maximum, distance)
                #expect(distance <= fishSize * AquariumMandarinfishMotion.visibleLengthRatio
                    * AquariumMandarinfishMotion.correctionBodyLengths.upperBound + 0.000001)
                let ready = String(reflecting: action)
                action.updateGeometry(bounds: bounds, size: .zero)
                #expect(String(reflecting: action) == ready)
            }
        }
        try JSONSerialization.data(withJSONObject: ["seeds": 100, "maximumFirstHoverPoints": maximum])
            .write(to: URL(fileURLWithPath: "/private/tmp/MandarinFirstHoverMeasurements.json"))
    }

    @Test func firstGeometryResolutionSynchronizesThePublicMotionBeforeItsFirstTick() throws {
        var state = initial(1, size: .zero)
        let before = state.position
        let size = CGSize(width: 393, height: 746)
        let fish = AquariumFishSizing.displaySize(for: .mandarinfish, isFavorite: false)
        state.updateRoamingBounds(state.movementProfile.roamingStyle.bounds(in: size, fishSize: fish))
        state.updateStationKeepingGeometry(size: size, fishSize: fish)
        let action = try #require(state.stationKeeping)
        #expect(action.isGeometryReady && action.position == before && state.position == before)
        #expect(state.localTarget == action.target && state.anchorPosition == action.start)
        #expect(state.randomState == action.randomState && state.behaviorTimeRemaining == action.timeRemaining)
    }

    @Test func thirtySecondsAlternateHoverAndShortSmoothMovesAcrossScreenSizes() throws {
        for size in [CGSize(width: 320, height: 568), CGSize(width: 393, height: 746), CGSize(width: 1024, height: 768)] {
            for index in 1...5 {
                var state = initial(index, size: size), replay = initial(index, size: size)
                var previous = try #require(state.stationKeeping)
                #expect(state.position.y >= 0.59 && state.position.y < 0.84)
                var hoverCount = 0, moveCount = 0
                let body = AquariumFishSizing.displaySize(for: .mandarinfish, isFavorite: false) * AquariumMandarinfishMotion.visibleLengthRatio
                for tick in 1...900 {
                    let before = state.position
                    state.advance(deltaTime: 1.0 / 30, elapsedTime: Double(tick) / 30)
                    replay.advance(deltaTime: 1.0 / 30, elapsedTime: Double(tick) / 30)
                    let current = try #require(state.stationKeeping)
                    #expect(state.position == replay.position)
                    #expect(String(reflecting: current) == String(reflecting: replay.stationKeeping!))
                    #expect(state.roamingBounds.horizontal.contains(state.position.x))
                    #expect(state.roamingBounds.vertical.contains(state.position.y))
                    #expect(abs(current.headDipDegrees) <= 5)
                    #expect(state.facingDirection == .right || state.facingDirection == .left)
                    #expect(state.facingWidth == 1) // PNG全体の伸縮をしない。
                    let displacement = hypot((state.position.x - before.x) * size.width,
                                             (state.position.y - before.y) * size.height)
                    #expect(displacement < body * 0.09)
                    if current.phase == previous.phase && current.phase == .hovering {
                        #expect(current.facingRight == previous.facingRight)
                    }
                    if current.phase != previous.phase {
                        let distance = hypot((current.target.x - current.start.x) * size.width,
                                             (current.target.y - current.start.y) * size.height)
                        if current.phase == .moving {
                            moveCount += 1
                            #expect((0.75...1.875).contains(current.duration))
                            #expect(distance >= body * 0.3 - 0.0001 && distance <= body * 0.8 + 0.0001)
                        } else {
                            hoverCount += 1
                            #expect((1...3).contains(current.duration))
                            #expect(distance <= body * 0.022 + 0.0001)
                        }
                    }
                    previous = current
                }
                #expect(moveCount >= 6 && hoverCount >= 6)
                print("Mandarin \(size), ID \(index): \(moveCount) short moves / \(hoverCount) holds in 30s")
            }
        }
    }

    @Test func centralAppearanceIsNeverOverwrittenAndDescendsInSmallContinuousSteps() throws {
        let size = CGSize(width: 393, height: 746)
        let spawn = CGPoint(x: 0.5 + 45 / size.width, y: 0.5 - 15 / size.height)
        var state = initial(1, size: size, spawn: spawn)
        #expect(state.position == spawn && state.stationKeeping?.position == spawn)
        let firstFacing = state.facingDirection
        for tick in 1...20 {
            state.advance(deltaTime: 1.0 / 30, elapsedTime: Double(tick) / 30)
            #expect(hypot((state.position.x - spawn.x) * size.width,
                          (state.position.y - spawn.y) * size.height) < 1)
            #expect(state.facingDirection == firstFacing)
        }
        for tick in 21...900 { state.advance(deltaTime: 1.0 / 30, elapsedTime: Double(tick) / 30) }
        #expect(state.position.y > spawn.y)
        #expect(state.position.y < 0.86)
    }

    @Test func independentHoldsTargetsAndSessionOwnershipPreserveTheWholeAction() throws {
        let size = CGSize(width: 393, height: 746)
        let states = (1...5).map { initial($0, size: size) }
        #expect(Set(states.map { $0.stationKeeping!.duration }).count == 5)
        #expect(Set(states.map { "\($0.stationKeeping!.target)" }).count == 5)
        let session = AquariumFishViewingSession(), id = UUID(), old = UUID(), next = UUID()
        var state = states[0]
        for tick in 1...120 { state.advance(deltaTime: 1.0 / 30, elapsedTime: Double(tick) / 30) }
        let snapshot = AquariumFishViewingSession.Snapshot(motion: state,
            direction: .init(direction: state.facingDirection), elapsedTime: 4)
        _ = session.claim(id, owner: old, initial: snapshot, bounds: state.roamingBounds)
        session.release(id, owner: old)
        let resumed = session.claim(id, owner: next, initial: .init(motion: states[1], direction: .init(direction: .left)), bounds: state.roamingBounds)
        #expect(String(reflecting: resumed.motion.stationKeeping) == String(reflecting: state.stationKeeping))
        #expect(resumed.elapsedTime == 4)
        #expect(!session.update(id, owner: old, snapshot: snapshot))
        session.beginEditing()
        let edit = try #require(session.editingSession)
        var edited = edit.claim(id, owner: old, initial: snapshot, bounds: state.roamingBounds)
        edited.motion.advance(deltaTime: 1.0 / 30, elapsedTime: 4.033)
        _ = edit.update(id, owner: old, snapshot: edited)
        session.finishEditing()
        #expect(String(reflecting: session.snapshot(for: id)?.motion.stationKeeping) == String(reflecting: state.stationKeeping))
    }

    @Test func viewportChangeRetainsPhaseTimeAndNormalizedPosition() throws {
        var state = initial(1, size: CGSize(width: 393, height: 746))
        for tick in 1...65 { state.advance(deltaTime: 1.0 / 30, elapsedTime: Double(tick) / 30) }
        let before = try #require(state.stationKeeping)
        let size = CGSize(width: 320, height: 568)
        let fish = AquariumFishSizing.displaySize(for: .mandarinfish, isFavorite: false)
        state.updateRoamingBounds(state.movementProfile.roamingStyle.bounds(in: size, fishSize: fish))
        state.updateStationKeepingGeometry(size: size, fishSize: fish)
        let after = try #require(state.stationKeeping)
        #expect(before.phase == after.phase && before.elapsed == after.elapsed && before.duration == after.duration)
        #expect(before.position == after.position && before.randomState == after.randomState)
        #expect(after.aquariumSize == size)
    }
    @Test func changingBoundsDoesNotJumpToARecomputedCurve() throws {
        let size = CGSize(width: 393, height: 746)
        var state = initial(1, size: size)
        for tick in 1...3000 {
            state.advance(deltaTime: 1.0 / 300, elapsedTime: Double(tick) / 300)
            if let action = state.stationKeeping, action.phase == .moving,
               action.elapsed > action.duration * 0.4 { break }
        }
        let before = try #require(state.stationKeeping)
        #expect(before.phase == .moving)
        let middle = (before.target.x + before.position.x) / 2
        let horizontal = before.target.x > before.position.x
            ? state.roamingBounds.horizontal.lowerBound...middle
            : middle...state.roamingBounds.horizontal.upperBound
        let bounds = FishRoamingBounds(horizontal: horizontal, vertical: state.roamingBounds.vertical,
            horizontalWallMargin: 0.07, verticalWallMargin: 0.06)
        state.updateRoamingBounds(bounds)
        #expect(state.position == before.position)
        #expect(state.stationKeeping?.elapsed == before.elapsed)
        state.advance(deltaTime: 1.0 / 300, elapsedTime: 10)
        #expect(hypot((state.position.x - before.position.x) * size.width,
                      (state.position.y - before.position.y) * size.height) < 0.5)
    }

    /// 本番のState、連番、サイズ、背景補正を使う25秒のプレビュー。背景だけ静止。
    @Test func exportTwentyFiveSecondBehaviorPreview() async throws {
        let size = CGSize(width: 394, height: 746)
        let path = URL(fileURLWithPath: "/private/tmp/Mandarinfish-station-keeping-25s.mp4")
        if FileManager.default.fileExists(atPath: path.path) { try FileManager.default.removeItem(at: path) }
        let writer = try AVAssetWriter(outputURL: path, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 788, AVVideoHeightKey: 1492,
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 3_000_000]
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input,
            sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: 788, kCVPixelBufferHeightKey as String: 1492])
        writer.add(input)
        #expect(writer.startWriting())
        writer.startSession(atSourceTime: .zero)
        let background = try #require(ImageRenderer(content: AquariumBackground(theme: .tropical)
            .frame(width: size.width, height: size.height)).uiImage?.cgImage)
        var states = (1...3).map { initial($0, size: size) }
        let fishSize = AquariumFishSizing.displaySize(for: .mandarinfish, isFavorite: false)
        let sprites: [[CGImage]] = try states.map { state in
            try (0..<5).map { index in
                let renderer = ImageRenderer(content: FishImageView(species: .mandarinfish, fixedAnimationFrameIndex: index)
                    .frame(width: fishSize, height: fishSize)
                    .modifier(AquariumFishColorCorrection.correction(for: .tropical, species: .mandarinfish))
                    .opacity(state.depthOpacity))
                renderer.scale = 4
                return try #require(renderer.uiImage?.cgImage)
            }
        }
        var samples: [CGImage] = []
        for frame in 0..<500 {
            for _ in 0..<1000 {
                if input.isReadyForMoreMediaData { break }
                try await Task.sleep(for: .milliseconds(5))
            }
            try #require(input.isReadyForMoreMediaData)
            var optionalBuffer: CVPixelBuffer?
            let result = CVPixelBufferCreate(kCFAllocatorDefault, 788, 1492, kCVPixelFormatType_32BGRA,
                [kCVPixelBufferCGImageCompatibilityKey: true, kCVPixelBufferCGBitmapContextCompatibilityKey: true] as CFDictionary,
                &optionalBuffer)
            #expect(result == kCVReturnSuccess)
            let buffer = try #require(optionalBuffer)
            CVPixelBufferLockBaseAddress(buffer, [])
            let context = try #require(CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: 788, height: 1492,
                bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue))
            context.scaleBy(x: 2, y: 2) // Retina相当。水槽座標と魚のpt寸法は本番のまま。
            context.draw(background, in: CGRect(origin: .zero, size: size))
            let time = Double(frame) / 20
            for index in states.indices {
                let state = states[index], action = try #require(state.stationKeeping)
                let id = UUID(uuidString: String(format: "A4DAF15A-6A60-4A60-8A60-%012d", index + 1))!
                let spriteIndex = FishSpriteAnimation.pingPongFrameIndex(frameCount: 5, elapsedTime: time,
                    frameDuration: 0.20 * AquariumFishMotion.spriteTempoMultiplier(for: id),
                    phase: AquariumFishMotion.spriteAnimationPhase(for: id))
                context.saveGState()
                context.translateBy(x: state.position.x * size.width, y: size.height * (1 - state.position.y))
                context.rotate(by: -action.headDipDegrees * (action.facingRight ? 1 : -1) * .pi / 180)
                context.scaleBy(x: action.facingRight ? 1 : -1, y: 1)
                context.draw(sprites[index][spriteIndex], in: CGRect(x: -fishSize / 2, y: -fishSize / 2,
                    width: fishSize, height: fishSize))
                context.restoreGState()
            }
            context.saveGState()
            context.translateBy(x: 0, y: size.height)
            context.scaleBy(x: 1, y: -1)
            UIGraphicsPushContext(context)
            (String(format: "Mandarinfish / %.2fs", time) as NSString).draw(at: CGPoint(x: 12, y: 20),
                withAttributes: [.font: UIFont.monospacedSystemFont(ofSize: 14, weight: .medium), .foregroundColor: UIColor.black])
            for index in states.indices {
                let state = states[index], action = state.stationKeeping!
                let label = "#\(index + 1) \(action.phase == .hovering ? "HOLD" : "MOVE")"
                (label as NSString).draw(at: CGPoint(x: state.position.x * size.width - 20,
                    y: state.position.y * size.height + fishSize / 2),
                    withAttributes: [.font: UIFont.monospacedSystemFont(ofSize: 9, weight: .medium), .foregroundColor: UIColor.black])
            }
            UIGraphicsPopContext()
            context.restoreGState()
            if [0, 20, 40, 80, 160, 240, 320, 400, 480].contains(frame) {
                samples.append(try #require(context.makeImage()))
            }
            CVPixelBufferUnlockBaseAddress(buffer, [])
            #expect(adaptor.append(buffer, withPresentationTime: CMTime(value: Int64(frame), timescale: 20)))
            for index in states.indices { states[index].advance(deltaTime: 1.0 / 20, elapsedTime: time + 1.0 / 20) }
        }
        input.markAsFinished()
        await writer.finishWriting()
        #expect(writer.status == .completed)
        #expect(states.allSatisfy { ($0.stationKeeping?.completedMoves ?? 0) >= 5 })
        let renderer = ImageRenderer(content: VStack(spacing: 4) {
            ForEach(0..<3) { row in
                HStack(spacing: 4) {
                    ForEach(0..<3) { column in
                        Image(decorative: samples[row * 3 + column], scale: 1)
                            .resizable().scaledToFit().frame(width: 197, height: 373)
                    }
                }
            }
        })
        renderer.scale = 2
        try #require(renderer.uiImage?.pngData()).write(to: URL(fileURLWithPath: "/private/tmp/Mandarinfish-25s-frames.png"))
    }

}
