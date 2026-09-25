import SwiftUI

enum CoreTutorialTarget: Hashable {
    case dailyFish
    case coinBalance
    case studySummary
    case homeStart
    case studyMode
    case studySettings
    case studyStart
    case aquariumEdit
    case aquariumDone
    case tutorialClownfish
    case aquariumTab
    case homeTab
}

struct CoreTutorialTargetPreferenceKey: PreferenceKey {
    static var defaultValue: [CoreTutorialTarget: Anchor<CGRect>] = [:]

    static func reduce(
        value: inout [CoreTutorialTarget: Anchor<CGRect>],
        nextValue: () -> [CoreTutorialTarget: Anchor<CGRect>]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, latest in latest })
    }
}

extension View {
    func coreTutorialTarget(_ target: CoreTutorialTarget) -> some View {
        anchorPreference(key: CoreTutorialTargetPreferenceKey.self, value: .bounds) {
            [target: $0]
        }
    }
}

struct CoreTutorialCoachCard: View {
    let title: String
    let message: String
    var details: [String] = []
    var buttonTitle: String?
    var action: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.bold())

            Text(message)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)

            if !details.isEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(details, id: \.self) { detail in
                        Label(detail, systemImage: "checkmark.circle.fill")
                    }
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            }

            if let buttonTitle {
                Button(buttonTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(.cyan)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .foregroundStyle(.primary)
        .padding(18)
        .frame(maxWidth: 330)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(.cyan.opacity(0.7), lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.3), radius: 16, y: 7)
        .accessibilityElement(children: .contain)
    }
}

struct CoreTutorialConversationPage: Equatable {
    struct Feature: Equatable, Identifiable {
        let icon: String
        let text: String

        var id: String { "\(icon)-\(text)" }
    }

    let text: String
    var features: [Feature] = []

    static func message(_ text: String) -> Self {
        Self(text: text)
    }

    static let possibilities = Self(
        text: "ほかにも、こんな楽しみ方があります。",
        features: [
            Feature(icon: "fish.fill", text: "魚を集める"),
            Feature(icon: "sparkles", text: "水槽を飾る"),
            Feature(icon: "chart.bar.fill", text: "集中時間を記録する"),
            Feature(icon: "storefront.fill", text: "ショップで装飾や背景を交換する")
        ]
    )
}

enum CoreTutorialConversationScript {
    static let homeIntro: [CoreTutorialConversationPage] = [
        .message("ポモドーロ水族館へようこそ。"),
        .message("まずは一緒に、最初の1匹と出会ってみましょう。"),
        .message("では、最初にホームから見ていきましょう。"),
        .message("ここでは、今日ゲットした魚の数を確認できます。"),
        .message("25分以上集中すると、魚を1匹ゲットできます。")
    ]

    static let homePoints: [CoreTutorialConversationPage] = [
        .message("こっちはポイントです。"),
        .message("集中すると貯まって、ショップで水槽の装飾や背景と交換できます。")
    ]

    static let homeStudySummary: [CoreTutorialConversationPage] = [
        .message("ここでは、今日と昨日の集中時間を確認できます。"),
        .message("昨日の集中時間が長いほど、今日は珍しい魚に出会いやすくなります。")
    ]

    static let homeStart: [CoreTutorialConversationPage] = [
        .message("では、実際に集中してみましょう。"),
        .message("「勉強をはじめる」を押してみてください。")
    ]

    static let studyMode: [CoreTutorialConversationPage] = [
        .message("集中方法は3つあります。"),
        .message("今回はポモドーロを使ってみましょう。")
    ]

    static let studySettings: [CoreTutorialConversationPage] = [
        .message("勉強時間や休憩時間、セット数はあとから自由に変更できます。"),
        .message("今回は標準の設定で進めます。")
    ]

    static let studyStart: [CoreTutorialConversationPage] = [
        .message(StudyFocusRulesContent.introduction),
        .message(StudyFocusRulesContent.keepScreenOpen),
        .message(StudyFocusRulesContent.backgroundLimit),
        .message("今回はチュートリアルなので、25分待たずに進めます。"),
        .message("集中完了後の流れをすぐ体験してみましょう。"),
        .message("準備ができたら、「勉強開始」を押してみてください。")
    ]

    static let rewardFollowUp: [CoreTutorialConversationPage] = [
        .message("クマノミをゲットできました！"),
        .message("次は、クマノミを水槽に入れてみましょう。"),
        .message("下の「水槽」を押してみてください。")
    ]

    static let aquariumIntro: [CoreTutorialConversationPage] = [
        .message("ここがあなたの水槽です。"),
        .message("さっきゲットしたクマノミを入れてみましょう。"),
        .message("まずは「編集」を押してみてください。")
    ]

