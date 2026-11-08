import XCTest

/// End-to-end check of the calendar sheet (the week selector's calendar button): the week
/// picker, and with calendar events on the viewed week's events, using the built-in test
/// calendar (`-fakeCalendar`) and throwaway app data (`-isolatedData`).
final class CalendarUITests: XCTestCase {
    /// With events on, the sheet opens on them; Weeks shows months where the viewed week is
    /// picked, a tap on another week picks all of it, and Go goes there. With events off the
    /// same button is just Go to Week.
    @MainActor
    func testWeekPicker() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-demoData", "-fakeCalendar"]
        app.launch()
        let calendar = app.buttons["Calendar and events"]
        XCTAssertTrue(calendar.waitForExistence(timeout: 10))
        let title = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Week of")).firstMatch
        let thisWeek = title.label
        calendar.tap()
        XCTAssertTrue(app.staticTexts["This Week's Events"].waitForExistence(timeout: 3), "opens on the events")
        app.buttons["Weeks"].tap()
        let weeks = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Week of"))
        XCTAssertTrue(weeks.firstMatch.waitForExistence(timeout: 3))
        let picked = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@ AND selected == true", "Week of"))
        XCTAssertEqual(picked.count, 1, "the viewed week is picked, as one row")
        let rows = weeks.allElementsBoundByIndex
        let index = try XCTUnwrap(rows.firstIndex { $0.isSelected })
        let next = rows[index + 1]
        next.tap()
        XCTAssertTrue(next.isSelected, "a tap picks the whole week")
        XCTAssertEqual(picked.count, 1)
        app.buttons["Go"].tap()
        XCTAssertTrue(app.staticTexts["This Week's Events"].waitForNonExistence(timeout: 3))
        XCTAssertNotEqual(title.label, thisWeek, "went to the picked week")

