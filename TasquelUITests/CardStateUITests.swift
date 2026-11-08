import XCTest

/// A card's open state and place after its category is renamed or deleted somewhere other
/// than the card itself.
final class CardStateUITests: XCTestCase {
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

    /// Renaming an open card's category in Settings ▸ Saved Categories keeps the card open,
    /// in its place.
    @MainActor
    func testRenameInSavedCategoriesKeepsCardOpen() throws {
        card("Work").tap()
        XCTAssertTrue(app.buttons["Close Work"].waitForExistence(timeout: 3))
        let workTop = app.buttons["Close Work"].frame.minY

        app.buttons["Settings"].tap()
        app.buttons["Saved Categories"].tap()
        let name = app.textFields.matching(NSPredicate(format: "value == %@", "Work")).firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        name.tap()
        name.doubleTap()  // select the word
        name.typeText("Job\n")
        XCTAssertTrue(app.textFields.matching(NSPredicate(format: "value == %@", "Job")).firstMatch.waitForExistence(timeout: 3))
        app.navigationBars.buttons.element(boundBy: 0).tap()  // back to Settings
        app.buttons["Done"].firstMatch.tap()

        XCTAssertTrue(app.buttons["Close Job"].waitForExistence(timeout: 3), "the renamed card is still open")
        XCTAssertEqual(app.buttons["Close Job"].frame.minY, workTop, accuracy: 2, "in the same place")
    }

    /// A card that was open when Edit began, then deleted, doesn't come back open: not when
    /// Edit ends, and not when a category with its name is added again.
    @MainActor
    func testDeletedOpenCardDoesNotReopen() throws {
        card("Work").tap()
        XCTAssertTrue(app.buttons["Close Work"].waitForExistence(timeout: 3))

        app.buttons["Edit"].tap()
        app.buttons["Delete Work"].tap()
        app.buttons["Delete Category"].tap()
        XCTAssertTrue(card("Work").waitForNonExistence(timeout: 3))
        app.buttons["Done Editing"].tap()
        sleep(1)

        // Nothing is open, so pulling down shows no "close all" hint and opening all works.
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Close ")).firstMatch.exists)

        app.buttons["Edit"].tap()
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Add Category")).firstMatch.tap()
        let saved = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Work")).firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: 3))
        saved.tap()  // adds it and ends Edit
        sleep(2)
        XCTAssertFalse(app.buttons["Close Work"].exists, "Work doesn't come back open by itself")
        XCTAssertTrue(card("Work").exists, "Work is back, closed")
    }

    /// Words typed in Add task are added when the card's edit button is tapped, as they
    /// are however else the keyboard goes away.
    @MainActor
    func testEditButtonKeepsTypedTask() throws {
        card("Errands").tap()
        let field = app.addTaskField
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText("Buy stamps")  // no Return
        let edit = app.buttons["Edit Errands"]
        XCTAssertTrue(edit.waitForExistence(timeout: 3))
        edit.tap()
        XCTAssertTrue(app.staticTexts["Buy stamps"].waitForExistence(timeout: 3), "the typed task was added")
    }

    /// A sub-task typed but not yet added is added when the card's edit button is tapped,
    /// like a typed task.
    @MainActor
    func testEditButtonKeepsTypedSubtask() throws {
        card("Errands").tap()
        let field = app.addTaskField
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText("Milk\n")
        app.buttons["Add sub-task to Milk"].tap()
        let subtask = app.textFields["Add sub-task"]
        XCTAssertTrue(subtask.waitForExistence(timeout: 3))
        subtask.typeText("Oat")  // no Return
        app.buttons["Edit Errands"].tap()
        XCTAssertTrue(app.staticTexts["Oat"].waitForExistence(timeout: 3), "the typed sub-task was added")
        app.buttons["Done editing Errands"].tap()
        XCTAssertFalse(app.textFields.matching(NSPredicate(format: "value == %@", "Oat")).firstMatch.exists,
                       "and isn't left waiting in the field")
    }

