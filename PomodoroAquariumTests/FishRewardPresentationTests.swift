import CoreGraphics
import Foundation
import SwiftData
import Testing
import SwiftUI
import UIKit
@testable import PomodoroAquarium

@MainActor
struct FishRewardPresentationTests {
    @Test func newFishUsesSpeciesCountBeforeTheSingleAward() throws {
        for previousCount in [0, 1, 4, 9] {
            let player = Player(ownedFish: (0..<previousCount).map { _ in
                PlayerFish(species: .clownfish)
            } + [PlayerFish(species: .manta)])
            var awardCalls = 0
            let result = try #require(FishAcquisitionResult.capture(for: player) {
                awardCalls += 1
                let fish = PlayerFish(species: .clownfish)
                player.ownedFish.append(fish)
                return fish
            })
            #expect(awardCalls == 1)
            #expect(result.previousOwnedCount == previousCount)
            #expect(result.currentOwnedCount == previousCount + 1)
            #expect(result.isNewFish == (previousCount == 0))
            #expect(result.showsNewBadge == (previousCount == 0))
        }
    }

    @Test func savedFishIsNotNewAfterReopeningTheStore() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RewardNewFishTests.\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let configuration = ModelConfiguration(url: directory.appendingPathComponent("Player.store"))
        do {
            let container = try ModelContainer(for: Player.self, PlayerFish.self, configurations: configuration)
            let context = ModelContext(container)
            context.autosaveEnabled = false
            context.insert(Player(ownedFish: [PlayerFish(species: .clownfish)]))
            try context.save()
        }
        let reopened = try ModelContainer(for: Player.self, PlayerFish.self, configurations: configuration)
        let context = ModelContext(reopened)
        // This temporary store is deleted at scope exit; never autosave into it later.
        context.autosaveEnabled = false
        let player = try #require(context.fetch(FetchDescriptor<Player>()).first)
        let result = try #require(FishAcquisitionResult.capture(for: player) {
            let fish = PlayerFish(species: .clownfish)
            player.ownedFish.append(fish)
            return fish
        })
        #expect(result.previousOwnedCount == 1)
        #expect(!result.isNewFish)
        #expect(!result.showsNewBadge)
    }

    @Test func revealFlashGrowsStrongerWithRarity() {
        let styles = [FishRarity.common, .rare, .epic, .legendary]
            .map { FishRewardRevealFlashStyle.style(for: $0) }
        #expect(styles[0].rayAngles.isEmpty)
        #expect(styles[1].rayAngles.isEmpty)
        #expect(styles[2].rayAngles.count == 6)
        #expect(styles[3].rayAngles.count == 10)
        #expect(styles[2].sparkleCount == 5)
        #expect(styles[3].sparkleCount == 10)
        for index in 1..<styles.count {
            #expect(styles[index].sizeMultiplier > styles[index - 1].sizeMultiplier)
            #expect(styles[index].peakOpacity > styles[index - 1].peakOpacity)
        }
    }

    @Test func preRevealSilhouetteUsesGenericArtwork() throws {
        _ = try #require(UIImage(named: FishRewardMysteryAppearance.backgroundImageName))
        #expect(FishRewardPresentationTiming.approachDuration == 3.0)
        #expect(FishRewardPresentationTiming.reducedMotionApproachDuration == 0.18)
        #expect(FishRewardMysteryAppearance.approachScale == 1.30)
        #expect(FishRewardGenericSilhouette.systemImageName == "fish.fill")
        #expect(FishRewardGenericSilhouette.width == 190)
        #expect(FishRewardGenericSilhouette.height == 120)
    }

    @Test func rewardFishIsSlightlySmallerWithoutShrinkingSmallFishTooFar() {
        #expect(FishRewardImageLayout.displayScale == 0.88)
        #expect(FishRewardImageLayout.displaySize(from: 80) == 80)
        #expect(FishRewardImageLayout.displaySize(from: 200) == 176)
        #expect(FishRewardImageLayout.displaySize(from: 300) == 264)
    }

    @Test func rewardStartsAsASilhouetteWithoutResultInformation() {
        let state = FishRewardPresentationState()

        #expect(state.phase == .silhouette)
        #expect(state.showsSilhouette)
        #expect(!state.showsRarityAppearance)
        #expect(!state.showsResultInformation)
    }

    @Test func revealCanBeginOnlyOnceAndResultInformationWaitsForCompletion() {
        var state = FishRewardPresentationState()

        let didBeginTooEarly = state.beginReveal()
        #expect(!didBeginTooEarly)
        let didBeginApproach = state.beginApproach()
        #expect(didBeginApproach)
        #expect(state.showsSilhouette)
        #expect(!state.showsTapPrompt)
        #expect(!state.showsRarityAppearance)
        #expect(!state.showsResultInformation)
        let didBeginApproachAgain = state.beginApproach()
        #expect(!didBeginApproachAgain)

        let didBeginReveal = state.beginReveal()
        #expect(didBeginReveal)
        #expect(state.phase == .reveal)
        #expect(!state.showsSilhouette)
        #expect(state.showsRarityAppearance)
        #expect(!state.showsResultInformation)
        let didBeginRevealAgain = state.beginReveal()
        #expect(!didBeginRevealAgain)

        state.finishReveal()
        #expect(state.phase == .result)
        #expect(state.showsResultInformation)
    }

    @Test func informationAppearsInOrderWhileTheStrokeIsStillPlaying() {
        for isNewFish in [true, false] {
            let steps = FishRewardPresentationTiming.informationSteps(isNewFish: isNewFish)
            #expect(steps.map(\.rawValue) == (isNewFish ? [0, 1, 2, 3, 4] : [0, 2, 3, 4]))
            var presentation = FishRewardPresentationState()
            presentation.showInformation(.action)
            #expect(!presentation.shows(.action))
            _ = presentation.beginApproach()
            _ = presentation.beginReveal()
            for step in steps {
                #expect(!presentation.shows(step))
                presentation.showInformation(step)
                #expect(presentation.shows(step))
                #expect(!presentation.showsResultInformation)
            }
            presentation.showInformation(.rarity)
            #expect(presentation.shows(.action)) // late/repeated stages cannot rewind
            presentation.finishReveal()
            #expect(presentation.showsResultInformation)
            let didRestart = presentation.beginReveal()
            #expect(!didRestart)

            let informationDuration = Double(steps.count) * FishRewardPresentationTiming.informationInterval
                + FishRewardPresentationTiming.informationFadeDuration
            for species in [FishSpecies.clownfish, .whaleShark] {
                #expect(informationDuration < FishRewardPresentationTiming.oneStrokeDuration(for: species))
            }
        }
        #expect(FishRewardPresentationTiming.informationInterval == 0.30)
        #expect(FishRewardPresentationTiming.informationFadeDuration == 0.25)
        #expect(FishRewardPresentationTiming.fishAppearanceDuration == 0.35)
    }

    @Test func actualRewardCompletesOnceAfterTheStrokeAndCancelsOnDismissal() async throws {
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        for (species, isNewFish) in [
            (FishSpecies.clownfish, true), (.whaleShark, true),
            (.clownfish, false), (.whaleShark, false)
        ] {
            var completions = 0
            let result = FishAcquisitionResult(fish: PlayerFish(species: species),
                previousOwnedCount: isNewFish ? 0 : 1, currentOwnedCount: isNewFish ? 1 : 2)
            let informationDuration = Double(FishRewardPresentationTiming.informationSteps(isNewFish: isNewFish).count)
                * FishRewardPresentationTiming.informationInterval + FishRewardPresentationTiming.informationFadeDuration
            let minimumDuration = FishRewardPresentationTiming.approachDuration
                + FishRewardPresentationTiming.revealHoldDuration(for: species.rarity)
                + max(FishRewardPresentationTiming.oneStrokeDuration(for: species), informationDuration)
                + FishRewardPresentationTiming.informationFadeDuration
            let start = ContinuousClock.now
            let host = UIHostingController(rootView: FishRewardView(result: result,
                sequence: .init(startsAutomatically: true, onPresentationFinished: { completions += 1 }, onAdvance: {})))
            let window = UIWindow(windowScene: scene)
            window.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
            window.rootViewController = host
            window.makeKeyAndVisible()
            defer { window.isHidden = true; window.rootViewController = nil }
            host.view.layoutIfNeeded()
            while completions == 0 && start.duration(to: .now) < .seconds(minimumDuration + 2) {
                try await Task.sleep(for: .milliseconds(50))
            }
            #expect(completions == 1)
            #expect(start.duration(to: .now) >= .seconds(minimumDuration))
            try await Task.sleep(for: .milliseconds(250))
            #expect(completions == 1)
            let format = UIGraphicsImageRendererFormat(); format.scale = 1
            let image = UIGraphicsImageRenderer(size: window.frame.size, format: format).image { _ in
                host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true)
            }
            let suffix = isNewFish ? "new" : "duplicate"
            try #require(image.pngData()).write(to: URL(fileURLWithPath:
                "/private/tmp/FishReward-\(species.rawValue)-\(suffix).png"))
        }

        var cancelledCompletions = 0
        let host = UIHostingController(rootView: FishRewardView(result: .init(
            fish: PlayerFish(species: .clownfish), previousOwnedCount: 0, currentOwnedCount: 1),
            sequence: .init(startsAutomatically: true,
                onPresentationFinished: { cancelledCompletions += 1 }, onAdvance: {})))
        let window = UIWindow(windowScene: scene)
        window.rootViewController = host
        window.makeKeyAndVisible()
        try await Task.sleep(for: .milliseconds(100))
        window.rootViewController = nil
        window.isHidden = true
        try await Task.sleep(for: .seconds(
            FishRewardPresentationTiming.approachDuration
                + FishRewardPresentationTiming.revealHoldDuration(for: .common)
                + FishRewardPresentationTiming.oneStrokeDuration(for: .clownfish)
                + FishRewardPresentationTiming.informationFadeDuration + 0.5
        ))
        #expect(cancelledCompletions == 0)
    }

    @Test func rewardRarityColorsUseTheSharedPresentationRoles() {
        #expect(FishRarity.common.rewardColorRole == .gray)
        #expect(FishRarity.rare.rewardColorRole == .lime)
        #expect(FishRarity.epic.rewardColorRole == .purple)
        #expect(FishRarity.legendary.rewardColorRole == .gold)
    }

    @Test func rarityGlowStrengthIncreasesByRarity() {
        let common = FishRewardGlowStyle.style(for: .common)
        let rare = FishRewardGlowStyle.style(for: .rare)
        let epic = FishRewardGlowStyle.style(for: .epic)
        let legendary = FishRewardGlowStyle.style(for: .legendary)

        #expect(common.sizeMultiplier < rare.sizeMultiplier)
        #expect(rare.sizeMultiplier < epic.sizeMultiplier)
        #expect(epic.sizeMultiplier < legendary.sizeMultiplier)
        #expect(common.pulseScale < rare.pulseScale)
        #expect(rare.pulseScale < epic.pulseScale)
        #expect(epic.pulseScale < legendary.pulseScale)
        #expect(common.pulseOpacity < rare.pulseOpacity)
        #expect(rare.pulseOpacity < epic.pulseOpacity)
        #expect(epic.pulseOpacity < legendary.pulseOpacity)
        #expect(common.rotationDuration == 0)
        #expect(rare.rotationDuration > epic.rotationDuration)
        #expect(epic.rotationDuration > legendary.rotationDuration)
        #expect(common.fishAuraOpacity < rare.fishAuraOpacity)
        #expect(rare.fishAuraOpacity < epic.fishAuraOpacity)
        #expect(epic.fishAuraOpacity < legendary.fishAuraOpacity)
        #expect(common.fishAuraPulseScale < rare.fishAuraPulseScale)
        #expect(rare.fishAuraPulseScale < epic.fishAuraPulseScale)
        #expect(epic.fishAuraPulseScale < legendary.fishAuraPulseScale)
        #expect(common.particleCount == 4)
        #expect(common.particleCount < epic.particleCount)
        #expect(rare.particleCount == 0)
        #expect(epic.particleCount > 0)
        #expect(legendary.particleCount > epic.particleCount)
        #expect(!epic.usesSparkles)
        #expect(legendary.usesSparkles)
    }

    @Test func rewardAnimationPreservesExistingTimingAndUsesTheWhaleSharkForwardCycle() {
        #expect(FishRewardPresentationTiming.rewardStrokeDuration == 3.0)

        for species in FishSpecies.allCases {
            let state = FishDetailStrokeAnimationState(species: species)
            if species == .whaleShark || species == .orca {
                var playing = state
                let started = playing.start()
                #expect(started)
                var frames: [Int] = []
                while let index = playing.currentFrameIndex { frames.append(index); playing.advance() }
                #expect(frames == Array(0..<species.swimmingImageNames.count))
                #expect(FishRewardPresentationTiming.rewardFrameDuration(for: species) == (species == .orca ? 0.16 : 0.24))
                #expect(abs(FishRewardPresentationTiming.oneStrokeDuration(for: species) - (species == .orca ? 2.56 : 2.88)) < 0.000001)
                continue
            }
            let expected = FishDetailStrokeAnimationState.oneStrokeFrameIndices(
                frameCount: species.swimmingImageNames.count
            )
            let rewardFrameDuration = FishRewardPresentationTiming.rewardFrameDuration(
                for: species
            )

            #expect(state.frameCount == species.swimmingImageNames.count)
            #expect(!expected.isEmpty)
            #expect(expected.first == 0)
            #expect(expected.last == 0)
            #expect(abs(
                FishRewardPresentationTiming.oneStrokeDuration(for: species)
                    - FishRewardPresentationTiming.rewardStrokeDuration
            ) < 0.000_001)
            #expect(abs(
                rewardFrameDuration * Double(expected.count)
                    - FishRewardPresentationTiming.rewardStrokeDuration
            ) < 0.000_001)
        }
    }

    @Test func rewardFrameDurationSafelyHandlesZeroAndOneFrame() {
        #expect(
            FishRewardPresentationTiming.rewardFrameDuration(frameCount: 0)
                == FishRewardPresentationTiming.rewardStrokeDuration
        )
        #expect(
            FishRewardPresentationTiming.rewardFrameDuration(frameCount: 1)
                == FishRewardPresentationTiming.rewardStrokeDuration
        )
        #expect(FishRewardPresentationTiming.oneStrokeDuration(frameCount: 0) == 0)
        #expect(FishRewardPresentationTiming.oneStrokeDuration(frameCount: 1) == 0)
    }

    @Test func ineligibleStudyKeepsTheExistingNoFishRewardPath() {
        let player = Player()
        let result = FishAcquisitionResult.capture(for: player) {
            FishRewardService.awardFish(for: 24, to: player)
        }

        #expect(result == nil)
        #expect(player.ownedFish.isEmpty)

        let reward = StudyCompletionReward(
            studyReward: 0,
            streakReward: 0,
            streakDays: 0,
            didEarnFish: false
        )
        #expect(!reward.didEarnFish)
        #expect(StudyCompletionRewardPresentation.amountText(reward.totalReward) == "0コイン")
    }

    @Test func eligibleStudyAwardsExactlyOneFishBeforePresentation() throws {
        let player = Player()
        let result = try #require(FishAcquisitionResult.capture(for: player) {
            FishRewardService.awardFish(for: 25, to: player)
        })

        #expect(player.ownedFish.count == 1)
        #expect(player.ownedFish.first?.id == result.fish.id)
        #expect(result.currentOwnedCount == 1)
    }

    @Test func duplicateFishPresentationDoesNotAwardAnotherFish() throws {
        let existingFish = PlayerFish(species: .clownfish)
        let player = Player(ownedFish: [existingFish])
        let result = try #require(FishAcquisitionResult.capture(for: player) {
            let awardedFish = PlayerFish(species: .clownfish)
            player.ownedFish.append(awardedFish)
            return awardedFish
        })
        let countAfterAward = player.ownedFish.count

        var presentation = FishRewardPresentationState()
        _ = presentation.beginApproach()
        _ = presentation.beginReveal()
        presentation.finishReveal()

        #expect(result.previousOwnedCount == 1)
        #expect(result.currentOwnedCount == 2)
        #expect(presentation.phase == .result)
        #expect(player.ownedFish.count == countAfterAward)
    }

