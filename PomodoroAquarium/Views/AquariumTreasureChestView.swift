import SwiftUI

/// 水槽内の宝箱本体専用。サムネイル・粒子・選択光彩には適用しない。
struct AquariumTreasureChestColorCorrection: ViewModifier {
    let saturation: Double
    let contrast: Double
    let brightness: Double
    let red: Double
    let green: Double
    let blue: Double

    static func correction(for theme: AquariumBackgroundTheme) -> Self {
        switch theme {
        case .aquarium:
            Self(saturation: 0.90, contrast: 0.97, brightness: -0.015, red: 0.97, green: 0.99, blue: 1)
        case .tropical:
            Self(saturation: 0.96, contrast: 0.99, brightness: -0.005, red: 1, green: 1, blue: 1)
        case .deepSea:
            Self(saturation: 0.85, contrast: 0.95, brightness: -0.03, red: 0.90, green: 0.96, blue: 1)
        }
    }

    func body(content: Content) -> some View {
        content.contrast(contrast).saturation(saturation)
            .colorMultiply(Color(red: red, green: green, blue: blue))
            .brightness(brightness)
    }
}

/// 水槽内の宝箱に共通の30fps時計。粒子の開始情報はIDごとに一度だけ作成する。
struct AquariumTreasureChestAnimationLayer<Content: View>: View {
    let instances: [AquariumTreasureChestEffects.Instance]
    let isSimulationPaused: Bool
    @ViewBuilder let content: ([String: AquariumTreasureChestEffects.Frame]) -> Content
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false
    @State private var clock = AquariumTreasureChestClock()
    @State private var patterns: [String: AquariumTreasureChestEffects.Pattern] = [:]

    private var runs: Bool { isVisible && scenePhase == .active && !isSimulationPaused && !reduceMotion && !instances.isEmpty }

    var body: some View {
        Group {
            if instances.isEmpty {
                content([:])
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !runs)) { timeline in
                    content(AquariumTreasureChestEffects.frames(instances: instances,
                        patterns: patterns, elapsed: clock.elapsed(at: timeline.date)))
                }
            }
        }
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false; clock.setRunning(false, at: .now) }
        .onChange(of: runs, initial: true) { _, running in clock.setRunning(running, at: .now) }
        .onChange(of: instances.map(\.id), initial: true) { _, ids in
            let retained = Set(ids)
            patterns = patterns.filter { retained.contains($0.key) }
            for id in ids where patterns[id] == nil {
                patterns[id] = AquariumTreasureChestEffects.Pattern(placementID: id)
            }
        }
    }
}

/// 本体PNGは静止。光彩・奥行きopacityは本体だけに適用し、泡のB案に追加の減衰を掛けない。
struct AquariumTreasureChestView: View {
    let direction: AquariumDecorationFacingDirection
    let frame: AquariumTreasureChestEffects.Frame
    let backgroundTheme: AquariumBackgroundTheme
    let isSelected: Bool
    let bodyOpacity: Double
    // 比較描画用。水槽での呼び出しは常に既定の補正を使用する。
    var appliesColorCorrection = true

    private let side = AquariumTreasureChestEffects.canvasSide
    private let overflowTop: CGFloat = AquariumTreasureChestEffects.overflowTop

    var body: some View {
        Image(AquariumDecorationKind.treasureChest.assetImageName(for: backgroundTheme, facingDirection: direction)!)
            .renderingMode(.original)
            .resizable().scaledToFit()
            .frame(width: side, height: side)
            .modifier(appliesColorCorrection
                ? AquariumTreasureChestColorCorrection.correction(for: backgroundTheme)
                : AquariumTreasureChestColorCorrection(saturation: 1, contrast: 1, brightness: 0, red: 1, green: 1, blue: 1))
            .modifier(AquariumSelectionGlow(isSelected: isSelected))
            .opacity(bodyOpacity)
            .overlay(alignment: .bottom) {
                if !frame.bubbles.isEmpty || !frame.sparkles.isEmpty {
                    Canvas { context, _ in
                        drawEffects(in: context)
                    }
                // 泡がPNGの上端を越えても切れない。overlayなので本体のlayoutは拡大しない。
                .frame(width: side, height: side + overflowTop)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                }
            }
    }

    private func point(_ uv: CGPoint) -> CGPoint {
        CGPoint(x: uv.x * side, y: overflowTop + uv.y * side)
    }
    private func drawEffects(in context: GraphicsContext) {
        var bubbles = context
        var clip = Path()
        clip.move(to: .zero)
        clip.addLine(to: CGPoint(x: side, y: 0))
        for p in AquariumTreasureChestEffects.frontRim(direction).reversed() { clip.addLine(to: point(p)) }
        clip.closeSubpath()
        bubbles.clip(to: clip)
        let image = bubbles.resolve(Image(AquariumTreasureChestEffects.bubbleAsset).renderingMode(.original))
        for bubble in frame.bubbles {
            let center = point(bubble.point)
            let diameter = bubble.diameter / AquariumTreasureChestEffects.bubbleVisibleFraction
            bubbles.opacity = bubble.opacity
            bubbles.draw(image, in: CGRect(x: center.x - diameter / 2, y: center.y - diameter / 2,
                width: diameter, height: diameter))
        }
        for sparkle in frame.sparkles {
            var light = context
            light.opacity = sparkle.opacity * (backgroundTheme == .deepSea ? 0.74 : 1)
            let center = point(sparkle.point), size = sparkle.size
            let reflection = Path(ellipseIn: CGRect(x: center.x - size * 0.48, y: center.y - size * 0.48,
                width: size * 0.96, height: size * 0.96))
            light.fill(reflection, with: .radialGradient(Gradient(colors: [Color(red: 1, green: 0.957, blue: 0.792).opacity(0.45), .clear]),
                center: center, startRadius: 0, endRadius: size * 0.47))
            var star = Path()
            let offsets: [CGPoint] = [CGPoint(x: 0, y: -0.5), CGPoint(x: 0.085, y: -0.085),
                CGPoint(x: 0.35, y: 0), CGPoint(x: 0.085, y: 0.085), CGPoint(x: 0, y: 0.5),
                CGPoint(x: -0.085, y: 0.085), CGPoint(x: -0.35, y: 0), CGPoint(x: -0.085, y: -0.085)]
            for (index, offset) in offsets.enumerated() {
                let p = CGPoint(x: center.x + offset.x * size, y: center.y + offset.y * size)
                if index == 0 { star.move(to: p) } else { star.addLine(to: p) }
            }
            star.closeSubpath()
            light.fill(star, with: .color(Color(red: 1, green: 0.973, blue: 0.875)))
        }
    }
}
