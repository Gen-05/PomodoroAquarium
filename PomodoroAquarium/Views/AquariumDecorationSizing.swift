import CoreGraphics

/// 水槽canvas内だけの表示倍率。保存scale・一覧素材サイズ・沈没船の遠景設定は変更しない。
enum AquariumDecorationSizing {
    static let referenceShortSide: CGFloat = 393
    static let maximumViewportScale: CGFloat = 1.8

    static func viewportScale(for kind: AquariumDecorationKind, in canvas: CGSize) -> CGFloat {
        guard kind != .shipwreck, canvas.width.isFinite, canvas.height.isFinite,
              canvas.width > 0, canvas.height > 0 else { return 1 }
        return min(max(min(canvas.width, canvas.height) / referenceShortSide, 1), maximumViewportScale)
    }

    static func scale(for kind: AquariumDecorationKind, individualScale: CGFloat,
                      relativeY: CGFloat, in canvas: CGSize) -> CGFloat {
        individualScale * AquariumDecorationDepthPresentation(kind: kind, relativeY: relativeY).scale
            * viewportScale(for: kind, in: canvas)
    }

    /// 根元を配置座標に合わせた画像枠。透明部分の判定と描画で同じ変換を使う。
    static func frame(for decoration: AquariumDecoration, root: CGPoint? = nil, in canvas: CGSize) -> CGRect {
        let root = root ?? CGPoint(x: decoration.relativeX, y: decoration.relativeY)
        let scale = scale(for: decoration.kind, individualScale: decoration.scale, relativeY: root.y, in: canvas)
        let width = decoration.kind.displaySize.width * scale
        let height = decoration.kind.displaySize.height * scale
        return CGRect(x: root.x * canvas.width - width / 2,
                      y: root.y * canvas.height - (decoration.kind.groundAnchorY(facingDirection: decoration.facingDirection) ?? 0.5) * height,
                      width: width, height: height)
    }
}
