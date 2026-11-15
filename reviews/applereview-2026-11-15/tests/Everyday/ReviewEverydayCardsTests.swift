import XCTest

/// Pins, Add Category several times, Just this week, duplicates and clearing a name
/// (review 2026-11-15).
final class ReviewEverydayCardsTests: ReviewEverydayBase {

    func cardOrder() -> [String] {
        let cards = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open ")).allElementsBoundByIndex
        return cards.sorted { ($0.frame.minY, $0.frame.minX) < ($1.frame.minY, $1.frame.minX) }
            .map { String($0.label.dropFirst(5).prefix { $0 != "," }) }
            .filter { $0 != "all cards" }
    }

    /// Pin two cards and two tasks; a third is refused; unpin; the order comes back; relaunch.
    @MainActor
    func testPinTwoCardsAndTwoTasksThenUnpin() throws {
        launch()
        let before = cardOrder()
        log("order before: \(before)")
        app.buttons["Edit"].tap()
        XCTAssertTrue(app.buttons["Pin Study"].waitForExistence(timeout: 3))
        app.buttons["Pin Study"].tap()
        app.buttons["Pin Appointments"].tap()
        sleep(1)
        log("Pin Work enabled with two pinned: \(app.buttons["Pin Work"].isEnabled)")
        XCTAssertFalse(app.buttons["Pin Work"].isEnabled)
        app.buttons["Pin Work"].tap()  // a third: refused
        shot("pins-01-edit-two-pinned")
        app.buttons["Done Editing"].tap()
        sleep(1)
        let pinned = cardOrder()
        log("order pinned: \(pinned)")
        XCTAssertEqual(Array(pinned.prefix(2)), ["Study", "Appointments"])

        openCard("Errands")
        typeTasks(["Dry cleaning", "Donations", "Groceries", "Stamps"])
        keyboardDone()
        app.editCard("Errands")
        app.buttons["Pin Groceries"].tap()
        app.buttons["Pin Stamps"].tap()
        sleep(1)
        let third = app.buttons["Pin Donations"]
        log("third task pin enabled: \(third.isEnabled) label: \(third.label)")
        XCTAssertFalse(third.isEnabled, "two tasks a card")
        shot("pins-02-card-edit-two-pinned")
        app.buttons["Done editing Errands"].tap()
        sleep(1)
        log("tasks pinned: \(taskTitles)")
        XCTAssertEqual(taskTitles, ["Complete Groceries", "Complete Stamps", "Complete Dry cleaning", "Complete Donations"])
        shot("pins-03-tasks-pinned")

        relaunch()
        log("order after relaunch: \(cardOrder())")
        XCTAssertEqual(Array(cardOrder().prefix(2)), ["Study", "Appointments"], "pins kept")
        openCard("Errands")
        XCTAssertEqual(taskTitles, ["Complete Groceries", "Complete Stamps", "Complete Dry cleaning", "Complete Donations"])
        app.editCard("Errands")
        app.buttons["Pin Groceries"].tap()  // unpin
        app.buttons["Pin Stamps"].tap()
        app.buttons["Done editing Errands"].tap()
        sleep(1)
        XCTAssertEqual(taskTitles, ["Complete Dry cleaning", "Complete Donations", "Complete Groceries", "Complete Stamps"], "back in place")
        app.buttons["Close Errands"].tap()
        sleep(1)
        app.buttons["Edit"].tap()
        sleep(1)
        app.buttons["Pin Study"].tap()
        app.buttons["Pin Appointments"].tap()
        app.buttons["Done Editing"].tap()
        sleep(1)
        log("order unpinned: \(cardOrder())")
        XCTAssertEqual(cardOrder(), before, "order comes back")
        shot("pins-04-unpinned")
        // Next week follows.
        app.buttons["Next week"].tap()
        sleep(2)
        log("next week order: \(cardOrder())")
        XCTAssertEqual(cardOrder(), before)
    }

