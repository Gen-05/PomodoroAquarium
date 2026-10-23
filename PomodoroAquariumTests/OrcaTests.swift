import SwiftUI
import SwiftData
import UIKit
import Testing
@testable import PomodoroAquarium

@MainActor
struct OrcaTests {
    private let ids = (1...5).map {
        UUID(uuidString: String(format: "0ACA1150-6A60-4A60-8A60-%012d", $0))!
    }

    @Test func registrationAssetsAndSavedIdentifiersRemainCompatible() throws {
        #expect(FishSpecies.orca.rawValue == "orca" && FishSpecies.orca.name == "シャチ")
        #expect(FishSpecies.orca.rarity == .legendary && FishSpecies.orca.imageName == "fish_orca")
        #expect(FishSpecies.orca.swimmingImageNames == (1...16).map { "fish_orca_side_\($0)" })
        #expect(FishSpecies.orca.usesForwardSwimmingLoop && FishSpecies.orca.usesHorizontalSwimmingFlip)
        #expect(!FishSpecies.orca.usesDirectionalSwimmingSprites)
        for species in FishSpecies.allCases {
            let data = Data("\"\(species.rawValue)\"".utf8)
            #expect(try JSONDecoder().decode(FishSpecies.self, from: data) == species)
            #expect(try JSONEncoder().encode(species) == data)
        }
        #expect(FishSpecies.manta.rawValue == "manta" && FishSpecies.whaleShark.rawValue == "whaleShark")
        for name in FishSpecies.orca.swimmingImageNames + ["fish_orca"] {
            let image = try #require(UIImage(named: name)?.cgImage)
            #expect(image.width == 1254 && image.height == 1254)
            #expect(image.alphaInfo != .none && image.alphaInfo != .noneSkipFirst && image.alphaInfo != .noneSkipLast)
        }
        #expect(UIImage(named: "fish_orca")?.pngData() == UIImage(named: "fish_orca_side_1")?.pngData())
        var detail = FishDetailStrokeAnimationState(species: .orca)
        #expect(detail.frameDuration == 0.16)
        let started = detail.start(); #expect(started)
        var frames: [Int] = []
        while let index = detail.currentFrameIndex { frames.append(index); detail.advance() }
        #expect(frames == Array(0..<16))
        #expect(FishRewardPresentationTiming.rewardFrameDuration(for: .orca) == 0.16)
        #expect(abs(FishRewardPresentationTiming.oneStrokeDuration(for: .orca) - 2.56) < 0.0000001)
    }

    @Test func twoForwardCyclesConnectToNeutralGlideAndResumeAtNeutral() {
        var state = AquariumOrcaSwimming.State(id: ids[0], staggered: false)
        #expect(AquariumOrcaSwimming.frameDuration == 0.16)
        #expect(AquariumOrcaSwimming.State.propulsionDuration == 5.12)
        for step in 0..<32 {
            #expect(state.phase == .propulsion && state.frameNumber == step % 16 + 1)
            state.advance(deltaTime: 0.16)
        }
        #expect(state.phase == .gliding && state.imageName == "fish_orca_side_1")
        state.advance(deltaTime: 1.4 - 0.000001)
        #expect(state.phase == .gliding && state.frameNumber == 1)
        state.advance(deltaTime: 0.000001)
        #expect(state.phase == .propulsion && state.frameNumber == 1)
        state.advance(deltaTime: 0.16)
        #expect(state.frameNumber == 2)
        var split = AquariumOrcaSwimming.State(id: ids[0], staggered: false)
        var whole = split
        whole.advance(deltaTime: 30)
        for _ in 0..<1800 { split.advance(deltaTime: 1.0 / 60) }
        #expect(split.phase == whole.phase && split.frameNumber == whole.frameNumber)
        #expect(abs(split.phaseElapsed - whole.phaseElapsed) < 0.000001)
        #expect(abs(split.speedMultiplier - whole.speedMultiplier) < 0.000001)
    }

