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
        var inflation: AquariumPorcupinefishInflation.State?
        var dolphin: AquariumDolphinSwimming.State?
        var whaleSharkTempo: AquariumWhaleSharkAnimationTempo.State?
    }

    let id: UUID
    let scopeID = UUID()
    private var snapshots: [UUID: Snapshot] = [:]
    private var owners: [UUID: UUID] = [:]
    private var inflationRequests: Set<UUID> = []
    private(set) var handledViewingTapToken: UUID?
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

    /// 描画側の所有者だけが消費するコマンド。古いSnapshotで新しい泳ぎを上書きしない。
    @discardableResult
    func requestInflation(for fishID: UUID) -> Bool {
        guard owners[fishID] != nil, snapshots[fishID]?.inflation?.canRequest == true,
              !inflationRequests.contains(fishID) else { return false }
        inflationRequests.insert(fishID)
        return true
    }

    func takeInflationRequest(for fishID: UUID, owner: UUID) -> Bool {
        guard isOwner(fishID, owner: owner) else { return false }
        return inflationRequests.remove(fishID) != nil
    }

    func handleViewingTap(token: UUID, fishID: UUID, owner: UUID) {
        guard handledViewingTapToken != token, isOwner(fishID, owner: owner) else { return }
        handledViewingTapToken = token // 膨張中のタップも宝箱へ通さない。
        requestInflation(for: fishID)
    }

    /// 画面遷移のreleaseでは残すが、収納・削除した個体の専用アニメーション状態は破棄する。
    func stopInflation(except activeIDs: Set<UUID>) {
        let removed = snapshots.keys.filter { !activeIDs.contains($0) && (snapshots[$0]?.inflation != nil || snapshots[$0]?.dolphin != nil || snapshots[$0]?.whaleSharkTempo != nil) }
        for id in removed {
            snapshots[id] = nil
            owners[id] = nil
            inflationRequests.remove(id)
        }
    }

    func beginEditing() {
        guard editingSession == nil else { return }
        let editing = AquariumFishViewingSession(id: id)
        editing.snapshots = snapshots
        editing.inflationRequests = inflationRequests
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
            inflationRequests.removeAll()
            stopInflation(except: Set(activeIDs))
        }
        editing.owners.removeAll()
        editingSession = nil
    }
}
