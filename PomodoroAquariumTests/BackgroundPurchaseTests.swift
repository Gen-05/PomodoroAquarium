import Foundation
import SwiftData
import Testing
@testable import PomodoroAquarium

@MainActor
struct BackgroundPurchaseTests {
    private func container() throws -> ModelContainer {
        try ModelContainer(for: Player.self, PlayerFish.self, AquariumDecorationPlacement.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }
    private func product(_ theme: AquariumBackgroundTheme) throws -> ShopItem {
        try #require(ShopCatalog.items.first { $0.content == .background(theme) })
    }
    private func defaults() -> UserDefaults { UserDefaults(suiteName: "BackgroundPurchaseTests.\(UUID())")! }

    @Test func newPlayersOnlyOwnTheBasicBackground() throws {
        let store = try container()
        let player = Player()
        store.mainContext.insert(player)
        try store.mainContext.save()
        #expect(AquariumBackgroundOwnership.canUse(.aquarium, player: player))
        #expect(!AquariumBackgroundOwnership.canUse(.deepSea, player: player))
        #expect(!AquariumBackgroundOwnership.canUse(.tropical, player: player))
        #expect(player.ownedBackgroundRawValues == ["aquarium"])
        #expect(!ShopCatalog.items.contains { $0.content == .background(.aquarium) })
    }

    @Test(arguments: [AquariumBackgroundTheme.deepSea, .tropical])
    func confirmedPurchasePersistsWithoutSelectingOrStartingDecorationTutorial(theme: AquariumBackgroundTheme) throws {
        let store = try container(), settings = defaults()
        let selectedBefore = UserDefaults.standard.string(forKey: AquariumThemeStore.storageKey)
        let player = Player(coins: 6_500)
        store.mainContext.insert(player)
        let item = try product(theme)
        #expect(item.price == 3_000)
        let tutorial = DecorationPurchaseTutorial(defaults: settings)
        let flow = ShopPurchaseFlow()
        flow.requestConfirmation(for: item)
        #expect(flow.confirmation == item && player.coins == 6_500)
        flow.confirm(player: player, in: store.mainContext, tutorial: tutorial)
        flow.confirm(player: player, in: store.mainContext, tutorial: tutorial)
        #expect(player.coins == 3_500 && AquariumBackgroundOwnership.canUse(theme, player: player))
        #expect(!tutorial.isPurchaseFeedbackVisible && tutorial.phase == .idle)
        flow.confirmationDidDismiss()
        #expect(flow.feedback?.message == "\(item.name)を購入しました")
        flow.feedback = nil
        flow.feedbackDidDismiss(tutorial: tutorial)
        #expect(tutorial.phase == .idle && !settings.bool(forKey: DecorationPurchaseTutorial.storageKey))
        #expect(settings.object(forKey: AquariumThemeStore.storageKey) == nil)
        #expect(UserDefaults.standard.string(forKey: AquariumThemeStore.storageKey) == selectedBefore)
        #expect(try store.mainContext.fetchCount(FetchDescriptor<AquariumDecorationPlacement>()) == 0)
        let reloaded = ModelContext(store)
        let saved = try #require(reloaded.fetch(FetchDescriptor<Player>()).first)
        #expect(saved.coins == 3_500 && AquariumBackgroundOwnership.canUse(theme, player: saved))
        #expect(throws: ShopPurchaseError.alreadyOwned) {
            try ShopService.purchaseBackground(item, for: player, in: store.mainContext)
        }
        #expect(player.coins == 3_500)
        let work = AquariumEditorWorkingState(official: player, placements: [])
        let initial = AquariumEditorDraft(player: work.player, placements: [], background: .aquarium)
        var history = AquariumEditorHistory(initial: initial)
        history.record(AquariumEditorDraft(player: work.player, placements: [], background: theme))
        let undo = history.undo()
        work.apply(try #require(undo))
        #expect(AquariumBackgroundOwnership.canUse(theme, player: work.player))
        let redo = history.redo()
        work.apply(try #require(redo))
        #expect(AquariumBackgroundOwnership.canUse(theme, player: work.player))
    }

    @Test func cancellationAndChangedBalanceOrOwnershipCannotSpendAgain() throws {
        let store = try container(), settings = defaults()
        let player = Player(coins: 6_000)
        store.mainContext.insert(player)
        let item = try product(.deepSea)
        let tutorial = DecorationPurchaseTutorial(defaults: settings)
        let flow = ShopPurchaseFlow()
        flow.requestConfirmation(for: item)
        flow.confirmation = nil
        flow.confirmationDidDismiss()
        #expect(player.coins == 6_000 && !AquariumBackgroundOwnership.canUse(.deepSea, player: player))
        #expect(!tutorial.isPurchaseFeedbackVisible && tutorial.phase == .idle)
        flow.requestConfirmation(for: item)
        try CurrencyService.spendCoins(3_001, from: player, in: store.mainContext)
        flow.confirm(player: player, in: store.mainContext, tutorial: tutorial)
        flow.confirmationDidDismiss()
        #expect(flow.feedback?.message == "コインが足りません" && player.coins == 2_999)
        #expect(!AquariumBackgroundOwnership.canUse(.deepSea, player: player))
        flow.feedback = nil; flow.feedbackDidDismiss(tutorial: tutorial)
        try CurrencyService.addCoins(3_001, to: player, in: store.mainContext)
        flow.requestConfirmation(for: item)
        try ShopService.purchaseBackground(item, for: player, in: store.mainContext)
        flow.confirm(player: player, in: store.mainContext, tutorial: tutorial)
        flow.confirmationDidDismiss()
        #expect(flow.feedback?.message == "この背景は購入済みです" && player.coins == 3_000)
        flow.feedback = nil; flow.feedbackDidDismiss(tutorial: tutorial)
        #expect(tutorial.phase == .idle && !settings.bool(forKey: DecorationPurchaseTutorial.storageKey))
    }

    @Test func failedSaveRestoresBothCoinsAndOwnershipWithoutRollingBackOtherData() throws {
        enum Failure: Error { case save }
        let store = try container(), player = Player(coins: 6_000)
        store.mainContext.insert(player)
        try store.mainContext.save()
        player.todayStudyMinutes = 17 // 購入と無関係の未保存データも巻き戻さない。
        let item = try product(.tropical)
        var saves = 0
        #expect(throws: Failure.save) {
            try ShopService.purchaseBackground(item, for: player, in: store.mainContext, save: {
                saves += 1
                #expect(player.coins == 3_000 && AquariumBackgroundOwnership.canUse(.tropical, player: player))
                throw Failure.save
            })
        }
        #expect(saves == 1 && player.coins == 6_000 && player.todayStudyMinutes == 17)
        #expect(!AquariumBackgroundOwnership.canUse(.tropical, player: player))
        try store.mainContext.save()
        let reloaded = ModelContext(store)
        let saved = try #require(reloaded.fetch(FetchDescriptor<Player>()).first)
        #expect(saved.coins == 6_000 && saved.todayStudyMinutes == 17)
        #expect(!AquariumBackgroundOwnership.canUse(.tropical, player: saved))
    }

    @Test func legacyMigrationKeepsSelectedDraftAndHistoryThemesWithoutRewritingTheDraft() throws {
        let store = try container(), settings = defaults()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("BackgroundMigration-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let draftStore = AquariumEditorDraftStore(url: directory.appendingPathComponent("draft.json"))
        let fish = PlayerFish(species: .blueTang)
        let player = Player(ownedFish: [fish], activeAquariumFishIDs: [fish.id],
            hasInitializedActiveAquariumFish: true, coins: 99, ownedBackgroundRawValues: nil)
        let rock = AquariumDecorationPlacement(kind: .smallRockA, relativeX: 0.3, relativeY: 0.8,
            scale: 1.1, isPlaced: true, zOrder: 13, isStackingOrderInitialized: true)
        store.mainContext.insert(player); store.mainContext.insert(rock)
        try store.mainContext.save()
        AquariumThemeStore(defaults: settings).save(.deepSea)
        let original = AquariumEditorDraft(player: player, placements: [rock], background: .aquarium)
        var draft = AquariumEditorDraft(player: player, placements: [rock], background: .deepSea)
        var history = AquariumEditorHistory(initial: AquariumEditorDraft(player: player, placements: [rock], background: .tropical))
        history.record(draft); draft.history = history
        try draftStore.save(draft)
        let bytes = try Data(contentsOf: draftStore.url)
        let result = try HomePlayerInitialization.prepare(in: store.mainContext, defaults: settings, draftStore: draftStore)
        #expect(result.player === player && !result.didCreatePlayer)
        #expect(Set(player.ownedBackgroundRawValues ?? []) == Set(AquariumBackgroundTheme.allCases.map(\.rawValue)))
        #expect(player.coins == 99 && player.activeAquariumFishIDs == [fish.id])
        #expect(AquariumThemeStore(defaults: settings).selectedTheme == .deepSea)
        #expect(try Data(contentsOf: draftStore.url) == bytes)
        #expect(AquariumEditorDraft(player: player, placements: [rock], background: .aquarium) == original)
        #expect(try !AquariumBackgroundOwnership.migrateIfNeeded(for: player, in: store.mainContext,
            defaults: settings, draftStore: draftStore))
        let basicLegacy = Player(ownedBackgroundRawValues: nil)
        store.mainContext.insert(basicLegacy)
        let absent = AquariumEditorDraftStore(url: directory.appendingPathComponent("absent.json"))
        AquariumThemeStore(defaults: settings).save(.aquarium)
        try AquariumBackgroundOwnership.migrateIfNeeded(for: basicLegacy, in: store.mainContext, defaults: settings, draftStore: absent)
        AquariumThemeStore(defaults: settings).save(.tropical)
        try AquariumBackgroundOwnership.migrateIfNeeded(for: basicLegacy, in: store.mainContext, defaults: settings, draftStore: draftStore)
        #expect(basicLegacy.ownedBackgroundRawValues == ["aquarium"])
    }

