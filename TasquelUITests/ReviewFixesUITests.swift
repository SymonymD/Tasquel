import XCTest

/// Fixes from the 2026-11-15 review (`reviews/applereview-2026-11-15/`), one test each,
/// adapted from the reviewers' own tests (which are kept, whole, in that folder). Each failed
/// before its fix.
final class ReviewFixesUITests: XCTestCase {
    private static let largestText = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]

    override func setUp() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        XCUIDevice.shared.appearance = .light
    }

    override func tearDown() {
        XCUIDevice.shared.appearance = .light
    }

    /// 2: typed words, a date in a later week from the options popup, then the popup's Add
    /// Task: the screen follows the task there and the keyboard goes. It stayed up with no
    /// field to type in, the bottom bar gone.
    @MainActor
    func testPopupAddToAnotherWeekPutsTheKeyboardAway() throws {
        let app = launch(["-isolatedData"])
        openCard("Errands", in: app)
        let field = app.addTaskField
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText("Return library books")
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "New task options")).firstMatch.tap()
        XCTAssertTrue(app.buttons["Add a date"].waitForExistence(timeout: 3))
        app.buttons["One-Time"].firstMatch.tap()
        app.buttons["Add a date"].tap()
        XCTAssertTrue(app.staticTexts["Until"].waitForExistence(timeout: 3))
        // Eight days on is always in a later week.
        let later = Calendar.current.date(byAdding: .day, value: 8, to: Date())!
        let cell = app.buttons[later.formatted(.dateTime.weekday(.wide).month(.wide).day())]
        if !cell.exists { app.buttons["Next month"].tap() }
        cell.tap()
        app.buttons["Set"].tap()
        let thisWeek = weekTitle(app)
        app.buttons["Add Task"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Moved OK"].waitForExistence(timeout: 5))
        XCTAssertNotEqual(weekTitle(app), thisWeek, "the screen followed the task")
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3), "no keyboard left behind")
        app.buttons["Moved OK"].tap()
        XCTAssertTrue(app.buttons["Previous week"].waitForExistence(timeout: 3), "the bottom bar is back")
    }

    /// 3: at the largest text size a dated task's name keeps the row's width; its date mark
    /// goes under it. It read "Pl / an / M / o / m's" in a 62pt column.
    @MainActor
    func testDatedNameKeepsItsWidthAtLargestText() throws {
        let app = launch(["-demoData", "-demoToday", "2026-11-11"] + Self.largestText)
        openCard("Errands", in: app)
        let name = app.staticTexts["Plan Mom's birthday"].firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        let screen = app.windows.firstMatch.frame
        for _ in 0..<8 where name.frame.minY > screen.maxY - 200 { app.swipeUp(velocity: .slow) }
        XCTAssertGreaterThan(name.frame.width, 150, "most of the row, not a sliver beside the date")
        XCTAssertLessThan(name.frame.height, 260, "a few lines, not one per word")
    }

    /// 4: in a card's edit mode at the largest text size the Just this week chip stays on
    /// the card and the Completed line stays readable.
    @MainActor
    func testJustThisWeekChipFitsAtLargestText() throws {
        let app = launch(["-demoData", "-demoToday", "2026-11-11"] + Self.largestText)
        openCard("Errands", in: app)
        app.editCard("Errands")
        let chip = app.descendants(matching: .any)["Just this week chip"].firstMatch
        XCTAssertTrue(chip.waitForExistence(timeout: 3))
        let completed = app.staticTexts["1 of 4 complete"].firstMatch
        XCTAssertLessThanOrEqual(chip.frame.maxX, app.windows.firstMatch.frame.maxX - 16, "the chip stays on the card")
        XCTAssertGreaterThan(completed.frame.width, 40, "the Completed line is still there")
    }

    /// 5: Add Category at the largest text size: the Saved Categories heading doesn't break
    /// mid-word beside Edit ("Cate- / gories").
    @MainActor
    func testAddCategoryHeadingKeepsWholeWordsAtLargestText() throws {
        let app = launch(["-demoData", "-demoToday", "2026-11-11"] + Self.largestText)
        app.buttons["Edit"].tap()
        let tile = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Add Category")).firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 5))
        tile.tap()
        XCTAssertTrue(app.navigationBars["Add Category"].waitForExistence(timeout: 5))
        let heading = app.staticTexts["Saved Categories"].firstMatch
        let createNew = app.staticTexts["Create New"].firstMatch
        XCTAssertTrue(heading.waitForExistence(timeout: 3))
        let oneLine = createNew.frame.height
        for _ in 0..<3 where heading.frame.maxY > app.windows.firstMatch.frame.maxY - 120 {
            app.collectionViews.firstMatch.swipeUp(velocity: .slow)
        }
        sleep(1)
        XCTAssertLessThan(heading.frame.height, oneLine * 1.9, "at most two lines, no word split")
    }

    /// 6: Add Category's Done with a name typed adds it and closes the sheet.
    @MainActor
    func testAddCategoryDoneWithANameTypedAddsAndCloses() throws {
        let app = launch(["-isolatedData"])
        app.buttons["Edit"].tap()
        let tile = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Add Category")).firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 3))
        tile.tap()
        app.buttons["Create New Category"].tap()
        let field = app.textFields["Category name"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.typeText("Garden")
        app.navigationBars["Add Category"].buttons["Done"].tap()
        XCTAssertTrue(app.navigationBars["Add Category"].waitForNonExistence(timeout: 3), "Done closes the sheet")
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Garden,")).firstMatch
            .waitForExistence(timeout: 3), "Garden was added")
    }

    /// 7: Seasonal picked with Settings open, then the phone goes dark: the rows go dark with
    /// it. They stayed cream under light words.
    @MainActor
    func testSeasonalSettingsRowsFollowTheDarkSwitch() throws {
        let app = launch(["-demoData", "-demoSeason", "fall"])
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.buttons["System"].waitForExistence(timeout: 5))
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Seasonal")).firstMatch.tap()
        sleep(1)
        XCUIDevice.shared.appearance = .dark
        sleep(3)
        let row = app.buttons["System"].frame, screen = app.frame
        let brightness = Self.brightness(atX: Double((row.minX + row.width * 0.75) / screen.width), y: Double(row.midY / screen.height))
        XCTAssertLessThan(brightness, 0.35, "the rows went dark with the phone")
    }

    /// Seasonal's colors are plain colors for the phone's light or dark (`SeasonalScheme`, set
    /// by ContentView), no longer UIKit colors that picked as they were drawn (they made
    /// swiping weeks lag, 2026-11-15). The cards and backdrop must still follow a switch
    /// made while the app is open, both ways.
    @MainActor
    func testSeasonalScreenFollowsTheDarkSwitch() throws {
        XCUIDevice.shared.appearance = .light
        let app = launch(["-demoData", "-demoAppearance", "seasonal", "-demoSeason", "fall"])
        let card = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open ")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        sleep(1)
        XCTAssertGreaterThan(cardBrightness(card.frame, app), 0.75, "a fall card is cream in light mode")
        XCUIDevice.shared.appearance = .dark
        sleep(3)
        XCTAssertLessThan(cardBrightness(card.frame, app), 0.35, "the cards went dark with the phone")
        XCTAssertLessThan(Self.brightness(atX: 0.04, y: 0.995), 0.35, "so did what's behind them")
        XCUIDevice.shared.appearance = .light
        sleep(3)
        XCTAssertGreaterThan(cardBrightness(card.frame, app), 0.75, "and light again")
    }

    // MARK: Helpers

    /// The median brightness along a line across a card's lower part, clear of a stray word.
    @MainActor
    private func cardBrightness(_ frame: CGRect, _ app: XCUIApplication) -> CGFloat {
        let screen = app.frame
        let samples = (2...8).map { step in
            Self.brightness(atX: Double((frame.minX + frame.width * CGFloat(step) / 10) / screen.width),
                            y: Double((frame.minY + frame.height * 0.82) / screen.height))
        }
        return samples.sorted()[samples.count / 2]
    }

    @MainActor
    private func launch(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
        if app.staticTexts["Welcome to Tasquel"].waitForExistence(timeout: 3) { app.buttons["Skip"].tap() }
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 10))
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

    private func weekTitle(_ app: XCUIApplication) -> String {
        app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Week of")).firstMatch.label
    }

    /// The screen's brightness (0 black … 1 white) at a point, as fractions of its size.
    private static func brightness(atX fx: Double, y fy: Double) -> CGFloat {
        guard let cg = XCUIScreen.main.screenshot().image.cgImage,
              let data = cg.dataProvider?.data, let bytes = CFDataGetBytePtr(data) else { return -1 }
        let x = Int(Double(cg.width) * fx), y = Int(Double(cg.height) * fy)
        let offset = y * cg.bytesPerRow + x * (cg.bitsPerPixel / 8)
        return (CGFloat(bytes[offset]) + CGFloat(bytes[offset + 1]) + CGFloat(bytes[offset + 2])) / (3 * 255)
    }
}
