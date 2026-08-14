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
            .aquariumGlass(cornerRadius: 20)
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
