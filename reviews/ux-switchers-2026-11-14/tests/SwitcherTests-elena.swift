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

    /// Watch the whole welcome tour, one screenshot per page.
    func test01_tour() {
        app.launch()
        for i in 1...7 {
            snap("01-tour-p\(i)")
            let next = app.buttons["Next"]
            if next.waitForExistence(timeout: 3) && next.isHittable {
                next.tap()
            } else {
                print("REVIEW: no Next on page \(i)")
                break
            }
        }
        snap("01-tour-last")
    }

    /// Finish the tour (turn on calendar), look at the home screen, then Edit.
    func test02_homeAndEdit() {
        app.launch()
        if app.buttons["Skip"].waitForExistence(timeout: 3) {
            // tour shows again? go to last page
            for _ in 0..<5 { if app.buttons["Next"].exists { app.buttons["Next"].tap() } }
        }
        let cal = app.buttons["Turn On Calendar Events"]
        if cal.waitForExistence(timeout: 3) { cal.tap(); allowSystemAlert(); snap("02-cal-turned-on") }
        if app.buttons["Let's Go!"].waitForExistence(timeout: 3) { app.buttons["Let's Go!"].tap() }
        snap("02-home")
        app.buttons["Edit"].tap()
        snap("02-edit")
        // try tapping the first card name in edit mode
        let errands = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Errands'")).firstMatch
        if errands.exists { errands.tap(); snap("02-edit-tap-errands") }
    }

    func tapAt(_ x: CGFloat, _ y: CGFloat) {
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x, dy: y)).tap()
    }
    func pressAt(_ x: CGFloat, _ y: CGFloat, _ d: TimeInterval = 1.2) {
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x, dy: y)).press(forDuration: d)
    }

    /// Goal 1, looking: can I rename a category? Tap card title in Edit, long-press a card, open Add Category.
    func test03_categoryLook() {
        app.launch()
        // 1. long-press the Work card on the home screen
        pressAt(260, 165)
        snap("03-longpress-work")
        tapAt(200, 650) // dismiss whatever
        // 2. Edit mode, tap the Work card's title
        app.buttons["Edit"].tap()
        tapAt(245, 168)
        snap("03-edit-tap-work-title")
        tapAt(200, 650)
        // 3. Add Category
        app.buttons["Add Category"].tap()
        snap("03-add-category")
    }

    /// Goal 1: scroll saved categories, then Create New Category "Clients".
    func test04_createClients() {
        app.launch()
        app.buttons["Edit"].tap()
        app.buttons["Add Category"].tap()
        let grab = app.buttons["Sheet Grabber"]
        if grab.waitForExistence(timeout: 3) { grab.swipeUp() }
        snap("04-add-sheet-full")
        app.swipeUp()
        snap("04-add-sheet-scrolled")
        app.swipeDown()
        app.buttons["Create New Category"].tap()
        snap("04-create-new")
        let tf = app.textFields.firstMatch
        if tf.waitForExistence(timeout: 3) {
            tf.tap(); tf.typeText("Clients")
            snap("04-typed-clients")
        } else { print("REVIEW: no text field after Create New Category") }
        let iconish = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'icon' OR label CONTAINS[c] 'symbol'")).firstMatch
        if iconish.exists { print("REVIEW: icon button \(iconish.label)"); iconish.tap(); snap("04-icon-picker") }
    }

    /// The small "Add Category" button inside the sheet (not the big card).
    func sheetAddButton() -> XCUIElement? {
        let all = app.buttons.matching(NSPredicate(format: "label == 'Add Category'")).allElementsBoundByIndex
        return all.first { $0.frame.width < 160 && $0.isHittable }
    }

    func createCategory(_ name: String, iconLabel: String, iconID: String, step: String) {
        let create = app.buttons["Create New Category"]
        guard create.waitForExistence(timeout: 3) else { print("REVIEW: no Create New Category for \(name)"); return }
        create.tap()
        let tf = app.textFields["Category name"].exists ? app.textFields["Category name"] : app.textFields.firstMatch
        if tf.waitForExistence(timeout: 3) { tf.tap(); tf.typeText(name) }
        let iconBtn = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Icon:'")).firstMatch
        if iconBtn.exists {
            iconBtn.tap()
            let choice = app.buttons.matching(NSPredicate(format: "identifier == %@ AND label == %@", iconID, iconLabel)).firstMatch
            if choice.waitForExistence(timeout: 3) { choice.tap() } else { print("REVIEW: icon \(iconLabel) not found") }
        }
        snap("05-\(step)-\(name)-ready")
        if let add = sheetAddButton() { add.tap() } else { print("REVIEW: no sheet Add Category button") }
        snap("05-\(step)-\(name)-added")
    }

    /// Goal 1: create Clients, Home, Health with icons; peek at Edit Saved Categories.
    func test05_createAreas() {
        app.launch()
        app.buttons["Edit"].tap()
        app.buttons["Add Category"].firstMatch.tap()
        createCategory("Clients", iconLabel: "Work", iconID: "briefcase", step: "a")
        createCategory("Home", iconLabel: "Home", iconID: "house", step: "b")
        createCategory("Health", iconLabel: "Heart", iconID: "heart", step: "c")
        let editSaved = app.buttons["Edit Saved Categories"]
        if editSaved.exists {
            if !editSaved.isHittable { app.swipeUp() }
            editSaved.tap(); snap("05-d-edit-saved")
        }
    }

    func enterEdit() {
        if app.buttons["Edit"].exists && app.buttons["Edit"].isHittable { app.buttons["Edit"].tap() }
    }

    /// Goal 1: Home and Health, then remove the five starter categories, then Edit Saved Categories.
    func test06_areasAndCleanup() {
        app.launch()
        for (name, label, id, step) in [("Home", "Home", "house", "b"), ("Health", "Heart", "heart", "c")] {
            enterEdit()
            app.buttons.matching(NSPredicate(format: "label == 'Add Category'")).firstMatch.tap()
            createCategory(name, iconLabel: label, iconID: id, step: step)
        }
        for cat in ["Errands", "Work", "Fitness", "Study", "Appointments"] {
            enterEdit()
            let del = app.buttons["Delete \(cat)"]
            if del.waitForExistence(timeout: 3) {
                del.tap()
                let confirm = app.buttons["Delete Category"]
                if confirm.waitForExistence(timeout: 3) { confirm.tap() } else { print("REVIEW: no confirm for \(cat)") }
            } else { print("REVIEW: no delete for \(cat)") }
        }
        snap("06-after-deletes")
        if app.buttons["Done Editing"].exists { app.buttons["Done Editing"].tap() }
        snap("06-home-three-areas")
        enterEdit()
        app.buttons.matching(NSPredicate(format: "label == 'Add Category'")).firstMatch.tap()
        let editSaved = app.buttons["Edit Saved Categories"]
        if editSaved.waitForExistence(timeout: 3) {
            if !editSaved.isHittable { app.swipeUp() }
            editSaved.tap(); snap("06-edit-saved")
        }
    }

    /// Goal 2, looking: open Clients, Add Task, type the Acme title, see the options.
    func test07_acmeLook() {
        app.launch()
        app.buttons["Open Clients, no tasks yet"].tap()
        snap("07-clients-open")
        let add = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Add Task'")).firstMatch
        if add.waitForExistence(timeout: 3) { add.tap() } else { print("REVIEW: no Add Task") }
        snap("07-add-task")
        let field = app.textFields.firstMatch.exists ? app.textFields.firstMatch : app.textViews.firstMatch
        if field.waitForExistence(timeout: 3) {
            field.typeText("Acme website redesign")
            snap("07-typed-acme")
        } else { print("REVIEW: no field") }
    }

    func focused() -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "hasKeyboardFocus == true")).firstMatch
    }

    /// Goal 2: make Acme a list with three steps via the task-type options.
    func test08_acmeList() {
        app.launch()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Open Clients'")).firstMatch.tap()
        let addBtn = app.buttons["Add task"]
        if addBtn.waitForExistence(timeout: 3) { addBtn.tap() }
        let field = app.textFields["Add task"]
        _ = field.waitForExistence(timeout: 3)
        if !(field.value as? String ?? "").contains("Acme") { field.tap(); field.typeText("Acme website redesign") }
        let opts = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'New task options'")).firstMatch
        opts.tap()
        snap("08-type-options")
        let list = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'List'")).firstMatch
        if list.waitForExistence(timeout: 2) { print("REVIEW: list option \(list.label)"); list.tap() } else { print("REVIEW: no List option") }
        snap("08-list-chosen")
        let f2 = app.textFields["Add task"]
        if f2.exists { f2.tap(); f2.typeText("\n") }
        snap("08-acme-added")
        for step in ["Wireframes", "Moodboard", "Client review"] {
            let fx = focused()
            if fx.exists { print("REVIEW: focused \(fx.elementType.rawValue) \(fx.identifier) \(fx.label) [\(fx.placeholderValue ?? "")]"); fx.typeText(step); Thread.sleep(forTimeInterval: 0.4); fx.typeText("\n"); Thread.sleep(forTimeInterval: 0.4) }
            else { print("REVIEW: nothing focused for \(step)"); break }
        }
        snap("08-steps")
    }

    func openCard(_ name: String) {
        let b = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open \(name)")).firstMatch
        if b.waitForExistence(timeout: 3) { b.tap() }
    }

    /// Goal 2: Acme as a List that carries over, then its three steps.
    func test09_acmeListAdd() {
        app.launch()
        openCard("Clients")
        let addBtn = app.buttons["Add task"]
        if addBtn.waitForExistence(timeout: 3) { addBtn.tap() }
        let field = app.textFields["Add task"]
        _ = field.waitForExistence(timeout: 3)
        if !(field.value as? String ?? "").contains("Acme") { field.typeText("Acme website redesign") }
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'New task options'")).firstMatch.tap()
        app.buttons["List"].tap()
        app.buttons["Carry Over"].tap()
        snap("09-list-carry")
        app.buttons["Add Task"].tap()
        snap("09-acme-added")
        for step in ["Wireframes", "Moodboard", "Client review"] {
            let fx = focused()
            if fx.waitForExistence(timeout: 2) { print("REVIEW: focused \(fx.elementType.rawValue) id=\(fx.identifier) label=\(fx.label) ph=\(fx.placeholderValue ?? "")"); fx.typeText(step); Thread.sleep(forTimeInterval: 0.4); fx.typeText("\n"); Thread.sleep(forTimeInterval: 0.5) }
            else { print("REVIEW: nothing focused for \(step)"); break }
        }
        snap("09-steps")
    }

    /// Goal 3 + 7, looking: long-press a list item and the task, then the task's date option.
    func test10_dateLook() {
        app.launch()
        openCard("Clients")
        let item = app.staticTexts["Client review"]
        if item.waitForExistence(timeout: 3) { item.press(forDuration: 1.2); snap("10-longpress-item") }
        tapAt(200, 30) // status-bar area to dismiss
        let acme = app.staticTexts["Acme website redesign"]
        if acme.waitForExistence(timeout: 3) { acme.press(forDuration: 1.2); snap("10-longpress-acme") }
        tapAt(200, 30)
        let opts = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Task options'")).firstMatch
        if opts.waitForExistence(timeout: 3) { opts.tap(); snap("10-task-options") }
        let date = app.buttons["Add a date"]
        if date.waitForExistence(timeout: 3) { date.tap(); snap("10-add-date") } else { print("REVIEW: no Add a date") }
    }

    func closeAllCards() {
        let c = app.buttons["Close all cards"]
        if c.exists && c.isHittable { c.tap() }
    }
    func hideKeyboard() {
        let k = app.buttons.matching(identifier: "keyboard.chevron.compact.down").firstMatch
        if k.exists && k.isHittable { k.tap() }
    }
    /// The options button on the same row as a task title.
    func taskOptions(_ title: String) -> XCUIElement? {
        let t = app.staticTexts[title]
        guard t.waitForExistence(timeout: 3) else { print("REVIEW: no task \(title)"); return nil }
        let opts = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Task options'")).allElementsBoundByIndex
        return opts.first { abs($0.frame.midY - t.frame.midY) < 16 }
    }
    func addTask(_ card: String, _ title: String, _ choices: [String], snapName: String) {
        closeAllCards()
        openCard(card)
        let addBtn = app.buttons["Add task"].firstMatch
        if addBtn.waitForExistence(timeout: 3) { addBtn.tap() }
        let field = app.textFields["Add task"]
        guard field.waitForExistence(timeout: 3) else { print("REVIEW: no add field in \(card)"); return }
        if let v = field.value as? String, !v.isEmpty, v != field.placeholderValue, v != "Add task" {
            print("REVIEW: draft left in field: \(v)")
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: v.count + 3))
        }
        field.typeText(title)
        let opts = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'New task options'")).firstMatch
        print("REVIEW: new-task default in \(card): \(opts.label) placeholder=\(field.placeholderValue ?? "")")
        opts.tap()
        for c in choices { let b = app.buttons[c]; if b.waitForExistence(timeout: 2) { b.tap() } else { print("REVIEW: no choice \(c)") } }
        snap(snapName)
        let go = app.buttons["Add Task"]
        if go.waitForExistence(timeout: 2) { go.tap() } else { print("REVIEW: no Add Task in popover") }
        hideKeyboard()
    }

    /// Goals 3, 4, 5, 7 in one go.
    func test11_planning() {
        app.launch()
        // Goal 3: Acme until Tue Nov 24
        closeAllCards(); openCard("Clients")
        if let o = taskOptions("Acme website redesign") {
            o.tap()
            app.buttons["Add a date"].tap()
            app.buttons["Tuesday, November 24"].tap()
            snap("11-a-until-picked")
            app.buttons["Set"].tap()
            snap("11-a-until-set")
            if app.buttons["Done"].exists { app.buttons["Done"].firstMatch.tap() }
        }
        snap("11-a-acme-with-deadline")
        // Goal 4: two tasks for today (Saturday)
        addTask("Clients", "Send Acme invoice", ["Checkbox", "One-Time", "Saturday"], snapName: "11-b-invoice-options")
        addTask("Health", "Book dentist", ["Saturday"], snapName: "11-b-dentist-options")
        closeAllCards()
        snap("11-b-home-after-today-tasks")
        app.buttons["Day Saturday"].tap()
        snap("11-c-today-filter")
        app.buttons["Day Saturday"].tap()
        // Goal 5: Learn ceramics, look at its date options
        closeAllCards(); openCard("Home")
        let addBtn = app.buttons["Add task"].firstMatch
        if addBtn.waitForExistence(timeout: 3) { addBtn.tap() }
        let field = app.textFields["Add task"]
        if field.waitForExistence(timeout: 3) { field.typeText("Learn ceramics") }
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'New task options'")).firstMatch.tap()
        app.buttons["Add a date"].tap()
        snap("11-d-ceramics-date")
        let wk = app.buttons["Week"]
        if wk.exists { wk.tap(); snap("11-d-ceramics-week") }
    }

    /// Goals 7, 5 (and 6 by looking): swipes, tomorrow, next week, calendar, future week.
    func test12_moving() {
        app.launch()
        if app.buttons["This Week"].exists { app.buttons["This Week"].tap() }
        closeAllCards(); openCard("Health")
        let dentist = app.staticTexts["Book dentist"]
        if dentist.waitForExistence(timeout: 3) {
            dentist.tap(); snap("12-a-tap-title"); hideKeyboard()
        }
        if let o = taskOptions("Book dentist") {
            o.tap(); app.buttons["Sunday"].tap(); snap("12-b-dentist-sunday-picked")
            app.buttons["Done"].firstMatch.tap(); snap("12-b-dentist-sunday")
        }
        if let o = taskOptions("Book dentist") {
            o.tap(); app.buttons["Add a date"].tap(); snap("12-c-dentist-date")
            if app.buttons["Cancel"].exists { app.buttons["Cancel"].tap() }
            if app.buttons["Done"].exists { app.buttons["Done"].firstMatch.tap() }
        }
        closeAllCards()
        app.buttons["Calendar and events"].tap(); snap("12-d-calendar")
        if app.buttons["Weeks"].exists { app.buttons["Weeks"].tap(); snap("12-d-calendar-weeks") }
        if app.buttons["Done"].exists { app.buttons["Done"].firstMatch.tap() }
        for _ in 0..<6 { app.buttons["Next week"].tap(); Thread.sleep(forTimeInterval: 0.3) }
        snap("12-e-future-week")
        addTask("Home", "Learn ceramics", [], snapName: "12-e-ceramics-options")
        snap("12-e-ceramics-future")
        app.buttons["This Week"].tap(); snap("12-f-back-this-week")
    }

    /// Goals 7 (next week), 5 (ceramics later), 9 (fold/close), 10 (finished), Settings look.
    func test13_laterAndDone() {
        app.launch()
        if app.buttons["This Week"].exists { app.buttons["This Week"].tap() }
        closeAllCards(); openCard("Health")
        let chg = app.buttons["Change day of Book dentist"]
        if chg.waitForExistence(timeout: 3) { chg.tap(); snap("13-a-change-day") }
        tapAt(200, 690)
        closeAllCards()
        for _ in 0..<6 { app.buttons["Next week"].tap(); Thread.sleep(forTimeInterval: 0.4) }
        snap("13-b-future-week")
        addTask("Home", "Learn ceramics", [], snapName: "13-b-ceramics-options")
        snap("13-b-ceramics-future")
        app.buttons["This Week"].tap(); snap("13-b-back-this-week")
        closeAllCards(); openCard("Clients")
        for t in ["Complete Wireframes", "Complete Send Acme invoice"] {
            let b = app.buttons[t]; if b.waitForExistence(timeout: 2) { b.tap(); Thread.sleep(forTimeInterval: 0.5) } else { print("REVIEW: no \(t)") }
        }
        snap("13-c-checked")
        let fold = app.buttons["Fold Acme website redesign"]
        if fold.exists { fold.tap(); snap("13-c-folded") }
        closeAllCards(); snap("13-c-closed")
        app.buttons["Previous week"].tap(); snap("13-d-last-week")
        app.buttons["This Week"].tap()
        app.buttons["Settings"].tap(); snap("13-e-settings")
        app.swipeUp(); snap("13-e-settings-2")
        app.swipeUp(); snap("13-e-settings-3")
    }

    func pickTheme(_ name: String) {
        let b = app.buttons[name].firstMatch
        if b.waitForExistence(timeout: 3) { b.tap() } else { print("REVIEW: no theme \(name)") }
        allowSystemAlert("OK")
        Thread.sleep(forTimeInterval: 0.6)
    }

    /// Goal 8 (appearance), Help (after 3 tries on someday / next week / logbook / evening), final look.
    func test14_themesHelpFinal() {
        app.launch()
        if app.buttons["This Week"].exists { app.buttons["This Week"].tap() }
        app.buttons["Settings"].tap()
        for t in ["Dark", "Seasonal", "Retro"] {
            pickTheme(t); snap("14-a-settings-\(t)")
            app.buttons["Done"].firstMatch.tap(); closeAllCards(); openCard("Clients"); snap("14-a-home-\(t)")
            app.buttons["Settings"].tap()
        }
        pickTheme("Seasonal")
        let help = app.buttons["How to Use Tasquel"]
        if !help.isHittable { app.swipeUp() }
        help.tap(); snap("14-b-help-1")
        app.swipeUp(); snap("14-b-help-2")
        app.swipeUp(); snap("14-b-help-3")
        app.swipeUp(); snap("14-b-help-4")
        print("REVIEW-HELP-TEXT-START")
        for t in app.staticTexts.allElementsBoundByIndex { print("HELP: \(t.label)") }
        for b in app.buttons.allElementsBoundByIndex { print("HELPBTN: \(b.label)") }
    }

    /// Goal 8 (Seasonal), Help, and the end-of-day look.
    func test15_seasonalHelpFinal() {
        app.launch()
        if app.buttons["This Week"].exists { app.buttons["This Week"].tap() }
        app.buttons["Settings"].tap()
        pickTheme("Seasonal, now Fall")
        snap("15-a-settings-seasonal")
        let help = app.buttons.matching(NSPredicate(format: "label CONTAINS 'How to Use Tasquel'")).firstMatch
        var n = 0
        while !(help.exists && help.isHittable) && n < 4 { app.swipeUp(); n += 1 }
        help.tap(); snap("15-b-help-1")
        print("REVIEW-HELP-TEXT-START")
        for t in app.staticTexts.allElementsBoundByIndex { print("HELP: \(t.label)") }
        for b in app.buttons.allElementsBoundByIndex { print("HELPBTN: \(b.label)") }
        app.swipeUp(); snap("15-b-help-2")
        app.swipeUp(); snap("15-b-help-3")
        for t in app.staticTexts.allElementsBoundByIndex { print("HELP2: \(t.label)") }
    }

    func test16_finalLook() {
        app.launch()
        if app.buttons["This Week"].exists { app.buttons["This Week"].tap() }
        app.buttons["Settings"].tap()
        let help = app.buttons.matching(NSPredicate(format: "label CONTAINS 'How to Use Tasquel'")).firstMatch
        var n = 0
        while !(help.exists && help.isHittable) && n < 4 { app.swipeUp(); n += 1 }
        help.tap()
        for tab in ["Tasks", "After This Week", "Days and Dates"] {
            let b = app.buttons[tab]
            if b.waitForExistence(timeout: 3) { b.tap() } else { print("REVIEW: no tab \(tab)"); continue }
            snap("16-help-\(tab)")
            for _ in 0..<2 { app.swipeUp() }
            for t in app.staticTexts.allElementsBoundByIndex where t.label.count > 40 { print("HELP[\(tab)]: \(t.label)") }
            for _ in 0..<2 { app.swipeDown() }
        }
        app.terminate(); app.launch()
        if app.buttons["This Week"].exists { app.buttons["This Week"].tap() }
        closeAllCards(); snap("16-final-closed")
        app.buttons["Open all cards"].tap(); snap("16-final-open-all")
    }
}
