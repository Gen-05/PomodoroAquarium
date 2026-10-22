import Foundation

/// ジンベイザメの画像再生だけを減速する。移動用の時間・乱数には触れない。
enum AquariumWhaleSharkAnimationTempo {
    static let normalDuration: ClosedRange<TimeInterval> = 5...12
    static let slowDuration: ClosedRange<TimeInterval> = 3...7
    static let transitionDuration: ClosedRange<TimeInterval> = 1.5...3
    static let slowSpeed: ClosedRange<Double> = 0.60...0.75

    struct State: Equatable {
        enum Phase: Equatable { case normal, slowing, slow, returning }
        private(set) var phase: Phase = .normal
        private(set) var phaseElapsed: TimeInterval = 0
        private(set) var phaseDuration: TimeInterval = 0
        private(set) var slowSpeedMultiplier: Double = 1
        private(set) var playbackTime: TimeInterval
        private(set) var randomState: UInt64

        init(id: UUID, playbackTime: TimeInterval = 0) {
            self.playbackTime = playbackTime
            randomState = AquariumFishMotion.individualSeed(for: id) ^ 0x5753_5445_4D50_4F31
            phaseDuration = random(in: normalDuration)
        }

        var speedMultiplier: Double {
            let p = min(max(phaseElapsed / phaseDuration, 0), 1)
            let smooth = p * p * (3 - 2 * p)
            let (start, end) = endpointSpeeds
            return start + (end - start) * smooth
        }

        mutating func advance(deltaTime: TimeInterval) {
            guard deltaTime.isFinite, deltaTime > 0 else { return }
            var remaining = deltaTime
            while remaining > 0.000000001 {
                let step = min(remaining, phaseDuration - phaseElapsed)
                let (start, end) = endpointSpeeds
                let a = phaseElapsed / phaseDuration
                let b = min((phaseElapsed + step) / phaseDuration, 1)
                // smoothstepの積分。間隔を直接変えず、進行量を積み上げるので
                // 減速・復帰の途中でも逆戻りやフレーム先頭へのリセットを起こさない。
                playbackTime += start * step + (end - start) * phaseDuration
                    * (integratedSmoothstep(b) - integratedSmoothstep(a))
                phaseElapsed += step
                remaining -= step
                if phaseElapsed >= phaseDuration - 0.000000001 { beginNextPhase() }
            }
        }

        private var endpointSpeeds: (Double, Double) {
            switch phase {
            case .normal: (1, 1)
            case .slowing: (1, slowSpeedMultiplier)
            case .slow: (slowSpeedMultiplier, slowSpeedMultiplier)
            case .returning: (slowSpeedMultiplier, 1)
            }
        }

        private mutating func beginNextPhase() {
            phaseElapsed = 0
            // 抽選は初期化と状態の切り替え時だけ。各区間中のtickでは行わない。
            switch phase {
            case .normal:
                phase = .slowing
                slowSpeedMultiplier = random(in: slowSpeed)
                phaseDuration = random(in: transitionDuration)
            case .slowing:
                phase = .slow
                phaseDuration = random(in: slowDuration)
            case .slow:
                phase = .returning
                phaseDuration = random(in: transitionDuration)
            case .returning:
                phase = .normal
                phaseDuration = random(in: normalDuration)
            }
        }

        private mutating func random(in range: ClosedRange<Double>) -> Double {
            randomState = randomState &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            let unit = Double(randomState >> 40) / Double(0xFFFFFF)
            return range.lowerBound + unit * (range.upperBound - range.lowerBound)
        }

        private func integratedSmoothstep(_ p: Double) -> Double {
            p * p * p - p * p * p * p / 2
        }
    }
}
