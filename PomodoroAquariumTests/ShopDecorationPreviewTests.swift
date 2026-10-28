import Foundation
import SwiftData
import SwiftUI
import Testing
import UIKit
@testable import PomodoroAquarium

@MainActor
struct ShopDecorationPreviewTests {
    private func fixture() throws -> (ModelContainer, Player, [AquariumDecorationPlacement]) {
        let container = try ModelContainer(for: Player.self, PlayerFish.self, AquariumDecorationPlacement.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let fish = PlayerFish(species: .clownfish)
        let player = Player(ownedFish: [fish, PlayerFish(species: .orca)],
            activeAquariumFishIDs: [fish.id], hasInitializedActiveAquariumFish: true, coins: 0)
        let rock = AquariumDecorationPlacement(decorationID: "saved-rock", kind: .mediumRockB,
            relativeX: 0.2, relativeY: 0.86, scale: 1.2, isPlaced: true, zOrder: 17,
            rockIsForeground: true, isStackingOrderInitialized: true)
        let plant = AquariumDecorationPlacement(decorationID: "saved-plant", kind: .seaweedB,
            relativeX: 0.75, relativeY: 0.9, scale: 0.9, isPlaced: true, zOrder: 22)
        let stored = AquariumDecorationPlacement(kind: .treasureChest,
            relativeX: 0.5, relativeY: 0.92, scale: 1, isPlaced: false, facingDirection: .left)
        container.mainContext.insert(player)
        let placements = [rock, plant, stored]
        placements.forEach { container.mainContext.insert($0) }
        try container.mainContext.save()
        return (container, player, placements)
    }

    @Test(arguments: [AquariumDecorationKind.seaweedA, .treasureChest, .shipwreck])
    func trialUsesOnlySavedCopiesAndCannotChangeProduction(kind: AquariumDecorationKind) throws {
        let (production, player, placements) = try fixture()
        let initial = AquariumEditorSessionSnapshot.capture(player: player,
            decorationPlacements: placements, backgroundTheme: .deepSea)
        let item = try #require(ShopCatalog.items.first { $0.content == .decoration(kind) })
        let flow = ShopPurchaseFlow()
        flow.requestConfirmation(for: item)
        let sourceSession = AquariumFishViewingSession()
        let fishID = try #require(player.activeAquariumFishIDs.first)
        let sourceOwner = UUID()
        let motion = AquariumFishMotion.initialState(for: fishID, initialPosition: CGPoint(x: 0.4, y: 0.4))
        let originalSwim = sourceSession.claim(fishID, owner: sourceOwner,
            initial: .init(motion: motion, direction: .init(direction: motion.facingDirection), wing: nil, elapsedTime: 9),
            bounds: .legacy)

        let preview = try ShopDecorationPreviewSession(item: item, official: player, placements: placements,
            backgroundTheme: .deepSea, fishViewingSession: sourceSession)
        #expect(preview.backgroundTheme == .deepSea)
        #expect(preview.placements.count == 3 && preview.trial.kind == kind && preview.trial.isPlaced)
        #expect(preview.working.player !== player && preview.working.player.modelContext == nil)
        #expect(preview.working.player.ownedFish.map(\.id) == [fishID])
        #expect(preview.working.player.ownedFish[0] !== player.ownedFish[0])
        #expect(preview.working.player.ownedFish[0].modelContext == nil)
        let normalDraft = AquariumEditorDraft(player: player,
            placements: placements.filter(\.isPlaced), background: .deepSea)
        let normalWorking = AquariumEditorWorkingState(official: player,
            placements: placements.filter(\.isPlaced), draft: normalDraft)
        for original in placements where original.isPlaced {
            let copy = try #require(preview.working.placements.first { $0.decorationID == original.decorationID })
            let normalCopy = try #require(normalWorking.placements.first { $0.decorationID == original.decorationID })
            #expect(copy !== original && copy.modelContext == nil)
            #expect(AquariumDecorationEditorState(copy) == AquariumDecorationEditorState(normalCopy))
        }
        if kind == .shipwreck {
            preview.placeShipwreck(on: .left)
            #expect(preview.trial.facingDirection == .left)
            preview.placeShipwreck(on: .right)
            #expect(preview.trial.facingDirection == .right)
            #expect(preview.placements.filter { $0.kind == .shipwreck && $0.isPlaced }.count == 1)
        } else {
            let original = CGPoint(x: preview.trial.relativeX, y: preview.trial.relativeY)
            let moved = AquariumDecorationEditor.relativePosition(originalX: original.x, originalY: original.y,
                translation: CGSize(width: 35, height: -30), aquariumSize: CGSize(width: 393, height: 852),
                kind: kind, isEditing: true, scale: 1)
            try AquariumDecorationService.confirmPlacement(preview.trial, at: moved,
                in: preview.modelContainer.mainContext, persistChanges: false)
            #expect(CGPoint(x: preview.trial.relativeX, y: preview.trial.relativeY) != original)
            preview.changeFacing()
            #expect(preview.trial.facingDirection == (kind.supportsFacingDirection ? .left : .right))
        }
        #expect(preview.trial.modelContext == nil)
        #expect(try preview.modelContainer.mainContext.fetchCount(FetchDescriptor<AquariumDecorationPlacement>()) == 0)
        #expect(preview.modelContainer.mainContext.hasChanges == false)

        // 同じ個体IDでも、プレビューの更新権・位置・位相は本番から独立している。
        let previewOwner = UUID()
        var swim = preview.fishViewingSession.claim(fishID, owner: previewOwner,
            initial: originalSwim, bounds: .legacy)
        #expect(swim.motion.position == originalSwim.motion.position && swim.elapsedTime == 9)
        swim.motion.position.x += 0.1
        swim.elapsedTime += 2
        #expect(preview.fishViewingSession.update(fishID, owner: previewOwner, snapshot: swim))
        #expect(sourceSession.isOwner(fishID, owner: sourceOwner))
        #expect(sourceSession.snapshot(for: fishID)?.motion.position == originalSwim.motion.position)
        #expect(sourceSession.snapshot(for: fishID)?.elapsedTime == 9)
        #expect(preview.fishViewingSession !== sourceSession)

        #expect(flow.confirmation == item && flow.feedback == nil)
        #expect(player.coins == 0 && player.ownedFish.count == 2)
        #expect(!initial.hasChanges(player: player, decorationPlacements: placements, backgroundTheme: .deepSea))
        #expect(player.modelContext === production.mainContext)
        try production.mainContext.save()
        let reloaded = ModelContext(production)
        #expect(try reloaded.fetchCount(FetchDescriptor<AquariumDecorationPlacement>()) == 3)
        let savedPlayer = try #require(reloaded.fetch(FetchDescriptor<Player>()).first)
        let savedPlacements = try reloaded.fetch(FetchDescriptor<AquariumDecorationPlacement>())
        #expect(!initial.hasChanges(player: savedPlayer, decorationPlacements: savedPlacements, backgroundTheme: .deepSea))
        #expect(savedPlayer.coins == 0)
        let reopened = try ShopDecorationPreviewSession(item: item, official: player, placements: placements,
            backgroundTheme: .deepSea, fishViewingSession: sourceSession)
        #expect(reopened.trial.decorationID != preview.trial.decorationID)
        #expect(CGPoint(x: reopened.trial.relativeX, y: reopened.trial.relativeY) == kind.restorationPosition)
    }

    @Test func nudgeAndAllStackingActionsUseOnlyThePreviewCopies() throws {
        let (production, player, placements) = try fixture()
        let before = AquariumEditorSessionSnapshot.capture(player: player,
            decorationPlacements: placements, backgroundTheme: .deepSea)
        let item = try #require(ShopCatalog.items.first { $0.content == .decoration(.treasureChest) })
        let preview = try ShopDecorationPreviewSession(item: item, official: player, placements: placements,
            backgroundTheme: .deepSea, fishViewingSession: nil)
        let rock = try #require(preview.working.placements.first { $0.decorationID == "saved-rock" })
        let canvas = CGSize(width: 393, height: 852)
        try AquariumDecorationService.confirmPlacement(preview.trial,
            at: CGPoint(x: rock.relativeX, y: rock.relativeY), in: preview.modelContainer.mainContext, persistChanges: false)
        for delta in [CGSize(width: -8, height: 0), CGSize(width: 8, height: 0),
                      CGSize(width: 0, height: -8), CGSize(width: 0, height: 8)] {
            let original = CGPoint(x: preview.trial.relativeX, y: preview.trial.relativeY)
            let next = AquariumDecorationEditor.relativePosition(originalX: original.x, originalY: original.y,
                translation: delta, aquariumSize: canvas, kind: .treasureChest, isEditing: true, scale: 1)
            try AquariumDecorationService.confirmPlacement(preview.trial, at: next,
                in: preview.modelContainer.mainContext, persistChanges: false)
            #expect(abs((preview.trial.relativeX - original.x) * canvas.width - delta.width) < 0.000_001)
            #expect(abs((preview.trial.relativeY - original.y) * canvas.height - delta.height) < 0.000_001)
        }
        let members = AquariumDecorationOverlapGroups.members(of: preview.trial.decorationID,
            placements: preview.placements, size: canvas, theme: .deepSea)
        #expect(members.contains(rock.decorationID))
        #expect(!members.contains("saved-plant"))
        let initialRockOrder = rock.zOrder
        for action in [AquariumDecorationStacking.Action.back, .forward, .backward, .front] {
            #expect(AquariumDecorationStacking.canMove(preview.trial, action: action,
                among: preview.placements, within: members))
            let changed = AquariumDecorationStacking.move(preview.trial, action: action,
                among: preview.placements, within: members)
            #expect(changed)
            let behind = action == .back || action == .backward
            #expect(AquariumDecorationStacking.isBehind(preview.trial.decoration, rock.decoration) == behind)
            if behind { #expect(rock.zOrder != initialRockOrder) }
        }
        #expect(!before.hasChanges(player: player, decorationPlacements: placements, backgroundTheme: .deepSea))
        #expect(player.coins == 0 && player.ownedFish.count == 2)
        #expect(!production.mainContext.hasChanges)
        #expect(!preview.modelContainer.mainContext.hasChanges)
        #expect(try preview.modelContainer.mainContext.fetchCount(FetchDescriptor<AquariumDecorationPlacement>()) == 0)
    }

