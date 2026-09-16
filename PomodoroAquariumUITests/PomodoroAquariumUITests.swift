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
    func testRewardFishAndGlowShareTheScreenCenter() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-reward-layout-debug")
        app.launch()
        XCTAssertTrue(app.buttons["startButton"].waitForExistence(timeout: 5))
        app.buttons["startButton"].tap()
        XCTAssertTrue(app.buttons["mainTab.more"].waitForExistence(timeout: 5))
        app.buttons["mainTab.more"].tap()
        app.buttons["more.rewardPreview"].tap()

        for rarity in ["epic", "legendary", "common", "rare"] {
            if rarity == "rare" {
                let newFishSwitch = app.switches["rewardPreview.newFish"]
                newFishSwitch.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
                let duplicatePreviewReady = XCTNSPredicateExpectation(
                    predicate: NSPredicate(format: "value == %@", "0"),
                    object: newFishSwitch
                )
                XCTAssertEqual(XCTWaiter.wait(for: [duplicatePreviewReady], timeout: 3), .completed)
            }
            let previewButton = app.buttons["rewardPreview.\(rarity)"]
            XCTAssertTrue(previewButton.waitForExistence(timeout: 5))
            previewButton.tap()
            let prompt = app.staticTexts["fishReward.tapPrompt"]
            XCTAssertTrue(prompt.waitForExistence(timeout: 5))
            assertRewardCenters(app, names: ["container"])
            XCTAssertFalse(app.staticTexts["fishRarity"].exists)
            XCTAssertFalse(app.staticTexts["fishReward.getMessage"].exists)
            XCTAssertFalse(app.staticTexts["fishReward.newBadge"].exists)
            let anticipationAttachment = XCTAttachment(screenshot: app.screenshot())
            anticipationAttachment.name = "Reward anticipation \(rarity)"
            anticipationAttachment.lifetime = .keepAlways
            add(anticipationAttachment)
            prompt.tap()
            let geometryReady = XCTNSPredicateExpectation(
                predicate: NSPredicate(
                    format: "label CONTAINS %@ AND NOT (label CONTAINS %@)",
                    "fish=", "fish=0.00"
                ),
                object: app.staticTexts["fishReward.debugCoordinates"]
            )
            XCTAssertEqual(XCTWaiter.wait(for: [geometryReady], timeout: 3), .completed)
            assertRewardCenters(app, names: ["container", "composite", "fish", "glow"])
            XCTAssertTrue(app.staticTexts["fishReward.getMessage"].waitForExistence(timeout: 8))
            XCTAssertEqual(app.staticTexts["fishReward.newBadge"].exists, rarity != "rare")

            let coordinates = app.staticTexts["fishReward.debugCoordinates"]
            XCTAssertTrue(coordinates.exists)
            assertRewardCenters(app, names: ["container", "composite", "fish", "glow"])
            print("REWARD CENTER \(rarity): \(coordinates.label)")
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "Reward center \(rarity)"
            attachment.lifetime = .keepAlways
            add(attachment)
            app.buttons["fishReward.close"].tap()
        }
    }

    @MainActor
    private func assertRewardCenters(_ app: XCUIApplication, names: [String]) {
        let label = app.staticTexts["fishReward.debugCoordinates"].label
        let values: [String: Double] = Dictionary(uniqueKeysWithValues: label.split(separator: "\n").compactMap { line in
            let pair = line.split(separator: "=")
            guard pair.count == 2, let value = Double(pair[1]) else { return nil }
            return (String(pair[0]), value)
        })
        guard let screenCenter = values["screen"] else {
            XCTFail("Missing screen center: \(label)")
            return
        }
        for name in names {
            guard let center = values[name] else {
                XCTFail("Missing \(name) center: \(label)")
                continue
            }
            XCTAssertEqual(center, screenCenter, accuracy: 0.5, "\(name): \(label)")
        }
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
        let dailyFishProgress = app.descendants(matching: .any)["home.dailyFishProgress"]
        let increaseFishLimitButton = app.buttons["home.increaseDailyFishLimit"]
        let studySummary = app.descendants(matching: .any)["home.studySummary"]
        let todayStudyMinutes = app.staticTexts["home.todayStudyMinutes"]
        let yesterdayStudyMinutes = app.staticTexts["home.yesterdayStudyMinutes"]
        let coinBalance = app.descendants(matching: .any)["home.coinBalance"]
        let customTabBar = app.descendants(matching: .any)["mainTab.customTabBar"]
        XCTAssertTrue(dailyFishProgress.exists)
        XCTAssertTrue(increaseFishLimitButton.exists)
        XCTAssertTrue(studySummary.exists)
        XCTAssertTrue(todayStudyMinutes.exists)
        XCTAssertTrue(yesterdayStudyMinutes.exists)
        XCTAssertTrue(coinBalance.exists)
        XCTAssertTrue(customTabBar.exists)
        XCTAssertLessThanOrEqual(studyButton.frame.maxY, customTabBar.frame.minY)
        XCTAssertLessThanOrEqual(dailyFishProgress.frame.maxX, studySummary.frame.minX)
        XCTAssertLessThanOrEqual(studySummary.frame.maxX, coinBalance.frame.minX)
        let statusBar = app.statusBars.firstMatch
        if statusBar.exists {
            XCTAssertGreaterThanOrEqual(dailyFishProgress.frame.minY, statusBar.frame.maxY)
            XCTAssertGreaterThanOrEqual(studySummary.frame.minY, statusBar.frame.maxY)
            XCTAssertGreaterThanOrEqual(coinBalance.frame.minY, statusBar.frame.maxY)
        }

        increaseFishLimitButton.tap()
        let fishLimitAlert = app.alerts["魚の獲得上限"]
        XCTAssertTrue(fishLimitAlert.waitForExistence(timeout: 2))
        fishLimitAlert.buttons["OK"].tap()
        for tabIdentifier in [
            "mainTab.home",
            "mainTab.aquarium",
            "mainTab.shop",
            "mainTab.statistics",
            "mainTab.more"
        ] {
            XCTAssertTrue(app.buttons[tabIdentifier].exists)
        }
        XCTAssertFalse(app.buttons["mainTab.book"].exists)

        let statisticsTab = app.buttons["mainTab.statistics"]
        XCTAssertTrue(statisticsTab.exists)
        statisticsTab.tap()
        XCTAssertTrue(app.navigationBars["統計"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["monthlyStudyCalendar"].exists)

        let moreTab = app.buttons["mainTab.more"]
        moreTab.tap()
        XCTAssertTrue(app.navigationBars["その他"].waitForExistence(timeout: 5))
        app.buttons["more.book"].tap()
        XCTAssertTrue(app.navigationBars["魚図鑑"].waitForExistence(timeout: 5))

        app.navigationBars["魚図鑑"].buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["その他"].waitForExistence(timeout: 5))
        app.buttons["more.settings"].tap()
        XCTAssertTrue(app.navigationBars["設定"].waitForExistence(timeout: 5))
        app.navigationBars["設定"].buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["その他"].waitForExistence(timeout: 5))

        let shopTab = app.buttons["mainTab.shop"]
        shopTab.tap()
        XCTAssertTrue(app.navigationBars["ショップ"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["100コイン"].exists)

        app.buttons["mainTab.home"].tap()

        XCTAssertTrue(studyButton.waitForExistence(timeout: 5))
        studyButton.tap()

        XCTAssertTrue(app.buttons["ポモドーロ"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["timer.startStudy"].exists)
        app.buttons["mainTab.home"].tap()
        XCTAssertTrue(studyButton.waitForExistence(timeout: 5))
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
            app.buttons["mainTab.aquarium"],
            app.buttons["mainTab.shop"],
            app.buttons["mainTab.statistics"],
            app.buttons["mainTab.more"]
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
                x: app.buttons["mainTab.aquarium"].frame.maxX,
                y: app.buttons["mainTab.aquarium"].frame.midY
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

        XCTAssertFalse(app.buttons["水槽編集"].exists)
        XCTAssertFalse(app.buttons["設定"].exists)
        app.buttons["mainTab.aquarium"].tap()

        let tutorial = app.descendants(matching: .any)["aquariumEditor.tutorial"]
        let panel = app.descendants(matching: .any)["aquariumEditor.panel"]
        let editButton = app.buttons["aquariumEditor.start"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 5))
        XCTAssertFalse(panel.exists)
        XCTAssertFalse(app.buttons["aquariumEditor.done"].exists)
        XCTAssertFalse(app.buttons["aquariumEditor.help"].exists)
        XCTAssertFalse(tutorial.exists)

        editButton.tap()
        let editAlert = app.alerts["水槽を編集しますか？"]
        XCTAssertTrue(editAlert.waitForExistence(timeout: 2))
        editAlert.buttons["キャンセル"].tap()
        XCTAssertTrue(editButton.waitForExistence(timeout: 2))
        XCTAssertFalse(panel.exists)

        editButton.tap()
        XCTAssertTrue(editAlert.waitForExistence(timeout: 2))
        editAlert.buttons["編集する"].tap()

        if tutorial.waitForExistence(timeout: 1) {
            app.buttons["aquariumEditor.tutorial.dismiss"].tap()
            XCTAssertTrue(tutorial.waitForNonExistence(timeout: 2))
        }

        XCTAssertTrue(panel.waitForExistence(timeout: 5))
        XCTAssertLessThan(panel.frame.width, app.frame.width / 2)
        XCTAssertGreaterThan(app.frame.width - panel.frame.width, app.frame.width / 2)
        XCTAssertGreaterThan(panel.frame.minX, app.frame.midX)
        XCTAssertTrue(app.staticTexts["水槽の魚"].exists)
        XCTAssertEqual(
            app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "戻す")).count,
            0
        )

        let helpButton = app.buttons["aquariumEditor.help"]
        XCTAssertTrue(helpButton.exists)
        helpButton.tap()
        XCTAssertTrue(tutorial.waitForExistence(timeout: 2))
        app.buttons["aquariumEditor.tutorial.dismiss"].tap()
        XCTAssertTrue(tutorial.waitForNonExistence(timeout: 2))
        helpButton.tap()
        XCTAssertTrue(tutorial.waitForExistence(timeout: 2))
        app.buttons["aquariumEditor.tutorial.dismiss"].tap()

        app.buttons["aquariumEditor.collapsePanel"].tap()
        XCTAssertTrue(panel.waitForNonExistence(timeout: 2))
        let expandPanel = app.buttons["aquariumEditor.expandPanel"]
        XCTAssertTrue(expandPanel.waitForExistence(timeout: 2))
        XCTAssertLessThan(expandPanel.frame.width, app.frame.width * 0.15)
        XCTAssertGreaterThanOrEqual(expandPanel.frame.height, 70)
        XCTAssertLessThanOrEqual(expandPanel.frame.height, 110)
        XCTAssertLessThanOrEqual(abs(expandPanel.frame.maxX - app.frame.maxX), 2)
        XCTAssertFalse(app.buttons["aquariumEditor.help"].exists)
        expandPanel.tap()
        XCTAssertTrue(panel.waitForExistence(timeout: 2))

        app.buttons["aquariumEditor.category.decoration"].tap()
        XCTAssertTrue(app.staticTexts["水槽へドラッグ"].waitForExistence(timeout: 5))
        let placedRock = app.descendants(matching: .any)[
            "aquariumEditor.placedDecoration.default-rock"
        ]
        let removeDecorationButton = app.buttons["aquariumEditor.removeSelectedDecoration"]
        let emptyCanvas = app.descendants(matching: .any)["aquariumEditor.emptyCanvas"]
        XCTAssertTrue(placedRock.waitForExistence(timeout: 5))
        XCTAssertTrue(emptyCanvas.exists)
        placedRock.tap()
        XCTAssertTrue(removeDecorationButton.waitForExistence(timeout: 2))
        emptyCanvas.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)).tap()
        XCTAssertTrue(removeDecorationButton.waitForNonExistence(timeout: 2))

        app.buttons["aquariumEditor.category.background"].tap()
        let deepSeaBackground = app.buttons["aquariumEditor.background.deepSea"]
        XCTAssertTrue(deepSeaBackground.waitForExistence(timeout: 5))
        deepSeaBackground.tap()
        XCTAssertEqual(deepSeaBackground.value as? String, "選択中")

        app.buttons["aquariumEditor.category.fish"].tap()
        XCTAssertTrue(app.staticTexts["水槽の魚"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["水槽編集を終了"].exists)

        app.buttons["aquariumEditor.done"].tap()
        let saveConfirmation = app.sheets.firstMatch
        if saveConfirmation.waitForExistence(timeout: 1) {
            saveConfirmation.buttons["変更を破棄"].tap()
        }
        XCTAssertTrue(editButton.waitForExistence(timeout: 5))
        XCTAssertTrue(panel.waitForNonExistence(timeout: 2))
        XCTAssertFalse(app.buttons["aquariumEditor.done"].exists)
        XCTAssertFalse(app.buttons["aquariumEditor.help"].exists)

        app.buttons["mainTab.shop"].tap()
        XCTAssertTrue(app.navigationBars["ショップ"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testAquariumViewingControlsAutoHideAndEditingKeepsThemVisible() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.buttons["startButton"].waitForExistence(timeout: 5))
        app.buttons["startButton"].tap()
        app.buttons["mainTab.aquarium"].tap()

        let editButton = app.buttons["aquariumEditor.start"]
        let homeTab = app.buttons["mainTab.home"]
        let tapSurface = app.descendants(matching: .any)["aquariumViewing.tapSurface"]
        let customTabBar = app.descendants(matching: .any)["mainTab.customTabBar"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 5))
        XCTAssertTrue(homeTab.exists)
        XCTAssertTrue(tapSurface.exists)
        XCTAssertTrue(customTabBar.exists)
        XCTAssertEqual(app.tabBars.count, 0)

        let editButtonHidden = expectation(
            for: NSPredicate(format: "hittable == false"),
            evaluatedWith: editButton
        )
        let tabBarHidden = expectation(
            for: NSPredicate(format: "hittable == false"),
            evaluatedWith: homeTab
        )
        wait(for: [editButtonHidden, tabBarHidden], timeout: 6)
        XCTAssertFalse(customTabBar.isHittable)

        tapSurface.tap()
        XCTAssertTrue(editButton.waitForExistence(timeout: 2))
        XCTAssertTrue(homeTab.waitForExistence(timeout: 2))
        XCTAssertTrue(customTabBar.isHittable)

        Thread.sleep(forTimeInterval: 3)
        tapSurface.tap()
        Thread.sleep(forTimeInterval: 1.5)
        XCTAssertTrue(editButton.exists)
        XCTAssertTrue(homeTab.exists)

        editButton.tap()
        let editAlert = app.alerts["水槽を編集しますか？"]
        XCTAssertTrue(editAlert.waitForExistence(timeout: 2))
        editAlert.buttons["編集する"].tap()

        let tutorial = app.descendants(matching: .any)["aquariumEditor.tutorial"]
        if tutorial.waitForExistence(timeout: 1) {
            app.buttons["aquariumEditor.tutorial.dismiss"].tap()
        }

        let panel = app.descendants(matching: .any)["aquariumEditor.panel"]
        XCTAssertTrue(panel.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["aquariumEditor.done"].exists)
        XCTAssertTrue(app.buttons["aquariumEditor.help"].exists)
        XCTAssertTrue(homeTab.exists)

        Thread.sleep(forTimeInterval: 10.5)
        XCTAssertTrue(panel.exists)
        XCTAssertTrue(app.buttons["aquariumEditor.done"].exists)
        XCTAssertTrue(app.buttons["aquariumEditor.help"].exists)
        XCTAssertTrue(homeTab.exists)

        app.buttons["aquariumEditor.done"].tap()
        XCTAssertTrue(editButton.waitForExistence(timeout: 2))
        XCTAssertTrue(homeTab.exists)
        Thread.sleep(forTimeInterval: 4.5)
        XCTAssertFalse(editButton.isHittable)
        XCTAssertFalse(homeTab.isHittable)

        tapSurface.tap()
        XCTAssertTrue(homeTab.waitForExistence(timeout: 2))
        homeTab.tap()
        let studyButton = app.buttons["勉強をはじめる"]
        XCTAssertTrue(studyButton.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 4.5)
        XCTAssertTrue(studyButton.exists)
        XCTAssertTrue(app.buttons["mainTab.aquarium"].exists)
        XCTAssertTrue(app.buttons["mainTab.aquarium"].isHittable)
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
