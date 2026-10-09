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
    static let studyStart = 6
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
        XCTAssertTrue(app.buttons["home.startStudy"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testHomeStudyButtonNavigatesToTimerViewWithinThreeSeconds() {
        let app = XCUIApplication()
        app.launchArguments += ["-core-tutorial-in-memory", "-timerSessionState", ""]
        launchReturningUser(app)

        XCTAssertEqual(app.buttons["home.startStudy"].label, "はじめよう")
        XCTAssertTrue(app.staticTexts["home.dailyMessage"].exists)
        keepScreenshot(app, name: "home-water-surface-entry")

        app.buttons["home.startStudy"].tap()

        XCTAssertTrue(
            app.buttons["timer.startStudy"].waitForExistence(timeout: 3),
            "TimerView should be presented within three seconds of the real Home button tap"
        )
        XCTAssertTrue(app.buttons["START"].exists)
        XCTAssertTrue(app.buttons["ポモドーロ"].exists)
        XCTAssertEqual(app.buttons.matching(identifier: "timer.startStudy").count, 1)
        XCTAssertFalse(app.buttons["一時停止"].exists)
        XCTAssertFalse(app.staticTexts["home.dailyMessage"].exists)
        keepScreenshot(app, name: "unchanged-timer-setup")

        // A single Back returns Home: there is no duplicate destination on the stack.
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["home.startStudy"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["timer.startStudy"].exists)
    }

    @MainActor
    func testCompletedAutomaticPomodoroCanReenterTimerWithoutPop() {
        verifyPomodoroReentry(automatically: true)
    }

    @MainActor
    func testCompletedManualPomodoroCanReenterTimerWithoutPop() {
        verifyPomodoroReentry(automatically: false)
    }

    @MainActor
    private func verifyPomodoroReentry(automatically: Bool) {
        let app = XCUIApplication()
        app.launchArguments += ["-core-tutorial-in-memory", "-pomodoro-navigation-ui-test",
                                "-timerSessionState", "", "-hasShownNotificationIntroduction", "YES",
                                "-pomodoroStudyDuration", "25", "-pomodoroBreakDuration", "5",
                                "-pomodoroSetCount", "2", "-pomodoroAutoStartNextSet", automatically ? "YES" : "NO"]
        launchReturningUser(app)
        app.buttons["home.startStudy"].tap()
        XCTAssertTrue(app.buttons["timer.startStudy"].waitForExistence(timeout: 5))
        app.buttons["timer.startStudy"].tap()
        XCTAssertTrue(app.buttons["一時停止"].waitForExistence(timeout: 5))
        let advance = app.buttons["timer.testCompletePhase"]
        advance.tap() // study1
        if automatically {
            XCTAssertTrue(app.buttons["休憩を終える"].waitForExistence(timeout: 5))
            XCTAssertFalse(app.buttons["報酬を見る"].exists)
        } else {
            finishPomodoroReward(in: app)
            XCTAssertTrue(app.buttons["休憩を終える"].waitForExistence(timeout: 5))
        }
        advance.tap() // break1
        if !automatically {
            let next = app.alerts.buttons["次のセットを始める"]
            XCTAssertTrue(next.waitForExistence(timeout: 5))
            next.tap()
        }
        XCTAssertTrue(app.buttons["一時停止"].waitForExistence(timeout: 5))
        advance.tap() // final study
        finishPomodoroReward(in: app)
        XCTAssertTrue(app.buttons["home.startStudy"].waitForExistence(timeout: 5))
        keepScreenshot(app, name: "pomodoro-ended-\(automatically)")
        app.buttons["home.startStudy"].tap()
        XCTAssertTrue(app.buttons["timer.startStudy"].waitForExistence(timeout: 5))
        // Destination appeared: now prove it remains there beyond delayed callbacks/onAppear.
        let unexpectedPop = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true"), object: app.buttons["home.startStudy"]
        )
        XCTAssertEqual(XCTWaiter.wait(for: [unexpectedPop], timeout: 3), .timedOut)
        XCTAssertTrue(app.buttons["timer.startStudy"].exists)
        XCTAssertFalse(app.buttons["報酬を見る"].exists)
        XCTAssertFalse(app.staticTexts["fishReward.tapPrompt"].exists)
        keepScreenshot(app, name: "pomodoro-reentered-\(automatically)")
    }

    @MainActor
    private func finishPomodoroReward(in app: XCUIApplication) {
        XCTAssertTrue(app.buttons["報酬を見る"].waitForExistence(timeout: 5))
        app.buttons["報酬を見る"].tap()
        let closePoints = app.buttons["閉じる"].firstMatch
        XCTAssertTrue(closePoints.waitForExistence(timeout: 5))
        closePoints.tap()
        let prompt = app.staticTexts["fishReward.tapPrompt"]
        XCTAssertTrue(prompt.waitForExistence(timeout: 5))
        prompt.tap()
        let deadline = Date().addingTimeInterval(60)
        while Date() < deadline {
            let summaryClose = app.buttons["rewardPreview.multipleFish.close"]
            let singleClose = app.buttons["fishReward.close"]
            if summaryClose.exists && summaryClose.isHittable { summaryClose.tap(); return }
            if singleClose.exists && singleClose.isHittable { singleClose.tap(); return }
            let next = app.buttons["タップして次へ"]
            if next.exists && next.isEnabled && next.isHittable { next.tap() }
            Thread.sleep(forTimeInterval: 0.2)
        }
        XCTFail("Reward sequence did not reach its closing action")
    }

    @MainActor
    func testRunningFocusDisplayForAllThreeModes() {
        for mode in ["ポモドーロ", "タイマー", "ストップウォッチ"] {
            let app = XCUIApplication()
            app.launchArguments += ["-core-tutorial-in-memory", "-shore-wave-ui-test", "-hasShownNotificationIntroduction", "YES", "-timerSessionState", ""]
            launchReturningUser(app)
            app.buttons["home.startStudy"].tap()
            XCTAssertTrue(app.buttons["timer.startStudy"].waitForExistence(timeout: 3))
            app.buttons[mode].tap()
            XCTAssertTrue(app.buttons[mode].isSelected)
            XCTAssertEqual(app.buttons["timer.startStudy"].label, "START")
            if mode != "ポモドーロ" {
                XCTAssertFalse(app.descendants(matching: .any)["ポモドーロの進捗"].exists)
            }
            if mode == "ストップウォッチ" {
                XCTAssertEqual(app.staticTexts["timer.timeDisplay"].label, "00:00")
            }
            keepScreenshot(app, name: "start-\(mode)-setup")
            app.buttons["timer.startStudy"].tap()
            let later = app.buttons["あとで"]
            if later.waitForExistence(timeout: 1) { later.tap() }

            let pause = app.buttons["一時停止"]
            let wake = app.descendants(matching: .any)["timer.showControls"].firstMatch
            let time = app.descendants(matching: .any)["timer.timeDisplay"].firstMatch
            XCTAssertTrue(pause.waitForExistence(timeout: 3))
            let pausePosition = app.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: pause.frame.midX, dy: pause.frame.midY))
            let timeFrame = time.frame
            keepScreenshot(app, name: "focus-\(mode)-normal")
            XCTAssertTrue(wake.waitForExistence(timeout: 14))
            // Opacity preserves view identity; XCTest may still report hidden views as existing.
            sleep(1)
            XCTAssertFalse(pause.isHittable)
            XCTAssertTrue(time.exists)
            if mode == "ストップウォッチ" {
                XCTAssertTrue(time.label.hasPrefix("00:"), "Stopwatch must show elapsed time, not a countdown")
            }
            XCTAssertEqual(time.frame.minY, timeFrame.minY, accuracy: 1)
            if mode == "ポモドーロ" {
                XCTAssertFalse(app.descendants(matching: .any)["ポモドーロの進捗"].isHittable)
            }
            keepScreenshot(app, name: "focus-\(mode)-hidden")

            // Wake at exactly the pause button's old location: the same tap must NOT pause.
            pausePosition.tap()
            XCTAssertTrue(wake.waitForNonExistence(timeout: 3))
            XCTAssertTrue(pause.waitForExistence(timeout: 3))
            XCTAssertFalse(app.buttons["再開する"].exists)
            XCTAssertTrue(wake.waitForExistence(timeout: 14))
            // Also wake from the area previously occupied by the bottom tab bar.
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.94)).tap()
            XCTAssertTrue(wake.waitForNonExistence(timeout: 3))
            XCTAssertTrue(pause.waitForExistence(timeout: 3))
            pause.tap()
            XCTAssertTrue(app.buttons["再開する"].waitForExistence(timeout: 3))
            let remainsVisible = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true"), object: wake)
            remainsVisible.isInverted = true
            wait(for: [remainsVisible], timeout: 11)
            XCTAssertTrue(app.buttons["再開する"].exists)
            XCTAssertTrue(app.buttons["終了する"].exists)
            keepScreenshot(app, name: "focus-\(mode)-paused")
            app.buttons["再開する"].tap()
            XCTAssertTrue(pause.waitForExistence(timeout: 3))
            XCTAssertTrue(wake.waitForExistence(timeout: 14))

            // Foreground restoration resets only the display timer, not the session timer.
            if mode == "ポモドーロ" {
                XCUIDevice.shared.press(.home)
                app.activate()
                XCTAssertTrue(pause.waitForExistence(timeout: 3))
                XCTAssertFalse(wake.exists)
                XCTAssertTrue(wake.waitForExistence(timeout: 14))
            }
            wake.tap()
            XCTAssertTrue(wake.waitForNonExistence(timeout: 3))
            XCTAssertTrue(pause.waitForExistence(timeout: 3))
            pause.tap()
            app.buttons["終了する"].tap()
            let endAlert = app.alerts["集中を終了しますか？"]
            XCTAssertTrue(endAlert.waitForExistence(timeout: 3))
            endAlert.buttons["終了する"].tap()
            XCTAssertTrue(app.buttons["報酬を見る"].waitForExistence(timeout: 3))
            XCTAssertFalse(wake.exists)
            app.terminate()
        }
    }

    @MainActor
    func testShoreWaveStartsAndReturnsToRunningUI() {
        let app = XCUIApplication()
        app.launchArguments += ["-core-tutorial-in-memory", "-shore-wave-ui-test", "-hasShownNotificationIntroduction", "YES", "-timerSessionState", ""]
        launchReturningUser(app)
        app.buttons["home.startStudy"].tap()
        XCTAssertTrue(app.buttons["timer.startStudy"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.buttons["timer.startStudy"].label, "START")
        // Keep the setup visible briefly for the simulator recording's before/after comparison.
        sleep(3)
        app.buttons["timer.startStudy"].tap()
        let pause = app.buttons["一時停止"]
        XCTAssertTrue(pause.waitForExistence(timeout: 3))
        let controlsReady = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "hittable == true"), object: pause
        )
        XCTAssertEqual(XCTWaiter.wait(for: [controlsReady], timeout: 3), .completed)
        keepScreenshot(app, name: "shore-wave-running")
        app.terminate()
    }

    @MainActor
    private func keepScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testAcquisitionHistoryEmptyStateFromMore() {
        let app = XCUIApplication()
        launchReturningUser(app)

        app.buttons["mainTab.more"].tap()
        XCTAssertTrue(app.buttons["more.acquisitionHistory"].waitForExistence(timeout: 5))
        app.buttons["more.acquisitionHistory"].tap()

        XCTAssertTrue(app.navigationBars["獲得履歴"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["まだ獲得履歴はありません"].exists)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "acquisition-history-empty"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testStatisticsEndpointLabelsRenderInsideChart() {
        let app = XCUIApplication()
        launchReturningUser(app)

        app.buttons["mainTab.statistics"].tap()
        XCTAssertTrue(app.navigationBars["統計"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["focusPeriodBarChart"].waitForExistence(timeout: 5))

        let monthlyScreenshot = XCTAttachment(screenshot: app.screenshot())
        monthlyScreenshot.name = "statistics-monthly-axis"
        monthlyScreenshot.lifetime = .keepAlways
        add(monthlyScreenshot)

        let dailyButton = app.buttons["日間"]
        XCTAssertTrue(dailyButton.exists)
        dailyButton.tap()
        XCTAssertTrue(app.otherElements["focusPeriodBarChart"].waitForExistence(timeout: 3))

        let dailyScreenshot = XCTAttachment(screenshot: app.screenshot())
        dailyScreenshot.name = "statistics-daily-axis"
        dailyScreenshot.lifetime = .keepAlways
        add(dailyScreenshot)
    }

    @MainActor
    func testStatisticsTapSelectionAndVerticalScrolling() {
        let app = XCUIApplication()
        app.launchArguments.append("-statistics-tap-ui-test")
        launchReturningUser(app)

        app.buttons["mainTab.statistics"].tap()
        XCTAssertTrue(app.navigationBars["統計"].waitForExistence(timeout: 5))

        let chart = app.otherElements["focusPeriodBarChart"].firstMatch
        let selection = app.descendants(matching: .any)["statistics.selectedBucket"]
        XCTAssertTrue(chart.waitForExistence(timeout: 5))

        let calendar = Calendar.current
        let now = Date()
        let day = calendar.component(.day, from: now)
        let month = calendar.component(.month, from: now)
        let dayCount = calendar.range(of: .day, in: .month, for: now)?.count ?? 30
        let monthX = min(
            0.975,
            (36.0 + ((Double(day) - 0.5) / Double(dayCount)) * 306.0) / 342.0
        )

        chart.coordinate(withNormalizedOffset: CGVector(dx: monthX, dy: 0.65)).tap()
        XCTAssertTrue(selection.waitForExistence(timeout: 3))
        XCTAssertTrue(selection.label.contains("\(month)月\(day)日"))
        XCTAssertTrue(selection.label.contains("2時間45分"))

        // 指を離しても固定され、期間切替で解除される。
        XCTAssertTrue(selection.exists)
        app.buttons["日間"].tap()
        XCTAssertFalse(selection.exists)

        chart.coordinate(withNormalizedOffset: CGVector(dx: 0.61, dy: 0.65)).tap()
        XCTAssertTrue(selection.waitForExistence(timeout: 3))
        XCTAssertTrue(selection.label.contains("13時台"))
        XCTAssertTrue(selection.label.contains("2時間15分"))

        chart.coordinate(withNormalizedOffset: CGVector(dx: 0.69, dy: 0.65)).tap()
        XCTAssertTrue(selection.label.contains("15時台"))
        XCTAssertTrue(selection.label.contains("30分"))

        let initialChartY = chart.frame.minY
        chart.swipeUp()
        XCTAssertLessThan(chart.frame.minY, initialChartY)

        let scrollEnd = app.otherElements["statistics.scrollEnd"]
        let tabBar = app.otherElements["mainTab.customTabBar"]
        XCTAssertTrue(scrollEnd.exists)
        XCTAssertTrue(tabBar.exists)
        XCTAssertLessThanOrEqual(scrollEnd.frame.maxY, tabBar.frame.minY)
    }

    @MainActor
    func testStatisticsMonthEndBarsAndSelection() {
        for (month, lastDay) in [(9, 30), (7, 31)] {
            let app = XCUIApplication()
            app.launchArguments.append("-statistics-month-end-\(lastDay)")
            launchReturningUser(app)
            app.buttons["mainTab.statistics"].tap()

            let chart = app.otherElements["focusPeriodBarChart"].firstMatch
            let selection = app.descendants(matching: .any)["statistics.selectedBucket"]
            XCTAssertTrue(chart.waitForExistence(timeout: 5))
            XCTAssertTrue(app.staticTexts["2時間15分"].waitForExistence(timeout: 5))

            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "statistics-month-end-\(lastDay)"
            screenshot.lifetime = .keepAlways
            add(screenshot)

            for day in (lastDay - 2)...lastDay {
                let chartWidth = chart.frame.width
                let x = (36 + Double(day) / Double(lastDay + 1) * (chartWidth - 36))
                    / chartWidth
                chart.coordinate(withNormalizedOffset: CGVector(dx: x, dy: 0.65)).tap()
                XCTAssertTrue(selection.waitForExistence(timeout: 3))
                XCTAssertTrue(selection.label.contains("\(month)月\(day)日"))
                XCTAssertTrue(selection.label.contains("45分"))
            }
            app.terminate()
        }
    }

    @MainActor
    func testCategoryAndColorSheetsCloseBeforeStudyStartsNormally() {
        let app = XCUIApplication()
        launchReturningUser(app)
        app.buttons["home.startStudy"].tap()
        XCTAssertTrue(app.buttons["timer.startStudy"].waitForExistence(timeout: 3))

        app.buttons["timer.focusCategory"].tap()
        XCTAssertTrue(app.navigationBars["集中カテゴリ"].waitForExistence(timeout: 3))
        app.buttons["カテゴリを追加"].tap()
        XCTAssertTrue(app.navigationBars["カテゴリを追加"].waitForExistence(timeout: 3))
        app.buttons["カラーを選択"].tap()
        XCTAssertTrue(app.navigationBars["カラーを選択"].waitForExistence(timeout: 3))
        app.navigationBars["カラーを選択"].buttons["キャンセル"].tap()
        XCTAssertTrue(app.navigationBars["カテゴリを追加"].waitForExistence(timeout: 3))
        app.navigationBars["カテゴリを追加"].buttons["キャンセル"].tap()
        XCTAssertTrue(app.navigationBars["集中カテゴリ"].waitForExistence(timeout: 3))
        app.buttons["読書"].tap()

        XCTAssertTrue(app.buttons["timer.startStudy"].waitForExistence(timeout: 3))
        app.buttons["timer.startStudy"].tap()
        let laterButton = app.buttons["あとで"]
        if laterButton.waitForExistence(timeout: 1) {
            laterButton.tap()
        }
        let pauseButton = app.buttons["一時停止"]
        XCTAssertTrue(pauseButton.waitForExistence(timeout: 3))

        // このテストで開始した永続sessionを次のUI Testへ持ち越さない。
        pauseButton.tap()
        XCTAssertTrue(app.buttons["終了する"].waitForExistence(timeout: 3))
        app.buttons["終了する"].tap()
        let endAlert = app.alerts["集中を終了しますか？"]
        XCTAssertTrue(endAlert.waitForExistence(timeout: 3))
        endAlert.buttons["終了する"].tap()
        XCTAssertTrue(app.buttons["報酬を見る"].waitForExistence(timeout: 3))
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
            XCTAssertFalse(app.buttons["home.startStudy"].exists)
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
        let studyButton = app.buttons["home.startStudy"]
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
        app.launchArguments = ["-core-tutorial-ui-test", "-timerSessionState", ""]
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
        advanceConversation(
            in: app,
            pageCount: CoreTutorialConversationPageCount.studyStart - 1
        )
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

        XCTAssertTrue(app.buttons["aquariumEditor.category.fish"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["aquariumEditor.fish.pufferfish"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["aquariumEditor.fish.seahorse"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["aquariumEditor.fish.manta"].exists)
        let tutorialFish = app.descendants(matching: .any)["aquariumEditor.dragFish.clownfish"]
        XCTAssertTrue(tutorialFish.waitForExistence(timeout: 5))
        tutorialFish.tap()

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
        for _ in 0..<3 where !previewButton.exists {
            app.collectionViews.firstMatch.swipeUp()
        }
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
        advanceConversation(
            in: app,
            pageCount: CoreTutorialConversationPageCount.studyStart - 1
        )
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
        XCTAssertTrue(app.buttons["aquariumEditor.category.fish"].waitForExistence(timeout: 5))

        let tutorialFish = app.descendants(matching: .any)["aquariumEditor.dragFish.clownfish"]
        XCTAssertTrue(tutorialFish.waitForExistence(timeout: 5))
        tutorialFish.tap()

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

        let studyButton = app.buttons["home.startStudy"]
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
        XCTAssertTrue(app.otherElements["focusPeriodBarChart"].exists)

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

        XCTAssertTrue(app.buttons["home.startStudy"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["mainTab.hitShield"].exists)
        app.buttons["home.startStudy"].tap()
        XCTAssertTrue(app.buttons["START"].waitForExistence(timeout: 5))
        app.buttons["START"].tap()

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
        let endAlert = app.alerts["集中を終了しますか？"]
        XCTAssertTrue(endAlert.waitForExistence(timeout: 5))
        endAlert.buttons["終了する"].tap()

        XCTAssertTrue(app.buttons["報酬を見る"].waitForExistence(timeout: 5))
        XCTAssertTrue(hitShield.waitForNonExistence(timeout: 5))
        app.buttons["報酬を見る"].tap()
        XCTAssertTrue(app.staticTexts["0コイン"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["獲得魚なし"].exists)
    }

    @MainActor
    func testFishEditorDragDirectSelectionAndIndividualStorage() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-core-tutorial-in-memory", "-fish-editor-ui-test", "-timerSessionState", ""]
        launchReturningUser(app)
        app.buttons["mainTab.aquarium"].tap()
        app.buttons["aquariumEditor.start"].tap()
        app.alerts["水槽を編集しますか？"].buttons["編集する"].tap()
        XCTAssertFalse(app.descendants(matching: .any)["aquariumEditor.fullScreenLibrary"].exists)
        app.buttons["aquariumEditor.category.fish"].tap()
        let library = app.descendants(matching: .any)["aquariumEditor.fullScreenLibrary"]
        XCTAssertTrue(library.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(library.frame.height, app.frame.height * 0.8)
        app.buttons["aquariumEditor.closeLibrary"].tap()
        app.buttons["aquariumEditor.category.fish"].tap()
        let card = app.buttons["aquariumEditor.dragFish.clownfish"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["水槽 0 / 5"].firstMatch.exists)
        keepScreenshot(app, name: "fish-editor-inventory")
        card.tap()
        keepScreenshot(app, name: "fish-editor-new-fish-appearance")
        XCTAssertFalse(library.exists)
        app.buttons["aquariumEditor.category.background"].tap()
        keepScreenshot(app, name: "editor-full-screen-background-library")
        app.buttons["aquariumEditor.closeLibrary"].tap()
        let fish = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "aquarium.fish.")).firstMatch
        XCTAssertTrue(fish.waitForExistence(timeout: 5))
        fish.tap()
        XCTAssertEqual(fish.value as? String, "選択中")
        let directStore = app.buttons["aquariumEditor.removeSelectedFish"]
        XCTAssertTrue(directStore.waitForExistence(timeout: 5))
        keepScreenshot(app, name: "fish-editor-selected-swimming-fish")
        directStore.tap()
        XCTAssertTrue(directStore.waitForNonExistence(timeout: 5))
        XCTAssertTrue(fish.waitForNonExistence(timeout: 5))
        for _ in 0..<2 {
            app.buttons["aquariumEditor.category.fish"].tap()
            app.buttons["追加する"].tap()
            card.tap()
        }
        let swimming = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "aquarium.fish."))
        XCTAssertEqual(swimming.count, 2)
        app.buttons["aquariumEditor.category.fish"].tap()
        app.buttons["水槽にいる魚"].tap()
        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "aquariumEditor.selectFish."))
        XCTAssertEqual(rows.count, 2)
        let firstID = rows.element(boundBy: 0).identifier.replacingOccurrences(of: "aquariumEditor.selectFish.", with: "")
        let secondID = rows.element(boundBy: 1).identifier.replacingOccurrences(of: "aquariumEditor.selectFish.", with: "")
        rows.element(boundBy: 0).coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.5)).tap()
        XCTAssertFalse(library.exists)
        XCTAssertEqual(app.descendants(matching: .any)["aquarium.fish." + firstID].value as? String, "選択中")
        app.buttons["aquariumEditor.category.fish"].tap()
        rows.element(boundBy: 1).coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.5)).tap()
        XCTAssertEqual(app.descendants(matching: .any)["aquarium.fish." + firstID].value as? String, "")
        XCTAssertEqual(app.descendants(matching: .any)["aquarium.fish." + secondID].value as? String, "選択中")
        XCTAssertFalse(app.buttons["魚一覧に戻る"].exists)
        XCTAssertTrue(directStore.exists)
        keepScreenshot(app, name: "fish-editor-list-selection-glow")
        directStore.tap()
        XCTAssertTrue(app.descendants(matching: .any)["aquarium.fish." + secondID].waitForNonExistence(timeout: 5))
        XCTAssertEqual(swimming.count, 1)
        XCTAssertEqual(app.descendants(matching: .any)["aquarium.fish." + firstID].value as? String, "")
        app.buttons["aquariumEditor.category.fish"].tap()
        app.buttons["aquariumEditor.storeFish." + firstID].tap()
        XCTAssertEqual(swimming.count, 0)
        app.buttons["追加する"].tap()
        XCTAssertTrue(app.staticTexts["水槽 0 / 5"].firstMatch.exists)
        app.buttons["aquariumEditor.closeLibrary"].tap()
        for species in ["manta", "whaleShark"] {
            app.buttons["aquariumEditor.category.fish"].tap()
            app.buttons["追加する"].tap()
            let largeCard = app.buttons["aquariumEditor.dragFish." + species]
            if !largeCard.isHittable { app.swipeUp() }
            XCTAssertTrue(largeCard.isHittable)
            largeCard.tap()
            Thread.sleep(forTimeInterval: 1.1) // 出現演出終了後の輪郭幅を撮影する。
            app.buttons["aquariumEditor.category.fish"].tap()
            app.buttons["水槽にいる魚"].tap()
            rows.firstMatch.tap()
            keepScreenshot(app, name: "fish-editor-selected-" + species)
            directStore.tap()
        }
        app.buttons["aquariumEditor.done"].tap()
        app.buttons["保存する"].tap()
        XCTAssertTrue(app.buttons["aquariumEditor.start"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testBulkStorageConfirmationUndoRedoAndRestart() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-core-tutorial-in-memory", "-fish-editor-ui-test", "-timerSessionState", "",
                                "-hasCompletedOnboarding", "YES", "-hasCompletedCoreTutorial", "YES"]
        app.launch()
        if app.buttons["aquariumEditor.cancel"].waitForExistence(timeout: 2) {
            app.buttons["aquariumEditor.cancel"].tap()
            XCTAssertTrue(app.alerts["編集内容を破棄しますか？"].waitForExistence(timeout: 5))
            app.alerts["編集内容を破棄しますか？"].buttons["変更を破棄"].tap()
        } else { app.buttons["mainTab.aquarium"].tap() }
        app.buttons["aquariumEditor.start"].tap()
        XCTAssertTrue(app.alerts["水槽を編集しますか？"].waitForExistence(timeout: 5))
        app.alerts["水槽を編集しますか？"].buttons["編集する"].tap()
        for _ in 0..<2 {
            app.buttons["aquariumEditor.category.fish"].tap()
            let fish = app.buttons["aquariumEditor.dragFish.clownfish"]
            XCTAssertTrue(fish.waitForExistence(timeout: 5)); fish.tap()
        }
        app.buttons["aquariumEditor.category.fish"].tap()
        app.buttons["水槽にいる魚"].tap()
        let fishRows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "aquariumEditor.selectFish."))
        let fishIDs = Set(fishRows.allElementsBoundByIndex.map(\.identifier))
        XCTAssertEqual(fishIDs.count, 2)
        let fishBulk = app.buttons["aquariumEditor.storeAllFish"]
        fishBulk.tap()
        let fishAlert = app.alerts["魚を全部しまいますか？"]
        XCTAssertTrue(fishAlert.waitForExistence(timeout: 5))
        XCTAssertTrue(fishAlert.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "2匹")).firstMatch.exists)
        fishAlert.buttons["キャンセル"].tap()
        XCTAssertEqual(fishRows.count, 2)
        fishBulk.tap()
        XCTAssertTrue(fishAlert.waitForExistence(timeout: 5))
        fishAlert.buttons["全部しまう"].tap()
        XCTAssertTrue(app.staticTexts["aquariumEditor.emptyFish"].waitForExistence(timeout: 5))
        XCTAssertFalse(fishBulk.isEnabled)
        app.buttons["aquariumEditor.closeLibrary"].tap()
        app.buttons["aquariumEditor.undo"].tap()
        app.buttons["aquariumEditor.category.fish"].tap()
        XCTAssertEqual(Set(fishRows.allElementsBoundByIndex.map(\.identifier)), fishIDs)
        app.buttons["aquariumEditor.closeLibrary"].tap()
        app.buttons["aquariumEditor.redo"].tap()
        app.buttons["aquariumEditor.category.fish"].tap()
        XCTAssertTrue(app.staticTexts["aquariumEditor.emptyFish"].waitForExistence(timeout: 5))
        app.buttons["aquariumEditor.closeLibrary"].tap()
        app.buttons["aquariumEditor.category.decoration"].tap()
        let decoration = app.buttons["aquariumEditor.add.seaweed-a"]
        XCTAssertTrue(decoration.waitForExistence(timeout: 5)); decoration.tap()
        app.buttons["aquariumEditor.category.decoration"].tap()
        app.buttons["配置済み"].tap()
        let placedRows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "aquariumEditor.selectPlaced."))
        let placementIDs = Set(placedRows.allElementsBoundByIndex.map(\.identifier))
        XCTAssertGreaterThan(placementIDs.count, 0)
        let decorationBulk = app.buttons["aquariumEditor.storeAllDecorations"]
        decorationBulk.tap()
        let decorationAlert = app.alerts["装飾を全部しまいますか？"]
        XCTAssertTrue(decorationAlert.waitForExistence(timeout: 5))
        decorationAlert.buttons["キャンセル"].tap()
        XCTAssertEqual(Set(placedRows.allElementsBoundByIndex.map(\.identifier)), placementIDs)
        decorationBulk.tap()
        XCTAssertTrue(decorationAlert.waitForExistence(timeout: 5))
        decorationAlert.buttons["全部しまう"].tap()
        XCTAssertTrue(app.staticTexts["aquariumEditor.emptyDecorations"].waitForExistence(timeout: 5))
        XCTAssertFalse(decorationBulk.isEnabled)
        keepScreenshot(app, name: "bulk-storage-empty-list")
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["aquariumEditor.undo"].waitForExistence(timeout: 5))
        app.buttons["aquariumEditor.undo"].tap()
        app.buttons["aquariumEditor.category.decoration"].tap()
        app.buttons["配置済み"].tap()
        XCTAssertEqual(Set(placedRows.allElementsBoundByIndex.map(\.identifier)), placementIDs)
        app.buttons["aquariumEditor.closeLibrary"].tap()
        app.buttons["aquariumEditor.redo"].tap()
        app.buttons["aquariumEditor.category.decoration"].tap()
        app.buttons["配置済み"].tap()
        XCTAssertTrue(app.staticTexts["aquariumEditor.emptyDecorations"].waitForExistence(timeout: 5))
        app.buttons["aquariumEditor.closeLibrary"].tap()
        app.buttons["aquariumEditor.cancel"].tap()
        XCTAssertTrue(app.alerts["編集内容を破棄しますか？"].waitForExistence(timeout: 5))
        app.alerts["編集内容を破棄しますか？"].buttons["変更を破棄"].tap()
        XCTAssertTrue(app.buttons["aquariumEditor.start"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testAquariumHistoryButtonsPersistRedoAndClearOnCancel() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-core-tutorial-in-memory", "-timerSessionState", ""]
        app.launchArguments += ["-hasCompletedOnboarding", "YES", "-hasCompletedCoreTutorial", "YES"]
        app.launch()
        if app.buttons["aquariumEditor.cancel"].waitForExistence(timeout: 2) {
            app.buttons["aquariumEditor.cancel"].tap()
            XCTAssertTrue(app.alerts["編集内容を破棄しますか？"].waitForExistence(timeout: 5))
            app.alerts["編集内容を破棄しますか？"].buttons["変更を破棄"].tap()
        } else {
            app.buttons["mainTab.aquarium"].tap()
        }
        app.buttons["aquariumEditor.start"].tap()
        XCTAssertTrue(app.alerts["水槽を編集しますか？"].waitForExistence(timeout: 5))
        app.alerts["水槽を編集しますか？"].buttons["編集する"].tap()
        let undo = app.buttons["aquariumEditor.undo"]
        let redo = app.buttons["aquariumEditor.redo"]
        XCTAssertTrue(undo.waitForExistence(timeout: 5))
        XCTAssertFalse(undo.isEnabled)
        XCTAssertFalse(redo.isEnabled)
        app.buttons["aquariumEditor.category.decoration"].tap()
        let seaweed = app.buttons["aquariumEditor.add.seaweed-a"]
        XCTAssertTrue(seaweed.waitForExistence(timeout: 5))
        seaweed.tap()
        XCTAssertTrue(app.buttons["aquariumEditor.openNudge"].waitForExistence(timeout: 5))
        XCTAssertTrue(undo.isEnabled)
        undo.tap()
        XCTAssertFalse(undo.isEnabled)
        XCTAssertTrue(redo.isEnabled)
        app.terminate()
        app.launch()
        XCTAssertTrue(redo.waitForExistence(timeout: 5))
        XCTAssertTrue(redo.isEnabled)
        XCTAssertFalse(undo.isEnabled)
        redo.tap()
        XCTAssertTrue(undo.isEnabled)
        undo.tap()
        app.buttons["aquariumEditor.category.background"].tap()
        app.buttons["深い海"].tap()
        XCTAssertTrue(undo.waitForExistence(timeout: 5))
        XCTAssertFalse(redo.isEnabled)
        keepScreenshot(app, name: "aquarium-history-controls")
        app.buttons["aquariumEditor.cancel"].tap()
        XCTAssertTrue(app.alerts["編集内容を破棄しますか？"].waitForExistence(timeout: 5))
        app.alerts["編集内容を破棄しますか？"].buttons["変更を破棄"].tap()
        XCTAssertTrue(app.buttons["aquariumEditor.start"].waitForExistence(timeout: 5))
        app.buttons["aquariumEditor.start"].tap()
        XCTAssertTrue(app.alerts["水槽を編集しますか？"].waitForExistence(timeout: 5))
        app.alerts["水槽を編集しますか？"].buttons["編集する"].tap()
        XCTAssertTrue(undo.waitForExistence(timeout: 5))
        XCTAssertFalse(undo.isEnabled)
        XCTAssertFalse(redo.isEnabled)
        app.buttons["aquariumEditor.done"].tap()
        XCTAssertTrue(app.buttons["aquariumEditor.start"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testAquariumDraftRestartsAndCancelsWithoutOpeningLibrary() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-core-tutorial-in-memory", "-timerSessionState", ""]
        launchReturningUser(app)
        app.buttons["mainTab.aquarium"].tap()
        // Clear a draft left by an interrupted simulator test.
        if app.buttons["aquariumEditor.cancel"].waitForExistence(timeout: 2) {
            app.buttons["aquariumEditor.cancel"].tap()
            app.alerts["編集内容を破棄しますか？"].buttons["変更を破棄"].tap()
        }
        XCTAssertTrue(app.buttons["aquariumEditor.start"].waitForExistence(timeout: 5))
        app.buttons["aquariumEditor.start"].tap()
        XCTAssertTrue(app.alerts["水槽を編集しますか？"].waitForExistence(timeout: 5))
        app.alerts["水槽を編集しますか？"].buttons["編集する"].tap()
        XCTAssertTrue(app.buttons["aquariumEditor.category.background"].waitForExistence(timeout: 5))
        app.buttons["aquariumEditor.category.background"].tap()
        app.buttons["深い海"].tap()
        XCTAssertTrue(app.buttons["aquariumEditor.cancel"].waitForExistence(timeout: 5))
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.buttons["aquariumEditor.done"].waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["aquariumEditor.done"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["aquariumEditor.fullScreenLibrary"].exists)
        keepScreenshot(app, name: "aquarium-draft-restored")
        app.buttons["aquariumEditor.cancel"].tap()
        let dialog = app.alerts["編集内容を破棄しますか？"]
        XCTAssertTrue(dialog.waitForExistence(timeout: 3))
        dialog.buttons["編集を続ける"].tap()
        XCTAssertTrue(app.buttons["aquariumEditor.done"].exists)
        app.buttons["aquariumEditor.cancel"].tap()
        app.alerts["編集内容を破棄しますか？"].buttons["変更を破棄"].tap()
        XCTAssertTrue(app.buttons["aquariumEditor.start"].waitForExistence(timeout: 5))
        app.terminate()
        launchReturningUser(app)
        app.buttons["mainTab.aquarium"].tap()
        XCTAssertTrue(app.buttons["aquariumEditor.start"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["aquariumEditor.done"].exists)
        app.buttons["aquariumEditor.start"].tap()
        XCTAssertTrue(app.alerts["水槽を編集しますか？"].waitForExistence(timeout: 5))
        app.alerts["水槽を編集しますか？"].buttons["編集する"].tap()
        XCTAssertTrue(app.buttons["aquariumEditor.done"].waitForExistence(timeout: 5))
        app.buttons["aquariumEditor.done"].tap()
        XCTAssertTrue(app.buttons["aquariumEditor.start"].waitForExistence(timeout: 5))
        app.terminate()
        launchReturningUser(app)
    }

    @MainActor
    func testAquariumFullCanvasAddsSelectsMovesAndStoresDecoration() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-core-tutorial-in-memory", "-timerSessionState", ""]
        launchReturningUser(app)
        app.buttons["mainTab.aquarium"].tap()
        app.buttons["aquariumEditor.start"].tap()
        let alert = app.alerts["水槽を編集しますか？"]
        XCTAssertTrue(alert.waitForExistence(timeout: 3))
        alert.buttons["編集する"].tap()
        let library = app.buttons["aquariumEditor.category.decoration"]
        XCTAssertTrue(library.waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["aquariumEditor.panel"].exists)
        XCTAssertFalse(app.buttons["mainTab.home"].isHittable)
        keepScreenshot(app, name: "editor-full-canvas")
        library.tap()
        keepScreenshot(app, name: "editor-full-screen-decoration-library")
        app.buttons["サンゴ"].tap()
        app.swipeUp()
        let coral = app.buttons["aquariumEditor.add.coral_c_pink"]
        XCTAssertTrue(coral.waitForExistence(timeout: 5))
        coral.tap()
        XCTAssertTrue(app.buttons["aquariumEditor.openNudge"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["aquariumEditor.nudge.arrow.up"].exists)
        keepScreenshot(app, name: "editor-compact-selection-menu")
        app.buttons["aquariumEditor.openNudge"].tap()
        XCTAssertTrue(app.buttons["aquariumEditor.nudge.arrow.up"].waitForExistence(timeout: 5))
        XCTAssertFalse(coral.exists)
        let fixedFrame = app.buttons["aquariumEditor.nudge.arrow.up"].frame
        for direction in ["up", "down", "left", "right"] {
            for _ in 0..<12 {
                app.buttons["aquariumEditor.nudge.arrow." + direction].tap()
                let current = app.buttons["aquariumEditor.nudge.arrow.up"].frame
                XCTAssertEqual(current.minY, fixedFrame.minY, accuracy: 0.5)
                XCTAssertEqual(current.minX, fixedFrame.minX, accuracy: 0.5)
            }
        }
        keepScreenshot(app, name: "editor-selected-coral")
        app.buttons["aquariumEditor.closeNudge"].tap()
        XCTAssertFalse(app.buttons["aquariumEditor.nudge.arrow.up"].exists)
        XCTAssertTrue(app.buttons["aquariumEditor.openNudge"].exists)
        let canvas = app.descendants(matching: .any)["aquariumEditor.decorationCanvas"]
        XCTAssertTrue(canvas.exists)
        let newDecoration = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "aquariumEditor.placedDecoration.developer-owned-coral_c_pink")).firstMatch
        let start = newDecoration.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
        let end = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.78))
        start.press(forDuration: 0.1, thenDragTo: end)
        XCTAssertTrue(app.buttons["aquariumEditor.openNudge"].waitForExistence(timeout: 3))
        keepScreenshot(app, name: "editor-dragged-coral")
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.42)).tap()
        XCTAssertFalse(app.buttons["aquariumEditor.nudge.arrow.up"].exists)
        XCTAssertFalse(app.buttons["mainTab.home"].isHittable)
        library.tap()
        app.buttons["配置済み"].tap()
        let saved = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "aquariumEditor.selectPlaced.developer-owned-coral_c_pink")).firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: 5))
        saved.tap()
        XCTAssertTrue(app.buttons["aquariumEditor.removeSelectedDecoration"].waitForExistence(timeout: 5))
        app.buttons["aquariumEditor.removeSelectedDecoration"].tap()
        XCTAssertFalse(app.buttons["aquariumEditor.nudge.arrow.up"].exists)
        app.buttons["aquariumEditor.category.background"].tap()
        XCTAssertTrue(app.buttons["サンゴ礁"].waitForExistence(timeout: 5))
        app.buttons["サンゴ礁"].tap()
        app.buttons["aquariumEditor.done"].tap()
        let save = app.buttons["保存する"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()
        XCTAssertTrue(app.buttons["aquariumEditor.start"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["mainTab.home"].isHittable)
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
        XCTAssertFalse(panel.exists)
        XCTAssertTrue(app.buttons["aquariumEditor.category.fish"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["aquariumEditor.done"].exists)
        XCTAssertFalse(app.buttons["aquariumEditor.help"].exists)
        XCTAssertFalse(homeTab.isHittable)

        Thread.sleep(forTimeInterval: 10.5)
        XCTAssertFalse(panel.exists)
        XCTAssertTrue(app.buttons["aquariumEditor.done"].exists)
        XCTAssertFalse(app.buttons["aquariumEditor.help"].exists)
        XCTAssertFalse(homeTab.isHittable)

        app.buttons["aquariumEditor.done"].tap()
        XCTAssertTrue(editButton.waitForExistence(timeout: 2))
        XCTAssertTrue(homeTab.exists)
        Thread.sleep(forTimeInterval: 4.5)
        XCTAssertFalse(editButton.isHittable)
        XCTAssertFalse(homeTab.isHittable)

        tapSurface.tap()
        XCTAssertTrue(homeTab.waitForExistence(timeout: 2))
        homeTab.tap()
        let studyButton = app.buttons["home.startStudy"]
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
