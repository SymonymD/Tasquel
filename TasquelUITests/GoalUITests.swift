import XCTest

/// Goal setup with a unit, Add Progress, closing the keyboard, and list tasks, using
/// throwaway app data (`-isolatedData`).
final class GoalUITests: XCTestCase {
    /// Launches with throwaway data and skips onboarding.
    @MainActor
    private func launchFresh() -> XCUIApplication {
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
        return app
    }

    /// Closes a popover by tapping outside it.
    @MainActor
    private func dismissPopover(_ app: XCUIApplication) {
        let region = app.otherElements["PopoverDismissRegion"]
        if region.exists {
            region.tap()
        } else {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.03)).tap()
        }
    }

    @MainActor
    func testTimeGoalAddProgressAndKeyboardDone() throws {
        let app = launchFresh()

        let work = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Work,")).firstMatch
        XCTAssertTrue(work.waitForExistence(timeout: 5))
        work.tap()

        // Add a task and make it a goal.
        let addTask = app.textFields["Add task"]
        XCTAssertTrue(addTask.waitForExistence(timeout: 3))
        addTask.tap()
        addTask.typeText("Practice\n")
        // Return adds a one-time checkbox; the options picker turns it into a goal.
        let optionsButton = app.buttons["Task options: Checkbox, One-Time"].firstMatch
        XCTAssertTrue(optionsButton.waitForExistence(timeout: 3), "Return adds a one-time checkbox")
        optionsButton.tap()
        app.buttons["Goal"].firstMatch.tap()
        dismissPopover(app)

        // Unit menu: Time shows hours and minutes fields.
        let unitMenu = app.buttons["Goal unit: Quantity"]
        XCTAssertTrue(unitMenu.waitForExistence(timeout: 3))
        unitMenu.tap()
        app.buttons["Custom"].firstMatch.tap()
        // "Custom" fits on one line in the menu button.
        let customMenu = app.buttons["Goal unit: Custom"]
        XCTAssertLessThan(customMenu.frame.height, 50, "the unit button stays one line")
        customMenu.tap()
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
        let options = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "New task options")).firstMatch
        XCTAssertTrue(options.waitForExistence(timeout: 2))
        let done = app.buttons["Done"]
        XCTAssertLessThan(options.frame.maxY, done.frame.minY, "Done must not cover the new task's options")

        let header = app.staticTexts["Work"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        header.press(forDuration: 0.05, thenDragTo: header.withOffset(CGVector(dx: 0, dy: -120)))
        XCTAssertTrue(keyboard.exists, "scrolling up keeps the keyboard open")

        options.tap()
        app.buttons["Repeating"].firstMatch.tap()
        app.buttons["Add Task"].tap()
        XCTAssertTrue(app.staticTexts["Stretch"].waitForExistence(timeout: 3), "Add Task adds it")
        XCTAssertTrue(app.buttons["Task options: Checkbox, Repeating"].exists)
    }

    /// A repeating list: picking List in the new-task options goes straight to its first item, Return
    /// adds each item and keeps the keyboard up, and checking every item checks the list.
    @MainActor
    func testListAddsItemsAndChecksItself() throws {
        let app = launchFresh()
        let errands = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Errands,")).firstMatch
        XCTAssertTrue(errands.waitForExistence(timeout: 5))
        errands.tap()

        let addTask = app.textFields["Add task"]
        XCTAssertTrue(addTask.waitForExistence(timeout: 3))
        addTask.tap()
        addTask.typeText("Groceries")
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "New task options")).firstMatch.tap()
        app.buttons["List"].firstMatch.tap()
        app.buttons["Repeating"].firstMatch.tap()
        app.buttons["Add Task"].tap()

        let item = app.textFields["Add item"]
        XCTAssertTrue(item.waitForExistence(timeout: 3))
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 3), "a new list takes the keyboard for its first item")
        item.typeText("Eggs\n")
        XCTAssertTrue(keyboard.waitForExistence(timeout: 2), "Return keeps the keyboard up")
        item.typeText("Milk\n")
        XCTAssertTrue(app.staticTexts["Eggs"].exists)
        XCTAssertTrue(app.staticTexts["Milk"].exists)
        XCTAssertTrue(app.buttons["Task options: List, Repeating"].exists)

        app.buttons["Done"].tap()
        let list = app.buttons["Check Groceries"]
        XCTAssertEqual(list.value as? String, "Unchecked")
        app.buttons["Check Eggs"].tap()
        XCTAssertEqual(list.value as? String, "Unchecked", "one item left")
        app.buttons["Check Milk"].tap()
        XCTAssertEqual(list.value as? String, "Checked", "checking every item checks the list")
    }

    /// Help opens and shows every section (it once indexed past its last section and crashed).
    @MainActor
    func testHelpOpens() throws {
        let app = launchFresh()
        let settings = app.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        settings.tap()
        let help = app.buttons["How to Use Tasquel"]
        XCTAssertTrue(app.buttons["Saved Categories"].waitForExistence(timeout: 3))
        while !help.isHittable { app.swipeUp() }
        help.tap()
        XCTAssertTrue(app.staticTexts["Type and Mode"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.state, .runningForeground)
    }

    /// A closed card can be dragged onto another card's place without edit mode, and still
    /// opens afterwards.
    @MainActor
    func testDragCardToReorder() throws {
        let app = launchFresh()
        let work = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Work,")).firstMatch
        let study = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Study,")).firstMatch
        XCTAssertTrue(study.waitForExistence(timeout: 5))
        XCTAssertLessThan(work.frame.minY, study.frame.minY, "Work starts above Study")

        study.press(forDuration: 1.0, thenDragTo: work)
        let moved = NSPredicate { _, _ in study.frame.minY < work.frame.minY }
        wait(for: [XCTNSPredicateExpectation(predicate: moved, object: nil)], timeout: 5)

        // Dragging sideways onto the neighbor moves the card instead of changing week.
        let week = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Week of")).firstMatch.label
        let fitness = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Fitness,")).firstMatch
        let before = fitness.frame.minX
        // After the first move the second row is Work | Fitness.
        XCTAssertEqual(work.frame.minY, fitness.frame.minY, "Work and Fitness share a row")
        fitness.press(forDuration: 1.0, thenDragTo: work)
        sleep(1)
        XCTAssertNotEqual(fitness.frame.minX, before, "Fitness moved across")
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Week of")).firstMatch.label, week,
                       "a sideways card drag doesn't change week")

        study.tap()
        XCTAssertTrue(app.buttons["Collapse Study"].waitForExistence(timeout: 3), "the moved card still opens")
    }

    /// In a card's edit mode nothing can be added, and a sub-task's delete button sits on
    /// the left, away from the task's trash can on the right.
    @MainActor
    func testEditModeHidesAddingAndSeparatesDeletes() throws {
        let app = launchFresh()
        let errands = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Errands,")).firstMatch
        XCTAssertTrue(errands.waitForExistence(timeout: 5))
        errands.tap()
        let addTask = app.textFields["Add task"]
        XCTAssertTrue(addTask.waitForExistence(timeout: 3))
        addTask.tap()
        addTask.typeText("Pharmacy\n")
        app.buttons["Add sub-task to Pharmacy"].tap()
        app.textFields["Add sub-task"].typeText("Refill\n")
        app.buttons["Done"].tap()

        app.buttons["Edit Errands"].tap()
        XCTAssertFalse(app.textFields["Add task"].exists, "no adding tasks in edit mode")
        XCTAssertFalse(app.buttons["Add sub-task to Pharmacy"].exists, "no adding sub-tasks in edit mode")
        let deleteTask = app.buttons["Delete Pharmacy"]
        let deleteSubtask = app.buttons["Delete sub-task Refill"]
        XCTAssertTrue(deleteSubtask.waitForExistence(timeout: 3))
        XCTAssertLessThan(deleteSubtask.frame.maxX, deleteTask.frame.minX - 100, "the two deletes are far apart")

        deleteSubtask.tap()
        app.buttons["Delete Sub-Task"].tap()
        XCTAssertFalse(app.staticTexts["Refill"].waitForExistence(timeout: 1))
        XCTAssertTrue(app.staticTexts["Pharmacy"].exists, "the task stays")

        // One tap on a task's name in edit mode opens the keyboard on it.
        app.staticTexts["Pharmacy"].firstMatch.tap()
        let nameField = app.textFields["Task name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 2), "the keyboard opens on the first tap")
        XCTAssertEqual(nameField.value(forKey: "hasKeyboardFocus") as? Bool, true)
    }

    /// One tap on any field in the goal editor opens the keyboard on it.
    @MainActor
    func testEditGoalFieldsFocusOnFirstTap() throws {
        let app = launchFresh()
        let work = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Work,")).firstMatch
        XCTAssertTrue(work.waitForExistence(timeout: 5))
        work.tap()
        let addTask = app.textFields["Add task"]
        XCTAssertTrue(addTask.waitForExistence(timeout: 3))
        addTask.tap()
        addTask.typeText("Read\n")
        app.buttons["Task options: Checkbox, One-Time"].firstMatch.tap()
        app.buttons["Goal"].firstMatch.tap()
        dismissPopover(app)
        let targetField = app.textFields["Target"]
        XCTAssertTrue(targetField.waitForExistence(timeout: 3))
        targetField.tap()
        targetField.typeText("10")
        app.buttons["Set"].tap()
        if app.buttons["Done"].exists { app.buttons["Done"].firstMatch.tap() }

        // One tap on the name renames it, outside edit mode too.
        app.staticTexts["Read"].firstMatch.tap()
        let nameField = app.textFields["Task name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))
        XCTAssertEqual(nameField.value(forKey: "hasKeyboardFocus") as? Bool, true)
        nameField.typeText(" more\n")
        XCTAssertTrue(app.staticTexts["Read more"].waitForExistence(timeout: 2))

        app.buttons["Edit goal"].tap()
        for label in ["Target", "Progress", "Target"] {
            let field = app.textFields[label].firstMatch
            XCTAssertTrue(field.waitForExistence(timeout: 3))
            field.tap()
            XCTAssertEqual(field.value(forKey: "hasKeyboardFocus") as? Bool, true, "\(label) focuses on the first tap")
        }
        // The amount is selected on focus, so typing replaces it.
        let progress = app.textFields["Progress"].firstMatch
        progress.tap()
        progress.typeText("3")
        XCTAssertEqual(progress.value as? String, "3")
        // A tap just below the box still focuses it.
        let target = app.textFields["Target"].firstMatch
        target.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 1.1)).tap()
        XCTAssertEqual(target.value(forKey: "hasKeyboardFocus") as? Bool, true)

        // Delete sits left of Save Goal and asks first.
        let delete = app.buttons["Delete"].firstMatch
        let save = app.buttons["Save Goal"]
        XCTAssertLessThan(delete.frame.maxX, save.frame.minX)
        delete.tap()
        app.buttons["Delete Task"].tap()
        XCTAssertFalse(app.staticTexts["Read more"].waitForExistence(timeout: 1), "the goal is deleted")
    }
}
