import CoreGraphics
import Foundation

/// 大型魚の従来設定と、小魚・浮遊系の広い回遊域を分離する。
enum FishRoamingStyle {
    case legacy, small, drifting, bluefinTuna

    var distantTargetProbability: CGFloat {
        switch self {
        case .legacy: 0
        case .small, .bluefinTuna: 0.28
        case .drifting: 0.24
        }
    }

    func bounds(in aquariumSize: CGSize, fishSize: CGFloat) -> FishRoamingBounds {
        guard self != .legacy, aquariumSize.width > 0, aquariumSize.height > 0 else {
            return .legacy
        }
        // 回転時の半対角と微小な泳動offsetを確保。画像のframe/scaleは変えない。
        let radius = fishSize * 0.72 + 6
        // クロマグロは追加回転・上下動がなく、実画像の最大半幅/半高で余白を確保する。
        let horizontalRadius = self == .bluefinTuna ? fishSize * 0.40 + 6 : radius
        let verticalRadius = self == .bluefinTuna ? fishSize * 0.20 + 6 : radius
        let xMargin = min(0.45, max(0.05, horizontalRadius / aquariumSize.width))
        let yMargin = min(0.45, max(0.07, verticalRadius / aquariumSize.height))
        return FishRoamingBounds(
            horizontal: xMargin...(1 - xMargin), vertical: yMargin...(1 - yMargin),
            horizontalWallMargin: self == .bluefinTuna ? 0.15 : 0.07,
            verticalWallMargin: self == .bluefinTuna ? 0.15 : 0.06
        )
    }
}

struct FishRoamingBounds {
    let horizontal: ClosedRange<CGFloat>
    let vertical: ClosedRange<CGFloat>
    let horizontalWallMargin: CGFloat
    let verticalWallMargin: CGFloat

    static let legacy = FishRoamingBounds(
        horizontal: 0.18...0.82, vertical: 0.16...0.62,
        horizontalWallMargin: 0.15, verticalWallMargin: 0.12
    )
}

struct FishMovementProfile {
    var roamingStyle: FishRoamingStyle = .legacy
    var usesStationKeeping = false
    var wallAvoidanceStrength: CGFloat = 1
    let baseSpeedRange: ClosedRange<CGFloat>
    let hoverProbability: CGFloat
    let burstProbability: CGFloat
    let gatheringProbability: CGFloat
    let wanderingRadiusX: ClosedRange<CGFloat>
    let wanderingRadiusY: ClosedRange<CGFloat>
    let turnResponsivenessRange: ClosedRange<CGFloat>
    let depthRange: ClosedRange<CGFloat>
    let depthScaleRange: ClosedRange<CGFloat>
    let depthOpacityRange: ClosedRange<CGFloat>
    let depthSpeedRange: ClosedRange<CGFloat>
    let depthChangeProbability: CGFloat
    let depthChangeResponse: CGFloat
    let directionHoldDurationRange: ClosedRange<TimeInterval>
    let burstSpeedMultiplierRange: ClosedRange<CGFloat>
    let burstDurationRange: ClosedRange<TimeInterval>
    let burstCooldownRange: ClosedRange<TimeInterval>
    let hoverDurationRange: ClosedRange<TimeInterval>
    let steeringNoiseMultiplier: CGFloat
    let verticalDirectionBias: CGFloat
    let accelerationResponseRange: ClosedRange<CGFloat>
    let brakingResponseRange: ClosedRange<CGFloat>
    let swimPhaseSpeedMultiplier: CGFloat

    static let clownfish = FishMovementProfile(
        roamingStyle: .small,
        baseSpeedRange: 0.020...0.032,
        hoverProbability: 0.34,
        burstProbability: 0.24,
        gatheringProbability: 0.06,
        wanderingRadiusX: 0.24...0.48,
        wanderingRadiusY: 0.24...0.46,
        turnResponsivenessRange: 0.62...1.02,
        depthRange: 0.12...0.92,
        depthScaleRange: 1.0...1.0,
        depthOpacityRange: 0.76...1.0,
        depthSpeedRange: 0.82...1.10,
        depthChangeProbability: 0.58,
        depthChangeResponse: 0.34,
        directionHoldDurationRange: 4.0...8.0,
        burstSpeedMultiplierRange: 1.8...2.6,
        burstDurationRange: 0.4...0.9,
        burstCooldownRange: 8.0...20.0,
        hoverDurationRange: 1.0...5.0,
        steeringNoiseMultiplier: 1.0,
        verticalDirectionBias: 0.5,
        accelerationResponseRange: 5.2...7.4,
        brakingResponseRange: 3.2...5.0,
        swimPhaseSpeedMultiplier: 1.0
    )

    /// クラゲなど、水中をゆっくり上下に漂う魚種向けの基準profile。
    static let jellyfish = FishMovementProfile(
        roamingStyle: .drifting,
        baseSpeedRange: 0.008...0.015,
        hoverProbability: 0.55,
        burstProbability: 0,
        gatheringProbability: 0.03,
        wanderingRadiusX: 0.12...0.24,
        wanderingRadiusY: 0.30...0.54,
        turnResponsivenessRange: 0.30...0.55,
        depthRange: 0.18...0.86,
        depthScaleRange: 1.0...1.0,
        depthOpacityRange: 0.80...1.0,
        depthSpeedRange: 0.90...1.02,
        depthChangeProbability: 0.40,
        depthChangeResponse: 0.18,
        directionHoldDurationRange: 5.0...10.0,
        burstSpeedMultiplierRange: 1.0...1.0,
        burstDurationRange: 0.4...0.4,
        burstCooldownRange: 20.0...20.0,
        hoverDurationRange: 2.0...5.0,
        steeringNoiseMultiplier: 0.30,
        verticalDirectionBias: 1.6,
        accelerationResponseRange: 0.9...1.6,
        brakingResponseRange: 0.8...1.4,
        swimPhaseSpeedMultiplier: 0.55
    )

    /// クラゲ型の浮遊性格を維持し、基準移動速度だけを上げたタツノオトシゴ用profile。
    static let seahorse = FishMovementProfile(
        roamingStyle: .drifting,
        baseSpeedRange: 0.016...0.030,
        hoverProbability: 0.55,
        burstProbability: 0,
        gatheringProbability: 0.03,
        wanderingRadiusX: 0.12...0.24,
        wanderingRadiusY: 0.30...0.54,
        turnResponsivenessRange: 0.30...0.55,
        depthRange: 0.18...0.86,
        depthScaleRange: 1.0...1.0,
        depthOpacityRange: 0.80...1.0,
        depthSpeedRange: 0.90...1.02,
        depthChangeProbability: 0.40,
        depthChangeResponse: 0.18,
        directionHoldDurationRange: 5.0...10.0,
        burstSpeedMultiplierRange: 1.0...1.0,
        burstDurationRange: 0.4...0.4,
        burstCooldownRange: 20.0...20.0,
        hoverDurationRange: 2.0...5.0,
        steeringNoiseMultiplier: 0.30,
        verticalDirectionBias: 1.6,
        accelerationResponseRange: 0.9...1.6,
        brakingResponseRange: 0.8...1.4,
        swimPhaseSpeedMultiplier: 0.55
    )

    /// 浮遊型を基にしたミノカサゴ専用設定。既存profileと共有計算は変更しない。
    static let lionfish = FishMovementProfile(
        roamingStyle: .small,
        baseSpeedRange: (clownfish.baseSpeedRange.lowerBound * 0.55)...(clownfish.baseSpeedRange.upperBound * 0.55),
        hoverProbability: 0.20,
        burstProbability: 0,
        gatheringProbability: 0,
        wanderingRadiusX: clownfish.wanderingRadiusX,
        wanderingRadiusY: 0.18...0.32,
        turnResponsivenessRange: jellyfish.turnResponsivenessRange,
        depthRange: clownfish.depthRange,
        depthScaleRange: clownfish.depthScaleRange,
        depthOpacityRange: clownfish.depthOpacityRange,
        depthSpeedRange: clownfish.depthSpeedRange,
        depthChangeProbability: jellyfish.depthChangeProbability,
        depthChangeResponse: jellyfish.depthChangeResponse,
        directionHoldDurationRange: 7.0...12.0,
        burstSpeedMultiplierRange: jellyfish.burstSpeedMultiplierRange,
        burstDurationRange: jellyfish.burstDurationRange,
        burstCooldownRange: jellyfish.burstCooldownRange,
        hoverDurationRange: jellyfish.hoverDurationRange,
        steeringNoiseMultiplier: 0.20,
        verticalDirectionBias: 0.45,
        accelerationResponseRange: jellyfish.accelerationResponseRange,
        brakingResponseRange: jellyfish.brakingResponseRange,
        swimPhaseSpeedMultiplier: jellyfish.swimPhaseSpeedMultiplier
    )

    /// 安全域・奥行きの既存設定のみ再利用。実移動は専用の滞留・近距離移動で決める。
    static let mandarinfish: FishMovementProfile = {
        var profile = lionfish
        profile.usesStationKeeping = true
        return profile
    }()

    /// マンタなど、大きな翼で長距離をゆっくり巡航する魚種向けの基準profile。
    static let manta = FishMovementProfile(
        roamingStyle: .legacy,
        baseSpeedRange: 0.042...0.066,
        hoverProbability: 0.08,
        burstProbability: 0,
        gatheringProbability: 0.04,
        wanderingRadiusX: 0.30...0.55,
        wanderingRadiusY: 0.16...0.30,
        turnResponsivenessRange: 0.22...0.42,
        depthRange: 0.20...0.82,
        depthScaleRange: 1.0...1.0,
        depthOpacityRange: 0.84...1.0,
        depthSpeedRange: 0.92...1.04,
        depthChangeProbability: 0.28,
        depthChangeResponse: 0.16,
        directionHoldDurationRange: 7.0...11.0,
        burstSpeedMultiplierRange: 1.0...1.0,
        burstDurationRange: 0.4...0.4,
        burstCooldownRange: 20.0...20.0,
        hoverDurationRange: 0.8...2.0,
        steeringNoiseMultiplier: 0.20,
        verticalDirectionBias: 0.55,
        accelerationResponseRange: 1.0...1.7,
        brakingResponseRange: 0.9...1.5,
        swimPhaseSpeedMultiplier: 0.70
    )

