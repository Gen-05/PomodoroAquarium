import SwiftUI
import Combine

private struct AquariumFishViewingSessionKey: EnvironmentKey {
    static let defaultValue: AquariumFishViewingSession? = nil
}

extension EnvironmentValues {
    var aquariumFishViewingSession: AquariumFishViewingSession? {
        get { self[AquariumFishViewingSessionKey.self] }
        set { self[AquariumFishViewingSessionKey.self] = newValue }
    }
}

/// Appが所有するメモリ内の泳ぎ。表示の切り替え・バックグラウンド復帰では作り直さない。
@MainActor
final class AquariumFishViewingSession: ObservableObject {
    struct Snapshot {
        var motion: AquariumFishMotion.State
        var direction: FishSpriteDirectionTransition
        var wing: AquariumFishMotion.WingCycle?
        var elapsedTime: TimeInterval = 0
        var appliedAppearanceStart: Date?
    }

    let id: UUID
    let scopeID = UUID()
    private var snapshots: [UUID: Snapshot] = [:]
    private var owners: [UUID: UUID] = [:]
    private(set) var editingSession: AquariumFishViewingSession?

    init(id: UUID = UUID()) { self.id = id }

    func snapshot(for fishID: UUID) -> Snapshot? { snapshots[fishID] }

    /// 遷移先だけに更新権を渡す。古いViewのtickやonDisappearは新しい状態を書き戻せない。
    func claim(_ fishID: UUID, owner: UUID, initial: Snapshot, bounds: FishRoamingBounds) -> Snapshot {
        var snapshot = snapshots[fishID] ?? initial
        snapshot.motion.updateRoamingBounds(bounds)
        snapshots[fishID] = snapshot
        owners[fishID] = owner
        return snapshot
    }

    func isOwner(_ fishID: UUID, owner: UUID) -> Bool { owners[fishID] == owner }

    @discardableResult
    func update(_ fishID: UUID, owner: UUID, snapshot: Snapshot) -> Bool {
        guard isOwner(fishID, owner: owner) else { return false }
        snapshots[fishID] = snapshot
        return true
    }

    func release(_ fishID: UUID, owner: UUID) {
        guard isOwner(fishID, owner: owner) else { return }
        owners[fishID] = nil
    }

    func beginEditing() {
        guard editingSession == nil else { return }
        let editing = AquariumFishViewingSession(id: id)
        editing.snapshots = snapshots
        editingSession = editing
    }

    func finishEditing(commit activeIDs: [UUID]? = nil) {
        guard let editing = editingSession else { return }
        if let activeIDs {
            for id in activeIDs {
                if let snapshot = editing.snapshots[id] { snapshots[id] = snapshot }
            }
            // 保存前のViewが、保存後の泳ぎを上書きできないよう更新権を破棄する。
            owners.removeAll()
        }
        editing.owners.removeAll()
        editingSession = nil
    }
}
