import Combine
import SwiftUI
import UIKit
import CoreGraphics
import Foundation
import Testing
@testable import PomodoroAquarium

struct AquariumEditorPresentationTests {
    @Test func appearanceIsOneSecondAndNeverReplaysAfterCompletion() {
        let start = Date(timeIntervalSince1970: 100)
        let appearance = AquariumFishAppearance(startedAt: start)
        #expect(appearance.progress(at: start) == 0)
        #expect(appearance.fishProgress(at: start) == 0)
        #expect(appearance.fishProgress(at: start.addingTimeInterval(0.5)) > 0)
        #expect(appearance.fishProgress(at: start.addingTimeInterval(0.5)) < 1)
        #expect(appearance.progress(at: start.addingTimeInterval(1)) == 1)
        #expect(appearance.fishProgress(at: start.addingTimeInterval(60)) == 1)
    }

    @Test func initialDecorationStaysGroundedAndAvoidsTheFixedMenuAndNeighbors() {
        let size = CGSize(width: 393, height: 808)
        for kind in AquariumDecorationKind.availableKinds where kind.groundAnchorY != nil {
            let first = AquariumEditorInitialPlacement.decoration(kind: kind, scale: 1, size: size, existing: [])
            let existing = AquariumDecoration(id: "existing", kind: kind, relativeX: first.x, relativeY: first.y, scale: 1)
            let next = AquariumEditorInitialPlacement.decoration(kind: kind, scale: 1, size: size, existing: [existing])
            #expect(kind.movementBounds.y.contains(first.y))
            #expect(kind.movementBounds.y.contains(next.y))
            #expect(first != next)
            #expect(first.y * size.height < size.height - 95 || abs(first.x * size.width - size.width / 2) > 130)
            #expect(existing.relativeX == first.x && existing.relativeY == first.y)
        }
    }

    @Test func addedFishRandomlyAppearInTheCentralAreaAcrossCanvasSizesAndSpecies() {
        var generator = SpawnTestGenerator()
        // 実canvas（セーフエリア除外後）の縦長端末・横向きiPad・小さい分割画面。
        for size in [CGSize(width: 320, height: 568), CGSize(width: 393, height: 746),
                     CGSize(width: 1024, height: 680), CGSize(width: 180, height: 240)] {
            for species in FishSpecies.allCases {
                let bounds = AquariumFishMotion.movementProfile(for: species).roamingStyle.bounds(
                    in: size, fishSize: AquariumFishSizing.displaySize(for: species, isFavorite: false))
                var points: [CGPoint] = []
                for _ in 0..<100 {
                    let point = AquariumEditorInitialPlacement.fish(species: species, size: size, using: &generator)
                    #expect(hypot((point.x - 0.5) * size.width, (point.y - 0.5) * size.height) <= 60.000_001)
                    #expect(AquariumFishMotion.clampedPoint(point, bounds: bounds) == point)
                    points.append(point)
                }
                #expect(points.contains { $0 != points[0] })
            }
        }
    }

