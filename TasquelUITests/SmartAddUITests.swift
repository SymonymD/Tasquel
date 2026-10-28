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
    @MainActor
    func testChangingWeekWhileWorking() throws {
        typeInFitness("run 3x per week")
        app.buttons["Smart Add"].tap()
        app.buttons["Next week"].tap()
        sleep(4)  // longer than Smart Add takes
        XCTAssertEqual(taskCount, 0, "nothing added to next week")
        app.buttons["Previous week"].tap()
        let field = app.textFields["Add task"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
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

    // MARK: Helpers

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
        let field = app.textFields["Add task"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText(text)
        XCTAssertTrue(app.buttons["Smart Add"].waitForExistence(timeout: 2))
        sleep(1)  // the row and keyboard have settled (an iPad may still be rotating back)
    }
}
