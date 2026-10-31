import SwiftUI
#if DEBUG
import SwiftData
#endif

struct MoreView: View {
#if DEBUG
    @Environment(\.modelContext) private var modelContext
    @Query private var players: [Player]
    @State private var coinGrantMessage: String?
#endif

    var body: some View {
        List {
            NavigationLink {
                BookView()
            } label: {
                Label("図鑑", systemImage: "book.closed.fill")
            }
            .accessibilityIdentifier("more.book")

            NavigationLink {
                AcquisitionHistoryView()
            } label: {
                Label("獲得履歴", systemImage: "clock.arrow.circlepath")
            }
            .accessibilityIdentifier("more.acquisitionHistory")

            NavigationLink {
                HintsView()
            } label: {
                Label("ヒント", systemImage: "questionmark.circle")
            }
            .accessibilityIdentifier("more.hints")

            NavigationLink {
                SettingsView()
            } label: {
                Label("設定", systemImage: "gearshape.fill")
            }
            .accessibilityIdentifier("more.settings")

#if DEBUG
            Section("開発") {
                NavigationLink {
                    RewardPreviewView()
                } label: {
                    Label("Reward Preview", systemImage: "sparkles")
                }
                .accessibilityIdentifier("more.rewardPreview")

                Button("テスト用コインを100,000枚追加") {
                    addTestCoins()
                }
                .disabled(players.first == nil || coinGrantMessage != nil)
                .accessibilityIdentifier("more.addTestCoins")
            }
#endif
        }
        .navigationTitle("その他")
#if DEBUG
        .alert("テスト用コイン", isPresented: Binding(
            get: { coinGrantMessage != nil },
            set: { if !$0 { coinGrantMessage = nil } }
        )) {
            Button("OK", role: .cancel) { coinGrantMessage = nil }
        } message: {
            Text(coinGrantMessage ?? "")
        }
#endif
    }

#if DEBUG
    private func addTestCoins() {
        guard coinGrantMessage == nil, let player = players.first else { return }
        let previousCoins = player.coins
        do {
            let balance = try CurrencyService.addCoins(100_000, to: player, in: modelContext)
            coinGrantMessage = "テスト用コインを追加しました。現在の残高：\(balance)コイン"
        } catch {
            // 保存失敗時の加算だけを戻し、他の未保存データには触れない。
            player.coins = previousCoins
            coinGrantMessage = "コインを追加できませんでした。"
        }
    }
#endif
}

#Preview {
    NavigationStack {
        MoreView()
    }
#if DEBUG
    .modelContainer(for: [Player.self, PlayerFish.self], inMemory: true)
#endif
}
