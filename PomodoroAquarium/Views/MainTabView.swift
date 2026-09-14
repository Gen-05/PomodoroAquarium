import Combine
import SwiftData
import SwiftUI

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
    @State private var timerViewModel: TimerViewModel
    @State private var tabSelectionState = MainTabSelectionState()
    @State private var aquariumEditorNavigation = AquariumEditorNavigationCoordinator()
    @State private var homeNavigationResetRequestID: UUID?
    @State private var areAquariumViewingControlsVisible = true
    @State private var aquariumViewingControlsAutoHideTask: Task<Void, Never>?

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init() {
        let defaults = UserDefaults.standard
        let studyMinutes = Int(defaults.string(
            forKey: TimerConfigurationStorageKey.studyTime
        ) ?? "") ?? 25
        let preferredBreakMinutes = Int(defaults.string(
            forKey: TimerConfigurationStorageKey.breakTime
        ) ?? "") ?? PomodoroBreakConfiguration.defaultBreakMinutes
        let setCount = PomodoroBreakConfiguration.configuredSetCount(in: defaults)
        _timerViewModel = State(initialValue: TimerViewModel(
            studyTime: studyMinutes,
            breakTime: PomodoroBreakConfiguration.effectiveBreakMinutes(
                preferredMinutes: preferredBreakMinutes,
                setCount: setCount
            ),
            totalSets: setCount
        ))
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
                        homeNavigationResetRequestID: homeNavigationResetRequestID
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
                        onAquariumViewingInteraction: showAndScheduleAquariumViewingControls
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
                if newPhase == .active {
                    timerViewModel.synchronizeTime()
                    updateAquariumViewingControlsAutoHide()
                } else {
                    timerViewModel.recordLastActiveTime()
                    stopAquariumViewingControlsAutoHide()
                }
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
            }
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
                ))
                .accessibilityLabel(tab.title)
                .accessibilityIdentifier(tab.accessibilityIdentifier)
                .accessibilityAddTraits(
                    tabSelectionState.selection == tab ? .isSelected : []
                )
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
        AquariumViewingControlsPolicy.isEnabled(
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

    private func updateAquariumViewingControlsAutoHide() {
        if isAquariumViewingControlsAutoHideActive {
            showAndScheduleAquariumViewingControls()
        } else {
            stopAquariumViewingControlsAutoHide()
        }
    }

    @discardableResult
    private func requestTabSelection(_ requestedTab: MainAppTab) -> Bool {
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
        aquariumEditorNavigation.continueEditing()
        let didSelect = tabSelectionState.select(requestedTab, whileStudyLocked: false)
        if didSelect {
            updateAquariumViewingControlsAutoHide()
        }
        return didSelect
    }
}

#Preview {
    MainTabView()
        .modelContainer(
            for: [Player.self, PlayerFish.self, AquariumDecorationPlacement.self, StudyDailyRecord.self],
            inMemory: true
        )
}