        // Earlier adds the month before the first one shown, at the top.
        app.buttons["Calendar and events"].tap()
        app.buttons["Weeks"].tap()
        let firstMonth = app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "^[A-Z][a-z]+ [0-9]{4}$")).firstMatch
        XCTAssertTrue(firstMonth.waitForExistence(timeout: 3))
        let opening = firstMonth.label
        app.buttons["Show earlier month"].tap()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "LLLL yyyy"
        let monthBefore = try XCTUnwrap(formatter.date(from: opening).flatMap { Calendar.current.date(byAdding: .month, value: -1, to: $0) })
        XCTAssertTrue(app.staticTexts[formatter.string(from: monthBefore)].waitForExistence(timeout: 3), "the month before \(opening)")
        app.buttons["Cancel"].tap()

        let plain = XCUIApplication()
        plain.launchArguments = ["-isolatedData"]
        plain.launch()
        if plain.staticTexts["Welcome to Tasquel"].waitForExistence(timeout: 3) { plain.buttons["Skip"].tap() }
        let goToWeek = plain.buttons["Go to week"]
        XCTAssertTrue(goToWeek.waitForExistence(timeout: 5), "without events, just the week picker")
        goToWeek.tap()
        XCTAssertTrue(plain.navigationBars["Go to Week"].waitForExistence(timeout: 3))
        XCTAssertFalse(plain.buttons["Events"].exists)
    }

    /// On another week the calendar sheet has This Week (at its top left): on Events it
    /// brings the cards and events back to this week and stays open; on Weeks it goes there
    /// and closes. On this week it isn't there.
    @MainActor
    func testThisWeekButton() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-demoData", "-fakeCalendar"]
        app.launch()
        let calendar = app.buttons["Calendar and events"]
        XCTAssertTrue(calendar.waitForExistence(timeout: 10))
        let title = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Week of")).firstMatch
        let thisWeek = title.label
        // In the sheet's bar (the Tasquel mark behind it is "This Week" to VoiceOver too).
        let backToThisWeek = app.navigationBars.buttons["This Week"]

        calendar.tap()
        XCTAssertTrue(app.staticTexts["This Week's Events"].waitForExistence(timeout: 3))
        XCTAssertFalse(backToThisWeek.exists, "not while on this week")
        app.buttons["Done"].firstMatch.tap()

        // Events: back to this week, the sheet stays.
        app.buttons["Next week"].tap()
        XCTAssertTrue(waitForLabel(of: title, toDifferFrom: thisWeek))
        calendar.tap()
        XCTAssertTrue(backToThisWeek.waitForExistence(timeout: 3), "on another week")
        backToThisWeek.tap()
        XCTAssertTrue(app.staticTexts["This Week's Events"].waitForExistence(timeout: 3), "this week's events, still in the sheet")
        XCTAssertTrue(backToThisWeek.waitForNonExistence(timeout: 3))
        app.buttons["Done"].firstMatch.tap()
        XCTAssertEqual(title.label, thisWeek, "the cards came back too")

        // Weeks: back to this week, and the sheet closes.
        app.buttons["Previous week"].tap()
        XCTAssertTrue(waitForLabel(of: title, toDifferFrom: thisWeek))
        calendar.tap()
        app.buttons["Weeks"].tap()
        XCTAssertTrue(app.buttons["Go"].waitForExistence(timeout: 3), "Go and Cancel are at the bottom")
        XCTAssertTrue(app.buttons["Cancel"].exists)
        backToThisWeek.tap()
        XCTAssertTrue(app.buttons["Weeks"].waitForNonExistence(timeout: 3), "the sheet closed")
        XCTAssertEqual(title.label, thisWeek)
    }

    @MainActor
    private func waitForLabel(of element: XCUIElement, toDifferFrom label: String) -> Bool {
        let changed = expectation(for: NSPredicate(format: "label != %@", label), evaluatedWith: element)
        return XCTWaiter.wait(for: [changed], timeout: 3) == .completed
    }

    /// Turning calendar events on in Settings turns the calendar button green with a person
    /// and gives its sheet the viewed week's events; turning them off again goes back.
    @MainActor
    func testEventsInCalendarSheet() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-fakeCalendar", "-isolatedData"]
        app.launch()
        if app.staticTexts["Welcome to Tasquel"].waitForExistence(timeout: 3) {
            app.buttons["Next"].tap()
            app.buttons["Next"].tap()
            app.buttons["Next"].tap()
            app.buttons["Next"].tap()
            app.buttons["Let's Go!"].tap()
        }
        let settings = app.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Go to week"].exists)
        XCTAssertFalse(app.buttons["Calendar and events"].exists, "no events until turned on in Settings")

        // Turn it on in Settings.
        settings.tap()
        let toggle = calendarToggle(in: app)
        XCTAssertTrue(toggle.exists)
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        let calendarsRow = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "selected")).firstMatch
        XCTAssertTrue(calendarsRow.waitForExistence(timeout: 3))
        XCTAssertTrue(calendarsRow.label.contains("2 selected"), "own calendars selected, Birthdays left out")
        app.buttons["Done"].firstMatch.tap()

        // Events live in the calendar sheet, not the grid.
        let calendar = app.buttons["Calendar and events"]
        XCTAssertTrue(calendar.waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Events")).firstMatch.exists)
        let dentist = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Dentist")).firstMatch
        XCTAssertFalse(dentist.exists)
        calendar.tap()
        XCTAssertTrue(dentist.waitForExistence(timeout: 3), "the sheet opens on the week's events")
        XCTAssertTrue(app.staticTexts["3 events"].exists)
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Sam's Birthday")).firstMatch.exists)
        app.buttons["Done"].tap()
        XCTAssertTrue(dentist.waitForNonExistence(timeout: 3))

        // The events follow the viewed week.
        app.buttons["Next week"].tap()
        calendar.tap()
        XCTAssertTrue(dentist.waitForExistence(timeout: 3))
        app.buttons["Done"].tap()
        app.buttons["Previous week"].tap()

        // Turning the setting off: just the week picker again.
        settings.tap()
        XCTAssertTrue(calendarToggle(in: app).exists)
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        app.buttons["Done"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Go to week"].waitForExistence(timeout: 3))
        XCTAssertFalse(calendar.exists)
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
            app.buttons["Next"].tap()
            app.buttons["Next"].tap()
            app.buttons["Let's Go!"].tap()
        }
        app.buttons["Settings"].tap()
        let toggle = calendarToggle(in: app)
        XCTAssertTrue(toggle.exists)
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "selected")).firstMatch.waitForExistence(timeout: 3))
        app.buttons["Done"].firstMatch.tap()

        // Relaunch with the same data; don't open Settings.
        app.terminate()
        app.launch()
        let calendar = app.buttons["Calendar and events"]
        XCTAssertTrue(calendar.waitForExistence(timeout: 5))
        calendar.tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Dentist")).firstMatch.waitForExistence(timeout: 3),
                      "events show after relaunch without visiting Settings")
    }

    /// A sideways swipe on the events goes to the next or previous week, even one that starts
    /// on an event, which doesn't open Calendar.
    @MainActor
    func testSwipeChangesEventsWeek() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-demoData", "-fakeCalendar", "-demoAppearance", "light"]
        app.launch()
        let calendar = app.buttons["Calendar and events"]
        XCTAssertTrue(calendar.waitForExistence(timeout: 10))
        calendar.tap()
        XCTAssertTrue(app.staticTexts["This Week's Events"].waitForExistence(timeout: 3))
        let standup = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Team Standup")).firstMatch
        XCTAssertTrue(standup.waitForExistence(timeout: 5))
        sleep(1)
        let onEvent = standup.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5))
        onEvent.press(forDuration: 0.05, thenDragTo: onEvent.withOffset(CGVector(dx: -250, dy: 0)))
        let nextWeek = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Events, Week of")).firstMatch
        XCTAssertTrue(nextWeek.waitForExistence(timeout: 3), "on to next week's events")
        XCTAssertEqual(app.state, .runningForeground, "the swipe didn't open Calendar")

        let list = app.staticTexts["Events, Week of"].exists ? app.staticTexts["Events, Week of"] : nextWeek
        let start = list.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5)).withOffset(CGVector(dx: 0, dy: 60))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 250, dy: 0)))
        XCTAssertTrue(app.staticTexts["This Week's Events"].waitForExistence(timeout: 3), "and back")
        XCTAssertEqual(app.state, .runningForeground)
    }

    /// A swipe up that starts on an event scrolls (or grows the sheet) rather than opening
    /// Calendar, and the week's last event can be reached.
    @MainActor
    func testEventsListScrolls() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-demoData", "-fakeCalendar", "-demoAppearance", "light"]
        app.launch()
        let calendar = app.buttons["Calendar and events"]
        XCTAssertTrue(calendar.waitForExistence(timeout: 10))
        calendar.tap()
        let standup = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Team Standup")).firstMatch
        let market = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Farmers Market")).firstMatch
        XCTAssertTrue(standup.waitForExistence(timeout: 5))
        sleep(1)
        let start = standup.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -150)), withVelocity: .default, thenHoldForDuration: 0.1)
        sleep(1)
        XCTAssertEqual(app.state, .runningForeground, "the swipe didn't open Calendar")
        XCTAssertTrue(market.isHittable, "the last event is in view")
    }

    /// Settings ▸ Calendar is a few rows down; a List only builds rows on screen.
    @MainActor
    private func calendarToggle(in app: XCUIApplication) -> XCUIElement {
        let toggle = app.switches["Show Calendar Events"]
        for _ in 0..<4 where !toggle.waitForExistence(timeout: 2) || !toggle.isHittable {
            app.collectionViews.firstMatch.swipeUp(velocity: .slow)
        }
        return toggle
    }
}
