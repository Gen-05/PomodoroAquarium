import CoreGraphics
import Foundation

/// ニシキテグリの底寄り探索。時刻・抽選状態もMotion.State内に保存し、Viewは選択しない。
enum AquariumMandarinfishMotion {
    static let hoverDuration: ClosedRange<TimeInterval> = 1...3
    static let travelDuration: ClosedRange<TimeInterval> = 0.75...1.875
    static let travelBodyLengths: ClosedRange<CGFloat> = 0.3...0.8
    static let correctionBodyLengths: ClosedRange<CGFloat> = 0.008...0.022
    static let lowerBand: ClosedRange<CGFloat> = 0.62...0.86
    static let visibleLengthRatio: CGFloat = 1147.0 / 1254
    static let maximumHeadDip: Double = 5

    static func hasValidGeometry(_ size: CGSize) -> Bool {
        size.width.isFinite && size.height.isFinite && size.width > 0 && size.height > 0
    }

    struct State {
        enum Phase { case hovering, moving }
        private(set) var phase: Phase = .hovering
        private(set) var elapsed: TimeInterval = 0
        private(set) var duration: TimeInterval = 1
        private(set) var start: CGPoint
        private(set) var target: CGPoint
        private(set) var position: CGPoint
        private(set) var velocity: CGVector = .zero
        private(set) var facingRight: Bool
        private(set) var randomState: UInt64
        private(set) var completedMoves = 0
        private(set) var aquariumSize: CGSize
        private(set) var fishSize: CGFloat
        private(set) var isGeometryReady: Bool
        private var bounds: FishRoamingBounds
        private var dip: Double = 0

        init(seed: UInt64, position: CGPoint, facingRight: Bool, bounds: FishRoamingBounds,
             aquariumSize: CGSize, fishSize: CGFloat, startNearBottom: Bool) {
            self.randomState = seed
            self.bounds = bounds
            self.aquariumSize = aquariumSize
            self.fishSize = fishSize
            self.facingRight = facingRight
            self.isGeometryReady = hasValidGeometry(aquariumSize)
            let position = startNearBottom ? Self.lowerInitialPosition(position, bounds: bounds) : position
            self.position = position
            self.start = position
            self.target = position
            // SwiftUIの最初のlayoutが0サイズなら、移動先の抽選も時計もまだ開始しない。
            if isGeometryReady { beginHover() }
        }

        var timeRemaining: TimeInterval { max(duration - elapsed, 0) }
        var headDipDegrees: Double {
            let t = min(max(elapsed / duration, 0), 1)
            return dip * pow(sin(.pi * t), 2)
        }

        static func lowerInitialPosition(_ position: CGPoint, bounds: FishRoamingBounds) -> CGPoint {
            let band = verticalBand(bounds)
            let unit = min(max((position.y - bounds.vertical.lowerBound)
                / max(bounds.vertical.upperBound - bounds.vertical.lowerBound, 0.001), 0), 1)
            return CGPoint(x: position.x, y: band.lowerBound + unit * (band.upperBound - band.lowerBound))
        }

        private static func verticalBand(_ bounds: FishRoamingBounds) -> ClosedRange<CGFloat> {
            let span = bounds.vertical.upperBound - bounds.vertical.lowerBound
            return (bounds.vertical.lowerBound + span * lowerBand.lowerBound)...(bounds.vertical.lowerBound + span * lowerBand.upperBound)
        }

        mutating func advance(deltaTime: TimeInterval) {
            guard isGeometryReady, deltaTime.isFinite, deltaTime > 0 else { return }
            var remaining = deltaTime
            while remaining > 0.000000001 {
                let step = min(remaining, max(duration - elapsed, 0))
                elapsed += step
                remaining -= step
                let t = CGFloat(min(elapsed / duration, 1))
                // 両端の速度・加速度が0。滞留への接続でも座標・速度を飛ばさない。
                let progress = t * t * t * (10 - 15 * t + 6 * t * t)
                let derivative = 30 * t * t * (1 - t) * (1 - t) / CGFloat(duration)
                position = CGPoint(x: start.x + (target.x - start.x) * progress,
                                   y: start.y + (target.y - start.y) * progress)
                velocity = CGVector(dx: (target.x - start.x) * derivative,
                                    dy: (target.y - start.y) * derivative)
                if elapsed >= duration - 0.000000001 {
                    position = target
                    velocity = .zero
                    if phase == .hovering { beginMove() }
                    else { completedMoves += 1; beginHover() }
                }
            }
        }

