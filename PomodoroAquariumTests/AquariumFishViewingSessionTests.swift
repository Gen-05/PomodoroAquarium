import SwiftUI
import UIKit
import Combine
import CoreGraphics
import Foundation
import Testing
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
                let prefix = species == .lionfish ? "110F15A0" : species == .pennantCoralfish ? "F1A77A7E" : species == .orientalButterflyfish ? "B077E2F1" : species == .blueGreenChromis ? "C470A115" : species == .yellowTang ? "E1107A60" : "B10E7A60"
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

    @Test(arguments: [FishSpecies.blueTang, .blueGreenChromis, .orientalButterflyfish, .pennantCoralfish, .lionfish])
    func actualFishViewsResumeAcrossRemountBackgroundAndCentralAddition(species: FishSpecies) async throws {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = try #require(scenes.first { $0.activationState == .foregroundActive } ?? scenes.first)
        let session = AquariumFishViewingSession(id: firstSession)
        let probe = ViewingSessionRenderProbe(species: species)
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
        #expect(abs(added.motion.position.x - (0.5 + 20.0 / 393)) < 0.000001)
        #expect(abs(added.motion.position.y - (0.5 - 15.0 / 852)) < 0.000001)
        #expect(String(reflecting: session.snapshot(for: probe.ids[1])) == String(reflecting: Optional(otherBefore)))
        let fish = try #require(probe.fishFrame), ring = try #require(probe.ringFrame)
        #expect(hypot(fish.midX - ring.midX, fish.midY - ring.midY) < 0.001)
    }

}


@MainActor
private final class ViewingSessionRenderProbe: ObservableObject {
    let species: FishSpecies
    init(species: FishSpecies) { self.species = species }
    var ids: [UUID] { [UUID(uuidString: species == .lionfish
        ? "110F15A0-6A60-4A60-8A60-000000000001" : species == .pennantCoralfish
        ? "F1A77A7E-6A60-4A60-8A60-000000000001" : species == .orientalButterflyfish
        ? "B077E2F1-6A60-4A60-8A60-000000000001" : species == .blueGreenChromis
        ? "C470A115-6A60-4A60-8A60-000000000001" : "B10E7A60-6A60-4A60-8A60-000000000001")!,
               UUID(uuidString: "E1107A60-6A60-4A60-8A60-000000000002")!] }
    @Published var screen = 0
    @Published var visible = true
    @Published var phase = ScenePhase.active
    @Published var date = Date(timeIntervalSince1970: 100)
    @Published var appearance: AquariumFishAppearance?
    var fishFrame: CGRect?
    var ringFrame: CGRect?
}

private struct ViewingSessionRenderHost: View {
    let session: AquariumFishViewingSession
    @ObservedObject var probe: ViewingSessionRenderProbe

    var body: some View {
        ZStack {
            if probe.visible {
                ForEach(probe.ids, id: \.self) { id in fish(id: id) }
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
            species: id == probe.ids[0] ? probe.species : .yellowTang,
            backgroundTheme: .aquarium, isFavorite: false, aquariumSize: CGSize(width: 393, height: 852),
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
