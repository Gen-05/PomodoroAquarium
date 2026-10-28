import Foundation
import Observation
import SwiftData

/// ショップ内の確認→結果だけを管理する。購入の確定・検証は既存Serviceへ任せる。
@MainActor @Observable
final class ShopPurchaseFlow {
    struct Feedback: Identifiable {
        let id = UUID()
        let message: String
    }

    var confirmation: ShopItem?
    var feedback: Feedback?
    private var pendingFeedback: Feedback?
    private var isCompletingPurchase = false

    var isPresenting: Bool { confirmation != nil || isCompletingPurchase || feedback != nil }

    func requestConfirmation(for item: ShopItem) {
        guard !isPresenting, case .decoration = item.content else { return }
        confirmation = item
    }

    func confirm(player: Player?, in context: ModelContext, tutorial: DecorationPurchaseTutorial?) {
        guard let item = confirmation, !isCompletingPurchase, feedback == nil else { return }
        isCompletingPurchase = true
        tutorial?.purchaseFeedbackWillPresent()
        let message: String
        do {
            if let tutorial {
                try tutorial.purchase(item, player: player, in: context)
            } else {
                try ShopService.purchaseDecoration(item, for: player, in: context)
            }
            message = "\(item.name)を購入しました"
        } catch ShopPurchaseError.insufficientCoins {
            message = "コインが足りません"
        } catch ShopPurchaseError.soldOut {
            message = "沈没船は売り切れです"
        } catch {
            message = "購入できませんでした"
        }
        pendingFeedback = Feedback(message: message)
        confirmation = nil // この時点から、確定の連打は受け付けない。
    }

    func confirmationDidDismiss() {
        // キャンセル・スワイプ終了ではpendingFeedbackがなく、結果や案内は表示しない。
        guard let result = pendingFeedback else { return }
        pendingFeedback = nil
        feedback = result
    }

    func feedbackDidDismiss(tutorial: DecorationPurchaseTutorial?) {
        guard isCompletingPurchase, pendingFeedback == nil, feedback == nil else { return }
        isCompletingPurchase = false
        tutorial?.purchaseFeedbackDidDismiss()
    }
}
