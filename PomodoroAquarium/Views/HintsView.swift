import SwiftUI

extension EnvironmentValues {
    @Entry var hintContentBottomBoundary: CGFloat? = nil
}

/// 閲覧専用。購入・編集・チュートリアルの状態には接続しない。
struct HintsView: View {
    @Environment(\.hintContentBottomBoundary) private var bottomBoundary

    var body: some View {
        GeometryReader { geometry in
            List {
                ForEach(HintTopic.allCases) { topic in
                    Section(topic.title) {
                        ForEach(topic.guides) { guide in
                            NavigationLink {
                                HintGuideView(guide: guide)
                            } label: {
                                Text(guide.title)
                                    .padding(.vertical, 4)
                            }
                            .accessibilityIdentifier("hints.guide.\(guide.id)")
                        }
                    }
                }
            }
            .frame(height: ShopContentLayout.contentHeight(frame: geometry.frame(in: .global), boundary: bottomBoundary))
            .clipped()
        }
        .navigationTitle("ヒント")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { HintsView() }
}