    static let fishPlacement: [CoreTutorialConversationPage] = [
        .message("クマノミを水槽へスライドしてみましょう。")
    ]

    static let aquariumSave: [CoreTutorialConversationPage] = [
        .message("できました！"),
        .message("最後に編集を保存しましょう。")
    ]

    static let aquariumReturnHome: [CoreTutorialConversationPage] = [
        .message("最初の1匹が水槽にやってきました！"),
        .message("一度ホームに戻ってみましょう。"),
        .message("下の「ホーム」を押してみてください。")
    ]

    static let finishing: [CoreTutorialConversationPage] = [
        .message("これで基本の流れは完了です。"),
        .possibilities,
        .message("それでは、自分だけの水族館を育てていきましょう。")
    ]
}

func coreTutorialConversationPage(
    in pages: [CoreTutorialConversationPage],
    at index: Int
) -> CoreTutorialConversationPage {
    pages[min(max(index, 0), pages.count - 1)]
}

struct CoreTutorialConversationCard: View {
    let displayedText: String
    let features: [CoreTutorialConversationPage.Feature]
    let isTextComplete: Bool
    let allowsAdvance: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: 28, height: 28)
                .background(.cyan.opacity(0.34), in: Circle())

            VStack(alignment: .leading, spacing: 9) {
                Text(displayedText.isEmpty ? " " : displayedText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                if isTextComplete, !features.isEmpty {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(features) { feature in
                            Label(feature.text, systemImage: feature.icon)
                        }
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.9))
                }

                if isTextComplete {
                    Text(allowsAdvance ? "タップして続ける" : "画面の案内に沿って操作してください")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white.opacity(0.65))
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: 350, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.cyan.opacity(0.2))
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(0.5), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.24), radius: 12, y: 5)
        .accessibilityElement(children: .combine)
    }
}

struct CoreTutorialPulseHighlight: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .overlay {
                if isActive {
                    CoreTutorialHighlightBorder()
                }
            }
    }
}

private struct CoreTutorialHighlightBorder: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 18)
            .stroke(.cyan.opacity(0.9), lineWidth: 3)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

extension View {
    func coreTutorialHighlight(_ isActive: Bool) -> some View {
        modifier(CoreTutorialPulseHighlight(isActive: isActive))
    }
}

private struct CoreTutorialSpotlightShape: Shape {
    let targetFrame: CGRect

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        path.addRoundedRect(
            in: targetFrame.insetBy(dx: -10, dy: -8),
            cornerSize: CGSize(width: 18, height: 18)
        )
        return path
    }
}

struct CoreTutorialPointingHand: View {
    let targetFrame: CGRect
    let containerWidth: CGFloat
    let containerHeight: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Image(systemName: handSymbolName)
            .font(.system(size: 38, weight: .medium))
            .foregroundStyle(Color(red: 0.84, green: 0.97, blue: 1).opacity(0.55))
            .shadow(color: .black.opacity(0.16), radius: 4, y: 2)
            .scaleEffect(x: pointsFromAbove ? 1 : (pointsFromRight ? 1 : -1), y: 1)
            .position(handPosition)
            // Symbol自身の描画だけをpulseさせる。SwiftUIのanimation transactionを
            // anchor preference経由で実画面側へ伝播させない。
            .symbolEffect(
                .pulse,
                options: .repeating.speed(0.75),
                isActive: !reduceMotion
            )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var pointsFromRight: Bool {
        targetFrame.midX <= containerWidth / 2
    }

    private var pointsFromAbove: Bool {
        targetFrame.midY > containerHeight * 0.75
    }

    private var handSymbolName: String {
        pointsFromAbove ? "hand.point.down.fill" : "hand.point.up.left.fill"
    }

    private var handPosition: CGPoint {
        if pointsFromAbove {
            // Bottom controls (including the real Tab button) use their resolved
            // anchor centre. The symbol centre stays just above that point so its
            // fingertip, rather than the whole hand, lands on the control.
            return CGPoint(
                x: min(max(targetFrame.midX, 24), containerWidth - 24),
                y: targetFrame.midY - 17
            )
        }

        let rawX: CGFloat
        if targetFrame.width > containerWidth * 0.55 {
            rawX = targetFrame.maxX - 12
        } else {
            rawX = pointsFromRight ? targetFrame.maxX + 25 : targetFrame.minX - 25
        }
        return CGPoint(
            x: min(max(rawX, 24), containerWidth - 24),
            y: targetFrame.maxY + 28
        )
    }
}

