import Foundation
import SwiftData
import Testing
@testable import PomodoroAquarium

@MainActor
struct CoreTutorialTests {
    @Test func conversationPagesStayInsideTheCurrentPersistentStep() throws {
        let (defaults, suite) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let coordinator = CoreTutorialCoordinator(defaults: defaults)

        #expect(coordinator.step == .homeIntro)
        #expect(coordinator.conversationIndex == 0)
        #expect(!coordinator.advanceConversation(totalCount: 2))
        #expect(coordinator.step == .homeIntro)
        #expect(coordinator.conversationIndex == 1)
        #expect(coordinator.advanceConversation(totalCount: 2))
        #expect(coordinator.step == .homeIntro)

        coordinator.dismissHomeIntro()
        #expect(coordinator.step == .homePointsIntro)
        #expect(coordinator.conversationIndex == 0)
    }

    @Test func stepsAdvanceOnlyFromRealInteractionHooks() throws {
        let (defaults, suite) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let coordinator = CoreTutorialCoordinator(defaults: defaults)

        #expect(coordinator.step == .homeIntro)
        coordinator.dismissHomeIntro()
        #expect(coordinator.step == .homePointsIntro)
        coordinator.dismissHomeIntro()
        #expect(coordinator.step == .homeStudySummaryIntro)
        coordinator.dismissHomeIntro()
        #expect(coordinator.step == .waitingForHomeStartTap)
        coordinator.didTapHomeStart()
        #expect(coordinator.step == .studySetupIntro)
        coordinator.dismissStudySetupIntro()
        #expect(coordinator.step == .studySettingsIntro)
        coordinator.dismissStudySetupIntro()
        #expect(coordinator.step == .waitingForStudyStartTap)
        coordinator.didTapStudyStart()
        #expect(coordinator.step == .reward)
        coordinator.didDismissReward()
        #expect(coordinator.step == .aquariumIntro)
    }

    @Test func tabSelectionHooksKeepTheSameStepAndRestartItsConversation() throws {
        let (defaults, suite) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let coordinator = CoreTutorialCoordinator(defaults: defaults)

        coordinator.dismissHomeIntro()
        coordinator.dismissHomeIntro()
        coordinator.dismissHomeIntro()
        coordinator.didTapHomeStart()
        coordinator.dismissStudySetupIntro()
        coordinator.dismissStudySetupIntro()
        coordinator.didTapStudyStart()
        coordinator.didDismissReward()
        #expect(coordinator.step == .aquariumIntro)
        #expect(!coordinator.advanceConversation(totalCount: 3))
        #expect(!coordinator.advanceConversation(totalCount: 3))
        #expect(coordinator.conversationIndex == 2)

        coordinator.didSelectAquariumTab()
        #expect(coordinator.step == .aquariumIntro)
        #expect(coordinator.conversationIndex == 0)

        defaults.set(true, forKey: CoreTutorialStorageKey.hasSavedAquarium)
        let finishingCoordinator = CoreTutorialCoordinator(defaults: defaults)
        #expect(finishingCoordinator.step == .finishing)
        #expect(!finishingCoordinator.advanceConversation(totalCount: 3))
        #expect(!finishingCoordinator.advanceConversation(totalCount: 3))
        finishingCoordinator.didSelectHomeTabAfterAquarium()
        #expect(finishingCoordinator.step == .finishing)
        #expect(finishingCoordinator.conversationIndex == 0)
    }

    @Test func interruptionBeforeRewardRestartsSafelyFromHome() throws {
        let (defaults, suite) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let coordinator = CoreTutorialCoordinator(defaults: defaults)
        coordinator.dismissHomeIntro()
        coordinator.dismissHomeIntro()
        coordinator.dismissHomeIntro()
        coordinator.didTapHomeStart()
        coordinator.dismissStudySetupIntro()
        coordinator.dismissStudySetupIntro()

        let relaunched = CoreTutorialCoordinator(defaults: defaults)
        #expect(relaunched.step == .homeIntro)
        #expect(relaunched.isActive)
    }

