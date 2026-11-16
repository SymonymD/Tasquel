import XCTest

/// Exploratory "brand-new user" session. Learns the app only from screenshots
/// and the accessibility tree; each test is one exploration step.
final class NewUserExploreTests: XCTestCase {
    let evidence = "/private/tmp/claude-501/-Volumes-T7-Design-JB-Portfolio-SYMONYM-Tasquel/c2c1eb9b-b059-49df-87cc-82751dbd8d02/scratchpad/logic/newuser-evidence"
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = true
    }

    func launch(id: String = "nu1") {
        app = XCUIApplication()
        app.launchArguments = ["-isolatedData", "-isolatedDataID", id]
        app.launch()
        let skip = app.buttons["Skip"]
        if skip.waitForExistence(timeout: 4) {
            skip.tap()
        }
        sleep(1)
    }

    func snap(_ name: String) {
        usleep(700_000)
        try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(evidence)/\(name).png"))
        try? app.debugDescription.write(toFile: "\(evidence)/\(name).txt", atomically: true, encoding: .utf8)
        print("REVIEW: snap \(name)")
    }

    func note(_ s: String) { print("REVIEW: \(s)") }

    // MARK: - Step 0: first look

    func test00FirstLook() {
        app = XCUIApplication()
        app.launchArguments = ["-isolatedData", "-isolatedDataID", "nu1"]
        app.launch()
        sleep(2)
        snap("00a-welcome")
        let skip = app.buttons["Skip"]
        if skip.waitForExistence(timeout: 4) { skip.tap() }
        sleep(1)
        snap("00b-main")
        app.swipeUp()
        snap("00c-main-scrolled")
        app.swipeUp()
        snap("00d-main-scrolled2")
    }

    func listInputs() {
        for f in app.textFields.allElementsBoundByIndex { note("textField id=\(f.identifier) label=\(f.label) ph=\(f.placeholderValue ?? "") val=\(f.value ?? "")") }
        for f in app.textViews.allElementsBoundByIndex { note("textView id=\(f.identifier) label=\(f.label) ph=\(f.placeholderValue ?? "") val=\(f.value ?? "")") }
    }

    /// Goal 1: Errands card -> add two tasks. The card says "No tasks yet · Tap to add".
    func test01Errands() {
        launch()
        app.buttons["Open Errands, no tasks yet"].tap()
        sleep(1)
        snap("01a-tap-errands")
        app.buttons["Add task"].tap()
        sleep(1)
        snap("01a2-tap-add-task")
        listInputs()
        let field = app.textFields.firstMatch.exists ? app.textFields.firstMatch : app.textViews.firstMatch
        if field.exists {
            if !field.hasKeyboardFocusSafe { field.tap() }
            field.typeText("Buy milk")
            snap("01b-typed-milk")
            field.typeText("\n")
            usleep(500_000)
            snap("01c-after-return")
            listInputs()
            let f2 = app.textFields.firstMatch.exists ? app.textFields.firstMatch : app.textViews.firstMatch
            if f2.exists {
                if !f2.hasKeyboardFocusSafe { f2.tap() }
                f2.typeText("Pick up dry cleaning")
                f2.typeText("\n")
                snap("01d-after-second")
            }
        } else {
            note("no text input after tapping card")
        }
    }
}

extension NewUserExploreTests {
    func dismissKeyboardIntro() {
        let c = app.buttons["Continue"]
        if c.exists && c.isHittable { c.tap(); usleep(400_000) }
    }

    func dumpButtons(_ tag: String) {
        for b in app.buttons.allElementsBoundByIndex where b.exists {
            let l = b.label
            if l.hasPrefix("Day ") || l.contains("November") { continue }
            note("\(tag) button id=\(b.identifier) label=\(l)")
        }
    }

    func addTask(_ text: String) {
        let f = app.textFields["Add task"]
        if !f.hasKeyboardFocusSafe { f.tap() }
        f.typeText(text)
        f.typeText("\n")
        usleep(500_000)
        dismissKeyboardIntro()
    }

