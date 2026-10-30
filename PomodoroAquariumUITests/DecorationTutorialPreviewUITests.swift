import XCTest

final class DecorationTutorialPreviewUITests: XCTestCase {
    @MainActor private func launch() -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-core-tutorial-in-memory", "-decoration-purchase-tutorial-ui-test",
            "-timerSessionState", "", "-hasCompletedOnboarding", "YES", "-hasCompletedCoreTutorial", "YES",
            "-hasHandledFirstDecorationPurchaseTutorial", "YES"]
        app.launch()
        if app.buttons["aquariumEditor.cancel"].waitForExistence(timeout: 2) {
            app.buttons["aquariumEditor.cancel"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            app.alerts["編集内容を破棄しますか？"].buttons["変更を破棄"].tap()
        }
        XCTAssertTrue(app.buttons["mainTab.more"].waitForExistence(timeout: 10))
        return app
    }
    @MainActor private func openPreview(_ app: XCUIApplication) {
        app.buttons["mainTab.more"].tap()
        if app.buttons["more.rewardPreview"].exists { app.buttons["more.rewardPreview"].tap() }
        let entry = app.buttons["rewardPreview.decorationTutorial"]
        for _ in 0..<6 {
            if entry.exists, entry.isHittable, entry.frame.maxY < app.buttons["mainTab.more"].frame.minY - 12 { break }
            app.collectionViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(entry.waitForExistence(timeout: 5)); entry.tap()
        XCTAssertTrue(app.buttons["decorationTutorialPreview.exit"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["decorationTutorial.use"].exists)
        let preview = app.otherElements["decorationTutorialPreview.container"]
        let buy = preview.buttons["purchase-decoration-treasure_chest"]
        for _ in 0..<8 {
            if buy.exists && buy.isHittable { break }
            preview.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(buy.exists && buy.isHittable); buy.tap()
        let confirm = app.buttons["shop.purchaseConfirmation.confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["decorationTutorial.use"].exists)
        confirm.tap()
        let result = app.buttons["shop.purchaseFeedback.close"]
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["decorationTutorial.use"].exists)
        result.tap()
        XCTAssertTrue(app.buttons["decorationTutorial.use"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["decorationTutorialPreview.exit"].exists)
        XCTAssertFalse(app.otherElements["decorationTutorialPreview.container"].buttons["mainTab.more"].isEnabled)
    }
    @MainActor private func closePreview(_ app: XCUIApplication) {
        app.buttons["decorationTutorialPreview.exit"].tap()
        XCTAssertTrue(app.buttons["decorationTutorialPreview.exit"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["rewardPreview.decorationTutorial"].waitForExistence(timeout: 5))
    }
    @MainActor private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }

    @MainActor private func waitStep(_ step: String, _ app: XCUIApplication) {
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "decorationTutorial.guide." + step).firstMatch.waitForExistence(timeout: 5))
    }
    @MainActor private func conversation(_ app: XCUIApplication) -> XCUIElement {
        let card = app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND (value == %@ OR value == %@)",
            "decorationTutorial.guide.", "入力中", "全文表示済み")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        return card
    }
    @MainActor private func acknowledge(_ app: XCUIApplication) {
        let card = conversation(app)
        if card.value as? String != "全文表示済み" { card.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap() }
        card.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }
    @MainActor private func enterEditingFromInvitation(_ app: XCUIApplication) {
        app.buttons["decorationTutorial.use"].tap()
        waitStep("edit", app)
        XCTAssertFalse(app.buttons["aquariumEditor.done"].exists)
        XCTAssertFalse(app.otherElements["decorationTutorialPreview.container"].buttons["mainTab.shop"].isEnabled)
        capture("Decoration Preview・編集ボタンの案内")
        app.buttons["aquariumEditor.start"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        app.alerts["水槽を編集しますか？"].buttons["編集する"].tap()
        waitStep("library", app)
        app.buttons["aquariumEditor.category.decoration"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        waitStep("add", app)
    }

    @MainActor func testEntryRealEditingSaveReopenAndProductionInventoryRemainUnchanged() {
        let app = launch()
        app.buttons["mainTab.aquarium"].tap()
        app.buttons["aquariumEditor.start"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        app.alerts["水槽を編集しますか？"].buttons["編集する"].tap()
        app.buttons["aquariumEditor.category.decoration"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        app.buttons["岩"].tap()
        app.buttons["aquariumEditor.add.small_rock_a"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let productionRock = app.descendants(matching: .any).matching(NSPredicate(format:
            "identifier BEGINSWITH %@", "aquariumEditor.placedDecoration.developer-owned-small_rock_a")).firstMatch
        XCTAssertTrue(productionRock.waitForExistence(timeout: 5))
        let rockID = productionRock.identifier
        app.buttons["aquariumEditor.done"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.buttons["aquariumEditor.start"].waitForExistence(timeout: 5))
        let productionFrame = app.descendants(matching: .any).matching(identifier: rockID).firstMatch.frame
        app.buttons["mainTab.shop"].tap()
        XCTAssertTrue(app.staticTexts["所持コイン 100枚"].waitForExistence(timeout: 5))

        openPreview(app)
        capture("Decoration Preview・購入後の案内")
        enterEditingFromInvitation(app)
        let add = app.buttons["aquariumEditor.add.treasure_chest"]
        XCTAssertTrue(add.waitForExistence(timeout: 5)); capture("Decoration Preview・購入品を示す吹き出し"); add.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertGreaterThanOrEqual(app.buttons["aquariumEditor.done"].frame.minY,
            app.buttons["decorationTutorialPreview.exit"].frame.maxY)
        let chest = app.descendants(matching: .any).matching(NSPredicate(format:
            "identifier BEGINSWITH %@ AND label == %@", "aquariumEditor.placedDecoration.", "宝箱")).firstMatch
        XCTAssertTrue(chest.waitForExistence(timeout: 5))
        let chestID = chest.identifier
        waitStep("move", app)
        acknowledge(app) // 操作段階は吹き出しをタップしても進まない。
        waitStep("move", app)
        let point = chest.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
        point.press(forDuration: 0.1, thenDragTo: point.withOffset(CGVector(dx: 20, dy: 0)))
        waitStep("tools", app)
        capture("Decoration Preview・操作を求めない説明")
        acknowledge(app)
        waitStep("save", app)
        capture("Decoration Preview・保存ボタンの案内")
        XCTAssertTrue(app.buttons["aquariumEditor.undo"].isEnabled)
        app.buttons["aquariumEditor.undo"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.buttons["aquariumEditor.redo"].isEnabled)
        app.buttons["aquariumEditor.redo"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        app.buttons["aquariumEditor.done"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        waitStep("completed", app)
        XCTAssertTrue(app.buttons["aquariumEditor.start"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: chestID).firstMatch.exists)
        closePreview(app)

        app.buttons["mainTab.shop"].tap()
        XCTAssertTrue(app.staticTexts["所持コイン 100枚"].waitForExistence(timeout: 5))
        app.buttons["mainTab.aquarium"].tap()
        let restoredRock = app.descendants(matching: .any).matching(identifier: rockID).firstMatch
        XCTAssertTrue(restoredRock.waitForExistence(timeout: 5))
        XCTAssertEqual(restoredRock.frame.minX, productionFrame.minX, accuracy: 1)
        XCTAssertEqual(restoredRock.frame.minY, productionFrame.minY, accuracy: 1)
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: chestID).firstMatch.exists)
        openPreview(app)
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: chestID).firstMatch.exists)
        closePreview(app)
    }

    @MainActor func testLaterMidwayExitAndFreshInvitationOnEveryOpening() {
        let app = launch()
        openPreview(app)
        app.buttons["decorationTutorial.later"].tap()
        XCTAssertFalse(app.buttons["decorationTutorial.use"].exists)
        app.otherElements["decorationTutorialPreview.container"].buttons["mainTab.aquarium"].tap()
        app.buttons["aquariumEditor.start"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        app.alerts["水槽を編集しますか？"].buttons["編集する"].tap()
        XCTAssertFalse(app.buttons["aquariumEditor.decorationHint"].exists)
        XCTAssertFalse(app.buttons["decorationTutorial.skip"].exists)
        XCTAssertTrue(app.buttons["aquariumEditor.done"].exists)
        closePreview(app) // 通常の編集途中でも終了できる。
        openPreview(app)
        enterEditingFromInvitation(app)
        XCTAssertTrue(app.buttons["aquariumEditor.add.treasure_chest"].waitForExistence(timeout: 5))
        app.buttons["decorationTutorial.skip"].tap()
        XCTAssertTrue(app.buttons["aquariumEditor.done"].exists) // スキップは編集を終了・保存しない。
        XCTAssertTrue(app.buttons["aquariumEditor.closeLibrary"].exists)
        closePreview(app)
        openPreview(app)
        closePreview(app)
    }
}
