import XCTest

/// Switches this simulator's multitasking mode, and checks the header against the iPadOS 26
/// window controls. (Classes sort by name: Setup runs before ReviewIPadTests.)
final class ReviewIPadSetupTests: ReviewIPadBase {
    @MainActor func testA_UseFullScreenApps() { reviewSetWindowedApps(false) }

    /// In a window (Windowed Apps), the window's controls (the three dots at its top left)
    /// must not sit on the Tasquel mark ("This Week"), the header's back-to-this-week button.
    @MainActor
    func testWindowControlsLeaveTheTasquelMarkClear() throws {
        reviewSetWindowedApps(true)
        defer { reviewSetWindowedApps(false) }
        launch(["-demoData"], orientation: .landscapeLeft)
        // A window smaller than the screen (window sizes are remembered, so from its frame).
        let start = windowFrame
        let origin = XCUIApplication(bundleIdentifier: "com.apple.springboard").coordinate(withNormalizedOffset: .zero)
        origin.withOffset(CGVector(dx: start.maxX - 6, dy: start.maxY - 6))
            .press(forDuration: 0.6, thenDragTo: origin.withOffset(CGVector(dx: start.minX + 800, dy: start.minY + 800)),
                   withVelocity: .slow, thenHoldForDuration: 0.3)
        Thread.sleep(forTimeInterval: 2.5)
        let mark = app.buttons["This Week"].firstMatch
        XCTAssertTrue(mark.waitForExistence(timeout: 3))
        let window = windowFrame
        shot("window-controls-vs-mark")
        log("window \(window) mark \(mark.frame) screen-sized \(window.width == 1376 && window.height == 1032)")
        // The controls take about the window's first 70pt across and 44pt down.
        if window.width < 1376 || window.height < 1032 {
            let controls = CGRect(x: window.minX, y: window.minY, width: 72, height: 50)
            XCTAssertFalse(controls.intersects(mark.frame), "the window controls cover the Tasquel mark: \(mark.frame)")
        }
    }
}