    func hideKeyboard() {
        let d = app.buttons["Done"]
        if d.exists && d.isHittable { d.tap(); usleep(500_000) }
    }

    /// Goal 2: Gym weekly. The pill next to each task says "Task options: Checkbox, One-Time".
    func test02GymWeekly() {
        launch()
        app.buttons["Open Fitness, no tasks yet"].tap()
        sleep(1)
        app.buttons["Add task"].tap()
        sleep(1)
        addTask("Gym")
        hideKeyboard()
        snap("02a-gym-added")
        let opts = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Task options'")).firstMatch
        opts.tap()
        sleep(1)
        snap("02b-gym-options")
        dumpButtons("02b")
    }

    /// Goal 2 continued (Gym exists) + Goal 3 start.
    func test02bRepeatAndBirthday() {
        launch()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Open Fitness'")).firstMatch.tap()
        sleep(1)
        if !app.buttons["Task options: Checkbox, Repeating"].exists {
            app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Task options'")).firstMatch.tap()
            sleep(1)
            app.buttons["Repeating"].tap()
            sleep(1)
            snap("02c-repeating-selected")
            app.buttons["Done"].tap()
            sleep(1)
            snap("02d-gym-repeating")
        }

        // Goal 3: Mom's birthday -> Appointments looks right for a date.
        app.buttons["Close Fitness"].tap()
        sleep(1)
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Open Appointments'")).firstMatch.tap()
        sleep(1)
        app.buttons["Add task"].tap()
        sleep(1)
        addTask("Mom's birthday")
        hideKeyboard()
        snap("03a-bday-added")
        let opts = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Task options: ' AND label CONTAINS 'One-Time'")).allElementsBoundByIndex
        note("one-time option pills: \(opts.count)")
        // The one in Appointments: pick the last hittable
        if let o = opts.last(where: { $0.isHittable }) { o.tap() }
        sleep(1)
        app.buttons["Add a date"].tap()
        sleep(1)
        snap("03b-add-a-date")
        dumpButtons("03b")
        for d in app.datePickers.allElementsBoundByIndex { note("datePicker \(d.label) \(String(describing: d.value))") }
        for s in app.switches.allElementsBoundByIndex { note("switch \(s.label) \(String(describing: s.value))") }
    }

    func openCard(_ name: String) {
        if app.buttons["Close \(name)"].exists { return }
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open \(name)")).firstMatch.tap()
        sleep(1)
    }

    func optionsPill(for task: String) -> XCUIElement {
        // The pill sits on the same row as "Complete <task>"
        let row = app.buttons["Complete \(task)"]
        let pills = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Task options'")).allElementsBoundByIndex
        let y = row.frame.midY
        return pills.min(by: { abs($0.frame.midY - y) < abs($1.frame.midY - y) }) ?? pills[0]
    }

    /// Goal 3: Try the "Until" calendar on Mom's birthday, pick Dec 5.
    func test03BirthdayDate() {
        launch()
        openCard("Appointments")
        optionsPill(for: "Mom's birthday").tap()
        sleep(1)
        app.buttons["Add a date"].tap()
        sleep(1)
        app.buttons["Next month"].tap()
        sleep(1)
        app.buttons["Saturday, December 5"].tap()
        sleep(1)
        snap("03c-dec5-picked")
        app.buttons["Set"].tap()
        sleep(1)
        snap("03d-after-set")
        dumpButtons("03d")
        for t in app.staticTexts.allElementsBoundByIndex where t.frame.minY > 130 { note("03d text: \(t.label)") }
        app.buttons["Done"].tap()
        sleep(1)
        snap("03e-row-after-date")
        dumpButtons("03e")
    }

    func closeAllCards() {
        let c = app.buttons["Close all cards"]
        if c.exists { c.tap(); sleep(1) }
    }

