#if DEBUG
import Foundation
import SwiftData
import SwiftUI
import UIKit
import Testing
@testable import PomodoroAquarium

@MainActor
struct DecorationTutorialPreviewTests {
    /// ショップと同じ確認→確定→結果を通し、結果を閉じてから案内へ進む。
    private func purchaseTreasureChest(in session: DecorationTutorialPreviewSession) throws {
        let context = session.modelContainer.mainContext
        let player = try #require(context.fetch(FetchDescriptor<Player>()).first)
        let item = try #require(DecorationTutorialPreviewSession.products.first { $0.content == .decoration(.treasureChest) })
        let coins = player.coins
        let flow = ShopPurchaseFlow()
        flow.requestConfirmation(for: item)
        #expect(flow.confirmation == item && player.coins == coins && session.tutorial.phase == .idle)
        flow.confirm(player: player, in: context, tutorial: session.tutorial)
        #expect(player.coins == coins - item.price && session.tutorial.phase == .waitingForFeedback)
        flow.confirmationDidDismiss()
        #expect(flow.feedback?.message == "\(item.name)を購入しました")
        #expect(session.tutorial.phase == .waitingForFeedback)
        flow.feedback = nil
        flow.feedbackDidDismiss(tutorial: session.tutorial)
        #expect(session.tutorial.phase == .invitation)
    }

    @Test func eachOpeningStartsBeforePurchaseWithIndependentResources() throws {
        let first = try DecorationTutorialPreviewSession()
        let second = try DecorationTutorialPreviewSession()
        defer { first.cleanUp(); second.cleanUp() }
        #expect(first.suiteName != second.suiteName)
        #expect(first.draftStore.url != second.draftStore.url)
        #expect(first.fishViewingSession !== second.fishViewingSession)
        #expect(first.modelContainer !== second.modelContainer)
        for session in [first, second] {
            let context = session.modelContainer.mainContext
            let player = try #require(try context.fetch(FetchDescriptor<Player>()).first)
            let placements = try context.fetch(FetchDescriptor<AquariumDecorationPlacement>())
            #expect(player.coins == 10_000)
            #expect(player.ownedFish.count == 1)
            #expect(placements.count == 2)
            #expect(placements.filter(\.isPlaced).map(\.kind) == [.smallRockA])
            #expect(session.tutorial.phase == .idle && session.tutorial.placementID == nil)
            #expect(!session.tutorial.isPurchaseFeedbackVisible)
            #expect(!session.defaults.bool(forKey: DecorationPurchaseTutorial.storageKey))
            #expect(!placements.contains { $0.kind == .treasureChest })
            #expect(DecorationTutorialPreviewSession.products == ShopCatalog.items(in: .decoration))
            #expect(DecorationTutorialPreviewSession.products.allSatisfy { $0.price <= player.coins })
            #expect(try context.fetchCount(FetchDescriptor<RewardHistoryEntry>()) == 0)
            #expect(try context.fetchCount(FetchDescriptor<StudyDailyRecord>()) == 0)
            #expect(try context.fetchCount(FetchDescriptor<FocusSessionRecord>()) == 0)
            #expect(try session.draftStore.load() == nil)
            let core = CoreTutorialCoordinator(mode: .decorationPreview, defaults: session.defaults,
                timerSessionStore: session.timerSessionStore)
            #expect(!core.isActive && core.isPreviewMode)
            #expect(AquariumEditorLaunchPolicy.canRestore(mode: .decorationPreview, defaults: session.defaults))
        }
        try purchaseTreasureChest(in: first)
        first.tutorial.dismiss()
        let player = try #require(try first.modelContainer.mainContext.fetch(FetchDescriptor<Player>()).first)
        let seaweed = try #require(DecorationTutorialPreviewSession.products.first { $0.content == .decoration(.seaweedA) })
        try first.tutorial.purchase(seaweed, player: player, in: first.modelContainer.mainContext)
        first.tutorial.purchaseFeedbackDidDismiss()
        #expect(first.tutorial.phase == .idle && player.coins == 9_470)
        #expect(second.tutorial.phase == .idle)
        try purchaseTreasureChest(in: second)
        #expect(second.tutorial.phase == .invitation)
    }

