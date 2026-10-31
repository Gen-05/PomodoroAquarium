import SwiftUI

#if DEBUG
private enum FishRewardLayoutDebug {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-reward-layout-debug")
    }
}

private struct FishRewardFramePreference: PreferenceKey {
    static let defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, next in next })
    }
}
#endif

private extension View {
    @ViewBuilder
    func rewardLayoutProbe(_ name: String) -> some View {
#if DEBUG
        if FishRewardLayoutDebug.isEnabled {
            background {
                GeometryReader { geometry in
                    Color.clear.preference(
                        key: FishRewardFramePreference.self,
                        value: [name: geometry.frame(in: .global)]
                    )
                }
            }
        } else {
            self
        }
#else
        self
#endif
    }
}

enum FishRewardInformationStep: Int, CaseIterable {
    case rarity, newBadge, name, detail, action
}

enum FishRewardPresentationPhase: Equatable {
    case silhouette
    case approaching
    case reveal
    case result
}

struct FishRewardPresentationState: Equatable {
    private(set) var phase: FishRewardPresentationPhase = .silhouette
    private(set) var informationStep: FishRewardInformationStep?

    func shows(_ step: FishRewardInformationStep) -> Bool {
        guard let informationStep else { return false }
        return informationStep.rawValue >= step.rawValue
    }

    mutating func showInformation(_ step: FishRewardInformationStep) {
        guard phase == .reveal, !shows(step) else { return }
        informationStep = step
    }

    var showsSilhouette: Bool { phase == .silhouette || phase == .approaching }
    var showsTapPrompt: Bool { phase == .silhouette }
    var showsRarityAppearance: Bool { phase == .reveal || phase == .result }
    var showsResultInformation: Bool { phase == .result }

    @discardableResult
    mutating func beginApproach() -> Bool {
        guard phase == .silhouette else { return false }
        phase = .approaching
        return true
    }

    @discardableResult
    mutating func beginReveal() -> Bool {
        guard phase == .approaching else { return false }
        phase = .reveal
        return true
    }

    mutating func finishReveal() {
        guard phase == .reveal else { return }
        informationStep = .action
        phase = .result
    }
}

enum FishRewardPresentationTiming {
    static let approachDuration: TimeInterval = 3.0
    static let reducedMotionApproachDuration: TimeInterval = 0.18
    static let silhouetteDissolveDuration: TimeInterval = 0.25
    static let revealDuration: TimeInterval = 0.45
    static let reducedMotionRevealDuration: TimeInterval = 0.18
    static let rewardStrokeDuration: TimeInterval = 3.0
    static let fishAppearanceDuration: TimeInterval = 0.35
    static let informationInterval: TimeInterval = 0.30
    static let informationFadeDuration: TimeInterval = 0.25

    static func informationSteps(isNewFish: Bool) -> [FishRewardInformationStep] {
        isNewFish ? [.rarity, .newBadge, .name, .detail, .action]
            : [.rarity, .name, .detail, .action]
    }

    static func revealHoldDuration(for rarity: FishRarity) -> TimeInterval {
        switch rarity {
        case .common: 0.5
        case .rare: 0.6
        case .epic: 0.9
        case .legendary: 1.2
        }
    }

    static func rewardFrameDuration(frameCount: Int) -> TimeInterval {
        let stepCount = FishDetailStrokeAnimationState.oneStrokeFrameIndices(
            frameCount: frameCount
        ).count
        guard stepCount > 1 else { return rewardStrokeDuration }
        return rewardStrokeDuration / Double(stepCount)
    }

    static func rewardFrameDuration(for species: FishSpecies) -> TimeInterval {
        if species == .orca { return AquariumOrcaSwimming.frameDuration }
        if species == .whaleShark { return AquariumFishMotion.whaleSharkSpriteFrameDuration }
        return rewardFrameDuration(frameCount: species.swimmingImageNames.count)
    }

    static func oneStrokeDuration(frameCount: Int) -> TimeInterval {
        let stepCount = FishDetailStrokeAnimationState.oneStrokeFrameIndices(
            frameCount: frameCount
        ).count
        guard stepCount > 1 else { return 0 }
        return Double(stepCount) * rewardFrameDuration(frameCount: frameCount)
    }

    static func oneStrokeDuration(for species: FishSpecies) -> TimeInterval {
        if species == .whaleShark || species == .orca {
            return Double(species.swimmingImageNames.count) * rewardFrameDuration(for: species)
        }
        return oneStrokeDuration(frameCount: species.swimmingImageNames.count)
    }
}

enum FishRewardGenericSilhouette {
    static let systemImageName = "fish.fill"
    static let width: CGFloat = 190
    static let height: CGFloat = 120
}

enum FishRewardImageLayout {
    static let displayScale: CGFloat = 0.88
    static let maximumDisplaySize: CGFloat = 264
    static let maximumStageWidth: CGFloat = 340
    static let stageHeight: CGFloat = 270