    /// マンタの回遊性格を再利用するウミガメ専用設定。マンタ本体は変更しない。
    static let seaTurtle = FishMovementProfile(
        roamingStyle: .small,
        baseSpeedRange: (manta.baseSpeedRange.lowerBound * 0.64)...(manta.baseSpeedRange.upperBound * 0.64),
        hoverProbability: 0,
        burstProbability: manta.burstProbability,
        gatheringProbability: 0,
        wanderingRadiusX: manta.wanderingRadiusX,
        wanderingRadiusY: manta.wanderingRadiusY,
        turnResponsivenessRange: manta.turnResponsivenessRange,
        depthRange: manta.depthRange,
        depthScaleRange: manta.depthScaleRange,
        depthOpacityRange: manta.depthOpacityRange,
        depthSpeedRange: manta.depthSpeedRange,
        depthChangeProbability: manta.depthChangeProbability,
        depthChangeResponse: manta.depthChangeResponse,
        directionHoldDurationRange: 9.0...14.0,
        burstSpeedMultiplierRange: manta.burstSpeedMultiplierRange,
        burstDurationRange: manta.burstDurationRange,
        burstCooldownRange: manta.burstCooldownRange,
        hoverDurationRange: manta.hoverDurationRange,
        steeringNoiseMultiplier: 0.16,
        verticalDirectionBias: manta.verticalDirectionBias,
        accelerationResponseRange: manta.accelerationResponseRange,
        brakingResponseRange: manta.brakingResponseRange,
        swimPhaseSpeedMultiplier: manta.swimPhaseSpeedMultiplier
    )

    /// ウミガメと同じ穏やかな旋回。画像の推進/滑走とは独立した基本移動速度。
    static let dolphin: FishMovementProfile = {
        let profile = seaTurtle
        return FishMovementProfile(
            roamingStyle: profile.roamingStyle,
            baseSpeedRange: (profile.baseSpeedRange.lowerBound * 1.10)...(profile.baseSpeedRange.upperBound * 1.10),
            hoverProbability: profile.hoverProbability, burstProbability: profile.burstProbability,
            gatheringProbability: profile.gatheringProbability, wanderingRadiusX: profile.wanderingRadiusX,
            wanderingRadiusY: profile.wanderingRadiusY, turnResponsivenessRange: profile.turnResponsivenessRange,
            depthRange: profile.depthRange, depthScaleRange: profile.depthScaleRange,
            depthOpacityRange: profile.depthOpacityRange, depthSpeedRange: profile.depthSpeedRange,
            depthChangeProbability: profile.depthChangeProbability, depthChangeResponse: profile.depthChangeResponse,
            directionHoldDurationRange: profile.directionHoldDurationRange,
            burstSpeedMultiplierRange: profile.burstSpeedMultiplierRange, burstDurationRange: profile.burstDurationRange,
            burstCooldownRange: profile.burstCooldownRange, hoverDurationRange: profile.hoverDurationRange,
            steeringNoiseMultiplier: profile.steeringNoiseMultiplier, verticalDirectionBias: profile.verticalDirectionBias,
            accelerationResponseRange: profile.accelerationResponseRange, brakingResponseRange: profile.brakingResponseRange,
            swimPhaseSpeedMultiplier: profile.swimPhaseSpeedMultiplier)
    }()

    // 全体速度は従来値のまま、画面X方向の移動成分だけを調整する。
    static let bluefinTunaHorizontalSpeedMultiplier: CGFloat = 6.76

    /// 保存上はmanta枠。基準速度はイルカの通常推進（2.30倍を含む）に対する1.2倍。
    static let bluefinTuna: FishMovementProfile = {
        let profile = dolphin
        var result = FishMovementProfile(
            roamingStyle: .bluefinTuna,
            baseSpeedRange: (profile.baseSpeedRange.lowerBound * AquariumDolphinSwimming.propulsionSpeed * 1.20)...(profile.baseSpeedRange.upperBound * AquariumDolphinSwimming.propulsionSpeed * 1.20),
            hoverProbability: 0, burstProbability: 0, gatheringProbability: 0,
            wanderingRadiusX: profile.wanderingRadiusX, wanderingRadiusY: profile.wanderingRadiusY,
            turnResponsivenessRange: 1.20...1.50, depthRange: profile.depthRange,
            depthScaleRange: profile.depthScaleRange, depthOpacityRange: profile.depthOpacityRange,
            depthSpeedRange: profile.depthSpeedRange, depthChangeProbability: profile.depthChangeProbability,
            depthChangeResponse: profile.depthChangeResponse, directionHoldDurationRange: 16...24,
            burstSpeedMultiplierRange: profile.burstSpeedMultiplierRange, burstDurationRange: profile.burstDurationRange,
            burstCooldownRange: profile.burstCooldownRange, hoverDurationRange: profile.hoverDurationRange,
            steeringNoiseMultiplier: 0, verticalDirectionBias: profile.verticalDirectionBias,
            accelerationResponseRange: profile.accelerationResponseRange, brakingResponseRange: profile.brakingResponseRange,
            swimPhaseSpeedMultiplier: profile.swimPhaseSpeedMultiplier)
        result.wallAvoidanceStrength = 5
        return result
    }()

    /// ジンベエザメなど、止まらず長距離を安定巡航する大型魚向けの基準profile。
    static let whaleShark = FishMovementProfile(
        roamingStyle: .legacy,
        baseSpeedRange: 0.026...0.040,
        hoverProbability: 0,
        burstProbability: 0,
        gatheringProbability: 0.02,
        wanderingRadiusX: 0.42...0.68,
        wanderingRadiusY: 0.20...0.36,
        turnResponsivenessRange: 0.14...0.28,
        depthRange: 0.20...0.82,
        depthScaleRange: 1.0...1.0,
        depthOpacityRange: 0.86...1.0,
        depthSpeedRange: 0.94...1.04,
        depthChangeProbability: 0.20,
        depthChangeResponse: 0.12,
        directionHoldDurationRange: 10.0...15.0,
        burstSpeedMultiplierRange: 1.0...1.0,
        burstDurationRange: 0.4...0.4,
        burstCooldownRange: 30.0...30.0,
        hoverDurationRange: 0.5...0.8,
        steeringNoiseMultiplier: 0.14,
        verticalDirectionBias: 0.48,
        accelerationResponseRange: 0.65...1.05,
        brakingResponseRange: 0.55...0.90,
        swimPhaseSpeedMultiplier: 0.35
    )

    func depthScale(at depth: CGFloat) -> CGFloat {
        interpolate(depthScaleRange, at: depth)
    }

    func depthOpacity(at depth: CGFloat) -> CGFloat {
        interpolate(depthOpacityRange, at: depth)
    }

    func depthSpeedMultiplier(at depth: CGFloat) -> CGFloat {
        interpolate(depthSpeedRange, at: depth)
    }

    private func interpolate(_ range: ClosedRange<CGFloat>, at depth: CGFloat) -> CGFloat {
        let progress = normalizedDepth(depth)
        return range.lowerBound + progress * (range.upperBound - range.lowerBound)
    }

    private func normalizedDepth(_ depth: CGFloat) -> CGFloat {
        min(max(depth, 0), 1)
    }
}

struct WingSwimmingProfile {
    let flapCycleCountRange: ClosedRange<Int>
    let glideDurationRange: ClosedRange<TimeInterval>
    let flapSpeedMultiplier: CGFloat
    let glideSpeedMultiplier: CGFloat
    let glideDecelerationResponseMultiplier: CGFloat
    let glideMinimumSpeedMultiplier: CGFloat
    let glideSteeringMultiplier: CGFloat
    let glidePresentationMultiplier: CGFloat
    let neutralFrameIndex: Int

    static let manta = WingSwimmingProfile(
        flapCycleCountRange: 1...2,
        glideDurationRange: 4.0...8.0,
        flapSpeedMultiplier: 2.20,
        glideSpeedMultiplier: 2.00,
        glideDecelerationResponseMultiplier: 0.20,
        glideMinimumSpeedMultiplier: 1.10,
        glideSteeringMultiplier: 0.25,
        glidePresentationMultiplier: 0.25,
        neutralFrameIndex: 3
    )
}

enum AquariumFishMotion {
    enum Behavior: CaseIterable {
        case cruising
        case wandering
        case hovering
        case burst
        case braking
        case turning
    }

    struct SpeedVariationProfile: Equatable {
        let changeIntervalRange: ClosedRange<TimeInterval>
        let hoveringRange: ClosedRange<CGFloat>
        let wanderingRange: ClosedRange<CGFloat>
        let cruisingRange: ClosedRange<CGFloat>
        let transitionRange: ClosedRange<CGFloat>

        static let seahorse = SpeedVariationProfile(
            changeIntervalRange: 2.0...6.0,
            hoveringRange: 0.60...0.75,
            wanderingRange: 0.75...1.20,
            cruisingRange: 1.10...1.35,
            transitionRange: 0.70...0.90
        )

        func multiplierRange(for behavior: Behavior) -> ClosedRange<CGFloat> {
            switch behavior {
            case .hovering:
                hoveringRange
            case .wandering:
                wanderingRange
            case .cruising, .burst:
                cruisingRange
            case .braking, .turning:
                transitionRange
            }
        }
    }

    static let horizontalRange: ClosedRange<CGFloat> = 0.18...0.82
    static let verticalRange: ClosedRange<CGFloat> = 0.16...0.62
    static let maximumDeltaTime: TimeInterval = 1.0 / 15.0
    static let whaleSharkSpriteFrameDuration: TimeInterval = 0.24 // 移動はFishMovementProfile.whaleSharkで独立調整。

    struct WingCycle {
        enum Phase: Equatable {
            case flapping
            case gliding
        }

        private(set) var phase: Phase = .flapping
        private(set) var flapElapsedTime: TimeInterval = 0
        private(set) var flapCycleCount: Int
        private(set) var glideTimeRemaining: TimeInterval = 0
        private var randomState: UInt64

        init(id: UUID, profile: WingSwimmingProfile) {
            let bytes = withUnsafeBytes(of: id.uuid) { Array($0) }
            randomState = AquariumFishMotion.seed(from: bytes) ^ 0xA7C3_51D9_2E64_8B10
            flapCycleCount = profile.flapCycleCountRange.lowerBound
            flapCycleCount = randomCycleCount(in: profile.flapCycleCountRange)
        }