    @Test func unmigratedPlayerDiskStoreRetainsFishDecorationsAndCoinsAfterReload() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("LegacyBackgroundStore-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("player.store")
        let fishID = UUID()
        let decorationID = UUID().uuidString
        try autoreleasepool {
            let old = try ModelContainer(for: Player.self, PlayerFish.self, AquariumDecorationPlacement.self,
                configurations: ModelConfiguration(url: url))
            let fish = PlayerFish(id: fishID, species: .clownfish)
            // 旧レコードの新しいnullable列がnilで読み込まれた状態を再現する。
            let player = Player(ownedBackgroundRawValues: nil)
            player.ownedFish = [fish]
            player.activeAquariumFishIDs = [fishID]
            player.hasInitializedActiveAquariumFish = true
            player.coins = 4_321
            player.totalStudyMinutes = 123
            old.mainContext.insert(player)
            old.mainContext.insert(AquariumDecorationPlacement(decorationID: decorationID, kind: .treasureChest,
                relativeX: 0.4, relativeY: 0.87, scale: 1.2, isPlaced: true, facingDirection: .left,
                zOrder: 71, isStackingOrderInitialized: true))
            try old.mainContext.save()
        }
        let current = try ModelContainer(for: Player.self, PlayerFish.self, AquariumDecorationPlacement.self,
            configurations: ModelConfiguration(url: url))
        let player = try #require(current.mainContext.fetch(FetchDescriptor<Player>()).first)
        #expect(player.ownedBackgroundRawValues == nil)
        let settings = defaults()
        AquariumThemeStore(defaults: settings).save(.deepSea)
        let draft = AquariumEditorDraftStore(url: directory.appendingPathComponent("absent.json"))
        try AquariumBackgroundOwnership.migrateIfNeeded(for: player, in: current.mainContext, defaults: settings, draftStore: draft)
        #expect(player.coins == 4_321 && player.totalStudyMinutes == 123)
        #expect(player.activeAquariumFishIDs == [fishID] && player.ownedFish.map(\.id) == [fishID])
        #expect(AquariumBackgroundOwnership.canUse(.deepSea, player: player))
        #expect(!AquariumBackgroundOwnership.canUse(.tropical, player: player))
        let chest = try #require(current.mainContext.fetch(FetchDescriptor<AquariumDecorationPlacement>()).first)
        #expect(chest.decorationID == decorationID && chest.isPlaced && chest.facingDirection == .left)
        #expect(chest.relativeX == 0.4 && chest.relativeY == 0.87 && chest.scale == 1.2 && chest.zOrder == 71)
        let reloaded = ModelContext(current)
        let saved = try #require(reloaded.fetch(FetchDescriptor<Player>()).first)
        #expect(saved.ownedBackgroundRawValues == ["aquarium", "deepSea"])
        #expect(try !AquariumBackgroundOwnership.migrateIfNeeded(for: saved, in: reloaded, defaults: settings, draftStore: draft))
        #expect(saved.coins == 4_321 && saved.ownedFish.map(\.id) == [fishID])
    }

    @Test func anUnmigratedPlayerCannotBeChargedAsIfTheBackgroundWereUnowned() throws {
        let store = try container(), player = Player(coins: 6_000, ownedBackgroundRawValues: nil)
        store.mainContext.insert(player)
        let item = try product(.deepSea)
        #expect(throws: ShopPurchaseError.backgroundOwnershipUnavailable) {
            try ShopService.purchaseBackground(item, for: player, in: store.mainContext)
        }
        #expect(player.coins == 6_000 && player.ownedBackgroundRawValues == nil)
    }
}
