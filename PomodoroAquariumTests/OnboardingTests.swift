import Foundation
import Testing
@testable import PomodoroAquarium

@MainActor
struct OnboardingTests {
    @Test func threePagesExplainTheRewardWithoutProbabilities() {
        #expect(OnboardingPage.allCases.count == 3)
        #expect(OnboardingPage.welcome.next == .reward)
        #expect(OnboardingPage.reward.next == .tomorrow)
        #expect(OnboardingPage.tomorrow.next == nil)
        #expect(OnboardingPage.reward.title == "25分以上集中すると魚を獲得")
        for page in OnboardingPage.allCases {
            #expect(!page.title.isEmpty)
            #expect(!page.subtitle.contains("%"))
            #expect(!page.subtitle.contains("倍"))
        }
    }

    @Test func completingOnboardingPersistsOnlyItsFlag() throws {
        let suite = "OnboardingTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let player = Player(ownedFish: [PlayerFish(species: .clownfish)],
                            totalStudyMinutes: 120, todayStudyMinutes: 25, coins: 90)
        let fishIDs = player.ownedFish.map(\.id)
        defaults.set(2, forKey: DailyFishAcquisitionStorageKey.count)
        defaults.set(true, forKey: AquariumEditorTutorialState.storageKey)
        let baseline = defaults.dictionaryRepresentation()
        let store = OnboardingStore(defaults: defaults)
        #expect(!store.hasCompletedOnboarding)

        // ページ生成・表示用の魚・完了フラグにはPlayerや報酬処理との接続がない。
        _ = OnboardingView(onComplete: store.complete)
        for page in OnboardingPage.allCases {
            _ = page.title
            _ = page.subtitle
        }
        #expect(!store.hasCompletedOnboarding)
        store.complete()
        store.complete()
        let reopenedDefaults = try #require(UserDefaults(suiteName: suite))
        #expect(OnboardingStore(defaults: reopenedDefaults).hasCompletedOnboarding)
        #expect(player.ownedFish.map(\.id) == fishIDs)
        #expect(player.coins == 90)
        #expect(player.totalStudyMinutes == 120)
        #expect(player.todayStudyMinutes == 25)
        #expect(defaults.integer(forKey: DailyFishAcquisitionStorageKey.count) == 2)
        #expect(defaults.bool(forKey: AquariumEditorTutorialState.storageKey))
        var after = defaults.dictionaryRepresentation()
        after.removeValue(forKey: OnboardingStore.storageKey)
        #expect(NSDictionary(dictionary: baseline).isEqual(to: after))
    }
}
