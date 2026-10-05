//
//  TimerView.swift
//  PomodoroAquarium
//
//  Created by 阿部弦生 on 2026/07/13.
//

import SwiftUI
import SwiftData
import UIKit

enum TimerConfigurationStorageKey {
    static let pomodoroStudyDuration = "pomodoroStudyDuration"
    static let pomodoroBreakDuration = "pomodoroBreakDuration"
    static let pomodoroSetCount = "pomodoroSetCount"
    static let timerDuration = "timerDuration"

    fileprivate static let legacyStudyTime = "studyTime"
    fileprivate static let legacyBreakTime = "breakTime"
}

enum TimerConfigurationStorage {
    static let defaultPomodoroStudyMinutes = 25
    static let defaultTimerDurationMinutes = 25

    static func migrateLegacyValuesIfNeeded(in defaults: UserDefaults = .standard) {
        let legacyStudyDuration = defaults.string(
            forKey: TimerConfigurationStorageKey.legacyStudyTime
        )
        let legacyBreakDuration = defaults.string(
            forKey: TimerConfigurationStorageKey.legacyBreakTime
        )

        if defaults.object(forKey: TimerConfigurationStorageKey.pomodoroStudyDuration) == nil {
            defaults.set(
                legacyStudyDuration ?? String(defaultPomodoroStudyMinutes),
                forKey: TimerConfigurationStorageKey.pomodoroStudyDuration
            )
        }
        if defaults.object(forKey: TimerConfigurationStorageKey.timerDuration) == nil {
            defaults.set(
                legacyStudyDuration ?? String(defaultTimerDurationMinutes),
                forKey: TimerConfigurationStorageKey.timerDuration
            )
        }
        if defaults.object(forKey: TimerConfigurationStorageKey.pomodoroBreakDuration) == nil {
            defaults.set(
                legacyBreakDuration ?? String(PomodoroBreakConfiguration.defaultBreakMinutes),
                forKey: TimerConfigurationStorageKey.pomodoroBreakDuration
            )
        }
    }
}

enum PomodoroBreakConfiguration {
    static let defaultBreakMinutes = 5
    static let defaultSetCount = 3

    static func configuredSetCount(in defaults: UserDefaults = .standard) -> Int {
        guard defaults.object(forKey: TimerConfigurationStorageKey.pomodoroSetCount) != nil else {
            return defaultSetCount
        }
        return max(defaults.integer(forKey: TimerConfigurationStorageKey.pomodoroSetCount), 1)
    }

    static func isBreakSelectionEnabled(setCount: Int) -> Bool {
        setCount > 1
    }

    static func effectiveBreakMinutes(preferredMinutes: Int, setCount: Int) -> Int {
        isBreakSelectionEnabled(setCount: setCount) ? max(preferredMinutes, 0) : 0
    }
}

struct CountdownDurationComponents {
    let hours: Int
    let minutes: Int

    init(totalMinutes: Int) {
        let nonnegativeMinutes = max(totalMinutes, 0)
        hours = nonnegativeMinutes / 60
        minutes = nonnegativeMinutes % 60
    }

    init(hours: Int, minutes: Int) {
        self.hours = hours
        self.minutes = minutes
    }

    var totalMinutes: Int {
        hours * 60 + minutes
    }
}

enum CountdownDurationConfiguration {
    static let maximumHours = 23
    static let maximumMinutes = 59
    static let totalMinutesRange = 1...(maximumHours * 60 + maximumMinutes)

    static func maximumMinuteComponent(hours: Int, maximumTotalMinutes: Int) -> Int {
        min(max(maximumTotalMinutes - max(hours, 0) * 60, 0), 59)
    }

    static func isValidDuration(hours: Int, minutes: Int) -> Bool {
        guard hours >= 0, (0...59).contains(minutes) else { return false }
        return totalMinutesRange.contains(
            CountdownDurationComponents(hours: hours, minutes: minutes).totalMinutes
        )
    }
}

enum StudyFocusRulesContent {
    static let title = "水族館内のルール"
    static let introduction = "集中を始める前に、ひとつだけ大切なことがあります。"
    static let keepScreenOpen = "集中を始めたら、魚たちと一緒に水族館で過ごしましょう。"
    static let backgroundLimit = "水族館を離れて3分経つと魚たちがお知らせします。\n5分以上離れると、今回の集中は終了します。"
}

private extension FocusCategoryColorKey {
    var swiftUIColor: Color {
        switch self {
        case .studyBlue:
            Color(red: 0.24, green: 0.73, blue: 0.94)
        case .readingCoral:
            Color(red: 1.0, green: 0.57, blue: 0.48)
        case .qualificationPurple:
            Color(red: 0.62, green: 0.48, blue: 0.94)
        case .testAmber:
            Color(red: 1.0, green: 0.72, blue: 0.25)
        case .assignmentMint:
            Color(red: 0.35, green: 0.82, blue: 0.65)
        case .languagePink:
            Color(red: 0.94, green: 0.45, blue: 0.72)
        case .oceanTeal:
            Color(red: 0.20, green: 0.72, blue: 0.75)
        case .skyIndigo:
            Color(red: 0.35, green: 0.51, blue: 0.95)
        case .sunsetOrange:
            Color(red: 1.0, green: 0.48, blue: 0.28)
        case .aquaCyan:
            Color(red: 0.25, green: 0.84, blue: 0.94)
        }
    }
}

private extension Color {
    init?(focusCategoryHex rawValue: String) {
        guard let normalized = FocusCategoryHexColor.normalized(rawValue),
              let rgb = UInt64(normalized.dropFirst(), radix: 16) else {
            return nil
        }
        self.init(
            .sRGB,
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255,
            opacity: 1
        )
    }

    var opaqueFocusCategoryHex: String? {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return nil
        }

        return String(
            format: "#%02X%02X%02X",
            Int((red * 255).rounded()),
            Int((green * 255).rounded()),
            Int((blue * 255).rounded())
        )
    }
}

extension FocusCategory {
    var swiftUIColor: Color {
        if let customHex = resolvedCustomHex,
           let customColor = Color(focusCategoryHex: customHex) {
            return customColor
        }
        return colorKey.swiftUIColor
    }
}

private struct PomodoroFishDashMask: View {
    var body: some View {
        Canvas { context, size in
            let dotDiameter: CGFloat = 2.6
            let step: CGFloat = 4.5
            let rowCount = Int(ceil(size.height / step)) + 1
            let columnCount = Int(ceil(size.width / step)) + 1

            for row in 0..<rowCount {
                let xOffset = row.isMultiple(of: 2) ? 0 : step / 2
                for column in 0..<columnCount {
                    let origin = CGPoint(
                        x: CGFloat(column) * step + xOffset,
                        y: CGFloat(row) * step
                    )
                    let dot = CGRect(
                        x: origin.x,
                        y: origin.y,
                        width: dotDiameter,
                        height: dotDiameter
                    )
                    context.fill(Path(ellipseIn: dot), with: .color(.white))
                }
            }
        }
    }
}

private struct PomodoroProgressFish: View {
    let isReached: Bool

    var body: some View {
        Group {
            if isReached {
                fishSilhouette
                    .foregroundStyle(.white.opacity(0.92))
            } else {
                dashedFishOutline
            }
        }
        .frame(width: 18, height: 14)
    }

    private var fishSilhouette: some View {
        Image(systemName: "fish.fill")
            .resizable()
            .scaledToFit()
            .frame(width: 18, height: 14)
    }

    private var dashedFishOutline: some View {
        ZStack {
            fishSilhouette
                .foregroundStyle(.white.opacity(0.68))

            fishSilhouette
                .foregroundStyle(.black)
                .scaleEffect(x: 0.72, y: 0.58)
                .blendMode(.destinationOut)
        }
        .compositingGroup()
        .mask {
            PomodoroFishDashMask()
        }
    }
}

struct TimerView: View {
    
    let studyTime: Int
    let breakTime: Int
    let player: Player?
    let coreTutorial: CoreTutorialCoordinator?
    private let defaults: UserDefaults

