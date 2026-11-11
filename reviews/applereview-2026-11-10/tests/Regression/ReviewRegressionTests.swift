import XCTest

/// Regression review of the 1.0.3 fixes (2026-11-10): tests around each change, not the
/// fixed bugs themselves. Every test starts from a clean launch with throwaway data.
final class ReviewRegressionTests: XCTestCase {
    private var shotDir: String { ProcessInfo.processInfo.environment["SHOT_DIR"] ?? NSTemporaryDirectory() }

    override func setUp() {
        continueAfterFailure = false
    }

    // MARK: - Helpers

    @MainActor
    private func launch(_ arguments: [String]) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
        if app.staticTexts["Welcome to Tasquel"].waitForExistence(timeout: 2) { app.buttons["Skip"].tap() }
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 10), "the app is up")
        return app
    }

    @MainActor
    private func shot(_ app: XCUIApplication, _ name: String) {
        Thread.sleep(forTimeInterval: 0.7)
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try? png.write(to: URL(fileURLWithPath: "\(shotDir)/\(name).png"))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func openCard(_ app: XCUIApplication, _ name: String) {
        let card = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open \(name),")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 8), "\(name) card")
        card.tap()
        XCTAssertTrue(app.buttons["Edit \(name)"].waitForExistence(timeout: 5), "\(name) opened")
    }

    /// The first element of `query` that's on the screen (the week pager lays the weeks
    /// before and after beside this one).
    @MainActor
    private func onScreen(_ query: XCUIElementQuery, _ app: XCUIApplication, timeout: TimeInterval = 5) -> XCUIElement? {
        let screen = app.windows.firstMatch.frame
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            for element in query.allElementsBoundByIndex where element.exists {
                let frame = element.frame
                if !frame.isEmpty, frame.midX > screen.minX, frame.midX < screen.maxX { return element }
            }
            Thread.sleep(forTimeInterval: 0.3)
        } while Date() < deadline
        return nil
    }

    @MainActor
    private func text(_ app: XCUIApplication, _ label: String, timeout: TimeInterval = 5) -> XCUIElement? {
        onScreen(app.staticTexts.matching(NSPredicate(format: "label == %@", label)), app, timeout: timeout)
    }

    @MainActor
    private func button(_ app: XCUIApplication, _ label: String, timeout: TimeInterval = 5) -> XCUIElement? {
        onScreen(app.buttons.matching(NSPredicate(format: "label == %@", label)), app, timeout: timeout)
    }

    @MainActor
    private func weekTitle(_ app: XCUIApplication) -> String {
        app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Week of")).firstMatch.label
    }

    @MainActor
    private func setThisWeekOnly(_ app: XCUIApplication, card: String, on: Bool) {
        app.buttons["Edit \(card)"].tap()
        let toggle = app.switches["This week only"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 3))
        if (toggle.value as? String == "1") != on { toggle.switches.firstMatch.tap() }
        XCTAssertEqual(toggle.value as? String, on ? "1" : "0")
        app.buttons["Done editing \(card)"].tap()
        XCTAssertTrue(app.buttons["Edit \(card)"].waitForExistence(timeout: 3))
    }

    /// Taps a task's name and types `suffix` after it, then Return.
    @MainActor
    private func rename(_ app: XCUIApplication, _ title: String, appending suffix: String) {
        guard let name = text(app, title) else { return XCTFail("no task \(title)") }
        name.tap()
        let field = app.textFields["Task name"]
        XCTAssertTrue(field.waitForExistence(timeout: 3), "rename field")
        Thread.sleep(forTimeInterval: 0.5)
        field.typeText(suffix)
        Thread.sleep(forTimeInterval: 0.4)
        field.typeText("\n")
        XCTAssertTrue(field.waitForNonExistence(timeout: 3), "Return saves and closes the rename field")
    }

    // MARK: - This week only

    /// Counting a step on a repeating goal's copy while its card is This week only, then
    /// turning the switch off: the copy is repeating again and, like any repeating copy
    /// whose progress was counted, still follows its task (spec: "A repeating copy keeps its
    /// own progress while following its source").
    @MainActor
    func testRepeatingGoalStepWhileThisWeekOnlyStillFollowsItsTask() throws {
        let app = launch(["-demoData", "-demoFirstCard", "Fitness"])
        openCard(app, "Fitness")
        XCTAssertNotNil(text(app, "Run"))
        app.buttons["Next week"].tap()
        XCTAssertNotNil(text(app, "Run"), "next week has Run's copy")

        setThisWeekOnly(app, card: "Fitness", on: true)
        guard let step = button(app, "Add 1") else { return XCTFail("Run's + step") }
        step.tap()
        XCTAssertNotNil(text(app, "1/3", timeout: 3), "the step counted")
        setThisWeekOnly(app, card: "Fitness", on: false)
        XCTAssertNotNil(button(app, "Task options: Goal, Repeating"), "Run is repeating again")
        shot(app, "twonly-goal-next-week-after-off")

        // Control, as a person would check: a rename of the task this week reaches the copy.
        app.buttons["This Week"].tap()
        XCTAssertTrue(app.staticTexts["Run"].waitForExistence(timeout: 5))
        rename(app, "Run", appending: " club")
        XCTAssertNotNil(text(app, "Run club"))
        app.buttons["Next week"].tap()
        Thread.sleep(forTimeInterval: 1)
        shot(app, "twonly-goal-next-week-after-rename")
        print("REVIEW: next week shows Run club? \(text(app, "Run club", timeout: 2) != nil) Run? \(text(app, "Run", timeout: 1) != nil)")
        XCTAssertNotNil(text(app, "Run club", timeout: 3),
                        "a repeating copy whose progress was counted still follows its task's rename")
        XCTAssertNotNil(text(app, "1/3", timeout: 2), "and keeps its own progress")
    }

    /// The same without counting a step: the untouched copy follows the rename after This
    /// week only goes on and off.
    @MainActor
    func testUntouchedCopyFollowsAfterThisWeekOnlyOnOff() throws {
        let app = launch(["-demoData", "-demoFirstCard", "Fitness"])
        openCard(app, "Fitness")
        app.buttons["Next week"].tap()
        XCTAssertNotNil(text(app, "Run"))
        setThisWeekOnly(app, card: "Fitness", on: true)
        XCTAssertNotNil(button(app, "Task options: Goal, One-Time"), "on: one-time")
        setThisWeekOnly(app, card: "Fitness", on: false)
        app.buttons["This Week"].tap()
        XCTAssertTrue(app.staticTexts["Run"].waitForExistence(timeout: 5))
        rename(app, "Run", appending: " club")
        app.buttons["Next week"].tap()
        XCTAssertNotNil(text(app, "Run club"), "the untouched copy follows the rename")
    }

    /// A rename made while This week only is on survives turning it off and a relaunch.
    @MainActor
    func testThisWeekOnlyRenameSurvivesOffAndRelaunch() throws {
        let id = "rr-twonly-\(UUID().uuidString)"
        let app = launch(["-demoData", "-isolatedDataID", id, "-demoFirstCard", "Fitness"])
        openCard(app, "Fitness")
        app.buttons["Next week"].tap()
        XCTAssertNotNil(text(app, "Yoga"))
        setThisWeekOnly(app, card: "Fitness", on: true)
        rename(app, "Yoga", appending: " flow")
        setThisWeekOnly(app, card: "Fitness", on: false)
        XCTAssertNotNil(text(app, "Yoga flow"))

        app.terminate()
        app.launchArguments = ["-isolatedDataID", id]
        app.launch()
        if app.staticTexts["Welcome to Tasquel"].waitForExistence(timeout: 2) { app.buttons["Skip"].tap() }
        XCTAssertTrue(app.buttons["Next week"].waitForExistence(timeout: 10))
        app.buttons["Next week"].tap()
        openCard(app, "Fitness")
        shot(app, "twonly-relaunch-next-week")
        XCTAssertNotNil(text(app, "Yoga flow"), "the rename survived")
        XCTAssertNil(text(app, "Yoga", timeout: 1), "no second, unrenamed copy came back")
        app.buttons["Edit Fitness"].tap()
        XCTAssertEqual(app.switches["This week only"].value as? String, "0", "still off after the relaunch")
    }

    // MARK: - Header

    /// On iPhone the header is as before: the mark 12pt from the left, the title centered,
    /// Open/Close All 12pt from the right, and the mark goes back to this week.
    @MainActor
    func testHeaderOnIPhoneUnchanged() throws {
        for appearance in ["system", "retro"] {
            let app = launch(["-demoData", "-demoAppearance", appearance])
            let screen = app.windows.firstMatch.frame
            let mark = app.buttons["This Week"]
            XCTAssertTrue(mark.waitForExistence(timeout: 5))
            let title = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Week of")).firstMatch
            let all = app.buttons["Open all cards"]
            print("REVIEW: header \(appearance) mark \(mark.frame) title \(title.frame) all \(all.frame) screen \(screen)")
            XCTAssertEqual(mark.frame.minX, 12, accuracy: 1, "the mark at the left")
            XCTAssertEqual(mark.frame.width, 44, accuracy: 1)
            XCTAssertEqual(title.frame.midX, screen.midX, accuracy: 2, "the title centered")
            XCTAssertEqual(screen.maxX - all.frame.maxX, 12, accuracy: 1, "Open/Close All at the right")
            XCTAssertEqual(mark.frame.midY, all.frame.midY, accuracy: 1)
            shot(app, "header-\(appearance)")
            let thisWeek = weekTitle(app)
            app.buttons["Next week"].tap()
            app.buttons["Next week"].tap()
            XCTAssertNotEqual(weekTitle(app), thisWeek)
            mark.tap()
            let titleQuery = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Week of")).firstMatch
            let back = NSPredicate { _, _ in titleQuery.label == thisWeek }
            wait(for: [XCTNSPredicateExpectation(predicate: back, object: nil)], timeout: 5)
            app.terminate()
        }
    }

    // MARK: - Rows at text sizes

    @MainActor
    private func checkRows(size: String?, name: String) {
        var arguments = ["-demoData", "-demoFirstCard", "Errands"]
        if let size { arguments += ["-UIPreferredContentSizeCategoryName", size] }
        let app = launch(arguments)
        let screen = app.windows.firstMatch.frame
        openCard(app, "Errands")
        let accessibilitySize = size?.contains("Accessibility") == true

        func checkIcons(_ context: String) {
            for title in ["Groceries", "Plan Mom's birthday", "Drop off donations", "Pick up dry cleaning"] {
                let options = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Task options:"))
                let names = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", title))
                guard let nameText = onScreen(names, app, timeout: 2) else { continue }  // scrolled away
                // The options button on the same task: the nearest one below the name's top.
                let candidates = options.allElementsBoundByIndex.filter {
                    $0.frame.midX > 0 && $0.frame.midX < screen.maxX && $0.frame.minY >= nameText.frame.minY - 20
                }
                guard let button = candidates.min(by: { $0.frame.minY < $1.frame.minY }) else { continue }
                print("REVIEW: \(name) \(context) \(title) name \(nameText.frame) options \(button.frame)")
                XCTAssertLessThanOrEqual(button.frame.maxX, screen.maxX, "\(title)'s icons stay on the screen (\(context))")
                XCTAssertGreaterThan(nameText.frame.width, 60, "\(title)'s name keeps room (\(context))")
                if accessibilitySize {
                    XCTAssertGreaterThanOrEqual(button.frame.minY + 1, nameText.frame.maxY - 2, "icons under the name (\(context))")
                } else {
                    XCTAssertLessThanOrEqual(nameText.frame.maxX, button.frame.minX + 1, "name and icons don't overlap (\(context))")
                }
            }
        }

        checkIcons("open")
        shot(app, "rows-\(name)-open")

        // Fold the list: its count joins the name.
        let fold = app.buttons["Fold Groceries"]
        XCTAssertTrue(fold.waitForExistence(timeout: 3))
        XCTAssertLessThanOrEqual(fold.frame.maxX, screen.maxX)
        fold.tap()
        XCTAssertNotNil(text(app, "Groceries"), "the folded list's count")
        XCTAssertNil(text(app, "Coffee beans", timeout: 1), "its items are folded away")
        checkIcons("folded")
        shot(app, "rows-\(name)-folded")

        // The card's edit mode: trash and handle.
        app.buttons["Edit Errands"].tap()
        let delete = app.buttons["Delete Plan Mom's birthday"]
        XCTAssertTrue(delete.waitForExistence(timeout: 3))
        XCTAssertLessThanOrEqual(delete.frame.maxX + 36, screen.maxX + 1, "the handle beside the trash fits on the screen")
        XCTAssertTrue(app.buttons["Fold Groceries"].exists, "the chevron stays in edit mode")
        checkIcons("edit")
        shot(app, "rows-\(name)-edit")
        app.buttons["Done editing Errands"].tap()

        // The type/mode popover of an existing task.
        let options = app.buttons["Task options: Checkbox, Carry Over"].firstMatch
        XCTAssertTrue(options.waitForExistence(timeout: 3))
        if !options.isHittable { app.swipeUp() }
        options.tap()
        let done = app.buttons["Done"].firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 3), "the picker opened")
        shot(app, "rows-\(name)-picker")
        let pickerHeader = app.staticTexts["AFTER THIS WEEK"]
        print("REVIEW: \(name) picker done \(done.frame) hittable \(done.isHittable) header \(pickerHeader.frame)")
        XCTAssertLessThanOrEqual(pickerHeader.frame.maxX, screen.maxX + 1, "the picker fits across the screen")
        if !done.isHittable { app.swipeUp() }
        XCTAssertTrue(done.isHittable, "Done can be reached")
        done.tap()
        XCTAssertTrue(pickerHeader.waitForNonExistence(timeout: 3))

        // Rename a sub-task to something long, and the goal's steps.
        if let item = text(app, "Book dinner") {
            item.tap()
            let field = app.textFields["Sub-task"]
            XCTAssertTrue(field.waitForExistence(timeout: 3))
            Thread.sleep(forTimeInterval: 0.5)
            field.typeText(" at the place by the river")
            Thread.sleep(forTimeInterval: 0.4)
            shot(app, "rows-\(name)-rename-subtask")
            field.typeText("\n")
            XCTAssertTrue(field.waitForNonExistence(timeout: 3))
            XCTAssertNotNil(text(app, "Book dinner at the place by the river"))
        } else {
            XCTFail("Book dinner sub-task")
        }
        shot(app, "rows-\(name)-after-rename")
    }

    @MainActor func testRowsAtDefaultSize() throws { checkRows(size: nil, name: "default") }
    @MainActor func testRowsAtXXXL() throws { checkRows(size: "UICTContentSizeCategoryXXXL", name: "xxxl") }
    @MainActor func testRowsAtAccessibilityXXXL() throws { checkRows(size: "UICTContentSizeCategoryAccessibilityXXXL", name: "ax5") }

    // MARK: - Undo

    /// Deleting a sub-task, then folding a list, then Undo: the sub-task is back, the list
    /// stays folded and its count is right.
    @MainActor
    func testUndoSubtaskDeleteThenFoldKeepsFoldAndCount() throws {
        let app = launch(["-demoData", "-demoFirstCard", "Errands"])
        openCard(app, "Errands")
        app.buttons["Edit Errands"].tap()
        let deleteItem = app.buttons["Delete item Lemons"]
        XCTAssertTrue(deleteItem.waitForExistence(timeout: 3))
        deleteItem.tap()
        app.buttons["Fold Groceries"].tap()
        XCTAssertNotNil(text(app, "Groceries", timeout: 2))
        let undo = app.buttons["Undo delete"]
        XCTAssertTrue(undo.waitForExistence(timeout: 2), "folding keeps the Undo")
        undo.tap()
        XCTAssertNotNil(text(app, "Groceries", timeout: 2), "Lemons is back, the list still folded")
        shot(app, "undo-fold-count")
        app.buttons["Fold Groceries"].tap()
        XCTAssertNotNil(text(app, "Lemons", timeout: 2))
    }

    /// Checking a task after a delete still ends the Undo, as before.
    @MainActor
    func testCheckingAfterDeleteStillEndsUndo() throws {
        let app = launch(["-demoData", "-demoFirstCard", "Errands"])
        openCard(app, "Errands")
        app.buttons["Edit Errands"].tap()
        app.buttons["Delete Pick up dry cleaning"].tap()
        let undo = app.buttons["Undo delete"]
        XCTAssertTrue(undo.waitForExistence(timeout: 2))
        app.buttons["Done editing Errands"].tap()
        app.buttons["Complete Plan Mom's birthday"].tap()
        XCTAssertTrue(undo.waitForNonExistence(timeout: 2), "checking a task ends the Undo")
    }

    /// A goal step after a delete ends the Undo; a rename after a delete (keyboard up and
    /// down) keeps it, and Undo keeps the rename.
    @MainActor
    func testGoalStepEndsUndoRenameKeepsIt() throws {
        let app = launch(["-demoData", "-demoFirstCard", "Errands"])
        openCard(app, "Errands")
        app.buttons["Edit Errands"].tap()
        app.buttons["Delete Pick up dry cleaning"].tap()
        let undo = app.buttons["Undo delete"]
        XCTAssertTrue(undo.waitForExistence(timeout: 2))
        // Renaming in edit mode, with the keyboard up (the message hides) and then down.
        rename(app, "Groceries", appending: " run")
        XCTAssertTrue(undo.waitForExistence(timeout: 2), "the Undo is back once the keyboard goes")
        undo.tap()
        XCTAssertNotNil(text(app, "Pick up dry cleaning", timeout: 2), "the task is back")
        XCTAssertNotNil(text(app, "Groceries run", timeout: 2), "and the rename stays")

        app.buttons["Delete Pick up dry cleaning"].tap()
        XCTAssertTrue(undo.waitForExistence(timeout: 2))
        app.buttons["Done editing Errands"].tap()
        let plus = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Add 1")).firstMatch
        XCTAssertTrue(plus.waitForExistence(timeout: 2))
        plus.tap()
        XCTAssertTrue(undo.waitForNonExistence(timeout: 2), "a goal step ends the Undo")
    }

    // MARK: - Rename fields

    /// A short rename doesn't move the card; a long one near the bottom stays clear of the
    /// keyboard as it grows.
    @MainActor
    func testRenameFieldScrollingAroundTheKeyboard() throws {
        let app = launch(["-demoData", "-demoFirstCard", "Errands"])
        openCard(app, "Errands")
        let anchor = app.buttons["Complete Groceries"]
        XCTAssertTrue(anchor.waitForExistence(timeout: 3))
        guard let name = text(app, "Plan Mom's birthday") else { return XCTFail() }
        name.tap()
        let field = app.textFields["Task name"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        Thread.sleep(forTimeInterval: 0.8)
        let before = anchor.frame.minY
        for letters in [" a", "nd", " c"] {
            field.typeText(letters)
            Thread.sleep(forTimeInterval: 0.4)
        }
        print("REVIEW: anchor before \(before) after \(anchor.frame.minY)")
        XCTAssertEqual(anchor.frame.minY, before, accuracy: 1, "a short rename doesn't move the card")
        field.typeText("\n")
        XCTAssertTrue(field.waitForNonExistence(timeout: 3))

        // The last task, just above the Add task row, renamed to three lines.
        guard let last = text(app, "Pick up dry cleaning") else { return XCTFail() }
        last.tap()
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        Thread.sleep(forTimeInterval: 0.8)
        for words in [" and the", " shirts from", " the tailor on", " Main Street", " before Friday", " noon"] {
            field.typeText(words)
            Thread.sleep(forTimeInterval: 0.4)
        }
        Thread.sleep(forTimeInterval: 0.6)
        let keyboard = app.keyboards.firstMatch
        print("REVIEW: long rename field \(field.frame) keyboard \(keyboard.frame)")
        shot(app, "rename-long-bottom")
        XCTAssertLessThanOrEqual(field.frame.maxY, keyboard.frame.minY, "the grown field is clear of the keyboard")
        app.buttons["Done"].firstMatch.tap()
        XCTAssertTrue(field.waitForNonExistence(timeout: 3), "Done saves")
        XCTAssertNotNil(text(app, "Pick up dry cleaning and the shirts from the tailor on Main Street before Friday noon"))
    }

    /// Typing a short rename one letter at a time, with the keyboard settled: the card
    /// stays still unless the field grows a line, and even then a field already in full
    /// view doesn't need to move.
    @MainActor
    func testShortRenameDoesNotJumpCard() throws {
        let app = launch(["-demoData", "-demoFirstCard", "Errands"])
        openCard(app, "Errands")
        let anchor = app.buttons["Complete Groceries"]
        XCTAssertTrue(anchor.waitForExistence(timeout: 3))
        guard let name = text(app, "Plan Mom's birthday") else { return XCTFail() }
        name.tap()
        let field = app.textFields["Task name"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        Thread.sleep(forTimeInterval: 2.0)  // the keyboard settles
        let before = anchor.frame.minY
        let keyboardTop = app.keyboards.firstMatch.frame.minY
        var moves: [String] = []
        for letter in [" ", "a", "n", "d", " ", "c", "a", "k", "e"] {
            let height = field.frame.height
            let y = anchor.frame.minY
            field.typeText(letter)
            Thread.sleep(forTimeInterval: 0.6)
            moves.append("'\(letter)': anchor \(y)->\(anchor.frame.minY) field h \(height)->\(field.frame.height) maxY \(field.frame.maxY)")
        }
        print("REVIEW: jump keyboardTop \(keyboardTop) before \(before)\n" + moves.joined(separator: "\n"))
        shot(app, "rename-short-typed")
        XCTAssertLessThan(field.frame.maxY, keyboardTop, "the field was in full view all along")
        XCTAssertEqual(anchor.frame.minY, before, accuracy: 1, "a short rename in full view doesn't move the card")
    }

    /// A rename closed by a week swipe or by the card's edit button is saved in its own
    /// week, with nothing left behind.
    @MainActor
    func testRenameSavedByWeekSwipeAndEditButton() throws {
        let app = launch(["-demoData", "-demoFirstCard", "Errands"])
        openCard(app, "Errands")
        let thisWeek = weekTitle(app)
        guard let name = text(app, "Plan Mom's birthday") else { return XCTFail() }
        name.tap()
        let field = app.textFields["Task name"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        Thread.sleep(forTimeInterval: 0.5)
        field.typeText(" party")
        Thread.sleep(forTimeInterval: 0.4)
        app.buttons["Edit Errands"].tap()
        // Renaming goes on in the card's edit mode (spec: edit mode is for trash cans and
        // renaming), so the field may stay: Return then saves it.
        if field.waitForExistence(timeout: 1) { field.typeText("\n") }
        XCTAssertTrue(field.waitForNonExistence(timeout: 3), "the rename ends")
        XCTAssertNotNil(text(app, "Plan Mom's birthday party"))
        app.buttons["Done editing Errands"].tap()

        guard let again = text(app, "Plan Mom's birthday party") else { return XCTFail() }
        again.tap()
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        Thread.sleep(forTimeInterval: 0.5)
        field.typeText("!")
        Thread.sleep(forTimeInterval: 0.4)
        app.staticTexts["Drop off donations"].firstMatch.swipeLeft()
        Thread.sleep(forTimeInterval: 1.0)
        XCTAssertNotEqual(weekTitle(app), thisWeek, "the swipe went to next week")
        XCTAssertFalse(app.keyboards.firstMatch.exists, "the keyboard went")
        shot(app, "rename-week-swipe-next")
        XCTAssertNotNil(text(app, "Plan Mom's birthday party!"), "next week's copy has the saved name")
        app.buttons["This Week"].tap()
        XCTAssertNotNil(text(app, "Plan Mom's birthday party!"), "saved in its own week")
        XCTAssertFalse(app.textFields["Task name"].exists, "no rename field left open")
    }

    // MARK: - Journey

    /// A card with a long list, a goal and a checkbox with sub-tasks; fold, reorder, rename,
    /// This week only on and off, next week and back, relaunch: every part survives.
    @MainActor
    func testJourneyFoldReorderRenameRelaunch() throws {
        let id = "rr-journey-\(UUID().uuidString)"
        let app = launch(["-demoData", "-isolatedDataID", id, "-demoFirstCard", "Errands"])
        openCard(app, "Errands")
        // A longer list.
        let addItem = app.buttons.matching(NSPredicate(format: "label == %@", "Add item to Groceries")).firstMatch
        XCTAssertTrue(addItem.waitForExistence(timeout: 3))
        addItem.tap()
        let itemField = app.textFields["Add item"]
        XCTAssertTrue(itemField.waitForExistence(timeout: 3))
        for item in ["Bread", "Rice", "Tea", "Apples", "Pasta", "Butter"] {
            itemField.typeText(item + "\n")
            Thread.sleep(forTimeInterval: 0.4)
        }
        app.buttons["Done"].firstMatch.tap()
        XCTAssertNotNil(text(app, "Butter"))
        // Fold, reorder Groceries below Plan Mom's birthday, rename an item.
        app.buttons["Fold Groceries"].tap()
        XCTAssertNotNil(text(app, "Groceries"))
        app.buttons["Edit Errands"].tap()
        let delete = app.buttons["Delete Groceries"]
        XCTAssertTrue(delete.waitForExistence(timeout: 3))
        let target = app.buttons["Complete Plan Mom's birthday"]
        let handle = delete.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5)).withOffset(CGVector(dx: 12, dy: 0))
        handle.press(forDuration: 1.0, thenDragTo: target.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .withOffset(CGVector(dx: 0, dy: 10)))
        let groceries = app.buttons["Complete Groceries"]
        let moved = NSPredicate { _, _ in groceries.frame.minY > target.frame.minY }
        wait(for: [XCTNSPredicateExpectation(predicate: moved, object: nil)], timeout: 5)
        setThisWeekOnly(app, card: "Errands", on: false)  // ends edit mode (it was off)
        shot(app, "journey-reordered-folded")

        // Next week and back.
        app.buttons["Next week"].tap()
        XCTAssertNotNil(text(app, "Groceries") ?? text(app, "Groceries"),
                        "next week's copy is folded too")
        shot(app, "journey-next-week")
        app.buttons["This Week"].tap()
        XCTAssertNotNil(text(app, "Groceries"))

        app.terminate()
        app.launchArguments = ["-isolatedDataID", id]
        app.launch()
        if app.staticTexts["Welcome to Tasquel"].waitForExistence(timeout: 2) { app.buttons["Skip"].tap() }
        openCard(app, "Errands")
        XCTAssertNotNil(text(app, "Groceries"), "still folded after a relaunch")
        let g = app.buttons["Complete Groceries"], p = app.buttons["Complete Plan Mom's birthday"]
        XCTAssertGreaterThan(g.frame.minY, p.frame.minY, "the order survived")
        shot(app, "journey-relaunch")
    }
}