    @Test func isolatedPurchaseEditSaveAndCleanupLeaveProductionValuesAndHistoryUntouched() throws {
        let suite = "ProductionDecorationPreviewTest.\(UUID())"
        let productionDefaults = try #require(UserDefaults(suiteName: suite))
        defer { productionDefaults.removePersistentDomain(forName: suite) }
        productionDefaults.set(true, forKey: DecorationPurchaseTutorial.storageKey)
        productionDefaults.set(false, forKey: AquariumEditorTutorialState.storageKey)
        productionDefaults.set(AquariumBackgroundTheme.deepSea.rawValue, forKey: AquariumThemeStore.storageKey)
        let beforeDefaults = productionDefaults.persistentDomain(forName: suite)! as NSDictionary
        let production = try ModelContainer(for: Player.self, PlayerFish.self, AquariumDecorationPlacement.self,
            RewardHistoryEntry.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let player = Player(ownedFish: [PlayerFish(species: .dolphin)], coins: 432)
        let rock = AquariumDecorationPlacement(kind: .mediumRockB, relativeX: 0.2, relativeY: 0.91,
            scale: 1.2, isPlaced: true, zOrder: 17, isStackingOrderInitialized: true)
        production.mainContext.insert(player); production.mainContext.insert(rock)
        let historyEntry = RewardHistoryEntry(fishID: player.ownedFish[0].id, fishSpecies: .dolphin,
            fishName: "イルカ", rarity: .epic, fishCountDelta: 1, pointDelta: 10,
            wasNewFish: true, previousOwnedCount: 0, currentOwnedCount: 1)
        production.mainContext.insert(historyEntry)
        let originalHistory = RewardHistorySnapshot(entry: historyEntry)
        try production.mainContext.save()
        var productionDraft = AquariumEditorDraft(player: player, placements: [rock], background: .deepSea)
        productionDraft.history = AquariumEditorHistory(initial: productionDraft)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ProductionDraft-\(UUID()).json")
        let productionStore = AquariumEditorDraftStore(url: url)
        try productionStore.save(productionDraft)
        defer { try? productionStore.remove() }
        let originalDraftBytes = try Data(contentsOf: url)
        let originalIDs = player.ownedFish.map(\.id)

        let preview = try DecorationTutorialPreviewSession()
        defer { preview.cleanUp() }
        let context = preview.modelContainer.mainContext
        let previewPlayer = try #require(try context.fetch(FetchDescriptor<Player>()).first)
        try purchaseTreasureChest(in: preview)
        let placements = try context.fetch(FetchDescriptor<AquariumDecorationPlacement>())
        let purchased = try #require(placements.first { $0.decorationID == preview.tutorial.placementID })
        let initial = AquariumEditorDraft(player: previewPlayer, placements: placements, background: .aquarium)
        let work = AquariumEditorWorkingState(official: previewPlayer, placements: placements, draft: initial)
        var history = AquariumEditorHistory(initial: initial)
        let copy = try #require(work.placements.first { $0.decorationID == purchased.decorationID })
        try AquariumDecorationService.confirmPlacement(copy, at: CGPoint(x: 0.5, y: 0.88),
            in: context, persistChanges: false)
        preview.tutorial.requestEditor(); preview.tutorial.didBeginEditing(placements: placements); preview.tutorial.didShowLibrary(isAdding: true)
        preview.tutorial.didAddDecoration(copy)
        history.record(AquariumEditorDraft(player: work.player, placements: work.placements, background: .tropical))
        var draft = history.current; draft.history = history
        try preview.draftStore.save(draft)
        let undo = history.undo(); work.apply(try #require(undo))
        #expect(!copy.isPlaced)
        let redo = history.redo(); work.apply(try #require(redo))
        #expect(copy.isPlaced && !purchased.isPlaced)
        let updated = AquariumEditorSessionSnapshot.capture(player: work.player, decorationPlacements: work.placements, backgroundTheme: .tropical)
        try AquariumEditorCommit.apply(updated, to: previewPlayer, placements: placements, background: .aquarium) { try context.save() }
        #expect(purchased.isPlaced)
        #expect(player.coins == 432 && player.ownedFish.map(\.id) == originalIDs)
        #expect(rock.relativeX == 0.2 && rock.relativeY == 0.91 && rock.scale == 1.2 && rock.zOrder == 17)
        #expect(try production.mainContext.fetchCount(FetchDescriptor<AquariumDecorationPlacement>()) == 1)
        #expect(try production.mainContext.fetch(FetchDescriptor<RewardHistoryEntry>()).map(RewardHistorySnapshot.init(entry:)) == [originalHistory])
        #expect(productionDefaults.persistentDomain(forName: suite)! as NSDictionary == beforeDefaults)
        #expect(try Data(contentsOf: url) == originalDraftBytes)
        preview.cleanUp(); preview.cleanUp()
        #expect(!FileManager.default.fileExists(atPath: preview.temporaryDirectory.path))
        #expect(preview.defaults.persistentDomain(forName: preview.suiteName)?.isEmpty != false)
        #expect(try Data(contentsOf: url) == originalDraftBytes)
    }

    @Test func realEditorStartupWritesOnlyTheInjectedDraftAndDefaults() async throws {
        let productionDefaults = UserDefaults.standard
        let domain = Bundle.main.bundleIdentifier!
        let standardValues = productionDefaults.persistentDomain(forName: domain) ?? [:]
        let productionURL = AquariumEditorDraftStore.standard.url
        let productionBytes = try? Data(contentsOf: productionURL)
        let preview = try DecorationTutorialPreviewSession()
        try purchaseTreasureChest(in: preview)
        let core = CoreTutorialCoordinator(mode: .decorationPreview, defaults: preview.defaults,
            timerSessionStore: preview.timerSessionStore)
        let timer = TimerViewModel(studyTime: 25, breakTime: 5, now: Date.init, sessionStore: preview.timerSessionStore,
            notificationService: DisabledTimerNotificationService.shared)
        preview.tutorial.requestEditor()
        let navigation = AquariumEditorNavigationCoordinator()
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let host = UIHostingController(rootView: HomeView(timerViewModel: timer, mode: .aquariumEditor,
            allowsEditorDraftRestoration: true, isAquariumEditorActive: true, aquariumEditorNavigation: navigation,
            appDefaults: preview.defaults, editorDraftStore: preview.draftStore, timerSessionStore: preview.timerSessionStore,
            coreTutorial: core, decorationTutorial: preview.tutorial)
            .defaultAppStorage(preview.defaults).modelContainer(preview.modelContainer)
            .environment(\.aquariumFishViewingSession, preview.fishViewingSession))
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        window.rootViewController = host; window.makeKeyAndVisible()
        defer { window.isHidden = true; preview.cleanUp() }
        for _ in 0..<5 {
            host.view.layoutIfNeeded()
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(preview.tutorial.step == .edit)
        #expect(navigation.tabMode == .viewing)
        #expect(try preview.draftStore.load() == nil) // 「はい」だけで編集や下書きを作らない。
        let afterBytes = try? Data(contentsOf: productionURL)
        #expect(afterBytes == productionBytes)
        for key in [DecorationPurchaseTutorial.storageKey, AquariumEditorTutorialState.storageKey,
                    AquariumThemeStore.storageKey, CoreTutorialStorageKey.hasCompleted] {
            #expect((productionDefaults.persistentDomain(forName: domain)?[key] as? NSObject) == (standardValues[key] as? NSObject))
        }
    }
}
#endif