        mutating func advance(
            deltaTime rawDeltaTime: TimeInterval,
            frameCount: Int,
            frameDuration: TimeInterval,
            profile: WingSwimmingProfile
        ) {
            let deltaTime = min(max(rawDeltaTime, 0), AquariumFishMotion.maximumDeltaTime)
            guard deltaTime > 0 else { return }

            switch phase {
            case .flapping:
                flapElapsedTime += deltaTime
                let stepsPerCycle = max((frameCount - 1) * 2, 1)
                let cycleDuration = Double(stepsPerCycle) * max(frameDuration, 0.01)
                if flapElapsedTime >= cycleDuration * Double(flapCycleCount) {
                    phase = .gliding
                    flapElapsedTime = 0
                    glideTimeRemaining = random(in: profile.glideDurationRange)
                }
            case .gliding:
                glideTimeRemaining -= deltaTime
                if glideTimeRemaining <= 0 {
                    phase = .flapping
                    flapElapsedTime = 0
                    flapCycleCount = randomCycleCount(in: profile.flapCycleCountRange)
                }
            }
        }

        private mutating func randomCycleCount(in range: ClosedRange<Int>) -> Int {
            guard range.lowerBound < range.upperBound else { return range.lowerBound }
            return randomUnit() < 0.72 ? range.lowerBound : range.upperBound
        }

        private mutating func random(in range: ClosedRange<TimeInterval>) -> TimeInterval {
            range.lowerBound + Double(randomUnit()) * (range.upperBound - range.lowerBound)
        }

        private mutating func randomUnit() -> CGFloat {
            randomState = randomState &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return CGFloat((randomState >> 40) & 0xFF_FFFF) / CGFloat(0xFF_FFFF)
        }
    }

    /// Stateと一緒に共有Snapshotへ保持。高さ変更と折り返しの時計は独立させる。
    struct BluefinTunaCruise {
        static let levelDuration: ClosedRange<TimeInterval> = 1...2 // 横進行1〜2回に加える最小保持時間
        static let heightDistance: ClosedRange<CGFloat> = 40...60
        static let heightDuration: ClosedRange<TimeInterval> = 5...8
        static let heightRampFraction: CGFloat = 0.20
        static let maneuverHorizontalSpeedMultiplier: CGFloat = 2.60 // 高さ変更時の横速度。折り返しはturningSpeedで制御。
        static let horizontalModeResponse: CGFloat = 3
        static let maximumVerticalSpeed: CGFloat = 10 // 実際の描画座標でpt/秒
        // 横向きPNGを変形させず、低速の折り返しと画像反転の時刻を分離する。
        static let turnDuration: TimeInterval = 1.6
        static let facingSwitchTime: TimeInterval = 0.8
        static let turningSpeed: CGFloat = 18 // 低速の折り返し上限。pt/秒、直進倍率とは独立。
        static let accelerationDuration: TimeInterval = 0.30
        static let brakingDuration: TimeInterval = 0.45
        static let edgeSlowingTime: CGFloat = 0.325
        enum TurnPhase { case braking, turning, accelerating }
        var aquariumSize: CGSize
        var levelTimeRemaining: TimeInterval
        var levelCrossingsRemaining: Int = 1
        var nextHeightDirection: CGFloat = 1
        var horizontalSpeedMultiplier: CGFloat = FishMovementProfile.bluefinTunaHorizontalSpeedMultiplier
        var heightStart: CGFloat = 0
        var heightTarget: CGFloat?
        var heightElapsed: TimeInterval = 0
        var heightTime: TimeInterval = 0
        var turnElapsed: TimeInterval?
        var turnPhase: TurnPhase?
        var phaseElapsed: TimeInterval = 0
        var countsAsLevelCrossing = false
        var turnEntryVelocity: CGFloat = 0
        var turnSpeed: CGFloat = 0 // 開始時に確保した余裕に収まる低速。正規化座標/秒。
        var brakingTime: TimeInterval = BluefinTunaCruise.brakingDuration
        var direction: CGFloat
        var horizontalVelocity: CGFloat?
    }

    struct State {
        var position: CGPoint
        var velocity: CGVector
        var desiredDirection: CGVector
        var behavior: Behavior
        var behaviorTimeRemaining: TimeInterval
        var anchorPosition: CGPoint
        var localTarget: CGPoint
        var roamingDestination: CGPoint?
        var roamingBounds: FishRoamingBounds
        var currentDepth: CGFloat
        var targetDepth: CGFloat
        var depthVelocity: CGFloat
        var depthChangeTimeRemaining: TimeInterval

        let movementProfile: FishMovementProfile
        let baseSpeed: CGFloat
        var currentSpeed: CGFloat
        var targetSpeed: CGFloat
        let accelerationResponse: CGFloat
        let brakingResponse: CGFloat
        let turnResponsiveness: CGFloat
        let hoverRadius: CGFloat
        let burstProbability: CGFloat
        let hoverProbability: CGFloat
        let gatheringProbability: CGFloat
        let wanderingRadiusX: CGFloat
        let wanderingRadiusY: CGFloat

        var directionChangeTimeRemaining: TimeInterval
        var burstCooldownRemaining: TimeInterval
        var noisePhaseX: CGFloat
        var noisePhaseY: CGFloat
        var swimPhase: CGFloat
        var accelerationMagnitude: CGFloat
        let speedVariationProfile: SpeedVariationProfile?
        var targetSpeedVariationMultiplier: CGFloat
        var speedVariationTimeRemaining: TimeInterval

        var facingSign: CGFloat
        var facingWidth: CGFloat
        var visualTurnTargetSign: CGFloat?
        var visualTurnProgress: CGFloat
        var visualTurnDuration: TimeInterval
        var facingDirection: FishFacingDirection
        var pendingFacingDirection: FishFacingDirection
        var pendingFacingDirectionDuration: TimeInterval
        var presentationMotionIntensity: CGFloat
        var presentationDirectionScale: CGFloat

        var randomState: UInt64
        var stationKeeping: AquariumMandarinfishMotion.State?
        var bluefinCruise: BluefinTunaCruise?

        mutating func advance(
            deltaTime rawDeltaTime: TimeInterval,
            elapsedTime: TimeInterval,
            speedMultiplier: CGFloat = 1,
            behaviorTargetSpeedMultiplier: CGFloat? = nil,
            speedResponseMultiplier: CGFloat = 1,
            minimumSpeedMultiplier: CGFloat = 0,
            steeringNoiseMultiplier: CGFloat = 1
        ) {
            advance(
                deltaTime: rawDeltaTime,
                elapsedTime: elapsedTime,
                neighborPositions: EmptyCollection<CGPoint>(),
                speedMultiplier: speedMultiplier,
                behaviorTargetSpeedMultiplier: behaviorTargetSpeedMultiplier,
                speedResponseMultiplier: speedResponseMultiplier,
                minimumSpeedMultiplier: minimumSpeedMultiplier,
                steeringNoiseMultiplier: steeringNoiseMultiplier
            )
        }

        mutating func advance<NeighborPositions: RandomAccessCollection>(
            deltaTime rawDeltaTime: TimeInterval,
            elapsedTime: TimeInterval,
            neighborPositions: NeighborPositions,
            speedMultiplier: CGFloat = 1,
            behaviorTargetSpeedMultiplier: CGFloat? = nil,
            speedResponseMultiplier: CGFloat = 1,
            minimumSpeedMultiplier: CGFloat = 0,
            steeringNoiseMultiplier: CGFloat = 1
        ) where NeighborPositions.Index == Int, NeighborPositions.Element == CGPoint {
            let deltaTime = min(max(rawDeltaTime, 0), AquariumFishMotion.maximumDeltaTime)
            guard deltaTime > 0 else { return }
            if var stationKeeping {
                stationKeeping.advance(deltaTime: deltaTime)
                self.stationKeeping = stationKeeping
                applyStationKeeping()
                return
            }

            behaviorTimeRemaining -= deltaTime
            directionChangeTimeRemaining -= deltaTime
            burstCooldownRemaining = max(0, burstCooldownRemaining - deltaTime)
            depthChangeTimeRemaining -= deltaTime
            if behaviorTimeRemaining <= 0 {
                transitionBehavior(neighborPositions: neighborPositions)
            } else if directionChangeTimeRemaining <= 0, behavior != .burst, behavior != .braking {
                updateLocalCourse(neighborPositions: neighborPositions)
            }

            updatePresentationMotionIntensity(deltaTime: deltaTime)
            updateSpeedVariation(deltaTime: deltaTime)

            let noise = AquariumFishMotion.smoothNoise(
                time: elapsedTime,
                phaseX: noisePhaseX,
                phaseY: noisePhaseY
            )
            let behaviorSteering = steeringForCurrentBehavior(noise: CGVector(
                dx: noise.dx * steeringNoiseMultiplier,
                dy: noise.dy * steeringNoiseMultiplier
            ))
            let speedRatio = currentSpeed / max(baseSpeed, 0.001)
            let wallStrength = AquariumFishMotion.wallStrength(
                behavior: behavior,
                speedRatio: speedRatio
            )
            // クロマグロの壁回避は予測進路で行う。壁の力を毎フレーム重ねて上下へ流さない。
            let wallForce = movementProfile.roamingStyle == .bluefinTuna ? CGVector.zero : AquariumFishMotion.wallSteering(
                at: position, strength: wallStrength * movementProfile.wallAvoidanceStrength, bounds: roamingBounds
            )
            let headingWeight: CGFloat
            switch behavior {
            case .hovering: headingWeight = 0.06
            case .wandering: headingWeight = 0.42
            case .cruising: headingWeight = 0.66
            case .burst: headingWeight = 1
            case .braking: headingWeight = 0.32
            case .turning: headingWeight = 0.48
            }
            let targetDirection = AquariumFishMotion.normalized(CGVector(
                dx: desiredDirection.dx * headingWeight + behaviorSteering.dx + wallForce.dx,
                dy: desiredDirection.dy * headingWeight + behaviorSteering.dy + wallForce.dy
            ))

            let stateTurnMultiplier: CGFloat = behavior == .turning ? 2.2 : (behavior == .burst ? 0.72 : 1)
            let steeringAmount = 1 - exp(-turnResponsiveness * stateTurnMultiplier * CGFloat(deltaTime))
            let currentDirection = AquariumFishMotion.normalized(velocity)
            let blendedDirection = AquariumFishMotion.normalized(CGVector(
                dx: currentDirection.dx + (targetDirection.dx - currentDirection.dx) * steeringAmount,
                dy: currentDirection.dy + (targetDirection.dy - currentDirection.dy) * steeringAmount
            ))
            updateSpeed(
                deltaTime: deltaTime,
                multiplier: speedMultiplier * targetSpeedVariationMultiplier,
                behaviorTargetSpeedMultiplier: behaviorTargetSpeedMultiplier,
                responseMultiplier: speedResponseMultiplier,
                minimumSpeedMultiplier: minimumSpeedMultiplier
            )
            if movementProfile.roamingStyle == .bluefinTuna {
                advanceBluefinTuna(deltaTime: deltaTime)
                updateFacing(deltaTime: deltaTime)
                updateSwimPhase(deltaTime: deltaTime)
                return
            }
            velocity = CGVector(dx: blendedDirection.dx * currentSpeed, dy: blendedDirection.dy * currentSpeed)
            updateDepth(deltaTime: deltaTime)
            let depthSpeed = movementProfile.depthSpeedMultiplier(at: currentDepth)
            let translation = translationVelocity
            position.x += translation.dx * CGFloat(deltaTime) * depthSpeed
            position.y += translation.dy * CGFloat(deltaTime) * depthSpeed
            position = AquariumFishMotion.clampedPoint(position, bounds: roamingBounds)

            updateFacing(deltaTime: deltaTime)
            updateSwimPhase(deltaTime: deltaTime)
        }

