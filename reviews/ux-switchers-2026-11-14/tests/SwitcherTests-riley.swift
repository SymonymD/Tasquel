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

    /// Riley watches the whole tour, tapping Next on each page.
    func test01_tour() {
        app.launch()
        for i in 1...8 {
            let next = app.buttons["Next"]
            if next.waitForExistence(timeout: 3) && next.isHittable {
                next.tap()
                snap("01-tour-\(i)")
            } else {
                break
            }
        }
        // Last page: list buttons so I can see what ends the tour
        let names = app.buttons.allElementsBoundByIndex.map { $0.label }
        print("REVIEW: buttons at end of tour: \(names)")
        snap("01-tour-end")
    }

    /// Finish the tour with "Let's Go!" (skip calendar: keep it simple), look at home, open Errands.
    func test02_home() {
        app.launch()
        let go = app.buttons["Let's Go!"]
        let skip = app.buttons["Skip"]
        if skip.waitForExistence(timeout: 3) { skip.tap() } else if go.exists { go.tap() }
        snap("02-home")
        app.buttons["Open Errands, no tasks yet"].tap()
        snap("02-errands-open")
    }

    /// Goal 1, try 1: Errands has a cart icon, so groceries go there. Tap Add Task and look.
    func test03_addTask() {
        app.launch()
        let errands = app.buttons["Open Errands, no tasks yet"]
        if errands.waitForExistence(timeout: 3) { errands.tap() }
        app.buttons["Add task"].tap()
        snap("03-add-task")
    }

    /// Dismiss the keyboard tip (iOS's, not the app's)
    func dismissKeyboardTip() {
        let cont = app.buttons["Continue"]
        if cont.waitForExistence(timeout: 1) { cont.tap() }
    }

    /// Goal 1, try 2: type "Groceries" (the tour said lists are "like Groceries"), then tap the
    /// little icons beside the field to make it a list.
    func test04_groceriesList() {
        app.launch()
        let errands = app.buttons["Open Errands, no tasks yet"]
        if errands.waitForExistence(timeout: 3) { errands.tap() }
        app.buttons["Add task"].tap()
        dismissKeyboardTip()
        let field = app.textFields["Add task"]
        field.typeText("Groceries")
        snap("04-typed-groceries")
        app.buttons["New task options: Checkbox, One-Time"].tap()
        snap("04-options")
        app.popovers.buttons["List"].tap()
        snap("04-list-chosen")
        app.popovers.buttons["Add Task"].tap()
        snap("04-groceries-added")
    }

    /// Opens a closed card by its name, if it's closed.
    func openCard(_ name: String) {
        let card = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open \(name)")).firstMatch
        if card.waitForExistence(timeout: 3) { card.tap() }
    }

    func dump(_ tag: String) {
        let labels = app.buttons.allElementsBoundByIndex.map { $0.label }
        print("REVIEW: \(tag) buttons: \(labels)")
    }

    /// Goal 1, part 2: type the five items, one per line like Notes, then check off milk and bread.
    func test05_groceryItems() {
        app.launch()
        snap("05-relaunch")
        openCard("Errands")
        var item = app.textFields["Add item"]
        if !item.waitForExistence(timeout: 2) {
            // Groceries might be folded; look for an Add Item control
            dump("no add-item field")
            let addItemBtn = app.buttons["Add item to Groceries"]
            if addItemBtn.exists { addItemBtn.tap() }
            item = app.textFields["Add item"]
        }
        item.tap()
        dismissKeyboardTip()
        for word in ["milk", "eggs", "bread", "bananas", "coffee"] {
            app.typeText(word + "\n")
            Thread.sleep(forTimeInterval: 0.5)
        }
        snap("05-items-typed")
        // put the keyboard away like a person: tap the keyboard Done button
        let done = app.buttons["Done"]
        if done.exists { done.tap() }
        snap("05-items-done")
        dump("after items")
    }

    /// Goal 1, part 3: shopping. Tap the circles by milk and bread.
    /// Goal 2, try 1: done shopping. Look for what happened, then long-press Groceries for a menu.
    func test06_shopping() {
        app.launch()
        openCard("Errands")
        app.buttons["Complete milk"].tap()
        snap("06-milk-checked")
        app.buttons["Complete bread"].tap()
        snap("06-bread-checked")
        dump("after checking")
        // Goal 2: In Notes I'd look for "Uncheck All". Long-press the Groceries title.
        app.staticTexts["Groceries"].press(forDuration: 1.2)
        snap("06-longpress-groceries")
        dump("after long-press")
    }

    /// Goal 2, tries 2-3: swipe the Groceries row for actions; then the icons at the end of the task.
    func test07_readyForNextWeek() {
        app.launch()
        openCard("Errands")
        app.staticTexts["Groceries"].swipeLeft()
        snap("07-swipe-groceries")
        dump("after swipe")
        // The swipe went to next week! Tap the green house to come back.
        app.buttons["Back to This Week"].tap()
        snap("07-back-home")
        openCard("Errands")
        app.buttons["Task options: List, One-Time"].tap()
        snap("07-task-options")
        let pop = app.popovers.firstMatch
        if pop.waitForExistence(timeout: 2) {
            print("REVIEW: popover texts: \(pop.staticTexts.allElementsBoundByIndex.map { $0.label })")
            print("REVIEW: popover buttons: \(pop.buttons.allElementsBoundByIndex.map { $0.label })")
        }
        app.popovers.buttons["Repeating"].tap()
        snap("07-repeating-chosen")
        if app.popovers.firstMatch.exists {
            print("REVIEW: popover after repeating: \(app.popovers.firstMatch.staticTexts.allElementsBoundByIndex.map { $0.label }) \(app.popovers.firstMatch.buttons.allElementsBoundByIndex.map { $0.label })")
            app.otherElements["PopoverDismissRegion"].tap()
        }
        snap("07-after-repeating")
        dump("after repeating")
        // Peek at next week to check the list is waiting, unchecked
        app.buttons["Next week"].tap()
        snap("07-next-week")
        dump("next week")
        app.buttons["Previous week"].tap()
        snap("07-back")
    }

    /// Goal 2, try 4: next week still shows milk and bread checked, though it said "unchecked".
    /// Uncheck them there, then see what this week looks like. Then peek at the pencil icon.
    func test08_uncheckNextWeek() {
        app.launch()
        openCard("Errands")
        app.buttons["Next week"].tap()
        snap("08-nextweek-before")
        app.buttons["Mark milk incomplete"].tap()
        app.buttons["Mark bread incomplete"].tap()
        snap("08-nextweek-unchecked")
        dump("next week after unchecking")
        app.buttons["Back to This Week"].tap()
        snap("08-thisweek-after")
        dump("this week after unchecking next week")
        app.buttons["Edit Errands"].tap()
        snap("08-edit-errands")
        dump("edit errands")
    }

    /// Adds a line in an open card's Add Task field and presses Return.
    func addLine(_ text: String) {
        let field = app.textFields["Add task"]
        if !field.exists || !(field.value as? String ?? "").isEmpty && !field.hasFocus {
            app.buttons["Add task"].firstMatch.tap()
        }
        if !field.hasFocus { field.tap() }
        dismissKeyboardTip()
        app.typeText(text)
        Thread.sleep(forTimeInterval: 0.4)
        app.typeText("\n")
        Thread.sleep(forTimeInterval: 0.6)
    }

    func hideKeyboard() {
        let done = app.buttons["Done"]
        if done.exists && done.isHittable { done.tap() }
    }

    /// Goal 3: my to-do note. "Call dentist" is an appointment; "Return Amazon package" is an errand.
    /// "Pay water bill" has no obvious card, so I look at Edit for adding a category.
    func test09_todo() {
        app.launch()
        snap("09-launch")
        let doneEditing = app.buttons["Done editing Errands"]
        if doneEditing.waitForExistence(timeout: 2) { doneEditing.tap() }
        if app.buttons["Close Errands"].exists { app.buttons["Close Errands"].tap() }
        openCard("Appointments")
        app.buttons["Add task"].firstMatch.tap()
        let f = app.textFields["Add task"]
        print("REVIEW: appointments add field placeholder: \(f.placeholderValue ?? "nil")")
        dismissKeyboardTip()
        app.typeText("Call dentist")
        Thread.sleep(forTimeInterval: 0.4)
        app.typeText("\n")
        snap("09-dentist")
        hideKeyboard()
        dump("after dentist")
        openCard("Errands")
        app.buttons["Add task"].firstMatch.tap()
        print("REVIEW: errands add field placeholder: \(app.textFields["Add task"].placeholderValue ?? "nil")")
        snap("09-errands-addfield")
        dismissKeyboardTip()
        app.typeText("Return Amazon package")
        Thread.sleep(forTimeInterval: 0.4)
        app.typeText("\n")
        snap("09-amazon")
        hideKeyboard()
        dump("after amazon")
        app.buttons["Edit"].firstMatch.tap()
        snap("09-edit-mode")
        dump("edit mode")
    }

    /// Goal 3, part 2: no card fits a bill, so add a category.
    func test10_addCategory() {
        app.launch()
        if !app.buttons["Add Category"].waitForExistence(timeout: 2) {
            app.buttons["Edit"].firstMatch.tap()
        }
        app.buttons["Add Category"].tap()
        snap("10-add-category")
        dump("add category")
        print("REVIEW: textfields: \(app.textFields.allElementsBoundByIndex.map { "\($0.label)|\($0.placeholderValue ?? "")" })")
    }

    /// Goal 3, part 3: scroll the saved categories, then Create New Category "Home", add Pay water bill.
    func test11_newCategory() {
        app.launch()
        if !app.buttons["Add Category"].waitForExistence(timeout: 2) {
            app.buttons["Edit"].firstMatch.tap()
        }
        app.buttons["Add Category"].tap()
        let sheet = app.buttons["Create New Category"]
        _ = sheet.waitForExistence(timeout: 3)
        // pull the sheet up to see the saved categories
        app.buttons["Sheet Grabber"].swipeUp()
        snap("11-sheet-full")
        print("REVIEW: saved list: \(app.buttons.allElementsBoundByIndex.map { $0.label }.filter { $0.contains("Added") || $0.contains("Add ") })")
        app.buttons["Create New Category"].tap()
        snap("11-create-new")
        dump("create new")
        print("REVIEW: textfields: \(app.textFields.allElementsBoundByIndex.map { "\($0.label)|\($0.placeholderValue ?? "")|\($0.value ?? "")" })")
    }

    /// Goal 3 end + goal 4: create "Home", add "Pay water bill", make it carry over, give it the 28th.
    func test12_homeAndBill() {
        app.launch()
        if !app.buttons["Add Category"].waitForExistence(timeout: 2) {
            app.buttons["Edit"].firstMatch.tap()
        }
        app.buttons["Add Category"].firstMatch.tap()
        app.buttons["Create New Category"].tap()
        dismissKeyboardTip()
        app.typeText("Home")
        snap("12-home-typed")
        app.typeText("\n")
        snap("12-home-return")
        dump("after home return")
        // close the sheet with its check button
        let check = app.buttons["Done"].firstMatch
        if check.exists && check.isHittable { check.tap() }
        snap("12-sheet-closed")
        leaveEditMode()
        snap("12-home-card")
        openCard("Home")
        app.buttons["Add task"].firstMatch.tap()
        dismissKeyboardTip()
        app.typeText("Pay water bill")
        app.buttons["New task options: Checkbox, One-Time"].tap()
        app.popovers.buttons["Carry Over"].tap()
        snap("12-carry-over")
        print("REVIEW: popover texts: \(app.popovers.firstMatch.staticTexts.allElementsBoundByIndex.map { $0.label })")
        app.popovers.buttons["Add a date"].tap()
        snap("12-date-picker")
        dump("date picker")
        print("REVIEW: date texts: \(app.staticTexts.allElementsBoundByIndex.map { $0.label })")
    }

    /// Goal 4: Pay water bill, carry over, until Nov 28. Then look at how it shows.
    func test14_billDate() {
        app.launch()
        leaveEditMode()
        openCard("Home")
        app.buttons["Add task"].firstMatch.tap()
        dismissKeyboardTip()
        app.typeText("Pay water bill")
        app.buttons["New task options: Checkbox, One-Time"].tap()
        app.popovers.buttons["Carry Over"].tap()
        app.popovers.buttons["Add a date"].tap()
        app.buttons["Saturday, November 28"].tap()
        snap("14-picked-28")
        app.buttons["Set"].tap()
        snap("14-date-set")
        print("REVIEW: popover texts after set: \(app.popovers.firstMatch.staticTexts.allElementsBoundByIndex.map { $0.label })")
        print("REVIEW: popover buttons after set: \(app.popovers.firstMatch.buttons.allElementsBoundByIndex.map { $0.label })")
        let add = app.popovers.buttons["Add Task"]
        if add.exists { add.tap() } else { app.typeText("\n") }
        hideKeyboard()
        snap("14-bill-added")
        dump("bill added")
        print("REVIEW: home texts: \(app.staticTexts.allElementsBoundByIndex.map { $0.label })")
        // set the other two to-dos to carry over as well
        for t in ["Call dentist", "Return Amazon package"] {
            let card = t == "Call dentist" ? "Appointments" : "Errands"
            openCard(card)
            let opt = app.buttons.matching(NSPredicate(format: "label == 'Task options: Checkbox, One-Time'")).allElementsBoundByIndex
            print("REVIEW: one-time options visible for \(t): \(opt.count)")
            // the row's options button sits right of its title
            let title = app.staticTexts[t]
            if title.exists {
                let btn = opt.min(by: { abs($0.frame.midY - title.frame.midY) < abs($1.frame.midY - title.frame.midY) })
                btn?.tap()
                if app.popovers.buttons["Carry Over"].waitForExistence(timeout: 2) {
                    app.popovers.buttons["Carry Over"].tap()
                    app.popovers.buttons["Done"].tap()
                }
            }
        }
        snap("14-todos-carry")
        app.buttons["Next week"].tap()
        snap("14-next-week")
        dump("next week with carry-overs")
        app.buttons["Back to This Week"].tap()
    }

    /// Goal 5: trip in three weeks. Tap > three times, then a "Packing" list in Home.
    func test15_packing() {
        app.launch()
        leaveEditMode()
        for _ in 0..<3 { app.buttons["Next week"].tap(); Thread.sleep(forTimeInterval: 0.5) }
        snap("15-three-weeks")
        print("REVIEW: title: \(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Week of'")).firstMatch.label)")
        openCard("Home")
        app.buttons["Add task"].firstMatch.tap()
        dismissKeyboardTip()
        app.typeText("Packing")
        app.buttons["New task options: Checkbox, One-Time"].tap()
        app.popovers.buttons["List"].tap()
        app.popovers.buttons["Add Task"].tap()
        for w in ["passport", "charger", "sunscreen"] {
            app.typeText(w + "\n"); Thread.sleep(forTimeInterval: 0.5)
        }
        hideKeyboard()
        snap("15-packing")
        dump("packing")
        app.buttons["Back to This Week"].tap()
        snap("15-back-this-week")
    }

    /// Goals 8, 9, 10: pin groceries; jot "call mom sunday" with the sparkles; peek at next week.
    func test16_pinSmartNext() {
        app.launch()
        leaveEditMode()
        openCard("Errands")
        app.buttons["Edit Errands"].tap()
        snap("16-edit-errands")
        dump("edit errands 2")
        let pinG = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Groceries' AND label CONTAINS[c] 'pin'")).firstMatch
        if pinG.exists { print("REVIEW: pin label: \(pinG.label)"); pinG.tap() }
        snap("16-pinned-groceries")
        app.buttons["Done editing Errands"].tap()
        app.buttons["Edit"].firstMatch.tap()
        let pinErr = app.buttons["Pin Errands to the top"]
        if pinErr.waitForExistence(timeout: 2) { pinErr.tap() }
        snap("16-pinned-errands")
        dump("pinned errands")
        leaveEditMode()
        // Goal 9
        openCard("Errands")
        app.buttons["Add task"].firstMatch.tap()
        dismissKeyboardTip()
        app.typeText("call mom sunday")
        snap("16-call-mom-typed")
        app.buttons["Smart Add"].tap()
        Thread.sleep(forTimeInterval: 2)
        snap("16-smart-add")
        dump("smart add")
        print("REVIEW: texts after smart add: \(app.staticTexts.allElementsBoundByIndex.map { $0.label })")
    }

    /// Goals 6 and 7 after 3 tries each: open Help ("How to Use Tasquel") and read it.
    func test17_help() {
        app.launch()
        leaveEditMode()
        if app.buttons["Show All"].exists { app.buttons["Show All"].tap() }
        app.buttons["Settings"].tap()
        let how = app.buttons["How to Use Tasquel"]
        for _ in 0..<4 where !how.isHittable { app.swipeUp() }
        how.tap()
        snap("17-help-1")
        var seen = Set<String>()
        for i in 0..<8 {
            let texts = app.staticTexts.allElementsBoundByIndex.map { $0.label }
            let new = texts.filter { !seen.contains($0) }
            new.forEach { seen.insert($0) }
            print("REVIEW: help page \(i): \(new)")
            print("REVIEW: help buttons \(i): \(app.buttons.allElementsBoundByIndex.map { $0.label }.filter { !$0.hasPrefix("Open ") && !$0.contains("day,") })")
            app.swipeUp()
            snap("17-help-\(i + 2)")
        }
        let all = seen.joined(separator: " ").lowercased()
        for w in ["share", "search", "find", "pin", "remind", "notification", "uncheck", "copy", "sync", "family", "partner"] {
            print("REVIEW: help mentions '\(w)': \(all.contains(w))")
        }
    }

    /// Help, every tab: look for share, search, pin, uncheck, reminders.
    func test18_helpTabs() {
        app.launch()
        leaveEditMode()
        if app.buttons["Show All"].exists { app.buttons["Show All"].tap() }
        app.buttons["Settings"].tap()
        let how = app.buttons["How to Use Tasquel"]
        for _ in 0..<4 where !how.isHittable { app.swipeUp() }
        how.tap()
        var all = ""
        for tab in ["Weekly Checklist", "Category Cards", "Tasks", "Task Types", "After This Week", "Days and Dates"] {
            let b = app.buttons[tab]
            guard b.waitForExistence(timeout: 2) else { print("REVIEW: no tab \(tab)"); continue }
            b.tap()
            Thread.sleep(forTimeInterval: 0.5)
            let texts = app.staticTexts.allElementsBoundByIndex.map { $0.label }.filter { $0.count > 3 }
            all += texts.joined(separator: " ")
            print("REVIEW: TAB \(tab): \(texts)")
            snap("18-help-\(tab.replacingOccurrences(of: " ", with: "-"))")
        }
        let low = all.lowercased()
        for w in ["share", "search", "find", "pin", "remind", "notification", "uncheck", "reset", "copy", "sync", "smart add", "sparkle", "until", "expir"] {
            print("REVIEW: help mentions '\(w)': \(low.contains(w))")
        }
    }

    /// Goal 10 and end of day: what's waiting next week, back via the logo; the calendar button; overview.
    func test19_nextWeekAndEndOfDay() {
        app.launch()
        leaveEditMode()
        if app.buttons["Close all cards"].exists { app.buttons["Close all cards"].tap() }
        snap("19-end-of-day-closed")
        app.buttons["Open all cards"].tap()
        snap("19-end-of-day-open")
        app.swipeUp()
        snap("19-end-of-day-open-2")
        app.buttons["Next week"].tap()
        if app.buttons["Close all cards"].exists { app.buttons["Close all cards"].tap() }
        snap("19-next-week-closed")
        dump("next week")
        app.buttons["Open all cards"].tap()
        snap("19-next-week-open")
        print("REVIEW: next week texts: \(app.staticTexts.allElementsBoundByIndex.map { $0.label })")
        app.buttons["This Week"].tap()
        snap("19-back-via-logo")
        print("REVIEW: title after logo: \(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Week of'")).firstMatch.label)")
        app.buttons["Go to week"].tap()
        snap("19-calendar-button")
        dump("calendar button")
        print("REVIEW: calendar texts: \(app.staticTexts.allElementsBoundByIndex.map { $0.label })")
    }

    /// Bringing data in: paste a checklist copied from Notes into Add Task (Work card),
    /// then try Smart Add on "Groceries: milk, eggs, bread" the way Help describes.
    func test20_pasteFromNotes() {
        UIPasteboard.general.string = "Order printer toner\nBook meeting room\nSend invoices"
        app.launch()
        leaveEditMode()
        if app.buttons["Close all cards"].exists { app.buttons["Close all cards"].tap() }
        Thread.sleep(forTimeInterval: 1.5)
        openCard("Work")
        _ = app.buttons["Close Work"].waitForExistence(timeout: 3)
        Thread.sleep(forTimeInterval: 1)
        let editWork = app.buttons["Edit Work"]
        let adds = app.buttons.matching(identifier: "Add task").allElementsBoundByIndex
        let mine = adds.filter { $0.frame.minY > editWork.frame.minY }.min(by: { $0.frame.minY < $1.frame.minY })
        (mine ?? adds.last)?.tap()
        dismissKeyboardTip()
        snap("20-work-add")
        print("REVIEW: work textfields: \(app.textFields.allElementsBoundByIndex.map { "\($0.identifier)|\($0.label)|\($0.placeholderValue ?? "")" })")
        let field = app.textFields.firstMatch
        field.press(forDuration: 1.2)
        let paste = app.menuItems["Paste"]
        if paste.waitForExistence(timeout: 3) { paste.tap() } else { print("REVIEW: no Paste menu"); dump("no paste") }
        allowSystemAlert("Allow Paste")
        Thread.sleep(forTimeInterval: 1)
        snap("20-pasted")
        print("REVIEW: field after paste: \(field.value ?? "nil")")
        app.typeText("\n")
        Thread.sleep(forTimeInterval: 1)
        snap("20-pasted-return")
        print("REVIEW: work texts: \(app.staticTexts.allElementsBoundByIndex.map { $0.label })")
        app.typeText("Groceries: milk, eggs, bread")
        app.buttons["Smart Add"].tap()
        Thread.sleep(forTimeInterval: 2)
        hideKeyboard()
        snap("20-smart-list")
        print("REVIEW: work texts 2: \(app.staticTexts.allElementsBoundByIndex.map { $0.label })")
    }

    func leaveEditMode() {
        let done = app.buttons["Done Editing"]
        if done.waitForExistence(timeout: 1) { done.tap() }
    }

    /// Goals 6 and 7: share the grocery list; find "dentist". Tries: long-press the closed card,
    /// pull down for a search bar, then Settings.
    func test13_shareAndSearch() {
        app.launch()
        leaveEditMode()
        if app.buttons["Close all cards"].exists { app.buttons["Close all cards"].tap() }
        snap("13-home-closed")
        // Share try: long-press the Errands card
        let errands = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Open Errands'")).firstMatch
        errands.press(forDuration: 1.5)
        snap("13-longpress-card")
        dump("after card long-press")
        // dismiss anything by tapping the week title
        app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Week of'")).firstMatch.tap()
        // Search try: pull down on the cards
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35))
        start.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75)))
        snap("13-pull-down")
        print("REVIEW: searchFields: \(app.searchFields.count) textFields: \(app.textFields.count)")
        // Settings
        app.buttons["Settings"].tap()
        snap("13-settings")
        dump("settings")
        print("REVIEW: settings texts: \(app.staticTexts.allElementsBoundByIndex.map { $0.label })")
        app.swipeUp()
        snap("13-settings-2")
        print("REVIEW: settings texts 2: \(app.staticTexts.allElementsBoundByIndex.map { $0.label })")
        app.swipeUp()
        snap("13-settings-3")
        print("REVIEW: settings texts 3: \(app.staticTexts.allElementsBoundByIndex.map { $0.label })")
        dump("settings bottom")
    }
}
