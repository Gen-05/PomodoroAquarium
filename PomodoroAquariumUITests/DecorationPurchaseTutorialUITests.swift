import XCTest

final class DecorationPurchaseTutorialUITests: XCTestCase {
    @MainActor private func launch() -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-core-tutorial-in-memory", "-decoration-purchase-tutorial-ui-test",
            "-reset-decoration-purchase-tutorial", "-timerSessionState", "", "-hasCompletedOnboarding", "YES",
            "-hasCompletedCoreTutorial", "YES", "-hasSeenAquariumEditorTutorial", "YES"]
        app.launch()
        if app.buttons["aquariumEditor.cancel"].waitForExistence(timeout: 2) {
            cancelEditing(app)
        }
        XCTAssertTrue(app.buttons["mainTab.shop"].waitForExistence(timeout: 10))
        app.buttons["mainTab.shop"].tap()
        XCTAssertFalse(app.buttons["decorationTutorial.use"].exists)
        return app
    }

    @MainActor private func buy(_ rawKind: String, in app: XCUIApplication) {
        let button = app.buttons["purchase-tutorial-test-" + rawKind]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        if !button.isHittable { app.swipeUp() }
        button.tap()
        let confirm = app.buttons["shop.purchaseConfirmation.confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["shop.purchaseFeedback.close"].exists)
        confirm.tap()
        XCTAssertTrue(app.buttons["shop.purchaseFeedback.close"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["decorationTutorial.use"].exists)
    }

    @MainActor private func closeFeedback(_ app: XCUIApplication) {
        app.buttons["shop.purchaseFeedback.close"].tap()
    }
    @MainActor private func cancelEditing(_ app: XCUIApplication) {
        app.buttons["aquariumEditor.cancel"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        app.alerts["編集内容を破棄しますか？"].buttons["変更を破棄"].tap()
    }
    @MainActor private func capture(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }

    @MainActor private func waitStep(_ step: String, _ app: XCUIApplication) {
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "decorationTutorial.guide." + step).firstMatch.waitForExistence(timeout: 5))
    }
    @MainActor private func acknowledge(_ app: XCUIApplication) {
        let card = app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND (value == %@ OR value == %@)",
            "decorationTutorial.guide.", "入力中", "全文表示済み")).firstMatch
        if card.value as? String != "全文表示済み" { card.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap() }
        card.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }
    @MainActor private func startGuide(_ app: XCUIApplication) {
        app.buttons["decorationTutorial.use"].tap()
        waitStep("edit", app)
        XCTAssertFalse(app.buttons["aquariumEditor.done"].exists)
        app.buttons["aquariumEditor.start"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        app.alerts["水槽を編集しますか？"].buttons["編集する"].tap()
        waitStep("library", app)
        app.buttons["aquariumEditor.category.decoration"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        waitStep("add", app)
    }

    @MainActor func testInsufficientFundsLaterAndRelaunchSuppression() {
        let app = launch()
        let insufficient = app.buttons["purchase-tutorial-test-small_rock_a"]
        XCTAssertTrue(insufficient.waitForExistence(timeout: 5))
        if !insufficient.isHittable { app.swipeUp() }
        insufficient.tap()
        XCTAssertTrue(app.staticTexts["コインが足りません"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["shop.purchaseConfirmation.confirm"].isEnabled)
        app.buttons["shop.purchaseConfirmation.cancel"].tap()
        XCTAssertFalse(app.buttons["decorationTutorial.use"].waitForExistence(timeout: 2))
        app.swipeDown()
        buy("seaweed-a", in: app)
        capture(app, "購入完了・案内は未表示")
        closeFeedback(app)
        XCTAssertTrue(app.buttons["decorationTutorial.use"].waitForExistence(timeout: 5))
        XCTAssertLessThanOrEqual(app.buttons["decorationTutorial.use"].frame.maxY, app.buttons["mainTab.shop"].frame.minY)
        capture(app, "初回購入の案内")
        app.buttons["decorationTutorial.later"].tap()
        buy("treasure_chest", in: app)
        closeFeedback(app)
        XCTAssertFalse(app.buttons["decorationTutorial.use"].waitForExistence(timeout: 2))
        app.terminate()
        app.launchArguments.removeAll { $0 == "-reset-decoration-purchase-tutorial" }
        app.launch()
        app.buttons["mainTab.shop"].tap()
        buy("seaweed-a", in: app)
        closeFeedback(app)
        XCTAssertFalse(app.buttons["decorationTutorial.use"].waitForExistence(timeout: 2))
        // 手動編集にヒント入口を出さず、既存の履歴操作は残す。
        app.buttons["mainTab.aquarium"].tap()
        XCTAssertFalse(app.buttons["aquariumEditor.decorationHint"].exists)
        app.buttons["aquariumEditor.start"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        app.alerts["水槽を編集しますか？"].buttons["編集する"].tap()
        XCTAssertFalse(app.buttons["aquariumEditor.decorationHint"].exists)
        XCTAssertTrue(app.buttons["aquariumEditor.undo"].exists)
        XCTAssertTrue(app.buttons["aquariumEditor.redo"].exists)
        XCTAssertFalse(app.buttons["decorationTutorial.skip"].exists)
        cancelEditing(app)
    }

    @MainActor func testPurchasedIndividualAddDragToolsUndoCancelSaveAndReopen() {
        let app = launch()
        buy("treasure_chest", in: app)
        closeFeedback(app)
        XCTAssertTrue(app.buttons["decorationTutorial.use"].waitForExistence(timeout: 5))
        startGuide(app)
        let add = app.buttons["aquariumEditor.add.treasure_chest"]
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        capture(app, "1・購入した装飾の追加")
        add.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let purchased = app.descendants(matching: .any).matching(NSPredicate(format:
            "identifier BEGINSWITH %@ AND NOT identifier BEGINSWITH %@",
            "aquariumEditor.placedDecoration.", "aquariumEditor.placedDecoration.developer-owned-")).firstMatch
        XCTAssertTrue(purchased.waitForExistence(timeout: 5))
        let purchasedID = purchased.identifier
        XCTAssertTrue(app.buttons["aquariumEditor.openNudge"].waitForExistence(timeout: 5))
        capture(app, "2・選択とドラッグ")
        let start = purchased.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 30, dy: 0)))
        waitStep("tools", app)
        capture(app, "3・微調整と重なり順")
        app.buttons["aquariumEditor.openNudge"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        app.buttons["奥へ"].tap()
        app.buttons["aquariumEditor.closeNudge"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        app.buttons["aquariumEditor.stackingMenu"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        app.buttons["aquariumEditor.closeStacking"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        app.buttons["aquariumEditor.changeTreasureChestDirection"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        acknowledge(app)
        waitStep("save", app)
        app.buttons["aquariumEditor.undo"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        app.buttons["aquariumEditor.redo"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        capture(app, "4・保存と破棄")
        app.buttons["decorationTutorial.skip"].tap()
        cancelEditing(app)
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: purchasedID).firstMatch.exists)
        app.buttons["aquariumEditor.start"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        app.alerts["水槽を編集しますか？"].buttons["編集する"].tap()
        XCTAssertFalse(app.buttons["aquariumEditor.decorationHint"].exists)
        app.buttons["aquariumEditor.category.decoration"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        add.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: purchasedID).firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["decorationTutorial.skip"].exists)
        app.buttons["aquariumEditor.done"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.buttons["aquariumEditor.start"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: purchasedID).firstMatch.exists)
        app.buttons["mainTab.shop"].tap()
        buy("seaweed-a", in: app)
        closeFeedback(app)
        XCTAssertFalse(app.buttons["decorationTutorial.use"].waitForExistence(timeout: 2))
    }

    @MainActor func testShipwreckUsesFixedSidesAndSkipDoesNotPlaceAnything() {
        let app = launch()
        buy("shipwreck_distant", in: app)
        closeFeedback(app)
        XCTAssertTrue(app.buttons["decorationTutorial.use"].waitForExistence(timeout: 5))
        startGuide(app)
        let add = app.buttons["aquariumEditor.add.shipwreck_distant"]
        XCTAssertTrue(add.waitForExistence(timeout: 10)); add.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        app.buttons["左奥"].tap()
        XCTAssertTrue(app.buttons["aquariumEditor.shipwreck.right"].waitForExistence(timeout: 5))
        capture(app, "沈没船の固定配置案内")
        XCTAssertFalse(app.buttons["aquariumEditor.openNudge"].exists)
        app.buttons["aquariumEditor.shipwreck.right"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        waitStep("tools", app)
        XCTAssertFalse(app.buttons["aquariumEditor.stackingMenu"].exists)
        app.buttons["aquariumEditor.removeSelectedDecoration"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        app.buttons["aquariumEditor.undo"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        app.buttons["aquariumEditor.redo"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        app.buttons["decorationTutorial.skip"].tap()
        cancelEditing(app)
        app.buttons["mainTab.shop"].tap()
        buy("seaweed-a", in: app)
        closeFeedback(app)
        XCTAssertFalse(app.buttons["decorationTutorial.use"].waitForExistence(timeout: 2))
    }

    @MainActor func testLongDecorationListFocusAndSkipBeforePlacement() {
        let app = launch()
        if app.windows.firstMatch.frame.width > 600 {
            XCUIDevice.shared.orientation = .landscapeLeft
            let rotated = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                app.windows.firstMatch.frame.width > app.windows.firstMatch.frame.height
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [rotated], timeout: 5), .completed)
        }
        defer { XCUIDevice.shared.orientation = .portrait }
        buy("coral_c_purple", in: app)
        closeFeedback(app)
        XCTAssertTrue(app.buttons["decorationTutorial.use"].waitForExistence(timeout: 5))
        XCTAssertLessThanOrEqual(app.buttons["decorationTutorial.use"].frame.maxY, app.buttons["mainTab.shop"].frame.minY)
        startGuide(app)
        let add = app.buttons["aquariumEditor.add.coral_c_purple"]
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        XCTAssertGreaterThanOrEqual(add.frame.minY, app.frame.minY)
        XCTAssertLessThanOrEqual(add.frame.maxY, app.frame.maxY)
        capture(app, "長い一覧でも購入したサンゴを案内")
        app.buttons["decorationTutorial.skip"].tap()
        app.buttons["aquariumEditor.closeLibrary"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertEqual(app.descendants(matching: .any).matching(NSPredicate(format:
            "identifier BEGINSWITH %@", "aquariumEditor.placedDecoration.")).count, 0)
        XCTAssertFalse(app.buttons["aquariumEditor.decorationHint"].exists)
        app.buttons["aquariumEditor.category.decoration"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        // 案内終了後も通常操作で購入個体を追加できる。
        add.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format:
            "identifier BEGINSWITH %@ AND label == %@", "aquariumEditor.placedDecoration.", "トゲサンゴ（パープル）")).firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["decorationTutorial.skip"].exists)
        cancelEditing(app)
    }
}
