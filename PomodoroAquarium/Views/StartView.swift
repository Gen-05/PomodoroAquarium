import SwiftUI
import SwiftData

struct StartView: View {
    let onStart: () -> Void

    @AppStorage(AquariumThemeStore.storageKey)
    private var backgroundThemeRawValue = AquariumBackgroundTheme.aquarium.rawValue

    @Query private var players: [Player]

    private var player: Player? {
        players.first
    }

    var body: some View {
        ZStack {
            AquariumView(
                player: player,
                backgroundTheme: AquariumThemeStore.theme(from: backgroundThemeRawValue)
            )
            .allowsHitTesting(false)

            VStack(spacing: 28) {
                Spacer()

                Image(systemName: "fish.fill")
                    .font(.system(size: 74, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .shadow(color: .cyan.opacity(0.45), radius: 12)

                Text("ポモドーロ水族館")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 8, y: 3)

                Button("START") {
                    onStart()
                }
                .buttonStyle(AquariumPrimaryButtonStyle())
                .frame(maxWidth: 260)
                .accessibilityIdentifier("startButton")

                Spacer()
            }
            .padding(.horizontal, 32)
        }
        .ignoresSafeArea()
    }
}

#Preview {
    StartView(onStart: {})
        .modelContainer(for: [Player.self, PlayerFish.self, AquariumDecorationPlacement.self], inMemory: true)
}
