import XCTest

/// Update review, step 1 (run in the LIVE 1.0.2 copy): uses the app like a long-time user,
/// in the simulator's real storage (no -isolatedData / -demoData), so the data is saved where
/// a real user's is. update_check.sh runs it on a freshly uninstalled app, then installs the
/// new build over it and runs ReviewUpdateCheck in the new copy.
///
/// What it leaves (this week unless said):
/// - Errands: Groceries (list, carry-over: Eggs checked, Milk, Bread), Laundry (checkbox,
///   repeating; sub-tasks Wash checked, Fold), Pay rent (one-time, completed), Buy stamps
///   (carry-over, renamed from "Buy"), a deleted task "Old note" (its Undo gone).
/// - Fitness: Run (goal, repeating, quantity 10, 2 steps = 4/10), Stretch (goal, carry-over,
///   time 1h, 1 step), Gym bag (list, repeating: Shoes checked, Towel).
/// - Work: Report (carry-over), Standup (repeating), Inbox (list, repeating: Reply), then
///   This week only switched ON (1.0.2 makes all three one-time for good).
/// - Trip: a category added for this week only, with Pack (one-time).
/// - Next week: Errands gets "Next week task" (one-time), which saves next week.
/// - Settings: Dark appearance.
final class ReviewUpdateSeed: XCTestCase {
    private var app: XCUIApplication!

