import XCTest

/// The bottom bar and what's placed by its height (the Undo message, the grid's bottom
/// padding) after something under a sheet changed the bar.
final class BottomBarUITests: XCTestCase {
    /// Turning calendar events on and off in Settings, under a sheet, changes the bar's
    /// calendar button. The Undo message afterwards sits just above the bar, as before.
    @MainActor
    func testUndoMessageFollowsBarAfterSettingsChange() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-isolatedData", "-fakeCalendar"]
        app.launch()
        if app.staticTexts["Welcome to Tasquel"].waitForExistence(timeout: 3) { app.buttons["Skip"].tap() }
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 5))

        // Both tasks first: typing shows the keyboard, which hides the bar and measures it
        // afresh, and the deletes below must happen without it.
        addTasks(["Milk", "Eggs"], in: app)
        let before = undoGap(in: app, task: "Milk")

        setCalendarEvents(in: app)  // on
        XCTAssertTrue(app.buttons["Calendar and events"].waitForExistence(timeout: 3))
        setCalendarEvents(in: app)  // off
        XCTAssertTrue(app.buttons["Go to week"].waitForExistence(timeout: 3))

        let after = undoGap(in: app, task: "Eggs")
        print("REVIEW gap before=\(before) after=\(after)")
        XCTAssertEqual(after, before, accuracy: 2, "the Undo message sits just above the bar again")
    }

    // MARK: Helpers

    /// Adds `task` to Errands, deletes it, and returns the space between the "Deleted …"
    /// message and the Settings button below it.
    @MainActor
    private func addTasks(_ tasks: [String], in app: XCUIApplication) {
        let errands = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Errands,")).firstMatch
        XCTAssertTrue(errands.waitForExistence(timeout: 3))
        errands.tap()
        let field = app.addTaskField
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        for task in tasks { field.typeText(task + "\n") }
        app.buttons["Done"].firstMatch.tap()  // the keyboard's Done
        sleep(1)
    }

    @MainActor
    private func undoGap(in app: XCUIApplication, task: String) -> CGFloat {
        let errands = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Errands,")).firstMatch
        if errands.exists { errands.tap() }
        let edit = app.buttons["Edit Errands"]
        XCTAssertTrue(edit.waitForExistence(timeout: 3))
        edit.tap()
        app.buttons["Delete \(task)"].tap()
        let message = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Deleted")).firstMatch
        XCTAssertTrue(message.waitForExistence(timeout: 3))
        sleep(1)
        let gap = app.buttons["Settings"].frame.minY - message.frame.maxY
        // Deleting the card's only task ends its editing by itself.
        let doneEditing = app.buttons["Done editing Errands"]
        if doneEditing.exists { doneEditing.tap() }
        XCTAssertTrue(message.waitForNonExistence(timeout: 8))
        return gap
    }

    /// Flips Settings ▸ Calendar ▸ Show Calendar Events and closes Settings.
    @MainActor
    private func setCalendarEvents(in app: XCUIApplication) {
        app.buttons["Settings"].tap()
        let toggle = app.switches["Show Calendar Events"]
        for _ in 0..<5 where !toggle.waitForExistence(timeout: 1) || !toggle.isHittable {
            app.collectionViews.firstMatch.swipeUp(velocity: .slow)
        }
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        sleep(1)
        app.buttons["Done"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 3))
        sleep(1)
    }
}
