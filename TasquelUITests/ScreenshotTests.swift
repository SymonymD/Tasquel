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

        // 2. A card open: a list, sub-tasks and a goal.
        open("Errands", in: app)
        snap("02-card-open")

        // 3. The type and mode picker.
        let options = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Task options:")).element(boundBy: 1)
        XCTAssertTrue(options.waitForExistence(timeout: 3))
        options.tap()
        XCTAssertTrue(app.buttons["Carry Over"].waitForExistence(timeout: 3))
        snap("03-type-and-mode")

        // 4. The week's calendar events in the bottom bar.
        app = launch()
        let showEvents = app.buttons["Show events"]
        XCTAssertTrue(showEvents.waitForExistence(timeout: 5))
        showEvents.tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Dentist")).firstMatch
            .waitForExistence(timeout: 5))
        snap("04-calendar-events")

        // 5. Retro, with goals showing.
        app = launch(appearance: "retro")
        open("Fitness", in: app)
        snap("05-retro")

        // 6. Dark.
        app = launch(appearance: "dark")
        open("Work", in: app)
        snap("06-dark")
    }

    // MARK: Helpers

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
    private func launch(appearance: String = "light") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-demoData", "-fakeCalendar", "-demoAppearance", appearance]
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