    @AppStorage(AquariumThemeStore.storageKey)
    private var backgroundThemeRawValue = AquariumBackgroundTheme.aquarium.rawValue
    @AppStorage(TimerConfigurationStorageKey.pomodoroStudyDuration)
    private var storedPomodoroStudyDuration = "25"
    @AppStorage(TimerConfigurationStorageKey.pomodoroBreakDuration)
    private var storedPomodoroBreakDuration = "5"
    @AppStorage(TimerConfigurationStorageKey.pomodoroSetCount) private var pomodoroSetCount = 3
    @AppStorage(TimerConfigurationStorageKey.timerDuration)
    private var storedTimerDuration = "25"
    @AppStorage(NotificationIntroductionSettings.hasShownKey)
    private var hasShownNotificationIntroduction = false
    @AppStorage(NotificationSettings.enabledKey)
    private var notificationsEnabled = false

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    // `navigationDestination(isPresented:)`のdestination値にpredicate付きQueryを直接持たせると、
    // iOS 26でdestination preferenceが安定せず再登録を繰り返すため、ここではQuery自体を
    // 安定させ、少数のカテゴリに対するarchive除外はactiveFocusCategoriesで行う。
    @Query private var focusCategories: [FocusCategory]
    
    init(
        studyTime: Int,
        breakTime: Int,
        player: Player?,
        viewModel: TimerViewModel? = nil,
        coreTutorial: CoreTutorialCoordinator? = nil,
        defaults: UserDefaults = .standard
    ) {
        TimerConfigurationStorage.migrateLegacyValuesIfNeeded(in: defaults)
        self.studyTime = studyTime
        self.breakTime = breakTime
        self.player = player
        self.coreTutorial = coreTutorial
        self.defaults = defaults
        
        let configuredSetCount = PomodoroBreakConfiguration.configuredSetCount(in: defaults)
        let tempViewModel = viewModel ?? TimerViewModel(
            studyTime: studyTime,
            breakTime: PomodoroBreakConfiguration.effectiveBreakMinutes(
                preferredMinutes: breakTime,
                setCount: configuredSetCount
            ),
            totalSets: configuredSetCount
        )
        if viewModel == nil {
            tempViewModel.selectCategory(FocusCategorySelectionStore.initialID(
                defaults: defaults,
                isTutorial: coreTutorial?.isActive == true || coreTutorial?.isPreviewMode == true
            ))
        }
        self._viewModel = State(initialValue: tempViewModel)
        self._completionReward = State(initialValue: nil)
        self._pendingCompletionReward = State(initialValue: nil)
#if DEBUG
        TimerNavigationDiagnostics.record("TimerView.init", model: tempViewModel)
#endif
    }
    
    @State private var viewModel: TimerViewModel
    @State private var fishRewardBatch: FishRewardBatch?
    @State private var pendingFishRewardBatches: [FishRewardBatch] = []
    @State private var lastFinalizedRewardBatch: FishRewardBatch?
    @State private var lastFinalizedPointReward = 0
    @State private var lastFinalizedSessionID: UUID?
    @State private var presentedPomodoroFlowID: UUID?
    @State private var isClosingStudyFlow = false
    @State private var completionReward: StudyCompletionReward?
    @State private var pendingCompletionReward: StudyCompletionReward?
    @State private var rewardHistoryIDs: [UUID] = []
    @State private var studyFinishedMinutes: Int?
    @State private var studyFinishedEndReason: StudySessionEndReason = .completed
    @State private var showsEndConfirmation = false
    @State private var showsBreakEndConfirmation = false
    @State private var breakEndConfirmationID: UUID?
    @State private var showsTimeSettings = false
    @State private var showsFocusRules = false
    @State private var showsFocusCategorySelection = false
    @State private var showsNotificationIntroduction = false
    @State private var tutorialCompletionTask: Task<Void, Never>?
    @State private var isCompletingCoreTutorialStudy = false
    @State private var focusDisplay = FocusDisplayState()
    @State private var isTimerViewVisible = false
    @State private var studyStartPresentation = StudyStartPresentation()
    @State private var studyStartFadeProgress: CGFloat = 0
    @State private var studyStartControlsOpacity: Double = 1
    @State private var studyStartIsRevealingRunningUI = false
    @State private var studyStartCanvasFrame: CGRect = .zero
    @State private var studyStartButtonFrame: CGRect = .zero
    @State private var studyStartOrigin = CGPoint(x: 0.5, y: 0.72)

