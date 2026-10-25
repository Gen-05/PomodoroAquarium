import Foundation
import CoreGraphics
import Observation
import SwiftData

/// 購入成功イベントだけで開始する。所有データや編集Draftには案内用の状態を混ぜない。
@MainActor @Observable
final class DecorationPurchaseTutorial {
    static let storageKey = "hasHandledFirstDecorationPurchaseTutorial"

    enum Step: Int, CaseIterable { case edit, library, additions, add, select, move, tools, save, completed }
    enum Phase: Equatable { case idle, waitingForFeedback, invitation, guide(Step) }
    private(set) var phase: Phase = .idle
    private(set) var placementID: String?
    private(set) var kind: AquariumDecorationKind?
    private(set) var isPurchaseFeedbackVisible = false
    private let defaults: UserDefaults
    private var handledFirstPurchaseOverride: Bool?

    /// プレビューでは起動引数の既読値に影響されず、独立した初回状態から開始する。
    init(defaults: UserDefaults = .standard, firstPurchaseHandled: Bool? = nil) {
        self.defaults = defaults
        handledFirstPurchaseOverride = firstPurchaseHandled
    }

    /// 購入成功イベントの入口。購入の確定は既存Serviceに一度だけ任せる。
    @discardableResult
    func purchase(_ item: ShopItem, player: Player?, in context: ModelContext) throws -> AquariumDecorationPlacement {
        let placement = try ShopService.purchaseDecoration(item, for: player, in: context)
        if !(handledFirstPurchaseOverride ?? defaults.bool(forKey: Self.storageKey)) {
            defaults.set(true, forKey: Self.storageKey)
            if handledFirstPurchaseOverride != nil { handledFirstPurchaseOverride = true }
            placementID = placement.decorationID
            kind = placement.kind
            phase = .waitingForFeedback
        }
        return placement
    }

    func purchaseFeedbackWillPresent() { isPurchaseFeedbackVisible = true }

    func purchaseFeedbackDidDismiss() {
        isPurchaseFeedbackVisible = false
        if phase == .waitingForFeedback { phase = .invitation }
    }

    var step: Step? { if case let .guide(step) = phase { step } else { nil } }
    private var selectedID: String?

    // 「はい」は通常の水槽へ移動するだけ。編集の開始は実ボタンから行う。
    func requestEditor() {
        if phase == .invitation { phase = .guide(.edit) }
    }

    func didBeginEditing(placements: [AquariumDecorationPlacement]) {
        guard step == .edit else { return }
        phase = .guide(placements.contains { $0.decorationID == placementID && $0.isPlaced } ? .select : .library)
    }

    func didShowLibrary(isAdding: Bool) {
        guard step == .library || step == .additions || step == .add else { return }
        phase = .guide(isAdding ? .add : .additions)
    }

    func didCloseLibrary() {
        if step == .add || step == .additions { phase = .guide(.library) }
    }

    func showHint(placements: [AquariumDecorationPlacement], selectedID: String?) {
        let available = placements.filter { $0.kind.isAvailable }
        let target = available.first { $0.decorationID == selectedID && $0.isPlaced }
            ?? available.first { $0.decorationID == placementID }
            ?? available.first { !$0.isPlaced } ?? available.first
        kind = target?.kind
        placementID = target?.decorationID
        self.selectedID = selectedID
        if let target, target.isPlaced {
            phase = .guide(target.decorationID == selectedID ? .move : .select)
        } else { phase = .guide(.library) }
    }

    func didAddDecoration(_ placement: AquariumDecorationPlacement) {
        guard step == .add, placement.isPlaced,
              placementID == nil || placementID == placement.decorationID ||
              (kind == .shipwreck && placement.kind == .shipwreck) else { return }
        kind = placement.kind
        placementID = placement.decorationID
        phase = .guide(selectedID == placementID ? .move : .select)
    }

    func didSelectDecoration(_ placement: AquariumDecorationPlacement?) {
        selectedID = placement?.decorationID
        if placement == nil && step == .tools { phase = .guide(.select) }
        guard let placement, placement.isPlaced, placement.decorationID == placementID else { return }
        if step == .select { phase = .guide(.move) }
    }

    func didDragDecoration(id: String, from: CGPoint, to: CGPoint) {
        guard step == .move, kind != .shipwreck, placementID == id, from != to else { return }
        phase = .guide(.tools)
    }

    func didChangeShipwreckSide(id: String, from: AquariumDecorationFacingDirection, to: AquariumDecorationFacingDirection) {
        guard step == .move, kind == .shipwreck, placementID == id, from != to else { return }
        phase = .guide(.tools)
    }

    func reconcilePlacedTarget(_ placements: [AquariumDecorationPlacement]) {
        if step == .library, placements.contains(where: { $0.decorationID == placementID && $0.isPlaced }) {
            phase = .guide(.select)
            return
        }
        guard let step, [.select, .move, .tools, .save].contains(step),
              !placements.contains(where: { $0.decorationID == placementID && $0.isPlaced }) else { return }
        phase = .guide(.library)
    }

    // 説明だけの段階以外は、吹き出しを連打しても進まない。
    func next() {
        if step == .tools { phase = .guide(.save) }
        else if step == .completed { dismiss() }
    }

    func didEndEditing(saved: Bool) {
        if saved && step == .save { phase = .guide(.completed) }
        else if step != nil { dismiss() }
    }

    func dismiss() { phase = .idle }
}

enum DecorationTutorialContent {
    static func message(step: DecorationPurchaseTutorial.Step, kind: AquariumDecorationKind?) -> String {
        let name = kind?.displayName ?? "装飾"
        switch step {
        case .edit: return "まずはここから、水槽を編集してみよう。確認画面で「編集する」を選んでね。"
        case .library: return "「装飾」を押して、一覧を開いてみよう。"
        case .additions: return "「追加する」に切り替えてみよう。"
        case .add:
            return kind == .shipwreck ? "沈没船をタップし、「左奥・右奥」を選ぼう。水槽に置けるのは1隻までだよ。" : "買った\(name)をタップして、水槽に入れてみよう。"
        case .select: return "飾った\(name)をタップしてみよう。"
        case .move:
            return kind == .shipwreck ? "「左奥・右奥」で、今と反対の場所に変えてみよう。沈没船は固定配置だよ。" : "そのままドラッグして、少し場所を動かしてみよう。"
        case .tools:
            if kind == .shipwreck { return "沈没船は「左奥・右奥」で配置を変更。「水槽からしまう」で所持に戻せるよ。" }
            let facing = kind?.supportsFacingDirection == true ? "左右矢印で向きを変更。" : ""
            return "「微調整」の奥へ・手前へは位置の移動。「重なり順」は重なった装飾の前後。\(facing)「水槽からしまう」で所持に戻せるよ。"
        case .save: return "飾れたら「完了」で保存しよう。「×」からは変更を破棄できるよ。"
        case .completed: return "飾れたね！水槽に保存しました。"
        }
    }
}
