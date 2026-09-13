import Foundation
import Observation

enum AquariumTabMode: Equatable {
    case viewing
    case editing
}

@MainActor
@Observable
final class AquariumEditorNavigationCoordinator {
    private(set) var tabMode: AquariumTabMode = .viewing
    private(set) var hasUnsavedChanges = false
    private(set) var pendingTabSelection: MainAppTab?
    private(set) var confirmationRequestID: UUID?

    func beginSession() {
        tabMode = .editing
        hasUnsavedChanges = false
        pendingTabSelection = nil
        confirmationRequestID = nil
    }

    func markChanged() {
        hasUnsavedChanges = true
    }

    func requestConfirmation(beforeSelecting tab: MainAppTab) {
        pendingTabSelection = tab
        confirmationRequestID = UUID()
    }

    func requestFinishConfirmation() {
        pendingTabSelection = nil
        confirmationRequestID = UUID()
    }

    func continueEditing() {
        pendingTabSelection = nil
        confirmationRequestID = nil
    }

    func finishSession() {
        tabMode = .viewing
        hasUnsavedChanges = false
        pendingTabSelection = nil
        confirmationRequestID = nil
    }
}

struct AquariumDecorationEditorState: Equatable {
    let decorationID: String
    let relativeX: Double
    let relativeY: Double
    let scale: Double
    let isPlaced: Bool

    @MainActor
    init(_ placement: AquariumDecorationPlacement) {
        decorationID = placement.decorationID
        relativeX = placement.relativeX
        relativeY = placement.relativeY
        scale = placement.scale
        isPlaced = placement.isPlaced
    }

    @MainActor
    func restore(to placement: AquariumDecorationPlacement) {
        placement.relativeX = relativeX
        placement.relativeY = relativeY
        placement.scale = scale
        placement.isPlaced = isPlaced
    }
}

/// 水槽編集開始時の正式状態。編集中は既存モデルをプレビューとして使い、
/// 破棄時にこの値へ戻すことで描画ロジックを二重化しない。
struct AquariumEditorSessionSnapshot: Equatable {
    let activeFishIDs: [UUID]
    let decorations: [AquariumDecorationEditorState]
    let backgroundTheme: AquariumBackgroundTheme

    @MainActor
    static func capture(
        player: Player?,
        decorationPlacements: [AquariumDecorationPlacement],
        backgroundTheme: AquariumBackgroundTheme
    ) -> Self {
        Self(
            activeFishIDs: player?.activeAquariumFishIDs ?? [],
            decorations: decorationStates(from: decorationPlacements),
            backgroundTheme: backgroundTheme
        )
    }

    @MainActor
    func hasChanges(
        player: Player?,
        decorationPlacements: [AquariumDecorationPlacement],
        backgroundTheme: AquariumBackgroundTheme
    ) -> Bool {
        activeFishIDs != (player?.activeAquariumFishIDs ?? []) ||
            decorations != Self.decorationStates(from: decorationPlacements) ||
            self.backgroundTheme != backgroundTheme
    }

    @MainActor
    func restore(
        player: Player?,
        decorationPlacements: [AquariumDecorationPlacement]
    ) {
        player?.activeAquariumFishIDs = activeFishIDs

        let statesByID = Dictionary(uniqueKeysWithValues: decorations.map {
            ($0.decorationID, $0)
        })
        for placement in decorationPlacements {
            statesByID[placement.decorationID]?.restore(to: placement)
        }
    }

    @MainActor
    private static func decorationStates(
        from placements: [AquariumDecorationPlacement]
    ) -> [AquariumDecorationEditorState] {
        placements
            .map(AquariumDecorationEditorState.init)
            .sorted { $0.decorationID < $1.decorationID }
    }
}

enum AquariumEditorTutorialState {
    static let storageKey = "hasSeenAquariumEditorTutorial"

    static func shouldPresent(in defaults: UserDefaults) -> Bool {
        !defaults.bool(forKey: storageKey)
    }

    static func markSeen(in defaults: UserDefaults) {
        defaults.set(true, forKey: storageKey)
    }
}