    var body: some View {
        ZStack {
            AquariumView(
                player: player,
                backgroundTheme: AquariumThemeStore.theme(from: backgroundThemeRawValue),
                isSimulationPaused: false
            )

            VStack(spacing: 18) {
                Spacer()
                sessionConfigurationControls
                    .modifier(FocusDisplayControlsModifier(isHidden: focusDisplay.isFocusDisplayMode))
                focusRulesControl
                    .modifier(FocusDisplayControlsModifier(isHidden: focusDisplay.isFocusDisplayMode))
                timerDisplay
                    .overlay(alignment: .top) {
                        if viewModel.state == .paused {
                            Text("一時停止中")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.8))
                                .offset(y: -28)
                        }
                    }
                    .opacity(focusDisplay.isFocusDisplayMode ? 0.45 : 1)
                    .animation(.easeInOut(duration: FocusDisplayState.fadeDuration), value: focusDisplay.isFocusDisplayMode)
                pomodoroProgress
                    .modifier(FocusDisplayControlsModifier(isHidden: focusDisplay.isFocusDisplayMode))
                sessionActionControls
                    .modifier(FocusDisplayControlsModifier(isHidden: focusDisplay.isFocusDisplayMode))
                Spacer()
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
            // 背景の魚・泡やTutorial overlayの局所animationを、
            // 固定すべきTimer操作UIへ伝播させない。
            .transaction { transaction in
                transaction.animation = nil
            }
            .opacity(isCoreTutorialStudy
                     ? (studyStartPresentation.isPresenting && studyStartPresentation.effect == .fade
                        ? 1 - Double(studyStartFadeProgress) : 1)
                     : studyStartControlsOpacity)
            .accessibilityHidden(isStudyStartQuietOverlay)
        }
        .background {
            // Measure the full overlay canvas once per layout, not on animation frames.
            GeometryReader { geometry in
                Color.clear.onGeometryChange(for: CGRect.self) { proxy in
                    proxy.frame(in: .global)
                } action: { frame in
                    studyStartCanvasFrame = frame
                }
            }
            .ignoresSafeArea()
        }
        .allowsHitTesting(!studyStartPresentation.isPresenting)
        .overlay {
            if studyStartPresentation.isPresenting {
                StudyStartRippleView(
                    effect: studyStartPresentation.effect,
                    fadeProgress: studyStartFadeProgress,
                    origin: studyStartOrigin
                )
                .id(studyStartPresentation.requestID)
                .ignoresSafeArea()
            }
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0).onEnded { _ in
                focusDisplay.userInteracted()
            },
            // Do not intercept UIKit-backed configuration Pickers before running.
            including: focusDisplayContext.canAutoHide && !focusDisplay.isFocusDisplayMode
                ? .all : .subviews
        )
        .overlay {
            if focusDisplay.isFocusDisplayMode {
                // This layer consumes the wake-up tap, including over hidden buttons.
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture { focusDisplay.userInteracted() }
                    .accessibilityLabel("操作を表示")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityIdentifier("timer.showControls")
            }
        }
        .overlayPreferenceValue(CoreTutorialTargetPreferenceKey.self) { targets in
            GeometryReader { geometry in
                coreTutorialStudyOverlay(targets: targets, geometry: geometry)
            }
        }
        .overlay {
            if isCompletingCoreTutorialStudy {
                CoreTutorialStudyStartingShield()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(
            viewModel.locksMainTabNavigation || isCoreTutorialStudy || isCompletingCoreTutorialStudy ||
                isStudyStartQuietOverlay
        )
        .toolbar {
            if isStudyStartQuietOverlay && !studyStartIsRevealingRunningUI {
                ToolbarItem(placement: .topBarLeading) {
                    // Keep the navigation row's height while its noninteractive back cue fades.
                    // Outside this transition, the original native back button is unchanged.
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.cyan)
                        .frame(width: 32, height: 32)
                        .background(.black.opacity(0.12), in: Circle())
                        .opacity(studyStartControlsOpacity)
                        .animation(.easeOut(duration: 0.25), value: studyStartControlsOpacity)
                        .accessibilityHidden(true)
                }
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .overlay(alignment: .top) { navigationRegressionControls }
        .toolbarColorScheme(.dark, for: .navigationBar)
        .preference(key: TimerFocusDisplayPreferenceKey.self,
                    value: focusDisplay.isFocusDisplayMode || isStudyStartQuietOverlay)
        .onAppear {
            traceTimerNavigation("TimerView.onAppear")
            isTimerViewVisible = true
#if DEBUG
            prepareShoreWaveVisualTestIfNeeded()
#endif
            initializeFocusCategorySelection()
            configureStudyCompletion()
            configurePomodoroAutoStart()
            prepareCoreTutorialStudyIfNeeded()
            viewModel.restorePersistedSessionIfNeeded()
            traceTimerNavigation("TimerView.after restore")
            viewModel.setAppActive(scenePhase == .active)
            viewModel.setTimerScreenVisible(true)
            viewModel.synchronizeTime()
            presentAutomaticPomodoroRewardsIfFinished()
            focusDisplay.update(context: focusDisplayContext)
        }
        .onChange(of: focusDisplayContext) { _, context in
            focusDisplay.update(context: context)
        }
        .onChange(of: viewModel.currentSet) { _, _ in
            focusDisplay.reset()
            focusDisplay.update(context: focusDisplayContext)
        }
        .task(id: focusDisplay.timeoutID) {
            guard let id = focusDisplay.timeoutID, let deadline = focusDisplay.deadline else { return }
            do {
                try await Task.sleep(for: .seconds(max(0, deadline.timeIntervalSinceNow)))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            guard focusDisplayContext.canAutoHide else {
                focusDisplay.reset()
                return
            }
            focusDisplay.timeout(id: id)
        }
        .task(id: studyStartPresentation.requestID) {
            await performStudyStartPresentation()
        }
        .onChange(of: studyStartPresentation.requestID) { _, id in
            if id == nil {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    studyStartFadeProgress = 0
                    studyStartIsRevealingRunningUI = false
                }
                withAnimation(.easeInOut(duration: 0.25)) { studyStartControlsOpacity = 1 }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { studyStartPresentation.reset() }
            if phase != .active { viewModel.setAppActive(false) }
            if phase == .active { timerScreenDidBecomeActive() }
        }
        .onChange(of: viewModel.state) { _, state in
            if !studyStartPresentation.canContinue(state: state, phase: viewModel.phase) {
                studyStartPresentation.reset()
            }
        }
        .onChange(of: viewModel.phase) { _, phase in
            if phase != .breakTime {
                showsBreakEndConfirmation = false
                breakEndConfirmationID = nil
            }
            if !studyStartPresentation.canContinue(state: viewModel.state, phase: phase) {
                studyStartPresentation.reset()
            }
        }
        .onChange(of: viewModel.shouldPresentBackgroundFailureAlert) { _, isPresented in
            if !isPresented && (pendingCompletionReward != nil || !pendingFishRewardBatches.isEmpty) {
                if viewModel.isAutomaticPomodoroFlow {
                    presentAutomaticPomodoroRewardsIfFinished()
                } else {
                    presentPendingCompletionReward()
                }
            }
        }
        .onChange(of: activeFocusCategoryIDs) { _, _ in
            ensureSelectedFocusCategoryIsActive()
        }
        .onDisappear {
            traceTimerNavigation("TimerView.onDisappear")
            // app backgroundとアプリ内Navigationを区別する。
            if scenePhase == .active { viewModel.setTimerScreenVisible(false) }
            isTimerViewVisible = false
            showsBreakEndConfirmation = false
            breakEndConfirmationID = nil
            studyStartPresentation.reset()
            studyStartControlsOpacity = 1
            studyStartIsRevealingRunningUI = false
            focusDisplay.reset()
            tutorialCompletionTask?.cancel()
            tutorialCompletionTask = nil
            if isCompletingCoreTutorialStudy {
                isCompletingCoreTutorialStudy = false
                restoreStoredTimerConfiguration()
            }
            if coreTutorial?.step == .studySetupIntro ||
                coreTutorial?.step == .studySettingsIntro ||
                coreTutorial?.step == .waitingForStudyStartTap {
                coreTutorial?.didLeaveStudySetupBeforeStarting()
                restoreStoredTimerConfiguration()
            }
        }
        .alert(viewModel.isStudyTime ? "集中を終了しますか？" : "休憩を終了しますか？", isPresented: $showsEndConfirmation) {
            Button("キャンセル", role: .cancel) {}
            Button("終了する", role: .destructive) {
                viewModel.endCurrentSession()
            }
        } message: {
            if viewModel.isStudyTime {
                Text("現在までの集中時間で報酬を計算します。\n\n今回の集中時間: \(viewModel.elapsedStudyMinutes)分")
            } else {
                Text("現在の休憩を終了して、次の集中へ進みます。")
            }
        }
        .alert("集中終了をお知らせ", isPresented: $showsNotificationIntroduction) {
            Button("あとで", role: .cancel) {
                notificationsEnabled = false
                viewModel.resumeTimer()
            }
            Button("通知を許可する") {
                viewModel.resumeTimer()
                NotificationService.shared.requestAuthorization { granted in
                    Task { @MainActor in
                        notificationsEnabled = granted
                        if granted {
                            viewModel.rescheduleCurrentSessionNotification()
                        }
                    }
                }
            }
        } message: {
            Text("集中や休憩が終わった時に通知でお知らせできます。")
        }
        .alert("次のセットを始めますか？", isPresented: Binding(
            get: { viewModel.shouldConfirmNextSet },
            set: { _ in }
        )) {
            Button("今回は終了する", role: .cancel) {
                viewModel.finishPomodoroSessionAfterBreak()
                closeCompletedStudyFlow()
            }
            Button("次のセットを始める") {
                viewModel.startNextSet()
            }
        } message: {
            Text("休憩が終了しました。次の集中セットを開始できます。")
        }
        .alert("魚が逃げてしまいました", isPresented: Binding(
            get: { viewModel.shouldPresentBackgroundFailureAlert },
            set: { isPresented in
                if !isPresented {
                    viewModel.acknowledgeBackgroundFailure()
                }
            }
        )) {
            Button("OK") {
                viewModel.acknowledgeBackgroundFailure()
            }
        } message: {
            Text("5分以上アプリを離れたため、今回の集中は終了しました。")
        }
        .sheet(
            isPresented: $showsTimeSettings
        ) {
            timeSettingsSheet
        }
        .sheet(isPresented: $showsFocusRules) {
            StudyFocusRulesSheet()
        }
        .sheet(isPresented: $showsFocusCategorySelection) {
            FocusCategorySelectionSheet(
                selectedCategoryID: viewModel.selectedCategoryID
            ) { categoryID in
                selectFocusCategory(categoryID)
            }
        }
        .sheet(
            isPresented: Binding(
                get: { studyFinishedMinutes != nil },
                set: { isPresented in
                    if !isPresented {
                        studyFinishedMinutes = nil
                    }
                }
            ),
            onDismiss: presentPendingCompletionReward
        ) {
            if let studyFinishedMinutes {
                StudyFinishedView(
                    studyMinutes: studyFinishedMinutes,
                    endReason: studyFinishedEndReason
                )
            }
        }
        .sheet(
            isPresented: Binding(
                get: { completionReward != nil },
                set: { isPresented in
                    if !isPresented {
                        completionReward = nil
                    }
                }
            ),
            onDismiss: presentPendingFishReward
        ) {
            if let completionReward {
                StudyCompletionRewardView(reward: completionReward)
            }
        }
        .fullScreenCover(
            isPresented: Binding(
                get: { fishRewardBatch != nil },
                set: { isPresented in
                    if !isPresented {
                        fishRewardBatch = nil
                    }
                }
            ),
            onDismiss: finishFishRewardPresentation
        ) {
            if let fishRewardBatch {
                if fishRewardBatch.results.count == 1, let result = fishRewardBatch.results.first {
                    FishRewardView(result: result)
                } else {
                    MultipleFishRewardView(results: fishRewardBatch.results)
                }
            }
        }
    }

    private func confirmBreakEnd() {
        guard breakEndConfirmationID != nil else { return }
        // 先に確認要求を消費し、同じ確認から終了処理を二度呼ばない。
        breakEndConfirmationID = nil
        guard viewModel.mode == .pomodoro else { return }
        guard viewModel.phase == .breakTime else { return }
        guard viewModel.isRunning else { return }
        viewModel.endPomodoroBreak()
    }

    private func handlePrimaryTimerAction() {
        if coreTutorial?.isActive == true {
            guard coreTutorial?.step == .waitingForStudyStartTap,
                  coreTutorial?.conversationIndex == CoreTutorialConversationScript.studyStart.count - 1,
                  !isCompletingCoreTutorialStudy,
                  viewModel.state == .idle,
                  viewModel.isStudyTime else { return }

            isCompletingCoreTutorialStudy = true
            coreTutorial?.didTapStudyStart()
            tutorialCompletionTask?.cancel()
            tutorialCompletionTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(700))
                guard !Task.isCancelled else { return }
                _ = viewModel.completeCoreTutorialStudyWithoutStartingSession()
            }
            return
        }

        if viewModel.isRunning {
            viewModel.pauseTimer()
            return
        }

        let isInitialStudyStart = viewModel.isStudyTime &&
            (viewModel.state == .idle || viewModel.state == .completed)
        if isInitialStudyStart,
           NotificationIntroductionSettings.shouldPresent(
               for: viewModel.mode,
               hasShown: hasShownNotificationIntroduction
           ) {
            hasShownNotificationIntroduction = true
            showsNotificationIntroduction = true
        } else {
            viewModel.resumeTimer()
        }
    }

#if DEBUG
    private func prepareShoreWaveVisualTestIfNeeded() {
        guard ProcessInfo.processInfo.arguments.contains("-shore-wave-ui-test"),
              modelContext.container.configurations.allSatisfy({ $0.isStoredInMemoryOnly }),
              let player, player.ownedFish.isEmpty else { return }
        let fish = PlayerFish(species: .clownfish)
        modelContext.insert(fish)
        player.ownedFish = [fish]
        player.activeAquariumFishIDs = [fish.id]
        player.hasInitializedActiveAquariumFish = true
    }
#endif

    private func configureStudyCompletion() {
        viewModel.onPomodoroFlowFinished = {
            Task { @MainActor in
                await Task.yield()
                presentAutomaticPomodoroRewardsIfFinished()
            }
        }
        viewModel.onFocusSessionFinalized = { session in
            do {
                // 過去日の復元結果に、今日の移行用累計を混ぜない。
                let baseline = Calendar.current.isDateInToday(session.completedAt)
                    ? (player?.todayStudyMinutes ?? 0) : 0
                try StudyHistoryService.recordValidFocusSession(
                    session,
                    existingTodayMinutesBeforeCompletion: baseline,
                    in: modelContext
                )
                guard let player else { return false }
                let pointReward = try DailyPointProgressService.process(
                    sessionID: session.id, for: player, in: modelContext
                )
                lastFinalizedPointReward = pointReward
                lastFinalizedSessionID = session.id
                try DailyFishProgressService.process(
                    sessionID: session.id,
                    for: player,
                    in: modelContext
                )
                let batch = try FishRewardBatchService.grant(
                    sessionID: session.id, to: player, pomodoroFlowID: session.pomodoroFlowID,
                    defaults: defaults, in: modelContext
                )
                lastFinalizedRewardBatch = batch
                if let batch {
                    pendingFishRewardBatches.append(batch)
                    try FishRewardBatchService.recordPoints(pointReward, for: batch, in: modelContext)
                }
                // failureにはonStudyFinishedが来ないが、確定済み有効秒数のptは失わない。
                if session.endReason == .backgroundLimitExceeded || session.endReason == .interrupted {
                    if pointReward > 0 || batch != nil {
                        queueCompletionReward(StudyCompletionReward(
                            studyReward: pointReward, streakReward: 0,
                            streakDays: player.studyStreakDays, didEarnFish: batch != nil
                        ), minutes: session.durationMinutes, sessionID: session.id,
                           flowID: session.pomodoroFlowID)
                    }
                    if session.endReason == .interrupted && session.pomodoroFlowID == nil {
                        Task { @MainActor in
                            await Task.yield()
                            presentPendingCompletionReward()
                        }
                    }
                }
                return true
            } catch {
                // 未保存結果はTimerSessionStoreへ残し、次の復元時に再送する。
                return false
            }
        }
        viewModel.onStudyFinished = {
            defer {
                lastFinalizedRewardBatch = nil
                lastFinalizedPointReward = 0
                lastFinalizedSessionID = nil
            }
            let completedStudyMinutes = viewModel.lastCompletedStudyMinutes
            studyFinishedEndReason = viewModel.lastStudySessionEndReason ?? .completed
            if !viewModel.isAutomaticPomodoroFlow { studyFinishedMinutes = completedStudyMinutes }
            guard let player else {
                queueStudyCompletionReward(StudyCompletionReward(
                    studyReward: 0,
                    streakReward: 0,
                    streakDays: 0,
                    didEarnFish: false
                ), minutes: completedStudyMinutes)
                return
            }

            if coreTutorial?.step == .reward {
                let fishResult = try? coreTutorial?.grantRewardIfNeeded(
                    to: player,
                    in: modelContext
                )
                if let fishResult {
                    pendingFishRewardBatches.append(FishRewardBatch(
                        id: UUID(), results: [fishResult], historyIDs: []
                    ))
                }
                queueStudyCompletionReward(StudyCompletionReward(
                    studyReward: CurrencyService.studyCompletionReward(
                        for: CoreTutorialRewardService.studyMinutes,
                        todayStudyMinutesBeforeCompletion: 0
                    ),
                    streakReward: 0,
                    streakDays: player.studyStreakDays,
                    didEarnFish: fishResult != nil
                ), minutes: completedStudyMinutes)
                return
            }

            // ポイントは全終了理由共通のfinalized callbackで保存済み。ここでは表示のみ。
            let awardedStudyReward = lastFinalizedPointReward
            player.todayStudyMinutes += completedStudyMinutes
            player.totalStudyMinutes += completedStudyMinutes

            guard StudyCompletionReward.isEligibleForExistingRewards(
                forStudyMinutes: completedStudyMinutes
            ) else {
                queueStudyCompletionReward(StudyCompletionReward(
                    studyReward: awardedStudyReward,
                    streakReward: 0,
                    streakDays: player.studyStreakDays,
                    didEarnFish: !pendingFishRewardBatches.isEmpty
                ), minutes: completedStudyMinutes)
                return
            }

            let streakUpdate = try? StudyStreakService.recordStudyCompletion(
                for: player,
                in: modelContext
            )

            let streakReward = streakUpdate?.awardedCoins ?? 0
            if let batch = lastFinalizedRewardBatch {
                let (totalPointDelta, overflowed) = awardedStudyReward
                    .addingReportingOverflow(streakReward)
                try? FishRewardBatchService.recordPoints(
                    overflowed ? Int.max : totalPointDelta, for: batch, in: modelContext
                )
            }

            queueStudyCompletionReward(StudyCompletionReward(
                studyReward: awardedStudyReward,
                streakReward: streakReward,
                streakDays: streakUpdate?.streakDays ?? player.studyStreakDays,
                didEarnFish: !pendingFishRewardBatches.isEmpty
            ), minutes: completedStudyMinutes)
        }
        viewModel.onBreakFinished = nil
    }

    private var timeSettingsSheet: some View {
        TimerTimeSettingsSheet(
            mode: viewModel.mode,
            studyMinutes: configuredStudyMinutes(for: viewModel.mode),
            breakMinutes: Int(storedPomodoroBreakDuration) ?? breakTime,
            setCount: pomodoroSetCount,
            autoStartNextSet: PomodoroAutoStartSettings.isEnabled(in: defaults),
            onSave: saveTimeSettings
        )
    }

    private func configurePomodoroAutoStart() {
        viewModel.configureAutoStartNextSet(
            coreTutorial?.isActive != true && coreTutorial?.isPreviewMode != true &&
            PomodoroAutoStartSettings.isEnabled(in: defaults)
        )
    }

    private func queueStudyCompletionReward(_ reward: StudyCompletionReward, minutes: Int) {
        queueCompletionReward(reward, minutes: minutes, sessionID: lastFinalizedSessionID,
                              flowID: viewModel.pomodoroFlowID)
    }

    private func queueCompletionReward(_ reward: StudyCompletionReward, minutes: Int,
                                       sessionID: UUID?, flowID: UUID?) {
        if let flowID, let sessionID {
            PomodoroFlowRewardStore.append(reward, minutes: minutes, sessionID: sessionID,
                                          flowID: flowID, defaults: defaults)
        } else {
            pendingCompletionReward = reward
        }
    }

    private func presentAutomaticPomodoroRewardsIfFinished() {
        guard viewModel.isAutomaticPomodoroFlow, viewModel.phase == .finished,
              isTimerViewVisible, scenePhase == .active, !viewModel.shouldPresentBackgroundFailureAlert,
              let flowID = viewModel.pomodoroFlowID, presentedPomodoroFlowID != flowID else { return }
        traceTimerNavigation("auto rewards: finished flow, visit marker differs")
        let batch: FishRewardBatch?
        do {
            batch = try FishRewardBatchService.batch(forPomodoroFlow: flowID, in: modelContext)
        } catch { return }
        presentedPomodoroFlowID = flowID
        // 所持魚・履歴は既に確定済み。各setを同じ既存複数魚Viewへまとめるだけ。
        pendingFishRewardBatches = batch.map { [$0] } ?? []
        if let summary = PomodoroFlowRewardStore.load(flowID: flowID, defaults: defaults) {
            pendingCompletionReward = summary.completionReward
            studyFinishedMinutes = summary.minutes
        } else {
            traceTimerNavigation("auto rewards: no saved summary; present pending")
            presentPendingCompletionReward()
        }
    }

    private func saveTimeSettings(studyMinutes: Int, breakMinutes: Int, setCount: Int,
                                  autoStartNextSet: Bool) {
        if viewModel.mode == .pomodoro {
            storedPomodoroStudyDuration = String(studyMinutes)
            if PomodoroBreakConfiguration.isBreakSelectionEnabled(setCount: setCount) {
                storedPomodoroBreakDuration = String(breakMinutes)
            }
            pomodoroSetCount = setCount
            if coreTutorial?.isActive != true && coreTutorial?.isPreviewMode != true {
                PomodoroAutoStartSettings.save(autoStartNextSet, in: defaults)
                configurePomodoroAutoStart()
            }
        } else if viewModel.mode == .countdown {
            storedTimerDuration = String(studyMinutes)
        }
        let effectiveBreakMinutes = PomodoroBreakConfiguration.effectiveBreakMinutes(
            preferredMinutes: breakMinutes,
            setCount: setCount
        )
        viewModel.updateConfiguration(
            studyTime: studyMinutes,
            breakTime: viewModel.mode == .pomodoro
                ? effectiveBreakMinutes
                : (Int(storedPomodoroBreakDuration) ?? breakTime),
            totalSets: viewModel.mode == .pomodoro ? setCount : nil
        )
    }

    private func selectTimerMode(_ mode: TimerMode) {
        viewModel.selectMode(mode)
        guard mode != .stopwatch else { return }

        let setCount = PomodoroBreakConfiguration.configuredSetCount(in: defaults)
        let preferredBreakMinutes = Int(storedPomodoroBreakDuration) ?? breakTime
        viewModel.updateConfiguration(
            studyTime: configuredStudyMinutes(for: mode),
            breakTime: PomodoroBreakConfiguration.effectiveBreakMinutes(
                preferredMinutes: preferredBreakMinutes,
                setCount: setCount
            ),
            totalSets: mode == .pomodoro ? setCount : nil
        )
    }

    private func configuredStudyMinutes(for mode: TimerMode) -> Int {
        switch mode {
        case .pomodoro:
            Int(storedPomodoroStudyDuration) ?? studyTime
        case .countdown:
            Int(storedTimerDuration) ?? TimerConfigurationStorage.defaultTimerDurationMinutes
        case .stopwatch:
            Int(storedPomodoroStudyDuration) ?? studyTime
        }
    }

    private func presentPendingCompletionReward() {
        guard !viewModel.defersPomodoroRewards else { return }
        if let pendingCompletionReward {
            completionReward = pendingCompletionReward
            self.pendingCompletionReward = nil
        } else {
            presentPendingFishReward()
        }
    }

    private func presentPendingFishReward() {
        guard !viewModel.defersPomodoroRewards else { return }
        guard fishRewardBatch == nil else { return }
        if !pendingFishRewardBatches.isEmpty {
            let batch = pendingFishRewardBatches.removeFirst()
            rewardHistoryIDs = batch.historyIDs
            fishRewardBatch = batch
        } else {
            finishStudyFlow()
        }
    }

    private func finishFishRewardPresentation() {
        try? FishRewardBatchService.acknowledge(rewardHistoryIDs, in: modelContext)
        rewardHistoryIDs = []
        if !pendingFishRewardBatches.isEmpty {
            presentPendingFishReward()
        } else {
            finishStudyFlow()
        }
    }

    private func finishStudyFlow() {
        guard !isClosingStudyFlow else { return }
        traceTimerNavigation("finishStudyFlow: pending=\(pendingFishRewardBatches.count)")
        if let flowID = presentedPomodoroFlowID {
            PomodoroFlowRewardStore.clear(flowID: flowID, defaults: defaults)
        }
        if coreTutorial?.step == .reward {
            coreTutorial?.didDismissReward()
            isCompletingCoreTutorialStudy = false
            restoreStoredTimerConfiguration()
            isClosingStudyFlow = true
            traceTimerNavigation("dismiss: tutorial reward finished")
            dismiss()
            return
        }
        if viewModel.shouldBeginPomodoroBreak {
            viewModel.beginPomodoroBreak()
        } else {
            closeCompletedStudyFlow()
        }
    }

    private func closeCompletedStudyFlow() {
        guard !isClosingStudyFlow, viewModel.finishCompletedSessionPresentation() else { return }
        isClosingStudyFlow = true
        // 前visitのsheet/onDismissや非同期callbackを、次のNavigationの条件に残さない。
        presentedPomodoroFlowID = nil
        pendingCompletionReward = nil
        completionReward = nil
        studyFinishedMinutes = nil
        pendingFishRewardBatches = []
        fishRewardBatch = nil
        rewardHistoryIDs = []
        lastFinalizedRewardBatch = nil
        lastFinalizedPointReward = 0
        lastFinalizedSessionID = nil
        traceTimerNavigation("cleanup completed; dismiss once")
        dismiss()
    }

    private func traceTimerNavigation(_ event: String) {
#if DEBUG
        TimerNavigationDiagnostics.record(event, model: viewModel)
#endif
    }

    private func timerScreenDidBecomeActive() {
        if isTimerViewVisible {
            viewModel.setAppActive(true)
            viewModel.setTimerScreenVisible(true)
        }
        presentAutomaticPomodoroRewardsIfFinished()
    }

    @ViewBuilder
    private var navigationRegressionControls: some View {
#if DEBUG
        if TimerNavigationDiagnostics.isEnabled {
            Button("テスト: phase完了") {
                TimerNavigationDiagnostics.advancePhase(of: viewModel)
            }
            .accessibilityIdentifier("timer.testCompletePhase")
            .padding(.top, 50)
        }
#endif
    }

    private var isCoreTutorialStudy: Bool {
        coreTutorial?.usesTutorialStudySetup == true
    }

    private var isStudyStartQuietOverlay: Bool {
        studyStartPresentation.isPresenting && !isCoreTutorialStudy
    }

    private var focusDisplayContext: FocusDisplayState.Context {
        .init(
            timerState: viewModel.state,
            phase: viewModel.phase,
            isActive: scenePhase == .active,
            // Start the existing ten-second timeout with running, even as the ripple fades.
            isVisible: isTimerViewVisible &&
                (!studyStartPresentation.isPresenting || studyStartPresentation.hasStarted),
            isTutorial: coreTutorial?.isActive == true || isCoreTutorialStudy
        )
    }

    private func performStudyStartPresentation() async {
        guard let id = studyStartPresentation.requestID,
              let startDeadline = studyStartPresentation.startDeadline,
              let deadline = studyStartPresentation.deadline else { return }
        let effect = studyStartPresentation.effect
        if !isCoreTutorialStudy {
            withAnimation(.easeOut(duration: effect == .ripple ? 0.25 : 0.2)) {
                studyStartControlsOpacity = 0
            }
        }
        if studyStartPresentation.effect == .fade {
            withAnimation(.easeOut(duration: studyStartPresentation.effect.startDelay)) {
                studyStartFadeProgress = 1
            }
        }
        if effect == .ripple {
            let revealDeadline = startDeadline.addingTimeInterval(-effect.runningUIFadeDuration)
            do {
                try await Task.sleep(for: .seconds(max(0, revealDeadline.timeIntervalSinceNow)))
            } catch { return }
            guard !Task.isCancelled else { return }
            guard isTimerViewVisible, scenePhase == .active,
                  StudyStartPresentation.canStart(state: viewModel.state, phase: viewModel.phase),
                  !isStudyStartDisabledForTutorial else {
                if studyStartPresentation.requestID == id { studyStartPresentation.reset() }
                return
            }
            // View-only running layout; the model is still idle until this fade completes.
            studyStartIsRevealingRunningUI = true
            withAnimation(.easeInOut(duration: effect.runningUIFadeDuration)) {
                studyStartControlsOpacity = 1
            }
        }
        do {
            try await Task.sleep(for: .seconds(max(0, startDeadline.timeIntervalSinceNow)))
        } catch { return }
        guard !Task.isCancelled else { return }
        guard isTimerViewVisible, scenePhase == .active,
              StudyStartPresentation.canStart(state: viewModel.state, phase: viewModel.phase),
              !isStudyStartDisabledForTutorial else {
            if studyStartPresentation.requestID == id { studyStartPresentation.reset() }
            return
        }
        guard studyStartPresentation.start(id: id) else { return }
        handlePrimaryTimerAction()
        do {
            try await Task.sleep(for: .seconds(max(0, deadline.timeIntervalSinceNow)))
        } catch { return }
        guard !Task.isCancelled else { return }
        _ = studyStartPresentation.complete(id: id)
    }

    @ViewBuilder
    private var sessionConfigurationControls: some View {
        if viewModel.canConfigureSession && !studyStartIsRevealingRunningUI {
            VStack(spacing: 8) {
                if viewModel.isStudyTime &&
                    !isCoreTutorialStudy {
                    HStack {
                        focusCategorySelection
                        Spacer(minLength: 0)
                    }
                }

                Picker("計測方法", selection: Binding(
                    get: { viewModel.mode },
                    set: selectTimerMode
                )) {
                    ForEach(TimerMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(5)
                .background(.black.opacity(0.14), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityIdentifier("timer.modeSelector")
                .coreTutorialTarget(.studyMode)
                .disabled(isCoreTutorialStudy)
            }
        }
    }

    @ViewBuilder
    private var focusRulesControl: some View {
        if viewModel.canConfigureSession && !studyStartIsRevealingRunningUI &&
            viewModel.isStudyTime && !isCoreTutorialStudy {
            Button {
                showsFocusRules = true
            } label: {
                Label(StudyFocusRulesContent.title, systemImage: "questionmark.circle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(.black.opacity(0.14), in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.28), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("timer.focusRules")
        }
    }

    private var timerDisplay: some View {
        HStack(spacing: 12) {
            Text(timerDisplayText)
                .accessibilityIdentifier("timer.timeDisplay")
                .font(.system(size: 72, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(viewModel.mode == .countdown ? 0.6 : 1)
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.25), radius: 10, y: 4)

            if viewModel.canConfigureSession && !studyStartIsRevealingRunningUI && viewModel.mode.showsTimeSettings {
                Button {
                    showsTimeSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(.black.opacity(0.18), in: Circle())
                }
                .accessibilityLabel("時間設定")
                .accessibilityIdentifier("timer.timeSettings")
                .coreTutorialTarget(.studySettings)
                .disabled(isCoreTutorialStudy)
            }
        }
    }

    private var timerDisplayText: String {
        viewModel.mode == .countdown
            ? formatCountdownTime(viewModel.displayedSeconds)
            : formatTime(viewModel.displayedSeconds)
    }

    private var pomodoroBreakEndButton: some View {
        Button("休憩を終える") {
            guard !showsBreakEndConfirmation else { return }
            breakEndConfirmationID = UUID()
            showsBreakEndConfirmation = true
        }
        .buttonStyle(AquariumPrimaryButtonStyle())
        .disabled(showsBreakEndConfirmation)
        .alert("休憩を終了しますか？", isPresented: $showsBreakEndConfirmation) {
            Button("キャンセル", role: .cancel) {
                breakEndConfirmationID = nil
            }
            Button("休憩を終える", role: .destructive) {
                confirmBreakEnd()
            }
        }
    }

    @ViewBuilder
    private var sessionActionControls: some View {
        if viewModel.state == .paused {
            Button("再開する") {
                viewModel.resumeTimer()
            }
            .buttonStyle(AquariumPrimaryButtonStyle())

            Button("終了する") {
                showsEndConfirmation = true
            }
            .buttonStyle(AquariumSecondaryButtonStyle())
        } else if viewModel.mode == .pomodoro && viewModel.phase == .breakTime && viewModel.isRunning {
            pomodoroBreakEndButton
        } else if viewModel.isRunning || studyStartIsRevealingRunningUI {
            Button("一時停止") {
                handlePrimaryTimerAction()
            }
            .buttonStyle(AquariumPrimaryButtonStyle())
        } else if viewModel.isStudyTime {
            Button("START") {
                guard scenePhase == .active, isTimerViewVisible,
                      !isStudyStartDisabledForTutorial,
                      !studyStartPresentation.isPresenting,
                      !showsNotificationIntroduction else { return }
                if studyStartCanvasFrame.width > 0 && !studyStartButtonFrame.isEmpty {
                    studyStartOrigin = CGPoint(
                        x: (studyStartButtonFrame.midX - studyStartCanvasFrame.minX) / studyStartCanvasFrame.width,
                        y: (studyStartButtonFrame.midY - studyStartCanvasFrame.minY) / studyStartCanvasFrame.height
                    )
                }
                studyStartPresentation.begin(
                    state: viewModel.state, phase: viewModel.phase,
                    reduceMotion: reduceMotion, isTutorial: isCoreTutorialStudy
                )
            }
            .buttonStyle(StudyStartButtonStyle())
            .onGeometryChange(for: CGRect.self) { geometry in
                geometry.frame(in: .global)
            } action: { frame in
                studyStartButtonFrame = frame
            }
            .coreTutorialTarget(.studyStart)
            .disabled(isStudyStartDisabledForTutorial || studyStartPresentation.isPresenting || showsNotificationIntroduction)
            .accessibilityHidden(isStudyStartHiddenForTutorial)
            .accessibilityIdentifier("timer.startStudy")
        } else {
            Button("休憩開始") {
                handlePrimaryTimerAction()
            }
            .buttonStyle(AquariumPrimaryButtonStyle())
        }
    }

    private var isStudyStartDisabledForTutorial: Bool {
        isCompletingCoreTutorialStudy || isStudyStartHiddenForTutorial
    }

    private var isStudyStartHiddenForTutorial: Bool {
        isCoreTutorialStudy &&
            (coreTutorial?.step != .waitingForStudyStartTap ||
                coreTutorial?.conversationIndex != CoreTutorialConversationScript.studyStart.count - 1)
    }

    @ViewBuilder
    private var pomodoroProgress: some View {
        if viewModel.mode == .pomodoro {
            HStack(spacing: 6) {
                ForEach(1...max(viewModel.totalSets, 1), id: \.self) { setNumber in
                    PomodoroProgressFish(isReached: setNumber <= viewModel.currentSet)
                }

                Text("/ \(viewModel.totalSets)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))
                    .padding(.leading, 2)
            }
            .frame(height: 22)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("ポモドーロの進捗")
            .accessibilityValue("\(viewModel.currentSet) / \(viewModel.totalSets)セット")
        }
    }

    private var activeFocusCategoryIDs: [String] {
        activeFocusCategories.map(\.id)
    }

    private var selectedFocusCategory: FocusCategory? {
        activeFocusCategories.first { $0.id == viewModel.selectedCategoryID }
    }

    private var activeFocusCategories: [FocusCategory] {
        focusCategories.filter { !$0.isArchived }
    }

    private var focusCategorySelection: some View {
        Button {
            showsFocusCategorySelection = true
        } label: {
            focusCategorySelectionLabel
        }
        .buttonStyle(.plain)
        .accessibilityLabel("集中カテゴリ")
        .accessibilityValue(selectedFocusCategory?.name ?? "勉強")
        .accessibilityIdentifier("timer.focusCategory")
    }

    private var focusCategorySelectionLabel: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(
                    selectedFocusCategory?.swiftUIColor
                        ?? FocusCategoryColorKey.studyBlue.swiftUIColor
                )
                .frame(width: 9, height: 9)

            Text(selectedFocusCategory?.name ?? "勉強")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)

            Image(systemName: "chevron.down")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.72))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .frame(minHeight: 36)
        .contentShape(Capsule())
    }

    private func selectFocusCategory(_ categoryID: String) {
        FocusCategorySelectionStore.select(
            categoryID, in: viewModel, categories: focusCategories, defaults: defaults,
            isTutorial: coreTutorial?.isActive == true || coreTutorial?.isPreviewMode == true
        )
    }

    private func initializeFocusCategorySelection() {
        // Queryへの反映待ちで、保存済みのマイカテゴリを不存在と誤判定しない。
        guard let categories = try? FocusCategoryService.createDefaultsIfNeeded(in: modelContext) else { return }
        FocusCategorySelectionStore.restore(
            to: viewModel, categories: categories, defaults: defaults,
            isTutorial: coreTutorial?.isActive == true || coreTutorial?.isPreviewMode == true
        )
    }

    private func ensureSelectedFocusCategoryIsActive() {
        let resolvedID = FocusCategoryService.resolvedSelectionID(
            viewModel.selectedCategoryID,
            from: focusCategories
        )
        guard resolvedID != viewModel.selectedCategoryID else { return }
        viewModel.selectCategory(resolvedID)
    }

    @ViewBuilder
    private func coreTutorialStudyOverlay(
        targets: [CoreTutorialTarget: Anchor<CGRect>],
        geometry: GeometryProxy
    ) -> some View {
        if coreTutorial?.step == .studySetupIntro {
            let pages = CoreTutorialConversationScript.studyMode
            let index = coreTutorial?.conversationIndex ?? 0
            CoreTutorialSpotlightStep(
                targetFrame: targets[.studyMode].map { geometry[$0] },
                page: coreTutorialConversationPage(in: pages, at: index),
                pageIndex: index,
                onConversationAdvance: {
                    if coreTutorial?.advanceConversation(totalCount: pages.count) == true {
                        coreTutorial?.dismissStudySetupIntro()
                    }
                },
                accessibilityIdentifier: "coreTutorial.studyModeIntro"
            )
        } else if coreTutorial?.step == .studySettingsIntro {
            let pages = CoreTutorialConversationScript.studySettings
            let index = coreTutorial?.conversationIndex ?? 0
            CoreTutorialSpotlightStep(
                targetFrame: targets[.studySettings].map { geometry[$0] },
                page: coreTutorialConversationPage(in: pages, at: index),
                pageIndex: index,
                onConversationAdvance: {
                    if coreTutorial?.advanceConversation(totalCount: pages.count) == true {
                        coreTutorial?.dismissStudySetupIntro()
                    }
                },
                accessibilityIdentifier: "coreTutorial.studySettingsIntro"
            )
        } else if coreTutorial?.step == .waitingForStudyStartTap {
            let pages = CoreTutorialConversationScript.studyStart
            let index = coreTutorial?.conversationIndex ?? 0
            let isStartInteractionPage = index == pages.count - 1
            CoreTutorialSpotlightStep(
                targetFrame: isStartInteractionPage
                    ? targets[.studyStart].map { geometry[$0] }
                    : nil,
                page: coreTutorialConversationPage(in: pages, at: index),
                pageIndex: index,
                showsPointingHand: isStartInteractionPage,
                allowsConversationAdvance: !isStartInteractionPage,
                allowsTargetInteraction: isStartInteractionPage,
                onConversationAdvance: {
                    _ = coreTutorial?.advanceConversation(totalCount: pages.count)
                },
                accessibilityIdentifier: "coreTutorial.studyStartPrompt"
            )
        }
    }

    private func prepareCoreTutorialStudyIfNeeded() {
        guard coreTutorial?.usesTutorialStudySetup == true else { return }
        viewModel.resetTimer()
        viewModel.selectMode(.pomodoro)
        viewModel.selectCategory(FocusCategoryDefaults.studyID)
        viewModel.updateConfiguration(
            studyTime: CoreTutorialRewardService.studyMinutes,
            breakTime: PomodoroBreakConfiguration.defaultBreakMinutes,
            totalSets: PomodoroBreakConfiguration.defaultSetCount
        )
    }

    private func restoreStoredTimerConfiguration() {
        guard !viewModel.isRunning else { return }
        let setCount = PomodoroBreakConfiguration.configuredSetCount(in: defaults)
        let storedBreakMinutes = Int(storedPomodoroBreakDuration) ?? breakTime
        viewModel.resetTimer()
        viewModel.updateConfiguration(
            studyTime: Int(storedPomodoroStudyDuration) ?? studyTime,
            breakTime: PomodoroBreakConfiguration.effectiveBreakMinutes(
                preferredMinutes: storedBreakMinutes,
                setCount: setCount
            ),
            totalSets: setCount
        )
        configurePomodoroAutoStart()
    }
}

private struct FocusDisplayControlsModifier: ViewModifier {
    let isHidden: Bool

    func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .contain)
            .opacity(isHidden ? 0 : 1)
            .allowsHitTesting(!isHidden)
            .accessibilityHidden(isHidden)
            .animation(.easeInOut(duration: FocusDisplayState.fadeDuration), value: isHidden)
    }
}

