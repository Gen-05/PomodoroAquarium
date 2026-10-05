import Foundation

/// 最後にユーザーが選んだUI設定。進行中sessionのカテゴリ保存とは独立。
enum FocusCategorySelectionStore {
    static let storageKey = "lastSelectedFocusCategoryID"

    static func initialID(defaults: UserDefaults, isTutorial: Bool) -> String {
        guard !isTutorial else { return FocusCategoryDefaults.studyID }
        return FocusCategoryDefaults.resolvedCategoryID(defaults.string(forKey: storageKey))
    }

    static func restore(
        to model: TimerViewModel, categories: [FocusCategory], defaults: UserDefaults, isTutorial: Bool
    ) {
        // running/pausedの復元カテゴリは既存sessionのものを優先する。
        guard model.canConfigureSession else { return }
        let id = initialID(defaults: defaults, isTutorial: isTutorial)
        model.selectCategory(FocusCategoryService.resolvedSelectionID(id, from: categories))
    }

    static func select(
        _ categoryID: String, in model: TimerViewModel, categories: [FocusCategory],
        defaults: UserDefaults, isTutorial: Bool
    ) {
        guard model.canConfigureSession else { return }
        let id = isTutorial ? FocusCategoryDefaults.studyID
            : FocusCategoryService.resolvedSelectionID(categoryID, from: categories)
        model.selectCategory(id)
        guard !isTutorial, model.selectedCategoryID == id else { return }
        defaults.set(id, forKey: storageKey)
    }
}