    /// Goal 3 retry: is there a reminder? Tap the green clock, tap the title, long-press the title.
    func test03bBirthdayReminderHunt() {
        launch()
        closeAllCards()
        openCard("Appointments")
        let title = app.staticTexts["Mom's birthday"]
        // 1. the little green clock just right of the title
        let clockPoint = title.coordinate(withNormalizedOffset: CGVector(dx: 1.0, dy: 0.5)).withOffset(CGVector(dx: -40, dy: 0))
        note("title frame \(title.frame)")
        clockPoint.tap()
        sleep(1)
        snap("03f-tap-clock")
        dumpButtons("03f")
        for t in app.staticTexts.allElementsBoundByIndex where t.frame.minY > 130 && t.frame.minY < 780 { note("03f text: \(t.label)") }
        listInputs()
        hideKeyboard()
        // 2. long-press the title
        let t2 = app.staticTexts["Mom's birthday"]
        if t2.waitForExistence(timeout: 3) {
            t2.press(forDuration: 1.2)
            sleep(1)
            snap("03h-longpress-title")
            dumpButtons("03h")
            for t in app.staticTexts.allElementsBoundByIndex where t.frame.minY > 130 && t.frame.minY < 780 { note("03h text: \(t.label)") }
        } else { note("title static text gone after edit") }
    }

    /// Goal 3 / 12: Settings, look for reminders and appearance.
    func test03cSettingsLook() {
        launch()
        closeAllCards()
        app.buttons["Settings"].tap()
        sleep(2)
        snap("12a-settings")
        dumpButtons("12a")
        for t in app.staticTexts.allElementsBoundByIndex { note("12a text: \(t.label)") }
        for s in app.switches.allElementsBoundByIndex { note("12a switch: \(s.label) = \(String(describing: s.value))") }
        app.swipeUp()
        sleep(1)
        snap("12b-settings-scrolled")
        for t in app.staticTexts.allElementsBoundByIndex { note("12b text: \(t.label)") }
        for s in app.switches.allElementsBoundByIndex { note("12b switch: \(s.label) = \(String(describing: s.value))") }
        app.swipeUp()
        sleep(1)
        snap("12c-settings-scrolled2")
        for t in app.staticTexts.allElementsBoundByIndex { note("12c text: \(t.label)") }
    }

    /// Goal 4: grocery list. No Groceries card; Errands is closest. Add "Groceries", make it a List.
    func test04GroceryList() {
        launch()
        closeAllCards()
        openCard("Errands")
        app.buttons["Add task"].tap()
        sleep(1)
        addTask("Groceries")
        hideKeyboard()
        optionsPill(for: "Groceries").tap()
        sleep(1)
        app.buttons["List"].tap()
        sleep(1)
        snap("04a-list-selected")
        for t in app.staticTexts.allElementsBoundByIndex where t.frame.minY > 130 && t.frame.minY < 600 { note("04a text: \(t.label)") }
        app.buttons["Done"].tap()
        sleep(1)
        snap("04b-groceries-list")
        dumpButtons("04b")
        listInputs()
    }
}

extension NewUserExploreTests {
    func dumpTexts(_ tag: String) {
        for t in app.staticTexts.allElementsBoundByIndex where t.exists && t.frame.minY > 130 && t.frame.minY < 790 { note("\(tag) text: \(t.label)") }
    }

    func dumpAll(_ tag: String) {
        dumpButtons(tag)
        dumpTexts(tag)
        for s in app.steppers.allElementsBoundByIndex { note("\(tag) stepper: \(s.label) \(String(describing: s.value))") }
        for s in app.sliders.allElementsBoundByIndex { note("\(tag) slider: \(s.label) \(String(describing: s.value))") }
        for s in app.switches.allElementsBoundByIndex { note("\(tag) switch: \(s.label) \(String(describing: s.value))") }
        listInputs()
    }

    /// Goal 4 continued: "Add Item" under Groceries.
    func test04bGroceryItems() {
        launch()
        closeAllCards()
        openCard("Errands")
        app.buttons["Add item to Groceries"].tap()
        sleep(1)
        snap("04c-add-item-tapped")
        listInputs()
        for item in ["Eggs", "Bread", "Apples"] {
            let f = app.textFields.matching(NSPredicate(format: "hasKeyboardFocus == true")).firstMatch
            let field = f.exists ? f : app.textFields.element(boundBy: 0)
            field.typeText(item)
            field.typeText("\n")
            usleep(600_000)
            dismissKeyboardIntro()
        }
        snap("04d-items-typed")
        listInputs()
        hideKeyboard()
        snap("04e-grocery-list-done")
        dumpButtons("04e")
        closeAllCards()
        snap("04f-collapsed")
    }