struct TimerFocusDisplayPreferenceKey: PreferenceKey {
    static let defaultValue = false

    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

private struct CoreTutorialStudyStartingShield: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.12)
                .contentShape(Rectangle())

            ProgressView()
                .tint(.white)
                .controlSize(.large)
                .padding(18)
                .background(.ultraThinMaterial, in: Circle())
        }
        .ignoresSafeArea()
        .allowsHitTesting(true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("集中完了を準備中")
        .accessibilityAddTraits(.isModal)
        .accessibilityIdentifier("coreTutorial.studyStartingShield")
    }
}

private struct FocusCategorySelectionSheet: View {
    let selectedCategoryID: String
    let onSelected: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var focusCategories: [FocusCategory]
    @State private var showsCreation = false
    @State private var dismissAfterCreation = false
    @State private var archiveErrorMessage: String?

    private var orderedDefaultCategories: [FocusCategory] {
        FocusCategoryService.ordered(
            focusCategories.filter { $0.isDefault && !$0.isArchived }
        )
    }

    private var customCategories: [FocusCategory] {
        focusCategories
            .filter { !$0.isDefault && !$0.isArchived }
            .sorted {
                $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        showsCreation = true
                    } label: {
                        Label("カテゴリを追加", systemImage: "plus")
                    }
                }

