import CoreGraphics
import Foundation
import SwiftData
import Testing
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
            context.insert(Player(ownedFish: [PlayerFish(species: .clownfish)]))
            try context.save()
        }
        let reopened = try ModelContainer(for: Player.self, PlayerFish.self, configurations: configuration)
        let context = ModelContext(reopened)
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

    @Test func preRevealSilhouetteUsesGenericArtwork() {
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
        #expect(common.particleCount == 0)
        #expect(rare.particleCount == 0)
        #expect(epic.particleCount > 0)
        #expect(legendary.particleCount > epic.particleCount)
        #expect(!epic.usesSparkles)
        #expect(legendary.usesSparkles)
    }

    @Test func rewardAnimationReusesTheDetailSequenceWithAUniformStrokeDuration() {
        #expect(FishRewardPresentationTiming.rewardStrokeDuration == 3.0)

        for species in FishSpecies.allCases {
            let state = FishDetailStrokeAnimationState(species: species)
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
