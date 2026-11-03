import Foundation
import CoreGraphics

/// 採用資料 preview_layout.json の852×1846座標。PNG内の透明余白も含めて同じ比率で配置する。
struct StartSurfaceLayout {
    static let referenceSize = CGSize(width: 852, height: 1846)
    static let fishRect = CGRect(x: 652.49125596184422, y: 909.14864864864865,
                                 width: 146, height: 91.22098569157393)
    static let buttonRect = CGRect(x: 251, y: 1223, width: 350, height: 78)
    let scale: CGFloat
    let origin: CGPoint

    init(size: CGSize) {
        scale = max(0, min(size.width / Self.referenceSize.width, size.height / Self.referenceSize.height))
        origin = CGPoint(x: (size.width - Self.referenceSize.width * scale) / 2,
                         y: (size.height - Self.referenceSize.height * scale) / 2)
    }
    func rect(_ source: CGRect) -> CGRect {
        CGRect(x: origin.x + source.minX * scale, y: origin.y + source.minY * scale,
               width: source.width * scale, height: source.height * scale)
    }
    var canvasRect: CGRect { rect(CGRect(origin: .zero, size: Self.referenceSize)) }
}

/// 表示中の実経過時間だけを積算。背景復帰/再表示時に隠れていた時間を加算しない。
struct StartSurfaceClock {
    static let period: TimeInterval = 180
    private(set) var elapsed: TimeInterval = 0
    private(set) var isRunning = false
    private var lastTimestamp: TimeInterval?

    mutating func setRunning(_ running: Bool) {
        guard running != isRunning else { return }
        isRunning = running
        lastTimestamp = nil
    }
    mutating func advance(at timestamp: TimeInterval) -> TimeInterval {
        guard isRunning else { return elapsed }
        if let lastTimestamp {
            elapsed = (elapsed + max(0, timestamp - lastTimestamp)).truncatingRemainder(dividingBy: Self.period)
        }
        lastTimestamp = timestamp
        return elapsed
    }
}