                Section("標準カテゴリ") {
                    ForEach(orderedDefaultCategories) { category in
                        categorySelectionButton(for: category)
                    }
                }

                if !customCategories.isEmpty {
                    Section("マイカテゴリ") {
                        ForEach(customCategories) { category in
                            categorySelectionButton(for: category)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        archive(category)
                                    } label: {
                                        Label("削除", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }
            .navigationTitle("集中カテゴリ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .sheet(
            isPresented: $showsCreation,
            onDismiss: {
                guard dismissAfterCreation else { return }
                dismissAfterCreation = false
                dismiss()
            }
        ) {
            FocusCategoryCreationSheet { categoryID in
                onSelected(categoryID)
                dismissAfterCreation = true
            }
        }
        .alert(
            "カテゴリを削除できませんでした",
            isPresented: Binding(
                get: { archiveErrorMessage != nil },
                set: { if !$0 { archiveErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(archiveErrorMessage ?? "")
        }
    }

    private func categorySelectionButton(for category: FocusCategory) -> some View {
        Button {
            onSelected(category.id)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(category.swiftUIColor)
                    .frame(width: 12, height: 12)

                Text(category.name)
                    .foregroundStyle(.primary)

                Spacer()

                if selectedCategoryID == category.id {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func archive(_ category: FocusCategory) {
        do {
            try FocusCategoryService.archive(category, in: modelContext)
            if selectedCategoryID == category.id {
                onSelected(FocusCategoryDefaults.studyID)
            }
        } catch {
            archiveErrorMessage = error.localizedDescription
        }
    }
}

private struct FocusCategoryCreationSheet: View {
    let onCreated: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var categoryName = ""
    @State private var selectedColor = FocusCategoryColorKey.oceanTeal.swiftUIColor
    @State private var showsColorSelection = false
    @State private var errorMessage: String?

    private var trimmedName: String {
        categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("カテゴリ名") {
                    TextField("例：数学", text: $categoryName)
                        .textInputAutocapitalization(.never)
                        .submitLabel(.done)
                        .onChange(of: categoryName) { _, newValue in
                            if newValue.count > FocusCategoryService.maximumNameLength {
                                categoryName = String(
                                    newValue.prefix(FocusCategoryService.maximumNameLength)
                                )
                            }
                            errorMessage = nil
                        }

                    HStack {
                        if let errorMessage {
                            Text(errorMessage)
                                .foregroundStyle(.red)
                        }
                        Spacer(minLength: 8)
                        Text("\(categoryName.count)/\(FocusCategoryService.maximumNameLength)")
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                }

                Section("色") {
                    Button {
                        showsColorSelection = true
                    } label: {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(selectedColor)
                                .frame(width: 28, height: 28)
                                .overlay {
                                    Circle()
                                        .stroke(.primary.opacity(0.18), lineWidth: 1)
                                }
                                .accessibilityHidden(true)

                            Text("カラーを選択")
                                .foregroundStyle(.primary)

                            Spacer(minLength: 0)

                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("カテゴリを追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { saveCategory() }
                        .disabled(trimmedName.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
        .sheet(isPresented: $showsColorSelection) {
            FocusCategoryColorSelectionSheet(initialColor: selectedColor) { color in
                selectedColor = color
                errorMessage = nil
            }
        }
    }

    private func saveCategory() {
        do {
            guard let customHex = selectedColor.opaqueFocusCategoryHex else {
                throw FocusCategoryService.CreationError.invalidColor
            }
            let category = try FocusCategoryService.createCustom(
                name: categoryName,
                customHex: customHex,
                in: modelContext
            )
            onCreated(category.id)
            dismiss()
        } catch let error as FocusCategoryService.CreationError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "カテゴリを保存できませんでした"
        }
    }
}

private struct FocusCategoryColorSelectionSheet: View {
    let onComplete: (Color) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var pendingColor: Color

    init(initialColor: Color, onComplete: @escaping (Color) -> Void) {
        self.onComplete = onComplete
        self._pendingColor = State(initialValue: initialColor)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ColorPicker(
                        "カラー",
                        selection: $pendingColor,
                        supportsOpacity: false
                    )
                }

                Section("現在の色") {
                    HStack {
                        Spacer()
                        Circle()
                            .fill(pendingColor)
                            .frame(width: 64, height: 64)
                            .overlay {
                                Circle()
                                    .stroke(.primary.opacity(0.18), lineWidth: 1)
                            }
                            .accessibilityLabel("現在選択中の色")
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("カラーを選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") {
                        onComplete(pendingColor)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private struct StudyFocusRulesSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Label {
                    Text(StudyFocusRulesContent.keepScreenOpen)
                } icon: {
                    Image(systemName: "iphone")
                        .foregroundStyle(.cyan)
                }

                Label {
                    Text(StudyFocusRulesContent.backgroundLimit)
                } icon: {
                    Image(systemName: "clock.badge.exclamationmark")
                        .foregroundStyle(.cyan)
                }

                Spacer(minLength: 0)
            }
            .font(.body)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .navigationTitle(StudyFocusRulesContent.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
        .presentationDetents([.height(280)])
    }
}

private struct TimerTimeSettingsSheet: View {
    let mode: TimerMode
    let onSave: (Int, Int, Int, Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var studyMinutes: Int
    @State private var breakMinutes: Int
    @State private var timerHours: Int
    @State private var timerMinuteComponent: Int
    @State private var setCount: Int
    @State private var retainedBreakMinutes: Int
    @State private var autoStartNextSet: Bool

    init(
        mode: TimerMode,
        studyMinutes: Int,
        breakMinutes: Int,
        setCount: Int,
        autoStartNextSet: Bool,
        onSave: @escaping (Int, Int, Int, Bool) -> Void
    ) {
        self.mode = mode
        self.onSave = onSave
        _autoStartNextSet = State(initialValue: autoStartNextSet)
        let editableTimerMinutes = min(
            max(studyMinutes, CountdownDurationConfiguration.totalMinutesRange.lowerBound),
            CountdownDurationConfiguration.totalMinutesRange.upperBound
        )
        let timerComponents = CountdownDurationComponents(totalMinutes: editableTimerMinutes)

        _studyMinutes = State(initialValue: studyMinutes)
        _breakMinutes = State(initialValue: PomodoroBreakConfiguration.effectiveBreakMinutes(
            preferredMinutes: breakMinutes,
            setCount: setCount
        ))
        _timerHours = State(initialValue: timerComponents.hours)
        _timerMinuteComponent = State(initialValue: timerComponents.minutes)
        _setCount = State(initialValue: setCount)
        _retainedBreakMinutes = State(initialValue: max(
            breakMinutes,
            PomodoroBreakConfiguration.defaultBreakMinutes
        ))
    }

    var body: some View {
        NavigationStack {
            VStack {
                if mode == .pomodoro {
                    HStack(alignment: .top, spacing: 4) {
                        pickerColumn(
                            title: "集中時間",
                            selection: $studyMinutes,
                            values: 1...180,
                            suffix: "分"
                        )

                        pickerColumn(
                            title: "休憩時間",
                            selection: $breakMinutes,
                            values: 0...60,
                            suffix: "分"
                        )
                        .disabled(!PomodoroBreakConfiguration.isBreakSelectionEnabled(
                            setCount: setCount
                        ))
                        .opacity(PomodoroBreakConfiguration.isBreakSelectionEnabled(
                            setCount: setCount
                        ) ? 1 : 0.42)

                        pickerColumn(
                            title: "セット数",
                            selection: $setCount,
                            values: 1...10,
                            suffix: "セット"
                        )
                    }
                    autoStartSetting
                } else {
                    durationPicker(
                        title: "集中時間",
                        hours: $timerHours,
                        minutes: $timerMinuteComponent,
                        maximumTotalMinutes: CountdownDurationConfiguration.totalMinutesRange.upperBound
                    )

                    if timerTotalMinutes == 0 {
                        Text("タイマー時間は1分以上に設定してください")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.top, 14)
            .onChange(of: timerHours) { _, newHours in
                timerMinuteComponent = min(
                    timerMinuteComponent,
                    CountdownDurationConfiguration.maximumMinuteComponent(
                        hours: newHours,
                        maximumTotalMinutes: CountdownDurationConfiguration.totalMinutesRange.upperBound
                    )
                )
            }
            .onChange(of: setCount) { oldSetCount, newSetCount in
                if newSetCount == 1 {
                    if oldSetCount > 1 {
                        retainedBreakMinutes = breakMinutes
                    }
                    breakMinutes = 0
                } else if oldSetCount == 1 {
                    breakMinutes = retainedBreakMinutes
                }
            }
            .navigationTitle(mode == .pomodoro ? "ポモドーロ設定" : "タイマー設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let savedStudyMinutes = mode == .countdown
                            ? timerTotalMinutes
                            : studyMinutes
                        onSave(savedStudyMinutes, breakMinutes, setCount, autoStartNextSet)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
        .presentationDetents([.height(mode == .pomodoro ? 420 : 300)])
    }

    private var autoStartSetting: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("超集中モード", isOn: $autoStartNextSet)
            Text(PomodoroAutoStartSettings.explanation)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 8)
    }

    private var timerTotalMinutes: Int {
        CountdownDurationComponents(
            hours: timerHours,
            minutes: timerMinuteComponent
        ).totalMinutes
    }

    private var canSave: Bool {
        guard mode == .countdown else { return true }
        return CountdownDurationConfiguration.isValidDuration(
            hours: timerHours,
            minutes: timerMinuteComponent
        )
    }

    private func durationPicker(
        title: String,
        hours: Binding<Int>,
        minutes: Binding<Int>,
        maximumTotalMinutes: Int
    ) -> some View {
        let maximumHours = maximumTotalMinutes / 60
        let maximumMinutes = CountdownDurationConfiguration.maximumMinuteComponent(
            hours: hours.wrappedValue,
            maximumTotalMinutes: maximumTotalMinutes
        )

        return VStack(spacing: 0) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                componentPicker(
                    accessibilityLabel: "\(title)の時間",
                    selection: hours,
                    values: 0...maximumHours,
                    suffix: "時間"
                )
                componentPicker(
                    accessibilityLabel: "\(title)の分",
                    selection: minutes,
                    values: 0...maximumMinutes,
                    suffix: "分"
                )
            }
        }
    }

    private func componentPicker(
        accessibilityLabel: String,
        selection: Binding<Int>,
        values: ClosedRange<Int>,
        suffix: String
    ) -> some View {
        Picker(accessibilityLabel, selection: selection) {
            ForEach(values, id: \.self) { value in
                Text("\(value)\(suffix)")
                    .tag(value)
            }
        }
        .pickerStyle(.wheel)
        .labelsHidden()
        .frame(maxWidth: .infinity)
        .frame(height: 105)
        .clipped()
    }

    private func pickerColumn(
        title: String,
        selection: Binding<Int>,
        values: ClosedRange<Int>,
        suffix: String
    ) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Picker(title, selection: selection) {
                ForEach(values, id: \.self) { value in
                    Text("\(value)\(suffix)").tag(value)
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            .frame(height: 170)
            .clipped()
        }
        .frame(maxWidth: .infinity)
    }
}

func formatTime(_ seconds: Int) -> String {
    let minutes = seconds / 60
    let seconds = seconds % 60
    
    return String(format: "%02d:%02d", minutes, seconds)
}

func formatCountdownTime(_ seconds: Int) -> String {
    let nonnegativeSeconds = max(seconds, 0)
    let hours = nonnegativeSeconds / 3600
    let minutes = (nonnegativeSeconds % 3600) / 60
    let seconds = nonnegativeSeconds % 60

    guard hours > 0 else {
        return String(format: "%02d:%02d", minutes, seconds)
    }
    return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
}

#Preview {
    TimerView(
        studyTime: 25,
        breakTime: 5,
        player: nil
    )
}
