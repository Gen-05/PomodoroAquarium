import SwiftUI
import SwiftData

struct ShopDecorationPreviewView: View {
    let session: ShopDecorationPreviewSession
    @Environment(\.dismiss) private var dismiss
    @State private var headerFrame = CGRect.zero
    @State private var canvasFrame = CGRect.zero

    var body: some View {
        ZStack(alignment: .top) {
            AquariumView(player: session.working.player,
                fishViewingSessionOverride: session.fishViewingSession,
                backgroundTheme: session.backgroundTheme,
                onGlobalCanvasGeometryChanged: { canvasFrame = $0 },
                allowsDeveloperDecorationSeeding: false,
                isEditing: true,
                isTreasureTapEnabled: false,
                defersDecorationPersistence: true,
                decorationControlsTopInset: headerFrame.isEmpty ? 160 : max(0, headerFrame.maxY - canvasFrame.minY + 12),
                decorationTrialID: session.trial.decorationID,
                editingPlacements: session.placements)

            VStack(spacing: 12) {
                HStack {
                    Text("\(session.item.name)を試し置き").font(.headline)
                    Spacer()
                    Button("閉じる") { dismiss() }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("shop.decorationPreview.close")
                }
                Text(session.trial.kind == .shipwreck
                     ? "「左奥・右奥」で配置を試せます。購入や保存はされません。"
                     : "ドラッグ・微調整で位置、重なり順で前後を試せます。購入や保存はされません。")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if session.trial.kind == .shipwreck {
                    HStack {
                        ForEach([AquariumDecorationFacingDirection.left, .right], id: \.self) { side in
                            Button(side == .left ? "左奥" : "右奥") { session.placeShipwreck(on: side) }
                                .buttonStyle(.bordered)
                                .tint(session.trial.facingDirection == side ? .cyan : .secondary)
                                .accessibilityIdentifier("shop.decorationPreview.shipwreck.\(side.rawValue)")
                        }
                    }
                }
            }
            .padding(16)
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { headerFrame = $0 }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
            .padding(16)
        }
        .coordinateSpace(name: AquariumEditorCoordinateSpace.name)
        .modelContainer(session.modelContainer)
    }
}
