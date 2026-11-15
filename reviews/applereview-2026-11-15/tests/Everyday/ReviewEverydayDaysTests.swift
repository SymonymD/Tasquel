import XCTest

/// Days for tasks, a day gone by, the day filter and the week start (review 2026-11-15).
final class ReviewEverydayDaysTests: ReviewEverydayBase {

    /// Monday start, today Sunday: a new task given Thursday in the Day row goes into next
    /// week; the pop-up's Back to This Week returns; next week still has it; relaunch keeps it.
    @MainActor
    func testDayGoneByJourneyBackAndRelaunch() throws {
        launch()
        openCard("Work")
        typeTasks(["Standup notes"])
        newTaskOptions.tap()
        XCTAssertTrue(app.staticTexts["DAY"].waitForExistence(timeout: 3))
        app.buttons["Thursday"].tap()
        shot("days-01-dayrow-thursday")
        app.buttons["Done"].firstMatch.tap()
        let field = app.addTaskField
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        log("placeholder after Thursday: \(field.placeholderValue ?? "nil")")
        XCTAssertEqual(field.placeholderValue, "Add Task for Next Thu")
        let thisWeek = weekTitle
        field.tap()
        field.typeText("Call dentist\n")
        let popUp = app.staticTexts["Added to next week"]
        XCTAssertTrue(popUp.waitForExistence(timeout: 5))
        shot("days-02-added-to-next-week")
        log("week now: \(weekTitle) (was \(thisWeek)); keyboard: \(app.keyboards.firstMatch.exists)")
        XCTAssertNotEqual(weekTitle, thisWeek)
        XCTAssertEqual(app.staticTexts["Call dentist"].value as? String, "Thursday")
        app.buttons["Moved Back to This Week"].tap()
        sleep(2)
        shot("days-03-back-to-this-week")
        XCTAssertEqual(weekTitle, thisWeek, "back on this week")
        XCTAssertFalse(app.staticTexts["Call dentist"].exists, "not in this week")
        XCTAssertTrue(app.staticTexts["Standup notes"].exists, "this week's task still there")
        log("this week's add field placeholder: \(app.textFields["Add task"].exists ? (app.textFields["Add task"].placeholderValue ?? "") : "closed")")
        // The add row keeps Thursday picked: check what it says now.
        let plusLabel = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Add Task")).firstMatch
        log("plus row label: \(plusLabel.exists ? plusLabel.label : "none")")

        app.buttons["Next week"].tap()
        sleep(2)
        XCTAssertTrue(app.staticTexts["Call dentist"].waitForExistence(timeout: 3), "next week has it")
        shot("days-04-next-week-again")
        relaunch()
        app.buttons["Next week"].tap()
        sleep(2)
        openCard("Work")
        XCTAssertTrue(app.staticTexts["Call dentist"].waitForExistence(timeout: 3), "kept after relaunch")
        XCTAssertEqual(app.staticTexts["Call dentist"].value as? String, "Thursday")
        shot("days-05-after-relaunch")
    }

