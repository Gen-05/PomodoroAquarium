import SwiftData
import SwiftUI

struct ShopView: View {
    var decorationTutorial: DecorationPurchaseTutorial?
    var products: [ShopItem] = ShopCatalog.items
    var bottomContentBoundary: CGFloat?
    @Environment(\.modelContext) private var modelContext
    @Query private var players: [Player]
    @Query private var ownedDecorations: [AquariumDecorationPlacement]
    @State private var selectedCategory: ShopCategory = .decoration
    @State private var purchaseFlow = ShopPurchaseFlow()
    @State private var decorationPreview: ShopDecorationPreviewSession?
    @State private var showsPreviewError = false
    @Environment(\.aquariumFishViewingSession) private var fishViewingSession
    @AppStorage(AquariumThemeStore.storageKey) private var backgroundThemeRawValue = AquariumBackgroundTheme.aquarium.rawValue

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var player: Player? { players.first }
    private var balance: Int { CurrencyService.balance(of: player) }

    var body: some View {
        GeometryReader { geometry in
            let contentHeight = ShopContentLayout.contentHeight(frame: geometry.frame(in: .global),
                boundary: bottomContentBoundary)
            VStack(spacing: 0) {
                balanceHeader
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                ScrollView {
                    VStack(spacing: 18) {
                        Picker("商品カテゴリ", selection: $selectedCategory) {
                            ForEach(ShopCategory.allCases) { category in
                                Text(category.displayName).tag(category)
                            }
                        }
                        .pickerStyle(.segmented)

                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(products.filter { $0.category == selectedCategory }) { item in
                                productCard(item)
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .frame(height: contentHeight, alignment: .top)
        }
        .background(Color.cyan.opacity(0.08).ignoresSafeArea())
        .navigationTitle("ショップ")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $purchaseFlow.confirmation, onDismiss: { purchaseFlow.confirmationDidDismiss() }) { item in
            purchaseConfirmation(item)
        }
        // 確認sheetが閉じ終わってから結果を表示し、結果が閉じ終わってから初回案内へ進む。
        .sheet(item: $purchaseFlow.feedback, onDismiss: {
            purchaseFlow.feedbackDidDismiss(tutorial: decorationTutorial)
        }) { result in
            VStack(spacing: 20) {
                Text("ショップ").font(.headline)
                Text(result.message).multilineTextAlignment(.center)
                Button("OK") { purchaseFlow.feedback = nil }.buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("shop.purchaseFeedback.close")
            }
            .padding(24).frame(maxWidth: .infinity, maxHeight: .infinity)
            .presentationDetents([.height(220)])
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("shop.purchaseFeedback")
        }
    }

    private var balanceHeader: some View {
        HStack(spacing: 7) {
            Image(systemName: "circle.hexagongrid.fill")
                .foregroundStyle(.yellow)
            Text("\(balance)")
                .font(.title2.bold())
                .monospacedDigit()
            Text("コイン")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("所持コイン \(balance)枚")
    }

    private func productCard(_ item: ShopItem) -> some View {
        let canAfford = CurrencyService.canAfford(item.price, player: player)
        let isPurchasable = item.category == .decoration
        let soldOut = isSoldOut(item)

        return VStack(spacing: 10) {
            productPreview(item, comparesDecorationSizes: true)
                .frame(height: ShopDecorationThumbnailLayout.height)
                // scaledToFillの画像領域を操作対象にせず、背後のPickerやスクロールへ通す。
                .allowsHitTesting(false)

            if case .decoration(.shipwreck) = item.content {
                Text("遠景の固定配置")
                    .font(.caption2).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(item.name)
                .font(.headline)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Label("\(item.price)コイン", systemImage: "circle.hexagongrid.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(canAfford ? .yellow : .secondary)

            Button {
                purchaseFlow.requestConfirmation(for: item)
            } label: {
                Text(soldOut ? "売り切れ" : (isPurchasable ? (canAfford ? "購入する" : "コイン不足") : "準備中"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(soldOut || !isPurchasable || player == nil || purchaseFlow.isPresenting)
            .accessibilityIdentifier("purchase-\(item.id)")
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(canAfford ? Color.cyan.opacity(0.45) : Color.secondary.opacity(0.2))
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func productPreview(_ item: ShopItem, comparesDecorationSizes: Bool = false) -> some View {
        switch item.content {
        case let .decoration(kind):
            if kind.isAvailable, let imageName = kind.assetImageName {
                if comparesDecorationSizes && kind != .shipwreck {
                    GeometryReader { geometry in
                        let frame = ShopDecorationThumbnailLayout.frame(for: kind, in: geometry.size)
                        Image(decorative: imageName)
                            .resizable().scaledToFit()
                            .frame(width: frame.width, height: frame.height)
                            .position(x: frame.midX, y: frame.midY)
                    }
                } else {
                    Image(decorative: imageName)
                        .resizable().scaledToFit().padding(4)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        case let .background(theme):
            GeometryReader { geometry in
                // 完成背景の静止画だけを使い、海底の違いが見える下寄せで切り取る。
                Image(decorative: theme.imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height, alignment: .bottom)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func isSoldOut(_ item: ShopItem) -> Bool {
        guard case let .decoration(kind) = item.content else { return false }
        return ShopService.isSoldOut(kind, among: ownedDecorations)
    }

    private func purchaseConfirmation(_ item: ShopItem) -> some View {
        let canAfford = CurrencyService.canAfford(item.price, player: player)
        let soldOut = isSoldOut(item)

        return NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    productPreview(item)
                        .frame(height: 180)
                        .allowsHitTesting(false)
                    Text(item.name)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                    VStack(spacing: 12) {
                        LabeledContent("価格", value: "\(item.price)コイン")
                        LabeledContent("現在の所持コイン", value: "\(balance)コイン")
                        LabeledContent("購入後の所持コイン", value: canAfford ? "\(balance - item.price)コイン" : "コイン不足")
                    }
                    .monospacedDigit()
                    if soldOut {
                        Text("売り切れです").foregroundStyle(.secondary)
                    } else if !canAfford {
                        Text("コインが足りません").foregroundStyle(.red)
                    }
                    Button("自分の水槽で試す") {
                        guard let player else { return }
                        do {
                            decorationPreview = try ShopDecorationPreviewSession(item: item, official: player,
                                placements: ownedDecorations,
                                backgroundTheme: AquariumThemeStore.theme(from: backgroundThemeRawValue),
                                fishViewingSession: fishViewingSession)
                        } catch { showsPreviewError = true }
                    }
                    .buttonStyle(.bordered)
                    .disabled(player == nil || decorationPreview != nil)
                    .accessibilityIdentifier("shop.purchaseConfirmation.tryInAquarium")
                    Button("購入を確定") {
                        purchaseFlow.confirm(player: player, in: modelContext, tutorial: decorationTutorial)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canAfford || soldOut || player == nil || purchaseFlow.confirmation == nil)
                    .accessibilityIdentifier("shop.purchaseConfirmation.confirm")
                    Button("キャンセル", role: .cancel) { purchaseFlow.confirmation = nil }
                        .accessibilityIdentifier("shop.purchaseConfirmation.cancel")
                }
                .padding(24)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("購入確認")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        // 確認sheetの内側に重ね、閉じてもconfirmationや結果のonDismissには触れない。
        .fullScreenCover(item: $decorationPreview) { session in
            ShopDecorationPreviewView(session: session)
        }
        .alert("プレビューを開けませんでした", isPresented: $showsPreviewError) {
            Button("OK", role: .cancel) {}
        }
    }
}

#Preview {
    NavigationStack { ShopView() }
        .modelContainer(
            for: [Player.self, PlayerFish.self, AquariumDecorationPlacement.self],
            inMemory: true
        )
}
