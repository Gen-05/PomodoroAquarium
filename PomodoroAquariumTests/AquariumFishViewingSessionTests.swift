import SwiftUI
import UIKit
import Combine
import CoreGraphics
import Foundation
import Testing
import ImageIO
import UniformTypeIdentifiers
@testable import PomodoroAquarium

@MainActor
struct AquariumFishViewingSessionTests {
    private let firstSession = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!
    private let nextSession = UUID(uuidString: "00000000-0000-4000-8000-000000000002")!

    @Test func newAppLaunchChangesPositionsForEverySpeciesWithinTheirRoamingBounds() {
        for species in FishSpecies.allCases {
            let profile = AquariumFishMotion.movementProfile(for: species)
            for size in [CGSize(width: 320, height: 568), CGSize(width: 393, height: 852),
                         CGSize(width: 1024, height: 768)] {
                let bounds = profile.roamingStyle.bounds(in: size,
                    fishSize: AquariumFishSizing.displaySize(for: species, isFavorite: false))
                let prefix = species == .manta ? "B10F17A0" : species == .dolphin ? "D01F1150" : species == .seaTurtle ? "7A271E50" : species == .mandarinfish ? "A4DAF15A" : species == .porcupinefish ? "B0C0F15A" : species == .lionfish ? "110F15A0" : species == .pennantCoralfish ? "F1A77A7E" : species == .orientalButterflyfish ? "B077E2F1" : species == .blueGreenChromis ? "C470A115" : species == .yellowTang ? "E1107A60" : "B10E7A60"
                let ids = (1...5).map {
                    UUID(uuidString: String(format: "\(prefix)-6A60-4A60-8A60-%012d", $0))!
                }
                var positions: [CGPoint] = []
                for id in ids {
                    let first = AquariumFishMotion.initialState(for: id, profile: profile,
                        roamingBounds: bounds, viewingSessionID: firstSession)
                    let repeated = AquariumFishMotion.initialState(for: id, profile: profile,
                        roamingBounds: bounds, viewingSessionID: firstSession)
                    let reopened = AquariumFishMotion.initialState(for: id, profile: profile,
                        roamingBounds: bounds, viewingSessionID: nextSession)
                    #expect(first.position == repeated.position)
                    #expect(first.position != reopened.position)
                    #expect(first.anchorPosition == first.position)
                    #expect(reopened.anchorPosition == reopened.position)
                    for state in [first, reopened] {
                        #expect(bounds.horizontal.contains(state.position.x))
                        #expect(bounds.vertical.contains(state.position.y))
                    }
                    // 今回変えるのは開始位置。既存の個体差・速度・泳ぎの特性は維持する。
                    #expect(first.velocity == reopened.velocity)
                    #expect(first.baseSpeed == reopened.baseSpeed)
                    #expect(first.randomState == reopened.randomState)
                    positions.append(first.position)
                }
                #expect(Set(positions.map { "\($0.x),\($0.y)" }).count == 5)
            }
        }
    }

    @Test func explicitCentralSpawnOverridesTheViewingSessionForEverySpecies() {
        let id = UUID(uuidString: "B10E7A60-6A60-4A60-8A60-000000000001")!
        let spawn = CGPoint(x: 0.49, y: 0.52)
        for species in FishSpecies.allCases {
            let profile = AquariumFishMotion.movementProfile(for: species)
            for session in [firstSession, nextSession] {
                let state = AquariumFishMotion.initialState(for: id, profile: profile,
                    initialPosition: spawn, viewingSessionID: session)
                #expect(state.position == spawn)
                #expect(state.anchorPosition == spawn)
            }
        }
    }
    private let fishID = UUID(uuidString: "B10E7A60-6A60-4A60-8A60-000000000001")!

    private func initial(_ session: AquariumFishViewingSession, fishID: UUID? = nil,
                         spawn: CGPoint? = nil) -> AquariumFishViewingSession.Snapshot {
        let id = fishID ?? self.fishID
        let motion = AquariumFishMotion.initialState(for: id, initialPosition: spawn, viewingSessionID: session.id)
        return .init(motion: motion, direction: FishSpriteDirectionTransition(direction: motion.facingDirection),
                     wing: AquariumFishMotion.WingCycle(id: id, profile: .manta))
    }

