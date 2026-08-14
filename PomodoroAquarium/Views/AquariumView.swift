//
//  AquariumView.swift
//  PomodoroAquarium
//

import SwiftUI
import UIKit

struct AquariumView: View {
    let player: Player?

    @State private var isSwimmingToRight = false

    private var favoriteFish: PlayerFish? {
        player?.favoriteFish
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                aquariumBackground
                aquariumDecorations
                aquariumContent(in: geometry.size)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        }
        .ignoresSafeArea()
    }

    // 背景テーマは、今後このレイヤーを差し替えて変更する。
    private var aquariumBackground: some View {
        LinearGradient(
            colors: [
                Color.cyan.opacity(0.45),
                Color.blue.opacity(0.55),
                Color.indigo.opacity(0.75)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // 泡、水草、装飾などはこのレイヤーに追加できる。
    private var aquariumDecorations: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.12))
                .frame(width: 180, height: 180)
                .blur(radius: 4)
                .offset(x: -130, y: -280)

            Circle()
                .fill(.cyan.opacity(0.12))
                .frame(width: 260, height: 260)
                .blur(radius: 8)
                .offset(x: 150, y: 300)
        }
    }

    @ViewBuilder
    private func aquariumContent(in size: CGSize) -> some View {
        if let favoriteFish {
            fishView(for: favoriteFish.species)
                .offset(
                    x: isSwimmingToRight ? swimmingDistance(in: size) : -swimmingDistance(in: size),
                    y: -size.height * 0.16
                )
                .onAppear {
                    withAnimation(.linear(duration: 9).repeatForever(autoreverses: true)) {
                        isSwimmingToRight = true
                    }
                }
        } else {
            VStack(spacing: 12) {
                Image(systemName: "fish")
                    .font(.system(size: 50))

                Text("図鑑からお気に入りの魚を選んでください")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal, 32)
            .offset(y: -size.height * 0.16)
        }
    }

    private func fishView(for species: FishSpecies) -> some View {
        VStack(spacing: 8) {
            if let image = UIImage(named: species.imageName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
            } else {
                Image(systemName: "fish")
                    .font(.system(size: 70))
            }

            Text(species.name)
                .font(.headline)
                .bold()
        }
        .accessibilityElement(children: .combine)
    }

    private func swimmingDistance(in size: CGSize) -> CGFloat {
        max(0, (size.width - 160) / 2)
    }
}

#Preview {
    AquariumView(player: nil)
}