    @Test func individualsAreIndependentAndMoveThroughGlidesWithoutSpeedJumps() {
        let states = ids.map { AquariumOrcaSwimming.State(id: $0) }
        #expect(states == ids.map { AquariumOrcaSwimming.State(id: $0) })
        #expect(Set(states.map { $0.phaseElapsed }).count == 5)
        #expect(Set(ids.map { AquariumFishMotion.initialState(for: $0, profile: .orca).position.x }).count == 5)
        var state = AquariumOrcaSwimming.State(id: ids[0], staggered: false)
        var motion = AquariumFishMotion.initialState(for: ids[0], profile: .orca)
        var previous = state.speedMultiplier
        var phases: Set<String> = []
        for frame in 1...1800 {
            state.advance(deltaTime: 1.0 / 60)
            #expect(state.speedMultiplier >= 1.75 && state.speedMultiplier <= 2.10)
            #expect(abs(state.speedMultiplier - previous) < 0.007)
            motion.advance(deltaTime: 1.0 / 60, elapsedTime: Double(frame) / 60, speedMultiplier: state.speedMultiplier)
            #expect(motion.currentSpeed > 0)
            previous = state.speedMultiplier
            phases.insert(String(describing: state.phase))
        }
        #expect(phases.count == 2)
        #expect(AquariumOrcaSwimming.propulsionSpeed < AquariumDolphinSwimming.propulsionSpeed)
        #expect(AquariumOrcaSwimming.glideSpeed < AquariumDolphinSwimming.glideSpeed)
        #expect(FishMovementProfile.orca.baseSpeedRange == FishMovementProfile.dolphin.baseSpeedRange)
        #expect(FishMovementProfile.orca.turnResponsivenessRange == FishMovementProfile.dolphin.turnResponsivenessRange)
        #expect(AquariumFishMotion.presentationAmplitude(for: .orca) == 0)
    }

    @Test func sharedCycleSurvivesHandoffEditingCancelAndCommit() throws {
        let session = AquariumFishViewingSession(), owner = UUID(), next = UUID()
        var cycle = AquariumOrcaSwimming.State(id: ids[0], staggered: false)
        cycle.advance(deltaTime: 5.5)
        let motion = AquariumFishMotion.initialState(for: ids[0], profile: .orca)
        var value = AquariumFishViewingSession.Snapshot(motion: motion,
            direction: .init(direction: motion.facingDirection), orca: cycle)
        _ = session.claim(ids[0], owner: owner, initial: value, bounds: .legacy)
        let resumed = session.claim(ids[0], owner: next, initial: value, bounds: .legacy)
        #expect(resumed.orca == cycle && resumed.orca?.phase == .gliding)
        value.orca?.advance(deltaTime: 0.2)
        #expect(!session.update(ids[0], owner: owner, snapshot: value))
        session.beginEditing()
        let editing = try #require(session.editingSession)
        _ = editing.claim(ids[0], owner: owner, initial: value, bounds: .legacy)
        #expect(editing.update(ids[0], owner: owner, snapshot: value))
        session.finishEditing()
        #expect(session.snapshot(for: ids[0])?.orca == cycle)
        session.beginEditing()
        let committed = try #require(session.editingSession)
        _ = committed.claim(ids[0], owner: owner, initial: value, bounds: .legacy)
        #expect(committed.update(ids[0], owner: owner, snapshot: value))
        session.finishEditing(commit: [ids[0]])
        #expect(session.snapshot(for: ids[0])?.orca == value.orca)
        session.stopInflation(except: [])
        #expect(session.snapshot(for: ids[0]) == nil)
    }

    @Test func legendaryPoolAndRarityWeightsUseTheExistingUniformDraw() {
        let pool = FishSpecies.allCases.filter { $0.rarity == .legendary }
        #expect(pool == [.whaleShark, .orca])
        for (minutes, expected) in [(0, [70.0, 20, 8, 2]), (180, [58.0, 25, 13, 4]), (300, [58.0, 25, 13, 4])] {
            let p = FishRewardService.rarityProbabilities(for: minutes)
            #expect([p.common, p.rare, p.epic, p.legendary] == expected && p.total == 100)
            #expect(p.legendary / Double(pool.count) == (minutes == 0 ? 1 : 2))
        }
        let legendaryOnly = FishRewardService.RarityProbabilities(common: 0, rare: 0, epic: 0, legendary: 100)
        for _ in 0..<20 {
            #expect(pool.contains(FishRewardService.drawSpecies(using: legendaryOnly)!))
        }
    }