    @Test func screenHandoffPreservesTheEntireSwimAndRejectsStaleWriters() {
        let session = AquariumFishViewingSession(id: firstSession)
        let home = UUID(), timer = UUID()
        var swimming = session.claim(fishID, owner: home, initial: initial(session), bounds: .legacy)
        for frame in 1...90 {
            swimming.elapsedTime += 1.0 / 30
            swimming.motion.advance(deltaTime: 1.0 / 30, elapsedTime: Double(frame) / 30)
            swimming.direction.update(toward: swimming.motion.facingDirection, deltaTime: 1.0 / 30)
            swimming.wing?.advance(deltaTime: 1.0 / 30, frameCount: 7, frameDuration: 0.36, profile: .manta)
        }
        #expect(session.update(fishID, owner: home, snapshot: swimming))
        let transferred = session.claim(fishID, owner: timer, initial: initial(session), bounds: .legacy)
        #expect(String(reflecting: transferred) == String(reflecting: swimming))
        #expect(!session.isOwner(fishID, owner: home))
        #expect(!session.update(fishID, owner: home, snapshot: initial(session)))
        session.release(fishID, owner: home)
        #expect(session.isOwner(fishID, owner: timer))
        #expect(String(reflecting: session.snapshot(for: fishID)) == String(reflecting: Optional(swimming)))
        // 再描画で初期値を作っても、保存済みの泳ぎを置き換えない。
        let repeated = session.claim(fishID, owner: timer, initial: initial(session), bounds: .legacy)
        #expect(String(reflecting: repeated) == String(reflecting: swimming))
    }

    @Test func backgroundResumeAndHiddenScreensDoNotAccumulateTime() {
        let session = AquariumFishViewingSession(id: firstSession)
        let owner = UUID()
        let before = session.claim(fishID, owner: owner, initial: initial(session), bounds: .legacy)
        var timing = AquariumSimulationTiming()
        let start = Date(timeIntervalSince1970: 100)
        #expect(timing.nextDeltaTime(at: start, isPaused: false) == nil)
        timing.pause()
        session.release(fishID, owner: owner)
        #expect(!session.update(fishID, owner: owner, snapshot: initial(session, spawn: .zero)))
        let resumed = session.claim(fishID, owner: owner, initial: initial(session), bounds: .legacy)
        #expect(String(reflecting: before) == String(reflecting: resumed))
        #expect(timing.nextDeltaTime(at: start.addingTimeInterval(3600), isPaused: false) == nil)
        let delta = timing.nextDeltaTime(at: start.addingTimeInterval(3600 + 1.0 / 30), isPaused: false)
        #expect(abs((delta ?? 0) - 1.0 / 30) < 0.000001)
    }

    @Test func editingAdditionStorageUndoAndCancelNeverChangeOfficialSwimming() throws {
        let session = AquariumFishViewingSession(id: firstSession)
        let owner = UUID()
        var official = session.claim(fishID, owner: owner, initial: initial(session), bounds: .legacy)
        official.elapsedTime = 4
        official.motion.position = CGPoint(x: 0.3, y: 0.4)
        #expect(session.update(fishID, owner: owner, snapshot: official))
        session.beginEditing()
        let editing = try #require(session.editingSession)
        let editor = UUID()
        let sameFish = editing.claim(fishID, owner: editor, initial: initial(editing), bounds: .legacy)
        #expect(String(reflecting: sameFish) == String(reflecting: official))
        let addedID = UUID()
        let spawn = CGPoint(x: 0.49, y: 0.52)
        let added = editing.claim(addedID, owner: editor, initial: initial(editing, fishID: addedID, spawn: spawn), bounds: .legacy)
        #expect(added.motion.position == spawn)
        #expect(session.snapshot(for: addedID) == nil)
        #expect(String(reflecting: editing.snapshot(for: fishID)) == String(reflecting: Optional(official)))
        // 収納でViewを離れ、Undo/Redoで復帰しても作業側の状態から再開する。
        editing.release(addedID, owner: editor)
        let restored = editing.claim(addedID, owner: UUID(), initial: initial(editing, fishID: addedID), bounds: .legacy)
        #expect(String(reflecting: restored) == String(reflecting: added))
        session.finishEditing()
        #expect(session.editingSession == nil)
        #expect(session.snapshot(for: addedID) == nil)
        #expect(String(reflecting: session.snapshot(for: fishID)) == String(reflecting: Optional(official)))
        #expect(!editing.update(fishID, owner: editor, snapshot: initial(editing)))
    }

