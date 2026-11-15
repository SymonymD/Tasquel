import XCTest

/// Update review (2026-11-15): uses the LIVE version (1.0.3) like a long-time user, through the
/// UI, with data saved where a real user's is (no throwaway or demo flags). Run on a fresh
/// simulator (or after `simctl uninstall`): onboarding is gone through first.
/// `TEST_RUNNER_SEED_SUNDAY=1` sets Sunday as the week's start first and picks Retro; otherwise
/// Monday and Dark. Screenshots go to `TEST_RUNNER_SHOT_DIR` with the prefix `before-`.
final class ReviewUpdateSeedUITests: XCTestCase {
    private var app: XCUIApplication!
    private let env = ProcessInfo.processInfo.environment
    private var shotDir: String { env["SHOT_DIR"] ?? NSTemporaryDirectory() }
    private var sunday: Bool { env["SEED_SUNDAY"] == "1" }

    @MainActor
    func testSeedLiveVersionData() throws {
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launch()
        if app.staticTexts["Welcome to Tasquel"].waitForExistence(timeout: 10) {
            for _ in 0..<4 { app.buttons["Next"].tap() }
            app.buttons["Let's Go!"].tap()
        }
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 10), "main screen")
        if sunday { setWeekStart(sunday: true) }

        // Work: a carry-over with sub-tasks (one checked), two same-named tasks, a checked
        // one-time task, a repeating task, a renamed task and a deleted one.
        open("Work")
        add("Report", mode: "Carry Over")
        addSubtasks(to: "Report", ["Draft", "Review"])
        add("Call mom")
        add("Call mom")
        add("Email boss")
        add("Standup", mode: "Repeating")
        add("Temp")
        hideKeyboard()
        tapButton("Complete Draft")
        tapButton("Complete Email boss")
        rename("Email boss", to: "Email the boss")
        tapButton("Edit Work")
        tapButton("Delete Temp")
        tapButton("Done editing Work")
        shot("before-work")
        close("Work")

        // Fitness: a repeating goal with progress, a carry-over time goal.
        open("Fitness")
        addGoal("Run", mode: "Repeating", target: "7", steps: 3)
        hideKeyboard()
        shot("before-fitness")
        close("Fitness")

        // Errands: a carry-over list, one item checked, folded.
        open("Errands")
        addList("Groceries", mode: "Carry Over", items: ["Milk", "Eggs", "Bread"])
        hideKeyboard()
        tapButton("Complete Milk")
        tapButton("Fold Groceries", identifier: true)
        shot("before-errands")
        close("Errands")

        // Trip: a new card, made This week only with 1.0.3's switch in its edit mode.
        addCategory("Trip")
        open("Trip")
        add("Pack bag", mode: "Carry Over")
        add("Book hotel", mode: "Repeating")
        hideKeyboard()
        tapButton("Edit Trip")
        let toggle = app.switches["This week only"]
        if toggle.waitForExistence(timeout: 5) { toggle.switches.firstMatch.tap() } else { note("no This week only switch") }
        sleep(1)
        shot("before-trip-edit")
        tapButton("Done editing Trip")
        close("Trip")

        // A deleted card (Study) and a reordered card (Appointments dragged onto Work).
        tapButton("Edit")
        tapButton("Delete Study")
        tapButton("Delete Category")  // 1.0.3 asks
        sleep(1)
        tapButton("Done Editing")
        sleep(6)  // Undo gone
        let appointments = card("Appointments"), work = card("Work")
        if appointments.waitForExistence(timeout: 5) && work.exists {
            appointments.press(forDuration: 1.0, thenDragTo: work)
            sleep(2)
        } else { note("cards to reorder not found") }
        shot("before-grid")
        let cards = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open ")).allElementsBoundByIndex
        print("REVIEW: seed card order: \(cards.map { ($0.frame, $0.label) }.sorted { ($0.0.minY.rounded(), $0.0.minX) < ($1.0.minY.rounded(), $1.0.minX) }.map { String($0.1.dropFirst(5).prefix { $0 != "," }) })")

        // Next week: rename the copy of Report, delete the repeating Standup there.
        tapButton("Next week")
        sleep(2)
        open("Work")
        rename("Report", to: "Report v2")
        tapButton("Edit Work")
        tapButton("Delete Standup")
        tapButton("Done editing Work")
        sleep(6)
        shot("before-next-week-work")
        close("Work")
        tapButton("Previous week")
        sleep(2)

        // Looks: Dark (Monday run) or Retro (Sunday run).
        tapButton("Settings")
        let look = app.buttons[sunday ? "Retro" : "Dark"]
        if look.waitForExistence(timeout: 5) { look.tap() } else { note("no appearance row") }
        sleep(2)
        dismissSpringboardAlert()
        shot("before-settings")
        app.buttons["Done"].firstMatch.tap()
        sleep(1)
        shot("before-grid-final")
        for name in ["Work", "Fitness", "Errands", "Trip"] {
            open(name)
            sleep(1)
            shot("before-open-\(name.lowercased())")
            close(name)
        }
        print("REVIEW: seed done, sunday=\(sunday)")
        app.terminate()
    }

    // MARK: - Helpers

    private func note(_ s: String) { print("REVIEW: seed: \(s)") }

    private func shot(_ name: String) {
        try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(shotDir)/\(name).png"))
    }

    private func card(_ name: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open \(name),")).firstMatch
    }

    private func tapButton(_ label: String, identifier: Bool = false) {
        let b = identifier ? app.buttons.matching(identifier: label).firstMatch : app.buttons[label].firstMatch
        if b.waitForExistence(timeout: 5) { b.tap() } else { note("no button \(label)") }
    }

    private func open(_ name: String) {
        let c = card(name)
        if c.waitForExistence(timeout: 5) { c.tap(); _ = app.buttons["Close \(name)"].waitForExistence(timeout: 5) } else { note("no card \(name)") }
    }

    private func close(_ name: String) {
        hideKeyboard()
        tapButton("Close \(name)")
        sleep(1)
    }

    private func hideKeyboard() {
        let kb = app.keyboards.firstMatch
        guard kb.exists else { return }
        let hide = app.buttons["keyboard.chevron.compact.down"]
        if hide.exists { hide.tap() } else { app.buttons["Done"].firstMatch.tap() }
        _ = kb.waitForNonExistence(timeout: 3)
    }

    /// Adds a task: Return alone (a one-time checkbox), or through the new task's options.
    private func add(_ title: String, type: String? = nil, mode: String? = nil) {
        let field = app.addTaskField
        guard field.waitForExistence(timeout: 5) else { note("no Add task field for \(title)"); return }
        field.tap()
        if type == nil && mode == nil {
            field.typeText("\(title)\n")
            Thread.sleep(forTimeInterval: 0.6)
            return
        }
        field.typeText(title)
        let options = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "New task options")).firstMatch
        guard options.waitForExistence(timeout: 3) else { note("no new task options"); return }
        options.tap()
        if let type { app.buttons[type].firstMatch.tap() }
        if let mode { app.buttons[mode].firstMatch.tap() }
        tapButton("Add Task")
        Thread.sleep(forTimeInterval: 0.6)
    }

    private func addSubtasks(to task: String, _ titles: [String]) {
        hideKeyboard()
        tapButton("Add sub-task to \(task)")
        let field = app.textViews["Add sub-task"].exists ? app.textViews["Add sub-task"] : app.textFields["Add sub-task"]
        guard field.waitForExistence(timeout: 3) else { note("no Add sub-task field"); return }
        for t in titles { field.typeText("\(t)\n"); Thread.sleep(forTimeInterval: 0.5) }
        hideKeyboard()
    }

    private func addGoal(_ title: String, mode: String, target: String, steps: Int) {
        add(title, type: "Goal", mode: mode)
        let field = app.textFields["Target"].firstMatch
        if field.waitForExistence(timeout: 5) {
            field.typeText(target)
            app.buttons["Done"].firstMatch.tap()
            sleep(1)
        } else { note("no Target field"); print(app.debugDescription) }
        let plus = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@ AND NOT (label BEGINSWITH %@)", "Add ", "Add task")).firstMatch
        for _ in 0..<steps where plus.waitForExistence(timeout: 3) { plus.tap(); Thread.sleep(forTimeInterval: 0.4) }
        print("REVIEW: seed goal plus label: \(plus.exists ? plus.label : "none")")
    }

    private func addList(_ title: String, mode: String, items: [String]) {
        add(title, type: "List", mode: mode)
        let item = app.textFields["Add item"].exists ? app.textFields["Add item"] : app.textViews["Add item"]
        guard item.waitForExistence(timeout: 5) else { note("no Add item field"); return }
        for i in items { item.typeText("\(i)\n"); Thread.sleep(forTimeInterval: 0.5) }
    }

    private func rename(_ title: String, to newTitle: String) {
        hideKeyboard()
        let text = app.staticTexts[title].firstMatch
        guard text.waitForExistence(timeout: 5) else { note("no task \(title) to rename"); return }
        text.tap()
        let field = app.textViews["Task name"].exists ? app.textViews["Task name"] : app.textFields["Task name"]
        guard field.waitForExistence(timeout: 3) else { note("no Task name field"); return }
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: title.count + 2))
        field.typeText("\(newTitle)\n")
        Thread.sleep(forTimeInterval: 0.6)
        hideKeyboard()
    }

    private func addCategory(_ name: String) {
        tapButton("Edit")
        let addCard = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Add Category")).firstMatch
        guard addCard.waitForExistence(timeout: 5) else { note("no Add Category"); return }
        addCard.tap()
        tapButton("Create New Category")
        let field = app.textFields["Category name"]
        guard field.waitForExistence(timeout: 3) else { note("no Category name field"); return }
        field.typeText("\(name)\n")
        _ = app.navigationBars["Add Category"].waitForNonExistence(timeout: 5)
        sleep(1)
        if app.buttons["Done"].exists && !app.keyboards.firstMatch.exists { app.buttons["Done"].firstMatch.tap() }
    }

    private func setWeekStart(sunday: Bool) {
        tapButton("Settings")
        let seg = app.buttons[sunday ? "Sunday" : "Monday"].firstMatch
        for _ in 0..<6 where !(seg.exists && seg.isHittable) { app.collectionViews.firstMatch.swipeUp(velocity: .slow) }
        if seg.exists { seg.tap() } else { note("no week start control") }
        sleep(1)
        app.buttons["Done"].firstMatch.tap()
        sleep(1)
    }

    /// Changing the app icon (Retro) shows a system alert.
    private func dismissSpringboardAlert() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let ok = springboard.buttons["OK"]
        if ok.waitForExistence(timeout: 2) { ok.tap() }
    }
}
