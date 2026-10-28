import Foundation
import CoreGraphics
import SwiftData
import Testing
@testable import PomodoroAquarium

@MainActor
struct DecorationPurchaseTutorialTests {
    private func defaults() -> UserDefaults {
        UserDefaults(suiteName: "DecorationTutorialTests-\(UUID())")!
    }
    private func container() throws -> ModelContainer {
        try ModelContainer(for: Player.self, PlayerFish.self, AquariumDecorationPlacement.self,
            RewardHistoryEntry.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }
    private func product(_ kind: AquariumDecorationKind = .seaweedA) -> ShopItem {
        ShopItem(id: kind.rawValue, name: kind.displayName, price: 10, category: .decoration, content: .decoration(kind))
    }

    private func begin(_ tutorial: DecorationPurchaseTutorial, placement: AquariumDecorationPlacement) {
        tutorial.requestEditor()
        tutorial.didBeginEditing(placements: [placement])
        tutorial.didShowLibrary(isAdding: true)
    }
    private func finish(_ tutorial: DecorationPurchaseTutorial, placement: AquariumDecorationPlacement) {
        placement.isPlaced = true
        tutorial.didAddDecoration(placement)
        tutorial.didSelectDecoration(placement)
        tutorial.didDragDecoration(id: placement.decorationID, from: .zero, to: CGPoint(x: 0.1, y: 0.2))
        tutorial.next()
        tutorial.didEndEditing(saved: true)
        tutorial.next()
    }

    @Test func onlySuccessfulPurchaseStartsAndEveryOperationNeedsItsRealEvent() throws {
        let store = try container(), settings = defaults(), player = Player(coins: 100)
        store.mainContext.insert(player)
        let item = try #require(ShopCatalog.items.first { $0.content == .decoration(.seaweedA) })
        let tutorial = DecorationPurchaseTutorial(defaults: settings)
        let bought = try tutorial.purchase(item, player: player, in: store.mainContext)
        #expect(tutorial.phase == .waitingForFeedback && player.coins == 70 && !bought.isPlaced)
        tutorial.requestEditor()
        #expect(tutorial.phase == .waitingForFeedback)
        tutorial.purchaseFeedbackDidDismiss(); tutorial.requestEditor()
        #expect(tutorial.step == .edit)
        for _ in 0..<10 { tutorial.next() }
        #expect(tutorial.step == .edit && !bought.isPlaced)
        tutorial.didShowLibrary(isAdding: true)
        #expect(tutorial.step == .edit)
        tutorial.didBeginEditing(placements: [bought])
        #expect(tutorial.step == .library)
        tutorial.didShowLibrary(isAdding: false)
        #expect(tutorial.step == .additions)
        tutorial.next(); #expect(tutorial.step == .additions)
        tutorial.didShowLibrary(isAdding: true)
        #expect(tutorial.step == .add)
        let wrong = AquariumDecorationPlacement(kind: bought.kind, relativeX: 0.5, relativeY: 0.8, scale: 1)
        tutorial.didAddDecoration(wrong)
        #expect(tutorial.step == .add) // 同種でも購入した個体以外では進まない。
        bought.isPlaced = true
        tutorial.didAddDecoration(bought)
        #expect(tutorial.step == .select)
        tutorial.didSelectDecoration(wrong)
        #expect(tutorial.step == .select)
        tutorial.didSelectDecoration(bought)
        #expect(tutorial.step == .move)
        tutorial.next()
        tutorial.didDragDecoration(id: bought.decorationID, from: .zero, to: .zero)
        #expect(tutorial.step == .move)
        tutorial.didDragDecoration(id: bought.decorationID, from: .zero, to: CGPoint(x: 0.1, y: 0))
        #expect(tutorial.step == .tools)
        tutorial.next(); #expect(tutorial.step == .save)
        tutorial.next(); #expect(tutorial.step == .save) // 説明を読むだけでは保存完了にならない。
        tutorial.didEndEditing(saved: true)
        #expect(tutorial.step == .completed)
        tutorial.next(); #expect(tutorial.phase == .idle)
        #expect(player.coins == 70)
        #expect(try store.mainContext.fetchCount(FetchDescriptor<AquariumDecorationPlacement>()) == 1)
        #expect(try store.mainContext.fetchCount(FetchDescriptor<RewardHistoryEntry>()) == 0)
        let reopened = DecorationPurchaseTutorial(defaults: settings)
        try reopened.purchase(item, player: player, in: store.mainContext)
        reopened.purchaseFeedbackDidDismiss()
        #expect(reopened.phase == .idle && player.coins == 40)
    }

    @Test func failureConditionsAndLoadingOrDebugGrantsNeverStartTutorial() throws {
        let store = try container(), settings = defaults()
        let player = Player(coins: 0)
        store.mainContext.insert(player)
        let item = try #require(ShopCatalog.items.first { $0.content == .decoration(.seaweedA) })
        let tutorial = DecorationPurchaseTutorial(defaults: settings)
        #expect(throws: ShopPurchaseError.insufficientCoins) {
            try tutorial.purchase(item, player: player, in: store.mainContext)
        }
        #expect(throws: ShopPurchaseError.playerUnavailable) {
            try tutorial.purchase(item, player: nil, in: store.mainContext)
        }
        let background = ShopCatalog.items.first { $0.category == .background }!
        #expect(throws: ShopPurchaseError.unsupportedProduct) {
            try tutorial.purchase(background, player: player, in: store.mainContext)
        }
        #expect(throws: ShopPurchaseError.unsupportedProduct) {
            try tutorial.purchase(product(.rock), player: player, in: store.mainContext)
        }
        _ = try AquariumDeveloperDecorations.seedIfNeeded(in: store.mainContext)
        _ = try AquariumDecorationService.addPlacement(kind: .seaweedA, in: store.mainContext)
        tutorial.purchaseFeedbackDidDismiss()
        #expect(tutorial.phase == .idle)
        #expect(!settings.bool(forKey: DecorationPurchaseTutorial.storageKey))
        let reopened = DecorationPurchaseTutorial(defaults: settings)
        #expect(reopened.phase == .idle)
        #expect(player.coins == 0)
    }

    @Test func soldOutShipwreckNeverStartsPurchaseTutorial() throws {
        let store = try container(), settings = defaults()
        let player = Player(coins: 2_500)
        store.mainContext.insert(player)
        let existing = try AquariumDecorationService.addPlacement(kind: .shipwreck, in: store.mainContext)
        let ship = try #require(ShopCatalog.items.first { $0.content == .decoration(.shipwreck) })
        let tutorial = DecorationPurchaseTutorial(defaults: settings)
        tutorial.purchaseFeedbackWillPresent()
        #expect(throws: ShopPurchaseError.soldOut) {
            try tutorial.purchase(ship, player: player, in: store.mainContext)
        }
        tutorial.purchaseFeedbackDidDismiss()
        #expect(tutorial.phase == .idle)
        #expect(!settings.bool(forKey: DecorationPurchaseTutorial.storageKey))
        #expect(player.coins == 2_500 && !existing.isPlaced)
        #expect(try store.mainContext.fetchCount(FetchDescriptor<AquariumDecorationPlacement>()) == 1)
    }

    @Test func laterSkipAndCompletionSuppressAutomaticPresentationButHintsRemainAvailable() throws {
        for action in 0..<3 {
            let settings = defaults(), store = try container()
            let player = Player(coins: 100); store.mainContext.insert(player)
            let tutorial = DecorationPurchaseTutorial(defaults: settings)
            let bought = try tutorial.purchase(product(.treasureChest), player: player, in: store.mainContext)
            tutorial.purchaseFeedbackDidDismiss()
            if action == 0 { tutorial.dismiss() } // あとで
            else {
                begin(tutorial, placement: bought)
                if action == 1 { tutorial.dismiss() } // スキップ
                else { finish(tutorial, placement: bought) }
            }
            let reopened = DecorationPurchaseTutorial(defaults: settings)
            #expect(reopened.phase == .idle)
            reopened.showHint(placements: [bought], selectedID: nil)
            #expect(reopened.step == (bought.isPlaced ? .select : .library))
            reopened.dismiss()
            #expect(reopened.phase == .idle)
            #expect(player.coins == 90)
            try reopened.purchase(product(), player: player, in: store.mainContext)
            reopened.purchaseFeedbackDidDismiss()
            #expect(reopened.phase == .idle)
            #expect(settings.bool(forKey: DecorationPurchaseTutorial.storageKey))
            #expect(!settings.bool(forKey: AquariumEditorTutorialState.storageKey))
            #expect(!settings.bool(forKey: CoreTutorialStorageKey.hasCompleted))
        }
    }

    @Test func purchasedInventoryJoinsEveryDraftSnapshotWithoutAddingHistoryOrChangingOfficialPlacement() throws {
        let store = try container(), player = Player(coins: 100)
        store.mainContext.insert(player)
        let existing = try AquariumDecorationService.addPlacement(kind: .smallRockA, at: CGPoint(x: 0.2, y: 0.8), isPlaced: true, in: store.mainContext)
        let initial = AquariumEditorDraft(player: player, placements: [existing], background: .deepSea)
        let work = AquariumEditorWorkingState(official: player, placements: [existing], draft: initial)
        var history = AquariumEditorHistory(initial: initial)
        work.placements[0].relativeX = 0.7
        history.record(AquariumEditorDraft(player: work.player, placements: work.placements, background: .deepSea))
        let bought = try DecorationPurchaseTutorial(defaults: defaults()).purchase(product(), player: player, in: store.mainContext)
        let baseline = work.includeNewlyOwnedDecorations([existing, bought])
        history.includeNewlyOwnedDecorations(baseline)
        #expect(history.position == 1 && history.states.count == 2)
        #expect(work.includeNewlyOwnedDecorations([existing, bought]).isEmpty)
        #expect(work.placements.count == 2 && existing.relativeX == 0.2)
        let copy = try #require(work.placements.first { $0.decorationID == bought.decorationID })
        #expect(copy !== bought)
        #expect(!copy.isPlaced)
        copy.isPlaced = true
        history.record(AquariumEditorDraft(player: work.player, placements: work.placements, background: .deepSea))
        let undoPlacement = history.undo()
        work.apply(try #require(undoPlacement))
        #expect(!copy.isPlaced && work.placements[0].relativeX == 0.7)
        let redoPlacement = history.redo()
        work.apply(try #require(redoPlacement))
        #expect(copy.isPlaced && !bought.isPlaced)
        let undoAgain = history.undo()
        work.apply(try #require(undoAgain))
        let undoExistingMovement = history.undo()
        work.apply(try #require(undoExistingMovement))
        #expect(work.placements[0].relativeX == 0.2 && !copy.isPlaced)
        // 編集キャンセルはdetached workを捨てるだけ。購入済みの所有はそのまま。
        #expect(!bought.isPlaced && existing.relativeX == 0.2 && player.coins == 90)
    }

    @Test func automaticSelectionHintsShipwreckAndSkippingNeverForgeOperations() {
        let tutorial = DecorationPurchaseTutorial(defaults: defaults())
        let chest = AquariumDecorationPlacement(kind: .treasureChest, relativeX: 0.5, relativeY: 0.8, scale: 1, isPlaced: false)
        tutorial.showHint(placements: [chest], selectedID: nil)
        #expect(tutorial.step == .library)
        tutorial.didShowLibrary(isAdding: true)
        chest.isPlaced = true
        tutorial.didSelectDecoration(chest) // 追加の通知より選択の通知が先でも停止しない。
        tutorial.didAddDecoration(chest)
        #expect(tutorial.step == .move)
        tutorial.dismiss()
        #expect(chest.isPlaced && chest.relativeX == 0.5)
        tutorial.showHint(placements: [chest], selectedID: chest.decorationID)
        #expect(tutorial.step == .move) // 編集開始・購入はやり直さない。
        chest.isPlaced = false
        tutorial.reconcilePlacedTarget([chest])
        #expect(tutorial.step == .library)
        #expect(DecorationTutorialContent.message(step: .tools, kind: .treasureChest).contains("向きを変更"))
        #expect(!DecorationTutorialContent.message(step: .tools, kind: .seaweedA).contains("向きを変更"))
        let ship = AquariumDecorationPlacement(kind: .shipwreck, relativeX: 0.5, relativeY: 0.8, scale: 1)
        tutorial.showHint(placements: [ship], selectedID: ship.decorationID)
        tutorial.didDragDecoration(id: ship.decorationID, from: .zero, to: CGPoint(x: 1, y: 1))
        #expect(tutorial.step == .move)
        tutorial.didChangeShipwreckSide(id: ship.decorationID, from: .left, to: .left)
        #expect(tutorial.step == .move)
        tutorial.didChangeShipwreckSide(id: ship.decorationID, from: .left, to: .right)
        #expect(tutorial.step == .tools)
        #expect(!DecorationTutorialContent.message(step: .tools, kind: .shipwreck).contains("微調整"))
        tutorial.next(); tutorial.didEndEditing(saved: false)
        #expect(tutorial.phase == .idle) // 破棄を保存完了として表示しない。
        #expect(DecorationPurchaseTutorial.Step.allCases.allSatisfy { !DecorationTutorialContent.message(step: $0, kind: .shipwreck).contains("サイズ") })
    }
}
