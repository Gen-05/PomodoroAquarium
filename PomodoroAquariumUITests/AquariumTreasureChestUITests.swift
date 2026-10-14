import XCTest

final class AquariumTreasureChestUITests: XCTestCase {
    @MainActor
    func testDirectionHistoryStorageAndPersistenceOnRealEditor() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        // This test runs on a dedicated simulator; use its persistent store to verify app relaunch.
        app.launchArguments = ["-hasCompletedOnboarding", "YES", "-hasCompletedCoreTutorial", "YES",
            "-hasSeenAquariumEditorTutorial", "YES", "-timerSessionState", ""]
        app.launch()
        XCTAssertTrue(app.buttons["home.startStudy"].waitForExistence(timeout: 10))
        app.buttons["mainTab.aquarium"].tap()
        startEditing(app)
        addChest(app)
        let direction = app.buttons["aquariumEditor.changeTreasureChestDirection"]
        XCTAssertTrue(direction.waitForExistence(timeout: 5))
        XCTAssertEqual(direction.value as? String, "右側面")
        direction.tap()
        XCTAssertEqual(direction.value as? String, "左側面")
        app.buttons["aquariumEditor.undo"].tap()
        reselectChest(app)
        XCTAssertEqual(direction.value as? String, "右側面")
        app.buttons["aquariumEditor.redo"].tap()
        reselectChest(app)
        XCTAssertEqual(direction.value as? String, "左側面")
        app.buttons["aquariumEditor.openNudge"].tap()
        app.buttons["aquariumEditor.nudge.arrow.left"].tap()
        app.buttons["aquariumEditor.closeNudge"].tap()
        let chest = app.descendants(matching: .any).matching(NSPredicate(format:
            "identifier BEGINSWITH %@", "aquariumEditor.placedDecoration.developer-owned-treasure_chest")).firstMatch
        let canvas = app.descendants(matching: .any)["aquariumEditor.decorationCanvas"]
        chest.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.78))
            .press(forDuration: 0.15, thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.80)))
        XCTAssertTrue(direction.waitForExistence(timeout: 5))
        keepScreenshot(app, "treasure-chest-left-editor")
        app.buttons["aquariumEditor.removeSelectedDecoration"].tap()
        XCTAssertFalse(direction.exists)
        addChest(app)
        XCTAssertEqual(direction.value as? String, "左側面")
        app.buttons["aquariumEditor.done"].tap()
        XCTAssertTrue(app.buttons["保存する"].waitForExistence(timeout: 5))
        app.buttons["保存する"].tap()
        XCTAssertTrue(app.buttons["aquariumEditor.start"].waitForExistence(timeout: 5))
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["home.startStudy"].waitForExistence(timeout: 10))
        app.buttons["mainTab.aquarium"].tap()
        XCTAssertTrue(chest.waitForExistence(timeout: 5))
        XCTAssertEqual(chest.value as? String, "左側面")
        keepScreenshot(app, "treasure-chest-left-relaunched")
        startEditing(app)
        addChest(app)
        XCTAssertEqual(direction.value as? String, "右側面")
        app.buttons["aquariumEditor.done"].tap()
        app.buttons["保存する"].tap()
        XCTAssertTrue(app.buttons["aquariumEditor.start"].waitForExistence(timeout: 5))
        keepScreenshot(app, "treasure-chest-two-directions")
    }

    @MainActor
    private func startEditing(_ app: XCUIApplication) {
        app.buttons["aquariumEditor.start"].tap()
        let alert = app.alerts["水槽を編集しますか？"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5)); alert.buttons["編集する"].tap()
        XCTAssertTrue(app.buttons["aquariumEditor.category.decoration"].waitForExistence(timeout: 5))
    }
    @MainActor
    private func addChest(_ app: XCUIApplication) {
        app.buttons["aquariumEditor.category.decoration"].tap()
        app.buttons["その他"].tap()
        app.buttons["追加する"].tap()
        let add = app.buttons["aquariumEditor.add.treasure_chest"]
        XCTAssertTrue(add.waitForExistence(timeout: 5)); add.tap()
    }
    @MainActor
    private func reselectChest(_ app: XCUIApplication) {
        app.buttons["aquariumEditor.category.decoration"].tap()
        app.buttons["その他"].tap()
        app.buttons["配置済み"].tap()
        let placed = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@",
            "aquariumEditor.selectPlaced.developer-owned-treasure_chest")).firstMatch
        XCTAssertTrue(placed.waitForExistence(timeout: 5)); placed.tap()
    }
    @MainActor
    private func keepScreenshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
