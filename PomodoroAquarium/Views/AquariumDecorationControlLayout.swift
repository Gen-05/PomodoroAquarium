import CoreGraphics

/// 表示専用。最大幅を予約し、モード切替で中心が変わらないようにする。
enum AquariumDecorationControlLayout {
    static func center(bounds: CGRect, canvas: CGSize, topInset: CGFloat) -> CGPoint {
        let width = min(330, max(0, canvas.width - 24))
        let height: CGFloat = 60
        let minX = 12 + width / 2, maxX = max(minX, canvas.width - 12 - width / 2)
        let maxY = max(height / 2, canvas.height - 24 - height / 2)
        let minY = min(maxY, max(12, topInset) + height / 2)
        func clamped(_ p: CGPoint) -> CGPoint {
            CGPoint(x: min(maxX, max(minX, p.x)), y: min(maxY, max(minY, p.y)))
        }
        let gap: CGFloat = 16
        let candidates = [
            CGPoint(x: bounds.midX, y: bounds.minY - gap - height / 2),
            CGPoint(x: bounds.midX, y: bounds.maxY + gap + height / 2),
            CGPoint(x: bounds.minX - gap - width / 2, y: bounds.midY),
            CGPoint(x: bounds.maxX + gap + width / 2, y: bounds.midY),
            CGPoint(x: minX, y: minY), CGPoint(x: maxX, y: minY),
            CGPoint(x: minX, y: maxY), CGPoint(x: maxX, y: maxY)
        ].map(clamped)
        func overlap(_ center: CGPoint) -> CGFloat {
            let rect = CGRect(x: center.x - width / 2, y: center.y - height / 2, width: width, height: height)
            let intersection = rect.intersection(bounds.insetBy(dx: -8, dy: -8))
            return intersection.isNull ? 0 : intersection.width * intersection.height
        }
        if let clear = candidates.first(where: { overlap($0) == 0 }) { return clear }
        // 装飾が可用領域全体を占める場合のみ、隠す面積が最も小さい場所へ退避する。
        return candidates.min(by: { overlap($0) < overlap($1) }) ?? clamped(.zero)
    }
}
