import XCTest

/// A card's Add task row: a + until it's tapped, then the field, with the keyboard.
final class AddTaskUITests: XCTestCase {
    /// + opens the field with the keyboard on it, ready to type; Return keeps it open for
    /// the next task; closing the keyboard with nothing typed folds it back to the +.
    @MainActor
    func testPlusOpensField() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-isolatedData"]
        app.launch()
        if app.staticTexts["Welcome to Tasquel"].waitForExistence(timeout: 3) { app.buttons["Skip"].tap() }
        let fitness = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Fitness,")).firstMatch
        XCTAssertTrue(fitness.waitForExistence(timeout: 5))
        fitness.tap()

        let plus = app.buttons["Add task"]
        let field = app.textFields["Add task"]
        XCTAssertTrue(plus.waitForExistence(timeout: 3), "a + to start with")
        XCTAssertFalse(field.exists, "no field until it's tapped")
        plus.tap()
        XCTAssertTrue(field.waitForExistence(timeout: 1))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 1), "the keyboard comes up with it")
        XCTAssertEqual(field.value(forKey: "hasKeyboardFocus") as? Bool, true, "ready to type")
        XCTAssertFalse(plus.exists)

        field.typeText("Walk\n")
        XCTAssertTrue(app.staticTexts["Walk"].waitForExistence(timeout: 3))
        XCTAssertEqual(field.value(forKey: "hasKeyboardFocus") as? Bool, true, "open for the next task")

        app.buttons["Done"].firstMatch.tap()
        XCTAssertTrue(field.waitForNonExistence(timeout: 3), "empty, it folds back")
        XCTAssertTrue(plus.exists)

        // And opens again.
        plus.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 1))
        XCTAssertEqual(field.value(forKey: "hasKeyboardFocus") as? Bool, true)
    }
}
