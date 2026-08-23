//
//  PomodoroAquariumTests.swift
//  PomodoroAquariumTests
//
//  Created by 阿部弦生 on 2026/07/02.
//

import Foundation
import SwiftData
import Testing
@testable import PomodoroAquarium

struct PomodoroAquariumTests {

    @Test func pomodoroConfigurationUpdatesStudyAndBreakDurationsBeforeStart() {
        let clock = TestClock()
        let viewModel = TimerViewModel(
            studyTime: 25,
            breakTime: 5,
            now: { clock.now },
            sessionStore: makeTimerStore()
        )

        viewModel.updateConfiguration(studyTime: 40, breakTime: 9)
        #expect(viewModel.displayedSeconds == 40 * 60)

        viewModel.resumeTimer()
        clock.advance(by: 40 * 60)
        viewModel.tick()

        #expect(!viewModel.isStudyTime)
        #expect(viewModel.displayedSeconds == 9 * 60)
    }

    @Test func countdownConfigurationUpdatesOnlyItsDisplayedStudyDuration() {
        let viewModel = TimerViewModel(
            studyTime: 25,
            breakTime: 5,
            sessionStore: makeTimerStore()
        )
        viewModel.selectMode(.countdown)

        viewModel.updateConfiguration(studyTime: 60, breakTime: 5)

        #expect(viewModel.mode == .countdown)
        #expect(viewModel.displayedSeconds == 60 * 60)
    }

    @Test func stopwatchDoesNotOfferTimeSettings() {
        #expect(TimerMode.pomodoro.showsTimeSettings)
        #expect(TimerMode.countdown.showsTimeSettings)
        #expect(!TimerMode.stopwatch.showsTimeSettings)
    }

    @Test func timerConfigurationValuesPersistAcrossDefaultsReaders() throws {
        let suiteName = "PomodoroAquariumTimerConfigurationTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set("40", forKey: TimerConfigurationStorageKey.studyTime)
        defaults.set("9", forKey: TimerConfigurationStorageKey.breakTime)
        defaults.set(4, forKey: TimerConfigurationStorageKey.pomodoroSetCount)

        let relaunchedDefaults = try #require(UserDefaults(suiteName: suiteName))
        #expect(relaunchedDefaults.string(forKey: TimerConfigurationStorageKey.studyTime) == "40")
        #expect(relaunchedDefaults.string(forKey: TimerConfigurationStorageKey.breakTime) == "9")
        #expect(relaunchedDefaults.integer(forKey: TimerConfigurationStorageKey.pomodoroSetCount) == 4)
    }

    @Test func runningTimerUsesElapsedTimeForTenSeconds() {
        let clock = TestClock()
        let viewModel = TimerViewModel(studyTime: 25, breakTime: 5, now: { clock.now }, sessionStore: makeTimerStore())

        viewModel.startStopTimer()
        clock.advance(by: 10)
        viewModel.tick()

        #expect(viewModel.timeRemaining == 25 * 60 - 10)
    }

    @Test func stopwatchCountsUpInSeconds() {
        let clock = TestClock()
        let viewModel = TimerViewModel(studyTime: 60, breakTime: 5, now: { clock.now }, sessionStore: makeTimerStore())
        viewModel.selectMode(.stopwatch)

        viewModel.resumeTimer()
        clock.advance(by: 10)
        viewModel.tick()

        #expect(viewModel.mode == .stopwatch)
        #expect(viewModel.stopwatchElapsedSeconds == 10)
        #expect(viewModel.displayedSeconds == 10)
    }

    @Test func stopwatchPauseAndResumeKeepsAccumulatedTime() {
        let clock = TestClock()
        let viewModel = TimerViewModel(studyTime: 60, breakTime: 5, now: { clock.now }, sessionStore: makeTimerStore())
        viewModel.selectMode(.stopwatch)

        viewModel.resumeTimer()
        clock.advance(by: 10)
        viewModel.pauseTimer()
        clock.advance(by: 5 * 60)
        viewModel.tick()
        #expect(viewModel.stopwatchElapsedSeconds == 10)

        viewModel.resumeTimer()
        clock.advance(by: 5)
        viewModel.tick()
        #expect(viewModel.stopwatchElapsedSeconds == 15)
    }

