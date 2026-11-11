import XCTest

/// Pre-ship review (1.0.3), everyday flows: a card with a long list, a goal and a checkbox
/// task with sub-tasks, used across weeks and relaunches. Each test starts from its own
/// throwaway storage (`-isolatedDataID`, a fresh name per test).
final class ReviewEverydayTests: XCTestCase {
    private var app: XCUIApplication!
    private var arguments: [String] = []

    @MainActor
    override func setUp() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    // MARK: Helpers

    @MainActor
    private func launch(_ extra: [String] = []) {
        arguments = ["-isolatedDataID", "review-everyday-\(UUID().uuidString)"] + extra
        app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
        if app.staticTexts["Welcome to Tasquel"].waitForExistence(timeout: 4) { app.buttons["Skip"].tap() }
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func relaunch() {
        app.terminate()
        app.launchArguments = arguments
        app.launch()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 5))
    }

    private func shot(_ name: String) {
        Thread.sleep(forTimeInterval: 0.6)
        let dir = ProcessInfo.processInfo.environment["SHOT_DIR"] ?? NSTemporaryDirectory()
        try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
    }

    @MainActor
    private func card(_ name: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open \(name),")).firstMatch
    }

    @MainActor
    private func openCard(_ name: String) {
        let closed = card(name)
        XCTAssertTrue(closed.waitForExistence(timeout: 5), "card \(name)")
        closed.tap()
        XCTAssertTrue(app.buttons["Close \(name)"].waitForExistence(timeout: 3))
    }

    @MainActor
    private var weekTitle: String {
        app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Week of")).firstMatch.label
    }

    @MainActor
    private func closeKeyboard() {
        let done = app.buttons["Done"].firstMatch
        if app.keyboards.firstMatch.exists, done.exists { done.tap() }
        _ = app.keyboards.firstMatch.waitForNonExistence(timeout: 3)
    }

    /// Adds a task through the new-task options (type and mode), Add Task.
    @MainActor
    private func addTask(_ title: String, type: String? = nil, mode: String? = nil) {
        let field = app.addTaskField
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText(title)
        if type == nil && mode == nil {
            field.typeText("\n")
            usleep(400_000)
            return
        }
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "New task options")).firstMatch.tap()
        if let type { app.buttons[type].firstMatch.tap() }
        if let mode { app.buttons[mode].firstMatch.tap() }
        app.buttons["Add Task"].tap()
        usleep(400_000)
    }

    @MainActor
    private func typeLines(_ field: XCUIElement, _ lines: [String]) {
        for line in lines {
            field.typeText(line + "\n")
            usleep(450_000)
        }
    }

    /// A list of six items, two checked; a Smart Add session goal; a carry-over checkbox with
    /// two sub-tasks, all in Errands.
    @MainActor
    private func setUpErrands() {
        openCard("Errands")
        addTask("Groceries", type: "List", mode: "Repeating")
        let item = app.textFields["Add item"]
        XCTAssertTrue(item.waitForExistence(timeout: 3))
        typeLines(item, ["Milk", "Eggs", "Bread", "Apples", "Rice", "Beans"])
        closeKeyboard()
        app.buttons["Complete Milk"].tap()
        app.buttons["Complete Eggs"].tap()

        addTask("Pack bag", type: "Checkbox", mode: "Carry Over")
        closeKeyboard()
        app.buttons["Add sub-task to Pack bag"].tap()
        let sub = app.textFields["Add sub-task"]
        XCTAssertTrue(sub.waitForExistence(timeout: 3))
        typeLines(sub, ["Shoes", "Towel"])
        closeKeyboard()
    }

    // MARK: Journeys

    /// The whole card survives next week and back, and a relaunch: the list's fold and
    /// count, its checks, the carry-over task's sub-tasks.
    @MainActor
    func testFoldedListCardSurvivesWeeksAndRelaunch() throws {
        launch()
        setUpErrands()
        let fold = app.buttons["Fold Groceries"]
        XCTAssertEqual(fold.label, "Collapse list", "a new list starts open")
        fold.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "value == %@", "2 of 6 items checked")).firstMatch.waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["Bread"].exists)
        XCTAssertTrue(app.staticTexts["Shoes"].exists, "the other task's sub-tasks stay")
        shot("journey-1-folded")

        let thisWeek = weekTitle
        app.buttons["Next week"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@ AND label != %@", "Week of", thisWeek)).firstMatch.waitForExistence(timeout: 3))
        // Open cards stay open across week changes.
        XCTAssertTrue(app.buttons["Close Errands"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "value == %@", "2 of 6 items checked")).firstMatch.waitForExistence(timeout: 2),
                      "next week's repeating copy is folded, with its checks")
        XCTAssertTrue(app.staticTexts["Shoes"].exists, "the carry-over task came with its sub-tasks")
        shot("journey-2-next-week")
        print("REVIEW: next week \(weekTitle)")

        app.buttons["Previous week"].tap()
        XCTAssertTrue(app.staticTexts[thisWeek].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "value == %@", "2 of 6 items checked")).firstMatch.waitForExistence(timeout: 2))

        relaunch()
        openCard("Errands")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "value == %@", "2 of 6 items checked")).firstMatch.waitForExistence(timeout: 3), "still folded after a relaunch")
        XCTAssertTrue(app.staticTexts["Shoes"].exists)
        XCTAssertTrue(app.staticTexts["Towel"].exists)
        XCTAssertTrue(app.buttons["Task options: List, Repeating"].exists)
        XCTAssertTrue(app.buttons["Task options: Checkbox, Carry Over"].exists)
        app.buttons["Next week"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "value == %@", "2 of 6 items checked")).firstMatch.waitForExistence(timeout: 3), "next week too, after a relaunch")
        app.buttons["Fold Groceries"].tap()
        XCTAssertTrue(app.buttons["Mark Milk incomplete"].waitForExistence(timeout: 2), "checks kept next week")
        XCTAssertTrue(app.staticTexts["Beans"].exists)
        shot("journey-3-relaunch-next-week-open")
    }

    /// Fold is "not an edit" and keeps a delete's Undo. Undo then puts the whole week back as
    /// it was before the delete, so it also undoes the fold made after it.
    @MainActor
    func testUndoAfterFoldKeepsTheFold() throws {
        launch()
        openCard("Errands")
        addTask("Groceries", type: "List", mode: "Repeating")
        let item = app.textFields["Add item"]
        XCTAssertTrue(item.waitForExistence(timeout: 3))
        typeLines(item, ["Milk", "Eggs"])
        closeKeyboard()
        addTask("Temp")
        closeKeyboard()

        app.buttons["Edit Errands"].tap()
        app.buttons["Delete Temp"].tap()
        XCTAssertTrue(app.buttons["Undo delete"].waitForExistence(timeout: 2))
        // Still in the card's edit mode: the chevron stays there.
        app.buttons["Fold Groceries"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "value == %@", "0 of 2 items checked")).firstMatch.waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Undo delete"].exists, "folding keeps the Undo (spec)")
        shot("undo-fold-1-before-undo")
        app.buttons["Undo delete"].tap()
        XCTAssertTrue(app.buttons["Delete Temp"].waitForExistence(timeout: 2), "Undo brings the task back")
        shot("undo-fold-2-after-undo")
        print("REVIEW: after Undo, fold label = \(app.buttons["Fold Groceries"].label), count shown = \(app.staticTexts.matching(NSPredicate(format: "value == %@", "0 of 2 items checked")).firstMatch.exists)")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "value == %@", "0 of 2 items checked")).firstMatch.exists, "the list is still folded after Undo")
        XCTAssertEqual(app.buttons["Fold Groceries"].label, "Expand list")
    }

    /// The rename field (task, sub-task, list item) that's open.
    @MainActor
    private func renameField(_ id: String) -> XCUIElement {
        let view = app.textViews[id]
        return view.exists ? view : app.textFields[id]
    }

    /// Long names for a task, a sub-task and a list item: the field wraps, Return saves the
    /// whole name (no line break), and the keyboard goes.
    @MainActor
    func testRenameLongTaskSubtaskAndItem() throws {
        launch()
        setUpErrands()
        let longTask = "Pack the gym bag with shoes, a towel, the water bottle, the lock and a change of clothes for Saturday"
        let longSub = "Running shoes and the spare insoles from the drawer under the stairs in the hall"
        let longItem = "Oat milk, the unsweetened one in the blue carton from the shelf by the bakery"

        // The list item first: renaming the task below scrolls the list under the header.
        app.staticTexts["Milk"].tap()
        var field = renameField("Item")
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.press(forDuration: 1.2)
        if app.menuItems["Select All"].waitForExistence(timeout: 2) { app.menuItems["Select All"].tap() }
        field.typeText(longItem)
        usleep(500_000)
        shot("rename-3-item-field")
        field.typeText("\n")
        XCTAssertTrue(app.staticTexts[longItem].waitForExistence(timeout: 3))
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3), "the keyboard goes after Return")
        XCTAssertTrue(app.buttons["Mark \(longItem) incomplete"].exists, "the item keeps its check")
        app.staticTexts["Pack bag"].tap()
        field = renameField("Task name")
        XCTAssertTrue(field.waitForExistence(timeout: 3), "tapping the name renames it")
        field.press(forDuration: 1.2)
        if app.menuItems["Select All"].waitForExistence(timeout: 2) { app.menuItems["Select All"].tap() }
        field.typeText(longTask)
        usleep(500_000)
        print("REVIEW: task rename field height \(field.frame.height)")
        shot("rename-1-task-field")
        field.typeText("\n")
        XCTAssertTrue(app.staticTexts[longTask].waitForExistence(timeout: 3), "Return saves the whole name")
        XCTAssertFalse(renameField("Task name").exists, "the field closes")
        XCTAssertTrue(app.buttons["Add sub-task to \(longTask)"].exists)

        app.staticTexts["Shoes"].tap()
        field = renameField("Sub-task")
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.press(forDuration: 1.2)
        if app.menuItems["Select All"].waitForExistence(timeout: 2) { app.menuItems["Select All"].tap() }
        field.typeText(longSub)
        usleep(500_000)
        shot("rename-2-subtask-field")
        field.typeText("\n")
        XCTAssertTrue(app.staticTexts[longSub].waitForExistence(timeout: 3))
        XCTAssertFalse(renameField("Sub-task").exists)

        shot("rename-4-saved")

        relaunch()
        openCard("Errands")
        XCTAssertTrue(app.staticTexts[longTask].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts[longSub].exists)
        XCTAssertTrue(app.staticTexts[longItem].exists)
    }

    /// This week only on and off puts every mode back; on, the card isn't in next week; off,
    /// it is, with its carry-over and repeating tasks; and it all survives a relaunch.
    @MainActor
    func testThisWeekOnlyOnOffAcrossWeeksAndRelaunch() throws {
        launch()
        openCard("Work")
        addTask("Report", type: "Checkbox", mode: "Carry Over")
        addTask("Standup", type: "Checkbox", mode: "Repeating")
        addTask("Lunch", type: "Checkbox", mode: "One-Time")
        closeKeyboard()
        XCTAssertTrue(app.buttons["Task options: Checkbox, Carry Over"].exists)
        XCTAssertTrue(app.buttons["Task options: Checkbox, Repeating"].exists)

        app.buttons["Edit Work"].tap()
        let toggle = app.switches["This week only"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 3))
        toggle.switches.firstMatch.tap()
        XCTAssertEqual(toggle.value as? String, "1")
        XCTAssertEqual(app.buttons.matching(identifier: "Task options: Checkbox, One-Time").count, 3)
        shot("twonly-1-on")
        toggle.switches.firstMatch.tap()
        XCTAssertEqual(toggle.value as? String, "0")
        XCTAssertTrue(app.buttons["Task options: Checkbox, Carry Over"].waitForExistence(timeout: 2), "modes come back")
        XCTAssertTrue(app.buttons["Task options: Checkbox, Repeating"].exists)
        XCTAssertEqual(app.buttons.matching(identifier: "Task options: Checkbox, One-Time").count, 1)

        // On, then next week: no Work card.
        toggle.switches.firstMatch.tap()
        app.buttons["Done editing Work"].tap()
        app.buttons["Next week"].tap()
        usleep(800_000)
        XCTAssertFalse(card("Work").exists, "a this-week-only card isn't in next week")
        XCTAssertFalse(app.buttons["Close Work"].exists)
        shot("twonly-2-next-week-on")
        app.buttons["Previous week"].tap()
        XCTAssertTrue(app.buttons["Close Work"].waitForExistence(timeout: 3), "the open card is open again")
        app.buttons["Edit Work"].tap()
        app.switches["This week only"].switches.firstMatch.tap()
        app.buttons["Done editing Work"].tap()
        app.buttons["Next week"].tap()
        XCTAssertTrue(app.buttons["Close Work"].waitForExistence(timeout: 3), "off: the card is in next week again")
        XCTAssertTrue(app.staticTexts["Report"].exists)
        XCTAssertTrue(app.staticTexts["Standup"].exists)
        XCTAssertFalse(app.staticTexts["Lunch"].exists, "one-time doesn't carry")
        shot("twonly-3-next-week-off")

        relaunch()
        openCard("Work")
        XCTAssertTrue(app.buttons["Task options: Checkbox, Carry Over"].exists)
        XCTAssertTrue(app.buttons["Task options: Checkbox, Repeating"].exists)
        XCTAssertTrue(app.buttons["Task options: Checkbox, One-Time"].exists)
    }

    /// A task half-typed in Add task, then a week swipe: it's added to the week it was typed
    /// in, not lost and not added to the next.
    @MainActor
    func testHalfTypedTaskThenWeekSwipe() throws {
        launch()
        openCard("Errands")
        let field = app.addTaskField
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText("Half typed")
        let thisWeek = weekTitle
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.32))
        start.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.33)))
        usleep(900_000)
        print("REVIEW: after swipe week = \(weekTitle) (was \(thisWeek)), keyboard = \(app.keyboards.firstMatch.exists)")
        shot("halftyped-1-after-swipe")
        XCTAssertNotEqual(weekTitle, thisWeek, "the swipe changed week")
        XCTAssertFalse(app.staticTexts["Half typed"].exists, "not added to next week")
        app.buttons["Previous week"].tap()
        XCTAssertTrue(app.staticTexts[thisWeek].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Half typed"].waitForExistence(timeout: 3), "added to the week it was typed in")
    }

    /// Renaming a list item in the card's edit mode, then deleting another item (no
    /// confirmation): the Undo must still be there once the keyboard goes.
    @MainActor
    func testDeleteWhileRenamingKeepsUndo() throws {
        launch()
        openCard("Errands")
        addTask("Groceries", type: "List", mode: "Repeating")
        let item = app.textFields["Add item"]
        XCTAssertTrue(item.waitForExistence(timeout: 3))
        typeLines(item, ["Milk", "Eggs", "Bread"])
        closeKeyboard()
        app.buttons["Edit Errands"].tap()
        app.staticTexts["Milk"].tap()
        let field = renameField("Item")
        XCTAssertTrue(field.waitForExistence(timeout: 3), "items rename in edit mode too")
        field.typeText(" oat")
        app.buttons["Delete item Eggs"].tap()
        XCTAssertFalse(app.staticTexts["Eggs"].exists)
        shot("rename-delete-1-keyboard-up")
        closeKeyboard()
        shot("rename-delete-2-keyboard-down")
        print("REVIEW: after closing keyboard: undo=\(app.buttons["Undo delete"].exists) milk=\(app.staticTexts["Milk oat"].exists)")
        XCTAssertTrue(app.staticTexts["Milk oat"].waitForExistence(timeout: 2), "the rename is saved")
        XCTAssertTrue(app.buttons["Undo delete"].exists, "the delete can still be undone")
        app.buttons["Undo delete"].tap()
        XCTAssertTrue(app.staticTexts["Eggs"].waitForExistence(timeout: 2))
    }

    /// Reordering by the handle in a card's edit mode: a tall open list taken below two
    /// short tasks lands last; the order is kept next week and after a relaunch.
    @MainActor
    func testReorderTallListBelowTasksKeepsOrder() throws {
        launch()
        openCard("Errands")
        addTask("Groceries", type: "List", mode: "Repeating")
        let item = app.textFields["Add item"]
        XCTAssertTrue(item.waitForExistence(timeout: 3))
        typeLines(item, ["Milk", "Eggs", "Bread", "Apples", "Rice", "Beans"])
        closeKeyboard()
        addTask("Bank", type: "Checkbox", mode: "Repeating")
        addTask("Post", type: "Checkbox", mode: "Repeating")
        closeKeyboard()

        app.buttons["Edit Errands"].tap()
        let list = app.buttons["Complete Groceries"]
        let post = app.buttons["Complete Post"]
        XCTAssertTrue(list.waitForExistence(timeout: 2))
        let handle = app.buttons["Delete Groceries"].coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5))
            .withOffset(CGVector(dx: 12, dy: 0))
        // The list's middle must pass Post's middle: drag by the list's height plus a bit.
        let listHeight = app.staticTexts["Beans"].frame.maxY - list.frame.minY
        handle.press(forDuration: 0.3, thenDragTo: handle.withOffset(CGVector(dx: 0, dy: post.frame.midY - list.frame.midY + listHeight / 2 + 20)))
        let moved = NSPredicate { _, _ in list.frame.minY > post.frame.minY }
        wait(for: [XCTNSPredicateExpectation(predicate: moved, object: nil)], timeout: 5)
        shot("reorder-1-dropped")
        app.buttons["Done editing Errands"].tap()
        XCTAssertTrue(app.buttons["Complete Bank"].frame.minY < post.frame.minY)

        app.buttons["Next week"].tap()
        usleep(900_000)
        XCTAssertTrue(app.buttons["Complete Groceries"].waitForExistence(timeout: 3))
        XCTAssertGreaterThan(app.buttons["Complete Groceries"].frame.minY, app.buttons["Complete Post"].frame.minY, "next week keeps the order")
        app.buttons["Previous week"].tap()
        relaunch()
        openCard("Errands")
        XCTAssertGreaterThan(app.buttons["Complete Groceries"].frame.minY, app.buttons["Complete Post"].frame.minY, "kept after a relaunch")
        XCTAssertGreaterThan(app.buttons["Complete Post"].frame.minY, app.buttons["Complete Bank"].frame.minY)
    }

    /// Smart Add sessions (rules only, as in a simulator): "Gym 3 times 45 min" becomes a
    /// 2h 15m goal that counts 45 a tap; a list doesn't get its own title as an item.
    @MainActor
    func testSmartAddSessionGoalAndList() throws {
        launch(["-smartAddRules", "-smartAddDelay", "0.5"])
        openCard("Fitness")
        let field = app.addTaskField
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText("Gym 3 times 45 min")
        app.buttons["Smart Add"].tap()
        XCTAssertTrue(app.staticTexts["0m / 2h 15m"].waitForExistence(timeout: 5), "135 minutes")
        XCTAssertTrue(app.buttons["Add 45 minutes"].exists, "counts 45 a tap")
        XCTAssertTrue(app.buttons["Task options: Goal, One-Time"].exists)
        app.buttons["Add 45 minutes"].tap()
        XCTAssertTrue(app.staticTexts["45m / 2h 15m"].waitForExistence(timeout: 2))
        shot("smartadd-1-gym")

        let field2 = app.addTaskField
        field2.tap()
        field2.typeText("Groceries: milk, eggs")
        app.buttons["Smart Add"].tap()
        XCTAssertTrue(app.buttons["Fold Groceries"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Milk"].exists || app.staticTexts["milk"].exists)
        XCTAssertFalse(app.buttons["Complete Groceries"].exists && app.staticTexts.matching(identifier: "Groceries").count > 1,
                       "the list's title isn't one of its items")
        shot("smartadd-2-list")
    }

    /// A long task name typed into the wrapping rename field of a task low on the screen:
    /// the line being typed (the caret's) must stay above the keyboard, and the keyboard's
    /// Done button must not cover the task's type and mode button.
    @MainActor
    func testWrappedRenameFieldStaysAboveKeyboard() throws {
        launch()
        setUpErrands()
        let longTask = "Pack the gym bag with shoes, a towel, the water bottle, the lock and a change of clothes for Saturday"
        app.staticTexts["Pack bag"].tap()
        let field = renameField("Task name")
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 3))
        field.typeText(" with shoes, a towel, the water bottle, the lock and a change of clothes for Saturday")
        usleep(800_000)
        shot("rename-keyboard-1-typed")
        let options = app.buttons["Task options: Checkbox, Carry Over"]
        let done = app.buttons["Done"].firstMatch
        print("REVIEW: field \(field.frame) keyboard top \(keyboard.frame.minY) options \(options.frame) done \(done.frame)")
        XCTAssertLessThanOrEqual(field.frame.maxY, keyboard.frame.minY + 1, "the whole rename field (and its caret line) is above the keyboard")
        XCTAssertFalse(options.frame.intersects(done.frame), "the keyboard's Done button doesn't cover the task's options")
        field.typeText("\n")
        XCTAssertTrue(app.staticTexts[longTask].waitForExistence(timeout: 3))
    }

    /// A folded list in the card's edit mode: its count, chevron, type/mode, trash and
    /// handle leave the title so little room that "Groceries" breaks mid-word ("Groceri / es").
    @MainActor
    func testFoldedListTitleFitsInEditMode() throws {
        launch()
        openCard("Errands")
        addTask("Groceries", type: "List", mode: "Repeating")
        let item = app.textFields["Add item"]
        XCTAssertTrue(item.waitForExistence(timeout: 3))
        typeLines(item, ["Milk", "Eggs"])
        closeKeyboard()
        let title = app.staticTexts["Groceries"]
        let oneLine = title.frame.height
        app.buttons["Fold Groceries"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "value == %@", "0 of 2 items checked")).firstMatch.waitForExistence(timeout: 2))
        app.buttons["Edit Errands"].tap()
        XCTAssertTrue(app.buttons["Delete Groceries"].waitForExistence(timeout: 2))
        usleep(500_000)
        shot("folded-title-edit-mode")
        print("REVIEW: title height open \(oneLine), folded in edit mode \(title.frame.height) width \(title.frame.width)")
        XCTAssertLessThan(title.frame.height, oneLine * 1.5, "a one-word title stays on one line")
    }
}
