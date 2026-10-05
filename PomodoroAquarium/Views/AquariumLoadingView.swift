import SwiftUI

/// 起動準備などで共通利用する、simulationを持たない軽量なLoading画面。
struct AquariumLoadingView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var swimmingTime: TimeInterval = 0
    @State private var advancesSpinner = false

    private var animatesFish: Bool { scenePhase == .active && !reduceMotion }
    private var animatesBackground: Bool { scenePhase == .active && !reduceMotion }
    private var spinnerCycleDuration: Double? {
        scenePhase == .active ? (reduceMotion ? 2.5 : 2.2) : nil
    }

    var body: some View {
        ZStack {
            background
            ZStack {
                AquariumLoadingSpinner(progress: advancesSpinner ? 10 : 0)
                    .frame(width: 168, height: 168)
                FishImageView(
                    species: .clownfish,
                    animationTime: swimmingTime,
                    animationFrameDuration: FishDetailStrokeAnimationState.frameDuration(for: .clownfish)
                )
                .frame(width: 53, height: 42)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("読み込み中")
        .task(id: spinnerCycleDuration) {
            withAnimation(nil) { advancesSpinner = false }
            guard let duration = spinnerCycleDuration else { return }
            withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                advancesSpinner = true
            }
        }
        .task(id: animatesFish) {
            swimmingTime = 0
            guard animatesFish else { return }
            let frameDuration = FishDetailStrokeAnimationState.frameDuration(for: .clownfish)
            let startedAt = Date()
            // 既存spriteの切替間隔だけ更新。水槽の移動・回遊処理は起動しない。
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(frameDuration))
                } catch {
                    return
                }
                guard !Task.isCancelled else { return }
                swimmingTime = Date().timeIntervalSince(startedAt)
            }
        }
    }

    private var background: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.32, green: 0.72, blue: 0.83),
                        Color(red: 0.07, green: 0.37, blue: 0.60),
                        Color(red: 0.04, green: 0.23, blue: 0.42)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                RadialGradient(
                    colors: [.white.opacity(0.16), .white.opacity(0.04), .clear],
                    center: UnitPoint(x: 0.35, y: 0),
                    startRadius: 0,
                    endRadius: max(geometry.size.width, geometry.size.height) * 0.75
                )
                AquariumLoadingSoftLight(size: geometry.size, animates: animatesBackground)
            }
        }
        .ignoresSafeArea()
    }

}

/// 輪郭線を描かず、上部の面反射・柔らかい水中光・広いガラスの艶を重ねる。
/// simulation・描画用Timer・TimelineViewは使用しない。
private struct AquariumLoadingSoftLight: View {
    let size: CGSize
    let animates: Bool
    @State private var topLightChanges = false
    @State private var sideLightChanges = false
    @State private var glassReflectionChanges = false
    @State private var surfaceLightChanges = false

    private var lightColor: Color { Color(red: 0.86, green: 0.97, blue: 1) }

    var body: some View {
        ZStack {
            Ellipse()
                .fill(RadialGradient(
                    colors: [lightColor, lightColor.opacity(0.3), .clear],
                    center: UnitPoint(x: 0.40, y: 0.35),
                    startRadius: 0,
                    endRadius: size.width * 0.65
                ))
                .frame(width: size.width * 1.35, height: size.height * 0.23)
                .blur(radius: 22)
                .scaleEffect(x: topLightChanges ? 1.04 : 1.01, y: topLightChanges ? 0.99 : 1.03)
                .rotationEffect(.degrees(topLightChanges ? -10 : -14))
                .position(x: size.width * 0.37, y: size.height * 0.12)
                .offset(x: topLightChanges ? 14 : -12, y: topLightChanges ? 8 : -5)
                .opacity(topLightChanges ? 0.20 : 0.16)
                .animation(animates ? .easeInOut(duration: 8.2).repeatForever(autoreverses: true) : nil,
                           value: topLightChanges)

            AquariumLoadingSoftPatch()
                .fill(RadialGradient(
                    colors: [Color(red: 0.70, green: 0.94, blue: 1), .cyan.opacity(0.2), .clear],
                    center: UnitPoint(x: 0.55, y: 0.4),
                    startRadius: 0,
                    endRadius: size.width * 0.52
                ))
                .frame(width: size.width * 0.72, height: size.height * 0.43)
                .blur(radius: 38)
                .scaleEffect(x: sideLightChanges ? 0.99 : 1.04, y: sideLightChanges ? 1.03 : 0.99)
                .rotationEffect(.degrees(sideLightChanges ? 23 : 19))
                .position(x: size.width * 0.82, y: size.height * 0.36)
                .offset(x: sideLightChanges ? -14 : 12, y: sideLightChanges ? -10 : 5)
                .opacity(sideLightChanges ? 0.08 : 0.12)
                .animation(animates ? .easeInOut(duration: 11.4).delay(0.7).repeatForever(autoreverses: true) : nil,
                           value: sideLightChanges)

            glassReflection

            surfaceLight
        }
        .frame(width: size.width, height: size.height)
        .blendMode(.screen)
        .allowsHitTesting(false)
        .task(id: animates) {
            withAnimation(nil) {
                topLightChanges = false
                sideLightChanges = false
                glassReflectionChanges = false
                surfaceLightChanges = false
            }
            guard animates else { return }
            // 各layer側へ個別animationを指定し、周期や位相を共有しない。
            topLightChanges = true
            sideLightChanges = true
            glassReflectionChanges = true
            surfaceLightChanges = true
        }
    }

