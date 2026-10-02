import Foundation
import Testing
@testable import PomodoroAquarium

@MainActor
struct HomeStartPresentationTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return calendar
    }

    @Test func sameLocalDayAlwaysSelectsTheSameMessage() throws {
        let morning = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 1, hour: 0)))
        let evening = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 1, hour: 23, minute: 59)))
        #expect(HomeDailyMessage.message(on: morning, calendar: calendar) == HomeDailyMessage.message(on: evening, calendar: calendar))
        #expect(HomeDailyMessage.message(on: morning, calendar: calendar) == HomeDailyMessage.message(on: morning, calendar: calendar))
        #expect(HomeDailyMessage.messages.count == 25)
        #expect(Set(HomeDailyMessage.messages).count == HomeDailyMessage.messages.count)
    }

    @Test func nextDayChoosesAnotherCandidateAcrossMonthAndYearBoundaries() throws {
        for components in [
            DateComponents(year: 2026, month: 9, day: 30),
            DateComponents(year: 2026, month: 12, day: 31),
            DateComponents(year: 2024, month: 2, day: 28),
            DateComponents(year: 2000, month: 12, day: 30)
        ] {
            let date = try #require(calendar.date(from: components))
            let nextDay = try #require(calendar.date(byAdding: .day, value: 1, to: date))
            #expect(HomeDailyMessage.message(on: date, calendar: calendar) != HomeDailyMessage.message(on: nextDay, calendar: calendar))
        }
    }

    @Test func oneTapProducesOneNavigationAndRepeatedTapsCannotDuplicateIt() throws {
        var state = HomeStartTransitionState()
        let alreadyPresented = state.begin(isDestinationPresented: true)
        #expect(alreadyPresented == nil)
        let firstRequest = state.begin(isDestinationPresented: false)
        let id = try #require(firstRequest)
        let repeatedRequest = state.begin(isDestinationPresented: false)
        #expect(repeatedRequest == nil)
        let firstNavigation = state.consume(id: id)
        #expect(firstNavigation)
        let repeatedNavigation = state.consume(id: id)
        #expect(!repeatedNavigation)
        let requestBeforeReset = state.begin(isDestinationPresented: false)
        #expect(requestBeforeReset == nil)
        state.reset()
        let nextRequest = state.begin(isDestinationPresented: false)
        let nextID = try #require(nextRequest)
        let staleNavigation = state.consume(id: id)
        #expect(!staleNavigation)
        state.reset()
        let cancelledNavigation = state.consume(id: nextID)
        #expect(!cancelledNavigation)
        #expect(!state.isOpening)
        #expect(state.requestID == nil)
    }
}
