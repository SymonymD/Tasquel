import XCTest

/// Smart Add while other things happen. The parser takes a moment (on a phone, the model;
/// here, `-smartAddRules` with the same pause), and meanwhile the user may close the card,
/// change week, close the keyboard, tap again or open another card.
final class SmartAddUITests: XCTestCase {
    private var app: XCUIApplication!

    @MainActor
    override func setUp() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchArguments = ["-isolatedData", "-smartAddRules"]
        app.launch()
        if app.staticTexts["Welcome to Tasquel"].waitForExistence(timeout: 3) { app.buttons["Skip"].tap() }
    }

    /// Closing the card while Smart Add works still adds the task to it.
    @MainActor
    func testClosingCardWhileWorking() throws {
        typeInFitness("run 3x per week")
        app.buttons["Smart Add"].tap()
        app.buttons["Close Fitness"].tap()
        let added = NSPredicate(format: "label BEGINSWITH %@", "Open Fitness, 0 of 1")
        XCTAssertTrue(app.buttons.matching(added).firstMatch.waitForExistence(timeout: 10), "the task was added")
        fitnessCard.tap()
        XCTAssertTrue(app.buttons["Task options: Goal, Repeating"].waitForExistence(timeout: 3))
    }

    /// Changing week while Smart Add works adds nothing to either week, and the words stay.
    /// Swiped, as while typing: the week selector is in the bottom bar, which makes way for
    /// the keyboard.
    @MainActor
    func testChangingWeekWhileWorking() throws {
        // Smart Add takes 6 seconds here, so the swipe surely lands while it works.
        app.terminate()
        app.launchArguments += ["-smartAddDelay", "6"]
        app.launch()
        if app.staticTexts["Welcome to Tasquel"].waitForExistence(timeout: 3) { app.buttons["Skip"].tap() }
        typeInFitness("run 3x per week")
        app.buttons["Smart Add"].tap()
        swipeWeek(forward: true)
        let nextWeek = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Week of")).firstMatch.label
        sleep(7)  // longer than Smart Add takes
        XCTAssertEqual(taskCount, 0, "nothing added to next week (\(nextWeek))")
        swipeWeek(forward: false)
        let field = app.textFields["Add task"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        XCTAssertNotEqual(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Week of")).firstMatch.label, nextWeek)
        XCTAssertEqual(taskCount, 0, "nothing added to this week")
        XCTAssertEqual(field.value as? String, "run 3x per week", "the words are still there to try again")
    }

    /// The keyboard's Done button while Smart Add works: the task is added once, as Smart
    /// Add worked it out, not also as the plain typed text.
    @MainActor
    func testKeyboardDoneWhileWorking() throws {
        typeInFitness("run 3x per week")
        app.buttons["Smart Add"].tap()
        app.buttons["Done"].firstMatch.tap()
        assertOneRunGoal()
        XCTAssertFalse(app.staticTexts["run 3x per week"].exists)
    }

    /// Two quick taps on Smart Add add one task.
    @MainActor
    func testDoubleTapAddsOnce() throws {
        typeInFitness("run 3x per week")
        app.buttons["Smart Add"].doubleTap()
        assertOneRunGoal()
    }

    /// Opening another card while Smart Add works: the task lands in the card it was typed
    /// in and both cards stay open.
    @MainActor
    func testOpeningAnotherCardWhileWorking() throws {
        typeInFitness("run 3x per week")
        app.buttons["Smart Add"].tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Study,")).firstMatch.tap()
        assertOneRunGoal()
        XCTAssertTrue(app.buttons["Close Fitness"].exists)
        XCTAssertTrue(app.buttons["Close Study"].exists)
    }

    /// A list with no items yet takes the keyboard for its first item; the words aren't
    /// added a second time as the Add task field lets go of the keyboard. (List is picked
    /// first: Smart Add keeps a picked type, and without a model the rules wouldn't make
    /// a list from one word.)
    @MainActor
    func testEmptyListTakesKeyboardForFirstItem() throws {
        typeInFitness("Groceries")
        app.buttons["New task options: Checkbox, One-Time"].tap()
        app.buttons["List"].tap()
        let dismiss = app.otherElements["PopoverDismissRegion"]
        if dismiss.exists { dismiss.tap() }  // the picker stays open: tap outside it
        let smartAdd = app.buttons["Smart Add"]
        XCTAssertTrue(smartAdd.waitForExistence(timeout: 3))
        smartAdd.tap()
        let item = app.textFields["Add item"]
        XCTAssertTrue(item.waitForExistence(timeout: 10), "the new list's item field appears")
        sleep(1)
        XCTAssertEqual(taskCount, 1, "added once")
        XCTAssertTrue(item.value(forKey: "hasKeyboardFocus") as? Bool ?? false, "the keyboard moved to the first item")
        item.typeText("Milk\n")
        XCTAssertTrue(app.staticTexts["Milk"].waitForExistence(timeout: 3))
        XCTAssertEqual(taskCount, 1, "still one task")
    }

    /// Closing the card while Smart Add works on a list with no items: the list is added,
    /// and the keyboard doesn't come up for its (now hidden) first-item field.
    @MainActor
    func testClosingCardWhileWorkingOnEmptyList() throws {
        typeInFitness("Groceries")
        app.buttons["New task options: Checkbox, One-Time"].tap()
        app.buttons["List"].tap()
        let dismiss = app.otherElements["PopoverDismissRegion"]
        if dismiss.exists { dismiss.tap() }
        let smartAdd = app.buttons["Smart Add"]
        XCTAssertTrue(smartAdd.waitForExistence(timeout: 3))
        smartAdd.tap()
        app.buttons["Close Fitness"].tap()
        let added = NSPredicate(format: "label BEGINSWITH %@", "Open Fitness, 0 of 1")
        XCTAssertTrue(app.buttons.matching(added).firstMatch.waitForExistence(timeout: 10), "the list was added")
        sleep(1)
        XCTAssertEqual(app.keyboards.count, 0, "no keyboard for a field in a closed card")
    }

    /// "Added … · Undo" sits under the task it describes, above the Add task field. When its
    /// time is up while the field has the keyboard, it fades but keeps its place, so the
    /// field doesn't move up; its place goes with the keyboard. (Measured from the task
    /// above: the grid itself scrolls back as the keyboard goes.)
    @MainActor
    func testMessageSitsUnderTheAddedTask() throws {
        typeInFitness("run 3x per week")
        app.buttons["Smart Add"].tap()
        let undo = app.buttons["Undo Smart Add"]
        XCTAssertTrue(undo.waitForExistence(timeout: 10))
        let goal = app.buttons["Task options: Goal, Repeating"]
        let field = app.textFields["Add task"]
        XCTAssertLessThan(goal.frame.midY, undo.frame.midY, "under the new task")
        XCTAssertLessThan(undo.frame.midY, field.frame.midY, "above the Add task field")
        let fieldY = field.frame.minY
        let gap = field.frame.minY - goal.frame.maxY
        XCTAssertTrue(field.value(forKey: "hasKeyboardFocus") as? Bool ?? false, "still typing")

        let faded = expectation(for: NSPredicate(format: "isEnabled == false"), evaluatedWith: undo)
        wait(for: [faded], timeout: 8)
        XCTAssertEqual(field.frame.minY, fieldY, accuracy: 0.5, "the field didn't move")

        app.buttons["Done"].firstMatch.tap()
        XCTAssertTrue(undo.waitForNonExistence(timeout: 3), "its place went with the keyboard")
        // The empty field is back to its + now.
        XCTAssertLessThan(app.addTaskRow.frame.minY - goal.frame.maxY, gap)
    }

    /// The next task takes the message away: it would sit under that task instead.
    @MainActor
    func testNextTaskTakesTheMessageAway() throws {
        typeInFitness("run 3x per week")
        app.buttons["Smart Add"].tap()
        let undo = app.buttons["Undo Smart Add"]
        XCTAssertTrue(undo.waitForExistence(timeout: 10))
        app.textFields["Add task"].typeText("Stretch\n")
        XCTAssertTrue(app.staticTexts["Stretch"].waitForExistence(timeout: 3))
        XCTAssertFalse(undo.exists)
        XCTAssertEqual(taskCount, 2)
    }

    /// Words with no real word in them skip the model and are added as typed, saying so.
    @MainActor
    func testNoRealWordsAddedAsTyped() throws {
        typeInFitness("asldkjlkd")
        app.buttons["Smart Add"].tap()
        let note = app.staticTexts["Added asldkjlkd · one-time · set up from your words"]
        XCTAssertTrue(note.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Task options: Checkbox, One-Time"].exists)
        XCTAssertEqual(taskCount, 1)
    }

    /// With the field down at the keyboard, a tall task (a goal, with its message) added
    /// above it while typing scrolls the whole field into view, not just its caret.
    @MainActor
    func testFieldStaysInViewAfterTallAdd() throws {
        XCTAssertTrue(fitnessCard.waitForExistence(timeout: 5))
        fitnessCard.tap()
        let field = app.addTaskField
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 3))
        // Plain tasks until the field is down at the keyboard.
        for name in ["Stretch", "Walk", "Plank", "Squats", "Lunges", "Rows", "Curls", "Dips", "Hike"]
        where field.frame.maxY < keyboard.frame.minY - 140 {
            field.typeText("\(name)\n")
            XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 3))
        }
        field.typeText("run 3x per week")
        app.buttons["Smart Add"].tap()
        XCTAssertTrue(app.buttons["Undo Smart Add"].waitForExistence(timeout: 10))
        sleep(1)  // the scroll has settled
        XCTAssertTrue(field.value(forKey: "hasKeyboardFocus") as? Bool ?? false, "still typing")
        XCTAssertLessThanOrEqual(field.frame.maxY, keyboard.frame.minY, "the whole field is above the keyboard")
        let done = app.buttons["Done"].firstMatch
        if done.exists { XCTAssertLessThanOrEqual(field.frame.maxY, done.frame.minY + 1, "and clear of Done") }
    }

    // MARK: Helpers

    /// Drags the grid sideways to the next or previous week.
    @MainActor
    private func swipeWeek(forward: Bool) {
        let from = app.coordinate(withNormalizedOffset: CGVector(dx: forward ? 0.85 : 0.15, dy: 0.3))
        from.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: forward ? 0.1 : 0.9, dy: 0.3)))
        sleep(1)  // the slide has settled
    }

    /// Tasks in the open cards, counted by their type and mode buttons (one per task; a
    /// title shows as two texts).
    private var taskCount: Int {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Task options:")).count
    }

    private var fitnessCard: XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Fitness,")).firstMatch
    }

    /// Waits for Smart Add to finish, then checks exactly one "Run" goal was added and no
    /// second one follows.
    @MainActor
    private func assertOneRunGoal(file: StaticString = #filePath, line: UInt = #line) {
        let goal = app.buttons["Task options: Goal, Repeating"]
        XCTAssertTrue(goal.waitForExistence(timeout: 20), "Smart Add added the goal", file: file, line: line)
        sleep(1)
        XCTAssertEqual(taskCount, 1, "added once", file: file, line: line)
    }

    @MainActor
    private func typeInFitness(_ text: String) {
        XCTAssertTrue(fitnessCard.waitForExistence(timeout: 5))
        fitnessCard.tap()
        let field = app.addTaskField
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText(text)
        XCTAssertTrue(app.buttons["Smart Add"].waitForExistence(timeout: 2))
        sleep(1)  // the row and keyboard have settled (an iPad may still be rotating back)
    }
}
