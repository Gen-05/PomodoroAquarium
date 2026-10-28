import SwiftUI
import UIKit
import Combine
import Testing
@testable import PomodoroAquarium

@MainActor
struct AquariumFishWorldTests {
    private let size = CGSize(width: 393, height: 852)
    private let id = UUID(uuidString: "B10E7A60-6A60-4A60-8A60-000000000001")!
    private let dt = 1.0 / 30

    private func initial(_ species: FishSpecies, position: CGPoint) -> AquariumFishMotion.State {
        let profile = AquariumFishMotion.movementProfile(for: species)
        return AquariumFishMotion.initialState(for: id, profile: profile,
            roamingBounds: profile.roamingStyle.bounds(in: size,
                fishSize: AquariumFishSizing.displaySize(for: species, isFavorite: false)),
            initialPosition: position, aquariumSize: size, fishSize: AquariumFishSizing.referenceSize(for: species))
    }

    @Test func expandedBoundsKeepVerticalLayersPositionsAndPointSpeeds() {
        #expect(AquariumFishWorld.horizontalRange == -0.5...1.5)
        for species in FishSpecies.allCases {
            let profile = AquariumFishMotion.movementProfile(for: species)
            for canvas in [size, CGSize(width: 1024, height: 768)] {
                let fishSize = AquariumFishSizing.displaySize(for: species, isFavorite: false)
                let viewport = profile.roamingStyle.visibleBounds(in: canvas, fishSize: fishSize)
                let world = profile.roamingStyle.bounds(in: canvas, fishSize: fishSize)
                #expect(world.horizontal == -0.5...1.5)
                #expect(world.vertical == viewport.vertical)
                var state = AquariumFishMotion.initialState(for: id, profile: profile, roamingBounds: viewport,
                    initialPosition: CGPoint(x: 0.5, y: 0.5), aquariumSize: canvas, fishSize: fishSize)
                let before = state
                state.updateRoamingBounds(world)
                #expect(state.position == before.position)
                #expect(state.velocity == before.velocity && state.currentDepth == before.currentDepth)
                #expect(state.behaviorTimeRemaining == before.behaviorTimeRemaining)
                // 壁の影響がない同じ座標で1 tick進め、幅を2倍にした速度換算がないことを確認。
                let open = FishRoamingBounds(horizontal: -10...10, vertical: world.vertical,
                    horizontalWallMargin: world.horizontalWallMargin, verticalWallMargin: world.verticalWallMargin)
                var reference = state
                reference.updateRoamingBounds(open)
                state.advance(deltaTime: dt, elapsedTime: dt)
                reference.advance(deltaTime: dt, elapsedTime: dt)
                #expect(abs(state.position.x - reference.position.x) * canvas.width < 0.000001)
            }
        }
    }

    @Test func ordinaryMotionCrossesTheViewportAndReturnsWithoutACustomTrip() {
        for species in [FishSpecies.clownfish, .seaTurtle, .dolphin, .manta, .whaleShark, .orca] {
            var state = initial(species, position: CGPoint(x: 1.35, y: 0.5))
            var dolphin: AquariumDolphinSwimming.State? = species == .dolphin ? .init(id: id) : nil
            var orca: AquariumOrcaSwimming.State? = species == .orca ? .init(id: id) : nil
            var movedOutside = false, returned = false, safe = true
            for tick in 1...18_000 {
                let before = state.position
                dolphin?.advance(deltaTime: dt)
                orca?.advance(deltaTime: dt)
                let multiplier = dolphin?.speedMultiplier ?? orca?.speedMultiplier
                    ?? (species == .seaTurtle ? AquariumFishMotion.seaTurtlePropulsionMultiplier(
                        elapsedTime: Double(tick) * dt, frameDuration: 0.22,
                        phase: AquariumFishMotion.spriteAnimationPhase(for: id)) : 1)
                state.advance(deltaTime: dt, elapsedTime: Double(tick) * dt, speedMultiplier: multiplier,
                    behaviorTargetSpeedMultiplier: AquariumFishMotion.behaviorTargetSpeedMultiplier(for: species, behavior: state.behavior))
                safe = safe && state.roamingBounds.horizontal.contains(state.position.x)
                    && state.roamingBounds.vertical.contains(state.position.y)
                    && abs(state.position.x - before.x) < 0.06
                if before.x > 1 && before != state.position { movedOutside = true }
                if state.position.x <= 1 { returned = true; break }
            }
            #expect(movedOutside && returned && safe, "\(species)")
        }
        // 滞留型も画面端を壁にせず、従来の短距離移動を外側で継続する。
        var stationary = initial(.mandarinfish, position: CGPoint(x: 1.1, y: 0.7))
        let start = stationary.position
        #expect(stationary.stationKeeping?.target.x ?? 0 > 1)
        for tick in 1...90 { stationary.advance(deltaTime: dt, elapsedTime: Double(tick) * dt) }
        #expect(stationary.position != start)
        #expect(stationary.roamingBounds.horizontal.contains(stationary.position.x))
    }

