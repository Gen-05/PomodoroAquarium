import SwiftUI

/// 加工済みPNGの背景別表示設定。画像本来の色とアルファを保持する。
struct AquariumShipwreckPresentation {
    let assetName: String
    let left: CGPoint
    let right: CGPoint
    let widthRatio: CGFloat
    let rotationDegrees: Double
    static let imageAspectRatio: CGFloat = 1600.0 / 1088.0

    static func settings(for theme: AquariumBackgroundTheme) -> Self {
        switch theme {
        case .aquarium:
            Self(assetName: "shipwreck_distant", left: CGPoint(x: 0.290, y: 0.423),
                 right: CGPoint(x: 0.710, y: 0.413), widthRatio: 0.97888, rotationDegrees: 20)
        case .tropical:
            Self(assetName: "shipwreck_distant_coral", left: CGPoint(x: 0.285, y: 0.412),
                 right: CGPoint(x: 0.715, y: 0.403), widthRatio: 0.9982, rotationDegrees: 20)
        case .deepSea:
            Self(assetName: "shipwreck_distant_deep", left: CGPoint(x: 0.280, y: 0.410),
                 right: CGPoint(x: 0.720, y: 0.392), widthRatio: 1.0626, rotationDegrees: 20)
        }
    }
    func center(side: AquariumDecorationFacingDirection, size: CGSize) -> CGPoint {
        let p = side == .left ? left : right
        return CGPoint(x: p.x * size.width, y: p.y * size.height)
    }
    /// 最終PNGのキャンバス中心で反転・回転する。旧PNGのアルファ重心補正は使用しない。
    func point(_ unit: CGPoint, side: AquariumDecorationFacingDirection, size: CGSize) -> CGPoint {
        let width = size.width * widthRatio, height = width / Self.imageAspectRatio
        let x = (unit.x - 0.5) * width * (side == .right ? -1 : 1)
        let y = (unit.y - 0.5) * height
        let angle = CGFloat(rotationDegrees * .pi / 180) * (side == .left ? -1 : 1)
        let root = center(side: side, size: size)
        return CGPoint(x: root.x + x * cos(angle) - y * sin(angle),
                       y: root.y + x * sin(angle) + y * cos(angle))
    }
    func bounds(side: AquariumDecorationFacingDirection, size: CGSize) -> CGRect {
        let corners = [CGPoint.zero, CGPoint(x: 1, y: 0), CGPoint(x: 0, y: 1), CGPoint(x: 1, y: 1)]
            .map { point($0, side: side, size: size) }
        let xs = corners.map(\.x), ys = corners.map(\.y)
        return CGRect(x: xs.min()!, y: ys.min()!, width: xs.max()! - xs.min()!, height: ys.max()! - ys.min()!)
    }
}

/// PNGの色・透明度・霞・部分フェードをそのまま表示する。
struct AquariumShipwreckView: View {
    let side: AquariumDecorationFacingDirection
    let theme: AquariumBackgroundTheme
    let size: CGSize
    var body: some View {
        let setting = AquariumShipwreckPresentation.settings(for: theme)
        let width = size.width * setting.widthRatio
        Image(setting.assetName)
            .resizable().scaledToFit()
            .frame(width: width, height: width / AquariumShipwreckPresentation.imageAspectRatio)
            .scaleEffect(x: side == .right ? -1 : 1, y: 1)
            .rotationEffect(.degrees(side == .left ? -setting.rotationDegrees : setting.rotationDegrees))
            .position(setting.center(side: side, size: size))
            .allowsHitTesting(false)
    }
}
