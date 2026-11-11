import XCTest

/// Shared helpers for the Settings and themes review tests (ReviewSettings*.swift).
class ReviewSettingsBase: XCTestCase {
    var app: XCUIApplication!
    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    var shotDir: String { ProcessInfo.processInfo.environment["SHOT_DIR"] ?? NSTemporaryDirectory() }

    @MainActor
    override func setUp() {
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
    }

    /// Demo data (Errands first, with the Groceries list), no onboarding.
    @MainActor
    @discardableResult
    func launchDemo(_ extra: [String] = []) -> XCUIApplication {
        app = XCUIApplication()
        app.launchArguments = ["-demoData", "-demoFirstCard", "Errands", "-fakeCalendar"] + extra
        app.launch()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 8))
        dismissIconAlert()
        return app
    }

    /// Throwaway storage kept across launches under `id`; skips onboarding.
    @MainActor
    @discardableResult
    func launchIsolated(_ id: String, _ extra: [String] = []) -> XCUIApplication {
        app = XCUIApplication()
        app.launchArguments = ["-isolatedDataID", id, "-fakeCalendar"] + extra
        app.launch()
        if app.staticTexts["Welcome to Tasquel"].waitForExistence(timeout: 3) { app.buttons["Skip"].tap() }
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 8))
        dismissIconAlert()
        return app
    }

    @MainActor
    func relaunch() {
        app.terminate()
        app.launch()
        if app.staticTexts["Welcome to Tasquel"].waitForExistence(timeout: 2) { app.buttons["Skip"].tap() }
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 8))
    }

    /// iOS's own "You have changed the icon" alert, if it's up. Returns whether it was.
    @MainActor
    @discardableResult
    func dismissIconAlert(timeout: TimeInterval = 0.5) -> Bool {
        let alert = springboard.alerts.firstMatch
        guard alert.waitForExistence(timeout: timeout) else { return false }
        print("REVIEW: springboard alert: \(alert.label)")
        let ok = alert.buttons["OK"]
        if ok.exists { ok.tap() } else { alert.buttons.firstMatch.tap() }
        _ = alert.waitForNonExistence(timeout: 3)
        return true
    }

    @MainActor
    func shot(_ name: String, settle: TimeInterval = 0.8) {
        Thread.sleep(forTimeInterval: settle)
        let screenshot = XCUIScreen.main.screenshot()
        try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: "\(shotDir)/\(name).png"))
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func card(_ name: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open \(name),")).firstMatch
    }

    @MainActor
    func openCard(_ name: String) {
        let c = card(name)
        XCTAssertTrue(c.waitForExistence(timeout: 5), "\(name) card exists")
        c.tap()
        _ = app.buttons["Close \(name)"].waitForExistence(timeout: 3)
    }

    @MainActor
    func openSettings() {
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.buttons["System"].waitForExistence(timeout: 4), "Settings opened")
    }

    @MainActor
    func closeSettings() {
        let done = app.navigationBars.buttons["Done"].firstMatch
        if done.exists { done.tap() } else { app.buttons["Done"].firstMatch.tap() }
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 4), "Settings closed")
    }

    /// Settings ▸ Appearance: picks `mode` (System, Light, Dark, Retro) and, in Retro, `color`.
    @MainActor
    func chooseTheme(_ mode: String, color: String? = nil, shotName: String? = nil) {
        openSettings()
        app.buttons[mode].firstMatch.tap()
        dismissIconAlert(timeout: 2)
        if let color {
            let swatch = app.buttons[color].firstMatch
            XCTAssertTrue(swatch.waitForExistence(timeout: 3), "\(color) swatch")
            swatch.tap()
        }
        if let shotName { shot(shotName) }
        closeSettings()
    }

    /// Prints the contrast audit's findings (doesn't fail the test).
    @MainActor
    func auditContrast(_ context: String) {
        do {
            try app.performAccessibilityAudit(for: [.contrast]) { issue in
                print("REVIEW: audit[\(context)] \(issue.auditType) \(issue.compactDescription) [\(issue.element?.label ?? "-")]")
                return true
            }
        } catch {
            print("REVIEW: audit[\(context)] failed \(error)")
        }
    }

    /// The reorder handle of a task in its card's edit mode: just right of its delete button.
    @MainActor
    func handle(of task: String) -> XCUICoordinate {
        app.buttons["Delete \(task)"].coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5))
            .withOffset(CGVector(dx: 12, dy: 0))
    }
}
