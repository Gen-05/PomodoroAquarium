import Combine
import SwiftData
import SwiftUI
import UIKit

enum MainAppTab: Hashable, CaseIterable, Identifiable {
    case home
    case aquarium
    case shop
    case statistics
    case more

    var id: Self { self }

    var title: String {
        switch self {
        case .home: "ホーム"
        case .aquarium: "水槽"
        case .shop: "ショップ"
        case .statistics: "統計"
        case .more: "その他"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house.fill"
        case .aquarium: "fish.fill"
        case .shop: "storefront.fill"
        case .statistics: "chart.bar.fill"
        case .more: "ellipsis.circle.fill"
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .home: "mainTab.home"
        case .aquarium: "mainTab.aquarium"
        case .shop: "mainTab.shop"
        case .statistics: "mainTab.statistics"
        case .more: "mainTab.more"
        }
    }
}

enum MainTabNavigationPolicy {
    static let lockedTabOpacity = 0.42

    static func canSelect(_ tab: MainAppTab, whileStudyLocked: Bool) -> Bool {
        !whileStudyLocked || tab == .home
    }

    static func opacity(for tab: MainAppTab, whileStudyLocked: Bool) -> Double {
        canSelect(tab, whileStudyLocked: whileStudyLocked) ? 1 : lockedTabOpacity
    }

    static func shouldResetHomeNavigation(
        currentTab: MainAppTab,
        requestedTab: MainAppTab,
        whileStudyLocked: Bool
    ) -> Bool {
        !whileStudyLocked && currentTab == .home && requestedTab == .home
    }

    static func requiresAquariumSaveConfirmation(
        from selectedTab: MainAppTab,
        to requestedTab: MainAppTab,
        whileStudyLocked: Bool,
        hasUnsavedAquariumChanges: Bool
    ) -> Bool {
        guard !whileStudyLocked else {
            return false
        }
        return selectedTab == .aquarium &&
            requestedTab != .aquarium &&
            hasUnsavedAquariumChanges
    }
}

enum CoreTutorialTabInteractionPolicy {
    static func canSelect(
        _ tab: MainAppTab,
        step: CoreTutorialStep,
        conversationIndex: Int,
        selectedTab: MainAppTab
    ) -> Bool {
        if step == .aquariumIntro,
           selectedTab == .home,
           conversationIndex == CoreTutorialConversationScript.rewardFollowUp.count - 1 {
            return tab == .aquarium
        }

        if step == .finishing,
           selectedTab == .aquarium,
           conversationIndex == CoreTutorialConversationScript.aquariumReturnHome.count - 1 {
            return tab == .home
        }

        return false
    }
}

enum MainTabBarHitShieldLayout {
    static let tabBarHeight: CGFloat = 54
    static let upperOverflow: CGFloat = 32
    static let zIndex = 1_000.0

    static func height(bottomSafeArea: CGFloat) -> CGFloat {
        tabBarHeight + upperOverflow + max(0, bottomSafeArea)
    }

    static func isActive(whileStudyLocked: Bool) -> Bool {
        whileStudyLocked
    }
}

enum MainTabAquariumActivityPolicy {
    static func isSimulationPaused(
        for aquariumTab: MainAppTab,
        selectedTab: MainAppTab
    ) -> Bool {
        aquariumTab != selectedTab
    }
}

enum AquariumViewingControlsPolicy {
    static let autoHideDelay: TimeInterval = 4
    static let fadeDuration: TimeInterval = 0.25

    static func isEnabled(selectedTab: MainAppTab, tabMode: AquariumTabMode) -> Bool {
        selectedTab == .aquarium && tabMode == .viewing
    }

    static func shouldShowBottomTabBar(
        selectedTab: MainAppTab,
        tabMode: AquariumTabMode,
        areControlsVisible: Bool
    ) -> Bool {
        !isEnabled(selectedTab: selectedTab, tabMode: tabMode) || areControlsVisible
    }
}

enum TimerScenePhaseTrackingAction: Equatable {
    case measureActiveReturn
    case recordBackgroundEntry
    case none
}

