import SwiftUI

/// Presentation-only ambience, mounted only during the cave scene.
struct FishRewardCaveAtmosphere: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var particles: [CaveParticle] = []

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ZStack {
                    ForEach(CaveLightLayer.layers) { layer in
                        if reduceMotion {
                            CaveFlowingLight(layer: layer, size: geometry.size, phase: 0)
                                .opacity(0.55)
                        } else {
                            // PhaseAnimator commits its starting pose before advancing; no onAppear state jump.
                            Color.clear.phaseAnimator([0, 1, 2]) { _, phase in
                                CaveFlowingLight(layer: layer, size: geometry.size, phase: phase)
                            } animation: { _ in
                                .easeInOut(duration: layer.duration)
                            }
                        }
                    }
                }
                .mask {
                    RadialGradient(
                        colors: [.white, .white.opacity(0.8), .clear],
                        center: FishRewardMysteryAppearance.approachAnchor,
                        startRadius: geometry.size.width * 0.12,
                        endRadius: min(geometry.size.width * 0.75, geometry.size.height * 0.36)
                    )
                }

                ForEach(particles) { particle in
                    if reduceMotion {
                        CaveParticleImage(particle: particle)
                            .position(particle.position(in: geometry.size, phase: 0))
                    } else {
                        CaveParticleImage(particle: particle)
                            .phaseAnimator([0, 1, 2]) { image, phase in
                                image.position(particle.position(in: geometry.size, phase: phase))
                            } animation: { _ in
                                .linear(duration: particle.duration)
                            }
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            // Randomness is sampled once, retained across waiting and camera approach.
            guard particles.isEmpty else { return }
            particles = CaveParticle.makeParticles()
        }
        // The owner removes this view on discovery/dismissal, ending every phase animation.
    }
}

private struct CaveParticle: Identifiable {
    let id: Int
    let origin: UnitPoint
    let drift: CGSize
    let diameter: CGFloat
    let opacity: Double
    let duration: TimeInterval
    let initialPhase: Int

    func position(in size: CGSize, phase: Int) -> CGPoint {
        let distance = min(size.width, size.height)
        let offset: CGSize
        switch (phase + initialPhase) % 3 {
        case 0: offset = CGSize(width: -drift.width * 0.5, height: -drift.height * 0.5)
        case 1: offset = CGSize(width: drift.width * 0.5, height: drift.height * 0.5)
        default: offset = CGSize(width: -drift.height * 0.25, height: drift.width * 0.25)
        }
        return CGPoint(x: size.width * origin.x + distance * offset.width,
                       y: size.height * origin.y + distance * offset.height)
    }

    static func makeParticles() -> [Self] {
        // Six columns by three rows keep the particles distributed across the scene.
        (0..<18).map { index in
            let angle = Double.random(in: 0..<(2 * .pi))
            let distance = CGFloat.random(in: 0.18...0.32)
            return Self(
                id: index,
                origin: UnitPoint(x: (CGFloat(index % 6) + .random(in: 0.2...0.8)) / 6,
                                  y: (CGFloat(index / 6) + .random(in: 0.2...0.8)) / 3),
                drift: CGSize(width: CGFloat(cos(angle)) * distance, height: CGFloat(sin(angle)) * distance),
                diameter: .random(in: 2...4),
                opacity: .random(in: 0.3...0.5),
                duration: .random(in: 8...12),
                initialPhase: .random(in: 0..<3)
            )
        }
    }
}

private struct CaveParticleImage: View {
    let particle: CaveParticle

    var body: some View {
        Circle()
            .fill(Color(red: 0.77, green: 0.91, blue: 1).opacity(particle.opacity))
            .frame(width: particle.diameter, height: particle.diameter)
            .blur(radius: 0.3)
    }
}

private struct CaveLightLayer: Identifiable {
    let id: Int
    let center: UnitPoint
    let size: CGSize
    let travel: CGSize
    let angle: Double
    let duration: TimeInterval
    let opacity: Double

    static let layers: [Self] = [
        Self(id: 0, center: UnitPoint(x: 0.44, y: 0.39), size: CGSize(width: 1.12, height: 0.22),
             travel: CGSize(width: 0.22, height: 0.10), angle: -24, duration: 5.8, opacity: 0.40),
        Self(id: 1, center: UnitPoint(x: 0.65, y: 0.48), size: CGSize(width: 0.72, height: 0.32),
             travel: CGSize(width: -0.24, height: 0.10), angle: 18, duration: 7.1, opacity: 0.34),
        Self(id: 2, center: UnitPoint(x: 0.45, y: 0.61), size: CGSize(width: 1.04, height: 0.16),
             travel: CGSize(width: 0.25, height: -0.10), angle: -12, duration: 8.3, opacity: 0.30)
    ]
}

private struct CaveFlowingLight: View {
    let layer: CaveLightLayer
    let size: CGSize
    let phase: Int

    private var displacement: CGFloat { phase == 0 ? -0.5 : (phase == 1 ? 0.5 : -0.15) }

    var body: some View {
        RadialGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: Color(red: 0.38, green: 0.88, blue: 1), location: 0.36),
                .init(color: .cyan.opacity(0.30), location: 0.64),
                .init(color: .clear, location: 1)
            ],
            center: .center, startRadius: 0, endRadius: size.width * 0.46
        )
        .frame(width: size.width * layer.size.width, height: size.width * 0.92)
        .scaleEffect(x: phase == 1 ? 1.12 : 0.9,
                     y: layer.size.height * size.height / (size.width * 0.92) * (phase == 2 ? 1.18 : 0.9))
        .rotationEffect(.degrees(layer.angle + (phase == 1 ? 16 : (phase == 2 ? -12 : 0))))
        .blur(radius: 12)
        .opacity(layer.opacity)
        .blendMode(.screen)
        .position(x: size.width * (layer.center.x + layer.travel.width * displacement),
                  y: size.height * (layer.center.y + layer.travel.height * displacement))
    }
}
