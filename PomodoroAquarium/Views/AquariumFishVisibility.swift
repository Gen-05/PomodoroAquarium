import CoreGraphics

/// 画像を取得せず、透明余白を含む描画枠全体で判定する。実際の魚体より保守的な範囲。
enum AquariumFishVisibility {
    static let effectPadding: CGFloat = 32
    static let reappearanceMargin: CGFloat = 12
    static let hysteresis: CGFloat = 12

    static func drawingBounds(position: CGPoint, aquariumSize: CGSize, fishSize: CGFloat,
                              rotationDegrees: Double) -> CGRect {
        let angle = CGFloat(rotationDegrees) * .pi / 180
        // 既存の微小な泳動回転(最大1.8度)と縦伸縮(最大2%)も含める。
        let projection = min(CGFloat(2).squareRoot(), abs(cos(angle)) + abs(sin(angle)) + 0.05)
        let halfExtent = fishSize / 2 * projection * 1.02 + effectPadding
        return CGRect(x: position.x * aquariumSize.width - halfExtent,
                      y: position.y * aquariumSize.height - halfExtent,
                      width: halfExtent * 2, height: halfExtent * 2)
    }

    static func shouldRender(wasRendering: Bool, position: CGPoint, aquariumSize: CGSize,
                             fishSize: CGFloat, rotationDegrees: Double, velocity: CGVector) -> Bool {
        guard AquariumFishWorld.hasValidGeometry(aquariumSize) else { return false }
        // 次の更新を飛び越して見え始めないよう、速い魚は現在速度の2 tick分先から用意する。
        let lookAhead = max(reappearanceMargin,
                            max(abs(velocity.dx * aquariumSize.width), abs(velocity.dy * aquariumSize.height))
                                * CGFloat(AquariumFishMotion.maximumDeltaTime * 2))
        let margin = lookAhead + (wasRendering ? hysteresis : 0)
        let viewport = CGRect(origin: .zero, size: aquariumSize).insetBy(dx: -margin, dy: -margin)
        return drawingBounds(position: position, aquariumSize: aquariumSize, fishSize: fishSize,
                             rotationDegrees: rotationDegrees).intersects(viewport)
    }
}
