import Foundation
import SwiftData
import Testing
@testable import PomodoroAquarium

@MainActor
struct FishProbabilityPresentationTests {
    @Test func homeProjectionUsesTheDrawAPIAndSummedFinalizedSeconds() throws {
        let f = try ProbabilityFixture()
        let yesterday = f.calendar.date(byAdding: .day, value: -1, to: f.now)!
        f.context.insert(FocusSessionRecord(completedAt: yesterday, durationMinutes: 999, durationSeconds: 1500))
        f.context.insert(FocusSessionRecord(completedAt: f.now, durationMinutes: 999, durationSeconds: 30))
        f.context.insert(FocusSessionRecord(completedAt: f.now, durationMinutes: 999, durationSeconds: 30))
        try f.context.save()
        let records = try f.records()
        let projection = FishProbabilityProjection.make(on: f.now, records: records, calendar: f.calendar)
        let minutes = try PreviousDayFocusDurationService.minutes(before: f.now, calendar: f.calendar, in: f.context)
        #expect(minutes == 25)
        for rarity in [FishRarity.common, .rare, .epic, .legendary] {
            #expect(projection.today.probability(for: rarity) == FishRewardService.rarityProbabilities(for: minutes).probability(for: rarity))
            #expect(projection.tomorrow.probability(for: rarity) == FishRewardService.rarityProbabilities(for: 1).probability(for: rarity))
        }
        let dayAfter = f.calendar.date(byAdding: .day, value: 1, to: f.now)!
        let nextDay = FishProbabilityProjection.make(on: dayAfter, records: records, calendar: f.calendar)
        #expect(nextDay.today.rare == projection.tomorrow.rare)
        // A running timer has no finalized record and cannot affect either projection.
        let store = TimerSessionStore(defaults: f.defaults)
        let timer = TimerViewModel(studyTime: 25, breakTime: 5, now: { f.now }, sessionStore: store,
                                   notificationService: DisabledTimerNotificationService.shared)
        timer.resumeTimer()
        #expect(FishProbabilityProjection.make(on: f.now, records: try f.records(), calendar: f.calendar).tomorrow.rare
            == projection.tomorrow.rare)
        timer.pauseTimer()
    }

    @Test func increaseIsFixedAndReprocessingCannotCountTheSameSessionTwice() throws {
        let f = try ProbabilityFixture()
        let id = UUID()
        let first = try f.finalize(id: id, seconds: 1500)
        #expect(first.before(for: .rare) == 20)
        #expect(abs(first.after(for: .rare) - 20.694444444444443) < 0.000001)
        #expect(FishProbabilityProjection.percentageText(first.after(for: .rare)) == "20.7%")
        #expect(first.hasIncrease(on: f.now, calendar: f.calendar))
        for rarity in FishProbabilityProjection.rarities {
            #expect(first.before(for: rarity) == FishRewardService.rarityProbabilities(for: 0).probability(for: rarity))
            #expect(first.after(for: rarity) == FishRewardService.rarityProbabilities(for: 25).probability(for: rarity))
            #expect(first.showsIncrease(for: rarity, on: f.now, calendar: f.calendar) == (rarity != .common))
        }
        #expect(FishProbabilityProjection.percentageText(70, compact: true) == "70%")
        #expect(FishProbabilityProjection.percentageText(first.after(for: .rare), compact: true) == "20.7%")
        _ = try f.finalize(seconds: 1500)
        let replay = try f.finalize(id: id, seconds: 1500)
        #expect(replay == first)
        #expect(try f.records().count == 2)
        let reopened = UserDefaults(suiteName: f.suite)!
        let restored = try FishProbabilityPresentationStore.snapshot(for: id, wasAlreadyRecorded: true,
            on: f.now, calendar: f.calendar, defaults: reopened, in: f.context)
        #expect(restored == first)
    }

    @Test func upperLimitAndSubminuteChangesNeverShowFalseUp() throws {
        let f = try ProbabilityFixture()
        _ = try f.finalize(seconds: 180 * 60)
        let capped = try f.finalize(seconds: 1500)
        #expect(capped.before(for: .rare) == 25 && capped.after(for: .rare) == 25)
        #expect(!capped.hasIncrease(on: f.now, calendar: f.calendar))
        for rarity in FishProbabilityProjection.increasingRarities {
            #expect(capped.before(for: rarity) == capped.after(for: rarity))
            #expect(!capped.showsIncrease(for: rarity, on: f.now, calendar: f.calendar))
        }
        #expect(capped.status(on: f.now, calendar: f.calendar) == "明日の確率は上限です")
        let g = try ProbabilityFixture()
        let small = try g.finalize(seconds: 30)
        #expect(small.before(for: .rare) == small.after(for: .rare))
        #expect(!small.isAtMaximum)
        let crossesMinute = try g.finalize(seconds: 30)
        #expect(crossesMinute.after(for: .rare) > crossesMinute.before(for: .rare))
        #expect(crossesMinute.afterSeconds == 60)
    }

    @Test func crossMidnightUsesAttributionDayAndStaleReceiptsDoNotSayTomorrowUp() throws {
        let f = try ProbabilityFixture()
        let yesterday = f.calendar.date(byAdding: .day, value: -1, to: f.now)!
        let crossingStart = f.calendar.startOfDay(for: f.now).addingTimeInterval(-600)
        let change = try f.finalize(seconds: 1200, startedAt: crossingStart)
        #expect(change.before(for: .rare) == change.after(for: .rare))
        #expect(StudyHistoryService.focusMinutes(on: yesterday, from: try f.records(), calendar: f.calendar) == 20)
        let current = try f.finalize(seconds: 1500)
        let nextDay = f.calendar.date(byAdding: .day, value: 1, to: f.now)!
        #expect(!current.hasIncrease(on: nextDay, calendar: f.calendar))
        #expect(current.status(on: nextDay, calendar: f.calendar).contains("過去日"))
    }

    @Test func pomodoroAggregationCombinesSecondsAndSurvivesReopening() throws {
        let f = try ProbabilityFixture(), flow = UUID()
        let first = try f.finalize(seconds: 1500), second = try f.finalize(seconds: 1500)
        for change in [first, first, second] {
            PomodoroFlowRewardStore.append(.init(studyReward: 10, streakReward: 0, streakDays: 1,
                probabilityChange: change), minutes: 25, sessionID: change.sessionIDs[0], flowID: flow, defaults: f.defaults)
        }
        let summary = try #require(PomodoroFlowRewardStore.load(flowID: flow, defaults: UserDefaults(suiteName: f.suite)!))
        let combined = try #require(summary.completionReward.probabilityChange)
        #expect(summary.sessions.count == 2 && summary.studyPoints == 20 && summary.minutes == 50)
        #expect(combined.beforeSeconds == 0 && combined.afterSeconds == 3000)
        #expect(FishProbabilityProjection.percentageText(combined.after(for: .rare)) == "21.4%")
        #expect(summary.completionReward.applyingStudyRewardMultiplier(2).probabilityChange == combined)
        let tomorrow = f.calendar.date(byAdding: .day, value: 1, to: f.now)!
        let next = try f.finalize(seconds: 1500, displayDate: tomorrow)
        let acrossDays = try #require(FishProbabilityChange.combined([first, second, next]))
        #expect(acrossDays.referenceDay == f.calendar.startOfDay(for: tomorrow))
        #expect(acrossDays.beforeSeconds == 0 && acrossDays.afterSeconds == 1500)
        #expect(acrossDays.sessionIDs == next.sessionIDs)
    }

    @Test func existingRecordWithoutReceiptIsConservativeAndOldFlowJSONStillLoads() throws {
        let f = try ProbabilityFixture()
        let id = UUID()
        f.context.insert(FocusSessionRecord(id: id, completedAt: f.now, durationMinutes: 25))
        try f.context.save()
        let replay = try f.finalize(id: id, seconds: 1500)
        #expect(replay.before(for: .rare) == replay.after(for: .rare))
        #expect(!replay.hasIncrease(on: f.now, calendar: f.calendar))
        let flow = UUID()
        let legacy: [String: Any] = ["flowID": flow.uuidString, "sessions": [id.uuidString], "minutes": 25,
            "studyPoints": 10, "streakPoints": 0, "streakDays": 1, "didEarnFish": false]
        f.defaults.set(try JSONSerialization.data(withJSONObject: legacy), forKey: "pomodoroFlowRewardSummary")
        let summary = try #require(PomodoroFlowRewardStore.load(flowID: flow, defaults: f.defaults))
        #expect(summary.studyPoints == 10 && summary.minutes == 25)
        #expect(summary.completionReward.probabilityChange == nil)
    }
}

