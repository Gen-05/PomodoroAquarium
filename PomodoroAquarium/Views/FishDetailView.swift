//
//  FishDetailView.swift
//  PomodoroAquarium
//

import SwiftUI

enum FishDetailImageLayout {
    static let cardHeight: CGFloat = 240
    static let cardContentInset: CGFloat = 24
    static let minimumPreferredSize: CGFloat = 80
    static let maximumPreferredSize: CGFloat = 300
    static let maximumVisibleContentRatio: CGFloat = 0.92

    static func availableSize(in cardSize: CGSize) -> CGSize {
        CGSize(
            width: max(cardSize.width - cardContentInset * 2, 0),
            height: max(cardSize.height - cardContentInset * 2, 0)
        )
    }

    static func preferredDisplaySize(for species: FishSpecies) -> CGFloat {
        let minimumScale = FishSpecies.clownfish.displayScale.squareRoot()
        let maximumScale = FishSpecies.whaleShark.displayScale.squareRoot()
        let speciesScale = species.displayScale.squareRoot()
        let normalizedScale = min(
            max((speciesScale - minimumScale) / (maximumScale - minimumScale), 0),
            1
        )
        return minimumPreferredSize
            + normalizedScale * (maximumPreferredSize - minimumPreferredSize)
    }

    static func displaySize(for species: FishSpecies, availableSize: CGSize) -> CGFloat {
        let visibleRatio = visibleContentRatio(for: species)
        let maximumWidth = availableSize.width
            * maximumVisibleContentRatio / max(visibleRatio.width, 0.01)
        let maximumHeight = availableSize.height
            * maximumVisibleContentRatio / max(visibleRatio.height, 0.01)
        return min(preferredDisplaySize(for: species), maximumWidth, maximumHeight)
    }

    /// neutral Assetのcanvasに対する可視魚体のおおよその占有率。
    /// 透明余白だけを考慮し、displayScaleによる体格差はpreferredDisplaySizeで扱う。
    static func visibleContentRatio(for species: FishSpecies) -> CGSize {
        switch species {
        case .clownfish:
            CGSize(width: 1.00, height: 0.63)
        case .jellyfish:
            CGSize(width: 0.81, height: 0.73)
        case .pufferfish:
            CGSize(width: 0.81, height: 0.29)
        case .seahorse:
            CGSize(width: 0.40, height: 0.70)
        case .manta:
            CGSize(width: 0.92, height: 0.49)
        case .whaleShark:
            CGSize(width: 0.95, height: 0.28)
        }
    }
}

struct FishDetailStrokeAnimationState {
    let frameCount: Int
    let frameDuration: TimeInterval

    private(set) var currentStepIndex: Int?

    init(frameCount: Int, frameDuration: TimeInterval) {
        self.frameCount = max(frameCount, 0)
        self.frameDuration = max(frameDuration, 0.01)
    }

    init(species: FishSpecies) {
        self.init(
            frameCount: species.swimmingImageNames.count,
            frameDuration: Self.frameDuration(for: species)
        )
    }

    var isAnimating: Bool {
        currentStepIndex != nil
    }

    var currentFrameIndex: Int? {
        guard let currentStepIndex else { return nil }
        return Self.oneStrokeFrameIndices(frameCount: frameCount)[currentStepIndex]
    }

    @discardableResult
    mutating func start() -> Bool {
        guard frameCount > 1, !isAnimating else { return false }
        currentStepIndex = 0
        return true
    }

    /// 次のフレームへ進み、1ストローク完了時はneutral静止表示へ戻す。
    @discardableResult
    mutating func advance() -> Bool {
        guard let currentStepIndex else { return false }
        let nextStepIndex = currentStepIndex + 1
        guard nextStepIndex < Self.oneStrokeFrameIndices(frameCount: frameCount).count else {
            reset()
            return false
        }
        self.currentStepIndex = nextStepIndex
        return true
    }

    mutating func reset() {
        currentStepIndex = nil
    }

    static func oneStrokeFrameIndices(frameCount: Int) -> [Int] {
        guard frameCount > 0 else { return [] }
        guard frameCount > 1 else { return [0] }
        let finalStep = (frameCount - 1) * 2
        return (0...finalStep).map { step in
            FishSpriteAnimation.pingPongFrameIndex(
                frameCount: frameCount,
                elapsedTime: TimeInterval(step),
                frameDuration: 1
            )
        }
    }

    /// 詳細画面にはMovement状態がないため、既存の魚種別cruisingテンポを使う。
    static func frameDuration(for species: FishSpecies) -> TimeInterval {
        AquariumFishMotion.spriteFrameDuration(
            for: species,
            behavior: .cruising,
            currentSpeed: 1,
            baseSpeed: 1
        )
    }
}

struct FishDetailView: View {
    let species: FishSpecies
    let player: Player?

    @State private var strokeAnimation: FishDetailStrokeAnimationState
    @State private var strokeTask: Task<Void, Never>?

    init(species: FishSpecies, player: Player?) {
        self.species = species
        self.player = player
        self._strokeAnimation = State(
            initialValue: FishDetailStrokeAnimationState(species: species)
        )
    }

    private var ownedCount: Int {
        BookView.ownedCount(for: species, in: player)
    }

    private var isFavorite: Bool {
        player?.favoriteFish?.species == species
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                GeometryReader { geometry in
                    let availableSize = FishDetailImageLayout.availableSize(in: geometry.size)
                    let imageSize = FishDetailImageLayout.displaySize(
                        for: species,
                        availableSize: availableSize
                    )

                    FishImageView(
                        species: species,
                        fixedAnimationFrameIndex: strokeAnimation.currentFrameIndex
                    )
                        .frame(width: imageSize, height: imageSize)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                    .frame(maxWidth: .infinity)
                    .frame(height: FishDetailImageLayout.cardHeight)
                    .background(Color.cyan.opacity(0.12), in: RoundedRectangle(cornerRadius: 24))
                    .clipped()
                    .contentShape(Rectangle())
                    .onTapGesture(perform: playOneStroke)
                    .accessibilityHint("タップすると魚が一度動きます")

                VStack(spacing: 16) {
                    detailRow(title: "魚の名前", value: species.name)
                    Divider()
                    detailRow(title: "レアリティ", value: species.rarity.rawValue)
                    Divider()
                    detailRow(title: "所持数", value: "\(ownedCount)匹")
                }
                .padding(20)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))

                if isFavorite {
                    Label("現在の水槽表示魚", systemImage: "star.fill")
                        .font(.headline)
                        .foregroundStyle(.yellow)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Color.yellow.opacity(0.12), in: Capsule())
                } else {
                    Button {
                        if let player {
                            BookView.setFavorite(species, for: player)
                        }
                    } label: {
                        Label("お気に入りに設定", systemImage: "star")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(player == nil || ownedCount == 0)
                }
            }
            .padding()
        }
        .navigationTitle(species.name)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear(perform: stopStrokeAnimation)
    }

    private func playOneStroke() {
        guard strokeAnimation.start() else { return }
        let frameDuration = strokeAnimation.frameDuration

        strokeTask = Task { @MainActor in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(frameDuration))
                } catch {
                    break
                }

                guard strokeAnimation.advance() else {
                    strokeTask = nil
                    return
                }
            }

            strokeAnimation.reset()
            strokeTask = nil
        }
    }

    private func stopStrokeAnimation() {
        strokeTask?.cancel()
        strokeTask = nil
        strokeAnimation.reset()
    }

    private func detailRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
    }
}

#Preview {
    NavigationStack {
        FishDetailView(species: .clownfish, player: nil)
    }
}
