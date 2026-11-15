import XCTest

/// Findings from the Everyday-flows review (2026-11-15). Each asserts what should happen,
/// so it fails while the problem is there.
final class ReviewEverydayFindingsTests: ReviewEverydayBase {

    func dayLabel(_ date: Date) -> String { date.formatted(.dateTime.weekday(.wide).month(.wide).day()) }

    /// Typed words, then the options popup: One-Time with a date next week, then the popup's
    /// Add Task. The task goes into next week and the screen follows; the keyboard should
    /// go with the field it belonged to (this week's, now off screen).
    @MainActor
    func testPopupAddToNextWeekLeavesNoKeyboard() throws {
        launch()
        openCard("Errands")
        let field = app.addTaskField
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText("Return library books")
        newTaskOptions.tap()
        XCTAssertTrue(app.buttons["Add a date"].waitForExistence(timeout: 3))
        app.buttons["One-Time"].firstMatch.tap()
        app.buttons["Add a date"].tap()
        XCTAssertTrue(app.staticTexts["Until"].waitForExistence(timeout: 3))
        let wed = Calendar.current.date(byAdding: .day, value: 3, to: Date())!
        let cell = app.buttons[dayLabel(wed)]
        if !cell.exists { app.buttons["Next month"].tap() }
        cell.tap()
        app.buttons["Set"].tap()
        sleep(1)
        let thisWeek = weekTitle
        app.buttons["Add Task"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Added to next week"].waitForExistence(timeout: 5))
        sleep(2)
        let keyboardUp = app.keyboards.firstMatch.exists
        let openFields = app.textFields.matching(identifier: "Add task").allElementsBoundByIndex.filter { $0.isHittable }.count
        log("after popup Add Task to next week: keyboard \(keyboardUp), visible Add task fields \(openFields), week \(weekTitle)")
        shot("finding-kb-01-popup-add-next-week")
        XCTAssertNotEqual(weekTitle, thisWeek)
        XCTAssertFalse(keyboardUp, "no keyboard for a field that's off screen")
        // (Typing then fails in XCUITest: "Neither element nor any descendant has keyboard
        // focus": the keyboard is up with no field focused.)
        app.buttons["Moved OK"].tap()
        sleep(1)
        log("after OK: keyboard \(app.keyboards.firstMatch.exists), bar shows Previous week \(app.buttons["Previous week"].exists), house \(app.buttons.matching(identifier: "Bar Back to This Week").firstMatch.exists)")
        shot("finding-kb-02-after-ok")
        XCTAssertTrue(app.buttons["Previous week"].exists, "the bottom bar is there")
        if app.keyboards.firstMatch.exists {
            let down = app.buttons["keyboard.chevron.compact.down"]
            log("keyboard-down button: \(down.exists)")
            if down.exists { down.tap() } else { keyboardDone() }
            sleep(2)
            log("after keyboard-down: keyboard \(app.keyboards.firstMatch.exists), Previous week \(app.buttons["Previous week"].exists)")
            shot("finding-kb-02b-after-keyboard-down")
        }
        app.buttons["Previous week"].tap()
        sleep(2)
        let leftovers = app.textFields.matching(NSPredicate(format: "value == %@", "zz")).count
        let zzTask = app.staticTexts["zz"].exists
        log("back on this week: field holding zz \(leftovers), task zz \(zzTask), tasks \(taskTitles)")
        shot("finding-kb-03-this-week")
    }

    /// After a popup add went to another week, the stray keyboard: which ways out work?
    @MainActor
    func testStrayKeyboardWaysOut() throws {
        launch()
        openCard("Work")
        let field = app.addTaskField
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText("Call dentist")
        newTaskOptions.tap()
        XCTAssertTrue(app.staticTexts["DAY"].waitForExistence(timeout: 3))
        app.buttons["Thursday"].tap()
        app.buttons["Add Task"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Added to next week"].waitForExistence(timeout: 5))
        app.buttons["Moved OK"].tap()
        sleep(1)
        let down = app.buttons["keyboard.chevron.compact.down"]
        for attempt in 1...2 where app.keyboards.firstMatch.exists {
            if down.exists { down.tap() }
            sleep(2)
            log("keyboard-down tap \(attempt): keyboard \(app.keyboards.firstMatch.exists), bar \(app.buttons["Previous week"].exists)")
        }
        // Swipe back a week.
        if app.keyboards.firstMatch.exists {
            let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.3))
            from.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.3)))
            sleep(2)
            log("after swiping to the week before: week \(weekTitle), keyboard \(app.keyboards.firstMatch.exists), bar \(app.buttons["Previous week"].exists || app.buttons["Next week"].exists)")
            shot("finding-kb-20-after-swipe")
        }
        // Open a field and close it.
        if app.keyboards.firstMatch.exists {
            openCardIfClosed("Work")
            let f2 = app.addTaskField
            if f2.waitForExistence(timeout: 3) { f2.tap() }
            sleep(1)
            if down.exists { down.tap() }
            sleep(2)
            log("after opening a field and keyboard-down: keyboard \(app.keyboards.firstMatch.exists), bar \(app.buttons["Next week"].exists)")
            shot("finding-kb-21-after-field")
        }
        XCTAssertTrue(app.buttons["Next week"].exists || app.buttons["Previous week"].exists, "the bar is back")
    }

    /// The same with a day gone by (Thursday on a Sunday, Monday start) and the popup's Add
    /// Task instead of Return.
    @MainActor
    func testPopupAddForPastDayLeavesNoKeyboard() throws {
        launch()
        openCard("Work")
        let field = app.addTaskField
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText("Call dentist")
        newTaskOptions.tap()
        XCTAssertTrue(app.staticTexts["DAY"].waitForExistence(timeout: 3))
        app.buttons["Thursday"].tap()
        app.buttons["Add Task"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Added to next week"].waitForExistence(timeout: 5))
        sleep(2)
        let keyboardUp = app.keyboards.firstMatch.exists
        log("after popup Add Task for a past day: keyboard \(keyboardUp), week \(weekTitle)")
        shot("finding-kb-10-popup-add-past-day")
        XCTAssertFalse(keyboardUp, "no keyboard for a field that's off screen")
        app.buttons["Moved OK"].tap()
        sleep(1)
        XCTAssertTrue(app.buttons["Previous week"].exists, "the bottom bar is there")
    }

    /// Control: the same past day added with Return closes the keyboard as the screen moves.
    @MainActor
    func testReturnAddForPastDayClosesKeyboard() throws {
        launch()
        openCard("Work")
        let field = app.addTaskField
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        newTaskOptions.tap()
        XCTAssertTrue(app.staticTexts["DAY"].waitForExistence(timeout: 3))
        app.buttons["Thursday"].tap()
        app.buttons["Done"].firstMatch.tap()
        let f = app.addTaskField
        f.tap()
        f.typeText("Call dentist\n")
        XCTAssertTrue(app.staticTexts["Added to next week"].waitForExistence(timeout: 5))
        sleep(2)
        log("after Return add for a past day: keyboard \(app.keyboards.firstMatch.exists)")
        XCTAssertFalse(app.keyboards.firstMatch.exists)
    }

    /// Monday start, Sunday: "Call dentist" for Thursday goes into next week (Thu Nov 19).
    /// Switching to a Sunday start makes Nov 15–21 this week, so Thursday the 19th is in it;
    /// the task should still be on the 19th, not a week later. A task dated Fri Nov 20 that
    /// moved into next week should not vanish.
    @MainActor
    func testWeekStartSwitchKeepsNextWeeksDayTask() throws {
        launch()
        openCard("Work")
        let field = app.addTaskField
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        newTaskOptions.tap()
        XCTAssertTrue(app.staticTexts["DAY"].waitForExistence(timeout: 3))
        app.buttons["Thursday"].tap()
        app.buttons["Done"].firstMatch.tap()
        let f = app.addTaskField
        f.tap()
        f.typeText("Call dentist\n")
        XCTAssertTrue(app.staticTexts["Added to next week"].waitForExistence(timeout: 5))
        let nextWeekTitle = weekTitle  // Week of Nov 16
        app.buttons["Moved Back to This Week"].tap()
        sleep(2)
        if app.keyboards.firstMatch.exists { keyboardDone() }
        // A task dated Friday Nov 20 from the clock, also into next week.
        openCardIfClosed("Work")
        let f2 = app.addTaskField
        f2.tap()
        newTaskOptions.tap()
        XCTAssertTrue(app.staticTexts["DAY"].waitForExistence(timeout: 3))
        app.buttons["Any day"].firstMatch.tap()
        app.buttons["Done"].firstMatch.tap()
        let f3 = app.addTaskField
        f3.tap()
        f3.typeText("Review deck\n")
        keyboardDone()
        app.editCard("Work")
        app.buttons["Expiration Review deck"].tap()
        XCTAssertTrue(app.staticTexts["Expires"].waitForExistence(timeout: 3))
        let fri = Calendar.current.date(byAdding: .day, value: 5, to: Date())!
        app.buttons[dayLabel(fri)].firstMatch.tap()
        app.buttons["Set"].firstMatch.tap()
        sleep(2)
        if app.buttons["Moved OK"].exists { app.buttons["Moved OK"].tap() }
        openCardIfClosed("Work")
        if app.buttons["Done editing Work"].exists { app.buttons["Done editing Work"].tap() }
        log("next week (\(nextWeekTitle)) before switch: \(taskTitles)")
        shot("finding-ws-01-next-week-before")
        if app.buttons["Bar Back to This Week"].exists { app.buttons["Bar Back to This Week"].tap() } else { app.buttons["Previous week"].tap() }
        sleep(2)

        setWeekStart(sunday: true)
        let thisWeek = weekTitle
        log("after switch, this week: \(thisWeek)")
        openCardIfClosed("Work")
        log("this week (Sun start) Work tasks: \(taskTitles)")
        shot("finding-ws-02-this-week-after-switch")
        let dentistHere = app.staticTexts["Call dentist"].exists
        let deckHere = app.staticTexts["Review deck"].exists
        app.buttons["Next week"].tap()
        sleep(2)
        openCardIfClosed("Work")
        log("next week (\(weekTitle)) Work tasks: \(taskTitles) dentist value \(app.staticTexts["Call dentist"].value as? String ?? "-")")
        shot("finding-ws-03-next-week-after-switch")
        XCTAssertTrue(dentistHere, "Thursday the 19th is in this week now; so is the task meant for it")
        XCTAssertTrue(deckHere || app.staticTexts["Review deck"].exists, "the task dated Nov 20 still exists somewhere")
        // Back to Monday: does everything come back?
        app.buttons["Previous week"].tap()
        sleep(1)
        setWeekStart(sunday: false)
        app.buttons["Next week"].tap()
        sleep(2)
        openCardIfClosed("Work")
        log("after switching back, next week (\(weekTitle)): \(taskTitles)")
        shot("finding-ws-04-back-to-monday")
    }

    /// The "Added to next week" pop-up sits over the card's note for its 6 s, and the note's
    /// Undo lasts 8 s: a user who reads the pop-up and lets it go has about 2 s left to Undo.
    @MainActor
    func testUndoOutlastsTheMovedPopUp() throws {
        launch()
        openCard("Work")
        let field = app.addTaskField
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        newTaskOptions.tap()
        XCTAssertTrue(app.staticTexts["DAY"].waitForExistence(timeout: 3))
        app.buttons["Thursday"].tap()
        app.buttons["Done"].firstMatch.tap()
        let f = app.addTaskField
        f.tap()
        f.typeText("Call dentist\n")
        let popUp = app.staticTexts["Added to next week"]
        XCTAssertTrue(popUp.waitForExistence(timeout: 5))
        let start = Date()
        let undo = app.buttons["Undo adding Call dentist"]
        log("Undo hittable under the pop-up: \(undo.exists && undo.isHittable); pop-up frame \(app.buttons["Moved OK"].frame) undo frame \(undo.frame)")
        // The pop-up's card: from above its icon to below its buttons.
        let top = popUp.frame.minY - 50, bottom = app.buttons["Moved OK"].frame.maxY + 20
        let covered = undo.frame.midY > top && undo.frame.midY < bottom
        log("pop-up spans y \(Int(top))–\(Int(bottom)); the note's Undo at y \(Int(undo.frame.midY)): covered \(covered)")
        shot("finding-undo-01-popup-over-note")
        XCTAssertFalse(covered, "the pop-up doesn't sit on the note and its Undo")
        XCTAssertTrue(popUp.waitForNonExistence(timeout: 10))
        let gone = Date().timeIntervalSince(start)
        sleep(2)
        let stillThere = undo.exists
        log("pop-up went after \(String(format: "%.1f", gone)) s; Undo 2 s later: \(stillThere)")
        shot("finding-undo-02-two-seconds-after-popup")
        XCTAssertTrue(stillThere, "Undo is still there a moment after the pop-up goes")
    }

    @MainActor
    func openCardIfClosed(_ name: String) {
        if app.buttons["Close \(name)"].exists { return }
        let c = card(name)
        if c.waitForExistence(timeout: 3) { c.tap(); sleep(1) }
    }

    /// Add Category ▸ Create New: a name typed, then Done (✓) should add it and close the
    /// sheet, as Done does everywhere.
    @MainActor
    func testAddCategoryDoneWithTypedNameCloses() throws {
        launch()
        app.buttons["Edit"].tap()
        let tile = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Add Category")).firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 3))
        tile.tap()
        app.buttons["Create New Category"].tap()
        let field = app.textFields["Category name"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.typeText("Garden")
        app.navigationBars["Add Category"].buttons["Done"].tap()
        sleep(2)
        let open = app.navigationBars["Add Category"].exists
        let added = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Added Garden")).firstMatch.exists
        log("after Done with 'Garden' typed: sheet open \(open), 'Added Garden' note \(added)")
        shot("finding-cat-01-done-with-typed-name")
        XCTAssertFalse(open, "Done closes the sheet")
        if open {
            app.navigationBars["Add Category"].buttons["Done"].tap()
            sleep(2)
        }
        XCTAssertTrue(card("Garden").waitForExistence(timeout: 3), "Garden was added")
    }

    /// A name that's taken, still in the field: Done should still close the sheet (or say
    /// why not); it does nothing.
    @MainActor
    func testAddCategoryDoneWithTakenName() throws {
        launch()
        app.buttons["Edit"].tap()
        let tile = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Add Category")).firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 3))
        tile.tap()
        app.buttons["Create New Category"].tap()
        let field = app.textFields["Category name"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.typeText("Work")
        sleep(1)
        app.navigationBars["Add Category"].buttons["Done"].tap()
        sleep(2)
        let open = app.navigationBars["Add Category"].exists
        log("after Done with taken 'Work' typed: sheet still open \(open)")
        shot("finding-cat-02-done-with-taken-name")
        XCTAssertFalse(open, "Done closes the sheet")
    }
}
