import SwiftUI

/// Home's original two rings, plus a larger START variant using the same ring renderer.
struct WaterRippleView: View {
    enum Variant {
        case home
        case studyStart

        static let startRingDelay: TimeInterval = 0.12
        static let startDuration: TimeInterval = 1.6
    }

    let variant: Variant
    var origin = CGPoint(x: 0.5, y: 0.5)
    @State private var hasExpanded = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<(variant == .home ? 2 : 3), id: \.self) { index in
                    ring(index, size: geometry.size)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .position(x: geometry.size.width * origin.x, y: geometry.size.height * origin.y)
        }
        .onAppear { hasExpanded = true }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func ring(_ index: Int, size: CGSize) -> some View {
        let isHome = variant == .home
        let horizontal = max(origin.x, 1 - origin.x) * size.width
        let vertical = max(origin.y, 1 - origin.y) * size.height
        let screenDiameter = sqrt(horizontal * horizontal + vertical * vertical) * 2.08
        let finalDiameter: CGFloat = isHome ? [190, 140][index] : screenDiameter * [1, 0.90, 0.78][index]
        let initialDiameter: CGFloat = [18, 10, 8][index]
        let lineWidth: CGFloat = isHome ? [0.9, 0.8][index] : [1.2, 1.0, 0.9][index]
        let initialOpacity: Double = isHome ? [0.42, 0.32][index] : [0.52, 0.42, 0.32][index]
        let animation: Animation = isHome
            ? .easeOut(duration: 0.6).delay(index == 0 ? 0 : 0.05)
            : .easeInOut(duration: Variant.startDuration - 2 * Variant.startRingDelay)
                .delay(Double(index) * Variant.startRingDelay)

        return Circle()
            .stroke(index == 0 ? Color.white : Color(red: 0.72, green: 0.94, blue: 1), lineWidth: lineWidth)
            .frame(width: hasExpanded ? finalDiameter : initialDiameter,
                   height: hasExpanded ? finalDiameter : initialDiameter)
            .opacity(hasExpanded ? 0 : initialOpacity)
            .animation(animation, value: hasExpanded)
    }
}
