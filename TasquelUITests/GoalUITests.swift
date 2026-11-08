import XCTest

/// Goal setup with a unit, the goal row and its steps, closing the keyboard, and list tasks, using
/// throwaway app data (`-isolatedData`).
final class GoalUITests: XCTestCase {
    /// Launches with throwaway data and skips onboarding.
    @MainActor
    private func launchFresh(_ extraArguments: [String] = []) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-isolatedData"] + extraArguments
        app.launch()
        if app.staticTexts["Welcome to Tasquel"].waitForExistence(timeout: 3) {
            app.buttons["Next"].tap()
            app.buttons["Next"].tap()
            app.buttons["Next"].tap()
            app.buttons["Next"].tap()
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
    func testTimeGoalStepsAndKeyboardDone() throws {
        let app = launchFresh()

        let work = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Work,")).firstMatch
        XCTAssertTrue(work.waitForExistence(timeout: 5))
        work.tap()

        // Add a task and make it a goal.
        let addTask = app.addTaskField
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

        // While the keyboard is up, the bottom bar becomes a Done button that closes it,
        // and sets the typed target rather than leaving it unsaved in the field.
        targetHours.tap()
        targetHours.typeText("2")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["Settings"].exists, "bottom bar hidden while typing")
        app.buttons["Done"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 2), "Done closes the keyboard")
        XCTAssertTrue(app.staticTexts["0m / 2h"].waitForExistence(timeout: 3), "Done set the goal")
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 2), "bottom bar returns")

        // + adds a step (15 minutes toward a 2-hour goal), − takes one back.
        let plus = app.buttons["Add 15 minutes"]
        XCTAssertTrue(plus.waitForExistence(timeout: 2))
        for _ in 0..<3 { plus.tap() }
        XCTAssertTrue(app.staticTexts["45m / 2h"].waitForExistence(timeout: 2))
        app.buttons["Remove 15 minutes"].tap()
        XCTAssertTrue(app.staticTexts["30m / 2h"].waitForExistence(timeout: 2))
        plus.tap()
        XCTAssertTrue(app.staticTexts["45m / 2h"].waitForExistence(timeout: 2))

        // Swiping down into the keyboard also closes it (here in the goal's editor).
        app.buttons["Edit goal"].tap()
        let editHours = app.textFields["Target hours"]
        XCTAssertTrue(editHours.waitForExistence(timeout: 3))
        editHours.tap()
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 3))
        let grid = app.staticTexts["45m / 2h"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        grid.press(forDuration: 0.05, thenDragTo: keyboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8)))
        XCTAssertTrue(keyboard.waitForNonExistence(timeout: 2), "swipe down closes the keyboard")
        app.buttons["Cancel editing goal"].tap()
        XCTAssertTrue(editHours.waitForNonExistence(timeout: 2))

        // Adding a task below the goal: its options stay clear of the Done button, scrolling
        // up keeps the keyboard open, and choosing a type adds the task.
        let addTask2 = app.addTaskField
        addTask2.tap()
        addTask2.typeText("Stretch")
        XCTAssertTrue(keyboard.waitForExistence(timeout: 2))
        let options = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "New task options")).firstMatch
        XCTAssertTrue(options.waitForExistence(timeout: 2))
        let done = app.buttons["Done"]
        XCTAssertLessThan(options.frame.maxY, done.frame.minY, "Done must not cover the new task's options")

        options.tap()
        app.buttons["Repeating"].firstMatch.tap()
        app.buttons["Add Task"].tap()
        XCTAssertTrue(app.staticTexts["Stretch"].waitForExistence(timeout: 3), "Add Task adds it")
        XCTAssertTrue(app.buttons["Task options: Checkbox, Repeating"].exists)

        // Last: scrolling up can carry the card under the header bar, where a tap meant for
        // it lands on the bar instead.
        let header = app.staticTexts["Work"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        header.press(forDuration: 0.05, thenDragTo: header.withOffset(CGVector(dx: 0, dy: -120)))
        XCTAssertTrue(keyboard.exists, "scrolling up keeps the keyboard open")
    }

    /// A repeating list: picking List in the new-task options goes straight to its first item, Return
    /// adds each item and keeps the keyboard up, and checking every item checks the list.
    @MainActor
    func testListAddsItemsAndChecksItself() throws {
        let app = launchFresh()
        let errands = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Errands,")).firstMatch
        XCTAssertTrue(errands.waitForExistence(timeout: 5))
        errands.tap()

        let addTask = app.addTaskField
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
        XCTAssertTrue(app.buttons["Complete Groceries"].exists)
        app.buttons["Complete Eggs"].tap()
        XCTAssertTrue(app.buttons["Complete Groceries"].exists, "one item left")
        app.buttons["Complete Milk"].tap()
        XCTAssertTrue(app.buttons["Mark Groceries incomplete"].waitForExistence(timeout: 2), "checking every item checks the list")
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
        XCTAssertTrue(app.staticTexts["Navigate Weeks"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.state, .runningForeground)
    }

    /// Deleting a card's only task while editing it brings the Add task row straight back,
    /// empty and with the default type and mode.
    @MainActor
    func testDeletingLastTaskEndsCardEditing() throws {
        let app = launchFresh()
        let errands = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Errands,")).firstMatch
        XCTAssertTrue(errands.waitForExistence(timeout: 5))
        errands.tap()
        let addTask = app.addTaskField
        XCTAssertTrue(addTask.waitForExistence(timeout: 3))
        addTask.tap()
        addTask.typeText("Return library books\n")
        app.buttons["Done"].firstMatch.tap()

        app.buttons["Edit Errands"].tap()
        XCTAssertFalse(addTask.exists, "no adding while editing")
        app.buttons["Delete Return library books"].tap()

        XCTAssertTrue(app.addTaskRow.waitForExistence(timeout: 3), "the Add task row is back")
        XCTAssertTrue(app.buttons["Edit Errands"].exists, "the card left edit mode")
        app.addTaskField.tap()
        XCTAssertTrue(app.buttons["New task options: Checkbox, One-Time"].waitForExistence(timeout: 2))
    }

    /// In a card's edit mode a task can be dragged by its handle to a new place.
    @MainActor
    func testReorderTasksByHandle() throws {
        let app = launchFresh()
        let errands = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Errands,")).firstMatch
        XCTAssertTrue(errands.waitForExistence(timeout: 5))
        errands.tap()
        let addTask = app.addTaskField
        XCTAssertTrue(addTask.waitForExistence(timeout: 3))
        addTask.tap()
        for name in ["Alpha", "Bravo", "Charlie"] {
            addTask.typeText(name + "\n")
            usleep(400_000)
        }
        app.buttons["Done"].firstMatch.tap()
        app.buttons["Edit Errands"].tap()

        let alpha = app.buttons["Complete Alpha"]
        let charlie = app.buttons["Complete Charlie"]
        XCTAssertTrue(alpha.waitForExistence(timeout: 2))
        XCTAssertLessThan(alpha.frame.minY, charlie.frame.minY)
        // The handle is for touch only (VoiceOver has Move Up / Move Down), so it isn't in
        // the accessibility tree: it sits just right of the task's Delete button.
        let delete = app.buttons["Delete Alpha"]
        XCTAssertTrue(delete.exists, "edit mode shows delete and the drag handle")
        let handle = delete.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5)).withOffset(CGVector(dx: 12, dy: 0))
        handle.press(forDuration: 1.0, thenDragTo: charlie.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)))
        let moved = NSPredicate { _, _ in alpha.frame.minY > charlie.frame.minY }
        wait(for: [XCTNSPredicateExpectation(predicate: moved, object: nil)], timeout: 5)
    }

    /// Return adds exactly what was typed; Smart Add (where it shows) works out a schedule,
    /// count or list from the words.
    @MainActor
    func testSmartAddWords() throws {
        // The simulator has no Apple Intelligence model: -smartAddRules gives Smart Add the
        // rules it applies after the model (with the model's pause), so this always runs.
        let app = launchFresh(["-smartAddRules"])
        let errands = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Errands,")).firstMatch
        XCTAssertTrue(errands.waitForExistence(timeout: 5))
        errands.tap()
        let addTask = app.addTaskField
        XCTAssertTrue(addTask.waitForExistence(timeout: 3))
        addTask.tap()

        addTask.typeText("read a book every week\n")
        XCTAssertTrue(app.staticTexts["read a book every week"].waitForExistence(timeout: 3), "Return adds it as typed")
        XCTAssertTrue(app.buttons["Task options: Checkbox, One-Time"].exists)

        addTask.typeText("run 3x per week")
        let smartAdd = app.buttons["Smart Add"]
        XCTAssertTrue(smartAdd.waitForExistence(timeout: 2))
        smartAdd.tap()
        XCTAssertTrue(app.staticTexts["Run"].waitForExistence(timeout: 30))
        XCTAssertTrue(app.buttons["Task options: Goal, Repeating"].exists, "3x per week is a repeating goal")
        XCTAssertTrue(app.staticTexts["0/3"].exists)
        // It says what it did, with Undo, which takes the task back entirely: no
        // "Deleted … · Undo" of its own, and nothing left in the field.
        let message = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Added Run")).firstMatch
        XCTAssertTrue(message.waitForExistence(timeout: 2))
        app.buttons["Undo Smart Add"].tap()
        XCTAssertTrue(app.staticTexts["Run"].waitForNonExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Undo delete"].exists)

        addTask.tap()
        addTask.typeText("Groceries: milk, eggs")
        smartAdd.tap()
        XCTAssertTrue(app.staticTexts["milk"].waitForExistence(timeout: 30), "a list with its items")
        XCTAssertTrue(app.staticTexts["eggs"].exists)
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
        XCTAssertTrue(app.buttons["Close Study"].waitForExistence(timeout: 3), "the moved card still opens")
    }

    /// In a card's edit mode nothing can be added, and a sub-task's delete button sits on
    /// the left, away from the task's trash can on the right.
    @MainActor
    func testEditModeHidesAddingAndSeparatesDeletes() throws {
        let app = launchFresh()
        let errands = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Errands,")).firstMatch
        XCTAssertTrue(errands.waitForExistence(timeout: 5))
        errands.tap()
        let addTask = app.addTaskField
        XCTAssertTrue(addTask.waitForExistence(timeout: 3))
        addTask.tap()
        addTask.typeText("Pharmacy\n")
        app.buttons["Add sub-task to Pharmacy"].tap()
        app.textFields["Add sub-task"].typeText("Refill\n")
        app.buttons["Done"].tap()

        app.buttons["Edit Errands"].tap()
        XCTAssertFalse(app.addTaskRow.exists, "no adding tasks in edit mode")
        XCTAssertFalse(app.buttons["Add sub-task to Pharmacy"].exists, "no adding sub-tasks in edit mode")
        let deleteTask = app.buttons["Delete Pharmacy"]
        let deleteSubtask = app.buttons["Delete sub-task Refill"]
        XCTAssertTrue(deleteSubtask.waitForExistence(timeout: 3))
        XCTAssertLessThan(deleteSubtask.frame.maxX, deleteTask.frame.minX - 100, "the two deletes are far apart")

        deleteSubtask.tap()
        XCTAssertFalse(app.staticTexts["Refill"].waitForExistence(timeout: 1))
        XCTAssertTrue(app.staticTexts["Pharmacy"].exists, "the task stays")
        // No confirmation: Undo brings it back.
        app.buttons["Undo delete"].tap()
        XCTAssertTrue(app.staticTexts["Refill"].waitForExistence(timeout: 2), "undo restores the sub-task")

        // One tap on a task's name in edit mode opens the keyboard on it.
        app.staticTexts["Pharmacy"].firstMatch.tap()
        let nameField = app.textFields["Task name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 2), "the keyboard opens on the first tap")
        XCTAssertEqual(nameField.value(forKey: "hasKeyboardFocus") as? Bool, true)
    }

    /// A new goal's + is alone, centered under the bar. The first tap nudges it over to make
    /// room for −, and a quick second tap where + was still adds instead of undoing.
    @MainActor
    func testFirstStepMakesRoomForMinus() throws {
        let app = launchFresh()
        let work = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Work,")).firstMatch
        XCTAssertTrue(work.waitForExistence(timeout: 5))
        work.tap()
        let addTask = app.addTaskField
        XCTAssertTrue(addTask.waitForExistence(timeout: 3))
        addTask.tap()
        addTask.typeText("Read\n")
        sleep(1)  // the new row and the scroll after it have settled
        app.buttons["Task options: Checkbox, One-Time"].firstMatch.tap()
        app.buttons["Goal"].firstMatch.tap()
        dismissPopover(app)
        let targetField = app.textFields["Target"]
        XCTAssertTrue(targetField.waitForExistence(timeout: 3))
        targetField.tap()
        targetField.typeText("10")
        app.buttons["Set"].tap()
        if app.buttons["Done"].exists { app.buttons["Done"].firstMatch.tap() }

        let plus = app.buttons["Add 1"]
        XCTAssertTrue(plus.waitForExistence(timeout: 3))
        sleep(1)
        XCTAssertFalse(app.buttons["Remove 1"].exists, "no − before there's progress")
        let bar = app.progressIndicators.firstMatch.frame
        XCTAssertEqual(plus.frame.midX, bar.midX, accuracy: 1, "+ alone, centered under the bar")
        let before = plus.frame
        // Where + was, on the screen (a coordinate from the element would follow it).
        let spot = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: before.midX, dy: before.midY))
        spot.tap()
        XCTAssertTrue(app.staticTexts["1/10"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Remove 1"].waitForExistence(timeout: 2), "− came in")
        sleep(1)
        XCTAssertGreaterThan(plus.frame.minX, before.minX, "+ moved over for it")
        spot.tap()
        XCTAssertTrue(app.staticTexts["2/10"].waitForExistence(timeout: 3), "a second tap where + was still adds")
    }

    /// The goal's sliders button sits left of the bar (8pt, twice the system one), and the − and + steps
    /// are centered under the bar, together about a third of its width, their tap areas
    /// side by side, and + stays at the target. A six-digit step's pill grows to fit it on one line. The button opens
    /// the editor and closes it again; switching the unit to Time carries the progress
    /// over (1 → 1h).
    @MainActor
    func testGoalRowLayout() throws {
        let app = launchFresh()
        let work = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Work,")).firstMatch
        XCTAssertTrue(work.waitForExistence(timeout: 5))
        work.tap()
        let addTask = app.addTaskField
        XCTAssertTrue(addTask.waitForExistence(timeout: 3))
        addTask.tap()
        addTask.typeText("Read\n")
        sleep(1)  // the new row and the scroll after it have settled
        app.buttons["Task options: Checkbox, One-Time"].firstMatch.tap()
        app.buttons["Goal"].firstMatch.tap()
        dismissPopover(app)
        let targetField = app.textFields["Target"]
        XCTAssertTrue(targetField.waitForExistence(timeout: 3))
        targetField.tap()
        targetField.typeText("10")
        app.buttons["Set"].tap()
        if app.buttons["Done"].exists { app.buttons["Done"].firstMatch.tap() }

        let plus = app.buttons["Add 1"]
        XCTAssertTrue(plus.waitForExistence(timeout: 3))
        plus.tap()
        let minus = app.buttons["Remove 1"]
        XCTAssertTrue(minus.waitForExistence(timeout: 3))
        sleep(1)
        let bar = app.progressIndicators.firstMatch.frame
        let editGoal = app.buttons["Edit goal"]
        XCTAssertEqual(bar.height, 8, accuracy: 0.5, "twice the system bar's height")
        XCTAssertLessThan(editGoal.frame.midX, bar.minX, "the button is left of the bar")
        XCTAssertEqual(editGoal.frame.midY, bar.midY, accuracy: 1, "in line with it")
        XCTAssertGreaterThan(minus.frame.midY, bar.maxY, "the steps are under the bar")
        let steps = minus.frame.union(plus.frame)
        XCTAssertEqual(steps.midX, bar.midX, accuracy: 1, "centered under the bar")
        // The frames include the tap areas, 16pt out on each side.
        XCTAssertEqual((steps.width - 32) / bar.width, 1.0 / 3, accuracy: 0.06, "about a third of the bar")
        XCTAssertLessThanOrEqual(minus.frame.maxX, plus.frame.minX + 0.5, "the tap areas don't overlap")
        XCTAssertFalse(app.buttons["Add progress"].exists)

        editGoal.tap()
        XCTAssertTrue(app.textFields["Target"].waitForExistence(timeout: 3), "the button opens the editor")
        XCTAssertFalse(app.textFields["Progress"].exists, "progress isn't typed in")
        XCTAssertFalse(plus.exists, "the steps hide while editing")
        editGoal.tap()
        XCTAssertTrue(app.textFields["Target"].waitForNonExistence(timeout: 3), "the button closes it again")
        XCTAssertTrue(plus.waitForExistence(timeout: 2))

        let smallPlus = plus.frame
        editGoal.tap()
        let stepField = app.textFields["Auto"].firstMatch
        XCTAssertTrue(stepField.waitForExistence(timeout: 3))
        stepField.tap()
        stepField.typeText("999999")
        app.buttons["Save Goal"].tap()
        let bigPlus = app.buttons["Add 999,999"]
        XCTAssertTrue(bigPlus.waitForExistence(timeout: 3))
        XCTAssertEqual(bigPlus.frame.height, smallPlus.height, accuracy: 1, "still one line")
        XCTAssertGreaterThan(bigPlus.frame.width, smallPlus.width + 20, "the pill grew to fit")
        XCTAssertEqual(app.buttons["Remove 999,999"].frame.union(bigPlus.frame).midX, bar.midX, accuracy: 1, "still centered")

        editGoal.tap()
        app.textFields["Auto"].firstMatch.clearAndType("")
        app.buttons["Goal unit: Quantity"].tap()
        app.buttons["Time"].firstMatch.tap()
        let hours = app.textFields["Target hours"]
        XCTAssertTrue(hours.waitForExistence(timeout: 3))
        hours.clearAndType("3")
        app.buttons["Save Goal"].tap()
        XCTAssertTrue(app.staticTexts["1h / 3h"].waitForExistence(timeout: 3), "the progress came along as 1h")

        // At the target + stays, so the goal can be beaten.
        editGoal.tap()
        app.textFields["Target hours"].clearAndType("1")
        app.buttons["Save Goal"].tap()
        XCTAssertTrue(app.staticTexts["1h / 1h"].waitForExistence(timeout: 3))
        let pastTarget = app.buttons["Add 10 minutes"]
        XCTAssertTrue(pastTarget.waitForExistence(timeout: 2), "+ stays at the target")
        pastTarget.tap()
        XCTAssertTrue(app.staticTexts["1h 10m / 1h"].waitForExistence(timeout: 3), "and counts past it")
    }

    /// One tap on any field in the goal editor opens the keyboard on it.
    @MainActor
    func testEditGoalFieldsFocusOnFirstTap() throws {
        let app = launchFresh()
        let work = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Work,")).firstMatch
        XCTAssertTrue(work.waitForExistence(timeout: 5))
        work.tap()
        let addTask = app.addTaskField
        XCTAssertTrue(addTask.waitForExistence(timeout: 3))
        addTask.tap()
        addTask.typeText("Read\n")
        sleep(1)  // the new row and the scroll after it have settled
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
        // Target and Step ("Auto" until one is set); progress moves by the steps only.
        for label in ["Target", "Auto", "Target"] {
            let field = app.textFields[label].firstMatch
            XCTAssertTrue(field.waitForExistence(timeout: 3))
            field.tap()
            XCTAssertEqual(field.value(forKey: "hasKeyboardFocus") as? Bool, true, "\(label) focuses on the first tap")
        }
        XCTAssertFalse(app.textFields["Progress"].exists, "no Progress field")
        // The amount is selected on focus, so typing replaces it.
        let target = app.textFields["Target"].firstMatch
        target.typeText("3")
        XCTAssertEqual(target.value as? String, "3")
        // A tap just below the box still focuses it.
        let step = app.textFields["Auto"].firstMatch
        step.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 1.1)).tap()
        XCTAssertEqual(step.value(forKey: "hasKeyboardFocus") as? Bool, true)

        // Delete sits left of Save Goal; it can be undone instead of asking first.
        let delete = app.buttons["Delete task"]
        let save = app.buttons["Save Goal"]
        XCTAssertLessThan(delete.frame.maxX, save.frame.minX)
        delete.tap()
        XCTAssertTrue(app.buttons["Undo delete"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["Read more"].waitForExistence(timeout: 1), "the goal is deleted")
    }
}

private extension XCUIElement {
    /// Deletes the field's text, then types `text`.
    func clearAndType(_ text: String) {
        tap()
        let current = (value as? String) ?? ""
        typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count) + text)
    }
}
