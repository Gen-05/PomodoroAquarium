import SwiftUI

struct StudyStartRippleView: View {
    let effect: StudyStartPresentation.Effect
    let fadeProgress: CGFloat
    let origin: CGPoint

    var body: some View {
        ZStack {
            if effect == .ripple {
                WaterRippleView(variant: .studyStart, origin: origin)
                StudyStartCueView()
            } else {
                Color(red: 0.80, green: 0.95, blue: 1).opacity(0.15 * fadeProgress)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A one-shot cue above the unchanged ripple. It never starts or measures a session.
private struct StudyStartCueView: View {
    @State private var isVisible = true
    @State private var scale: CGFloat = 0.9
    @State private var opacity: Double = 0

    var body: some View {
        Group {
            if isVisible {
                Text("START!")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(Color(red: 0.92, green: 0.98, blue: 1))
                    .shadow(color: .black.opacity(0.22), radius: 6, y: 3)
                    .shadow(color: .cyan.opacity(0.12), radius: 10)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 24)
                    .scaleEffect(scale)
                    .opacity(opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            do {
                try await Task.sleep(for: .seconds(0.3))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.18)) {
                    scale = 1.05
                    opacity = 1
                }
                try await Task.sleep(for: .seconds(0.18))
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.1)) { scale = 1 }
                // Settle and hold, then remove the cue before any running controls appear.
                try await Task.sleep(for: .seconds(0.52))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.2)) { opacity = 0 }
                try await Task.sleep(for: .seconds(0.2))
                guard !Task.isCancelled else { return }
                isVisible = false
            } catch { return }
        }
    }
}

/// The existing button appearance, with only a tiny pressed response.
struct StudyStartButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.38), radius: 2, y: 1)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Color.cyan.opacity(configuration.isPressed ? 0.28 : 0.22), in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.68), lineWidth: 1))
            .shadow(color: .cyan.opacity(0.18), radius: 8, y: 3)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
