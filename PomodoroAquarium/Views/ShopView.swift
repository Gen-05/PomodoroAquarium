import SwiftData
import SwiftUI

struct ShopView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var players: [Player]
    @State private var selectedCategory: ShopCategory = .decoration
    @State private var feedbackMessage: String?

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
                    ForEach(ShopCatalog.items(in: selectedCategory)) { item in
                        productCard(item)
                    }
                }
            }
            .padding()
        }
        .background(Color.cyan.opacity(0.08).ignoresSafeArea())
        .navigationTitle("ショップ")
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            "ショップ",
            isPresented: Binding(
                get: { feedbackMessage != nil },
                set: { if !$0 { feedbackMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(feedbackMessage ?? "")
        }
    }

    private func productCard(_ item: ShopItem) -> some View {
        let canAfford = CurrencyService.canAfford(item.price, player: player)
        let isPurchasable = item.category == .decoration

        return VStack(spacing: 10) {
            productPreview(item)
                .frame(height: 92)

            Text(item.name)
                .font(.headline)

            Label("\(item.price)コイン", systemImage: "circle.hexagongrid.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(canAfford ? .yellow : .secondary)

            Button {
                purchase(item)
            } label: {
                Text(isPurchasable ? (canAfford ? "購入する" : "コイン不足") : "準備中")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!isPurchasable || player == nil)
            .accessibilityIdentifier("purchase-\(item.id)")
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(canAfford ? Color.cyan.opacity(0.45) : Color.secondary.opacity(0.2))
        }
    }

    @ViewBuilder
    private func productPreview(_ item: ShopItem) -> some View {
        switch item.content {
        case let .decoration(kind):
            AquariumDecorationView(decoration: AquariumDecoration(
                id: "shop-preview-\(kind.rawValue)",
                kind: kind,
                relativeX: 0.5,
                relativeY: 0.5,
                scale: 1
            ))
            .scaleEffect(0.65)
        case let .background(theme):
            LinearGradient(
                colors: theme.fallbackColors,
                startPoint: .top,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func purchase(_ item: ShopItem) {
        do {
            _ = try ShopService.purchaseDecoration(item, for: player, in: modelContext)
            feedbackMessage = "\(item.name)を購入しました"
        } catch ShopPurchaseError.insufficientCoins {
            feedbackMessage = "コインが足りません"
        } catch {
            feedbackMessage = "購入できませんでした"
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
