import XCTest

/// Update review, step 4–5 (run in the NEW copy, installed over the live 1.0.2 build): the data
/// ReviewUpdateSeed (old copy) saved in the simulator's real storage must load unchanged, and
/// the new features must work on it. These tests need that seed: run them through
/// `shots/update_check.sh`, which uninstalls the app, seeds with 1.0.2, installs the new build
/// over it and runs them in order. Each test launches cold on the real storage (no
/// -isolatedData) and puts back what it changes, so they can run in any order after the seed.
final class ReviewUpdateCheck: XCTestCase {
    private var app: XCUIApplication!

    @MainActor
    override func setUp() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchArguments = []  // the real storage 1.0.2 saved
        launch()
    }

    @MainActor
    private func launch() {
        app.launch()
        XCTAssertFalse(app.staticTexts["Welcome to Tasquel"].waitForExistence(timeout: 3),
                       "an updating user isn't shown onboarding again")
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 8))
    }

    @MainActor
    private func relaunch() {
        app.terminate()
        launch()
    }

    // MARK: Step 4: everything from 1.0.2 is still there and means the same

    /// Every card, task, type, mode, check, goal amount and item from 1.0.2, after the update
    /// and after two more cold launches.
    @MainActor
    func testOldDataLoadsIntactAcrossRelaunches() throws {
        for pass in 1...3 {
            assertThisWeek(pass: pass)
            if pass < 3 { relaunch() }
        }
    }

    /// Next week was saved by 1.0.2 (a task added there). Its carried and repeating copies
    /// are still there, reset the way they were (repeating unchecked, carry-over as left),
    /// and no one-time or this-week-only task came along. The week after (a preview) too.
    @MainActor
    func testCarryOverAndRepeatingCopiesFromOldData() throws {
        for (week, saved) in [(1, true), (2, false)] {
            app.buttons["Next week"].tap()
            sleep(1)
            open("Errands")
            XCTAssertTrue(app.buttons["Task options: List, Carry Over"].exists, "w+\(week): Groceries carried")
            XCTAssertTrue(app.staticTexts["Groceries"].exists)
            XCTAssertTrue(app.buttons["Task options: Checkbox, Repeating"].exists, "w+\(week): Laundry repeats")
            XCTAssertTrue(app.buttons["Complete Wash"].exists, "w+\(week): a repeating copy's sub-task starts unchecked")
            XCTAssertTrue(app.staticTexts["Buy stamps"].exists, "w+\(week): carry-over Buy stamps carried")
            XCTAssertFalse(app.staticTexts["Pay rent"].exists, "w+\(week): a done one-time task stays behind")
            XCTAssertFalse(app.staticTexts["Old note"].exists, "w+\(week): the deleted task stays deleted")
            if saved { XCTAssertTrue(app.staticTexts["Next week task"].exists, "next week's own task") }
            XCTAssertEqual(count("Groceries"), 1, "w+\(week): no duplicate copies")
            XCTAssertEqual(count("Laundry"), 1)
            app.buttons["Close Errands"].tap()

            open("Fitness")
            XCTAssertTrue(app.staticTexts["0/10"].exists, "w+\(week): the repeating goal starts again at 0")
            XCTAssertTrue(app.staticTexts["Stretch"].exists, "w+\(week): the carry-over goal carried")
            // A repeating list keeps its checks (resetRecurringTask's keepsItems), as in 1.0.2.
            XCTAssertTrue(app.buttons["Mark Shoes incomplete"].exists, "w+\(week): a repeating list keeps its checks")
            XCTAssertTrue(app.buttons["Complete Towel"].exists)
            app.buttons["Close Fitness"].tap()

            XCTAssertFalse(card("Trip").exists, "w+\(week): a this-week-only category doesn't come back")
            XCTAssertFalse(card("Work").exists, "w+\(week): nor does Work, this week only in 1.0.2")
        }
    }

    /// Settings saved by 1.0.2 (Dark) are kept.
    @MainActor
    func testOldSettingsKept() throws {
        app.buttons["Settings"].tap()
        let dark = app.buttons["Dark"]
        XCTAssertTrue(dark.waitForExistence(timeout: 3))
        XCTAssertTrue(dark.isSelected, "Dark is still the theme")
        app.buttons["Done"].firstMatch.tap()
    }

    /// The first save in the new version rewrites the 1.0.2 file: tick an item, relaunch,
    /// and everything is still there, with the tick. Then untick it again.
    @MainActor
    func testFirstSaveInNewVersionKeepsEverything() throws {
        open("Errands")
        app.buttons["Complete Milk"].tap()
        XCTAssertTrue(app.buttons["Mark Milk incomplete"].waitForExistence(timeout: 2))
        relaunch()
        open("Errands")
        XCTAssertTrue(app.buttons["Mark Milk incomplete"].waitForExistence(timeout: 3), "the tick was saved")
        app.buttons["Close Errands"].tap()
        assertThisWeek(pass: 4, milkChecked: true)
        relaunch()
        open("Errands")
        app.buttons["Mark Milk incomplete"].tap()
        XCTAssertTrue(app.buttons["Complete Milk"].waitForExistence(timeout: 2))
        relaunch()
        assertThisWeek(pass: 5)
    }

    // MARK: Step 5: new features on 1.0.2 data

    /// Lists from 1.0.2 load open, fold (count shown, items hidden), stay folded after a
    /// relaunch, and next week's copy (saved by 1.0.2) and the preview after it are folded
    /// too. Opened again at the end.
    @MainActor
    func testOldListsLoadOpenAndFold() throws {
        open("Errands")
        let fold = app.buttons["Fold Groceries"]
        XCTAssertTrue(fold.waitForExistence(timeout: 3), "an old list has the chevron")
        XCTAssertEqual(fold.label, "Collapse list", "a 1.0.2 list loads open")
        XCTAssertTrue(app.staticTexts["Bread"].exists)
        fold.tap()
        XCTAssertTrue(app.staticTexts["1 of 3 items checked"].waitForExistence(timeout: 2), "folded: the count")
        XCTAssertFalse(app.staticTexts["Bread"].exists, "folded: the items are hidden")
        XCTAssertTrue(app.buttons["Task options: List, Carry Over"].exists, "folding didn't change the mode")
        shot("after-fold-groceries")

        relaunch()
        open("Errands")
        XCTAssertTrue(app.staticTexts["1 of 3 items checked"].waitForExistence(timeout: 3), "still folded after a relaunch")
        app.buttons["Close Errands"].tap()

        for week in 1...2 {
            app.buttons["Next week"].tap()
            sleep(1)
            open("Errands")
            XCTAssertEqual(app.buttons["Fold Groceries"].label, "Expand list", "w+\(week): the copy is folded too")
            shot("after-fold-groceries-w\(week)")
            app.buttons["Close Errands"].tap()
        }
        app.buttons["Previous week"].tap(); sleep(1)
        app.buttons["Previous week"].tap(); sleep(1)
        open("Errands")
        app.buttons["Fold Groceries"].tap()
        XCTAssertTrue(app.staticTexts["Bread"].waitForExistence(timeout: 2), "opens again")
    }

    /// Work had This week only turned on in 1.0.2, which made its carry-over and repeating
    /// tasks one-time for good (no remembered mode). Turned off in the new version, they stay
    /// one-time, nothing is lost, the app keeps running, and it lasts a relaunch. Turned back
    /// on at the end.
    @MainActor
    func testThisWeekOnlyOffOnOldCardKeepsTasksOneTime() throws {
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Work, this week only")).firstMatch.exists)
        open("Work")
        app.buttons["Edit Work"].tap()
        let toggle = app.switches["This week only"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 3))
        XCTAssertEqual(toggle.value as? String, "1", "on, as 1.0.2 left it")
        toggle.switches.firstMatch.tap()
        XCTAssertEqual(toggle.value as? String, "0")
        XCTAssertEqual(app.state, .runningForeground)
        app.buttons["Done editing Work"].tap()
        assertWorkOneTime()
        shot("after-work-this-week-only-off")

        relaunch()
        XCTAssertTrue(card("Work").exists)
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Work, this week only")).firstMatch.exists,
                       "off after a relaunch")
        open("Work")
        assertWorkOneTime()
        // Put it back on, as the seed left it.
        app.buttons["Edit Work"].tap()
        let again = app.switches["This week only"]
        XCTAssertTrue(again.waitForExistence(timeout: 3))
        again.switches.firstMatch.tap()
        XCTAssertEqual(again.value as? String, "1")
        app.buttons["Done editing Work"].tap()
    }

    /// This week only on a 1.0.2 card that never had it (Errands): on makes its carry-over and
    /// repeating tasks one-time, off puts each one's mode back exactly.
    @MainActor
    func testThisWeekOnlyRoundTripOnOldTasks() throws {
        open("Errands")
        app.buttons["Edit Errands"].tap()
        let toggle = app.switches["This week only"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 3))
        XCTAssertEqual(toggle.value as? String, "0")
        toggle.switches.firstMatch.tap()
        XCTAssertTrue(app.buttons["Task options: List, One-Time"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["Task options: Checkbox, Repeating"].exists)
        toggle.switches.firstMatch.tap()
        XCTAssertTrue(app.buttons["Task options: List, Carry Over"].waitForExistence(timeout: 2), "Groceries carry-over again")
        XCTAssertTrue(app.buttons["Task options: Checkbox, Repeating"].exists, "Laundry repeating again")
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label == %@", "Task options: Checkbox, Carry Over")).count, 1,
                       "Buy stamps carry-over again")
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label == %@", "Task options: Checkbox, One-Time")).count, 1,
                       "Pay rent stays one-time")
        app.buttons["Done editing Errands"].tap()
        relaunch()
        // Next week still has the copies (they didn't leave for good while it was on).
        app.buttons["Next week"].tap()
        sleep(1)
        open("Errands")
        XCTAssertTrue(app.staticTexts["Groceries"].exists, "next week's Groceries is back")
        XCTAssertTrue(app.staticTexts["Laundry"].exists, "next week's Laundry is back")
        XCTAssertTrue(app.staticTexts["Next week task"].exists, "next week's own task kept")
        shot("after-roundtrip-errands-w1")
    }

    // MARK: Findings

    /// FINDING: 1.0.2 let a carry-over copy arrive in a later week's This week only card
    /// (seed: next week's Study, Flashcards). 1.0.3 makes such arrivals one-time, but leaves
    /// the old one as it is: it still says Carry Over in a card whose note says it won't come
    /// back, and the week after it's gone. Should read One-Time (remembering Carry Over).
    @MainActor
    func testOldCarryOverCopyInThisWeekOnlyCardIsOneTime() throws {
        app.buttons["Next week"].tap()
        sleep(1)
        open("Study")
        XCTAssertTrue(app.staticTexts["Flashcards"].exists)
        shot("finding-old-carryover-in-this-week-only")
        XCTAssertFalse(app.buttons["Task options: List, Carry Over"].exists,
                       "a task in a This week only card shouldn't say Carry Over: it won't carry")
        XCTAssertTrue(app.buttons["Task options: List, One-Time"].exists)
    }

    // MARK: Helpers

    /// This week's 1.0.2 content, card by card.
    @MainActor
    private func assertThisWeek(pass: Int, milkChecked: Bool = false) {
        let tag = "pass \(pass)"
        for name in ["Errands", "Fitness", "Work", "Trip", "Study", "Appointments"] {
            XCTAssertTrue(card(name).waitForExistence(timeout: 3), "\(tag): card \(name)")
        }
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Trip, this week only")).firstMatch.exists, "\(tag): Trip this week only")

        open("Errands")
        XCTAssertTrue(app.buttons["Task options: List, Carry Over"].exists, "\(tag): Groceries")
        XCTAssertTrue(app.buttons["Mark Eggs incomplete"].exists, "\(tag): Eggs checked")
        XCTAssertTrue(app.buttons[milkChecked ? "Mark Milk incomplete" : "Complete Milk"].exists, "\(tag): Milk")
        XCTAssertTrue(app.buttons["Complete Bread"].exists, "\(tag): Bread")
        XCTAssertTrue(app.buttons["Task options: Checkbox, Repeating"].exists, "\(tag): Laundry repeating")
        XCTAssertTrue(app.buttons["Mark Wash incomplete"].exists, "\(tag): Wash checked")
        XCTAssertTrue(app.buttons["Complete Fold"].exists, "\(tag): Fold")
        XCTAssertTrue(app.buttons["Mark Pay rent incomplete"].exists, "\(tag): Pay rent done")
        XCTAssertTrue(app.staticTexts["Buy stamps"].exists, "\(tag): the renamed task")
        XCTAssertFalse(app.staticTexts["Buy"].exists, "\(tag): not its old name")
        XCTAssertFalse(app.staticTexts["Old note"].exists, "\(tag): the deleted task stays deleted")
        XCTAssertEqual(count("Groceries"), 1, "\(tag): no duplicates")
        app.buttons["Close Errands"].tap()

        open("Fitness")
        XCTAssertTrue(app.staticTexts["4/10"].exists, "\(tag): Run 4/10")
        XCTAssertTrue(app.buttons["Task options: Goal, Repeating"].exists, "\(tag): Run repeating")
        XCTAssertTrue(app.staticTexts["9m / 1h"].exists, "\(tag): Stretch 9m / 1h")
        XCTAssertTrue(app.buttons["Task options: Goal, Carry Over"].exists, "\(tag): Stretch carry-over")
        XCTAssertTrue(app.buttons["Add 9 minutes"].exists, "\(tag): Stretch's step")
        XCTAssertTrue(app.buttons["Task options: List, Repeating"].exists, "\(tag): Gym bag")
        XCTAssertTrue(app.buttons["Mark Shoes incomplete"].exists, "\(tag): Shoes checked")
        XCTAssertTrue(app.buttons["Complete Towel"].exists, "\(tag): Towel")
        app.buttons["Close Fitness"].tap()

        open("Work")
        assertWorkOneTime()
        app.buttons["Close Work"].tap()

        open("Trip")
        XCTAssertTrue(app.staticTexts["Pack"].exists, "\(tag): Pack")
        app.buttons["Close Trip"].tap()
    }

    /// Work's three tasks, one-time (as 1.0.2 made them), with Inbox's item.
    @MainActor
    private func assertWorkOneTime() {
        for title in ["Report", "Standup", "Inbox", "Reply"] {
            XCTAssertTrue(app.staticTexts[title].exists, "Work: \(title)")
        }
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label == %@", "Task options: Checkbox, One-Time")).count, 2,
                       "Report and Standup one-time")
        XCTAssertTrue(app.buttons["Task options: List, One-Time"].exists, "Inbox one-time")
    }

    @MainActor
    private func card(_ name: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open \(name),")).firstMatch
    }

    @MainActor
    private func open(_ name: String) {
        let button = card(name)
        XCTAssertTrue(button.waitForExistence(timeout: 5), "card \(name)")
        button.tap()
        XCTAssertTrue(app.buttons["Close \(name)"].waitForExistence(timeout: 3))
        usleep(500_000)
    }

    @MainActor
    private func count(_ title: String) -> Int {
        app.staticTexts.matching(NSPredicate(format: "label == %@", title)).count
    }

    @MainActor
    private func shot(_ name: String) {
        sleep(1)
        let dir = ProcessInfo.processInfo.environment["SHOT_DIR"] ?? NSTemporaryDirectory()
        try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
    }
}