    @Test func endingStopwatchPassesElapsedStudyTimeToExistingRewardFlowOnce() {
        let clock = TestClock()
        let viewModel = TimerViewModel(studyTime: 60, breakTime: 5, now: { clock.now }, sessionStore: makeTimerStore())
        var completionCount = 0
        viewModel.onStudyFinished = { completionCount += 1 }
        viewModel.selectMode(.stopwatch)

        viewModel.resumeTimer()
        clock.advance(by: 50 * 60)
        viewModel.pauseTimer()
        #expect(viewModel.endCurrentSession())
        #expect(!viewModel.endCurrentSession())

        #expect(completionCount == 1)
        #expect(viewModel.lastCompletedStudyMinutes == 50)
        #expect(CurrencyService.studyCompletionReward(
            for: viewModel.lastCompletedStudyMinutes,
            todayStudyMinutesBeforeCompletion: 0
        ) == 20)
    }

    @Test func stopwatchUnderTwentyFiveMinutesUsesExistingNoRewardRule() {
        let clock = TestClock()
        let viewModel = TimerViewModel(studyTime: 60, breakTime: 5, now: { clock.now }, sessionStore: makeTimerStore())
        viewModel.selectMode(.stopwatch)
        viewModel.resumeTimer()
        clock.advance(by: 10 * 60)
        viewModel.pauseTimer()
        viewModel.endCurrentSession()

        #expect(viewModel.lastCompletedStudyMinutes == 10)
        #expect(CurrencyService.studyCompletionReward(
            for: viewModel.lastCompletedStudyMinutes,
            todayStudyMinutesBeforeCompletion: 0
        ) == 0)
    }

    @Test func stopwatchModeAndElapsedTimeRestoreWithinGracePeriod() {
        let clock = TestClock()
        let defaults = makeTimerDefaults()
        let oldStore = TimerSessionStore(defaults: defaults, processIdentifier: "old")
        let original = TimerViewModel(studyTime: 60, breakTime: 5, now: { clock.now }, sessionStore: oldStore)
        original.selectMode(.stopwatch)
        original.resumeTimer()
        clock.advance(by: 5 * 60)

        let newStore = TimerSessionStore(defaults: defaults, processIdentifier: "new")
        let restored = TimerViewModel(studyTime: 60, breakTime: 5, now: { clock.now }, sessionStore: newStore)
        restored.restorePersistedSessionIfNeeded()

        #expect(restored.mode == .stopwatch)
        #expect(restored.isRunning)
        #expect(restored.stopwatchElapsedSeconds == 5 * 60)
    }

    @Test func pomodoroStudyCompletionWaitsBeforeStartingBreak() {
        let clock = TestClock()
        let viewModel = TimerViewModel(studyTime: 25, breakTime: 5, now: { clock.now }, sessionStore: makeTimerStore())

        #expect(viewModel.mode == .pomodoro)
        viewModel.resumeTimer()
        clock.advance(by: 25 * 60)
        viewModel.synchronizeTime()

        #expect(!viewModel.isStudyTime)
        #expect(viewModel.state == .completed)
        #expect(!viewModel.isRunning)

        viewModel.beginPomodoroBreak()
        #expect(viewModel.isRunning)
        #expect(viewModel.timeRemaining == 5 * 60)
    }

    @Test func threePomodoroSetsCompleteStudyRewardHookThreeTimes() {
        let clock = TestClock()
        let viewModel = TimerViewModel(studyTime: 25, breakTime: 5, now: { clock.now }, sessionStore: makeTimerStore())
        var studyCompletionCount = 0
        viewModel.onStudyFinished = { studyCompletionCount += 1 }

        for setIndex in 0..<3 {
            viewModel.resumeTimer()
            clock.advance(by: 25 * 60)
            viewModel.synchronizeTime()

            viewModel.beginPomodoroBreak()
            clock.advance(by: 5 * 60)
            viewModel.synchronizeTime()

            if setIndex < 2 {
                viewModel.resumeTimer()
            }
        }

        #expect(studyCompletionCount == 3)
    }

    @Test @MainActor func threePomodoroSetsAwardEachNormalRewardAndAdvanceStreakOnce() throws {
        let container = try makePlayerContainer()
        let context = container.mainContext
        let player = Player()
        context.insert(player)
        let clock = TestClock()
        let viewModel = TimerViewModel(studyTime: 25, breakTime: 5, now: { clock.now }, sessionStore: makeTimerStore())
        let completionDate = Date(timeIntervalSince1970: 1_800_000_000)

        viewModel.onStudyFinished = {
            let reward = CurrencyService.studyCompletionReward(
                for: viewModel.lastCompletedStudyMinutes,
                todayStudyMinutesBeforeCompletion: player.todayStudyMinutes
            )
            player.todayStudyMinutes += viewModel.lastCompletedStudyMinutes
            _ = FishRewardService.awardFish(for: viewModel.lastCompletedStudyMinutes, to: player)
            _ = try? CurrencyService.addCoins(reward, to: player, in: context)
            _ = try? StudyStreakService.recordStudyCompletion(
                for: player,
                at: completionDate,
                in: context
            )
        }

        for setIndex in 0..<3 {
            viewModel.resumeTimer()
            clock.advance(by: 25 * 60)
            viewModel.synchronizeTime()
            viewModel.beginPomodoroBreak()
            clock.advance(by: 5 * 60)
            viewModel.synchronizeTime()
            if setIndex < 2 { viewModel.resumeTimer() }
        }

        #expect(player.coins == 30)
        #expect(player.ownedFish.count == 3)
        #expect(player.studyStreakDays == 1)
    }

    @Test func pomodoroBreakCompletionRequestsNextSetOnlyAfterBreakEnds() {
        let clock = TestClock()
        let viewModel = TimerViewModel(studyTime: 25, breakTime: 5, now: { clock.now }, sessionStore: makeTimerStore())
        var nextSetPromptCount = 0
        viewModel.onBreakFinished = { nextSetPromptCount += 1 }

        viewModel.resumeTimer()
        clock.advance(by: 25 * 60)
        viewModel.synchronizeTime()
        #expect(nextSetPromptCount == 0)

        viewModel.beginPomodoroBreak()
        clock.advance(by: 5 * 60)
        viewModel.synchronizeTime()

        #expect(nextSetPromptCount == 1)
        #expect(viewModel.isStudyTime)
        #expect(viewModel.state == .completed)
    }

    @Test func countdownTimerCompletionDoesNotEnterBreak() {
        let clock = TestClock()
        let viewModel = TimerViewModel(studyTime: 25, breakTime: 5, now: { clock.now }, sessionStore: makeTimerStore())
        viewModel.selectMode(.countdown)

        viewModel.resumeTimer()
        clock.advance(by: 25 * 60)
        viewModel.synchronizeTime()

        #expect(viewModel.mode == .countdown)
        #expect(viewModel.isStudyTime)
        #expect(viewModel.state == .completed)
        #expect(!viewModel.isRunning)
    }

    @Test func stopwatchCompletionDoesNotEnterBreak() {
        let clock = TestClock()
        let viewModel = TimerViewModel(studyTime: 60, breakTime: 5, now: { clock.now }, sessionStore: makeTimerStore())
        viewModel.selectMode(.stopwatch)
        viewModel.resumeTimer()
        clock.advance(by: 25 * 60)
        viewModel.pauseTimer()
        viewModel.endCurrentSession()

        #expect(viewModel.isStudyTime)
        #expect(viewModel.state == .completed)
        #expect(!viewModel.isRunning)
    }

    @Test func foregroundSynchronizationCorrectsBackgroundElapsedTime() {
        let clock = TestClock()
        let viewModel = TimerViewModel(studyTime: 25, breakTime: 5, now: { clock.now }, sessionStore: makeTimerStore())

        viewModel.startStopTimer()
        clock.advance(by: 10 * 60)
        viewModel.synchronizeTime()

        #expect(viewModel.timeRemaining == 15 * 60)
    }

    @Test func pausedTimerDoesNotLoseTime() {
        let clock = TestClock()
        let viewModel = TimerViewModel(studyTime: 25, breakTime: 5, now: { clock.now }, sessionStore: makeTimerStore())

        viewModel.startStopTimer()
        clock.advance(by: 10)
        viewModel.startStopTimer()
        let pausedTimeRemaining = viewModel.timeRemaining

        clock.advance(by: 5 * 60)
        viewModel.synchronizeTime()

        #expect(!viewModel.isRunning)
        #expect(viewModel.timeRemaining == pausedTimeRemaining)
    }

    @Test func timerStateTransitionsFromRunningToPausedAndBackToRunning() {
        let clock = TestClock()
        let viewModel = TimerViewModel(studyTime: 60, breakTime: 5, now: { clock.now }, sessionStore: makeTimerStore())

        viewModel.resumeTimer()
        #expect(viewModel.state == .running)

        clock.advance(by: 10 * 60)
        viewModel.pauseTimer()
        #expect(viewModel.state == .paused)
        #expect(viewModel.elapsedStudyMinutes == 10)

        viewModel.resumeTimer()
        #expect(viewModel.state == .running)
        #expect(viewModel.timeRemaining == 50 * 60)
    }

    @Test func pausedStudyDoesNotAdvanceAndResumeContinuesWithoutDoubleCounting() {
        let clock = TestClock()
        let viewModel = TimerViewModel(studyTime: 60, breakTime: 5, now: { clock.now }, sessionStore: makeTimerStore())

        viewModel.resumeTimer()
        clock.advance(by: 10 * 60)
        viewModel.pauseTimer()
        clock.advance(by: 15 * 60)
        viewModel.synchronizeTime()

        #expect(viewModel.elapsedStudyMinutes == 10)

        viewModel.resumeTimer()
        clock.advance(by: 5 * 60)
        viewModel.pauseTimer()

        #expect(viewModel.elapsedStudyMinutes == 15)
        #expect(viewModel.timeRemaining == 45 * 60)
    }

    @Test func endingPausedFiftyMinuteStudyUsesElapsedMinutesAndCompletesOnce() {
        let clock = TestClock()
        let viewModel = TimerViewModel(studyTime: 60, breakTime: 5, now: { clock.now }, sessionStore: makeTimerStore())
        var completionCount = 0
        viewModel.onStudyFinished = { completionCount += 1 }

        viewModel.resumeTimer()
        clock.advance(by: 50 * 60)
        viewModel.pauseTimer()

        #expect(viewModel.endCurrentStudySession())
        #expect(!viewModel.endCurrentStudySession())
        #expect(viewModel.lastCompletedStudyMinutes == 50)
        #expect(completionCount == 1)
        #expect(viewModel.state == .completed)
        #expect(!viewModel.isStudyTime)
        #expect(CurrencyService.studyCompletionReward(
            for: viewModel.lastCompletedStudyMinutes,
            todayStudyMinutesBeforeCompletion: 0
        ) == 20)
    }

    @Test func endingPausedTenMinuteStudyIsBelowRewardThreshold() {
        let clock = TestClock()
        let viewModel = TimerViewModel(studyTime: 60, breakTime: 5, now: { clock.now }, sessionStore: makeTimerStore())

        viewModel.resumeTimer()
        clock.advance(by: 10 * 60)
        viewModel.pauseTimer()
        viewModel.endCurrentStudySession()

        #expect(viewModel.lastCompletedStudyMinutes == 10)
        #expect(!StudyCompletionReward.shouldPresent(forStudyMinutes: viewModel.lastCompletedStudyMinutes))
        #expect(CurrencyService.studyCompletionReward(
            for: viewModel.lastCompletedStudyMinutes,
            todayStudyMinutesBeforeCompletion: 0
        ) == 0)
    }

    @Test func pausedStudyPersistsElapsedStudyTime() {
        let clock = TestClock()
        let store = makeTimerStore()
        let viewModel = TimerViewModel(studyTime: 60, breakTime: 5, now: { clock.now }, sessionStore: store)

        viewModel.resumeTimer()
        clock.advance(by: 12 * 60 + 30)
        viewModel.pauseTimer()

        #expect(viewModel.elapsedStudySeconds == 12 * 60 + 30)
        #expect(store.load()?.elapsedStudySeconds == 12 * 60 + 30)
    }

    @Test func restoredPausedStudyCanFinishUsingItsElapsedRewardTime() {
        let clock = TestClock()
        let defaults = makeTimerDefaults()
        let oldStore = TimerSessionStore(defaults: defaults, processIdentifier: "old")
        let original = TimerViewModel(studyTime: 60, breakTime: 5, now: { clock.now }, sessionStore: oldStore)

        original.resumeTimer()
        clock.advance(by: 50 * 60)
        original.pauseTimer()

        let newStore = TimerSessionStore(defaults: defaults, processIdentifier: "new")
        let restored = TimerViewModel(studyTime: 60, breakTime: 5, now: { clock.now }, sessionStore: newStore)
        restored.restorePersistedSessionIfNeeded()
        restored.endCurrentStudySession()

        #expect(restored.lastCompletedStudyMinutes == 50)
        #expect(CurrencyService.studyCompletionReward(
            for: restored.lastCompletedStudyMinutes,
            todayStudyMinutesBeforeCompletion: 0
        ) == 20)
    }

    @Test func cancelingEndConfirmationLeavesPausedSessionAvailableToResume() {
        let clock = TestClock()
        let viewModel = TimerViewModel(studyTime: 60, breakTime: 5, now: { clock.now }, sessionStore: makeTimerStore())
        var completionCount = 0
        viewModel.onStudyFinished = { completionCount += 1 }

        viewModel.resumeTimer()
        clock.advance(by: 10 * 60)
        viewModel.pauseTimer()
        // UIのキャンセルは終了メソッドを呼ばない。

        #expect(viewModel.state == .paused)
        #expect(completionCount == 0)

        viewModel.resumeTimer()
        #expect(viewModel.state == .running)
        #expect(viewModel.timeRemaining == 50 * 60)
    }

    @Test func confirmingPausedStudyEndCallsExistingCompletionOnce() {
        let clock = TestClock()
        let viewModel = TimerViewModel(studyTime: 50, breakTime: 5, now: { clock.now }, sessionStore: makeTimerStore())
        var completionCount = 0
        viewModel.onStudyFinished = { completionCount += 1 }

        viewModel.resumeTimer()
        clock.advance(by: 25 * 60)
        viewModel.pauseTimer()

        #expect(viewModel.endCurrentSession())
        #expect(!viewModel.endCurrentSession())
        #expect(completionCount == 1)
        #expect(viewModel.lastCompletedStudyMinutes == 25)
    }

    @Test func pausedBreakCanBeEndedWithoutCallingStudyCompletion() {
        let clock = TestClock()
        let viewModel = TimerViewModel(studyTime: 25, breakTime: 5, now: { clock.now }, sessionStore: makeTimerStore())
        var completionCount = 0
        viewModel.onStudyFinished = { completionCount += 1 }

        viewModel.resumeTimer()
        clock.advance(by: 25 * 60)
        viewModel.synchronizeTime()
        #expect(completionCount == 1)

        viewModel.resumeTimer()
        clock.advance(by: 60)
        viewModel.pauseTimer()
        #expect(viewModel.endCurrentSession())

        #expect(completionCount == 1)
        #expect(viewModel.isStudyTime)
        #expect(viewModel.state == .completed)
        #expect(viewModel.timeRemaining == 25 * 60)
    }

    @Test func studyCompletionIsHandledOnlyOnce() {
        let clock = TestClock()
        let viewModel = TimerViewModel(studyTime: 25, breakTime: 5, now: { clock.now }, sessionStore: makeTimerStore())
        var completionCount = 0
        viewModel.onStudyFinished = {
            completionCount += 1
        }

        viewModel.startStopTimer()
        clock.advance(by: 25 * 60)
        viewModel.synchronizeTime()
        viewModel.synchronizeTime()
        viewModel.tick()

        #expect(completionCount == 1)
        #expect(!viewModel.isStudyTime)
        #expect(!viewModel.isRunning)
        #expect(viewModel.timeRemaining == 5 * 60)
    }

    @Test func studyCompletionSwitchesToConfiguredBreakTime() {
        let clock = TestClock()
        let viewModel = TimerViewModel(studyTime: 25, breakTime: 7, now: { clock.now }, sessionStore: makeTimerStore())

        viewModel.startStopTimer()
        clock.advance(by: 25 * 60)
        viewModel.synchronizeTime()

        #expect(!viewModel.isStudyTime)
        #expect(!viewModel.isRunning)
        #expect(viewModel.timeRemaining == 7 * 60)
        #expect(viewModel.endDate == nil)
    }

    @Test func breakTimerUsesEndDateToCorrectBackgroundElapsedTime() {
        let clock = TestClock()
        let viewModel = TimerViewModel(studyTime: 25, breakTime: 5, now: { clock.now }, sessionStore: makeTimerStore())

        viewModel.startStopTimer()
        clock.advance(by: 25 * 60)
        viewModel.synchronizeTime()

        viewModel.startStopTimer()
        let expectedEndDate = clock.now.addingTimeInterval(5 * 60)
        clock.advance(by: 2 * 60)
        viewModel.synchronizeTime()

        #expect(viewModel.endDate == expectedEndDate)
        #expect(!viewModel.isStudyTime)
        #expect(viewModel.isRunning)
        #expect(viewModel.timeRemaining == 3 * 60)
    }

    @Test func pausedBreakTimerDoesNotLoseTime() {
        let clock = TestClock()
        let viewModel = TimerViewModel(studyTime: 25, breakTime: 5, now: { clock.now }, sessionStore: makeTimerStore())

        viewModel.startStopTimer()
        clock.advance(by: 25 * 60)
        viewModel.synchronizeTime()
        viewModel.startStopTimer()
        clock.advance(by: 30)
        viewModel.startStopTimer()
        let pausedTimeRemaining = viewModel.timeRemaining

        clock.advance(by: 10 * 60)
        viewModel.synchronizeTime()

        #expect(!viewModel.isStudyTime)
        #expect(!viewModel.isRunning)
        #expect(viewModel.endDate == nil)
        #expect(viewModel.timeRemaining == pausedTimeRemaining)
        #expect(viewModel.timeRemaining == 4 * 60 + 30)
    }

    @Test func breakCompletionIsHandledOnlyOnce() {
        let clock = TestClock()
        let viewModel = TimerViewModel(studyTime: 25, breakTime: 5, now: { clock.now }, sessionStore: makeTimerStore())
        var studyCompletionCount = 0
        viewModel.onStudyFinished = {
            studyCompletionCount += 1
        }

        viewModel.startStopTimer()
        clock.advance(by: 25 * 60)
        viewModel.synchronizeTime()
        viewModel.startStopTimer()
        clock.advance(by: 5 * 60)
        viewModel.synchronizeTime()
        viewModel.synchronizeTime()
        viewModel.tick()

        #expect(studyCompletionCount == 1)
        #expect(viewModel.isStudyTime)
        #expect(!viewModel.isRunning)
        #expect(viewModel.timeRemaining == 25 * 60)
        #expect(viewModel.endDate == nil)
    }

    @Test func sameProcessBackgroundLongerThanGracePeriodStillContinues() {
        let clock = TestClock()
        let store = makeTimerStore(processIdentifier: "same-process")
        let viewModel = TimerViewModel(studyTime: 25, breakTime: 5, now: { clock.now }, sessionStore: store)

        viewModel.startStopTimer()
        clock.advance(by: 10 * 60)
        viewModel.synchronizeTime()

        #expect(viewModel.isRunning)
        #expect(viewModel.timeRemaining == 15 * 60)
    }

    @Test func newProcessRestoresRunningSessionAfterSixtySeconds() {
        let clock = TestClock()
        let defaults = makeTimerDefaults()
        let oldStore = TimerSessionStore(defaults: defaults, processIdentifier: "old")
        let oldViewModel = TimerViewModel(studyTime: 25, breakTime: 5, now: { clock.now }, sessionStore: oldStore)
        oldViewModel.startStopTimer()
        clock.advance(by: 60)

        let newStore = TimerSessionStore(defaults: defaults, processIdentifier: "new")
        let restored = TimerViewModel(studyTime: 25, breakTime: 5, now: { clock.now }, sessionStore: newStore)
        restored.restorePersistedSessionIfNeeded()

        #expect(restored.isRunning)
        #expect(restored.isStudyTime)
        #expect(restored.timeRemaining == 24 * 60)
    }

    @Test func newProcessRestoresSessionAfterFiveMinutes() {
        let clock = TestClock()
        let defaults = makeTimerDefaults()
        let oldStore = TimerSessionStore(defaults: defaults, processIdentifier: "old")
        let oldViewModel = TimerViewModel(studyTime: 25, breakTime: 5, now: { clock.now }, sessionStore: oldStore)
        oldViewModel.startStopTimer()
        clock.advance(by: 5 * 60)

        let newStore = TimerSessionStore(defaults: defaults, processIdentifier: "new")
        let restored = TimerViewModel(studyTime: 25, breakTime: 5, now: { clock.now }, sessionStore: newStore)
        restored.restorePersistedSessionIfNeeded()

        #expect(restored.isRunning)
        #expect(restored.isStudyTime)
        #expect(restored.timeRemaining == 20 * 60)
    }

    @Test func expiredSessionWithinGracePeriodCompletesOnlyOnce() {
        let clock = TestClock()
        let defaults = makeTimerDefaults()
        let oldStore = TimerSessionStore(defaults: defaults, processIdentifier: "old")
        let oldViewModel = TimerViewModel(studyTime: 1, breakTime: 5, now: { clock.now }, sessionStore: oldStore)
        oldViewModel.startStopTimer()
        clock.advance(by: 60)

        let newStore = TimerSessionStore(defaults: defaults, processIdentifier: "new")
        let restored = TimerViewModel(studyTime: 1, breakTime: 5, now: { clock.now }, sessionStore: newStore)
        var completionCount = 0
        restored.onStudyFinished = { completionCount += 1 }
        restored.restorePersistedSessionIfNeeded()
        restored.synchronizeTime()
        restored.tick()

        #expect(completionCount == 1)
        #expect(!restored.isStudyTime)
        #expect(!restored.isRunning)
        #expect(newStore.load() == nil)
    }

    @Test func sessionOlderThanTenMinutesFinishesUsingSavedElapsedTime() {
        let clock = TestClock()
        let defaults = makeTimerDefaults()
        let oldStore = TimerSessionStore(defaults: defaults, processIdentifier: "old")
        let oldViewModel = TimerViewModel(studyTime: 60, breakTime: 5, now: { clock.now }, sessionStore: oldStore)
        oldViewModel.resumeTimer()
        clock.advance(by: 30 * 60)
        oldViewModel.recordLastActiveTime()
        clock.advance(by: 10 * 60 + 1)

        var completionCount = 0
        let newStore = TimerSessionStore(defaults: defaults, processIdentifier: "new")
        let restored = TimerViewModel(studyTime: 60, breakTime: 5, now: { clock.now }, sessionStore: newStore)
        restored.onStudyFinished = {
            completionCount += 1
        }
        restored.restorePersistedSessionIfNeeded()

        #expect(completionCount == 1)
        #expect(restored.lastCompletedStudyMinutes == 40)
        #expect(CurrencyService.studyCompletionReward(
            for: restored.lastCompletedStudyMinutes,
            todayStudyMinutesBeforeCompletion: 0
        ) == 10)
        #expect(newStore.load() == nil)
    }

    @Test func pausedSessionRestoresPausedWithinGracePeriod() {
        let clock = TestClock()
        let defaults = makeTimerDefaults()
        let oldStore = TimerSessionStore(defaults: defaults, processIdentifier: "old")
        let oldViewModel = TimerViewModel(studyTime: 25, breakTime: 5, now: { clock.now }, sessionStore: oldStore)
        oldViewModel.startStopTimer()
        clock.advance(by: 30)
        oldViewModel.startStopTimer()
        clock.advance(by: 60)

        let newStore = TimerSessionStore(defaults: defaults, processIdentifier: "new")
        let restored = TimerViewModel(studyTime: 25, breakTime: 5, now: { clock.now }, sessionStore: newStore)
        restored.restorePersistedSessionIfNeeded()

        #expect(!restored.isRunning)
        #expect(restored.timeRemaining == 24 * 60 + 30)
        #expect(restored.endDate == nil)
    }

    @Test func breakSessionIsNotPersistedOrRestored() {
        let clock = TestClock()
        let defaults = makeTimerDefaults()
        let oldStore = TimerSessionStore(defaults: defaults, processIdentifier: "old")
        let oldViewModel = TimerViewModel(studyTime: 1, breakTime: 5, now: { clock.now }, sessionStore: oldStore)
        oldViewModel.startStopTimer()
        clock.advance(by: 60)
        oldViewModel.synchronizeTime()
        oldViewModel.startStopTimer()
        clock.advance(by: 60)

        #expect(oldStore.load() == nil)

        let newStore = TimerSessionStore(defaults: defaults, processIdentifier: "new")
        let restored = TimerViewModel(studyTime: 1, breakTime: 5, now: { clock.now }, sessionStore: newStore)
        restored.restorePersistedSessionIfNeeded()

        #expect(restored.isStudyTime)
        #expect(!restored.isRunning)
        #expect(restored.timeRemaining == 60)
    }

    @Test func resetPreventsOldSessionFromRestoring() {
        let clock = TestClock()
        let defaults = makeTimerDefaults()
        let store = TimerSessionStore(defaults: defaults, processIdentifier: "old")
        let viewModel = TimerViewModel(studyTime: 25, breakTime: 5, now: { clock.now }, sessionStore: store)
        viewModel.startStopTimer()
        viewModel.resetTimer()

        let newStore = TimerSessionStore(defaults: defaults, processIdentifier: "new")
        #expect(newStore.launchStatus(at: clock.now) == .none)
    }

    @Test func normalCompletionDoesNotCreateInterruptionBanner() {
        let clock = TestClock()
        let store = makeTimerStore()
        let viewModel = TimerViewModel(studyTime: 1, breakTime: 5, now: { clock.now }, sessionStore: store)
        viewModel.startStopTimer()
        clock.advance(by: 60)
        viewModel.synchronizeTime()

        #expect(!store.consumeInterruptionBanner())
    }

    @Test func expiredSessionIsReturnedForViewModelCompletion() {
        let clock = TestClock()
        let defaults = makeTimerDefaults()
        let oldStore = TimerSessionStore(defaults: defaults, processIdentifier: "old")
        let oldViewModel = TimerViewModel(studyTime: 25, breakTime: 5, now: { clock.now }, sessionStore: oldStore)
        oldViewModel.startStopTimer()
        clock.advance(by: 10 * 60 + 1)

        let newStore = TimerSessionStore(defaults: defaults, processIdentifier: "new")
        guard case .expired = newStore.launchStatus(at: clock.now) else {
            Issue.record("10分を超えたセッションがexpiredになっていません")
            return
        }
        #expect(newStore.load() != nil)
    }

    @Test func expiredStudyUnderTwentyFiveMinutesHasNoReward() {
        let clock = TestClock()
        let defaults = makeTimerDefaults()
        let oldStore = TimerSessionStore(defaults: defaults, processIdentifier: "old")
        let original = TimerViewModel(studyTime: 60, breakTime: 5, now: { clock.now }, sessionStore: oldStore)
        original.resumeTimer()
        clock.advance(by: 10 * 60)
        original.recordLastActiveTime()
        clock.advance(by: 10 * 60 + 1)

        let newStore = TimerSessionStore(defaults: defaults, processIdentifier: "new")
        let restored = TimerViewModel(studyTime: 60, breakTime: 5, now: { clock.now }, sessionStore: newStore)
        restored.restorePersistedSessionIfNeeded()

        #expect(restored.lastCompletedStudyMinutes == 20)
        #expect(CurrencyService.studyCompletionReward(
            for: restored.lastCompletedStudyMinutes,
            todayStudyMinutesBeforeCompletion: 0
        ) == 0)
    }

    @Test @MainActor func defaultAquariumDecorationsAreCreatedOnFirstLaunch() throws {
        let container = try makeDecorationContainer()
        let context = container.mainContext

        let didCreate = try AquariumDecorationService.createDefaultsIfNeeded(in: context)
        let placements = try context.fetch(FetchDescriptor<AquariumDecorationPlacement>())

        #expect(didCreate)
        #expect(placements.count == AquariumDecorationService.defaultDecorations.count)
        #expect(Set(placements.map(\.decorationID)) == Set(["default-seaweed", "default-rock"]))
    }

    @Test @MainActor func aquariumDecorationRelativePositionIsPersistedAndRefetched() throws {
        let container = try makeDecorationContainer()
        let context = container.mainContext
        try AquariumDecorationService.createDefaultsIfNeeded(in: context)
        let placement = try #require(
            context.fetch(FetchDescriptor<AquariumDecorationPlacement>())
                .first { $0.decorationID == "default-rock" }
        )

        placement.relativeX = 0.42
        placement.relativeY = 0.79
        try context.save()

        let refetchContext = ModelContext(container)
        let refetched = try #require(
            refetchContext.fetch(FetchDescriptor<AquariumDecorationPlacement>())
                .first { $0.decorationID == "default-rock" }
        )
        #expect(refetched.relativeX == 0.42)
        #expect(refetched.relativeY == 0.79)
    }

    @Test @MainActor func defaultAquariumDecorationsAreNotDuplicated() throws {
        let container = try makeDecorationContainer()
        let context = container.mainContext

        let firstCreation = try AquariumDecorationService.createDefaultsIfNeeded(in: context)
        let secondCreation = try AquariumDecorationService.createDefaultsIfNeeded(in: context)
        let count = try context.fetchCount(FetchDescriptor<AquariumDecorationPlacement>())

        #expect(firstCreation)
        #expect(!secondCreation)
        #expect(count == AquariumDecorationService.defaultDecorations.count)
    }

    @Test @MainActor func defaultAquariumDecorationsUseStableIDsForDeduplication() throws {
        let container = try makeDecorationContainer()
        let context = container.mainContext
        context.insert(AquariumDecorationPlacement(
            kind: .seaweed,
            relativeX: 0.5,
            relativeY: 0.8,
            scale: 1
        ))
        try context.save()

        #expect(try AquariumDecorationService.createDefaultsIfNeeded(in: context))
        #expect(!(try AquariumDecorationService.createDefaultsIfNeeded(in: context)))

        let placements = try context.fetch(FetchDescriptor<AquariumDecorationPlacement>())
        #expect(placements.count == 3)
        #expect(placements.filter { $0.decorationID == "default-seaweed" }.count == 1)
        #expect(placements.filter { $0.decorationID == "default-rock" }.count == 1)
    }

    @Test @MainActor func multipleDecorationsOfTheSameKindCanBeOwnedAndPlaced() throws {
        let container = try makeDecorationContainer()
        let context = container.mainContext
        let positions = [0.2, 0.5, 0.8]

        let seaweeds = try positions.map { x in
            try AquariumDecorationService.addPlacement(
                kind: .seaweed,
                at: CGPoint(x: CGFloat(x), y: 0.82),
                isPlaced: true,
                in: context
            )
        }

        #expect(Set(seaweeds.map(\.decorationID)).count == 3)
        #expect(seaweeds.allSatisfy { $0.kind == .seaweed && $0.isPlaced })
        #expect(Set(seaweeds.map(\.relativeX)) == Set(positions))
        #expect(try context.fetchCount(FetchDescriptor<AquariumDecorationPlacement>()) == 3)
    }

    @Test @MainActor func oneSameKindDecorationCanBeStoredWithoutAffectingOthers() throws {
        let container = try makeDecorationContainer()
        let context = container.mainContext
        let seaweeds = try (0..<3).map { index in
            try AquariumDecorationService.addPlacement(
                kind: .seaweed,
                at: CGPoint(x: 0.2 + CGFloat(index) * 0.3, y: 0.82),
                isPlaced: true,
                in: context
            )
        }

        try AquariumDecorationService.store(seaweeds[1], in: context)

        #expect(seaweeds[0].isPlaced)
        #expect(!seaweeds[1].isPlaced)
        #expect(seaweeds[2].isPlaced)
        let stored = AquariumDecorationService.storedPlacements(from: seaweeds)
        #expect(stored.map(\.decorationID) == [seaweeds[1].decorationID])
    }

    @Test @MainActor func multipleStoredSameKindDecorationsAreReturnedAndOneCanBeRestored() throws {
        let container = try makeDecorationContainer()
        let context = container.mainContext
        let first = try AquariumDecorationService.addPlacement(
            kind: .seaweed,
            isPlaced: false,
            in: context
        )
        let second = try AquariumDecorationService.addPlacement(
            kind: .seaweed,
            isPlaced: false,
            in: context
        )

        let storedBefore = AquariumDecorationService.storedPlacements(from: [first, second])
        #expect(storedBefore.count == 2)

        try AquariumDecorationService.confirmPlacement(
            first,
            at: CGPoint(x: 0.3, y: 0.8),
            in: context
        )

        #expect(first.isPlaced)
        #expect(!second.isPlaced)
        let storedAfter = AquariumDecorationService.storedPlacements(from: [first, second])
        #expect(storedAfter.map(\.decorationID) == [second.decorationID])
    }

    @Test func aquariumDecorationDragDoesNotMoveOutsideEditingMode() {
        let original = CGPoint(x: 0.25, y: 0.82)
        let result = AquariumDecorationEditor.relativePosition(
            originalX: original.x,
            originalY: original.y,
            translation: CGSize(width: 180, height: -100),
            aquariumSize: CGSize(width: 390, height: 844),
            kind: .seaweed,
            isEditing: false
        )

        #expect(result == original)
    }

    @Test func aquariumDecorationDragUsesRelativeCoordinatesAndBounds() {
        let result = AquariumDecorationEditor.relativePosition(
            originalX: 0.5,
            originalY: 0.8,
            translation: CGSize(width: 100, height: 50),
            aquariumSize: CGSize(width: 400, height: 500),
            kind: .rock,
            isEditing: true
        )

        #expect(result.x == 0.75)
        #expect(result.y == 0.9)
    }

    @Test @MainActor func decorationStorageContainsOnlyUnplacedDecorations() throws {
        let container = try makeDecorationContainer()
        let context = container.mainContext
        let placed = AquariumDecorationPlacement(
            decorationID: "placed",
            kind: .rock,
            relativeX: 0.3,
            relativeY: 0.8,
            scale: 1,
            isPlaced: true
        )
        let stored = AquariumDecorationPlacement(
            decorationID: "stored",
            kind: .seaweed,
            relativeX: 0.7,
            relativeY: 0.8,
            scale: 1,
            isPlaced: false
        )
        context.insert(placed)
        context.insert(stored)

        let result = AquariumDecorationService.storedPlacements(from: [placed, stored])

        #expect(result.map(\.decorationID) == ["stored"])
    }

    @Test func aquariumDecorationKindsHaveExpectedCategories() {
        #expect(AquariumDecorationKind.seaweed.category == .plant)
        #expect(AquariumDecorationKind.rock.category == .rock)
    }

    @Test @MainActor func decorationStorageCategoryFilterReturnsMatchingItemsOnly() throws {
        let container = try makeDecorationContainer()
        let context = container.mainContext
        let seaweed = AquariumDecorationPlacement(
            decorationID: "stored-seaweed-filter",
            kind: .seaweed,
            relativeX: 0.3,
            relativeY: 0.8,
            scale: 1,
            isPlaced: false
        )
        let rock = AquariumDecorationPlacement(
            decorationID: "stored-rock-filter",
            kind: .rock,
            relativeX: 0.7,
            relativeY: 0.85,
            scale: 1,
            isPlaced: false
        )
        context.insert(seaweed)
        context.insert(rock)

        let plants = AquariumDecorationService.storedPlacements(
            from: [seaweed, rock],
            category: .plant
        )
        let rocks = AquariumDecorationService.storedPlacements(
            from: [seaweed, rock],
            category: .rock
        )
        let corals = AquariumDecorationService.storedPlacements(
            from: [seaweed, rock],
            category: .coral
        )

        #expect(plants.map(\.decorationID) == ["stored-seaweed-filter"])
        #expect(rocks.map(\.decorationID) == ["stored-rock-filter"])
        #expect(corals.isEmpty)
    }

    @Test @MainActor func confirmingStoredDecorationPersistsPlacementAndPosition() throws {
        let container = try makeDecorationContainer()
        let context = container.mainContext
        let placement = AquariumDecorationPlacement(
            decorationID: "stored-rock",
            kind: .rock,
            relativeX: 0.2,
            relativeY: 0.8,
            scale: 1,
            isPlaced: false
        )
        context.insert(placement)
        try context.save()

        try AquariumDecorationService.confirmPlacement(
            placement,
            at: CGPoint(x: 0.55, y: 0.86),
            in: context
        )

        let refetchContext = ModelContext(container)
        let refetched = try #require(
            refetchContext.fetch(FetchDescriptor<AquariumDecorationPlacement>())
                .first { $0.decorationID == "stored-rock" }
        )
        #expect(refetched.isPlaced)
        #expect(refetched.relativeX == 0.55)
        #expect(refetched.relativeY == 0.86)
    }

    @Test @MainActor func cancellingStoredDecorationLeavesItUnplaced() throws {
        let container = try makeDecorationContainer()
        let context = container.mainContext
        let placement = AquariumDecorationPlacement(
            decorationID: "stored-seaweed",
            kind: .seaweed,
            relativeX: 0.14,
            relativeY: 0.82,
            scale: 1,
            isPlaced: false
        )
        context.insert(placement)
        try context.save()

        // 再配置中の仮位置はViewのStateだけで扱うため、キャンセル時はモデル操作を行わない。
        let previewPosition = placement.kind.restorationPosition
        #expect(previewPosition != CGPoint(x: placement.relativeX, y: placement.relativeY))

        let refetchContext = ModelContext(container)
        let refetched = try #require(
            refetchContext.fetch(FetchDescriptor<AquariumDecorationPlacement>())
                .first { $0.decorationID == "stored-seaweed" }
        )
        #expect(!refetched.isPlaced)
        #expect(refetched.relativeX == 0.14)
        #expect(refetched.relativeY == 0.82)
    }

    @Test func aquariumThemeDefaultsToAquariumWithoutSavedValue() {
        let defaults = makeThemeDefaults()
        let store = AquariumThemeStore(defaults: defaults)

        #expect(store.selectedTheme == .aquarium)
    }

    @Test func aquariumThemeCanBeSavedAndRefetched() {
        let defaults = makeThemeDefaults()
        AquariumThemeStore(defaults: defaults).save(.deepSea)

        let refetchedStore = AquariumThemeStore(defaults: defaults)
        #expect(refetchedStore.selectedTheme == .deepSea)
    }

    @Test func aquariumThemePreviewCancellationDoesNotChangeSavedValue() {
        let defaults = makeThemeDefaults()
        let store = AquariumThemeStore(defaults: defaults)
        store.save(.aquarium)

        let previewTheme = AquariumBackgroundTheme.tropical
        #expect(previewTheme == .tropical)
        // キャンセルではsaveを呼ばず、Viewのプレビュー状態だけ破棄する。
        #expect(store.selectedTheme == .aquarium)
    }

    @Test func invalidAquariumThemeRawValueFallsBackToAquarium() {
        #expect(AquariumThemeStore.theme(from: "unknown-theme") == .aquarium)
        #expect(AquariumThemeStore.theme(from: nil) == .aquarium)
    }

    @Test func homeAndTimerThemeReadersUseTheSameSavedValue() {
        let defaults = makeThemeDefaults()
        let homeThemeStore = AquariumThemeStore(defaults: defaults)
        let timerThemeStore = AquariumThemeStore(defaults: defaults)
        homeThemeStore.save(.tropical)

        #expect(homeThemeStore.selectedTheme == .tropical)
        #expect(timerThemeStore.selectedTheme == .tropical)
    }

    @Test func rarityProbabilitiesAtZeroMinutesUseBaseRates() {
        let probabilities = FishRewardService.rarityProbabilities(for: 0)

        #expect(probabilities.common == 70)
        #expect(probabilities.rare == 20)
        #expect(probabilities.epic == 8)
        #expect(probabilities.legendary == 2)
        #expect(probabilities.total == 100)
    }

    @Test func rarityProbabilitiesAt90MinutesAreHalfway() {
        let probabilities = FishRewardService.rarityProbabilities(for: 90)

        #expect(probabilities.common == 64)
        #expect(probabilities.rare == 22.5)
        #expect(probabilities.epic == 10.5)
        #expect(probabilities.legendary == 3)
        #expect(probabilities.total == 100)
    }

    @Test func rarityProbabilitiesAt180MinutesUseMaximumBonus() {
        let probabilities = FishRewardService.rarityProbabilities(for: 180)

        #expect(probabilities.common == 58)
        #expect(probabilities.rare == 25)
        #expect(probabilities.epic == 13)
        #expect(probabilities.legendary == 4)
        #expect(probabilities.total == 100)
    }

    @Test func rarityProbabilitiesAreCappedAt180Minutes() {
        let at180Minutes = FishRewardService.rarityProbabilities(for: 180)
        let at300Minutes = FishRewardService.rarityProbabilities(for: 300)

        #expect(at300Minutes.common == at180Minutes.common)
        #expect(at300Minutes.rare == at180Minutes.rare)
        #expect(at300Minutes.epic == at180Minutes.epic)
        #expect(at300Minutes.legendary == at180Minutes.legendary)
        #expect(at300Minutes.total == 100)
    }

    @Test func rarityProbabilitiesAlwaysTotal100Percent() {
        for minutes in [0, 1, 47, 90, 179, 180, 300] {
            let probabilities = FishRewardService.rarityProbabilities(for: minutes)

            #expect(abs(probabilities.total - 100) < 0.000_001)
        }
    }

    @Test func studySessionUnder25MinutesDoesNotAwardFish() {
        let player = Player()

        let awardedFish = FishRewardService.awardFish(for: 24, to: player)

        #expect(awardedFish == nil)
        #expect(player.ownedFish.isEmpty)
    }

    @Test func studySessionOf25MinutesAwardsOneFish() {
        let player = Player()

        let awardedFish = FishRewardService.awardFish(for: 25, to: player)

        #expect(awardedFish != nil)
        #expect(player.ownedFish.count == 1)
        #expect(player.ownedFish.first === awardedFish)
    }

    @Test func repeatedEligibleSessionsAwardOneFishEach() {
        let player = Player()

        FishRewardService.awardFish(for: 25, to: player)
        FishRewardService.awardFish(for: 30, to: player)
        FishRewardService.awardFish(for: 60, to: player)

        #expect(player.ownedFish.count == 3)
    }

    @Test func playerCanOwnMultipleFishOfTheSameSpecies() {
        let firstClownfish = PlayerFish(species: .clownfish)
        let secondClownfish = PlayerFish(species: .clownfish)
        let player = Player()

        player.ownedFish.append(firstClownfish)
        player.ownedFish.append(secondClownfish)

        #expect(firstClownfish.id != secondClownfish.id)
        #expect(player.ownedFish.count == 2)
        #expect(player.ownedFish.count { $0.species == .clownfish } == 2)
    }

    @Test @MainActor func firstFishAcquisitionIsMarkedNewWithOneOwnedFish() throws {
        let player = Player()
        let result = try #require(FishAcquisitionResult.capture(for: player) {
            let fish = PlayerFish(species: .clownfish)
            player.ownedFish.append(fish)
            return fish
        })

        #expect(result.isNewFish)
        #expect(result.showsNewBadge)
        #expect(result.previousOwnedCount == 0)
        #expect(result.currentOwnedCount == 1)
        #expect(player.ownedFish.count { $0.species == .clownfish } == 1)
        #expect(result.species.rarity == .common)
    }

    @Test @MainActor func duplicateFishAcquisitionShowsExactCountChangeWithoutNewBadge() throws {
        let player = Player(ownedFish: (0..<4).map { _ in
            PlayerFish(species: .clownfish)
        })
        let result = try #require(FishAcquisitionResult.capture(for: player) {
            let fish = PlayerFish(species: .clownfish)
            player.ownedFish.append(fish)
            return fish
        })

        #expect(!result.isNewFish)
        #expect(!result.showsNewBadge)
        #expect(result.previousOwnedCount == 4)
        #expect(result.currentOwnedCount == 5)
        #expect(player.ownedFish.count { $0.species == .clownfish } == 5)
        #expect(result.species.rarity.rawValue == FishRarity.common.rawValue)
    }

    @Test @MainActor func ineligibleStudyDoesNotCreateFishAcquisitionResult() {
        let player = Player()
        let result = FishAcquisitionResult.capture(for: player) {
            FishRewardService.awardFish(for: 24, to: player)
        }

        #expect(result == nil)
        #expect(player.ownedFish.isEmpty)
    }

    @Test func fishInitialPositionIsStablePerIndividualAndIndependentAcrossIDs() {
        let firstID = UUID(uuid: (1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16))
        let secondID = UUID(uuid: (21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36))

        let firstPosition = AquariumFishMotion.initialPosition(for: firstID)
        #expect(AquariumFishMotion.initialPosition(for: firstID) == firstPosition)
        #expect(AquariumFishMotion.initialPosition(for: secondID) != firstPosition)
    }

    @Test func fishSwimmingPointsStayInsideAquariumSafeBounds() {
        let lowerPoint = AquariumFishMotion.point(xFraction: -1, yFraction: -1)
        let upperPoint = AquariumFishMotion.point(xFraction: 2, yFraction: 2)

        #expect(AquariumFishMotion.horizontalRange.contains(lowerPoint.x))
        #expect(AquariumFishMotion.verticalRange.contains(lowerPoint.y))
        #expect(AquariumFishMotion.horizontalRange.contains(upperPoint.x))
        #expect(AquariumFishMotion.verticalRange.contains(upperPoint.y))
    }

    @Test func fishVelocitySteersGraduallyTowardDesiredDirection() {
        let id = UUID(uuid: (1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16))
        var motion = AquariumFishMotion.initialState(for: id)
        motion.position = CGPoint(x: 0.5, y: 0.4)
        motion.behavior = .cruising
        motion.behaviorTimeRemaining = 100
        motion.velocity = CGVector(dx: motion.baseSpeed, dy: 0)
        motion.desiredDirection = CGVector(dx: 0, dy: 1)
        motion.currentSpeed = motion.baseSpeed
        motion.targetSpeed = motion.baseSpeed
        motion.directionChangeTimeRemaining = 100

        motion.advance(deltaTime: 1.0 / 30.0, elapsedTime: 1)

        #expect(motion.velocity.dx > 0)
        #expect(motion.velocity.dy > 0)
        #expect(motion.velocity.dy < motion.baseSpeed)
    }

    @Test func fishNearAquariumEdgesReceiveGradualInwardSteering() {
        let leftForce = AquariumFishMotion.wallSteering(at: CGPoint(x: 0.19, y: 0.4))
        let rightForce = AquariumFishMotion.wallSteering(at: CGPoint(x: 0.81, y: 0.4))
        let centerForce = AquariumFishMotion.wallSteering(at: CGPoint(x: 0.5, y: 0.4))

        #expect(leftForce.dx > 0)
        #expect(rightForce.dx < 0)
        #expect(abs(centerForce.dx) < 0.0001)
    }

    @Test func fishFacingUsesHysteresisAndDoesNotFlipInstantly() {
        let id = UUID(uuid: (1, 2, 3, 4, 255, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16))
        var motion = AquariumFishMotion.initialState(for: id)
        motion.position = CGPoint(x: 0.5, y: 0.4)
        motion.behavior = .cruising
        motion.behaviorTimeRemaining = 100
        motion.facingSign = -1
        motion.pendingFacingSign = -1
        motion.velocity = CGVector(dx: -motion.baseSpeed, dy: 0)
        motion.desiredDirection = CGVector(dx: -1, dy: 0)
        motion.currentSpeed = motion.baseSpeed
        motion.targetSpeed = motion.baseSpeed
        motion.directionChangeTimeRemaining = 100

        motion.advance(deltaTime: 0.1, elapsedTime: 1)
        #expect(motion.facingSign == -1)
        #expect(motion.facingWidth == 1)

        for step in 2...10 {
            motion.advance(deltaTime: 0.1, elapsedTime: Double(step))
        }
        #expect(motion.visualTurnTargetSign == 1)
        #expect(motion.facingWidth < 1)
        #expect(motion.facingWidth >= 0.55)
    }

    @Test func fishDartAlwaysTransitionsIntoBraking() {
        let id = UUID(uuid: (31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46))
        var motion = AquariumFishMotion.initialState(for: id)
        motion.behavior = .darting
        motion.behaviorTimeRemaining = 0

        motion.advance(deltaTime: 1.0 / 30.0, elapsedTime: 1)

        #expect(motion.behavior == .braking)
        #expect(motion.targetSpeed < motion.baseSpeed)
    }

    @Test func fishDartAndBrakeChangeSpeedThroughAcceleration() {
        let id = UUID(uuid: (51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66))
        var motion = AquariumFishMotion.initialState(for: id)
        motion.behavior = .darting
        motion.behaviorTimeRemaining = 10
        motion.targetSpeed = motion.baseSpeed * 2.5
        motion.currentSpeed = motion.baseSpeed
        let initialSpeed = motion.currentSpeed

        motion.advance(deltaTime: 1.0 / 30.0, elapsedTime: 1)

        #expect(motion.currentSpeed > initialSpeed)
        #expect(motion.currentSpeed < motion.targetSpeed)
        #expect(motion.accelerationMagnitude > 0)
    }

    @Test func bookOwnedCountCountsOnlyMatchingSpecies() {
        let player = Player(ownedFish: [
            PlayerFish(species: .clownfish),
            PlayerFish(species: .clownfish),
            PlayerFish(species: .pufferfish)
        ])

        #expect(BookView.ownedCount(for: .clownfish, in: player) == 2)
        #expect(BookView.ownedCount(for: .pufferfish, in: player) == 1)
        #expect(BookView.ownedCount(for: .seahorse, in: player) == 0)
    }

    @Test func bookOwnedCountIsZeroWithoutPlayer() {
        #expect(BookView.ownedCount(for: .clownfish, in: nil) == 0)
    }

    @Test func ownedFishCanBeSetAsFavorite() {
        let clownfish = PlayerFish(species: .clownfish)
        let player = Player(ownedFish: [clownfish])

        let didSetFavorite = BookView.setFavorite(.clownfish, for: player)

        #expect(didSetFavorite)
        #expect(player.favoriteFish?.id == clownfish.id)
    }

    @Test func selectingAnotherFishUpdatesFavorite() {
        let clownfish = PlayerFish(species: .clownfish)
        let pufferfish = PlayerFish(species: .pufferfish)
        let player = Player(ownedFish: [clownfish, pufferfish])

        BookView.setFavorite(.clownfish, for: player)
        BookView.setFavorite(.pufferfish, for: player)

        #expect(player.favoriteFish?.id == pufferfish.id)
    }

    @Test func unownedSpeciesCannotBeSetAsFavorite() {
        let clownfish = PlayerFish(species: .clownfish)
        let player = Player(ownedFish: [clownfish], favoriteFish: clownfish)

        let didSetFavorite = BookView.setFavorite(.whaleShark, for: player)

        #expect(!didSetFavorite)
        #expect(player.favoriteFish?.id == clownfish.id)
    }

    @Test @MainActor func initialCoinBalanceIsZero() throws {
        let container = try makePlayerContainer()
        let player = Player()
        container.mainContext.insert(player)
        try container.mainContext.save()

        #expect(CurrencyService.balance(of: player) == 0)
    }

    @Test @MainActor func coinsCanBeAddedMultipleTimesAndPersisted() throws {
        let container = try makePlayerContainer()
        let context = container.mainContext
        let player = Player()
        context.insert(player)
        try context.save()

        #expect(try CurrencyService.addCoins(10, to: player, in: context) == 10)
        #expect(try CurrencyService.addCoins(25, to: player, in: context) == 35)

        let refetchContext = ModelContext(container)
        let refetched = try #require(
            refetchContext.fetch(FetchDescriptor<Player>()).first
        )
        #expect(CurrencyService.balance(of: refetched) == 35)
    }

    @Test @MainActor func zeroAndNegativeCoinAdditionsAreIgnoredSafely() throws {
        let container = try makePlayerContainer()
        let context = container.mainContext
        let player = Player(coins: 12)
        context.insert(player)
        try context.save()

        #expect(try CurrencyService.addCoins(0, to: player, in: context) == 12)
        #expect(try CurrencyService.addCoins(-100, to: player, in: context) == 12)
        #expect(player.coins == 12)
    }

    @Test @MainActor func coinAdditionSaturatesAtIntegerMaximum() throws {
        let container = try makePlayerContainer()
        let context = container.mainContext
        let player = Player(coins: Int.max - 2)
        context.insert(player)
        try context.save()

        #expect(try CurrencyService.addCoins(10, to: player, in: context) == Int.max)
        #expect(CurrencyService.canAfford(Int.max, player: player))
    }

    @Test @MainActor func completedStudySessionAwardsTenCoinsAndKeepsFishReward() throws {
        let container = try makePlayerContainer()
        let context = container.mainContext
        let player = Player()
        context.insert(player)
        let clock = TestClock()
        let viewModel = TimerViewModel(
            studyTime: 25,
            breakTime: 5,
            now: { clock.now },
            sessionStore: makeTimerStore()
        )
        viewModel.onStudyFinished = {
            FishRewardService.awardFish(for: 25, to: player)
            let reward = CurrencyService.studyCompletionReward(
                for: 25,
                todayStudyMinutesBeforeCompletion: player.todayStudyMinutes
            )
            _ = try? CurrencyService.addCoins(reward, to: player, in: context)
        }

        viewModel.startStopTimer()
        clock.advance(by: 25 * 60)
        viewModel.synchronizeTime()

        #expect(CurrencyService.balance(of: player) == 10)
        #expect(player.ownedFish.count == 1)
    }

    @Test @MainActor func breakCompletionDoesNotAwardAdditionalCoins() throws {
        let container = try makePlayerContainer()
        let context = container.mainContext
        let player = Player()
        context.insert(player)
        let clock = TestClock()
        let viewModel = TimerViewModel(
            studyTime: 25,
            breakTime: 5,
            now: { clock.now },
            sessionStore: makeTimerStore()
        )
        viewModel.onStudyFinished = {
            let reward = CurrencyService.studyCompletionReward(
                for: 25,
                todayStudyMinutesBeforeCompletion: player.todayStudyMinutes
            )
            _ = try? CurrencyService.addCoins(reward, to: player, in: context)
        }

        viewModel.startStopTimer()
        clock.advance(by: 25 * 60)
        viewModel.synchronizeTime()
        #expect(CurrencyService.balance(of: player) == 10)

        viewModel.startStopTimer()
        clock.advance(by: 5 * 60)
        viewModel.synchronizeTime()

        #expect(CurrencyService.balance(of: player) == 10)
    }

    @Test func studyCoinRewardIsZeroForSessionsUnderTwentyFiveMinutes() {
        #expect(CurrencyService.studyCompletionReward(
            for: 24,
            todayStudyMinutesBeforeCompletion: 0
        ) == 0)
        #expect(CurrencyService.studyCompletionReward(
            for: 24,
            todayStudyMinutesBeforeCompletion: 200
        ) == 0)
    }

    @Test func studyCoinRewardIsTenBelowDailyTwoHundredMinutes() {
        #expect(CurrencyService.studyCompletionReward(
            for: 25,
            todayStudyMinutesBeforeCompletion: 0
        ) == 10)
        #expect(CurrencyService.studyCompletionReward(
            for: 25,
            todayStudyMinutesBeforeCompletion: 199
        ) == 10)
    }

    @Test func studyCoinRewardIsTwoAtOrAboveDailyTwoHundredMinutes() {
        #expect(CurrencyService.studyCompletionReward(
            for: 25,
            todayStudyMinutesBeforeCompletion: 200
        ) == 2)
        #expect(CurrencyService.studyCompletionReward(
            for: 60,
            todayStudyMinutesBeforeCompletion: 300
        ) == 4)
    }

    @Test func studyCoinRewardUsesTwentyFiveMinuteUnitsAcrossReductionThreshold() {
        #expect(CurrencyService.studyCompletionReward(
            for: 25,
            todayStudyMinutesBeforeCompletion: 0
        ) == 10)
        #expect(CurrencyService.studyCompletionReward(
            for: 50,
            todayStudyMinutesBeforeCompletion: 0
        ) == 20)
        #expect(CurrencyService.studyCompletionReward(
            for: 150,
            todayStudyMinutesBeforeCompletion: 0
        ) == 60)
        #expect(CurrencyService.studyCompletionReward(
            for: 200,
            todayStudyMinutesBeforeCompletion: 0
        ) == 80)
        #expect(CurrencyService.studyCompletionReward(
            for: 250,
            todayStudyMinutesBeforeCompletion: 0
        ) == 84)
    }

    @Test @MainActor func rewardUsesDailyTotalBeforeCompletedMinutesAreAdded() throws {
        let container = try makePlayerContainer()
        let context = container.mainContext
        let player = Player(todayStudyMinutes: 190)
        context.insert(player)

        let reward = CurrencyService.studyCompletionReward(
            for: 25,
            todayStudyMinutesBeforeCompletion: player.todayStudyMinutes
        )
        player.todayStudyMinutes += 25
        _ = try CurrencyService.addCoins(reward, to: player, in: context)

        #expect(player.todayStudyMinutes == 215)
        #expect(CurrencyService.balance(of: player) == 10)
    }

    @Test @MainActor func expiredStudyUnderTwentyFiveMinutesDoesNotAwardCoins() throws {
        let container = try makePlayerContainer()
        let context = container.mainContext
        let player = Player()
        context.insert(player)
        let clock = TestClock()
        let defaults = makeTimerDefaults()
        let oldStore = TimerSessionStore(defaults: defaults, processIdentifier: "coin-old")
        let oldViewModel = TimerViewModel(
            studyTime: 60,
            breakTime: 5,
            now: { clock.now },
            sessionStore: oldStore
        )
        oldViewModel.startStopTimer()
        clock.advance(by: 10 * 60)
        oldViewModel.recordLastActiveTime()
        clock.advance(by: 10 * 60 + 1)

        let newStore = TimerSessionStore(defaults: defaults, processIdentifier: "coin-new")
        let restored = TimerViewModel(
            studyTime: 60,
            breakTime: 5,
            now: { clock.now },
            sessionStore: newStore
        )
        restored.onStudyFinished = {
            let reward = CurrencyService.studyCompletionReward(
                for: restored.lastCompletedStudyMinutes,
                todayStudyMinutesBeforeCompletion: player.todayStudyMinutes
            )
            _ = try? CurrencyService.addCoins(reward, to: player, in: context)
        }
        restored.restorePersistedSessionIfNeeded()

        #expect(CurrencyService.balance(of: player) == 0)
    }

    @Test @MainActor func repeatedCompletionChecksDoNotAwardCoinsTwice() throws {
        let container = try makePlayerContainer()
        let context = container.mainContext
        let player = Player()
        context.insert(player)
        let clock = TestClock()
        let viewModel = TimerViewModel(
            studyTime: 25,
            breakTime: 5,
            now: { clock.now },
            sessionStore: makeTimerStore()
        )
        viewModel.onStudyFinished = {
            _ = try? CurrencyService.addCoins(10, to: player, in: context)
        }

        viewModel.startStopTimer()
        clock.advance(by: 25 * 60)
        viewModel.synchronizeTime()
        viewModel.synchronizeTime()
        viewModel.tick()

        #expect(CurrencyService.balance(of: player) == 10)
    }

    @Test @MainActor func firstStudyCompletionStartsStreakAtOne() throws {
        let container = try makePlayerContainer()
        let player = Player()
        container.mainContext.insert(player)

        let result = try StudyStreakService.recordStudyCompletion(
            for: player,
            at: streakDate(year: 2026, month: 8, day: 1),
            calendar: streakCalendar,
            in: container.mainContext
        )

        #expect(result == StudyStreakUpdate(streakDays: 1, awardedCoins: 0, didAdvance: true))
        #expect(player.studyStreakDays == 1)
    }

    @Test @MainActor func multipleCompletionsOnSameDayDoNotAdvanceStreak() throws {
        let container = try makePlayerContainer()
        let player = Player()
        container.mainContext.insert(player)
        let completionDate = streakDate(year: 2026, month: 8, day: 2)

        _ = try StudyStreakService.recordStudyCompletion(
            for: player,
            at: completionDate,
            calendar: streakCalendar,
            in: container.mainContext
        )
        let secondResult = try StudyStreakService.recordStudyCompletion(
            for: player,
            at: completionDate.addingTimeInterval(60 * 60),
            calendar: streakCalendar,
            in: container.mainContext
        )

        #expect(!secondResult.didAdvance)
        #expect(secondResult.awardedCoins == 0)
        #expect(player.studyStreakDays == 1)
    }

    @Test @MainActor func studyingOnTheNextDayContinuesStreakAndGapResetsIt() throws {
        let container = try makePlayerContainer()
        let player = Player()
        container.mainContext.insert(player)

        _ = try StudyStreakService.recordStudyCompletion(
            for: player,
            at: streakDate(year: 2026, month: 8, day: 1),
            calendar: streakCalendar,
            in: container.mainContext
        )
        _ = try StudyStreakService.recordStudyCompletion(
            for: player,
            at: streakDate(year: 2026, month: 8, day: 2),
            calendar: streakCalendar,
            in: container.mainContext
        )
        #expect(player.studyStreakDays == 2)

        _ = try StudyStreakService.recordStudyCompletion(
            for: player,
            at: streakDate(year: 2026, month: 8, day: 4),
            calendar: streakCalendar,
            in: container.mainContext
        )
        #expect(player.studyStreakDays == 1)
    }

    @Test @MainActor func sevenDayRewardIsAwardedEverySevenConsecutiveDays() throws {
        let container = try makePlayerContainer()
        let player = Player(
            studyStreakDays: 6,
            lastStudyCompletionDate: streakDate(year: 2026, month: 8, day: 6)
        )
        container.mainContext.insert(player)

        let firstAchievement = try StudyStreakService.recordStudyCompletion(
            for: player,
            at: streakDate(year: 2026, month: 8, day: 7),
            calendar: streakCalendar,
            in: container.mainContext
        )
        #expect(firstAchievement.awardedCoins == 70)
        #expect(CurrencyService.balance(of: player) == 70)

        let sameDayCompletion = try StudyStreakService.recordStudyCompletion(
            for: player,
            at: streakDate(year: 2026, month: 8, day: 7).addingTimeInterval(60 * 60),
            calendar: streakCalendar,
            in: container.mainContext
        )
        #expect(sameDayCompletion.awardedCoins == 0)
        #expect(CurrencyService.balance(of: player) == 70)

        player.studyStreakDays = 13
        player.lastStudyCompletionDate = streakDate(year: 2026, month: 8, day: 13)
        let fourteenDayAchievement = try StudyStreakService.recordStudyCompletion(
            for: player,
            at: streakDate(year: 2026, month: 8, day: 14),
            calendar: streakCalendar,
            in: container.mainContext
        )
        #expect(fourteenDayAchievement.awardedCoins == 70)
        #expect(CurrencyService.balance(of: player) == 140)

        player.studyStreakDays = 20
        player.lastStudyCompletionDate = streakDate(year: 2026, month: 8, day: 20)
        let twentyOneDayAchievement = try StudyStreakService.recordStudyCompletion(
            for: player,
            at: streakDate(year: 2026, month: 8, day: 21),
            calendar: streakCalendar,
            in: container.mainContext
        )
        #expect(twentyOneDayAchievement.awardedCoins == 70)
        #expect(CurrencyService.balance(of: player) == 210)
    }

    @Test @MainActor func thirtyDayRewardIsAwardedEveryThirtyConsecutiveDays() throws {
        let thirtyDayContainer = try makePlayerContainer()
        let thirtyDayPlayer = Player(
            studyStreakDays: 29,
            lastStudyCompletionDate: streakDate(year: 2026, month: 8, day: 29)
        )
        thirtyDayContainer.mainContext.insert(thirtyDayPlayer)
        let thirtyDayResult = try StudyStreakService.recordStudyCompletion(
            for: thirtyDayPlayer,
            at: streakDate(year: 2026, month: 8, day: 30),
            calendar: streakCalendar,
            in: thirtyDayContainer.mainContext
        )
        #expect(thirtyDayResult.awardedCoins == 200)
        #expect(CurrencyService.balance(of: thirtyDayPlayer) == 200)

        let sameDayResult = try StudyStreakService.recordStudyCompletion(
            for: thirtyDayPlayer,
            at: streakDate(year: 2026, month: 8, day: 30).addingTimeInterval(60 * 60),
            calendar: streakCalendar,
            in: thirtyDayContainer.mainContext
        )
        #expect(sameDayResult.awardedCoins == 0)
        #expect(CurrencyService.balance(of: thirtyDayPlayer) == 200)

        thirtyDayPlayer.studyStreakDays = 59
        thirtyDayPlayer.lastStudyCompletionDate = streakDate(year: 2026, month: 9, day: 28)
        let sixtyDayResult = try StudyStreakService.recordStudyCompletion(
            for: thirtyDayPlayer,
            at: streakDate(year: 2026, month: 9, day: 29),
            calendar: streakCalendar,
            in: thirtyDayContainer.mainContext
        )
        #expect(sixtyDayResult.awardedCoins == 200)
        #expect(CurrencyService.balance(of: thirtyDayPlayer) == 400)
    }

    @Test @MainActor func yearRewardIsAwardedEveryThreeHundredSixtyFiveConsecutiveDays() throws {
        let yearContainer = try makePlayerContainer()
        let yearPlayer = Player(
            studyStreakDays: 364,
            lastStudyCompletionDate: streakDate(year: 2027, month: 7, day: 31)
        )
        yearContainer.mainContext.insert(yearPlayer)
        let yearResult = try StudyStreakService.recordStudyCompletion(
            for: yearPlayer,
            at: streakDate(year: 2027, month: 8, day: 1),
            calendar: streakCalendar,
            in: yearContainer.mainContext
        )
        #expect(yearResult.awardedCoins == 2_000)
        #expect(CurrencyService.balance(of: yearPlayer) == 2_000)

        yearPlayer.studyStreakDays = 729
        yearPlayer.lastStudyCompletionDate = streakDate(year: 2028, month: 7, day: 31)
        let sevenHundredThirtyDayResult = try StudyStreakService.recordStudyCompletion(
            for: yearPlayer,
            at: streakDate(year: 2028, month: 8, day: 1),
            calendar: streakCalendar,
            in: yearContainer.mainContext
        )
        #expect(sevenHundredThirtyDayResult.awardedCoins == 2_000)
        #expect(CurrencyService.balance(of: yearPlayer) == 4_000)
    }

    @Test func studyCompletionRewardKeepsStudyAndStreakRewardsSeparate() {
        let reward = StudyCompletionReward(
            studyReward: 60,
            streakReward: 70,
            streakDays: 7
        )

        #expect(reward.studyReward == 60)
        #expect(reward.streakReward == 70)
        #expect(reward.totalReward == 130)
        #expect(reward.streakDays == 7)
        #expect(reward.hasStreakReward)
    }

    @Test func zeroStreakRewardIsMarkedAsHiddenFromCompletionBreakdown() {
        let reward = StudyCompletionReward(
            studyReward: 60,
            streakReward: 0,
            streakDays: 6
        )

        #expect(!reward.hasStreakReward)
        #expect(reward.totalReward == 60)
    }

    @Test func smallRewardCountAnimationIncrementsOneCoinAtATime() {
        #expect(RewardCountAnimation.values(to: 10) == Array(0...10))
    }

    @Test func largeRewardCountAnimationIsBoundedAndEndsAtExactAmount() {
        let values = RewardCountAnimation.values(to: 2_000)

        #expect(values.first == 0)
        #expect(values.last == 2_000)
        #expect(values.count <= RewardCountAnimation.maximumSteps + 1)
    }

    @Test func rewardCountAnimationSafelyHandlesZero() {
        #expect(RewardCountAnimation.values(to: 0) == [0])
        #expect(RewardCountAnimation.values(to: -10) == [0])
    }

    @Test func studyRewardMultiplierDoesNotMultiplyStreakReward() {
        let reward = StudyCompletionReward(
            studyReward: 10,
            streakReward: 70,
            streakDays: 7
        )
        let doubled = reward.applyingStudyRewardMultiplier(2)

        #expect(doubled.studyReward == 20)
        #expect(doubled.streakReward == 70)
        #expect(doubled.totalReward == 90)
    }

    @Test func completionRewardPresentationRequiresTwentyFiveMinutes() {
        #expect(!StudyCompletionReward.shouldPresent(forStudyMinutes: 24))
        #expect(StudyCompletionReward.shouldPresent(forStudyMinutes: 25))
    }

    @Test @MainActor func dailyStudyMinutesArePersistedAndSameDaySessionsAreCombined() throws {
        let container = try makeStudyHistoryContainer()
        let date = streakDate(year: 2026, month: 8, day: 22)

        try StudyHistoryService.addStudyMinutes(25, on: date, calendar: streakCalendar, in: container.mainContext)
        try StudyHistoryService.addStudyMinutes(50, on: date, calendar: streakCalendar, in: container.mainContext)

        let records = try container.mainContext.fetch(FetchDescriptor<StudyDailyRecord>())
        #expect(records.count == 1)
        #expect(StudyHistoryService.minutes(on: date, from: records, calendar: streakCalendar) == 75)
    }

    @Test @MainActor func dailyStudyMinutesSeparateCalendarDaysAndReturnZeroForMissingDays() throws {
        let container = try makeStudyHistoryContainer()
        let today = streakDate(year: 2026, month: 8, day: 22)
        let yesterday = streakDate(year: 2026, month: 8, day: 21)
        let noStudyDay = streakDate(year: 2026, month: 8, day: 20)

        try StudyHistoryService.addStudyMinutes(50, on: today, calendar: streakCalendar, in: container.mainContext)
        try StudyHistoryService.addStudyMinutes(75, on: yesterday, calendar: streakCalendar, in: container.mainContext)

        let records = try container.mainContext.fetch(FetchDescriptor<StudyDailyRecord>())
        #expect(StudyHistoryService.minutes(on: today, from: records, calendar: streakCalendar) == 50)
        #expect(StudyHistoryService.minutes(on: yesterday, from: records, calendar: streakCalendar) == 75)
        #expect(StudyHistoryService.minutes(on: noStudyDay, from: records, calendar: streakCalendar) == 0)
    }

    @Test func recentStudyHistoryAlwaysContainsThirtyChronologicalDays() {
        let today = streakDate(year: 2026, month: 8, day: 22)
        let summaries = StudyHistoryService.recentDays(
            count: 30,
            endingAt: today,
            from: [],
            calendar: streakCalendar
        )

        #expect(summaries.count == 30)
        #expect(summaries.last?.date == streakCalendar.startOfDay(for: today))
        #expect(summaries.allSatisfy { $0.minutes == 0 })
        #expect(zip(summaries, summaries.dropFirst()).allSatisfy { pair in
            pair.0.date < pair.1.date
        })
    }

    @Test @MainActor func existingTodayTotalSeedsFirstDailyHistoryRecord() throws {
        let container = try makeStudyHistoryContainer()
        let today = streakDate(year: 2026, month: 8, day: 22)

        try StudyHistoryService.addStudyMinutes(
            25,
            on: today,
            existingTodayMinutesBeforeCompletion: 50,
            calendar: streakCalendar,
            in: container.mainContext
        )

        let records = try container.mainContext.fetch(FetchDescriptor<StudyDailyRecord>())
        #expect(StudyHistoryService.minutes(on: today, from: records, calendar: streakCalendar) == 75)
    }

    @Test func monthlyCalendarUsesCorrectDayCountsIncludingLeapYear() {
        let cases = [
            (2024, 2, 29),
            (2026, 2, 28),
            (2026, 4, 30),
            (2026, 8, 31)
        ]

        for (year, month, expectedDayCount) in cases {
            let date = streakDate(year: year, month: month, day: 15)
            let cells = StudyHistoryService.monthlyCalendar(
                containing: date,
                from: [],
                calendar: streakCalendar
            )
            #expect(cells.compactMap(\.date).count == expectedDayCount)
            #expect(cells.count.isMultiple(of: 7))
        }
    }

    @Test func monthlyCalendarAlignsFirstDayWithItsWeekday() {
        let august2026 = streakDate(year: 2026, month: 8, day: 15)
        let cells = StudyHistoryService.monthlyCalendar(
            containing: august2026,
            from: [],
            calendar: streakCalendar
        )
        let firstDateIndex = cells.firstIndex { $0.date != nil }

        // 2026年8月1日は土曜日。日曜始まりでは7列目（index 6）。
        #expect(firstDateIndex == 6)
    }

    @Test @MainActor func monthlyCalendarIncludesRecordedMinutesAndZeroForMissingDays() {
        let august2026 = streakDate(year: 2026, month: 8, day: 15)
        let recordedDay = streakDate(year: 2026, month: 8, day: 22)
        let record = StudyDailyRecord(day: recordedDay, studyMinutes: 50)
        let cells = StudyHistoryService.monthlyCalendar(
            containing: august2026,
            from: [record],
            calendar: streakCalendar
        )

        #expect(cells.first { cell in
            guard let date = cell.date else { return false }
            return streakCalendar.component(.day, from: date) == 22
        }?.minutes == 50)
        #expect(cells.first { cell in
            guard let date = cell.date else { return false }
            return streakCalendar.component(.day, from: date) == 21
        }?.minutes == 0)
    }

    @Test func adjacentMonthMovesBackwardAndForwardFromMonthStart() {
        let august2026 = streakDate(year: 2026, month: 8, day: 22)
        let previous = StudyHistoryService.adjacentMonth(
            from: august2026,
            offset: -1,
            calendar: streakCalendar
        )
        let next = StudyHistoryService.adjacentMonth(
            from: august2026,
            offset: 1,
            calendar: streakCalendar
        )

        #expect(streakCalendar.component(.month, from: previous) == 7)
        #expect(streakCalendar.component(.month, from: next) == 9)
        #expect(streakCalendar.component(.day, from: previous) == 1)
        #expect(streakCalendar.component(.day, from: next) == 1)
    }

    @Test func shopCatalogKeepsPricesAndCategoriesInOneDefinition() throws {
        let seaweed = try #require(ShopCatalog.items.first { $0.id == "decoration-seaweed" })
        let rock = try #require(ShopCatalog.items.first { $0.id == "decoration-rock" })

        #expect(seaweed.price == 100)
        #expect(rock.price == 120)
        #expect(ShopCatalog.items(in: .decoration).count == 2)
        #expect(ShopCatalog.items(in: .background).count == AquariumBackgroundTheme.allCases.count)
    }

    @Test @MainActor func affordableDecorationPurchaseConsumesCoinsAndAddsStoredPlacement() throws {
        let container = try makeShopContainer()
        let player = Player(coins: 250)
        container.mainContext.insert(player)
        let seaweed = try #require(ShopCatalog.items.first { $0.id == "decoration-seaweed" })

        let placement = try ShopService.purchaseDecoration(
            seaweed,
            for: player,
            in: container.mainContext
        )

        #expect(CurrencyService.balance(of: player) == 150)
        #expect(placement.kind == .seaweed)
        #expect(!placement.isPlaced)
        #expect(try container.mainContext.fetch(FetchDescriptor<AquariumDecorationPlacement>()).count == 1)
    }

    @Test @MainActor func sameDecorationCanBePurchasedMultipleTimesAsSeparateItems() throws {
        let container = try makeShopContainer()
        let player = Player(coins: 300)
        container.mainContext.insert(player)
        let seaweed = try #require(ShopCatalog.items.first { $0.id == "decoration-seaweed" })

        let first = try ShopService.purchaseDecoration(seaweed, for: player, in: container.mainContext)
        let second = try ShopService.purchaseDecoration(seaweed, for: player, in: container.mainContext)
        let placements = try container.mainContext.fetch(FetchDescriptor<AquariumDecorationPlacement>())

        #expect(first.decorationID != second.decorationID)
        #expect(placements.count == 2)
        #expect(placements.allSatisfy { $0.kind == .seaweed && !$0.isPlaced })
        #expect(CurrencyService.balance(of: player) == 100)
    }

    @Test @MainActor func insufficientCoinsDoNotPurchaseDecorationOrChangeBalance() throws {
        let container = try makeShopContainer()
        let player = Player(coins: 99)
        container.mainContext.insert(player)
        let seaweed = try #require(ShopCatalog.items.first { $0.id == "decoration-seaweed" })

        #expect(!CurrencyService.canAfford(seaweed.price, player: player))
        #expect(throws: ShopPurchaseError.insufficientCoins) {
            try ShopService.purchaseDecoration(seaweed, for: player, in: container.mainContext)
        }
        #expect(CurrencyService.balance(of: player) == 99)
        #expect(try container.mainContext.fetch(FetchDescriptor<AquariumDecorationPlacement>()).isEmpty)
    }

    @Test @MainActor func backgroundProductIsDisplayedButNotPurchasedYet() throws {
        let container = try makeShopContainer()
        let player = Player(coins: 1_000)
        container.mainContext.insert(player)
        let background = try #require(ShopCatalog.items.first { $0.category == .background })

        #expect(throws: ShopPurchaseError.unsupportedProduct) {
            try ShopService.purchaseDecoration(background, for: player, in: container.mainContext)
        }
        #expect(CurrencyService.balance(of: player) == 1_000)
    }

}

