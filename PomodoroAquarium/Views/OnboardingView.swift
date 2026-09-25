import SwiftUI

enum OnboardingPage: Int, CaseIterable, Identifiable {
    case welcome, reward, tomorrow

    var id: Int { rawValue }
    var next: Self? { Self(rawValue: rawValue + 1) }

    var title: String {
        switch self {
        case .welcome: "ポモドーロ水族館へようこそ"
        case .reward: "25分以上集中すると魚を獲得"
        case .tomorrow: "今日の頑張りが、明日の出会いを変える"
        }
    }

    var subtitle: String {
        switch self {
        case .welcome: "集中した時間が、水族館の成長として残ります。"
        case .reward: "集中のごほうびに、新しい魚と出会えます。\n集中を始めたら、魚たちと一緒に水族館で過ごしましょう。"
        case .tomorrow: "前日に集中した時間が多いほど、翌日は珍しい魚に出会いやすくなります。"
        }
    }
}

/// 表示専用。Player、ModelContext、報酬サービスを受け取らない。
struct OnboardingView: View {
    var completionButtonTitle = "はじめる"
    let onComplete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page: OnboardingPage = .welcome
    @State private var hasFinished = false

    var body: some View {
        ZStack {
            // 通常水槽のMovementやTimelineを生成せず、背景画像だけを利用する。
            GeometryReader { geometry in
                Image(AquariumBackgroundTheme.aquarium.imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
            }
            .ignoresSafeArea()
            .accessibilityHidden(true)
            LinearGradient(
                colors: [Color(red: 0.02, green: 0.13, blue: 0.24).opacity(0.88),
                         Color(red: 0.02, green: 0.19, blue: 0.30).opacity(0.58)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                TabView(selection: $page) {
                    ForEach(OnboardingPage.allCases) { item in
                        pageContent(item)
                            .tag(item)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .accessibilityIdentifier("onboarding.pages")

                HStack(spacing: 9) {
                    ForEach(OnboardingPage.allCases) { item in
                        Circle()
                            .fill(.white.opacity(page == item ? 1 : 0.3))
                            .frame(width: 7, height: 7)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(page.rawValue + 1) / 3ページ")
                .accessibilityIdentifier("onboarding.pageIndicator")

                Button(page.next == nil ? completionButtonTitle : "次へ") {
                    guard !hasFinished else { return }
                    if let next = page.next {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
                            page = next
                        }
                    } else {
                        hasFinished = true
                        onComplete()
                    }
                }
                .buttonStyle(AquariumStudyStartButtonStyle())
                .frame(maxWidth: 280)
                .disabled(hasFinished)
                .accessibilityIdentifier("onboarding.next")
            }
            .padding(.vertical, 24)
        }
    }

    private func pageContent(_ item: OnboardingPage) -> some View {
        VStack(spacing: 16) {
            Text(item.title)
                .font(.title2.weight(.heavy))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("onboarding.title.\(item.rawValue)")
            Text(item.subtitle)
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .lineSpacing(2)
                .shadow(color: .black.opacity(0.28), radius: 2, y: 1)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)
            illustration(item)
                .frame(maxWidth: .infinity)
            Spacer(minLength: 8)
        }
        .padding(.horizontal, 28)
        .padding(.top, 24)
        .background {
            if page == item, !reduceMotion {
                OnboardingBubbles(count: item == .welcome ? 7 : 5)
                    .opacity(item == .welcome ? 1 : 0.65)
            }
        }
    }

    @ViewBuilder
    private func illustration(_ item: OnboardingPage) -> some View {
        switch item {
        case .welcome:
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(RadialGradient(colors: [.cyan.opacity(0.25), .clear],
                                             center: .center, startRadius: 5, endRadius: 145))
                        .frame(width: 290, height: 290)
                    OnboardingWelcomeFish(species: .clownfish, isActive: page == .welcome)
                        .frame(width: 108, height: 108)
                        .offset(x: -45, y: -28)
                    OnboardingWelcomeFish(species: .jellyfish, isActive: page == .welcome)
                        .frame(width: 90, height: 90)
                        .offset(x: 70, y: -75)
                    OnboardingWelcomeFish(species: .seahorse, isActive: page == .welcome)
                        .frame(width: 120, height: 120)
                        .offset(x: 72, y: 65)
                }

                HStack(spacing: 6) {
                    loopStep("集中", symbol: "timer")
                    Image(systemName: "arrow.right")
                    loopStep("魚をゲット", symbol: "fish.fill")
                    Image(systemName: "arrow.right")
                    loopStep("水族館が育つ", symbol: "water.waves")
                }
                .font(.caption)
                .foregroundStyle(.white)
            }
        case .reward:
            rewardIllustration
        case .tomorrow:
            VStack(spacing: 14) {
                VStack(spacing: 6) {
                    Text("昨日").font(.subheadline.weight(.semibold))
                    Text("120分集中").font(.title.weight(.heavy))
                }
                .shadow(color: .black.opacity(0.28), radius: 2, y: 1)
                .padding(.horizontal, 28)
                .padding(.vertical, 18)
                .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 20))

                causalArrow

                Text("レア率UP ↑")
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(Color(red: 0.55, green: 0.95, blue: 1))
                    .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(.black.opacity(0.14), in: Capsule())
                    .accessibilityIdentifier("onboarding.rareChanceBoost")

                causalArrow

                HStack(spacing: 8) {
                    raritySilhouette(.rare)
                    raritySilhouette(.epic)
                    raritySilhouette(.legendary)
                }
            }
            .foregroundStyle(.white)
        }
    }

