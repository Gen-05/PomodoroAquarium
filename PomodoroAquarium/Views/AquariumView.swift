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

    // 保存・編集機能を追加するまでは、固定装飾をこの配列から表示する。
    private let decorations: [AquariumDecoration] = [
        AquariumDecoration(
            id: "default-seaweed",
            kind: .seaweed,
            relativeX: 0.14,
            relativeY: 0.82,
            scale: 1.0
        ),
        AquariumDecoration(
            id: "default-rock",
            kind: .rock,
            relativeX: 0.82,
            relativeY: 0.88,
            scale: 1.1
        )
    ]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                AquariumBackground()
                BubbleLayer()
                AquariumFloor()
                decorationLayer(in: geometry.size)
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

    // AquariumDecorationを画面上の座標へ変換して描画する装飾レイヤー。
    private func decorationLayer(in size: CGSize) -> some View {
        ZStack {
            ForEach(decorations) { decoration in
                AquariumDecorationView(decoration: decoration)
                    .scaleEffect(decoration.scale)
                    .position(
                        x: size.width * decoration.relativeX,
                        y: size.height * decoration.relativeY
                    )
            }
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

private struct AquariumDecorationView: View {
    let decoration: AquariumDecoration

    @ViewBuilder
    var body: some View {
        switch decoration.kind {
        case .seaweed:
            HStack(alignment: .bottom, spacing: -8) {
                seaweedStem(height: 88, rotation: -8)
                seaweedStem(height: 120, rotation: 3)
                seaweedStem(height: 76, rotation: 10)
            }
            .foregroundStyle(
                LinearGradient(
                    colors: [.mint, .green.opacity(0.75)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

        case .rock:
            ZStack(alignment: .bottom) {
                Ellipse()
                    .fill(Color.black.opacity(0.18))
                    .frame(width: 112, height: 30)

                RoundedRectangle(cornerRadius: 28)
                    .fill(
                        LinearGradient(
                            colors: [.gray.opacity(0.9), .black.opacity(0.55)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 94, height: 64)
                    .offset(y: -8)
            }
        }
    }

    private func seaweedStem(height: CGFloat, rotation: Double) -> some View {
        Capsule()
            .fill(.green)
            .frame(width: 18, height: height)
            .rotationEffect(.degrees(rotation), anchor: .bottom)
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
