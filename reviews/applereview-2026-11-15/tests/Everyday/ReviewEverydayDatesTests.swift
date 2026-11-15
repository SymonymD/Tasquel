import XCTest

/// Dates through the Day row's calendar and the edit-mode clock, followed across weeks
/// (review 2026-11-15).
final class ReviewEverydayDatesTests: ReviewEverydayBase {

    func dayLabel(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    /// In the open calendar, goes forward to `date`'s month and taps it.
    @MainActor
    func pickInCalendar(_ date: Date) {
        let target = app.buttons[dayLabel(date)]
        for _ in 0..<14 where !target.exists {
            app.buttons["Next month"].tap()
            Thread.sleep(forTimeInterval: 0.3)
        }
        XCTAssertTrue(target.exists, "calendar has \(dayLabel(date))")
        target.tap()
    }

    /// A One-Time task dated next week (Day row calendar, while adding) moves there with the
    /// pop-up; Undo on the note takes it back; the field forgets the date.
    @MainActor
    func testOneTimeDateNextWeekWhileAdding() throws {
        launch()
        openCard("Errands")
        let field = app.addTaskField
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText("Return library books")
        newTaskOptions.tap()
        XCTAssertTrue(app.buttons["Add a date"].waitForExistence(timeout: 3))
        app.buttons["One-Time"].firstMatch.tap()
        app.buttons["Add a date"].tap()
        XCTAssertTrue(app.staticTexts["Until"].waitForExistence(timeout: 3))
        let wed = Calendar.current.date(byAdding: .day, value: 3, to: Date())!  // Wed Nov 18
        pickInCalendar(wed)
        shot("dates-01-calendar-next-wed")
        app.buttons["Set"].tap()
        sleep(1)
        let hint = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Moves to the week of ")).firstMatch
        log("hint: \(hint.exists ? hint.label : "none")")
        shot("dates-02-options-with-date")
        let thisWeek = weekTitle
        app.buttons["Add Task"].firstMatch.tap()
        let popUp = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@ OR label BEGINSWITH %@", "Moved to", "Added to")).firstMatch
        XCTAssertTrue(popUp.waitForExistence(timeout: 5), "a pop-up")
        log("pop-up: \(popUp.label); week: \(weekTitle)")
        shot("dates-03-popup")
        let note = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Return library books")).allElementsBoundByIndex.map(\.label)
        log("notes/labels: \(note)")
        XCTAssertNotEqual(weekTitle, thisWeek)
        app.buttons["Moved OK"].tap()
        sleep(1)
        let value = app.staticTexts["Return library books"].value as? String
        log("row value: \(value ?? "nil")")
        let undo = app.buttons["Undo adding Return library books"]
        log("undo exists: \(undo.exists)")
        shot("dates-04-next-week-note")
        if undo.exists {
            undo.tap()
            XCTAssertTrue(app.staticTexts["Return library books"].waitForNonExistence(timeout: 3), "undo takes it back")
        }
        shot("dates-04b-after-undo")
        log("after undo: keyboard \(app.keyboards.firstMatch.exists) prev week button \(app.buttons["Previous week"].exists) week \(weekTitle)")
        // The add row, back on this week: does it still hold the date?
        keyboardDone()
        app.buttons["Previous week"].tap()
        sleep(2)
        let f = app.addTaskField
        log("placeholder after a dated add: \(f.placeholderValue ?? "nil")")
        shot("dates-05-this-week-after")
    }

    /// Carry Over dated months away: stays here, carries; Go to Week shows a purple mark.
    /// Then One-Time months away from an existing task (popup): moves into its date's week.
    @MainActor
    func testMonthsAwayCarryOverAndOneTime() throws {
        launch()
        openCard("Errands")
        typeTasks(["Renew passport", "Buy gifts"])
        keyboardDone()
        let far = Calendar.current.date(byAdding: .day, value: 75, to: Date())!  // ~Jan 29 2027
        // Carry Over, months away.
        options(for: "Renew passport").tap()
        app.buttons["Carry Over"].firstMatch.tap()
        app.buttons["Add a date"].tap()
        XCTAssertTrue(app.staticTexts["Until"].waitForExistence(timeout: 3))
        pickInCalendar(far)
        app.buttons["Set"].tap()
        sleep(1)
        let hint = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Carries over until")).firstMatch
        log("carry hint: \(hint.exists ? hint.label : "none")")
        app.buttons["Done"].firstMatch.tap()
        sleep(1)
        XCTAssertTrue(app.staticTexts["Renew passport"].exists, "carry-over stays here")
        let mark = app.buttons["Change date of Renew passport"]
        log("date mark: \(mark.exists ? mark.label + " / " + (mark.value as? String ?? "") : "none")")
        shot("dates-10-carry-far")

        // One-Time, months away: moves to its week.
        let thisWeek = weekTitle
        options(for: "Buy gifts").tap()
        app.buttons["One-Time"].firstMatch.tap()
        app.buttons["Add a date"].tap()
        XCTAssertTrue(app.staticTexts["Until"].waitForExistence(timeout: 3))
        pickInCalendar(far)
        shot("dates-11-onetime-far-calendar")
        app.buttons["Set"].tap()
        sleep(1)
        shot("dates-12-onetime-far-options")
        // An existing task moves on Set: the popup closes with its row.
        if app.buttons["Done"].firstMatch.exists { app.buttons["Done"].firstMatch.tap() }
        let popUp = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Moved to")).firstMatch
        XCTAssertTrue(popUp.waitForExistence(timeout: 5), "moved pop-up")
        log("pop-up: \(popUp.exists ? popUp.label : "none"); week: \(weekTitle)")
        shot("dates-13-moved-far")
        XCTAssertNotEqual(weekTitle, thisWeek)
        let gifts = app.staticTexts["Buy gifts"]
        log("gifts there: \(gifts.exists) value \(gifts.value as? String ?? "nil")")
        // The carry-over is in that week too (carries until its date).
        log("passport in far week: \(app.staticTexts["Renew passport"].exists)")
        let house = app.buttons.matching(NSPredicate(format: "identifier == %@", "Bar Back to This Week")).firstMatch
        log("house: \(house.exists)")
        app.buttons["Moved Back to This Week"].tap()
        sleep(2)
        XCTAssertEqual(weekTitle, thisWeek)
        XCTAssertFalse(app.staticTexts["Buy gifts"].exists, "gone from this week")

        // Relaunch, then Go to Week to its date's week.
        relaunch()
        app.buttons["Go to week"].tap()
        XCTAssertTrue(app.navigationBars["Go to Week"].waitForExistence(timeout: 3))
        shot("dates-14-goto-week")
        let farStart: Date = {
            var c = Calendar(identifier: .gregorian); c.firstWeekday = 2
            return c.dateInterval(of: .weekOfYear, for: far)!.start
        }()
        let row = app.buttons["Week of \(farStart.formatted(.dateTime.month(.wide).day().year()))"]
        for _ in 0..<8 where !(row.exists && row.isHittable) { app.swipeUp(velocity: .slow) }
        shot("dates-15-goto-week-far-month")
        XCTAssertTrue(row.exists)
        row.tap()
        app.buttons["Go"].tap()
        sleep(2)
        openCard("Errands")
        XCTAssertTrue(app.staticTexts["Buy gifts"].exists, "in its date's week after relaunch")
        XCTAssertTrue(app.staticTexts["Renew passport"].exists, "the carry-over reaches its date's week")
        shot("dates-16-far-week-after-relaunch")
        // And the week after its date: gone.
        app.buttons["Next week"].tap()
        sleep(2)
        log("week after date has passport: \(app.staticTexts["Renew passport"].exists) gifts: \(app.staticTexts["Buy gifts"].exists)")
        shot("dates-17-week-after-date")
    }

    /// The edit-mode clock on a one-time task: a date next week moves it (pop-up "Moved to
    /// next week"?), a date this week makes it a day task.
    @MainActor
    func testClockDateThisWeekAndNextWeek() throws {
        launch()
        openCard("Work")
        typeTasks(["Send invoice", "Review deck"])
        keyboardDone()
        app.editCard("Work")
        let clock = app.buttons["Expiration Send invoice"]
        XCTAssertTrue(clock.waitForExistence(timeout: 3))
        clock.tap()
        XCTAssertTrue(app.staticTexts["Expires"].waitForExistence(timeout: 3))
        app.buttons[dayLabel(Date())].tap()  // today, Sunday
        app.buttons["Set"].tap()
        sleep(1)
        log("clock value today: \(clock.value as? String ?? "nil")")
        app.buttons["Done editing Work"].tap()
        sleep(1)
        log("Send invoice value: \(app.staticTexts["Send invoice"].value as? String ?? "nil")")
        let dateMark = app.buttons["Change date of Send invoice"]
        let dayMark = app.buttons["Change day of Send invoice"]
        log("marks: date \(dateMark.exists) day \(dayMark.exists)")
        shot("dates-20-clock-today")

        let thisWeek = weekTitle
        app.editCard("Work")
        let clock2 = app.buttons["Expiration Review deck"]
        clock2.tap()
        XCTAssertTrue(app.staticTexts["Expires"].waitForExistence(timeout: 3))
        let fri = Calendar.current.date(byAdding: .day, value: 5, to: Date())!
        pickInCalendar(fri)
        let summary = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@ OR label BEGINSWITH %@", "Until", "Moves")).allElementsBoundByIndex.map(\.label)
        log("clock summary: \(summary)")
        shot("dates-21-clock-next-fri")
        app.buttons["Set"].tap()
        let popUp = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Moved to")).firstMatch
        let moved = popUp.waitForExistence(timeout: 5)
        log("moved pop-up: \(moved ? popUp.label : "none"); week \(weekTitle)")
        shot("dates-22-clock-moved")
        XCTAssertTrue(moved)
        XCTAssertNotEqual(weekTitle, thisWeek)
        log("card edit mode on arrival: \(app.buttons["Done editing Work"].exists)")
        app.buttons["Moved Back to This Week"].tap()
        sleep(2)
        log("this week edit mode after back: \(app.buttons["Done editing Work"].exists); tasks: \(taskTitles)")
        shot("dates-23-back")
    }
}
