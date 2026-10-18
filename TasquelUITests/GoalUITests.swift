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
        // Return adds a plain checkbox; the type menu turns it into a goal.
        let typeMenu = app.buttons["Task type: Checkbox"].firstMatch
        XCTAssertTrue(typeMenu.waitForExistence(timeout: 3), "Return adds a Checkbox task")
        typeMenu.tap()
        app.buttons["Goal"].firstMatch.tap()

        // Unit menu: Time shows hours and minutes fields.
        let unitMenu = app.buttons["Goal unit: Quantity"]
        XCTAssertTrue(unitMenu.waitForExistence(timeout: 3))
        unitMenu.tap()
        app.buttons["Time"].firstMatch.tap()
        let targetHours = app.textFields["Target hours"]
        XCTAssertTrue(targetHours.waitForExistence(timeout: 3))

        // While the keyboard is up, the bottom bar becomes a Done button that closes it.
        targetHours.tap()
        targetHours.typeText("2")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["Settings"].exists, "bottom bar hidden while typing")
        app.buttons["Done"].tap()
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
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 2), "bottom bar returns")

        // Swiping down into the keyboard also closes it.
        app.buttons["Add progress"].tap()
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 3))
        let grid = app.staticTexts["45m / 2h"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        grid.press(forDuration: 0.05, thenDragTo: keyboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8)))
        XCTAssertTrue(keyboard.waitForNonExistence(timeout: 2), "swipe down closes the keyboard")

        // Adding a task below the goal: its options stay clear of the Done button, scrolling
        // up keeps the keyboard open, and choosing a type adds the task.
        let addTask2 = app.textFields["Add task"]
        addTask2.tap()
        addTask2.typeText("Stretch")
        XCTAssertTrue(keyboard.waitForExistence(timeout: 2))
        let options = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "New task type")).firstMatch
        XCTAssertTrue(options.waitForExistence(timeout: 2))
        let done = app.buttons["Done"]
        XCTAssertLessThan(options.frame.maxY, done.frame.minY, "Done must not cover the new task's options")

        let header = app.staticTexts["Work"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        header.press(forDuration: 0.05, thenDragTo: header.withOffset(CGVector(dx: 0, dy: -120)))
        XCTAssertTrue(keyboard.exists, "scrolling up keeps the keyboard open")

        options.tap()
        app.buttons["Repeating"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Stretch"].waitForExistence(timeout: 3), "choosing a type adds the task")
        XCTAssertTrue(app.buttons["Task type: Repeating"].exists)
    }
}
