import XCTest

/// Backgrounding and relaunching mid-task (review 2026-11-15).
final class ReviewEverydayLifecycleTests: ReviewEverydayBase {

    /// Words half-typed in Add Task, then Home and back: nothing is lost (added, or still in
    /// the field), and the card is as it was.
    @MainActor
    func testHalfTypedTaskSurvivesBackground() throws {
        launch()
        openCard("Errands")
        typeTasks(["Bank"])
        let field = app.addTaskField
        field.typeText("Half typed")
        XCUIDevice.shared.press(.home)
        sleep(2)
        app.activate()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 5) || app.keyboards.firstMatch.exists)
        sleep(1)
        let inField = app.textFields.matching(NSPredicate(format: "value == %@", "Half typed")).count
        let added = app.staticTexts["Half typed"].exists
        log("after background: added \(added), in field \(inField), card open \(app.buttons["Close Errands"].exists), keyboard \(app.keyboards.firstMatch.exists)")
        shot("life-01-after-background")
        XCTAssertTrue(added || inField > 0, "the half-typed words aren't lost")
        // Cold relaunch: it was saved.
        relaunch()
        openCard("Errands")
        log("after relaunch: \(taskTitles)")
        XCTAssertTrue(taskTitles.contains("Complete Bank"))
    }

    /// A task's options popup open, then Home and back: the popup and the card's order.
    @MainActor
    func testOptionsOpenAcrossBackground() throws {
        launch()
        openCard("Work")
        typeTasks(["Alpha", "Bravo"])
        keyboardDone()
        options(for: "Bravo").tap()
        XCTAssertTrue(app.staticTexts["DAY"].waitForExistence(timeout: 3))
        app.buttons["Sunday"].tap()  // today: would move Bravo first once closed
        XCUIDevice.shared.press(.home)
        sleep(2)
        app.activate()
        sleep(2)
        log("after background with options open: DAY shown \(app.staticTexts["DAY"].exists), tasks \(taskTitles)")
        shot("life-10-options-after-background")
        if app.buttons["Done"].firstMatch.exists { app.buttons["Done"].firstMatch.tap() }
        sleep(1)
        log("after Done: \(taskTitles)")
        XCTAssertEqual(taskTitles.first, "Complete Bravo", "today's task first once the popup closes")
    }
}
