import XCTest

/// App Store screenshots. Steps through the screens with sample data (`-demoData`) and, at
/// each one, asks the host to take the picture with `xcrun simctl io <device> screenshot`
/// (so the status bar override shows): it writes the screenshot's name to `ready` in
/// `SHOT_DIR` and waits until the host removes it. Run by `scripts/app-store-screenshots.sh`,
/// which passes the folder as `TEST_RUNNER_SHOT_DIR`; skipped otherwise.
final class ScreenshotTests: XCTestCase {
    private var shotDirectory: URL?

    override func setUpWithError() throws {
        let path = ProcessInfo.processInfo.environment["SHOT_DIR"]
        try XCTSkipIf(path == nil, "only for scripts/app-store-screenshots.sh")
        shotDirectory = URL(fileURLWithPath: path!)
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    func testAppStoreScreenshots() throws {
        if UIDevice.current.userInterfaceIdiom == .pad { useFullScreenApps() }

        // 1. The week, cards closed.
        var app = launch()
        snap("01-week")

        // 2. Smart Add: a sentence becomes a repeating goal. (`-smartAddRules`: the same
        // rules Smart Add applies after the model, since a simulator has no model.)
        app = launch(extra: ["-smartAddRules", "-demoFirstCard", "Fitness"])
        open("Fitness", in: app)
        let field = app.addTaskField
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText("Swim 3 times a week")
        app.buttons["Smart Add"].tap()
        XCTAssertTrue(app.buttons["Undo Smart Add"].waitForExistence(timeout: 10))
        // With demo data the "Added …" message stays (it's gone after 4 seconds otherwise,
        // which a slow simulator missed).
        let keyboardDone = app.buttons["keyboard.chevron.compact.down"]
        if keyboardDone.exists { keyboardDone.tap() }
        XCTAssertTrue(app.buttons["Undo Smart Add"].exists)
        snap("02-smart-add")

        // 3. A card open: a list, sub-tasks and a goal.
        app = launch()
        open("Errands", in: app)
        snap("03-card-open")

        // 4. The type and mode picker, in Dark.
        app = launch(appearance: "dark")
        open("Errands", in: app)
        let options = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Task options:")).element(boundBy: 1)
        XCTAssertTrue(options.waitForExistence(timeout: 3))
        options.tap()
        XCTAssertTrue(app.buttons["Carry Over"].waitForExistence(timeout: 3))
        snap("04-type-and-mode")

        // 5. Dark: the week's calendar events (the week selector's calendar sheet) over an
        // open card of goals.
        app = launch(appearance: "dark", extra: ["-demoFirstCard", "Fitness"])
        open("Fitness", in: app)
        let showEvents = app.buttons["Calendar and events"]
        XCTAssertTrue(showEvents.waitForExistence(timeout: 5))
        showEvents.tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Dentist")).firstMatch
            .waitForExistence(timeout: 5))
        snap("05-calendar-events")

        // 6. Retro, with goals showing.
        app = launch(appearance: "retro")
        open("Fitness", in: app)
        snap("06-retro")

        // 7. Dark.
        app = launch(appearance: "dark")
        open("Work", in: app)
        snap("07-dark")
    }

    /// Seasonal, one 1.1 feature a season, each on a Wednesday of that season (holiday marks
    /// follow the demo's today; the season's colors come from `-demoSeason`). Spring and summer
    /// light, fall and winter dark: Seasonal follows the device's setting, which the host switches.
    @MainActor
    func testSeasonalScreenshots() throws {
        if UIDevice.current.userInterfaceIdiom == .pad { useFullScreenApps() }
        let seasonal = ["-demoDaysAndPins", "-demoSeason"]

        // 8. Spring: days for tasks ("Today", "Tue · late", the day strip's dates).
        systemAppearance("light")
        var app = launch(appearance: "seasonal", today: "2026-04-15", extra: seasonal + ["spring"])
        open("Appointments", in: app)
        snap("08-spring-days")

        // 9. Summer: a task's date, in its calendar.
        app = launch(appearance: "seasonal", today: "2026-07-15", extra: seasonal + ["summer"])
        open("Errands", in: app)
        optionsButton(for: "Plan Mom's birthday", in: app).tap()
        let date = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Date:")).firstMatch
        XCTAssertTrue(date.waitForExistence(timeout: 3))
        date.tap()
        XCTAssertTrue(app.buttons["Set"].waitForExistence(timeout: 3))
        snap("09-summer-dates")

        // 10. Fall, in Thanksgiving week (the feathered mark): pinned cards and their rings.
        systemAppearance("dark")
        app = launch(appearance: "seasonal", today: "2026-11-25", extra: seasonal + ["fall"])
        snap("10-fall-pins")

        // 11. Winter, under the holiday lights: Smart Add reads a date and offers to set it.
        app = launch(appearance: "seasonal", today: "2026-12-16", extra: seasonal + ["winter", "-smartAddRules"])
        open("Appointments", in: app)
        let field = app.addTaskField
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText("Dentist December 18")
        app.buttons["Smart Add"].tap()
        XCTAssertTrue(app.buttons["Undo Smart Add"].waitForExistence(timeout: 10))
        let keyboardDone = app.buttons["keyboard.chevron.compact.down"]
        if keyboardDone.exists { keyboardDone.tap() }
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Set date to")).firstMatch
            .waitForExistence(timeout: 3))
        snap("11-winter-smart-add")

