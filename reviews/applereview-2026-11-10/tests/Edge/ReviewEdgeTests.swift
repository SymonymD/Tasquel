import XCTest

/// Edge cases and small screens (App Review audit, 1.0.3). Written for the iPhone SE (3rd
/// generation), the smallest iPhone, but none of it depends on the device.
final class ReviewEdgeTests: XCTestCase {

    override func setUp() {
        continueAfterFailure = true
    }

    // MARK: Helpers

    @MainActor
    private func launch(_ arguments: [String], tz: String? = nil, throughOnboarding: Bool = true) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = arguments
        if let tz { app.launchEnvironment["TZ"] = tz }
        app.launch()
        if throughOnboarding, app.staticTexts["Welcome to Tasquel"].waitForExistence(timeout: 3) {
            for _ in 0..<4 { app.buttons["Next"].tap() }
            app.buttons["Let's Go!"].tap()
        }
        return app
    }

    @MainActor
    private func shot(_ app: XCUIApplication, _ name: String) {
        Thread.sleep(forTimeInterval: 0.7)
        let image = XCUIScreen.main.screenshot()
        let dir = ProcessInfo.processInfo.environment["SHOT_DIR"] ?? NSTemporaryDirectory()
        try? image.pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
        let attachment = XCTAttachment(screenshot: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func openCard(_ app: XCUIApplication, _ name: String) {
        let card = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open \(name),")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5), "card \(name)")
        card.tap()
    }

    @MainActor
    private func weekTitle(_ app: XCUIApplication) -> String {
        app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Week of")).firstMatch.label
    }

    /// Adds a list task named `title` to the open card (the field takes the keyboard for its
    /// first item afterwards) and returns the Add item field.
    @MainActor
    private func addList(_ app: XCUIApplication, _ title: String) -> XCUIElement {
        let field = app.addTaskField
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText(title)
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "New task options")).firstMatch.tap()
        app.buttons["List"].firstMatch.tap()
        app.buttons["Add Task"].tap()
        let item = app.textFields["Add item"]
        XCTAssertTrue(item.waitForExistence(timeout: 3))
        return item
    }

    @MainActor
    private func closeKeyboard(_ app: XCUIApplication) {
        let done = app.buttons["keyboard.chevron.compact.down"]
        if done.exists { done.tap() } else if app.buttons["Done"].exists { app.buttons["Done"].firstMatch.tap() }
        _ = app.keyboards.firstMatch.waitForNonExistence(timeout: 3)
    }

    // MARK: Bottom bar on a Home-button iPhone after onboarding

    /// The bottom bar's gap to the screen's bottom edge must be the same after onboarding
    /// (fresh data) as on a launch without it. The home-indicator inset (0 on a Home-button
    /// iPhone) is skipped while a sheet is up, and onboarding is a sheet from the first frame.
    @MainActor
    func testBottomBarSitsAtBottomAfterOnboarding() throws {
        let fresh = launch(["-isolatedData"])
        let settings = fresh.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1)
        let window = fresh.windows.firstMatch.frame
        let gapAfterOnboarding = window.maxY - settings.frame.maxY
        shot(fresh, "bar-after-onboarding")
        fresh.terminate()

        let demo = launch(["-demoData"], throughOnboarding: false)
        XCTAssertTrue(demo.buttons["Settings"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1)
        let gapNoOnboarding = demo.windows.firstMatch.frame.maxY - demo.buttons["Settings"].frame.maxY
        shot(demo, "bar-no-onboarding")
        print("REVIEW: bar gap after onboarding=\(gapAfterOnboarding) without onboarding=\(gapNoOnboarding) window=\(window)")
        XCTAssertEqual(gapAfterOnboarding, gapNoOnboarding, accuracy: 2,
                       "the bar sits at the same place after onboarding as on a normal launch")

        // A later launch of the same data (no onboarding) for comparison.
        demo.terminate()
    }

    /// On a Home-button iPhone (no home indicator, bottom inset 0) the bar's buttons keep a
    /// margin above the screen's bottom edge, instead of running into it.
    @MainActor
    func testBottomBarClearsBottomEdgeOnHomeButtonIPhone() throws {
        let app = launch(["-demoData"], throughOnboarding: false)
        let settings = app.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1)
        let window = app.windows.firstMatch.frame
        shot(app, "bar-home-button-iphone")
        for button in [settings, app.buttons["Go to week"], app.buttons["Edit"]] {
            print("REVIEW: \(button.label) frame=\(button.frame) window=\(window)")
            XCTAssertLessThanOrEqual(button.frame.maxY, window.maxY - 6, "\(button.label) keeps a margin above the bottom edge")
        }
    }

    /// The same data relaunched after onboarding (no sheet at launch) puts the bar back.
    @MainActor
    func testBottomBarAfterOnboardingThenRelaunch() throws {
        let id = "bar-\(UUID().uuidString)"
        let app = launch(["-isolatedDataID", id])
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1)
        let gap1 = app.windows.firstMatch.frame.maxY - app.buttons["Settings"].frame.maxY
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1)
        let gap2 = app.windows.firstMatch.frame.maxY - app.buttons["Settings"].frame.maxY
        shot(app, "bar-relaunch")
        // Settings opened and closed (a sheet) after onboarding: does the bar move?
        app.buttons["Settings"].tap()
        let done = app.buttons["Done"].firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 3))
        done.tap()
        Thread.sleep(forTimeInterval: 1)
        let gap3 = app.windows.firstMatch.frame.maxY - app.buttons["Settings"].frame.maxY
        print("REVIEW: bar gap first launch (after onboarding)=\(gap1) relaunch=\(gap2) after Settings=\(gap3)")
        XCTAssertEqual(gap1, gap2, accuracy: 2, "first launch and relaunch place the bar alike")
    }

    // MARK: Folding lists: long titles, counts

    /// A very long list title beside the folded count, the chevron and the type/mode button:
    /// the title wraps, the count and both buttons stay on the screen and inside the card.
    @MainActor
    func testLongListTitleBesideFoldedCount() throws {
        let app = launch(["-isolatedData"])
        openCard(app, "Errands")
        let title = "Pick up everything we need for the long weekend at the cabin by the lake 🏕️🛶 before Friday"
        let item = addList(app, title)
        item.typeText("Firewood\n")
        Thread.sleep(forTimeInterval: 0.4)
        item.typeText("Marshmallows\n")
        Thread.sleep(forTimeInterval: 0.4)
        closeKeyboard(app)
        let fold = app.buttons["Fold \(title)"]
        XCTAssertTrue(fold.waitForExistence(timeout: 3))
        fold.tap()
        let count = app.staticTexts.matching(NSPredicate(format: "value == %@", "0 of 2 items checked")).firstMatch
        XCTAssertTrue(count.waitForExistence(timeout: 3))
        shot(app, "long-list-title-folded")
        let window = app.windows.firstMatch.frame
        let options = app.buttons["Task options: List, One-Time"]
        let titleText = app.staticTexts[title]
        print("REVIEW: title=\(titleText.frame) count=\(count.frame) fold=\(fold.frame) options=\(options.frame)")
        XCTAssertTrue(count.isHittable || count.frame.width > 0)
        XCTAssertLessThanOrEqual(options.frame.maxX, window.maxX)
        XCTAssertLessThanOrEqual(titleText.frame.maxX, count.frame.minX + 1, "the title doesn't run under the count")
        XCTAssertLessThanOrEqual(count.frame.maxX, fold.frame.minX + 12, "the count sits before the chevron")
        XCTAssertGreaterThan(titleText.frame.height, 30, "a long title wraps")
        XCTAssertGreaterThan(titleText.frame.width, 80, "the title keeps a readable width")
    }

    /// The same at the largest accessibility text size.
    @MainActor
    func testLongListTitleBesideFoldedCountLargestText() throws {
        let app = launch(["-isolatedData", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        openCard(app, "Errands")
        let title = "Pick up everything for the cabin weekend"
        let item = addList(app, title)
        for n in 1...12 {
            item.typeText("Thing \(n)\n")
            Thread.sleep(forTimeInterval: 0.35)
        }
        closeKeyboard(app)
        let fold = app.buttons["Fold \(title)"]
        XCTAssertTrue(fold.waitForExistence(timeout: 3))
        fold.tap()
        let count = app.staticTexts.matching(NSPredicate(format: "value == %@", "0 of 12 items checked")).firstMatch
        XCTAssertTrue(count.waitForExistence(timeout: 3))
        // Scroll the folded row into view.
        if !fold.isHittable { app.swipeUp() }
        shot(app, "long-list-title-folded-axxxl")
        let titleText = app.staticTexts[title]
        let window = app.windows.firstMatch.frame
        print("REVIEW: AXXXL title=\(titleText.frame) count=\(count.frame) fold=\(fold.frame) window=\(window)")
        XCTAssertGreaterThan(titleText.frame.width, 80, "the title keeps a readable width at the largest size")
        XCTAssertLessThanOrEqual(app.buttons["Task options: List, One-Time"].frame.maxX, window.maxX)
    }

    /// Pasting several lines into Add item (a shopping list copied from Notes) adds one item
    /// per line, none holding line breaks.
    @MainActor
    func testPasteLinesIntoAddItemAddsOneItemPerLine() throws {
        try pasteLines(into: "item")
    }

    /// The same for the card's Add task field.
    @MainActor
    func testPasteLinesIntoAddTaskAddsOneTaskPerLine() throws {
        try pasteLines(into: "task")
    }

    @MainActor
    private func pasteLines(into kind: String) throws {
        let app = launch(["-isolatedData"])
        openCard(app, "Errands")
        let names = (1...8).map { "Line \($0)" }
        let field: XCUIElement
        if kind == "item" {
            field = addList(app, "Shop")
        } else {
            field = app.addTaskField
            XCTAssertTrue(field.waitForExistence(timeout: 3))
            field.tap()
        }
        UIPasteboard.general.string = names.joined(separator: "\n") + "\n"
        field.press(forDuration: 1.2)
        let paste = app.menuItems["Paste"]
        XCTAssertTrue(paste.waitForExistence(timeout: 3))
        paste.tap()
        Thread.sleep(forTimeInterval: 3)
        shot(app, "paste-\(kind)-typing")
        closeKeyboard(app)
        Thread.sleep(forTimeInterval: 1)
        shot(app, "paste-\(kind)-after")
        let rows = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Line ")).allElementsBoundByIndex.map(\.label)
        print("REVIEW: paste into \(kind): \(rows.count) rows: \(rows.map { $0.replacingOccurrences(of: "\n", with: "⏎") })")
        for name in names {
            XCTAssertTrue(app.staticTexts[name].exists, "\(name) is its own \(kind)")
        }
        XCTAssertFalse(rows.contains { $0.contains("\n") }, "no \(kind) holds line breaks")
    }

    /// At the largest text size, a folded list (demo Groceries, 2 of 5 checked) keeps its
    /// name on the screen and its type/mode button inside the screen, as it does open.
    @MainActor
    func testFoldedListKeepsTitleAndButtonsAtLargestText() throws {
        let app = launch(["-demoData", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"],
                         throughOnboarding: false)
        openCard(app, "Errands")
        let fold = app.buttons["Fold Groceries"]
        XCTAssertTrue(fold.waitForExistence(timeout: 3))
        let window = app.windows.firstMatch.frame
        let title = app.staticTexts["Groceries"]
        let options = app.buttons["Task options: List, Repeating"]
        print("REVIEW: AXXXL open: title=\(title.frame) fold=\(fold.frame) options=\(options.frame)")
        shot(app, "axxxl-groceries-open")
        fold.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "value == %@", "2 of 5 items checked")).firstMatch.waitForExistence(timeout: 3))
        Thread.sleep(forTimeInterval: 0.5)
        shot(app, "axxxl-groceries-folded")
        let count = app.staticTexts.matching(NSPredicate(format: "value == %@", "2 of 5 items checked")).firstMatch
        print("REVIEW: AXXXL folded: title exists=\(title.exists) frame=\(title.frame) count=\(count.frame) fold=\(fold.frame) options=\(options.frame) window=\(window)")
        XCTAssertTrue(title.exists && title.frame.width > 60, "the folded list's name is still shown")
        XCTAssertLessThanOrEqual(options.frame.maxX, window.maxX, "the type/mode button stays on the screen")
        XCTAssertLessThanOrEqual(fold.frame.maxX, window.maxX, "the chevron stays on the screen")
    }

    /// 0 items: no count; 1 item; and 120 items pasted at once (multi-line paste adds one
    /// item per line). The count reads right and the app stays responsive.
    @MainActor
    func testFoldedCountZeroOneAndManyItems() throws {
        let app = launch(["-isolatedData"])
        openCard(app, "Errands")
        _ = addList(app, "Empty")
        closeKeyboard(app)
        let foldEmpty = app.buttons["Fold Empty"]
        XCTAssertTrue(foldEmpty.waitForExistence(timeout: 3))
        foldEmpty.tap()
        XCTAssertEqual(foldEmpty.label, "Expand list")
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "value ENDSWITH %@", "items checked")).firstMatch.exists,
                       "an empty folded list shows no count")
        XCTAssertFalse(app.buttons["Add item to Empty"].exists, "folded: no Add Item row")
        shot(app, "fold-empty")
        foldEmpty.tap()  // open it again

        let item = addList(app, "Big")
        item.typeText("Solo\n")
        Thread.sleep(forTimeInterval: 0.5)
        closeKeyboard(app)
        let foldBig = app.buttons["Fold Big"]
        foldBig.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "value == %@", "0 of 1 item checked")).firstMatch.waitForExistence(timeout: 3))
        foldBig.tap()

        // Paste 120 lines into Add item.
        let lines = (1...120).map { "Item \($0)" }.joined(separator: "\n") + "\n"
        UIPasteboard.general.string = lines
        app.buttons["Add item to Big"].firstMatch.tap()
        let field = app.textFields["Add item"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.press(forDuration: 1.2)
        let paste = app.menuItems["Paste"]
        if paste.waitForExistence(timeout: 3) {
            let start = Date()
            paste.tap()
            let allowPaste = app.alerts.buttons["Allow Paste"]
            if allowPaste.waitForExistence(timeout: 1) { allowPaste.tap() }
            XCTAssertTrue(app.staticTexts["Item 120"].waitForExistence(timeout: 30), "120 pasted items added")
            print("REVIEW: 120 pasted items took \(Date().timeIntervalSince(start))s")
        } else {
            XCTFail("no Paste menu")
        }
        closeKeyboard(app)
        // Fold: the row shows 0 of 121 and the card shrinks back.
        let foldAgain = app.buttons["Fold Big"]
        let deadline = Date().addingTimeInterval(10)
        while !foldAgain.isHittable && Date() < deadline { app.swipeDown() }
        foldAgain.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "value == %@", "0 of 121 items checked")).firstMatch.waitForExistence(timeout: 5))
        shot(app, "fold-121")
        // Checking the whole list from its checkbox while folded.
        app.buttons["Complete Big"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "value == %@", "121 of 121 items checked")).firstMatch.waitForExistence(timeout: 5))
    }

    // MARK: Folding while renaming or typing

    /// An item being renamed saves when its list is folded (the row goes).
    @MainActor
    func testFoldWhileRenamingItemSavesIt() throws {
        let app = launch(["-demoData"], throughOnboarding: false)
        openCard(app, "Errands")
        let lemons = app.staticTexts["Lemons"]
        XCTAssertTrue(lemons.waitForExistence(timeout: 3))
        lemons.tap()
        let field = app.textFields["Item"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.typeText(" and limes")
        app.buttons["Fold Groceries"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "value == %@", "2 of 5 items checked")).firstMatch.waitForExistence(timeout: 3))
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3), "the keyboard goes with the field")
        shot(app, "fold-while-renaming-item")
        app.buttons["Fold Groceries"].tap()
        XCTAssertTrue(app.staticTexts["Lemons and limes"].waitForExistence(timeout: 3), "the rename was saved")
    }

    /// The list's own name being renamed, then its chevron tapped: renamed and folded.
    @MainActor
    func testFoldWhileRenamingListTitle() throws {
        let app = launch(["-demoData"], throughOnboarding: false)
        openCard(app, "Errands")
        Thread.sleep(forTimeInterval: 0.8)  // the card opens
        app.staticTexts["Groceries"].tap()
        let field = app.textFields["Task name"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.typeText(" run")
        shot(app, "rename-list-title-before-fold")
        let fold = app.buttons["Fold Groceries"]
        XCTAssertTrue(fold.exists, "the chevron is there while renaming")
        fold.tap()
        Thread.sleep(forTimeInterval: 1)
        shot(app, "rename-list-title-after-fold")
        // Seen: the list folds and the rename stays open with its text; closing the
        // keyboard saves it.
        XCTAssertEqual(fold.label, "Expand list", "the tap on the chevron folded it")
        XCTAssertFalse(app.staticTexts["Lemons"].exists, "items folded away")
        closeKeyboard(app)
        XCTAssertTrue(app.staticTexts["Groceries run"].waitForExistence(timeout: 3), "renamed")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "value == %@", "2 of 5 items checked")).firstMatch.waitForExistence(timeout: 3), "folded, with its count")
    }

    /// Pasted multi-line text in a rename field: joined with spaces and saved.
    @MainActor
    func testRenamePasteMultilineJoins() throws {
        let app = launch(["-demoData"], throughOnboarding: false)
        openCard(app, "Errands")
        app.staticTexts["Plan Mom's birthday"].tap()
        let field = app.textFields["Task name"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        UIPasteboard.general.string = "Plan Mom's\nbig\n\nbirthday party"
        // Select all, then paste over it.
        field.press(forDuration: 1.2)
        if app.menuItems["Select All"].waitForExistence(timeout: 2) { app.menuItems["Select All"].tap() }
        if app.menuItems["Paste"].waitForExistence(timeout: 2) { app.menuItems["Paste"].tap() }
        XCTAssertTrue(app.staticTexts["Plan Mom's big birthday party"].waitForExistence(timeout: 3))
        shot(app, "rename-paste-multiline")
    }

    /// Fixing a typo inside a word, then Return: the name is saved as typed, without a
    /// space where the caret was (the wrapping field gets Return as a line break, and a
    /// line break is replaced by a space).
    @MainActor
    func testReturnMidWordInRenameAddsNoSpace() throws {
        let app = launch(["-demoData"], throughOnboarding: false)
        openCard(app, "Errands")
        app.staticTexts["Plan Mom's birthday"].tap()
        let field = app.textFields["Task name"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        // Rename to a typo, then move the caret back into the word with the keyboard's
        // trackpad (hold the space bar and slide), as a person fixing a typo would.
        field.press(forDuration: 1.2)
        if app.menuItems["Select All"].waitForExistence(timeout: 2) { app.menuItems["Select All"].tap() }
        field.typeText("Grocries")
        let space = app.keyboards.keys["space"]
        XCTAssertTrue(space.waitForExistence(timeout: 3))
        let start = space.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 1.0, thenDragTo: start.withOffset(CGVector(dx: -40, dy: 0)),
                    withVelocity: 60, thenHoldForDuration: 0.3)
        field.typeText("e")
        Thread.sleep(forTimeInterval: 0.3)
        let typed = (field.value as? String) ?? ""
        print("REVIEW: rename field holds '\(typed)' before Return")
        shot(app, "rename-midword-before-return")
        field.typeText("\n")
        Thread.sleep(forTimeInterval: 0.8)
        shot(app, "rename-midword-after-return")
        // The renamed task (not the Groceries list): its name contains "cries".
        let saved = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@ AND label != %@", "cries", "Groceries")).firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: 3))
        print("REVIEW: saved name '\(saved.label)' (field held '\(typed)')")
        XCTAssertEqual(saved.label, typed, "Return mid-word saves the name as typed, without adding a space")
    }

    // MARK: Time zones and travel

    /// Tasks and a folded list made far ahead (UTC+14), then the app reopened far behind
    /// (UTC−11): same week, nothing moved, duplicated or lost, still folded.
    @MainActor
    func testTravelKiritimatiToPagoPago() throws {
        let id = "tz-\(UUID().uuidString)"
        let app = launch(["-isolatedDataID", id], tz: "Pacific/Kiritimati")
        openCard(app, "Errands")
        let item = addList(app, "Packing")
        item.typeText("Passport\n")
        Thread.sleep(forTimeInterval: 0.4)
        closeKeyboard(app)
        let field = app.addTaskField
        field.tap()
        field.typeText("Book taxi\n")
        Thread.sleep(forTimeInterval: 0.4)
        closeKeyboard(app)
        app.buttons["Fold Packing"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "value == %@", "0 of 1 item checked")).firstMatch.waitForExistence(timeout: 3))
        let titleAhead = weekTitle(app)
        let todayAhead = app.otherElements["Week days"].label
        shot(app, "tz-kiritimati")
        app.terminate()

        app.launchEnvironment["TZ"] = "Pacific/Pago_Pago"
        app.launch()
        openCard(app, "Errands")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "value == %@", "0 of 1 item checked")).firstMatch.waitForExistence(timeout: 3), "still folded")
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label == %@", "Book taxi")).count, 1, "once")
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier == %@", "Fold Packing")).count, 1, "once")
        XCTAssertFalse(app.staticTexts["Past week · view only"].exists)
        let titleBehind = weekTitle(app)
        let todayBehind = app.otherElements["Week days"].label
        shot(app, "tz-pagopago")
        print("REVIEW: week ahead=\(titleAhead) [\(todayAhead)] behind=\(titleBehind) [\(todayBehind)]")
        XCTAssertEqual(titleAhead, titleBehind, "the same week (both dates are in it today)")
    }

    /// A week ending far ahead (UTC+14), reopened in the next week far behind (UTC−11):
    /// the repeating list arrives folded, the carry-over arrives, the This week only card
    /// stays behind, and last week shows the list open and view only.
    @MainActor
    func testWeekBoundaryRolloverAcrossZones() throws {
        let id = "roll-\(UUID().uuidString)"
        // Sunday of last week (Monday-start weeks), far ahead.
        let app = launch(["-isolatedDataID", id, "-demoData", "-demoToday", "2026-11-08"], tz: "Pacific/Kiritimati",
                         throughOnboarding: false)
        let lastWeek = weekTitle(app)
        openCard(app, "Appointments")
        app.buttons["Edit Appointments"].tap()
        let toggle = app.switches["This week only"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 3))
        toggle.switches.firstMatch.tap()
        XCTAssertEqual(toggle.value as? String, "1")
        app.buttons["Done editing Appointments"].tap()
        app.buttons["Close Appointments"].firstMatch.tap()
        Thread.sleep(forTimeInterval: 0.6)
        openCard(app, "Errands")
        let foldLast = app.buttons["Fold Groceries"]
        XCTAssertTrue(foldLast.waitForExistence(timeout: 3))
        foldLast.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "value == %@", "2 of 5 items checked")).firstMatch.waitForExistence(timeout: 3))
        shot(app, "roll-lastweek-kiritimati")
        app.terminate()

        app.launchArguments = ["-isolatedDataID", id]
        app.launchEnvironment["TZ"] = "Pacific/Pago_Pago"
        app.launch()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 5))
        let thisWeek = weekTitle(app)
        print("REVIEW: last week=\(lastWeek) this week=\(thisWeek)")
        XCTAssertNotEqual(lastWeek, thisWeek)
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Appointments,")).firstMatch.exists,
                       "a This week only card doesn't come back")
        openCard(app, "Errands")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "value == %@", "2 of 5 items checked")).firstMatch.waitForExistence(timeout: 3) ||
                      app.staticTexts.matching(NSPredicate(format: "value == %@", "0 of 5 items checked")).firstMatch.exists, "the repeating list arrives folded")
        XCTAssertTrue(app.staticTexts["Plan Mom's birthday"].exists, "the carry-over arrived")
        shot(app, "roll-thisweek-pagopago")

        app.buttons["Previous week"].tap()
        XCTAssertTrue(app.staticTexts["Past week · view only"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Lemons"].waitForExistence(timeout: 3) || {
            openCard(app, "Errands"); return app.staticTexts["Lemons"].waitForExistence(timeout: 3)
        }(), "a past week shows every list open")
        XCTAssertFalse(app.buttons["Fold Groceries"].exists, "no chevron in a past week")
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Appointments,")).firstMatch.exists ||
                      app.staticTexts["Appointments"].exists, "last week keeps its This week only card")
        shot(app, "roll-pastweek")
    }

    /// Delete a task, fold a list while the Undo message is up (folding keeps the Undo),
    /// then Undo: the task comes back and the list stays folded.
    @MainActor
    func testUndoDeleteKeepsLaterFold() throws {
        let app = launch(["-demoData"], throughOnboarding: false)
        openCard(app, "Errands")
        let editErrands = app.buttons["Edit Errands"]
        XCTAssertTrue(editErrands.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.6)
        editErrands.tap()
        let delete = app.buttons["Delete Plan Mom's birthday"]
        if !delete.waitForExistence(timeout: 3) { editErrands.tap() }
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        delete.tap()
        let undo = app.buttons["Undo delete"]
        XCTAssertTrue(undo.waitForExistence(timeout: 3))
        let fold = app.buttons["Fold Groceries"]
        // (Not under the header: a tap there lands on the header.)
        if !fold.isHittable || fold.frame.minY < 140 {
            let mid = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            mid.press(forDuration: 0.05, thenDragTo: mid.withOffset(CGVector(dx: 0, dy: 160)))
        }
        fold.tap()
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertEqual(fold.label, "Expand list", "folded")
        XCTAssertTrue(undo.exists, "folding keeps the Undo")
        undo.tap()
        XCTAssertTrue(app.staticTexts["Plan Mom's birthday"].waitForExistence(timeout: 3), "the task is back")
        Thread.sleep(forTimeInterval: 0.6)
        shot(app, "undo-after-fold")
        print("REVIEW: after Undo the list is \(fold.label)")
        XCTAssertEqual(fold.label, "Expand list", "Undo of the delete doesn't open the list folded after it")
    }

    /// A list folded in next week, then folded and opened again this week: next week's own
    /// fold stays ("a fold changed in a later week stays").
    @MainActor
    func testFoldSetInNextWeekStaysAfterFoldingThisWeek() throws {
        let app = launch(["-demoData"], throughOnboarding: false)
        let thisWeek = weekTitle(app)
        app.buttons["Next week"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Week of")).firstMatch.waitForExistence(timeout: 3))
        openCard(app, "Errands")
        let fold = app.buttons["Fold Groceries"]
        XCTAssertTrue(fold.waitForExistence(timeout: 3))
        fold.tap()
        XCTAssertEqual(fold.label, "Expand list", "folded in next week")
        app.buttons["Previous week"].tap()
        let back = NSPredicate { _, _ in self.weekTitle(app) == thisWeek }
        _ = XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: back, object: nil)], timeout: 5)
        if !fold.waitForExistence(timeout: 2) { openCard(app, "Errands") }
        XCTAssertEqual(fold.label, "Collapse list", "this week's list is still open")
        fold.tap()  // fold this week
        Thread.sleep(forTimeInterval: 0.5)
        fold.tap()  // and open it again
        XCTAssertEqual(fold.label, "Collapse list")
        app.buttons["Next week"].tap()
        Thread.sleep(forTimeInterval: 1)
        if !fold.waitForExistence(timeout: 2) { openCard(app, "Errands") }
        shot(app, "fold-nextweek-after-thisweek")
        print("REVIEW: next week's Groceries after folding and opening this week's: \(fold.label)")
        XCTAssertEqual(fold.label, "Expand list", "next week's own fold stays")
    }

    // MARK: Lifecycle

    /// Folding and renaming, then the app killed at once: both saved.
    @MainActor
    func testForceQuitRightAfterFoldAndRename() throws {
        let id = "kill-\(UUID().uuidString)"
        let app = launch(["-isolatedDataID", id])
        openCard(app, "Errands")
        let item = addList(app, "Hardware")
        item.typeText("Screws\n")
        Thread.sleep(forTimeInterval: 0.4)
        closeKeyboard(app)
        app.buttons["Fold Hardware"].tap()
        app.terminate()  // straight away
        app.launch()
        openCard(app, "Errands")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "value == %@", "0 of 1 item checked")).firstMatch.waitForExistence(timeout: 3), "the fold was saved")

        // Background in the middle of a rename, then killed while away.
        app.staticTexts["Hardware"].tap()
        let field = app.textFields["Task name"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.typeText(" store")
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 1)
        app.terminate()
        app.launch()
        openCard(app, "Errands")
        XCTAssertTrue(app.staticTexts["Hardware store"].waitForExistence(timeout: 3), "a rename in progress is saved on backgrounding")
    }

    /// Backgrounding mid-typing in Add item, then coming back: the item is added and the
    /// list, the keyboard and the bar are in a sane state.
    @MainActor
    func testBackgroundWhileTypingItem() throws {
        let app = launch(["-demoData"], throughOnboarding: false)
        openCard(app, "Errands")
        app.buttons["Add item to Groceries"].firstMatch.tap()
        let field = app.textFields["Add item"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.typeText("Bread")
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 1)
        app.activate()
        XCTAssertTrue(app.staticTexts["Bread"].waitForExistence(timeout: 3), "the typed item was added")
        Thread.sleep(forTimeInterval: 1)
        shot(app, "background-while-typing")
        XCTAssertTrue(app.buttons["Settings"].exists, "the bar is back")
    }

    // MARK: Small screen: keyboard and popover

    /// On the SE, with the keyboard up in a This week only card, the new task's picker
    /// (with the extra hint line) still shows Add Task.
    @MainActor
    func testPickerFitsWithKeyboardInThisWeekOnlyCard() throws {
        let app = launch(["-demoData"], throughOnboarding: false)
        openCard(app, "Appointments")
        app.buttons["Edit Appointments"].tap()
        app.switches["This week only"].switches.firstMatch.tap()
        app.buttons["Done editing Appointments"].tap()
        let field = app.addTaskField
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText("Passport photos")
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "New task options")).firstMatch.tap()
        app.buttons["Repeating"].firstMatch.tap()
        let add = app.buttons["Add Task"]
        XCTAssertTrue(add.waitForExistence(timeout: 3))
        shot(app, "picker-keyboard-thisweekonly")
        let keyboard = app.keyboards.firstMatch
        print("REVIEW: add=\(add.frame) keyboard=\(keyboard.exists ? keyboard.frame : .zero)")
        XCTAssertTrue(add.isHittable, "Add Task fits")
        if keyboard.exists { XCTAssertLessThanOrEqual(add.frame.maxY, keyboard.frame.minY + 1, "above the keyboard") }
    }

    // MARK: Reordering on the small screen

    /// The last task of a long card dragged up to near the top of the screen: the grid
    /// scrolls up and the task can be taken to the start.
    @MainActor
    func testReorderAutoScrollUpOnSmallScreen() throws {
        let app = launch(["-isolatedData"])
        openCard(app, "Errands")
        let field = app.addTaskField
        field.tap()
        for n in 1...14 {
            field.typeText("Task \(n)\n")
            usleep(400_000)
        }
        closeKeyboard(app)
        app.buttons["Edit Errands"].tap()
        let last = app.buttons["Complete Task 14"]
        let first = app.buttons["Complete Task 1"]
        XCTAssertTrue(app.buttons["Delete Task 14"].waitForExistence(timeout: 3))
        // Bring the last task into view.
        var tries = 0
        while !app.buttons["Delete Task 14"].isHittable && tries < 6 { app.swipeUp(velocity: .slow); tries += 1 }
        let handle = app.buttons["Delete Task 14"].coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5))
            .withOffset(CGVector(dx: 12, dy: 0))
        // Near the top, just under the header.
        let header = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Week of")).firstMatch.frame
        let nearTop = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 180, dy: header.maxY + 70))
        handle.press(forDuration: 0.3, thenDragTo: nearTop, withVelocity: .default, thenHoldForDuration: 5)
        let moved = NSPredicate { _, _ in last.frame.minY < first.frame.minY }
        let result = XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: moved, object: nil)], timeout: 5)
        shot(app, "reorder-up-se")
        XCTAssertEqual(result, .completed, "the last task reached the top")
    }

    // MARK: Locale and right to left

    /// German region: decimal comma in a goal target.
    @MainActor
    func testGermanDecimalCommaGoal() throws {
        let app = launch(["-isolatedData", "-AppleLanguages", "(de)", "-AppleLocale", "de_DE"])
        openCard(app, "Fitness")
        let field = app.addTaskField
        field.tap()
        field.typeText("Laufen")
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "New task options")).firstMatch.tap()
        app.buttons["Goal"].firstMatch.tap()
        app.buttons["Add Task"].tap()
        let target = app.textFields.matching(NSPredicate(format: "identifier BEGINSWITH %@ OR label BEGINSWITH %@", "Target", "Target")).firstMatch
        XCTAssertTrue(target.waitForExistence(timeout: 3))
        target.typeText("2,5")
        shot(app, "de-goal-typing")
        closeKeyboard(app)
        Thread.sleep(forTimeInterval: 0.5)
        shot(app, "de-goal-set")
        XCTAssertTrue(app.staticTexts["0 / 2,5"].waitForExistence(timeout: 3), "2,5 is two and a half")
    }

    /// Right to left (forced): the folded chevron points to the leading side's opposite
    /// (left), the count sits beside it, and nothing runs off the screen.
    @MainActor
    func testRightToLeftFoldedList() throws {
        let app = launch(["-demoData", "-AppleTextDirection", "YES", "-NSForceRightToLeftWritingDirection", "YES"],
                         throughOnboarding: false)
        openCard(app, "Errands")
        let fold = app.buttons["Fold Groceries"]
        XCTAssertTrue(fold.waitForExistence(timeout: 3))
        shot(app, "rtl-open")
        fold.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "value == %@", "2 of 5 items checked")).firstMatch.waitForExistence(timeout: 3))
        shot(app, "rtl-folded")
        let window = app.windows.firstMatch.frame
        XCTAssertGreaterThanOrEqual(fold.frame.minX, window.minX)
    }
}