    /// 1匹演出とPreviewまとめで同じ基準frameを使う。サイズの計算式は従来どおり。
    static func detailDisplaySize(for species: FishSpecies, stageSize: CGSize) -> CGFloat {
        FishDetailImageLayout.displaySize(
            for: species,
            availableSize: CGSize(width: min(stageSize.width, maximumStageWidth), height: stageSize.height)
        )
    }

    static func displaySize(from detailDisplaySize: CGFloat) -> CGFloat {
        min(
            max(
                detailDisplaySize * displayScale,
                FishDetailImageLayout.minimumPreferredSize
            ),
            maximumDisplaySize
        )
    }
}

struct FishRewardGlowStyle: Equatable {
    let sizeMultiplier: CGFloat
    let restingOpacity: Double
    let revealOpacity: Double
    let blurRadius: CGFloat
    let particleCount: Int
    let particleRestingOpacity: Double
    let usesSparkles: Bool
    let pulseScale: CGFloat
    let pulseOpacity: Double
    let pulseDuration: TimeInterval
    let rotationDuration: TimeInterval
    let ringOpacity: Double
    let fishAuraScale: CGFloat
    let fishAuraPulseScale: CGFloat
    let fishAuraOpacity: Double
    let fishAuraPulseOpacity: Double
    let fishAuraBlurRadius: CGFloat

    static func style(for rarity: FishRarity) -> FishRewardGlowStyle {
        switch rarity {
        case .common:
            FishRewardGlowStyle(
                sizeMultiplier: 1.6,
                restingOpacity: 0.40,
                revealOpacity: 0.64,
                blurRadius: 14,
                particleCount: 4,
                particleRestingOpacity: 0.24,
                usesSparkles: false,
                pulseScale: 1.025,
                pulseOpacity: 0.46,
                pulseDuration: 2.8,
                rotationDuration: 0,
                ringOpacity: 0.13,
                fishAuraScale: 1.04,
                fishAuraPulseScale: 1.065,
                fishAuraOpacity: 0.18,
                fishAuraPulseOpacity: 0.24,
                fishAuraBlurRadius: 8
            )
        case .rare:
            FishRewardGlowStyle(
                sizeMultiplier: 2.0,
                restingOpacity: 0.48,
                revealOpacity: 0.78,
                blurRadius: 18,
                particleCount: 0,
                particleRestingOpacity: 0,
                usesSparkles: false,
                pulseScale: 1.045,
                pulseOpacity: 0.57,
                pulseDuration: 2.5,
                rotationDuration: 18,
                ringOpacity: 0.14,
                fishAuraScale: 1.05,
                fishAuraPulseScale: 1.085,
                fishAuraOpacity: 0.28,
                fishAuraPulseOpacity: 0.37,
                fishAuraBlurRadius: 10
            )
        case .epic:
            FishRewardGlowStyle(
                sizeMultiplier: 2.5,
                restingOpacity: 0.56,
                revealOpacity: 0.88,
                blurRadius: 22,
                particleCount: 12,
                particleRestingOpacity: 0.40,
                usesSparkles: false,
                pulseScale: 1.065,
                pulseOpacity: 0.68,
                pulseDuration: 2.2,
                rotationDuration: 13,
                ringOpacity: 0.22,
                fishAuraScale: 1.06,
                fishAuraPulseScale: 1.105,
                fishAuraOpacity: 0.38,
                fishAuraPulseOpacity: 0.50,
                fishAuraBlurRadius: 12
            )
        case .legendary:
            FishRewardGlowStyle(
                sizeMultiplier: 2.9,
                restingOpacity: 0.64,
                revealOpacity: 0.98,
                blurRadius: 26,
                particleCount: 16,
                particleRestingOpacity: 0.52,
                usesSparkles: true,
                pulseScale: 1.085,
                pulseOpacity: 0.78,
                pulseDuration: 2.0,
                rotationDuration: 9,
                ringOpacity: 0.30,
                fishAuraScale: 1.07,
                fishAuraPulseScale: 1.125,
                fishAuraOpacity: 0.48,
                fishAuraPulseOpacity: 0.62,
                fishAuraBlurRadius: 14
            )
        }
    }
}

enum FishRewardMysteryAppearance {
    static let backgroundImageName = "reward_mystery_cave"
    static let backgroundDimmingOpacity = 0.08
    static let approachScale: CGFloat = 1.30
    static let approachAnchor = UnitPoint(x: 0.55, y: 0.45)
    static let backgroundColors: [Color] = [
        Color(red: 0.01, green: 0.035, blue: 0.075),
        Color(red: 0.025, green: 0.105, blue: 0.16),
        Color(red: 0.005, green: 0.025, blue: 0.06)
    ]
    static let glowColor = Color(red: 0.54, green: 0.82, blue: 0.88)
}

