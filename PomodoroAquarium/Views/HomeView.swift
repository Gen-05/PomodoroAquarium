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

struct HomeView: View {
    let timerViewModel: TimerViewModel
    var mode: HomeViewMode = .home
    var isAquariumSimulationPaused = false
    var isAquariumEditorActive = false
    var aquariumEditorNavigation: AquariumEditorNavigationCoordinator?
    var onFinishAquariumEditing: (MainAppTab) -> Void = { _ in }
    var areAquariumViewingControlsVisible = true
    var onAquariumViewingInteraction: () -> Void = {}
    var homeNavigationResetRequestID: UUID?
    
    @AppStorage("studyTime") private var studyTime = "25"
    @AppStorage("breakTime") private var breakTime = "5"
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
    @Query private var decorationPlacements: [AquariumDecorationPlacement]
    @State private var showsInterruptionBanner = false
    @State private var showsTimerScreen = false
    @State private var isEditingAquarium = false
    @State private var aquariumEditorCategory: AquariumEditorCategory = .fish
    @State private var selectedAquariumFishID: UUID?
    @State private var aquariumSelectionResetRequestID: UUID?
    @State private var fishDragSession: AquariumFishDragSession?
    @State private var decorationDragSession: AquariumDecorationDragSession?
    @State private var isEditorPanelExpanded = true
    @State private var editorSessionSnapshot: AquariumEditorSessionSnapshot?
    @State private var draftBackgroundTheme: AquariumBackgroundTheme?
    @State private var showsAquariumEditConfirmation = false
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
        players.first
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

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let editorWidth = AquariumSideEditorLayout.width(for: geometry.size.width)
                let aquariumWidth = AquariumSideEditorLayout.aquariumWidth(
                    for: geometry.size.width,
                    isEditing: isAquariumEditorPresented,
                    isPanelExpanded: isEditorPanelExpanded
                )
                let aquariumSize = CGSize(width: aquariumWidth, height: geometry.size.height)

