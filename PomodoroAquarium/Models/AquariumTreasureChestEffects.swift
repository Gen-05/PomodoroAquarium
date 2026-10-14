import CoreGraphics
import Foundation

/// B案の通常時だけを再生する。時間から有限のサンプルを計算し、粒子Timerや保存データを持たない。
nonisolated enum AquariumTreasureChestEffects {
    static let bubbleAsset = "treasure_chest_bubble"
    // 本体・接地・当たり判定とエフェクトのUV座標を同じ表示寸法へ合わせる。
    static let canvasSide = 180.0 * 0.7 * 1254 / 1115
    static let overflowTop = 140.0
    static let bubbleVisibleFraction = 0.7296650717703349
    static let bubbleLimitPerChest = 16
    static let sparkleLimitPerChest = 3
    static let sceneBubbleLimit = 80
    static let sceneSparkleLimit = 16

    struct Instance: Equatable {
        let id: String
        let direction: AquariumDecorationFacingDirection
    }
    struct BubbleSpec: Equatable {
        let birth, diameter, lifetime, rise, sway, phase, frequency, opacity: Double
        let originIndex: Int
    }
    struct SparkleSpec: Equatable {
        let birth, lifetime, size: Double
        let spot: Int
    }
    struct Pattern: Equatable {
        let bubbles: [BubbleSpec]
        let sparkles: [SparkleSpec]
        let phaseOffset: Double

        init(placementID: String) {
            let seed = placementID.utf8.reduce(UInt64(14_695_981_039_346_656_037)) {
                ($0 ^ UInt64($1)) &* 1_099_511_628_211
            }
            var random = Random(seed: seed)
            phaseOffset = random.next() * 40
            let gaps = (0..<15).map { _ in 0.43 + random.next() * 0.43 }
            let sum = gaps.reduce(0, +)
            var birth = 0.12
            var result: [BubbleSpec] = []
            for index in gaps.indices {
                result.append(BubbleSpec(birth: birth, diameter: 5.5 + random.next() * 6,
                    lifetime: 2.5 + random.next() * 0.6, rise: 135 + random.next() * 40,
                    sway: 1.1 + random.next() * 2.1, phase: random.next() * .pi * 2,
                    frequency: 1.3 + random.next() * 1.2, opacity: 0.82 + random.next() * 0.18,
                    originIndex: index % 3))
                birth += gaps[index] / sum * 10
            }
            bubbles = result
            // 40秒の中で24回。場所を8箇所ずつshuffleし、10秒ごとの同じ点滅を避ける。
            var order: [Int] = []
            for _ in 0..<3 {
                var group = Array(0..<8)
                for i in stride(from: 7, through: 1, by: -1) {
                    group.swapAt(i, Int(random.next() * Double(i + 1)))
                }
                if group.first == order.last { group.swapAt(0, 1) }
                order.append(contentsOf: group)
            }
            sparkles = (0..<24).map { index in
                SparkleSpec(birth: 0.55 + Double(index) * (40 / 24.0) + random.next() * 0.3,
                    lifetime: 0.42 + random.next() * 0.26, size: 5.5 + random.next() * 2.1,
                    spot: order[index])
            }
        }
    }
    struct Bubble: Equatable {
        let point: CGPoint // PNG左上=(0,0)、右下=(1,1)。上昇でyは負にもなる。
        let diameter: CGFloat
        let opacity: Double
    }
    struct Sparkle: Equatable {
        let point: CGPoint
        let size: CGFloat
        let opacity: Double
    }
    struct Frame: Equatable {
        var bubbles: [Bubble] = []
        var sparkles: [Sparkle] = []
        static let empty = Frame()
    }

    static func smooth(_ value: Double) -> Double {
        let v = min(1, max(0, value))
        return v * v * (3 - 2 * v)
    }
    static func bubbleOpacity(age: Double, lifetime: Double, individualOpacity: Double = 1) -> Double {
        guard age >= 0, age < lifetime else { return 0 }
        // 基本透明度1.0。PNG内部のalphaに旧0.62や素材別補正を重ねない。
        return min(1, max(0, smooth(age / 0.23) * smooth((lifetime - age) / 0.4) * individualOpacity))
    }
    private static func wrappedAge(_ elapsed: Double, birth: Double, period: Double) -> Double {
        let age = (elapsed - birth).truncatingRemainder(dividingBy: period)
        return age < 0 ? age + period : age
    }
    static func frame(pattern: Pattern, elapsed: Double, direction: AquariumDecorationFacingDirection,
                      bubbleLimit: Int = bubbleLimitPerChest, sparkleLimit: Int = sparkleLimitPerChest) -> Frame {
        var result = Frame()
        let time = elapsed + pattern.phaseOffset
        let origins = bubbleOrigins(direction), spots = sparklePoints(direction)
        for spec in pattern.bubbles where result.bubbles.count < max(0, min(bubbleLimit, bubbleLimitPerChest)) {
            let age = wrappedAge(time, birth: spec.birth, period: 10)
            guard age < spec.lifetime else { continue }
            let progress = age / spec.lifetime
            let dx = spec.sway * (sin(age * spec.frequency + spec.phase) - sin(spec.phase) + 0.23 * sin(age * spec.frequency * 1.6))
            let dy = spec.rise * (progress * 0.94 + 0.06 * progress * progress)
            let origin = origins[spec.originIndex]
            result.bubbles.append(Bubble(point: CGPoint(x: origin.x + dx / canvasSide, y: origin.y - dy / canvasSide),
                diameter: spec.diameter * (0.94 + 0.06 * smooth(age / 0.3)),
                opacity: bubbleOpacity(age: age, lifetime: spec.lifetime, individualOpacity: spec.opacity)))
        }
        for spec in pattern.sparkles where result.sparkles.count < max(0, min(sparkleLimit, sparkleLimitPerChest)) {
            let age = wrappedAge(time, birth: spec.birth, period: 40)
            guard age < spec.lifetime else { continue }
            let pulse = pow(sin(.pi * age / spec.lifetime), 2)
            result.sparkles.append(Sparkle(point: spots[spec.spot],
                size: spec.size * (0.62 + 0.38 * pulse), opacity: 0.62 * pulse))
        }
        return result
    }
    static func frames(instances: [Instance], patterns: [String: Pattern], elapsed: Double) -> [String: Frame] {
        var result: [String: Frame] = [:]
        var bubbleBudget = sceneBubbleLimit, sparkleBudget = sceneSparkleLimit
        for instance in instances {
            guard bubbleBudget > 0 || sparkleBudget > 0 else { break }
            guard let pattern = patterns[instance.id] else { continue }
            let sample = frame(pattern: pattern, elapsed: elapsed, direction: instance.direction,
                bubbleLimit: bubbleBudget, sparkleLimit: sparkleBudget)
            result[instance.id] = sample
            bubbleBudget -= sample.bubbles.count
            sparkleBudget -= sample.sparkles.count
        }
        return result
    }
    private struct Random {
        var state: UInt64
        init(seed: UInt64) { state = seed }
        mutating func next() -> Double {
            state &+= 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return Double((z ^ (z >> 31)) >> 11) / 9_007_199_254_740_992
        }
    }

    // Work/anchors.jsonの実測UV。左右は別PNGなので単純反転で代用しない。
    static func bubbleOrigins(_ direction: AquariumDecorationFacingDirection) -> [CGPoint] {
        direction == .right ? [CGPoint(x: 0.467305, y: 0.460128), CGPoint(x: 0.582137, y: 0.489633), CGPoint(x: 0.697767, y: 0.490431)]
            : [CGPoint(x: 0.520734, y: 0.460925), CGPoint(x: 0.407496, y: 0.490431), CGPoint(x: 0.293461, y: 0.490431)]
    }
    static func frontRim(_ direction: AquariumDecorationFacingDirection) -> [CGPoint] {
        direction == .right ? [CGPoint(x: 0, y: 0.448166), CGPoint(x: 0.07177, y: 0.478469), CGPoint(x: 0.641148, y: 0.678628), CGPoint(x: 0.933812, y: 0.515152), CGPoint(x: 1, y: 0.490431)]
            : [CGPoint(x: 0, y: 0.490431), CGPoint(x: 0.062201, y: 0.513557), CGPoint(x: 0.362041, y: 0.678628), CGPoint(x: 0.940989, y: 0.478469), CGPoint(x: 1, y: 0.448166)]
    }
    static func sparklePoints(_ direction: AquariumDecorationFacingDirection) -> [CGPoint] {
        direction == .right ? [CGPoint(x: 0.518011, y: 0.367673), CGPoint(x: 0.352573, y: 0.619971), CGPoint(x: 0.539567, y: 0.474628), CGPoint(x: 0.647673, y: 0.528911), CGPoint(x: 0.574672, y: 0.551913), CGPoint(x: 0.416268, y: 0.518341), CGPoint(x: 0.77512, y: 0.42504), CGPoint(x: 0.439994, y: 0.359506)]
            : [CGPoint(x: 0.501722, y: 0.36806), CGPoint(x: 0.66179, y: 0.621854), CGPoint(x: 0.481071, y: 0.474873), CGPoint(x: 0.36722, y: 0.525472), CGPoint(x: 0.443879, y: 0.551258), CGPoint(x: 0.58134, y: 0.518341), CGPoint(x: 0.23764, y: 0.42504), CGPoint(x: 0.580971, y: 0.361162)]
    }
}

/// 非表示・background・simulation停止の間は時計を止め、復帰時に過去の泡を追い生成しない。
nonisolated struct AquariumTreasureChestClock {
    private var accumulated: TimeInterval = 0
    private var runningSince: Date?
    mutating func setRunning(_ running: Bool, at date: Date) {
        if running, runningSince == nil { runningSince = date }
        else if !running, let start = runningSince {
            accumulated += max(0, date.timeIntervalSince(start)); runningSince = nil
        }
    }
    func elapsed(at date: Date) -> TimeInterval {
        accumulated + (runningSince.map { max(0, date.timeIntervalSince($0)) } ?? 0)
    }
}
