import Foundation
import Testing
@testable import PomodoroAquarium

@MainActor
struct AquariumEditorLaunchTests {
    @Test func validDraftChoosesAquariumOnlyAfterFirstRunGuidance() throws {
        let suite = UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = AquariumEditorDraftStore(url: url)
        defer { try? store.remove() }
        let draft = AquariumEditorDraft(player: Player(), placements: [], background: .deepSea)
        try store.save(draft)
        #expect(AquariumEditorLaunchPolicy.initialTab(mode: .production, defaults: defaults, store: store) == .home)
        defaults.set(true, forKey: OnboardingStore.storageKey)
        #expect(AquariumEditorLaunchPolicy.initialTab(mode: .production, defaults: defaults, store: store) == .home)
        defaults.set(true, forKey: CoreTutorialStorageKey.hasCompleted)
        #expect(AquariumEditorLaunchPolicy.initialTab(mode: .production, defaults: defaults, store: store) == .aquarium)
        #expect(AquariumEditorLaunchPolicy.initialTab(mode: .preview, defaults: defaults, store: store) == .home)
        #expect(try store.load() == draft)
        try store.remove()
        #expect(AquariumEditorLaunchPolicy.initialTab(mode: .production, defaults: defaults, store: store) == .home)
        try Data("broken".utf8).write(to: url)
        #expect(AquariumEditorLaunchPolicy.initialTab(mode: .production, defaults: defaults, store: store) == .home)
    }
}
