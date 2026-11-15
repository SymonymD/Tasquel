import XCTest

/// Review 2026-11-15 (Edge cases): Smart Add dates and days at the week's end, month and
/// year ends, Sunday week start, and long names beside the new marks on an iPhone SE.
final class ReviewEdgeDatesTests: ReviewEdgeCase {

    @MainActor
    private func launchNY(_ zone: String = "America/New_York", id: String, extra: [String] = ["-smartAddRules"]) -> XCUIApplication {
        launch(zone, id: id, extra: extra)
    }

    /// Types `text` in the open card's Add task field and taps Smart Add; waits for its note.
    @MainActor
    private func smartAdd(_ text: String, in app: XCUIApplication) {
        let field = app.addTaskField
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        if app.keyboards.count == 0 { field.tap() }
        field.typeText(text)
        let button = app.buttons["Smart Add"]
        XCTAssertTrue(button.waitForExistence(timeout: 3))
        sleep(1)
        button.tap()
        sleep(4)  // the rules' 2 s pause, and the add
    }

    @MainActor
    private func setWeekStartsOnSunday(_ app: XCUIApplication) {
        app.buttons["Settings"].tap()
        let sunday = app.settingsButton("Sunday")
        XCTAssertTrue(sunday.waitForExistence(timeout: 3))
        sunday.tap()
        sleep(1)
        app.buttons["Done"].firstMatch.tap()
        sleep(1)
    }

    // MARK: Deadline words

    /// "before" and "till" make a typed date a deadline (Carry Over), and Set Date takes the
    /// date out of the name. The joining word should go with it, as "by", "due", "until"
    /// and "on" do: "Return books before 12/1" should become "Return books".
    @MainActor
    func testSetDateTakesBeforeAndTillOutOfTheName() throws {
        let app = launchNY(id: "edge-deadline-\(UUID().uuidString)")
        open("Errands", in: app)
        let day = Calendar.current.date(byAdding: .day, value: 10, to: Date())!
        let parts = Calendar.current.dateComponents([.month, .day], from: day)
        let month = day.formatted(.dateTime.month(.abbreviated)).lowercased()
        for (typed, expected) in [("Return books before \(parts.month!)/\(parts.day!)", "Return books"),
                                  ("Pay rent till \(month) \(parts.day!)", "Pay rent"),
                                  ("Renew permit by \(parts.month!)/\(parts.day!)", "Renew permit")] {
            smartAdd(typed, in: app)
            let setDate = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Set date to")).firstMatch
            XCTAssertTrue(setDate.waitForExistence(timeout: 10), "a date is offered for \(typed)")
            setDate.tap()
            sleep(1)
            let names = taskTitles(app)
            print("REVIEW deadline \(typed) -> \(names)")
            shot("edge-deadline-\(expected.replacingOccurrences(of: " ", with: "-"))")
            XCTAssertTrue(app.staticTexts[expected].exists, "“\(typed)” is named “\(expected)” (tasks: \(names))")
            if app.buttons["Done"].firstMatch.exists, app.keyboards.count > 0 { app.buttons["Done"].firstMatch.tap() }
        }
    }

    // MARK: The week's last day

    /// On Sunday, the week's last day (Monday start): "tomorrow" is next Monday. The task
    /// goes into next week on Monday; the pop-up and the note shouldn't say Monday "had
    /// already gone by" (it's tomorrow).
    @MainActor
    func testTomorrowOnTheWeeksLastDay() throws {
        let calendar = Calendar(identifier: .gregorian)
        try XCTSkipIf(calendar.component(.weekday, from: Date()) != 1, "only on a Sunday")
        let app = launchNY(id: "edge-tomorrow-\(UUID().uuidString)")
        open("Errands", in: app)
        let thisWeek = weekTitle(app)
        smartAdd("Call mom tomorrow", in: app)
        sleep(1)
        let texts = app.staticTexts.allElementsBoundByIndex.map(\.label).filter { $0.contains("gone by") || $0.contains("next week") || $0.contains("Added") || $0.contains("Moved") }
        print("REVIEW tomorrow texts: \(texts) week=\(weekTitle(app))")
        shot("edge-tomorrow-on-sunday")
        XCTAssertNotEqual(weekTitle(app), thisWeek, "the screen went to next week")
        XCTAssertTrue(app.staticTexts["Call mom"].exists, "named without the day word")
        XCTAssertEqual(app.staticTexts["Call mom"].value as? String, "Monday", "on Monday, not late")
        XCTAssertFalse(texts.contains { $0.contains("Monday had already gone by") },
                       "tomorrow hasn't gone by: the pop-up and note shouldn't say so (\(texts))")
    }

