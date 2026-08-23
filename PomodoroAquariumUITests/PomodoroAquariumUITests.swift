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

        let statisticsTab = app.tabBars.buttons["統計"]
        XCTAssertTrue(statisticsTab.exists)
        statisticsTab.tap()
        XCTAssertTrue(app.navigationBars["統計"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["monthlyStudyCalendar"].exists)

        let bookTab = app.tabBars.buttons["図鑑"]
        bookTab.tap()
        XCTAssertTrue(app.navigationBars["魚図鑑"].waitForExistence(timeout: 5))

        let shopTab = app.tabBars.buttons["ショップ"]
        shopTab.tap()
        XCTAssertTrue(app.navigationBars["ショップ"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["100コイン"].exists)

        app.tabBars.buttons["水槽"].tap()

        XCTAssertTrue(studyButton.waitForExistence(timeout: 5))
        studyButton.tap()

        XCTAssertTrue(app.buttons["ポモドーロ"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
