import XCTest

/// The keyboard's room after rotating, and the bottom bar's margin on a phone with a Home
/// button (2026-11-10 review findings 11 and 16). Escape (finding 21) is in the unit tests
/// (`EscapeKeyTests`): a UI test's Escape types on the on-screen keyboard, which has none,
/// so it never reaches the app.
final class KeyboardUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchDemo() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-demoData", "-demoFirstCard", "Errands"]
        app.launch()
        return app
    }

    private func openErrands(_ app: XCUIApplication) {
        let errands = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Errands,")).firstMatch
        XCTAssertTrue(errands.waitForExistence(timeout: 5))
        errands.tap()
        Thread.sleep(forTimeInterval: 1)
    }

    /// On iPad, the Add task field being typed in is scrolled back above the keyboard
    /// after rotating; what was typed stays.
    @MainActor
    func testRotatingWhileTypingKeepsFieldAboveKeyboard() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "iPad only")
        XCUIDevice.shared.orientation = .portrait
        let app = launchDemo()
        openErrands(app)
        let field = app.openAddTaskField()
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.typeText("Rotate me")
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        Thread.sleep(forTimeInterval: 3)
        let keyboard = app.keyboards.firstMatch
        XCTAssertEqual(field.value as? String, "Rotate me", "the words are kept")
        if keyboard.exists {
            XCTAssertLessThanOrEqual(field.frame.maxY, keyboard.frame.minY + 1, "the field is above the keyboard")
        }
    }

    /// The bottom bar's buttons keep a margin above the screen's edge, also where there's
    /// no home indicator (iPhone SE).
    @MainActor
    func testBottomBarClearsBottomEdge() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-isolatedData"]
        app.launch()
        if app.staticTexts["Welcome to Tasquel"].waitForExistence(timeout: 3) { app.buttons["Skip"].tap() }
        let settings = app.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1)
        let window = app.windows.firstMatch.frame
        for button in [settings, app.buttons["Go to week"], app.buttons["Edit"]] {
            XCTAssertLessThanOrEqual(button.frame.maxY, window.maxY - 7.5, "\(button.label) keeps a margin above the bottom edge")
        }
    }
}
