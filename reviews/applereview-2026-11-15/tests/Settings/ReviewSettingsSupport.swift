import XCTest

/// Shared helpers for the 2026-11-15 Settings and themes review (ReviewSettings*.swift).
enum ReviewSettings {
    static var shotDir: String { ProcessInfo.processInfo.environment["SHOT_DIR"] ?? NSTemporaryDirectory() }

    /// Saves a screenshot into the shots folder.
    static func shot(_ name: String) {
        Thread.sleep(forTimeInterval: 0.7)
        let data = XCUIScreen.main.screenshot().pngRepresentation
        try? data.write(to: URL(fileURLWithPath: "\(shotDir)/\(name).png"))
    }

    /// Launches with `arguments`, tapping through onboarding when it shows.
    @MainActor
    static func launch(_ arguments: [String]) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
        skipOnboarding(app)
        return app
    }

    @MainActor
    static func skipOnboarding(_ app: XCUIApplication) {
        if app.staticTexts["Welcome to Tasquel"].waitForExistence(timeout: 3) {
            if app.buttons["Skip"].exists { app.buttons["Skip"].tap(); return }
            for _ in 0..<4 { app.buttons["Next"].tap() }
            app.buttons["Let's Go!"].tap()
        }
    }

    @MainActor
    static func openSettings(_ app: XCUIApplication) {
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 5))
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.buttons["System"].waitForExistence(timeout: 5), "Settings is open")
    }

    @MainActor
    static func closeSettings(_ app: XCUIApplication) {
        app.navigationBars.buttons["Done"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.5)
    }

    /// Scrolls Settings (a List, or Retro's ScrollView) until `element` can be tapped.
    @MainActor
    static func scrollTo(_ element: XCUIElement, in app: XCUIApplication, up: Bool = false) {
        let list: XCUIElement? = app.collectionViews.firstMatch.exists ? app.collectionViews.firstMatch : nil
        for _ in 0..<10 where !(element.exists && element.isHittable) {
            if let list {
                if up { list.swipeDown(velocity: .slow) } else { list.swipeUp(velocity: .slow) }
            } else {
                let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: up ? 0.35 : 0.7))
                let to = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: up ? 0.7 : 0.35))
                from.press(forDuration: 0.05, thenDragTo: to)
            }
        }
        Thread.sleep(forTimeInterval: 0.5)
    }

    /// Picks an appearance in Settings (Settings is open).
    @MainActor
    static func pickAppearance(_ label: String, in app: XCUIApplication) {
        let button = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", label)).firstMatch
        scrollTo(button, in: app, up: true)
        button.tap()
        Thread.sleep(forTimeInterval: 0.8)
    }

    @MainActor
    static func card(_ name: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open \(name),")).firstMatch
    }

    /// How light the screen is at a point (0–1), from a screenshot.
    static func brightness(atX fx: Double, y fy: Double) -> CGFloat {
        let image = XCUIScreen.main.screenshot().image
        guard let cg = image.cgImage else { return -1 }
        let x = Int(Double(cg.width) * fx), y = Int(Double(cg.height) * fy)
        guard let data = cg.dataProvider?.data, let bytes = CFDataGetBytePtr(data) else { return -1 }
        let offset = y * cg.bytesPerRow + x * (cg.bitsPerPixel / 8)
        let r = CGFloat(bytes[offset]), g = CGFloat(bytes[offset + 1]), b = CGFloat(bytes[offset + 2])
        return (r + g + b) / (3 * 255)
    }
}