        /// 初回の実寸確定で開始し、その後のサイズ変更では行動・残り時間・経路を継続する。
        mutating func updateGeometry(bounds: FishRoamingBounds, size: CGSize? = nil, fishSize: CGFloat? = nil) {
            // 復帰・一時的な未layoutで、有効な経路を0サイズへ戻さない。
            if let size, !hasValidGeometry(size) { return }
            self.bounds = bounds
            if let size { aquariumSize = size }
            if let fishSize { self.fishSize = fishSize }
            if !isGeometryReady {
                guard hasValidGeometry(aquariumSize) else { return }
                isGeometryReady = true
                position = AquariumFishMotion.clampedPoint(position, bounds: bounds)
                start = position
                target = position
                beginHover() // 初回確定時だけ、実寸を使った最初の滞留目標を作る。
                return
            }
            let correctedPosition = AquariumFishMotion.clampedPoint(position, bounds: bounds)
            let correctedTarget = AquariumFishMotion.clampedPoint(target, bounds: bounds)
            if correctedPosition != position || correctedTarget != target {
                let t = CGFloat(min(elapsed / duration, 1))
                let progress = t * t * t * (10 - 15 * t + 6 * t * t)
                let remainder = max(1 - progress, 0.000000001)
                // 目標だけが安全補正された場合も、次tickの補間が現在位置へ連続するよう逆算。
                start = CGPoint(x: (correctedPosition.x - correctedTarget.x * progress) / remainder,
                                y: (correctedPosition.y - correctedTarget.y * progress) / remainder)
                target = correctedTarget
                position = correctedPosition
            }
        }

        private var bodyLength: CGFloat { fishSize * visibleLengthRatio }
        private var width: CGFloat { max(aquariumSize.width, 1) }
        private var height: CGFloat { max(aquariumSize.height, 1) }

        private mutating func beginHover() {
            phase = .hovering
            elapsed = 0
            duration = random(hoverDuration)
            start = position
            let angle = randomUnit() * .pi * 2
            let distance = random(correctionBodyLengths) * bodyLength
            target = localPoint(dx: cos(angle) * distance, dy: sin(angle) * distance * 0.4)
            // 必要時の小さな採餌姿勢だけ。規則的な上下の描画揺れは使わない。
            dip = randomUnit() < 0.25 ? Double(randomUnit()) * 3 : 0
        }

        private mutating func beginMove() {
            phase = .moving
            elapsed = 0
            duration = random(travelDuration)
            start = position
            let band = Self.verticalBand(bounds)
            let distance = random(travelBodyLengths) * bodyLength
            for _ in 0..<12 {
                var angle = randomUnit() * .pi * 2
                // 中央出現からは短距離移動を重ねて下側へ。初回に下へワープさせない。
                if position.y < band.lowerBound { angle = randomUnit() * .pi * 0.8 + .pi * 0.1 }
                else if position.y > band.upperBound { angle = -(randomUnit() * .pi * 0.8 + .pi * 0.1) }
                var dx = cos(angle), dy = sin(angle) * 0.55
                let length = max(hypot(dx, dy), 0.001)
                dx = dx / length * distance; dy = dy / length * distance
                let proposed = localPoint(dx: dx, dy: dy)
                let actual = hypot((proposed.x - position.x) * width, (proposed.y - position.y) * height)
                if actual >= travelBodyLengths.lowerBound * bodyLength {
                    target = proposed
                    break
                }
            }
            if target == start {
                let roomRight = (bounds.horizontal.upperBound - start.x) * width
                target = CGPoint(x: start.x + (roomRight >= distance ? distance : -distance) / width, y: start.y)
            }
            // 微小な補正や縦成分から向きを選ばない。向き変更は停止後の移動開始時だけ。
            if abs((target.x - start.x) * width) > bodyLength * 0.12 {
                facingRight = target.x > start.x
            }
            dip = target.y > start.y ? Double(randomUnit()) * maximumHeadDip : 0
        }

        private func localPoint(dx: CGFloat, dy: CGFloat) -> CGPoint {
            let band = Self.verticalBand(bounds)
            let yRange = band.contains(position.y) ? band : bounds.vertical
            func reflected(_ value: CGFloat, in range: ClosedRange<CGFloat>) -> CGFloat {
                if value < range.lowerBound { return min(range.lowerBound + range.lowerBound - value, range.upperBound) }
                if value > range.upperBound { return max(range.upperBound - (value - range.upperBound), range.lowerBound) }
                return value
            }
            return CGPoint(x: reflected(position.x + dx / width, in: bounds.horizontal),
                           y: reflected(position.y + dy / height, in: yRange))
        }

        private mutating func randomUnit() -> CGFloat {
            randomState = randomState &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return CGFloat(randomState >> 40) / CGFloat(0xFFFFFF)
        }
        private mutating func random(_ range: ClosedRange<CGFloat>) -> CGFloat {
            range.lowerBound + randomUnit() * (range.upperBound - range.lowerBound)
        }
        private mutating func random(_ range: ClosedRange<TimeInterval>) -> TimeInterval {
            range.lowerBound + Double(randomUnit()) * (range.upperBound - range.lowerBound)
        }
    }
}
