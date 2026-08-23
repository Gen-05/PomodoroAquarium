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
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
            ZStack {
                ForEach(displayedFish) { playerFish in
                    let isFavorite = playerFish.id == favoriteFish?.id

                    SwimmingFishView(
                        fishID: playerFish.id,
                        species: playerFish.species,
                        isFavorite: isFavorite,
                        aquariumSize: size,
                        updateDate: timeline.date
                    )
                }
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
    let fishID: UUID
    let species: FishSpecies
    let isFavorite: Bool
    let aquariumSize: CGSize
    let updateDate: Date

    @State private var motion: AquariumFishMotion.State
    @State private var lastUpdateDate: Date?
    @State private var elapsedTime: TimeInterval = 0

    init(
        fishID: UUID,
        species: FishSpecies,
        isFavorite: Bool,
        aquariumSize: CGSize,
        updateDate: Date
    ) {
        self.fishID = fishID
        self.species = species
        self.isFavorite = isFavorite
        self.aquariumSize = aquariumSize
        self.updateDate = updateDate

        self._motion = State(initialValue: AquariumFishMotion.initialState(for: fishID))
    }

    var body: some View {
        fishImage
            // 分離された尾びれ素材がないため、1枚絵へ速度連動の微細な変形を加える。
            .rotationEffect(.degrees(swimRotation))
            .scaleEffect(
                x: motion.facingSign * motion.facingWidth,
                y: swimVerticalScale
            )
            .offset(y: swimVerticalOffset)
            .position(
                x: aquariumSize.width * motion.position.x,
                y: aquariumSize.height * motion.position.y
            )
            .onChange(of: updateDate) { _, newDate in
                updateMotion(at: newDate)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(isFavorite ? "お気に入りの\(species.name)" : species.name)
    }

    private func updateMotion(at date: Date) {
        guard let lastUpdateDate else {
            self.lastUpdateDate = date
            return
        }
        let deltaTime = date.timeIntervalSince(lastUpdateDate)
        self.lastUpdateDate = date
        elapsedTime += min(max(deltaTime, 0), AquariumFishMotion.maximumDeltaTime)
        motion.advance(deltaTime: deltaTime, elapsedTime: elapsedTime)
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

    private var swimIntensity: CGFloat {
        min(max(motion.currentSpeed / max(motion.baseSpeed, 0.001), 0.15), 2.4)
    }

    private var swimRotation: Double {
        Double(sin(motion.swimPhase) * min(0.8 + swimIntensity * 0.45, 1.8))
    }

    private var swimVerticalScale: CGFloat {
        1 + cos(motion.swimPhase * 1.07) * min(0.008 + swimIntensity * 0.005, 0.02)
    }

    private var swimVerticalOffset: CGFloat {
        sin(motion.swimPhase * 0.53) * min(0.7 + swimIntensity * 0.45, 1.8)
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