struct CoreTutorialSpotlightStep: View {
    let targetFrame: CGRect?
    let page: CoreTutorialConversationPage
    let pageIndex: Int
    var showsPointingHand = false
    var allowsConversationAdvance = true
    var allowsTargetInteraction = false
    var onConversationAdvance: () -> Void = {}
    let accessibilityIdentifier: String

    @State private var capturedTargetFrame: CGRect?
    @State private var capturedStepIdentifier: String?
    @State private var latestTargetFrame: CGRect?

    var body: some View {
        GeometryReader { geometry in
            let fixedTargetFrame = resolvedTargetFrame

            ZStack {
                if let fixedTargetFrame {
                    CoreTutorialSpotlightShape(targetFrame: fixedTargetFrame)
                        .fill(
                            Color.black.opacity(0.43),
                            style: FillStyle(eoFill: true)
                        )
                        .transaction { transaction in
                            transaction.animation = nil
                        }
                        .allowsHitTesting(false)

                    RoundedRectangle(cornerRadius: 18)
                        .stroke(.cyan.opacity(0.94), lineWidth: 2.5)
                        .frame(
                            width: fixedTargetFrame.width + 20,
                            height: fixedTargetFrame.height + 16
                        )
                        .position(x: fixedTargetFrame.midX, y: fixedTargetFrame.midY)
                        .shadow(color: .cyan.opacity(0.42), radius: 8)
                        .transaction { transaction in
                            transaction.animation = nil
                        }
                        .allowsHitTesting(false)

                    if showsPointingHand {
                        CoreTutorialPointingHand(
                            targetFrame: fixedTargetFrame,
                            containerWidth: geometry.size.width,
                            containerHeight: geometry.size.height
                        )
                    }
                } else {
                    Color.black.opacity(0.30)
                        .allowsHitTesting(false)
                }

                conversationLayer(
                    in: geometry.size,
                    safeAreaInsets: geometry.safeAreaInsets,
                    targetFrame: fixedTargetFrame
                )
            }
        }
        .accessibilityIdentifier(accessibilityIdentifier)
        .task(id: captureIdentity) {
            latestTargetFrame = targetFrame
            capturedTargetFrame = nil
            capturedStepIdentifier = nil

            // Navigation遷移中の一時的なAnchor位置ではなく、
            // layoutが確定した対象View自身のframeをStep中の基準にする。
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            captureTargetFrame(latestTargetFrame ?? targetFrame)
        }
        .onChange(of: targetFrame) { _, newFrame in
            if capturedStepIdentifier != captureIdentity {
                latestTargetFrame = newFrame
            }
        }
    }

    @ViewBuilder
    private func conversationLayer(
        in size: CGSize,
        safeAreaInsets: EdgeInsets,
        targetFrame: CGRect?
    ) -> some View {
        CoreTutorialConversationLayer(
            page: page,
            targetFrame: targetFrame,
            containerSize: size,
            safeAreaInsets: safeAreaInsets,
            reservesPointingHandSpace: showsPointingHand,
            allowsAdvance: allowsConversationAdvance,
            allowsTargetInteraction: allowsTargetInteraction,
            onAdvance: onConversationAdvance
        )
        .id(captureIdentity)
    }

    private var resolvedTargetFrame: CGRect? {
        guard capturedStepIdentifier == captureIdentity else {
            return targetFrame
        }
        return capturedTargetFrame ?? targetFrame
    }

    private var captureIdentity: String {
        "\(accessibilityIdentifier).\(pageIndex)"
    }

    private func captureTargetFrame(_ frame: CGRect?) {
        guard let frame else { return }

        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            capturedTargetFrame = frame
            capturedStepIdentifier = captureIdentity
        }
    }
}

private struct CoreTutorialConversationLayer: View {
    let page: CoreTutorialConversationPage
    let targetFrame: CGRect?
    let containerSize: CGSize
    let safeAreaInsets: EdgeInsets
    let reservesPointingHandSpace: Bool
    let allowsAdvance: Bool
    let allowsTargetInteraction: Bool
    let onAdvance: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var displayedText = ""
    @State private var isTextComplete = false
    @State private var isVisible = false
    @State private var typingTask: Task<Void, Never>?
    @State private var advanceTask: Task<Void, Never>?
    @State private var cardSize: CGSize = .zero

