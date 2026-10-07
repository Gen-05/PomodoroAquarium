//
//  AquariumBackground.swift
//  PomodoroAquarium
//

import SwiftUI
import UIKit

enum AquariumBackgroundTheme: String, CaseIterable, Identifiable {
    // 保存IDは維持する。背景は色・光・水深の情景を担い、物体は装飾layerで扱う。
    case aquarium
    case deepSea
    case tropical

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .aquarium: "ベーシック海底"
        case .deepSea: "深い海"
        case .tropical: "サンゴ礁"
        }
    }

    /// v1ではベーシック海底だけに既存の砂地を残す。
    var showsSand: Bool { self == .aquarium }

    /// 00に砂が含まれるため、画像がないfallback時だけSwiftUIの砂を使う。
    var usesFallbackSandLayer: Bool {
        showsSand && UIImage(named: imageName) == nil
    }

    var imageName: String {
        switch self {
        case .aquarium:
            "basic_ocean_00"
        case .deepSea:
            "deep_ocean_00"
        case .tropical:
            "coral_ocean_00"
        }
    }

    var lightFrameNames: [String] {
        switch self {
        case .aquarium:
            [
                "basic_ocean_01", "basic_ocean_02", "basic_ocean_03",
                "basic_ocean_04", "basic_ocean_05"
            ]
        case .tropical:
            [
                "coral_ocean_01", "coral_ocean_02", "coral_ocean_03",
                "coral_ocean_04", "coral_ocean_05"
            ]
        case .deepSea:
            [
                "deep_ocean_01", "deep_ocean_02", "deep_ocean_03",
                "deep_ocean_04", "deep_ocean_05"
            ]
        }
    }

    var fallbackColors: [Color] {
        switch self {
        case .aquarium:
            [
                Color(red: 0.20, green: 0.76, blue: 0.86),
                Color(red: 0.03, green: 0.36, blue: 0.66),
                Color(red: 0.01, green: 0.10, blue: 0.28)
            ]
        case .deepSea:
            [Color.indigo.opacity(0.75), Color(red: 0.01, green: 0.04, blue: 0.16)]
        case .tropical:
            [Color.cyan.opacity(0.8), Color.blue.opacity(0.72)]
        }
    }
}

struct AquariumBackground: View {
    let theme: AquariumBackgroundTheme

    @State private var isLightSwaying = false

    init(theme: AquariumBackgroundTheme = .aquarium) {
        self.theme = theme
    }

    private var usesAnimatedOceanAssets: Bool {
        !theme.lightFrameNames.isEmpty && UIImage(named: theme.imageName) != nil
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                backgroundContent(in: geometry.size)

                // 画像の光overlayと旧光表現を二重表示しない。旧光は画像がないfallback時だけ。
                if !usesAnimatedOceanAssets {
                    LinearGradient(
                        colors: [.white.opacity(0.20), .cyan.opacity(0.05), .black.opacity(0.10)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    lightBeams
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 7).repeatForever(autoreverses: true)) {
                isLightSwaying = true
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func backgroundContent(in size: CGSize) -> some View {
        if let backgroundImage = UIImage(named: theme.imageName) {
            if !theme.lightFrameNames.isEmpty {
                OceanLightBackground(
                    baseImage: backgroundImage,
                    size: size,
                    lightFrameNames: theme.lightFrameNames
                )
                .id(theme.id) // 背景だけの再生stateを切替時にリセット。魚には影響しない。
            } else {
                Image(uiImage: backgroundImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .clipped()
            }
        } else {
            LinearGradient(
                colors: theme.fallbackColors,
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var lightBeams: some View {
        ZStack {
            lightBeam(width: 105, opacity: 0.09)
                .rotationEffect(.degrees(isLightSwaying ? 12 : 19), anchor: .top)
                .offset(x: -105, y: -180)

            lightBeam(width: 72, opacity: 0.07)
                .rotationEffect(.degrees(isLightSwaying ? 22 : 14), anchor: .top)
                .offset(x: 65, y: -210)

            Ellipse()
                .fill(.white.opacity(isLightSwaying ? 0.11 : 0.06))
                .frame(width: 330, height: 100)
                .blur(radius: 18)
                .offset(y: -330)
        }
    }

    private func lightBeam(width: CGFloat, opacity: Double) -> some View {
        LinearGradient(
            colors: [.white.opacity(opacity), .white.opacity(opacity * 0.25), .clear],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(width: width, height: 760)
        .blur(radius: 8)
    }
}

/// 固定背景と透過の光だけを重ねる。魚のsimulation・計測用Timerから独立。
private struct OceanLightBackground: View {
    let baseImage: UIImage
    let size: CGSize
    let lightFrameNames: [String]

    // ベーシック海底・サンゴ礁・深い海で同じ再生・合成設定を使う。
    private static let frameDuration = 0.75
    private static let crossFadeDuration = 0.15
    /// 光素材の強さは維持し、切替時だけ短くcross fadeする。
    private static let lightOpacity = 1.0

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lightFrameIndex = 0

    private var animatesLight: Bool { scenePhase == .active && !reduceMotion }

    var body: some View {
        ZStack {
            fullSizeImage(Image(uiImage: baseImage)) // 00は切替・fade・移動の対象にしない。

            // 光layerだけをfadeする。00やAquariumのidentityは変更しない。
            ZStack {
                ForEach(lightFrameNames.indices, id: \.self) { index in
                    fullSizeImage(Image(lightFrameNames[index]))
                        .opacity(index == lightFrameIndex ? 1.0 : 0.0)
                }
            }
            .compositingGroup()
            .opacity(Self.lightOpacity)
            // 固定背景に対して光だけをscreen合成し、明部を穏やかに強調する。
            .blendMode(.screen)
            .animation(.linear(duration: Self.crossFadeDuration), value: lightFrameIndex)
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        .ignoresSafeArea()
        .task(id: animatesLight) {
            guard animatesLight else { return }
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(Self.frameDuration))
                } catch {
                    return
                }
                guard !Task.isCancelled else { return }
                lightFrameIndex = (lightFrameIndex + 1) % lightFrameNames.count
            }
        }
    }

    private func fullSizeImage(_ image: Image) -> some View {
        image
            .resizable()
            .scaledToFill()
            .frame(width: size.width, height: size.height)
            .clipped()
    }
}

#Preview("水・光背景") {
    @Previewable @State var theme: AquariumBackgroundTheme = .aquarium

    ZStack {
        AquariumBackground(theme: theme)
        VStack {
            Picker("背景", selection: $theme) {
                Text(AquariumBackgroundTheme.aquarium.displayName)
                    .tag(AquariumBackgroundTheme.aquarium)
                Text(AquariumBackgroundTheme.tropical.displayName)
                    .tag(AquariumBackgroundTheme.tropical)
                Text(AquariumBackgroundTheme.deepSea.displayName)
                    .tag(AquariumBackgroundTheme.deepSea)
            }
            .pickerStyle(.segmented)
            .padding()
            Spacer()
        }
    }
}
