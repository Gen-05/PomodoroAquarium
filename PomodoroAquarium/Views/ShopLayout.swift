import CoreGraphics

enum ShopContentLayout {
    /// 実際のタブバー上端までをレイアウト領域にする。親が既に縮めていれば二重に縮めない。
    static func contentHeight(frame: CGRect, boundary: CGFloat?) -> CGFloat {
        guard let boundary else { return frame.height }
        return max(0, min(frame.height, boundary - frame.minY))
    }
}

/// カード専用。通常装飾は同じ倍率・同じ接地線で比較し、水槽の設定には触れない。
enum ShopDecorationThumbnailLayout {
    static let height: CGFloat = 92
    static let padding: CGFloat = 4
    static let kinds = AquariumDecorationKind.availableKinds.filter { $0 != .shipwreck }
    private static let referenceWidth = kinds.map { $0.displaySize.width }.max() ?? 1
    private static let aboveGround = kinds.map { $0.displaySize.height * ($0.groundAnchorY ?? 1) }.max() ?? 1
    private static let belowGround = kinds.map { $0.displaySize.height * (1 - ($0.groundAnchorY ?? 1)) }.max() ?? 0

    static func scale(in size: CGSize) -> CGFloat {
        guard size.width.isFinite, size.height.isFinite else { return 0 }
        return max(0, min((size.width - padding * 2) / referenceWidth,
                          (size.height - padding * 2) / (aboveGround + belowGround)))
    }

    static func frame(for kind: AquariumDecorationKind, in size: CGSize) -> CGRect {
        guard kind.isAvailable, kind != .shipwreck else { return .zero }
        let scale = scale(in: size)
        let width = kind.displaySize.width * scale
        let height = kind.displaySize.height * scale
        let baseline = size.height - padding - belowGround * scale
        return CGRect(x: (size.width - width) / 2,
                      y: baseline - (kind.groundAnchorY ?? 1) * height,
                      width: width, height: height)
    }
}