enum FishRewardSceneAppearance {
    static func color(for rarity: FishRarity) -> Color {
        rarity == .common ? Color(red: 0.76, green: 0.91, blue: 1) : rarity.rewardColor
    }

    static func backgroundImageName(for rarity: FishRarity) -> String {
        switch rarity {
        case .common: "reward_result_common"
        case .rare: "reward_result_rare"
        case .epic: "reward_result_epic"
        case .legendary: "reward_result_legendary"
        }
    }
}

private extension View {
    // A thin dark edge keeps small bright text readable without a heavy glow.
    func rewardTextEdge() -> some View {
        self.shadow(color: .black.opacity(0.75), radius: 0, x: -0.5)
            .shadow(color: .black.opacity(0.75), radius: 0, x: 0.5)
            .shadow(color: .black.opacity(0.75), radius: 0, y: -0.5)
            .shadow(color: .black.opacity(0.75), radius: 0, y: 0.5)
    }

    func rewardInformationVisibility(_ visible: Bool) -> some View {
        opacity(visible ? 1 : 0)
            .allowsHitTesting(visible)
            .accessibilityHidden(!visible)
    }
}

enum FishRewardParticleLayout {
    static let normalizedOffsets: [CGSize] = [
        CGSize(width: -0.46, height: -0.08),
        CGSize(width: -0.38, height: -0.32),
        CGSize(width: -0.24, height: -0.46),
        CGSize(width: -0.03, height: -0.52),
        CGSize(width: 0.19, height: -0.46),
        CGSize(width: 0.37, height: -0.31),
        CGSize(width: 0.47, height: -0.07),
        CGSize(width: 0.42, height: 0.22),
        CGSize(width: 0.28, height: 0.42),
        CGSize(width: 0.06, height: 0.50),
        CGSize(width: -0.17, height: 0.46),
        CGSize(width: -0.36, height: 0.31),
        CGSize(width: -0.18, height: -0.20),
        CGSize(width: 0.16, height: -0.23),
        CGSize(width: 0.22, height: 0.18),
        CGSize(width: -0.21, height: 0.18)
    ]
}

enum FishRarityRewardColorRole: Equatable {
    case gray
    case lime
    case purple
    case gold
}

extension FishRarity {
    var rewardColorRole: FishRarityRewardColorRole {
        switch self {
        case .common: .gray
        case .rare: .lime
        case .epic: .purple
        case .legendary: .gold
        }
    }

    var rewardColor: Color {
        switch rewardColorRole {
        case .gray:
            .gray
        case .lime:
            Color(red: 0.58, green: 0.84, blue: 0.20)
        case .purple:
            .purple
        case .gold:
            Color(red: 1.00, green: 0.77, blue: 0.12)
        }
    }

    var rewardBackgroundColors: [Color] {
        switch rewardColorRole {
        case .gray:
            [
                Color(red: 0.12, green: 0.18, blue: 0.25),
                Color(red: 0.31, green: 0.37, blue: 0.43),
                Color(red: 0.08, green: 0.14, blue: 0.21)
            ]
        case .lime:
            [
                Color(red: 0.07, green: 0.20, blue: 0.15),
                Color(red: 0.34, green: 0.48, blue: 0.13),
                Color(red: 0.05, green: 0.15, blue: 0.17)
            ]
        case .purple:
            [
                Color(red: 0.14, green: 0.08, blue: 0.28),
                Color(red: 0.42, green: 0.18, blue: 0.56),
                Color(red: 0.08, green: 0.10, blue: 0.25)
            ]
        case .gold:
            [
                Color(red: 0.24, green: 0.16, blue: 0.03),
                Color(red: 0.60, green: 0.42, blue: 0.07),
                Color(red: 0.15, green: 0.12, blue: 0.05)
            ]
        }
    }
}

struct FishRewardRevealFlashStyle: Equatable {
    let rayAngles: [Double]
    let sizeMultiplier: CGFloat
    let rayWidth: CGFloat
    let peakOpacity: Double
    let sparkleCount: Int

    static func style(for rarity: FishRarity) -> Self {
        switch rarity {
        case .common:
            Self(rayAngles: [], sizeMultiplier: 0.68, rayWidth: 0,
                 peakOpacity: 0.50, sparkleCount: 0)
        case .rare:
            Self(rayAngles: [], sizeMultiplier: 0.82, rayWidth: 0,
                 peakOpacity: 0.65, sparkleCount: 0)
        case .epic:
            Self(
                rayAngles: [-156, -116, -48, -12, 38, 104],
                sizeMultiplier: 1.02,
                rayWidth: 7,
                peakOpacity: 0.86,
                sparkleCount: 5
            )
        case .legendary:
            Self(
                rayAngles: [-164, -136, -104, -76, -42, -8, 24, 56, 92, 144],
                sizeMultiplier: 1.20,
                rayWidth: 10,
                peakOpacity: 1.0,
                sparkleCount: 10
            )
        }
    }
}

