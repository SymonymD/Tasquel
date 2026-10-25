//
//  TasquelUITests.swift
//  TasquelUITests
//
//  Created by John Fentner on 2/8/26.
//

import XCTest

final class TasquelUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it's important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExpandingNeighborKeepsFirstCategoryOpen() throws {
        let app = XCUIApplication()
        app.launch()

        if app.staticTexts["Welcome to Tasquel"].waitForExistence(timeout: 3) {
            app.buttons["Next"].tap()
            app.buttons["Next"].tap()
            app.buttons["Next"].tap()
            app.buttons["Next"].tap()
            app.buttons["Let's Go!"].tap()
        }

        let work = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Work,")).firstMatch
        let errands = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Errands,")).firstMatch
        XCTAssertTrue(work.waitForExistence(timeout: 5))
        XCTAssertTrue(errands.waitForExistence(timeout: 5))

        work.tap()
        XCTAssertTrue(errands.waitForExistence(timeout: 5))
        errands.tap()

        XCTAssertFalse(work.exists, "Expanding Errands should leave Work expanded")
        XCTAssertFalse(errands.exists, "Errands should also be expanded")
        let workHeader = app.staticTexts["Work"]
        let errandsHeader = app.staticTexts["Errands"]
        XCTAssertTrue(workHeader.waitForExistence(timeout: 5))
        XCTAssertTrue(errandsHeader.waitForExistence(timeout: 5))
        XCTAssertLessThan(workHeader.frame.midY, errandsHeader.frame.midY,
                          "Work should keep its top row when Errands expands")
    }

    @MainActor
    func testExpandedCategoriesStayOpenAcrossWeeks() throws {
        let app = XCUIApplication()
        app.launch()

        if app.staticTexts["Welcome to Tasquel"].waitForExistence(timeout: 3) {
            app.buttons["Next"].tap()
            app.buttons["Next"].tap()
            app.buttons["Next"].tap()
            app.buttons["Next"].tap()
            app.buttons["Let's Go!"].tap()
        }

        let work = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Work,")).firstMatch
        let errands = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Errands,")).firstMatch
        XCTAssertTrue(work.waitForExistence(timeout: 5))
        XCTAssertTrue(errands.waitForExistence(timeout: 5))
        work.tap()
        // Let Work finish opening: Errands slides to a new row, and tapping it
        // mid-slide can land where it used to be.
        XCTAssertTrue(app.buttons["Close Work"].waitForExistence(timeout: 5))
        let settled = expectation(for: NSPredicate(format: "isHittable == true"), evaluatedWith: errands)
        wait(for: [settled], timeout: 5)
        errands.tap()
        XCTAssertFalse(work.exists)
        XCTAssertFalse(errands.exists)

        app.buttons["Next week"].tap()
        XCTAssertTrue(app.staticTexts["Work"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Errands"].waitForExistence(timeout: 5))
        XCTAssertFalse(work.exists, "Work should remain expanded in the following week")
        XCTAssertFalse(errands.exists, "Errands should remain expanded in the following week")
        XCTAssertLessThan(app.staticTexts["Work"].frame.midY, app.staticTexts["Errands"].frame.midY)

        app.buttons["Previous week"].tap()
        XCTAssertTrue(app.staticTexts["Work"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Errands"].waitForExistence(timeout: 5))
        XCTAssertFalse(work.exists, "Work should still be expanded after returning")
        XCTAssertFalse(errands.exists, "Errands should still be expanded after returning")
    }

    /// Regression: the see-through bottom bar let taps fall through to the grid,
    /// so Settings and Edit did nothing.
    @MainActor
    func testBottomBarButtonsRespond() throws {
        let app = XCUIApplication()
        app.launch()

        if app.staticTexts["Welcome to Tasquel"].waitForExistence(timeout: 3) {
            app.buttons["Next"].tap()
            app.buttons["Next"].tap()
            app.buttons["Next"].tap()
            app.buttons["Next"].tap()
            app.buttons["Let's Go!"].tap()
        }

        let settingsButton = app.buttons["Settings"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3), "Settings should open")
        app.buttons["Done"].firstMatch.tap()

        let editButton = app.buttons["Edit"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 3))
        editButton.tap()
        XCTAssertTrue(app.staticTexts["Add Category"].waitForExistence(timeout: 3), "Edit mode should show Add Category")
    }

    /// Pulling the grid down past its top and letting go closes every open card; a short
    /// tug doesn't.
    @MainActor
    func testPullDownClosesAllCards() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-isolatedData"]
        app.launch()
        if app.staticTexts["Welcome to Tasquel"].waitForExistence(timeout: 3) { app.buttons["Skip"].tap() }
        let errands = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Errands,")).firstMatch
        let work = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Work,")).firstMatch
        XCTAssertTrue(errands.waitForExistence(timeout: 5))
        errands.tap()
        XCTAssertTrue(app.buttons["Close Errands"].waitForExistence(timeout: 3))
        work.tap()
        XCTAssertTrue(app.buttons["Close Work"].waitForExistence(timeout: 3))

        // Ordinary scrolling, flicking up and back down to the top, leaves them open.
        app.swipeUp()
        app.swipeDown()
        app.swipeDown()
        XCTAssertTrue(app.buttons["Close Errands"].waitForExistence(timeout: 2), "scrolling back to the top doesn't close cards")

        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 0, dy: 40)),
                    withVelocity: .slow, thenHoldForDuration: 0.2)
        XCTAssertTrue(app.buttons["Close Errands"].exists, "a short tug leaves the cards open")

        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 0, dy: 420)),
                    withVelocity: .slow, thenHoldForDuration: 0.3)
        XCTAssertTrue(app.buttons["Close Errands"].waitForNonExistence(timeout: 3), "a long pull closes them all")
        XCTAssertFalse(app.buttons["Close Work"].exists)
    }
    /// When cards fill the screen, a swipe that starts on a card still scrolls (holding a
    /// card still lifts it to move).
    @MainActor
    func testSwipeOnCardsScrolls() throws {
        let app = XCUIApplication()
        // Accessibility text: one card per row, so the cards overfill the screen.
        app.launchArguments = ["-isolatedData", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"]
        app.launch()
        if app.staticTexts["Welcome to Tasquel"].waitForExistence(timeout: 3) {
            let skip = app.buttons["Skip"]
            while !skip.isHittable { app.swipeUp() }
            skip.tap()
        }
        let first = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@ AND label != %@", "Open ", "Open all cards")).firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        let before = first.frame.minY
        first.swipeUp(velocity: .slow)
        let scrolled = NSPredicate { _, _ in first.frame.minY < before - 40 }
        wait(for: [XCTNSPredicateExpectation(predicate: scrolled, object: nil)], timeout: 3)
    }
}
