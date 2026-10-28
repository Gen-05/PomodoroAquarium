import CoreGraphics

/// 水槽内の魚画像だけに使う奥行きぼかし。深度の更新・泳ぎの状態は持たない。
enum AquariumFishDepthBlur {
    static let maximumRadius: CGFloat = 0.4
    static let startDepth: CGFloat = 0.5

    static func radius(at depth: CGFloat) -> CGFloat {
        guard depth.isFinite, startDepth > 0 else { return 0 }
        let progress = min(max((startDepth - depth) / startDepth, 0), 1)
        return maximumRadius * progress
    }
}
