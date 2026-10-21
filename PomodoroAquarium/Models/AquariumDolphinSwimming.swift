import Foundation

/// 共有回遊と同じ停止可能なdeltaTimeで進む、イルカだけの画像・推進状態。
enum AquariumDolphinSwimming {
    static let propulsionFrameDuration: TimeInterval = 0.12
    static let glideFrameDuration: TimeInterval = 0.30
    static let propulsionCycles = 2
    static let glideDuration: ClosedRange<TimeInterval> = 3...5
    static let propulsionSpeed: CGFloat = 2.30
    static let glideSpeed: CGFloat = 1.95
    static let speedResponse: Double = 1.2
    // 終端のneutralは次周期・次状態の先頭と共有し、二重に保持しない。
    static let propulsionFrames = [5, 6, 7, 8, 9, 8, 7, 6, 5, 4, 3, 2, 1, 2, 3, 4]
    static let glideFrames = [3, 4, 5, 4, 3, 2, 1, 2]
    static let glideImageNames = (1...5).map { "fish_dolphin_glide_\($0)" }

    struct State: Equatable {
        enum Phase: Equatable { case propulsion, gliding }
        private(set) var phase: Phase = .propulsion
        private(set) var frameStep = 0
        private(set) var frameElapsed: TimeInterval = 0
        private(set) var phaseElapsed: TimeInterval = 0
        private(set) var plannedGlideDuration: TimeInterval = 0
        private(set) var speedMultiplier: CGFloat = propulsionSpeed
        private var randomState: UInt64

        init(id: UUID, staggered: Bool = true) {
            randomState = AquariumFishMotion.individualSeed(for: id)
            if staggered {
                // UUID全体から決定。再描画・画面遷移では再抽選しない。
                let offset = nextUnit() * (Double(propulsionFrames.count * propulsionCycles) * propulsionFrameDuration + 4.8)
                advance(deltaTime: offset)
            }
        }

        var frameDuration: TimeInterval { phase == .propulsion ? propulsionFrameDuration : glideFrameDuration }
        var frameNumber: Int {
            let frames = phase == .propulsion ? propulsionFrames : glideFrames
            return frames[frameStep % frames.count]
        }
        var imageName: String {
            "fish_dolphin_\(phase == .propulsion ? "side" : "glide")_\(frameNumber)"
        }
        var timeUntilConnection: TimeInterval {
            if phase == .propulsion {
                return Double(propulsionFrames.count * propulsionCycles - frameStep) * frameDuration - frameElapsed
            }
            // 3番へ戻るのは半周期ごと。指定時間を過ぎた最初のneutralまで続ける。
            let steps = max(4, Int(ceil((plannedGlideDuration - 0.000000001) / (4 * frameDuration))) * 4)
            return Double(steps - frameStep) * frameDuration - frameElapsed
        }

        mutating func advance(deltaTime: TimeInterval) {
            guard deltaTime.isFinite, deltaTime > 0 else { return }
            var remaining = deltaTime
            while remaining > 0.000000001 {
                let step = min(remaining, frameDuration - frameElapsed)
                let target = phase == .propulsion ? propulsionSpeed : glideSpeed
                speedMultiplier = target + (speedMultiplier - target) * CGFloat(exp(-speedResponse * step))
                frameElapsed += step
                phaseElapsed += step
                remaining -= step
                if frameElapsed >= frameDuration - 0.000000001 {
                    frameElapsed = 0
                    frameStep += 1
                    if phase == .propulsion && frameStep == propulsionFrames.count * propulsionCycles {
                        phase = .gliding
                        // neutralへ戻る半周期(1.2秒)単位で、3〜5秒内の3.6/4.8秒を選ぶ。
                        let interval = 4 * glideFrameDuration
                        let minimum = Int(ceil(glideDuration.lowerBound / interval))
                        let maximum = Int(floor(glideDuration.upperBound / interval))
                        let steps = min(maximum, minimum + Int(nextUnit() * Double(maximum - minimum + 1)))
                        plannedGlideDuration = Double(steps) * interval
                        frameStep = 0
                        phaseElapsed = 0
                    } else if phase == .gliding && frameStep.isMultiple(of: 4)
                                && phaseElapsed >= plannedGlideDuration - 0.000000001 {
                        phase = .propulsion
                        frameStep = 0
                        phaseElapsed = 0
                    }
                }
            }
        }

        private mutating func nextUnit() -> Double {
            randomState = randomState &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Double(randomState >> 40) / Double(0xFFFFFF)
        }
    }
}
