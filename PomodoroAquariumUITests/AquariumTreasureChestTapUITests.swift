import XCTest

final class AquariumTreasureChestTapUITests: XCTestCase {
    @MainActor
    func testNormalTapBurstAndEditorExclusion() {
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
        app.buttons.matching(NSPredicate(format: "label == %@ AND identifier != %@", "その他", "mainTab.more")).firstMatch.tap()
        let addButton = app.buttons["aquariumEditor.add.treasure_chest"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5)); addButton.tap()
        let chest = app.descendants(matching: .any).matching(NSPredicate(format:
            "identifier BEGINSWITH %@", "aquariumEditor.placedDecoration.developer-owned-treasure_chest")).firstMatch
        let effects = app.descendants(matching: .any)["aquarium.treasureEffects"]
        XCTAssertTrue(chest.waitForExistence(timeout: 5))
        tapBody(chest, in: app)
        XCTAssertTrue((effects.value as? String)?.hasPrefix("通常の演出") == true)
        app.buttons["aquariumEditor.done"].tap()
        XCTAssertTrue(app.buttons["aquariumEditor.start"].waitForExistence(timeout: 5))
        let canvas = app.descendants(matching: .any)["aquarium.treasureTapCanvas"]
        XCTAssertTrue(canvas.waitForExistence(timeout: 5))
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.5,dy: 0.35)).tap()
        XCTAssertTrue((effects.value as? String)?.hasPrefix("通常の演出") == true)
        tapBody(chest, in: app)
        let started = waitValue(effects, value: "1個の宝箱で特別演出中", timeout: 2)
        XCTAssertTrue(started)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "宝箱タップ特別演出"; attachment.lifetime = .keepAlways; add(attachment)
        tapBody(chest, in: app)
        XCTAssertTrue((effects.value as? String)?.hasPrefix("1個の宝箱で特別演出中") == true)
        XCTAssertTrue(waitValue(effects, value: "通常の演出", timeout: 5))
        tapBody(chest, in: app)
        XCTAssertTrue(waitValue(effects, value: "1個の宝箱で特別演出中", timeout: 2))
    }
    @MainActor private func tapBody(_ chest: XCUIElement, in app: XCUIApplication) {
        // AXの高さには泡の描画余白も含まれるため、本体の幅と下端からタップ位置を求める。
        let frame = chest.frame
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: frame.midX, dy: frame.maxY - frame.width * 0.25)).tap()
    }
    @MainActor private func waitValue(_ element: XCUIElement, value: String, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "value == %@", value)
        return XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: element)], timeout: timeout) == .completed
    }
}
