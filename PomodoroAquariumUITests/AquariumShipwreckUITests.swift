import XCTest

final class AquariumShipwreckUITests: XCTestCase {
    @MainActor func testSixPresentationsOneShipUndoStorageAndCancel() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-core-tutorial-in-memory", "-timerSessionState", "", "-hasCompletedOnboarding", "YES",
            "-hasCompletedCoreTutorial", "YES", "-hasSeenAquariumEditorTutorial", "YES"]
        app.launch()
        if app.buttons["aquariumEditor.cancel"].waitForExistence(timeout: 2) {
            app.buttons["aquariumEditor.cancel"].tap()
            app.alerts["編集内容を破棄しますか？"].buttons["変更を破棄"].tap()
        } else {
            XCTAssertTrue(app.buttons["mainTab.aquarium"].waitForExistence(timeout: 10))
            app.buttons["mainTab.aquarium"].tap()
        }
        app.buttons["aquariumEditor.start"].tap()
        app.alerts["水槽を編集しますか？"].buttons["編集する"].tap()
        let ship = app.descendants(matching: .any).matching(identifier: "aquarium.shipwreck").firstMatch
        for theme in ["ベーシック海底", "サンゴ礁", "深い海"] {
            app.buttons["aquariumEditor.category.background"].tap()
            app.buttons[theme].tap()
            app.buttons["aquariumEditor.category.decoration"].tap()
            app.buttons.matching(NSPredicate(format: "label == %@ AND identifier != %@", "その他", "mainTab.more")).firstMatch.tap()
            let add = app.buttons["aquariumEditor.add.shipwreck_distant"]
            XCTAssertTrue(add.waitForExistence(timeout: 5)); add.tap()
            app.buttons["左奥"].tap()
            XCTAssertTrue(ship.waitForExistence(timeout: 5))
            XCTAssertEqual(ship.value as? String, "左奥")
            XCTAssertFalse(app.buttons["aquariumEditor.openNudge"].exists)
            XCTAssertFalse(app.buttons["aquariumEditor.stackingMenu"].exists)
            capture(app, name: theme + "・左奥")
            app.buttons["aquariumEditor.shipwreck.right"].tap()
            XCTAssertEqual(ship.value as? String, "右奥")
            app.buttons["aquariumEditor.undo"].tap()
            XCTAssertEqual(ship.value as? String, "左奥")
            app.buttons["aquariumEditor.redo"].tap()
            XCTAssertEqual(ship.value as? String, "右奥")
            capture(app, name: theme + "・右奥")
        }
        // The existing atomic draft file restores the slot and its history after termination.
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["aquariumEditor.cancel"].waitForExistence(timeout: 10))
        XCTAssertTrue(ship.waitForExistence(timeout: 5))
        XCTAssertEqual(ship.value as? String, "右奥")
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "aquarium.shipwreck").count, 1)
        XCTAssertFalse(app.buttons["aquariumEditor.closeLibrary"].exists)
        app.buttons["aquariumEditor.undo"].tap()
        XCTAssertEqual(ship.value as? String, "左奥")
        app.buttons["aquariumEditor.redo"].tap()
        XCTAssertEqual(ship.value as? String, "右奥")
        // Reopen placed list after history restored the selection-free state.
        app.buttons["aquariumEditor.category.decoration"].tap()
        app.buttons["配置済み"].tap()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "aquariumEditor.selectPlaced.developer-owned-shipwreck_distant")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5)); row.tap()
        app.buttons["aquariumEditor.removeSelectedDecoration"].tap()
        XCTAssertFalse(ship.exists)
        app.buttons["aquariumEditor.undo"].tap()
        XCTAssertTrue(ship.exists)
        app.buttons["aquariumEditor.category.decoration"].tap()
        app.buttons["配置済み"].tap()
        app.buttons["aquariumEditor.storeAllDecorations"].tap()
        app.alerts["装飾を全部しまいますか？"].buttons["全部しまう"].tap()
        app.buttons["aquariumEditor.closeLibrary"].tap()
        XCTAssertFalse(ship.exists)
        app.buttons["aquariumEditor.undo"].tap()
        XCTAssertTrue(ship.exists)
        app.buttons["aquariumEditor.cancel"].tap()
        app.alerts["編集内容を破棄しますか？"].buttons["変更を破棄"].tap()
        XCTAssertFalse(ship.exists)
    }
    @MainActor private func capture(_ app: XCUIApplication, name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "沈没船・" + name; shot.lifetime = .keepAlways; add(shot)
    }
}