    @Test func interruptionAfterTutorialStartClearsOnlyThePseudoTimerSession() throws {
        let (defaults, suite) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let sessionStore = TimerSessionStore(defaults: defaults, processIdentifier: "tutorial-test")
        let viewModel = TimerViewModel(
            studyTime: 25,
            breakTime: 5,
            now: Date.init,
            sessionStore: sessionStore,
            notificationService: TestCoreTutorialNotificationService()
        )
        defaults.set(CoreTutorialStep.reward.rawValue, forKey: CoreTutorialStorageKey.step)
        viewModel.resumeTimer()
        #expect(sessionStore.load() != nil)

        let relaunched = CoreTutorialCoordinator(
            defaults: defaults,
            timerSessionStore: sessionStore
        )

        #expect(relaunched.step == .homeIntro)
        #expect(sessionStore.load() == nil)
    }

    @Test func tutorialTimerCompletesImmediatelyWithoutTickingOrChangingDefaults() throws {
        let (defaults, suite) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("45", forKey: TimerConfigurationStorageKey.pomodoroStudyDuration)
        defaults.set("10", forKey: TimerConfigurationStorageKey.pomodoroBreakDuration)
        defaults.set(4, forKey: TimerConfigurationStorageKey.pomodoroSetCount)
        defaults.set("40", forKey: TimerConfigurationStorageKey.timerDuration)
        let sessionStore = TimerSessionStore(
            defaults: defaults,
            processIdentifier: "tutorial-direct-completion"
        )
        let viewModel = TimerViewModel(
            studyTime: CoreTutorialRewardService.studyMinutes,
            breakTime: PomodoroBreakConfiguration.defaultBreakMinutes,
            totalSets: PomodoroBreakConfiguration.defaultSetCount,
            now: Date.init,
            sessionStore: sessionStore,
            notificationService: TestCoreTutorialNotificationService()
        )
        var completionCount = 0
        viewModel.onStudyFinished = { completionCount += 1 }

        #expect(!viewModel.isRunning)
        #expect(viewModel.completeCoreTutorialStudyWithoutStartingSession())
        #expect(!viewModel.completeCoreTutorialStudyWithoutStartingSession())

        #expect(completionCount == 1)
        #expect(!viewModel.isRunning)
        #expect(viewModel.lastCompletedStudyMinutes == FishRewardService.minimumStudyMinutes)
        #expect(viewModel.state == .completed)
        #expect(viewModel.phase == .finished)
        #expect(sessionStore.load() == nil)
        #expect(defaults.string(forKey: TimerConfigurationStorageKey.pomodoroStudyDuration) == "45")
        #expect(defaults.string(forKey: TimerConfigurationStorageKey.pomodoroBreakDuration) == "10")
        #expect(defaults.integer(forKey: TimerConfigurationStorageKey.pomodoroSetCount) == 4)
        #expect(defaults.string(forKey: TimerConfigurationStorageKey.timerDuration) == "40")
    }

