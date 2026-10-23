import Foundation

/// イルカと同じ共有deltaTimeで進む、シャチ専用の推進・中立滑走。
enum AquariumOrcaSwimming {
    static let frameDuration: TimeInterval = 0.16
    static let frameCount = 16
    static let propulsionCycles = 2
    static let glideDuration: TimeInterval = 1.4
    // 画像の再生間隔とは独立した移動設定。滑走でも前進を保つ。
    static let propulsionSpeed: CGFloat = 2.10
    static let glideSpeed: CGFloat = 1.75
    static let speedResponse: Double = 1.1

    struct State: Equatable {
        enum Phase: Equatable { case propulsion, gliding }
        private(set) var phase: Phase = .propulsion
        private(set) var phaseElapsed: TimeInterval = 0
        private(set) var speedMultiplier: CGFloat = propulsionSpeed

        init(id: UUID, staggered: Bool = true) {
            if staggered {
                let seed = AquariumFishMotion.individualSeed(for: id) ^ 0x4F52_4341_4359_434C
                let unit = Double(seed >> 40) / Double(0xFFFFFF)
                advance(deltaTime: unit * (Self.propulsionDuration + glideDuration))
            }
        }

        static var propulsionDuration: TimeInterval {
            Double(frameCount * propulsionCycles) * frameDuration
        }

        var frameNumber: Int {
            guard phase == .propulsion else { return 1 }
            return min(Int(floor((phaseElapsed + 0.000000001) / frameDuration)),
                       frameCount * propulsionCycles - 1) % frameCount + 1
        }

        var imageName: String { "fish_orca_side_\(frameNumber)" }

        mutating func advance(deltaTime: TimeInterval) {
            guard deltaTime.isFinite, deltaTime > 0 else { return }
            var remaining = deltaTime
            while remaining > 0.000000001 {
                let duration = phase == .propulsion ? Self.propulsionDuration : glideDuration
                let step = min(remaining, duration - phaseElapsed)
                let target = phase == .propulsion ? propulsionSpeed : glideSpeed
                speedMultiplier = target + (speedMultiplier - target) * CGFloat(exp(-speedResponse * step))
                phaseElapsed += step
                remaining -= step
                if phaseElapsed >= duration - 0.000000001 {
                    phase = phase == .propulsion ? .gliding : .propulsion
                    phaseElapsed = 0 // 接続点は常にside_1。同じ座標・倍率・向きを保つ。
                }
            }
        }
    }
}
