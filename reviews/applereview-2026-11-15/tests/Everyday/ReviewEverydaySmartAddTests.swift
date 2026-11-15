import XCTest

/// Smart Add with days and dates, followed across weeks (review 2026-11-15; -smartAddRules).
final class ReviewEverydaySmartAddTests: ReviewEverydayBase {

    @MainActor
    func smartAdd(_ text: String) {
        let field = app.addTaskField
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText(text)
        XCTAssertTrue(app.buttons["Smart Add"].waitForExistence(timeout: 2))
        sleep(1)
        app.buttons["Smart Add"].tap()
    }

    func notes() -> [String] {
        app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@ OR label CONTAINS %@ OR label BEGINSWITH %@", "Added", "gone by", "Until")).allElementsBoundByIndex.map(\.label)
    }

    /// Monday start, today Sunday: "Call mom tomorrow" goes to next Monday; "Call mom Sunday"
    /// is today; "Gym Mon Wed Fri" is a list of days; "remind me to" is dropped.
    @MainActor
    func testSmartAddDaysOnSunday() throws {
        launch(["-smartAddRules", "-smartAddDelay", "1"])
        openCard("Errands")
        let thisWeek = weekTitle
        smartAdd("Call mom Sunday")
        sleep(3)
        log("after 'Call mom Sunday': tasks \(taskTitles) notes \(notes()) week \(weekTitle)")
        let mom = app.staticTexts["Call mom"]
        log("Call mom value: \(mom.value as? String ?? "nil")")
        XCTAssertEqual(mom.value as? String, "today")
        shot("smart-01-call-mom-sunday")

        smartAdd("remind me to water plants tomorrow")
        let popUp = app.staticTexts["Added to next week"]
        let moved = popUp.waitForExistence(timeout: 6)
        log("after 'tomorrow': pop-up \(moved) week \(weekTitle) tasks \(taskTitles) notes \(notes())")
        shot("smart-02-tomorrow")
        XCTAssertTrue(moved)
        XCTAssertNotEqual(weekTitle, thisWeek)
        if moved { app.buttons["Moved OK"].tap() }
        let water = app.staticTexts.matching(NSPredicate(format: "label ==[c] %@", "water plants")).firstMatch
        log("water plants exists \(water.exists) value \(water.value as? String ?? "nil")")
        XCTAssertTrue(water.exists, "'remind me to' and 'tomorrow' are dropped")
        let undoSmart = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Undo")).allElementsBoundByIndex.map(\.label)
        log("undo on next week: \(undoSmart)")
        shot("smart-03-next-week-note")

        app.buttons["Moved Back to This Week"].exists ? app.buttons["Moved Back to This Week"].tap() : app.buttons["Previous week"].tap()
        sleep(2)
        XCTAssertEqual(weekTitle, thisWeek)
        smartAdd("Gym Mon Wed Fri")
        sleep(4)
        log("after 'Gym Mon Wed Fri': week \(weekTitle) tasks \(taskTitles) opts \(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Task options:")).allElementsBoundByIndex.map(\.label)) notes \(notes())")
        shot("smart-04-gym-mwf")
        smartAdd("Go to the zoo and harass penguins")
        sleep(4)
        log("after zoo: tasks \(taskTitles) notes \(notes())")
        shot("smart-05-zoo")
    }

    /// A written date: "dentist december 15" offers "Until Tue, Dec 15? Set Date", which stays
    /// until answered; Set Date moves the one-time task to that week. "Pay rent by december 1"
    /// carries over.
    @MainActor
    func testSmartAddWrittenDates() throws {
        launch(["-smartAddRules", "-smartAddDelay", "1"])
        openCard("Appointments")
        let thisWeek = weekTitle
        smartAdd("dentist december 15")
        let setDate = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Set date to")).firstMatch
        XCTAssertTrue(setDate.waitForExistence(timeout: 8))
        log("offer: \(notes()) tasks \(taskTitles)")
        shot("smart-10-dentist-offer")
        sleep(10)  // longer than the 8 s note
        log("after 10 s, offer still there: \(setDate.exists)")
        XCTAssertTrue(setDate.exists, "the date offer stays until answered")
        keyboardDone()
        log("after keyboard down, offer: \(setDate.exists)")
        setDate.tap()
        let popUp = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Moved to")).firstMatch
        XCTAssertTrue(popUp.waitForExistence(timeout: 5))
        log("pop-up: \(popUp.label) week \(weekTitle) tasks \(taskTitles)")
        shot("smart-11-dentist-moved")
        app.buttons["Moved Back to This Week"].tap()
        sleep(2)
        XCTAssertEqual(weekTitle, thisWeek)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH[c] %@", "dentist")).firstMatch.exists, "gone from this week")

        smartAdd("Pay rent by december 1")
        let setDate2 = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Set date to")).firstMatch
        XCTAssertTrue(setDate2.waitForExistence(timeout: 8))
        log("rent offer: \(notes()) tasks \(taskTitles)")
        setDate2.tap()
        sleep(2)
        let opts = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Task options:")).allElementsBoundByIndex.map(\.label)
        log("rent after set: tasks \(taskTitles) opts \(opts) week \(weekTitle)")
        XCTAssertEqual(weekTitle, thisWeek, "a deadline carries over here")
        XCTAssertTrue(opts.contains("Task options: Checkbox, Carry Over"))
        shot("smart-12-rent-carry")

        // Undo of a Smart Add while a date offer is up for another task.
        smartAdd("Haircut december 3")
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Set date to")).firstMatch.waitForExistence(timeout: 8))
        let undo = app.buttons["Undo Smart Add"].firstMatch
        log("undo smart add exists: \(undo.exists)")
        if undo.exists { undo.tap() }
        sleep(1)
        log("after undo: tasks \(taskTitles) offer still \(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Set date to")).firstMatch.exists)")
        shot("smart-13-undo-with-offer")
        relaunch()
        openCard("Appointments")
        log("after relaunch: \(taskTitles)")
    }
}