    /// Goal 7: rename (tap title, seen in 03f), then look for delete: swipe left, then the card's pencil.
    func test07RenameDelete() {
        launch()
        closeAllCards()
        openCard("Work")
        app.buttons["Add task"].tap()
        sleep(1)
        addTask("Call plumber")
        hideKeyboard()
        app.staticTexts["Call plumber"].tap()
        sleep(1)
        let f = app.textFields["Task name"]
        note("rename field exists: \(f.exists)")
        f.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 7))
        f.typeText("electrician")
        snap("07a-renaming")
        f.typeText("\n")
        sleep(1)
        hideKeyboard()
        snap("07b-renamed")
        dumpTexts("07b")
        // Delete attempt 1: swipe left on the row
        let row = app.staticTexts["Call electrician"]
        if row.exists {
            row.swipeLeft()
            sleep(1)
            snap("07c-swipe-left")
            dumpButtons("07c")
        } else { note("renamed row not found") }
        // Delete attempt 2: the pencil on the card
        if app.buttons["Edit Work"].exists {
            app.buttons["Edit Work"].tap()
            sleep(1)
            snap("07d-card-edit-mode")
            dumpAll("07d")
        }
    }

    /// Goal 5: run 3 times this week. Fitness -> add "Run" -> Goal type.
    func test05GoalRun() {
        launch()
        closeAllCards()
        openCard("Fitness")
        app.buttons["Add task"].tap()
        sleep(1)
        addTask("Run")
        hideKeyboard()
        optionsPill(for: "Run").tap()
        sleep(1)
        app.buttons["Goal"].tap()
        sleep(1)
        snap("05a-goal-selected")
        dumpAll("05a")
    }

    /// Goal 5 continued: Run is a Goal with a "Target" field and "Set" behind the popover.
    func test05bGoalTarget() {
        launch()
        closeAllCards()
        openCard("Fitness")
        snap("05b-fitness-with-goal-row")
        dumpAll("05b")
        let target = app.textFields["Target"].exists ? app.textFields["Target"] : app.textFields.matching(NSPredicate(format: "placeholderValue == 'Target'")).firstMatch
        target.tap()
        sleep(1)
        snap("05c-target-tapped")
        target.typeText("3")
        snap("05d-target-3")
        if app.buttons["Set"].exists { app.buttons["Set"].tap() } else { target.typeText("\n") }
        sleep(1)
        hideKeyboard()
        snap("05e-goal-set")
        dumpAll("05e")
        // Log one run: tap whatever is on the left of the Run row
        let runBtn = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Run' AND NOT (label BEGINSWITH 'Add sub-task') AND NOT (label BEGINSWITH 'Task options')")).firstMatch
        note("05 run button: \(runBtn.label) value=\(String(describing: runBtn.value))")
        runBtn.tap()
        sleep(1)
        snap("05f-after-one-tap")
        dumpAll("05f")
    }

    /// Goal 5 end: log one run with "+1".
    func test05cLogRun() {
        launch()
        closeAllCards()
        openCard("Fitness")
        app.buttons["Add 1"].tap()
        sleep(1)
        snap("05g-one-run-logged")
        let p = app.otherElements["Run progress"]
        note("05g run progress value: \(String(describing: p.value))")
        closeAllCards()
        snap("05h-collapsed-after-run")
    }

    /// Goal 7: delete. Swipe-left changed week (07c). Try the card's pencil (edit mode) with a task in it.
    func test07bDeleteViaCardEdit() {
        launch()
        closeAllCards()
        openCard("Work")
        snap("07e-work-this-week")
        app.buttons["Edit Work"].tap()
        sleep(1)
        snap("07f-work-edit-mode")
        dumpAll("07f")
        let del = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'delete' OR label CONTAINS[c] 'remove' OR identifier CONTAINS[c] 'minus' OR identifier CONTAINS[c] 'trash'")).allElementsBoundByIndex
        for d in del { note("07f delete-ish: id=\(d.identifier) label=\(d.label) hittable=\(d.isHittable)") }
        if let d = del.first(where: { $0.label.contains("electrician") || $0.label.contains("Call") }) ?? del.first(where: { $0.isHittable }) {
            d.tap()
            usleep(300_000)
            snap("07g-just-deleted")
            dumpAll("07g")
            sleep(2)
            snap("07h-2s-after-delete")
            dumpButtons("07h")
        }
    }

    func springboardAlerts(_ tag: String) {
        let sb = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for a in sb.alerts.allElementsBoundByIndex { note("\(tag) SPRINGBOARD ALERT: \(a.label)") }
        if sb.alerts.count == 0 { note("\(tag) no springboard alert") }
    }

    /// Goal 7 end: delete then Undo; then measure how long the Undo toast stays.
    /// Also Goal 3 alt path: the clock in card edit mode.
    func test07cUndoAndClock() {
        launch()
        closeAllCards()
        openCard("Work")
        app.buttons["Add task"].tap(); sleep(1)
        addTask("Water plants")
        addTask("Temp task")
        hideKeyboard()
        app.buttons["Edit Work"].tap(); sleep(1)
        // Goal 3 alt: the clock
        app.buttons["Set expiration for Water plants"].tap(); sleep(1)
        snap("03i-card-edit-clock")
        dumpAll("03i")
        springboardAlerts("03i")
        if app.buttons["Cancel"].exists { app.buttons["Cancel"].tap(); sleep(1) }
        // delete + undo
        app.buttons["Delete Water plants"].tap()
        usleep(300_000)
        let undo = app.buttons["Undo delete"]
        note("undo visible right after delete: \(undo.exists)")
        undo.tap()
        sleep(1)
        snap("07i-after-undo")
        dumpTexts("07i")
        // measure toast lifetime with the throwaway task
        if !app.buttons["Delete Temp task"].exists { app.buttons["Edit Work"].tap(); sleep(1) }
        app.buttons["Delete Temp task"].tap()
        let start = Date()
        var last = 0.0
        while Date().timeIntervalSince(start) < 15 {
            if app.buttons["Undo delete"].exists { last = Date().timeIntervalSince(start) } else if last > 0 { break }
            usleep(250_000)
        }
        note("undo toast visible for about \(String(format: "%.1f", last)) s")
        snap("07j-toast-gone")
        // any other way back? look at bottom bar / edit
        dumpButtons("07j")
    }

    /// Goal 8: Edit -> pin Appointments; then try hold-and-drag Study to the top-left.
    func test08bPinAndDrag() {
        launch()
        closeAllCards()
        app.buttons["Edit"].tap(); sleep(1)
        app.buttons["Pin Appointments to the top"].tap(); sleep(1)
        snap("08c-pinned-appointments")
        dumpButtons("08c")
        let study = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Open Study'")).firstMatch
        let anyCard = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Open Errands'")).firstMatch
        note("study exists \(study.exists) frame \(study.frame); errands frame \(anyCard.frame)")
        if study.exists && anyCard.exists {
            study.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 1.0, thenDragTo: anyCard.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.3)))
            sleep(1)
            snap("08d-after-drag-study")
            dumpButtons("08d")
        } else {
            // cards in edit mode may not be "Open" buttons; dump everything
            dumpAll("08d-nocards")
        }
        if app.buttons["Done Editing"].exists { app.buttons["Done Editing"].tap(); sleep(1) }
        snap("08e-after-done")
    }

    /// Goal 10: Edit -> Add Category -> "Garden".
    func test10NewCard() {
        launch()
        closeAllCards()
        app.buttons["Edit"].tap(); sleep(1)
        app.buttons["Add Category"].tap(); sleep(1)
        snap("10a-add-category")
        dumpAll("10a")
    }

    /// Goal 10 continued: Create New Category -> Garden.
    func test10bGarden() {
        launch()
        closeAllCards()
        if !app.buttons["Done Editing"].exists { app.buttons["Edit"].tap(); sleep(1) }
        app.buttons["Add Category"].tap(); sleep(1)
        app.buttons["Create New Category"].tap(); sleep(1)
        snap("10b-create-new")
        dumpAll("10b")
        let f = app.textFields.matching(NSPredicate(format: "hasKeyboardFocus == true")).firstMatch
        let field = f.exists ? f : app.textFields.element(boundBy: 0)
        if !field.hasKeyboardFocusSafe { field.tap() }
        field.typeText("Garden")
        dismissKeyboardIntro()
        snap("10c-typed-garden")
        dumpButtons("10c")
    }

    /// Goal 10 finish: confirm "Garden" with the blue "Add Category" button.
    func test10cGardenConfirm() {
        launch()
        closeAllCards()
        if !app.buttons["Done Editing"].exists { app.buttons["Edit"].tap(); sleep(1) }
        app.buttons["Add Category"].tap(); sleep(1)
        app.buttons["Create New Category"].tap(); sleep(1)
        let f = app.textFields["Category name"].exists ? app.textFields["Category name"] : app.textFields.element(boundBy: 0)
        if !f.hasKeyboardFocusSafe { f.tap() }
        f.typeText("Garden")
        dismissKeyboardIntro()
        // The confirm button in the Create New row (lowest "Add Category" button on screen)
        let adds = app.buttons.matching(NSPredicate(format: "label == 'Add Category'")).allElementsBoundByIndex.filter { $0.isHittable }
        note("add category buttons hittable: \(adds.count) frames \(adds.map { $0.frame })")
        if let confirm = adds.max(by: { $0.frame.minY < $1.frame.minY }) { confirm.tap() }
        sleep(1)
        snap("10d-after-add")
        dumpTexts("10d")
        if app.buttons["Done"].exists && app.buttons["Done"].isHittable { app.buttons["Done"].tap(); sleep(1) }
        if app.buttons["Done Editing"].exists { app.buttons["Done Editing"].tap(); sleep(1) }
        snap("10e-main-with-garden")
        dumpButtons("10e")
    }

    /// Goal 3 check: does iOS list Tasquel under Notifications (i.e. did the app ever ask)?
    func test03dNotificationPermission() {
        let prefs = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        prefs.launch()
        sleep(2)
        let n = prefs.descendants(matching: .any).matching(NSPredicate(format: "label == 'Notifications'")).firstMatch
        note("notifications row exists: \(n.exists)")
        if n.exists { n.tap() } else { try? prefs.debugDescription.write(toFile: "\(evidence)/03k-prefs-root.txt", atomically: true, encoding: .utf8) }
        sleep(2)
        try? prefs.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(evidence)/03k-ios-notifications.png"))
        for _ in 0..<3 where !prefs.staticTexts["Tasquel"].exists { prefs.swipeUp(); sleep(1) }
        try? prefs.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(evidence)/03l-ios-notifications-scrolled.png"))
        try? prefs.debugDescription.write(toFile: "\(evidence)/03l-ios-notifications.txt", atomically: true, encoding: .utf8)
        note("Tasquel listed under iOS Notifications: \(prefs.staticTexts["Tasquel"].exists)")
        prefs.terminate()
    }

    /// Goal 8 alt: hold-and-drag in Edit mode (coordinates), plus check reminder permission after setting a date.
    func test08cDragAndPermission() {
        launch()
        closeAllCards()
        if app.buttons["Done Editing"].exists { app.buttons["Done Editing"].tap(); sleep(1) }
        app.buttons["Edit"].tap(); sleep(1)
        let from = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 106, dy: 508))
        let to = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 300, dy: 210))
        from.press(forDuration: 1.0, thenDragTo: to)
        sleep(1)
        snap("08d-after-drag-study")
        app.buttons["Done Editing"].tap(); sleep(1)
        snap("08e-after-done")
        // reminder permission: set a last day via the card clock and watch for an iOS prompt
        openCard("Work")
        app.buttons["Edit Work"].tap(); sleep(1)
        app.buttons["Set expiration for Water plants"].tap(); sleep(1)
        app.buttons["Next month"].tap(); sleep(1)
        app.buttons["Friday, December 4"].tap(); sleep(1)
        app.buttons["Set"].tap(); sleep(2)
        springboardAlerts("03j")
        snap("03j-after-clock-set")
        dumpTexts("03j")
    }

    /// Goal 11: a Friday-only task. Today is Saturday.
    func test11Friday() {
        launch()
        closeAllCards()
        openCard("Study")
        app.buttons["Add task"].tap(); sleep(1)
        addTask("Review notes")
        hideKeyboard()
        optionsPill(for: "Review notes").tap(); sleep(1)
        app.buttons["Friday"].tap(); sleep(1)
        snap("11a-friday-picked")
        dumpTexts("11a")
        app.buttons["Done"].tap(); sleep(1)
        snap("11b-friday-row")
        dumpAll("11b")
        app.buttons["Day Friday"].tap(); sleep(1)
        snap("11c-tap-friday-pill")
        dumpTexts("11c")
    }

    /// Goal 12: Settings -> Dark, look at main, then back to System.
    func test12Dark() {
        launch()
        closeAllCards()
        app.buttons["Settings"].tap(); sleep(1)
        app.buttons["Dark"].tap(); sleep(1)
        snap("12d-dark-selected")
        app.buttons["Done"].tap(); sleep(1)
        snap("12e-main-dark")
        app.buttons["Settings"].tap(); sleep(1)
        app.buttons["System"].tap(); sleep(1)
        app.buttons["Done"].tap(); sleep(1)
    }

    /// Goal 8 / 10: the bottom-right "Edit" button.
    func test08EditButton() {
        launch()
        closeAllCards()
        app.buttons["Edit"].tap()
        sleep(1)
        snap("08a-edit-mode")
        dumpAll("08a")
        app.swipeUp()
        sleep(1)
        snap("08b-edit-mode-scrolled")
        dumpButtons("08b")
    }

    /// Goal 9: next week, add something, come back.
    func test09NextWeek() {
        launch()
        closeAllCards()
        app.buttons["Next week"].tap()
        sleep(1)
        snap("09a-next-week")
        dumpAll("09a")
        openCard("Errands")
        snap("09b-next-week-errands")
        app.buttons["Add task"].tap()
        sleep(1)
        addTask("Return library books")
        hideKeyboard()
        snap("09c-next-week-added")
        dumpTexts("09c")
        // Come back: the top-left logo button is labelled "This Week"
        app.buttons["This Week"].tap()
        sleep(1)
        snap("09d-back-this-week")
        dumpTexts("09d")
    }

    /// Goal 13: last week.
    func test13LastWeek() {
        launch()
        closeAllCards()
        app.buttons["Previous week"].tap()
        sleep(1)
        snap("13a-last-week")
        dumpAll("13a")
        app.buttons["Open all cards"].tap()
        sleep(1)
        snap("13b-last-week-all-open")
        dumpTexts("13b")
        app.buttons["This Week"].tap()
        sleep(1)
        app.buttons["Go to week"].tap()
        sleep(1)
        snap("13c-go-to-week")
        dumpAll("13c")
    }

    /// Goal 6: check off Buy milk, then un-check it.
    func test06CheckUncheck() {
        launch()
        closeAllCards()
        openCard("Errands")
        app.buttons["Complete Buy milk"].tap()
        sleep(1)
        snap("06a-checked")
        dumpButtons("06a")
        dumpTexts("06a")
        let b = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Buy milk' AND NOT (label BEGINSWITH 'Add sub-task')")).firstMatch
        note("06 row button now: \(b.label)")
        b.tap()
        sleep(1)
        snap("06b-unchecked")
        dumpButtons("06b")
    }
}

extension XCUIElement {
    var hasKeyboardFocusSafe: Bool { (value(forKey: "hasKeyboardFocus") as? Bool) ?? false }
}
