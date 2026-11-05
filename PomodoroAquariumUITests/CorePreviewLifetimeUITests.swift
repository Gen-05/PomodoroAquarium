import XCTest

/// Preview一覧を破棄した後にも、通常Contextで保存できることを確認する。
final class CorePreviewLifetimeUITests: XCTestCase {
    @MainActor
    func testCoinsCanBeSavedAfterLeavingCoreTutorialPreview() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = [
            "-core-tutorial-in-memory", "-timerSessionState", "",
            "-hasCompletedOnboarding", "YES", "-hasCompletedCoreTutorial", "YES"
        ]
        app.launch()
        XCTAssertTrue(app.buttons["mainTab.more"].waitForExistence(timeout: 10))
        app.buttons["mainTab.more"].tap()
        // 一覧終了で所有Viewを破棄し、再表示によるリセット後にも保存する。
        for _ in 0..<2 {
            app.buttons["more.rewardPreview"].tap()
            let tutorial = app.buttons["rewardPreview.coreTutorial"]
            for _ in 0..<6 {
                if tutorial.exists && tutorial.isHittable { break }
                app.collectionViews.firstMatch.swipeUp()
            }
            XCTAssertTrue(tutorial.waitForExistence(timeout: 5))
            tutorial.tap()
            XCTAssertTrue(app.descendants(matching: .any)["coreTutorial.homeFishIntro"].waitForExistence(timeout: 10))
            app.buttons["coreTutorialPreview.exit"].tap()
            XCTAssertTrue(tutorial.waitForExistence(timeout: 5))
            app.navigationBars.buttons.firstMatch.tap()
            let grant = app.buttons["more.addTestCoins"]
            XCTAssertTrue(grant.waitForExistence(timeout: 5))
            grant.tap()
            let alert = app.alerts["テスト用コイン"]
            XCTAssertTrue(alert.waitForExistence(timeout: 5))
            XCTAssertTrue(alert.staticTexts.containing(NSPredicate(
                format: "label CONTAINS %@", "テスト用コインを追加しました"
            )).firstMatch.exists)
            alert.buttons["OK"].tap()
        }
    }
}
