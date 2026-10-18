import Foundation

/// ハリセンボン専用。実時間のTimerではなく、回遊と同じ停止可能なdeltaTimeで進める。
enum AquariumPorcupinefishInflation {
    static let swimmingFrameDuration: TimeInterval = 0.30
    static let inflationDuration: TimeInterval = 1.2
    static let holdingDuration: TimeInterval = 0.8
    static let deflationDuration: TimeInterval = 1.8
    static let automaticInterval: ClosedRange<TimeInterval> = 25...45
    static let inflatedSpeedMultiplier: CGFloat = 0.60
    static let inflationImageNames = (1...10).map { String(format: "fish_porcupinefish_inflate_%02d", $0) }

    struct State: Equatable {
        enum Phase: Equatable { case swimming, inflating, holding, deflating }
        private(set) var phase: Phase = .swimming
        private(set) var phaseElapsed: TimeInterval = 0
        private(set) var waitingTime: TimeInterval = 0
        private(set) var swimmingTime: TimeInterval
        private(set) var requested = false
        let frameDuration: TimeInterval
        private var randomState: UInt64

        init(id: UUID) {
            randomState = AquariumFishMotion.individualSeed(for: id)
            swimmingTime = AquariumFishMotion.spriteAnimationPhase(for: id)
            frameDuration = swimmingFrameDuration * AquariumFishMotion.spriteTempoMultiplier(for: id)
            waitingTime = nextInterval()
        }

        var canRequest: Bool { phase == .swimming && !requested }

        /// 接続フレームへ到達するまで最大約2フレーム待つ。連打の予約は一件だけ。
        @discardableResult
        mutating func request() -> Bool {
            guard canRequest else { return false }
            requested = true
            beginIfNeutral()
            return true
        }

        var swimmingFrameIndex: Int {
            FishSpriteAnimation.pingPongFrameIndex(frameCount: 3,
                elapsedTime: swimmingTime, frameDuration: frameDuration)
        }

        var imageName: String {
            switch phase {
            case .swimming:
                return "fish_porcupinefish_side_\(swimmingFrameIndex + 1)"
            case .inflating:
                let index = min(Int(phaseElapsed / inflationDuration * 9), 9)
                return inflationImageNames[index]
            case .holding:
                return inflationImageNames[9]
            case .deflating:
                let index = max(9 - Int(ceil(phaseElapsed / deflationDuration * 9)), 0)
                return inflationImageNames[index]
            }
        }

        var speedMultiplier: CGFloat {
            let amount: CGFloat
            switch phase {
            case .swimming: amount = 0
            case .inflating: amount = smooth(phaseElapsed / inflationDuration)
            case .holding: amount = 1
            case .deflating: amount = 1 - smooth(phaseElapsed / deflationDuration)
            }
            return 1 - (1 - inflatedSpeedMultiplier) * amount
        }

        mutating func advance(deltaTime: TimeInterval) {
            guard deltaTime.isFinite, deltaTime > 0 else { return }
            var remaining = deltaTime
            while remaining > 0.000000001 {
                if phase == .swimming {
                    if !requested && waitingTime <= 0.000000001 { _ = request() }
                    beginIfNeutral()
                    if phase != .swimming { continue }
                    // neutralフレームを飛ばさず、通常2番とinflate_01を同じ座標・倍率で接続。
                    let untilFrame = frameDuration - swimmingTime.truncatingRemainder(dividingBy: frameDuration)
                    let step = min(remaining, max(untilFrame, 0.00000001),
                                   requested ? remaining : max(waitingTime, 0.00000001))
                    swimmingTime += step
                    waitingTime = max(0, waitingTime - step)
                    remaining -= step
                    if !requested && waitingTime <= 0.000000001 { _ = request() }
                    beginIfNeutral()
                } else {
                    let duration: TimeInterval = switch phase {
                    case .inflating: inflationDuration
                    case .holding: holdingDuration
                    case .deflating: deflationDuration
                    case .swimming: 0
                    }
                    let step = min(remaining, max(duration - phaseElapsed, 0))
                    phaseElapsed += step
                    remaining -= step
                    if phaseElapsed >= duration - 0.000000001 {
                        switch phase {
                        case .inflating: phase = .holding
                        case .holding: phase = .deflating
                        case .deflating:
                            phase = .swimming
                            swimmingTime = frameDuration // side_2 == inflate_01
                            requested = false
                            waitingTime = nextInterval() // 収縮完了から次の待ち時間を数える。
                        case .swimming: break
                        }
                        phaseElapsed = 0
                    }
                }
            }
        }

        private mutating func beginIfNeutral() {
            guard requested, phase == .swimming, swimmingFrameIndex == 1 else { return }
            phase = .inflating
            phaseElapsed = 0
        }

        private mutating func nextInterval() -> TimeInterval {
            randomState = randomState &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            let unit = Double(randomState >> 40) / Double(0xFFFFFF)
            return automaticInterval.lowerBound + unit * (automaticInterval.upperBound - automaticInterval.lowerBound)
        }

        private func smooth(_ progress: TimeInterval) -> CGFloat {
            let p = CGFloat(min(max(progress, 0), 1))
            return p * p * (3 - 2 * p)
        }
    }
}
