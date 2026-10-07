import Foundation
import Testing
import UIKit
@testable import PomodoroAquarium

@MainActor
struct AquariumBackgroundThemeTests {
    @Test func allOceanAssetsUseTheSharedLightSequence() {
        #expect(AquariumBackgroundTheme.aquarium.imageName == "basic_ocean_00")
        #expect(AquariumBackgroundTheme.tropical.imageName == "coral_ocean_00")
        #expect(AquariumBackgroundTheme.deepSea.imageName == "deep_ocean_00")

        for (theme, prefix) in [
            (AquariumBackgroundTheme.aquarium, "basic_ocean"),
            (AquariumBackgroundTheme.tropical, "coral_ocean"),
            (AquariumBackgroundTheme.deepSea, "deep_ocean")
        ] {
            #expect(theme.lightFrameNames == (1...5).map { String(format: "%@_%02d", prefix, $0) })
            #expect(UIImage(named: theme.imageName) != nil)
            for name in theme.lightFrameNames {
                #expect(UIImage(named: name) != nil)
            }
            #expect(!theme.usesFallbackSandLayer)
        }
    }

    @Test func v1NamesAndSandPolicy() {
        #expect(AquariumBackgroundTheme.aquarium.displayName == "ベーシック海底")
        #expect(AquariumBackgroundTheme.tropical.displayName == "サンゴ礁")
        #expect(AquariumBackgroundTheme.deepSea.displayName == "深い海")
        #expect(AquariumBackgroundTheme.aquarium.showsSand)
        #expect(!AquariumBackgroundTheme.tropical.showsSand)
        #expect(!AquariumBackgroundTheme.deepSea.showsSand)
    }

    @Test(arguments: ["aquarium", "tropical", "deepSea"])
    func existingStoredIDsRestoreWithoutMigration(rawValue: String) throws {
        let suiteName = "AquariumBackgroundThemeTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(rawValue, forKey: AquariumThemeStore.storageKey)

        let restored = AquariumThemeStore(defaults: defaults).selectedTheme
        #expect(restored.rawValue == rawValue)
        #expect(restored == AquariumBackgroundTheme(rawValue: rawValue))
        AquariumThemeStore(defaults: defaults).save(restored)
        #expect(defaults.string(forKey: AquariumThemeStore.storageKey) == rawValue)
        #expect(AquariumThemeStore(defaults: defaults).selectedTheme == restored)
    }

    @Test func defaultAndInvalidIDsStillUseTheBasicSeabed() {
        #expect(AquariumThemeStore.theme(from: nil) == .aquarium)
        #expect(AquariumThemeStore.theme(from: "unknown-theme") == .aquarium)
    }
}
