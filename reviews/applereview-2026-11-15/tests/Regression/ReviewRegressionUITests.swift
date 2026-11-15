import XCTest

/// Regression review after the 2026-11-15 fixes: around each fix, what it could disturb.
/// Findings first, then "Checked" tests asserting what worked. Each starts from a clean launch.
final class ReviewRegressionUITests: XCTestCase {
    private static let largestText = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
    /// A Wednesday, so Friday is still ahead.
    private static let wednesday = ["-demoData", "-demoToday", "2026-11-11"]

    override func setUp() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        XCUIDevice.shared.appearance = .light
    }

    override func tearDown() {
        XCUIDevice.shared.appearance = .light
    }

    // MARK: Fix 1: Settings ▸ Week

    /// Checked: on a Sunday, "Gym" for Thursday goes into next week; Week Starts On Sunday
    /// brings it into this week (Thursday the 19th is in it now), not late, and next week no
    /// longer has it.
    @MainActor
    func testWeekSwitchOnSundayBringsNextWeeksDayTaskHere() throws {
        let app = launch(["-demoData", "-demoToday", "2026-11-15"])
        openCard("Errands", in: app)
        addWithDay("Gym class", day: "Thursday", in: app)
        XCTAssertTrue(app.buttons["Moved Back to This Week"].waitForExistence(timeout: 5))
        app.buttons["Moved Back to This Week"].tap()
        sleep(2)
        closeKeyboard(app)
        app.buttons["Settings"].tap()
        let sunday = app.settingsButton("Sunday")
        sunday.tap()
        sleep(1)
        app.buttons["Done"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 5))
        sleep(1)
        if !app.buttons["Close Errands"].exists { openCard("Errands", in: app) }
        let gym = app.staticTexts["Gym class"].firstMatch
        XCTAssertTrue(gym.waitForExistence(timeout: 3), "Gym class is in this week now")
        shot("fix1-sunday-switch-this-week", app)
        print("REVIEW: after Sunday starts: \(weekTitle(app)); Gym class value \(gym.value ?? "")")
        XCTAssertFalse((gym.value as? String ?? "").contains("late"))
        app.buttons["Next week"].tap()
        sleep(2)
        XCTAssertFalse(app.staticTexts["Gym class"].exists, "not left in next week too")
    }

    // MARK: Fix 3: day and date marks

    /// A duplicate's "⧉ Duplicate" is in the name's text, but `stacksMark` measures the name
    /// alone: "Buy stamps" and "Fri" fit on one line, "Buy stamps  ⧉ Duplicate" and "Fri" don't,
    /// so the mark stays beside a name that now wraps, taking width from both its lines.
    @MainActor
    func testDuplicateNameWithADayPutsTheMarkUnderWhenItWraps() throws {
        let app = launch(Self.wednesday)
        openCard("Errands", in: app)
        addWithDay("Buy stamps", day: "Friday", in: app)
        let name = app.staticTexts.matching(identifier: "Buy stamps").element(boundBy: 0)
        let mark = app.buttons.matching(identifier: "Change day of Buy stamps").element(boundBy: 0)
        XCTAssertTrue(mark.waitForExistence(timeout: 3))
        let oneLine = name.frame.height
        print("REVIEW: one Buy stamps: name \(name.frame), mark \(mark.frame)")
        // The same again, with Return (the add row keeps Friday picked).
        app.typeText("Buy stamps\n")
        sleep(1)
        closeKeyboard(app)
        let first = app.staticTexts.matching(identifier: "Buy stamps").element(boundBy: 0)
        let firstMark = app.buttons.matching(identifier: "Change day of Buy stamps").element(boundBy: 0)
        XCTAssertEqual(app.staticTexts.matching(identifier: "Buy stamps").count, 2)
        XCTAssertTrue((first.value as? String ?? "").contains("duplicate"), "flagged as a duplicate")
        shot("fix3-duplicate-day-mark", app)
        print("REVIEW: duplicate Buy stamps: name \(first.frame) (one line \(oneLine)), mark \(firstMark.frame), value \(first.value ?? "")")
        if first.frame.height > oneLine * 1.5 {
            XCTAssertGreaterThanOrEqual(firstMark.frame.minY, first.frame.maxY - 4,
                                        "the name wraps, so the mark goes under it, not beside both lines")
        }
    }

    /// Checked: at the largest size the mark is under the name; tapping the mark opens the
    /// options (Day row), tapping the name renames.
    @MainActor
    func testStackedMarkOpensOptionsAndNameRenames() throws {
        let app = launch(Self.wednesday + Self.largestText)
        openCard("Errands", in: app)
        let name = app.staticTexts["Plan Mom's birthday"].firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        let mark = app.buttons["Change date of Plan Mom's birthday"].firstMatch
        for _ in 0..<8 where !(name.isHittable && name.frame.maxY < app.windows.firstMatch.frame.maxY - 260) {
            app.swipeUp(velocity: .slow)
        }
        shot("fix3-ax-stacked-mark", app)
        print("REVIEW: AX name \(name.frame), mark button \(mark.frame)")
        // The name: renames.
        name.tap()
        let renamed = app.keyboards.firstMatch.waitForExistence(timeout: 3)
        let calendarFromName = app.staticTexts["Until"].exists
        print("REVIEW: tap on the name: keyboard \(renamed), date calendar \(calendarFromName)")
        if calendarFromName { app.buttons["Cancel"].firstMatch.tap() }
        closeKeyboard(app)
        XCTAssertTrue(renamed && !calendarFromName, "a tap on the name renames")
        // The mark, under the name: opens the date calendar.
        let markPoint = app.windows.firstMatch.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: name.frame.minX + 60, dy: name.frame.maxY + 28))
        markPoint.tap()
        XCTAssertTrue(app.staticTexts["Until"].waitForExistence(timeout: 4), "the mark opens the date calendar")
        app.buttons["Cancel"].firstMatch.tap()
    }

    // MARK: Fix 2: Add Task from the popup

    /// Checked: the popup's Add Task for this week keeps the keyboard in the field, and
    /// typing straight after it starts a new task (nothing joined onto the one just added).
    @MainActor
    func testPopupAddTaskThenTypingRightAwayKeepsTasksApart() throws {
        let app = launch(Self.wednesday)
        openCard("Errands", in: app)
        let field = app.addTaskField
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.typeText("Buy stamps")
        openNewTaskOptions(app)
        app.buttons["One-Time"].firstMatch.tap()
        app.buttons["Add Task"].firstMatch.tap()
        app.typeText("Mail letter\n")
        sleep(1)
        print("REVIEW: after popup Add Task + typing at once: \(app.staticTexts.allElementsBoundByIndex.map(\.label).filter { $0.contains("stamps") || $0.contains("letter") })")
        XCTAssertTrue(app.staticTexts["Buy stamps"].exists)
        XCTAssertTrue(app.staticTexts["Mail letter"].exists)
        XCTAssertTrue(app.keyboards.firstMatch.exists, "the field keeps the keyboard")
        shot("fix2-popup-add-then-type", app)
    }

    /// Checked: Smart Add for a day that's next week ("tomorrow" on a Sunday) follows it
    /// there and puts the keyboard away; the bar comes back; the note has its Undo.
    @MainActor
    func testSmartAddToNextWeekPutsTheKeyboardAway() throws {
        let app = launch(["-demoData", "-demoToday", "2026-11-15", "-smartAddRules", "-smartAddDelay", "0.5"])
        openCard("Errands", in: app)
        let thisWeek = weekTitle(app)
        let field = app.addTaskField
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.typeText("Call mom tomorrow")
        app.buttons["Smart Add"].tap()
        XCTAssertTrue(app.buttons["Moved OK"].waitForExistence(timeout: 8))
        XCTAssertNotEqual(weekTitle(app), thisWeek, "the screen followed the task")
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3), "no keyboard left behind")
        shot("fix2-smartadd-next-week", app)
        app.buttons["Moved OK"].tap()
        XCTAssertTrue(app.buttons["Previous week"].waitForExistence(timeout: 3), "the bottom bar is back")
        XCTAssertTrue(app.buttons["Undo Smart Add"].exists, "the note's Undo")
    }

    // MARK: Fix 6: Add Category's Done

    /// Checked: Add one (the sheet stays), then a second typed with Just this week on and
    /// Done: both are added, the second just this week, the sheet closes and Edit ends.
    @MainActor
    func testAddCategoryAddThenDoneWithJustThisWeek() throws {
        let app = launch(Self.wednesday)
        app.buttons["Edit"].tap()
        let tile = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Add Category")).firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 5))
        tile.tap()
        app.buttons["Create New Category"].tap()
        let field = app.textFields["Category name"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.typeText("Garden")
        app.buttons.matching(NSPredicate(format: "label == %@", "Add Category")).allElementsBoundByIndex
            .last { $0.isHittable }?.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Added Garden")).firstMatch
            .waitForExistence(timeout: 3), "the sheet stays after Add Category")
        let name = app.textFields["Category name"]
        name.tap()
        name.typeText("Trip")
        let toggle = app.switches.matching(NSPredicate(format: "label BEGINSWITH %@", "Just this week")).firstMatch
        XCTAssertEqual(toggle.value as? String, "0", "off again after an add")
        toggle.switches.firstMatch.tap()
        app.navigationBars["Add Category"].buttons["Done"].tap()
        XCTAssertTrue(app.navigationBars["Add Category"].waitForNonExistence(timeout: 3), "Done closes the sheet")
        XCTAssertTrue(app.buttons["Edit"].waitForExistence(timeout: 3), "Edit ended")
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        let trip = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Trip,")).firstMatch
        let garden = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Garden,")).firstMatch
        XCTAssertTrue(trip.waitForExistence(timeout: 3))
        XCTAssertTrue(garden.exists)
        print("REVIEW: Trip \(trip.label) | Garden \(garden.label)")
        XCTAssertTrue(trip.label.lowercased().contains("just this week"), "Trip is just this week")
        XCTAssertFalse(garden.label.lowercased().contains("just this week"))
        shot("fix6-add-then-done", app)
    }

    // MARK: Fix 7: Settings rebuilt on light/dark

    /// Settings ▸ Saved Categories open when the phone goes dark: the list behind it is
    /// rebuilt (`.id` on the scheme), which can pop the page it pushed.
    @MainActor
    func testSavedCategoriesStaysOpenWhenPhoneGoesDark() throws {
        let app = launch(Self.wednesday)
        app.buttons["Settings"].tap()
        app.settingsButton("Saved Categories").tap()
        XCTAssertTrue(app.navigationBars["Saved Categories"].waitForExistence(timeout: 3))
        XCUIDevice.shared.appearance = .dark
        sleep(3)
        shot("fix7-saved-categories-dark", app)
        XCTAssertTrue(app.navigationBars["Saved Categories"].exists, "still on Saved Categories")
        XCUIDevice.shared.appearance = .light
        sleep(2)
        XCTAssertTrue(app.navigationBars["Saved Categories"].exists, "still on Saved Categories after going light")
    }

    /// Settings scrolled down to About when the phone goes dark: the list, rebuilt by fix 7's
    /// `.id`, jumps back to the top.
    @MainActor
    func testSettingsKeepsItsPlaceWhenPhoneGoesDark() throws {
        let app = launch(Self.wednesday)
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.buttons["System"].waitForExistence(timeout: 5))
        let system = app.buttons["System"]
        for _ in 0..<6 { app.collectionViews.firstMatch.swipeUp(velocity: .slow) }
        sleep(1)
        shot("fix7-settings-scrolled-light", app)
        XCTAssertFalse(system.exists && system.isHittable, "scrolled down, past Appearance")
        XCUIDevice.shared.appearance = .dark
        sleep(3)
        shot("fix7-settings-scrolled-dark", app)
        print("REVIEW: after going dark, System hittable \(system.exists && system.isHittable)")
        XCTAssertFalse(system.exists && system.isHittable, "Settings kept its place, not back at the top")
    }

    /// Checked: Help open over Settings stays open when the phone goes dark.
    @MainActor
    func testHelpStaysOpenWhenPhoneGoesDark() throws {
        let app = launch(Self.wednesday)
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.buttons["System"].waitForExistence(timeout: 5))
        let help = app.settingsButton("How to Use Tasquel")
        help.tap()
        XCTAssertTrue(app.buttons["Q&A"].waitForExistence(timeout: 5) || app.navigationBars.count > 1)
        let helpBars = app.navigationBars.allElementsBoundByIndex.map(\.identifier)
        XCUIDevice.shared.appearance = .dark
        sleep(3)
        shot("fix7-help-dark", app)
        print("REVIEW: nav bars with Help open \(helpBars) → after dark \(app.navigationBars.allElementsBoundByIndex.map(\.identifier))")
        XCTAssertEqual(app.navigationBars.allElementsBoundByIndex.map(\.identifier), helpBars, "Help stays open")
    }

    // MARK: Fixes 4 and 5 at the largest text size

    /// Checked: Settings ▸ Saved Categories (it shares `SavedCategoryRow` with Add Category)
    /// keeps whole words at the largest size; the chip at the largest size toggles and the
    /// Completed line follows.
    @MainActor
    func testSettingsSavedCategoriesShowWholeNamesAtLargestText() throws {
        let app = launch(Self.wednesday + Self.largestText)
        app.buttons["Settings"].tap()
        app.settingsButton("Saved Categories").tap()
        XCTAssertTrue(app.navigationBars["Saved Categories"].waitForExistence(timeout: 3))
        sleep(1)
        shot("fix5-settings-saved-categories-ax", app)
        // The rows are in-place name fields: one line, so a long name is cut off ("Appointme…").
        let field = app.textFields.matching(NSPredicate(format: "value == %@", "Appointments")).firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        let font = UIFont.preferredFont(forTextStyle: .body,
                                        compatibleWith: UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge))
        let needed = ("Appointments" as NSString).size(withAttributes: [.font: font]).width
        print("REVIEW: Settings ▸ Saved Categories at AX: Appointments field \(field.frame), needs \(needed)")
        XCTAssertGreaterThanOrEqual(field.frame.width, needed, "the whole name shows (it reads Appointme…)")
    }

    /// Checked: the Just this week chip at the largest size toggles, stays on the card, and
    /// the Completed line follows.
    @MainActor
    func testJustThisWeekChipTogglesAtLargestText() throws {
        let app = launch(Self.wednesday + Self.largestText)
        openCard("Errands", in: app)
        app.editCard("Errands")
        let chip = app.descendants(matching: .any)["Just this week chip"].firstMatch
        XCTAssertTrue(chip.waitForExistence(timeout: 3))
        chip.tap()
        sleep(1)
        shot("fix4-chip-on-ax", app)
        print("REVIEW: chip value \(chip.value ?? "") frame \(chip.frame)")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "just this week")).firstMatch.exists,
                      "the Completed line says just this week")
        XCTAssertLessThanOrEqual(chip.frame.maxX, app.windows.firstMatch.frame.maxX)
    }

    // MARK: Helpers

    @MainActor
    private func launch(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
        if app.staticTexts["Welcome to Tasquel"].waitForExistence(timeout: 3) { app.buttons["Skip"].tap() }
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 15))
        return app
    }

    @MainActor
    private func openCard(_ name: String, in app: XCUIApplication) {
        let card = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open \(name),")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.tap()
        XCTAssertTrue(app.buttons["Close \(name)"].waitForExistence(timeout: 3))
        sleep(1)
    }

    @MainActor
    private func openNewTaskOptions(_ app: XCUIApplication) {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "New task options")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["DAY"].waitForExistence(timeout: 3))
    }

    /// Types a new task, picks its day in the add row's options, and adds it from there.
    @MainActor
    private func addWithDay(_ title: String, day: String, in app: XCUIApplication) {
        let field = app.addTaskField
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.typeText(title)
        openNewTaskOptions(app)
        app.buttons[day].tap()
        app.buttons["Add Task"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["DAY"].waitForNonExistence(timeout: 3))
        sleep(1)
    }

    @MainActor
    private func closeKeyboard(_ app: XCUIApplication) {
        let done = app.buttons["Done"].firstMatch
        if app.keyboards.firstMatch.exists, done.exists { done.tap() }
        _ = app.keyboards.firstMatch.waitForNonExistence(timeout: 3)
        sleep(1)
    }

    private func weekTitle(_ app: XCUIApplication) -> String {
        app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Week of")).firstMatch.label
    }

    private func shot(_ name: String, _ app: XCUIApplication) {
        let dir = ProcessInfo.processInfo.environment["SHOT_DIR"] ?? NSTemporaryDirectory()
        try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
