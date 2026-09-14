import CoreGraphics
import Foundation
import SwiftData
import Testing
@testable import PomodoroAquarium

@MainActor
struct AquariumSideEditorTests {
    @Test func viewingControlsAutoHideIsLimitedToAquariumViewing() {
        #expect(AquariumViewingControlsPolicy.autoHideDelay == 4)
        #expect(AquariumViewingControlsPolicy.isEnabled(selectedTab: .aquarium, tabMode: .viewing))
        #expect(!AquariumViewingControlsPolicy.isEnabled(selectedTab: .aquarium, tabMode: .editing))
        #expect(!AquariumViewingControlsPolicy.isEnabled(selectedTab: .home, tabMode: .viewing))
        #expect(!AquariumViewingControlsPolicy.isEnabled(selectedTab: .shop, tabMode: .viewing))
        #expect(!AquariumViewingControlsPolicy.isEnabled(selectedTab: .statistics, tabMode: .viewing))
        #expect(!AquariumViewingControlsPolicy.isEnabled(selectedTab: .more, tabMode: .viewing))

        #expect(!AquariumViewingControlsPolicy.shouldShowBottomTabBar(
            selectedTab: .aquarium,
            tabMode: .viewing,
            areControlsVisible: false
        ))
        #expect(AquariumViewingControlsPolicy.shouldShowBottomTabBar(
            selectedTab: .aquarium,
            tabMode: .viewing,
            areControlsVisible: true
        ))
        #expect(AquariumViewingControlsPolicy.shouldShowBottomTabBar(
            selectedTab: .aquarium,
            tabMode: .editing,
            areControlsVisible: false
        ))
        #expect(AquariumViewingControlsPolicy.shouldShowBottomTabBar(
            selectedTab: .home,
            tabMode: .viewing,
            areControlsVisible: false
        ))
    }

    @Test func sidePanelUsesAboutOneThirdOfPhoneWidthWithoutCoveringHalf() {
        let compactWidth = AquariumSideEditorLayout.width(for: 320)
        let regularWidth = AquariumSideEditorLayout.width(for: 390)
        let widePhoneWidth = AquariumSideEditorLayout.width(for: 430)

        #expect(compactWidth == AquariumSideEditorLayout.minimumWidth)
        #expect(abs(regularWidth - 140.4) < 0.001)
        #expect(abs(widePhoneWidth - 154.8) < 0.001)
        #expect(regularWidth < 390 / 2)
        #expect(AquariumSideEditorLayout.width(for: 768) == AquariumSideEditorLayout.maximumWidth)
    }

    @Test func sidePanelOccupiesTheRightEdgeAndLeavesTheAquariumOnTheLeft() {
        let screenWidth: CGFloat = 390
        let panelWidth = AquariumSideEditorLayout.width(for: screenWidth)
        let panelMinX = AquariumSideEditorLayout.panelMinX(for: screenWidth)
        let aquariumWidth = AquariumSideEditorLayout.aquariumWidth(
            for: screenWidth,
            isEditing: true
        )

        #expect(abs(panelMinX - aquariumWidth) < 0.000_001)
        #expect(abs(panelMinX + panelWidth - screenWidth) < 0.000_001)
        #expect(aquariumWidth > screenWidth / 2)
        #expect(AquariumSideEditorLayout.aquariumWidth(
            for: screenWidth,
            isEditing: false
        ) == screenWidth)
    }

    @Test func collapsedPanelLeavesOnlyAThinHandleAndMoreAquariumVisible() {
        let screenWidth: CGFloat = 390
        let expandedWidth = AquariumSideEditorLayout.aquariumWidth(
            for: screenWidth,
            isEditing: true,
            isPanelExpanded: true
        )
        let collapsedWidth = AquariumSideEditorLayout.aquariumWidth(
            for: screenWidth,
            isEditing: true,
            isPanelExpanded: false
        )

        #expect(AquariumSideEditorLayout.collapsedHandleWidth == 38)
        #expect(AquariumSideEditorLayout.collapsedHandleHeight == 88)
        #expect(collapsedWidth == screenWidth)
        #expect(collapsedWidth > expandedWidth)
        #expect(collapsedWidth > screenWidth * 0.99)
    }

    @Test func aquariumEditorTutorialIsPresentedOnlyUntilMarkedSeen() throws {
        let suiteName = "AquariumEditorTutorialTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        #expect(AquariumEditorTutorialState.shouldPresent(in: defaults))
        AquariumEditorTutorialState.markSeen(in: defaults)
        #expect(!AquariumEditorTutorialState.shouldPresent(in: defaults))
    }

    @Test func manualTutorialRequestsDoNotResetTheSeenPreference() throws {
        let suiteName = "AquariumEditorManualTutorialTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        AquariumEditorTutorialState.markSeen(in: defaults)

        // 手動表示はViewの表示Stateだけを変え、保存フラグには触れない。
        #expect(!AquariumEditorTutorialState.shouldPresent(in: defaults))
        #expect(defaults.bool(forKey: AquariumEditorTutorialState.storageKey))
    }

    @Test func pendingTabSelectionKeepsDirtyStateUntilSaveOrDiscardFinishes() {
        let coordinator = AquariumEditorNavigationCoordinator()
        #expect(coordinator.tabMode == .viewing)
        coordinator.beginSession()
        #expect(coordinator.tabMode == .editing)
        #expect(!coordinator.hasUnsavedChanges)

        coordinator.markChanged()
        coordinator.requestConfirmation(beforeSelecting: .shop)
        #expect(coordinator.hasUnsavedChanges)
        #expect(coordinator.pendingTabSelection == .shop)
        #expect(coordinator.confirmationRequestID != nil)

        coordinator.continueEditing()
        #expect(coordinator.hasUnsavedChanges)
        #expect(coordinator.pendingTabSelection == nil)

        coordinator.requestConfirmation(beforeSelecting: .statistics)
        coordinator.finishSession()
        #expect(coordinator.tabMode == .viewing)
        #expect(!coordinator.hasUnsavedChanges)
        #expect(coordinator.pendingTabSelection == nil)
        #expect(coordinator.confirmationRequestID == nil)
    }

    @Test func doneConfirmationStaysOnAquariumWhileTabConfirmationKeepsDestination() {
        let coordinator = AquariumEditorNavigationCoordinator()
        coordinator.beginSession()
        coordinator.markChanged()

        coordinator.requestFinishConfirmation()
        #expect(coordinator.tabMode == .editing)
        #expect(coordinator.pendingTabSelection == nil)
        #expect(coordinator.confirmationRequestID != nil)

        coordinator.continueEditing()
        coordinator.requestConfirmation(beforeSelecting: .more)
        #expect(coordinator.pendingTabSelection == .more)
    }

    @Test func studyLockTakesPriorityOverAquariumUnsavedChangeConfirmation() {
        #expect(MainTabNavigationPolicy.requiresAquariumSaveConfirmation(
            from: .aquarium,
            to: .shop,
            whileStudyLocked: false,
            hasUnsavedAquariumChanges: true
        ))
        #expect(!MainTabNavigationPolicy.requiresAquariumSaveConfirmation(
            from: .aquarium,
            to: .shop,
            whileStudyLocked: true,
            hasUnsavedAquariumChanges: true
        ))
        #expect(!MainTabNavigationPolicy.requiresAquariumSaveConfirmation(
            from: .aquarium,
            to: .home,
            whileStudyLocked: true,
            hasUnsavedAquariumChanges: true
        ))
        #expect(!MainTabNavigationPolicy.requiresAquariumSaveConfirmation(
            from: .aquarium,
            to: .shop,
            whileStudyLocked: false,
            hasUnsavedAquariumChanges: false
        ))
        #expect(!MainTabNavigationPolicy.requiresAquariumSaveConfirmation(
            from: .home,
            to: .shop,
            whileStudyLocked: false,
            hasUnsavedAquariumChanges: true
        ))
    }

    @Test func editorSnapshotDetectsAndRestoresFishDecorationAndBackgroundChanges() {
        let firstFish = PlayerFish(species: .clownfish)
        let secondFish = PlayerFish(species: .manta)
        let player = Player(
            ownedFish: [firstFish, secondFish],
            activeAquariumFishIDs: [firstFish.id],
            hasInitializedActiveAquariumFish: true
        )
        let placement = AquariumDecorationPlacement(
            decorationID: "snapshot-rock",
            kind: .rock,
            relativeX: 0.25,
            relativeY: 0.8,
            scale: 1.1,
            isPlaced: true
        )
        let snapshot = AquariumEditorSessionSnapshot.capture(
            player: player,
            decorationPlacements: [placement],
            backgroundTheme: .aquarium
        )

        player.activeAquariumFishIDs = [secondFish.id]
        placement.relativeX = 0.7
        placement.relativeY = 0.6
        placement.scale = 0.8
        placement.isPlaced = false

        #expect(snapshot.hasChanges(
            player: player,
            decorationPlacements: [placement],
            backgroundTheme: .deepSea
        ))

        snapshot.restore(player: player, decorationPlacements: [placement])

        #expect(player.activeAquariumFishIDs == [firstFish.id])
        #expect(placement.relativeX == 0.25)
        #expect(placement.relativeY == 0.8)
        #expect(placement.scale == 1.1)
        #expect(placement.isPlaced)
        #expect(!snapshot.hasChanges(
            player: player,
            decorationPlacements: [placement],
            backgroundTheme: .aquarium
        ))
    }

    @Test func deferredDecorationEditingUpdatesPreviewWithoutPersistingImmediately() throws {
        let container = try makeDecorationContainer()
        let context = ModelContext(container)
        let placement = AquariumDecorationPlacement(
            decorationID: "draft-seaweed",
            kind: .seaweed,
            relativeX: 0.1,
            relativeY: 0.8,
            scale: 1,
            isPlaced: false
        )
        context.insert(placement)
        try context.save()

        try AquariumDecorationService.confirmPlacement(
            placement,
            at: CGPoint(x: 0.4, y: 0.7),
            in: context,
            persistChanges: false
        )

        #expect(placement.isPlaced)
        #expect(placement.relativeX == 0.4)

        let persistedContext = ModelContext(container)
        let persistedPlacement = try #require(
            persistedContext.fetch(FetchDescriptor<AquariumDecorationPlacement>()).first
        )
        #expect(!persistedPlacement.isPlaced)
        #expect(persistedPlacement.relativeX == 0.1)
    }

    @Test func editorHasFishDecorationAndBackgroundCategories() {
        #expect(AquariumEditorCategory.allCases == [.fish, .decoration, .background])
    }

    @Test func aquariumDropAreaExcludesTopAndBottomControls() {
        let size = CGSize(width: 250, height: 800)

        #expect(!AquariumSideEditorLayout.acceptsDrop(at: CGPoint(x: 120, y: 30), in: size))
        #expect(AquariumSideEditorLayout.acceptsDrop(at: CGPoint(x: 120, y: 400), in: size))
        #expect(!AquariumSideEditorLayout.acceptsDrop(at: CGPoint(x: 120, y: 760), in: size))
        #expect(!AquariumSideEditorLayout.acceptsDrop(at: CGPoint(x: -1, y: 400), in: size))
    }

    @Test func fishDragStartsOnlyForLeftwardHorizontalMovement() {
        #expect(AquariumFishDragInteraction.minimumDistance == 6)
        #expect(AquariumFishDragInteraction.intent(
            for: CGSize(width: -12, height: 3)
        ) == .aquarium)
        #expect(AquariumFishDragInteraction.intent(
            for: CGSize(width: -5, height: 14)
        ) == .scrolling)
        #expect(AquariumFishDragInteraction.intent(
            for: CGSize(width: 14, height: 2)
        ) == .scrolling)
    }

    @Test func fishDragPreviewUsesAquariumScaleWithATransparentFriendlySizeCap() {
        #expect(AquariumFishDragPresentation.previewSize(for: .clownfish) == 44)
        #expect(abs(
            AquariumFishDragPresentation.previewSize(for: .pufferfish) -
                AquariumFishSizing.displaySize(for: .pufferfish, isFavorite: false)
        ) < 0.000_001)
        #expect(AquariumFishDragPresentation.previewSize(for: .whaleShark) == 180)

        for species in FishSpecies.allCases {
            #expect(AquariumFishDragPresentation.frameDuration(for: species) > 0)
        }
    }

    @Test func customFishDragAddsOnlyWhenItEndsInsideTheAquarium() {
        let fish = PlayerFish(species: .clownfish)
        let player = Player(
            ownedFish: [fish],
            activeAquariumFishIDs: [],
            hasInitializedActiveAquariumFish: true
        )
        let aquariumSize = CGSize(width: 250, height: 800)
        _ = AquariumFishDragSession(
            species: .clownfish,
            location: CGPoint(x: 200, y: 400)
        )

        #expect(player.activeAquariumFishIDs.isEmpty)
        #expect(!AquariumEditorDropCoordinator.completeFishDrag(
            species: .clownfish,
            at: CGPoint(x: 270, y: 400),
            aquariumSize: aquariumSize,
            player: player
        ))
        #expect(player.activeAquariumFishIDs.isEmpty)
        #expect(AquariumEditorDropCoordinator.completeFishDrag(
            species: .clownfish,
            at: CGPoint(x: 200, y: 400),
            aquariumSize: aquariumSize,
            player: player
        ))
        #expect(player.activeAquariumFishIDs == [fish.id])
    }

    @Test func fishDragAddsOneOwnedIndividualAndUpdatesActiveIDs() {
        let fish = PlayerFish(species: .clownfish)
        let player = Player(
            ownedFish: [fish],
            activeAquariumFishIDs: [],
            hasInitializedActiveAquariumFish: true
        )

        #expect(AquariumEditorDropCoordinator.addFish(
            from: .fish(.clownfish),
            to: player
        ))
        #expect(player.activeAquariumFishIDs == [fish.id])
        #expect(player.aquariumCount(for: .clownfish) == 1)
        #expect(!AquariumEditorDropCoordinator.addFish(
            from: .fish(.clownfish),
            to: player
        ))
    }

    @Test func fishDragRejectsUnownedSpeciesAndEleventhFish() {
        let fish = (0...AquariumDisplayLimits.maxFishCount).map { index in
            PlayerFish(species: index == AquariumDisplayLimits.maxFishCount ? .manta : .clownfish)
        }
        let player = Player(
            ownedFish: fish,
            activeAquariumFishIDs: fish.prefix(AquariumDisplayLimits.maxFishCount).map(\.id),
            hasInitializedActiveAquariumFish: true
        )

        #expect(!AquariumEditorDropCoordinator.addFish(from: .fish(.manta), to: player))
        #expect(player.activeAquariumFish.count == AquariumDisplayLimits.maxFishCount)

        let emptyPlayer = Player(
            activeAquariumFishIDs: [],
            hasInitializedActiveAquariumFish: true
        )
        #expect(!AquariumEditorDropCoordinator.addFish(
            from: .fish(.jellyfish),
            to: emptyPlayer
        ))
    }

    @Test func decorationDropUsesOnlyAquariumLocalCoordinatesAndPersists() throws {
        let container = try makeDecorationContainer()
        let context = ModelContext(container)
        let placement = AquariumDecorationPlacement(
            decorationID: "dragged-rock",
            kind: .rock,
            relativeX: 0.2,
            relativeY: 0.75,
            scale: 1,
            isPlaced: false
        )
        context.insert(placement)
        try context.save()

        try AquariumEditorDropCoordinator.placeDecoration(
            from: .decoration(id: placement.decorationID),
            placement: placement,
            at: CGPoint(x: 210, y: 720),
            aquariumSize: CGSize(width: 300, height: 800),
            in: context
        )

        let restoredContext = ModelContext(container)
        let restored = try #require(
            restoredContext.fetch(FetchDescriptor<AquariumDecorationPlacement>()).first
        )
        #expect(restored.isPlaced)
        #expect(abs(restored.relativeX - 0.7) < 0.000_001)
        #expect(abs(restored.relativeY - 0.9) < 0.000_001)
    }

    @Test func proportionalDecorationDropsAreIndependentOfPanelAndAquariumWidth() {
        let first = AquariumDecorationEditor.relativePosition(
            forDropLocation: CGPoint(x: 150, y: 720),
            aquariumSize: CGSize(width: 300, height: 800),
            kind: .rock
        )
        let second = AquariumDecorationEditor.relativePosition(
            forDropLocation: CGPoint(x: 125, y: 720),
            aquariumSize: CGSize(width: 250, height: 800),
            kind: .rock
        )

        #expect(abs(first.x - second.x) < 0.000_001)
        #expect(abs(first.y - second.y) < 0.000_001)
    }

    @Test func decorationDropRejectsARequestForAnotherIndividual() throws {
        let container = try makeDecorationContainer()
        let context = ModelContext(container)
        let placement = AquariumDecorationPlacement(
            decorationID: "owned-rock",
            kind: .rock,
            relativeX: 0.2,
            relativeY: 0.75,
            scale: 1,
            isPlaced: false
        )
        context.insert(placement)

        #expect(throws: (any Error).self) {
            try AquariumEditorDropCoordinator.placeDecoration(
                from: .decoration(id: "different-rock"),
                placement: placement,
                at: CGPoint(x: 150, y: 700),
                aquariumSize: CGSize(width: 300, height: 800),
                in: context
            )
        }
        #expect(!placement.isPlaced)
    }

    @Test func tappedBackgroundUsesExistingStoreWhenTheEditorIsSaved() throws {
        let theme = AquariumBackgroundTheme.deepSea
        let suiteName = "AquariumSideEditorTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        AquariumThemeStore(defaults: defaults).save(theme)

        #expect(AquariumThemeStore(defaults: defaults).selectedTheme == .deepSea)
    }

    @Test func decorationDragUsesTheFishDragThresholdAndDirectionRule() {
        #expect(AquariumFishDragInteraction.minimumDistance == 6)
        #expect(AquariumFishDragInteraction.intent(
            for: CGSize(width: -14, height: 2)
        ) == .aquarium)
        #expect(AquariumFishDragInteraction.intent(
            for: CGSize(width: -3, height: 14)
        ) == .scrolling)

        let session = AquariumDecorationDragSession(
            decorationID: "stored-rock",
            location: CGPoint(x: 120, y: 480)
        )
        #expect(session.decorationID == "stored-rock")
    }

    private func makeDecorationContainer() throws -> ModelContainer {
        try ModelContainer(
            for: AquariumDecorationPlacement.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }
}