                ZStack(alignment: .trailing) {
                    AquariumView(
                        player: player,
                        backgroundTheme: displayedBackgroundTheme,
                        isSimulationPaused: isAquariumSimulationPaused,
                        isEditing: isAquariumEditorPresented && aquariumEditorCategory == .decoration,
                        defersDecorationPersistence: mode == .aquariumEditor,
                        isFishSelectionEnabled: isAquariumEditorPresented && aquariumEditorCategory == .fish,
                        selectedFishID: selectedAquariumFishID,
                        onFishSelected: selectAquariumFish,
                        onCanvasTapped: clearAquariumSelections,
                        onDecorationChanged: markAquariumEditorChanged,
                        onDecorationEditingChanged: { isEditingDecoration in
                            if isEditingDecoration {
                                selectedAquariumFishID = nil
                            }
                        },
                        selectionResetRequestID: aquariumSelectionResetRequestID
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
                        selectedFishRemovalControl(aquariumWidth: aquariumWidth)
                        editorCompletionControl(aquariumWidth: aquariumWidth)

                        if isEditorPanelExpanded {
                            AquariumSideEditor(
                                player: player,
                                decorationPlacements: decorationPlacements,
                                selectedBackgroundTheme: displayedBackgroundTheme,
                                panelWidth: editorWidth,
                                selectedCategory: $aquariumEditorCategory,
                                updateFishDrag: updateFishDrag,
                                finishFishDrag: { species, location in
                                    finishFishDrag(
                                        species: species,
                                        at: location,
                                        aquariumSize: aquariumSize
                                    )
                                },
                                cancelFishDrag: cancelFishDrag,
                                updateDecorationDrag: updateDecorationDrag,
                                finishDecorationDrag: { decorationID, location in
                                    finishDecorationDrag(
                                        decorationID: decorationID,
                                        at: location,
                                        aquariumSize: aquariumSize
                                    )
                                },
                                cancelDecorationDrag: cancelDecorationDrag,
                                selectBackground: selectBackground,
                                finishEditing: finishAquariumEditing,
                                collapse: collapseEditorPanel,
                                showTutorial: showAquariumEditorTutorial,
                                showsFinishButton: mode != .aquariumEditor
                            )
                            .frame(height: geometry.size.height)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                            .zIndex(30)
                        } else {
                            collapsedEditorHandle
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                                .zIndex(30)
                        }

                        if let fishDragSession {
                            AquariumFishDragPreview(species: fishDragSession.species)
                                .position(fishDragSession.location)
                                .zIndex(50)
                        }

                        if let decorationDragSession,
                           let placement = decorationPlacements.first(where: {
                               $0.decorationID == decorationDragSession.decorationID
                           }) {
                            AquariumDecorationDragPreview(decoration: placement.decoration)
                                .position(decorationDragSession.location)
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
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showsTimerScreen) {
                TimerView(
                    studyTime: Int(studyTime) ?? 25,
                    breakTime: Int(breakTime) ?? 5,
                    player: player,
                    viewModel: timerViewModel
                )
            }
        }
        .onAppear {
            if mode == .home {
                inspectPersistedTimerSession()
                DailyFishAcquisitionStore.resetIfNeeded()
            }
            let now = Date()
            let calendar = Calendar.current
            let today = DateFormatter.yyyyMMdd.string(from: now)

            let currentPlayer: Player
            if let player {
                currentPlayer = player
            } else {
                let newPlayer = Player()
                modelContext.insert(newPlayer)
                currentPlayer = newPlayer
            }

            if AquariumFishSelection.initializeIfNeeded(for: currentPlayer) {
                try? modelContext.save()
            }

            if lastStudyDate.isEmpty {
                lastStudyDate = today
            } else if let lastDate = DateFormatter.yyyyMMdd.date(from: lastStudyDate),
                      !calendar.isDate(lastDate, inSameDayAs: now) {
                let yesterday = calendar.date(byAdding: .day, value: -1, to: now)

                if let yesterday,
                   calendar.isDate(lastDate, inSameDayAs: yesterday) {
                    currentPlayer.yesterdayStudyMinutes = currentPlayer.todayStudyMinutes
                } else {
                    currentPlayer.yesterdayStudyMinutes = 0
                }

                currentPlayer.todayStudyMinutes = 0
                lastStudyDate = today
            } else if DateFormatter.yyyyMMdd.date(from: lastStudyDate) == nil {
                currentPlayer.yesterdayStudyMinutes = 0
                currentPlayer.todayStudyMinutes = 0
                lastStudyDate = today
            }

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
            showsTimerScreen = false
        }
        .onChange(of: isAquariumEditorPresented) { _, isEditing in
            if !isEditing {
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
        }
        .onChange(of: isAquariumEditorActive) { _, isActive in
            if !isActive, !hasUnsavedAquariumEditorChanges {
                resetAquariumEditorSession()
            }
        }
        .onChange(of: aquariumEditorNavigation?.confirmationRequestID) { _, requestID in
            if requestID != nil, isAquariumEditorActive {
                showsEditorSaveConfirmation = true
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                discardAquariumEditorSession(closeEditor: false)
            }
        }
        .alert("水槽を編集しますか？", isPresented: $showsAquariumEditConfirmation) {
            Button("編集する") {
                beginAquariumEditorSessionIfNeeded(player: player)
            }
            Button("キャンセル", role: .cancel) {}
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
            Button("変更を破棄", role: .destructive) {
                discardAquariumEditorSession(closeEditor: true)
            }
            Button("編集を続ける", role: .cancel) {
                continueAquariumEditing()
            }
        }
    }

    private var regularHomeControls: some View {
        VStack(spacing: 0) {
            homeStatusRow

            Spacer(minLength: 24)

            Button {
                showsTimerScreen = true
            } label: {
                Label(
                    HomeTimerEntryPresentation.title(
                        for: timerViewModel.phase,
                        state: timerViewModel.state
                    ),
                    systemImage: "timer"
                )
            }
            .buttonStyle(AquariumStudyStartButtonStyle())
            .frame(maxWidth: 290)
            .accessibilityIdentifier("home.startStudy")

            Spacer(minLength: 24)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        // AquariumViewは全面描画するため、Homeの主要操作だけ実TabBar高ぶん確実に退避する。
        .padding(.bottom, 24 + MainTabBarHitShieldLayout.tabBarHeight)
    }

    private var homeStatusRow: some View {
        HStack(alignment: .top, spacing: 8) {
            dailyFishProgress

            Spacer(minLength: 2)

            VStack(spacing: 2) {
                Text("今日 \(HomeDashboardPresentation.studyDurationText(minutes: player?.todayStudyMinutes ?? 0))")
                    .accessibilityIdentifier("home.todayStudyMinutes")
                Text("昨日 \(HomeDashboardPresentation.studyDurationText(minutes: player?.yesterdayStudyMinutes ?? 0))")
                    .accessibilityIdentifier("home.yesterdayStudyMinutes")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .aquariumGlass(cornerRadius: 14)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("home.studySummary")

            Spacer(minLength: 2)

            HStack(spacing: 5) {
                Image(systemName: "circle.hexagongrid.fill")
                Text("\(CurrencyService.balance(of: player))")
                    .monospacedDigit()
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(.yellow)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
            .aquariumGlass(cornerRadius: 14)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("所持コイン \(CurrencyService.balance(of: player))枚")
            .accessibilityIdentifier("home.coinBalance")
            .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity)
    }

    private var dailyFishProgress: some View {
        HStack(spacing: 5) {
            Image(systemName: "fish.fill")
            Text("\(todayFishAcquisitionCount) / \(DailyFishAcquisitionPolicy.basicLimit)")
                .monospacedDigit()

            Button {
                showsDailyFishLimitInformation = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.body)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("魚の獲得上限を増やす")
            .accessibilityIdentifier("home.increaseDailyFishLimit")
        }
        .font(.caption.weight(.bold))
        .foregroundStyle(.white)
        .fixedSize(horizontal: true, vertical: false)
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .aquariumGlass(cornerRadius: 14)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            "今日の魚獲得数 \(todayFishAcquisitionCount)匹、基本上限 \(DailyFishAcquisitionPolicy.basicLimit)匹"
        )
        .accessibilityIdentifier("home.dailyFishProgress")
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
        guard isAquariumEditorPresented,
              AquariumSideEditorLayout.acceptsDrop(at: location, in: aquariumSize) else {
            return false
        }

        for item in items {
            switch item.kind {
            case .fish:
                guard let player,
                      AquariumEditorDropCoordinator.addFish(from: item, to: player) else {
                    continue
                }
                markAquariumEditorChanged()
                return true

            case .decoration:
                guard let placement = decorationPlacements.first(where: {
                    $0.decorationID == item.identifier
                }) else { continue }
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

    private func selectAquariumFish(_ playerFishID: UUID) {
        guard isAquariumEditorPresented,
              aquariumEditorCategory == .fish,
              player?.activeAquariumFishIDs.contains(playerFishID) == true else { return }
        aquariumSelectionResetRequestID = UUID()
        selectedAquariumFishID = playerFishID
    }

    private func clearAquariumSelections() {
        selectedAquariumFishID = nil
        aquariumSelectionResetRequestID = UUID()
    }

    private func updateFishDrag(species: FishSpecies, location: CGPoint) {
        guard isAquariumEditorPresented, aquariumEditorCategory == .fish else {
            fishDragSession = nil
            return
        }
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
              let player,
              AquariumEditorDropCoordinator.completeFishDrag(
                species: species,
                at: location,
                aquariumSize: aquariumSize,
                player: player
              ) else { return }
        markAquariumEditorChanged()
    }

    private func cancelFishDrag() {
        fishDragSession = nil
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
    }

    private func finishDecorationDrag(
        decorationID: String,
        at location: CGPoint,
        aquariumSize: CGSize
    ) {
        defer { decorationDragSession = nil }
        guard isAquariumEditorPresented,
              aquariumEditorCategory == .decoration,
              decorationDragSession?.decorationID == decorationID,
              AquariumSideEditorLayout.acceptsDrop(at: location, in: aquariumSize),
              let placement = decorationPlacements.first(where: {
                  $0.decorationID == decorationID && !$0.isPlaced
              }) else { return }

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
        } catch {}
    }

    private func cancelDecorationDrag() {
        decorationDragSession = nil
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

    private func removeSelectedAquariumFish() {
        guard let selectedAquariumFishID,
              let player,
              player.removeFishFromAquarium(playerFishID: selectedAquariumFishID) else { return }
        self.selectedAquariumFishID = nil
        markAquariumEditorChanged()
    }

    @ViewBuilder
    private func selectedFishRemovalControl(aquariumWidth: CGFloat) -> some View {
        if aquariumEditorCategory == .fish,
           let selectedAquariumFishID,
           player?.activeAquariumFishIDs.contains(selectedAquariumFishID) == true {
            VStack {
                Spacer()
                Button(action: removeSelectedAquariumFish) {
                    Label("水槽から戻す", systemImage: "arrow.uturn.backward.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 13)
                        .background(.red.opacity(0.82), in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.4), lineWidth: 1))
                        .shadow(color: .black.opacity(0.24), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("aquariumEditor.removeSelectedFish")
            }
            .padding(.bottom, AquariumSideEditorLayout.excludedDropBottomHeight + 8)
            .frame(width: aquariumWidth)
            .frame(maxHeight: .infinity)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .allowsHitTesting(true)
            .zIndex(25)
        }
    }

    @ViewBuilder
    private var aquariumEditingEntryControl: some View {
        VStack {
            HStack {
                Spacer(minLength: 0)
                Button {
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
                    Button(action: finishAquariumEditing) {
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
        aquariumEditorNavigation?.markChanged()
    }

    private func beginAquariumEditorSessionIfNeeded(player: Player?) {
        guard mode == .aquariumEditor,
              isAquariumEditorActive,
              aquariumEditorNavigation?.tabMode == .viewing,
              editorSessionSnapshot == nil,
              let player else { return }

        _ = try? AquariumDecorationService.createDefaultsIfNeeded(in: modelContext)
        let currentPlacements = (try? modelContext.fetch(
            FetchDescriptor<AquariumDecorationPlacement>()
        )) ?? decorationPlacements

        draftBackgroundTheme = savedBackgroundTheme
        editorSessionSnapshot = AquariumEditorSessionSnapshot.capture(
            player: player,
            decorationPlacements: currentPlacements,
            backgroundTheme: savedBackgroundTheme
        )
        aquariumEditorCategory = .fish
        clearAquariumSelections()
        fishDragSession = nil
        decorationDragSession = nil
        isEditorPanelExpanded = true
        showsAquariumEditorTutorial = !hasSeenAquariumEditorTutorial
        aquariumEditorNavigation?.beginSession()
    }

    private func saveAquariumEditorSession() {
        guard mode == .aquariumEditor else { return }
        let destination = aquariumEditorNavigation?.pendingTabSelection
        backgroundThemeRawValue = displayedBackgroundTheme.rawValue
        try? modelContext.save()
        endAquariumEditorSession(selecting: destination)
    }

    private func discardAquariumEditorSession(closeEditor: Bool) {
        guard mode == .aquariumEditor,
              let editorSessionSnapshot else { return }

        let destination = aquariumEditorNavigation?.pendingTabSelection
        if hasUnsavedAquariumEditorChanges {
            editorSessionSnapshot.restore(
                player: player,
                decorationPlacements: decorationPlacements
            )
            draftBackgroundTheme = editorSessionSnapshot.backgroundTheme
            // SwiftDataのautosaveが途中で走っていても、破棄状態を正式値として戻す。
            try? modelContext.save()
        }

        if closeEditor {
            endAquariumEditorSession(selecting: destination)
        } else {
            resetAquariumEditorSession()
        }
    }

    private func continueAquariumEditing() {
        aquariumEditorNavigation?.continueEditing()
        showsEditorSaveConfirmation = false
    }

    private func resetAquariumEditorSession() {
        editorSessionSnapshot = nil
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

        if hasUnsavedAquariumEditorChanges {
            aquariumEditorNavigation?.requestFinishConfirmation()
            // dirty flagの参照だけで即時に表示し、snapshot比較や保存は行わない。
            showsEditorSaveConfirmation = true
        } else {
            endAquariumEditorSession(selecting: nil)
        }
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
                AquariumDecorationView(decoration: placement.decoration)
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
                LinearGradient(
                    colors: theme.fallbackColors,
                    startPoint: .top,
                    endPoint: .bottom
                )
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
                Text("前回の勉強は中断されました")
                    .font(.subheadline.weight(.semibold))
                Text("勉強時間と魚獲得には反映されません")
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

    private func inspectPersistedTimerSession() {
        switch TimerSessionStore.shared.launchStatus(at: Date()) {
        case .recoverable, .expired:
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
            "勉強をはじめる"
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
