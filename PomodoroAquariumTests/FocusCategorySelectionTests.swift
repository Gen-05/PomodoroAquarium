import Foundation
import SwiftData
import Testing
@testable import PomodoroAquarium

@MainActor
struct FocusCategorySelectionTests {
    @Test(arguments: [TimerMode.pomodoro, .countdown, .stopwatch])
    func standardCategoryIsRestoredAcrossAllModes(mode: TimerMode) throws {
        let fixture = try SelectionFixture()
        let model = fixture.model()
        model.selectMode(mode)
        fixture.select(FocusCategoryDefaults.readingID, in: model)
        let reopenedDefaults = try #require(UserDefaults(suiteName: fixture.suiteName))
        let relaunched = fixture.model()
        FocusCategorySelectionStore.restore(to: relaunched, categories: fixture.categories,
                                             defaults: reopenedDefaults, isTutorial: false)
        #expect(relaunched.selectedCategoryID == FocusCategoryDefaults.readingID)
        let selected = try #require(fixture.categories.first { $0.id == relaunched.selectedCategoryID })
        #expect(selected.name == "読書")
        #expect(selected.colorKey == .readingCoral)
        relaunched.selectMode(mode)
        #expect(relaunched.selectedCategoryID == selected.id)
    }

    @Test func customCategoryRestoresIDNameColorAndSavedSessionCategory() throws {
        let fixture = try SelectionFixture()
        let custom = FocusCategory(id: UUID().uuidString, name: "数学", color: .oceanTeal,
                                   customHex: "#123ABC", isDefault: false)
        fixture.context.insert(custom)
        try fixture.context.save()
        fixture.categories = try fixture.context.fetch(FetchDescriptor<FocusCategory>())
        fixture.select(custom.id, in: fixture.model())
        // SwiftDataとUserDefaultsの両方を読み直す再起動相当。
        let reopenedContext = ModelContext(fixture.container)
        let categories = try reopenedContext.fetch(FetchDescriptor<FocusCategory>())
        let relaunched = fixture.model()
        let reopenedDefaults = try #require(UserDefaults(suiteName: fixture.suiteName))
        FocusCategorySelectionStore.restore(to: relaunched, categories: categories,
                                             defaults: reopenedDefaults, isTutorial: false)
        let selected = try #require(categories.first { $0.id == relaunched.selectedCategoryID })
        #expect(selected.id == custom.id)
        #expect(selected.name == "数学")
        #expect(selected.colorKey == .oceanTeal)
        #expect(selected.resolvedCustomHex == "#123ABC")
        relaunched.onFocusSessionFinalized = { result in
            do {
                try StudyHistoryService.recordValidFocusSession(result, in: reopenedContext)
                return true
            } catch { Issue.record(error); return false }
        }
        relaunched.selectMode(.stopwatch)
        relaunched.resumeTimer()
        fixture.date = fixture.date.addingTimeInterval(60)
        relaunched.pauseTimer()
        relaunched.endCurrentSession()
        let record = try #require(reopenedContext.fetch(FetchDescriptor<FocusSessionRecord>()).first)
        #expect(record.categoryID == custom.id)
        #expect(record.durationSeconds == 60)
    }

    @Test(arguments: [false, true])
    func archivedOrMissingSelectionFallsBackToStudy(archived: Bool) throws {
        let fixture = try SelectionFixture()
        let id = UUID().uuidString
        if archived {
            let custom = FocusCategory(id: id, name: "数学", color: .oceanTeal,
                                       isDefault: false, isArchived: true)
            fixture.context.insert(custom)
            try fixture.context.save()
            fixture.categories.append(custom)
        }
        fixture.defaults.set(id, forKey: FocusCategorySelectionStore.storageKey)
        let model = fixture.model()
        FocusCategorySelectionStore.restore(to: model, categories: fixture.categories,
                                             defaults: fixture.defaults, isTutorial: false)
        #expect(model.selectedCategoryID == FocusCategoryDefaults.studyID)
        #expect(fixture.categories.first { $0.id == model.selectedCategoryID }?.name == "勉強")
    }

    @Test(arguments: [CoreTutorialMode.production, .preview])
    func tutorialKeepsStudyAndDoesNotOverwriteProductionSelection(mode: CoreTutorialMode) throws {
        let fixture = try SelectionFixture()
        fixture.select(FocusCategoryDefaults.qualificationID, in: fixture.model())
        let coordinator = CoreTutorialCoordinator(mode: mode, defaults: fixture.defaults)
        let isTutorial = coordinator.isActive || coordinator.isPreviewMode
        let model = fixture.model()
        #expect(FocusCategorySelectionStore.initialID(defaults: fixture.defaults, isTutorial: isTutorial)
                == FocusCategoryDefaults.studyID)
        FocusCategorySelectionStore.restore(to: model, categories: fixture.categories,
                                             defaults: fixture.defaults, isTutorial: isTutorial)
        fixture.select(FocusCategoryDefaults.readingID, in: model, isTutorial: isTutorial)
        #expect(model.selectedCategoryID == FocusCategoryDefaults.studyID)
        #expect(fixture.defaults.string(forKey: FocusCategorySelectionStore.storageKey)
                == FocusCategoryDefaults.qualificationID)
        let production = fixture.model()
        FocusCategorySelectionStore.restore(to: production, categories: fixture.categories,
                                             defaults: fixture.defaults, isTutorial: false)
        #expect(production.selectedCategoryID == FocusCategoryDefaults.qualificationID)
    }

    @Test func runningAndPausedSessionCategoryIsNotOverriddenByUISetting() throws {
        let fixture = try SelectionFixture()
        let model = fixture.model()
        model.selectCategory(FocusCategoryDefaults.readingID)
        model.resumeTimer()
        fixture.defaults.set(FocusCategoryDefaults.qualificationID, forKey: FocusCategorySelectionStore.storageKey)
        for paused in [false, true] {
            if paused { model.pauseTimer() }
            FocusCategorySelectionStore.restore(to: model, categories: fixture.categories,
                                                 defaults: fixture.defaults, isTutorial: false)
            fixture.select(FocusCategoryDefaults.studyID, in: model)
            #expect(model.selectedCategoryID == FocusCategoryDefaults.readingID)
            #expect(fixture.defaults.string(forKey: FocusCategorySelectionStore.storageKey)
                    == FocusCategoryDefaults.qualificationID)
        }
    }
}

@MainActor
private final class SelectionFixture {
    let suiteName = "FocusCategorySelection-\(UUID())"
    let defaults: UserDefaults
    let container: ModelContainer
    let context: ModelContext
    var categories: [FocusCategory]
    var date = Date(timeIntervalSinceReferenceDate: 1_000_000)

    init() throws {
        defaults = UserDefaults(suiteName: suiteName)!
        container = try ModelContainer(for: FocusCategory.self, FocusSessionRecord.self, StudyDailyRecord.self,
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        context = ModelContext(container)
        categories = try FocusCategoryService.createDefaultsIfNeeded(in: context)
    }

    func model() -> TimerViewModel {
        TimerViewModel(studyTime: 25, breakTime: 5, now: { self.date },
                       sessionStore: TimerSessionStore(defaults: defaults),
                       notificationService: DisabledTimerNotificationService.shared)
    }

    func select(_ id: String, in model: TimerViewModel, isTutorial: Bool = false) {
        FocusCategorySelectionStore.select(id, in: model, categories: categories,
                                            defaults: defaults, isTutorial: isTutorial)
    }
}
