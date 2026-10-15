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
        let prefix = "aquariumEditor.placedDecoration."
        let first = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix + "developer-owned-small_rock_a")).firstMatch
        let firstID = first.identifier
        let nudge = app.buttons["aquariumEditor.openNudge"]
        XCTAssertTrue(nudge.waitForExistence(timeout: 5))
        let basicFrame = nudge.frame
        tapPadding(nudge)
        let nudgeFrame = app.buttons["aquariumEditor.closeNudge"].frame
        tapPadding(app.buttons["aquariumEditor.closeNudge"])
        let menu = app.buttons["aquariumEditor.stackingMenu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 5))
        tapPadding(menu)
        for title in ["一番手前へ", "1つ手前へ", "1つ奥へ", "一番奥へ"] { XCTAssertFalse(app.buttons[title].isEnabled) }
        tapPadding(app.buttons["aquariumEditor.closeStacking"])
        app.buttons["aquariumEditor.category.decoration"].tap()
        add.tap()
        let second = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@ AND identifier != %@", prefix + "developer-owned-small_rock_a", firstID)).firstMatch
        XCTAssertTrue(second.waitForExistence(timeout: 5))
        let fixedFirst = app.descendants(matching: .any).matching(identifier: firstID).firstMatch
        second.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7)).press(forDuration: 0.15,
            thenDragTo: fixedFirst.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7)))
        // Add a third overlapping rock, so repeated one-step moves each change order.
        let secondID = second.identifier
        app.buttons["aquariumEditor.category.decoration"].tap()
        add.tap()
        let third = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@ AND identifier != %@ AND identifier != %@", prefix + "developer-owned-small_rock_a", firstID, secondID)).firstMatch
        XCTAssertTrue(third.waitForExistence(timeout: 5))
        third.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7)).press(forDuration: 0.15,
            thenDragTo: fixedFirst.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7)))
        tapPadding(menu)
        let forward = app.buttons["aquariumEditor.stacking.forward"]
        let backward = app.buttons["aquariumEditor.stacking.backward"]
        let close = app.buttons["aquariumEditor.closeStacking"]
        XCTAssertFalse(app.buttons["一番奥へ"].isEnabled)
        tapPadding(forward)
        XCTAssertTrue(close.exists && forward.isEnabled)
        tapPadding(forward)
        XCTAssertTrue(close.exists)
        XCTAssertFalse(forward.isEnabled)
        tapPadding(backward)
        XCTAssertTrue(close.exists && backward.isEnabled)
        tapPadding(backward)
        XCTAssertFalse(backward.isEnabled)
        app.buttons["aquariumEditor.undo"].tap()
        XCTAssertTrue(close.exists && backward.isEnabled && forward.isEnabled)
        app.buttons["aquariumEditor.redo"].tap()
        XCTAssertTrue(close.exists && !backward.isEnabled)
        tapPadding(app.buttons["一番手前へ"])
        XCTAssertTrue(close.exists && !forward.isEnabled)
        // All three modes share the same middle-water container.
        XCTAssertEqual(close.frame.midY, basicFrame.midY, accuracy: 1)
        XCTAssertGreaterThan(close.frame.minY, app.buttons["aquariumEditor.undo"].frame.maxY)
        XCTAssertGreaterThan(close.frame.minX, 0)
        XCTAssertLessThan(close.frame.maxX, app.frame.width)
        XCTAssertLessThan(close.frame.maxY, fixedFirst.frame.minY)
        XCTAssertEqual(close.frame.midY, nudgeFrame.midY, accuracy: 1)
        XCTAssertEqual(close.frame.height, nudgeFrame.height, accuracy: 1)
        XCTAssertFalse(menu.exists)
        XCTAssertFalse(app.buttons["aquariumEditor.closeNudge"].exists)
        XCTAssertLessThan(app.buttons["aquariumEditor.stacking.back"].frame.minX, backward.frame.minX)
        XCTAssertLessThan(backward.frame.minX, forward.frame.minX)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Persistent stacking toolbar"
        screenshot.lifetime = .keepAlways
        self.add(screenshot)
        tapPadding(close)
        tapPadding(app.buttons["aquariumEditor.openNudge"])
        let fixedNudgeFrame = app.buttons["aquariumEditor.closeNudge"].frame
        for direction in ["up", "down", "right", "left"] {
            tapPadding(app.buttons["aquariumEditor.nudge.arrow." + direction])
            XCTAssertEqual(app.buttons["aquariumEditor.closeNudge"].frame, fixedNudgeFrame)
        }
        for _ in 0..<5 { tapPadding(app.buttons["aquariumEditor.nudge.arrow.left"]) }
        XCTAssertEqual(app.buttons["aquariumEditor.closeNudge"].frame, fixedNudgeFrame)
        tapPadding(app.buttons["aquariumEditor.closeNudge"])
        tapPadding(menu)
        XCTAssertFalse(app.buttons["一番手前へ"].isEnabled)
        tapPadding(app.buttons["aquariumEditor.closeStacking"])
        // Storage also responds in the clear corner of its allocated label.
        let removal = app.buttons["aquariumEditor.removeSelectedDecoration"]
        tapPadding(removal)
        XCTAssertFalse(removal.exists)
        XCTAssertFalse(third.exists)
        selectRock(app, id: String(secondID.dropFirst(prefix.count)))
        // Transparent space outside the controls still reaches the aquarium.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.55)).tap()
        XCTAssertFalse(app.buttons["aquariumEditor.openNudge"].exists)
        app.buttons["aquariumEditor.cancel"].tap()
        app.alerts["編集内容を破棄しますか？"].buttons["変更を破棄"].tap()
        XCTAssertTrue(app.buttons["aquariumEditor.start"].waitForExistence(timeout: 5))
    }
    @MainActor private func tapPadding(_ button: XCUIElement) {
        XCTAssertGreaterThanOrEqual(button.frame.height, 50)
        XCTAssertGreaterThanOrEqual(button.frame.width, 44)
        button.coordinate(withNormalizedOffset: CGVector(dx: 0.10, dy: 0.12)).tap()
    }
    @MainActor private func selectRock(_ app: XCUIApplication, id: String) {
        app.buttons["aquariumEditor.category.decoration"].tap()
        app.buttons["配置済み"].tap()
        let row = app.buttons["aquariumEditor.selectPlaced." + id]
        XCTAssertTrue(row.waitForExistence(timeout: 5)); row.tap()
    }
}
