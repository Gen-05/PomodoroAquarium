//
//  TimerView.swift
//  PomodoroAquarium
//
//  Created by 阿部弦生 on 2026/07/13.
//

import SwiftUI
import SwiftData

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
        }
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
        self._viewModel = State(initialValue: tempViewModel)
        self._fishAcquisition = State(initialValue: nil)
        self._pendingFishAcquisition = State(initialValue: nil)
        self._completionReward = State(initialValue: nil)
        self._pendingCompletionReward = State(initialValue: nil)
    }
    
    @State private var viewModel: TimerViewModel
    @State private var fishAcquisition: FishAcquisitionResult?
    @State private var pendingFishAcquisition: FishAcquisitionResult?
    @State private var completionReward: StudyCompletionReward?
    @State private var pendingCompletionReward: StudyCompletionReward?
    @State private var rewardHistoryID: UUID?
    @State private var studyFinishedMinutes: Int?
    @State private var studyFinishedEndReason: StudySessionEndReason = .completed
    @State private var showsEndConfirmation = false
    @State private var showsTimeSettings = false
    @State private var showsFocusRules = false
    @State private var showsNotificationIntroduction = false
    @State private var tutorialCompletionTask: Task<Void, Never>?
    @State private var isCompletingCoreTutorialStudy = false
    
    var body: some View {
        ZStack {
            AquariumView(
                player: player,
                backgroundTheme: AquariumThemeStore.theme(from: backgroundThemeRawValue),
                isSimulationPaused: showsTimeSettings
            )

            VStack(spacing: 18) {
                Spacer()

                if viewModel.canConfigureSession {
                    VStack(spacing: 8) {
                        if viewModel.isStudyTime && !isCoreTutorialStudy {
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
                        .coreTutorialTarget(.studyMode)
                        .disabled(isCoreTutorialStudy)
                    }
                }

                if viewModel.canConfigureSession && viewModel.isStudyTime && !isCoreTutorialStudy {
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

                HStack(spacing: 12) {
                    Text(viewModel.mode == .countdown
                         ? formatCountdownTime(viewModel.displayedSeconds)
                         : formatTime(viewModel.displayedSeconds))
                        .font(.system(size: 72, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(viewModel.mode == .countdown ? 0.6 : 1)
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.25), radius: 10, y: 4)

                    if viewModel.canConfigureSession && viewModel.mode.showsTimeSettings {
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

                if viewModel.state == .paused {
                    Button("再開する") {
                        viewModel.resumeTimer()
                    }
                    .buttonStyle(AquariumPrimaryButtonStyle())

                    Button("終了する") {
                        showsEndConfirmation = true
                    }
                    .buttonStyle(AquariumSecondaryButtonStyle())
                } else {
                    if viewModel.isRunning {
                        Button("一時停止") {
                            handlePrimaryTimerAction()
                        }
                        .buttonStyle(AquariumPrimaryButtonStyle())
                    } else if viewModel.isStudyTime {
                        Button("勉強開始") {
                            handlePrimaryTimerAction()
                        }
                        .buttonStyle(AquariumStudyStartButtonStyle())
                        .coreTutorialTarget(.studyStart)
                        .disabled(
                            isCompletingCoreTutorialStudy ||
                                (isCoreTutorialStudy &&
                                    (coreTutorial?.step != .waitingForStudyStartTap ||
                                        coreTutorial?.conversationIndex != CoreTutorialConversationScript.studyStart.count - 1))
                        )
                        .accessibilityHidden(
                            isCoreTutorialStudy &&
                                (coreTutorial?.step != .waitingForStudyStartTap ||
                                    coreTutorial?.conversationIndex != CoreTutorialConversationScript.studyStart.count - 1)
                        )
                        .accessibilityIdentifier("timer.startStudy")
                    } else {
                        Button("休憩開始") {
                            handlePrimaryTimerAction()
                        }
                        .buttonStyle(AquariumPrimaryButtonStyle())
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
            // 背景の魚・泡やTutorial overlayの局所animationを、
            // 固定すべきTimer操作UIへ伝播させない。
            .transaction { transaction in
                transaction.animation = nil
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
            viewModel.locksMainTabNavigation || isCoreTutorialStudy || isCompletingCoreTutorialStudy
        )
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            _ = try? FocusCategoryService.createDefaultsIfNeeded(in: modelContext)
            configureStudyCompletion()
            prepareCoreTutorialStudyIfNeeded()
            viewModel.restorePersistedSessionIfNeeded()
            viewModel.synchronizeTime()
        }
        .onDisappear {
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
        .alert(viewModel.isStudyTime ? "勉強を終了しますか？" : "休憩を終了しますか？", isPresented: $showsEndConfirmation) {
            Button("キャンセル", role: .cancel) {}
            Button("終了する", role: .destructive) {
                viewModel.endCurrentSession()
            }
        } message: {
            if viewModel.isStudyTime {
                Text("現在の勉強時間を報酬計算します。\n\n今回の勉強時間: \(viewModel.elapsedStudyMinutes)分")
            } else {
                Text("現在の休憩を終了して、次の勉強へ進みます。")
            }
        }
        .alert("勉強終了をお知らせ", isPresented: $showsNotificationIntroduction) {
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
            Text("勉強や休憩が終わった時に通知でお知らせできます。")
        }
        .alert("次のセットを始めますか？", isPresented: Binding(
            get: { viewModel.shouldConfirmNextSet },
            set: { _ in }
        )) {
            Button("今回は終了する", role: .cancel) {
                viewModel.finishPomodoroSessionAfterBreak()
                dismiss()
            }
            Button("次のセットを始める") {
                viewModel.startNextSet()
            }
        } message: {
            Text("休憩が終了しました。次の勉強セットを開始できます。")
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
            TimerTimeSettingsSheet(
                mode: viewModel.mode,
                studyMinutes: configuredStudyMinutes(for: viewModel.mode),
                breakMinutes: Int(storedPomodoroBreakDuration) ?? breakTime,
                setCount: pomodoroSetCount,
                onSave: saveTimeSettings
            )
        }
        .sheet(isPresented: $showsFocusRules) {
            StudyFocusRulesSheet()
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
                get: { fishAcquisition != nil },
                set: { isPresented in
                    if !isPresented {
                        fishAcquisition = nil
                    }
                }
            ),
            onDismiss: finishFishRewardPresentation
        ) {
            if let fishAcquisition {
                FishRewardView(result: fishAcquisition)
            }
        }
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

    private func configureStudyCompletion() {
        viewModel.onStudyFinished = {
            let completedStudyMinutes = viewModel.lastCompletedStudyMinutes
            studyFinishedEndReason = viewModel.lastStudySessionEndReason ?? .completed
            studyFinishedMinutes = completedStudyMinutes
            guard let player else {
                rewardHistoryID = nil
                pendingFishAcquisition = nil
                pendingCompletionReward = StudyCompletionReward(
                    studyReward: 0,
                    streakReward: 0,
                    streakDays: 0,
                    didEarnFish: false
                )
                return
            }

            if coreTutorial?.step == .reward {
                rewardHistoryID = nil
                let fishResult = try? coreTutorial?.grantRewardIfNeeded(
                    to: player,
                    in: modelContext
                )
                pendingFishAcquisition = fishResult
                pendingCompletionReward = StudyCompletionReward(
                    studyReward: CurrencyService.studyCompletionReward(
                        for: CoreTutorialRewardService.studyMinutes,
                        todayStudyMinutesBeforeCompletion: 0
                    ),
                    streakReward: 0,
                    streakDays: player.studyStreakDays,
                    didEarnFish: fishResult != nil
                )
                return
            }

            let coinReward = CurrencyService.studyCompletionReward(
                for: completedStudyMinutes,
                todayStudyMinutesBeforeCompletion: player.todayStudyMinutes
            )
            let todayMinutesBeforeCompletion = player.todayStudyMinutes
            player.todayStudyMinutes += completedStudyMinutes
            player.totalStudyMinutes += completedStudyMinutes
            try? StudyHistoryService.addStudyMinutes(
                completedStudyMinutes,
                existingTodayMinutesBeforeCompletion: todayMinutesBeforeCompletion,
                categoryID: viewModel.selectedCategoryID,
                in: modelContext
            )

            guard StudyCompletionReward.isEligibleForExistingRewards(
                forStudyMinutes: completedStudyMinutes
            ) else {
                rewardHistoryID = nil
                pendingFishAcquisition = nil
                pendingCompletionReward = StudyCompletionReward(
                    studyReward: 0,
                    streakReward: 0,
                    streakDays: player.studyStreakDays,
                    didEarnFish: false
                )
                return
            }

            let fishResult = FishAcquisitionResult.capture(for: player) {
                FishRewardService.awardFish(for: completedStudyMinutes, to: player)
            }
            if fishResult != nil {
                DailyFishAcquisitionStore.recordAcquisition()
            }

            var awardedStudyReward = 0
            if coinReward > 0 {
                if (try? CurrencyService.addCoins(
                    coinReward,
                    to: player,
                    in: modelContext
                )) != nil {
                    awardedStudyReward = coinReward
                }
            }

            let streakUpdate = try? StudyStreakService.recordStudyCompletion(
                for: player,
                in: modelContext
            )

            let streakReward = streakUpdate?.awardedCoins ?? 0
            if let fishResult {
                let (totalPointDelta, overflowed) = awardedStudyReward
                    .addingReportingOverflow(streakReward)
                let history = try? RewardHistoryService.record(
                    result: fishResult,
                    pointDelta: overflowed ? Int.max : totalPointDelta,
                    in: modelContext
                )
                rewardHistoryID = history?.id
            } else {
                rewardHistoryID = nil
            }
            // 履歴を保存してから、各報酬画面を表示可能なpending stateへ渡す。
            pendingFishAcquisition = fishResult

            pendingCompletionReward = StudyCompletionReward(
                studyReward: awardedStudyReward,
                streakReward: streakReward,
                streakDays: streakUpdate?.streakDays ?? player.studyStreakDays,
                didEarnFish: fishResult != nil
            )
        }
        viewModel.onBreakFinished = nil
    }

    private func saveTimeSettings(studyMinutes: Int, breakMinutes: Int, setCount: Int) {
        if viewModel.mode == .pomodoro {
            storedPomodoroStudyDuration = String(studyMinutes)
            if PomodoroBreakConfiguration.isBreakSelectionEnabled(setCount: setCount) {
                storedPomodoroBreakDuration = String(breakMinutes)
            }
            pomodoroSetCount = setCount
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
        if let pendingCompletionReward {
            completionReward = pendingCompletionReward
            self.pendingCompletionReward = nil
        } else {
            presentPendingFishReward()
        }
    }

    private func presentPendingFishReward() {
        if let pendingFishAcquisition {
            fishAcquisition = pendingFishAcquisition
            self.pendingFishAcquisition = nil
        } else {
            finishStudyFlow()
        }
    }

    private func finishFishRewardPresentation() {
        if let rewardHistoryID {
            try? RewardHistoryService.acknowledge(id: rewardHistoryID, in: modelContext)
            self.rewardHistoryID = nil
        }
        finishStudyFlow()
    }

    private func finishStudyFlow() {
        if coreTutorial?.step == .reward {
            coreTutorial?.didDismissReward()
            isCompletingCoreTutorialStudy = false
            restoreStoredTimerConfiguration()
            dismiss()
            return
        }
        if viewModel.shouldBeginPomodoroBreak {
            viewModel.beginPomodoroBreak()
        } else {
            dismiss()
        }
    }

    private var isCoreTutorialStudy: Bool {
        coreTutorial?.usesTutorialStudySetup == true
    }

    private var orderedFocusCategories: [FocusCategory] {
        FocusCategoryService.ordered(focusCategories)
    }

    private var selectedFocusCategory: FocusCategory? {
        orderedFocusCategories.first { $0.id == viewModel.selectedCategoryID }
    }

    private var focusCategorySelection: some View {
        Menu {
            ForEach(orderedFocusCategories) { category in
                Button {
                    viewModel.selectCategory(category.id)
                } label: {
                    if viewModel.selectedCategoryID == category.id {
                        Label(category.name, systemImage: "checkmark")
                    } else {
                        Text(category.name)
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill((selectedFocusCategory?.colorKey ?? .studyBlue).swiftUIColor)
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
        .buttonStyle(.plain)
        .accessibilityLabel("集中カテゴリ")
        .accessibilityValue(selectedFocusCategory?.name ?? "勉強")
        .accessibilityIdentifier("timer.focusCategory")
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
    let onSave: (Int, Int, Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var studyMinutes: Int
    @State private var breakMinutes: Int
    @State private var timerHours: Int
    @State private var timerMinuteComponent: Int
    @State private var setCount: Int
    @State private var retainedBreakMinutes: Int

    init(
        mode: TimerMode,
        studyMinutes: Int,
        breakMinutes: Int,
        setCount: Int,
        onSave: @escaping (Int, Int, Int) -> Void
    ) {
        self.mode = mode
        self.onSave = onSave
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
                            title: "勉強時間",
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
                } else {
                    durationPicker(
                        title: "勉強時間",
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
                        onSave(savedStudyMinutes, breakMinutes, setCount)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
        .presentationDetents([.height(300)])
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
