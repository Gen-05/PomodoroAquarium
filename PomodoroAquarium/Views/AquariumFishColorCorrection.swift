import SwiftUI

/// 水槽内の魚だけに適用する水中光。Asset・alpha・泳ぎの状態は変更しない。
struct AquariumFishColorCorrection: ViewModifier {
    let saturation: Double
    let brightness: Double
    let red: Double
    let green: Double
    let blue: Double
    var contrast: Double = 1

    static func correction(for theme: AquariumBackgroundTheme, species: FishSpecies) -> Self {
        switch theme {
        case .aquarium:
            switch BasicWaterLightResponse(species: species) {
            case .standard:
                Self(saturation: 0.88, brightness: -0.015, red: 0.97, green: 0.99, blue: 1, contrast: 0.96)
            case .vividWarm:
                Self(saturation: 0.84, brightness: -0.015, red: 0.97, green: 0.99, blue: 1, contrast: 0.96)
            case .translucent:
                Self(saturation: 0.92, brightness: -0.005, red: 0.98, green: 0.995, blue: 1, contrast: 0.98)
            }
        case .tropical:
            // 浅瀬の明るさを保ち、控えめな青緑の反射光を加える。
            Self(saturation: 0.94, brightness: 0.008, red: 0.96, green: 1, blue: 1)
        case .deepSea:
            // 半透明のクラゲは補正を半分にし、淡い輪郭とハイライトを残す。
            if species == .jellyfish {
                Self(saturation: 0.94, brightness: -0.03, red: 0.91, green: 0.955, blue: 1)
            } else {
                Self(saturation: 0.88, brightness: -0.06, red: 0.82, green: 0.91, blue: 1)
            }
        }
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        if saturation == 1 && brightness == 0 && red == 1 && green == 1 && blue == 1 && contrast == 1 {
            content
        } else {
            contrastAdjusted(content)
                .saturation(saturation)
                .colorMultiply(Color(red: red, green: green, blue: blue))
                .brightness(brightness)
        }
    }

    @ViewBuilder
    private func contrastAdjusted(_ content: Content) -> some View {
        // 他背景では既存の描画経路を維持し、contrastを重ね掛けしない。
        if contrast == 1 { content } else { content.contrast(contrast) }
    }
}

/// 表示専用の分類。魚モデル・保存データへの項目追加は不要。
private enum BasicWaterLightResponse {
    case standard, vividWarm, translucent
    init(species: FishSpecies) {
        switch species {
        case .clownfish, .seahorse: self = .vividWarm
        case .jellyfish: self = .translucent
        default: self = .standard
        }
    }
}

#if DEBUG
#Preview("魚の水中光・3背景比較") {
    VStack(spacing: 4) {
        ForEach([FishSpecies.clownfish, .manta, .whaleShark, .jellyfish], id: \.self) { species in
            HStack(spacing: 4) {
                ForEach([AquariumBackgroundTheme.aquarium, .tropical, .deepSea], id: \.self) { theme in
                    ZStack {
                        AquariumBackground(theme: theme)
                        FishImageView(species: species, fixedAnimationFrameIndex: 0)
                            .frame(width: 90, height: 90)
                            .modifier(AquariumFishColorCorrection.correction(for: theme, species: species))
                        VStack {
                            Text(theme.displayName).font(.caption2).foregroundStyle(.white)
                            Spacer()
                        }.padding(.top, 8)
                    }.clipped()
                }
            }
        }
    }
}
#endif