    /// Add Category several times in one go, with and without Just this week, then the
    /// card's own chip on and off.
    @MainActor
    func testAddCategorySeveralTimesAndChip() throws {
        launch()
        app.buttons["Edit"].tap()
        let tile = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Add Category")).firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 3))
        tile.tap()
        app.buttons["Create New Category"].tap()
        let field = app.textFields["Category name"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.typeText("Garden\n")
        sleep(1)
        let added = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Added")).firstMatch
        log("after Garden: \(added.exists ? added.label : "none"), keyboard \(app.keyboards.firstMatch.exists), field value '\(field.value as? String ?? "")'")
        shot("cats-01-added-garden")
        field.typeText("Trip")
        let toggle = app.switches.matching(NSPredicate(format: "label BEGINSWITH %@", "Just this week")).firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 3))
        toggle.switches.firstMatch.tap()
        field.tap()
        field.typeText("\n")
        sleep(1)
        log("after Trip: \(added.exists ? added.label : "none"), toggle now \(toggle.value as? String ?? "")")
        XCTAssertEqual(toggle.value as? String, "0", "off again after an add")
        field.typeText("Garden\n")  // a duplicate name
        sleep(1)
        let texts = app.staticTexts.allElementsBoundByIndex.map(\.label).filter { $0.contains("Garden") || $0.contains("already") }
        log("after Garden twice: \(texts)")
        shot("cats-02-garden-twice")
        // Saved category tap
        let saved = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Errands")).firstMatch
        log("saved Errands row: \(saved.exists ? saved.label : "none")")
        // (Done with the taken name still typed does nothing: see testAddCategoryDoneWithTakenName.)
        app.buttons["Cancel"].firstMatch.tap()
        app.navigationBars["Add Category"].buttons["Done"].tap()
        sleep(1)
        log("Edit ended: \(app.buttons["Edit"].exists) order: \(cardOrder())")
        shot("cats-03-after-sheet")
        XCTAssertTrue(card("Garden").exists)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Trip, just this week")).firstMatch.exists)

