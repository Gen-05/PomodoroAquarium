import Foundation
import SwiftData

@MainActor
enum AquariumBackgroundOwnership {
    static func canUse(_ theme: AquariumBackgroundTheme, player: Player?) -> Bool {
        theme == .aquarium || player?.ownedBackgroundRawValues?.contains(theme.rawValue) == true
    }

    /// 旧データだけ一度引き継ぐ。選択中の背景・下書き・Undo/Redo内の背景を保持する。
    @discardableResult
    static func migrateIfNeeded(for player: Player, in context: ModelContext,
                                defaults: UserDefaults, draftStore: AquariumEditorDraftStore) throws -> Bool {
        guard player.ownedBackgroundRawValues == nil else { return false }
        var themes: Set<AquariumBackgroundTheme> = [.aquarium, AquariumThemeStore(defaults: defaults).selectedTheme]
        themes.formUnion(try draftStore.backgroundThemesForOwnershipMigration())
        player.ownedBackgroundRawValues = AquariumBackgroundTheme.allCases.filter { themes.contains($0) }.map(\.rawValue)
        do { try context.save() }
        catch { player.ownedBackgroundRawValues = nil; throw error }
        return true
    }
}
