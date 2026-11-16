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

        // + adds a step (a day's share of a 2-hour goal, 120 ÷ 7 rounded up: 18 minutes),
        // − takes one back.
        let plus = app.buttons["Add 18 minutes"]
        XCTAssertTrue(plus.waitForExistence(timeout: 2))
        for _ in 0..<3 { plus.tap() }
        XCTAssertTrue(app.staticTexts["54m / 2h"].waitForExistence(timeout: 2))
        app.buttons["Remove 18 minutes"].tap()
        XCTAssertTrue(app.staticTexts["36m / 2h"].waitForExistence(timeout: 2))
        plus.tap()
        XCTAssertTrue(app.staticTexts["54m / 2h"].waitForExistence(timeout: 2))

        // Swiping down into the keyboard also closes it (here in the goal's editor).
        app.buttons["Edit goal"].tap()
        let editHours = app.textFields["Target hours"]
        XCTAssertTrue(editHours.waitForExistence(timeout: 3))
        editHours.tap()
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 3))
        let grid = app.staticTexts["54m / 2h"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
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

    /// Folding a list: its chevron hides the items and the Add Item row (adding what was typed
    /// there first) and shows how many are checked; the list stays folded after a relaunch, and
    /// the chevron opens it again.
    @MainActor
    func testListNameStaysWholeInEditMode() throws {
        // In a card's edit mode a list has five icons (chevron, type, pin, trash, handle);
        // beside them "Groceries" broke as "Grocerie / s". Its icons go under it instead.
        for size in [nil, "UICTContentSizeCategoryXXXL"] as [String?] {
            var arguments = ["-demoData", "-demoFirstCard", "Errands"]
            if let size { arguments += ["-UIPreferredContentSizeCategoryName", size] }
            let app = XCUIApplication()
            app.launchArguments = arguments
            app.launch()
            let open = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Errands,")).firstMatch
            XCTAssertTrue(open.waitForExistence(timeout: 5))
            open.tap()
            let name = app.staticTexts["Groceries"]
            XCTAssertTrue(name.waitForExistence(timeout: 3))
            sleep(1)
            let oneLine = name.frame.height
            app.editCard("Errands")
            XCTAssertTrue(app.buttons["Pin Groceries"].waitForExistence(timeout: 3))
            sleep(1)
            XCTAssertLessThan(name.frame.height, oneLine * 1.5, "Groceries stays on one line (\(size ?? "default size"))")
            app.terminate()
        }
    }

    @MainActor
    func testDuplicatesAreMarkedAndCanBeTakenBack() throws {
        let app = launchFresh(["-isolatedDataID", "dupes-\(UUID().uuidString)"])
        let openErrands = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Errands,")).firstMatch
        XCTAssertTrue(openErrands.waitForExistence(timeout: 5))
        openErrands.tap()
        let addTask = app.addTaskField
        XCTAssertTrue(addTask.waitForExistence(timeout: 3))
        addTask.tap()
        addTask.typeText("Groceries\n")
        Thread.sleep(forTimeInterval: 0.4)
        XCTAssertFalse(app.staticTexts["“Groceries” is already in this card"].exists, "the first one isn't a duplicate")
        addTask.typeText("groceries \n")

        XCTAssertTrue(app.staticTexts["“groceries” is already in this card"].waitForExistence(timeout: 3), "the note says so")
        let marked = app.staticTexts.matching(NSPredicate(format: "value == %@", "duplicate"))
        XCTAssertEqual(marked.count, 2, "both are marked")
        app.buttons["Undo adding groceries"].tap()
        XCTAssertTrue(app.staticTexts["“groceries” is already in this card"].waitForNonExistence(timeout: 3))
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label == %@", "groceries")).count, 0, "the second one is gone")
        XCTAssertEqual(marked.count, 0, "and Groceries isn't marked any more")
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Deleted")).firstMatch.exists,
                       "taking it back isn't a delete to undo")

        // Items in a list.
        addTask.typeText("Bugs")
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "New task options")).firstMatch.tap()
        app.buttons["List"].firstMatch.tap()
        app.buttons["Add Task"].tap()
        let item = app.textFields["Add item"]
        XCTAssertTrue(item.waitForExistence(timeout: 3))
        item.typeText("Crash\n")
        Thread.sleep(forTimeInterval: 0.4)
        item.typeText("Crash\n")
        XCTAssertTrue(app.staticTexts["“Crash” is already in Bugs"].waitForExistence(timeout: 3))
        XCTAssertEqual(marked.count, 2, "both items are marked")
        app.buttons["Undo adding Crash"].tap()
        XCTAssertTrue(app.staticTexts["“Crash” is already in Bugs"].waitForNonExistence(timeout: 3))
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label == %@", "Crash")).count, 1)
        XCTAssertEqual(marked.count, 0)
    }

    /// Clearing a name and pressing Return deletes the task or item, with Undo; closing the
    /// keyboard with Done instead keeps the name.
    @MainActor
    func testClearingANameAndReturnDeletes() throws {
        let app = launchFresh(["-isolatedDataID", "clear-\(UUID().uuidString)"])
        let openErrands = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Errands,")).firstMatch
        XCTAssertTrue(openErrands.waitForExistence(timeout: 5))
        openErrands.tap()
        let addTask = app.addTaskField
        XCTAssertTrue(addTask.waitForExistence(timeout: 3))
        addTask.tap()
        addTask.typeText("Pharmacy\n")
        Thread.sleep(forTimeInterval: 0.4)
        addTask.typeText("Bank\n")
        Thread.sleep(forTimeInterval: 0.4)
        addTask.typeText("Bugs")
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "New task options")).firstMatch.tap()
        app.buttons["List"].firstMatch.tap()
        app.buttons["Add Task"].tap()
        let item = app.textFields["Add item"]
        XCTAssertTrue(item.waitForExistence(timeout: 3))
        item.typeText("Crash\n")
        Thread.sleep(forTimeInterval: 0.4)
        item.typeText("Typo\n")
        app.buttons["Done"].firstMatch.tap()
        sleep(1)

        app.staticTexts["Pharmacy"].tap()
        let nameField = app.textFields["Task name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))
        nameField.clearAndType("\n")
        XCTAssertTrue(app.staticTexts["Pharmacy"].waitForNonExistence(timeout: 2), "the task is deleted")
        XCTAssertTrue(app.staticTexts["Bank"].exists, "the others stay")
        let undo = app.buttons["Undo delete"]
        XCTAssertTrue(undo.waitForExistence(timeout: 2), "with the usual Undo")
        undo.tap()
        XCTAssertTrue(app.staticTexts["Pharmacy"].waitForExistence(timeout: 2), "Undo brings it back")

        app.staticTexts["Crash"].tap()
        let itemField = app.textFields["Item"]
        XCTAssertTrue(itemField.waitForExistence(timeout: 2))
        itemField.clearAndType("\n")
        XCTAssertTrue(app.staticTexts["Crash"].waitForNonExistence(timeout: 2), "the item is deleted")
        XCTAssertTrue(app.staticTexts["Typo"].exists)

        // Emptied, then the keyboard's Done: nothing is deleted, the name stays.
        app.staticTexts["Bank"].tap()
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))
        nameField.clearAndType("")
        app.buttons["Done"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Bank"].waitForExistence(timeout: 2), "Done keeps the name")
    }

    /// A date from the type and mode popup while adding a task (watching someone add a
    /// birthday, 2026-11-14): the calendar opens in the popup, the date shows in its Date
    /// row, a one-time task dated after this week turns Carry Over, and the task added has
    /// the date as its last day.
    @MainActor
    func testDateFromTheOptionsPopup() throws {
        let app = launchFresh(["-isolatedDataID", "date-\(UUID().uuidString)"])
        let openErrands = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Errands,")).firstMatch
        XCTAssertTrue(openErrands.waitForExistence(timeout: 5))
        openErrands.tap()
        let addTask = app.addTaskField
        XCTAssertTrue(addTask.waitForExistence(timeout: 3))
        addTask.tap()
        addTask.typeText("Birthday party")
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "New task options:")).firstMatch.tap()
        let addDate = app.buttons["Add a date"]
        XCTAssertTrue(addDate.waitForExistence(timeout: 3))
        app.buttons["One-Time"].firstMatch.tap()
        addDate.tap()
        XCTAssertTrue(app.staticTexts["Until"].waitForExistence(timeout: 3), "the calendar opens in the popup")

        // Ten days on: after this week.
        let day = Calendar.current.date(byAdding: .day, value: 10, to: Date())!
        if !Calendar.current.isDate(day, equalTo: Date(), toGranularity: .month) { app.buttons["Next month"].tap() }
        app.buttons[day.formatted(.dateTime.weekday(.wide).month(.wide).day())].tap()
        XCTAssertTrue(app.staticTexts["As a One-Time task, it moves to that week."].exists, "the calendar says where it goes")
        app.buttons["Set"].tap()
        XCTAssertTrue(app.staticTexts["Until"].waitForNonExistence(timeout: 3), "back to the options")
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Date: ")).firstMatch.exists, "the calendar says the date")
        // One-time, dated after this week: it goes into its date's week (2026-11-15).
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Moves to the week of ")).firstMatch.exists, "and so does the hint")
        XCTAssertTrue(app.buttons["Add Task"].firstMatch.isHittable, "Add Task stays in the popover, keyboard and all")
        XCTAssertTrue(app.buttons["One-Time"].firstMatch.isSelected, "it stays One-Time")
        // Carry Over keeps it here until then.
        app.buttons["Carry Over"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Carries over until ")).firstMatch.waitForExistence(timeout: 2))
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "date-in-popup"
        shot.lifetime = .keepAlways
        add(shot)

        app.buttons["Add Task"].firstMatch.tap()
        let checkbox = app.buttons.matching(NSPredicate(format: "label == %@ AND value BEGINSWITH %@", "Complete Birthday party", "expires in 10 days")).firstMatch
        XCTAssertTrue(checkbox.waitForExistence(timeout: 3), "added with the date as its last day")

        // The calendar mark after its name opens the date's calendar; Cancel closes it all.
        let mark = app.buttons["Change date of Birthday party"]
        XCTAssertTrue(mark.waitForExistence(timeout: 3), "the mark is a button")
        mark.tap()
        XCTAssertTrue(app.staticTexts["Until"].waitForExistence(timeout: 3), "straight to the calendar")
        app.buttons["Cancel"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Until"].waitForNonExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["DAY"].exists, "closed, not back to the options")

        // A day picked instead takes the date away: a day and a date are one choice.
        let options = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Task options:"))
        let row = app.staticTexts["Birthday party"].frame
        options.allElementsBoundByIndex.min { abs($0.frame.midY - row.midY) < abs($1.frame.midY - row.midY) }!.tap()
        app.buttons["Saturday"].firstMatch.tap()
        app.buttons["Done"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Change day of Birthday party"].waitForExistence(timeout: 3), "a day now, no date")
        XCTAssertFalse(app.buttons["Change date of Birthday party"].exists)
    }

    /// A task given a day stays where it is while its options are open, and moves into place
    /// (tasks with a day first) once they close (it jumped while being chosen; 2026-11-14).
    @MainActor
    func testOrderHoldsWhileOptionsAreOpen() throws {
        let app = launchFresh(["-isolatedDataID", "orderhold-\(UUID().uuidString)"])
        let openErrands = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Errands,")).firstMatch
        XCTAssertTrue(openErrands.waitForExistence(timeout: 5))
        openErrands.tap()
        let addTask = app.addTaskField
        XCTAssertTrue(addTask.waitForExistence(timeout: 3))
        addTask.tap()
        addTask.typeText("Bank\n")
        Thread.sleep(forTimeInterval: 0.4)
        addTask.typeText("Gym\n")
        app.buttons["Done"].firstMatch.tap()
        sleep(1)
        XCTAssertLessThan(app.staticTexts["Bank"].frame.minY, app.staticTexts["Gym"].frame.minY)

        let options = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Task options:"))
        let gym = app.staticTexts["Gym"].frame
        options.allElementsBoundByIndex.min { abs($0.frame.midY - gym.midY) < abs($1.frame.midY - gym.midY) }!.tap()
        app.buttons["Monday"].firstMatch.tap()
        sleep(1)
        XCTAssertLessThan(app.staticTexts["Bank"].frame.minY, app.staticTexts["Gym"].frame.minY, "still below while choosing")
        app.buttons["Done"].firstMatch.tap()
        sleep(1)
        XCTAssertLessThan(app.staticTexts["Gym"].frame.minY, app.staticTexts["Bank"].frame.minY, "first once closed: a task with a day")
    }

    /// A task's date mark tapped while another task's name is being edited: the name saves,
    /// the keyboard closes, then the calendar opens (it opened with the other field still
    /// editable under it; the user, 2026-11-14).
    @MainActor
    func testMarkEndsRenameFirst() throws {
        let app = launchFresh(["-isolatedDataID", "markrename-\(UUID().uuidString)"])
        let openErrands = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Errands,")).firstMatch
        XCTAssertTrue(openErrands.waitForExistence(timeout: 5))
        openErrands.tap()
        let addTask = app.addTaskField
        XCTAssertTrue(addTask.waitForExistence(timeout: 3))
        addTask.tap()
        addTask.typeText("Gifts\n")
        Thread.sleep(forTimeInterval: 0.4)
        addTask.typeText("Bank\n")
        app.buttons["Done"].firstMatch.tap()
        sleep(1)

        // Gifts gets a date from its options: carry-over, so it stays in this week (a one-time
        // task dated after this week goes into its date's week, 2026-11-15).
        let options = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Task options:"))
        let gifts = app.staticTexts["Gifts"].frame
        options.allElementsBoundByIndex.min { abs($0.frame.midY - gifts.midY) < abs($1.frame.midY - gifts.midY) }!.tap()
        app.buttons["Carry Over"].firstMatch.tap()
        app.buttons["Add a date"].tap()
        let day = Calendar.current.date(byAdding: .day, value: 10, to: Date())!
        if !Calendar.current.isDate(day, equalTo: Date(), toGranularity: .month) { app.buttons["Next month"].tap() }
        app.buttons[day.formatted(.dateTime.weekday(.wide).month(.wide).day())].tap()
        app.buttons["Set"].tap()
        app.buttons["Done"].firstMatch.tap()
        sleep(1)

        // Renaming Bank, then Gifts' calendar mark.
        app.staticTexts["Bank"].tap()
        let field = app.textFields["Task name"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.typeText(" run")
        app.buttons["Change date of Gifts"].tap()
        XCTAssertTrue(app.staticTexts["Until"].waitForExistence(timeout: 3), "the calendar opens")
        XCTAssertTrue(app.staticTexts["Bank run"].exists, "the name being edited was saved")
        XCTAssertFalse(field.exists, "its field is gone")
        XCTAssertFalse(app.keyboards.firstMatch.exists, "and the keyboard closed")
        app.buttons["Cancel"].firstMatch.tap()
    }

    /// In a card's edit mode the clock takes the type and mode's place: it sets a task's
    /// last day (a date or a week), shows it, and takes it away again.
    @MainActor
    func testExpirationFromTheClock() throws {
        let app = launchFresh(["-isolatedDataID", "expiry-\(UUID().uuidString)"])
        let openErrands = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Errands,")).firstMatch
        XCTAssertTrue(openErrands.waitForExistence(timeout: 5))
        openErrands.tap()
        let addTask = app.addTaskField
        XCTAssertTrue(addTask.waitForExistence(timeout: 3))
        addTask.tap()
        addTask.typeText("Gifts\n")
        app.buttons["Done"].firstMatch.tap()
        let options = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Task options:")).firstMatch
        XCTAssertTrue(options.waitForExistence(timeout: 3))

        app.editCard("Errands")
        let clock = app.buttons["Expiration Gifts"]
        XCTAssertTrue(clock.waitForExistence(timeout: 3))
        XCTAssertFalse(options.exists, "the clock takes the type and mode's place")
        XCTAssertEqual(clock.label, "Set expiration for Gifts")

        // A date: today, its last day.
        clock.tap()
        XCTAssertTrue(app.staticTexts["Expires"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Set"].isEnabled, "nothing picked yet")
        app.buttons[Date().formatted(.dateTime.weekday(.wide).month(.wide).day())].tap()
        app.buttons["Set"].tap()
        XCTAssertTrue(app.staticTexts["Expires"].waitForNonExistence(timeout: 3))
        XCTAssertEqual(clock.label, "Change expiration of Gifts")
        XCTAssertEqual(clock.value as? String, "expires today")
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label == %@ AND value == %@", "Complete Gifts", "expires today")).firstMatch.exists,
                      "the checkbox says so too")

        // Removed again.
        clock.tap()
        app.buttons["Remove date"].tap()
        XCTAssertTrue(app.staticTexts["Expires"].waitForNonExistence(timeout: 3))
        XCTAssertEqual(clock.label, "Set expiration for Gifts")

        // A week: this one, its last day.
        clock.tap()
        app.buttons["Week"].tap()
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2  // weeks start on Monday
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())!.start
        app.buttons["Week of \(weekStart.formatted(.dateTime.month(.wide).day()))"].tap()
        app.buttons["Set"].tap()
        XCTAssertTrue(app.staticTexts["Expires"].waitForNonExistence(timeout: 3))
        XCTAssertTrue((clock.value as? String)?.hasPrefix("expires") == true)

        app.buttons["Done editing Errands"].tap()
        XCTAssertTrue(options.waitForExistence(timeout: 3), "type and mode are back outside edit mode")
    }

    /// A task's day, picked in its type and mode picker, shows after its name and sorts it.
    /// The day pills at the top take no taps in 1.1 (the day filter waits for 1.2).
    @MainActor
    func testTaskDayAndDayFilter() throws {
        let app = launchFresh(["-isolatedDataID", "days-\(UUID().uuidString)"])
        let openErrands = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Errands,")).firstMatch
        XCTAssertTrue(openErrands.waitForExistence(timeout: 5))
        openErrands.tap()
        let addTask = app.addTaskField
        XCTAssertTrue(addTask.waitForExistence(timeout: 3))
        addTask.tap()
        addTask.typeText("Gym\n")
        Thread.sleep(forTimeInterval: 0.4)
        addTask.typeText("Party\n")
        Thread.sleep(forTimeInterval: 0.4)
        addTask.typeText("Bank\n")
        app.buttons["Done"].firstMatch.tap()
        sleep(1)

        func pickDay(_ title: String, _ day: String) {
            let options = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Task options:"))
            let row = app.staticTexts[title].frame
            let button = options.allElementsBoundByIndex.min { abs($0.frame.midY - row.midY) < abs($1.frame.midY - row.midY) }!
            button.tap()
            XCTAssertTrue(app.staticTexts["DAY"].waitForExistence(timeout: 3), "the picker has a Day row")
            app.buttons[day].tap()
            app.buttons["Done"].firstMatch.tap()
            XCTAssertTrue(app.staticTexts["DAY"].waitForNonExistence(timeout: 3))
            sleep(1)
        }
        pickDay("Party", "Friday")
        pickDay("Gym", "Saturday")
        // "Friday", "today" on a Friday, "Friday, late" after it.
        let partyDay = app.staticTexts["Party"].value as? String ?? ""
        XCTAssertTrue(partyDay.hasPrefix("Friday") || partyDay == "today", "Party's day is said (\(partyDay))")
        XCTAssertLessThan(app.staticTexts["Party"].frame.minY, app.staticTexts["Gym"].frame.minY, "Friday before Saturday")
        XCTAssertLessThan(app.staticTexts["Gym"].frame.minY, app.staticTexts["Bank"].frame.minY, "days before no day")

        XCTAssertFalse(app.buttons["Day Friday"].exists, "the day pills take no taps")
    }

    @MainActor
    func testFoldingAList() throws {
        let arguments = ["-isolatedDataID", "fold-\(UUID().uuidString)"]
        let app = launchFresh(arguments)
        let openErrands = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Errands,")).firstMatch
        XCTAssertTrue(openErrands.waitForExistence(timeout: 5))
        openErrands.tap()

        let addTask = app.addTaskField
        XCTAssertTrue(addTask.waitForExistence(timeout: 3))
        addTask.tap()
        addTask.typeText("Bugs")
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "New task options")).firstMatch.tap()
        app.buttons["List"].firstMatch.tap()
        app.buttons["Add Task"].tap()

        let item = app.textFields["Add item"]
        XCTAssertTrue(item.waitForExistence(timeout: 3))
        item.typeText("Crash\n")
        Thread.sleep(forTimeInterval: 0.4)
        item.typeText("Typo")  // typed, not added yet

        let fold = app.buttons["Fold Bugs"]
        XCTAssertTrue(fold.exists, "a list has a chevron")
        XCTAssertEqual(fold.label, "Collapse list", "a new list starts open")
        fold.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "value == %@", "0 of 2 items checked")).firstMatch.waitForExistence(timeout: 2),
                      "what was typed is added, and the folded list shows its count")
        XCTAssertFalse(app.staticTexts["Crash"].exists, "the items are folded away")
        XCTAssertFalse(app.textFields["Add item"].exists, "and so is Add Item")
        XCTAssertEqual(fold.label, "Expand list")

        // Same storage again (open cards aren't remembered, so open Errands again).
        app.terminate()
        app.launch()
        XCTAssertTrue(openErrands.waitForExistence(timeout: 5))
        openErrands.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "value == %@", "0 of 2 items checked")).firstMatch.waitForExistence(timeout: 3), "still folded after a relaunch")
        XCTAssertFalse(app.staticTexts["Crash"].exists)

        app.buttons["Fold Bugs"].tap()
        XCTAssertTrue(app.staticTexts["Crash"].waitForExistence(timeout: 2), "the chevron opens it again")
        XCTAssertTrue(app.staticTexts["Typo"].exists)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "value == %@", "0 of 2 items checked")).firstMatch.exists, "an open list shows no count")
    }

    /// A long list item takes all the lines it needs, whatever comes after it in the card: with
    /// two more lists below, it was laid out one line tall and cut off ("…passwor…"), and its
    /// rename field showed only the end.
    @MainActor
    func testLongItemWrapsWithListsBelow() throws {
        let app = launchFresh(["-isolatedDataID", "long-item-\(UUID().uuidString)"])
        // A card below two rows of closed ones, as where it was seen.
        let card = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Appointments,")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.tap()

        func addList(_ title: String, items: [String]) {
            let addTask = app.addTaskField
            XCTAssertTrue(addTask.waitForExistence(timeout: 3))
            addTask.tap()
            addTask.typeText(title)
            app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "New task options")).firstMatch.tap()
            app.buttons["List"].firstMatch.tap()
            app.buttons["Add Task"].tap()
            let field = app.textFields["Add item"]
            XCTAssertTrue(field.waitForExistence(timeout: 3))
            for item in items {
                for word in item.split(separator: " ") {
                    field.typeText(word + " ")
                    usleep(120_000)
                }
                field.typeText("\n")
                Thread.sleep(forTimeInterval: 0.4)
            }
            app.buttons["Done"].firstMatch.tap()
        }
        let long = "Hidden tasks (for things like passwords) and now let's test the long text edit thing"
        addList("Ideas", items: ["Cloud", "Watch", "Charts", long, "Voice", "Calendar views"])
        addList("Next", items: ["Points"])
        addList("Later", items: ["Site", "Video", "Posts", "Press"])

        let item = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Hidden tasks")).firstMatch
        let short = app.staticTexts["Cloud"]
        XCTAssertTrue(item.waitForExistence(timeout: 3))
        while !item.isHittable { app.swipeUp(velocity: .slow) }
        XCTAssertGreaterThan(item.frame.height, short.frame.height * 1.5, "the long item wraps onto more lines")
        item.tap()
        let rename = app.textViews["Item"].exists ? app.textViews["Item"] : app.textFields["Item"]
        XCTAssertTrue(rename.waitForExistence(timeout: 2))
        XCTAssertGreaterThan(rename.frame.height, short.frame.height * 1.5, "its rename field shows every line")
    }

    /// Help opens and shows every section (it once indexed past its last section and crashed).
    @MainActor
    func testHelpOpens() throws {
        let app = launchFresh()
        let settings = app.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        settings.tap()
        let help = app.buttons["How to Use Tasquel"]
        XCTAssertTrue(app.buttons["System"].waitForExistence(timeout: 3), "Settings is open")
        _ = app.settingsButton("How to Use Tasquel")
        help.tap()
        // It opens on the questions new users came with; Weeks is the next tab.
        XCTAssertTrue(app.staticTexts["Is there a Someday list?"].waitForExistence(timeout: 3))
        app.buttons["Weeks"].tap()
        XCTAssertTrue(app.staticTexts["Navigate Weeks"].waitForExistence(timeout: 3))
        // In tabs: Cards shows its own entries; a swipe goes to the next tab. Each pill is
        // named as it reads ("Cards", for Voice Control), its section's title the hint.
        app.buttons["Cards"].tap()
        XCTAssertTrue(app.staticTexts["Close All Cards"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["Navigate Weeks"].isHittable, "the first tab's out of view")
        app.staticTexts["Close All Cards"].swipeLeft()
        XCTAssertTrue(app.staticTexts["Smart Add"].waitForExistence(timeout: 3), "Tasks")
        XCTAssertTrue(app.buttons["Tasks"].isSelected)
        XCTAssertEqual(app.state, .runningForeground)
    }

    /// After an update (`-demoWhatsNew`), "What's New?" beside the Tasquel mark opens What's
    /// New; the second time is its last, saying Settings has it, and then it's gone.
    /// Settings ▸ What's New opens it too.
    @MainActor
    func testWhatsNewButtonAndSettings() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-isolatedData", "-demoWhatsNew"]
        app.launch()
        if app.staticTexts["Welcome to Tasquel"].waitForExistence(timeout: 3) { app.buttons["Skip"].tap() }
        let button = app.buttons["What's New?"]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", "Days for Tasks")).firstMatch
            .waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["You can also find this anytime in Settings ▸ Help ▸ What's New."].exists)
        app.buttons["Continue"].tap()
        XCTAssertTrue(button.waitForExistence(timeout: 3), "still there after once")
        button.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "That's the last time")).firstMatch
            .waitForExistence(timeout: 3))
        app.buttons["Continue"].tap()
        XCTAssertTrue(button.waitForNonExistence(timeout: 3), "gone after twice")

        app.buttons["Settings"].tap()
        let row = app.settingsButton("What's New in 1.1")
        row.tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", "Days for Tasks")).firstMatch
            .waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Settings ▸ What's New")).firstMatch.exists,
                       "no note from Settings")
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

        app.editCard("Errands")
        XCTAssertFalse(addTask.exists, "no adding while editing")
        app.buttons["Delete Return library books"].tap()

        XCTAssertTrue(app.addTaskRow.waitForExistence(timeout: 3), "the Add task row is back")
        XCTAssertTrue(app.buttons["Edit Errands"].exists, "the card left edit mode")
        app.addTaskField.tap()
        XCTAssertTrue(app.buttons["New task options: Checkbox, One-Time"].waitForExistence(timeout: 2))
    }

    /// A new task given a day that has gone by this week goes into next week on that day, with
    /// a note saying so and Undo; the field's placeholder says "Next" beforehand (the user's
    /// rule, 2026-11-14: Thursday picked on a Friday means next Thursday).
    @MainActor
    func testDayGoneByAddsToNextWeek() throws {
        // Monday has gone by on every day but Monday (weeks start on Monday here).
        try XCTSkipIf(Calendar(identifier: .gregorian).component(.weekday, from: Date()) == 2, "nothing has gone by on a Monday")
        let app = launchFresh(["-isolatedDataID", "nextweek-\(UUID().uuidString)"])
        let work = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Work,")).firstMatch
        XCTAssertTrue(work.waitForExistence(timeout: 5))
        work.tap()
        let addTask = app.addTaskField
        XCTAssertTrue(addTask.waitForExistence(timeout: 3))
        addTask.tap()
        app.buttons["New task options: Checkbox, One-Time"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["DAY"].waitForExistence(timeout: 3))
        app.buttons["Monday"].tap()
        app.buttons["Done"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["DAY"].waitForNonExistence(timeout: 3))
        // On iPad the options close the keyboard first, and the empty field folds back to its
        // +: open it again (`addTaskField` taps the + when it must).
        let field = app.addTaskField
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        XCTAssertEqual(field.placeholderValue, "Add Task for Next Mon", "the field says where it will go")
        let thisWeek = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Week of")).firstMatch.label

        field.tap()
        field.typeText("Call dentist\n")
        // The screen goes with it to next week, where its note is (2026-11-15: left behind
        // on this week, it seemed to vanish).
        // On a Sunday, Monday is tomorrow, and it's said so (the 2026-11-15 review).
        let isSunday = Calendar(identifier: .gregorian).component(.weekday, from: Date()) == 1
        let note = app.staticTexts[isSunday ? "Tomorrow is in next week, so “Call dentist” is here"
                                            : "Monday had already gone by, so “Call dentist” is here, in next week"]
        XCTAssertTrue(note.waitForExistence(timeout: 5), "next week's card says where it is")
        XCTAssertNotEqual(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Week of")).firstMatch.label,
                          thisWeek, "next week is on screen")
        let dentist = app.staticTexts["Call dentist"]
        XCTAssertTrue(dentist.exists, "the task is there")
        XCTAssertEqual(dentist.value as? String, "Monday", "on Monday, and not late")
        // The bar was away with the keyboard as the week changed; the house still comes out.
        let house = app.buttons.matching(NSPredicate(format: "identifier == %@", "Bar Back to This Week")).firstMatch
        XCTAssertTrue(house.waitForExistence(timeout: 3), "the way back to this week is there")

        // A pop-up says so, where it can't be missed; OK closes it.
        XCTAssertTrue(app.staticTexts["Added to next week"].exists, "the pop-up says where the screen went")
        XCTAssertTrue(app.staticTexts[isSunday ? "Tomorrow is the first day of next week." : "Monday had already gone by this week."].exists)
        app.buttons["Moved OK"].tap()
        XCTAssertTrue(app.staticTexts["Added to next week"].waitForNonExistence(timeout: 3))

        // Undo there takes it back.
        app.buttons["Undo adding Call dentist"].tap()
        XCTAssertTrue(dentist.waitForNonExistence(timeout: 3), "taken back")
    }

    /// While Add Task is in use, a new task stays just above the field (by its note), even
    /// one whose day puts it first; once the keyboard goes it moves into place ("Call mom
    /// Sunday" jumped to the top, its note left by the field, 2026-11-15).
    @MainActor
    func testNewTaskStaysByTheFieldWhileTyping() throws {
        let app = launchFresh()
        let work = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Work,")).firstMatch
        XCTAssertTrue(work.waitForExistence(timeout: 5))
        work.tap()
        let addTask = app.addTaskField
        XCTAssertTrue(addTask.waitForExistence(timeout: 3))
        addTask.tap()
        addTask.typeText("Alpha\n")
        addTask.typeText("Beta\n")
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "EEEE"
        app.buttons["New task options: Checkbox, One-Time"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["DAY"].waitForExistence(timeout: 3))
        app.buttons[formatter.string(from: Date())].tap()  // today: a day task comes first
        app.buttons["Done"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["DAY"].waitForNonExistence(timeout: 3))
        addTask.tap()
        addTask.typeText("Gamma\n")

        let alpha = app.staticTexts["Alpha"], beta = app.staticTexts["Beta"], gamma = app.staticTexts["Gamma"]
        XCTAssertTrue(gamma.waitForExistence(timeout: 3))
        XCTAssertGreaterThan(gamma.frame.minY, beta.frame.minY, "while typing, it's last, by the field")
        app.buttons["Done"].firstMatch.tap()  // the keyboard goes
        let movedFirst = expectation(for: NSPredicate { _, _ in gamma.frame.minY < alpha.frame.minY }, evaluatedWith: nil, handler: nil)
        wait(for: [movedFirst], timeout: 8)
    }

    /// A pinned task shows a pin after its name outside the card's edit mode too, and
    /// VoiceOver hears "pinned" (it only sat at the top before, 2026-11-14).
    @MainActor
    func testPinnedTaskShowsItsPin() throws {
        let app = launchFresh()
        let errands = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Errands,")).firstMatch
        XCTAssertTrue(errands.waitForExistence(timeout: 5))
        errands.tap()
        let addTask = app.addTaskField
        XCTAssertTrue(addTask.waitForExistence(timeout: 3))
        addTask.tap()
        addTask.typeText("Return books\n")
        addTask.typeText("Groceries\n")
        app.buttons["Done"].firstMatch.tap()
        sleep(1)
        app.editCard("Errands")
        let pin = app.buttons["Pin Groceries to the top"]
        XCTAssertTrue(pin.waitForExistence(timeout: 3))
        pin.tap()
        app.buttons["Done editing Errands"].tap()
        sleep(1)
        XCTAssertEqual(app.staticTexts["Groceries"].value as? String, "pinned", "said after the name")
        XCTAssertEqual(app.staticTexts["Return books"].value as? String ?? "", "", "and only on the pinned one")
    }

    /// A target that the goal's progress already meets says so before Save Goal, rather than
    /// the goal turning up struck through ("Done, 8 of 7", 2026-11-14).
    @MainActor
    func testEditGoalSaysWhenItWouldBeMet() throws {
        let app = launchFresh()
        let work = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Work,")).firstMatch
        XCTAssertTrue(work.waitForExistence(timeout: 5))
        work.tap()
        let addTask = app.addTaskField
        XCTAssertTrue(addTask.waitForExistence(timeout: 3))
        addTask.tap()
        addTask.typeText("Push-ups\n")
        sleep(1)
        app.buttons["Task options: Checkbox, One-Time"].firstMatch.tap()
        app.buttons["Goal"].firstMatch.tap()
        dismissPopover(app)
        let targetField = app.textFields["Target"]
        XCTAssertTrue(targetField.waitForExistence(timeout: 3))
        targetField.tap()
        targetField.typeText("10")
        app.buttons["Set"].tap()
        if app.buttons["Done"].exists { app.buttons["Done"].firstMatch.tap() }
        let plus = app.buttons["Add 2"]  // 10 ÷ 7, rounded up
        XCTAssertTrue(plus.waitForExistence(timeout: 3))
        plus.tap()

        app.buttons["Edit goal"].tap()
        let target = app.textFields["Target"].firstMatch
        XCTAssertTrue(target.waitForExistence(timeout: 3))
        target.tap()
        target.typeText("2")
        let note = app.staticTexts["Already 2 of 2: saving marks it done"]
        XCTAssertTrue(note.waitForExistence(timeout: 3), "it says so before saving")
        target.typeText("0")
        XCTAssertTrue(note.waitForNonExistence(timeout: 3), "20 isn't met yet")
    }

    /// A task's day mark sits beside its whole name, so a name with a long word and a day gets
    /// its icons on their own line rather than breaking mid-word ("Send invoic / e" next to
    /// "Fri · late", 2026-11-14). In the card's edit mode the marks give way, so the four
    /// edit icons stay beside the name (2026-11-15).
    @MainActor
    func testDayMarkLeavesRoomForTheName() throws {
        let app = launchFresh(["-isolatedDataID", "daymark-\(UUID().uuidString)"])
        let work = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Work,")).firstMatch
        XCTAssertTrue(work.waitForExistence(timeout: 5))
        work.tap()
        let addTask = app.addTaskField
        XCTAssertTrue(addTask.waitForExistence(timeout: 3))
        addTask.tap()
        addTask.typeText("Spreadsheets\n")
        app.buttons["Done"].firstMatch.tap()
        sleep(1)

        // Today, which is never a day gone by.
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "EEEE"
        app.buttons["Task options: Checkbox, One-Time"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["DAY"].waitForExistence(timeout: 3))
        app.buttons[formatter.string(from: Date())].tap()
        app.buttons["Done"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["DAY"].waitForNonExistence(timeout: 3))
        sleep(1)

        let name = app.staticTexts["Spreadsheets"]
        XCTAssertLessThan(name.frame.height, 34, "one line beside its day: never broken mid-word")

        app.editCard("Work")
        let delete = app.buttons["Delete Spreadsheets"]
        XCTAssertTrue(delete.waitForExistence(timeout: 3))
        sleep(1)  // the edit icons run out to their places
        XCTAssertLessThan(name.frame.height, 34, "one line in edit mode too")
        XCTAssertLessThan(delete.frame.minY, name.frame.midY, "the day gives way, so the icons stay beside the name")
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
        app.editCard("Errands")

        let alpha = app.buttons["Complete Alpha"]
        let charlie = app.buttons["Complete Charlie"]
        XCTAssertTrue(alpha.waitForExistence(timeout: 2))
        XCTAssertLessThan(alpha.frame.minY, charlie.frame.minY)
        // The handle is for touch only (VoiceOver has Move Up / Move Down), so it isn't in
        // the accessibility tree: it sits just right of the task's Delete button.
        let delete = app.buttons["Delete Alpha"]
        XCTAssertTrue(delete.exists, "edit mode shows delete and the drag handle")
        let handle = delete.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5)).withOffset(CGVector(dx: 12, dy: 0))
        // The task follows the handle and takes a task's place once it reaches its middle:
        // dragged a little past Charlie's.
        handle.press(forDuration: 1.0, thenDragTo: charlie.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .withOffset(CGVector(dx: 0, dy: 10)))
        let moved = NSPredicate { _, _ in alpha.frame.minY > charlie.frame.minY }
        wait(for: [XCTNSPredicateExpectation(predicate: moved, object: nil)], timeout: 5)

        // A sideways drag on a handle moves nothing and doesn't swipe the week (it used to).
        let week = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Week of")).firstMatch.label
        let bravoHandle = app.buttons["Delete Bravo"].coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5))
            .withOffset(CGVector(dx: 12, dy: 0))
        bravoHandle.press(forDuration: 0.1, thenDragTo: bravoHandle.withOffset(CGVector(dx: -220, dy: 4)))
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Week of")).firstMatch.label, week)
        XCTAssertTrue(app.buttons["Delete Bravo"].exists, "still this week, still in edit mode")
    }

    /// Held near the bottom of the screen, a task moved by its handle scrolls a card longer
    /// than the screen, so it can be taken to the end.
    @MainActor
    func testReorderAutoScrollsLongCard() throws {
        let app = launchFresh()
        let errands = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Errands,")).firstMatch
        XCTAssertTrue(errands.waitForExistence(timeout: 5))
        errands.tap()
        let addTask = app.addTaskField
        XCTAssertTrue(addTask.waitForExistence(timeout: 3))
        addTask.tap()
        // One at a time, like the other tests: typed all at once, keys were lost.
        for number in 1...16 {
            addTask.typeText("Task \(number)\n")
            usleep(400_000)
        }
        app.buttons["Done"].firstMatch.tap()
        app.editCard("Errands")

        let first = app.buttons["Complete Task 1"]
        let last = app.buttons["Complete Task 16"]
        XCTAssertTrue(first.waitForExistence(timeout: 2))
        XCTAssertFalse(last.isHittable, "the card is longer than the screen")
        let handle = app.buttons["Delete Task 1"].coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5))
            .withOffset(CGVector(dx: 12, dy: 0))
        let nearBottom = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.86))
        handle.press(forDuration: 0.3, thenDragTo: nearBottom, withVelocity: .default, thenHoldForDuration: 4)
        let moved = NSPredicate { _, _ in first.frame.minY > last.frame.minY }
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

        app.editCard("Errands")
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

    /// − and + are always there, centered under the bar, − dimmed until there's progress,
    /// so neither moves under a finger: a second tap where + was still adds.
    @MainActor
    func testStepsKeepTheirPlace() throws {
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
        targetField.typeText("7")  // (a day's share: 1)
        app.buttons["Set"].tap()
        if app.buttons["Done"].exists { app.buttons["Done"].firstMatch.tap() }

        let plus = app.buttons["Add 1"]
        let minus = app.buttons["Remove 1"]
        XCTAssertTrue(plus.waitForExistence(timeout: 3))
        sleep(1)
        XCTAssertTrue(minus.exists, "− is there from the start")
        XCTAssertFalse(minus.isEnabled, "dimmed before there's progress")
        let bar = app.progressIndicators.firstMatch.frame
        XCTAssertEqual(minus.frame.union(plus.frame).midX, bar.midX, accuracy: 1, "centered under the bar")
        let before = plus.frame
        // Where + was, on the screen (a coordinate from the element would follow it).
        let spot = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: before.midX, dy: before.midY))
        spot.tap()
        XCTAssertTrue(app.staticTexts["1/7"].waitForExistence(timeout: 3))
        XCTAssertTrue(minus.isEnabled, "− works once there's progress")
        sleep(1)
        XCTAssertEqual(plus.frame.minX, before.minX, accuracy: 0.5, "+ didn't move")
        spot.tap()
        XCTAssertTrue(app.staticTexts["2/7"].waitForExistence(timeout: 3), "a second tap where + was still adds")
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
        targetField.typeText("7")  // (a day's share: 1)
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
        // The frames include the tap areas: 16pt outward, and half the 12pt gap inward.
        XCTAssertEqual(minus.frame.width - 22, 56, accuracy: 1, "− is 56pt wide (twice its old 28)")
        XCTAssertGreaterThanOrEqual(plus.frame.width - 22, 56 - 0.5, "+ at least as wide")
        XCTAssertEqual(steps.width - 32 - (minus.frame.width - 22) - (plus.frame.width - 22), 12, accuracy: 1, "12pt between them")
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
        // (The step × 7 days made the target 999,999 too: its wider amount moved the bar.)
        let newBar = app.progressIndicators.firstMatch.frame
        XCTAssertEqual(app.buttons["Remove 999,999"].frame.union(bigPlus.frame).midX, newBar.midX, accuracy: 1, "still centered")

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
        let pastTarget = app.buttons["Add 9 minutes"]  // (60 ÷ 7, rounded up)
        XCTAssertTrue(pastTarget.waitForExistence(timeout: 2), "+ stays at the target")
        pastTarget.tap()
        XCTAssertTrue(app.staticTexts["1h 9m / 1h"].waitForExistence(timeout: 3), "and counts past it")
    }

    /// With a custom unit the goal editor stays on the screen: the unit's name gets its own row
    /// where it doesn't fit beside the target (on a 402pt iPhone it and Save Goal ran off the
    /// card's edge, 2026-11-14).
    @MainActor
    func testEditGoalWithCustomUnitFits() throws {
        let app = launchFresh()
        let work = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Work,")).firstMatch
        XCTAssertTrue(work.waitForExistence(timeout: 5))
        work.tap()
        let addTask = app.addTaskField
        XCTAssertTrue(addTask.waitForExistence(timeout: 3))
        addTask.tap()
        addTask.typeText("Drink water\n")
        sleep(1)
        app.buttons["Task options: Checkbox, One-Time"].firstMatch.tap()
        app.buttons["Goal"].firstMatch.tap()
        dismissPopover(app)
        let targetField = app.textFields["Target"]
        XCTAssertTrue(targetField.waitForExistence(timeout: 3))
        targetField.tap()
        targetField.typeText("56")
        app.buttons["Set"].tap()
        if app.buttons["Done"].exists { app.buttons["Done"].firstMatch.tap() }

        app.buttons["Edit goal"].tap()
        let unitMenu = app.buttons["Goal unit: Quantity"]
        XCTAssertTrue(unitMenu.waitForExistence(timeout: 3))
        unitMenu.tap()
        app.buttons["Custom"].firstMatch.tap()
        let unitName = app.textFields["Unit name, for example pages"]
        XCTAssertTrue(unitName.waitForExistence(timeout: 3))
        unitName.tap()
        unitName.typeText("glasses")
        sleep(1)

        // Sideways nothing moves with the keyboard up, so the edges can be checked now.
        let screen = app.windows.firstMatch.frame
        XCTAssertLessThanOrEqual(unitName.frame.maxX, screen.maxX - 16, "the unit's name is on the screen")
        let save = app.buttons["Save Goal"]
        XCTAssertTrue(save.exists)
        XCTAssertLessThanOrEqual(save.frame.maxX, screen.maxX - 16, "so is Save Goal")
        // The keyboard's Done saves the goal, as Save Goal would.
        app.buttons["Done"].firstMatch.tap()
        let unitShown = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "glasses")).firstMatch
        XCTAssertTrue(unitShown.waitForExistence(timeout: 3), "the unit was saved")
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
        // A tap just below the box still focuses it, and doesn't flip the Days toggle under it.
        let step = app.textFields["Auto"].firstMatch
        step.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 1.1)).tap()
        XCTAssertTrue(app.buttons["7 days"].isSelected, "Days unchanged")
        XCTAssertEqual(step.value(forKey: "hasKeyboardFocus") as? Bool, true)

        // Delete sits left of Save Goal; it can be undone instead of asking first.
        let delete = app.buttons["Delete task"]
        let save = app.buttons["Save Goal"]
        XCTAssertLessThan(delete.frame.maxX, save.frame.minX)
        delete.tap()
        XCTAssertTrue(app.buttons["Undo delete"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["Read more"].waitForExistence(timeout: 1), "the goal is deleted")
    }

    /// The goal editor's Days, a 5 | 7 toggle, with Step left on Auto: + steps by the target
    /// ÷ the days, and the editor says so. A target typed then keeps the days.
    @MainActor
    func testGoalDaysWithAutoStep() throws {
        let app = launchDemoFitness()
        XCTAssertTrue(app.buttons["Add 13 minutes"].exists, "Yoga's 1h 30m ÷ 7, rounded up")
        try openYogaEditor(app)

        XCTAssertTrue(app.staticTexts["Target ÷ 7 days = 13m a step"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["7 days"].isSelected, "7 to start")
        XCTAssertFalse(app.textFields["Days"].exists, "a toggle, not a field")
        app.buttons["5 days"].tap()
        XCTAssertTrue(app.staticTexts["Target ÷ 5 days = 18m a step"].waitForExistence(timeout: 2))
        XCTAssertEqual(app.textFields["Target hours"].value as? String, "1", "the target stays")

        app.textFields["Target hours"].clearAndType("2")
        XCTAssertTrue(app.buttons["5 days"].isSelected, "typing the target keeps the days")
        XCTAssertTrue(app.staticTexts["Target ÷ 5 days = 30m a step"].waitForExistence(timeout: 2), "2h 30m ÷ 5")
        app.buttons["Save Goal"].tap()
        XCTAssertTrue(app.buttons["Add 30 minutes"].waitForExistence(timeout: 3), "+ steps by a day's share of 5 days")
    }

    /// With a Step typed, the target is Step × Days and follows the toggle; typing the target
    /// then puts the Step back to Auto. Saved, + steps by the Step.
    @MainActor
    func testGoalDaysFollowStep() throws {
        let app = launchDemoFitness()
        try openYogaEditor(app)

        app.textFields["Auto minutes"].clearAndType("20")
        XCTAssertEqual(app.textFields["Target hours"].value as? String, "2")
        XCTAssertEqual(app.textFields["Target minutes"].value as? String, "20", "20 min × 7 days")
        XCTAssertTrue(app.staticTexts["Step × 7 days = Target"].exists)
        app.buttons["5 days"].tap()
        XCTAssertTrue(app.staticTexts["Step × 5 days = Target"].waitForExistence(timeout: 2))
        XCTAssertEqual(app.textFields["Target hours"].value as? String, "1")
        XCTAssertEqual(app.textFields["Target minutes"].value as? String, "40", "20 min × 5 days")

        // A target typed by hand leads: the Step goes back to Auto, a day's share of it.
        app.textFields["Target hours"].clearAndType("3")
        XCTAssertTrue(app.staticTexts["Target ÷ 5 days = 44m a step"].waitForExistence(timeout: 2), "3h 40m ÷ 5")
        XCTAssertFalse(app.staticTexts["Step × 5 days = Target"].exists)

        app.textFields["Auto minutes"].clearAndType("30")
        XCTAssertEqual(app.textFields["Target hours"].value as? String, "2")
        XCTAssertEqual(app.textFields["Target minutes"].value as? String, "30", "30 min × 5 days")
        app.buttons["Save Goal"].tap()
        XCTAssertTrue(app.buttons["Add 30 minutes"].waitForExistence(timeout: 3), "+ steps by the Step")
    }

    /// The demo's week with Fitness open first (Yoga: 1h 30m, no step).
    @MainActor
    private func launchDemoFitness() -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-demoData", "-demoFirstCard", "Fitness"]
        app.launch()
        let fitness = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Fitness,")).firstMatch
        XCTAssertTrue(fitness.waitForExistence(timeout: 10))
        fitness.tap()
        XCTAssertTrue(app.staticTexts["Yoga"].waitForExistence(timeout: 3))
        return app
    }

    /// Yoga's sliders: the Edit goal button nearest below its name.
    @MainActor
    private func openYogaEditor(_ app: XCUIApplication) throws {
        let yoga = app.staticTexts["Yoga"]
        let edit = app.buttons.matching(identifier: "Edit goal").allElementsBoundByIndex
            .filter { $0.frame.minY > yoga.frame.minY }.min { $0.frame.minY < $1.frame.minY }
        try XCTUnwrap(edit).tap()
        XCTAssertTrue(app.buttons["Save Goal"].waitForExistence(timeout: 3))
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
