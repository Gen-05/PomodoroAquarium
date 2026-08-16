//
//  BubbleView.swift
//  PomodoroAquarium
//

import SwiftUI

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

struct BubbleLayer: View {
    private static let bubbles: [BubbleConfiguration] = (0..<14).map { index in
        BubbleConfiguration(
            id: index,
            relativeX: CGFloat.random(in: 0.06...0.94),
            relativeY: CGFloat.random(in: 0.35...1.05),
            diameter: CGFloat.random(in: 5...17),
            duration: Double.random(in: 11...19),
            delay: Double.random(in: 0...7)
        )
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(Self.bubbles) { bubble in
                    BubbleView(
                        diameter: bubble.diameter,
                        travelDistance: geometry.size.height + 100,
                        duration: bubble.duration,
                        delay: bubble.delay
                    )
                    .position(
                        x: geometry.size.width * bubble.relativeX,
                        y: geometry.size.height * bubble.relativeY
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct BubbleConfiguration: Identifiable {
    let id: Int
    let relativeX: CGFloat
    let relativeY: CGFloat
    let diameter: CGFloat
    let duration: Double
    let delay: Double
}

#Preview {
    ZStack {
        Color.blue
        BubbleLayer()
    }
}