    @Test func savePromotesOnlyCommittedFishAndInvalidatesOldOwners() throws {
        let session = AquariumFishViewingSession(id: firstSession)
        let owner = UUID()
        _ = session.claim(fishID, owner: owner, initial: initial(session), bounds: .legacy)
        session.beginEditing()
        let editing = try #require(session.editingSession)
        // Draftからの復帰でも同じ作業コピーを使う。
        session.beginEditing()
        #expect(session.editingSession === editing)
        let editor = UUID()
        var updated = editing.claim(fishID, owner: editor, initial: initial(editing), bounds: .legacy)
        updated.motion.position = CGPoint(x: 0.6, y: 0.7)
        updated.elapsedTime = 12
        #expect(editing.update(fishID, owner: editor, snapshot: updated))
        session.finishEditing(commit: [fishID])
        #expect(String(reflecting: session.snapshot(for: fishID)) == String(reflecting: Optional(updated)))
        #expect(!session.update(fishID, owner: owner, snapshot: initial(session)))
        #expect(!editing.update(fishID, owner: editor, snapshot: initial(editing)))
    }

    @Test func differentCanvasClampsExistingPositionAndTargetsWithoutReinitializing() {
        let session = AquariumFishViewingSession(id: firstSession)
        let owner = UUID()
        var swimming = session.claim(fishID, owner: owner, initial: initial(session), bounds: .legacy)
        swimming.motion.position = CGPoint(x: 0.99, y: 0.99)
        swimming.motion.anchorPosition = swimming.motion.position
        swimming.motion.localTarget = swimming.motion.position
        swimming.motion.roamingDestination = swimming.motion.position
        swimming.elapsedTime = 8
        #expect(session.update(fishID, owner: owner, snapshot: swimming))
        let bounds = AquariumFishMotion.movementProfile(for: .blueTang).roamingStyle.bounds(
            in: CGSize(width: 320, height: 568), fishSize: 50)
        let adjusted = session.claim(fishID, owner: UUID(), initial: initial(session), bounds: bounds)
        #expect(adjusted.motion.position == AquariumFishMotion.clampedPoint(swimming.motion.position, bounds: bounds))
        #expect(adjusted.motion.localTarget == adjusted.motion.position)
        #expect(adjusted.motion.roamingDestination == adjusted.motion.position)
        #expect(adjusted.motion.velocity == swimming.motion.velocity)
        #expect(adjusted.motion.behaviorTimeRemaining == swimming.motion.behaviorTimeRemaining)
        #expect(adjusted.elapsedTime == 8)
    }