@MainActor
private final class ProbabilityFixture {
    let container: ModelContainer
    let context: ModelContext
    let suite = "FishProbabilityPresentationTests-\(UUID())"
    let defaults: UserDefaults
    let calendar: Calendar
    let now: Date

    init() throws {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        calendar = c
        now = c.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 12))!
        defaults = UserDefaults(suiteName: suite)!
        container = try ModelContainer(for: Player.self, PlayerFish.self, FocusSessionRecord.self,
            StudyDailyRecord.self, RewardHistoryEntry.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        context = ModelContext(container)
        context.autosaveEnabled = false
    }
    deinit { defaults.removePersistentDomain(forName: suite) }
    func records() throws -> [FocusSessionRecord] { try context.fetch(FetchDescriptor<FocusSessionRecord>()) }
    func finalize(id: UUID = UUID(), seconds: Int, startedAt: Date? = nil, displayDate: Date? = nil) throws -> FishProbabilityChange {
        let date = displayDate ?? now
        let existed = try FishProbabilityPresentationStore.containsSession(id, in: context)
        let session = FinalizedFocusSession(id: id, completedAt: date, validFocusSeconds: seconds,
            endReason: .completed, categoryID: FocusCategoryDefaults.studyID, focusMethod: .pomodoro,
            sessionStartedAt: startedAt)
        try StudyHistoryService.recordValidFocusSession(session, calendar: calendar, in: context)
        return try #require(try FishProbabilityPresentationStore.snapshot(for: id, wasAlreadyRecorded: existed,
            on: date, calendar: calendar, defaults: defaults, in: context))
    }
}
