import Foundation
import SwiftData
import Testing
@testable import PomodoroAquarium

@MainActor
struct FocusCategoryTests {
    @Test func defaultCategoriesAreCreatedWithStableColors() throws {
        let container = try makeContainer()

        let categories = try FocusCategoryService.createDefaultsIfNeeded(
            in: container.mainContext
        )

        #expect(categories.map(\.id) == [
            FocusCategoryDefaults.studyID,
            FocusCategoryDefaults.readingID
        ])
        #expect(categories.map(\.name) == ["勉強", "読書"])
        #expect(categories.map(\.colorKey) == [.studyBlue, .readingCoral])
        #expect(categories.map(\.isDefault) == [true, true])
    }

    @Test func creatingDefaultsRepeatedlyDoesNotDuplicateThem() throws {
        let container = try makeContainer()

        try FocusCategoryService.createDefaultsIfNeeded(in: container.mainContext)
        try FocusCategoryService.createDefaultsIfNeeded(in: container.mainContext)

        let categories = try container.mainContext.fetch(FetchDescriptor<FocusCategory>())
        #expect(categories.count == 2)
        #expect(Set(categories.map(\.id)).count == 2)
    }

    @Test func completedSessionStoresSelectedCategoryID() throws {
        let container = try makeContainer()
        let completedAt = Date(timeIntervalSince1970: 1_800_000_000)

        try StudyHistoryService.addStudyMinutes(
            25,
            on: completedAt,
            categoryID: FocusCategoryDefaults.readingID,
            in: container.mainContext
        )

        let sessions = try container.mainContext.fetch(FetchDescriptor<FocusSessionRecord>())
        #expect(sessions.count == 1)
        #expect(sessions.first?.durationMinutes == 25)
        #expect(sessions.first?.completedAt == completedAt)
        #expect(sessions.first?.resolvedCategoryID == FocusCategoryDefaults.readingID)
    }

    @Test func missingLegacyCategoryFallsBackToStudy() {
        let legacyRecord = FocusSessionRecord(
            completedAt: Date(),
            durationMinutes: 25,
            categoryID: nil
        )

        #expect(legacyRecord.resolvedCategoryID == FocusCategoryDefaults.studyID)
        #expect(FocusCategoryDefaults.resolvedCategoryID(nil) == FocusCategoryDefaults.studyID)
    }

    @Test func legacyDailyHistoryIsMigratedToStudyOnce() throws {
        let container = try makeContainer()
        let legacyDay = Date(timeIntervalSince1970: 1_700_000_000)
        container.mainContext.insert(StudyDailyRecord(
            day: legacyDay,
            studyMinutes: 40,
            categoryHistoryMigratedAt: nil
        ))
        try container.mainContext.save()

        try FocusSessionHistoryMigration.migrateLegacyDailyRecordsIfNeeded(
            in: container.mainContext
        )
        try FocusSessionHistoryMigration.migrateLegacyDailyRecordsIfNeeded(
            in: container.mainContext
        )

        let sessions = try container.mainContext.fetch(FetchDescriptor<FocusSessionRecord>())
        #expect(sessions.count == 1)
        #expect(sessions.first?.durationMinutes == 40)
        #expect(sessions.first?.resolvedCategoryID == FocusCategoryDefaults.studyID)
    }

    @Test func selectedCategoryIsPersistedWhenSessionStarts() throws {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = TimerSessionStore(defaults: defaults, processIdentifier: "focus-category")
        let viewModel = TimerViewModel(
            studyTime: 25,
            breakTime: 5,
            now: Date.init,
            sessionStore: store,
            notificationService: DisabledTimerNotificationService.shared
        )

        viewModel.selectCategory(FocusCategoryDefaults.readingID)
        viewModel.resumeTimer()

        #expect(store.load()?.selectedCategoryID == FocusCategoryDefaults.readingID)
    }

    @Test func coreTutorialAlwaysUsesStudyCategory() throws {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let viewModel = TimerViewModel(
            studyTime: 25,
            breakTime: 5,
            now: Date.init,
            sessionStore: TimerSessionStore(
                defaults: defaults,
                processIdentifier: "focus-category-tutorial"
            ),
            notificationService: DisabledTimerNotificationService.shared
        )
        viewModel.selectCategory(FocusCategoryDefaults.readingID)

        #expect(viewModel.completeCoreTutorialStudyWithoutStartingSession())
        #expect(viewModel.selectedCategoryID == FocusCategoryDefaults.studyID)
    }

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: FocusCategory.self, FocusSessionRecord.self, StudyDailyRecord.self,
            configurations: configuration
        )
    }

    private func makeDefaults() -> (UserDefaults, String) {
        let suiteName = "FocusCategoryTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }
}