    @Test func realAquariumStartupAndClosingLeaveDraftFlagsAndProductionUntouched() async throws {
        let (production, player, placements) = try fixture()
        let before = AquariumEditorSessionSnapshot.capture(player: player, decorationPlacements: placements, backgroundTheme: .tropical)
        let draftURL = AquariumEditorDraftStore.standard.url
        let draftBytes = try? Data(contentsOf: draftURL)
        let keys = [AquariumThemeStore.storageKey, DecorationPurchaseTutorial.storageKey,
                    AquariumEditorTutorialState.storageKey, CoreTutorialStorageKey.hasCompleted]
        let values = keys.map { UserDefaults.standard.object(forKey: $0) as? NSObject }
        let item = try #require(ShopCatalog.items.first { $0.content == .decoration(.treasureChest) })
        let preview = try ShopDecorationPreviewSession(item: item, official: player, placements: placements,
            backgroundTheme: .tropical, fishViewingSession: nil)
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let host = UIHostingController(rootView: ShopDecorationPreviewView(session: preview))
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        window.rootViewController = host
        window.isHidden = false
        defer { window.isHidden = true; window.rootViewController = nil }
        for _ in 0..<5 {
            host.view.layoutIfNeeded()
            try await Task.sleep(for: .milliseconds(50))
        }
        preview.changeFacing()
        window.isHidden = true
        window.rootViewController = nil
        await Task.yield()
        #expect(try preview.modelContainer.mainContext.fetchCount(FetchDescriptor<AquariumDecorationPlacement>()) == 0)
        #expect(try preview.modelContainer.mainContext.fetchCount(FetchDescriptor<Player>()) == 0)
        #expect(!before.hasChanges(player: player, decorationPlacements: placements, backgroundTheme: .tropical))
        #expect(player.coins == 0 && player.modelContext === production.mainContext)
        #expect((try? Data(contentsOf: draftURL)) == draftBytes)
        #expect(keys.map { UserDefaults.standard.object(forKey: $0) as? NSObject } == values)
    }
}
