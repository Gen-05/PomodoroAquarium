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

    var sentences: [String] { subtitle.components(separatedBy: "\n") }

    func text(for element: OnboardingElement) -> String? {
        switch element {
        case .title: return title
        case .sentence(let index): return sentences[index]
        default: return nil
        }
    }

    /// 見出しの段階から開始し、すべての要素が揃ったらページ送りを解放する。
    var revealSteps: [[OnboardingElement]] {
        switch self {
        case .welcome:
            [[.title, .welcomeFish], [.sentence(0)], [.focus], [.caughtFish], [.growingAquarium]]
        case .reward:
            [[.title], [.sentence(0)], [.sentence(1)], [.studyTimer], [.rarity], [.rewardFish]]
        case .tomorrow:
            [[.title], [.sentence(0)], [.yesterdayStudy], [.boost], [.rare], [.epic], [.legendary]]
        }
    }
}

enum OnboardingElement: Hashable {
    case title, sentence(Int), welcomeFish, focus, caughtFish, growingAquarium
    case studyTimer, rarity, rewardFish, yesterdayStudy, boost, rare, epic, legendary
}

/// オンボーディング専用。句読点の間は通常の間隔へ加算せず、次の文字までの時間とする。
enum OnboardingTextTiming {
    static let characterInterval: Duration = .milliseconds(50)
    static let commaPause: Duration = .milliseconds(200)
    static let sentencePause: Duration = .milliseconds(350)
    static let diagramInterval: Duration = .milliseconds(700)
    static let textHoldDuration: Duration = .seconds(1)

    static func delay(after previous: Character?, before character: Character) -> Duration {
        if character.isNewline { return .zero }
        switch previous {
        case "、": return commaPause
        case "。", "！", "？", "!", "?": return sentencePause
        default: return characterInterval
        }
    }
}

struct OnboardingTypingText {
    let page: OnboardingPage
    let element: OnboardingElement
    let text: String
    private(set) var visibleCharacterCount = 0

    var isComplete: Bool { visibleCharacterCount == text.count }
    var visibleText: String { String(text.prefix(visibleCharacterCount)) }
    mutating func revealCharacter() { visibleCharacterCount = min(visibleCharacterCount + 1, text.count) }
    mutating func complete() { visibleCharacterCount = text.count }
}

/// 表示段階・文字の進行だけを保持。画面内の往復では残し、Preview再生成時には初期化する。
struct OnboardingRevealProgress {
    private var steps: [OnboardingPage: Int] = [:]
    private var begunPages: Set<OnboardingPage> = []
    private(set) var activeText: OnboardingTypingText?

    func step(on page: OnboardingPage) -> Int { steps[page, default: 1] }
    func isComplete(on page: OnboardingPage) -> Bool {
        step(on: page) == page.revealSteps.count && !isTyping(on: page)
    }
    func isTyping(on page: OnboardingPage) -> Bool { activeText?.page == page && activeText?.isComplete == false }
    func canAutoAdvance(on page: OnboardingPage) -> Bool {
        begunPages.contains(page) && !isTyping(on: page) && step(on: page) < page.revealSteps.count
    }
    func autoAdvanceDelay(on page: OnboardingPage) -> Duration {
        let currentGroup = page.revealSteps[step(on: page) - 1]
        return currentGroup.contains { page.text(for: $0) != nil }
            ? OnboardingTextTiming.textHoldDuration : OnboardingTextTiming.diagramInterval
    }
    func isVisible(_ element: OnboardingElement, on page: OnboardingPage) -> Bool {
        page.revealSteps.prefix(step(on: page)).contains { $0.contains(element) }
    }
    func characterCount(for element: OnboardingElement, on page: OnboardingPage) -> Int {
        if let activeText, activeText.page == page, activeText.element == element {
            return activeText.visibleCharacterCount
        }
        if element == .title, !begunPages.contains(page) { return 0 }
        return page.text(for: element)?.count ?? 0
    }
    mutating func beginPage(on page: OnboardingPage, typesText: Bool) {
        guard begunPages.insert(page).inserted else { return }
        activeText = OnboardingTypingText(page: page, element: .title, text: page.title)
        if !typesText { completeText() }
    }
    mutating func advanceAutomatically(on page: OnboardingPage, typesText: Bool = false) {
        guard canAutoAdvance(on: page) else { return }
        let nextStep = step(on: page) + 1
        steps[page] = nextStep
        activeText = nil
        for element in page.revealSteps[nextStep - 1] {
            if let text = page.text(for: element) {
                activeText = OnboardingTypingText(page: page, element: element, text: text)
                if !typesText { completeText() }
            }
        }
    }
    mutating func finishPage(on page: OnboardingPage) {
        begunPages.insert(page)
        steps[page] = page.revealSteps.count
        if activeText?.page == page { activeText = nil }
    }
    mutating func revealCharacter() { activeText?.revealCharacter() }
    mutating func completeText() { activeText?.complete() }
}

