import XCTest

final class AquariumDecorationStackingUITests: XCTestCase {
    @MainActor
    func testManualOrderSelectionUndoRedoAndCancel() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-core-tutorial-in-memory", "-timerSessionState", "",
            "-hasCompletedOnboarding", "YES", "-hasCompletedCoreTutorial", "YES",
            "-hasSeenAquariumEditorTutorial", "YES"]
        app.launch()
        if app.buttons["aquariumEditor.cancel"].waitForExistence(timeout: 2) {
            app.buttons["aquariumEditor.cancel"].tap()
            app.alerts["編集内容を破棄しますか？"].buttons["変更を破棄"].tap()
        } else {
            XCTAssertTrue(app.buttons["mainTab.aquarium"].waitForExistence(timeout: 10))
            app.buttons["mainTab.aquarium"].tap()
        }
        app.buttons["aquariumEditor.start"].tap()
        XCTAssertTrue(app.alerts["水槽を編集しますか？"].waitForExistence(timeout: 5))
        app.alerts["水槽を編集しますか？"].buttons["編集する"].tap()
        app.buttons["aquariumEditor.category.decoration"].tap()
        app.buttons["岩"].tap()
        let add = app.buttons["aquariumEditor.add.small_rock_a"]
        XCTAssertTrue(add.waitForExistence(timeout: 5)); add.tap()
        let menu = app.buttons["aquariumEditor.stackingMenu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 5))
        menu.tap()
        XCTAssertFalse(app.buttons["一番奥へ"].isEnabled)
        app.buttons["一番手前へ"].tap()
        menu.tap()
        XCTAssertFalse(app.buttons["一番手前へ"].isEnabled)
        app.buttons["1つ奥へ"].tap()
        app.buttons["aquariumEditor.undo"].tap()
        selectRock(app)
        XCTAssertTrue(app.buttons["aquariumEditor.redo"].isEnabled)
        menu.tap()
        XCTAssertFalse(app.buttons["一番手前へ"].isEnabled)
        app.tap() // dismiss the menu without changing order
        app.buttons["aquariumEditor.redo"].tap()
        selectRock(app)
        menu.tap()
        XCTAssertTrue(app.buttons["一番手前へ"].isEnabled)
        app.buttons["一番手前へ"].tap()
        app.buttons["aquariumEditor.openNudge"].tap()
        app.buttons["aquariumEditor.nudge.arrow.left"].tap()
        app.buttons["aquariumEditor.closeNudge"].tap()
        menu.tap()
        XCTAssertFalse(app.buttons["一番手前へ"].isEnabled)
        app.tap()
        app.buttons["aquariumEditor.cancel"].tap()
        app.alerts["編集内容を破棄しますか？"].buttons["変更を破棄"].tap()
        XCTAssertTrue(app.buttons["aquariumEditor.start"].waitForExistence(timeout: 5))
    }
    @MainActor private func selectRock(_ app: XCUIApplication) {
        app.buttons["aquariumEditor.category.decoration"].tap()
        app.buttons["配置済み"].tap()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "aquariumEditor.selectPlaced.developer-owned-small_rock_a")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5)); row.tap()
    }
}
