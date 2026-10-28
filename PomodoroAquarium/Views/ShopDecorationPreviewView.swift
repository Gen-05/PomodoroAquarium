import SwiftUI
import SwiftData

struct ShopDecorationPreviewView: View {
    let session: ShopDecorationPreviewSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .top) {
            AquariumView(player: session.working.player,
                fishViewingSessionOverride: session.fishViewingSession,
                backgroundTheme: session.backgroundTheme,
                allowsDeveloperDecorationSeeding: false,
                isEditing: true,
                isTreasureTapEnabled: false,
                defersDecorationPersistence: true,
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
                     : "光っている商品をドラッグして動かせます。購入や保存はされません。")
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
                } else if session.trial.kind.supportsFacingDirection {
                    Button("向きを変える", systemImage: "arrow.left.arrow.right") { session.changeFacing() }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("shop.decorationPreview.changeFacing")
                }
            }
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
            .padding(16)
        }
        .coordinateSpace(name: AquariumEditorCoordinateSpace.name)
        .modelContainer(session.modelContainer)
    }
}
