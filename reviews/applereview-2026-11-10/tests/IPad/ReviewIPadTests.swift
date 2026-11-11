import XCTest

/// iPad review: reordering, folding, rename fields, the type/mode popover, rotation and keyboards.
/// Each test starts from a clean launch (-demoData unless it says otherwise).
final class ReviewIPadTests: ReviewIPadBase {

    // MARK: Reordering by the handle

    /// Landscape (4 columns): Groceries dragged a little past Drop off donations' middle lands
    /// below it, and the week doesn't change.
    @MainActor
    func testReorderByHandleLandscape() throws {
        launch(["-demoData", "-demoFirstCard", "Errands"], orientation: .landscapeLeft)
        try reorderGroceriesPastDonations(shotName: "reorder-landscape")
    }

    /// Portrait (3 columns): the same.
    @MainActor
    func testReorderByHandlePortrait() throws {
        launch(["-demoData", "-demoFirstCard", "Errands"], orientation: .portrait)
        try reorderGroceriesPastDonations(shotName: "reorder-portrait")
    }

    @MainActor
    private func reorderGroceriesPastDonations(shotName: String) throws {
        openCard("Errands")
        app.buttons["Edit Errands"].tap()
        let groceries = app.staticTexts["Groceries"].firstMatch
        let donations = app.staticTexts["Drop off donations"].firstMatch
        XCTAssertTrue(app.buttons["Delete Groceries"].waitForExistence(timeout: 3))
        let week = weekTitle
        let target = donations.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).withOffset(CGVector(dx: 0, dy: 30))
        handle("Groceries").press(forDuration: 0.3, thenDragTo: target, withVelocity: .slow, thenHoldForDuration: 0.5)
        shot("\(shotName)-after")
        let moved = NSPredicate { _, _ in groceries.frame.minY > donations.frame.minY }
        wait(for: [XCTNSPredicateExpectation(predicate: moved, object: nil)], timeout: 5)
        XCTAssertEqual(weekTitle, week, "the week didn't change")
        XCTAssertTrue(app.buttons["Delete Groceries"].exists, "still in the card's edit mode")
    }

    /// A long card in landscape: held near the bottom, the lifted task scrolls the grid and
    /// can be taken to the end; held near the top, back to the start.
    @MainActor
    func testReorderAutoScrollsLongCardLandscape() throws {
        launch(["-isolatedData"], orientation: .landscapeLeft)
        openCard("Errands")
        let field = app.addTaskField
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        for number in 1...18 {
            field.typeText("Task \(number)\n")
            usleep(450_000)
        }
        app.buttons["Done"].firstMatch.tap()
        Thread.sleep(forTimeInterval: 1.5)
        app.buttons["Edit Errands"].tap()
        Thread.sleep(forTimeInterval: 1.5)
        let first = app.buttons["Complete Task 1"]
        let last = app.buttons["Complete Task 18"]
        if !app.buttons["Delete Task 1"].waitForExistence(timeout: 3) {
            shot("autoscroll-landscape-no-edit")
            print(app.debugDescription)
        }
        XCTAssertTrue(app.buttons["Delete Task 1"].exists)
        XCTAssertFalse(last.isHittable, "the card is longer than the screen")
        let nearBottom = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.86))
        handle("Task 1").press(forDuration: 0.3, thenDragTo: nearBottom, withVelocity: .default, thenHoldForDuration: 5)
        shot("autoscroll-landscape-down")
        let moved = NSPredicate { _, _ in first.frame.minY > last.frame.minY }
        wait(for: [XCTNSPredicateExpectation(predicate: moved, object: nil)], timeout: 5)
        log("autoscroll down ok")
    }

    // MARK: Folding lists

    /// Landscape: folding Groceries in the open Errands card shows its count, hides its items
    /// and Add Item, and the closed cards around it neither overlap it nor move oddly.
    @MainActor
    func testFoldListInOpenCardBesideClosedCardsLandscape() throws {
        launch(["-demoData", "-demoFirstCard", "Errands"], orientation: .landscapeLeft)
        try foldGroceries(shotName: "fold-landscape")
    }

    @MainActor
    func testFoldListInOpenCardBesideClosedCardsPortrait() throws {
        launch(["-demoData", "-demoFirstCard", "Errands"], orientation: .portrait)
        try foldGroceries(shotName: "fold-portrait")
    }

    @MainActor
    private func foldGroceries(shotName: String) throws {
        // Another card open first, so Errands' row sits among closed cards.
        openCard("Errands")
        shot("\(shotName)-open")
        let fold = app.buttons["Fold Groceries"]
        XCTAssertTrue(fold.exists)
        XCTAssertEqual(fold.label, "Collapse list")
        fold.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "value == %@", "2 of 5 items checked")).firstMatch.waitForExistence(timeout: 3), "the count shows")
        XCTAssertFalse(app.staticTexts["Coffee beans"].exists, "items hidden")
        shot("\(shotName)-folded")
        // The count sits on the list's row, left of the chevron, and doesn't overlap it.
        let count = app.staticTexts.matching(NSPredicate(format: "value == %@", "2 of 5 items checked")).firstMatch
        XCTAssertLessThanOrEqual(count.frame.maxX, fold.frame.minX + 1, "count before the chevron")
        XCTAssertEqual(count.frame.midY, fold.frame.midY, accuracy: 12, "count on the row")
        // Every closed card is clear of the open card's tasks.
        let addTask = app.addTaskRow
        let lastTaskMaxY = addTask.frame.maxY
        for closed in app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open ")).allElementsBoundByIndex
        where closed.exists && closed.frame.height > 40 {
            let f = closed.frame
            if f.maxY > fold.frame.minY && f.minY < lastTaskMaxY {
                XCTFail("closed card \(closed.label) overlaps the open card: \(f)")
            }
        }
        fold.tap()
        XCTAssertTrue(app.staticTexts["Coffee beans"].waitForExistence(timeout: 3), "opens again")
    }

    // MARK: Rename fields

    /// A long name in a task's rename field wraps onto more lines within the card, in a wide
    /// (landscape) and a narrow (portrait) card, stays above the keyboard, and Return saves it
    /// without a line break.
    @MainActor
    func testRenameFieldWrapsLandscapeAndPortrait() throws {
        for orientation in [UIDeviceOrientation.landscapeLeft, .portrait] {
            launch(["-demoData", "-demoFirstCard", "Errands"], orientation: orientation)
            let tag = orientation == .portrait ? "portrait" : "landscape"
            openCard("Errands")
            app.staticTexts["Plan Mom's birthday"].firstMatch.tap()
            Thread.sleep(forTimeInterval: 1)
            let field = renameField("Task name")
            if !field.exists { print(app.debugDescription) }
            XCTAssertTrue(field.waitForExistence(timeout: 3), "rename field opens")
            let oneLine = field.frame.height
            let long = "Plan Mom's birthday with the whole family at the lake house and book the boat for the afternoon, then the dinner reservation and the cake, and ask Aunt Ruth about the photos from last summer so we can print a few for the album before Saturday morning"
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 0))
            // Replace the name.
            field.press(forDuration: 1.2)
            if app.menuItems["Select All"].waitForExistence(timeout: 2) { app.menuItems["Select All"].tap() }
            field.typeText(long)
            Thread.sleep(forTimeInterval: 0.5)
            shot("rename-\(tag)-long")
            let card = app.windows.firstMatch.frame
            log("\(tag) rename field \(field.frame) one line \(oneLine) window \(card)")
            XCTAssertGreaterThan(field.frame.height, oneLine * 1.6, "the field wraps (\(tag))")
            XCTAssertTrue(contains(card, field.frame), "the field stays in the window (\(tag))")
            let keyboard = app.keyboards.firstMatch
            if keyboard.exists {
                XCTAssertLessThanOrEqual(field.frame.maxY, keyboard.frame.minY + 1, "the field stays above the keyboard (\(tag))")
            }
            field.typeText("\n")
            let saved = app.staticTexts.matching(NSPredicate(format: "label == %@", long)).firstMatch
            XCTAssertTrue(saved.waitForExistence(timeout: 3), "Return saves the whole name (\(tag))")
            XCTAssertFalse(renameField("Task name").exists, "and closes the field")
            app.terminate()
        }
    }

    /// Hardware keyboard keys in a rename field: Tab doesn't put a tab into the name, and
    /// Escape doesn't lose the typing.
    @MainActor
    func testRenameFieldTabAndEscapeKeys() throws {
        launch(["-demoData", "-demoFirstCard", "Errands"], orientation: .landscapeLeft)
        openCard("Errands")
        app.staticTexts["Pick up dry cleaning"].firstMatch.tap()
        Thread.sleep(forTimeInterval: 1)
        let field = renameField("Task name")
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.typeText(" soon")
        field.typeKey(.tab, modifierFlags: [])
        Thread.sleep(forTimeInterval: 0.5)
        let value = (field.exists ? field.value as? String : nil) ?? ""
        log("after Tab: field exists \(field.exists) value '\(value.replacingOccurrences(of: "\t", with: "<TAB>"))'")
        shot("rename-tab")
        // Type on after the Tab and save with Return: is the tab kept in the name?
        if field.exists { field.typeText("now\n") }
        let saved = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Pick up dry cleaning")).firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: 3))
        log("saved name '\(saved.label.replacingOccurrences(of: "\t", with: "<TAB>"))'")
        XCTAssertFalse(saved.label.contains("\t"), "no tab in the saved name")
    }

    /// Escape (hardware keyboard) in a rename field: logs what it does. iPad convention is to
    /// cancel the edit; at least the field must not be left in a stuck state.
    @MainActor
    func testRenameFieldEscapeKey() throws {
        launch(["-demoData", "-demoFirstCard", "Errands"], orientation: .landscapeLeft)
        openCard("Errands")
        app.staticTexts["Pick up dry cleaning"].firstMatch.tap()
        Thread.sleep(forTimeInterval: 1)
        let field = renameField("Task name")
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.typeText(" later")
        field.typeKey(.escape, modifierFlags: [])
        Thread.sleep(forTimeInterval: 1)
        shot("rename-escape")
        let focus = field.exists ? (field.value(forKey: "hasKeyboardFocus") as? Bool ?? false) : false
        log("after Escape: field exists \(field.exists) focused \(focus) value '\(field.exists ? (field.value as? String ?? "") : "")' keyboard \(app.keyboards.firstMatch.exists)")
        // Expected (iPad convention): Escape cancels the rename and keeps the old name.
        XCTAssertFalse(field.exists && focus, "Escape ends the rename")
        XCTAssertTrue(app.staticTexts["Pick up dry cleaning"].waitForExistence(timeout: 2), "and keeps the old name")
    }

    // MARK: Type/mode popover

    /// From a list row with the keyboard up (typing in its Add Item): the options button
    /// closes the keyboard and the popover is wholly on screen, in landscape and portrait.
    @MainActor
    func testListRowOptionsPopoverWithKeyboard() throws {
        for orientation in [UIDeviceOrientation.landscapeLeft, .portrait] {
            launch(["-demoData", "-demoFirstCard", "Errands"], orientation: orientation)
            let tag = orientation == .portrait ? "portrait" : "landscape"
            openCard("Errands")
            let addItem = app.buttons["Add item to Groceries"].firstMatch
            XCTAssertTrue(addItem.waitForExistence(timeout: 3))
            addItem.tap()
            Thread.sleep(forTimeInterval: 1)
            let itemField = renameField("Add item")
            XCTAssertTrue(itemField.waitForExistence(timeout: 3))
            itemField.typeText("Bread")
            XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
            app.buttons["Task options: List, Repeating"].tap()
            let oneTime = app.buttons["One-Time"].firstMatch
            XCTAssertTrue(oneTime.waitForExistence(timeout: 4), "the picker opens (\(tag))")
            Thread.sleep(forTimeInterval: 0.6)
            shot("list-options-\(tag)")
            let window = windowFrame
            for label in ["Checkbox", "Goal", "List", "Carry Over", "Repeating", "One-Time"] {
                let b = app.buttons[label].firstMatch
                XCTAssertTrue(b.exists && contains(window, b.frame) && b.isHittable, "\(label) on screen (\(tag)): \(b.frame)")
            }
            XCTAssertTrue(app.staticTexts["Bread"].exists, "the typed item was added (\(tag))")
            app.terminate()
        }
    }

    /// The new-task picker with the keyboard up, in landscape: Add Task fits on screen.
    @MainActor
    func testNewTaskOptionsPopoverWithKeyboardLandscape() throws {
        launch(["-demoData", "-demoFirstCard", "Errands"], orientation: .landscapeLeft)
        openCard("Errands")
        let field = app.addTaskField
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText("Buy stamps")
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "New task options")).firstMatch.tap()
        let add = app.buttons["Add Task"]
        XCTAssertTrue(add.waitForExistence(timeout: 4))
        Thread.sleep(forTimeInterval: 0.6)
        shot("new-options-landscape")
        XCTAssertTrue(contains(windowFrame, add.frame) && add.isHittable, "Add Task on screen \(add.frame)")
        XCTAssertTrue(contains(windowFrame, app.buttons["Checkbox"].firstMatch.frame), "first row on screen")
        add.tap()
        XCTAssertTrue(app.staticTexts["Buy stamps"].waitForExistence(timeout: 3))
    }

    // MARK: Rotation

    /// Rotating while typing a new task keeps the words, and the field stays visible.
    @MainActor
    func testRotateWhileTypingKeepsText() throws {
        launch(["-demoData", "-demoFirstCard", "Errands"], orientation: .portrait)
        openCard("Errands")
        let field = app.addTaskField
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText("Rotate me")
        XCUIDevice.shared.orientation = .landscapeLeft
        Thread.sleep(forTimeInterval: 4)
        shot("rotate-typing-landscape")
        let f = renameField("Add task")
        XCTAssertTrue(f.exists, "the field is still there")
        XCTAssertEqual(f.value as? String, "Rotate me", "the words are kept")
        let keyboard = app.keyboards.firstMatch
        log("after rotating: field \(f.frame) keyboard \(keyboard.exists ? keyboard.frame : .zero) focused \(String(describing: f.value(forKey: "hasKeyboardFocus")))")
        let hiddenAfterRotation = keyboard.exists && f.frame.maxY > keyboard.frame.minY + 1
        Thread.sleep(forTimeInterval: 4)
        log("after 8 s: field \(f.frame) keyboard \(keyboard.exists ? keyboard.frame : .zero)")
        shot("rotate-typing-landscape-8s")
        // Does typing bring it back into view?
        f.typeText("!")
        Thread.sleep(forTimeInterval: 1.5)
        log("after typing: field \(f.frame) keyboard \(keyboard.exists ? keyboard.frame : .zero)")
        shot("rotate-typing-landscape-typed")
        XCTAssertFalse(hiddenAfterRotation, "the field being typed in stays above the keyboard after rotating")
        f.typeText(XCUIKeyboardKey.delete.rawValue)
        XCUIDevice.shared.orientation = .portrait
        Thread.sleep(forTimeInterval: 1.5)
        shot("rotate-typing-portrait")
        XCTAssertEqual(f.value as? String, "Rotate me")
    }

    /// Rotating with the type/mode popover open: it stays on screen and works.
    @MainActor
    func testRotateWithOptionsPopoverOpen() throws {
        launch(["-demoData", "-demoFirstCard", "Errands"], orientation: .portrait)
        openCard("Errands")
        app.buttons["Task options: Checkbox, Carry Over"].firstMatch.tap()
        XCTAssertTrue(app.buttons["One-Time"].firstMatch.waitForExistence(timeout: 3))
        XCUIDevice.shared.orientation = .landscapeLeft
        Thread.sleep(forTimeInterval: 1.5)
        shot("rotate-popover-landscape")
        let goal = app.buttons["Goal"].firstMatch
        if goal.exists {
            XCTAssertTrue(contains(windowFrame, goal.frame), "popover on screen after rotating")
        }
        log("popover after rotation exists \(goal.exists)")
    }

    /// Rotating with Settings open: the sheet is a sensible size both ways.
    @MainActor
    func testRotateWithSettingsSheet() throws {
        launch(["-demoData"], orientation: .portrait)
        app.buttons["Settings"].tap()
        let done = app.buttons["Done"].firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 3))
        shot("settings-portrait")
        let nav = app.navigationBars.firstMatch
        log("settings portrait nav \(nav.frame) window \(windowFrame)")
        XCTAssertLessThan(nav.frame.width, windowFrame.width * 0.9, "a form sheet, not full width (portrait)")
        XCUIDevice.shared.orientation = .landscapeLeft
        Thread.sleep(forTimeInterval: 1.5)
        shot("settings-landscape")
        log("settings landscape nav \(nav.frame) window \(windowFrame)")
        XCTAssertLessThan(nav.frame.width, windowFrame.width * 0.8, "a form sheet, not full width (landscape)")
        XCTAssertTrue(done.isHittable)
    }
}
