//
//  AquariumBackground.swift
//  PomodoroAquarium
//

import SwiftUI
import UIKit

enum AquariumBackgroundTheme: String, CaseIterable, Identifiable {
    case aquarium
    case deepSea
    case tropical

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .aquarium: "通常"
        case .deepSea: "深海"
        case .tropical: "南国"
        }
    }

    var imageName: String {
        switch self {
        case .aquarium:
            "aquariumBackground"
        case .deepSea:
            "deepSeaBackground"
        case .tropical:
            "tropicalBackground"
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

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                backgroundContent(in: geometry.size)

                // 画像の上にも水中らしい色と光を重ねる。
                LinearGradient(
                    colors: [.white.opacity(0.20), .cyan.opacity(0.05), .black.opacity(0.10)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                lightBeams
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
            Image(uiImage: backgroundImage)
                .resizable()
                .scaledToFill()
                .frame(width: size.width, height: size.height)
                .clipped()
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

#Preview {
    AquariumBackground(theme: .aquarium)
}
