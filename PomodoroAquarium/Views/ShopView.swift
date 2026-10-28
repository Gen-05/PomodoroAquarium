import SwiftData
import SwiftUI

struct ShopView: View {
    var decorationTutorial: DecorationPurchaseTutorial?
    var products: [ShopItem] = ShopCatalog.items
    @Environment(\.modelContext) private var modelContext
    @Query private var players: [Player]
    @Query private var ownedDecorations: [AquariumDecorationPlacement]
    @State private var selectedCategory: ShopCategory = .decoration
    @State private var feedback: PurchaseFeedback?

    private struct PurchaseFeedback: Identifiable {
        let id = UUID()
        let message: String
    }

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var player: Player? { players.first }
    private var balance: Int { CurrencyService.balance(of: player) }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
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
            .padding()
        }
        .background(Color.cyan.opacity(0.08).ignoresSafeArea())
        .navigationTitle("ショップ")
        .navigationBarTitleDisplayMode(.inline)
        // onDismissは購入結果の表示が閉じ終わってから呼ばれる。案内と重ねない。
        .sheet(item: $feedback, onDismiss: { decorationTutorial?.purchaseFeedbackDidDismiss() }) { result in
            VStack(spacing: 20) {
                Text("ショップ").font(.headline)
                Text(result.message).multilineTextAlignment(.center)
                Button("OK") { feedback = nil }.buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("shop.purchaseFeedback.close")
            }
            .padding(24).frame(maxWidth: .infinity, maxHeight: .infinity)
            .presentationDetents([.height(220)])
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("shop.purchaseFeedback")
        }
    }

    private func productCard(_ item: ShopItem) -> some View {
        let canAfford = CurrencyService.canAfford(item.price, player: player)
        let isPurchasable = item.category == .decoration
        let isSoldOut: Bool
        if case let .decoration(kind) = item.content {
            isSoldOut = ShopService.isSoldOut(kind, among: ownedDecorations)
        } else {
            isSoldOut = false
        }

        return VStack(spacing: 10) {
            productPreview(item)
                .frame(height: 92)
                // scaledToFillの画像領域を操作対象にせず、背後のPickerやスクロールへ通す。
                .allowsHitTesting(false)

            Text(item.name)
                .font(.headline)

            Label("\(item.price)コイン", systemImage: "circle.hexagongrid.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(canAfford ? .yellow : .secondary)

            Button {
                purchase(item)
            } label: {
                Text(isSoldOut ? "売り切れ" : (isPurchasable ? (canAfford ? "購入する" : "コイン不足") : "準備中"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSoldOut || !isPurchasable || player == nil || feedback != nil)
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
    private func productPreview(_ item: ShopItem) -> some View {
        switch item.content {
        case let .decoration(kind):
            if kind.isAvailable, let imageName = kind.assetImageName {
                Image(decorative: imageName)
                    .resizable()
                    .scaledToFit()
                    .padding(4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    private func purchase(_ item: ShopItem) {
        guard feedback == nil else { return }
        decorationTutorial?.purchaseFeedbackWillPresent()
        do {
            if let decorationTutorial {
                try decorationTutorial.purchase(item, player: player, in: modelContext)
            } else {
                try ShopService.purchaseDecoration(item, for: player, in: modelContext)
            }
            feedback = PurchaseFeedback(message: "\(item.name)を購入しました")
        } catch ShopPurchaseError.insufficientCoins {
            feedback = PurchaseFeedback(message: "コインが足りません")
        } catch ShopPurchaseError.soldOut {
            feedback = PurchaseFeedback(message: "沈没船は売り切れです")
        } catch {
            feedback = PurchaseFeedback(message: "購入できませんでした")
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