/// 表示専用。Player、ModelContext、報酬サービスを受け取らない。
struct OnboardingView: View {
    var completionButtonTitle = "はじめる"
    let onComplete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @State private var typingTask: Task<Void, Never>?
    @State private var page: OnboardingPage = .welcome
    @State private var revealProgress = OnboardingRevealProgress()
    @State private var showsStartScreen = true
    @State private var hasFinished = false

    var body: some View {
        if showsStartScreen {
            StartSurfaceView {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
                    showsStartScreen = false
                }
            }
        } else {
            explanationContent
                .onAppear(perform: beginPageTitle)
                .onDisappear(perform: stopTyping)
                .onChange(of: reduceMotion) { _, enabled in if enabled { stopTyping() } }
                .onChange(of: voiceOverEnabled) { _, enabled in if enabled { stopTyping() } }
                .task(id: autoAdvanceKey) {
                    guard autoAdvanceKey != nil else { return }
                    let expectedPage = page
                    let expectedStep = revealProgress.step(on: page)
                    do {
                        try await Task.sleep(for: revealProgress.autoAdvanceDelay(on: page))
                    } catch {
                        return
                    }
                    guard !Task.isCancelled, page == expectedPage,
                          revealProgress.step(on: page) == expectedStep,
                          revealProgress.canAutoAdvance(on: page) else { return }
                    var next = revealProgress
                    next.advanceAutomatically(on: page, typesText: !reduceMotion && !voiceOverEnabled)
                    withAnimation(reduceMotion || next.isTyping(on: page) ? nil : .easeInOut(duration: 0.22)) {
                        revealProgress = next
                    }
                    startTyping()
                }
        }
    }

    // 一つのページ・段階につき一つだけ待機。ページ変更・非表示ではSwiftUIがTaskをキャンセルする。
    private var autoAdvanceKey: String? {
        revealProgress.canAutoAdvance(on: page) ? "\(page.rawValue):\(revealProgress.step(on: page))" : nil
    }

    private var explanationContent: some View {
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
                pageContent(page)
                    .id(page)
                    .transition(.opacity)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture { completeCurrentText() }
                    // 横スワイプはページ移動だけに使う。未読中は先へ飛ばさない。
                    .gesture(DragGesture(minimumDistance: 30).onEnded { value in
                        guard abs(value.translation.width) > abs(value.translation.height) else { return }
                        if value.translation.width > 50,
                           let previous = OnboardingPage(rawValue: page.rawValue - 1) {
                            showPage(previous)
                        } else if value.translation.width < -50, revealProgress.isComplete(on: page),
                                  let next = page.next {
                            showPage(next)
                        }
                    })
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("onboarding.pages")
                    .accessibilityActions {
                        if revealProgress.isTyping(on: page) {
                            Button("文章を全文表示") { completeCurrentText() }
                        }
                        if let previous = OnboardingPage(rawValue: page.rawValue - 1) {
                            Button("前のページ") { showPage(previous) }
                        }
                    }

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
                .contentShape(Rectangle())
                .onTapGesture { completeCurrentText() }

                // 文字サイズに追従する寸法だけを先に確保し、未読中は「次へ」を生成しない。
                ZStack {
                    Text(page.next == nil ? completionButtonTitle : "次へ")
                        .font(.headline)
                        .padding(.vertical, 15)
                        .frame(minHeight: 54)
                        .hidden()
                        .accessibilityHidden(true)

                    if revealProgress.isComplete(on: page) {
                        Button(page.next == nil ? completionButtonTitle : "次へ") {
                            guard !hasFinished, revealProgress.isComplete(on: page) else { return }
                            if let next = page.next {
                                showPage(next)
                            } else {
                                hasFinished = true
                                onComplete()
                            }
                        }
                        .buttonStyle(AquariumStudyStartButtonStyle())
                        .frame(maxWidth: 280)
                        .disabled(hasFinished)
                        .accessibilityIdentifier("onboarding.next")
                        .transition(.opacity)

                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 24)
        }
    }

    private func pageContent(_ item: OnboardingPage) -> some View {
        VStack(spacing: 16) {
            revealed(.title, on: item) {
                let count = revealProgress.characterCount(for: .title, on: item)
                displayText(item.title, characterCount: count)
                    .font(.title2.weight(.heavy))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityLabel(String(item.title.prefix(count)))
                    .accessibilityValue(count < item.title.count ? "文字表示中" : "全文表示済み")
                    .transaction { $0.animation = nil }
                    .accessibilityIdentifier("onboarding.title.\(item.rawValue)")
            }
            VStack(spacing: 2) {
                ForEach(Array(item.sentences.enumerated()), id: \.offset) { index, sentence in
                    sentenceText(sentence)
                        .hidden()
                        .accessibilityHidden(true)
                        .overlay {
                            if revealProgress.isVisible(.sentence(index), on: item) {
                                let count = revealProgress.characterCount(for: .sentence(index), on: item)
                                sentenceText(sentence, characterCount: count)
                                    .accessibilityLabel(String(sentence.prefix(count)))
                                    .accessibilityValue(count < sentence.count ? "文字表示中" : "全文表示済み")
                                    .accessibilityIdentifier("onboarding.sentence.\(item.rawValue).\(index)")
                                    .transition(.identity)
                                    .transaction { $0.animation = nil }
                            }
                        }
                }
            }

            Spacer(minLength: 8)
            illustration(item)
                .frame(maxWidth: .infinity)
            Spacer(minLength: 8)
        }
        .padding(.horizontal, 28)
        .padding(.top, 24)
        .background {
            if page == item, revealProgress.step(on: item) > 0, !reduceMotion {
                OnboardingBubbles(count: item == .welcome ? 7 : 5)
                    .opacity(item == .welcome ? 1 : 0.65)
            }
        }
    }

    /// 単一のViewを透明にして寸法を維持。魚・エフェクトを複製せず、隠れている要素は読み上げない。
    private func revealed<Content: View>(
        _ element: OnboardingElement, on item: OnboardingPage, @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .opacity(revealProgress.isVisible(element, on: item) ? 1 : 0)
            .accessibilityHidden(!revealProgress.isVisible(element, on: item))
    }

    private func displayText(_ string: String, characterCount: Int? = nil) -> Text {
        var text = AttributedString(string)
        if let characterCount, characterCount < string.count {
            let firstHidden = text.characters.index(text.startIndex, offsetBy: max(0, characterCount))
            text[firstHidden..<text.endIndex].foregroundColor = .clear
        }
        // 見出しも本文も全文で組版し、文字送りで折り返しや図の位置を変えない。
        return Text(text)
    }

    private func sentenceText(_ sentence: String, characterCount: Int? = nil) -> some View {
        displayText(sentence, characterCount: characterCount)
            .font(.subheadline.weight(.medium))
            .multilineTextAlignment(.center)
            .foregroundStyle(.white)
            .lineSpacing(2)
            .shadow(color: .black.opacity(0.28), radius: 2, y: 1)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func illustration(_ item: OnboardingPage) -> some View {
        switch item {
        case .welcome:
            VStack(spacing: 16) {
                revealed(.welcomeFish, on: item) {
                    ZStack {
                        Circle()
                            .fill(RadialGradient(colors: [.cyan.opacity(0.25), .clear],
                                                 center: .center, startRadius: 5, endRadius: 145))
                            .frame(width: 290, height: 290)
                        OnboardingWelcomeFish(species: .clownfish, isActive: page == .welcome && revealProgress.isVisible(.welcomeFish, on: .welcome))
                            .frame(width: 108, height: 108)
                            .offset(x: -45, y: -28)
                        OnboardingWelcomeFish(species: .jellyfish, isActive: page == .welcome && revealProgress.isVisible(.welcomeFish, on: .welcome))
                            .frame(width: 90, height: 90)
                            .offset(x: 70, y: -75)
                        OnboardingWelcomeFish(species: .seahorse, isActive: page == .welcome && revealProgress.isVisible(.welcomeFish, on: .welcome))
                            .frame(width: 120, height: 120)
                            .offset(x: 72, y: 65)
                    }
                }

                HStack(spacing: 6) {
                    revealed(.focus, on: item) { loopStep("集中", symbol: "timer") }
                    revealed(.caughtFish, on: item) { Image(systemName: "arrow.right") }
                    revealed(.caughtFish, on: item) { loopStep("魚をゲット", symbol: "fish.fill") }
                    revealed(.growingAquarium, on: item) { Image(systemName: "arrow.right") }
                    revealed(.growingAquarium, on: item) { loopStep("水族館が育つ", symbol: "water.waves") }
                }
                .font(.caption)
                .foregroundStyle(.white)
            }
        case .reward:
            rewardIllustration
        case .tomorrow:
            VStack(spacing: 14) {
                revealed(.yesterdayStudy, on: item) {
                    VStack(spacing: 6) {
                        Text("昨日").font(.subheadline.weight(.semibold))
                        Text("120分集中").font(.title.weight(.heavy))
                    }
                    .shadow(color: .black.opacity(0.28), radius: 2, y: 1)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 18)
                    .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 20))
                }

                revealed(.boost, on: item) { causalArrow }

                revealed(.boost, on: item) {
                    Text("レア率UP ↑")
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(Color(red: 0.55, green: 0.95, blue: 1))
                        .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 12)
                        .background(.black.opacity(0.14), in: Capsule())
                        .accessibilityIdentifier("onboarding.rareChanceBoost")
                }

                revealed(.rare, on: item) { causalArrow }

                HStack(spacing: 8) {
                    revealed(.rare, on: item) { raritySilhouette(.rare) }
                    revealed(.epic, on: item) { raritySilhouette(.epic) }
                    revealed(.legendary, on: item) { raritySilhouette(.legendary) }
                }
            }
            .foregroundStyle(.white)
        }
    }

    private func completeCurrentText() {
        // 任意の全文表示だけを許可し、タップで段階を進めたり待機を短縮したりしない。
        if revealProgress.isTyping(on: page) { stopTyping() }
    }

    private func beginPageTitle() {
        revealProgress.beginPage(on: page, typesText: !reduceMotion && !voiceOverEnabled)
        startTyping()
    }

    private func startTyping() {
        guard let text = revealProgress.activeText, revealProgress.isTyping(on: page) else { return }
        typingTask?.cancel()
        typingTask = Task { @MainActor in
            _ = await TutorialTextReveal.reveal(text.text, delayBeforeCharacter: OnboardingTextTiming.delay, onCharacter: { _ in
                guard page == text.page,
                      revealProgress.activeText?.element == text.element,
                      revealProgress.isTyping(on: page) else { return }
                revealProgress.revealCharacter()
            })
        }
    }

    private func stopTyping() {
        typingTask?.cancel()
        typingTask = nil
        revealProgress.completeText()
    }

    private func showPage(_ destination: OnboardingPage) {
        stopTyping()
        revealProgress.finishPage(on: page)
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
            page = destination
        }
        beginPageTitle()
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
            revealed(.studyTimer, on: .reward) {
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
            }

            revealed(.rarity, on: .reward) { causalArrow }

            revealed(.rarity, on: .reward) {
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
            }

            revealed(.rewardFish, on: .reward) {
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