enum TimerScenePhaseTrackingPolicy {
    static func action(for scenePhase: ScenePhase) -> TimerScenePhaseTrackingAction {
        switch scenePhase {
        case .active:
            .measureActiveReturn
        case .background:
            .recordBackgroundEntry
        case .inactive:
            .none
        @unknown default:
            .none
        }
    }
}

enum StudyIdleTimerPolicy {
    static func shouldDisableIdleTimer(
        sessionRequiresScreenAwake: Bool,
        applicationIsActive: Bool,
        isPreview: Bool
    ) -> Bool {
        sessionRequiresScreenAwake && applicationIsActive && !isPreview
    }
}

struct MainTabSelectionState {
    private(set) var selection: MainAppTab = .home

    /// Bindingと実際のTabボタンが共有する選択処理。拒否時はselectionを変更しない。
    @discardableResult
    mutating func select(_ requestedTab: MainAppTab, whileStudyLocked: Bool) -> Bool {
        guard MainTabNavigationPolicy.canSelect(
            requestedTab,
            whileStudyLocked: whileStudyLocked
        ) else { return false }
        selection = requestedTab
        return true
    }
}

struct MainTabView: View {
    @Query private var players: [Player]
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @State private var timerViewModel: TimerViewModel
    @State private var tabSelectionState = MainTabSelectionState()
    @State private var aquariumEditorNavigation = AquariumEditorNavigationCoordinator()
    @State private var homeNavigationResetRequestID: UUID?
    @State private var areAquariumViewingControlsVisible = true
    @State private var aquariumViewingControlsAutoHideTask: Task<Void, Never>?
    @State private var coreTutorial: CoreTutorialCoordinator
    @State private var showsCoreTutorialCompletion = false
    @State private var hasReconciledCoreTutorial = false
    @State private var hasCheckedRewardRecovery = false
    @State private var pendingRewardRecovery: RewardHistorySnapshot?
    @State private var replayReward: RewardHistorySnapshot?
    @State private var replayRewardHistoryID: UUID?
    @State private var showsRewardRecoveryPrompt = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let appDefaults: UserDefaults
    private let coreTutorialMode: CoreTutorialMode
    private let onCoreTutorialPreviewFinished: () -> Void

    init(
        coreTutorialMode: CoreTutorialMode = .production,
        defaults: UserDefaults = .standard,
        timerSessionStore: TimerSessionStore? = nil,
        notificationService: TimerNotificationScheduling? = nil,
        onCoreTutorialPreviewFinished: @escaping () -> Void = {}
    ) {
        TimerConfigurationStorage.migrateLegacyValuesIfNeeded(in: defaults)
        let resolvedSessionStore = timerSessionStore ?? (
            coreTutorialMode == .production
                ? TimerSessionStore.shared
                : TimerSessionStore(defaults: defaults)
        )
        let studyMinutes = Int(defaults.string(
            forKey: TimerConfigurationStorageKey.pomodoroStudyDuration
        ) ?? "") ?? 25
        let preferredBreakMinutes = Int(defaults.string(
            forKey: TimerConfigurationStorageKey.pomodoroBreakDuration
        ) ?? "") ?? PomodoroBreakConfiguration.defaultBreakMinutes
        let setCount = PomodoroBreakConfiguration.configuredSetCount(in: defaults)
        _timerViewModel = State(initialValue: TimerViewModel(
            studyTime: studyMinutes,
            breakTime: PomodoroBreakConfiguration.effectiveBreakMinutes(
                preferredMinutes: preferredBreakMinutes,
                setCount: setCount
            ),
            totalSets: setCount,
            now: Date.init,
            sessionStore: resolvedSessionStore,
            notificationService: notificationService ?? NotificationService.appDefault
        ))
        _coreTutorial = State(initialValue: CoreTutorialCoordinator(
            mode: coreTutorialMode,
            defaults: defaults,
            timerSessionStore: resolvedSessionStore
        ))
        self.appDefaults = defaults
        self.coreTutorialMode = coreTutorialMode
        self.onCoreTutorialPreviewFinished = onCoreTutorialPreviewFinished
    }

    private var player: Player? { players.first }

    private var tabSelection: Binding<MainAppTab> {
        Binding(
            get: { tabSelectionState.selection },
            set: { requestedTab in
                _ = requestTabSelection(requestedTab)
            }
        )
    }