#if DEBUG
    @Test func rewardPreviewProvidesOneRepresentativeForEveryRarity() throws {
        #expect(RewardPreviewCatalog.items.count == 4)

        for rarity in [
            FishRarity.common,
            .rare,
            .epic,
            .legendary
        ] {
            let item = try #require(RewardPreviewCatalog.item(for: rarity))
            #expect(item.rarity == rarity)
            #expect(item.species.rarity == rarity)
        }
    }

    @Test func rewardPreviewDataDoesNotMutatePlayerOrDailyAcquisitionCount() throws {
        let player = Player(
            ownedFish: [PlayerFish(species: .jellyfish)],
            totalStudyMinutes: 180,
            todayStudyMinutes: 60,
            coins: 90
        )
        let suiteName = "RewardPreviewTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(3, forKey: DailyFishAcquisitionStorageKey.count)

        let ownedFishIDsBefore = player.ownedFish.map(\.id)
        let totalStudyMinutesBefore = player.totalStudyMinutes
        let todayStudyMinutesBefore = player.todayStudyMinutes
        let coinsBefore = player.coins
        let acquisitionCountBefore = defaults.integer(
            forKey: DailyFishAcquisitionStorageKey.count
        )

        for item in RewardPreviewCatalog.items {
            for isNewFish in [true, false] {
                let result = RewardPreviewCatalog.previewResult(for: item, isNewFish: isNewFish)
                #expect(result.species == item.species)
                #expect(result.species.rarity == item.rarity)
                #expect(result.isNewFish == isNewFish)
            }
        }

        #expect(player.ownedFish.map(\.id) == ownedFishIDsBefore)
        #expect(player.totalStudyMinutes == totalStudyMinutesBefore)
        #expect(player.todayStudyMinutes == todayStudyMinutesBefore)
        #expect(player.coins == coinsBefore)
        #expect(defaults.integer(forKey: DailyFishAcquisitionStorageKey.count) == acquisitionCountBefore)
    }
#endif
}
