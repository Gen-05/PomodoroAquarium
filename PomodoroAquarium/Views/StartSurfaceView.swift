import SwiftUI

/// 表示と開始イベントだけを持つ。初回完了フラグ・Player・Contextへ書き込まない。
struct StartSurfaceView: View {
    let onStart: () -> Void
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var buttonTextScale: CGFloat = 1
    @State private var isVisible = false
    @State private var hasStarted = false

    var body: some View {
        GeometryReader { geometry in
            let layout = StartSurfaceLayout(size: geometry.size)
            let canvas = layout.canvasRect
            let fish = layout.rect(StartSurfaceLayout.fishRect)
            let button = layout.rect(StartSurfaceLayout.buttonRect)
            ZStack {
                StartSurfaceWaterView(isActive: isVisible && scenePhase == .active && !reduceMotion)
                    .accessibilityHidden(true)
                Image("start_title_logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: canvas.width, height: canvas.height)
                    .position(x: canvas.midX, y: canvas.midY)
                    .accessibilityLabel("Pomodoro Aquarium、ポモドーロ水族館")
                    .accessibilityIdentifier("startSurface.title")
                    .allowsHitTesting(false)
                Image("start_title_clownfish")
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(x: -1, y: 1)
                    .frame(width: fish.width, height: fish.height)
                    .position(x: fish.midX, y: fish.midY)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
                Button {
                    guard !hasStarted else { return }
                    hasStarted = true
                    onStart()
                } label: {
                    Text("スタート")
                        .font(.system(size: max(12, 26 * layout.scale) * buttonTextScale, weight: .semibold))
                        .foregroundStyle(Color(red: 0.03, green: 0.42, blue: 0.69))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(width: button.width)
                        .frame(minHeight: button.height)
                        .background(.white.opacity(0.94), in: Capsule())
                        // 見た目は採用寸法のまま、タップ可能な高さだけ44pt以上を確保する。
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(hasStarted)
                .position(x: button.midX, y: button.midY)
                .accessibilityIdentifier("startSurface.start")
            }
        }
        .ignoresSafeArea()
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
    }
}
