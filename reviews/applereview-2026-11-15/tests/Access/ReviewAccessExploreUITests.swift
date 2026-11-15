import XCTest

/// Accessibility review (2026-11-15): walks the main screens in their states, runs the
/// automated accessibility audit on each (collecting the issues without failing), and saves
/// a screenshot and the accessibility tree of each to SHOT_DIR. Exploration, not assertions:
/// the findings have their own tests in ReviewAccessFindingsUITests.
final class ReviewAccessExploreUITests: XCTestCase {
    private var app: XCUIApplication!
    private var tag = ""
    private var dir: String { ProcessInfo.processInfo.environment["SHOT_DIR"] ?? NSTemporaryDirectory() }

    override func setUp() {
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    func testExploreDefaultSize() throws {
        tag = "def"
        explore([])
    }

    @MainActor
    func testExploreAccessibilityXXXL() throws {
        tag = "ax5"
        explore(["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
    }

    @MainActor
    func testExploreXXXL() throws {
        tag = "xxxl"
        explore(["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryXXXL"])
    }

    // MARK: Walk

    @MainActor
    private func explore(_ extra: [String]) {
        app = XCUIApplication()
        app.launchArguments = ["-demoData", "-demoToday", "2026-11-11", "-fakeCalendar"] + extra
        app.launch()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 10))
        sleep(1)
        record("01-main")

        // Today's day pill, then a past one.
        let wed = app.buttons["Day Wednesday"]
        if wed.waitForExistence(timeout: 3) {
            print("REVIEW: pill Wednesday label=\(wed.label) value=\(String(describing: wed.value)) frame=\(wed.frame) selected=\(wed.isSelected)")
            wed.tap(); sleep(1)
            record("02-filter-today")
            wed.tap(); sleep(1)
        }
        let mon = app.buttons["Day Monday"]
        if mon.exists {
            print("REVIEW: pill Monday label=\(mon.label) frame=\(mon.frame)")
            mon.tap(); sleep(1)
            record("03-filter-monday")
            mon.tap(); sleep(1)
        }

        // An open card.
        let errands = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Errands,")).firstMatch
        if errands.waitForExistence(timeout: 3) {
            print("REVIEW: closed card label=\(errands.label)")
            errands.tap(); sleep(1)
            record("04-errands-open")

            // The type/mode popup of the first task.
            let options = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Task options:")).element(boundBy: 1)
            if options.exists {
                options.tap(); sleep(1)
                record("05-options-popup")
                let done = app.buttons["Done"].firstMatch
                if done.exists { done.tap() } else { app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.03)).tap() }
                sleep(1)
            }

            // The card's own edit mode.
            if app.buttons["Edit Errands"].waitForExistence(timeout: 3) {
                app.editCard("Errands")
                record("06-card-edit")
                let doneEditing = app.buttons["Done editing Errands"]
                if doneEditing.exists { doneEditing.tap(); sleep(1) }
            }
            let close = app.buttons["Close Errands"]
            if close.exists { close.tap(); sleep(1) }
        }

        // The grid's Edit mode and Add Category.
        if app.buttons["Edit"].exists {
            app.buttons["Edit"].tap(); sleep(1)
            record("07-grid-edit")
            let addCard = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Add Category")).firstMatch
            if addCard.exists {
                addCard.tap(); sleep(1)
                record("08-add-category")
                let editSaved = app.buttons["Edit Saved Categories"]
                if editSaved.exists {
                    editSaved.tap(); sleep(1)
                    record("09-edit-saved")
                    let doneSaved = app.buttons["Done Editing Saved Categories"]
                    if doneSaved.exists { doneSaved.tap(); sleep(1) }
                }
                app.navigationBars["Add Category"].buttons["Done"].firstMatch.tap(); sleep(1)
            }
            let doneEditing = app.buttons["Done Editing"]
            if doneEditing.exists { doneEditing.tap(); sleep(1) }
        }

        // Next week: the bar's house.
        if app.buttons["Next week"].exists {
            app.buttons["Next week"].tap(); sleep(2)
            record("10-next-week")
            let house = app.buttons["Bar Back to This Week"]
            print("REVIEW: house exists=\(house.exists) label=\(house.exists ? house.label : "") frame=\(house.exists ? house.frame : .zero)")
            if house.exists { house.tap(); sleep(1) }
        }

        // Settings and Help.
        app.buttons["Settings"].tap(); sleep(1)
        record("11-settings")
        let help = app.settingsButton("How to Use Tasquel")
        if help.exists {
            help.tap(); sleep(1)
            record("12-help")
            for name in ["Weeks", "Dates"] where app.buttons[name].exists {
                app.buttons[name].tap(); sleep(1)
                record("13-help-\(name)")
            }
        }
    }

    // MARK: Helpers

    @MainActor
    private func record(_ name: String) {
        let full = "\(tag)-\(name)"
        try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/\(full).png"))
        try? app.debugDescription.write(toFile: "\(dir)/\(full).tree.txt", atomically: true, encoding: .utf8)
        var lines: [String] = []
        do {
            try app.performAccessibilityAudit(for: .all) { issue in
                let el = issue.element
                let line = "REVIEW: audit [\(full)] \(issue.auditType) | \(issue.compactDescription) | label=\(el?.label ?? "") id=\(el?.identifier ?? "") frame=\(el?.frame ?? .zero)"
                print(line)
                lines.append(line)
                return true
            }
        } catch {
            print("REVIEW: audit [\(full)] threw \(error)")
        }
        try? lines.joined(separator: "\n").write(toFile: "\(dir)/\(full).audit.txt", atomically: true, encoding: .utf8)
    }
}