    var body: some View {
        ZStack {
            if allowsTargetInteraction {
                CoreTutorialInteractionBlocker(
                    targetFrame: targetFrame,
                    containerSize: containerSize
                )
            } else {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(perform: handleTap)
            }

            card
                .frame(maxWidth: max(min(350, containerSize.width - 48), 1))
                .background {
                    GeometryReader { geometry in
                        Color.clear.preference(
                            key: CoreTutorialConversationCardSizePreferenceKey.self,
                            value: geometry.size
                        )
                    }
                }
                .position(cardPosition)
            .allowsHitTesting(allowsTargetInteraction)
        }
        .onPreferenceChange(CoreTutorialConversationCardSizePreferenceKey.self) { newSize in
            var transaction = Transaction()
            transaction.animation = nil
            withTransaction(transaction) {
                cardSize = newSize
            }
        }
        .onAppear(perform: beginPresentation)
        .onDisappear(perform: cancelTasks)
    }

    private var card: some View {
        CoreTutorialConversationCard(
            displayedText: displayedText,
            features: page.features,
            isTextComplete: isTextComplete,
            allowsAdvance: allowsAdvance
        )
        .offset(x: reduceMotion ? 0 : (isVisible ? 0 : -32))
        .opacity(isVisible ? 1 : 0)
        .animation(.easeOut(duration: reduceMotion ? 0.12 : 0.28), value: isVisible)
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onTapGesture(perform: handleTap)
        .accessibilityIdentifier("coreTutorial.conversationCard")
        .accessibilityValue(isTextComplete ? "全文表示済み" : "入力中")
    }

    private var cardPosition: CGPoint {
        let measuredWidth = cardSize.width > 0
            ? cardSize.width
            : max(min(350, containerSize.width - 48), 1)
        let measuredHeight = cardSize.height > 0 ? cardSize.height : 112
        let horizontalMargin: CGFloat = 24
        let verticalMargin: CGFloat = 18
        let targetGap: CGFloat = reservesPointingHandSpace ? 64 : 18
        let minCenterX = horizontalMargin + measuredWidth / 2
        let maxCenterX = containerSize.width - horizontalMargin - measuredWidth / 2
        let minCenterY = max(safeAreaInsets.top, verticalMargin) + measuredHeight / 2
        let maxCenterY = containerSize.height
            - max(safeAreaInsets.bottom, verticalMargin)
            - measuredHeight / 2

        guard let targetFrame else {
            return CGPoint(
                x: containerSize.width / 2,
                y: clamped(
                    containerSize.height * 0.62,
                    minimum: minCenterY,
                    maximum: maxCenterY
                )
            )
        }

        let belowTargetY = targetFrame.maxY + targetGap + measuredHeight / 2
        let aboveTargetY = targetFrame.minY - targetGap - measuredHeight / 2
        let fitsBelow = belowTargetY <= maxCenterY
        let fitsAbove = aboveTargetY >= minCenterY
        let targetIsUpper = targetFrame.midY < containerSize.height * 0.38
        let targetIsLower = targetFrame.midY > containerSize.height * 0.62
        let preferredY: CGFloat

        if targetIsUpper {
            preferredY = fitsBelow ? belowTargetY : aboveTargetY
        } else if targetIsLower {
            preferredY = fitsAbove ? aboveTargetY : belowTargetY
        } else {
            let roomAbove = targetFrame.minY - max(safeAreaInsets.top, verticalMargin)
            let roomBelow = containerSize.height
                - max(safeAreaInsets.bottom, verticalMargin)
                - targetFrame.maxY
            if roomBelow >= roomAbove {
                preferredY = fitsBelow ? belowTargetY : aboveTargetY
            } else {
                preferredY = fitsAbove ? aboveTargetY : belowTargetY
            }
        }

        return CGPoint(
            x: clamped(
                targetFrame.midX,
                minimum: minCenterX,
                maximum: maxCenterX
            ),
            y: clamped(preferredY, minimum: minCenterY, maximum: maxCenterY)
        )
    }

    private func clamped(_ value: CGFloat, minimum: CGFloat, maximum: CGFloat) -> CGFloat {
        guard minimum <= maximum else { return (minimum + maximum) / 2 }
        return min(max(value, minimum), maximum)
    }

    private func beginPresentation() {
        cancelTasks()
        displayedText = reduceMotion ? page.text : ""
        isTextComplete = reduceMotion
        isVisible = false

        isVisible = true

        guard !reduceMotion else { return }
        typingTask = Task { @MainActor in
            for character in page.text {
                try? await Task.sleep(for: .milliseconds(20))
                guard !Task.isCancelled else { return }
                displayedText.append(character)
            }
            isTextComplete = true
        }
    }

