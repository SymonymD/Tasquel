import XCTest

/// Review 2026-11-15 (Edge cases): time zones, travel and week boundaries with the new days
/// and dates. Each test starts from a clean launch with its own `-isolatedDataID`.
final class ReviewEdgeTimeZoneTests: ReviewEdgeCase {
    // MARK: Travel

    /// Made in New York on Sunday, opened in Kiritimati (UTC+14), where it's already Monday:
    /// the new week is current, the repeating Sunday task and the carry-over came with it,
    /// once each, not late; the week before keeps everything (view only).
    @MainActor
    func testTravelEastIntoTheNextWeekKeepsTasks() throws {
        let east = "Pacific/Kiritimati", home = "America/New_York"
        try XCTSkipIf(ReviewEdgeCase.weekTitle(in: east) == ReviewEdgeCase.weekTitle(in: home), "same week in both zones right now")
        let id = "edge-east-\(UUID().uuidString)"
        var app = launch(home, id: id)
        XCTAssertEqual(weekTitle(app), ReviewEdgeCase.weekTitle(in: home))
        open("Errands", in: app)
        add(["Water plants", "Plain carry", "Once only"], in: app)
        let sunday = ReviewEdgeCase.calendar(home).component(.weekday, from: Date()) == 1
        setOptions(of: "Water plants", mode: "Repeating", day: "Sunday", in: app)
        setOptions(of: "Plain carry", mode: "Carry Over", in: app)
        if sunday { XCTAssertEqual(app.staticTexts["Water plants"].value as? String, "today") }
        shot("edge-travel-east-1-newyork")

        app.terminate()
        app = launch(east, id: id)
        print("REVIEW east week title: \(weekTitle(app))")
        XCTAssertEqual(weekTitle(app), ReviewEdgeCase.weekTitle(in: east), "Kiritimati's week is current")
        open("Errands", in: app)
        let titles = taskTitles(app)
        print("REVIEW east tasks: \(titles)")
        XCTAssertEqual(titles.filter { $0.contains("Water plants") }.count, 1, "the repeating task once")
        XCTAssertEqual(titles.filter { $0.contains("Plain carry") }.count, 1, "the carry-over once")
        XCTAssertFalse(titles.contains { $0.contains("Once only") }, "the one-time task stayed in its week")
        let day = app.staticTexts["Water plants"].value as? String ?? ""
        print("REVIEW east Water plants value: \(day)")
        XCTAssertEqual(day, "Sunday", "its Sunday is this week's, still to come")
        shot("edge-travel-east-2-kiritimati")

        app.buttons["Previous week"].tap()
        sleep(1)
        XCTAssertEqual(weekTitle(app), ReviewEdgeCase.weekTitle(in: home), "the week it was made in")
        let before = taskTitles(app)
        print("REVIEW east last week tasks: \(before)")
        XCTAssertEqual(before.count, 3, "all three are kept there")
        shot("edge-travel-east-3-lastweek")
    }

    /// A user who opened the app on Monday in Kiritimati (or Tokyo) and flies back to New
    /// York, where it's still Sunday: this week is current again and the next week is a
    /// later week. A carry-over checked off here should leave next week, and a carry-over
    /// added here should show up there, as for anyone who never travelled.
    @MainActor
    func testFlyingBackWestKeepsNextWeekFollowingThisWeek() throws {
        try flyBackWest(from: "Pacific/Kiritimati")
    }

    /// The same from Tokyo (UTC+9), Monday morning there, Sunday evening in New York.
    @MainActor
    func testFlyingBackFromTokyoKeepsNextWeekFollowingThisWeek() throws {
        try flyBackWest(from: "Asia/Tokyo")
    }

    @MainActor
    private func flyBackWest(from east: String) throws {
        let home = "America/New_York"
        try XCTSkipIf(ReviewEdgeCase.weekTitle(in: east) == ReviewEdgeCase.weekTitle(in: home), "same week in both zones right now")
        let id = "edge-west-\(UUID().uuidString)"
        var app = launch(home, id: id)
        open("Errands", in: app)
        add(["Plain carry"], in: app)
        setOptions(of: "Plain carry", mode: "Carry Over", in: app)
        app.terminate()

        // Monday in Kiritimati: the app is opened there once.
        app = launch(east, id: id)
        XCTAssertEqual(weekTitle(app), ReviewEdgeCase.weekTitle(in: east))
        open("Errands", in: app)
        XCTAssertTrue(app.buttons["Complete Plain carry"].waitForExistence(timeout: 3), "carried into the new week")
        app.terminate()

        // Back home, still Sunday: last week is this week again.
        app = launch(home, id: id)
        XCTAssertEqual(weekTitle(app), ReviewEdgeCase.weekTitle(in: home), "this week is current again")
        open("Errands", in: app)
        app.buttons["Complete Plain carry"].tap()
        XCTAssertTrue(app.buttons["Mark Plain carry incomplete"].waitForExistence(timeout: 3))
        add(["Added after the trip"], in: app)
        setOptions(of: "Added after the trip", mode: "Carry Over", in: app)
        shot("edge-travel-west-1-thisweek")

        app.buttons["Next week"].tap()
        sleep(2)
        if !app.buttons["Edit Errands"].exists { open("Errands", in: app) }
        let next = taskTitles(app)
        print("REVIEW west next week tasks: \(next)")
        shot("edge-travel-west-2-nextweek")
        XCTAssertFalse(next.contains { $0.contains("Plain carry") }, "done this week, so it doesn't carry into next week")
        XCTAssertTrue(next.contains { $0.contains("Added after the trip") }, "a new carry-over reaches next week")
    }