    /// "by friday" on the week's last day: a deadline, next Friday, carrying over.
    @MainActor
    func testByFridayOnTheWeeksLastDay() throws {
        let calendar = Calendar(identifier: .gregorian)
        try XCTSkipIf(calendar.component(.weekday, from: Date()) != 1, "only on a Sunday")
        let app = launchNY(id: "edge-byfriday-\(UUID().uuidString)")
        open("Errands", in: app)
        smartAdd("Send invoice by friday", in: app)
        sleep(1)
        let texts = app.staticTexts.allElementsBoundByIndex.map(\.label).filter { $0.contains("gone by") || $0.contains("next week") }
        print("REVIEW byfriday texts: \(texts) week=\(weekTitle(app)) tasks=\(taskTitles(app))")
        let options = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Task options:")).allElementsBoundByIndex.map(\.label)
        print("REVIEW byfriday options: \(options)")
        shot("edge-byfriday-on-sunday")
        XCTAssertTrue(app.staticTexts["Send invoice"].exists)
        XCTAssertEqual(app.staticTexts["Send invoice"].value as? String, "Friday")
    }

    // MARK: Year end

    /// "Party 12/31": Set Date moves the one-time task into the week of Dec 28, which runs
    /// into the new year; its day strip shows Dec 28 … Jan 3, and the week after says 2027.
    @MainActor
    func testDecember31MovesIntoAWeekAcrossTheNewYear() throws {
        let app = launchNY(id: "edge-yearend-\(UUID().uuidString)")
        open("Errands", in: app)
        smartAdd("Party 12/31", in: app)
        let setDate = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Set date to")).firstMatch
        XCTAssertTrue(setDate.waitForExistence(timeout: 10))
        setDate.tap()
        let popUp = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Moved to ")).firstMatch
        XCTAssertTrue(popUp.waitForExistence(timeout: 5))
        print("REVIEW yearend popup: \(popUp.label) week=\(weekTitle(app))")
        shot("edge-yearend-1-popup")
        app.buttons["Moved OK"].tap()
        sleep(1)
        XCTAssertEqual(weekTitle(app), "Week of Dec 28")
        let thursday = app.buttons["Day Thursday"].label, friday = app.buttons["Day Friday"].label
        print("REVIEW yearend pills: \(thursday) / \(friday) / party value=\(app.staticTexts["Party"].value ?? "")")
        XCTAssertTrue(thursday.hasPrefix("Thursday, December 31"))
        XCTAssertTrue(friday.hasPrefix("Friday, January 1"))
        XCTAssertTrue(app.staticTexts["Party"].exists)
        shot("edge-yearend-2-week")
        app.buttons["Next week"].tap()
        sleep(2)
        print("REVIEW yearend next title: \(weekTitle(app))")
        XCTAssertEqual(weekTitle(app), "Week of Jan 4, 2027", "a week in another year says so")
        XCTAssertFalse(app.staticTexts["Party"].exists, "gone after its date")
    }

    /// Weeks from Sunday: on Sunday today is the week's first day, so "tomorrow" stays in this
    /// week, and "Party 12/31" goes into the week of Dec 27.
    @MainActor
    func testSundayStartTomorrowAndYearEnd() throws {
        let app = launchNY(id: "edge-sunstart-\(UUID().uuidString)")
        setWeekStartsOnSunday(app)
        let thisWeek = weekTitle(app)
        print("REVIEW sunstart title: \(thisWeek)")
        XCTAssertEqual(thisWeek, ReviewEdgeCase.weekTitle(in: "America/New_York", mondayStart: false))
        open("Errands", in: app)
        smartAdd("Call mom tomorrow", in: app)
        XCTAssertEqual(weekTitle(app), thisWeek, "tomorrow is in this week")
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        XCTAssertEqual(app.staticTexts["Call mom"].value as? String, tomorrow.formatted(.dateTime.weekday(.wide)))
        if app.keyboards.count > 0 { app.buttons["Done"].firstMatch.tap(); sleep(1) }
        smartAdd("Party 12/31", in: app)
        let setDate = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Set date to")).firstMatch
        XCTAssertTrue(setDate.waitForExistence(timeout: 10))
        setDate.tap()
        XCTAssertTrue(app.buttons["Moved OK"].waitForExistence(timeout: 5))
        app.buttons["Moved OK"].tap()
        sleep(1)
        print("REVIEW sunstart party week: \(weekTitle(app)) value=\(app.staticTexts["Party"].value ?? "")")
        shot("edge-sunstart-party")
        XCTAssertEqual(weekTitle(app), "Week of Dec 27")
        XCTAssertTrue(app.staticTexts["Party"].exists)
    }

    // MARK: Sunday start and a late day, then long names on the SE

