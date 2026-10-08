import SwiftUI

enum AquariumDecorationFramePlayback {
    /// 素材順に0→1→…→最終→0とループする。
    nonisolated static func frameIndex(step: Int, frameCount: Int) -> Int {
        guard frameCount > 0 else { return 0 }
        return max(0, step) % frameCount
    }

    /// Swiftのランダム化Hasherは使わず、個体IDから再現可能な開始frameを得る。
    nonisolated static func startFrameOffset(placementID: String?, frameCount: Int) -> Int {
        guard let placementID, !placementID.isEmpty, frameCount > 1 else { return 0 }
        let hash = placementID.utf8.reduce(UInt64(14_695_981_039_346_656_037)) {
            ($0 ^ UInt64($1)) &* 1_099_511_628_211
        }
        return Int(hash % UInt64(frameCount))
    }
}

/// 低頻度の装飾frame再生。魚のsimulationや背景animationから独立する。
struct AquariumDecorationFrameView: View {
    let kind: AquariumDecorationKind
    var placementID: String? = nil

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step = 0
    @State private var nextStep = 0
    @State private var fadeProgress = 0.0
    @State private var isCrossFading = false

    private var animates: Bool {
        scenePhase == .active && !reduceMotion && kind.animationFrameNames.count > 1
    }

    var body: some View {
        ZStack {
            frameImage(at: step)
                .opacity(1 - fadeProgress)
            frameImage(at: nextStep)
                .opacity(fadeProgress)
                .blendMode(.plusLighter)
        }
        // 半透明画像の重なりで暗くならないよう、2枚の加算合成をこの透明group内に限定する。
        .compositingGroup()
        .frame(width: kind.displaySize.width, height: kind.displaySize.height)
        .task(id: animates) {
            settleTransition()
            guard animates else { return }
            let fadeDuration = min(kind.animationCrossFadeDuration, kind.animationFrameDuration)
            let holdDuration = max(0, kind.animationFrameDuration - fadeDuration)
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(holdDuration))
                    guard !Task.isCancelled else { return }
                    nextStep = (step + 1) % kind.animationFrameNames.count
                    isCrossFading = true
                    withAnimation(.easeInOut(duration: fadeDuration)) {
                        fadeProgress = 1
                    }
                    try await Task.sleep(for: .seconds(fadeDuration))
                } catch {
                    return
                }
                guard !Task.isCancelled else { return }
                settleTransition()
            }
        }
    }

    private func frameImage(at step: Int) -> some View {
        let offset = AquariumDecorationFramePlayback.startFrameOffset(
            placementID: placementID, frameCount: kind.animationFrameNames.count
        )
        let index = AquariumDecorationFramePlayback.frameIndex(
            step: step + offset, frameCount: kind.animationFrameNames.count
        )
        return Image(kind.animationFrameNames[index])
            .resizable()
            .scaledToFit()
            .frame(width: kind.displaySize.width, height: kind.displaySize.height)
    }

    private func settleTransition() {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            if isCrossFading { step = nextStep }
            nextStep = step
            fadeProgress = 0
            isCrossFading = false
        }
    }
}

#if DEBUG
/// 同じ海藻animationを3背景で比較。保存・Aquarium simulationは使用しない。
struct AquariumSeaweedAnimationPreview: View {
    var body: some View {
        HStack(spacing: 2) {
            ForEach(AquariumBackgroundTheme.allCases, id: \.self) { theme in
                GeometryReader { geometry in
                    ZStack {
                        AquariumBackground(theme: theme)
                        AquariumDecorationFrameView(kind: .seaweedA)
                            .offset(y: AquariumDecorationKind.seaweedA.groundAnchorOffset())
                            .position(x: geometry.size.width / 2, y: geometry.size.height * 0.86)
                        VStack {
                            Text(theme.displayName)
                                .font(.caption2)
                                .foregroundStyle(.white)
                                .padding(.top, 16)
                            Spacer()
                        }
                    }
                    .clipped()
                }
            }
        }
        .environment(\.scenePhase, .active)
    }
}

#Preview("海藻A・3背景") {
    AquariumSeaweedAnimationPreview()
}
#endif