    @Test func tutorialAllowsOnlyAquariumTabAtItsPrompt() {
        for tab in MainAppTab.allCases {
            let canSelect = CoreTutorialTabInteractionPolicy.canSelect(
                tab,
                step: .aquariumIntro,
                conversationIndex: CoreTutorialConversationScript.rewardFollowUp.count - 1,
                selectedTab: .home
            )
            #expect(canSelect == (tab == .aquarium))
        }

        #expect(!CoreTutorialTabInteractionPolicy.canSelect(
            .aquarium,
            step: .aquariumIntro,
            conversationIndex: 0,
            selectedTab: .home
        ))
    }

    @Test func tutorialAllowsOnlyHomeTabAtItsPrompt() {
        for tab in MainAppTab.allCases {
            let canSelect = CoreTutorialTabInteractionPolicy.canSelect(
                tab,
                step: .finishing,
                conversationIndex: CoreTutorialConversationScript.aquariumReturnHome.count - 1,
                selectedTab: .aquarium
            )
            #expect(canSelect == (tab == .home))
        }

        #expect(!CoreTutorialTabInteractionPolicy.canSelect(
            .home,
            step: .finishing,
            conversationIndex: 0,
            selectedTab: .aquarium
        ))
    }

    @Test func rewardIsClownfishNewInactiveAndIdempotentWithoutStatisticsOrDailyCount() throws {
        let (defaults, suite) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(3, forKey: DailyFishAcquisitionStorageKey.count)
        defaults.set(
            DailyFishAcquisitionStore.dayIdentifier(for: Date()),
            forKey: DailyFishAcquisitionStorageKey.dayIdentifier
        )
        let container = try makeContainer()
        let context = ModelContext(container)
        let player = Player(
            totalStudyMinutes: 120,
            todayStudyMinutes: 50,
            yesterdayStudyMinutes: 75,
            coins: 4,
            studyStreakDays: 6
        )
        context.insert(player)
        try context.save()

        let first = try CoreTutorialRewardService.grantIfNeeded(
            to: player,
            in: context,
            defaults: defaults
        )
        let second = try CoreTutorialRewardService.grantIfNeeded(
            to: player,
            in: context,
            defaults: defaults
        )

        #expect(first.species == .clownfish)
        #expect(first.isNewFish)
        #expect(first.showsNewBadge)
        #expect(second.fish.id == first.fish.id)
        #expect(player.ownedFish.count == 1)
        #expect(player.activeAquariumFishIDs.isEmpty)
        #expect(player.hasInitializedActiveAquariumFish)
        #expect(player.coins == 4 + CurrencyService.baseStudyCompletionReward)
        #expect(player.todayStudyMinutes == 50)
        #expect(player.yesterdayStudyMinutes == 75)
        #expect(player.totalStudyMinutes == 120)
        #expect(player.studyStreakDays == 6)
        #expect(player.lastStudyCompletionDate == nil)
        #expect(defaults.integer(forKey: DailyFishAcquisitionStorageKey.count) == 3)
        #expect(defaults.bool(forKey: CoreTutorialStorageKey.hasGrantedReward))
        #expect(defaults.bool(forKey: CoreTutorialStorageKey.hasGrantedPoints))

        let records = try context.fetch(FetchDescriptor<StudyDailyRecord>())
        #expect(records.isEmpty)
    }

    @Test func placementTracksTutorialIndividualAndSaveCompletesPersistently() throws {
        let (defaults, suite) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let container = try makeContainer()
        let context = ModelContext(container)
        let existingClownfish = PlayerFish(species: .clownfish)
        let player = Player(
            ownedFish: [existingClownfish],
            activeAquariumFishIDs: [existingClownfish.id],
            hasInitializedActiveAquariumFish: true
        )
        context.insert(player)
        try context.save()
        let result = try CoreTutorialRewardService.grantIfNeeded(
            to: player,
            in: context,
            defaults: defaults
        )
        let tutorialFishID = try #require(player.coreTutorialRewardFishID)
        #expect(result.fish.id == tutorialFishID)
        #expect(!result.isNewFish)
        #expect(player.activeAquariumFishIDs == [existingClownfish.id])

        let coordinator = CoreTutorialCoordinator(defaults: defaults)
        coordinator.didEnterAquariumEditing(tutorialFishIsActive: false)
        #expect(coordinator.step == .waitingForFishPlacement)
        coordinator.didStartFishDrag(species: .clownfish)
        #expect(!coordinator.shouldShowGhostHand)
        #expect(player.addFishToAquarium(playerFishID: tutorialFishID))
        coordinator.didObserveActiveFishIDs(
            player.activeAquariumFishIDs,
            tutorialFishID: tutorialFishID
        )
        #expect(coordinator.step == .waitingForAquariumSave)

        player.hasSavedCoreTutorialAquarium = true
        try context.save()
        coordinator.didSaveAquarium(with: player)
        #expect(coordinator.step == .finishing)
        coordinator.complete()
        #expect(!coordinator.isActive)
        #expect(defaults.bool(forKey: CoreTutorialStorageKey.hasCompleted))
        #expect(!CoreTutorialCoordinator(defaults: defaults).isActive)
    }

    @Test func previewModeMutatesOnlyItsTemporaryDefaultsAndPlayer() throws {
        let (productionDefaults, productionSuite) = try makeDefaults(prefix: "CoreTutorialProduction")
        let (previewDefaults, previewSuite) = try makeDefaults(prefix: "CoreTutorialPreview")
        defer {
            productionDefaults.removePersistentDomain(forName: productionSuite)
            previewDefaults.removePersistentDomain(forName: previewSuite)
        }
        productionDefaults.set(false, forKey: CoreTutorialStorageKey.hasCompleted)
        productionDefaults.set(4, forKey: DailyFishAcquisitionStorageKey.count)
        previewDefaults.set(true, forKey: CoreTutorialStorageKey.hasCompleted)

        let productionContainer = try makeContainer()
        let productionContext = ModelContext(productionContainer)
        let productionFish = PlayerFish(species: .seahorse)
        let productionPlayer = Player(
            ownedFish: [productionFish],
            activeAquariumFishIDs: [productionFish.id],
            hasInitializedActiveAquariumFish: true,
            totalStudyMinutes: 90,
            todayStudyMinutes: 30,
            coins: 99
        )
        productionContext.insert(productionPlayer)
        try productionContext.save()

        let previewContainer = try makeContainer()
        let previewContext = ModelContext(previewContainer)
        let previewPlayer = Player()
        previewContext.insert(previewPlayer)
        try previewContext.save()
        let coordinator = CoreTutorialCoordinator(
            mode: .preview,
            defaults: previewDefaults,
            timerSessionStore: TimerSessionStore(defaults: previewDefaults)
        )

        #expect(coordinator.isPreviewMode)
        #expect(coordinator.isActive)
        #expect(coordinator.step == .homeIntro)
        let reward = try coordinator.grantRewardIfNeeded(
            to: previewPlayer,
            in: previewContext
        )
        coordinator.didDismissReward()
        let tutorialFishID = try #require(previewPlayer.coreTutorialRewardFishID)
        #expect(previewPlayer.addFishToAquarium(playerFishID: tutorialFishID))
        previewPlayer.hasSavedCoreTutorialAquarium = true
        coordinator.didSaveAquarium(with: previewPlayer)
        coordinator.complete()

        #expect(reward.species == .clownfish)
        #expect(previewPlayer.ownedFish.count == 1)
        #expect(previewPlayer.activeAquariumFishIDs == [tutorialFishID])
        #expect(previewPlayer.coins == CurrencyService.baseStudyCompletionReward)
        #expect(previewPlayer.todayStudyMinutes == 0)
        #expect(previewDefaults.bool(forKey: CoreTutorialStorageKey.hasCompleted))
        #expect(previewDefaults.integer(forKey: DailyFishAcquisitionStorageKey.count) == 0)

        #expect(productionPlayer.ownedFish.map(\.id) == [productionFish.id])
        #expect(productionPlayer.activeAquariumFishIDs == [productionFish.id])
        #expect(productionPlayer.coins == 99)
        #expect(productionPlayer.todayStudyMinutes == 30)
        #expect(productionPlayer.totalStudyMinutes == 90)
        #expect(!productionDefaults.bool(forKey: CoreTutorialStorageKey.hasCompleted))
        #expect(!productionDefaults.bool(forKey: CoreTutorialStorageKey.hasGrantedReward))
        #expect(!productionDefaults.bool(forKey: CoreTutorialStorageKey.hasGrantedPoints))
        #expect(productionDefaults.integer(forKey: DailyFishAcquisitionStorageKey.count) == 4)
    }

    private func makeDefaults(prefix: String = "CoreTutorialTests") throws -> (UserDefaults, String) {
        let suite = "\(prefix).\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        return (defaults, suite)
    }

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Player.self,
            PlayerFish.self,
            StudyDailyRecord.self,
            configurations: configuration
        )
    }
}

private final class TestCoreTutorialNotificationService: TimerNotificationScheduling {
    var notificationsEnabled = false

    func authorizationStatus(_ completion: @escaping @Sendable (NotificationAuthorizationState) -> Void) {
        completion(.denied)
    }
    func requestAuthorization(_ completion: @escaping @Sendable (Bool) -> Void) { completion(false) }
    func scheduleStudyEnd(at date: Date) {}
    func scheduleBreakEnd(at date: Date) {}
    func cancelCurrentSessionNotification() {}
}
