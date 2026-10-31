import SwiftUI

/// 実画面の静止画像を読むだけのガイド。ページ位置はこの画面の中だけで保持する。
struct HintGuideView: View {
    let guide: HintGuide
    @State private var pageIndex = 0
    @Environment(\.hintContentBottomBoundary) private var bottomBoundary

    var body: some View {
        let page = guide.pages[pageIndex]
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(page.title)
                        .font(.title2.bold())
                        .accessibilityAddTraits(.isHeader)

                    Image(page.image.assetName)
                        .resizable()
                        .aspectRatio(page.image.aspectRatio, contentMode: .fit)
                        .overlay {
                            GeometryReader { geometry in
                                if let key = page.target, let target = page.image.targets[key] {
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(.orange, lineWidth: 3)
                                        .frame(width: geometry.size.width * target.width + 8,
                                           height: geometry.size.height * target.height + 8)
                                        .position(x: geometry.size.width * target.midX,
                                              y: geometry.size.height * target.midY)
                                }
                            }
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .accessibilityLabel("\(page.title)の実際の画面。\(page.explanation)")
                        .accessibilityIdentifier("hints.guide.screenshot.\(pageIndex)")

                    Text(page.explanation)
                        .font(.body)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack {
                        Button("前の画像") { pageIndex = max(0, pageIndex - 1) }
                            .disabled(pageIndex == 0)
                            .accessibilityIdentifier("hints.guide.previousImage")
                        Spacer()
                        Text("\(pageIndex + 1) / \(guide.pages.count)")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button("次の画像") { pageIndex = min(guide.pages.count - 1, pageIndex + 1) }
                            .disabled(pageIndex == guide.pages.count - 1)
                            .accessibilityIdentifier("hints.guide.nextImage")
                    }
                    .buttonStyle(.bordered)
                    .padding(.top, 4)
                }
                .padding(20)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .id(pageIndex) // 読み進めたページは、画像の先頭から表示する。
            .frame(height: ShopContentLayout.contentHeight(frame: geometry.frame(in: .global), boundary: bottomBoundary))
            .clipped()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("ヒント")
        .navigationBarTitleDisplayMode(.inline)
    }

}

#Preview {
    NavigationStack { HintGuideView(guide: HintTopic.stackingGuide) }
}
