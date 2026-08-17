//
//  PomodoroAquariumTests.swift
//  PomodoroAquariumTests
//
//  Created by 阿部弦生 on 2026/07/02.
//

import Foundation
import Testing
@testable import PomodoroAquarium

struct PomodoroAquariumTests {

    @Test func runningTimerUsesElapsedTimeForTenSeconds() {
        let clock = TestClock()
        let viewModel = TimerViewModel(studyTime: 25, breakTime: 5, now: { clock.now }, sessionStore: makeTimerStore())

        viewModel.startStopTimer()
        clock.advance(by: 10)
        viewModel.tick()

        #expect(viewModel.timeRemaining == 25 * 60 - 10)
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

    @Test func newProcessInterruptsSessionAfterOneHundredTwentyOneSeconds() {
        let clock = TestClock()
        let defaults = makeTimerDefaults()
        let oldStore = TimerSessionStore(defaults: defaults, processIdentifier: "old")
        let oldViewModel = TimerViewModel(studyTime: 25, breakTime: 5, now: { clock.now }, sessionStore: oldStore)
        oldViewModel.startStopTimer()
        clock.advance(by: 121)

        let newStore = TimerSessionStore(defaults: defaults, processIdentifier: "new")
        let restored = TimerViewModel(studyTime: 25, breakTime: 5, now: { clock.now }, sessionStore: newStore)
        restored.restorePersistedSessionIfNeeded()

        #expect(!restored.isRunning)
        #expect(restored.isStudyTime)
        #expect(restored.timeRemaining == 25 * 60)
        #expect(newStore.load() == nil)
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

    @Test func interruptedSessionDoesNotCompleteOrAwardFish() {
        let clock = TestClock()
        let defaults = makeTimerDefaults()
        let oldStore = TimerSessionStore(defaults: defaults, processIdentifier: "old")
        let oldViewModel = TimerViewModel(studyTime: 25, breakTime: 5, now: { clock.now }, sessionStore: oldStore)
        oldViewModel.startStopTimer()
        clock.advance(by: 121)

        let player = Player()
        var completionCount = 0
        let newStore = TimerSessionStore(defaults: defaults, processIdentifier: "new")
        let restored = TimerViewModel(studyTime: 25, breakTime: 5, now: { clock.now }, sessionStore: newStore)
        restored.onStudyFinished = {
            completionCount += 1
            FishRewardService.awardFish(for: 25, to: player)
        }
        restored.restorePersistedSessionIfNeeded()

        #expect(completionCount == 0)
        #expect(player.ownedFish.isEmpty)
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

    @Test func breakSessionRestoresWithinGracePeriod() {
        let clock = TestClock()
        let defaults = makeTimerDefaults()
        let oldStore = TimerSessionStore(defaults: defaults, processIdentifier: "old")
        let oldViewModel = TimerViewModel(studyTime: 1, breakTime: 5, now: { clock.now }, sessionStore: oldStore)
        oldViewModel.startStopTimer()
        clock.advance(by: 60)
        oldViewModel.synchronizeTime()
        oldViewModel.startStopTimer()
        clock.advance(by: 60)

        let newStore = TimerSessionStore(defaults: defaults, processIdentifier: "new")
        let restored = TimerViewModel(studyTime: 1, breakTime: 5, now: { clock.now }, sessionStore: newStore)
        restored.restorePersistedSessionIfNeeded()

        #expect(!restored.isStudyTime)
        #expect(restored.isRunning)
        #expect(restored.timeRemaining == 4 * 60)
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

    @Test func interruptionBannerIsConsumedOnlyOnce() {
        let clock = TestClock()
        let defaults = makeTimerDefaults()
        let oldStore = TimerSessionStore(defaults: defaults, processIdentifier: "old")
        let oldViewModel = TimerViewModel(studyTime: 25, breakTime: 5, now: { clock.now }, sessionStore: oldStore)
        oldViewModel.startStopTimer()
        clock.advance(by: 121)

        let newStore = TimerSessionStore(defaults: defaults, processIdentifier: "new")
        #expect(newStore.launchStatus(at: clock.now) == .interrupted)
        #expect(newStore.consumeInterruptionBanner())
        #expect(!newStore.consumeInterruptionBanner())
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