    @Test func savedOrcaAndExistingIndividualsKeepIDsAfterRepeatedReads() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Orca-\(UUID()).store")
        defer { for suffix in ["", "-shm", "-wal"] { try? FileManager.default.removeItem(atPath: url.path + suffix) } }
        let config = ModelConfiguration(url: url)
        let oldID = UUID()
        do {
            let container = try ModelContainer(for: Player.self, PlayerFish.self, configurations: config)
            let context = ModelContext(container); context.autosaveEnabled = false
            let orca = PlayerFish(id: ids[0], species: .orca), old = PlayerFish(id: oldID, species: .manta)
            context.insert(Player(ownedFish: [orca, old], favoriteFish: orca,
                activeAquariumFishIDs: [ids[0], oldID], hasInitializedActiveAquariumFish: true))
            try context.save()
        }
        for _ in 0..<2 {
            let container = try ModelContainer(for: Player.self, PlayerFish.self, configurations: config)
            let context = ModelContext(container); context.autosaveEnabled = false
            let fish = try context.fetch(FetchDescriptor<PlayerFish>())
            #expect(fish.count == 2 && fish.first { $0.id == ids[0] }?.species == .orca)
            #expect(fish.first { $0.id == oldID }?.species == .manta)
            let player = try #require(context.fetch(FetchDescriptor<Player>()).first)
            #expect(Set(player.ownedFish.map(\.id)) == Set([ids[0], oldID]))
            #expect(player.activeAquariumFishIDs == [ids[0], oldID] && player.favoriteFish?.id == ids[0])
        }
    }

    @Test func developerGrantIsIdempotentAndDoesNotAffectPlacementOrRewards() throws {
        let container = try ModelContainer(for: Player.self, PlayerFish.self, RewardHistoryEntry.self,
            FocusSessionRecord.self, StudyDailyRecord.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let regular = PlayerFish(species: .orca), placed = PlayerFish(species: .dolphin)
        let player = Player(ownedFish: [regular, placed], activeAquariumFishIDs: [placed.id],
            hasInitializedActiveAquariumFish: true, totalStudyMinutes: 90, todayStudyMinutes: 25, coins: 80)
        player.dailyEarnedFishCount = 3; player.pendingFishEarnedCount = 2
        player.dailyClaimedFishCount = 1; player.dailyGrantedFishCount = 1
        context.insert(player); try context.save()
        let added = try AquariumDeveloperFish.seedIfNeeded(for: player, in: context)
#if DEBUG
        #expect(added && AquariumDeveloperFish.individualIDs(for: .orca) == ids)
        #expect(player.ownedFish.filter { $0.species == .orca }.count == 6)
#else
        #expect(!added && AquariumDeveloperFish.individualIDs(for: .orca).isEmpty)
        #expect(player.ownedFish.count == 2)
#endif
        #expect(player.activeAquariumFishIDs == [placed.id])
        let allIDs = player.ownedFish.map(\.id)
        #expect(Set(allIDs).count == allIDs.count)
        let again = try AquariumDeveloperFish.seedIfNeeded(for: player, in: context)
        #expect(!again && player.ownedFish.map(\.id) == allIDs)
        #expect(player.coins == 80 && player.totalStudyMinutes == 90 && player.todayStudyMinutes == 25)
        #expect(player.dailyEarnedFishCount == 3 && player.pendingFishEarnedCount == 2)
        #expect(player.dailyClaimedFishCount == 1 && player.dailyGrantedFishCount == 1)
        #expect(try context.fetchCount(FetchDescriptor<RewardHistoryEntry>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<FocusSessionRecord>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<StudyDailyRecord>()) == 0)
        #expect(player.addFishToAquarium(playerFishID: regular.id))
        #expect(player.removeFishFromAquarium(playerFishID: regular.id))
        #expect(BookView.ownedCount(for: .orca, in: player) == (added ? 6 : 1))
        let ordered = AquariumFishEditorPresentation.ownedSpecies(from: player.ownedFish)
        #expect(ordered.last == .orca)
    }
}