    /// A card's own edit mode stays with its week: next week's card isn't left editing
    /// (with no Add task row).
    @MainActor
    func testCardEditModeStaysInItsWeek() throws {
        card("Work").tap()
        let field = app.addTaskField
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText("Report\n")
        app.buttons["Done"].firstMatch.tap()
        app.buttons["Edit Work"].tap()
        XCTAssertTrue(app.buttons["Done editing Work"].waitForExistence(timeout: 3))
        app.buttons["Next week"].tap()
        sleep(2)
        XCTAssertFalse(app.buttons["Done editing Work"].exists, "next week's Work isn't in edit mode")
        XCTAssertTrue(app.addTaskRow.exists, "and can be added to")
    }

    /// Undo from another week goes back to the week of the delete, where the task returns.
    @MainActor
    func testUndoFromAnotherWeekGoesBack() throws {
        card("Work").tap()
        let field = app.addTaskField
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText("Report\n")
        field.typeText("Email\n")
        app.buttons["Done"].firstMatch.tap()
        let week = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Week of")).firstMatch.label
        app.buttons["Edit Work"].tap()
        app.buttons["Delete Report"].tap()
        app.buttons["Done editing Work"].tap()
        app.buttons["Next week"].tap()
        sleep(1)
        let undo = app.buttons["Undo delete"].firstMatch
        XCTAssertTrue(undo.waitForExistence(timeout: 2))
        undo.tap()
        sleep(2)
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Week of")).firstMatch.label, week,
                       "back on the week of the delete")
        XCTAssertTrue(app.staticTexts["Report"].exists, "with the task back")
    }

    /// Renaming a card to a name another card has, with Return, says why it didn't take.
    @MainActor
    func testRenameToTakenNameSaysWhy() throws {
        card("Errands").tap()
        XCTAssertTrue(app.addTaskRow.waitForExistence(timeout: 3))
        let edit = app.buttons["Edit Errands"]
        XCTAssertTrue(edit.waitForExistence(timeout: 3))
        sleep(1)  // the edit button fades in as the card opens
        edit.tap()
        let name = app.textFields["Category name"]
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        name.tap()
        name.doubleTap()  // select the word
        name.typeText("Work\n")
        XCTAssertTrue(app.staticTexts["Another category is already named Work."].waitForExistence(timeout: 2))
        sleep(1)
        XCTAssertTrue(app.staticTexts["Another category is already named Work."].exists, "and the message stays")
    }

    /// A type picked for one task stays picked for the card's next task; the Add task field
    /// says so, so Return holds no surprise.
    @MainActor
    func testAddFieldSaysPickedType() throws {
        card("Fitness").tap()
        let field = app.addTaskField
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        XCTAssertEqual(field.placeholderValue, "Add task")
        field.tap()
        field.typeText("Run")
        app.buttons["New task options: Checkbox, One-Time"].tap()
        app.buttons["Goal"].tap()
        let dismiss = app.otherElements["PopoverDismissRegion"]
        if dismiss.exists { dismiss.tap() }
        field.tap()
        field.typeText("\n")
        XCTAssertTrue(app.buttons["Task options: Goal, One-Time"].waitForExistence(timeout: 3))
        // The new goal took the keyboard for its target, so the empty field folded to its +.
        XCTAssertEqual(app.addTaskField.placeholderValue, "Add goal", "the next task will be a goal, and the field says so")
    }

    /// Return adds each task and keeps the keyboard for the next; typing straight on after
    /// Return loses nothing and adds nothing twice.
    @MainActor
    func testFastTypingAfterReturn() throws {
        card("Errands").tap()
        let field = app.addTaskField
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        // One key at a time (about a quick typist's pace; a single typeText of all four
        // is faster than any person and drops words with or without this field's handling).
        for character in "Alpha\nBravo\nCharlie\nDelta\n" { field.typeText(String(character)) }
        sleep(1)
        let titles = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Complete ")).allElementsBoundByIndex.map(\.label)
        XCTAssertEqual(titles, ["Complete Alpha", "Complete Bravo", "Complete Charlie", "Complete Delta"])
        XCTAssertTrue(app.keyboards.firstMatch.exists, "the keyboard stayed up")
        XCTAssertEqual(field.value as? String ?? "", "Add task", "the field is empty again (its placeholder shows)")
    }

    private func card(_ name: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open \(name),")).firstMatch
    }
}
