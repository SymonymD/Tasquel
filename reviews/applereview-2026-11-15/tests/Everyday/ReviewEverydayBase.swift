import XCTest

/// Shared helpers for the Everyday-flows review tests (2026-11-15 App Review audit).
class ReviewEverydayBase: XCTestCase {
    var app: XCUIApplication!
    var dataID = ""

    override func setUp() {
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
    }

    /// A clean launch with its own throwaway storage, kept across relaunches in this test.
    @MainActor
    func launch(_ extra: [String] = [], id: String? = nil) {
        dataID = id ?? "everyday-\(UUID().uuidString)"
        app = XCUIApplication()
        app.launchArguments = ["-isolatedDataID", dataID] + extra
        app.launch()
        if app.staticTexts["Welcome to Tasquel"].waitForExistence(timeout: 4) { app.buttons["Skip"].tap() }
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 8))
    }

    /// Cold relaunch on the same storage.
    @MainActor
    func relaunch() {
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 8))
        sleep(1)
    }

    @MainActor
    func shot(_ name: String) {
        Thread.sleep(forTimeInterval: 0.6)
        let dir = ProcessInfo.processInfo.environment["SHOT_DIR"] ?? NSTemporaryDirectory()
        try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
    }

    func log(_ text: String) { print("REVIEW: \(name) \(text)") }

    func card(_ name: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open \(name),")).firstMatch
    }

    @MainActor
    func openCard(_ name: String) {
        let c = card(name)
        XCTAssertTrue(c.waitForExistence(timeout: 5), "card \(name)")
        c.tap()
        XCTAssertTrue(app.buttons["Close \(name)"].waitForExistence(timeout: 3))
        sleep(1)
    }

    var weekTitle: String {
        app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Week of")).firstMatch.label
    }

    /// The type/mode button on the row of `title`.
    func options(for title: String) -> XCUIElement {
        let all = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Task options:")).allElementsBoundByIndex
        let row = app.staticTexts[title].firstMatch.frame
        return all.min { abs($0.frame.midY - row.midY) < abs($1.frame.midY - row.midY) }!
    }

    var newTaskOptions: XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "New task options")).firstMatch
    }

    @MainActor
    func dismissPopover() {
        let region = app.otherElements["PopoverDismissRegion"]
        if region.exists { region.tap() } else { app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.03)).tap() }
        sleep(1)
    }

    @MainActor
    func keyboardDone() {
        let done = app.buttons["Done"].firstMatch
        if done.exists { done.tap() }
        sleep(1)
    }

    @MainActor
    func typeTasks(_ titles: [String]) {
        let field = app.addTaskField
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        for t in titles {
            field.typeText(t + "\n")
            Thread.sleep(forTimeInterval: 0.5)
        }
    }

    /// Settings ▸ Week ▸ Sunday or Monday.
    @MainActor
    func setWeekStart(sunday: Bool) {
        app.buttons["Settings"].tap()
        let target = sunday ? "Sunday" : "Monday"
        let seg = app.buttons[target].firstMatch
        let list = app.collectionViews.firstMatch
        for _ in 0..<8 where !(seg.exists && seg.isHittable) { list.swipeUp(velocity: .slow) }
        XCTAssertTrue(seg.exists, "week start \(target) in Settings")
        seg.tap()
        sleep(1)
        app.buttons["Done"].firstMatch.tap()
        sleep(1)
    }

    var taskTitles: [String] {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@ OR label BEGINSWITH %@", "Complete ", "Mark "))
            .allElementsBoundByIndex.map(\.label)
    }

    func weekdayName(_ date: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US"); f.dateFormat = "EEEE"
        return f.string(from: date)
    }
}