    /// Weeks from Sunday. Made in Pago Pago on Sunday, the week's first day: a task for
    /// Sunday is "Today". Opened in Kiritimati, already Monday in the same week: "Sun · late".
    /// Long names beside "Sun · late", a date ("Nov 28") and "⧉ Duplicate" must still show
    /// whole on the SE.
    @MainActor
    func testLateMarkAndLongNamesOnSE() throws {
        let west = "Pacific/Pago_Pago", east = "Pacific/Kiritimati"
        let calendar = ReviewEdgeCase.calendar(west)
        try XCTSkipIf(calendar.component(.weekday, from: Date()) != 1, "only while it's Sunday in Pago Pago")
        try XCTSkipIf(ReviewEdgeCase.calendar(east).component(.weekday, from: Date()) != 2, "and Monday in Kiritimati")
        let id = "edge-late-\(UUID().uuidString)"
        var app = launchNY(west, id: id, extra: [])
        setWeekStartsOnSunday(app)
        XCTAssertEqual(weekTitle(app), ReviewEdgeCase.weekTitle(in: west, mondayStart: false))
        open("Errands", in: app)
        let late = "Pick up the dry cleaning from the shop across town"
        let dup = "Buy a birthday present for grandma"
        let dated = "Renew the passport at the post office downtown"
        add([late, dup, dup, dated], in: app)
        setOptions(of: late, mode: "Carry Over", day: "Sunday", in: app)
        setDate(of: dated, mode: "Carry Over", daysAhead: 13, in: app)
        XCTAssertEqual(app.staticTexts[late].value as? String, "today")
        app.terminate()

        app = launchNY(east, id: id, extra: [])
        XCTAssertEqual(weekTitle(app), ReviewEdgeCase.weekTitle(in: east, mondayStart: false), "the same week, from Sunday")
        open("Errands", in: app)
        let value = app.staticTexts[late].value as? String ?? ""
        print("REVIEW late value: \(value)")
        XCTAssertEqual(value, "Sunday, late", "Sunday has gone by unfinished")
        shot("edge-late-long-names-SE")
        let width = app.windows.firstMatch.frame.width
        for name in [late, dup, dated] {
            let frame = app.staticTexts.matching(identifier: name).firstMatch.frame
            print("REVIEW name frame \(name): \(frame)")
            XCTAssertLessThanOrEqual(frame.maxX, width, "\(name) stays on the screen")
            XCTAssertGreaterThan(frame.height, 20, "\(name) has room for its words")
            // Nine words at the default size: three lines without a mark (the duplicate's
            // mark goes under the name); beside "Sun · late" it took seven (155pt).
            XCTAssertLessThanOrEqual(frame.height, 90, "\(name) takes at most four lines (\(frame.height)pt)")
        }
    }
}

/// A date as far off as the calendar goes (24 months): the one-time task moves there, the
/// app stays quick, and coming back to this week and opening a card is still instant.
final class ReviewEdgeFarDateTests: ReviewEdgeCase {
    @MainActor
    func testDateTwoYearsAwayMovesAndStaysQuick() throws {
        let app = launch("America/New_York", id: "edge-far-\(UUID().uuidString)")
        open("Errands", in: app)
        add(["Renew passport"], in: app)
        let options = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Task options:")).firstMatch
        options.tap()
        XCTAssertTrue(app.staticTexts["DAY"].waitForExistence(timeout: 3))
        app.buttons["Add a date"].tap()
        XCTAssertTrue(app.staticTexts["Until"].waitForExistence(timeout: 3))
        let next = app.buttons["Next month"]
        var taps = 0
        while next.isEnabled && taps < 30 { next.tap(); taps += 1 }
        print("REVIEW far: Next month taps until disabled = \(taps)")
        let target = Calendar.current.date(byAdding: .month, value: taps, to: Date())!
        var parts = Calendar.current.dateComponents([.year, .month], from: target)
        parts.day = 10
        let day = Calendar.current.date(from: parts)!
        app.buttons[day.formatted(.dateTime.weekday(.wide).month(.wide).day())].tap()
        shot("edge-far-calendar")
        let start = Date()
        app.buttons["Set"].tap()
        if app.staticTexts["DAY"].waitForExistence(timeout: 2) { app.buttons["Done"].firstMatch.tap() }
        let popUp = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Moved to ")).firstMatch
        XCTAssertTrue(popUp.waitForExistence(timeout: 10), "it moves to its date's week")
        let moveTime = Date().timeIntervalSince(start)
        print("REVIEW far: popup=\(popUp.label) title=\(weekTitle(app)) moveTime=\(moveTime)")
        shot("edge-far-moved")
        XCTAssertTrue(weekTitle(app).contains("\(parts.year!)"), "the far week's title has its year")
        // The pop-up names the week too: without the year, "Nov 6" reads as this year's.
        XCTAssertTrue(popUp.label.contains("\(parts.year!)"), "the pop-up says which year (\(popUp.label))")
        let back = Date()
        app.buttons["Moved Back to This Week"].tap()
        XCTAssertTrue(app.staticTexts[ReviewEdgeCase.weekTitle(in: "America/New_York")].waitForExistence(timeout: 10))
        print("REVIEW far: back time=\(Date().timeIntervalSince(back))")
        // Go to Week reads every week's marks.
        let open = Date()
        app.buttons["Go to week"].tap()
        sleep(1)
        print("REVIEW far: go to week open time=\(Date().timeIntervalSince(open))")
        shot("edge-far-gotoweek")
        XCTAssertLessThan(moveTime, 8)
    }
}
