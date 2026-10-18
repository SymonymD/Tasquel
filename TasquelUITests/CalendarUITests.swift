import XCTest

/// End-to-end check of calendar events in the bottom bar, using the built-in test
/// calendar (`-fakeCalendar`) and throwaway app data (`-isolatedData`).
final class CalendarUITests: XCTestCase {
    @MainActor
    func testEventsInBottomBar() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-fakeCalendar", "-isolatedData"]
        app.launch()
        if app.staticTexts["Welcome to Tasquel"].waitForExistence(timeout: 3) {
            app.buttons["Next"].tap()
            app.buttons["Next"].tap()
            app.buttons["Continue"].tap()
            app.buttons["Skip"].tap()
            app.buttons["Let's Go!"].tap()
        }
        let settings = app.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Show events"].exists, "no calendar toggle until turned on in Settings")

        // Turn it on in Settings.
        settings.tap()
        let toggle = app.switches["Show Calendar Events"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 3))
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        let calendarsRow = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "selected")).firstMatch
        XCTAssertTrue(calendarsRow.waitForExistence(timeout: 3))
        XCTAssertTrue(calendarsRow.label.contains("2 selected"), "own calendars selected, Birthdays left out")
        app.buttons["Done"].firstMatch.tap()

        // Events live in the bottom bar, not the grid.
        let showEvents = app.buttons["Show events"]
        XCTAssertTrue(showEvents.waitForExistence(timeout: 3), "calendar toggle next to Settings")
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Events")).firstMatch.exists)
        let dentist = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Dentist")).firstMatch
        XCTAssertFalse(dentist.exists, "events hidden until the toggle is on")

        XCTAssertEqual(showEvents.value as? String, "Has events this week", "icon shows the week has events")
        showEvents.tap()
        XCTAssertTrue(dentist.waitForExistence(timeout: 3), "toggle reveals the week's events")
        XCTAssertTrue(app.staticTexts["3 events"].exists)
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Sam's Birthday")).firstMatch.exists)

        // The panel follows the viewed week.
        app.buttons["Next week"].tap()
        XCTAssertTrue(dentist.waitForExistence(timeout: 3))
        app.buttons["Previous week"].tap()

        app.buttons["Hide events"].tap()
        XCTAssertFalse(dentist.waitForExistence(timeout: 1), "toggle hides the events")

        // Swiping down on the events minimizes them; a short drag doesn't.
        app.buttons["Show events"].tap()
        XCTAssertTrue(dentist.waitForExistence(timeout: 3))
        let header = app.staticTexts["This Week's Events"]
        let start = header.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: 20)))
        XCTAssertTrue(dentist.waitForExistence(timeout: 1), "a short drag springs back")
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: 200)),
                    withVelocity: .fast, thenHoldForDuration: 0)
        XCTAssertFalse(dentist.waitForExistence(timeout: 2), "swiping down minimizes the events")
        XCTAssertTrue(app.buttons["Show events"].exists)

        // A short list can be dragged from an event too, without opening it in Calendar.
        app.buttons["Show events"].tap()
        XCTAssertTrue(dentist.waitForExistence(timeout: 3))
        let onEvent = dentist.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        onEvent.press(forDuration: 0.05, thenDragTo: onEvent.withOffset(CGVector(dx: 0, dy: 200)),
                      withVelocity: .fast, thenHoldForDuration: 0)
        XCTAssertFalse(dentist.waitForExistence(timeout: 2), "dragging from an event minimizes the events")
        XCTAssertEqual(app.state, .runningForeground, "the drag didn't open Calendar")

        // Turning the setting off removes the toggle.
        settings.tap()
        XCTAssertTrue(toggle.waitForExistence(timeout: 3))
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        app.buttons["Done"].firstMatch.tap()
        XCTAssertFalse(app.buttons["Show events"].waitForExistence(timeout: 1))
    }

    /// Regression: after relaunching, events didn't appear until the setting was
    /// toggled off and on in Settings (the calendar list wasn't loaded at launch).
    @MainActor
    func testEventsShowAfterRelaunch() throws {
        XCUIDevice.shared.orientation = .portrait
        let dataID = UUID().uuidString
        let app = XCUIApplication()
        app.launchArguments = ["-fakeCalendar", "-isolatedDataID", dataID]
        app.launch()
        if app.staticTexts["Welcome to Tasquel"].waitForExistence(timeout: 3) {
            app.buttons["Next"].tap()
            app.buttons["Next"].tap()
            app.buttons["Continue"].tap()
            app.buttons["Skip"].tap()
            app.buttons["Let's Go!"].tap()
        }
        app.buttons["Settings"].tap()
        let toggle = app.switches["Show Calendar Events"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 3))
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "selected")).firstMatch.waitForExistence(timeout: 3))
        app.buttons["Done"].firstMatch.tap()

        // Relaunch with the same data; don't open Settings.
        app.terminate()
        app.launch()
        let showEvents = app.buttons["Show events"]
        XCTAssertTrue(showEvents.waitForExistence(timeout: 5))
        let hasEvents = expectation(for: NSPredicate(format: "value == %@", "Has events this week"), evaluatedWith: showEvents)
        wait(for: [hasEvents], timeout: 5)
        showEvents.tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Dentist")).firstMatch.waitForExistence(timeout: 3),
                      "events show after relaunch without visiting Settings")
    }
}
