#if DEBUG
import Foundation
import SwiftData
import Testing
@testable import PomodoroAquarium

@MainActor
struct SwiftDataStopDiagnosticsTests {
    @Test func diagnosticsDoNotKeepACustomContextAlive() throws {
        let container = try ModelContainer(for: Player.self, PlayerFish.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        var context: ModelContext? = ModelContext(container)
        weak var reference = context
        SwiftDataStopDiagnostics.register(context!, role: "Test.weakLifetime")
        context = nil
        #expect(reference == nil)
        _ = container // Containerはまだ生存しているが、診断はContextを保持しない。
    }

    @Test func observingSavesAndReferencesDoesNotChangeModelsOrSaveAgain() throws {
        let container = try ModelContainer(for: Player.self, PlayerFish.self, FocusSessionRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let fish = PlayerFish(species: .clownfish)
        let player = Player(ownedFish: [fish], activeAquariumFishIDs: [fish.id], coins: 123)
        let record = FocusSessionRecord(completedAt: Date(), durationMinutes: 25)
        context.insert(player)
        context.insert(record)
        SwiftDataStopDiagnostics.register(context, role: "Test.notifications")
        try context.save()
        #expect(!context.hasChanges)
        SwiftDataStopDiagnostics.references("Test.references", context: context, models: [player, fish, record])
        SwiftDataStopDiagnostics.record("Test.readOnly", context: context)
        #expect(!context.hasChanges)
        #expect(player.coins == 123 && player.ownedFish.count == 1 && player.activeAquariumFishIDs == [fish.id])
        #expect(record.validFocusSeconds == 1500)
        #expect(try context.fetchCount(FetchDescriptor<FocusSessionRecord>()) == 1)
    }
}
#endif
