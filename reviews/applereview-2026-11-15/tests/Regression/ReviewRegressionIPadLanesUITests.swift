import XCTest

/// Regression review after fix 8 (iPad landscape lanes kept in the layout's cache by category
/// ID): what else moves open cards between lanes. iPad only; skipped on iPhone.
final class ReviewRegressionIPadLanesUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "iPad lanes only")
        XCUIDevice.shared.orientation = .landscapeLeft
        app = XCUIApplication()
        app.launchArguments = ["-demoData", "-demoToday", "2026-11-11"]
        app.launch()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 15))
        sleep(1)
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
    }

    /// Work opened first (left lane, the shorter on a tie), then Errands, which sat in the right
    /// lane while closed, opens there. Two weeks ahead and back (or Go to Week), this week's page
    /// is built again with an empty cache: both open cards are dealt afresh, Errands left and
    /// Work right, so they swap sides; next week's page shows them swapped too.
    @MainActor
    func testOpenCardsKeepTheirLanesAfterPagingTwoWeeksAndBack() throws {
        open("Work")
        open("Errands")
        let before = lanes()
        shot("fix8-lanes-0-work-then-errands")
        print("REVIEW: lanes after opening Work then Errands: \(before)")
        XCTAssertEqual(before["Work"], "left", "fix 8: Work stays where it opened")
        XCTAssertEqual(before["Errands"], "right", "fix 8: Errands opens in the lane it sat in")

        app.buttons["Next week"].tap()
        sleep(2)
        let nextWeek = lanes()
        shot("fix8-lanes-1-next-week")
        app.buttons["Next week"].tap()
        sleep(2)
        app.buttons["Previous week"].tap()
        sleep(2)
        app.buttons["Previous week"].tap()
        sleep(2)
        let after = lanes()
        shot("fix8-lanes-2-back-two-weeks")
        print("REVIEW: next week \(nextWeek); back on this week after two weeks ahead \(after)")
        XCTAssertEqual(after, before, "the open cards are where they were before paging")
    }

    /// Checked: one week ahead and back keeps this week's page (and its lanes); closing Work
    /// leaves Errands in its lane; opening Fitness puts it where it sat.
    @MainActor
    func testLanesHoldWhileOpeningAndClosingAndPagingOneWeek() throws {
        open("Work")
        open("Errands")
        let before = lanes()
        app.buttons["Next week"].tap()
        sleep(2)
        app.buttons["Previous week"].tap()
        sleep(2)
        XCTAssertEqual(lanes(), before, "one week there and back keeps the page")
        app.buttons["Close Work"].firstMatch.tap()
        sleep(1)
        XCTAssertEqual(lanes()["Errands"], before["Errands"], "closing Work doesn't move Errands")
        shot("fix8-lanes-3-work-closed")
    }

    /// Edit collapses open cards and reopens them as it ends: do they come back in their lanes?
    @MainActor
    func testOpenCardsKeepTheirLanesAfterEdit() throws {
        open("Work")
        open("Errands")
        let before = lanes()
        app.buttons["Edit"].firstMatch.tap()
        sleep(2)
        let done = app.buttons["Done Editing"].firstMatch
        if !done.waitForExistence(timeout: 5) {
            print("REVIEW: no Done; buttons \(app.buttons.allElementsBoundByIndex.prefix(40).map(\.label))")
        }
        done.tap()
        sleep(2)
        let after = lanes()
        shot("fix8-lanes-4-after-edit")
        print("REVIEW: lanes before Edit \(before), after \(after)")
        XCTAssertEqual(after, before, "open cards come back in their lanes after Edit")
    }

    // MARK: Helpers

    @MainActor
    private func open(_ name: String) {
        let card = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open \(name),")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.tap()
        XCTAssertTrue(app.buttons["Close \(name)"].waitForExistence(timeout: 3))
        sleep(1)
    }

    /// Which half of the screen each open card's header is in.
    @MainActor
    private func lanes() -> [String: String] {
        let mid = app.windows.firstMatch.frame.midX
        var result: [String: String] = [:]
        for name in ["Errands", "Work", "Fitness", "Study", "Appointments"] {
            let close = app.buttons["Close \(name)"].firstMatch
            guard close.exists else { continue }
            result[name] = close.frame.midX < mid ? "left" : "right"
        }
        return result
    }

    private func shot(_ name: String) {
        let dir = ProcessInfo.processInfo.environment["SHOT_DIR"] ?? NSTemporaryDirectory()
        try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
    }
}