    @MainActor
    @Test func twentyAddsUseTheActualRenderedFishAndRingCenterEvenWhenSpawnArrivesLate() async throws {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let windowScene = try #require(scenes.first { $0.activationState == .foregroundActive } ?? scenes.first)
        var generator = SpawnTestGenerator()
        for size in [CGSize(width: 320, height: 568), CGSize(width: 393, height: 852),
                     CGSize(width: 1024, height: 768)] {
            let probe = SpawnRenderProbe()
            let recorder = SpawnRenderRecorder()
            let session = AquariumFishViewingSession()
            let host = UIHostingController(rootView: SpawnRenderHost(probe: probe, recorder: recorder, size: size, session: session))
            let window = UIWindow(windowScene: windowScene)
            window.frame = CGRect(origin: .zero, size: size)
            window.rootViewController = host
            window.makeKeyAndVisible()
            defer { window.isHidden = true }
            let player = Player(ownedFish: FishSpecies.allCases.map { PlayerFish(species: $0) },
                activeAquariumFishIDs: [], hasInitializedActiveAquariumFish: true)
            var maximumRenderedDistance: CGFloat = 0
            for index in 0..<20 {
                let species = FishSpecies.allCases[index % FishSpecies.allCases.count]
                let canvas = CGRect(x: 27, y: -62, width: size.width, height: size.height)
                let initial = AquariumEditorInitialPlacement.fish(species: species, size: canvas.size, using: &generator)
                let added = try #require(AquariumFishEditing.drop(species: species,
                    location: CGPoint(x: canvas.minX + canvas.width * initial.x,
                                      y: canvas.minY + canvas.height * initial.y), canvas: canvas, player: player))
                probe.appearance = nil
                probe.id = added.id
                probe.species = species
                // 先に通常のランダム位置で同じViewをmountし、後から追加イベントを渡す。
                try await settle(host)
                let start = Date(timeIntervalSince1970: Double(100 + index * 10))
                probe.date = start
                probe.appearance = AquariumFishAppearance(startedAt: start, spawnOffset: CGPoint(
                    x: (added.position.x - 0.5) * canvas.width,
                    y: (added.position.y - 0.5) * canvas.height))
                for elapsed in [0.0, 0.5, 0.999] {
                    probe.date = start.addingTimeInterval(elapsed)
                    try await settle(host)
                    let fish = try #require(recorder.fish)
                    let ring = try #require(recorder.ring)
                    let renderedCanvas = try #require(recorder.canvas)
                    let center = CGPoint(x: renderedCanvas.midX, y: renderedCanvas.midY)
                    let distance = hypot(fish.midX - center.x, fish.midY - center.y)
                    maximumRenderedDistance = max(maximumRenderedDistance, distance)
                    #expect(distance <= 60)
                    #expect(hypot(fish.midX - ring.midX, fish.midY - ring.midY) < 0.001)
                    // Geometryは端末ピクセルへ丸められるので0.5pt未満の差を許容する。
                    let xDifference = abs(fish.midX - center.x - (added.position.x - 0.5) * size.width)
                    let yDifference = abs(fish.midY - center.y - (added.position.y - 0.5) * size.height)
                    #expect(xDifference < 0.5)
                    #expect(yDifference < 0.5)
                }
                var previous = try #require(recorder.fish)
                for frame in 30...38 {
                    probe.date = start.addingTimeInterval(Double(frame) / 30)
                    try await settle(host)
                    let fish = try #require(recorder.fish)
                    if species == .manta {
                        // 高速直進のクロマグロは1tickで5pt以上進める。描画と共有座標を直接照合する。
                        let motion = try #require(session.snapshot(for: added.id)?.motion)
                        let canvas = try #require(recorder.canvas)
                        #expect(abs(fish.midX - canvas.minX - motion.position.x * size.width) < 0.5)
                        #expect(abs(fish.midY - canvas.minY - motion.position.y * size.height) < 0.5)
                    } else {
                        #expect(hypot(fish.midX - previous.midX, fish.midY - previous.midY) < 5,
                            "species=\(species) size=\(size) frame=\(frame) previous=\(previous) actual=\(fish) motion=\(String(describing: session.snapshot(for: added.id)?.motion.position))")
                    }
                    previous = fish
                }
                #expect(AquariumFishEditing.store(id: added.id, player: player))
            }
            print("Spawn render: \(size), 20 adds, maximum distance \(maximumRenderedDistance)pt")
        }
    }

    @MainActor
    private func settle(_ host: UIHostingController<SpawnRenderHost>) async throws {
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(25))
        host.view.layoutIfNeeded()
    }

    @Test func appearanceResumesSwimmingFromItsSpawnWithoutAJump() throws {
        let start = Date(timeIntervalSince1970: 100)
        let appearance = AquariumFishAppearance(startedAt: start)
        let size = CGSize(width: 393, height: 746)
        var generator = SpawnTestGenerator()
        for species in FishSpecies.allCases {
            for _ in 0..<10 {
                let id = UUID()
                let spawn = AquariumEditorInitialPlacement.fish(species: species, size: size, using: &generator)
                let profile = AquariumFishMotion.movementProfile(for: species)
                let bounds = profile.roamingStyle.bounds(in: size,
                    fishSize: AquariumFishSizing.displaySize(for: species, isFavorite: false))
                var motion = AquariumFishMotion.initialState(for: id, profile: profile,
                    roamingBounds: bounds, initialPosition: spawn)
                #expect(motion.position == spawn)
                #expect(motion.anchorPosition == spawn)
                var timing = AquariumSimulationTiming()
                // Viewと同じ時計条件。演出中は魚と輪を載せるpositionを動かさない。
                for frame in 0...30 {
                    let date = start.addingTimeInterval(Double(frame) / 30)
                    let pausedDelta = timing.nextDeltaTime(at: date,
                        isPaused: appearance.progress(at: date) < 1)
                    #expect(pausedDelta == nil)
                    #expect(motion.position == spawn)
                }
                var elapsed: TimeInterval = 0
                for frame in 31...150 {
                    let date = start.addingTimeInterval(Double(frame) / 30)
                    let nextDelta = timing.nextDeltaTime(at: date, isPaused: false)
                    let delta = try #require(nextDelta)
                    let previous = motion.position
                    elapsed += delta
                    motion.advance(deltaTime: delta, elapsedTime: elapsed)
                    if species == .manta {
                        // 固定の距離上限ではなく、採用済み横速度の1tick分と連続していることを確認。
                        let translated = CGPoint(x: previous.x + motion.translationVelocity.dx * motion.depthSpeedMultiplier * delta,
                            y: previous.y + motion.translationVelocity.dy * motion.depthSpeedMultiplier * delta)
                        let expected = AquariumFishMotion.clampedPoint(translated, bounds: bounds)
                        #expect(abs(motion.position.x - expected.x) < 0.00000001)
                        #expect(abs(motion.position.y - expected.y) < 0.00000001)
                    } else {
                        #expect(hypot(motion.position.x - previous.x, motion.position.y - previous.y) < 0.01)
                    }
                }
                #expect(motion.position != spawn)
            }
        }
    }

    @Test func spawnOverridePreservesSpeedDirectionAndOrdinaryInitialization() {
        let id = UUID()
        for species in FishSpecies.allCases {
            let profile = AquariumFishMotion.movementProfile(for: species)
            let ordinary = AquariumFishMotion.initialState(for: id, profile: profile)
            let spawned = AquariumFishMotion.initialState(for: id, profile: profile,
                initialPosition: CGPoint(x: 0.5, y: 0.5))
            let initial = AquariumFishMotion.initialPosition(for: id)
            let expected = profile.usesStationKeeping
                ? AquariumMandarinfishMotion.State.lowerInitialPosition(initial, bounds: .legacy) : initial
            #expect(ordinary.position == expected)
            #expect(spawned.position == CGPoint(x: 0.5, y: 0.5))
            #expect(ordinary.anchorPosition == ordinary.position)
            #expect(spawned.baseSpeed == ordinary.baseSpeed)
            #expect(spawned.currentSpeed == ordinary.currentSpeed)
            #expect(spawned.velocity == ordinary.velocity)
            #expect(spawned.facingDirection == ordinary.facingDirection)
            #expect(spawned.randomState == ordinary.randomState)
        }
    }
}

