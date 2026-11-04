import Foundation
import CoreGraphics

/// 採用 render.swift の泡の軌道を1回だけ再生。完成後は点を保持する。
enum StartTitleBubblePresentation {
    static let travelDuration: TimeInterval = 2.65
    static let formedStart: TimeInterval = 3.08
    static let formedDuration: TimeInterval = 0.48
    static let duration: TimeInterval = 0.45 + 2 * 0.24 + travelDuration
    static let motifScale = StartSurfaceLayout.iDotRadius / 11.8
    static let lineWidth: CGFloat = 1.6 * motifScale

    struct Particle {
        let center: CGPoint
        let radius: CGFloat
        let opacity: CGFloat
    }

    static func particle(_ index: Int, at time: TimeInterval, completed: Bool = false) -> Particle {
        precondition((0..<4).contains(index))
        let mouth = StartSurfaceLayout.fishMouth
        let dot = StartSurfaceLayout.iDotCenter
        if completed || time >= duration {
            return Particle(center: dot, radius: index == 3 ? StartSurfaceLayout.iDotRadius : 0,
                            opacity: index == 3 ? 1 : 0)
        }
        let t = max(0, time)
        if index == 3 {
            let formed = ease((t - formedStart) / formedDuration)
            return Particle(center: dot, radius: StartSurfaceLayout.iDotRadius * (0.88 + 0.12 * formed), opacity: formed)
        }
        let start = 0.45 + Double(index) * 0.24
        let u = (t - start) / travelDuration
        guard u >= 0, u < 1 else { return Particle(center: mouth, radius: 0, opacity: 0) }
        let v = ease(u)
        let center = CGPoint(x: mouth.x + (dot.x - mouth.x) * v,
                             y: mouth.y + (dot.y - mouth.y) * u - 12 * motifScale * sin(.pi * u))
        let radius = ((index == 0 ? 9.0 : 5.0) + 2 * u) * motifScale
        let alpha = min(1, u * 12) * (1 - ease((u - 0.92) / 0.08))
        return Particle(center: center, radius: radius, opacity: alpha)
    }

    private static func ease(_ value: Double) -> Double {
        let u = min(1, max(0, value))
        return u * u * (3 - 2 * u)
    }
}
