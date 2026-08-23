import SwiftData
import SwiftUI

struct MainTabView: View {
    @Query private var players: [Player]

    private var player: Player? { players.first }

    var body: some View {
        TabView {
            Tab("水槽", systemImage: "fish.fill") {
                HomeView()
            }

            Tab("図鑑", systemImage: "book.closed.fill") {
                NavigationStack {
                    BookView()
                }
            }

            Tab("統計", systemImage: "chart.bar.fill") {
                NavigationStack {
                    StatisticsView(player: player)
                }
            }
        }
        .tint(.cyan)
    }
}

#Preview {
    MainTabView()
        .modelContainer(
            for: [Player.self, PlayerFish.self, AquariumDecorationPlacement.self, StudyDailyRecord.self],
            inMemory: true
        )
}