    @Test(arguments: [FishSpecies.blueTang, .blueGreenChromis, .orientalButterflyfish, .pennantCoralfish, .lionfish, .porcupinefish, .mandarinfish, .seaTurtle, .dolphin, .manta])
    func actualFishViewsResumeAcrossRemountBackgroundAndCentralAddition(species: FishSpecies) async throws {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = try #require(scenes.first { $0.activationState == .foregroundActive } ?? scenes.first)
        let session = AquariumFishViewingSession(id: firstSession)
        let probe = ViewingSessionRenderProbe(species: species)
        if species == .porcupinefish {
            let id = probe.ids[0], owner = UUID()
            let profile = AquariumFishMotion.movementProfile(for: species)
            let bounds = profile.roamingStyle.bounds(in: CGSize(width: 393, height: 852),
                fishSize: AquariumFishSizing.displaySize(for: species, isFavorite: false))
            let motion = AquariumFishMotion.initialState(for: id, profile: profile, roamingBounds: bounds)
            var inflation = AquariumPorcupinefishInflation.State(id: id)
            for _ in 0..<100 where inflation.swimmingFrameIndex != 1 { inflation.advance(deltaTime: 0.01) }
            inflation.request()
            inflation.advance(deltaTime: 1.3)
            _ = session.claim(id, owner: owner, initial: .init(motion: motion,
                direction: .init(direction: motion.facingDirection), inflation: inflation), bounds: bounds)
            session.release(id, owner: owner)
        }
        let host = UIHostingController(rootView: ViewingSessionRenderHost(session: session, probe: probe))
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        func settle() async throws {
            host.view.setNeedsLayout()
            host.view.layoutIfNeeded()
            try await Task.sleep(for: .milliseconds(30))
            host.view.layoutIfNeeded()
        }
        try await settle()
        for frame in 1...6 {
            probe.date = Date(timeIntervalSince1970: 100 + Double(frame) / 30)
            try await settle()
        }
        let before = try #require(session.snapshot(for: probe.ids[0]))
        #expect(before.elapsedTime > 0)
        if species == .porcupinefish { #expect(before.inflation?.phase == .holding) }
        if species == .dolphin { #expect(before.dolphin != nil) }
        // ホーム→水槽→タイマー相当のView作り直し。位置・行動・向き・位相を丸ごと引き継ぐ。
        for _ in 0..<3 {
            probe.screen += 1
            try await settle()
            let after = try #require(session.snapshot(for: probe.ids[0]))
            #expect(String(reflecting: after) == String(reflecting: before))
        }
        probe.phase = .background
        try await settle()
        probe.date = Date(timeIntervalSince1970: 3700)
        try await settle()
        probe.phase = .active
        try await settle()
        probe.date = Date(timeIntervalSince1970: 3700 + 1.0 / 30)
        try await settle()
        #expect(String(reflecting: session.snapshot(for: probe.ids[0])) == String(reflecting: Optional(before)))
        // 非表示からの復帰も、経過した実時間をまとめて泳がせない。
        probe.visible = false
        try await settle()
        probe.date = Date(timeIntervalSince1970: 7200)
        probe.visible = true
        try await settle()
        #expect(String(reflecting: session.snapshot(for: probe.ids[0])) == String(reflecting: Optional(before)))
        let otherBefore = try #require(session.snapshot(for: probe.ids[1]))
        // 同じ個体の再配置イベント。追加された魚だけ中央へ戻し、他個体は継続する。
        probe.appearance = AquariumFishAppearance(startedAt: probe.date, spawnOffset: CGPoint(x: 20, y: -15))
        try await settle()
        let added = try #require(session.snapshot(for: probe.ids[0]))
        if species == .porcupinefish { #expect(added.inflation?.phase == .swimming) }
        #expect(abs(added.motion.position.x - (0.5 + 20.0 / 393)) < 0.000001)
        #expect(abs(added.motion.position.y - (0.5 - 15.0 / 852)) < 0.000001)
        #expect(String(reflecting: session.snapshot(for: probe.ids[1])) == String(reflecting: Optional(otherBefore)))
        let fish = try #require(probe.fishFrame), ring = try #require(probe.ringFrame)
        #expect(hypot(fish.midX - ring.midX, fish.midY - ring.midY) < 0.001)
    }

    @Test func mandarinFirstGeometryAndBackgroundResumeUseTheSameRenderedAndSharedState() async throws {
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let session = AquariumFishViewingSession()
        let probe = ViewingSessionRenderProbe(species: .mandarinfish)
        probe.aquariumSize = .zero
        let host = UIHostingController(rootView: ViewingSessionRenderHost(session: session, probe: probe))
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        func settle() async throws {
            host.view.layoutIfNeeded()
            try await Task.sleep(for: .milliseconds(30))
            host.view.layoutIfNeeded()
        }
        try await settle()
        let unresolved = try #require(session.snapshot(for: probe.ids[0])?.motion.stationKeeping)
        #expect(!unresolved.isGeometryReady && unresolved.target == unresolved.position)
        probe.aquariumSize = CGSize(width: 393, height: 852)
        try await settle()
        let initial = try #require(session.snapshot(for: probe.ids[0]))
        let action = try #require(initial.motion.stationKeeping)
        #expect(action.isGeometryReady && action.position == initial.motion.position && action.elapsed == 0)
        let frame = try #require(probe.fishFrame)
        // 内部座標は上で完全一致、Geometryは各軸の半ピクセル丸めだけを許容する。
        let pixelTolerance = sqrt(2) / (2 * max(host.traitCollection.displayScale, 1))
        #expect(hypot(frame.midX - initial.motion.position.x * 393, frame.midY - initial.motion.position.y * 852) <= pixelTolerance)
        for tick in 1...30 {
            probe.date = Date(timeIntervalSince1970: 100 + Double(tick) / 30)
            try await settle()
            let current = try #require(session.snapshot(for: probe.ids[0]))
            let distance = hypot((current.motion.position.x - initial.motion.position.x) * 393,
                (current.motion.position.y - initial.motion.position.y) * 852)
            #expect(distance < 1)
            #expect(current.motion.position == current.motion.stationKeeping?.position)
        }
        let beforeBackground = try #require(session.snapshot(for: probe.ids[0]))
        probe.phase = .background
        try await settle()
        probe.aquariumSize = .zero
        probe.date = Date(timeIntervalSince1970: 3700)
        try await settle()
        probe.phase = .active
        try await settle()
        probe.aquariumSize = CGSize(width: 393, height: 852)
        try await settle()
        probe.date = Date(timeIntervalSince1970: 3700 + 1.0 / 30)
        try await settle()
        #expect(String(reflecting: session.snapshot(for: probe.ids[0])) == String(reflecting: Optional(beforeBackground)))
        probe.screen += 1
        try await settle()
        #expect(String(reflecting: session.snapshot(for: probe.ids[0])) == String(reflecting: Optional(beforeBackground)))
        session.beginEditing()
        let edit = try #require(session.editingSession)
        let owner = UUID()
        var edited = edit.claim(probe.ids[0], owner: owner, initial: initial, bounds: initial.motion.roamingBounds)
        edited.motion.advance(deltaTime: 1.0 / 30, elapsedTime: 1.1)
        #expect(edit.update(probe.ids[0], owner: owner, snapshot: edited))
        session.finishEditing(commit: [probe.ids[0]])
        probe.screen += 1
        try await settle()
        #expect(String(reflecting: session.snapshot(for: probe.ids[0])) == String(reflecting: Optional(edited)))
    }

    @Test func tunaRendersContinuousUndistortedTurnsInBothDirections() async throws {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = try #require(scenes.first { $0.activationState == .foregroundActive } ?? scenes.first)
        let session = AquariumFishViewingSession()
        let probe = ViewingSessionRenderProbe(species: .manta)
        let size = CGSize(width: 393, height: 852)
        let bounds = FishMovementProfile.bluefinTuna.roamingStyle.bounds(in: size,
            fishSize: AquariumFishSizing.displaySize(for: .manta, isFavorite: false))
        var motion = AquariumFishMotion.initialState(for: probe.ids[0], profile: .bluefinTuna,
            roamingBounds: bounds, initialPosition: CGPoint(x: 0.5, y: 0.5), aquariumSize: size)
        motion.currentDepth = 0.5; motion.targetDepth = 0.5
        let owner = UUID()
        _ = session.claim(probe.ids[0], owner: owner,
            initial: .init(motion: motion, direction: .init(direction: motion.facingDirection)), bounds: bounds)
        session.release(probe.ids[0], owner: owner)
        let host = UIHostingController(rootView: ViewingSessionRenderHost(session: session, probe: probe, preview: true))
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: size)
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        func settle() async throws {
            host.view.layoutIfNeeded()
            try await Task.sleep(for: .milliseconds(20))
            host.view.layoutIfNeeded()
        }
        try await settle()
        let url = URL(fileURLWithPath: "/private/tmp/TunaRigidTurnsActualView.gif")
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, 200, nil))
        CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary:
            [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        var directions: Set<Int> = []
        var records: [[String: Any]] = []
        var contact: [UIImage] = []
        var priorSign = motion.facingSign
        var stoppedTime = 0.0, maximumStoppedTime = 0.0
        for tick in 1...400 {
            probe.date = Date(timeIntervalSince1970: 100 + Double(tick) / 20)
            try await settle()
            let actual = try #require(session.snapshot(for: probe.ids[0]))
            let state = actual.motion
            #expect(abs(state.facingHorizontalScale) == 1 && state.facingWidth == 1)
            #expect(bounds.horizontal.contains(state.position.x) && bounds.vertical.contains(state.position.y))
            if state.facingSign != priorSign {
                directions.insert(state.facingSign < 0 ? 1 : -1)
                #expect(abs(state.translationVelocity.dx * state.depthSpeedMultiplier * size.width) < 0.00001)
                priorSign = state.facingSign
            }
            let xSpeed = state.translationVelocity.dx * state.depthSpeedMultiplier * size.width
            if abs(xSpeed) < 0.00001 { stoppedTime += 0.05 } else { stoppedTime = 0 }
            maximumStoppedTime = max(maximumStoppedTime, stoppedTime)
            #expect(maximumStoppedTime <= 0.15)
            if abs(xSpeed) > 0.00001 { #expect(xSpeed * state.facingHorizontalScale > 0) }
            records.append(["time": actual.elapsedTime, "x": state.position.x * size.width,
                "y": state.position.y * size.height, "xSpeed": xSpeed,
                "phase": state.bluefinCruise?.turnPhase.map { String(describing: $0) } ?? "straight",
                "horizontalScale": state.facingHorizontalScale])
            if tick.isMultiple(of: 2) {
                let image = renderer.image { _ in
                    host.view.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
                }
                CGImageDestinationAddImage(destination, try #require(image.cgImage),
                    [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 0.1]] as CFDictionary)
                if tick.isMultiple(of: 20), contact.count < 10 { contact.append(image) }
            }
        }
        #expect(directions == [-1, 1])
        #expect(CGImageDestinationFinalize(destination))
        try JSONSerialization.data(withJSONObject: records, options: .prettyPrinted)
            .write(to: URL(fileURLWithPath: "/private/tmp/TunaRigidTurnsActualView.json"))
        let comparison = ImageRenderer(content: VStack(spacing: 4) {
            ForEach(0..<2) { row in
                HStack(spacing: 4) {
                    ForEach(0..<5) { column in
                        VStack {
                            Text("\(row * 5 + column + 1)s")
                            Image(uiImage: contact[row * 5 + column]).resizable().frame(width: 196.5, height: 426)
                        }
                    }
                }
            }
        }.padding().background(.white))
        comparison.scale = 1
        try #require(comparison.uiImage?.pngData()).write(to: URL(fileURLWithPath: "/private/tmp/TunaRigidTurnsActualView.png"))
    }

    @Test func porcupinefishReceivesOverlayTapsWithoutRestartingInflation() async throws {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = try #require(scenes.first { $0.activationState == .foregroundActive } ?? scenes.first)
        let session = AquariumFishViewingSession()
        let probe = ViewingSessionRenderProbe(species: .porcupinefish)
        let host = UIHostingController(rootView: ViewingSessionRenderHost(session: session, probe: probe))
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        func settle() async throws {
            host.view.layoutIfNeeded()
            try await Task.sleep(for: .milliseconds(35))
            host.view.layoutIfNeeded()
        }
        try await settle()
        let id = probe.ids[0]
        let before = try #require(session.snapshot(for: id))
        probe.tapRequest = .init(point: CGPoint(x: before.motion.position.x * 393,
            y: before.motion.position.y * 852), aquariumSize: CGSize(width: 393, height: 852))
        try await settle()
        #expect(session.handledViewingTapToken == probe.tapRequest?.token)
        for frame in 1...30 {
            probe.date = Date(timeIntervalSince1970: 100 + Double(frame) / 30)
            try await settle()
        }
        let active = try #require(session.snapshot(for: id)?.inflation)
        #expect(active.phase == .inflating)
        // 同じ時刻で再タップ。開始時刻・残り時間を更新しない。
        let position = try #require(session.snapshot(for: id)?.motion.position)
        probe.tapRequest = .init(point: CGPoint(x: position.x * 393, y: position.y * 852),
            aquariumSize: CGSize(width: 393, height: 852))
        try await settle()
        #expect(session.snapshot(for: id)?.inflation == active)
        #expect(!session.requestInflation(for: id))
        probe.tapRequest = .init(point: .zero, aquariumSize: CGSize(width: 393, height: 852))
        try await settle()
        #expect(session.handledViewingTapToken != probe.tapRequest?.token)
    }

}


@MainActor
private final class ViewingSessionRenderProbe: ObservableObject {
    let species: FishSpecies
    init(species: FishSpecies) { self.species = species }
    var ids: [UUID] { [UUID(uuidString: species == .manta
        ? "B10F17A0-6A60-4A60-8A60-000000000001" : species == .dolphin
        ? "D01F1150-6A60-4A60-8A60-000000000001" : species == .seaTurtle
        ? "7A271E50-6A60-4A60-8A60-000000000001" : species == .mandarinfish
        ? "A4DAF15A-6A60-4A60-8A60-000000000001" : species == .porcupinefish
        ? "B0C0F15A-6A60-4A60-8A60-000000000001" : species == .lionfish
        ? "110F15A0-6A60-4A60-8A60-000000000001" : species == .pennantCoralfish
        ? "F1A77A7E-6A60-4A60-8A60-000000000001" : species == .orientalButterflyfish
        ? "B077E2F1-6A60-4A60-8A60-000000000001" : species == .blueGreenChromis
        ? "C470A115-6A60-4A60-8A60-000000000001" : "B10E7A60-6A60-4A60-8A60-000000000001")!,
               UUID(uuidString: "E1107A60-6A60-4A60-8A60-000000000002")!] }
    @Published var aquariumSize = CGSize(width: 393, height: 852)
    @Published var screen = 0
    @Published var visible = true
    @Published var phase = ScenePhase.active
    @Published var date = Date(timeIntervalSince1970: 100)
    @Published var appearance: AquariumFishAppearance?
    @Published var tapRequest: AquariumTreasureChestTapLocation?
    var fishFrame: CGRect?
    var ringFrame: CGRect?
}

private struct ViewingSessionRenderHost: View {
    let session: AquariumFishViewingSession
    @ObservedObject var probe: ViewingSessionRenderProbe
    var preview = false

    var body: some View {
        ZStack {
            if preview { AquariumBackground(theme: .aquarium) }
            if probe.visible {
                ForEach(preview ? Array(probe.ids.prefix(1)) : probe.ids, id: \.self) { id in fish(id: id) }
                    .id(probe.screen)
            }
        }
        .frame(width: 393, height: 852)
        .ignoresSafeArea()
        .environment(\.scenePhase, probe.phase)
    }

    private func fish(id: UUID) -> some View {
        var view = SwimmingFishView(fishID: id, viewingSession: session,
            appearance: id == probe.ids[0] ? probe.appearance : nil,
            viewingTapRequest: probe.tapRequest,
            species: id == probe.ids[0] ? probe.species : .yellowTang,
            backgroundTheme: .aquarium, isFavorite: false, aquariumSize: probe.aquariumSize,
            updateDate: probe.date, isSimulationPaused: false, isSelectionEnabled: false,
            isSelected: false, neighborPositions: .empty, reportPosition: { _ in }, select: {})
        if id == probe.ids[0] {
            view.onRenderedFrames = { ring, frame in
                if ring { probe.ringFrame = frame } else { probe.fishFrame = frame }
            }
        }
        return view
    }
}