        /// 操舵用velocityを変えずに、座標へ適用するX成分だけを調整する。
        /// この後に正規化や速度全体の再計算を行わず、Y成分を維持する。
        var translationVelocity: CGVector {
            CGVector(dx: velocity.dx * (movementProfile.roamingStyle == .bluefinTuna
                ? FishMovementProfile.bluefinTunaHorizontalSpeedMultiplier : 1), dy: velocity.dy)
        }

        var depthScale: CGFloat {
            movementProfile.depthScale(at: currentDepth)
        }

        var depthOpacity: CGFloat {
            movementProfile.depthOpacity(at: currentDepth)
        }

        var depthSpeedMultiplier: CGFloat {
            movementProfile.depthSpeedMultiplier(at: currentDepth)
        }

        var facingHorizontalScale: CGFloat {
            if movementProfile.roamingStyle == .bluefinTuna {
                return facingSign < 0 ? 1 : -1
            }
            return switch facingDirection {
            case .right, .upRight, .downRight, .up, .down, .front:
                abs(facingWidth)
            case .left, .upLeft, .downLeft:
                -abs(facingWidth)
            }
        }

        private mutating func updateDepth(deltaTime: TimeInterval) {
            if depthChangeTimeRemaining <= 0 {
                chooseNextDepth()
            }

            let behaviorMultiplier: CGFloat
            switch behavior {
            case .hovering: behaviorMultiplier = 0.14
            case .wandering: behaviorMultiplier = 0.72
            case .cruising: behaviorMultiplier = 1
            case .burst: behaviorMultiplier = 0.24
            case .braking: behaviorMultiplier = 0.38
            case .turning: behaviorMultiplier = 0.25
            }
            let amount = 1 - exp(
                -movementProfile.depthChangeResponse
                    * behaviorMultiplier
                    * CGFloat(deltaTime)
            )
            let previousDepth = currentDepth
            currentDepth += (targetDepth - currentDepth) * amount
            currentDepth = min(max(currentDepth, 0), 1)
            depthVelocity = (currentDepth - previousDepth) / max(CGFloat(deltaTime), 0.001)
        }

        private mutating func chooseNextDepth() {
            guard behavior != .turning else {
                depthChangeTimeRemaining = random(in: 0.5...1.2)
                return
            }

            let probabilityMultiplier: CGFloat
            let maximumChange: CGFloat
            let interval: ClosedRange<TimeInterval>
            switch behavior {
            case .hovering:
                probabilityMultiplier = 0.24
                maximumChange = 0.05
                interval = 2.5...5.5
            case .wandering:
                probabilityMultiplier = 1
                maximumChange = 0.24
                interval = 2.0...5.0
            case .cruising:
                probabilityMultiplier = 0.86
                maximumChange = 0.34
                interval = 2.8...6.2
            case .burst:
                probabilityMultiplier = 0.22
                maximumChange = 0.08
                interval = 1.2...2.8
            case .braking:
                probabilityMultiplier = 0.34
                maximumChange = 0.10
                interval = 1.5...3.2
            case .turning:
                return
            }

            if chance(movementProfile.depthChangeProbability * probabilityMultiplier) {
                let proposedDepth = currentDepth + random(in: -maximumChange...maximumChange)
                targetDepth = min(
                    max(proposedDepth, movementProfile.depthRange.lowerBound),
                    movementProfile.depthRange.upperBound
                )

                // 手前へ来る時は少し下、奥へ抜ける時は少し上へ向く傾向だけを加える。
                let depthDelta = targetDepth - currentDepth
                if movementProfile.roamingStyle != .bluefinTuna {
                    desiredDirection = AquariumFishMotion.normalized(CGVector(
                        dx: desiredDirection.dx,
                        dy: desiredDirection.dy + depthDelta * 0.45
                    ))
                }
            }
            depthChangeTimeRemaining = random(in: interval)
        }

        private mutating func steeringForCurrentBehavior(noise: CGVector) -> CGVector {
            // クロマグロは目標点への逐次追従をせず、決めた進路を維持する。
            if movementProfile.roamingStyle == .bluefinTuna { return .zero }
            let noise = CGVector(
                dx: noise.dx * movementProfile.steeringNoiseMultiplier,
                dy: noise.dy * movementProfile.steeringNoiseMultiplier
            )
            switch behavior {
            case .wandering:
                let towardTarget = AquariumFishMotion.direction(from: position, to: localTarget)
                return CGVector(
                    dx: towardTarget.dx * 0.58 + noise.dx * 0.20,
                    dy: towardTarget.dy * 0.66 + noise.dy * 0.27
                )
            case .hovering:
                let offset = CGVector(dx: anchorPosition.x - position.x, dy: anchorPosition.y - position.y)
                let distance = hypot(offset.dx, offset.dy)
                let restoringStrength = min(distance / max(hoverRadius, 0.001), 1) * 0.85
                return CGVector(
                    dx: offset.dx / max(hoverRadius, 0.001) * restoringStrength + noise.dx * 0.34,
                    dy: offset.dy / max(hoverRadius, 0.001) * restoringStrength + noise.dy * 0.42
                )
            case .cruising:
                let towardTarget = AquariumFishMotion.direction(from: position, to: localTarget)
                return CGVector(
                    dx: towardTarget.dx * 0.30 + noise.dx * 0.11,
                    dy: towardTarget.dy * 0.40 + noise.dy * 0.17
                )
            case .burst:
                return CGVector(dx: noise.dx * 0.045, dy: noise.dy * 0.06)
            case .braking:
                return CGVector(dx: noise.dx * 0.16, dy: noise.dy * 0.22)
            case .turning:
                return CGVector(dx: noise.dx * 0.07, dy: noise.dy * 0.09)
            }
        }

        private mutating func updatePresentationMotionIntensity(deltaTime: TimeInterval) {
            let target: CGFloat = behavior == .turning ? 0.30 : 1
            let amount = 1 - exp(-9 * CGFloat(deltaTime))
            presentationMotionIntensity += (target - presentationMotionIntensity) * amount
            let scaleAmount = 1 - exp(-14 * CGFloat(deltaTime))
            presentationDirectionScale += (
                facingDirection.directionScale - presentationDirectionScale
            ) * scaleAmount
        }

        private mutating func updateSpeed(
            deltaTime: TimeInterval,
            multiplier: CGFloat,
            behaviorTargetSpeedMultiplier: CGFloat?,
            responseMultiplier: CGFloat,
            minimumSpeedMultiplier: CGFloat
        ) {
            let previousSpeed = currentSpeed
            let behaviorTargetSpeed = behaviorTargetSpeedMultiplier.map { baseSpeed * max($0, 0) }
                ?? targetSpeed
            let effectiveTargetSpeed = max(
                behaviorTargetSpeed * max(multiplier, 0),
                baseSpeed * max(minimumSpeedMultiplier, 0)
            )
            let baseResponse = effectiveTargetSpeed > currentSpeed ? accelerationResponse : brakingResponse
            let response = baseResponse * max(responseMultiplier, 0)
            let amount = 1 - exp(-response * CGFloat(deltaTime))
            currentSpeed += (effectiveTargetSpeed - currentSpeed) * amount
            accelerationMagnitude = abs(currentSpeed - previousSpeed) / max(CGFloat(deltaTime), 0.001)
        }

        private mutating func updateSpeedVariation(deltaTime: TimeInterval) {
            guard let speedVariationProfile else { return }
            speedVariationTimeRemaining -= deltaTime
            guard speedVariationTimeRemaining <= 0 else { return }

            targetSpeedVariationMultiplier = random(
                in: speedVariationProfile.multiplierRange(for: behavior)
            )
            speedVariationTimeRemaining = random(in: speedVariationProfile.changeIntervalRange)
        }

        private mutating func updateSwimPhase(deltaTime: TimeInterval) {
            let speedRatio = currentSpeed / max(baseSpeed, 0.001)
            let phaseVelocity = 2.0 + min(speedRatio, 3) * 3.2 + min(accelerationMagnitude * 24, 3)
            swimPhase += phaseVelocity
                * movementProfile.swimPhaseSpeedMultiplier
                * CGFloat(deltaTime)
            if swimPhase > .pi * 2 { swimPhase.formTruncatingRemainder(dividingBy: .pi * 2) }
        }

        private mutating func updateFacing(deltaTime: TimeInterval) {
            if movementProfile.roamingStyle == .bluefinTuna {
                // 横向き素材は等倍のまま最も低速の地点で反転。擬似的な立体変形は加えない。
                if let cruise = bluefinCruise, cruise.turnPhase == .turning,
                   cruise.phaseElapsed >= BluefinTunaCruise.facingSwitchTime {
                    facingSign = cruise.direction // 元が右進行なら、新しい左向きの内部signは+1。
                }
                facingWidth = 1
                visualTurnTargetSign = nil
                visualTurnProgress = 0
                facingDirection = facingSign < 0 ? .right : .left
                pendingFacingDirection = facingDirection
                pendingFacingDirectionDuration = 0
                return
            }

            updateFacingWidth(deltaTime: deltaTime)
            let speedThreshold = max(baseSpeed * 0.18, 0.005)
            let planarSpeed = hypot(velocity.dx, velocity.dy)
            if behavior == .hovering, planarSpeed < baseSpeed * 0.55 {
                pendingFacingDirectionDuration = max(0, pendingFacingDirectionDuration - deltaTime)
                return
            }
            guard planarSpeed >= speedThreshold || abs(depthVelocity) >= speedThreshold * 0.45 else {
                pendingFacingDirectionDuration = max(0, pendingFacingDirectionDuration - deltaTime)
                return
            }

            let candidate = FishFacingDirection.quantized(
                velocity: velocity,
                depthVelocity: depthVelocity,
                frontPlanarSpeedThreshold: speedThreshold,
                retaining: facingDirection
            )
            guard candidate != facingDirection else {
                pendingFacingDirection = candidate
                pendingFacingDirectionDuration = 0
                return
            }

            if candidate != pendingFacingDirection {
                pendingFacingDirection = candidate
                pendingFacingDirectionDuration = 0
            } else {
                pendingFacingDirectionDuration += deltaTime
            }

            // 約0.2秒同じ方向が続いた場合だけ表示を変え、小さな揺れによる切替を抑える。
            let confirmation: TimeInterval = 0.20
            guard pendingFacingDirectionDuration >= confirmation else { return }
            facingDirection = candidate
            pendingFacingDirectionDuration = 0

            let targetSign: CGFloat?
            switch candidate {
            case .right, .upRight, .downRight:
                targetSign = -1
            case .left, .upLeft, .downLeft:
                targetSign = 1
            case .up, .down, .front:
                targetSign = nil
            }
            if let targetSign {
                facingSign = targetSign
            }
        }