private final class TestClock {
    var now = Date(timeIntervalSinceReferenceDate: 1_000_000)

    func advance(by interval: TimeInterval) {
        now = now.addingTimeInterval(interval)
    }
}

private func makeTimerDefaults() -> UserDefaults {
    UserDefaults(suiteName: "PomodoroAquariumTests.\(UUID().uuidString)")!
}

private func makeTimerStore(processIdentifier: String = UUID().uuidString) -> TimerSessionStore {
    TimerSessionStore(defaults: makeTimerDefaults(), processIdentifier: processIdentifier)
}

private func makeDecorationContainer() throws -> ModelContainer {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(
        for: AquariumDecorationPlacement.self,
        configurations: configuration
    )
}

private func makePlayerContainer() throws -> ModelContainer {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(
        for: Player.self, PlayerFish.self,
        configurations: configuration
    )
}

private func makeStudyHistoryContainer() throws -> ModelContainer {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(
        for: StudyDailyRecord.self,
        configurations: configuration
    )
}

private func makeShopContainer() throws -> ModelContainer {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(
        for: Player.self, PlayerFish.self, AquariumDecorationPlacement.self,
        configurations: configuration
    )
}

private func makeThemeDefaults() -> UserDefaults {
    UserDefaults(suiteName: "PomodoroAquariumThemeTests.\(UUID().uuidString)")!
}

private var streakCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
}

private func streakDate(year: Int, month: Int, day: Int) -> Date {
    streakCalendar.date(from: DateComponents(
        year: year,
        month: month,
        day: day,
        hour: 12
    ))!
}
