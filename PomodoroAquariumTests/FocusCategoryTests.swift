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
            FocusCategoryDefaults.readingID,
            FocusCategoryDefaults.qualificationID,
            FocusCategoryDefaults.testStudyID,
            FocusCategoryDefaults.assignmentID,
            FocusCategoryDefaults.languageID
        ])
        #expect(categories.map(\.name) == [
            "勉強", "読書", "資格勉強", "テスト勉強", "課題", "語学"
        ])
        #expect(categories.map(\.colorKey) == [
            .studyBlue,
            .readingCoral,
            .qualificationPurple,
            .testAmber,
            .assignmentMint,
            .languagePink
        ])
        #expect(categories.allSatisfy { $0.isDefault })
        #expect(categories.allSatisfy { $0.resolvedCustomHex == nil })
        #expect(categories.allSatisfy { !$0.isArchived })
    }

    @Test func creatingDefaultsRepeatedlyDoesNotDuplicateThem() throws {
        let container = try makeContainer()

        try FocusCategoryService.createDefaultsIfNeeded(in: container.mainContext)
        try FocusCategoryService.createDefaultsIfNeeded(in: container.mainContext)

        let categories = try container.mainContext.fetch(FetchDescriptor<FocusCategory>())
        #expect(categories.count == 6)
        #expect(Set(categories.map(\.id)).count == 6)
    }

    @Test func existingDefaultsArePreservedAndOnlyMissingDefaultsAreAdded() throws {
        let container = try makeContainer()
        let existingStudy = FocusCategory(
            id: FocusCategoryDefaults.studyID,
            name: "勉強",
            color: .oceanTeal,
            isDefault: true
        )
        let existingReading = FocusCategory(
            id: FocusCategoryDefaults.readingID,
            name: "読書",
            color: .readingCoral,
            isDefault: true
        )
        container.mainContext.insert(existingStudy)
        container.mainContext.insert(existingReading)
        try container.mainContext.save()

        let categories = try FocusCategoryService.createDefaultsIfNeeded(
            in: container.mainContext
        )

        #expect(categories.count == 6)
        #expect(categories.first { $0.id == FocusCategoryDefaults.studyID }?.colorKey == .oceanTeal)
        #expect(categories.filter { $0.name == "勉強" }.count == 1)
        #expect(categories.filter { $0.name == "読書" }.count == 1)
        #expect(Set(categories.map(\.id)).isSuperset(of: [
            FocusCategoryDefaults.qualificationID,
            FocusCategoryDefaults.testStudyID,
            FocusCategoryDefaults.assignmentID,
            FocusCategoryDefaults.languageID
        ]))
    }

    @Test func customCategoryIsTrimmedSavedAndNotDefault() throws {
        let container = try makeContainer()

        let category = try FocusCategoryService.createCustom(
            name: "  数学  ",
            color: .skyIndigo,
            in: container.mainContext
        )

        let categories = try container.mainContext.fetch(FetchDescriptor<FocusCategory>())
        #expect(category.name == "数学")
        #expect(category.colorKey == .skyIndigo)
        #expect(!category.isDefault)
        #expect(categories.contains { $0.id == category.id })
    }

    @Test func customHexColorIsNormalizedAndSaved() throws {
        let container = try makeContainer()

        let category = try FocusCategoryService.createCustom(
            name: "英語",
            customHex: "4aa8ff",
            in: container.mainContext
        )

        let saved = try #require(
            container.mainContext.fetch(FetchDescriptor<FocusCategory>()).first
        )
        #expect(category.resolvedCustomHex == "#4AA8FF")
        #expect(saved.resolvedCustomHex == "#4AA8FF")
        #expect(!saved.isDefault)
    }

    @Test func customHexColorPersistsAfterReopeningTheStore() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FocusCategoryHexTests.\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let configuration = ModelConfiguration(
            url: directory.appendingPathComponent("FocusCategory.store")
        )

        do {
            let container = try ModelContainer(
                for: FocusCategory.self,
                configurations: configuration
            )
            _ = try FocusCategoryService.createCustom(
                name: "プログラミング",
                customHex: "#12B886",
                in: container.mainContext
            )
        }

        let reopened = try ModelContainer(
            for: FocusCategory.self,
            configurations: configuration
        )
        let categories = try reopened.mainContext.fetch(FetchDescriptor<FocusCategory>())
        let category = try #require(categories.first { $0.name == "プログラミング" })
        #expect(category.resolvedCustomHex == "#12B886")
    }

    @Test func archivingCustomCategoryKeepsPastRecordResolvable() throws {
        let container = try makeContainer()
        let category = try FocusCategoryService.createCustom(
            name: "数学",
            customHex: "#4AA8FF",
            in: container.mainContext
        )
        container.mainContext.insert(FocusSessionRecord(
            completedAt: Date(timeIntervalSince1970: 1_800_000_000),
            durationMinutes: 25,
            categoryID: category.id
        ))
        try container.mainContext.save()

        try FocusCategoryService.archive(category, in: container.mainContext)

        let categories = try container.mainContext.fetch(FetchDescriptor<FocusCategory>())
        let records = try container.mainContext.fetch(FetchDescriptor<FocusSessionRecord>())
        let archived = try #require(categories.first { $0.id == category.id })
        let record = try #require(records.first)
        #expect(archived.isArchived)
        #expect(!FocusCategoryService.activeOrdered(categories).contains { $0.id == category.id })
        #expect(record.resolvedCategoryID == category.id)
        #expect(categories.contains { $0.id == record.resolvedCategoryID })
        #expect(archived.name == "数学")
        #expect(archived.resolvedCustomHex == "#4AA8FF")
    }

    @Test func defaultCategoryCannotBeArchived() throws {
        let container = try makeContainer()
        let categories = try FocusCategoryService.createDefaultsIfNeeded(
            in: container.mainContext
        )
        let study = try #require(
            categories.first { $0.id == FocusCategoryDefaults.studyID }
        )

        do {
            try FocusCategoryService.archive(study, in: container.mainContext)
            Issue.record("初期カテゴリがアーカイブされました")
        } catch let error as FocusCategoryService.ArchiveError {
            #expect(error == .defaultCategory)
        }

        #expect(!study.isArchived)
    }

    @Test func archivedSelectedCategoryFallsBackToStudy() throws {
        let container = try makeContainer()
        let category = try FocusCategoryService.createCustom(
            name: "数学",
            customHex: "#4AA8FF",
            in: container.mainContext
        )
        try FocusCategoryService.createDefaultsIfNeeded(in: container.mainContext)
        var categories = try container.mainContext.fetch(FetchDescriptor<FocusCategory>())
        #expect(FocusCategoryService.resolvedSelectionID(category.id, from: categories) == category.id)

        try FocusCategoryService.archive(category, in: container.mainContext)
        categories = try container.mainContext.fetch(FetchDescriptor<FocusCategory>())

        #expect(
            FocusCategoryService.resolvedSelectionID(category.id, from: categories)
                == FocusCategoryDefaults.studyID
        )
    }

    @Test func recreatingArchivedCategoryRestoresSameRecordWithNewColor() throws {
        let container = try makeContainer()
        let original = try FocusCategoryService.createCustom(
            name: "数学",
            customHex: "#4AA8FF",
            in: container.mainContext
        )
        let originalID = original.id
        try FocusCategoryService.archive(original, in: container.mainContext)

        let restored = try FocusCategoryService.createCustom(
            name: "  数学  ",
            customHex: "#FF7A45",
            in: container.mainContext
        )
        let categories = try container.mainContext.fetch(FetchDescriptor<FocusCategory>())

        #expect(restored.id == originalID)
        #expect(!restored.isArchived)
        #expect(restored.resolvedCustomHex == "#FF7A45")
        #expect(categories.filter { $0.name == "数学" }.count == 1)
    }

    @Test func archivedStatePersistsAfterReopeningTheStore() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FocusCategoryArchiveTests.\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let configuration = ModelConfiguration(
            url: directory.appendingPathComponent("FocusCategory.store")
        )
        var categoryID = ""

        do {
            let container = try ModelContainer(
                for: FocusCategory.self,
                configurations: configuration
            )
            let category = try FocusCategoryService.createCustom(
                name: "数学",
                customHex: "#4AA8FF",
                in: container.mainContext
            )
            categoryID = category.id
            try FocusCategoryService.archive(category, in: container.mainContext)
        }

        let reopened = try ModelContainer(
            for: FocusCategory.self,
            configurations: configuration
        )
        let categories = try reopened.mainContext.fetch(FetchDescriptor<FocusCategory>())
        let category = try #require(categories.first { $0.id == categoryID })
        #expect(category.isArchived)
        #expect(FocusCategoryService.activeOrdered(categories).isEmpty)
    }

    @Test func duplicateCustomCategoryNameIsRejected() throws {
        let container = try makeContainer()
        _ = try FocusCategoryService.createCustom(
            name: "数学",
            color: .skyIndigo,
            in: container.mainContext
        )

        do {
            _ = try FocusCategoryService.createCustom(
                name: "  数学 ",
                color: .sunsetOrange,
                in: container.mainContext
            )
            Issue.record("同名カテゴリが保存されました")
        } catch let error as FocusCategoryService.CreationError {
            #expect(error == .duplicateName)
        }

        let categories = try container.mainContext.fetch(FetchDescriptor<FocusCategory>())
        #expect(categories.filter { $0.name == "数学" }.count == 1)
    }

    @Test func emptyAndOverlongCustomCategoryNamesAreRejected() throws {
        let container = try makeContainer()

        do {
            _ = try FocusCategoryService.createCustom(
                name: "   \n",
                color: .oceanTeal,
                in: container.mainContext
            )
            Issue.record("空のカテゴリ名が保存されました")
        } catch let error as FocusCategoryService.CreationError {
            #expect(error == .emptyName)
        }

        do {
            _ = try FocusCategoryService.createCustom(
                name: String(repeating: "あ", count: FocusCategoryService.maximumNameLength + 1),
                color: .oceanTeal,
                in: container.mainContext
            )
            Issue.record("文字数上限を超えたカテゴリ名が保存されました")
        } catch let error as FocusCategoryService.CreationError {
            #expect(error == .nameTooLong)
        }
    }

    @Test func defaultCreationDoesNotDuplicateAnExistingCategoryWithTheSameName() throws {
        let container = try makeContainer()
        container.mainContext.insert(FocusCategory(
            id: "focus-category.custom.existing-qualification",
            name: "資格勉強",
            color: .aquaCyan,
            isDefault: false
        ))
        try container.mainContext.save()

        let categories = try FocusCategoryService.createDefaultsIfNeeded(
            in: container.mainContext
        )

        #expect(categories.filter { $0.name == "資格勉強" }.count == 1)
        #expect(!categories.contains { $0.id == FocusCategoryDefaults.qualificationID })
    }

    @Test func completedSessionStoresSelectedCategoryID() throws {
        let container = try makeContainer()
        let completedAt = Date(timeIntervalSince1970: 1_800_000_000)

        try StudyHistoryService.addStudyMinutes(
            25,
            on: completedAt,
            categoryID: FocusCategoryDefaults.readingID,
            focusMethod: .timer,
            in: container.mainContext
        )

        let sessions = try container.mainContext.fetch(FetchDescriptor<FocusSessionRecord>())
        #expect(sessions.count == 1)
        #expect(sessions.first?.durationMinutes == 25)
        #expect(sessions.first?.completedAt == completedAt)
        #expect(sessions.first?.resolvedCategoryID == FocusCategoryDefaults.readingID)
        #expect(sessions.first?.focusMethod == .timer)
    }

    @Test func missingLegacyCategoryFallsBackToStudy() {
        let legacyRecord = FocusSessionRecord(
            completedAt: Date(),
            durationMinutes: 25,
            categoryID: nil
        )

        #expect(legacyRecord.resolvedCategoryID == FocusCategoryDefaults.studyID)
        #expect(FocusCategoryDefaults.resolvedCategoryID(nil) == FocusCategoryDefaults.studyID)
        #expect(legacyRecord.focusMethod == .legacy)
    }

    @Test func completedSessionsPersistEachFocusMethod() throws {
        let container = try makeContainer()
        let methods: [FocusMethod] = [.pomodoro, .timer, .stopwatch]

        for (offset, method) in methods.enumerated() {
            try StudyHistoryService.addStudyMinutes(
                25,
                on: Date(timeIntervalSince1970: 1_800_000_000 + Double(offset * 86_400)),
                categoryID: FocusCategoryDefaults.studyID,
                focusMethod: method,
                in: container.mainContext
            )
        }

        let sessions = try container.mainContext.fetch(
            FetchDescriptor<FocusSessionRecord>(sortBy: [SortDescriptor(\.completedAt)])
        )
        #expect(sessions.map(\.focusMethod) == methods)
        #expect(sessions.allSatisfy { $0.resolvedCategoryID == FocusCategoryDefaults.studyID })
        #expect(TimerMode.pomodoro.focusMethod == .pomodoro)
        #expect(TimerMode.countdown.focusMethod == .timer)
        #expect(TimerMode.stopwatch.focusMethod == .stopwatch)
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
        #expect(sessions.first?.focusMethod == .pomodoro)
    }

    @Test func legacyFocusMethodsAreMigratedToPomodoroWithoutChangingSessionData() throws {
        let container = try makeContainer()
        let nilDate = Date(timeIntervalSince1970: 1_700_000_000)
        let emptyDate = Date(timeIntervalSince1970: 1_700_086_400)
        let legacyDate = Date(timeIntervalSince1970: 1_700_172_800)
        let nilMethod = FocusSessionRecord(
            completedAt: nilDate,
            durationMinutes: 400,
            categoryID: FocusCategoryDefaults.readingID
        )
        let emptyMethod = FocusSessionRecord(
            completedAt: emptyDate,
            durationMinutes: 30,
            categoryID: "custom-math"
        )
        emptyMethod.focusMethodRawValue = ""
        let explicitLegacy = FocusSessionRecord(
            completedAt: legacyDate,
            durationMinutes: 23,
            categoryID: FocusCategoryDefaults.studyID,
            focusMethod: .legacy
        )
        let pomodoro = FocusSessionRecord(
            completedAt: Date(timeIntervalSince1970: 1_700_259_200),
            durationMinutes: 25,
            focusMethod: .pomodoro
        )
        let timer = FocusSessionRecord(
            completedAt: Date(timeIntervalSince1970: 1_700_345_600),
            durationMinutes: 40,
            focusMethod: .timer
        )
        let stopwatch = FocusSessionRecord(
            completedAt: Date(timeIntervalSince1970: 1_700_432_000),
            durationMinutes: 15,
            focusMethod: .stopwatch
        )
        let records = [nilMethod, emptyMethod, explicitLegacy, pomodoro, timer, stopwatch]
        records.forEach(container.mainContext.insert)
        try container.mainContext.save()

        let originalIDs = Set(records.map(\.id))
        let originalTotal = records.reduce(0) { $0 + $1.durationMinutes }
        let firstResult = try FocusSessionHistoryMigration
            .migrateLegacyFocusMethodsToPomodoroIfNeeded(in: container.mainContext)
        let secondResult = try FocusSessionHistoryMigration
            .migrateLegacyFocusMethodsToPomodoroIfNeeded(in: container.mainContext)
        let migrated = try container.mainContext.fetch(
            FetchDescriptor<FocusSessionRecord>(sortBy: [SortDescriptor(\.completedAt)])
        )

        #expect(firstResult.legacyRecordCount == 3)
        #expect(firstResult.migratedRecordCount == 3)
        #expect(firstResult.migratedMinutes == 453)
        #expect(firstResult.totalMinutesBefore == originalTotal)
        #expect(firstResult.totalMinutesAfter == originalTotal)
        #expect(secondResult.legacyRecordCount == 0)
        #expect(secondResult.migratedRecordCount == 0)
        #expect(secondResult.migratedMinutes == 0)
        #expect(Set(migrated.map(\.id)) == originalIDs)
        #expect(migrated.count == records.count)
        #expect(migrated.map(\.focusMethod) == [
            .pomodoro, .pomodoro, .pomodoro, .pomodoro, .timer, .stopwatch
        ])
        #expect(migrated[0].completedAt == nilDate)
        #expect(migrated[0].durationMinutes == 400)
        #expect(migrated[0].categoryID == FocusCategoryDefaults.readingID)
        #expect(migrated[1].completedAt == emptyDate)
        #expect(migrated[1].durationMinutes == 30)
        #expect(migrated[1].categoryID == "custom-math")
        #expect(migrated[2].completedAt == legacyDate)
        #expect(migrated[2].durationMinutes == 23)
        #expect(migrated[2].categoryID == FocusCategoryDefaults.studyID)
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

    @Test func customCategoryIDIsPersistedWhenSessionStarts() throws {
        let container = try makeContainer()
        let category = try FocusCategoryService.createCustom(
            name: "プログラミング",
            color: .oceanTeal,
            in: container.mainContext
        )
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = TimerSessionStore(defaults: defaults, processIdentifier: "custom-category")
        let viewModel = TimerViewModel(
            studyTime: 25,
            breakTime: 5,
            now: Date.init,
            sessionStore: store,
            notificationService: DisabledTimerNotificationService.shared
        )

        viewModel.selectCategory(category.id)
        viewModel.resumeTimer()

        #expect(store.load()?.selectedCategoryID == category.id)
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
