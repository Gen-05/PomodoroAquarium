import CoreGraphics
import Foundation
import SwiftData
import Testing
@testable import PomodoroAquarium

@MainActor
struct AquariumSideEditorTests {
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

    @Test func backgroundDragResolvesAndExistingStorePersistsSelection() throws {
        let item = AquariumEditorDragItem.background(.deepSea)
        let theme = try #require(AquariumEditorDropCoordinator.backgroundTheme(from: item))
        let suiteName = "AquariumSideEditorTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        AquariumThemeStore(defaults: defaults).save(theme)

        #expect(AquariumThemeStore(defaults: defaults).selectedTheme == .deepSea)
        #expect(AquariumEditorDropCoordinator.backgroundTheme(
            from: .fish(.clownfish)
        ) == nil)
    }

    private func makeDecorationContainer() throws -> ModelContainer {
        try ModelContainer(
            for: AquariumDecorationPlacement.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }
}
