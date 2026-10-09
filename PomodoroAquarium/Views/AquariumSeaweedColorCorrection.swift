import SwiftUI

/// 海藻A・B・C共通の描画時補正。素材・Placement・奥行きのopacityは変更しない。
struct AquariumSeaweedColorCorrection: ViewModifier {
    let hueDegrees: Double
    let saturation: Double
    let brightness: Double
    let red: Double
    let green: Double
    let blue: Double

    static func correction(for theme: AquariumBackgroundTheme) -> Self {
        switch theme {
        case .aquarium:
            Self(hueDegrees: 0, saturation: 1, brightness: 0, red: 1, green: 1, blue: 1)
        case .tropical:
            Self(hueDegrees: 0, saturation: 1.15, brightness: 0.05, red: 1.05, green: 1.12, blue: 0.85)
        case .deepSea:
            Self(hueDegrees: 18, saturation: 0.80, brightness: -0.02, red: 0.65, green: 0.85, blue: 1.10)
        }
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        // ベーシックはmodifierを通さず、元の描画をそのまま維持する。
        if hueDegrees == 0 && saturation == 1 && brightness == 0 && red == 1 && green == 1 && blue == 1 {
            content
        } else {
            content
                .hueRotation(.degrees(hueDegrees))
                .saturation(saturation)
                .colorMultiply(Color(red: red, green: green, blue: blue))
                .brightness(brightness)
        }
    }
}