private struct FishRewardRevealFlash: View {
    let style: FishRewardRevealFlashStyle
    let color: Color
    let holdDuration: TimeInterval

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var flashOpacity = 0.0
    @State private var flashScale: CGFloat = 0.35

    var body: some View {
        GeometryReader { geometry in
            let diameter = min(geometry.size.width * style.sizeMultiplier, 440)
            let rayLength = diameter * 0.46
            ZStack {
                RadialGradient(
                    colors: [.white.opacity(0.94), color.opacity(0.95),
                             color.opacity(0.42), .clear],
                    center: .center, startRadius: 2, endRadius: diameter / 2
                )
                .frame(width: diameter, height: diameter)
                .blur(radius: 5)

                ForEach(style.rayAngles.indices, id: \.self) { index in
                    let length = rayLength * (index.isMultiple(of: 2) ? 1 : 0.84)
                    Capsule()
                        .fill(LinearGradient(
                            colors: [.white.opacity(0.95), color, color.opacity(0.55), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(width: length, height: style.rayWidth)
                        .blur(radius: 1.5)
                        .offset(x: 10 + length / 2)
                        .rotationEffect(.degrees(style.rayAngles[index]))
                }

                ForEach(0..<(reduceMotion ? 0 : style.sparkleCount), id: \.self) { index in
                    Image(systemName: "sparkle")
                        .font(.system(size: CGFloat(5 + index % 4), weight: .semibold))
                        .foregroundStyle(color.opacity(0.95))
                        .shadow(color: color, radius: 4)
                        .offset(x: rayLength * (index.isMultiple(of: 2) ? 0.9 : 0.68))
                        .rotationEffect(.degrees(Double(index) * 137 - 64))
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
            .scaleEffect(reduceMotion ? 1 : flashScale)
            .opacity(flashOpacity)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task {
            withAnimation(.easeOut(duration: 0.2)) {
                flashOpacity = reduceMotion ? style.peakOpacity * 0.45 : style.peakOpacity
                flashScale = 1.05
            }
            do {
                try await Task.sleep(for: .seconds(holdDuration))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.38)) {
                flashOpacity = 0
                flashScale = 1.14
            }
        }
    }
}

struct FishRewardNewBadge: View {
    let glowColor: Color
    @ScaledMetric(relativeTo: .subheadline) private var fontSize: CGFloat = 21

    var body: some View {
        Text("NEW!")
            .font(.system(size: fontSize, weight: .heavy))
            .tracking(1.1)
            .foregroundStyle(.white)
            .rewardTextEdge()
            .shadow(color: glowColor.opacity(0.3), radius: 3)
            .accessibilityIdentifier("fishReward.newBadge")
    }
}

struct FishRewardView: View {
    let result: FishAcquisitionResult
    private static let rarityLabelHeight: CGFloat = 42

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var presentation = FishRewardPresentationState()
    @State private var strokeAnimation: FishDetailStrokeAnimationState
    @State private var strokeTask: Task<Void, Never>?
    @State private var revealTask: Task<Void, Never>?
    @State private var silhouettePulse = false
    @State private var caveScale: CGFloat = 1
    @State private var silhouetteOpacity = 1.0
    @State private var glowScale: CGFloat = 0.25
    @State private var glowOpacity = 0.0
    @State private var rewardGlowScale: CGFloat = 0.5
    @State private var rewardGlowOpacity = 0.0
    @State private var rewardGlowRotation = 0.0
    @State private var particleExpansion: CGFloat = 0.35
    @State private var particleOpacity = 0.0
    @State private var fishAuraScale: CGFloat = 0.86
    @State private var fishAuraOpacity = 0.0
    @State private var hasFishAppeared = false
    @State private var hasInformationFinished = false
    @State private var isSequencePresentationFinished = false
    private var sequence: FishRewardSequenceHooks?
#if DEBUG
    @State private var debugFrames: [String: CGRect] = [:]
#endif

    init(result: FishAcquisitionResult) {
        self.result = result
        self._strokeAnimation = State(
            initialValue: FishDetailStrokeAnimationState(species: result.species)
        )
    }

    init(result: FishAcquisitionResult, sequence: FishRewardSequenceHooks) {
        self.init(result: result)
        self.sequence = sequence
    }

    private var species: FishSpecies { result.species }
    private var rarityColor: Color { FishRewardSceneAppearance.color(for: result.rarity) }
    private var glowStyle: FishRewardGlowStyle {
        FishRewardGlowStyle.style(for: result.rarity)
    }
    private var ambientGlowColor: Color {
        presentation.showsRarityAppearance
            ? rarityColor
            : FishRewardMysteryAppearance.glowColor
    }

    var body: some View {
        ZStack {
            rewardBackground

            RadialGradient(
                colors: [ambientGlowColor.opacity(0.22), .clear],
                center: .center,
                startRadius: 30,
                endRadius: 310
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [rarityColor.opacity(0.34), .clear],
                center: .center,
                startRadius: 8,
                endRadius: 260
            )
            .scaleEffect(glowScale)
            .opacity(glowOpacity)
            .ignoresSafeArea()

            ZStack {
                fishStage
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .top) {
                resultRarityLabel
                    .frame(height: Self.rarityLabelHeight)
            }
            .overlay {
                GeometryReader { geometry in
                    if result.showsNewBadge {
                        let rarityCenterY = Self.rarityLabelHeight / 2
                        let fishCenterY = geometry.size.height / 2
                        FishRewardNewBadge(glowColor: rarityColor)
                            // Restore the upper position with 4pt more breathing room above the fish.
                            .position(
                                x: geometry.size.width / 2,
                                y: fishCenterY - (fishCenterY - rarityCenterY) * 0.18 - 4
                            )
                            .rewardInformationVisibility(presentation.shows(.newBadge))
                    }
                }
                .allowsHitTesting(false)
            }
            .overlay(alignment: .center) {
                rewardMessage
                    .frame(height: 72)
                    .offset(y: 185)
            }
            .overlay(alignment: .bottom) {
                resultAction
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .rewardLayoutProbe("screen")
        .task {
            if sequence?.startsAutomatically == true { revealFish() }
        }
#if DEBUG
        .onPreferenceChange(FishRewardFramePreference.self) { frames in
            if frames != debugFrames { debugFrames = frames }
        }
        .overlay(alignment: .topLeading) {
            if FishRewardLayoutDebug.isEnabled {
                debugLayoutOverlay
            }
        }
#endif
        .contentShape(Rectangle())
        .onTapGesture(perform: handleFishTap)
        .accessibilityAction(named: Text("魚を確認")) {
            handleFishTap()
        }
        .presentationBackground(Color.black)
        .interactiveDismissDisabled(!presentation.showsResultInformation)
        .onAppear(perform: startSilhouettePulse)
        .onDisappear(perform: stopAnimations)
    }

    private var rewardBackground: some View {
        ZStack {
            // Only the selected rarity image sits behind the fading cave layer.
            GeometryReader { geometry in
                Image(FishRewardSceneAppearance.backgroundImageName(for: result.rarity))
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
            }

            // The image and its ambience share the approach transform, independently of the UI.
            GeometryReader { geometry in
                ZStack {
                    Image(FishRewardMysteryAppearance.backgroundImageName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .overlay(Color.black.opacity(FishRewardMysteryAppearance.backgroundDimmingOpacity))

                    if presentation.showsSilhouette {
                        FishRewardCaveAtmosphere()
                            .transition(.opacity)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .scaleEffect(caveScale, anchor: FishRewardMysteryAppearance.approachAnchor)
                .clipped()
            }
            .opacity(presentation.showsSilhouette ? 1 : 0)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .accessibilityIdentifier("fishReward.fullScreenBackground")
    }

    private var resultRarityLabel: some View {
        Text(result.rarity.rawValue.uppercased())
            .font(.headline.weight(.bold))
            .tracking(1.4)
            .foregroundStyle(rarityColor)
            .rewardTextEdge()
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(rarityColor.opacity(0.7), lineWidth: 1))
            .shadow(color: rarityColor.opacity(0.20), radius: 6)
            .accessibilityIdentifier("fishRarity")
            .rewardInformationVisibility(presentation.shows(.rarity))
    }

    @ViewBuilder
    private var resultAction: some View {
        if let sequence {
            if result.isNewFish {
                Button("タップして次へ", action: sequence.onAdvance)
                    .buttonStyle(AquariumStudyStartButtonStyle())
                    .frame(maxWidth: 260)
                    .rewardInformationVisibility(
                        presentation.shows(.action) && presentation.showsResultInformation
                    )
                    .allowsHitTesting(isSequencePresentationFinished)
                    .accessibilityHidden(!isSequencePresentationFinished)
            } else {
                Color.clear.frame(height: 50).accessibilityHidden(true)
            }
        } else {
            standardCloseAction
                .rewardInformationVisibility(presentation.shows(.action))
                .allowsHitTesting(hasInformationFinished)
                .accessibilityHidden(!hasInformationFinished)
        }
    }

    private var standardCloseAction: some View {
        Button("閉じる") { dismiss() }
            .buttonStyle(AquariumStudyStartButtonStyle())
            .frame(maxWidth: 260)
            .accessibilityIdentifier("fishReward.close")
            .transition(.opacity)
    }

    private func handleFishTap() {
        if let sequence {
            if presentation.showsTapPrompt && !sequence.startsAutomatically {
                // 連続演出の最初だけ、通常の1匹Rewardと同じtap待機を維持する。
                revealFish()
            } else if isSequencePresentationFinished && presentation.showsResultInformation && result.isNewFish {
                sequence.onAdvance()
            }
            return
        }
        revealFish()
    }

    private var fishStage: some View {
        GeometryReader { geometry in
            ZStack {
                if presentation.showsSilhouette {
                    Circle()
                        .fill(Color.cyan.opacity(0.10))
                        .frame(width: 230, height: 180)
                        .blur(radius: 18)

                    ZStack {
                        Image(systemName: FishRewardGenericSilhouette.systemImageName)
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(Color(red: 0.015, green: 0.055, blue: 0.11))
                            .shadow(color: Color.cyan.opacity(0.24), radius: 3)
                            .frame(
                                width: FishRewardGenericSilhouette.width,
                                height: FishRewardGenericSilhouette.height
                            )

                        Text("?")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.94))
                            .shadow(color: .black.opacity(0.7), radius: 3, y: 1)
                    }
                    .scaleEffect(reduceMotion ? 1 : (silhouettePulse ? 1.025 : 0.985))
                    .opacity(silhouetteOpacity)
                    .accessibilityHidden(true)
                    .accessibilityIdentifier("fishReward.genericSilhouette")
                } else {
                    let detailImageSize = FishRewardImageLayout.detailDisplaySize(
                        for: species,
                        stageSize: geometry.size
                    )
                    let imageSize = FishRewardImageLayout.displaySize(
                        from: detailImageSize
                    )
                    let maximumGlowDiameter = min(geometry.size.width * 1.22, 430)
                    let glowDiameter = min(
                        max(detailImageSize * glowStyle.sizeMultiplier, 170),
                        maximumGlowDiameter
                    )
                    ZStack {
                        rewardGlow(diameter: glowDiameter)

                        if presentation.phase == .reveal {
                            FishRewardRevealFlash(
                                style: FishRewardRevealFlashStyle.style(for: result.rarity),
                                color: rarityColor,
                                holdDuration: FishRewardPresentationTiming.revealHoldDuration(for: result.rarity)
                            )
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .transition(.identity)
                        }

                        rewardFishImage(size: imageSize)
                            .brightness(1)
                            .colorMultiply(rarityColor)
                            .blur(radius: glowStyle.fishAuraBlurRadius)
                            .scaleEffect(fishAuraScale)
                            .opacity(hasFishAppeared ? fishAuraOpacity : 0)
                            .accessibilityHidden(true)

                        rewardFishImage(size: imageSize)
                            .rewardLayoutProbe("fish")
                            .accessibilityIdentifier("fishReward.revealedFish")
                            .opacity(hasFishAppeared ? 1 : 0)
                    }
                    .rewardLayoutProbe("composite")
                }
            }
            // Glow can be wider than the proposed stage. Keep its layout frame
            // at the actual stage size so overflowing light stays centered.
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
            .rewardLayoutProbe("container")
        }
        .frame(maxWidth: .infinity)
        .frame(height: FishRewardImageLayout.stageHeight)
        .accessibilityIdentifier("fishReward.fishStage")
    }

    private func rewardFishImage(size: CGFloat) -> some View {
        FishImageView(
            species: species,
            fallbackSystemName: "fish.fill",
            fallbackColor: rarityColor,
            fixedAnimationFrameIndex: strokeAnimation.currentFrameIndex
        )
        .frame(width: size, height: size)
    }

    private func rewardGlow(diameter: CGFloat) -> some View {
        ZStack {
            RadialGradient(
                colors: [
                    Color.white.opacity(0.72),
                    rarityColor.opacity(0.72),
                    rarityColor.opacity(0.20),
                    .clear
                ],
                center: .center,
                startRadius: 4,
                endRadius: diameter * 0.5
            )
            .frame(width: diameter, height: diameter * 0.74)
            .rewardLayoutProbe("glow")
            .blur(radius: glowStyle.blurRadius)
            .scaleEffect(rewardGlowScale)
            .opacity(rewardGlowOpacity)

            Ellipse()
                .stroke(
                    AngularGradient(
                        colors: [
                            .clear,
                            rarityColor.opacity(0.85),
                            Color.white.opacity(0.72),
                            .clear,
                            rarityColor.opacity(0.62),
                            .clear
                        ],
                        center: .center
                    ),
                    lineWidth: 2
                )
                .frame(width: diameter * 0.94, height: diameter * 0.64)
                .blur(radius: 1.4)
                .scaleEffect(rewardGlowScale)
                .rotationEffect(.degrees(rewardGlowRotation))
                .opacity(glowStyle.ringOpacity * rewardGlowOpacity)

            ForEach(0..<glowStyle.particleCount, id: \.self) { index in
                let offsetIndex = index * FishRewardParticleLayout.normalizedOffsets.count / glowStyle.particleCount
                let offset = FishRewardParticleLayout.normalizedOffsets[offsetIndex]
                let symbolName = glowStyle.usesSparkles && index.isMultiple(of: 3)
                    ? "sparkle"
                    : "circle.fill"

                Image(systemName: symbolName)
                    .font(.system(size: CGFloat(3 + index % 4), weight: .semibold))
                    .foregroundStyle(rarityColor.opacity(0.9))
                    .shadow(color: rarityColor.opacity(0.8), radius: 4)
                    .offset(
                        x: offset.width * diameter * particleExpansion,
                        y: offset.height * diameter * 0.72 * particleExpansion
                    )
                    .opacity(particleOpacity)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .accessibilityIdentifier("fishReward.rarityGlow")
    }

#if DEBUG
    private var debugLayoutOverlay: some View {
        GeometryReader { geometry in
            let originX = geometry.frame(in: .global).minX
            let names = ["screen", "container", "composite", "fish", "glow"]
            ZStack(alignment: .topLeading) {
                ForEach(names, id: \.self) { name in
                    if let frame = debugFrames[name] {
                        Rectangle()
                            .fill(name == "screen" ? Color.red : Color.cyan.opacity(0.65))
                            .frame(width: 1, height: geometry.size.height)
                            .offset(x: frame.midX - originX)
                    }
                }
                Text(names.map { name in
                    let center = debugFrames[name]?.midX ?? 0
                    return "\(name)=\(String(format: "%.2f", center))"
                }.joined(separator: "\n")
                    + "\nphase=\(presentation.phase)"
                    + "\ninformation=\(presentation.informationStep.map { String(describing: $0) } ?? "hidden")")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.white)
                .padding(8)
                .background(.black.opacity(0.8))
                .accessibilityIdentifier("fishReward.debugCoordinates")
            }
        }
        .allowsHitTesting(false)
    }
#endif

    @ViewBuilder
    private var rewardMessage: some View {
        if presentation.showsSilhouette {
            Text("Tap!")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(red: 0.80, green: 0.94, blue: 1))
                .rewardTextEdge()
                .opacity(presentation.showsTapPrompt ? (reduceMotion ? 1 : (silhouettePulse ? 1 : 0.55)) : 0)
                .accessibilityHidden(!presentation.showsTapPrompt)
                .accessibilityLabel("タップして魚を確認")
                .accessibilityIdentifier("fishReward.tapPrompt")
        } else {
            // Keep every result row in the layout while fading it in independently.
            VStack(spacing: 8) {
                Text("\(result.fishName)をゲット！")
                    .font(.title.bold())
                    .foregroundStyle(.white)
                    .rewardTextEdge()
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("fishReward.getMessage")
                    .rewardInformationVisibility(presentation.shows(.name))

                Group {
                    if result.isNewFish {
                        Label("図鑑に登録されました", systemImage: "book.closed.fill")
                            .font(.subheadline.weight(.medium))
                    } else {
                        Text("所持数 \(result.previousOwnedCount)匹 → \(result.currentOwnedCount)匹")
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                            .accessibilityIdentifier("ownedCountChange")
                    }
                }
                .foregroundStyle(.white.opacity(0.95))
                .rewardTextEdge()
                .rewardInformationVisibility(presentation.shows(.detail))
            }
        }
    }

    private func startSilhouettePulse() {
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 1.15).repeatForever(autoreverses: true)) {
            silhouettePulse = true
        }
    }

    private func approachCave() async -> Bool {
        if reduceMotion {
            withAnimation(.easeOut(duration: FishRewardPresentationTiming.reducedMotionApproachDuration)) {
                silhouetteOpacity = 0
            }
            do {
                try await Task.sleep(for: .seconds(FishRewardPresentationTiming.reducedMotionApproachDuration))
            } catch { return false }
        } else {
            withAnimation(.easeInOut(duration: FishRewardPresentationTiming.approachDuration)) {
                caveScale = FishRewardMysteryAppearance.approachScale
            }
            do {
                try await Task.sleep(for: .seconds(
                    FishRewardPresentationTiming.approachDuration - FishRewardPresentationTiming.silhouetteDissolveDuration
                ))
            } catch { return false }
            guard !Task.isCancelled else { return false }
            withAnimation(.easeOut(duration: FishRewardPresentationTiming.silhouetteDissolveDuration)) {
                silhouetteOpacity = 0
            }
            do {
                try await Task.sleep(for: .seconds(FishRewardPresentationTiming.silhouetteDissolveDuration))
            } catch { return false }
        }
        // Hold the enlarged background during the crossfade; never rewind it to 1x.
        return !Task.isCancelled
    }

    private func revealFish() {
        // Commit synchronously before creating the task so repeated taps cannot restart it.
        guard presentation.beginApproach() else { return }
        revealTask?.cancel()
        revealTask = Task { @MainActor in
            guard await approachCave() else { return }
            let revealDuration = reduceMotion
                ? FishRewardPresentationTiming.reducedMotionRevealDuration
                : FishRewardPresentationTiming.revealDuration
            rewardGlowScale = reduceMotion ? 1 : 0.5
            rewardGlowOpacity = reduceMotion ? glowStyle.restingOpacity : glowStyle.revealOpacity
            rewardGlowRotation = 0
            fishAuraScale = reduceMotion ? glowStyle.fishAuraScale : 0.86
            fishAuraOpacity = reduceMotion ? glowStyle.fishAuraOpacity : glowStyle.fishAuraPulseOpacity
            particleExpansion = reduceMotion ? 1 : 0.35
            particleOpacity = reduceMotion
                ? 0
                : min(glowStyle.particleRestingOpacity + 0.38, 0.92)
            withAnimation(.easeInOut(duration: revealDuration)) {
                _ = presentation.beginReveal()
            }

            silhouettePulse = false
            glowScale = 0.25
            glowOpacity = reduceMotion ? 0.28 : 0.9
            withAnimation(.easeOut(duration: revealDuration)) {
                glowScale = reduceMotion ? 0.8 : 1.45
                glowOpacity = 0
            }

            if !reduceMotion {
                withAnimation(.spring(response: 0.50, dampingFraction: 0.58)) {
                    rewardGlowScale = 1
                    particleExpansion = 1
                }
            }
            do {
                try await Task.sleep(for: .seconds(
                    FishRewardPresentationTiming.revealHoldDuration(for: result.rarity)
                ))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: FishRewardPresentationTiming.fishAppearanceDuration)) {
                hasFishAppeared = true
            }
            AppFeedbackService.shared.playFishAcquisition(isNewFish: result.isNewFish)
            playOneStroke()
            if !reduceMotion {
                withAnimation(.easeOut(duration: 0.52)) {
                    fishAuraScale = glowStyle.fishAuraScale
                    rewardGlowOpacity = glowStyle.restingOpacity
                    particleOpacity = glowStyle.particleRestingOpacity
                    fishAuraOpacity = glowStyle.fishAuraOpacity
                }
            }

            // Text and the existing one-stroke animation progress concurrently.
            // This is the only task scheduling the information stages.
            for step in FishRewardPresentationTiming.informationSteps(isNewFish: result.isNewFish) {
                do {
                    try await Task.sleep(for: .seconds(FishRewardPresentationTiming.informationInterval))
                } catch { return }
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: FishRewardPresentationTiming.informationFadeDuration)) {
                    presentation.showInformation(step)
                }
            }
            do {
                try await Task.sleep(for: .seconds(FishRewardPresentationTiming.informationFadeDuration))
            } catch { return }
            guard !Task.isCancelled else { return }
            hasInformationFinished = true
            startRewardGlowBreathing()

            // Wait for actual stroke completion, not a second estimated countdown.
            await strokeTask?.value
            guard !Task.isCancelled, !isSequencePresentationFinished else { return }
            withAnimation(.easeOut(duration: FishRewardPresentationTiming.informationFadeDuration)) {
                presentation.finishReveal()
            }
            if let sequence {
                // The final sequence action must also finish fading before advancing.
                do {
                    try await Task.sleep(for: .seconds(FishRewardPresentationTiming.informationFadeDuration))
                } catch { return }
                guard !Task.isCancelled else { return }
                isSequencePresentationFinished = true
                sequence.onPresentationFinished()
            }
            revealTask = nil
        }
    }

    private func startRewardGlowBreathing() {
        guard !reduceMotion else { return }

        withAnimation(
            .easeInOut(duration: glowStyle.pulseDuration)
                .repeatForever(autoreverses: true)
        ) {
            rewardGlowScale = glowStyle.pulseScale
            rewardGlowOpacity = glowStyle.pulseOpacity
            particleExpansion = 1.06
            particleOpacity = min(glowStyle.particleRestingOpacity + 0.12, 0.72)
            fishAuraScale = glowStyle.fishAuraPulseScale
            fishAuraOpacity = glowStyle.fishAuraPulseOpacity
        }

        guard glowStyle.rotationDuration > 0 else { return }
        withAnimation(
            .linear(duration: glowStyle.rotationDuration)
                .repeatForever(autoreverses: false)
        ) {
            rewardGlowRotation = 360
        }
    }

    private func playOneStroke() {
        guard strokeAnimation.start() else { return }
        let frameDuration = FishRewardPresentationTiming.rewardFrameDuration(for: species)

        strokeTask?.cancel()
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

    private func stopAnimations() {
        revealTask?.cancel()
        revealTask = nil
        strokeTask?.cancel()
        strokeTask = nil
        strokeAnimation.reset()
        rewardGlowOpacity = 0
        rewardGlowRotation = 0
        particleOpacity = 0
        fishAuraOpacity = 0
    }
}

#Preview("初獲得") {
    FishRewardView(result: FishAcquisitionResult(
        fish: PlayerFish(species: .clownfish),
        previousOwnedCount: 0,
        currentOwnedCount: 1
    ))
}

#Preview("重複") {
    FishRewardView(result: FishAcquisitionResult(
        fish: PlayerFish(species: .clownfish),
        previousOwnedCount: 4,
        currentOwnedCount: 5
    ))
}