        private mutating func updateFacingWidth(deltaTime: TimeInterval) {
            if let targetSign = visualTurnTargetSign {
                visualTurnProgress = min(visualTurnProgress + CGFloat(deltaTime / visualTurnDuration), 1)
                let distanceFromMiddle = abs(visualTurnProgress - 0.5) * 2
                facingWidth = 0.30 + 0.70 * distanceFromMiddle
                if visualTurnProgress >= 0.5, facingSign != targetSign {
                    facingSign = targetSign
                }
                if visualTurnProgress >= 1 {
                    facingWidth = 1
                    visualTurnTargetSign = nil
                    visualTurnProgress = 0
                }
            }
        }

        private mutating func transitionBehavior<NeighborPositions: RandomAccessCollection>(
            neighborPositions: NeighborPositions
        ) where NeighborPositions.Index == Int, NeighborPositions.Element == CGPoint {
            let next: Behavior
            let canBurst = burstCooldownRemaining <= 0
            switch behavior {
            case .hovering:
                let roll = randomUnit()
                next = canBurst && roll < burstProbability
                    ? .burst
                    : (roll < 0.72 ? .wandering : .cruising)
            case .cruising:
                let roll = randomUnit()
                if canBurst && roll < burstProbability {
                    next = .burst
                } else if roll < burstProbability + hoverProbability {
                    next = .hovering
                } else if roll < 0.84 {
                    next = .wandering
                } else {
                    next = .turning
                }
            case .wandering:
                let roll = randomUnit()
                if roll < hoverProbability {
                    next = .hovering
                } else if canBurst && roll < hoverProbability + burstProbability {
                    next = .burst
                } else if roll < 0.82 {
                    next = .wandering
                } else {
                    next = .cruising
                }
            case .burst:
                next = .braking
            case .braking:
                next = hoverProbability > 0 && chance(0.62) ? .hovering : .wandering
            case .turning:
                next = hoverProbability > 0 && chance(0.38) ? .hovering : .wandering
            }
            enter(next, neighborPositions: neighborPositions)
        }

        private mutating func enter<NeighborPositions: RandomAccessCollection>(
            _ next: Behavior,
            neighborPositions: NeighborPositions
        ) where NeighborPositions.Index == Int, NeighborPositions.Element == CGPoint {
            behavior = next
            switch next {
            case .wandering:
                behaviorTimeRemaining = random(in: 2.0...6.0)
                targetSpeed = baseSpeed * random(in: 0.40...0.82)
                chooseLocalTarget(neighborPositions: neighborPositions, permitsGathering: true)
                directionChangeTimeRemaining = random(in: movementProfile.directionHoldDurationRange)
            case .hovering:
                behaviorTimeRemaining = random(in: movementProfile.hoverDurationRange)
                anchorPosition = position
                localTarget = position
                targetSpeed = baseSpeed * random(in: 0.04...0.20)
                directionChangeTimeRemaining = random(in: 0.8...1.8)
            case .cruising:
                behaviorTimeRemaining = random(in: 3.0...8.0)
                targetSpeed = baseSpeed * random(in: 0.68...1.05)
                chooseLocalTarget(neighborPositions: neighborPositions, permitsGathering: true)
                directionChangeTimeRemaining = random(in: movementProfile.directionHoldDurationRange)
            case .burst:
                behaviorTimeRemaining = random(in: movementProfile.burstDurationRange)
                targetSpeed = baseSpeed * random(in: movementProfile.burstSpeedMultiplierRange)
                directionChangeTimeRemaining = behaviorTimeRemaining
                burstCooldownRemaining = random(in: movementProfile.burstCooldownRange)
                desiredDirection = perturbedDirection(maxAngle: 0.08)
            case .braking:
                behaviorTimeRemaining = random(in: 0.3...0.8)
                targetSpeed = baseSpeed * random(in: 0.55...0.82)
                directionChangeTimeRemaining = behaviorTimeRemaining
            case .turning:
                behaviorTimeRemaining = random(in: 0.7...1.55)
                targetSpeed = baseSpeed * random(in: 0.38...0.68)
                directionChangeTimeRemaining = behaviorTimeRemaining
                let turnAngle = random(in: 0.75...1.5) * (chance(0.5) ? 1 : -1)
                if movementProfile.roamingStyle != .bluefinTuna {
                    desiredDirection = AquariumFishMotion.rotated(desiredDirection, by: turnAngle)
                }
            }
        }

        private mutating func updateLocalCourse<NeighborPositions: RandomAccessCollection>(
            neighborPositions: NeighborPositions
        ) where NeighborPositions.Index == Int, NeighborPositions.Element == CGPoint {
            if movementProfile.roamingStyle == .bluefinTuna {
                directionChangeTimeRemaining = random(in: movementProfile.directionHoldDurationRange)
                return
            }
            if behavior == .wandering || behavior == .cruising {
                chooseLocalTarget(neighborPositions: neighborPositions, permitsGathering: true)
            }
            let maxAngle: CGFloat = behavior == .hovering ? 0.55 : 0.09
            let targetDirection = AquariumFishMotion.direction(from: position, to: localTarget)
            desiredDirection = AquariumFishMotion.rotated(
                targetDirection,
                by: random(in: -maxAngle...maxAngle)
            )
            directionChangeTimeRemaining = behavior == .hovering
                ? random(in: 1.2...2.4)
                : random(in: movementProfile.directionHoldDurationRange)
        }

        mutating func chooseLocalTarget<NeighborPositions: RandomAccessCollection>(
            neighborPositions: NeighborPositions,
            permitsGathering: Bool
        ) where NeighborPositions.Index == Int, NeighborPositions.Element == CGPoint {
            if movementProfile.roamingStyle == .bluefinTuna {
                if roamingDestination == nil { chooseBluefinTunaForwardTarget() }
                return
            }
            // 遠い目標は短いbehavior遷移で捨てず、同じ速度で時間をかけて回遊する。
            // hoverの停留・既存の方向転換は維持し、大型魚はこの分岐を通さない。
            if movementProfile.roamingStyle != .legacy {
                if let destination = roamingDestination,
                   hypot(destination.x - position.x, destination.y - position.y) > 0.07 {
                    localTarget = destination
                    desiredDirection = AquariumFishMotion.direction(from: position, to: localTarget)
                    return
                }
                roamingDestination = nil
                if chance(movementProfile.roamingStyle.distantTargetProbability) {
                    let x = movementProfile.roamingStyle == .drifting
                        ? position.x + random(in: -wanderingRadiusX...wanderingRadiusX)
                        : random(in: roamingBounds.horizontal)
                    let destination = AquariumFishMotion.clampedPoint(CGPoint(
                        x: x, y: random(in: roamingBounds.vertical)
                    ), bounds: roamingBounds)
                    roamingDestination = destination
                    localTarget = destination
                    desiredDirection = AquariumFishMotion.direction(from: position, to: localTarget)
                    return
                }
            }
            let center: CGPoint
            let isGathering: Bool
            if permitsGathering,
               !neighborPositions.isEmpty,
               chance(gatheringProbability) {
                let index = min(Int(randomUnit() * CGFloat(neighborPositions.count)), neighborPositions.count - 1)
                center = neighborPositions[index]
                isGathering = true
            } else {
                center = position
                isGathering = false
            }

            let xRadius = behavior == .cruising ? wanderingRadiusX * 1.65 : wanderingRadiusX
            let yRadius = behavior == .cruising ? wanderingRadiusY * 1.45 : wanderingRadiusY
            let xOffset: CGFloat
            if isGathering {
                // 同じ場所を目指しても画像が完全には重ならない距離を残す。
                xOffset = random(in: 0.10...0.16) * (chance(0.5) ? 1 : -1)
            } else {
                xOffset = random(in: -xRadius...xRadius)
            }
            localTarget = AquariumFishMotion.clampedPoint(CGPoint(
                x: center.x + xOffset,
                y: center.y + random(in: -yRadius...yRadius)
            ), bounds: roamingBounds)
            desiredDirection = AquariumFishMotion.direction(from: position, to: localTarget)
        }

        private mutating func chooseBluefinTunaForwardTarget() {
            let sign = bluefinCruise?.direction ?? (velocity.dx >= 0 ? 1.0 : -1.0)
            localTarget = CGPoint(x: sign > 0 ? roamingBounds.horizontal.upperBound : roamingBounds.horizontal.lowerBound,
                                  y: bluefinCruise?.heightTarget ?? position.y)
            roamingDestination = localTarget
            desiredDirection = CGVector(dx: sign, dy: 0)
        }