    private func handleTap() {
        if !isTextComplete {
            typingTask?.cancel()
            displayedText = page.text
            isTextComplete = true
            return
        }

        guard allowsAdvance, advanceTask == nil else { return }
        advanceTask = Task { @MainActor in
            if !reduceMotion {
                withAnimation(.easeIn(duration: 0.12)) {
                    isVisible = false
                }
                try? await Task.sleep(for: .milliseconds(120))
                guard !Task.isCancelled else { return }
            }
            onAdvance()
        }
    }

    private func cancelTasks() {
        typingTask?.cancel()
        typingTask = nil
        advanceTask?.cancel()
        advanceTask = nil
    }
}

private struct CoreTutorialConversationCardSizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        if next != .zero {
            value = next
        }
    }
}

/// Blocks the backing screen while leaving only the real tutorial target hittable.
/// Four rectangles form a hole around the resolved target frame, so no fake control
/// is layered over the action the user is asked to perform.
private struct CoreTutorialInteractionBlocker: View {
    let targetFrame: CGRect?
    let containerSize: CGSize

    @ViewBuilder
    var body: some View {
        if let bounds = validContainerBounds {
            if let target = validTarget(in: bounds) {
                ZStack(alignment: .topLeading) {
                    blockingRegion(CGRect(
                        x: 0,
                        y: 0,
                        width: bounds.width,
                        height: target.minY
                    ))
                    blockingRegion(CGRect(
                        x: 0,
                        y: target.maxY,
                        width: bounds.width,
                        height: bounds.height - target.maxY
                    ))
                    blockingRegion(CGRect(
                        x: 0,
                        y: target.minY,
                        width: target.minX,
                        height: target.height
                    ))
                    blockingRegion(CGRect(
                        x: target.maxX,
                        y: target.minY,
                        width: bounds.width - target.maxX,
                        height: target.height
                    ))
                }
                .frame(width: bounds.width, height: bounds.height)
            } else {
                blockingRegion(bounds)
            }
        } else {
            fullSizeBlocker
        }
    }

    private var validContainerBounds: CGRect? {
        guard containerSize.width.isFinite,
              containerSize.height.isFinite,
              containerSize.width > 0,
              containerSize.height > 0 else {
            return nil
        }

        return CGRect(origin: .zero, size: containerSize)
    }

    private func validTarget(in bounds: CGRect) -> CGRect? {
        guard let targetFrame,
              isValidRegion(targetFrame) else {
            return nil
        }

        let target = targetFrame.intersection(bounds)
        return isValidRegion(target) ? target : nil
    }

    @ViewBuilder
    private func blockingRegion(_ frame: CGRect) -> some View {
        if isValidRegion(frame) {
            Color.clear
                .frame(width: frame.width, height: frame.height)
                .contentShape(Rectangle())
                .position(x: frame.midX, y: frame.midY)
                .onTapGesture { }
                .accessibilityHidden(true)
        }
    }

    private func isValidRegion(_ frame: CGRect) -> Bool {
        frame.width.isFinite
            && frame.height.isFinite
            && frame.midX.isFinite
            && frame.midY.isFinite
            && frame.width > 0
            && frame.height > 0
    }

    private var fullSizeBlocker: some View {
        Color.clear
            .contentShape(Rectangle())
            .onTapGesture { }
            .accessibilityHidden(true)
    }
}

struct CoreTutorialGhostDragHint: View {
    let start: CGPoint
    let end: CGPoint

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: CGFloat = 0
    @State private var opacity = 0.0

    private var currentPosition: CGPoint {
        CGPoint(
            x: start.x + (end.x - start.x) * progress,
            y: start.y + (end.y - start.y) * progress
        )
    }

    var body: some View {
        ZStack {
            Path { path in
                path.move(to: start)
                path.addLine(to: end)
            }
            .trim(from: 0, to: max(progress, 0.12))
            .stroke(
                Color.cyan.opacity(0.18),
                style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [5, 8])
            )

            Image(systemName: "hand.draw.fill")
                .font(.system(size: 42, weight: .medium))
                .foregroundStyle(Color(red: 0.82, green: 0.96, blue: 1))
                .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
                .position(currentPosition)
                .opacity(opacity)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task {
            while !Task.isCancelled {
                progress = 0
                opacity = 0
                withAnimation(.easeIn(duration: 0.18)) { opacity = 0.52 }
                try? await Task.sleep(for: .milliseconds(420))
                guard !Task.isCancelled else { return }
                if reduceMotion {
                    progress = 1
                } else {
                    withAnimation(.easeInOut(duration: 1.0)) { progress = 1 }
                }
                try? await Task.sleep(for: .milliseconds(1_050))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.22)) { opacity = 0 }
                try? await Task.sleep(for: .milliseconds(700))
            }
        }
        .accessibilityIdentifier("coreTutorial.ghostHand")
    }
}
