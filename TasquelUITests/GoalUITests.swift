import XCTest

/// Goal setup with a unit, Add Progress, and closing the keyboard, using throwaway
/// app data (`-isolatedData`).
final class GoalUITests: XCTestCase {
    @MainActor
    func testTimeGoalAddProgressAndKeyboardDone() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-isolatedData"]
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
        XCTAssertTrue(work.waitForExistence(timeout: 5))
        work.tap()

        // Add a task and make it a goal.
        let addTask = app.textFields["Add task"]
        XCTAssertTrue(addTask.waitForExistence(timeout: 3))
        addTask.tap()
        addTask.typeText("Practice\n")
        let makeGoal = app.buttons["Make goal task"].firstMatch
        XCTAssertTrue(makeGoal.waitForExistence(timeout: 3))
        makeGoal.tap()

        // Unit menu: Time shows hours and minutes fields.
        let unitMenu = app.buttons["Goal unit: Quantity"]
        XCTAssertTrue(unitMenu.waitForExistence(timeout: 3))
        unitMenu.tap()
        app.buttons["Time"].firstMatch.tap()
        let targetHours = app.textFields["Target hours"]
        XCTAssertTrue(targetHours.waitForExistence(timeout: 3))

        // The number pad's Done button closes the keyboard.
        targetHours.tap()
        targetHours.typeText("2")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 2))
        app.toolbars.buttons["Done"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 2), "Done closes the keyboard")

        app.buttons["Set"].tap()
        XCTAssertTrue(app.staticTexts["0m / 2h"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.textFields["Amount minutes"].exists, "progress entry hidden until Add Progress")

        // Add Progress reveals the entry with the keyboard up; Add hides both.
        app.buttons["Add progress"].tap()
        let amountMinutes = app.textFields["Amount minutes"]
        XCTAssertTrue(amountMinutes.waitForExistence(timeout: 3))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 2), "entry is focused when revealed")
        amountMinutes.tap()
        amountMinutes.typeText("45")
        app.buttons["Add"].tap()
        XCTAssertTrue(app.staticTexts["45m / 2h"].waitForExistence(timeout: 3))
        XCTAssertTrue(amountMinutes.waitForNonExistence(timeout: 2), "entry hides after Add")
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 2), "keyboard closes after Add")
    }
}
