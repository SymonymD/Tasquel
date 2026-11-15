import XCTest

/// Update review (2026-11-15): 1.1 installed over 1.0.3 data seeded by the old copy's
/// `ReviewUpdateSeedUITests` (shots/update_check.sh runs them in order). Launched WITHOUT
/// throwaway flags, on the data where a real user's is. Each test skips when there's no
/// seeded data (a fresh install shows onboarding).
/// `TEST_RUNNER_SEED_SUNDAY=1` when the data was seeded with Sunday as the week's start.
final class ReviewUpdateCheckUITests: XCTestCase {
    private var app: XCUIApplication!
    private let env = ProcessInfo.processInfo.environment
    private var shotDir: String { env["SHOT_DIR"] ?? NSTemporaryDirectory() }
    private var sunday: Bool { env["SEED_SUNDAY"] == "1" }

    @MainActor
    override func setUp() {
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
    }

    @MainActor
    private func launchUpdated() throws {
        app.launch()
        if app.staticTexts["Welcome to Tasquel"].waitForExistence(timeout: 4) {
            throw XCTSkip("no 1.0.3 data on this simulator (onboarding showed): run shots/update_check.sh")
        }
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 10))
        sleep(2)  // the What's New pill slides out a moment after opening
    }

    /// Everything 1.0.3 saved is still there and means the same, through two relaunches.
    @MainActor
    func testUpdateKeepsLiveVersionData() throws {
        try launchUpdated()
        for launch in 1...3 {
            if launch > 1 { app.terminate(); app.launch(); XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 10)); sleep(2) }
            XCTAssertFalse(app.staticTexts["Welcome to Tasquel"].exists, "no onboarding for an updater")
            shot("after-grid-launch\(launch)")
            print("REVIEW: launch \(launch) card order: \(cardOrder())")
            for name in ["Work", "Fitness", "Errands", "Trip", "Appointments", "Home"] where name != "Home" {
                XCTAssertTrue(card(name).waitForExistence(timeout: 5), "card \(name) kept (launch \(launch))")
            }
            XCTAssertFalse(card("Study").exists, "the deleted card stays deleted")
            let order = cardOrder()
            if let a = order.firstIndex(of: "Appointments"), let w = order.firstIndex(of: "Work") {
                XCTAssertLessThan(a, w, "the reordered card keeps its place")
            }

            open("Work")
            shot("after-open-work-launch\(launch)")
            for t in ["Report", "Draft", "Review", "Email the boss", "Standup"] {
                XCTAssertTrue(app.staticTexts[t].firstMatch.exists, "\(t) kept")
            }
            XCTAssertFalse(app.staticTexts["Temp"].exists, "the deleted task stays deleted")
            XCTAssertTrue(app.buttons["Mark Draft incomplete"].exists, "checked sub-task still checked")
            XCTAssertTrue(app.buttons["Complete Review"].exists, "unchecked sub-task still unchecked")
            XCTAssertTrue(app.buttons["Mark Email the boss incomplete"].exists, "checked task still checked")
            let calls = app.staticTexts.matching(identifier: "Call mom")
            let callsByLabel = app.staticTexts.matching(NSPredicate(format: "label == %@", "Call mom"))
            XCTAssertEqual(max(calls.count, callsByLabel.count), 2, "both Call mom kept, not merged")
            for i in 0..<callsByLabel.count {
                XCTAssertTrue((callsByLabel.element(boundBy: i).value as? String ?? "").contains("duplicate"), "old same-named tasks are flagged Duplicate")
            }
            for t in ["Report", "Email the boss", "Standup"] {
                let v = app.staticTexts[t].firstMatch.value as? String ?? ""
                XCTAssertFalse(v.contains("duplicate") || v.contains("late") || v.contains("today") || v.contains("pinned"),
                               "\(t) has no day, date, pin or Duplicate after the update (value: \(v))")
            }
            // (1.0.3's add row kept the last mode picked: Report's Carry Over.)
            XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label == %@", "Task options: Checkbox, Carry Over")).count, 4, "Report, Call mom ×2, Email the boss still Carry Over")
            XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label == %@", "Task options: Checkbox, Repeating")).count, 1, "Standup is still Repeating")
            XCTAssertFalse(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] %@ OR value CONTAINS[c] %@", "late", "· late")).firstMatch.exists, "nothing late")
            close("Work")

            open("Fitness")
            shot("after-open-fitness-launch\(launch)")
            XCTAssertTrue(app.staticTexts["3/7"].exists || app.descendants(matching: .any).matching(NSPredicate(format: "value CONTAINS %@", "3 of 7")).firstMatch.exists,
                          "goal progress kept (3/7)")
            XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label == %@", "Task options: Goal, Repeating")).count, 1, "Run is still a repeating goal")
            close("Fitness")

            open("Errands")
            shot("after-open-errands-launch\(launch)")
            let groceries = app.staticTexts["Groceries"].firstMatch
            XCTAssertTrue(groceries.exists, "the list kept")
            XCTAssertTrue((groceries.value as? String ?? "").contains("1 of 3 items checked"), "still folded, 1 of 3 checked (value: \(groceries.value as? String ?? ""))")
            XCTAssertFalse(app.staticTexts["Milk"].exists, "folded: items hidden")
            XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label == %@", "Task options: List, Carry Over")).count, 1, "Groceries is still a carry-over list")
            close("Errands")

            open("Trip")
            shot("after-open-trip-launch\(launch)")
            XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label == %@", "Task options: Checkbox, One-Time")).count, 2, "This week only made both one-time")
            tapButton("Edit Trip")
            let chip = app.descendants(matching: .any).matching(identifier: "Just this week chip").firstMatch
            XCTAssertTrue(chip.waitForExistence(timeout: 5), "the Just this week chip shows")
            XCTAssertEqual(chip.value as? String, "On", "1.0.3's This week only card shows the chip on")
            sleep(1)
            shot("after-trip-edit-launch\(launch)")
            tapButton("Done editing Trip")
            close("Trip")
        }
        // Next week: 1.0.3's renamed copy and deleted repeating copy.
        tapButton("Next week")
        sleep(2)
        open("Work")
        shot("after-next-week-work")
        XCTAssertTrue(app.staticTexts["Report v2"].exists, "next week's renamed copy kept its name")
        XCTAssertFalse(app.staticTexts["Standup"].exists, "next week's deleted repeating copy stays deleted")
        close("Work")
        XCTAssertFalse(card("Trip").exists, "This week only card isn't in next week")
        app.terminate()
    }

    /// The header's What's New pill shows for the updater until it's been opened twice from
    /// there; then it's gone, also after a relaunch. Settings keeps What's New.
    @MainActor
    func testWhatsNewPillTwiceThenGone() throws {
        try launchUpdated()
        let pill = app.buttons["What's New?"]
        XCTAssertTrue(pill.waitForExistence(timeout: 5), "the pill shows for someone who updated")
        shot("after-whatsnew-pill")
        for time in 1...2 {
            guard pill.waitForExistence(timeout: 5) else { XCTFail("pill gone before its \(time) open"); break }
            pill.tap()
            let cont = app.buttons["Continue"]
            XCTAssertTrue(cont.waitForExistence(timeout: 5), "What's New opens (\(time))")
            shot("after-whatsnew-sheet\(time)")
            cont.tap()
            sleep(2)
            if time == 1 {
                app.terminate(); app.launch()
                XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 10)); sleep(2)
                XCTAssertTrue(pill.waitForExistence(timeout: 5), "still there after one open and a relaunch")
            }
        }
        XCTAssertTrue(pill.waitForNonExistence(timeout: 5), "gone after two opens")
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 10)); sleep(3)
        XCTAssertFalse(pill.exists, "and stays gone after a relaunch")
        tapButton("Settings")
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "What's New in")).firstMatch
        for _ in 0..<6 where !(row.exists && row.isHittable) { app.collectionViews.firstMatch.swipeUp(velocity: .slow) }
        XCTAssertTrue(row.exists, "Settings keeps What's New")
        app.buttons["Done"].firstMatch.tap()
        app.terminate()
    }

    /// New features on tasks and cards 1.0.3 made: a day, a pin, a card pin, Just this week
    /// off; all kept through a relaunch.
    @MainActor
    func testNewFeaturesWorkOnOldItems() throws {
        try launchUpdated()
        XCTAssertFalse(XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch.exists,
                       "no notification prompt at launch (no task has a date)")
        open("Work")
        // A day on the old repeating Standup: one already gone by this week (Friday, Monday
        // start) isn't late; today's (Sunday) reads today.
        let standupOptions = app.buttons["Task options: Checkbox, Repeating"].firstMatch
        XCTAssertTrue(standupOptions.waitForExistence(timeout: 5))
        standupOptions.tap()
        let friday = app.buttons["Friday"].firstMatch
        XCTAssertTrue(friday.waitForExistence(timeout: 5), "the popup has a Day row")
        shot("after-standup-options")
        friday.tap()
        sleep(1)
        if app.buttons["Done"].exists { app.buttons["Done"].firstMatch.tap() }
        sleep(1)
        let standup = app.staticTexts["Standup"].firstMatch
        let sv = standup.value as? String ?? ""
        XCTAssertTrue(sv.contains("Friday"), "Standup has its day (value: \(sv))")
        XCTAssertFalse(sv.contains("late"), "an existing task given a day gone by isn't late (value: \(sv))")
        XCTAssertTrue(app.staticTexts["Standup"].exists, "an existing task given a past day stays put")
        // Pins: a task in the card's edit mode.
        tapButton("Edit Work")
        let pin = app.buttons.matching(identifier: "Pin Email the boss").firstMatch
        XCTAssertTrue(pin.waitForExistence(timeout: 5), "edit mode has a pin")
        pin.tap()
        sleep(1)
        shot("after-work-edit-pinned")
        tapButton("Done editing Work")
        sleep(1)
        XCTAssertTrue((app.staticTexts["Email the boss"].firstMatch.value as? String ?? "").contains("pinned"))
        close("Work")
        // Just this week off restores 1.0.3's modes.
        open("Trip")
        tapButton("Edit Trip")
        let chip = app.descendants(matching: .any).matching(identifier: "Just this week chip").firstMatch
        XCTAssertTrue(chip.waitForExistence(timeout: 5))
        chip.tap()
        sleep(1)
        XCTAssertEqual(chip.value as? String, "Off")
        tapButton("Done editing Trip")
        sleep(1)
        shot("after-trip-just-this-week-off")
        XCTAssertTrue(app.buttons["Task options: Checkbox, Carry Over"].exists, "Pack bag is Carry Over again")
        XCTAssertTrue(app.buttons["Task options: Checkbox, Repeating"].exists, "Book hotel is Repeating again")
        close("Trip")
        // A card pin in Edit.
        tapButton("Edit")
        let cardPin = app.buttons.matching(identifier: "Pin Fitness").firstMatch
        XCTAssertTrue(cardPin.waitForExistence(timeout: 5), "Edit has card pins")
        cardPin.tap()
        sleep(1)
        tapButton("Done Editing")
        sleep(1)
        XCTAssertEqual(cardOrder().first, "Fitness", "the pinned card is first")

        // Relaunch: all kept.
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 10)); sleep(2)
        shot("after-features-relaunch-grid")
        XCTAssertEqual(cardOrder().first, "Fitness", "the card pin survives a relaunch")
        open("Work")
        shot("after-features-relaunch-work")
        XCTAssertTrue((app.staticTexts["Standup"].firstMatch.value as? String ?? "").contains("Friday"), "the day survives a relaunch")
        XCTAssertTrue((app.staticTexts["Email the boss"].firstMatch.value as? String ?? "").contains("pinned"), "the pin survives a relaunch")
        close("Work")
        open("Trip")
        XCTAssertTrue(app.buttons["Task options: Checkbox, Carry Over"].exists, "Trip's modes survive a relaunch")
        close("Trip")
        app.terminate()
    }

    /// A fresh 1.1 install (no 1.0.3 data) never shows the pill. Run after `simctl uninstall`.
    @MainActor
    func testFreshInstallHasNoWhatsNewPill() throws {
        app.launch()
        guard app.staticTexts["Welcome to Tasquel"].waitForExistence(timeout: 8) else {
            throw XCTSkip("not a fresh install")
        }
        for _ in 0..<4 { app.buttons["Next"].tap() }
        app.buttons["Let's Go!"].tap()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 10)); sleep(3)
        XCTAssertFalse(app.buttons["What's New?"].exists, "no pill on a new install")
        shot("fresh-install-grid")
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 10)); sleep(3)
        XCTAssertFalse(app.buttons["What's New?"].exists, "nor on its second launch")
        app.terminate()
    }

    // MARK: - Helpers

    private func shot(_ name: String) {
        try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(shotDir)/\(name).png"))
    }

    private func card(_ name: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open \(name),")).firstMatch
    }

    /// The cards' names in reading order (rows, then columns).
    private func cardOrder() -> [String] {
        let cards = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open ")).allElementsBoundByIndex
        return cards.map { ($0.frame, $0.label) }
            .sorted { ($0.0.minY.rounded(), $0.0.minX) < ($1.0.minY.rounded(), $1.0.minX) }
            .map { String($0.1.dropFirst(5).prefix { $0 != "," }) }
            .filter { $0 != "all cards" && $0 != "All Cards" }
    }

    private func tapButton(_ label: String) {
        let b = app.buttons[label].firstMatch
        if b.waitForExistence(timeout: 5) { b.tap() } else { XCTFail("no button \(label)") }
    }

    private func open(_ name: String) {
        let c = card(name)
        guard c.waitForExistence(timeout: 5) else { XCTFail("no card \(name)"); return }
        c.tap()
        XCTAssertTrue(app.buttons["Close \(name)"].waitForExistence(timeout: 5))
        sleep(1)
    }

    private func close(_ name: String) {
        if app.keyboards.firstMatch.exists { app.buttons["Done"].firstMatch.tap() }
        tapButton("Close \(name)")
        sleep(1)
    }
}
