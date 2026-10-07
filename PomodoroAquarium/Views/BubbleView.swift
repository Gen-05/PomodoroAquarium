//
//  BubbleView.swift
//  PomodoroAquarium
//

import SwiftUI

/// Onboardingの独立した演出用。共通水槽には泡を描画しない。
struct BubbleView: View {
    let diameter: CGFloat
    let travelDistance: CGFloat
    let duration: Double
    let delay: Double

    @State private var hasRisen = false

    var body: some View {
        Circle()
            .fill(.white.opacity(0.035))
            .overlay(Circle().stroke(.white.opacity(0.22), lineWidth: 0.8))
            .frame(width: diameter, height: diameter)
            .offset(y: hasRisen ? -travelDistance : 0)
            .onAppear {
                withAnimation(
                    .linear(duration: duration)
                    .delay(delay)
                    .repeatForever(autoreverses: false)
                ) {
                    hasRisen = true
                }
            }
            .accessibilityHidden(true)
    }
}

#Preview("Onboarding用の泡") {
    ZStack {
        Color.blue
        BubbleView(diameter: 12, travelDistance: 160, duration: 12, delay: 0)
            .offset(y: 80)
    }
}
