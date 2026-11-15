import XCTest

/// Exploration for the Settings and themes review: walks every appearance over the same
/// screen (demo data on a Wednesday, a day task, a duplicate, pins) and saves screenshots.
/// Run in light, then in dark (`xcrun simctl ui <UDID> appearance dark`); SHOT_PREFIX names them.
final class ReviewSettingsExploreTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = true
        // DARK=1: the phone in Dark for these looks (simctl's setting doesn't stick once a test has set one).
        XCUIDevice.shared.appearance = ProcessInfo.processInfo.environment["DARK"] != nil ? .dark : .light
    }

    private var prefix: String { ProcessInfo.processInfo.environment["SHOT_PREFIX"] ?? "explore" }

    /// Demo data with a day task, a duplicate, a pinned card and a pinned task in Errands, open.
    @MainActor
    private func preparedApp(_ extra: [String] = []) -> XCUIApplication {
        let app = ReviewSettings.launch(["-demoData", "-demoToday", "2026-11-11", "-fakeCalendar", "-demoFirstCard", "Errands"] + extra)
        let errands = ReviewSettings.card("Errands", in: app)
        XCTAssertTrue(errands.waitForExistence(timeout: 8))
        // Pin the Errands card in Edit.
        app.buttons["Edit"].tap()
        let pinErrands = app.buttons["Pin Errands"]
        if pinErrands.waitForExistence(timeout: 3) { pinErrands.tap() }
        app.buttons["Done Editing"].tap()
        sleep(1)
        errands.tap()
        sleep(1)
        // A duplicate of a task and a day for another.
        let field = app.addTaskField
        if field.waitForExistence(timeout: 3) {
            field.tap()
            field.typeText("Pick up dry cleaning\n")
            Thread.sleep(forTimeInterval: 0.4)
            field.typeText("Return library books\n")
            app.buttons["Done"].firstMatch.tap()
            sleep(1)
        }
        let options = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Task options:"))
        let row = app.staticTexts["Return library books"]
        if row.exists {
            let frame = row.frame
            options.allElementsBoundByIndex.min { abs($0.frame.midY - frame.midY) < abs($1.frame.midY - frame.midY) }?.tap()
            if app.buttons["Friday"].firstMatch.waitForExistence(timeout: 3) { app.buttons["Friday"].firstMatch.tap() }
            app.buttons["Done"].firstMatch.tap()
            sleep(1)
        }
        // Pin Groceries in the card's own edit mode.
        if app.buttons["Edit Errands"].exists {
            app.editCard("Errands")
            let pin = app.buttons["Pin Groceries to the top"]
            if pin.waitForExistence(timeout: 2) { pin.tap() }
            ReviewSettings.shot("\(prefix)-cardedit")
            app.buttons["Done editing Errands"].firstMatch.tap()
            sleep(1)
        }
        return app
    }

    @MainActor
    func testExploreAppearances() throws {
        let app = preparedApp(["-demoWhatsNew"])
        ReviewSettings.shot("\(prefix)-00-system-main")
        print("REVIEW TREE\n\(app.debugDescription)")
        for (index, mode) in ["Light", "Dark", "Seasonal", "Retro", "System"].enumerated() {
            ReviewSettings.openSettings(app)
            ReviewSettings.pickAppearance(mode, in: app)
            ReviewSettings.shot("\(prefix)-\(index + 1)-\(mode)-settings")
            if ProcessInfo.processInfo.environment["SHEETS"] != nil { sheets(app, "\(prefix)-\(index + 1)-\(mode)") }
            ReviewSettings.closeSettings(app)
            ReviewSettings.shot("\(prefix)-\(index + 1)-\(mode)-main")
        }
    }

    /// Help (Q&A and Dates tabs), What's New, and the lower half of Settings, from Settings.
    @MainActor
    private func sheets(_ app: XCUIApplication, _ name: String) {
        let help = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "How to Use Tasquel")).firstMatch
        ReviewSettings.scrollTo(help, in: app)
        ReviewSettings.shot("\(name)-settings2")
        help.tap()
        sleep(1)
        ReviewSettings.shot("\(name)-help")
        // Swipe the pages to the last tab, Dates (its pill is off to the side on an iPhone).
        for _ in 0..<6 { app.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.6)).press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.6))); Thread.sleep(forTimeInterval: 0.6) }
        ReviewSettings.shot("\(name)-help-dates")
        print("REVIEW: Help Dates pill selected after 6 swipes: \(app.buttons["Dates"].firstMatch.isSelected), hittable: \(app.buttons["Dates"].firstMatch.isHittable)")
        let helpBar = app.navigationBars.matching(NSPredicate(format: "identifier == %@ OR identifier == %@", "How to Use Tasquel", "> HELP_")).firstMatch
        helpBar.buttons.firstMatch.tap()
        sleep(1)
        let whatsNew = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "What's New in")).firstMatch
        ReviewSettings.scrollTo(whatsNew, in: app)
        whatsNew.tap()
        sleep(1)
        ReviewSettings.shot("\(name)-whatsnew")
        app.buttons["Continue"].firstMatch.tap()
        sleep(1)
        let privacy = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Privacy Policy")).firstMatch
        ReviewSettings.scrollTo(privacy, in: app)
        ReviewSettings.shot("\(name)-settings3")
        ReviewSettings.scrollTo(app.buttons["System"], in: app, up: true)
    }

    @MainActor
    func testExploreRetroColors() throws {
        let app = preparedApp()
        ReviewSettings.openSettings(app)
        ReviewSettings.pickAppearance("Retro", in: app)
        for color in ["Green", "Amber", "Blue", "White", "Red", "Purple"] {
            let swatch = app.buttons[color]
            ReviewSettings.scrollTo(swatch, in: app, up: true)
            swatch.tap()
            ReviewSettings.shot("\(prefix)-retro-\(color)-settings")
            ReviewSettings.closeSettings(app)
            ReviewSettings.shot("\(prefix)-retro-\(color)-main")
            ReviewSettings.openSettings(app)
        }
    }

    /// Seasonal for the season in SEASON (passed as -demoSeason).
    @MainActor
    func testExploreSeason() throws {
        let season = ProcessInfo.processInfo.environment["SEASON"] ?? "fall"
        let app = preparedApp(["-demoSeason", season, "-demoAppearance", "seasonal", "-demoWhatsNew"])
        ReviewSettings.shot("\(prefix)-season-\(season)-main")
        ReviewSettings.openSettings(app)
        ReviewSettings.shot("\(prefix)-season-\(season)-settings")
        ReviewSettings.closeSettings(app)
    }
    /// The new parts in one look (APPEARANCE, SEASON, HOLIDAY from the environment): holiday
    /// mark, day filter, card edit mode, a DOS field, Edit with Add Category, next week's house,
    /// Go to Week.
    @MainActor
    func testExploreNewParts() throws {
        // COMBOS: "look:season:holiday,…", e.g. "retro::thanksgiving,seasonal:winter:holidaySeason".
        let combos = (ProcessInfo.processInfo.environment["COMBOS"] ?? "system::").split(separator: ",").map(String.init)
        for combo in combos { exploreNewParts(combo) }
    }

    @MainActor
    private func exploreNewParts(_ combo: String) {
        let parts = combo.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        let look = parts[0]
        var extra = ["-demoAppearance", look, "-demoWhatsNew"]
        if parts.count > 1, !parts[1].isEmpty { extra += ["-demoSeason", parts[1]] }
        if parts.count > 2, !parts[2].isEmpty { extra += ["-demoHoliday", parts[2]] }
        let app = preparedApp(extra)
        let name = "\(prefix)-new-\(look)\(parts.count > 1 && !parts[1].isEmpty ? "-" + parts[1] : "")"
        ReviewSettings.shot("\(name)-1-main")
        let friday = app.buttons["Day Friday"].firstMatch
        if friday.exists { friday.tap(); ReviewSettings.shot("\(name)-2-dayfilter"); friday.tap(); sleep(1) }
        if app.buttons["Edit Errands"].exists {
            app.editCard("Errands")
            ReviewSettings.shot("\(name)-3-cardedit")
            app.buttons["Done editing Errands"].firstMatch.tap()
            sleep(1)
        }
        let field = app.addTaskField
        if field.waitForExistence(timeout: 3) {
            field.tap()
            field.typeText("abc")
            ReviewSettings.shot("\(name)-4-field")
            app.buttons["Done"].firstMatch.tap()
            sleep(1)
        }
        app.buttons["Edit"].tap()
        sleep(1)
        ReviewSettings.shot("\(name)-5-edit")
        let tile = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@ OR label CONTAINS %@", "Add Category", "NEW_CATEGORY")).firstMatch
        if tile.exists {
            tile.tap(); sleep(1)
            ReviewSettings.shot("\(name)-6-addcategory")
            app.navigationBars["Add Category"].buttons.firstMatch.tap()
            sleep(1)
        }
        app.buttons["Done Editing"].tap()
        sleep(1)
        app.buttons["Next week"].tap()
        sleep(2)
        ReviewSettings.shot("\(name)-7-nextweek")
        let calendarButton = app.buttons.matching(NSPredicate(format: "label == %@ OR label == %@", "Go to week", "Calendar and events")).firstMatch
        if calendarButton.exists { calendarButton.tap() }
        sleep(1)
        ReviewSettings.shot("\(name)-8-gotoweek")
    }
}
