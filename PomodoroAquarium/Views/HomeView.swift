//
//  HomeView.swift
//  PomodoroAquarium
//
//  Created by 阿部弦生 on 2026/07/11.
//

import SwiftUI
import SwiftData

enum HomeViewMode {
    case home
    case aquariumEditor
}

private enum HomeStatusRowLayout {
    static let spacing: CGFloat = 8
    static let cardHeight: CGFloat = 36
    static let cornerRadius: CGFloat = 13
    static let sideWidthRatio: CGFloat = 0.25
}

struct HomePlayerInitializationResult {
    let player: Player
    let didCreatePlayer: Bool
    let didInitializeAquariumSelection: Bool
}

@MainActor
enum HomePlayerInitialization {
    /// `@Query` の更新前でも既存Playerを再利用し、Homeの再表示で重複生成しない。
    static func prepare(in modelContext: ModelContext) throws -> HomePlayerInitializationResult {
        var descriptor = FetchDescriptor<Player>()
        descriptor.fetchLimit = 1

        let existingPlayer = try modelContext.fetch(descriptor).first
        let player = existingPlayer ?? Player()
        let didCreatePlayer = existingPlayer == nil
        if didCreatePlayer {
            modelContext.insert(player)
        }

        let didInitializeAquariumSelection = AquariumFishSelection.initializeIfNeeded(
            for: player
        )
        if didCreatePlayer || didInitializeAquariumSelection {
            try modelContext.save()
        }

        return HomePlayerInitializationResult(
            player: player,
            didCreatePlayer: didCreatePlayer,
            didInitializeAquariumSelection: didInitializeAquariumSelection
        )
    }
}

private extension View {
    func homeStatusGlass() -> some View {
        background {
            RoundedRectangle(
                cornerRadius: HomeStatusRowLayout.cornerRadius,
                style: .continuous
            )
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(
                    cornerRadius: HomeStatusRowLayout.cornerRadius,
                    style: .continuous
                )
                .fill(.cyan.opacity(0.1))
            }
            .overlay {
                RoundedRectangle(
                    cornerRadius: HomeStatusRowLayout.cornerRadius,
                    style: .continuous
                )
                .stroke(.white.opacity(0.5), lineWidth: 1)
            }
            .shadow(color: .cyan.opacity(0.1), radius: 5, y: 2)
        }
    }
}

struct HomeView: View {
    let timerViewModel: TimerViewModel
    var mode: HomeViewMode = .home
    var allowsEditorDraftRestoration = true
    var isAquariumSimulationPaused = false
    var isAquariumEditorActive = false
    var aquariumEditorNavigation: AquariumEditorNavigationCoordinator?
    var onFinishAquariumEditing: (MainAppTab) -> Void = { _ in }
    var areAquariumViewingControlsVisible = true
    var onAquariumViewingInteraction: () -> Void = {}
    var homeNavigationResetRequestID: UUID?
    var appDefaults: UserDefaults = .standard
    var coreTutorial: CoreTutorialCoordinator?
    var showsCoreTutorialCompletion = false
    var coreTutorialCompletionButtonTitle = "はじめる"
    var onDismissCoreTutorialCompletion: () -> Void = {}
    
    @AppStorage(TimerConfigurationStorageKey.pomodoroStudyDuration)
    private var studyTime = "25"
    @AppStorage(TimerConfigurationStorageKey.pomodoroBreakDuration)
    private var breakTime = "5"
    @AppStorage("lastStudyDate") private var lastStudyDate = ""
    @AppStorage(AquariumThemeStore.storageKey)
    private var backgroundThemeRawValue = AquariumBackgroundTheme.aquarium.rawValue
    @AppStorage(AquariumEditorTutorialState.storageKey)
    private var hasSeenAquariumEditorTutorial = false
    @AppStorage(DailyFishAcquisitionStorageKey.count)
    private var storedDailyFishAcquisitionCount = 0
    @AppStorage(DailyFishAcquisitionStorageKey.dayIdentifier)
    private var storedDailyFishAcquisitionDayIdentifier = ""
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    
    @Query private var players: [Player]
    @Query private var officialDecorationPlacements: [AquariumDecorationPlacement]
    @State private var editorHistory: AquariumEditorHistory?
    @State private var editorWorkingState: AquariumEditorWorkingState?
    @State private var editorPersistenceError: String?
    @State private var showsEditorCancelConfirmation = false
    private var decorationPlacements: [AquariumDecorationPlacement] {
        editorWorkingState?.placements ?? officialDecorationPlacements
    }
    @State private var showsInterruptionBanner = false
    @State private var showsTimerScreen = false
    @State private var homeStartTransition = HomeStartTransitionState()
    @State private var dailyMessageDate = Date.now
    @State private var fishSpawnPositions: [UUID: CGPoint] = [:]
    @State private var fishAppearances: [UUID: AquariumFishAppearance] = [:]
    @State private var editingFishPositions: [UUID: CGPoint] = [:]
    @State private var canvasFrame: CGRect = .zero
    @State private var showsEditorLibrary = false
    @State private var isFishLibraryCompact = false
    @State private var showsActiveFishLibrary = false
    @State private var isEditingAquarium = false
    @State private var aquariumEditorCategory: AquariumEditorCategory = .fish
    @State private var selectedAquariumFishID: UUID?
    @State private var aquariumSelectionResetRequestID: UUID?
    @State private var fishDragSession: AquariumFishDragSession?
    @State private var decorationDragSession: AquariumDecorationDragSession?
    @State private var isEditorPanelExpanded = true
    @State private var draftBackgroundTheme: AquariumBackgroundTheme?
    @State private var showsAquariumEditConfirmation = false
    @State private var showsAquariumCapacityAlert = false
    @State private var showsEditorSaveConfirmation = false
    @State private var showsAquariumEditorTutorial = false
    // 旧編集overlayは新UIの検証完了まで実装を保持し、表示経路だけ切り替える。
    @State private var isEditingDecoration = false
    @State private var showsDecorationStorage = false
    @State private var decorationRestoreRequestID: String?
    @State private var selectedDecorationCategory: AquariumDecorationCategory?
    @State private var showsBackgroundThemePicker = false
    @State private var originalBackgroundTheme: AquariumBackgroundTheme?
    @State private var previewBackgroundTheme: AquariumBackgroundTheme?
    @State private var showsDailyFishLimitInformation = false
    
    private var player: Player? {
        editorWorkingState?.player ?? players.first
    }

    private var isHomeStartTutorialInteractionAllowed: Bool {
        coreTutorial?.isActive == true &&
            coreTutorial?.step == .waitingForHomeStartTap &&
            coreTutorial?.conversationIndex == CoreTutorialConversationScript.homeStart.count - 1
    }

    private var isAquariumEditTutorialInteractionAllowed: Bool {
        coreTutorial?.isActive == true &&
            coreTutorial?.step == .aquariumIntro &&
            coreTutorial?.conversationIndex == CoreTutorialConversationScript.aquariumIntro.count - 1
    }

    private var isAquariumDoneTutorialInteractionAllowed: Bool {
        coreTutorial?.isActive == true &&
            coreTutorial?.step == .waitingForAquariumSave &&
            coreTutorial?.conversationIndex == CoreTutorialConversationScript.aquariumSave.count - 1
    }

    private var storedDecorations: [AquariumDecorationPlacement] {
        AquariumDecorationService.storedPlacements(from: decorationPlacements)
    }

    private var filteredStoredDecorations: [AquariumDecorationPlacement] {
        AquariumDecorationService.storedPlacements(
            from: decorationPlacements,
            category: selectedDecorationCategory
        )
    }

    private var savedBackgroundTheme: AquariumBackgroundTheme {
        AquariumThemeStore.theme(from: backgroundThemeRawValue)
    }

    private var displayedBackgroundTheme: AquariumBackgroundTheme {
        if mode == .aquariumEditor, let draftBackgroundTheme {
            return draftBackgroundTheme
        }
        return savedBackgroundTheme
    }

    private var isAquariumEditorPresented: Bool {
        if mode == .aquariumEditor {
            return aquariumEditorNavigation?.tabMode == .editing
        }
        return isEditingAquarium
    }

    private var hasUnsavedAquariumEditorChanges: Bool {
        aquariumEditorNavigation?.hasUnsavedChanges ?? false
    }

