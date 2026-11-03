import Foundation
import Testing
@testable import PomodoroAquarium

@MainActor
struct OnboardingTests {
    @Test func threeExplanationPagesFollowTheStartSurface() async {
        #expect(OnboardingPage.allCases.count == 3)
        #expect(OnboardingPage.welcome.next == .reward)
        #expect(OnboardingPage.welcome.title == "ポモドーロ水族館へようこそ")
        #expect(OnboardingPage.reward.next == .tomorrow)
        #expect(OnboardingPage.tomorrow.next == nil)
        #expect(OnboardingPage.reward.title == "25分以上集中すると魚を獲得")
        #expect(OnboardingPage.reward.sentences.count == 2)
        var progress = OnboardingRevealProgress()
        for page in OnboardingPage.allCases {
            progress.beginPage(on: page, typesText: false)
            #expect(progress.step(on: page) == 1)
            #expect(!progress.isComplete(on: page))
            #expect(progress.isVisible(.title, on: page))
            for count in 2...page.revealSteps.count {
                #expect(progress.canAutoAdvance(on: page))
                progress.advanceAutomatically(on: page)
                #expect(progress.step(on: page) == count)
                #expect(progress.isVisible(.title, on: page))
                for element in page.revealSteps.prefix(count).flatMap({ $0 }) {
                    #expect(progress.isVisible(element, on: page))
                }
                for element in page.revealSteps.dropFirst(count).flatMap({ $0 }) {
                    #expect(!progress.isVisible(element, on: page))
                }
                if count < page.revealSteps.count { #expect(!progress.isComplete(on: page)) }
            }
            #expect(progress.isComplete(on: page))
            progress.advanceAutomatically(on: page)
            #expect(progress.step(on: page) == page.revealSteps.count)
        }
        #expect(OnboardingPage.welcome.revealSteps.count == 5)
        #expect(OnboardingPage.reward.revealSteps.count == 6)
        #expect(OnboardingPage.tomorrow.revealSteps.count == 7)
        var welcome = OnboardingRevealProgress()
        #expect(welcome.isVisible(.welcomeFish, on: .welcome))
        #expect(!welcome.isVisible(.sentence(0), on: .welcome))
        #expect(!welcome.isVisible(.focus, on: .welcome))
        welcome.beginPage(on: .welcome, typesText: false)
        welcome.advanceAutomatically(on: .welcome)
        #expect(welcome.canAutoAdvance(on: .welcome))
        welcome.advanceAutomatically(on: .welcome)
        #expect(welcome.isVisible(.focus, on: .welcome))
        #expect(!welcome.isVisible(.caughtFish, on: .welcome))
        #expect(!welcome.isVisible(.growingAquarium, on: .welcome))
        var typed = OnboardingRevealProgress()
        typed.beginPage(on: .welcome, typesText: false)
        typed.advanceAutomatically(on: .welcome, typesText: true)
        #expect(typed.step(on: .welcome) == 2)
        #expect(typed.isTyping(on: .welcome))
        #expect(typed.activeText?.visibleText == "")
        typed.revealCharacter()
        #expect(typed.activeText?.visibleText == "集")
        typed.advanceAutomatically(on: .welcome, typesText: true)
        #expect(typed.step(on: .welcome) == 2) // 文字の途中では自動の段階送りを拒否する。
        typed.completeText()
        #expect(typed.step(on: .welcome) == 2)
        #expect(typed.activeText?.visibleText == OnboardingPage.welcome.sentences[0])
        #expect(!typed.isVisible(.focus, on: .welcome))
        #expect(typed.canAutoAdvance(on: .welcome))
        #expect(typed.autoAdvanceDelay(on: .welcome) == .seconds(1))
        typed.advanceAutomatically(on: .welcome)
        #expect(typed.step(on: .welcome) == 3)
        #expect(typed.isVisible(.focus, on: .welcome))
        #expect(typed.autoAdvanceDelay(on: .welcome) == .milliseconds(700))
        for page in OnboardingPage.allCases {
            var heading = OnboardingRevealProgress()
            #expect(heading.characterCount(for: .title, on: page) == 0)
            heading.beginPage(on: page, typesText: true)
            #expect(heading.step(on: page) == 1)
            #expect(heading.isTyping(on: page))
            heading.revealCharacter()
            #expect(heading.activeText?.visibleText == String(page.title.prefix(1)))
            heading.completeText()
            #expect(heading.step(on: page) == 1) // 全文表示は段階を進めない。
            #expect(heading.characterCount(for: .title, on: page) == page.title.count)
            #expect(!heading.isVisible(.sentence(0), on: page))
            heading.beginPage(on: page, typesText: true) // 再表示では既読を再開しない。
            #expect(!heading.isTyping(on: page))
            heading.advanceAutomatically(on: page, typesText: true)
            #expect(heading.step(on: page) == 2)
            #expect(heading.isTyping(on: page))
            #expect(heading.isVisible(.sentence(0), on: page))
        }
        var reward = OnboardingRevealProgress()
        reward.beginPage(on: .reward, typesText: false)
        #expect(reward.autoAdvanceDelay(on: .reward) == .seconds(1))
        reward.advanceAutomatically(on: .reward)
        #expect(reward.canAutoAdvance(on: .reward)) // 2文目も、間を置いて自動で開始する。
        reward.advanceAutomatically(on: .reward, typesText: true)
        #expect(reward.step(on: .reward) == 3)
        #expect(!reward.canAutoAdvance(on: .reward))
        reward.finishPage(on: .reward) // 途中で離脱したページも、戻った際は完成表示。
        #expect(reward.isComplete(on: .reward))
        reward.beginPage(on: .reward, typesText: true)
        #expect(reward.isComplete(on: .reward))
        #expect(!reward.canAutoAdvance(on: .reward))
        for element in OnboardingPage.reward.revealSteps.flatMap({ $0 }) {
            #expect(reward.isVisible(element, on: .reward))
        }
        #expect(OnboardingTextTiming.textHoldDuration == .seconds(1))
        #expect(OnboardingTextTiming.diagramInterval == .milliseconds(700))
        #expect(TutorialTextReveal.characterInterval == .milliseconds(20))
        #expect(OnboardingTextTiming.delay(after: nil, before: "集") == .milliseconds(50))
        #expect(OnboardingTextTiming.delay(after: "集", before: "中") == .milliseconds(50))
        #expect(OnboardingTextTiming.delay(after: "、", before: "魚") == .milliseconds(200))
        for punctuation: Character in ["。", "！", "？", "!", "?"] {
            #expect(OnboardingTextTiming.delay(after: punctuation, before: "魚") == .milliseconds(350))
        }
        #expect(OnboardingTextTiming.delay(after: "。", before: "\n") == .zero)
        var delays: [Duration] = []
        let paced = await TutorialTextReveal.reveal("あ、\nい。う", delayBeforeCharacter: { previous, character in
            delays.append(OnboardingTextTiming.delay(after: previous, before: character))
            return .zero // 待機を省き、句読点と改行の経路だけを確認する。
        }, onCharacter: { _ in })
        #expect(paced)
        #expect(delays == [.milliseconds(50), .milliseconds(50), .zero,
                           .milliseconds(200), .milliseconds(50), .milliseconds(350)])
        var characters = ""
        let completed = await TutorialTextReveal.reveal("魚あ") { characters.append($0) }
        #expect(completed)
        #expect(characters == "魚あ")
        let cancelled = Task { @MainActor in
            await TutorialTextReveal.reveal("出さない") { characters.append($0) }
        }
        cancelled.cancel()
        let didFinish = await cancelled.value
        #expect(!didFinish)
        #expect(characters == "魚あ")
        // ページ往復では既読を保持し、別のPreviewでは新しい状態から始まる。
        #expect(progress.isComplete(on: .welcome))
        #expect(OnboardingRevealProgress().step(on: .welcome) == 1)
        for page in OnboardingPage.allCases {
            #expect(!page.title.isEmpty)
            #expect(!page.subtitle.contains("%"))
            #expect(!page.subtitle.contains("倍"))
            #expect(page.sentences.joined(separator: "\n") == page.subtitle)
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
