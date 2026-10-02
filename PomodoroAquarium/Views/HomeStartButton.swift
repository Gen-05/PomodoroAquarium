import SwiftUI

/// Home only. TimerView keeps its existing start button style.
struct HomeWaterSurfaceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white.opacity(0.94))
            .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                LinearGradient(
                    colors: [
                        .white.opacity(configuration.isPressed ? 0.16 : 0.10),
                        .cyan.opacity(configuration.isPressed ? 0.22 : 0.14),
                        .blue.opacity(0.10)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                in: Capsule()
            )
            .overlay(Capsule().stroke(.white.opacity(0.38), lineWidth: 0.8))
            .shadow(color: .cyan.opacity(0.06), radius: 4, y: 1)
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
    }
}

struct HomeStartRipple: View {
    var body: some View {
        WaterRippleView(variant: .home)
    }
}