    /// Sunday start, today Sunday is the first day: Monday is still to come, so a new task
    /// for Monday stays in this week, with no "Next".
    @MainActor
    func testSundayStartKeepsLaterDaysThisWeek() throws {
        launch()
        setWeekStart(sunday: true)
        shot("days-10-sunday-start")
        let strip = app.descendants(matching: .any)["Week days"]
        log("strip: \(strip.exists)")
        let firstPill = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "Day ")).allElementsBoundByIndex.map(\.identifier)
        log("pills: \(firstPill)")
        XCTAssertEqual(firstPill.first, "Day Sunday", "Sunday first")
        openCard("Work")
        let thisWeek = weekTitle
        let field = app.addTaskField
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        newTaskOptions.tap()
        XCTAssertTrue(app.staticTexts["DAY"].waitForExistence(timeout: 3))
        app.buttons["Monday"].tap()
        app.buttons["Done"].firstMatch.tap()
        let f2 = app.addTaskField
        log("placeholder for Monday with Sunday start: \(f2.placeholderValue ?? "nil")")
        XCTAssertEqual(f2.placeholderValue, "Add Task for Mon")
        f2.tap()
        f2.typeText("Plan week\n")
        sleep(2)
        XCTAssertFalse(app.staticTexts["Added to next week"].exists, "no pop-up")
        XCTAssertEqual(weekTitle, thisWeek, "still this week")
        XCTAssertEqual(app.staticTexts["Plan week"].value as? String, "Monday")
        // Sunday is today.
        newTaskOptions.tap()
        if app.staticTexts["DAY"].waitForExistence(timeout: 2) {
            app.buttons["Sunday"].tap()
            app.buttons["Done"].firstMatch.tap()
        }
        let f3 = app.addTaskField
        f3.tap()
        f3.typeText("Laundry\n")
        sleep(1)
        keyboardDone()
        log("Laundry value: \(app.staticTexts["Laundry"].value as? String ?? "nil")")
        XCTAssertEqual(app.staticTexts["Laundry"].value as? String, "today")
        XCTAssertLessThan(app.staticTexts["Laundry"].frame.minY, app.staticTexts["Plan week"].frame.minY, "Sunday first in a Sunday week")
        shot("days-11-sunday-start-tasks")
        relaunch()
        openCard("Work")
        XCTAssertEqual(app.staticTexts["Plan week"].value as? String, "Monday", "kept after relaunch")
        XCTAssertEqual(weekTitle, thisWeek)
    }

    /// The day filter: a past day's pill, then adding while it's on: the new task gets that
    /// day, which has gone by, so it goes to next week, and the filter stays on there.
    @MainActor
    func testFilterOnPastDayThenAdd() throws {
        launch()
        openCard("Errands")
        typeTasks(["Bank"])
        keyboardDone()
        app.buttons["Day Thursday"].tap()
        sleep(1)
        let filterLine = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "tasks with no day")).firstMatch
        log("filter line: \(filterLine.exists ? filterLine.label : "none")")
        shot("days-20-filter-thursday")
        let field = app.addTaskField
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        log("placeholder with Thursday filter: \(field.placeholderValue ?? "nil")")
        field.tap()
        field.typeText("Pick up dry cleaning\n")
        let popped = app.staticTexts["Added to next week"].waitForExistence(timeout: 5)
        log("pop-up: \(popped) week: \(weekTitle)")
        shot("days-21-filter-add")
        if popped { app.buttons["Moved OK"].tap() }
        log("filter line on next week: \(filterLine.exists ? filterLine.label : "none")")
        XCTAssertTrue(app.staticTexts["Pick up dry cleaning"].exists, "visible in next week under the filter")
        app.buttons["Show All"].tap()
        sleep(1)
        shot("days-22-show-all")
        // Today's pill (Sunday).
        app.buttons["Day Sunday"].tap()
        sleep(1)
        log("filter line Sunday: \(filterLine.exists ? filterLine.label : "none")")
        shot("days-23-filter-sunday")
        app.buttons["Show All"].tap()
    }

    /// A late task this week (Monday start, today Sunday): a task given Tuesday when
    /// Tuesday... can't be made late by hand (a day picked after it has gone by isn't late);
    /// check that an existing task given a past day stays put and isn't late.
    @MainActor
    func testExistingTaskGivenPastDayStaysNotLate() throws {
        launch()
        openCard("Work")
        typeTasks(["Expense report"])
        keyboardDone()
        let thisWeek = weekTitle
        options(for: "Expense report").tap()
        XCTAssertTrue(app.staticTexts["DAY"].waitForExistence(timeout: 3))
        app.buttons["Tuesday"].tap()
        shot("days-30-existing-tuesday")
        app.buttons["Done"].firstMatch.tap()
        sleep(1)
        XCTAssertEqual(weekTitle, thisWeek, "stays in this week")
        log("value: \(app.staticTexts["Expense report"].value as? String ?? "nil")")
        XCTAssertEqual(app.staticTexts["Expense report"].value as? String, "Tuesday", "not late")
        app.buttons["Day Sunday"].tap()
        sleep(1)
        log("today's pill shows Tuesday task: \(app.staticTexts["Expense report"].exists)")
        shot("days-31-sunday-filter")
        app.buttons["Show All"].tap()
        relaunch()
        openCard("Work")
        XCTAssertEqual(app.staticTexts["Expense report"].value as? String, "Tuesday", "not late after relaunch")
    }
}