    private var isDecorationOperationFocused: Bool {
        AquariumDecorationEditingPresentation.isFocused(
            isEditing: isAquariumEditorPresented,
            isDecorationCategory: aquariumEditorCategory == .decoration,
            hasSelection: isEditingDecoration
        )
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let editorWidth = AquariumSideEditorLayout.width(for: geometry.size.width)
                let aquariumWidth = geometry.size.width
                let aquariumSize = CGSize(width: aquariumWidth, height: geometry.size.height)

                ZStack(alignment: .trailing) {
                    AquariumView(
                        player: player,
                        backgroundTheme: displayedBackgroundTheme,
                        fishSpawnPositions: fishSpawnPositions,
                        fishAppearances: fishAppearances,
                        onFishPositionsChanged: { editingFishPositions = $0 },
                        onCanvasGeometryChanged: { canvasFrame = $0 },
                        isSimulationPaused: isAquariumSimulationPaused,
                        isEditing: isAquariumEditorPresented && !showsEditorLibrary,
                        defersDecorationPersistence: mode == .aquariumEditor,
                        isFishSelectionEnabled: isAquariumEditorPresented && !showsEditorLibrary,
                        selectedFishID: selectedAquariumFishID,
                        onFishSelected: selectAquariumFish,
                        onCanvasTapped: clearAquariumSelections,
                        onDecorationChanged: markAquariumEditorChanged,
                        onDecorationEditingChanged: { isEditing in
                            updateDecorationEditingState(isEditing: isEditing)
                            if isEditing {
                                selectedAquariumFishID = nil
                            }
                        },
                        selectionResetRequestID: aquariumSelectionResetRequestID,
                        decorationRestoreRequestID: decorationRestoreRequestID,
                        onDecorationRestoreRequestHandled: { decorationRestoreRequestID = nil },
                        decorationDragPreview: decorationPreview(in: aquariumSize),
                        editingPlacements: editorWorkingState?.placements
                    )
                    .frame(width: aquariumWidth, height: geometry.size.height)
                    .contentShape(Rectangle())
                    .dropDestination(for: AquariumEditorDragItem.self) { items, location in
                        handleAquariumDrop(
                            items,
                            at: location,
                            aquariumSize: aquariumSize
                        )
                    }
                    .accessibilityHidden(coreTutorial?.isActive == true)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .animation(.easeInOut(duration: 0.22), value: isAquariumEditorPresented)

                    if mode == .home, !isAquariumEditorPresented {
                        regularHomeControls
                    }

                    if mode == .aquariumEditor, !isAquariumEditorPresented {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onAquariumViewingInteraction()
                            }
                            .accessibilityElement()
                            .accessibilityLabel("水槽")
                            .accessibilityHidden(coreTutorial?.isActive == true)
                            .accessibilityIdentifier("aquariumViewing.tapSurface")
                            .zIndex(15)

                        aquariumEditingEntryControl
                            .opacity(areAquariumViewingControlsVisible ? 1 : 0)
                            .allowsHitTesting(areAquariumViewingControlsVisible)
                            .accessibilityHidden(!areAquariumViewingControlsVisible)
                            .animation(
                                .easeInOut(duration: AquariumViewingControlsPolicy.fadeDuration),
                                value: areAquariumViewingControlsVisible
                            )
                    }

                    if isAquariumEditorPresented {
                        selectedFishRemovalControl
                        fullCanvasEditorControls(size: aquariumSize)
                        if showsEditorLibrary {
                            AquariumEditorSheet(placements: decorationPlacements, player: player,
                                backgroundTheme: displayedBackgroundTheme, editorCategory: aquariumEditorCategory,
                                selectedFishID: selectedAquariumFishID, showsActiveFish: $showsActiveFishLibrary,
                                addDecoration: addDecorationFromSheet,
                                selectPlacement: { id in showsEditorLibrary = false; decorationRestoreRequestID = id },
                                addFish: addFishFromLibrary, storeFish: storeAquariumFish,
                                selectFish: { id in selectAquariumFish(id); showsEditorLibrary = false },
                                close: { showsEditorLibrary = false },
                                selectBackground: { theme in selectBackground(theme); showsEditorLibrary = false },
                                storeAllFish: { storeAllAquariumItems(.fish) },
                                storeAllDecorations: { storeAllAquariumItems(.decorations) })
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .opacity(fishDragSession == nil ? 1 : 0)
                            .zIndex(40)
                        }

                        if let fishDragSession {
                            AquariumFishDragPreview(species: fishDragSession.species)
                                .position(fishDragSession.location)
                                .zIndex(50)
                        }

                        if showsAquariumEditorTutorial {
                            aquariumEditorTutorial(aquariumWidth: aquariumWidth)
                                .zIndex(60)
                        }
                    }

                    if showsInterruptionBanner {
                        VStack {
                            interruptionBanner
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                            .zIndex(40)
                    }

                }
                .coordinateSpace(name: AquariumEditorCoordinateSpace.name)
                .animation(.easeInOut(duration: 0.22), value: isEditorPanelExpanded)
                .animation(.easeInOut(duration: 0.20), value: isDecorationOperationFocused)
                .overlayPreferenceValue(CoreTutorialTargetPreferenceKey.self) { targets in
                    coreTutorialOverlay(
                        geometry: geometry,
                        aquariumWidth: aquariumWidth,
                        editorWidth: editorWidth,
                        targets: targets
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showsTimerScreen) {
                TimerView(
                    studyTime: Int(studyTime) ?? 25,
                    breakTime: Int(breakTime) ?? 5,
                    player: player,
                    viewModel: timerViewModel,
                    coreTutorial: coreTutorial,
                    defaults: appDefaults
                )
            }
        }
        // NavigationStackの安全領域の背景だけを覆い、一覧の見出しは移動しない。
        .overlay(alignment: .top) {
            if showsEditorLibrary {
                GeometryReader { geometry in
                    Color(red: 0.78, green: 0.94, blue: 0.98)
                        .frame(height: geometry.safeAreaInsets.top)
                        .offset(y: -geometry.safeAreaInsets.top)
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
        .preference(
            key: AquariumDecorationEditingPreferenceKey.self,
            value: isAquariumEditorPresented && (mode != .aquariumEditor || isAquariumEditorActive)
        )
        .onAppear {
            if mode == .home {
                inspectPersistedTimerSession()
                DailyFishAcquisitionStore.resetIfNeeded(defaults: appDefaults)
            }
        }
        .task {
            await initializeHomeDataAfterAppearance()
            restoreAquariumEditorDraftIfNeeded()
        }
        .task(id: homeStartTransition.requestID) {
            guard let id = homeStartTransition.requestID else { return }
            do {
                try await Task.sleep(for: .seconds(HomeStartTransitionState.navigationDelay))
            } catch {
                return
            }
            guard !Task.isCancelled,
                  scenePhase == .active,
                  !showsTimerScreen,
                  coreTutorial?.isActive != true || isHomeStartTutorialInteractionAllowed,
                  homeStartTransition.consume(id: id) else { return }
            coreTutorial?.didTapHomeStart()
#if DEBUG
            TimerNavigationDiagnostics.record("Home.navigation request", model: timerViewModel)
#endif
            showsTimerScreen = true
        }
        .task(id: scenePhase) {
            guard mode == .home, scenePhase == .active else { return }
            // A single midnight wake-up, not a periodic timer or an animation.
            while !Task.isCancelled {
                dailyMessageDate = .now
                let calendar = Calendar.current
                guard let nextDay = calendar.date(
                    byAdding: .day,
                    value: 1,
                    to: calendar.startOfDay(for: dailyMessageDate)
                ) else { return }
                do {
                    try await Task.sleep(for: .seconds(max(1, nextDay.timeIntervalSinceNow)))
                } catch {
                    return
                }
            }
        }
        .onChange(of: showsTimerScreen) { _, isPresented in
#if DEBUG
            TimerNavigationDiagnostics.record("Home.navigation presented=\(isPresented)", model: timerViewModel)
#endif
            if !isPresented { homeStartTransition.reset() }
        }
        .onDisappear {
            homeStartTransition.reset()
            persistAquariumEditorDraft()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { cancelFishDrag() }
        }
        .onChange(of: aquariumEditorCategory) { _, category in
            clearAquariumSelections()
            if category != .fish {
                fishDragSession = nil
            }
            if category != .decoration {
                decorationDragSession = nil
            }
        }
        .onChange(of: homeNavigationResetRequestID) { _, requestID in
            guard mode == .home, requestID != nil else { return }
#if DEBUG
            TimerNavigationDiagnostics.record("Home.navigation reset request", model: timerViewModel)
#endif
            showsTimerScreen = false
        }
        .onChange(of: isAquariumEditorPresented) { _, isEditing in
            if isEditing { aquariumEditorCategory = .fish; isFishLibraryCompact = false; showsActiveFishLibrary = false; showsEditorLibrary = false }
            if !isEditing {
                showsEditorLibrary = false
                clearAquariumSelections()
                fishDragSession = nil
                decorationDragSession = nil
            }
        }
        .onChange(of: player?.activeAquariumFishIDs ?? []) { _, activeFishIDs in
            if let selectedAquariumFishID,
               !activeFishIDs.contains(selectedAquariumFishID) {
                self.selectedAquariumFishID = nil
            }
            coreTutorial?.didObserveActiveFishIDs(
                activeFishIDs,
                tutorialFishID: coreTutorial?.tutorialFishID(in: player)
            )
        }
        .onChange(of: isAquariumEditorActive) { _, isActive in
            if !isActive, editorWorkingState == nil {
                resetAquariumEditorSession()
            }
        }
        .onChange(of: aquariumEditorNavigation?.confirmationRequestID) { _, requestID in
            if requestID != nil, isAquariumEditorActive {
                showsEditorSaveConfirmation = true
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active { homeStartTransition.reset() }
            if newPhase != .active {
                persistAquariumEditorDraft()
            }
        }
        .alert("編集内容を破棄しますか？", isPresented: $showsEditorCancelConfirmation) {
            Button("編集を続ける", role: .cancel) {}
            Button("変更を破棄", role: .destructive) { discardAquariumEditorSession(closeEditor: true) }
        }
        .alert("保存エラー", isPresented: Binding(get: { editorPersistenceError != nil }, set: { if !$0 { editorPersistenceError = nil } })) {
            Button("OK", role: .cancel) { editorPersistenceError = nil }
        } message: { Text(editorPersistenceError ?? "") }
        .alert("水槽を編集しますか？", isPresented: $showsAquariumEditConfirmation) {
            Button("編集する") {
                beginAquariumEditorSessionIfNeeded(player: player)
            }
            Button("キャンセル", role: .cancel) {}
        }
        .alert("水槽がいっぱいです", isPresented: $showsAquariumCapacityAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("水槽に置ける魚は\(AquariumDisplayLimits.maxFishCount)匹までです。")
        }
        .alert("魚の獲得上限", isPresented: $showsDailyFishLimitInformation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("今後、広告を見て今日の魚獲得上限を増やせるようになります。")
        }
        .confirmationDialog(
            "この編集内容を保存しますか？",
            isPresented: $showsEditorSaveConfirmation,
            titleVisibility: .visible
        ) {
            Button("保存する") {
                saveAquariumEditorSession()
            }
            if coreTutorial?.isActive != true {
                Button("変更を破棄", role: .destructive) {
                    discardAquariumEditorSession(closeEditor: true)
                }
                Button("編集を続ける", role: .cancel) {
                    continueAquariumEditing()
                }
            }
        }
    }

    private var regularHomeControls: some View {
        VStack(spacing: 0) {
            homeStatusRow

            Spacer(minLength: 24)

            Button {
                guard coreTutorial?.isActive != true || isHomeStartTutorialInteractionAllowed else {
                    return
                }
                _ = homeStartTransition.begin(isDestinationPresented: showsTimerScreen)
#if DEBUG
                TimerNavigationDiagnostics.record("Home.start tap", model: timerViewModel)
#endif
            } label: {
                Label(
                    HomeTimerEntryPresentation.title(
                        for: timerViewModel.phase,
                        state: timerViewModel.state
                    ),
                    systemImage: "timer"
                )
            }
            .buttonStyle(HomeWaterSurfaceButtonStyle())
            .frame(maxWidth: 290)
            .coreTutorialTarget(.homeStart)
            .disabled(
                homeStartTransition.isOpening ||
                    (coreTutorial?.isActive == true && !isHomeStartTutorialInteractionAllowed)
            )
            .accessibilityHidden(coreTutorial?.isActive == true && !isHomeStartTutorialInteractionAllowed)
            .accessibilityIdentifier("home.startStudy")
            .accessibilityLabel(HomeTimerEntryPresentation.title(
                for: timerViewModel.phase,
                state: timerViewModel.state
            ))
            .overlay {
                if homeStartTransition.isOpening {
                    HomeStartRipple()
                }
            }
            .overlay(alignment: .bottom) {
                Text(HomeDailyMessage.message(on: dailyMessageDate))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .alignmentGuide(.bottom) { $0[.top] - 12 }
                    .allowsHitTesting(false)
                    .accessibilityIdentifier("home.dailyMessage")
            }

            Spacer(minLength: 24)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        // AquariumViewは全面描画するため、Homeの主要操作だけ実TabBar高ぶん確実に退避する。
        .padding(.bottom, 24 + MainTabBarHitShieldLayout.tabBarHeight)
    }

    private var homeStatusRow: some View {
        GeometryReader { geometry in
            let availableWidth = max(
                geometry.size.width - HomeStatusRowLayout.spacing * 2,
                0
            )
            let sideWidth = availableWidth * HomeStatusRowLayout.sideWidthRatio
            let centerWidth = availableWidth - sideWidth * 2

            HStack(spacing: HomeStatusRowLayout.spacing) {
                dailyFishProgress
                    .frame(width: sideWidth, height: HomeStatusRowLayout.cardHeight)

                HStack(spacing: 6) {
                    Text("今日 \(HomeDashboardPresentation.studyDurationText(minutes: player?.todayStudyMinutes ?? 0))")
                        .accessibilityIdentifier("home.todayStudyMinutes")

                    Rectangle()
                        .fill(.white.opacity(0.34))
                        .frame(width: 1, height: 13)
                        .accessibilityHidden(true)

                    Text("昨日 \(HomeDashboardPresentation.studyDurationText(minutes: player?.yesterdayStudyMinutes ?? 0))")
                        .accessibilityIdentifier("home.yesterdayStudyMinutes")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.24), radius: 1, y: 1)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, 7)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .homeStatusGlass()
                .frame(width: centerWidth, height: HomeStatusRowLayout.cardHeight)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("home.studySummary")
                .coreTutorialTarget(.studySummary)

                HStack(spacing: 5) {
                    Image(systemName: "circle.hexagongrid.fill")
                    Text("\(CurrencyService.balance(of: player))")
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(.yellow)
                .shadow(color: .black.opacity(0.22), radius: 1, y: 1)
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .homeStatusGlass()
                .frame(width: sideWidth, height: HomeStatusRowLayout.cardHeight)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("所持コイン \(CurrencyService.balance(of: player))枚")
                .accessibilityIdentifier("home.coinBalance")
                .coreTutorialTarget(.coinBalance)
                .allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: HomeStatusRowLayout.cardHeight)
    }

    private var dailyFishProgress: some View {
        HStack(spacing: 5) {
            Image(systemName: "fish.fill")
            Text("\(todayFishAcquisitionCount) / \(todayFishLimit)")
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Button {
                showsDailyFishLimitInformation = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.body)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(coreTutorial?.isActive == true)
            .accessibilityHidden(coreTutorial?.isActive == true)
            .accessibilityLabel("魚の獲得上限を増やす")
            .accessibilityIdentifier("home.increaseDailyFishLimit")
        }
        .font(.caption.weight(.bold))
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.24), radius: 1, y: 1)
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .homeStatusGlass()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            "今日の魚獲得数 \(todayFishAcquisitionCount)匹、現在の上限 \(todayFishLimit)匹"
        )
        .accessibilityIdentifier("home.dailyFishProgress")
        .coreTutorialTarget(.dailyFish)
    }

    private var todayFishLimit: Int {
        guard let player, let date = player.dailyGrantedFishDate,
              Calendar.current.isDateInToday(date) else { return DailyFishAcquisitionPolicy.basicLimit }
        return min(DailyFishAcquisitionPolicy.maximumLimit,
                   max(DailyFishAcquisitionPolicy.basicLimit, player.dailyFishLimit))
    }

    private var todayFishAcquisitionCount: Int {
        DailyFishAcquisitionStore.todayCount(
            storedCount: storedDailyFishAcquisitionCount,
            storedDayIdentifier: storedDailyFishAcquisitionDayIdentifier
        )
    }

    private func handleAquariumDrop(
        _ items: [AquariumEditorDragItem],
        at location: CGPoint,
        aquariumSize: CGSize
    ) -> Bool {
        guard isAquariumEditorPresented else {
            return false
        }

        for item in items {
            switch item.kind {
            case .fish:
                guard AquariumSideEditorLayout.acceptsDrop(at: location, in: aquariumSize),
                      let player else { continue }
                let preferredFishID = item.fishSpecies == .clownfish &&
                    coreTutorial?.step == .waitingForFishPlacement
                    ? coreTutorial?.tutorialFishID(in: player)
                    : nil
                let result = AquariumEditorDropCoordinator.addFish(
                    from: item,
                    preferredFishID: preferredFishID,
                    to: player
                )
                if handleFishDropResult(result) {
                    return true
                }

            case .decoration:
                guard let placement = decorationPlacements.first(where: {
                    $0.decorationID == item.identifier
                }), AquariumEditorDropCoordinator.acceptsDecorationDrop(
                    at: location, in: aquariumSize, kind: placement.kind
                ) else { continue }
                do {
                    try AquariumEditorDropCoordinator.placeDecoration(
                        from: item,
                        placement: placement,
                        at: location,
                        aquariumSize: aquariumSize,
                        in: modelContext,
                        persistChanges: mode != .aquariumEditor
                    )
                    markAquariumEditorChanged()
                    return true
                } catch {
                    return false
                }

            }
        }
        return false
    }

    @discardableResult
    private func handleFishDropResult(_ result: AquariumFishDropResult) -> Bool {
        switch result {
        case .placed:
            markAquariumEditorChanged()
            return true
        case .aquariumFull:
            showsAquariumCapacityAlert = true
            return false
        case .outsideAquarium, .unavailable:
            return false
        }
    }

    private func fullCanvasEditorControls(size: CGSize) -> some View {
        VStack {
            HStack(alignment: .top, spacing: 12) {
                editorCategoryButton(.fish, title: "魚", symbol: "fish.fill")
                editorCategoryButton(.decoration, title: "装飾", symbol: "leaf.fill")
                editorCategoryButton(.background, title: "背景", symbol: "photo.fill")
                Spacer(minLength: 0)
                Button { showsEditorCancelConfirmation = true } label: {
                    Image(systemName: "xmark").frame(width: 44, height: 48)
                        .background(.ultraThinMaterial, in: Capsule())
                }.accessibilityLabel("キャンセル").accessibilityIdentifier("aquariumEditor.cancel")
                Button {
                    guard coreTutorial?.isActive != true || isAquariumDoneTutorialInteractionAllowed else { return }
                    finishAquariumEditing()
                } label: {
                    Label("完了", systemImage: "checkmark")
                        .padding(.horizontal, 14).frame(minHeight: 48)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                .coreTutorialTarget(.aquariumDone)
                .disabled(coreTutorial?.isActive == true && !isAquariumDoneTutorialInteractionAllowed)
                .accessibilityIdentifier("aquariumEditor.done")
            }
            .buttonStyle(.plain).foregroundStyle(.white)
            .padding(.horizontal, 16).padding(.top, 8)
            HStack(spacing: 0) {
                historyButton(isRedo: false)
                historyButton(isRedo: true)
            }
            .background(.ultraThinMaterial, in: Capsule())
            .padding(.top, 4)
            Spacer()
        }.zIndex(30)
    }

    private func historyButton(isRedo: Bool) -> some View {
        let enabled = isRedo ? editorHistory?.canRedo == true : editorHistory?.canUndo == true
        return Button { applyAquariumHistory(isRedo: isRedo) } label: {
            Image(systemName: isRedo ? "arrow.uturn.forward" : "arrow.uturn.backward")
                .frame(width: 44, height: 44)
                .foregroundStyle(.white.opacity(enabled ? 1 : 0.3))
        }
        .buttonStyle(.plain).disabled(!enabled)
        .accessibilityLabel(isRedo ? "やり直す" : "元に戻す")
        .accessibilityIdentifier(isRedo ? "aquariumEditor.redo" : "aquariumEditor.undo")
    }

    private func editorCategoryButton(_ category: AquariumEditorCategory, title: String, symbol: String) -> some View {
        Button {
            aquariumEditorCategory = category
            isFishLibraryCompact = false
            showsEditorLibrary = true
        } label: {
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.title3)
                    .frame(width: 52, height: 52)
                    .background(.ultraThinMaterial, in: Circle())
                    .background(aquariumEditorCategory == category ? Color.cyan.opacity(0.7) : .clear, in: Circle())
                    .overlay(Circle().stroke(.white.opacity(aquariumEditorCategory == category ? 0.8 : 0.2), lineWidth: 1))
                Text(title).font(.caption)
            }
        }
        .accessibilityLabel(title)
        .accessibilityIdentifier("aquariumEditor.category.\(category == .fish ? "fish" : category == .decoration ? "decoration" : "background")")
    }

    private func addFishFromLibrary(_ species: FishSpecies) {
        guard isAquariumEditorPresented, showsEditorLibrary, let player else { return }
        let preferredID = species == .clownfish && coreTutorial?.step == .waitingForFishPlacement
            ? coreTutorial?.tutorialFishID(in: player) : nil
        let initial = AquariumEditorInitialPlacement.fish(species: species, size: canvasFrame.size,
            neighbors: player.activeAquariumFish.compactMap { editingFishPositions[$0.id] ?? fishSpawnPositions[$0.id] })
        let location = CGPoint(x: canvasFrame.minX + canvasFrame.width * initial.x,
                               y: canvasFrame.minY + canvasFrame.height * initial.y)
        guard let added = AquariumFishEditing.drop(species: species, location: location,
            canvas: canvasFrame, player: player, preferredFishID: preferredID) else { return }
        fishSpawnPositions[added.id] = added.position
        fishAppearances[added.id] = AquariumFishAppearance(startedAt: Date())
        showsEditorLibrary = false
        markAquariumEditorChanged()
        if mode != .aquariumEditor { try? modelContext.save() }
    }

    private func addDecorationFromSheet(_ id: String) {
        guard let placement = decorationPlacements.first(where: { $0.decorationID == id && !$0.isPlaced }) else { return }
        do {
            let initial = AquariumEditorInitialPlacement.decoration(kind: placement.kind, scale: CGFloat(placement.scale),
                size: canvasFrame.size, existing: decorationPlacements.filter(\.isPlaced).map(\.decoration))
            try AquariumDecorationService.confirmPlacement(placement, at: initial,
                in: modelContext, persistChanges: mode != .aquariumEditor)
            aquariumEditorCategory = .decoration
            showsEditorLibrary = false
            decorationRestoreRequestID = id
            markAquariumEditorChanged()
        } catch { showsAquariumCapacityAlert = true }
    }

    private func selectAquariumFish(_ playerFishID: UUID) {
        guard isAquariumEditorPresented,
              player?.activeAquariumFishIDs.contains(playerFishID) == true else { return }
        aquariumSelectionResetRequestID = UUID()
        selectedAquariumFishID = playerFishID
        showsActiveFishLibrary = true
    }

    private func clearAquariumSelections() {
        selectedAquariumFishID = nil
        updateDecorationEditingState(isEditing: false)
        aquariumSelectionResetRequestID = UUID()
    }

    private func updateFishDrag(species: FishSpecies, location: CGPoint) {
        guard isAquariumEditorPresented, aquariumEditorCategory == .fish else {
            fishDragSession = nil
            return
        }
        if coreTutorial?.isActive == true {
            guard coreTutorial?.step == .waitingForFishPlacement,
                  species == .clownfish else {
                fishDragSession = nil
                return
            }
        }
        coreTutorial?.didStartFishDrag(species: species)
        fishDragSession = AquariumFishDragSession(species: species, location: location)
    }

    private func finishFishDrag(
        species: FishSpecies,
        at location: CGPoint,
        aquariumSize: CGSize
    ) {
        defer { fishDragSession = nil }
        guard isAquariumEditorPresented,
              aquariumEditorCategory == .fish,
              fishDragSession?.species == species,
              let player else { return }
        if coreTutorial?.isActive == true {
            guard coreTutorial?.step == .waitingForFishPlacement,
                  species == .clownfish else { return }
        }
        let preferredFishID = species == .clownfish &&
            coreTutorial?.step == .waitingForFishPlacement
            ? coreTutorial?.tutorialFishID(in: player)
            : nil
        guard let dropped = AquariumFishEditing.drop(species: species, location: location,
            canvas: canvasFrame, player: player, preferredFishID: preferredFishID) else { return }
        fishSpawnPositions[dropped.id] = dropped.position
        showsEditorLibrary = false
        markAquariumEditorChanged()
        if mode != .aquariumEditor { try? modelContext.save() }

    }

    private func cancelFishDrag() {
        fishDragSession = nil
    }

    private func decorationPreview(in aquariumSize: CGSize) -> AquariumDecoration? {
        guard let decorationDragSession,
              let placement = decorationPlacements.first(where: {
                  $0.decorationID == decorationDragSession.decorationID
              }) else { return nil }
        let root = AquariumDecorationEditor.dragPreviewPosition(
            forDropLocation: decorationDragSession.location,
            aquariumSize: aquariumSize,
            kind: placement.kind,
            scale: CGFloat(placement.scale)
        )
        return AquariumDecoration(
            id: placement.decorationID, kind: placement.kind,
            relativeX: root.x / max(aquariumSize.width, 1),
            relativeY: root.y / max(aquariumSize.height, 1),
            scale: CGFloat(placement.scale)
        )
    }

    private func updateDecorationDrag(decorationID: String, location: CGPoint) {
        guard isAquariumEditorPresented,
              aquariumEditorCategory == .decoration,
              decorationPlacements.contains(where: {
                  $0.decorationID == decorationID && !$0.isPlaced
              }) else {
            decorationDragSession = nil
            return
        }
        decorationDragSession = AquariumDecorationDragSession(
            decorationID: decorationID,
            location: location
        )
        updateDecorationEditingState(isEditing: true)
    }

    private func finishDecorationDrag(
        decorationID: String,
        at location: CGPoint,
        aquariumSize: CGSize
    ) {
        var didPlace = false
        defer {
            decorationDragSession = nil
            if !didPlace { updateDecorationEditingState(isEditing: false) }
        }
        guard isAquariumEditorPresented,
              aquariumEditorCategory == .decoration,
              decorationDragSession?.decorationID == decorationID,
              let placement = decorationPlacements.first(where: {
                  $0.decorationID == decorationID && !$0.isPlaced
              }), AquariumEditorDropCoordinator.acceptsDecorationDrop(
                  at: location, in: aquariumSize, kind: placement.kind
              ) else { return }

        do {
            try AquariumEditorDropCoordinator.placeDecoration(
                from: .decoration(id: decorationID),
                placement: placement,
                at: location,
                aquariumSize: aquariumSize,
                in: modelContext,
                persistChanges: mode != .aquariumEditor
            )
            markAquariumEditorChanged()
            didPlace = true
            // 配置後も選択を保持し、空いている水槽のtapまでUIを戻さない。
            decorationRestoreRequestID = placement.decorationID
        } catch {}
    }

    private func cancelDecorationDrag() {
        decorationDragSession = nil
        updateDecorationEditingState(isEditing: false)
    }

    private func selectBackground(_ theme: AquariumBackgroundTheme) {
        guard isAquariumEditorPresented, aquariumEditorCategory == .background else { return }
        if mode == .aquariumEditor {
            guard displayedBackgroundTheme != theme else { return }
            draftBackgroundTheme = theme
            markAquariumEditorChanged()
        } else {
            backgroundThemeRawValue = theme.rawValue
        }
    }

    @ViewBuilder
    private var selectedFishRemovalControl: some View {
        if !showsEditorLibrary,
           let id = selectedAquariumFishID,
           let fish = player?.activeAquariumFish.first(where: { $0.id == id }) {
            VStack(spacing: 4) {
                Text(fish.species.name).font(.caption)
                Button { storeAquariumFish(id) } label: {
                    Label("水槽から戻す", systemImage: "tray.and.arrow.down")
                        .font(.subheadline.bold()).padding(.horizontal, 16).frame(minHeight: 44)
                }.buttonStyle(.plain)
                .accessibilityIdentifier("aquariumEditor.removeSelectedFish")
                .disabled(coreTutorial?.isActive == true)
            }
            .padding(10).foregroundStyle(.white)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            .background(Color.cyan.opacity(0.12), in: RoundedRectangle(cornerRadius: 20))
            .padding(.bottom, 35)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .zIndex(25)
        }
    }

    private func storeAllAquariumItems(_ target: AquariumEditorBulkStorage) {
        guard isAquariumEditorPresented, showsEditorLibrary, let work = editorWorkingState else { return }
        // Recheck the current working state when confirmation is accepted.
        if target == .fish && work.player.activeAquariumFish.isEmpty { return }
        let before = AquariumEditorDraft(player: work.player, placements: work.placements, background: displayedBackgroundTheme)
        guard let after = target.applying(to: before) else { return }
        work.apply(after)
        if target == .fish {
            for id in before.fishIDs {
                fishAppearances[id] = nil
                fishSpawnPositions[id] = nil
            }
            selectedAquariumFishID = nil
        } else {
            updateDecorationEditingState(isEditing: false)
            aquariumSelectionResetRequestID = UUID()
        }
        // No per-item callback: the entire change is one history entry and one save.
        markAquariumEditorChanged()
    }

    private func removeSelectedAquariumFish() {
        guard let id = selectedAquariumFishID else { return }
        storeAquariumFish(id)
    }

    private func storeAquariumFish(_ id: UUID) {
        guard let player, AquariumFishEditing.store(id: id, player: player) else { return }
        if selectedAquariumFishID == id { selectedAquariumFishID = nil }
        fishSpawnPositions[id] = nil
        fishAppearances[id] = nil
        markAquariumEditorChanged()
        if mode != .aquariumEditor { try? modelContext.save() }
    }


    @ViewBuilder
    private var aquariumEditingEntryControl: some View {
        VStack {
            HStack {
                Spacer(minLength: 0)
                Button {
                    guard coreTutorial?.isActive != true || isAquariumEditTutorialInteractionAllowed else {
                        return
                    }
                    onAquariumViewingInteraction()
                    showsAquariumEditConfirmation = true
                } label: {
                    Label("編集", systemImage: "pencil")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.regularMaterial, in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.32), lineWidth: 1))
                        .shadow(color: .black.opacity(0.18), radius: 5, y: 2)
                }
                .buttonStyle(.plain)
                .coreTutorialTarget(.aquariumEdit)
                .coreTutorialHighlight(
                    coreTutorial?.isActive == true &&
                        coreTutorial?.step == .aquariumIntro &&
                        coreTutorial?.conversationIndex == CoreTutorialConversationScript.aquariumIntro.count - 1
                )
                .disabled(
                    coreTutorial?.isActive == true && !isAquariumEditTutorialInteractionAllowed
                )
                .accessibilityHidden(coreTutorial?.isActive == true && !isAquariumEditTutorialInteractionAllowed)
                .accessibilityLabel("水槽を編集")
                .accessibilityIdentifier("aquariumEditor.start")
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 12)
        .padding(.trailing, 12)
        .zIndex(20)
    }

    @ViewBuilder
    private func editorCompletionControl(aquariumWidth: CGFloat) -> some View {
        if mode == .aquariumEditor {
            VStack {
                HStack {
                    Button {
                        guard coreTutorial?.isActive != true || isAquariumDoneTutorialInteractionAllowed else {
                            return
                        }
                        finishAquariumEditing()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("完了")
                            if hasUnsavedAquariumEditorChanges {
                                Circle()
                                    .fill(.orange)
                                    .frame(width: 7, height: 7)
                                    .accessibilityHidden(true)
                            }
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 10)
                        .background(.blue.opacity(0.86), in: Capsule())
                        .shadow(color: .black.opacity(0.22), radius: 6, y: 3)
                    }
                    .buttonStyle(.plain)
                    .coreTutorialTarget(.aquariumDone)
                    .coreTutorialHighlight(
                        coreTutorial?.step == .waitingForAquariumSave &&
                            coreTutorial?.conversationIndex == CoreTutorialConversationScript.aquariumSave.count - 1
                    )
                    .disabled(
                        coreTutorial?.isActive == true && !isAquariumDoneTutorialInteractionAllowed
                    )
                    .accessibilityHidden(coreTutorial?.isActive == true && !isAquariumDoneTutorialInteractionAllowed)
                    .accessibilityHint(
                        hasUnsavedAquariumEditorChanges
                            ? "保存、破棄、編集を続けるから選択します"
                            : "水槽編集を終了します"
                    )
                    .accessibilityIdentifier("aquariumEditor.done")

                    Spacer(minLength: 0)
                }
                Spacer(minLength: 0)
            }
            .padding(.top, 12)
            .padding(.leading, 12)
            .frame(width: aquariumWidth)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .zIndex(26)
        }
    }

    private var collapsedEditorHandle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.22)) {
                isEditorPanelExpanded = true
            }
        } label: {
            Image(systemName: "chevron.left")
                .font(.subheadline.weight(.bold))
                .frame(
                    width: AquariumSideEditorLayout.collapsedHandleWidth,
                    height: AquariumSideEditorLayout.collapsedHandleHeight
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(coreTutorial?.isActive == true)
        .accessibilityHidden(coreTutorial?.isActive == true)
        .foregroundStyle(.primary)
        .background(.thinMaterial)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 14,
                bottomLeadingRadius: 14
            )
        )
        .shadow(color: .black.opacity(0.2), radius: 7, x: -3)
        .frame(
            width: AquariumSideEditorLayout.collapsedHandleWidth,
            height: AquariumSideEditorLayout.collapsedHandleHeight
        )
        .fixedSize()
        .contentShape(Rectangle())
        .accessibilityLabel("編集パネルを開く")
        .accessibilityIdentifier("aquariumEditor.expandPanel")
    }

    private func aquariumEditorTutorial(aquariumWidth: CGFloat) -> some View {
        VStack(spacing: 12) {
            Text("水槽編集の操作")
                .font(.headline)

            Label("魚や置物を左へスライドして、水槽へ追加できます", systemImage: "hand.draw.fill")
            Label("水槽内の魚をタップすると、その個体を戻せます", systemImage: "hand.tap.fill")
            Label("右パネルを閉じると、水槽全体を確認できます", systemImage: "rectangle.compress.vertical")

            Button("わかった", action: dismissAquariumEditorTutorial)
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("aquariumEditor.tutorial.dismiss")
        }
        .font(.subheadline)
        .multilineTextAlignment(.leading)
        .foregroundStyle(.primary)
        .padding(18)
        .frame(maxWidth: 300)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.28), radius: 12, y: 5)
        .frame(width: aquariumWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("aquariumEditor.tutorial")
    }

    private func collapseEditorPanel() {
        clearAquariumSelections()
        fishDragSession = nil
        decorationDragSession = nil
        withAnimation(.easeInOut(duration: 0.22)) {
            isEditorPanelExpanded = false
        }
    }

    private func dismissAquariumEditorTutorial() {
        hasSeenAquariumEditorTutorial = true
        withAnimation(.easeOut(duration: 0.18)) {
            showsAquariumEditorTutorial = false
        }
    }

    private func showAquariumEditorTutorial() {
        // 手動再表示では「初回表示済み」の保存値を変更しない。
        withAnimation(.easeIn(duration: 0.18)) {
            showsAquariumEditorTutorial = true
        }
    }

    private func markAquariumEditorChanged() {
        guard mode == .aquariumEditor else { return }
        guard let work = editorWorkingState else { return }
        let draft = AquariumEditorDraft(player: work.player, placements: work.placements, background: displayedBackgroundTheme)
        guard editorHistory?.record(draft) == true else { return }
        aquariumEditorNavigation?.markChanged()
        persistAquariumEditorDraft()
    }

    private func beginAquariumEditorSessionIfNeeded(player: Player?) {
        guard mode == .aquariumEditor,
              isAquariumEditorActive,
              aquariumEditorNavigation?.tabMode == .viewing,
              editorWorkingState == nil,
              let player else { return }

        _ = try? AquariumDecorationService.createDefaultsIfNeeded(in: modelContext)
        _ = try? AquariumDeveloperDecorations.seedIfNeeded(in: modelContext)
        let currentPlacements = (try? modelContext.fetch(
            FetchDescriptor<AquariumDecorationPlacement>()
        )) ?? decorationPlacements

        let initial = AquariumEditorDraft(player: player, placements: currentPlacements, background: savedBackgroundTheme)
        do { try AquariumEditorDraftStore.standard.save(initial) }
        catch { editorPersistenceError = "一時保存できませんでした。\(error.localizedDescription)"; return }
        editorWorkingState = AquariumEditorWorkingState(official: player, placements: currentPlacements, draft: initial)
        draftBackgroundTheme = savedBackgroundTheme
        editorHistory = AquariumEditorHistory(initial: initial)
        aquariumEditorCategory = .fish
        clearAquariumSelections()
        fishDragSession = nil
        decorationDragSession = nil
        isEditorPanelExpanded = true
        showsAquariumEditorTutorial = false
        hasSeenAquariumEditorTutorial = true
        aquariumEditorNavigation?.beginSession()
        let tutorialFishID = coreTutorial?.tutorialFishID(in: player)
        coreTutorial?.didEnterAquariumEditing(
            tutorialFishIsActive: tutorialFishID.map {
                player.activeAquariumFishIDs.contains($0)
            } ?? false
        )
    }

    private func applyAquariumHistory(isRedo: Bool) {
        guard let work = editorWorkingState else { return }
        let draft = isRedo ? editorHistory?.redo() : editorHistory?.undo()
        guard let draft else { return }
        let previousIDs = Set(work.player.activeAquariumFishIDs)
        work.apply(draft)
        draftBackgroundTheme = AquariumBackgroundTheme(rawValue: draft.background)
        clearAquariumSelections()
        let changedIDs = previousIDs.symmetricDifference(Set(work.player.activeAquariumFishIDs))
        for id in changedIDs { fishAppearances[id] = nil }
        // Only restored fish lose their initial spawn hint; other swimmers keep their state.
        fishSpawnPositions = fishSpawnPositions.filter { work.player.activeAquariumFishIDs.contains($0.key) }
        aquariumEditorNavigation?.markChanged()
        persistAquariumEditorDraft()
    }

    private func persistAquariumEditorDraft() {
        guard let work = editorWorkingState else { return }
        do {
            var draft = AquariumEditorDraft(player: work.player, placements: work.placements, background: displayedBackgroundTheme)
            draft.history = editorHistory
            try AquariumEditorDraftStore.standard.save(draft)
        } catch { editorPersistenceError = "一時保存できませんでした。\(error.localizedDescription)" }
    }

    private func restoreAquariumEditorDraftIfNeeded() {
        guard mode == .aquariumEditor, allowsEditorDraftRestoration, editorWorkingState == nil, let official = players.first else { return }
        do {
            guard let draft = try AquariumEditorDraftStore.standard.load() else { return }
            _ = try AquariumDecorationService.createDefaultsIfNeeded(in: modelContext)
            _ = try AquariumDeveloperDecorations.seedIfNeeded(in: modelContext)
            let currentPlacements = try modelContext.fetch(FetchDescriptor<AquariumDecorationPlacement>())
            let work = AquariumEditorWorkingState(official: official, placements: currentPlacements, draft: draft)
            editorWorkingState = work
            draftBackgroundTheme = AquariumBackgroundTheme(rawValue: draft.background)
            let current = AquariumEditorDraft(player: work.player,
                placements: work.placements, background: displayedBackgroundTheme)
            editorHistory = draft.history.flatMap { $0.isValid(for: current) ? $0 : nil } ?? AquariumEditorHistory(initial: current)
            aquariumEditorNavigation?.beginSession()
            aquariumEditorNavigation?.markChanged()
            showsEditorLibrary = false
            fishAppearances = [:]
        } catch { editorPersistenceError = "一時データを読み込めませんでした。正式な水槽データは保持されています。" }
    }

    private func saveAquariumEditorSession() {
        guard let work = editorWorkingState, let official = players.first else { return }
        let original = AquariumEditorSessionSnapshot.capture(player: official,
            decorationPlacements: officialDecorationPlacements, backgroundTheme: savedBackgroundTheme)
        let originalTutorialSaved = official.hasSavedCoreTutorialAquarium
        let updated = AquariumEditorSessionSnapshot.capture(player: work.player,
            decorationPlacements: work.placements, backgroundTheme: displayedBackgroundTheme)
        do {
            try AquariumEditorCommit.apply(updated, to: official, placements: officialDecorationPlacements,
                background: savedBackgroundTheme) {
                    if coreTutorial?.step == .waitingForAquariumSave,
                       let id = official.coreTutorialRewardFishID,
                       official.activeAquariumFishIDs.contains(id) {
                        official.hasSavedCoreTutorialAquarium = true
                    }
                    try modelContext.save()
                }
        } catch {
            official.hasSavedCoreTutorialAquarium = originalTutorialSaved
            editorPersistenceError = "保存できませんでした。編集内容は保持しています。"
            return
        }
        backgroundThemeRawValue = displayedBackgroundTheme.rawValue
        do { try AquariumEditorDraftStore.standard.remove() }
        catch {
            original.restore(player: official, decorationPlacements: officialDecorationPlacements)
            official.hasSavedCoreTutorialAquarium = originalTutorialSaved
            backgroundThemeRawValue = original.backgroundTheme.rawValue
            do { try modelContext.save() }
            catch { editorPersistenceError = "正式データの復旧保存に失敗しました。編集内容は保持しています。"; return }
            editorPersistenceError = "一時保存の削除に失敗しました。編集内容は保持しています。"
            return
        }
        coreTutorial?.didSaveAquarium(with: official)
        endAquariumEditorSession(selecting: nil)
    }

    private func discardAquariumEditorSession(closeEditor: Bool) {
        do { try AquariumEditorDraftStore.standard.remove() }
        catch { editorPersistenceError = "一時保存を破棄できませんでした。"; return }
        coreTutorial?.didDiscardAquariumChanges()
        endAquariumEditorSession(selecting: nil)
    }

    private func continueAquariumEditing() {
        aquariumEditorNavigation?.continueEditing()
        showsEditorSaveConfirmation = false
    }

    private func resetAquariumEditorSession() {
        editorWorkingState = nil
        editorHistory = nil
        draftBackgroundTheme = nil
        clearAquariumSelections()
        fishDragSession = nil
        decorationDragSession = nil
        showsAquariumEditConfirmation = false
        showsEditorSaveConfirmation = false
        showsAquariumEditorTutorial = false
        aquariumEditorNavigation?.finishSession()
    }

    private func endAquariumEditorSession(selecting destination: MainAppTab?) {
        resetAquariumEditorSession()
        if let destination {
            onFinishAquariumEditing(destination)
        }
    }

    private func requestAquariumEditorExit(to destination: MainAppTab) {
        aquariumEditorNavigation?.requestConfirmation(beforeSelecting: destination)
        // dirty flagの参照だけで即時に表示し、snapshot比較や保存はここでは行わない。
        showsEditorSaveConfirmation = true
    }

    private func finishAquariumEditing() {
        guard mode == .aquariumEditor else {
            selectedAquariumFishID = nil
            fishDragSession = nil
            withAnimation(.easeInOut(duration: 0.22)) {
                isEditingAquarium = false
            }
            return
        }

        saveAquariumEditorSession()
    }

    @ViewBuilder
    private func coreTutorialOverlay(
        geometry: GeometryProxy,
        aquariumWidth: CGFloat,
        editorWidth: CGFloat,
        targets: [CoreTutorialTarget: Anchor<CGRect>]
    ) -> some View {
        if mode == .home, showsCoreTutorialCompletion {
            Color.black.opacity(0.16)
                .ignoresSafeArea()
            CoreTutorialCoachCard(
                title: "準備完了！",
                message: "集中して魚を集め、自分だけの水族館を育てよう。",
                buttonTitle: coreTutorialCompletionButtonTitle,
                action: onDismissCoreTutorialCompletion
            )
            .padding(.horizontal, 24)
            .accessibilityIdentifier("coreTutorial.completed")
        } else if coreTutorial?.isActive == true {
            switch (mode, coreTutorial?.step, isAquariumEditorPresented) {
            case (.home, .homeIntro, _):
                let pages = CoreTutorialConversationScript.homeIntro
                let index = coreTutorial?.conversationIndex ?? 0
                CoreTutorialSpotlightStep(
                    targetFrame: index >= 3
                        ? targetFrame(.dailyFish, in: geometry, targets: targets)
                        : nil,
                    page: coreTutorialConversationPage(in: pages, at: index),
                    pageIndex: index,
                    onConversationAdvance: {
                        if coreTutorial?.advanceConversation(totalCount: pages.count) == true {
                            coreTutorial?.dismissHomeIntro()
                        }
                    },
                    accessibilityIdentifier: "coreTutorial.homeFishIntro"
                )

            case (.home, .homePointsIntro, _):
                let pages = CoreTutorialConversationScript.homePoints
                let index = coreTutorial?.conversationIndex ?? 0
                CoreTutorialSpotlightStep(
                    targetFrame: targetFrame(.coinBalance, in: geometry, targets: targets),
                    page: coreTutorialConversationPage(in: pages, at: index),
                    pageIndex: index,
                    onConversationAdvance: {
                        if coreTutorial?.advanceConversation(totalCount: pages.count) == true {
                            coreTutorial?.dismissHomeIntro()
                        }
                    },
                    accessibilityIdentifier: "coreTutorial.homePointsIntro"
                )

            case (.home, .homeStudySummaryIntro, _):
                let pages = CoreTutorialConversationScript.homeStudySummary
                let index = coreTutorial?.conversationIndex ?? 0
                CoreTutorialSpotlightStep(
                    targetFrame: targetFrame(.studySummary, in: geometry, targets: targets),
                    page: coreTutorialConversationPage(in: pages, at: index),
                    pageIndex: index,
                    onConversationAdvance: {
                        if coreTutorial?.advanceConversation(totalCount: pages.count) == true {
                            coreTutorial?.dismissHomeIntro()
                        }
                    },
                    accessibilityIdentifier: "coreTutorial.homeStudySummaryIntro"
                )

            case (.home, .waitingForHomeStartTap, _):
                let pages = CoreTutorialConversationScript.homeStart
                let index = coreTutorial?.conversationIndex ?? 0
                CoreTutorialSpotlightStep(
                    targetFrame: targetFrame(.homeStart, in: geometry, targets: targets),
                    page: coreTutorialConversationPage(in: pages, at: index),
                    pageIndex: index,
                    showsPointingHand: index == pages.count - 1,
                    allowsConversationAdvance: index < pages.count - 1,
                    allowsTargetInteraction: index == pages.count - 1,
                    onConversationAdvance: {
                        _ = coreTutorial?.advanceConversation(totalCount: pages.count)
                    },
                    accessibilityIdentifier: "coreTutorial.homeStartPrompt"
                )

            case (.home, .aquariumIntro, _):
                let pages = CoreTutorialConversationScript.rewardFollowUp
                let index = coreTutorial?.conversationIndex ?? 0
                if index < pages.count - 1 {
                    CoreTutorialSpotlightStep(
                        targetFrame: nil,
                        page: coreTutorialConversationPage(in: pages, at: index),
                        pageIndex: index,
                        onConversationAdvance: {
                            _ = coreTutorial?.advanceConversation(totalCount: pages.count)
                        },
                        accessibilityIdentifier: "coreTutorial.openAquarium"
                    )
                }

            case (.aquariumEditor, .aquariumIntro, false):
                let pages = CoreTutorialConversationScript.aquariumIntro
                let index = coreTutorial?.conversationIndex ?? 0
                CoreTutorialSpotlightStep(
                    targetFrame: index == pages.count - 1
                        ? targetFrame(.aquariumEdit, in: geometry, targets: targets)
                        : nil,
                    page: coreTutorialConversationPage(in: pages, at: index),
                    pageIndex: index,
                    showsPointingHand: index == pages.count - 1,
                    allowsConversationAdvance: index < pages.count - 1,
                    allowsTargetInteraction: index == pages.count - 1,
                    onConversationAdvance: {
                        _ = coreTutorial?.advanceConversation(totalCount: pages.count)
                    },
                    accessibilityIdentifier: "coreTutorial.aquariumEditPrompt"
                )

            case (.aquariumEditor, .waitingForFishPlacement, true):
                let clownfishFrame = targetFrame(
                    .tutorialClownfish,
                    in: geometry,
                    targets: targets
                )
                CoreTutorialSpotlightStep(
                    targetFrame: clownfishFrame,
                    page: CoreTutorialConversationScript.fishPlacement[0],
                    pageIndex: 0, allowsConversationAdvance: false, allowsTargetInteraction: true,
                    accessibilityIdentifier: "coreTutorial.fishPlacementPrompt"
                )

            case (.aquariumEditor, .waitingForAquariumSave, true):
                let pages = CoreTutorialConversationScript.aquariumSave
                let index = coreTutorial?.conversationIndex ?? 0
                CoreTutorialSpotlightStep(
                    targetFrame: index == pages.count - 1
                        ? targetFrame(.aquariumDone, in: geometry, targets: targets)
                        : nil,
                    page: coreTutorialConversationPage(in: pages, at: index),
                    pageIndex: index,
                    showsPointingHand: index == pages.count - 1,
                    allowsConversationAdvance: index < pages.count - 1,
                    allowsTargetInteraction: index == pages.count - 1,
                    onConversationAdvance: {
                        _ = coreTutorial?.advanceConversation(totalCount: pages.count)
                    },
                    accessibilityIdentifier: "coreTutorial.savePrompt"
                )

            case (.aquariumEditor, .finishing, false):
                let pages = CoreTutorialConversationScript.aquariumReturnHome
                let index = coreTutorial?.conversationIndex ?? 0
                if index < pages.count - 1 {
                    CoreTutorialSpotlightStep(
                        targetFrame: nil,
                        page: coreTutorialConversationPage(in: pages, at: index),
                        pageIndex: index,
                        onConversationAdvance: {
                            _ = coreTutorial?.advanceConversation(totalCount: pages.count)
                        },
                        accessibilityIdentifier: "coreTutorial.returnHome"
                    )
                }

            case (.home, .finishing, _):
                let pages = CoreTutorialConversationScript.finishing
                let index = coreTutorial?.conversationIndex ?? 0
                CoreTutorialSpotlightStep(
                    targetFrame: nil,
                    page: coreTutorialConversationPage(in: pages, at: index),
                    pageIndex: index,
                    onConversationAdvance: {
                        if coreTutorial?.advanceConversation(totalCount: pages.count) == true {
                            coreTutorial?.complete()
                        }
                    },
                    accessibilityIdentifier: "coreTutorial.finishing"
                )

            default:
                EmptyView()
            }
        }
    }

    private func targetFrame(
        _ target: CoreTutorialTarget,
        in geometry: GeometryProxy,
        targets: [CoreTutorialTarget: Anchor<CGRect>]
    ) -> CGRect? {
        targets[target].map { geometry[$0] }
    }

    private var decorationEditorControls: some View {
        Group {
            Text("水草や岩をタップして移動できます")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .aquariumGlass(cornerRadius: 16)

            HStack(spacing: 12) {
                Button {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        showsDecorationStorage = true
                    }
                } label: {
                    Label("収納", systemImage: "shippingbox.fill")
                }
                .buttonStyle(AquariumSecondaryButtonStyle())

                Button {
                    beginBackgroundThemeEditing()
                } label: {
                    Label("背景", systemImage: "photo.fill")
                }
                .buttonStyle(AquariumSecondaryButtonStyle())

                Button("完了") {
                    withAnimation { isEditingAquarium = false }
                }
                .buttonStyle(AquariumPrimaryButtonStyle())
            }
        }
    }

    private var decorationStorageOverlay: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { closeDecorationStorage() }

                decorationStoragePanel
                    .frame(maxWidth: .infinity)
                    .frame(height: geometry.size.height * 0.31)
                    .background(.ultraThinMaterial)
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 24,
                            topTrailingRadius: 24
                        )
                    )
                    .overlay(alignment: .top) {
                        Capsule()
                            .fill(.white.opacity(0.45))
                            .frame(width: 42, height: 5)
                            .padding(.top, 8)
                    }
                    .shadow(color: .black.opacity(0.2), radius: 18, y: -6)
                    .transition(.move(edge: .bottom))
            }
        }
        .ignoresSafeArea()
    }

    private var decorationStoragePanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("装飾の収納", systemImage: "shippingbox.fill")
                    .font(.headline)
                Spacer()
                Button(action: closeDecorationStorage) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    categoryButton(title: "すべて", category: nil)
                    ForEach(AquariumDecorationCategory.allCases) { category in
                        categoryButton(title: category.displayName, category: category)
                    }
                }
            }

            if filteredStoredDecorations.isEmpty {
                ContentUnavailableView(
                    storedDecorations.isEmpty
                        ? "収納中の装飾はありません"
                        : "このカテゴリの装飾はありません",
                    systemImage: "shippingbox"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(filteredStoredDecorations) { placement in
                            decorationStorageCard(placement)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(.top, 18)
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
    }

    private func categoryButton(
        title: String,
        category: AquariumDecorationCategory?
    ) -> some View {
        Button(title) {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedDecorationCategory = category
            }
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(selectedDecorationCategory == category ? .white : .primary)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            selectedDecorationCategory == category
                ? Color.blue.opacity(0.85)
                : Color.white.opacity(0.16),
            in: Capsule()
        )
    }

    private func decorationStorageCard(
        _ placement: AquariumDecorationPlacement
    ) -> some View {
        Button {
            decorationRestoreRequestID = placement.decorationID
            closeDecorationStorage()
        } label: {
            VStack(spacing: 8) {
                AquariumDecorationView(decoration: placement.decoration, backgroundTheme: displayedBackgroundTheme)
                    .scaleEffect(0.5)
                    .frame(height: 72)

                Text(placement.kind.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .frame(width: 104)
            .padding(10)
            .background(.white.opacity(0.2), in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.white.opacity(0.3))
            }
        }
        .buttonStyle(.plain)
    }

    private func closeDecorationStorage() {
        withAnimation(.easeInOut(duration: 0.22)) {
            showsDecorationStorage = false
        }
    }

    private var backgroundThemePickerOverlay: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { cancelBackgroundThemeEditing() }

                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label("水槽の背景", systemImage: "photo.fill")
                            .font(.headline)
                        Spacer()
                        Button("キャンセル", action: cancelBackgroundThemeEditing)
                            .font(.caption.weight(.semibold))
                        Button("確定", action: confirmBackgroundThemeEditing)
                            .font(.caption.weight(.bold))
                            .buttonStyle(.borderedProminent)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 12) {
                            ForEach(AquariumBackgroundTheme.allCases) { theme in
                                backgroundThemeCard(theme)
                            }
                        }
                    }
                }
                .padding(.top, 18)
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity)
                .frame(height: geometry.size.height * 0.31)
                .background(.ultraThinMaterial)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 24,
                        topTrailingRadius: 24
                    )
                )
                .shadow(color: .black.opacity(0.2), radius: 18, y: -6)
                .transition(.move(edge: .bottom))
            }
        }
        .ignoresSafeArea()
    }

    private func backgroundThemeCard(_ theme: AquariumBackgroundTheme) -> some View {
        let isSelected = previewBackgroundTheme == theme

        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                previewBackgroundTheme = theme
            }
        } label: {
            VStack(spacing: 7) {
                Image(theme.imageName)
                .resizable()
                .scaledToFill()
                .frame(width: 112, height: 78)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(alignment: .topTrailing) {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.white, .blue)
                            .padding(6)
                    }
                }

                Text(theme.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .padding(8)
            .background(
                isSelected ? Color.blue.opacity(0.18) : Color.white.opacity(0.16),
                in: RoundedRectangle(cornerRadius: 16)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.blue : Color.white.opacity(0.3), lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
    }

    private func beginBackgroundThemeEditing() {
        originalBackgroundTheme = savedBackgroundTheme
        previewBackgroundTheme = savedBackgroundTheme
        withAnimation(.easeInOut(duration: 0.22)) {
            showsBackgroundThemePicker = true
        }
    }

    private func cancelBackgroundThemeEditing() {
        previewBackgroundTheme = originalBackgroundTheme
        withAnimation(.easeInOut(duration: 0.22)) {
            showsBackgroundThemePicker = false
        }
        previewBackgroundTheme = nil
        originalBackgroundTheme = nil
    }

    private func confirmBackgroundThemeEditing() {
        if let previewBackgroundTheme {
            backgroundThemeRawValue = previewBackgroundTheme.rawValue
        }
        withAnimation(.easeInOut(duration: 0.22)) {
            showsBackgroundThemePicker = false
        }
        previewBackgroundTheme = nil
        originalBackgroundTheme = nil
    }

    private var interruptionBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            VStack(alignment: .leading, spacing: 3) {
                Text("前回の集中は中断されました")
                    .font(.subheadline.weight(.semibold))
                Text("集中時間と魚獲得には反映されません")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
            Spacer()
            Button {
                withAnimation { showsInterruptionBanner = false }
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(.white)
        .padding(14)
        .background(.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 16))
    }

    @MainActor
    private func initializeHomeDataAfterAppearance() async {
        // SwiftDataのQuery observerがappearance中に組み上がるタイミングを避ける。
        await Task.yield()
        guard !Task.isCancelled else { return }

        do {
            let initialization = try HomePlayerInitialization.prepare(in: modelContext)
#if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-fish-editor-ui-test"),
               ProcessInfo.processInfo.arguments.contains("-core-tutorial-in-memory"),
               initialization.player.ownedFish.isEmpty {
                initialization.player.ownedFish = FishSpecies.allCases.flatMap { species in
                    (0..<5).map { _ in PlayerFish(species: species) }
                }
                initialization.player.activeAquariumFishIDs = []
                initialization.player.hasInitializedActiveAquariumFish = true
                try modelContext.save()
            }
#endif
            guard !Task.isCancelled else { return }
            updateDailyStudyTotalsIfNeeded(for: initialization.player, now: Date())
        } catch {
#if DEBUG
            let nsError = error as NSError
            print(
                "[HOME INIT] failed error=\(String(reflecting: error)) " +
                "domain=\(nsError.domain) code=\(nsError.code)"
            )
#endif
        }
    }

    private func updateDailyStudyTotalsIfNeeded(for player: Player, now: Date) {
        let calendar = Calendar.current
        let today = DateFormatter.yyyyMMdd.string(from: now)

        if lastStudyDate.isEmpty {
            lastStudyDate = today
        } else if let lastDate = DateFormatter.yyyyMMdd.date(from: lastStudyDate),
                  !calendar.isDate(lastDate, inSameDayAs: now) {
            player.todayStudyMinutes = 0
            lastStudyDate = today
        } else if DateFormatter.yyyyMMdd.date(from: lastStudyDate) == nil {
            player.todayStudyMinutes = 0
            lastStudyDate = today
        }
        try? StudyHistoryService.synchronizeCurrentDayTotals(
            for: player, at: now, calendar: calendar, in: modelContext
        )
    }

    private func inspectPersistedTimerSession() {
        switch TimerSessionStore.shared.launchStatus(at: Date()) {
        case .recoverable, .interrupted:
            showsTimerScreen = true
        case .none, .sameProcess:
            break
        }

        if TimerSessionStore.shared.consumeInterruptionBanner() {
            withAnimation { showsInterruptionBanner = true }
        }
    }

    private func updateDecorationEditingState(isEditing: Bool) {
        withAnimation(.easeInOut(duration: 0.15)) {
            isEditingDecoration = isEditing
        }
    }

}

enum HomeTimerEntryPresentation {
    static func title(for phase: PomodoroSessionPhase, state: TimerState) -> String {
        switch phase {
        case .breakTime:
            "休憩に戻る"
        case .awaitingNextSet:
            "次のセット確認へ戻る"
        case .study, .finished:
            "はじめよう"
        }
    }
}

extension DateFormatter {
    static let yyyyMMdd: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter
    }()
}


#Preview {
    TimerView(
        studyTime: 25,
        breakTime: 5,
        player: nil
    )
}