        private mutating func advanceBluefinTuna(deltaTime dt: TimeInterval) {
            guard var cruise = bluefinCruise else { return }
            updateDepth(deltaTime: dt)
            let height = max(cruise.aquariumSize.height, 1)
            let width = max(cruise.aquariumSize.width, 1)
            let depthSpeed = max(depthSpeedMultiplier, 0.001)
            let targetMultiplier = cruise.heightTarget != nil || cruise.turnPhase == .braking || cruise.turnPhase == .turning
                ? BluefinTunaCruise.maneuverHorizontalSpeedMultiplier : FishMovementProfile.bluefinTunaHorizontalSpeedMultiplier
            cruise.horizontalSpeedMultiplier += (targetMultiplier - cruise.horizontalSpeedMultiplier)
                * (1 - exp(-BluefinTunaCruise.horizontalModeResponse * CGFloat(dt)))
            let fullXSpeed = currentSpeed * depthSpeed * cruise.horizontalSpeedMultiplier
            let x = roamingBounds.horizontal
            let remainingX = max(0, cruise.direction > 0 ? x.upperBound - position.x : position.x - x.lowerBound)
            // 減速の積分距離＋低速前進分＋余裕を先読み。直進倍率で折り返し時間を短縮しない。
            let predictionSpeed = max(fullXSpeed, abs(cruise.horizontalVelocity ?? 0))
            let wantedTurnSpeed = min(fullXSpeed, BluefinTunaCruise.turningSpeed / width)
            let turnForwardDistance = wantedTurnSpeed * CGFloat(BluefinTunaCruise.facingSwitchTime / 2)
            let brakingDistance = (predictionSpeed + wantedTurnSpeed) * CGFloat(BluefinTunaCruise.brakingDuration / 2)
                + turnForwardDistance + predictionSpeed * 0.1 + 0.01
            if cruise.turnElapsed == nil, remainingX <= brakingDistance {
                cruise.turnElapsed = 0
                cruise.turnPhase = .braking
                cruise.phaseElapsed = 0
                cruise.countsAsLevelCrossing = cruise.heightTarget == nil
                cruise.turnEntryVelocity = cruise.horizontalVelocity ?? (cruise.direction * fullXSpeed)
                // 減速後の低速前進分も予約。画面サイズ変更で端に近い場合は低速区間も抑える。
                cruise.turnSpeed = min(wantedTurnSpeed, remainingX
                    / CGFloat(BluefinTunaCruise.brakingDuration / 2 + BluefinTunaCruise.facingSwitchTime / 2 + 0.1))
                let reserved = cruise.turnSpeed * CGFloat(BluefinTunaCruise.facingSwitchTime / 2) + 0.001
                cruise.brakingTime = min(BluefinTunaCruise.brakingDuration,
                    Double(max(0, remainingX - reserved) * 2 / max(abs(cruise.turnEntryVelocity) + cruise.turnSpeed, 0.001)))
            }
            func smooth(_ value: CGFloat) -> CGFloat {
                let u = min(max(value, 0), 1)
                return u * u * (3 - 2 * u)
            }
            var horizontal = cruise.direction * fullXSpeed
            if let phase = cruise.turnPhase {
                cruise.turnElapsed = (cruise.turnElapsed ?? 0) + dt
                cruise.phaseElapsed += dt
                switch phase {
                case .braking:
                    if cruise.phaseElapsed < cruise.brakingTime {
                        let progress = smooth(CGFloat(cruise.phaseElapsed / cruise.brakingTime))
                        horizontal = cruise.turnEntryVelocity * (1 - progress) + cruise.direction * cruise.turnSpeed * progress
                    } else {
                        horizontal = cruise.direction * cruise.turnSpeed
                        cruise.turnPhase = .turning
                        cruise.phaseElapsed = 0
                    }
                case .turning:
                    let facingReady = facingSign == cruise.direction
                        && facingDirection == (cruise.direction > 0 ? .left : .right)
                    if cruise.phaseElapsed < BluefinTunaCruise.facingSwitchTime {
                        // 向きが変わる地点へ向けて低速前進をなだらかに弱める。
                        horizontal = cruise.direction * cruise.turnSpeed
                            * (1 - smooth(CGFloat(cruise.phaseElapsed / BluefinTunaCruise.facingSwitchTime)))
                    } else if facingReady {
                        // 前tickで表示方向が切り替わったことを確認してから、低速で新方向へ。
                        let progress = (cruise.phaseElapsed - BluefinTunaCruise.facingSwitchTime)
                            / (BluefinTunaCruise.turnDuration - BluefinTunaCruise.facingSwitchTime)
                        horizontal = -cruise.direction * wantedTurnSpeed * smooth(CGFloat(progress))
                    } else {
                        horizontal = 0
                    }
                    if cruise.phaseElapsed >= BluefinTunaCruise.turnDuration, facingReady {
                        // 外向きの余裕がない開始位置でも、内向きには低速で動き出せる。
                        cruise.turnSpeed = wantedTurnSpeed
                        cruise.direction *= -1
                        cruise.turnPhase = .accelerating
                        cruise.phaseElapsed = 0
                    }
                case .accelerating:
                    let multiplier = cruise.heightTarget != nil
                        ? BluefinTunaCruise.maneuverHorizontalSpeedMultiplier : FishMovementProfile.bluefinTunaHorizontalSpeedMultiplier
                    cruise.horizontalSpeedMultiplier = multiplier
                    let progress = smooth(CGFloat(cruise.phaseElapsed / BluefinTunaCruise.accelerationDuration))
                    let fastSpeed = currentSpeed * depthSpeed * multiplier
                    horizontal = cruise.direction * (cruise.turnSpeed + (fastSpeed - cruise.turnSpeed) * progress)
                    if cruise.phaseElapsed >= BluefinTunaCruise.accelerationDuration {
                        cruise.turnPhase = nil
                        cruise.turnElapsed = nil
                        if cruise.heightTarget == nil, cruise.countsAsLevelCrossing {
                            cruise.levelCrossingsRemaining = max(0, cruise.levelCrossingsRemaining - 1)
                        }
                    }
                }
            }
            // 再加速中も反対側の端を先読みし、座標の切り詰めに頼らず滑らかに減速する。
            let forwardRoom = max(0, horizontal >= 0 ? x.upperBound - position.x : position.x - x.lowerBound)
            let safeSpeed = forwardRoom / BluefinTunaCruise.edgeSlowingTime
            horizontal = (horizontal >= 0 ? 1 : -1) * min(abs(horizontal), safeSpeed)
            cruise.horizontalVelocity = horizontal

            if cruise.heightTarget == nil {
                cruise.levelTimeRemaining -= dt
                if cruise.levelTimeRemaining <= 0, cruise.levelCrossingsRemaining == 0 {
                    let y = roamingBounds.vertical
                    let maximumDistance = (y.upperBound - y.lowerBound) * height * 0.45
                    let distance = min(random(in: BluefinTunaCruise.heightDistance), maximumDistance) / height
                    var sign = cruise.nextHeightDirection
                    if position.y + distance > y.upperBound { sign = -1 }
                    else if position.y - distance < y.lowerBound { sign = 1 }
                    let target = min(max(position.y + distance * sign, y.lowerBound), y.upperBound)
                    if abs(target - position.y) * height >= max(1, min(BluefinTunaCruise.heightDistance.lowerBound, maximumDistance)) - 0.001 {
                        cruise.heightStart = position.y
                        cruise.heightTarget = target
                        cruise.heightElapsed = 0
                        cruise.nextHeightDirection = -sign
                        // 上下それぞれ20%の加減速区間を持つ補間。最大速度は平均の1.25倍。
                        // 60ptでも7.5秒以上なら従来の10pt/秒を超えない。横速度とは連動させない。
                        cruise.heightTime = max(random(in: BluefinTunaCruise.heightDuration),
                            Double(abs(target - position.y) * height
                                / ((1 - BluefinTunaCruise.heightRampFraction) * BluefinTunaCruise.maximumVerticalSpeed)))
                    } else { cruise.levelTimeRemaining = random(in: BluefinTunaCruise.levelDuration) }
                }
            }
            var nextY = position.y
            if let target = cruise.heightTarget {
                cruise.heightElapsed = min(cruise.heightElapsed + dt, cruise.heightTime)
                let u = min(max(CGFloat(cruise.heightElapsed / cruise.heightTime), 0), 1)
                let ramp = BluefinTunaCruise.heightRampFraction
                let progress: CGFloat
                if u < ramp { progress = u * u / (2 * ramp * (1 - ramp)) }
                else if u > 1 - ramp { progress = 1 - (1 - u) * (1 - u) / (2 * ramp * (1 - ramp)) }
                else { progress = (u - ramp / 2) / (1 - ramp) }
                let wanted = cruise.heightStart + (target - cruise.heightStart) * progress
                let limit = BluefinTunaCruise.maximumVerticalSpeed / height * CGFloat(dt)
                nextY += min(max(wanted - position.y, -limit), limit)
                if cruise.heightElapsed >= cruise.heightTime, abs(nextY - target) < 0.0000001 {
                    nextY = target
                    cruise.heightTarget = nil
                    cruise.levelTimeRemaining = random(in: BluefinTunaCruise.levelDuration)
                    cruise.levelCrossingsRemaining = 1 + (chance(0.5) ? 0 : 1)
                }
            }
            // Yはここでだけ進める。端の回避や旋回から上下成分を足さない。
            velocity = CGVector(dx: horizontal / (depthSpeed * FishMovementProfile.bluefinTunaHorizontalSpeedMultiplier),
                                dy: (nextY - position.y) / CGFloat(dt) / depthSpeed)
            position.x = min(max(position.x + horizontal * CGFloat(dt), x.lowerBound), x.upperBound)
            position.y = nextY
            bluefinCruise = cruise
            chooseBluefinTunaForwardTarget()
        }

        mutating func updateStationKeepingGeometry(size: CGSize, fishSize: CGFloat) {
            stationKeeping?.updateGeometry(bounds: roamingBounds, size: size, fishSize: fishSize)
            if stationKeeping != nil { applyStationKeeping() }
            bluefinCruise?.aquariumSize = size
        }

        fileprivate mutating func applyStationKeeping() {
            guard let stationKeeping else { return }
            position = stationKeeping.position
            velocity = stationKeeping.velocity
            currentSpeed = hypot(velocity.dx, velocity.dy)
            targetSpeed = currentSpeed
            behavior = stationKeeping.phase == .hovering ? .hovering : .wandering
            behaviorTimeRemaining = stationKeeping.timeRemaining
            directionChangeTimeRemaining = stationKeeping.timeRemaining
            anchorPosition = stationKeeping.start
            localTarget = stationKeeping.target
            roamingDestination = nil
            facingDirection = stationKeeping.facingRight ? .right : .left
            pendingFacingDirection = facingDirection
            facingSign = stationKeeping.facingRight ? -1 : 1
            facingWidth = 1
            visualTurnTargetSign = nil
            pendingFacingDirectionDuration = 0
            randomState = stationKeeping.randomState
        }

