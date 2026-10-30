import SwiftUI

enum DecorationTutorialTarget: Hashable {
    case edit, category, additions, closeLibrary, history, canvas, add(AquariumDecorationKind), placement(String), operations, done, cancel
}

struct DecorationTutorialTargetKey: PreferenceKey {
    static var defaultValue: [DecorationTutorialTarget: Anchor<CGRect>] = [:]
    static func reduce(value: inout [DecorationTutorialTarget: Anchor<CGRect>], nextValue: () -> [DecorationTutorialTarget: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

extension View {
    func decorationTutorialTarget(_ target: DecorationTutorialTarget) -> some View {
        anchorPreference(key: DecorationTutorialTargetKey.self, value: .bounds) { [target: $0] }
    }
}

/// 既存Core Tutorialの吹き出し・指差し・対象以外の操作ブロックを共用する。
struct DecorationTutorialSpotlight: View {
    let tutorial: DecorationPurchaseTutorial
    let targetFrame: CGRect?
    let interactionFrames: [CGRect]

    var body: some View {
        if let step = tutorial.step {
            let isExplanation = step == .tools || step == .completed
            CoreTutorialSpotlightStep(targetFrame: targetFrame,
                page: .message(DecorationTutorialContent.message(step: step, kind: tutorial.kind)),
                pageIndex: step.rawValue, showsTargetHighlight: step != .tools,
                showsPointingHand: step != .tools && step != .completed,
                allowsConversationAdvance: isExplanation,
                // 説明中は既存の全面タップ経路で全文表示・説明送りを行い、背後へ通さない。
                allowsTargetInteraction: !isExplanation, followsTargetFrame: true,
                interactionFrames: interactionFrames,
                onConversationAdvance: tutorial.next,
                accessibilityIdentifier: "decorationTutorial.guide.\(step)")
        }
    }
}

struct DecorationPurchaseInvitation: View {
    let tutorial: DecorationPurchaseTutorial
    let useInAquarium: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("買った装飾を水槽に飾ってみますか？").font(.headline)
            HStack(spacing: 24) {
                Button("あとで") { tutorial.dismiss() }
                    .accessibilityIdentifier("decorationTutorial.later")
                Button("はい", action: useInAquarium).buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("decorationTutorial.use")
            }
        }
        .padding(18).frame(maxWidth: 460)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        .padding()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("decorationTutorial.invitation")
    }
}