    @Test func cullingIncludesFullFramesAndEffectsAndHasReentryHysteresis() {
        for species in FishSpecies.allCases {
            let profile = AquariumFishMotion.movementProfile(for: species)
            for depth in [CGFloat(0), 0.5, 1] {
                let side = AquariumFishSizing.displaySize(for: species, isFavorite: false) * profile.depthScale(at: depth)
                for angle in [0.0, 45, 90] {
                    let radians = angle * .pi / 180
                    let half = side / 2 * (abs(cos(radians)) + abs(sin(radians)))
                    let partlyVisible = CGPoint(x: (size.width + half - 1) / size.width, y: 0.5)
                    #expect(AquariumFishVisibility.shouldRender(wasRendering: false, position: partlyVisible,
                        aquariumSize: size, fishSize: side, rotationDegrees: angle, velocity: .zero))
                }
            }
        }
        let frame = AquariumFishVisibility.drawingBounds(position: .zero, aquariumSize: size,
            fishSize: 60, rotationDegrees: 0)
        let half = frame.width / 2
        func draw(_ previous: Bool, gap: CGFloat) -> Bool {
            AquariumFishVisibility.shouldRender(wasRendering: previous,
                position: CGPoint(x: (size.width + half + gap) / size.width, y: 0.5), aquariumSize: size,
                fishSize: 60, rotationDegrees: 0, velocity: .zero)
        }
        #expect(!draw(true, gap: 25))
        #expect(!draw(false, gap: 18))
        #expect(draw(false, gap: 11)) // まだ魚体と効果が外側にあるうちに再表示。
        #expect(draw(true, gap: 18)) // 同じ位置へ少し戻っても点滅しない。
    }

    @Test func offscreenSessionHandoffEditingAndPlacedCountArePreserved() throws {
        let fish = (0..<20).map { PlayerFish(id: $0 == 0 ? id : UUID(), species: $0 == 0 ? .mandarinfish : .clownfish) }
        let player = Player(ownedFish: fish, activeAquariumFishIDs: fish.map(\.id), hasInitializedActiveAquariumFish: true)
        let session = AquariumFishViewingSession()
        session.setPlacedFishIDs(Set(fish.map(\.id)))
        let owner = UUID(), next = UUID()
        let motion = initial(.mandarinfish, position: CGPoint(x: 1.25, y: 0.7))
        let snapshot = AquariumFishViewingSession.Snapshot(motion: motion, direction: .init(direction: motion.facingDirection))
        _ = session.claim(id, owner: owner, initial: snapshot, bounds: motion.roamingBounds)
        var restored = session.claim(id, owner: next, initial: snapshot, bounds: motion.roamingBounds)
        #expect(String(reflecting: restored) == String(reflecting: snapshot))
        restored.motion.updateStationKeepingGeometry(size: .zero, fishSize: 40)
        #expect(String(reflecting: restored) == String(reflecting: snapshot))
        #expect(!session.update(id, owner: owner, snapshot: snapshot))
        session.beginEditing()
        let editing = try #require(session.editingSession)
        let editor = UUID()
        var draft = editing.claim(id, owner: editor, initial: snapshot, bounds: motion.roamingBounds)
        draft.motion.advance(deltaTime: dt, elapsedTime: dt)
        #expect(editing.update(id, owner: editor, snapshot: draft))
        session.finishEditing()
        #expect(session.snapshot(for: id)?.motion.position == snapshot.motion.position)
        session.beginEditing()
        let saving = try #require(session.editingSession)
        _ = saving.claim(id, owner: editor, initial: snapshot, bounds: motion.roamingBounds)
        #expect(saving.update(id, owner: editor, snapshot: draft))
        session.finishEditing(commit: [id])
        #expect(session.snapshot(for: id)?.motion.position == draft.motion.position)
        #expect(player.activeAquariumFishIDs == fish.map(\.id))
        #expect(player.activeAquariumFish.count == 20 && player.ownedFish.count == 20)
    }

    @Test func culledFishViewKeepsUpdatingAndDisplaysAgainWithoutRemounting() async throws {
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let session = AquariumFishViewingSession()
        var motion = initial(.manta, position: CGPoint(x: 1.49, y: 0.5))
        motion.velocity = CGVector(dx: -motion.baseSpeed, dy: 0)
        motion.currentSpeed = motion.baseSpeed
        motion.targetSpeed = motion.baseSpeed
        motion.facingDirection = .left
        motion.facingSign = 1
        motion.bluefinCruise?.direction = -1
        let owner = UUID()
        _ = session.claim(id, owner: owner, initial: .init(motion: motion, direction: .init(direction: .left)), bounds: motion.roamingBounds)
        session.release(id, owner: owner)
        let probe = WorldRenderProbe(id: id)
        let host = UIHostingController(rootView: WorldRenderHost(session: session, probe: probe, size: size))
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: size)
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        func settle() async throws {
            host.view.layoutIfNeeded()
            try await Task.sleep(for: .milliseconds(30))
            host.view.layoutIfNeeded()
        }
        try await settle()
        for tick in 1...2 {
            probe.date = Date(timeIntervalSince1970: 100 + Double(tick) * dt)
            try await settle()
        }
        let hidden = try #require(session.snapshot(for: id))
        #expect(probe.renderedImages == 0)
        #expect(hidden.elapsedTime > 0 && hidden.motion.position.x < 1.49)
        for tick in 3...40 {
            probe.date = Date(timeIntervalSince1970: 100 + Double(tick) * dt)
            try await settle()
        }
        let visible = try #require(session.snapshot(for: id))
        #expect(probe.renderedImages > 0)
        #expect(visible.elapsedTime > hidden.elapsedTime)
        #expect(visible.motion.position.x < hidden.motion.position.x)
    }
}

@MainActor
private final class WorldRenderProbe: ObservableObject {
    let id: UUID
    @Published var date = Date(timeIntervalSince1970: 100)
    var renderedImages = 0
    init(id: UUID) { self.id = id }
}

@MainActor
private struct WorldRenderHost: View {
    let session: AquariumFishViewingSession
    @ObservedObject var probe: WorldRenderProbe
    let size: CGSize
    var body: some View {
        var fish = SwimmingFishView(fishID: probe.id, viewingSession: session, species: .manta,
            backgroundTheme: .aquarium, isFavorite: false, aquariumSize: size, updateDate: probe.date,
            isSimulationPaused: false, isSelectionEnabled: false, isSelected: false,
            neighborPositions: .empty, reportPosition: { _ in }, select: {})
        fish.onRenderedFrames = { isRing, _ in if !isRing { probe.renderedImages += 1 } }
        return fish.frame(width: size.width, height: size.height).environment(\.scenePhase, .active)
    }
}
