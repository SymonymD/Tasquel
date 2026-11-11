import XCTest

/// FINDING (new features, any data): turning This week only on and straight off again on
/// this week's card puts the modes back, but next week's card is rebuilt: its untouched copies
/// are deleted and made again, so a list folded only in next week opens again (the spec says
/// a fold changed in a later week stays) and next week's own task moves among the copies.
/// Throwaway storage that lasts across launches (-isolatedDataID), so no seed is needed.
final class ReviewUpdateRoundTripTests: XCTestCase {
    @MainActor
    func testThisWeekOnlyRoundTripKeepsNextWeeksFoldAndOrder() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-isolatedDataID", "roundtrip-\(UUID().uuidString)"]
        app.launch()
        if app.staticTexts["Welcome to Tasquel"].waitForExistence(timeout: 3) { app.buttons["Skip"].tap() }
        let errands = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Errands,")).firstMatch
        XCTAssertTrue(errands.waitForExistence(timeout: 5))
        errands.tap()

        // This week: a carry-over list and a repeating task.
        let field = app.addTaskField
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText("Groceries")
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "New task options")).firstMatch.tap()
        app.buttons["List"].firstMatch.tap()
        app.buttons["Carry Over"].firstMatch.tap()
        app.buttons["Add Task"].tap()
        let item = app.textFields["Add item"]
        XCTAssertTrue(item.waitForExistence(timeout: 3))
        item.typeText("Milk\n")
        usleep(500_000)
        app.buttons["Done"].firstMatch.tap()
        let field2 = app.addTaskField
        field2.tap()
        field2.typeText("Laundry")
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "New task options")).firstMatch.tap()
        app.buttons["Checkbox"].firstMatch.tap()
        app.buttons["Repeating"].firstMatch.tap()
        app.buttons["Add Task"].tap()
        XCTAssertTrue(app.staticTexts["Laundry"].waitForExistence(timeout: 3))
        app.buttons["Done"].firstMatch.tap()

        // Next week: its own task last, and Groceries folded there only.
        app.buttons["Next week"].tap()
        sleep(1)
        let nextField = app.addTaskField
        XCTAssertTrue(nextField.waitForExistence(timeout: 3))
        nextField.tap()
        nextField.typeText("Own task\n")
        usleep(500_000)
        app.buttons["Done"].firstMatch.tap()
        app.buttons["Fold Groceries"].tap()
        XCTAssertEqual(app.buttons["Fold Groceries"].label, "Expand list")
        let before = taskOrder(app)
        XCTAssertEqual(before.last, "Own task")

        // This week: This week only on, then off again.
        app.buttons["Previous week"].tap()
        sleep(1)
        app.buttons["Edit Errands"].tap()
        let toggle = app.switches["This week only"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 3))
        toggle.switches.firstMatch.tap()
        toggle.switches.firstMatch.tap()
        XCTAssertEqual(toggle.value as? String, "0")
        app.buttons["Done editing Errands"].tap()

        // Next week is as it was.
        app.buttons["Next week"].tap()
        sleep(1)
        XCTAssertTrue(app.staticTexts["Groceries"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.buttons["Fold Groceries"].label, "Expand list", "next week's own fold is kept")
        XCTAssertEqual(taskOrder(app), before, "next week's tasks keep their order")
    }

    @MainActor
    private func taskOrder(_ app: XCUIApplication) -> [String] {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@ OR label BEGINSWITH %@", "Complete ", "Mark "))
            .allElementsBoundByIndex
            .filter { !["Milk"].contains($0.label.replacingOccurrences(of: "Complete ", with: "")) }
            .sorted { $0.frame.minY < $1.frame.minY }
            .map { $0.label.replacingOccurrences(of: "Complete ", with: "").replacingOccurrences(of: " incomplete", with: "").replacingOccurrences(of: "Mark ", with: "") }
    }
}
