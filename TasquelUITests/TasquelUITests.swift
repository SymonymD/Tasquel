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
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    @MainActor
    func testExpandingNeighborKeepsFirstCategoryOpen() throws {
        let app = XCUIApplication()
        app.launch()

        if app.staticTexts["Welcome to Tasquel"].waitForExistence(timeout: 3) {
            app.buttons["Next"].tap()
            app.buttons["Next"].tap()
            app.buttons["Next"].tap()
            app.buttons["Continue"].tap()
            app.buttons["Skip"].tap()
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
            app.buttons["Continue"].tap()
            app.buttons["Skip"].tap()
            app.buttons["Let's Go!"].tap()
        }

        let work = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Work,")).firstMatch
        let errands = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Errands,")).firstMatch
        XCTAssertTrue(work.waitForExistence(timeout: 5))
        XCTAssertTrue(errands.waitForExistence(timeout: 5))
        work.tap()
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
}
