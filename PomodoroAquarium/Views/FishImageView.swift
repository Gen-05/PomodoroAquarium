import SwiftUI
import UIKit

enum FishSpriteAnimation {
    static func pingPongFrameIndex(
        frameCount: Int,
        elapsedTime: TimeInterval,
        frameDuration: TimeInterval,
        phase: TimeInterval = 0
    ) -> Int {
        guard frameCount > 1 else { return 0 }
        let safeDuration = max(frameDuration, 0.01)
        let cycleLength = (frameCount - 1) * 2
        let step = Int(floor(max(elapsedTime + phase, 0) / safeDuration)) % cycleLength
        return step < frameCount ? step : cycleLength - step
    }
}

@MainActor
private enum FishSpriteAssetCache {
    private struct Key: Hashable {
        let species: FishSpecies
        let pose: FishSpritePose
    }

    private static var cachedFrames: [Key: [UIImage]] = [:]

    static func frames(for species: FishSpecies, pose: FishSpritePose) -> [UIImage] {
        let key = Key(species: species, pose: pose)
        if let cached = cachedFrames[key] {
            return cached
        }
        let imageNames = species.swimmingImageNames(for: pose)
        let loadedFrames = imageNames.compactMap(UIImage.init(named:))
        // 途中フレームが欠けている場合は不完全なループを再生せず、基準画像へfallbackする。
        let frames = loadedFrames.count == imageNames.count ? loadedFrames : []
        cachedFrames[key] = frames
        return frames
    }
}

/// 魚の正式アセットと未対応時のフォールバックを一元管理する表示View。
/// 正式なside画像は右向きを基準とする。
struct FishImageView: View {
    let species: FishSpecies
    var fallbackSystemName = "fish"
    var fallbackColor: Color = .blue
    var facingDirection: FishFacingDirection = .right
    var spritePose: FishSpritePose?
    var facingHorizontalScale: CGFloat = 1
    var animationTime: TimeInterval?
    var animationFrameDuration: TimeInterval = 0.18
    var animationPhase: TimeInterval = 0

    var body: some View {
        Group {
            if let spriteImage {
                Image(uiImage: spriteImage)
                    .resizable()
                    .scaledToFit()
            } else if let imageName = species.imageName,
               let image = UIImage(named: imageName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: fallbackSystemName)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(fallbackColor)
            }
        }
        .aspectRatio(contentMode: .fit)
        .scaleEffect(x: resolvedHorizontalScale, y: 1)
        .accessibilityLabel(species.name)
    }

    private var resolvedHorizontalScale: CGFloat {
        guard species.usesDirectionalSwimmingSprites else { return 1 }
        switch spritePose {
        case .sideToDiagonalUp15(let isLeftFacing),
             .sideToDiagonalDown15(let isLeftFacing):
            return isLeftFacing ? -abs(facingHorizontalScale) : abs(facingHorizontalScale)
        case .facing, nil:
            return facingHorizontalScale
        }
    }

    private var spriteImage: UIImage? {
        guard let animationTime else { return nil }
        let directionalFrames = FishSpriteAssetCache.frames(
            for: species,
            pose: spritePose ?? .facing(facingDirection)
        )
        let sideFrames = FishSpriteAssetCache.frames(for: species, pose: .facing(.right))
        let frames = directionalFrames.isEmpty ? sideFrames : directionalFrames
        guard !frames.isEmpty else { return nil }
        guard frames.count > 1 else { return frames[0] }
        let index = FishSpriteAnimation.pingPongFrameIndex(
            frameCount: frames.count,
            elapsedTime: animationTime,
            frameDuration: animationFrameDuration,
            phase: animationPhase
        )
        return frames[index]
    }
}