    var body: some View {
        GeometryReader { geometry in
            TabView(selection: tabSelection) {
                Tab(value: MainAppTab.home) {
                    HomeView(
                        timerViewModel: timerViewModel,
                        mode: .home,
                        isAquariumSimulationPaused: MainTabAquariumActivityPolicy
                            .isSimulationPaused(
                                for: .home,
                                selectedTab: tabSelectionState.selection
                            ),
                        homeNavigationResetRequestID: homeNavigationResetRequestID,
                        appDefaults: appDefaults,
                        coreTutorial: coreTutorial,
                        showsCoreTutorialCompletion: showsCoreTutorialCompletion,
                        coreTutorialCompletionButtonTitle: coreTutorialMode == .preview
                            ? "プレビュー終了"
                            : "はじめる",
                        onDismissCoreTutorialCompletion: {
                            if coreTutorialMode == .preview {
                                onCoreTutorialPreviewFinished()
                            } else {
                                showsCoreTutorialCompletion = false
                            }
                        }
                    )
                    .toolbarVisibility(.hidden, for: .tabBar)
                } label: {
                    Label("ホーム", systemImage: "house.fill")
                }

                Tab(value: MainAppTab.aquarium) {
                    HomeView(
                        timerViewModel: timerViewModel,
                        mode: .aquariumEditor,
                        isAquariumSimulationPaused: MainTabAquariumActivityPolicy
                            .isSimulationPaused(
                                for: .aquarium,
                                selectedTab: tabSelectionState.selection
                            ),
                        isAquariumEditorActive: tabSelectionState.selection == .aquarium,
                        aquariumEditorNavigation: aquariumEditorNavigation,
                        onFinishAquariumEditing: { destination in
                            tabSelectionState.select(
                                destination,
                                whileStudyLocked: timerViewModel.locksMainTabNavigation
                            )
                        },
                        areAquariumViewingControlsVisible: areAquariumViewingControlsVisible,
                        onAquariumViewingInteraction: showAndScheduleAquariumViewingControls,
                        appDefaults: appDefaults,
                        coreTutorial: coreTutorial
                    )
                    .toolbarVisibility(.hidden, for: .tabBar)
                } label: {
                    Label("水槽", systemImage: "fish.fill")
                }

                Tab(value: MainAppTab.shop) {
                    NavigationStack {
                        ShopView()
                    }
                    .toolbarVisibility(.hidden, for: .tabBar)
                } label: {
                    Label("ショップ", systemImage: "storefront.fill")
                }

                Tab(value: MainAppTab.statistics) {
                    NavigationStack {
                        StatisticsView(player: player)
                    }
                    .toolbarVisibility(.hidden, for: .tabBar)
                } label: {
                    Label("統計", systemImage: "chart.bar.fill")
                }

                Tab(value: MainAppTab.more) {
                    NavigationStack {
                        MoreView()
                    }
                    .toolbarVisibility(.hidden, for: .tabBar)
                } label: {
                    Label("その他", systemImage: "ellipsis.circle.fill")
                }
            }
            .toolbarVisibility(.hidden, for: .tabBar)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                customTabBar
                    .opacity(shouldShowBottomTabBar ? 1 : 0)
                    .allowsHitTesting(shouldShowBottomTabBar)
                    .accessibilityHidden(!shouldShowBottomTabBar)
                    .animation(
                        .easeInOut(duration: AquariumViewingControlsPolicy.fadeDuration),
                        value: shouldShowBottomTabBar
                    )
            }
            .overlayPreferenceValue(CoreTutorialTargetPreferenceKey.self) { targets in
                GeometryReader { tutorialGeometry in
                    coreTutorialTabOverlay(
                        geometry: tutorialGeometry,
                        targets: targets
                    )
                }
            }
            .overlay(alignment: .bottom) {
                if MainTabBarHitShieldLayout.isActive(
                    whileStudyLocked: timerViewModel.locksMainTabNavigation
                ) {
                    tabBarHitShield(bottomSafeArea: geometry.safeAreaInsets.bottom)
                }
            }
            .tint(.cyan)
            .onReceive(timer) { _ in
                timerViewModel.tick()
            }
            .onChange(of: scenePhase) { _, newPhase in
                switch TimerScenePhaseTrackingPolicy.action(for: newPhase) {
                case .measureActiveReturn:
                    timerViewModel.recordActiveReturn()
                    timerViewModel.synchronizeTime()
                    updateAquariumViewingControlsAutoHide()
                case .recordBackgroundEntry:
                    timerViewModel.recordLastActiveTime()
                    stopAquariumViewingControlsAutoHide()
                case .none:
                    break
                }
                synchronizeIdleTimer()
            }
            .onChange(of: timerViewModel.requiresIdleTimerDisabled) { _, _ in
                synchronizeIdleTimer()
            }
            .onChange(of: timerViewModel.locksMainTabNavigation) { _, isLocked in
                if isLocked {
                    stopAquariumViewingControlsAutoHide()
                    tabSelectionState.select(.home, whileStudyLocked: false)
                }
            }
            .onChange(of: tabSelectionState.selection) { _, _ in
                updateAquariumViewingControlsAutoHide()
            }
            .onChange(of: aquariumEditorNavigation.tabMode) { _, _ in
                updateAquariumViewingControlsAutoHide()
            }
            .onDisappear {
                aquariumViewingControlsAutoHideTask?.cancel()
                aquariumViewingControlsAutoHideTask = nil
                setIdleTimerDisabled(false)
            }
            .onAppear {
                reconcileCoreTutorialIfNeeded()
                checkForUnacknowledgedRewardIfNeeded()
                synchronizeIdleTimer()
            }
            .onChange(of: players.count) { _, _ in
                reconcileCoreTutorialIfNeeded()
            }
        }
        .alert("前回の報酬があります", isPresented: $showsRewardRecoveryPrompt) {
            Button("あとで", role: .cancel) {
                pendingRewardRecovery = nil
            }
            Button("見る") {
                guard let pendingRewardRecovery else { return }
                replayRewardHistoryID = pendingRewardRecovery.id
                replayReward = pendingRewardRecovery
                self.pendingRewardRecovery = nil
            }
        } message: {
            Text("獲得した魚とポイントをもう一度確認しますか？")
        }
        .fullScreenCover(item: $replayReward, onDismiss: acknowledgeReplayedReward) { reward in
            FishRewardView(result: reward.replayResult())
        }
    }

    private func tabBarHitShield(bottomSafeArea: CGFloat) -> some View {
        Rectangle()
            .fill(.clear)
            .frame(maxWidth: .infinity)
            .frame(height: MainTabBarHitShieldLayout.height(
                bottomSafeArea: bottomSafeArea
            ))
            .contentShape(Rectangle())
            .onTapGesture { }
            .allowsHitTesting(true)
            .ignoresSafeArea(edges: .bottom)
            .zIndex(MainTabBarHitShieldLayout.zIndex)
            .accessibilityLabel("勉強中はタブ操作不可")
            .accessibilityIdentifier("mainTab.hitShield")
    }

    private var customTabBar: some View {
        HStack(spacing: 0) {
            ForEach(MainAppTab.allCases) { tab in
                Button {
                    guard requestTabSelection(tab) else { return }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 18, weight: .semibold))
                        Text(tab.title)
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(
                        tabSelectionState.selection == tab ? Color.cyan : Color.secondary
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .opacity(MainTabNavigationPolicy.opacity(
                    for: tab,
                    whileStudyLocked: timerViewModel.locksMainTabNavigation
                ))
                .disabled(!MainTabNavigationPolicy.canSelect(
                    tab,
                    whileStudyLocked: timerViewModel.locksMainTabNavigation
                ) || !coreTutorialAllowsSelecting(tab))
                .accessibilityHidden(coreTutorial.isActive && !coreTutorialAllowsSelecting(tab))
                .accessibilityLabel(tab.title)
                .accessibilityIdentifier(tab.accessibilityIdentifier)
                .accessibilityAddTraits(
                    tabSelectionState.selection == tab ? .isSelected : []
                )
                .anchorPreference(
                    key: CoreTutorialTargetPreferenceKey.self,
                    value: .bounds
                ) { anchor in
                    switch tab {
                    case .home:
                        [.homeTab: anchor]
                    case .aquarium:
                        [.aquariumTab: anchor]
                    default:
                        [:]
                    }
                }
            }
        }
        .frame(height: MainTabBarHitShieldLayout.tabBarHeight)
        .padding(.horizontal, 8)
        .background(.bar)
        .overlay(alignment: .top) {
            Divider()
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("mainTab.customTabBar")
    }

    private var isAquariumViewingControlsAutoHideActive: Bool {
        if coreTutorial.isActive,
           coreTutorial.step == .aquariumIntro || coreTutorial.step == .finishing {
            return false
        }
        return AquariumViewingControlsPolicy.isEnabled(
            selectedTab: tabSelectionState.selection,
            tabMode: aquariumEditorNavigation.tabMode
        )
    }

    private var shouldShowBottomTabBar: Bool {
        AquariumViewingControlsPolicy.shouldShowBottomTabBar(
            selectedTab: tabSelectionState.selection,
            tabMode: aquariumEditorNavigation.tabMode,
            areControlsVisible: areAquariumViewingControlsVisible
        )
    }

    private func showAndScheduleAquariumViewingControls() {
        aquariumViewingControlsAutoHideTask?.cancel()
        aquariumViewingControlsAutoHideTask = nil

        withAnimation(.easeInOut(duration: AquariumViewingControlsPolicy.fadeDuration)) {
            areAquariumViewingControlsVisible = true
        }

        guard isAquariumViewingControlsAutoHideActive else { return }
        aquariumViewingControlsAutoHideTask = Task { @MainActor in
            do {
                try await Task.sleep(
                    for: .seconds(AquariumViewingControlsPolicy.autoHideDelay)
                )
            } catch {
                return
            }
            guard !Task.isCancelled, isAquariumViewingControlsAutoHideActive else { return }
            withAnimation(.easeInOut(duration: AquariumViewingControlsPolicy.fadeDuration)) {
                areAquariumViewingControlsVisible = false
            }
            aquariumViewingControlsAutoHideTask = nil
        }
    }

    private func stopAquariumViewingControlsAutoHide() {
        aquariumViewingControlsAutoHideTask?.cancel()
        aquariumViewingControlsAutoHideTask = nil
        areAquariumViewingControlsVisible = true
    }

    private func synchronizeIdleTimer() {
        let shouldDisable = StudyIdleTimerPolicy.shouldDisableIdleTimer(
            sessionRequiresScreenAwake: timerViewModel.requiresIdleTimerDisabled,
            applicationIsActive: scenePhase == .active,
            isPreview: coreTutorialMode == .preview
        )
        setIdleTimerDisabled(shouldDisable)
    }

    private func setIdleTimerDisabled(_ isDisabled: Bool) {
        guard UIApplication.shared.isIdleTimerDisabled != isDisabled else { return }
        UIApplication.shared.isIdleTimerDisabled = isDisabled
    }

    private func updateAquariumViewingControlsAutoHide() {
        if isAquariumViewingControlsAutoHideActive {
            showAndScheduleAquariumViewingControls()
        } else {
            stopAquariumViewingControlsAutoHide()
        }
    }

    @discardableResult
    private func requestTabSelection(_ requestedTab: MainAppTab) -> Bool {
        guard coreTutorialAllowsSelecting(requestedTab) else { return false }
        let isStudyLocked = timerViewModel.locksMainTabNavigation
        guard MainTabNavigationPolicy.canSelect(
            requestedTab,
            whileStudyLocked: isStudyLocked
        ) else {
            return false
        }

        if MainTabNavigationPolicy.shouldResetHomeNavigation(
            currentTab: tabSelectionState.selection,
            requestedTab: requestedTab,
            whileStudyLocked: isStudyLocked
        ) {
            homeNavigationResetRequestID = UUID()
            return true
        }

        if isAquariumViewingControlsAutoHideActive {
            if requestedTab == .aquarium {
                showAndScheduleAquariumViewingControls()
            } else {
                stopAquariumViewingControlsAutoHide()
            }
        }

        if MainTabNavigationPolicy.requiresAquariumSaveConfirmation(
            from: tabSelectionState.selection,
            to: requestedTab,
            whileStudyLocked: isStudyLocked,
            hasUnsavedAquariumChanges: aquariumEditorNavigation.hasUnsavedChanges
        ) {
            aquariumEditorNavigation.requestConfirmation(beforeSelecting: requestedTab)
            return false
        }

        if tabSelectionState.selection == .aquarium,
           requestedTab != .aquarium,
           aquariumEditorNavigation.tabMode == .editing {
            aquariumEditorNavigation.finishSession()
        }
        let previousTab = tabSelectionState.selection
        aquariumEditorNavigation.continueEditing()
        let didSelect = tabSelectionState.select(requestedTab, whileStudyLocked: false)
        if didSelect {
            if previousTab == .home,
               requestedTab == .aquarium,
               coreTutorial.step == .aquariumIntro,
               coreTutorial.conversationIndex == CoreTutorialConversationScript.rewardFollowUp.count - 1 {
                coreTutorial.didSelectAquariumTab()
            } else if previousTab == .aquarium,
                      requestedTab == .home,
                      coreTutorial.step == .finishing,
                      coreTutorial.conversationIndex == CoreTutorialConversationScript.aquariumReturnHome.count - 1 {
                coreTutorial.didSelectHomeTabAfterAquarium()
            }
            updateAquariumViewingControlsAutoHide()
        }
        return didSelect
    }

    private func reconcileCoreTutorialIfNeeded() {
        guard !hasReconciledCoreTutorial, let player else { return }
        coreTutorial.reconcile(with: player)
        hasReconciledCoreTutorial = true
    }

    private func checkForUnacknowledgedRewardIfNeeded() {
        guard !hasCheckedRewardRecovery,
              coreTutorialMode == .production,
              !coreTutorial.isActive else { return }
        hasCheckedRewardRecovery = true
        guard let entry = try? RewardHistoryService.latestUnacknowledged(in: modelContext) else {
            return
        }
        pendingRewardRecovery = RewardHistorySnapshot(entry: entry)
        showsRewardRecoveryPrompt = true
    }

    private func acknowledgeReplayedReward() {
        guard let replayRewardHistoryID else { return }
        try? RewardHistoryService.acknowledge(id: replayRewardHistoryID, in: modelContext)
        self.replayRewardHistoryID = nil
    }

    private func coreTutorialAllowsSelecting(_ tab: MainAppTab) -> Bool {
        guard coreTutorial.isActive else { return true }
        return CoreTutorialTabInteractionPolicy.canSelect(
            tab,
            step: coreTutorial.step,
            conversationIndex: coreTutorial.conversationIndex,
            selectedTab: tabSelectionState.selection
        )
    }

    @ViewBuilder
    private func coreTutorialTabOverlay(
        geometry: GeometryProxy,
        targets: [CoreTutorialTarget: Anchor<CGRect>]
    ) -> some View {
        if coreTutorial.isActive,
           coreTutorial.step == .aquariumIntro,
           tabSelectionState.selection == .home,
           coreTutorial.conversationIndex == CoreTutorialConversationScript.rewardFollowUp.count - 1 {
            CoreTutorialSpotlightStep(
                targetFrame: targets[.aquariumTab].map { geometry[$0] },
                page: CoreTutorialConversationScript.rewardFollowUp.last!,
                pageIndex: coreTutorial.conversationIndex,
                showsPointingHand: true,
                allowsConversationAdvance: false,
                allowsTargetInteraction: true,
                accessibilityIdentifier: "coreTutorial.aquariumTabPrompt"
            )
        } else if coreTutorial.isActive,
                  coreTutorial.step == .finishing,
                  tabSelectionState.selection == .aquarium,
                  coreTutorial.conversationIndex == CoreTutorialConversationScript.aquariumReturnHome.count - 1 {
            CoreTutorialSpotlightStep(
                targetFrame: targets[.homeTab].map { geometry[$0] },
                page: CoreTutorialConversationScript.aquariumReturnHome.last!,
                pageIndex: coreTutorial.conversationIndex,
                showsPointingHand: true,
                allowsConversationAdvance: false,
                allowsTargetInteraction: true,
                accessibilityIdentifier: "coreTutorial.homeTabPrompt"
            )
        }
    }
}

#Preview {
    MainTabView()
        .modelContainer(
            for: [
                Player.self,
                PlayerFish.self,
                AquariumDecorationPlacement.self,
                StudyDailyRecord.self,
                RewardHistoryEntry.self
            ],
            inMemory: true
        )
}