        mutating func updateRoamingBounds(_ bounds: FishRoamingBounds) {
            roamingBounds = bounds
            if let target = bluefinCruise?.heightTarget {
                bluefinCruise?.heightTarget = min(max(target, bounds.vertical.lowerBound), bounds.vertical.upperBound)
            }
            stationKeeping?.updateGeometry(bounds: bounds)
            let bounded = AquariumFishMotion.clampedPoint(position, bounds: bounds)
            if bluefinCruise != nil {
                position.x = bounded.x
                if position.y != bounded.y, bluefinCruise?.heightTarget != bounded.y {
                    // 画面寸法変更で必要になった高さ補正も、通常の縦速度上限で移動する。
                    bluefinCruise?.heightStart = position.y
                    bluefinCruise?.heightTarget = bounded.y
                    bluefinCruise?.heightElapsed = 0
                    let height = max(bluefinCruise?.aquariumSize.height ?? 1, 1)
                    bluefinCruise?.heightTime = max(3,
                        Double(abs(bounded.y - position.y) * height * 1.5 / BluefinTunaCruise.maximumVerticalSpeed))
                }
            } else { position = bounded }
            anchorPosition = AquariumFishMotion.clampedPoint(anchorPosition, bounds: bounds)
            localTarget = AquariumFishMotion.clampedPoint(localTarget, bounds: bounds)
            if let destination = roamingDestination {
                roamingDestination = AquariumFishMotion.clampedPoint(destination, bounds: bounds)
            }
        }

        private mutating func perturbedDirection(maxAngle: CGFloat) -> CGVector {
            AquariumFishMotion.rotated(desiredDirection, by: random(in: -maxAngle...maxAngle))
        }

        private mutating func chance(_ probability: CGFloat) -> Bool {
            randomUnit() < probability
        }

        private mutating func random(in range: ClosedRange<CGFloat>) -> CGFloat {
            range.lowerBound + randomUnit() * (range.upperBound - range.lowerBound)
        }

        private mutating func random(in range: ClosedRange<TimeInterval>) -> TimeInterval {
            range.lowerBound + Double(randomUnit()) * (range.upperBound - range.lowerBound)
        }

        private mutating func randomUnit() -> CGFloat {
            // 魚個体が保持する軽量PRNG。毎フレーム生成せず、状態遷移時だけ進める。
            randomState = randomState &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return CGFloat((randomState >> 40) & 0xFF_FFFF) / CGFloat(0xFF_FFFF)
        }
    }

    static func initialState(
        for id: UUID,
        profile: FishMovementProfile = .clownfish,
        speedVariationProfile: SpeedVariationProfile? = nil,
        roamingBounds: FishRoamingBounds = .legacy,
        initialPosition spawnPosition: CGPoint? = nil,
        viewingSessionID: UUID? = nil,
        aquariumSize: CGSize = CGSize(width: 393, height: 852),
        fishSize: CGFloat = 40
    ) -> State {
        let bytes = mixedIndividualBytes(for: id)
        let angle = CGFloat(bytes[4]) / 255 * .pi * 2
        let baseSpeed = interpolated(profile.baseSpeedRange, byte: bytes[5])
        // 追加時の座標を優先。通常表示は個体IDと表示セッションから位置を決める。
        let initialPosition = spawnPosition.map { clampedPoint($0, bounds: roamingBounds) }
            ?? initialPosition(for: id, bounds: roamingBounds, viewingSessionID: viewingSessionID)
        let direction = normalized(CGVector(
            // 水平姿勢に限定しても、混合済みIDから左右の個体差を維持する。
            dx: profile.roamingStyle == .bluefinTuna ? (bytes[4].isMultiple(of: 2) ? 1 : -1) : cos(angle),
            dy: profile.roamingStyle == .bluefinTuna ? 0 : sin(angle) * profile.verticalDirectionBias
        ))
        let facingSign: CGFloat = direction.dx >= 0 ? -1 : 1
        let facingDirection = FishFacingDirection.quantized(velocity: direction)
        let initialBehavior: Behavior = profile.hoverProbability > 0 && bytes[11].isMultiple(of: 3)
            ? .hovering
            : .wandering
        let wanderingRadiusX = interpolated(profile.wanderingRadiusX, byte: bytes[12])
        let wanderingRadiusY = interpolated(profile.wanderingRadiusY, byte: bytes[13])
        let initialDepth = interpolated(profile.depthRange, byte: bytes[14])
        let initialTargetDepth = min(
            max(
                initialDepth + (CGFloat(bytes[15]) / 255 - 0.5) * 0.24,
                profile.depthRange.lowerBound
            ),
            profile.depthRange.upperBound
        )
        let initialBurstCooldown = profile.burstCooldownRange.lowerBound
            + Double(bytes[10]) / 255
                * (profile.burstCooldownRange.upperBound - profile.burstCooldownRange.lowerBound)
        let initialSpeedVariationMultiplier = speedVariationProfile.map {
            interpolated($0.multiplierRange(for: initialBehavior), byte: bytes[0])
        } ?? 1
        let initialSpeedVariationTimeRemaining = speedVariationProfile.map {
            $0.changeIntervalRange.lowerBound
                + Double(bytes[1]) / 255
                    * ($0.changeIntervalRange.upperBound - $0.changeIntervalRange.lowerBound)
        } ?? 0

        var state = State(
            position: initialPosition,
            velocity: CGVector(dx: direction.dx * baseSpeed, dy: direction.dy * baseSpeed),
            desiredDirection: direction,
            behavior: initialBehavior,
            behaviorTimeRemaining: 1.5 + Double(bytes[9]) / 255 * 3.0,
            anchorPosition: initialPosition,
            localTarget: clampedPoint(CGPoint(
                x: initialPosition.x + direction.dx * wanderingRadiusX,
                y: initialPosition.y + direction.dy * wanderingRadiusY
            ), bounds: roamingBounds),
            roamingDestination: nil,
            roamingBounds: roamingBounds,
            currentDepth: initialDepth,
            targetDepth: initialTargetDepth,
            depthVelocity: 0,
            depthChangeTimeRemaining: 1.5 + Double(bytes[10]) / 255 * 3.5,
            movementProfile: profile,
            baseSpeed: baseSpeed,
            currentSpeed: initialBehavior == .hovering ? baseSpeed * 0.25 : baseSpeed,
            targetSpeed: initialBehavior == .hovering ? baseSpeed * 0.25 : baseSpeed,
            accelerationResponse: interpolated(profile.accelerationResponseRange, byte: bytes[6]),
            brakingResponse: interpolated(profile.brakingResponseRange, byte: bytes[7]),
            turnResponsiveness: interpolated(profile.turnResponsivenessRange, byte: bytes[8]),
            hoverRadius: 0.025 + CGFloat(bytes[12]) / 255 * 0.03,
            burstProbability: profile.burstProbability * (0.78 + CGFloat(bytes[13]) / 255 * 0.44),
            hoverProbability: profile.hoverProbability * (0.82 + CGFloat(bytes[10]) / 255 * 0.36),
            gatheringProbability: profile.gatheringProbability,
            wanderingRadiusX: wanderingRadiusX,
            wanderingRadiusY: wanderingRadiusY,
            directionChangeTimeRemaining: profile.directionHoldDurationRange.lowerBound
                + Double(bytes[10]) / 255
                    * (profile.directionHoldDurationRange.upperBound
                        - profile.directionHoldDurationRange.lowerBound),
            burstCooldownRemaining: initialBurstCooldown,
            noisePhaseX: CGFloat(bytes[14]) / 255 * .pi * 2,
            noisePhaseY: CGFloat(bytes[15]) / 255 * .pi * 2,
            swimPhase: CGFloat(bytes[3]) / 255 * .pi * 2,
            accelerationMagnitude: 0,
            speedVariationProfile: speedVariationProfile,
            targetSpeedVariationMultiplier: initialSpeedVariationMultiplier,
            speedVariationTimeRemaining: initialSpeedVariationTimeRemaining,
            facingSign: facingSign,
            facingWidth: 1,
            visualTurnTargetSign: nil,
            visualTurnProgress: 0,
            visualTurnDuration: 0.35,
            facingDirection: facingDirection,
            pendingFacingDirection: facingDirection,
            pendingFacingDirectionDuration: 0,
            presentationMotionIntensity: 1,
            presentationDirectionScale: facingDirection.directionScale,
            randomState: seed(from: bytes)
        )
        if profile.roamingStyle == .bluefinTuna {
            state.bluefinCruise = .init(aquariumSize: aquariumSize,
                levelTimeRemaining: BluefinTunaCruise.levelDuration.lowerBound + Double(bytes[12]) / 255
                    * (BluefinTunaCruise.levelDuration.upperBound - BluefinTunaCruise.levelDuration.lowerBound),
                levelCrossingsRemaining: 1 + Int(bytes[13] % 2),
                nextHeightDirection: bytes[15].isMultiple(of: 2) ? 1 : -1,
                direction: direction.dx >= 0 ? 1 : -1)
        }
        if profile.usesStationKeeping {
            state.stationKeeping = .init(seed: state.randomState, position: initialPosition,
                facingRight: direction.dx >= 0, bounds: roamingBounds, aquariumSize: aquariumSize,
                fishSize: fishSize, startNearBottom: spawnPosition == nil)
            state.applyStationKeeping()
        }
        return state
    }

    static func movementProfile(for species: FishSpecies) -> FishMovementProfile {
        switch species {
        case .clownfish, .blueTang, .yellowTang, .blueGreenChromis, .orientalButterflyfish, .pennantCoralfish:
            .clownfish
        case .mandarinfish:
            .mandarinfish
        case .lionfish, .porcupinefish:
            .lionfish
        case .jellyfish:
            .jellyfish
        case .dolphin:
            .dolphin
        case .seaTurtle:
            .seaTurtle
        case .manta:
            .bluefinTuna
        case .whaleShark:
            .whaleShark
        case .seahorse:
            .seahorse
        case .pufferfish:
            .clownfish
        }
    }

    static func speedVariationProfile(for species: FishSpecies) -> SpeedVariationProfile? {
        species == .seahorse ? .seahorse : nil
    }

    static func wingSwimmingProfile(for species: FishSpecies) -> WingSwimmingProfile? {
        // マンタのテンプレート自体はウミガメ等が参照するため残す。
        nil
    }

    /// Frame tempoと実移動の印象を揃えるクマノミ型の目標速度倍率。
    /// nilの魚種は従来のtargetSpeedをそのまま使う。
    static func behaviorTargetSpeedMultiplier(
        for species: FishSpecies,
        behavior: Behavior
    ) -> CGFloat? {
        guard species == .clownfish || species == .blueTang || species == .yellowTang || species == .blueGreenChromis || species == .orientalButterflyfish || species == .pennantCoralfish || species == .lionfish || species == .porcupinefish else { return nil }
        return switch behavior {
        case .hovering:
            0.62
        case .wandering:
            0.95
        case .cruising:
            1.22
        case .burst:
            1.90
        case .turning:
            0.85
        case .braking:
            nil
        }
    }

