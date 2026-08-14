//
//  AquariumView.swift
//  PomodoroAquarium
//

import SwiftUI
import UIKit

struct AquariumView: View {
    let player: Player?

    private var favoriteFish: PlayerFish? {
        player?.favoriteFish
    }

    private var displayedFish: [PlayerFish] {
        guard let player else { return [] }

        var fish = player.ownedFish
        if let favoriteFish {
            fish.removeAll { $0.id == favoriteFish.id }
            fish.insert(favoriteFish, at: 0)
        }
        return fish
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                aquariumBackground
                aquariumDecorations
                fishLayer(in: geometry.size)

                if displayedFish.isEmpty {
                    favoriteFishGuide
                        .offset(y: -geometry.size.height * 0.16)
                } else if favoriteFish == nil {
                    favoriteFishGuide
                        .scaleEffect(0.8)
                        .offset(y: -geometry.size.height * 0.36)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        }
        .ignoresSafeArea()
    }

    // 背景テーマは、今後このレイヤーを差し替えて変更する。
    private var aquariumBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.22, green: 0.78, blue: 0.88),
                    Color(red: 0.04, green: 0.38, blue: 0.68),
                    Color(red: 0.02, green: 0.12, blue: 0.32)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            LinearGradient(
                colors: [.white.opacity(0.22), .clear],
                startPoint: .topLeading,
                endPoint: .center
            )
        }
    }

    // 泡、水草、装飾などはこのレイヤーに追加できる。
    private var aquariumDecorations: some View {
        ZStack {
            Ellipse()
                .fill(.white.opacity(0.07))
                .frame(width: 110, height: 700)
                .rotationEffect(.degrees(18))
                .offset(x: -120, y: -180)

            Ellipse()
                .fill(.white.opacity(0.05))
                .frame(width: 80, height: 620)
                .rotationEffect(.degrees(18))
                .offset(x: 60, y: -220)

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

    // 魚の配置と泳ぎは、背景装飾とは独立したレイヤーで管理する。
    private func fishLayer(in size: CGSize) -> some View {
        ZStack {
            ForEach(Array(displayedFish.enumerated()), id: \.element.id) { index, playerFish in
                let isFavorite = playerFish.id == favoriteFish?.id

                SwimmingFishView(
                    species: playerFish.species,
                    isFavorite: isFavorite,
                    index: index,
                    swimmingDistance: swimmingDistance(in: size, isFavorite: isFavorite)
                )
                .position(
                    x: size.width / 2,
                    y: verticalPosition(for: index, count: displayedFish.count, in: size)
                )
            }
        }
    }

    private var favoriteFishGuide: some View {
        VStack(spacing: 8) {
            Image(systemName: "fish")
                .font(.system(size: 42))

            Text("図鑑からお気に入りの魚を選んでください")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
        .aquariumGlass(cornerRadius: 20)
        .padding(.horizontal, 32)
    }

    private func swimmingDistance(in size: CGSize, isFavorite: Bool) -> CGFloat {
        let fishWidth: CGFloat = isFavorite ? 130 : 90
        return max(0, (size.width - fishWidth) / 2)
    }

    private func verticalPosition(for index: Int, count: Int, in size: CGSize) -> CGFloat {
        let top = size.height * 0.18
        let bottom = size.height * 0.62

        guard count > 1 else { return size.height * 0.34 }
        return top + (bottom - top) * CGFloat(index) / CGFloat(count - 1)
    }
}

private struct SwimmingFishView: View {
    let species: FishSpecies
    let isFavorite: Bool
    let index: Int
    let swimmingDistance: CGFloat

    @State private var isSwimmingToRight: Bool

    init(
        species: FishSpecies,
        isFavorite: Bool,
        index: Int,
        swimmingDistance: CGFloat
    ) {
        self.species = species
        self.isFavorite = isFavorite
        self.index = index
        self.swimmingDistance = swimmingDistance
        self._isSwimmingToRight = State(initialValue: index.isMultiple(of: 2))
    }

    var body: some View {
        fishImage
        .offset(x: isSwimmingToRight ? swimmingDistance : -swimmingDistance)
        .onAppear {
            withAnimation(
                .linear(duration: animationDuration)
                .delay(Double(index % 4) * 0.3)
                .repeatForever(autoreverses: true)
            ) {
                isSwimmingToRight.toggle()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isFavorite ? "お気に入りの\(species.name)" : species.name)
    }

    @ViewBuilder
    private var fishImage: some View {
        if let image = UIImage(named: species.imageName) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: fishSize, height: fishSize)
        } else {
            Image(systemName: "fish")
                .font(.system(size: isFavorite ? 70 : 48))
        }
    }

    private var fishSize: CGFloat {
        isFavorite ? 120 : 78
    }

    private var animationDuration: Double {
        8 + Double(index % 3)
    }
}

extension View {
    func aquariumGlass(cornerRadius: CGFloat = 22) -> some View {
        background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(.white.opacity(0.28), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
        }
    }
}

struct AquariumPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                LinearGradient(
                    colors: [.cyan.opacity(0.9), .blue.opacity(0.9)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: Capsule()
            )
            .overlay(Capsule().stroke(.white.opacity(0.35), lineWidth: 1))
            .shadow(color: .blue.opacity(0.35), radius: 10, y: 5)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

struct AquariumSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.horizontal, 28)
            .padding(.vertical, 12)
            .background(.white.opacity(configuration.isPressed ? 0.12 : 0.18), in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 1))
    }
}

#Preview {
    AquariumView(player: nil)
}