    private var glassReflection: some View {
        Capsule()
            .fill(LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .white.opacity(0.45), location: 0.25),
                    .init(color: lightColor.opacity(0.85), location: 0.45),
                    .init(color: .cyan.opacity(0.25), location: 0.65),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            .frame(width: size.width * 0.62, height: size.height * 0.82)
            .blur(radius: 28)
            .scaleEffect(x: glassReflectionChanges ? 1.04 : 0.99, y: glassReflectionChanges ? 0.99 : 1.03)
            .rotationEffect(.degrees(glassReflectionChanges ? -16 : -20))
            .position(x: size.width * 0.18, y: size.height * 0.45)
            .offset(x: glassReflectionChanges ? 10 : -14, y: glassReflectionChanges ? -8 : 8)
            .opacity(glassReflectionChanges ? 0.11 : 0.07)
            .animation(animates ? .easeInOut(duration: 9.6).delay(1.4).repeatForever(autoreverses: true) : nil,
                       value: glassReflectionChanges)
    }

    private var surfaceLight: some View {
        Capsule()
            .fill(LinearGradient(
                colors: [.clear, lightColor.opacity(0.7), Color.cyan.opacity(0.25), .clear],
                startPoint: .leading,
                endPoint: .trailing
            ))
            .frame(width: size.width * 1.4, height: size.height * 0.09)
            .blur(radius: 18)
            .scaleEffect(x: surfaceLightChanges ? 1.03 : 0.98, y: 1)
            .rotationEffect(.degrees(surfaceLightChanges ? -3 : -6))
            .position(x: size.width * 0.48, y: size.height * 0.055)
            .offset(x: surfaceLightChanges ? 15 : -18, y: surfaceLightChanges ? 4 : -3)
            .opacity(surfaceLightChanges ? 0.12 : 0.08)
            .animation(animates ? .easeInOut(duration: 10.5).delay(1.8).repeatForever(autoreverses: true) : nil,
                       value: surfaceLightChanges)
    }
}

/// 丸の位置は固定し、先頭と尾のサイズ・濃淡を連続的に巡らせる。
private struct AquariumLoadingSpinner: View, Animatable {
    var progress: Double
    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        ZStack {
            ForEach(0..<10) { index in
                let prominence = prominence(for: index)
                Circle()
                    .fill(Color(red: 0.91, green: 0.98, blue: 1).opacity(0.14 + 0.78 * prominence))
                    .frame(width: 12, height: 12)
                    .scaleEffect(0.33 + 0.67 * prominence)
                    .offset(y: -80)
                    .rotationEffect(.degrees(Double(index) * 36))
            }
        }
    }

    private func prominence(for index: Int) -> Double {
        let distance = (progress - Double(index) + 10).truncatingRemainder(dividingBy: 10)
        let brightness: Double
        if distance <= 5 {
            brightness = pow(1 - distance / 5, 1.6)
        } else if distance >= 9 {
            // 次の丸をなめらかに明るくし、周回境界でも明るさを連続させる。
            brightness = (distance - 9) * (distance - 9)
        } else {
            brightness = 0
        }
        return brightness
    }
}

/// 1枚だけ使用する左右非対称の光の斑点。strokeではなく面をぼかして表示する。
private struct AquariumLoadingSoftPatch: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.width * 0.03, y: rect.height * 0.60))
            path.addCurve(
                to: CGPoint(x: rect.width * 0.78, y: rect.height * 0.16),
                control1: CGPoint(x: rect.width * 0.08, y: rect.height * 0.18),
                control2: CGPoint(x: rect.width * 0.47, y: rect.height * 0.02)
            )
            path.addCurve(
                to: CGPoint(x: rect.width * 0.60, y: rect.height * 0.93),
                control1: CGPoint(x: rect.width * 1.06, y: rect.height * 0.36),
                control2: CGPoint(x: rect.width * 0.84, y: rect.height * 0.80)
            )
            path.addCurve(
                to: CGPoint(x: rect.width * 0.03, y: rect.height * 0.60),
                control1: CGPoint(x: rect.width * 0.28, y: rect.height * 1.02),
                control2: CGPoint(x: -rect.width * 0.06, y: rect.height * 0.88)
            )
            path.closeSubpath()
        }
    }
}

#Preview {
    AquariumLoadingView()
}
