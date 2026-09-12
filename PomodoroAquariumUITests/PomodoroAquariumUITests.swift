//
//  PomodoroAquariumUITests.swift
//  PomodoroAquariumUITests
//
//  Created by 阿部弦生 on 2026/07/02.
//

import XCTest

final class PomodoroAquariumUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["ポモドーロ水族館"].waitForExistence(timeout: 5))

        let startButton = app.buttons["startButton"]
        XCTAssertTrue(startButton.exists)
        startButton.tap()

        let studyButton = app.buttons["勉強をはじめる"]
        XCTAssertTrue(studyButton.waitForExistence(timeout: 5))

        let statisticsTab = app.buttons["mainTab.statistics"]
        XCTAssertTrue(statisticsTab.exists)
        statisticsTab.tap()
        XCTAssertTrue(app.navigationBars["統計"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["monthlyStudyCalendar"].exists)

        let bookTab = app.buttons["mainTab.book"]
        bookTab.tap()
        XCTAssertTrue(app.navigationBars["魚図鑑"].waitForExistence(timeout: 5))

        let shopTab = app.buttons["mainTab.shop"]
        shopTab.tap()
        XCTAssertTrue(app.navigationBars["ショップ"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["100コイン"].exists)

        app.buttons["mainTab.aquarium"].tap()

        XCTAssertTrue(studyButton.waitForExistence(timeout: 5))
        studyButton.tap()

        XCTAssertTrue(app.buttons["ポモドーロ"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testStudyLocksTabsAndZeroRewardStillPresents() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.buttons["startButton"].waitForExistence(timeout: 5))
        app.buttons["startButton"].tap()

        XCTAssertTrue(app.buttons["勉強をはじめる"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["mainTab.hitShield"].exists)
        app.buttons["勉強をはじめる"].tap()
        XCTAssertTrue(app.buttons["勉強開始"].waitForExistence(timeout: 5))
        app.buttons["勉強開始"].tap()

        let laterButton = app.buttons["あとで"]
        if laterButton.waitForExistence(timeout: 1) {
            laterButton.tap()
        }
        XCTAssertTrue(app.buttons["一時停止"].waitForExistence(timeout: 5))
        let hitShield = app.descendants(matching: .any)["mainTab.hitShield"]
        XCTAssertTrue(hitShield.waitForExistence(timeout: 5))
        XCTAssertFalse(hitShield.frame.intersects(app.buttons["一時停止"].frame))

        let lockedTabs = [
            app.buttons["mainTab.book"],
            app.buttons["mainTab.shop"],
            app.buttons["mainTab.statistics"]
        ]
        for tab in lockedTabs {
            XCTAssertTrue(tab.exists)
            XCTAssertFalse(tab.isEnabled)
            repeatedlyTap(tab, normalizedOffset: CGVector(dx: 0.5, dy: 0.25), count: 10)
            repeatedlyTap(tab, normalizedOffset: CGVector(dx: 0.5, dy: 0.8), count: 10)
            repeatedlyTap(tab, normalizedOffset: CGVector(dx: 0.5, dy: -0.25), count: 10)
            XCTAssertTrue(app.buttons["一時停止"].exists)
        }

        repeatedlyTap(
            app,
            absolutePoint: CGPoint(
                x: app.buttons["mainTab.book"].frame.maxX,
                y: app.buttons["mainTab.book"].frame.midY
            ),
            count: 10
        )
        XCTAssertTrue(app.buttons["一時停止"].exists)

        app.buttons["一時停止"].tap()
        XCTAssertTrue(app.buttons["再開する"].waitForExistence(timeout: 5))
        for tab in lockedTabs {
            XCTAssertFalse(tab.isEnabled)
            tab.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            XCTAssertTrue(app.buttons["再開する"].exists)
        }
        app.buttons["再開する"].tap()
        XCTAssertTrue(app.buttons["一時停止"].waitForExistence(timeout: 5))
        app.buttons["一時停止"].tap()
        XCTAssertTrue(app.buttons["終了する"].waitForExistence(timeout: 5))

        app.buttons["終了する"].tap()
        let endAlert = app.alerts["勉強を終了しますか？"]
        XCTAssertTrue(endAlert.waitForExistence(timeout: 5))
        endAlert.buttons["終了する"].tap()

        XCTAssertTrue(app.buttons["報酬を見る"].waitForExistence(timeout: 5))
        XCTAssertTrue(hitShield.waitForNonExistence(timeout: 5))
        app.buttons["報酬を見る"].tap()
        XCTAssertTrue(app.staticTexts["0コイン"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["獲得魚なし"].exists)
    }

    @MainActor
    func testAquariumSideEditorKeepsTheAquariumVisibleAndSwitchesCategories() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.buttons["startButton"].waitForExistence(timeout: 5))
        app.buttons["startButton"].tap()

        let editButton = app.buttons["水槽編集"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 5))
        editButton.tap()

        let panel = app.descendants(matching: .any)["aquariumEditor.panel"]
        XCTAssertTrue(panel.waitForExistence(timeout: 5))
        XCTAssertLessThan(panel.frame.width, app.frame.width / 2)
        XCTAssertGreaterThan(app.frame.width - panel.frame.width, app.frame.width / 2)
        XCTAssertGreaterThan(panel.frame.minX, app.frame.midX)
        XCTAssertTrue(app.staticTexts["水槽の魚"].exists)
        XCTAssertEqual(
            app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "戻す")).count,
            0
        )

        app.buttons["aquariumEditor.category.decoration"].tap()
        XCTAssertTrue(app.staticTexts["水槽へドラッグ"].waitForExistence(timeout: 5))

        app.buttons["aquariumEditor.category.background"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["aquariumEditor.background.deepSea"].waitForExistence(timeout: 5))

        app.buttons["aquariumEditor.category.fish"].tap()
        XCTAssertTrue(app.staticTexts["水槽の魚"].waitForExistence(timeout: 5))
        app.buttons["水槽編集を終了"].tap()
        XCTAssertTrue(editButton.waitForExistence(timeout: 5))
    }

    private func repeatedlyTap(
        _ element: XCUIElement,
        normalizedOffset: CGVector,
        count: Int
    ) {
        let coordinate = element.coordinate(withNormalizedOffset: normalizedOffset)
        for _ in 0..<count {
            coordinate.tap()
        }
    }

    private func repeatedlyTap(
        _ app: XCUIApplication,
        absolutePoint: CGPoint,
        count: Int
    ) {
        let coordinate = app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: absolutePoint.x, dy: absolutePoint.y))
        for _ in 0..<count {
            coordinate.tap()
        }
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
