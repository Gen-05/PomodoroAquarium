import SwiftUI

/// 静止サンゴ共通の水中光補正。元PNGのalphaと陰影を維持する。
struct AquariumCoralColorCorrection: ViewModifier {
    let contrast: Double
    let saturation: Double
    let brightness: Double
    let red: Double
    let green: Double
    let blue: Double

    static func correction(for theme: AquariumBackgroundTheme, kind: AquariumDecorationKind) -> Self {
        guard kind.decorationType == .coral else {
            return Self(contrast: 1, saturation: 1, brightness: 0, red: 1, green: 1, blue: 1)
        }
        switch theme {
        case .aquarium:
            return Self(contrast: 1, saturation: 1, brightness: 0, red: 1, green: 1, blue: 1)
        case .tropical:
            return Self(contrast: 0.96, saturation: 0.92, brightness: -0.02, red: 0.97, green: 1, blue: 1)
        case .deepSea:
            return Self(contrast: 1, saturation: 0.94, brightness: -0.025, red: 0.90, green: 0.96, blue: 1)
        }
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        if contrast == 1 && saturation == 1 && brightness == 0 && red == 1 && green == 1 && blue == 1 {
            content
        } else {
            content
                .contrast(contrast)
                .saturation(saturation)
                .colorMultiply(Color(red: red, green: green, blue: blue))
                .brightness(brightness)
        }
    }
}

#if DEBUG
/// 全形状を同じY・保存scale=1で比較。実際の装飾Viewと共通depthを使用する。
private struct CoralThemeComparisonPreview: View {
    var body: some View {
        VStack(spacing: 8) {
            ForEach([AquariumBackgroundTheme.aquarium, .tropical, .deepSea], id: \.self) { theme in
                GeometryReader { geometry in
                    ZStack {
                        AquariumBackground(theme: theme)
                        ForEach(Array([AquariumDecorationKind.coralAPink, .coralBPink, .coralCPink].enumerated()), id: \.element) { index, kind in
                            let depth = AquariumDecorationDepthPresentation(kind: kind, relativeY: 0.90)
                            AquariumDecorationView(decoration: AquariumDecoration(
                                id: kind.rawValue, kind: kind, relativeX: 0.5, relativeY: 0.90, scale: 1
                            ), backgroundTheme: theme)
                            .scaleEffect(depth.scale)
                            .opacity(depth.opacity)
                            .offset(y: kind.groundAnchorOffset(scale: depth.scale))
                            .position(x: geometry.size.width * CGFloat(index * 2 + 1) / 6, y: geometry.size.height * 0.90)
                        }
                        VStack {
                            Text(theme.displayName).font(.caption).foregroundStyle(.white)
                            Spacer()
                        }.padding(.top, 8)
                    }.clipped()
                }
                .frame(height: 210)
            }
        }
    }
}

#Preview("サンゴA・B・C：同じ奥行き／3背景") {
    CoralThemeComparisonPreview()
}
#endif
