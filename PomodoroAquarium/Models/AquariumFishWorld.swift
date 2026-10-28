import CoreGraphics

/// 座標の1は表示幅のまま。回遊域だけを広げ、速度を2画面分へ換算しない。
enum AquariumFishWorld {
    static let horizontalExtension: CGFloat = 0.5
    static var horizontalRange: ClosedRange<CGFloat> { (-horizontalExtension)...(1 + horizontalExtension) }

    static func hasValidGeometry(_ size: CGSize) -> Bool {
        size.width.isFinite && size.height.isFinite && size.width > 0 && size.height > 0
    }

    static func bounds(from viewport: FishRoamingBounds) -> FishRoamingBounds {
        FishRoamingBounds(horizontal: horizontalRange, vertical: viewport.vertical,
            horizontalWallMargin: viewport.horizontalWallMargin, verticalWallMargin: viewport.verticalWallMargin)
    }
}