    @MainActor
    override func setUp() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchArguments = []  // real storage, like a user
        app.launch()
        if app.staticTexts["Welcome to Tasquel"].waitForExistence(timeout: 4) {
            for _ in 0..<4 { app.buttons["Next"].tap() }
            app.buttons["Let's Go!"].tap()
        }
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 8))
    }

    @MainActor
    func testSeedLiveData() throws {
        // MARK: Errands
        open("Errands")
        addTask("Groceries", type: "List", mode: "Carry Over")
        let item = app.textFields["Add item"]
        XCTAssertTrue(item.waitForExistence(timeout: 3))
        for name in ["Eggs", "Milk", "Bread"] { item.typeText(name + "\n"); usleep(500_000) }
        closeKeyboard()
        XCTAssertTrue(app.staticTexts["Bread"].waitForExistence(timeout: 3))
        app.buttons["Complete Eggs"].tap()

        addTask("Laundry", type: nil, mode: "Repeating")
        closeKeyboard()
        app.buttons["Add sub-task to Laundry"].tap()
        let sub = app.textFields["Add sub-task"]
        XCTAssertTrue(sub.waitForExistence(timeout: 3))
        for name in ["Wash", "Fold"] { sub.typeText(name + "\n"); usleep(500_000) }
        closeKeyboard()
        XCTAssertTrue(app.staticTexts["Fold"].waitForExistence(timeout: 3))
        app.buttons["Complete Wash"].tap()

        addPlain("Pay rent")
        addTask("Buy", type: nil, mode: "Carry Over")
        addPlain("Old note")
        closeKeyboard()
        app.buttons["Complete Pay rent"].tap()

        // Rename Buy → Buy stamps (an edited item).
        app.staticTexts["Buy"].firstMatch.tap()
        let name = app.textFields["Task name"]
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        name.typeText(" stamps\n")
        XCTAssertTrue(app.staticTexts["Buy stamps"].waitForExistence(timeout: 3))
        closeKeyboard()

        // Delete "Old note", then let its Undo run out.
        app.buttons["Edit Errands"].tap()
        app.buttons["Delete Old note"].tap()
        XCTAssertTrue(app.buttons["Undo delete"].firstMatch.waitForExistence(timeout: 3))
        sleep(7)
        XCTAssertFalse(app.buttons["Undo delete"].firstMatch.exists, "the Undo ran out")
        app.buttons["Done editing Errands"].tap()
        shot("seed-errands")
        app.buttons["Close Errands"].tap()

        // MARK: Fitness
        open("Fitness")
        addTask("Run", type: "Goal", mode: "Repeating")
        dismissPopoverIfAny()
        let target = app.textFields["Target"]
        if target.waitForExistence(timeout: 3) {
            target.tap()
            target.typeText("10")
            app.buttons["Set"].tap()
        }
        closeKeyboard()
        let add2 = app.buttons["Add 2"]
        XCTAssertTrue(add2.waitForExistence(timeout: 3))
        add2.tap(); usleep(400_000); add2.tap()
        XCTAssertTrue(app.staticTexts["4/10"].waitForExistence(timeout: 3))

        addTask("Stretch", type: "Goal", mode: "Carry Over")
        dismissPopoverIfAny()
        let unit = app.buttons["Goal unit: Quantity"]
        XCTAssertTrue(unit.waitForExistence(timeout: 3))
        unit.tap()
        app.buttons["Time"].firstMatch.tap()
        let hours = app.textFields["Target hours"]
        XCTAssertTrue(hours.waitForExistence(timeout: 3))
        hours.tap()
        hours.typeText("1")
        closeKeyboard()
        if app.buttons["Set"].exists { app.buttons["Set"].tap() }
        let add9 = app.buttons["Add 9 minutes"]
        XCTAssertTrue(add9.waitForExistence(timeout: 3))
        add9.tap()
        XCTAssertTrue(app.staticTexts["9m / 1h"].waitForExistence(timeout: 3))

        addTask("Gym bag", type: "List", mode: "Repeating")
        let item2 = app.textFields["Add item"]
        XCTAssertTrue(item2.waitForExistence(timeout: 3))
        for name in ["Shoes", "Towel"] { item2.typeText(name + "\n"); usleep(500_000) }
        closeKeyboard()
        XCTAssertTrue(app.staticTexts["Towel"].waitForExistence(timeout: 3))
        app.buttons["Complete Shoes"].tap()
        shot("seed-fitness")
        app.buttons["Close Fitness"].tap()

        // MARK: Work, then This week only on (1.0.2 makes its tasks one-time for good)
        open("Work")
        addTask("Report", type: nil, mode: "Carry Over")
        addTask("Standup", type: nil, mode: "Repeating")
        addTask("Inbox", type: "List", mode: "Repeating")
        let item3 = app.textFields["Add item"]
        XCTAssertTrue(item3.waitForExistence(timeout: 3))
        item3.typeText("Reply\n"); usleep(500_000)
        closeKeyboard()
        app.buttons["Edit Work"].tap()
        let toggle = app.switches["This week only"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 3))
        toggle.switches.firstMatch.tap()
        XCTAssertEqual(toggle.value as? String, "1")
        app.buttons["Done editing Work"].tap()
        XCTAssertTrue(app.buttons["Task options: Checkbox, One-Time"].waitForExistence(timeout: 3))
        shot("seed-work")
        app.buttons["Close Work"].tap()

        // MARK: Trip, a category for this week only
        app.buttons["Edit"].tap()
        let addCard = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Add Category")).firstMatch
        XCTAssertTrue(addCard.waitForExistence(timeout: 3))
        addCard.tap()
        let twoToggle = app.switches["This week only"]
        XCTAssertTrue(twoToggle.waitForExistence(timeout: 3))
        twoToggle.switches.firstMatch.tap()
        app.buttons["Create New Category"].tap()
        let catName = app.textFields["Category name"]
        XCTAssertTrue(catName.waitForExistence(timeout: 3))
        catName.typeText("Trip\n")
        XCTAssertTrue(app.navigationBars["Add Category"].waitForNonExistence(timeout: 3))
        if app.buttons["Done"].exists && !app.buttons["Settings"].exists { app.buttons["Done"].firstMatch.tap() }
        open("Trip")
        addPlain("Pack")
        closeKeyboard()
        app.buttons["Close Trip"].tap()

        // MARK: Next week: an edit saves it
        app.buttons["Next week"].tap()
        sleep(1)
        open("Errands")
        addPlain("Next week task")
        closeKeyboard()
        shot("seed-nextweek-errands")
        app.buttons["Close Errands"].tap()
        app.buttons["Previous week"].tap()
        sleep(1)

        // MARK: Study: a carry-over copy that 1.0.2 lets arrive in a This week only card
        // (this week's Study has Essay; next week's Study is made this week only; then a new
        // carry-over Flashcards added this week syncs into it, still carry-over in 1.0.2).
        open("Study")
        addTask("Essay", type: nil, mode: "Carry Over")
        closeKeyboard()
        app.buttons["Close Study"].tap()
        app.buttons["Next week"].tap()
        sleep(1)
        open("Study")
        app.buttons["Edit Study"].tap()
        let studyToggle = app.switches["This week only"]
        XCTAssertTrue(studyToggle.waitForExistence(timeout: 3))
        studyToggle.switches.firstMatch.tap()
        app.buttons["Done editing Study"].tap()
        app.buttons["Close Study"].tap()
        app.buttons["Previous week"].tap()
        sleep(1)
        open("Study")
        addTask("Flashcards", type: "List", mode: "Carry Over")
        let deck = app.textFields["Add item"]
        XCTAssertTrue(deck.waitForExistence(timeout: 3))
        deck.typeText("Deck 1\n"); usleep(500_000)
        closeKeyboard()
        app.buttons["Close Study"].tap()
        app.buttons["Next week"].tap()  // syncs Flashcards into next week's Study
        sleep(1)
        open("Study")
        XCTAssertTrue(app.buttons["Task options: List, Carry Over"].waitForExistence(timeout: 3),
                      "1.0.2: the copy arrived carry-over in a This week only card")
        shot("seed-nextweek-study")
        app.buttons["Close Study"].tap()
        app.buttons["Previous week"].tap()
        sleep(1)

        // MARK: Settings: Dark
        app.buttons["Settings"].tap()
        let dark = app.buttons["Dark"]
        XCTAssertTrue(dark.waitForExistence(timeout: 3))
        dark.tap()
        sleep(1)
        app.buttons["Done"].firstMatch.tap()
        sleep(1)
        shot("seed-home")
        app.terminate()
    }

    // MARK: Helpers

    @MainActor
    private func open(_ card: String) {
        let button = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open \(card),")).firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 5), "card \(card)")
        button.tap()
        XCTAssertTrue(app.buttons["Close \(card)"].waitForExistence(timeout: 3))
    }

    /// Types a task and adds it with its options (nil keeps Checkbox / One-Time).
    @MainActor
    private func addTask(_ title: String, type: String?, mode: String?) {
        let field = app.addTaskField
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText(title)
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "New task options")).firstMatch.tap()
        if let type { app.buttons[type].firstMatch.tap() }
        if let mode { app.buttons[mode].firstMatch.tap() }
        app.buttons["Add Task"].tap()
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 3), "added \(title)")
        usleep(500_000)
    }

    @MainActor
    private func addPlain(_ title: String) {
        let field = app.addTaskField
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText(title + "\n")
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 3), "added \(title)")
        usleep(500_000)
    }

    @MainActor
    private func closeKeyboard() {
        if app.keyboards.firstMatch.exists, app.buttons["Done"].exists {
            app.buttons["Done"].firstMatch.tap()
            _ = app.keyboards.firstMatch.waitForNonExistence(timeout: 2)
        }
        usleep(400_000)
    }

    @MainActor
    private func dismissPopoverIfAny() {
        let region = app.otherElements["PopoverDismissRegion"]
        if region.exists { region.tap() }
        usleep(400_000)
    }

    @MainActor
    private func shot(_ name: String) {
        sleep(1)
        let dir = ProcessInfo.processInfo.environment["SHOT_DIR"] ?? NSTemporaryDirectory()
        try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
    }
}