        // Garden's own chip on and off.
        openCard("Garden")
        typeTasks(["Rake leaves"])
        newTaskOptions.tap()
        app.buttons["Repeating"].firstMatch.tap()
        dismissPopover()
        let f = app.addTaskField
        f.tap()
        f.typeText("Water plants\n")
        keyboardDone()
        log("garden tasks: \(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Task options:")).allElementsBoundByIndex.map(\.label))")
        app.editCard("Garden")
        let chip = app.descendants(matching: .any).matching(identifier: "Just this week chip").firstMatch
        XCTAssertTrue(chip.waitForExistence(timeout: 3))
        chip.tap()
        sleep(1)
        let completed = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Just this week")).allElementsBoundByIndex.map(\.label)
        log("chip on: \(chip.value as? String ?? "") lines: \(completed)")
        shot("cats-04-chip-on")
        chip.tap()
        sleep(1)
        log("chip off: \(chip.value as? String ?? "")")
        app.buttons["Done editing Garden"].tap()
        sleep(1)
        let modes = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Task options:")).allElementsBoundByIndex.map(\.label)
        log("modes after chip on/off: \(modes)")
        XCTAssertTrue(modes.contains("Task options: Checkbox, Repeating"), "Water plants repeats again")
        app.buttons["Next week"].tap()
        sleep(2)
        log("next week cards: \(cardOrder())")
        XCTAssertTrue(cardOrder().contains("Garden") || app.buttons["Close Garden"].exists, "Garden comes back next week")
        XCTAssertFalse(cardOrder().contains("Trip"), "Trip was just this week")
    }

    /// Duplicates: the same task twice, the same item twice; Undo the note.
    @MainActor
    func testDuplicatesAndUndoTheNote() throws {
        launch()
        openCard("Errands")
        typeTasks(["Milk run"])
        let field = app.addTaskField
        field.typeText("milk run\n")
        sleep(1)
        let note = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "already in this card")).firstMatch
        log("dup note: \(note.exists ? note.label : "none")")
        shot("dups-01-task-twice")
        let values = app.staticTexts.matching(NSPredicate(format: "value == %@", "duplicate")).count
        log("marked duplicate: \(values)")
        XCTAssertEqual(values, 2)
        let undo = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Undo")).allElementsBoundByIndex.map(\.label)
        log("undo buttons: \(undo)")
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Undo adding")).firstMatch.tap()
        sleep(1)
        log("after undo: \(taskTitles) keyboard \(app.keyboards.firstMatch.exists)")
        XCTAssertEqual(taskTitles, ["Complete Milk run"])
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "value == %@", "duplicate")).count, 0, "mark gone")
        shot("dups-02-after-undo")

        // A list with the same item twice.
        let f2 = app.addTaskField
        f2.tap()
        f2.typeText("Groceries")
        newTaskOptions.tap()
        app.buttons["List"].firstMatch.tap()
        app.buttons["Add Task"].firstMatch.tap()
        let item = app.textFields["Add item"]
        XCTAssertTrue(item.waitForExistence(timeout: 3))
        item.typeText("Eggs\n")
        Thread.sleep(forTimeInterval: 0.5)
        item.typeText("eggs\n")
        sleep(1)
        let itemNote = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "is already in Groceries")).firstMatch
        log("item dup note: \(itemNote.exists ? itemNote.label : "none")")
        shot("dups-03-item-twice")
        let undoItem = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Undo")).allElementsBoundByIndex.map(\.label)
        log("undo buttons (item): \(undoItem)")
        if let label = undoItem.first { app.buttons[label].firstMatch.tap() }
        sleep(1)
        let eggs = app.staticTexts.matching(NSPredicate(format: "label ==[c] %@", "eggs")).count
        log("eggs after undo: \(eggs)")
        XCTAssertEqual(eggs, 1)
        keyboardDone()
        shot("dups-04-item-after-undo")
    }

    /// Clearing a task's name and pressing Return deletes it, with Undo; Undo brings it back
    /// in its place.
    @MainActor
    func testClearNameReturnDeletesThenUndo() throws {
        launch()
        openCard("Work")
        typeTasks(["Alpha", "Bravo", "Charlie"])
        keyboardDone()
        app.staticTexts["Bravo"].tap()
        let name = app.textFields["Task name"]
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        name.clearAndTypeEveryday("")
        name.typeText("\n")
        sleep(1)
        let deleted = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Deleted")).firstMatch
        log("after clear+return: \(taskTitles); deleted msg \(deleted.exists ? deleted.label : "none"); keyboard \(app.keyboards.firstMatch.exists)")
        shot("rename-01-cleared")
        XCTAssertEqual(taskTitles, ["Complete Alpha", "Complete Charlie"])
        let undo = app.buttons["Undo delete"].firstMatch
        XCTAssertTrue(undo.waitForExistence(timeout: 3), "Undo shown")
        undo.tap()
        sleep(1)
        log("after undo: \(taskTitles)")
        XCTAssertEqual(taskTitles, ["Complete Alpha", "Complete Bravo", "Complete Charlie"])
        shot("rename-02-undone")
        // A sub-task too.
        app.buttons["Add sub-task to Alpha"].tap()
        let sub = app.textFields["Add sub-task"]
        XCTAssertTrue(sub.waitForExistence(timeout: 3))
        sub.typeText("Step one\n")
        Thread.sleep(forTimeInterval: 0.5)
        keyboardDone()
        app.staticTexts["Step one"].tap()
        // The rename field is the one with the keyboard.
        let subName = app.descendants(matching: .any).matching(NSPredicate(format: "hasKeyboardFocus == true")).firstMatch
        XCTAssertTrue(subName.waitForExistence(timeout: 3))
        log("sub-task rename field: \(subName.elementType.rawValue) value '\(subName.value as? String ?? "")'")
        subName.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 12))
        subName.typeText("\n")
        sleep(1)
        log("sub-task after clear+return: exists \(app.staticTexts["Step one"].exists)")
        XCTAssertFalse(app.staticTexts["Step one"].exists)
        XCTAssertTrue(app.buttons["Undo delete"].firstMatch.waitForExistence(timeout: 3))
        app.buttons["Undo delete"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Step one"].waitForExistence(timeout: 3))
    }
}

extension XCUIElement {
    func clearAndTypeEveryday(_ text: String) {
        let current = value as? String ?? ""
        tap()
        if !current.isEmpty {
            // Move to the end, then delete everything.
            coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5)).tap()
            typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count + 2))
        }
        if !text.isEmpty { typeText(text) }
    }
}
