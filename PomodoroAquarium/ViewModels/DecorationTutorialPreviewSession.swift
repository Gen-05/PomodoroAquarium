#if DEBUG
import Foundation
import SwiftData

/// 開くたびに作る独立した体験。標準ストア・標準defaults・本番の魚セッションを受け取らない。
@MainActor
final class DecorationTutorialPreviewSession: Identifiable {
    enum SetupError: Error { case unavailableDefaults }
    let suiteName: String
    var id: String { suiteName }
    let defaults: UserDefaults
    let modelContainer: ModelContainer
    let draftStore: AquariumEditorDraftStore
    let temporaryDirectory: URL
    let timerSessionStore: TimerSessionStore
    let fishViewingSession = AquariumFishViewingSession()
    let tutorial: DecorationPurchaseTutorial

    static let products: [ShopItem] = [AquariumDecorationKind.treasureChest, .seaweedA, .smallRockA, .shipwreck].map {
        ShopItem(id: "decoration-preview-\($0.rawValue)", name: $0.displayName,
            price: 10, category: .decoration, content: .decoration($0))
    }

    init() throws {
        suiteName = "DecorationTutorialPreview.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else { throw SetupError.unavailableDefaults }
        self.defaults = defaults
        temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(suiteName, isDirectory: true)
        draftStore = AquariumEditorDraftStore(url: temporaryDirectory.appendingPathComponent("draft.json"))
        timerSessionStore = TimerSessionStore(defaults: defaults, processIdentifier: suiteName)
        tutorial = DecorationPurchaseTutorial(defaults: defaults, firstPurchaseHandled: false)
        let schema = Schema([Player.self, PlayerFish.self, AquariumDecorationPlacement.self,
            StudyDailyRecord.self, FocusCategory.self, FocusSessionRecord.self, RewardHistoryEntry.self])
        do {
            modelContainer = try ModelContainer(for: schema,
                configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        } catch {
            defaults.removePersistentDomain(forName: suiteName)
            throw error
        }
        do {
            defaults.set(true, forKey: OnboardingStore.storageKey)
            defaults.set(true, forKey: CoreTutorialStorageKey.hasCompleted)
            defaults.set(AquariumBackgroundTheme.aquarium.rawValue, forKey: AquariumThemeStore.storageKey)
            defaults.set("25", forKey: TimerConfigurationStorageKey.pomodoroStudyDuration)
            defaults.set("5", forKey: TimerConfigurationStorageKey.pomodoroBreakDuration)
            let context = modelContainer.mainContext
            let fish = PlayerFish(species: .clownfish)
            let player = Player(ownedFish: [fish], activeAquariumFishIDs: [fish.id],
                hasInitializedActiveAquariumFish: true, coins: 100)
            context.insert(player)
            context.insert(AquariumDecorationPlacement(kind: .seaweedA,
                relativeX: 0.25, relativeY: 0.88, scale: 1, isPlaced: false))
            context.insert(AquariumDecorationPlacement(kind: .smallRockA,
                relativeX: 0.7, relativeY: 0.87, scale: 1, isPlaced: true))
            try context.save()
            _ = try FocusCategoryService.createDefaultsIfNeeded(in: context)
            // 本番の購入成功処理を一度実行し、購入結果を閉じた直後の案内から確認する。
            try tutorial.purchase(Self.products[0], player: player, in: context)
            tutorial.purchaseFeedbackDidDismiss()
        } catch {
            cleanUp()
            throw error
        }
    }

    /// coverのonDismissで呼ぶ。編集ViewのonDisappearによる下書き保存が終わってから片付ける。
    func cleanUp() {
        fishViewingSession.finishEditing()
        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: temporaryDirectory)
    }
}
#endif
