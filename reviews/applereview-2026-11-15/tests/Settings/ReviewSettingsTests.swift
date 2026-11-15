import XCTest

/// Settings and themes review, 2026-11-15. Each test starts from a clean launch.
final class ReviewSettingsTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = true
        XCUIDevice.shared.appearance = .light
    }

    override func tearDown() {
        XCUIDevice.shared.appearance = .light
    }

    private func weekTitle(_ app: XCUIApplication) -> String {
        app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Week of")).firstMatch.label
    }

    /// "Week of Nov 15" for the week starting on `day` (this year).
    private func title(forWeekStarting day: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.setLocalizedDateFormatFromTemplate("MMMd")
        return "Week of \(f.string(from: day))"
    }

    /// Pages with the week selector's arrows until the title is `wanted` (at most 8 weeks).
    @MainActor
    private func go(to wanted: String, in app: XCUIApplication) -> Bool {
        for _ in 0..<8 {
            if weekTitle(app) == wanted { return true }
            let now = weekTitle(app)
            // Titles of this year compare by month/day well enough for nearby weeks.
            let f = DateFormatter(); f.locale = Locale(identifier: "en_US"); f.dateFormat = "MMM d"
            let a = f.date(from: String(now.dropFirst(8))), b = f.date(from: String(wanted.dropFirst(8)))
            let forward = (a ?? .distantPast) < (b ?? .distantFuture)
            app.buttons[forward ? "Next week" : "Previous week"].tap()
            sleep(1)
        }
        return weekTitle(app) == wanted
    }

    // MARK: - Week start

    /// A one-time task given a date in a later week moves into its date's week (1.1). Switching
    /// Settings ▸ Week to Sunday then moves every saved week by the same number of days (six on
    /// a Sunday, one on other days), but the task's date stays put: it should still be in the
    /// week that holds its date under the new start, not vanish.
    @MainActor
    func testWeekStartSwitchKeepsDatedTaskInItsWeek() throws {
        let gregorian = Calendar(identifier: .gregorian)
        let today = gregorian.startOfDay(for: Date())
        let weekday = gregorian.component(.weekday, from: today)  // 1 Sunday … 7 Saturday
        let daysSinceMonday = (weekday + 5) % 7
        let nextMonday = gregorian.date(byAdding: .day, value: 7 - daysSinceMonday, to: today)!
        // On a Sunday every week moves six days on: a Friday of next week falls behind its week.
        // On other days they move one day back: next week's Sunday falls out of its week.
        let date = gregorian.date(byAdding: .day, value: weekday == 1 ? 4 : 6, to: nextMonday)!
        let parts = gregorian.dateComponents([.month, .day], from: date)
        let sundayWeek = gregorian.date(byAdding: .day, value: -(gregorian.component(.weekday, from: date) - 1), to: date)!

        let app = ReviewSettings.launch(["-isolatedDataID", "weekstart-\(UUID().uuidString)", "-smartAddRules"])
        let fitness = ReviewSettings.card("Fitness", in: app)
        XCTAssertTrue(fitness.waitForExistence(timeout: 8))
        fitness.tap()
        let field = app.addTaskField
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText("Dentist \(parts.month!)/\(parts.day!)")
        app.buttons["Smart Add"].tap()
        let setDate = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Set date to")).firstMatch
        XCTAssertTrue(setDate.waitForExistence(timeout: 10), "the date is offered")
        sleep(1)
        setDate.tap()
        if !app.buttons["Moved OK"].waitForExistence(timeout: 4), setDate.exists {
            print("REVIEW: the first tap on Set Date did nothing; tapping again")
            setDate.tap()
        }
        XCTAssertTrue(app.buttons["Moved OK"].waitForExistence(timeout: 5), "moved into its date's week")
        app.buttons["Moved OK"].tap()
        XCTAssertTrue(app.staticTexts["Dentist"].exists)
        print("REVIEW: Dentist (\(parts.month!)/\(parts.day!)) is in \(weekTitle(app)) with Monday starts")
        ReviewSettings.shot("weekstart-1-moved-monday")

        ReviewSettings.openSettings(app)
        app.segmentedControls.buttons["Sunday"].tap()
        sleep(1)
        ReviewSettings.closeSettings(app)

        let wanted = title(forWeekStarting: sundayWeek)
        XCTAssertTrue(go(to: wanted, in: app), "reached \(wanted)")
        if ReviewSettings.card("Fitness", in: app).exists { ReviewSettings.card("Fitness", in: app).tap(); sleep(1) }
        ReviewSettings.shot("weekstart-2-sunday-week-of-date")
        XCTAssertTrue(app.staticTexts["Dentist"].exists,
                      "Dentist, dated \(parts.month!)/\(parts.day!), is in \(wanted), the week of its date with Sunday starts")
        // Where is it, if anywhere?
        for _ in 0..<2 {
            app.buttons["Next week"].tap(); sleep(1)
            if ReviewSettings.card("Fitness", in: app).exists { ReviewSettings.card("Fitness", in: app).tap(); sleep(1) }
            print("REVIEW: \(weekTitle(app)) has Dentist: \(app.staticTexts["Dentist"].exists)")
        }
        ReviewSettings.shot("weekstart-3-sunday-later-week")

        // Back to Monday: does it come back?
        ReviewSettings.openSettings(app)
        app.segmentedControls.buttons["Monday"].tap()
        sleep(1)
        ReviewSettings.closeSettings(app)
        let mondayWeek = title(forWeekStarting: nextMonday)
        XCTAssertTrue(go(to: mondayWeek, in: app))
        if ReviewSettings.card("Fitness", in: app).exists { ReviewSettings.card("Fitness", in: app).tap(); sleep(1) }
        ReviewSettings.shot("weekstart-4-back-to-monday")
        print("REVIEW: back on Monday starts, \(weekTitle(app)) has Dentist: \(app.staticTexts["Dentist"].exists)")
        XCTAssertTrue(app.staticTexts["Dentist"].exists, "back on Monday starts, Dentist is in its week again")
    }

    /// Pinned cards stay pinned and first after switching the week's start, in this week and the next.
    @MainActor
    func testWeekStartSwitchKeepsPinnedCardsFirst() throws {
        let app = ReviewSettings.launch(["-isolatedDataID", "weekpins-\(UUID().uuidString)"])
        XCTAssertTrue(ReviewSettings.card("Study", in: app).waitForExistence(timeout: 8))
        app.buttons["Edit"].tap()
        XCTAssertTrue(app.buttons["Pin Study"].waitForExistence(timeout: 3))
        app.buttons["Pin Study"].tap()
        app.buttons["Done Editing"].tap()
        sleep(1)
        for sunday in [true, false] {
            ReviewSettings.openSettings(app)
            app.segmentedControls.buttons[sunday ? "Sunday" : "Monday"].tap()
            sleep(1)
            ReviewSettings.closeSettings(app)
            for step in 0..<2 {
                let study = ReviewSettings.card("Study", in: app).frame
                for other in ["Errands", "Work", "Fitness", "Appointments"] {
                    let frame = ReviewSettings.card(other, in: app).frame
                    XCTAssertTrue(study.minY < frame.minY - 1 || (abs(study.minY - frame.minY) < 2 && study.minX < frame.minX),
                                  "Study, pinned, is before \(other) (\(sunday ? "Sunday" : "Monday") start, week +\(step))")
                }
                XCTAssertTrue(ReviewSettings.card("Study", in: app).label.contains("pinned"), "still pinned")
                app.buttons["Next week"].tap(); sleep(1)
            }
            app.buttons["Previous week"].tap(); sleep(1)
            app.buttons["Previous week"].tap(); sleep(1)
        }
    }

    // MARK: - Reminders footer

    /// Settings ▸ Reminders' footer says when notifications are off for Tasquel. Needs a fresh
    /// install (`xcrun simctl uninstall <UDID> com.symonym.Tasquel` first) and no throwaway data,
    /// so that turning Expiration Reminders back on asks for permission. Denied in the prompt,
    /// the footer should say so at once, with Settings still open.
    @MainActor
    func testRemindersFooterSaysNotificationsOffAfterDenying() throws {
        let app = ReviewSettings.launch([])
        ReviewSettings.openSettings(app)
        let toggle = app.switches["Expiration Reminders"]
        ReviewSettings.scrollTo(toggle, in: app)
        XCTAssertTrue(toggle.exists)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        toggle.switches.firstMatch.exists ? toggle.switches.firstMatch.tap() : toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        sleep(1)
        toggle.switches.firstMatch.exists ? toggle.switches.firstMatch.tap() : toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        let deny = springboard.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Don")).firstMatch
        let asked = deny.waitForExistence(timeout: 8)
        print("REVIEW: notification prompt shown: \(asked)")
        ReviewSettings.shot("reminders-1-prompt")
        try XCTSkipUnless(asked, "the prompt didn't show: uninstall the app first")
        deny.tap()
        sleep(2)
        XCTAssertEqual(toggle.value as? String, "1", "the switch stays on")
        let off = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Notifications are off for Tasquel")).firstMatch
        ReviewSettings.shot("reminders-2-after-deny")
        XCTAssertTrue(off.waitForExistence(timeout: 3), "the footer says notifications are off, right after denying")
        ReviewSettings.closeSettings(app)
        ReviewSettings.openSettings(app)
        ReviewSettings.scrollTo(toggle, in: app)
        ReviewSettings.shot("reminders-3-reopened")
        print("REVIEW: after reopening Settings the footer says off: \(off.exists)")
        XCTAssertTrue(off.exists, "and after reopening Settings")
    }

    // MARK: - Appearance

    /// Retro in Amber is kept across a relaunch, and System afterwards brings back the plain look.
    @MainActor
    func testAppearanceAndRetroColorSurviveRelaunch() throws {
        let id = "relaunch-\(UUID().uuidString)"
        var app = ReviewSettings.launch(["-isolatedDataID", id])
        ReviewSettings.openSettings(app)
        ReviewSettings.pickAppearance("Retro", in: app)
        app.buttons["Amber"].tap()
        sleep(1)
        XCTAssertTrue(app.buttons["Amber"].isSelected)
        ReviewSettings.closeSettings(app)
        app.terminate()
        app = ReviewSettings.launch(["-isolatedDataID", id])
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["[EDIT]"].exists || app.staticTexts["[EDIT]"].exists || app.buttons["Edit"].label == "Edit", "bar is there")
        ReviewSettings.shot("relaunch-1-retro-amber")
        ReviewSettings.openSettings(app)
        XCTAssertTrue(app.navigationBars["> SETTINGS_"].exists, "still Retro after relaunch")
        XCTAssertTrue(app.buttons["Amber"].isSelected, "still Amber")
        ReviewSettings.pickAppearance("System", in: app)
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3), "the plain Settings again")
        ReviewSettings.closeSettings(app)
        app.terminate()
        app = ReviewSettings.launch(["-isolatedDataID", id])
        ReviewSettings.openSettings(app)
        XCTAssertTrue(app.navigationBars["Settings"].exists, "System kept across relaunch")
        XCTAssertTrue(app.buttons["System"].isSelected)
    }

    /// The phone switched to Dark while Settings is open, with System or Seasonal chosen:
    /// Settings and the screen behind it go dark too, and back to light.
    @MainActor
    func testSystemDarkModeSwitchWhileSettingsIsOpen() throws {
        let app = ReviewSettings.launch(["-demoData", "-demoSeason", "fall"])
        for mode in ["System", "Seasonal"] {
            ReviewSettings.openSettings(app)
            ReviewSettings.pickAppearance(mode, in: app)
            let light = ReviewSettings.brightness(atX: 0.5, y: 0.97)
            XCUIDevice.shared.appearance = .dark
            sleep(2)
            ReviewSettings.shot("darkswitch-\(mode)-1-settings-dark")
            let dark = ReviewSettings.brightness(atX: 0.5, y: 0.97)
            print("REVIEW: \(mode) Settings brightness light \(light) → dark \(dark)")
            XCTAssertLessThan(dark, 0.35, "\(mode): Settings went dark with the phone")
            ReviewSettings.closeSettings(app)
            ReviewSettings.shot("darkswitch-\(mode)-2-main-dark")
            XCTAssertLessThan(ReviewSettings.brightness(atX: 0.5, y: 0.5), 0.35, "\(mode): the main screen is dark")
            ReviewSettings.openSettings(app)
            XCUIDevice.shared.appearance = .light
            sleep(2)
            ReviewSettings.shot("darkswitch-\(mode)-3-settings-light")
            XCTAssertGreaterThan(ReviewSettings.brightness(atX: 0.5, y: 0.97), 0.6, "\(mode): Settings back to light")
            ReviewSettings.closeSettings(app)
            XCTAssertGreaterThan(ReviewSettings.brightness(atX: 0.5, y: 0.5), 0.6, "\(mode): the main screen is light")
        }
    }

    /// Seasonal, with Settings open: the phone switched to Dark turns the whole of Settings
    /// dark, its rows included (their words must stay readable), and back to Light.
    @MainActor
    func testSeasonalSettingsRowsFollowDarkSwitch() throws {
        let app = ReviewSettings.launch(["-demoData", "-demoSeason", "fall", "-demoAppearance", "seasonal"])
        ReviewSettings.openSettings(app)
        // A point inside the System row, right of its words: the row's own background.
        func rowBrightness() -> CGFloat {
            let row = app.buttons["System"].frame, screen = app.frame
            return ReviewSettings.brightness(atX: Double((row.minX + row.width * 0.75) / screen.width), y: Double(row.midY / screen.height))
        }
        let light = rowBrightness()
        ReviewSettings.shot("seasonaldark-1-light")
        XCUIDevice.shared.appearance = .dark
        sleep(3)
        let dark = rowBrightness()
        ReviewSettings.shot("seasonaldark-2-switched-dark")
        print("REVIEW: Seasonal Settings row brightness light \(light) → after switching to dark \(dark)")
        XCTAssertLessThan(dark, 0.35, "the rows went dark with the phone (light words on a cream row can't be read)")
        ReviewSettings.closeSettings(app)
        ReviewSettings.openSettings(app)
        sleep(1)
        let reopened = rowBrightness()
        ReviewSettings.shot("seasonaldark-3-reopened-dark")
        print("REVIEW: reopened in dark, row brightness \(reopened)")
        XCTAssertLessThan(reopened, 0.35, "reopened in dark, the rows are dark")
        XCUIDevice.shared.appearance = .light
        sleep(3)
        let back = rowBrightness()
        ReviewSettings.shot("seasonaldark-4-switched-light")
        print("REVIEW: switched back to light, row brightness \(back)")
        XCTAssertGreaterThan(back, 0.6, "and light again with the phone")
        // Help, opened over Settings after the switch.
        XCUIDevice.shared.appearance = .dark
        sleep(3)
        let help = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "How to Use Tasquel")).firstMatch
        ReviewSettings.scrollTo(help, in: app)
        ReviewSettings.shot("seasonaldark-5-settings-lower-dark")
        help.tap()
        sleep(2)
        ReviewSettings.shot("seasonaldark-6-help-dark")
    }

    /// Seasonal picked with Settings open (System before it), then the phone switched to Dark:
    /// the rows must turn dark with everything else. They stayed cream under light words.
    @MainActor
    func testSeasonalPickedInOpenSettingsFollowsDarkSwitch() throws {
        let app = ReviewSettings.launch(["-demoData", "-demoSeason", "fall"])
        ReviewSettings.openSettings(app)
        ReviewSettings.pickAppearance("Seasonal", in: app)
        func rowBrightness() -> CGFloat {
            let row = app.buttons["System"].frame, screen = app.frame
            return ReviewSettings.brightness(atX: Double((row.minX + row.width * 0.75) / screen.width), y: Double(row.midY / screen.height))
        }
        let light = rowBrightness()
        XCUIDevice.shared.appearance = .dark
        sleep(3)
        let dark = rowBrightness()
        let background = ReviewSettings.brightness(atX: 0.5, y: 0.97)
        ReviewSettings.shot("seasonalpicked-1-switched-dark")
        print("REVIEW: Seasonal picked in open Settings: row \(light) → \(dark) after dark switch; sheet background \(background)")
        XCTAssertLessThan(dark, 0.35, "the rows went dark with the phone (light words on a cream row can't be read)")
        ReviewSettings.closeSettings(app)
        ReviewSettings.openSettings(app)
        sleep(1)
        ReviewSettings.shot("seasonalpicked-2-reopened")
        print("REVIEW: reopened, row \(rowBrightness())")
    }

    // MARK: - Links

    /// Support and Privacy Policy open their pages in Safari, in the plain and the Retro Settings,
    /// and Tasquel comes back with Settings still open.
    @MainActor
    func testSupportAndPrivacyLinksOpenTheirPages() throws {
        let app = ReviewSettings.launch(["-isolatedData"])
        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        for retro in [false, true] {
            ReviewSettings.openSettings(app)
            if retro { ReviewSettings.pickAppearance("Retro", in: app) }
            for (link, heading) in [("Support", "Tasquel Support"), ("Privacy Policy", "Tasquel Privacy Policy")] {
                let button = app.buttons.matching(NSPredicate(format: "label == %@", link)).firstMatch
                ReviewSettings.scrollTo(button, in: app)
                XCTAssertTrue(button.isHittable, "\(link) is there")
                button.tap()
                XCTAssertTrue(safari.wait(for: .runningForeground, timeout: 15), "\(link) opens Safari")
                let page = safari.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", heading)).firstMatch
                let loaded = page.waitForExistence(timeout: 25)
                ReviewSettings.shot("links-\(retro ? "retro" : "plain")-\(link.replacingOccurrences(of: " ", with: ""))")
                XCTAssertTrue(loaded, "\(link) shows \(heading)")
                app.activate()
                XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
                let settingsBar = app.navigationBars.matching(NSPredicate(format: "identifier == %@ OR identifier == %@", "Settings", "> SETTINGS_")).firstMatch
                XCTAssertTrue(settingsBar.waitForExistence(timeout: 3), "Settings is still open on return")
            }
            ReviewSettings.scrollTo(app.buttons["System"], in: app, up: true)
            if retro { ReviewSettings.pickAppearance("System", in: app) }
            ReviewSettings.closeSettings(app)
        }
    }

    // MARK: - Sort Cards

    /// With Recently Edited First, pinned cards stay first; a card edited last comes first
    /// among the rest once every card is closed.
    @MainActor
    func testSortCardsKeepsPinnedCardsFirst() throws {
        let app = ReviewSettings.launch(["-isolatedData"])
        XCTAssertTrue(ReviewSettings.card("Study", in: app).waitForExistence(timeout: 8))
        app.buttons["Edit"].tap()
        XCTAssertTrue(app.buttons["Pin Study"].waitForExistence(timeout: 3))
        app.buttons["Pin Study"].tap()
        app.buttons["Done Editing"].tap()
        sleep(1)
        ReviewSettings.openSettings(app)
        let sort = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Sort Cards")).firstMatch
        ReviewSettings.scrollTo(sort, in: app)
        sort.tap()
        app.buttons["Recently Edited First"].tap()
        ReviewSettings.closeSettings(app)
        ReviewSettings.card("Appointments", in: app).tap()
        let field = app.addTaskField
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText("Dentist\n")
        app.buttons["Done"].firstMatch.tap()
        app.buttons["Close Appointments"].tap()
        sleep(2)
        ReviewSettings.shot("sort-1-recently-edited")
        let study = ReviewSettings.card("Study", in: app).frame
        let appointments = ReviewSettings.card("Appointments", in: app).frame
        func before(_ a: CGRect, _ b: CGRect) -> Bool { a.minY < b.minY - 1 || (abs(a.minY - b.minY) < 2 && a.minX < b.minX) }
        XCTAssertTrue(before(study, appointments), "pinned Study stays first")
        for other in ["Errands", "Work", "Fitness"] {
            XCTAssertTrue(before(appointments, ReviewSettings.card(other, in: app).frame), "Appointments, edited last, before \(other)")
        }
    }
}
