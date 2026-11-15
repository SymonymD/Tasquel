import XCTest

/// Shared steps for the ReviewEdge* tests (review 2026-11-15, Edge cases and small screens).
class ReviewEdgeCase: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    // MARK: Helpers

    /// Today in `zone`, by a Gregorian calendar.
    static func today(in zone: String) -> Date { Date() }

    static func calendar(_ zone: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone)!
        calendar.locale = Locale(identifier: "en_US")
        return calendar
    }

    /// The Monday the week holding today in `zone` starts on, "Nov 16".
    static func weekTitle(in zone: String, mondayStart: Bool = true) -> String {
        let calendar = calendar(zone)
        let weekday = calendar.component(.weekday, from: Date())  // 1 Sunday … 7 Saturday
        let back = mondayStart ? (weekday + 5) % 7 : weekday - 1
        let start = calendar.date(byAdding: .day, value: -back, to: Date())!
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "MMM d"
        var title = "Week of " + formatter.string(from: start)
        if calendar.component(.year, from: start) != calendar.component(.year, from: Date()) {
            title += ", \(calendar.component(.year, from: start))"
        }
        return title
    }

    @MainActor
    func launch(_ zone: String, id: String, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["TZ"] = zone
        app.launchArguments = ["-isolatedDataID", id] + extra
        app.launch()
        if app.staticTexts["Welcome to Tasquel"].waitForExistence(timeout: 3) { app.buttons["Skip"].tap() }
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 5))
        return app
    }

    @MainActor
    func weekTitle(_ app: XCUIApplication) -> String {
        app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Week of")).firstMatch.label
    }

    @MainActor
    func open(_ card: String, in app: XCUIApplication) {
        let button = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open \(card),")).firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 5), "\(card) is there")
        button.tap()
        XCTAssertTrue(app.buttons["Edit \(card)"].waitForExistence(timeout: 3))
    }

    @MainActor
    func add(_ titles: [String], in app: XCUIApplication) {
        let field = app.addTaskField
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        // `addTaskField` already gave it the keyboard; a second tap shows the AutoFill menu.
        if app.keyboards.count == 0 { field.tap() }
        for title in titles {
            field.typeText(title + "\n")
            Thread.sleep(forTimeInterval: 0.5)
        }
        app.buttons["Done"].firstMatch.tap()  // the keyboard's Done
        sleep(1)
    }

    /// Opens the type/mode popup of `title`'s row, picks `mode` and `day`, and closes it.
    @MainActor
    func setOptions(of title: String, mode: String? = nil, day: String? = nil, in app: XCUIApplication) {
        let options = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Task options:"))
        let row = app.staticTexts[title].frame
        let button = options.allElementsBoundByIndex.min { abs($0.frame.midY - row.midY) < abs($1.frame.midY - row.midY) }!
        button.tap()
        XCTAssertTrue(app.staticTexts["DAY"].waitForExistence(timeout: 3))
        if let mode { app.buttons[mode].firstMatch.tap() }
        if let day { app.buttons[day].firstMatch.tap() }
        app.buttons["Done"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["DAY"].waitForNonExistence(timeout: 3))
        sleep(1)
    }

    @MainActor
    func shot(_ name: String) {
        let dir = ProcessInfo.processInfo.environment["SHOT_DIR"] ?? NSTemporaryDirectory()
        try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
    }

    @MainActor
    func taskTitles(_ app: XCUIApplication) -> [String] {
        // Each task row has a checkbox "Complete <title>" / "Mark <title> incomplete".
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Complete ' OR label BEGINSWITH 'Mark '")).allElementsBoundByIndex.map(\.label)
    }

    /// Opens `title`'s options, picks `mode`, then a date `daysAhead` days from today in the
    /// calendar, and sets it.
    @MainActor
    func setDate(of title: String, mode: String?, daysAhead: Int, in app: XCUIApplication) {
        let options = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Task options:"))
        let row = app.staticTexts[title].frame
        let button = options.allElementsBoundByIndex.min { abs($0.frame.midY - row.midY) < abs($1.frame.midY - row.midY) }!
        button.tap()
        XCTAssertTrue(app.staticTexts["DAY"].waitForExistence(timeout: 3))
        if let mode { app.buttons[mode].firstMatch.tap() }
        app.buttons["Add a date"].tap()
        XCTAssertTrue(app.staticTexts["Until"].waitForExistence(timeout: 3))
        let day = Calendar.current.date(byAdding: .day, value: daysAhead, to: Date())!
        if !Calendar.current.isDate(day, equalTo: Date(), toGranularity: .month) { app.buttons["Next month"].tap() }
        app.buttons[day.formatted(.dateTime.weekday(.wide).month(.wide).day())].tap()
        app.buttons["Set"].tap()
        XCTAssertTrue(app.staticTexts["Until"].waitForNonExistence(timeout: 3))
        if app.staticTexts["DAY"].exists { app.buttons["Done"].firstMatch.tap() }
        sleep(1)
        if app.buttons["Moved OK"].exists { app.buttons["Moved OK"].tap() }
    }
}