        systemAppearance("light")
    }

    // MARK: Helpers

    /// The type/mode button on the row showing `title` (each row's reads "Task options: …").
    @MainActor
    private func optionsButton(for title: String, in app: XCUIApplication) -> XCUIElement {
        let name = app.staticTexts[title].firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        let buttons = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Task options:")).allElementsBoundByIndex
        let row = name.frame.midY
        return buttons.min { abs($0.frame.midY - row) < abs($1.frame.midY - row) } ?? buttons[0]
    }

    /// Has the host switch the simulator to light or dark (`xcrun simctl ui … appearance`).
    private func systemAppearance(_ style: String) {
        let request = shotDirectory!.appending(path: "appearance")
        try? style.write(to: request, atomically: true, encoding: .utf8)
        let deadline = Date().addingTimeInterval(30)
        while FileManager.default.fileExists(atPath: request.path), Date() < deadline {
            Thread.sleep(forTimeInterval: 0.2)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: request.path), "the host didn't switch to \(style)")
        Thread.sleep(forTimeInterval: 1)
    }

    /// iPadOS 26 windowed apps show a resize handle in the corner; full-screen apps don't.
    /// Settings ▸ Multitasking & Gestures ▸ Full Screen Apps.
    @MainActor
    private func useFullScreenApps() {
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        settings.launch()
        let multitasking = settings.staticTexts["Multitasking & Gestures"]
        for _ in 0..<6 where !multitasking.waitForExistence(timeout: 1) || !multitasking.isHittable {
            settings.tables.firstMatch.exists ? settings.tables.firstMatch.swipeUp() : settings.collectionViews.firstMatch.swipeUp()
        }
        guard multitasking.exists else {
            print(settings.debugDescription)
            return XCTFail("Multitasking & Gestures not found")
        }
        multitasking.tap()
        let fullScreen = settings.staticTexts["Full Screen Apps"]
        guard fullScreen.waitForExistence(timeout: 3) else {
            print(settings.debugDescription)
            return XCTFail("Full Screen Apps not found")
        }
        fullScreen.tap()
        Thread.sleep(forTimeInterval: 1)
        settings.terminate()
    }

    @MainActor
    private func launch(appearance: String = "light", today day: String? = nil, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        // DEMO_TODAY (from the script): the day the demo week treats as today, unless given.
        let today = (day ?? ProcessInfo.processInfo.environment["DEMO_TODAY"]).map { ["-demoToday", $0] } ?? []
        app.launchArguments = ["-demoData", "-fakeCalendar", "-demoAppearance", appearance] + today + extra
        app.launch()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Errands,")).firstMatch
            .waitForExistence(timeout: 10))
        return app
    }

    @MainActor
    private func open(_ category: String, in app: XCUIApplication) {
        let card = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open \(category),")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.tap()
        XCTAssertTrue(app.buttons["Edit \(category)"].waitForExistence(timeout: 3))
    }

    /// Lets animations settle, then has the host take the screenshot.
    private func snap(_ name: String) {
        Thread.sleep(forTimeInterval: 1.5)
        let ready = shotDirectory!.appending(path: "ready")
        try? name.write(to: ready, atomically: true, encoding: .utf8)
        let deadline = Date().addingTimeInterval(30)
        while FileManager.default.fileExists(atPath: ready.path), Date() < deadline {
            Thread.sleep(forTimeInterval: 0.2)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: ready.path), "the host didn't take \(name)")
    }
}
