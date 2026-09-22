//
//  PomodoroAquariumUITests.swift
//  PomodoroAquariumUITests
//
//  Created by 阿部弦生 on 2026/07/02.
//

import XCTest

private enum CoreTutorialConversationPageCount {
    static let homeIntro = 5
    static let homePoints = 2
    static let homeStudySummary = 2
    static let studyMode = 2
    static let studySettings = 2
    static let rewardFollowUp = 3
    static let aquariumReturnHome = 3
    static let finishing = 3
}

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
    private func launchReturningUser(_ app: XCUIApplication) {
        app.launchArguments += [
            "-hasCompletedOnboarding", "YES",
            "-hasCompletedCoreTutorial", "YES"
        ]
        app.launch()
        XCTAssertTrue(app.buttons["勉強をはじめる"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testOnboardingCompletesOnceAndRelaunchesDirectlyIntoHome() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-reset-onboarding",
            "-hasCompletedCoreTutorial", "YES"
        ]
        app.launch()
        for page in 0..<3 {
            XCTAssertTrue(app.staticTexts["onboarding.title.\(page)"].waitForExistence(timeout: 5))
            XCTAssertFalse(app.buttons["勉強をはじめる"].exists)
            if page == 0 {
                for step in ["集中", "魚をゲット", "水族館が育つ"] {
                    XCTAssertTrue(app.staticTexts[step].exists)
                }
            }
            if page == 1 {
                XCTAssertTrue(app.staticTexts["onboarding.rewardStudyDuration"].exists)
                XCTAssertFalse(app.staticTexts["マンタをゲット！"].exists)
                XCTAssertTrue(app.images["onboarding.rewardSilhouette"].exists)
                XCTAssertEqual(app.staticTexts["onboarding.rewardRarity"].label, "RARE")
                XCTAssertTrue(app.staticTexts["fishReward.newBadge"].exists)
            }
            if page == 2 {
                XCTAssertEqual(app.staticTexts["onboarding.rareChanceBoost"].label, "レア率UP ↑")
                for rarity in ["RARE", "EPIC", "LEGENDARY"] {
                    XCTAssertTrue(app.staticTexts[rarity].exists)
                }
            }
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "Onboarding page \(page + 1)"
            attachment.lifetime = .keepAlways
            add(attachment)
            if page == 0 {
                app.collectionViews["onboarding.pages"].swipeLeft()
            } else {
                app.buttons["onboarding.next"].tap()
            }
        }
        let studyButton = app.buttons["勉強をはじめる"]
        XCTAssertTrue(studyButton.waitForExistence(timeout: 5))
        let homeIDs = ["home.dailyFishProgress", "home.coinBalance", "home.todayStudyMinutes"]
        let before = homeIDs.map { app.descendants(matching: .any)[$0].label }
        app.terminate()
        app.launchArguments = ["-hasCompletedCoreTutorial", "YES"]
        app.launch()
        XCTAssertTrue(studyButton.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["onboarding.title.0"].exists)
        XCTAssertFalse(app.buttons["startButton"].exists)
        XCTAssertEqual(homeIDs.map { app.descendants(matching: .any)[$0].label }, before)
        XCTAssertTrue(app.buttons["mainTab.home"].exists)

        app.buttons["mainTab.more"].tap()
        app.buttons["more.rewardPreview"].tap()
        app.buttons["rewardPreview.onboarding"].tap()
        for page in 0..<3 {
            XCTAssertTrue(app.staticTexts["onboarding.title.\(page)"].waitForExistence(timeout: 5))
            app.buttons["onboarding.next"].tap()
        }
        XCTAssertTrue(app.buttons["rewardPreview.onboarding"].waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        XCTAssertTrue(studyButton.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["onboarding.title.0"].exists)
        XCTAssertEqual(homeIDs.map { app.descendants(matching: .any)[$0].label }, before)
    }

    @MainActor
    func testCoreTutorialUsesRealControlsAndCompletesWithoutWaiting25Minutes() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-core-tutorial-ui-test"]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["coreTutorial.homeFishIntro"].waitForExistence(timeout: 5))
        advanceConversation(in: app, pageCount: CoreTutorialConversationPageCount.homeIntro)
        XCTAssertTrue(app.descendants(matching: .any)["coreTutorial.homePointsIntro"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.descendants(matching: .any)["coreTutorial.homeFishIntro"].exists)
        advanceConversation(in: app, pageCount: CoreTutorialConversationPageCount.homePoints)
        XCTAssertTrue(app.descendants(matching: .any)["coreTutorial.homeStudySummaryIntro"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.descendants(matching: .any)["coreTutorial.homePointsIntro"].exists)
        advanceConversation(in: app, pageCount: CoreTutorialConversationPageCount.homeStudySummary)
        XCTAssertTrue(app.descendants(matching: .any)["coreTutorial.homeStartPrompt"].exists)
        advanceConversation(in: app, pageCount: 1)
        waitForConversationReady(in: app)
        app.buttons["home.startStudy"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["coreTutorial.studyModeIntro"].waitForExistence(timeout: 5))
        sleep(1)
        let fixedTimerElements: [(String, XCUIElement)] = [
            ("mode switcher", app.segmentedControls.firstMatch),
            ("FOCUS", app.staticTexts["FOCUS"]),
            ("25:00", app.staticTexts["25:00"]),
            ("settings", app.buttons["timer.timeSettings"]),
            ("start", app.buttons["timer.startStudy"])
        ]
        for (name, element) in fixedTimerElements {
            XCTAssertTrue(element.exists, "Missing fixed Timer element: \(name)")
        }
        let initialTimerFrames = Dictionary(
            uniqueKeysWithValues: fixedTimerElements.map { ($0.0, $0.1.frame) }
        )
        for second in 1...10 {
            sleep(1)
            for (name, element) in fixedTimerElements {
                guard let initialFrame = initialTimerFrames[name] else {
                    XCTFail("Missing initial frame for \(name)")
                    continue
                }
                XCTAssertEqual(
                    element.frame.minY,
                    initialFrame.minY,
                    accuracy: 1,
                    "\(name) moved vertically after \(second) seconds"
                )
            }
        }
        let studyButtonY = app.buttons["timer.startStudy"].frame.minY
        advanceConversation(in: app, pageCount: CoreTutorialConversationPageCount.studyMode)
        XCTAssertTrue(app.descendants(matching: .any)["coreTutorial.studySettingsIntro"].waitForExistence(timeout: 2))
        sleep(1)
        XCTAssertEqual(app.buttons["timer.startStudy"].frame.minY, studyButtonY, accuracy: 1)
        advanceConversation(in: app, pageCount: CoreTutorialConversationPageCount.studySettings)
        XCTAssertTrue(app.descendants(matching: .any)["coreTutorial.studyStartPrompt"].waitForExistence(timeout: 2))
        sleep(1)
        XCTAssertEqual(app.buttons["timer.startStudy"].frame.minY, studyButtonY, accuracy: 1)
        advanceConversation(in: app, pageCount: 2)
        waitForConversationReady(in: app)
        XCTAssertTrue(app.buttons["timer.startStudy"].exists)
        app.buttons["timer.startStudy"].tap()

        XCTAssertTrue(app.buttons["報酬を見る"].waitForExistence(timeout: 5))
        app.buttons["報酬を見る"].tap()
        XCTAssertTrue(app.buttons["閉じる"].waitForExistence(timeout: 8))
        app.buttons["閉じる"].tap()

        let tapPrompt = app.staticTexts["fishReward.tapPrompt"]
        XCTAssertTrue(tapPrompt.waitForExistence(timeout: 5))
        tapPrompt.tap()
        XCTAssertTrue(app.staticTexts["fishReward.getMessage"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["fishReward.newBadge"].exists)
        app.buttons["fishReward.close"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["coreTutorial.openAquarium"].waitForExistence(timeout: 5))
        advanceConversation(
            in: app,
            pageCount: CoreTutorialConversationPageCount.rewardFollowUp - 1
        )
        XCTAssertTrue(app.descendants(matching: .any)["coreTutorial.aquariumTabPrompt"].waitForExistence(timeout: 3))
        app.buttons["mainTab.aquarium"].tap()
        XCTAssertTrue(app.buttons["aquariumEditor.start"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["図鑑からお気に入りの魚を選んでください"].exists)
        advanceConversation(in: app, pageCount: 2)
        waitForConversationReady(in: app)
        app.buttons["aquariumEditor.start"].tap()
        let editAlert = app.alerts["水槽を編集しますか？"]
        XCTAssertTrue(editAlert.waitForExistence(timeout: 3))
        editAlert.buttons["編集する"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["coreTutorial.ghostHand"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["aquariumEditor.fish.pufferfish"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["aquariumEditor.fish.seahorse"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["aquariumEditor.fish.manta"].exists)
        let clownfishHandle = app.images
            .matching(identifier: "aquariumEditor.fish.clownfish")
            .matching(NSPredicate(format: "label == %@", "クマノミ"))
            .firstMatch
        XCTAssertTrue(clownfishHandle.waitForExistence(timeout: 5))
        let destination = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
            .withOffset(CGVector(dx: 100, dy: clownfishHandle.frame.midY))
        clownfishHandle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.2, thenDragTo: destination)

        XCTAssertTrue(app.descendants(matching: .any)["coreTutorial.savePrompt"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["coreTutorial.ghostHand"].exists)
        advanceConversation(in: app, pageCount: 1)
        waitForConversationReady(in: app)
        app.buttons["aquariumEditor.done"].tap()
        XCTAssertTrue(app.buttons["保存する"].waitForExistence(timeout: 3))
        app.buttons["保存する"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["coreTutorial.returnHome"].waitForExistence(timeout: 5))
        advanceConversation(
            in: app,
            pageCount: CoreTutorialConversationPageCount.aquariumReturnHome - 1
        )
        XCTAssertTrue(app.descendants(matching: .any)["coreTutorial.homeTabPrompt"].waitForExistence(timeout: 3))
        app.buttons["mainTab.home"].tap()
        advanceConversation(in: app, pageCount: CoreTutorialConversationPageCount.finishing)
        XCTAssertTrue(app.buttons["home.startStudy"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["home.dailyFishProgress"].label.contains("0"))
        XCTAssertFalse(app.descendants(matching: .any)["coreTutorial.homeFishIntro"].exists)

        app.terminate()
        app.launchArguments = [
            "-core-tutorial-in-memory",
            "-hasCompletedOnboarding", "YES"
        ]
        app.launch()
        XCTAssertTrue(app.buttons["home.startStudy"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["coreTutorial.homeFishIntro"].exists)
    }

    @MainActor
    func testCoreTutorialPreviewRunsFullFlowWithoutChangingProductionDashboard() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-core-tutorial-in-memory",
            "-hasCompletedOnboarding", "YES",
            "-hasCompletedCoreTutorial", "YES"
        ]
        app.launch()

        let dashboardIDs = [
            "home.dailyFishProgress",
            "home.coinBalance",
            "home.todayStudyMinutes"
        ]
        XCTAssertTrue(app.buttons["home.startStudy"].waitForExistence(timeout: 5))
        let dashboardBeforePreview = dashboardIDs.map {
            app.descendants(matching: .any)[$0].label
        }

        app.buttons["mainTab.more"].tap()
        app.buttons["more.rewardPreview"].tap()
        let previewButton = app.buttons["rewardPreview.coreTutorial"]
        XCTAssertTrue(previewButton.waitForExistence(timeout: 5))
        previewButton.tap()

        XCTAssertTrue(app.descendants(matching: .any)["coreTutorial.homeFishIntro"].waitForExistence(timeout: 5))
        advanceConversation(in: app, pageCount: CoreTutorialConversationPageCount.homeIntro)
        XCTAssertTrue(app.descendants(matching: .any)["coreTutorial.homePointsIntro"].waitForExistence(timeout: 2))
        advanceConversation(in: app, pageCount: CoreTutorialConversationPageCount.homePoints)
        XCTAssertTrue(app.descendants(matching: .any)["coreTutorial.homeStudySummaryIntro"].waitForExistence(timeout: 2))
        advanceConversation(in: app, pageCount: CoreTutorialConversationPageCount.homeStudySummary)
        advanceConversation(in: app, pageCount: 1)
        waitForConversationReady(in: app)
        app.buttons["home.startStudy"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["coreTutorial.studyModeIntro"].waitForExistence(timeout: 5))
        sleep(1)
        let previewStudyButtonY = app.buttons["timer.startStudy"].frame.minY
        advanceConversation(in: app, pageCount: CoreTutorialConversationPageCount.studyMode)
        XCTAssertTrue(app.descendants(matching: .any)["coreTutorial.studySettingsIntro"].waitForExistence(timeout: 2))
        sleep(1)
        XCTAssertEqual(app.buttons["timer.startStudy"].frame.minY, previewStudyButtonY, accuracy: 1)
        advanceConversation(in: app, pageCount: CoreTutorialConversationPageCount.studySettings)
        XCTAssertTrue(app.descendants(matching: .any)["coreTutorial.studyStartPrompt"].waitForExistence(timeout: 2))
        advanceConversation(in: app, pageCount: 2)
        waitForConversationReady(in: app)
        app.buttons["timer.startStudy"].tap()

        XCTAssertTrue(app.buttons["報酬を見る"].waitForExistence(timeout: 5))
        app.buttons["報酬を見る"].tap()
        XCTAssertTrue(app.buttons["閉じる"].waitForExistence(timeout: 5))
        app.buttons["閉じる"].tap()
        let tapPrompt = app.staticTexts["fishReward.tapPrompt"]
        XCTAssertTrue(tapPrompt.waitForExistence(timeout: 5))
        tapPrompt.tap()
        XCTAssertTrue(app.staticTexts["fishReward.getMessage"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["fishReward.newBadge"].exists)
        app.buttons["fishReward.close"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["coreTutorial.openAquarium"].waitForExistence(timeout: 5))
        advanceConversation(
            in: app,
            pageCount: CoreTutorialConversationPageCount.rewardFollowUp - 1
        )
        XCTAssertTrue(app.descendants(matching: .any)["coreTutorial.aquariumTabPrompt"].waitForExistence(timeout: 3))
        tapPresentedButton(in: app, identifier: "mainTab.aquarium")
        advanceConversation(in: app, pageCount: 2)
        waitForConversationReady(in: app)
        app.buttons["aquariumEditor.start"].tap()
        let editAlert = app.alerts["水槽を編集しますか？"]
        XCTAssertTrue(editAlert.waitForExistence(timeout: 3))
        editAlert.buttons["編集する"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["coreTutorial.ghostHand"].waitForExistence(timeout: 5))

        let clownfishHandle = app.images
            .matching(identifier: "aquariumEditor.fish.clownfish")
            .matching(NSPredicate(format: "label == %@", "クマノミ"))
            .firstMatch
        XCTAssertTrue(clownfishHandle.waitForExistence(timeout: 5))
        let destination = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
            .withOffset(CGVector(dx: 100, dy: clownfishHandle.frame.midY))
        clownfishHandle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.2, thenDragTo: destination)

        XCTAssertTrue(app.descendants(matching: .any)["coreTutorial.savePrompt"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["coreTutorial.ghostHand"].exists)
        advanceConversation(in: app, pageCount: 1)
        waitForConversationReady(in: app)
        app.buttons["aquariumEditor.done"].tap()
        XCTAssertTrue(app.buttons["保存する"].waitForExistence(timeout: 3))
        app.buttons["保存する"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["coreTutorial.returnHome"].waitForExistence(timeout: 5))
        advanceConversation(
            in: app,
            pageCount: CoreTutorialConversationPageCount.aquariumReturnHome - 1
        )
        XCTAssertTrue(app.descendants(matching: .any)["coreTutorial.homeTabPrompt"].waitForExistence(timeout: 3))
        tapPresentedButton(in: app, identifier: "mainTab.home")
        advanceConversation(in: app, pageCount: CoreTutorialConversationPageCount.finishing)
        XCTAssertTrue(app.buttons["home.startStudy"].waitForExistence(timeout: 5))
        app.buttons["coreTutorialPreview.exit"].tap()

        XCTAssertTrue(previewButton.waitForExistence(timeout: 5))
        app.buttons["mainTab.home"].tap()
        XCTAssertTrue(app.buttons["home.startStudy"].waitForExistence(timeout: 5))
        XCTAssertEqual(
            dashboardIDs.map { app.descendants(matching: .any)[$0].label },
            dashboardBeforePreview
        )
        XCTAssertFalse(app.descendants(matching: .any)["coreTutorial.homeFishIntro"].exists)

        app.buttons["mainTab.more"].tap()
        XCTAssertTrue(app.buttons["rewardPreview.coreTutorial"].waitForExistence(timeout: 5))
        app.buttons["rewardPreview.coreTutorial"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["coreTutorial.homeFishIntro"].waitForExistence(timeout: 5))
        app.buttons["coreTutorialPreview.exit"].tap()
        XCTAssertTrue(app.buttons["rewardPreview.coreTutorial"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testRewardFishAndGlowShareTheScreenCenter() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-reward-layout-debug")
        launchReturningUser(app)
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
        launchReturningUser(app)

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
        launchReturningUser(app)

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
        launchReturningUser(app)

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
        launchReturningUser(app)
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

    @MainActor
    private func tapPresentedButton(
        in app: XCUIApplication,
        identifier: String,
        timeout: TimeInterval = 3
    ) {
        let query = app.buttons.matching(identifier: identifier)
        let deadline = Date().addingTimeInterval(timeout)

        repeat {
            let count = query.count
            if count > 0 {
                // Previewは本番画面の上にMainTabViewを表示するため同じidentifierが2つある。
                // accessibility treeの末尾にある、前面Preview側の実Button座標をtapする。
                let button = query.element(boundBy: count - 1)
                button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                return
            }
            Thread.sleep(forTimeInterval: 0.1)
        } while Date() < deadline

        XCTFail("No presented button found for \(identifier)")
    }

    @MainActor
    private func advanceConversation(in app: XCUIApplication, pageCount: Int) {
        for _ in 0..<pageCount {
            let card = waitForConversationReady(in: app)
            card.tap()
            Thread.sleep(forTimeInterval: 0.22)
        }
    }

    @MainActor
    @discardableResult
    private func waitForConversationReady(in app: XCUIApplication) -> XCUIElement {
        // Spotlightのstep要素が会話カードのaccessibility valueを持つため、
        // 固定identifierではなく会話状態で現在のカードを取得する。
        let card = app.descendants(matching: .any)
            .matching(NSPredicate(
                format: "identifier BEGINSWITH %@ AND (value == %@ OR value == %@)",
                "coreTutorial.",
                "入力中",
                "全文表示済み"
            ))
            .firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        let ready = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "全文表示済み"),
            object: card
        )
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 4), .completed)
        return card
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