private struct SpawnTestGenerator: RandomNumberGenerator {
    private var state: UInt64 = 42
    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return state
    }
}

@MainActor
private final class SpawnRenderProbe: ObservableObject {
    @Published var id = UUID()
    @Published var species = FishSpecies.clownfish
    @Published var appearance: AquariumFishAppearance?
    @Published var date = Date(timeIntervalSince1970: 0)
}

@MainActor
private final class SpawnRenderRecorder {
    var fish: CGRect?
    var ring: CGRect?
    var canvas: CGRect?
}

private struct SpawnRenderHost: View {
    @ObservedObject var probe: SpawnRenderProbe
    let recorder: SpawnRenderRecorder
    let size: CGSize
    let session: AquariumFishViewingSession

    var body: some View {
        ZStack {
            measuredFish
                .id(probe.id)
        }
        .frame(width: size.width, height: size.height)
        .background {
            GeometryReader { geometry in
                Color.clear.onAppear { recorder.canvas = geometry.frame(in: .global) }
                    .onChange(of: geometry.frame(in: .global)) { _, frame in recorder.canvas = frame }
            }
        }
        .ignoresSafeArea()
        .environment(\.scenePhase, .active) // 共有セッションの更新権を取れる実表示と同じ条件。
    }

    private var measuredFish: some View {
        let observedID = probe.id
        var fish = SwimmingFishView(fishID: observedID, viewingSession: session,
            initialPosition: probe.appearance?.spawnPosition(in: size), appearance: probe.appearance,
            species: probe.species, backgroundTheme: .aquarium, isFavorite: false,
            aquariumSize: size, updateDate: probe.date, isSimulationPaused: false,
            isSelectionEnabled: true, isSelected: false, neighborPositions: .empty,
            reportPosition: { _ in }, select: {})
        fish.onRenderedFrames = { isRing, frame in
            guard probe.id == observedID else { return }
            if isRing { recorder.ring = frame } else { recorder.fish = frame }
        }
        return fish
    }
}