    private func loopStep(_ title: String, symbol: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(.cyan.opacity(0.8))
                .accessibilityHidden(true)
            Text(title)
                .font(.caption.weight(.semibold))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
        }
        .frame(maxWidth: .infinity)
    }

    private var causalArrow: some View {
        Image(systemName: "arrow.down")
            .font(.title3.weight(.medium))
            .foregroundStyle(.cyan)
            .accessibilityHidden(true)
    }

    private var rewardIllustration: some View {
        let rarity = FishRarity.rare
        let color = rarity.rewardColor
        return VStack(spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "timer")
                    .font(.title2)
                    .foregroundStyle(.cyan)
                    .accessibilityHidden(true)
                Text("25:00")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.28), radius: 2, y: 1)
                    .accessibilityLabel("25分集中")
                    .accessibilityIdentifier("onboarding.rewardStudyDuration")
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 20))

            causalArrow

            Text(rarity.rawValue.uppercased())
                .font(.headline.weight(.heavy))
                .tracking(1.4)
                .foregroundStyle(color)
                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(.black.opacity(0.14), in: Capsule())
                .overlay(Capsule().stroke(color.opacity(0.7)))
                .accessibilityIdentifier("onboarding.rewardRarity")

            ZStack {
                Ellipse()
                    .fill(RadialGradient(colors: [.white.opacity(0.5), color.opacity(0.65), .clear],
                                         center: .center, startRadius: 4, endRadius: 145))
                    .frame(width: 290, height: 210)
                    .blur(radius: 12)
                Image(systemName: FishRewardGenericSilhouette.systemImageName)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Color(red: 0.01, green: 0.04, blue: 0.09))
                    .frame(width: FishRewardGenericSilhouette.width,
                           height: FishRewardGenericSilhouette.height)
                    .accessibilityLabel("未知の魚のシルエット")
                    .accessibilityIdentifier("onboarding.rewardSilhouette")
            }
            .overlay(alignment: .top) {
                FishRewardNewBadge(glowColor: color)
                    .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
            }
        }
    }

    private func raritySilhouette(_ rarity: FishRarity) -> some View {
        VStack(spacing: 4) {
            Image(systemName: FishRewardGenericSilhouette.systemImageName)
                .resizable()
                .scaledToFit()
                .foregroundStyle(rarity.rewardColor)
                .frame(height: 75)
                .accessibilityLabel("\(rarity.rawValue)の汎用魚シルエット")
            Text(rarity.rawValue.uppercased())
                .font(.caption.weight(.heavy))
                .foregroundStyle(rarity.rewardColor)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
        }
        .frame(maxWidth: .infinity)
    }
}

/// フレーム切替だけを低頻度で更新し、通常水槽のMovement・Timelineは生成しない。
private struct OnboardingWelcomeFish: View {
    let species: FishSpecies
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var elapsedTime: TimeInterval = 0
    @State private var isFloating = false

    private var shouldAnimate: Bool { isActive && !reduceMotion }
    private var frameDuration: TimeInterval {
        FishDetailStrokeAnimationState.frameDuration(for: species)
    }

    var body: some View {
        FishImageView(
            species: species,
            animationTime: elapsedTime,
            animationFrameDuration: frameDuration
        )
        .offset(x: isFloating ? 3 : -3, y: isFloating ? -4 : 4)
        .task(id: shouldAnimate) {
            withAnimation(nil) {
                elapsedTime = 0
                isFloating = false
            }
            guard shouldAnimate else { return }
            withAnimation(.easeInOut(duration: species == .clownfish ? 4 : 5)
                .repeatForever(autoreverses: true)) {
                isFloating = true
            }
            let start = Date()
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(frameDuration))
                } catch {
                    return
                }
                guard !Task.isCancelled else { return }
                elapsedTime = Date().timeIntervalSince(start)
            }
        }
    }
}

private struct OnboardingBubbles: View {
    let count: Int

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<count, id: \.self) { index in
                    let diameter = CGFloat(6 + (index % 4) * 3)
                    BubbleView(
                        diameter: diameter,
                        travelDistance: geometry.size.height + diameter * 2,
                        duration: Double(11 + (index % 4) * 2),
                        delay: Double(index) * 0.9
                    )
                    .position(
                        x: geometry.size.width * CGFloat(index + 1) / CGFloat(count + 1),
                        y: geometry.size.height + diameter
                    )
                }
            }
            .clipped()
            // 上部の文章付近では泡を薄くし、上端で自然に消す。
            .mask {
                LinearGradient(stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .white.opacity(0.2), location: 0.22),
                    .init(color: .white, location: 0.4),
                    .init(color: .white, location: 1)
                ], startPoint: .top, endPoint: .bottom)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#Preview {
    OnboardingView(onComplete: {})
}
