import XCTest

/// A "This week only" category: kept in Saved Categories, switched on and off from its
/// card's edit mode, and turned off by a carry-over or repeating task. Also the Done
/// button in an existing task's type and mode picker.
final class ThisWeekOnlyUITests: XCTestCase {
    private var app: XCUIApplication!

    @MainActor
    override func setUp() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchArguments = ["-isolatedData"]
        app.launch()
        if app.staticTexts["Welcome to Tasquel"].waitForExistence(timeout: 3) { app.buttons["Skip"].tap() }
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 5))
    }

    /// The switch in the card's edit mode shows the category is this week only, and a
    /// carry-over task turns it off.
    @MainActor
    func testCarryOverTaskTurnsThisWeekOnlyOff() throws {
        addThisWeekOnlyCategory("Trip")
        let card = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Trip, this week only")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 3))
        card.tap()

        app.buttons["Edit Trip"].tap()
        let toggle = app.switches["This week only"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 3))
        XCTAssertEqual(toggle.value as? String, "1")
        attachScreenshot("Card edit mode")
        app.buttons["Done editing Trip"].tap()

        let field = app.textFields["Add task"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText("Pack")
        app.buttons["New task options: Checkbox, One-Time"].tap()
        app.buttons["Carry Over"].tap()
        XCTAssertTrue(app.staticTexts["Carries over, and this card comes back next week"]
            .waitForExistence(timeout: 3))
        let add = app.buttons["Add Task"]
        XCTAssertTrue(add.isHittable, "Add Task fits in the picker")
        attachScreenshot("New task picker")
        add.tap()

        XCTAssertTrue(app.buttons["Task options: Checkbox, Carry Over"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["0 of 1 complete"].waitForExistence(timeout: 3), "no longer this week only")
    }

    /// Turning the switch on makes the card's carry-over task one-time.
    @MainActor
    func testTurningOnMakesTasksOneTime() throws {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Work,")).firstMatch.tap()
        let field = app.textFields["Add task"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText("Report")
        app.buttons["New task options: Checkbox, One-Time"].tap()
        app.buttons["Carry Over"].tap()
        app.buttons["Add Task"].tap()
        XCTAssertTrue(app.buttons["Task options: Checkbox, Carry Over"].waitForExistence(timeout: 3))
        app.buttons["keyboard.chevron.compact.down"].tap()

        app.buttons["Edit Work"].tap()
        let toggle = app.switches["This week only"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 3))
        XCTAssertEqual(toggle.value as? String, "0")
        XCTAssertTrue(app.staticTexts["Turning this on makes its carry-over and repeating tasks one-time."].exists)
        toggle.switches.firstMatch.tap()
        XCTAssertTrue(app.buttons["Task options: Checkbox, One-Time"].waitForExistence(timeout: 3))
        XCTAssertEqual(toggle.value as? String, "1")
    }

    /// An existing task's picker has a Done button that closes it.
    @MainActor
    func testExistingTaskPickerHasDone() throws {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Work,")).firstMatch.tap()
        let field = app.textFields["Add task"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText("Report\n")
        app.buttons["keyboard.chevron.compact.down"].tap()
        let options = app.buttons["Task options: Checkbox, One-Time"]
        XCTAssertTrue(options.waitForExistence(timeout: 3))
        sleep(1)  // the new row slides in; a tap meanwhile can land on the row below
        options.tap()
        let done = app.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 3))
        attachScreenshot("Existing task picker")
        done.tap()
        XCTAssertTrue(app.staticTexts["AFTER THIS WEEK"].waitForNonExistence(timeout: 3), "the picker closed")
    }

    /// A category added for this week only is kept in Saved Categories.
    @MainActor
    func testThisWeekOnlyCategoryIsSaved() throws {
        addThisWeekOnlyCategory("Trip")
        app.buttons["Settings"].tap()
        app.buttons["Saved Categories"].tap()
        let saved = app.textFields.matching(NSPredicate(format: "value == %@", "Trip")).firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: 3), "Trip is in Saved Categories")
    }

    // MARK: Helpers

    /// Edit ▸ Add Category, This week only on, and a new category named `name` (adding it
    /// ends Edit).
    @MainActor
    private func addThisWeekOnlyCategory(_ name: String) {
        app.buttons["Edit"].tap()
        let addCard = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Add Category")).firstMatch
        XCTAssertTrue(addCard.waitForExistence(timeout: 3))
        addCard.tap()
        let toggle = app.switches["This week only"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 3))
        toggle.switches.firstMatch.tap()
        app.buttons["Create New Category"].tap()
        let field = app.textFields["Category name"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.typeText("\(name)\n")
        XCTAssertTrue(app.navigationBars["Add Category"].waitForNonExistence(timeout: 3))
    }

    @MainActor
    private func attachScreenshot(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