    /// 体の揺れ・傾きだけを調整し、移動速度やひれのテンポから独立させる。
    static func presentationAmplitude(for species: FishSpecies) -> CGFloat {
        if species == .seaTurtle || species == .dolphin { return 0.20 }
        if species == .mandarinfish || species == .manta || species == .whaleShark { return 0 }
        return (species == .lionfish || species == .porcupinefish) ? 0.45 : 1
    }

    /// マンタは通常2.20（羽ばたき）/2.00（滑走）を掛ける。その中間を比較基準にする。
    /// 1→7の振り下ろしで緩やかに増速し、戻りで減速。再生速度と基準移動速度は独立。
    static func seaTurtlePropulsionMultiplier(elapsedTime: TimeInterval,
        frameDuration: TimeInterval, phase: TimeInterval) -> CGFloat {
        let reference = (WingSwimmingProfile.manta.flapSpeedMultiplier
                         + WingSwimmingProfile.manta.glideSpeedMultiplier) / 2
        let cycle = max(frameDuration, 0.01) * 12
        let progress = (elapsedTime + phase).truncatingRemainder(dividingBy: cycle) / cycle
        return reference * (1 - 0.04 * CGFloat(cos(2 * .pi * progress)))
    }

    static func spriteFrameDuration(
        for species: FishSpecies,
        behavior: Behavior,
        currentSpeed: CGFloat,
        baseSpeed: CGFloat
    ) -> TimeInterval {
        switch species {
        case .yellowTang, .blueGreenChromis, .orientalButterflyfish, .pennantCoralfish, .lionfish, .mandarinfish:
            return 0.20
        case .dolphin:
            return AquariumDolphinSwimming.propulsionFrameDuration
        case .seaTurtle:
            return 0.22
        case .porcupinefish:
            return AquariumPorcupinefishInflation.swimmingFrameDuration
        case .jellyfish:
            return 0.30
        case .manta:
            return 0.11
        case .whaleShark:
            return whaleSharkSpriteFrameDuration
        case .pufferfish:
            // 小さな胸びれを素早く見せつつ、30fpsでのちらつきを避ける。
            let sharedDuration = spriteFrameDuration(
                for: behavior,
                currentSpeed: currentSpeed,
                baseSpeed: baseSpeed
            )
            return max(sharedDuration * 0.45, 0.06)
        case .seahorse:
            return 0.28
        case .clownfish, .blueTang:
            break
        }
        return spriteFrameDuration(
            for: behavior,
            currentSpeed: currentSpeed,
            baseSpeed: baseSpeed
        )
    }

    static func spriteFrameDuration(
        for behavior: Behavior,
        currentSpeed: CGFloat,
        baseSpeed: CGFloat
    ) -> TimeInterval {
        switch behavior {
        case .hovering:
            return 0.30
        case .wandering:
            return 0.215
        case .cruising:
            return 0.155
        case .burst:
            return 0.09
        case .braking:
            // 減速に合わせ、約0.16秒から0.27秒へ徐々に遅くする。
            return 0.27 - TimeInterval(
                min(max(currentSpeed / max(baseSpeed, 0.001), 0), 1.5) / 1.5
            ) * 0.11
        case .turning:
            return 0.26
        }
    }

    static func spriteAnimationPhase(for id: UUID) -> TimeInterval {
        let bytes = mixedIndividualBytes(for: id)
        return Double(bytes[6]) / 255 * 1.7
    }

    /// 既存の泳動phaseを5枚ping-pongの1周期へ対応させる。
    static func seahorseSpriteAnimationTime(
        swimPhase: CGFloat,
        frameCount: Int,
        frameDuration: TimeInterval
    ) -> TimeInterval {
        let fullTurn = CGFloat.pi * 2
        let normalizedPhase = swimPhase.truncatingRemainder(dividingBy: fullTurn)
        let positivePhase = normalizedPhase >= 0 ? normalizedPhase : normalizedPhase + fullTurn
        let cycleStepCount = max((frameCount - 1) * 2, 1)
        return Double(positivePhase / fullTurn)
            * Double(cycleStepCount)
            * max(frameDuration, 0.01)
    }

    static func seahorseVisualOffsetY(
        swimPhase: CGFloat,
        amplitude: CGFloat = 1.2
    ) -> CGFloat {
        -sin(swimPhase) * amplitude
    }

    static func spriteTempoMultiplier(for id: UUID) -> TimeInterval {
        let bytes = mixedIndividualBytes(for: id)
        return 0.90 + Double(bytes[7]) / 255 * 0.20
    }

    static func initialPosition(
        for id: UUID,
        bounds: FishRoamingBounds = .legacy,
        viewingSessionID: UUID? = nil
    ) -> CGPoint {
        let bytes = mixedIndividualBytes(for: id, viewingSessionID: viewingSessionID)
        let xFraction = CGFloat(Int(bytes[0]) * 256 + Int(bytes[1])) / 65_535
        let yFraction = CGFloat(Int(bytes[2]) * 256 + Int(bytes[3])) / 65_535
        return point(xFraction: xFraction, yFraction: yFraction, bounds: bounds)
    }

    static func point(xFraction: CGFloat, yFraction: CGFloat, bounds: FishRoamingBounds = .legacy) -> CGPoint {
        let x = bounds.horizontal.lowerBound
            + min(max(xFraction, 0), 1) * (bounds.horizontal.upperBound - bounds.horizontal.lowerBound)
        let y = bounds.vertical.lowerBound
            + min(max(yFraction, 0), 1) * (bounds.vertical.upperBound - bounds.vertical.lowerBound)
        return CGPoint(
            x: min(max(x, bounds.horizontal.lowerBound), bounds.horizontal.upperBound),
            y: min(max(y, bounds.vertical.lowerBound), bounds.vertical.upperBound)
        )
    }

    static func smoothNoise(time: TimeInterval, phaseX: CGFloat, phaseY: CGFloat) -> CGVector {
        let time = CGFloat(time)
        // 周期と位相の異なる成分を重ね、単一sin波の規則的な往復を避ける。
        let x = sin(time * 0.37 + phaseX) * 0.55
            + sin(time * 0.19 + phaseY * 1.7) * 0.30
            + sin(time * 0.071 + phaseX * 0.43) * 0.15
        let y = sin(time * 0.31 + phaseY) * 0.50
            + sin(time * 0.137 + phaseX * 1.3) * 0.32
            + sin(time * 0.053 + phaseY * 0.61) * 0.18
        return CGVector(dx: x, dy: y)
    }

    static func wallSteering(
        at position: CGPoint, strength: CGFloat = 1, bounds: FishRoamingBounds = .legacy
    ) -> CGVector {
        let horizontalMargin = bounds.horizontalWallMargin
        let verticalMargin = bounds.verticalWallMargin
        var force = CGVector.zero
        force.dx += edgeForce(position.x - bounds.horizontal.lowerBound, margin: horizontalMargin)
        force.dx -= edgeForce(bounds.horizontal.upperBound - position.x, margin: horizontalMargin)
        force.dy += edgeForce(position.y - bounds.vertical.lowerBound, margin: verticalMargin)
        force.dy -= edgeForce(bounds.vertical.upperBound - position.y, margin: verticalMargin)
        return CGVector(dx: force.dx * 1.8 * strength, dy: force.dy * 1.45 * strength)
    }


    static func wallStrength(behavior: Behavior, speedRatio: CGFloat) -> CGFloat {
        let behaviorScale: CGFloat
        switch behavior {
        case .hovering: behaviorScale = 0.8
        case .cruising: behaviorScale = 1
        case .wandering: behaviorScale = 0.92
        case .burst: behaviorScale = 1.35
        case .braking: behaviorScale = 1.1
        case .turning: behaviorScale = 1.2
        }
        return behaviorScale * min(max(0.8 + speedRatio * 0.22, 0.8), 1.5)
    }

    static func normalized(_ vector: CGVector) -> CGVector {
        let length = hypot(vector.dx, vector.dy)
        guard length > 0.0001 else { return CGVector(dx: 1, dy: 0) }
        return CGVector(dx: vector.dx / length, dy: vector.dy / length)
    }

    static func rotated(_ vector: CGVector, by angle: CGFloat) -> CGVector {
        normalized(CGVector(
            dx: vector.dx * cos(angle) - vector.dy * sin(angle),
            dy: vector.dx * sin(angle) + vector.dy * cos(angle)
        ))
    }

    static func direction(from start: CGPoint, to end: CGPoint) -> CGVector {
        normalized(CGVector(dx: end.x - start.x, dy: end.y - start.y))
    }

    static func clampedPoint(_ point: CGPoint, bounds: FishRoamingBounds = .legacy) -> CGPoint {
        CGPoint(
            x: min(max(point.x, bounds.horizontal.lowerBound), bounds.horizontal.upperBound),
            y: min(max(point.y, bounds.vertical.lowerBound), bounds.vertical.upperBound)
        )
    }

    private static func edgeForce(_ distance: CGFloat, margin: CGFloat) -> CGFloat {
        guard distance < margin else { return 0 }
        let proximity = min(max((margin - distance) / margin, 0), 1)
        return proximity * proximity
    }

    /// UUID全16バイトを既存のFNV-1aでseed化し、SplitMix64で初期値用に拡散する。
    /// 末尾だけ異なる固定IDも全パラメータへ反映し、実行ごとに変わるhashValueは使わない。
    private static func mixedIndividualBytes(for id: UUID, viewingSessionID: UUID? = nil) -> [UInt8] {
        var input = withUnsafeBytes(of: id.uuid) { Array($0) }
        if let viewingSessionID {
            input.append(contentsOf: withUnsafeBytes(of: viewingSessionID.uuid) { Array($0) })
        }
        var state = seed(from: input)
        var bytes: [UInt8] = []
        for _ in 0..<2 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var value = state
            value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
            value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
            value ^= value >> 31
            // バイト順も固定し、CPUのエンディアンに依存しない。
            for shift in stride(from: 0, to: 64, by: 8) {
                bytes.append(UInt8(truncatingIfNeeded: value >> shift))
            }
        }
        return bytes
    }

    static func individualSeed(for id: UUID) -> UInt64 {
        seed(from: mixedIndividualBytes(for: id))
    }

    private static func seed(from bytes: [UInt8]) -> UInt64 {
        bytes.reduce(14_695_981_039_346_656_037) { ($0 ^ UInt64($1)) &* 1_099_511_628_211 }
    }

    private static func interpolated(_ range: ClosedRange<CGFloat>, byte: UInt8) -> CGFloat {
        range.lowerBound + CGFloat(byte) / 255 * (range.upperBound - range.lowerBound)
    }
}
