//
//  AquariumView.swift
//  PomodoroAquarium
//

import SwiftUI
import SwiftData
import UIKit

struct AquariumView: View {
    let player: Player?
    var backgroundTheme: AquariumBackgroundTheme = .aquarium
    var isEditing = false
    var onDecorationEditingChanged: (Bool) -> Void = { _ in }
    var decorationRestoreRequestID: String?
    var onDecorationRestoreRequestHandled: () -> Void = {}

    @Environment(\.modelContext) private var modelContext
    @Query private var decorationPlacements: [AquariumDecorationPlacement]
    @State private var editingDecorationID: String?
    @State private var originalPosition: CGPoint?
    @State private var previewPosition: CGPoint?

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
                AquariumBackground(theme: backgroundTheme)
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
        .onAppear {
            _ = try? AquariumDecorationService.createDefaultsIfNeeded(in: modelContext)
        }
        .onChange(of: isEditing) { _, newValue in
            if !newValue {
                cancelDecorationEditing()
            }
        }
        .onChange(of: decorationRestoreRequestID) { _, decorationID in
            guard let decorationID,
                  let placement = decorationPlacements.first(where: {
                      $0.decorationID == decorationID && !$0.isPlaced
                  }) else { return }
            beginEditing(placement, at: placement.kind.restorationPosition)
            onDecorationRestoreRequestHandled()
        }
    }

    // AquariumDecorationを画面上の座標へ変換して描画する装飾レイヤー。
    private func decorationLayer(in size: CGSize) -> some View {
        ZStack {
            ForEach(decorationPlacements.filter {
                $0.isPlaced || $0.decorationID == editingDecorationID
            }) { placement in
                EditableAquariumDecorationView(
                    placement: placement,
                    aquariumSize: size,
                    isEditing: isEditing,
                    isSelected: editingDecorationID == placement.decorationID,
                    position: position(for: placement),
                    select: { beginEditing(placement) },
                    updatePreview: { previewPosition = $0 },
                    cancel: cancelDecorationEditing,
                    store: { storeDecoration(placement) },
                    confirm: { confirmDecoration(placement) }
                )
            }
        }
        .allowsHitTesting(isEditing)
    }

    private func position(for placement: AquariumDecorationPlacement) -> CGPoint {
        if editingDecorationID == placement.decorationID, let previewPosition {
            return previewPosition
        }
        return CGPoint(x: placement.relativeX, y: placement.relativeY)
    }

    private func beginEditing(_ placement: AquariumDecorationPlacement) {
        beginEditing(
            placement,
            at: CGPoint(x: placement.relativeX, y: placement.relativeY)
        )
    }

    private func beginEditing(
        _ placement: AquariumDecorationPlacement,
        at initialPreviewPosition: CGPoint
    ) {
        guard isEditing else { return }
        let position = CGPoint(x: placement.relativeX, y: placement.relativeY)
        let wasEditing = editingDecorationID != nil
        editingDecorationID = placement.decorationID
        originalPosition = position
        previewPosition = initialPreviewPosition
        if !wasEditing {
            onDecorationEditingChanged(true)
        }
    }

    private func cancelDecorationEditing() {
        guard editingDecorationID != nil else { return }
        previewPosition = originalPosition
        finishDecorationEditing()
    }

    private func storeDecoration(_ placement: AquariumDecorationPlacement) {
        try? AquariumDecorationService.store(placement, in: modelContext)
        finishDecorationEditing()
    }

    private func confirmDecoration(_ placement: AquariumDecorationPlacement) {
        guard editingDecorationID == placement.decorationID, let previewPosition else { return }
        try? AquariumDecorationService.confirmPlacement(
            placement,
            at: previewPosition,
            in: modelContext
        )
        finishDecorationEditing()
    }

    private func finishDecorationEditing() {
        editingDecorationID = nil
        originalPosition = nil
        previewPosition = nil
        onDecorationEditingChanged(false)
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

private struct EditableAquariumDecorationView: View {
    let placement: AquariumDecorationPlacement
    let aquariumSize: CGSize
    let isEditing: Bool
    let isSelected: Bool
    let position: CGPoint
    let select: () -> Void
    let updatePreview: (CGPoint) -> Void
    let cancel: () -> Void
    let store: () -> Void
    let confirm: () -> Void

    @State private var dragStartPosition: CGPoint?

    private var decoration: AquariumDecoration {
        placement.decoration
    }

    private var absolutePosition: CGPoint {
        CGPoint(x: aquariumSize.width * position.x, y: aquariumSize.height * position.y)
    }

    private var controlsPosition: CGPoint {
        let offset: CGFloat = decoration.kind == .seaweed ? 92 : 70
        return CGPoint(
            x: min(max(absolutePosition.x, 105), max(105, aquariumSize.width - 105)),
            y: min(max(absolutePosition.y + offset, 44), max(44, aquariumSize.height - 44))
        )
    }

    var body: some View {
        ZStack {
            AquariumDecorationView(decoration: decoration)
                .scaleEffect(decoration.scale)
                .overlay {
                    if isEditing {
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                .white.opacity(isSelected ? 0.95 : 0.45),
                                style: StrokeStyle(lineWidth: 2, dash: isSelected ? [] : [6])
                            )
                            .padding(-8)
                    }
                }
                .position(absolutePosition)
                .onTapGesture {
                    if isEditing { select() }
                }
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            guard isEditing, isSelected else { return }
                            if dragStartPosition == nil {
                                dragStartPosition = position
                            }
                            guard let dragStartPosition else { return }
                            updatePreview(AquariumDecorationEditor.relativePosition(
                                originalX: dragStartPosition.x,
                                originalY: dragStartPosition.y,
                                translation: value.translation,
                                aquariumSize: aquariumSize,
                                kind: decoration.kind,
                                isEditing: true
                            ))
                        }
                        .onEnded { _ in
                            dragStartPosition = nil
                        }
                )

            if isSelected {
                DecorationEditingControls(cancel: cancel, store: store, confirm: confirm)
                    .position(controlsPosition)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: aquariumSize.width, height: aquariumSize.height)
        .accessibilityLabel(isSelected ? "編集中の水槽装飾" : "水槽装飾")
    }
}

private struct DecorationEditingControls: View {
    let cancel: () -> Void
    let store: () -> Void
    let confirm: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            controlButton(title: "キャンセル", systemImage: "xmark", action: cancel)
            controlButton(title: "収納", systemImage: "shippingbox.fill", action: store)
            controlButton(title: "確定", systemImage: "checkmark", action: confirm)
        }
        .padding(8)
        .background(.black.opacity(0.42), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.35)))
    }

    private func controlButton(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: systemImage)
                    .font(.headline)
                Text(title)
                    .font(.system(size: 9, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(width: 50, height: 40)
            .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

struct AquariumDecorationView: View {
    let decoration: AquariumDecoration

    @ViewBuilder
    var body: some View {
        if let imageName = decoration.kind.assetImageName,
           let image = UIImage(named: imageName) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
        } else {
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
        .modelContainer(for: AquariumDecorationPlacement.self, inMemory: true)
}
