import XCTest

/// Settings ▸ Week (Sunday / Monday) with folded lists and This week only cards, and
/// Settings ▸ Categories ▸ Sort Cards with folding.
final class ReviewSettingsWeekTests: ReviewSettingsBase {

    /// A folded repeating list (Errands ▸ Shop, 1 of 2 checked) and a This week only card
    /// (Work, with a one-time Report that was carry-over) survive Sunday ↔ Monday, in this
    /// week and next week, and a relaunch.
    @MainActor
    func testWeekStartKeepsFoldedListsAndThisWeekOnly() {
        launchIsolated("review-week-\(UUID().uuidString)")
        buildFoldedListAndThisWeekOnlyCard()
        let week0 = weekTitle()
        checkThisAndNextWeek("monday-before")

        setWeekStart("Sunday")
        XCTAssertNotEqual(weekTitle(), week0, "the week now starts on Sunday")
        checkThisAndNextWeek("sunday")

        relaunch()
        openCard("Errands")
        checkThisAndNextWeek("sunday-relaunch")

        setWeekStart("Monday")
        XCTAssertEqual(weekTitle(), week0, "back to the Monday week")
        checkThisAndNextWeek("monday-after")
    }

    /// Folding a list isn't an edit: with Recently Edited First, folding Errands' list
    /// doesn't move Errands to the front when the cards are re-sorted.
    @MainActor
    func testFoldingIsNotAnEditForSortCards() {
        launchDemo(["-demoAppearance", "light", "-demoFirstCard", "Work"])
        openSettings()
        let sort = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Sort Cards")).firstMatch
        XCTAssertTrue(sort.waitForExistence(timeout: 3))
        sort.tap()
        app.buttons["Recently Edited First"].firstMatch.tap()
        closeSettings()
        // Edit Work so it's the most recent.
        openCard("Work")
        app.buttons["Complete Inbox zero"].tap()
        app.buttons["Close Work"].tap()
        let before = cardOrder()
        print("REVIEW: sort order before fold \(before)")
        XCTAssertEqual(before.first, "Work", "the edited card is first")

        openCard("Errands")
        app.buttons["Fold Groceries"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "value == %@", "2 of 5 items checked")).firstMatch.waitForExistence(timeout: 2))
        app.buttons["Close Errands"].tap()  // every card closed: the sort refreshes
        sleep(1)
        let after = cardOrder()
        print("REVIEW: sort order after fold \(after)")
        XCTAssertEqual(after.first, "Work", "folding Groceries didn't count as editing Errands")
        shot("sort-after-fold")

        // Back to Manual.
        openSettings()
        sort.tap()
        app.buttons["Manual"].firstMatch.tap()
        closeSettings()
    }

    // MARK: Helpers

    @MainActor
    private func weekTitle() -> String {
        app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Week of")).firstMatch.label
    }

    @MainActor
    private func cardOrder() -> [String] {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open ")).allElementsBoundByIndex
            .filter { $0.frame.height > 40 && $0.label.contains(",") }
            .sorted { ($0.frame.minY, $0.frame.minX) < ($1.frame.minY, $1.frame.minX) }
            .map { String($0.label.dropFirst(5).prefix { $0 != "," }) }
    }

    @MainActor
    private func setWeekStart(_ day: String) {
        openSettings()
        let segment = app.buttons[day].firstMatch
        XCTAssertTrue(segment.waitForExistence(timeout: 3))
        segment.tap()
        XCTAssertTrue(segment.isSelected, "\(day) picked")
        closeSettings()
    }

    /// Errands: a repeating list Shop (Milk checked, Eggs) folded. Work: Report (carry-over),
    /// then This week only on.
    @MainActor
    private func buildFoldedListAndThisWeekOnlyCard() {
        openCard("Errands")
        let field = app.addTaskField
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.typeText("Shop")
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "New task options")).firstMatch.tap()
        app.buttons["List"].firstMatch.tap()
        app.buttons["Repeating"].firstMatch.tap()
        app.buttons["Add Task"].tap()
        let item = app.textFields["Add item"]
        XCTAssertTrue(item.waitForExistence(timeout: 3))
        item.typeText("Milk\n")
        Thread.sleep(forTimeInterval: 0.5)
        item.typeText("Eggs\n")
        Thread.sleep(forTimeInterval: 0.5)
        app.buttons["Done"].firstMatch.tap()  // the keyboard
        XCTAssertTrue(app.buttons["Complete Milk"].waitForExistence(timeout: 3))
        app.buttons["Complete Milk"].tap()
        app.buttons["Fold Shop"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "value == %@", "1 of 2 items checked")).firstMatch.waitForExistence(timeout: 2))
        // Close Errands, so the Add task field below is Work's.
        app.buttons["Close Errands"].tap()

        openCard("Work")
        let work = app.addTaskField
        XCTAssertTrue(work.waitForExistence(timeout: 3))
        work.typeText("Report")
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "New task options")).firstMatch.tap()
        app.buttons["Carry Over"].firstMatch.tap()
        app.buttons["Add Task"].tap()
        app.buttons["Done"].firstMatch.tap()
        app.buttons["Edit Work"].tap()
        let toggle = app.switches["This week only"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 3))
        toggle.switches.firstMatch.tap()
        XCTAssertEqual(toggle.value as? String, "1")
        app.buttons["Done editing Work"].tap()
        XCTAssertTrue(app.buttons["Task options: Checkbox, One-Time"].waitForExistence(timeout: 3), "Report is one-time")
        openCard("Errands")
    }

    /// This week: Shop folded (1 of 2), Work this week only with Report one-time.
    /// Next week: Shop folded, no Work card. Then back to this week.
    @MainActor
    private func checkThisAndNextWeek(_ tag: String) {
        if !app.buttons["Fold Shop"].exists, card("Errands").exists { openCard("Errands") }
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "value == %@", "1 of 2 items checked")).firstMatch.waitForExistence(timeout: 3), "[\(tag)] Shop still folded, 1 of 2")
        XCTAssertFalse(app.staticTexts["Milk"].exists, "[\(tag)] items hidden")
        let workClosed = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Work, this week only")).firstMatch
        let workOpen = app.buttons["Close Work"]
        XCTAssertTrue(workClosed.exists || workOpen.exists, "[\(tag)] Work is there")
        if workClosed.exists {
            print("REVIEW: [\(tag)] Work card: \(workClosed.label)")
        } else {
            app.buttons["Edit Work"].tap()
            XCTAssertEqual(app.switches["This week only"].value as? String, "1", "[\(tag)] Work still this week only")
            app.buttons["Done editing Work"].tap()
        }
        shot("week-\(tag)-this")

        app.buttons["Next week"].tap()
        sleep(1)
        if !app.buttons["Fold Shop"].exists, card("Errands").exists { openCard("Errands") }
        let nextCount = app.staticTexts.matching(NSPredicate(format: "value ENDSWITH %@", "items checked")).firstMatch
        XCTAssertTrue(nextCount.waitForExistence(timeout: 3), "[\(tag)] next week's Shop is folded too")
        print("REVIEW: [\(tag)] next week Shop: \(nextCount.exists ? nextCount.label : "not folded")")
        XCTAssertFalse(app.buttons["Close Work"].exists || card("Work").exists, "[\(tag)] no Work next week")
        shot("week-\(tag)-next")
        app.buttons["Previous week"].tap()
        sleep(1)
    }
}
