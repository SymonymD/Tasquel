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

    /// Just this week, beside Completed in the card's edit mode, shows the category is just
    /// this week's, and a carry-over task turns it off.
    @MainActor
    func testCarryOverTaskTurnsThisWeekOnlyOff() throws {
        addThisWeekOnlyCategory("Trip")
        let card = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Trip, just this week")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 3))
        card.tap()

        app.editCard("Trip")
        let chip = app.descendants(matching: .any).matching(identifier: "Just this week chip").firstMatch
        XCTAssertTrue(chip.waitForExistence(timeout: 3))
        XCTAssertEqual(chip.value as? String, "On")
        attachScreenshot("Card edit mode")
        app.buttons["Done editing Trip"].tap()

        let field = app.addTaskField
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
        let field = app.addTaskField
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText("Report")
        app.buttons["New task options: Checkbox, One-Time"].tap()
        app.buttons["Carry Over"].tap()
        app.buttons["Add Task"].tap()
        XCTAssertTrue(app.buttons["Task options: Checkbox, Carry Over"].waitForExistence(timeout: 3))
        app.buttons["keyboard.chevron.compact.down"].tap()

        app.editCard("Work")
        let chip = app.descendants(matching: .any).matching(identifier: "Just this week chip").firstMatch
        XCTAssertTrue(chip.waitForExistence(timeout: 3))
        XCTAssertEqual(chip.value as? String, "Off")
        XCTAssertTrue(app.staticTexts["Just this week would make its carry-over and repeating tasks one-time."].exists)
        chip.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Just this week: it won't come back")).firstMatch
            .waitForExistence(timeout: 3), "on, and its note says what that means")
        XCTAssertEqual(chip.value as? String, "On")
        // The type and mode show outside edit mode (the clock takes their place in it).
        app.buttons["Done editing Work"].tap()
        XCTAssertTrue(app.buttons["Task options: Checkbox, One-Time"].waitForExistence(timeout: 3))
    }

    /// An existing task's picker has a Done button that closes it.
    @MainActor
    func testExistingTaskPickerHasDone() throws {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Work,")).firstMatch.tap()
        let field = app.addTaskField
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
        app.settingsButton("Saved Categories").tap()
        let saved = app.textFields.matching(NSPredicate(format: "value == %@", "Trip")).firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: 3), "Trip is in Saved Categories")
    }

    // MARK: Helpers

    /// Edit ▸ Add Category ▸ Create New Category, a name, Just this week on, Return to add
    /// it; Done closes the sheet and ends Edit.
    @MainActor
    private func addThisWeekOnlyCategory(_ name: String) {
        app.buttons["Edit"].tap()
        let addCard = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Add Category")).firstMatch
        XCTAssertTrue(addCard.waitForExistence(timeout: 3))
        addCard.tap()
        app.buttons["Create New Category"].tap()
        let field = app.textFields["Category name"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.typeText(name)
        let toggle = app.switches.matching(NSPredicate(format: "label BEGINSWITH %@", "Just this week")).firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 3), "beside Add Category in Create New")
        XCTAssertEqual(toggle.value as? String, "0", "off to start")
        toggle.switches.firstMatch.tap()
        field.tap()
        field.typeText("\n")
        app.navigationBars["Add Category"].buttons["Done"].tap()
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