    /// The same steps without the trip, as a control: next week follows this week.
    @MainActor
    func testWithoutTravelNextWeekFollowsThisWeek() throws {
        let home = "America/New_York"
        let id = "edge-control-\(UUID().uuidString)"
        var app = launch(home, id: id)
        open("Errands", in: app)
        add(["Plain carry"], in: app)
        setOptions(of: "Plain carry", mode: "Carry Over", in: app)
        // Next week saved by an edit there, as the trip's Monday saved it.
        app.buttons["Next week"].tap()
        sleep(2)
        if !app.buttons["Edit Errands"].exists { open("Errands", in: app) }
        add(["Next week's own"], in: app)
        app.terminate()

        app = launch(home, id: id)
        open("Errands", in: app)
        app.buttons["Complete Plain carry"].tap()
        add(["Added after"], in: app)
        setOptions(of: "Added after", mode: "Carry Over", in: app)
        app.buttons["Next week"].tap()
        sleep(2)
        if !app.buttons["Edit Errands"].exists { open("Errands", in: app) }
        let next = taskTitles(app)
        print("REVIEW control next week tasks: \(next)")
        XCTAssertFalse(next.contains { $0.contains("Plain carry") })
        XCTAssertTrue(next.contains { $0.contains("Added after") })
    }

    /// Pago Pago (UTC−11) and Kiritimati (UTC+14): the day strip's today pill and the header
    /// agree with the zone's own date.
    @MainActor
    func testFarZonesShowTheirOwnToday() throws {
        for zone in ["Pacific/Pago_Pago", "Pacific/Kiritimati", "Asia/Tokyo", "America/Phoenix"] {
            let app = launch(zone, id: "edge-zone-\(UUID().uuidString)")
            XCTAssertEqual(weekTitle(app), ReviewEdgeCase.weekTitle(in: zone), "\(zone): the zone's week")
            let calendar = ReviewEdgeCase.calendar(zone)
            let name = calendar.weekdaySymbols[calendar.component(.weekday, from: Date()) - 1]
            let pill = app.buttons["Day \(name)"]
            XCTAssertTrue(pill.exists, "\(zone): \(name)'s pill")
            let formatter = DateFormatter()
            formatter.timeZone = calendar.timeZone
            formatter.locale = Locale(identifier: "en_US")
            formatter.dateFormat = "EEEE, MMMM d"
            print("REVIEW zone \(zone) title=\(weekTitle(app)) pill=\(pill.label) value=\(pill.value ?? "") expect=\(formatter.string(from: Date()))")
            XCTAssertTrue(pill.label.contains(formatter.string(from: Date())), "\(zone): today's date on its pill")
            shot("edge-zone-\(zone.replacingOccurrences(of: "/", with: "-"))")
            app.terminate()
        }
    }
}

/// Lifecycle: a change made just before the app is force-quit is saved; words typed in Add
/// task and then the app sent to the background (Control Center, a call) and quit there.
final class ReviewEdgeLifecycleTests: ReviewEdgeCase {
    @MainActor
    func testChangesSurviveForceQuit() throws {
        let id = "edge-quit-\(UUID().uuidString)"
        var app = launch("America/New_York", id: id)
        open("Errands", in: app)
        add(["Saved at once"], in: app)
        setOptions(of: "Saved at once", mode: "Repeating", day: "Sunday", in: app)
        app.buttons["Complete Saved at once"].tap()
        app.terminate()  // straight away
        app = launch("America/New_York", id: id)
        open("Errands", in: app)
        XCTAssertTrue(app.buttons["Mark Saved at once incomplete"].waitForExistence(timeout: 3), "the check was saved")
        let options = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Task options:")).firstMatch.label
        print("REVIEW quit options after relaunch: \(options) value=\(app.staticTexts["Saved at once"].value ?? "")")
        XCTAssertEqual(options, "Task options: Checkbox, Repeating")
    }

    /// Words typed but not added, then the app goes to the background and is quit there:
    /// the spec says typed tasks are added however the keyboard closes.
    @MainActor
    func testTypedTaskBackgroundedThenQuit() throws {
        let id = "edge-bg-\(UUID().uuidString)"
        var app = launch("America/New_York", id: id)
        open("Errands", in: app)
        let field = app.addTaskField
        if app.keyboards.count == 0 { field.tap() }
        field.typeText("Typed before a call")
        XCUIDevice.shared.press(.home)
        sleep(2)
        app.activate()
        sleep(1)
        // Going to the background closes the keyboard, which adds what was typed.
        let added = app.buttons["Complete Typed before a call"]
        print("REVIEW bg after activate: task=\(added.exists) keyboard=\(app.keyboards.count)")
        shot("edge-bg-after-activate")
        XCTAssertTrue(added.waitForExistence(timeout: 3), "the typed words became a task")
        XCUIDevice.shared.press(.home)
        sleep(2)
        app.terminate()
        app = launch("America/New_York", id: id)
        open("Errands", in: app)
        let kept = app.buttons["Complete Typed before a call"].waitForExistence(timeout: 3)
        print("REVIEW bg after quit: kept=\(kept)")
        XCTAssertTrue(kept, "and it was saved before the app was quit")
        shot("edge-bg-after-quit")
    }
}
