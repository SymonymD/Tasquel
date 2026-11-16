import XCTest

/// A first-time user's session in Tasquel. Every test launches with the same throwaway
/// data (`-isolatedDataID`), so each run continues where the last one left off. To start
/// completely fresh, change `dataID`.
final class SwitcherTests: XCTestCase {
    static let dataID = "switcher-1"
    var app: XCUIApplication!
    let shotDir = ProcessInfo.processInfo.environment["SHOT_DIR"] ?? NSTemporaryDirectory()

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments = ["-isolatedDataID", Self.dataID, "-smartAddRules", "-fakeCalendar"]
    }

    /// A screenshot and the accessibility tree, saved as <name>.png and <name>.txt.
    func snap(_ name: String) {
        Thread.sleep(forTimeInterval: 0.8)
        try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(shotDir)/\(name).png"))
        try? app.debugDescription.write(toFile: "\(shotDir)/\(name).txt", atomically: true, encoding: .utf8)
    }

    /// Taps a system alert's button (notifications, calendar) if one is showing.
    func allowSystemAlert(_ button: String = "Allow") {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let b = springboard.alerts.buttons[button]
        if b.waitForExistence(timeout: 2) { b.tap() }
    }

    func test00_firstLaunch() {
        app.launch()
        snap("00-first-launch")
    }

    /// Prints every hittable button label, for deciding what to try next.
    func listButtons(_ tag: String) {
        for b in app.buttons.allElementsBoundByIndex where b.exists && b.isHittable {
            print("REVIEW: [\(tag)] button '\(b.label)' id='\(b.identifier)' frame=\(b.frame)")
        }
    }

    /// Skims the welcome tour: Next quickly, screenshot each page.
    func test01_tour() {
        app.launch()
        for i in 1...7 {
            snap(String(format: "01-tour-%02d", i))
            listButtons("tour\(i)")
            let next = app.buttons["Next"]
            if next.exists && next.isHittable { next.tap(); continue }
            // last page: tap the big bottom button, whatever it says
            let bottom = app.buttons.allElementsBoundByIndex.filter { $0.exists && $0.isHittable && $0.frame.minY > 700 && $0.label != "Skip" }
            if let b = bottom.first { print("REVIEW: tapping final '\(b.label)'"); b.tap() }
            break
        }
        allowSystemAlert()
        snap("01-after-tour")
        listButtons("after-tour")
    }

    /// Prints hittable text fields / text views and their values/placeholders.
    func listFields(_ tag: String) {
        for f in app.textFields.allElementsBoundByIndex where f.exists {
            print("REVIEW: [\(tag)] textField label='\(f.label)' ph='\(f.placeholderValue ?? "")' value='\(f.value ?? "")' id='\(f.identifier)' hittable=\(f.isHittable)")
        }
        for f in app.textViews.allElementsBoundByIndex where f.exists {
            print("REVIEW: [\(tag)] textView label='\(f.label)' ph='\(f.placeholderValue ?? "")' value='\(f.value ?? "")' id='\(f.identifier)' hittable=\(f.isHittable)")
        }
    }

    /// Goal 1: Take out trash every Tuesday. First try: open Errands.
    func test02_openErrands() {
        app.launch()
        app.buttons["Open Errands, no tasks yet"].tap()
        snap("02-errands-open")
        listButtons("errands")
        listFields("errands")
        let add = app.buttons["Add Task"]
        if add.waitForExistence(timeout: 2) {
            add.tap()
            snap("02-errands-addtask")
            listButtons("addtask")
            listFields("addtask")
        } else { print("REVIEW: no Add Task button") }
    }

    /// No Family list. Tour said "Tap Edit at the bottom to add or delete categories."
    func test03_editCategories() {
        app.launch()
        app.buttons["Edit"].tap()
        snap("03-edit-mode")
        listButtons("edit")
        listFields("edit")
    }

    /// Add Category: see what it asks for.
    func test04_addCategorySheet() {
        app.launch()
        app.buttons["Edit"].tap()
        app.buttons["Add Category"].tap()
        snap("04-add-category")
        listButtons("addcat")
        listFields("addcat")
        for t in app.staticTexts.allElementsBoundByIndex where t.exists && t.isHittable { print("REVIEW: [addcat] text '\(t.label)'") }
    }

    func hittableTexts(_ tag: String) {
        for t in app.staticTexts.allElementsBoundByIndex where t.exists && t.isHittable { print("REVIEW: [\(tag)] text '\(t.label)'") }
    }

    /// Create New Category -> Family.
    func test05_createFamily() {
        app.launch()
        app.buttons["Edit"].tap()
        app.buttons["Add Category"].tap()
        app.buttons["Create New Category"].tap()
        snap("05-create-new")
        listButtons("create")
        listFields("create")
        hittableTexts("create")
    }

    /// Taps the first hittable button with this label (sheets can hide same-named buttons behind them).
    @discardableResult
    func tapHittable(_ label: String, _ q: XCUIElementQuery? = nil) -> Bool {
        let query = q ?? app.buttons
        for b in query.matching(identifier: label).allElementsBoundByIndex where b.exists && b.isHittable { b.tap(); return true }
        for b in query.allElementsBoundByIndex where b.exists && b.label == label && b.isHittable { b.tap(); return true }
        print("REVIEW: could not tap '\(label)'")
        return false
    }

    func dismissKeyboardTip() {
        let c = app.buttons["Continue"]
        if c.exists && c.isHittable { c.tap() }
    }

    /// Name it Family, add it, close the sheet, finish editing, open Family, tap Add task.
    func test06_familyAndAddTask() {
        app.launch()
        app.buttons["Edit"].tap()
        app.buttons["Add Category"].tap()
        app.buttons["Create New Category"].tap()
        dismissKeyboardTip()
        let name = app.textFields["Category name"]
        name.tap()
        name.typeText("Family")
        snap("06-family-typed")
        tapHittable("Add Category")
        snap("06-family-added")
        hittableTexts("added")
        tapHittable("Done")
        if app.buttons["Done Editing"].waitForExistence(timeout: 2) { app.buttons["Done Editing"].tap() }
        snap("06-home-with-family")
        listButtons("home")
        let fam = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Open Family'")).firstMatch
        if fam.waitForExistence(timeout: 2) {
            fam.tap()
            app.buttons["Add task"].firstMatch.tap()
            dismissKeyboardTip()
            snap("06-family-addtask")
            listButtons("addtask")
            listFields("addtask")
            hittableTexts("addtask")
        }
    }

    func openCard(_ name: String) {
        let c = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open \(name)")).firstMatch
        if c.waitForExistence(timeout: 3) { c.tap() } else { print("REVIEW: no card \(name)") }
    }

    /// Goal 1: type "Take out trash" in Family and press return.
    func test07_trashTyped() {
        app.launch()
        openCard("Family")
        snap("07-family-opened")
        tapHittable("Add task")
        let field = app.textFields["Add task"]
        if !field.waitForExistence(timeout: 2) { print("REVIEW: no field"); return }
        dismissKeyboardTip()
        field.typeText("Take out trash")
        snap("07-trash-typed")
        listButtons("typed")
        field.typeText("\n")
        snap("07-trash-return")
        listButtons("after-return")
        listFields("after-return")
        hittableTexts("after-return")
    }

    /// Goal 1: make it repeat. Tour: "tap the icons at the end of a task to choose."
    func test08_trashOptions() {
        app.launch()
        openCard("Family")
        snap("08-family")
        let opt = app.buttons["Task options: Checkbox, One-Time"].firstMatch
        if opt.waitForExistence(timeout: 2) { opt.tap() } else { print("REVIEW: no options btn"); return }
        snap("08-trash-options")
        listButtons("opts")
        hittableTexts("opts")
        for m in app.menuItems.allElementsBoundByIndex { print("REVIEW: [opts] menuItem '\(m.label)'") }
    }

    /// Goal 1: Repeating + Tuesday, then Done. Look for any time/alert.
    func test09_trashRepeatTuesday() {
        app.launch()
        openCard("Family")
        app.buttons["Task options: Checkbox, One-Time"].firstMatch.tap()
        tapHittable("Repeating")
        snap("09-repeating")
        hittableTexts("rep")
        tapHittable("Tuesday")
        snap("09-tuesday")
        hittableTexts("tue")
        listButtons("tue")
        tapHittable("Done")
        snap("09-trash-done")
        listButtons("done")
        hittableTexts("done")
    }

    func typeInto(_ card: String, _ text: String) -> XCUIElement? {
        openCard(card)
        tapHittable("Add task")
        let field = app.textFields["Add task"]
        if !field.waitForExistence(timeout: 2) { print("REVIEW: no field in \(card)"); return nil }
        dismissKeyboardTip()
        field.typeText(text)
        return field
    }

    /// Goal 2: Dentist this Thursday 3 PM. Reminders-style: type it all, see what the sparkles do.
    func test10_dentistSmartAdd() {
        app.launch()
        guard typeInto("Appointments", "Dentist appointment Thursday at 3pm") != nil else { return }
        snap("10-dentist-typed")
        tapHittable("Smart Add")
        snap("10-dentist-smartadd")
        listButtons("smart")
        listFields("smart")
        hittableTexts("smart")
    }

    func dumpTask(_ name: String, _ tag: String) {
        for t in app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", name)).allElementsBoundByIndex where t.exists {
            print("REVIEW: [\(tag)] task '\(t.label)' value='\(t.value ?? "")'")
        }
    }

    /// Goal 2: what did Smart Add do? Then tap the day chip to look for a time.
    func test11_dentistDay() {
        app.launch()
        openCard("Appointments")
        snap("11-appointments")
        dumpTask("Dentist", "appt")
        let chip = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Change day of Dentist'")).firstMatch
        if chip.waitForExistence(timeout: 2) { chip.tap() } else { print("REVIEW: no day chip"); return }
        snap("11-dentist-daychip")
        listButtons("chip")
        hittableTexts("chip")
        for p in app.datePickers.allElementsBoundByIndex { print("REVIEW: [chip] datePicker '\(p.label)' \(p.value ?? "")") }
    }

    func listPickers(_ tag: String) {
        for p in app.datePickers.allElementsBoundByIndex where p.exists { print("REVIEW: [\(tag)] datePicker '\(p.label)' value='\(p.value ?? "")' frame=\(p.frame)") }
        for p in app.pickerWheels.allElementsBoundByIndex where p.exists { print("REVIEW: [\(tag)] wheel value='\(p.value ?? "")'") }
        for s in app.switches.allElementsBoundByIndex where s.exists && s.isHittable { print("REVIEW: [\(tag)] switch '\(s.label)' value='\(s.value ?? "")'") }
    }

    /// Goal 2: it went to the Thursday that already passed. Open options -> calendar button.
    func test12_dentistDatePicker() {
        app.launch()
        openCard("Appointments")
        let opt = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Task options'")).firstMatch
        opt.tap()
        snap("12-dentist-options")
        hittableTexts("opts")
        tapHittable("Add a date")
        snap("12-dentist-addadate")
        listButtons("date")
        hittableTexts("date")
        listPickers("date")
    }

    /// Goal 2: "Until ... Pick the task's last day". I guess that's the due date: Thursday Nov 19.
    func test13_dentistUntil19() {
        app.launch()
        openCard("Appointments")
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Task options'")).firstMatch.tap()
        tapHittable("Add a date")
        tapHittable("Thursday, November 19")
        snap("13-dentist-19-picked")
        hittableTexts("picked")
        tapHittable("Set")
        snap("13-dentist-set")
        hittableTexts("set")
        listButtons("set")
        tapHittable("Done")
        snap("13-dentist-after")
        dumpTask("Dentist", "after")
    }

    var focusedField: XCUIElement {
        let f = app.textFields.matching(NSPredicate(format: "hasKeyboardFocus == true")).firstMatch
        if f.exists { return f }
        return app.textViews.matching(NSPredicate(format: "hasKeyboardFocus == true")).firstMatch
    }

    func closeAllCards() {
        let c = app.buttons["Close all cards"]
        if c.exists && c.isHittable { c.tap() }
    }

    /// Goal 3 (passport, ~6 weeks out) and goal 4 (Family tasks + party steps).
    func test14_passportAndFamily() {
        app.launch()
        closeAllCards()
        // Goal 3: try typing it naturally first.
        if let f = typeInto("Family", "Renew passport by December 26") {
            tapHittable("Smart Add")
            Thread.sleep(forTimeInterval: 2)
            snap("14-passport-smartadd")
            hittableTexts("passport")
            dumpTask("passport", "passport")
            _ = f
        }
        // Goal 4: the Family tasks, typed plainly one per line.
        let field = app.textFields["Add task"]
        if field.waitForExistence(timeout: 2) {
            if !field.isHittable { tapHittable("Add task") }
            for t in ["Sign permission slip", "Buy birthday gift for Ava", "Plan Ava's party"] {
                field.tap()
                field.typeText(t)
                Thread.sleep(forTimeInterval: 0.4)
                field.typeText("\n")
                Thread.sleep(forTimeInterval: 0.6)
            }
        }
        snap("14-family-three")
        dumpTask("", "family")
        // Steps for the party: the + next to the task said "Add sub-task to …"
        let plus = app.buttons["Add sub-task to Plan Ava's party"]
        if plus.waitForExistence(timeout: 2) {
            plus.tap()
            snap("14-subtask-field")
            listFields("sub")
            for t in ["order cake", "send invites", "book bounce house"] {
                let f = focusedField
                if !f.exists { print("REVIEW: no focused field for \(t)"); break }
                f.typeText(t)
                Thread.sleep(forTimeInterval: 0.4)
                f.typeText("\n")
                Thread.sleep(forTimeInterval: 0.6)
            }
            snap("14-subtasks-typed")
        } else { print("REVIEW: no sub-task plus") }
        let kb = app.buttons["Done"].firstMatch
        if kb.exists && kb.isHittable && kb.identifier == "keyboard.chevron.compact.down" { kb.tap() }
        snap("14-family-final")
        dumpTask("", "final")
        listButtons("final")
    }

    func listMenus(_ tag: String) {
        for m in app.menuItems.allElementsBoundByIndex where m.exists { print("REVIEW: [\(tag)] menuItem '\(m.label)'") }
        for m in app.collectionViews.buttons.allElementsBoundByIndex where m.exists && m.isHittable { print("REVIEW: [\(tag)] cvButton '\(m.label)'") }
    }

    func dismissPopover() {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)).tap()
        Thread.sleep(forTimeInterval: 0.5)
    }

    /// The "Task options" button on the same row as a task.
    func optionsFor(_ task: String) -> XCUIElement? {
        let t = app.staticTexts[task].firstMatch
        guard t.waitForExistence(timeout: 2) else { return nil }
        let y = t.frame.midY
        for b in app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Task options'")).allElementsBoundByIndex where b.exists {
            if abs(b.frame.midY - y) < 25 { return b }
        }
        return nil
    }

    /// Goal 5: flag "Sign permission slip". Try long-press, swipe, then look at the row.
    /// First: the passport date I skipped (the "Set Date" suggestion vanished when I kept typing).
    func test15_flag() {
        app.launch()
        closeAllCards()
        openCard("Family")
        if let o = optionsFor("Renew passport by December 26") {
            o.tap()
            tapHittable("Add a date")
            for b in app.buttons.allElementsBoundByIndex where b.exists && b.frame.minY > 330 && b.frame.minY < 460 && !b.label.contains("November") {
                print("REVIEW: [picker] btn '\(b.label)' id='\(b.identifier)' frame=\(b.frame) hit=\(b.isHittable)")
            }
            tapHittable("Date")
            tapHittable("Next month")
            Thread.sleep(forTimeInterval: 0.6)
            snap("15-passport-december")
            if tapHittable("Saturday, December 26") {
                hittableTexts("pp")
                tapHittable("Set")
                snap("15-passport-set")
                hittableTexts("ppset")
                tapHittable("Done")
            } else { tapHittable("Cancel"); dismissPopover() }
            dumpTask("passport", "pp")
        } else { print("REVIEW: no passport options") }
        let row = app.staticTexts["Sign permission slip"].firstMatch
        guard row.waitForExistence(timeout: 3) else { print("REVIEW: no slip row"); return }
        // Try 1: long-press the task
        row.press(forDuration: 1.2)
        snap("15-slip-longpress")
        listMenus("longpress")
        listButtons("longpress")
        listFields("longpress")
        dismissPopover()
        // Try 2: swipe left on the task
        let row2 = app.staticTexts["Sign permission slip"].firstMatch
        if row2.exists { row2.swipeLeft() }
        snap("15-slip-swipeleft")
        listButtons("swipeleft")
        dismissPopover()
        // Try 3: swipe right
        let row3 = app.staticTexts["Sign permission slip"].firstMatch
        if row3.exists { row3.swipeRight() }
        snap("15-slip-swiperight")
        listButtons("swiperight")
    }

    /// Goal 6: what do I need to do today? Tap today's pill, then the calendar button.
    func test16_today() {
        app.launch()
        closeAllCards()
        snap("16-home")
        let today = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Today'")).firstMatch
        if today.waitForExistence(timeout: 2) { today.tap() }
        snap("16-today-pill")
        hittableTexts("todaypill")
        listButtons("todaypill")
        dismissPopover()
        closeAllCards()
        tapHittable("Go to week")
        snap("16-calendar-btn")
        hittableTexts("cal")
        listButtons("cal")
    }

    /// Goal 7: share Groceries with my spouse. Try long-press card, the pencil, then Settings.
    func test17_share() {
        app.launch()
        closeAllCards()
        let fam = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Open Family'")).firstMatch
        if fam.waitForExistence(timeout: 2) { fam.press(forDuration: 1.2) }
        snap("17-card-longpress")
        listMenus("cardlp")
        hittableTexts("cardlp")
        dismissPopover()
        closeAllCards()
        openCard("Family")
        tapHittable("Edit Family")
        snap("17-edit-family")
        listButtons("editfam")
        hittableTexts("editfam")
        listFields("editfam")
    }

    /// Goal 7/10: Settings, every screen of it.
    func test18_settings() {
        app.launch()
        closeAllCards()
        tapHittable("Settings")
        Thread.sleep(forTimeInterval: 1)
        for i in 1...6 {
            snap(String(format: "18-settings-%02d", i))
            hittableTexts("set\(i)")
            for b in app.buttons.allElementsBoundByIndex where b.exists && b.isHittable { print("REVIEW: [set\(i)] button '\(b.label)'") }
            for sw in app.switches.allElementsBoundByIndex where sw.exists && sw.isHittable { print("REVIEW: [set\(i)] switch '\(sw.label)' = \(sw.value ?? "")") }
            app.swipeUp()
            Thread.sleep(forTimeInterval: 0.5)
        }
    }

    /// Goal 8: check off "Sign permission slip", then find it again later.
    func test19_checkOff() {
        app.launch()
        closeAllCards()
        openCard("Family")
        // Goal 5 (found by accident in the pencil's edit mode): pin it to the top as my "flag".
        tapHittable("Edit Family")
        tapHittable("Pin Sign permission slip to the top")
        snap("19-slip-pinned-edit")
        tapHittable("Done editing Family")
        snap("19-slip-pinned")
        dumpTask("", "pinned")
        tapHittable("Complete Sign permission slip")
        Thread.sleep(forTimeInterval: 1.5)
        snap("19-slip-checked")
        hittableTexts("checked")
        dumpTask("Sign permission", "checked")
        closeAllCards()
        snap("19-closed-cards")
        let fam = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Open Family'")).firstMatch
        print("REVIEW: [closed] family card label '\(fam.label)'")
        tapHittable("Next week")
        Thread.sleep(forTimeInterval: 1)
        openCard("Family")
        snap("19-next-week-family")
        hittableTexts("nextweek")
        closeAllCards()
        tapHittable("Previous week")
        Thread.sleep(forTimeInterval: 1)
        openCard("Family")
        snap("19-back-this-week")
        hittableTexts("back")
    }

    /// Goal 9: fastest add, typed like Siri. Errands is the first card.
    func test20_plumber() {
        app.launch()
        closeAllCards()
        guard typeInto("Errands", "remind me to call the plumber tomorrow at 9") != nil else { return }
        snap("20-plumber-typed")
        tapHittable("Smart Add")
        Thread.sleep(forTimeInterval: 2.5)
        snap("20-plumber-smartadd")
        hittableTexts("plumber")
        listButtons("plumber")
        dumpTask("lumber", "plumber")
    }

    /// Last resort: Help, for time-of-day reminders, flags, sharing, Siri. Read every tab.
    func test21_help() {
        app.launch()
        closeAllCards()
        tapHittable("Settings")
        let h = app.buttons["How to Use Tasquel"]
        for _ in 0..<4 where !(h.exists && h.isHittable) { app.swipeUp() }
        h.tap()
        Thread.sleep(forTimeInterval: 1)
        var tabs: [String] = []
        for b in app.buttons.allElementsBoundByIndex where b.exists && b.frame.minY > 145 && b.frame.minY < 165 && !b.frame.isEmpty && !b.label.hasPrefix("Open ") { tabs.append(b.label) }
        print("REVIEW: [help] tabs \(tabs)")
        var all = ""
        for (n, tab) in tabs.enumerated() {
            let b = app.buttons[tab].firstMatch
            if b.exists { b.tap() }
            Thread.sleep(forTimeInterval: 0.8)
            snap(String(format: "21-help-tab%02d", n + 1))
            all += "=== TAB \(tab)\n"
            var seen = Set<String>()
            for _ in 0..<6 {
                for t in app.staticTexts.allElementsBoundByIndex where t.exists && t.frame.minY > 190 && t.frame.minY < 874 {
                    if !seen.contains(t.label) { seen.insert(t.label); all += t.label + "\n" }
                }
                app.swipeUp()
                Thread.sleep(forTimeInterval: 0.3)
            }
            for _ in 0..<6 { app.swipeDown(); Thread.sleep(forTimeInterval: 0.2) }
        }
        try? all.write(toFile: "\(shotDir)/21-help-alltext.txt", atomically: true, encoding: .utf8)
    }

    /// Goal 10: long-press the app icon for quick actions / widget. Then the end-of-day look.
    func test22_iconAndEndOfDay() {
        app.launch()
        closeAllCards()
        // Retry the pin (goal 5): did it stick last time?
        openCard("Family")
        tapHittable("Edit Family")
        Thread.sleep(forTimeInterval: 0.8)
        let pin = app.buttons["Pin Sign permission slip"]
        if pin.waitForExistence(timeout: 2) {
            print("REVIEW: [pin] before '\(pin.label)' value='\(pin.value ?? "")' selected=\(pin.isSelected)")
            pin.tap()
            Thread.sleep(forTimeInterval: 1)
            print("REVIEW: [pin] after '\(pin.label)' value='\(pin.value ?? "")' selected=\(pin.isSelected)")
            snap("22-pin-edit")
        }
        tapHittable("Done editing Family")
        Thread.sleep(forTimeInterval: 1)
        snap("22-pin-after")
        closeAllCards()
        snap("22-end-of-day-this-week")
        let fam = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Open Family'")).firstMatch
        print("REVIEW: [eod] \(fam.label)")
        for b in app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Open '")).allElementsBoundByIndex { print("REVIEW: [eod] card '\(b.label)'") }
        tapHittable("Next week")
        Thread.sleep(forTimeInterval: 1)
        snap("22-end-of-day-next-week")
        for b in app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Open '")).allElementsBoundByIndex { print("REVIEW: [eod-next] card '\(b.label)'") }
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 1.5)
        let sb = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let icon = sb.icons["Tasquel"]
        var tries = 0
        while !icon.isHittable && tries < 4 { sb.swipeLeft(); Thread.sleep(forTimeInterval: 0.6); tries += 1 }
        if icon.exists {
            icon.press(forDuration: 1.5)
            Thread.sleep(forTimeInterval: 1)
            try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(shotDir)/22-icon-longpress.png"))
            for b in sb.buttons.allElementsBoundByIndex where b.exists && b.isHittable { print("REVIEW: [icon] button '\(b.label)'") }
            sb.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)).tap()
        } else { print("REVIEW: no icon found") }
    }
}
