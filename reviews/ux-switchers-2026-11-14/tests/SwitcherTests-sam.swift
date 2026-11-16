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

    /// Watch the welcome tour carefully, one page at a time, then look at the main screen.
    func test01_tour() {
        app.launch()
        for page in 1...6 {
            snap("01-tour-p\(page)")
            let next = app.buttons["Next"]
            if next.waitForExistence(timeout: 2) && next.isHittable {
                next.tap()
            } else {
                // last page: look for whatever finishes the tour
                for label in ["Get Started", "Done", "Start", "Continue", "Let's Go"] {
                    let b = app.buttons[label]
                    if b.exists && b.isHittable { print("REVIEW: tour end button \(label)"); b.tap(); break }
                }
                break
            }
        }
        snap("01-main")
        allowSystemAlert()
        snap("01-main-after")
    }

    /// Finish the tour (my planner has appointments, so turn calendar on), then look at Edit.
    func test02_finishTourAndEdit() {
        app.launch()
        for _ in 0..<4 {
            let next = app.buttons["Next"]
            if next.waitForExistence(timeout: 2) && next.isHittable { next.tap() }
        }
        let turnOn = app.buttons["Turn On Calendar Events"].firstMatch
        if turnOn.waitForExistence(timeout: 3) {
            turnOn.tap()
            allowSystemAlert()
            snap("02-tour-calendar-on")
            let go = app.buttons["Let's Go!"]
            if go.exists { go.tap() }
        }
        snap("02-main")
        app.buttons["Edit"].tap()
        snap("02-edit")
    }

    /// Goal 1: how do I turn "Work" into "School"? Try tapping the card in Edit, then look at Add Category.
    func test03_exploreRename() {
        app.launch()
        app.buttons["Edit"].tap()
        let work = app.otherElements["Work, no tasks yet"]
        if work.waitForExistence(timeout: 3) { work.tap() }
        snap("03-edit-tap-work")
        // dismiss whatever came up
        for label in ["Cancel", "Done", "Close"] {
            let b = app.buttons[label]
            if b.exists && b.isHittable { b.tap(); break }
        }
        snap("03-after-dismiss")
        // long-press the card title
        if work.exists { work.press(forDuration: 1.2) }
        snap("03-edit-longpress-work")
        for label in ["Cancel", "Done", "Close"] {
            let b = app.buttons[label]
            if b.exists && b.isHittable { b.tap(); break }
        }
        let add = app.buttons["Add Category"]
        if add.waitForExistence(timeout: 2) { add.tap() }
        snap("03-add-category")
    }

    /// Goal 1: Create New Category "School".
    func test04_createSchool() {
        app.launch()
        app.buttons["Edit"].tap()
        app.buttons["Add Category"].tap()
        let create = app.buttons["Create New Category"]
        XCTAssert(create.waitForExistence(timeout: 3))
        create.tap()
        snap("04-create-form")
        let field = app.textFields.firstMatch
        if field.waitForExistence(timeout: 3) {
            print("REVIEW: name field placeholder='\(field.placeholderValue ?? "")' value='\(field.value ?? "")' id='\(field.identifier)'")
            field.tap()
            field.typeText("School")
        }
        snap("04-create-typed")
        // dismiss keyboard so I can see the whole form
        if app.keyboards.buttons["Return"].exists { app.keyboards.buttons["Return"].tap() }
        else if app.keyboards.buttons["return"].exists { app.keyboards.buttons["return"].tap() }
        snap("04-create-form-full")
        app.swipeUp()
        snap("04-create-form-scrolled")
    }

    func dismissKeyboardTip() {
        let c = app.buttons["Continue"]
        if c.exists && c.isHittable { c.tap() }
    }

    func tapFirst(_ words: [String], in query: XCUIElementQuery) -> String? {
        for w in words {
            let m = query.matching(NSPredicate(format: "label CONTAINS[c] %@", w)).firstMatch
            if m.exists && m.isHittable { let l = m.label; m.tap(); return l }
        }
        return nil
    }

    /// Goal 1: my three sections, each with a fitting icon, and the defaults removed.
    func test05_mySections() {
        app.launch()
        app.buttons["Edit"].tap()
        app.buttons["Add Category"].tap()
        let sections: [(String, [String])] = [("School", ["Graduation", "School", "Pencil", "Book"]),
                                              ("Home", ["House", "Home"]),
                                              ("Self", ["Heart", "Person", "Leaf", "Star"])]
        for (i, (name, icons)) in sections.enumerated() {
            let create = app.buttons["Create New Category"]
            XCTAssert(create.waitForExistence(timeout: 3))
            create.tap()
            dismissKeyboardTip()
            let iconButton = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Icon:'")).firstMatch
            if iconButton.waitForExistence(timeout: 2) {
                iconButton.tap()
                if i == 0 { snap("05-icon-picker") }
                let picked = tapFirst(icons, in: app.buttons)
                print("REVIEW: icon for \(name) -> \(picked ?? "none found")")
                if picked == nil {
                    if i == 0 { app.swipeUp(); snap("05-icon-picker-scrolled") }
                    for l in ["Done", "Cancel", "Close"] { let b = app.buttons[l]; if b.exists && b.isHittable { b.tap(); break } }
                }
            }
            snap("05-\(name)-icon")
            let field = app.textFields["Category name"]
            if field.waitForExistence(timeout: 2) { field.tap(); field.typeText(name) }
            dismissKeyboardTip()
            snap("05-\(name)-ready")
            let addButtons = app.buttons.matching(NSPredicate(format: "label == 'Add Category'"))
            // the form's own Add Category button (not the grid tile behind the sheet)
            var tapped = false
            for j in 0..<addButtons.count {
                let b = addButtons.element(boundBy: j)
                if b.isHittable && b.frame.height < 60 { b.tap(); tapped = true; break }
            }
            print("REVIEW: tapped form Add Category for \(name): \(tapped)")
            snap("05-\(name)-added")
        }
        app.buttons["Done"].firstMatch.tap()
        snap("05-after-adding")
        // remove the sections I don't use
        for old in ["Errands", "Work", "Fitness", "Study", "Appointments"] {
            let del = app.buttons["Delete \(old)"]
            if del.waitForExistence(timeout: 2) {
                del.tap()
                if old == "Errands" { snap("05-delete-confirm") }
                let alertDelete = app.alerts.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Delete'")).firstMatch
                let sheetDelete = app.sheets.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Delete'")).firstMatch
                if alertDelete.exists { alertDelete.tap() } else if sheetDelete.exists { sheetDelete.tap() }
            }
        }
        snap("05-after-delete")
        app.buttons["Done Editing"].tap()
        snap("05-my-spread")
    }

    /// Goal 1 (second try, knowing the icon menu): School with an emoji, Home with the house, Self with the heart.
    func test06_mySections() {
        app.launch()
        app.buttons["Edit"].tap()
        app.buttons["Add Category"].tap()
        let sections: [(String, String)] = [("School", "Choose Emoji…"), ("Home", "Home"), ("Self", "Heart")]
        for (name, icon) in sections {
            let create = app.buttons["Create New Category"]
            XCTAssert(create.waitForExistence(timeout: 3))
            create.tap()
            dismissKeyboardTip()
            let field = app.textFields["Category name"]
            if field.waitForExistence(timeout: 2) { field.typeText(name) }
            dismissKeyboardTip()
            let iconButton = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Icon:'")).firstMatch
            if iconButton.waitForExistence(timeout: 2) {
                iconButton.tap()
                let choice = app.buttons[icon].firstMatch
                if choice.waitForExistence(timeout: 2) { choice.tap() }
                if icon == "Choose Emoji…" {
                    snap("06-emoji-picker")
                    // an apple for the teacher
                    let ef = app.textFields.matching(NSPredicate(format: "placeholderValue != 'Category name'")).firstMatch
                    print("REVIEW: emoji field exists=\(ef.exists) kb=\(app.keyboards.count)")
                    if app.keyboards.count > 0 { app.typeText("🍎") }
                    snap("06-emoji-typed")
                }
            }
            snap("06-\(name)-ready")
            let addButtons = app.buttons.matching(NSPredicate(format: "label == 'Add Category'"))
            var tapped = false
            for j in 0..<addButtons.count {
                let b = addButtons.element(boundBy: j)
                if b.isHittable && b.frame.height < 60 { b.tap(); tapped = true; break }
            }
            print("REVIEW: tapped form Add Category for \(name): \(tapped)")
            snap("06-\(name)-added")
        }
        let done = app.buttons["Done"].firstMatch
        if done.exists { done.tap() }
        snap("06-after-adding")
    }

    /// Goal 1 continued: the sheet closes after each one, so open it again for Home and Self; then remove the defaults.
    func test07_homeSelfAndCleanup() {
        app.launch()
        for (name, icon) in [("Home", "Home"), ("Self", "Heart")] {
            let edit = app.buttons["Edit"]
            if edit.waitForExistence(timeout: 2) && edit.isHittable { edit.tap() }
            app.buttons["Add Category"].tap()
            let create = app.buttons["Create New Category"]
            XCTAssert(create.waitForExistence(timeout: 3))
            create.tap()
            dismissKeyboardTip()
            let field = app.textFields["Category name"]
            if field.waitForExistence(timeout: 2) { field.typeText(name) }
            let iconButton = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Icon:'")).firstMatch
            if iconButton.waitForExistence(timeout: 2) {
                iconButton.tap()
                let choice = app.buttons[icon].firstMatch
                if choice.waitForExistence(timeout: 2) { choice.tap() }
            }
            let addButtons = app.buttons.matching(NSPredicate(format: "label == 'Add Category'"))
            for j in 0..<addButtons.count {
                let b = addButtons.element(boundBy: j)
                if b.isHittable && b.frame.height < 60 { b.tap(); break }
            }
            snap("07-\(name)-added")
        }
        // remove the sections I don't use
        let edit = app.buttons["Edit"]
        if edit.waitForExistence(timeout: 2) && edit.isHittable { edit.tap() }
        for old in ["Errands", "Work", "Fitness", "Study", "Appointments"] {
            let del = app.buttons["Delete \(old)"]
            if del.waitForExistence(timeout: 2) {
                del.tap()
                if old == "Errands" { snap("07-delete-confirm") }
                let alertDelete = app.alerts.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Delete'")).firstMatch
                let sheetDelete = app.sheets.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Delete'")).firstMatch
                if alertDelete.exists { alertDelete.tap() } else if sheetDelete.exists { sheetDelete.tap() }
            }
        }
        snap("07-after-delete")
        let doneEditing = app.buttons["Done Editing"]
        if doneEditing.exists { doneEditing.tap() }
        snap("07-my-spread")
    }

    /// Goal 2: open School, Add Task, write it the way I'd write it on paper.
    func test08_schoolTasks() {
        app.launch()
        let school = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Open School'")).firstMatch
        XCTAssert(school.waitForExistence(timeout: 3))
        school.tap()
        snap("08-school-open")
        let addTask = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Add Task'")).firstMatch
        if addTask.waitForExistence(timeout: 2) { addTask.tap() }
        dismissKeyboardTip()
        snap("08-add-task")
        app.typeText("Grade essays by Thursday")
        snap("08-typed-grade")
        let sparkles = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'sparkle' OR identifier CONTAINS[c] 'sparkles' OR label CONTAINS[c] 'Smart'")).firstMatch
        print("REVIEW: sparkles exists=\(sparkles.exists) label=\(sparkles.exists ? sparkles.label : "")")
        if sparkles.exists && sparkles.isHittable {
            sparkles.tap()
            Thread.sleep(forTimeInterval: 1.5)
            snap("08-sparkles-grade")
        }
    }

    func openCard(_ name: String) {
        let card = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open \(name)")).firstMatch
        if card.waitForExistence(timeout: 3) {
            if !card.isHittable { tapDone() }
            if card.isHittable { card.tap() } else { print("REVIEW: card \(name) not hittable") }
        }
    }

    /// Taps whichever Done button is actually on top.
    func tapDone() {
        let all = app.buttons.matching(NSPredicate(format: "label == 'Done'")).allElementsBoundByIndex
        for b in all.reversed() where b.exists && b.isHittable { b.tap(); return }
    }

    func closeCard(_ name: String) {
        let c = app.buttons["Close \(name)"]
        if c.exists && c.isHittable { c.tap() }
    }

    func addTask(_ text: String, smart: Bool) {
        let field = app.textFields["Add task"].firstMatch
        let button = app.buttons["Add task"].firstMatch
        if field.exists && field.isHittable { field.tap() }
        else if button.waitForExistence(timeout: 2) { button.tap() }
        dismissKeyboardTip()
        app.typeText(text)
        if smart {
            let s = app.buttons["Smart Add"].firstMatch
            if s.waitForExistence(timeout: 2) { s.tap() }
            Thread.sleep(forTimeInterval: 1.5)
        } else {
            app.typeText("\n")
        }
    }

    /// Goal 2 rest, and Goal 3 (what happens to "Email parents" if I don't finish it).
    func test09_fillWeek() {
        app.launch()
        openCard("School")
        // "late"? I wrote by Thursday. What does tapping that badge do?
        let changeDay = app.buttons["Change day of Grade essays by Thursday"]
        if changeDay.waitForExistence(timeout: 2) {
            changeDay.tap()
            snap("09-change-day")
            for l in ["Cancel", "Done", "Close"] { let b = app.buttons[l]; if b.exists && b.isHittable { b.tap(); break } }
            if app.buttons["Change day of Grade essays by Thursday"].isHittable == false {
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)).tap()
            }
        }
        addTask("Email parents about field trip", smart: false)
        snap("09-school-two")
        let done = app.buttons["Done"].firstMatch
        if done.exists && done.isHittable { done.tap() }   // hide keyboard
        let opts = app.buttons["Task options: Checkbox, One-Time"].firstMatch
        let emailOpts = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Task options'")).element(boundBy: 1)
        if emailOpts.exists { emailOpts.tap() } else if opts.exists { opts.tap() }
        snap("09-task-options")
        let carry = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'carr'")).firstMatch
        print("REVIEW: carry option exists=\(carry.exists) label=\(carry.exists ? carry.label : "")")
        if carry.exists && carry.isHittable { carry.tap() }
        snap("09-after-carry")
        for l in ["Done", "Close"] { let b = app.buttons[l].firstMatch; if b.exists && b.isHittable { b.tap(); break } }
        snap("09-school-final")
        closeCard("School")
        openCard("Home")
        addTask("Laundry", smart: false)
        let d2 = app.buttons["Done"].firstMatch
        if d2.exists && d2.isHittable { d2.tap() }
        closeCard("Home")
        openCard("Self")
        addTask("Yoga twice this week", smart: true)
        snap("09-yoga-smart")
        let d3 = app.buttons["Done"].firstMatch
        if d3.exists && d3.isHittable { d3.tap() }
        closeCard("Self")
        snap("09-week-filled")
    }

    /// Goal 2 fix: Smart Add didn't get "twice", so make Yoga a Goal of 2 by hand.
    /// Goal 3: look at next week. Also peek at Settings for Help.
    func test10_yogaGoalNextWeek() {
        app.launch()
        openCard("Self")
        let opts = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Task options'")).firstMatch
        if opts.waitForExistence(timeout: 2) { opts.tap() }
        let goal = app.buttons["Goal"].firstMatch
        if goal.waitForExistence(timeout: 2) { goal.tap() }
        snap("10-yoga-goal")
        let tf = app.textFields.matching(NSPredicate(format: "identifier != 'Add task'")).firstMatch
        print("REVIEW: goal field exists=\(tf.exists) label=\(tf.exists ? tf.label : "") value=\(tf.exists ? "\(tf.value ?? "")" : "")")
        if tf.exists && tf.isHittable {
            tf.tap()
            tf.press(forDuration: 1.0)
            let selectAll = app.menuItems["Select All"]
            if selectAll.waitForExistence(timeout: 1) { selectAll.tap() }
            tf.typeText("2")
            snap("10-yoga-goal-2")
        }
        let done = app.buttons["Done"].firstMatch
        if done.exists && done.isHittable { done.tap() }
        snap("10-yoga-after")
        closeCard("Self")
        // Goal 3: what will next week look like?
        app.buttons["Next week"].tap()
        snap("10-next-week")
        openCard("School")
        snap("10-next-week-school")
        app.buttons["This Week"].tap()
        snap("10-back-this-week")
        app.buttons["Settings"].tap()
        snap("10-settings")
        app.swipeUp()
        snap("10-settings-2")
    }

    @discardableResult func tapIf(_ e: XCUIElement, wait: Double = 2) -> Bool {
        if e.waitForExistence(timeout: wait) && e.isHittable { e.tap(); return true }
        return false
    }

    func hideKeyboard() {
        let k = app.buttons["Done"].firstMatch
        if app.keyboards.count > 0 && k.exists && k.isHittable { k.tap() }
    }

    /// Finish Yoga's target; then read Help before the collection and monthly goals.
    func test11_yogaTargetAndHelp() {
        app.launch()
        openCard("Self")
        let target = app.textFields["Target"].firstMatch
        if tapIf(target) {
            target.typeText("2")
            tapIf(app.buttons["Set"].firstMatch)
        }
        snap("11-yoga-set")
        closeCard("Self")
        tapIf(app.buttons["Settings"])
        app.swipeUp()
        tapIf(app.buttons["How to Use Tasquel"])
        for i in 1...8 {
            snap("11-help-\(i)")
            app.swipeUp()
        }
    }

    /// Help tabs about task types and dates, then Goal 4: a "Books to read" list that lasts.
    func test12_helpTabsAndBooks() {
        app.launch()
        tapIf(app.buttons["Settings"])
        app.swipeUp()
        tapIf(app.buttons["How to Use Tasquel"])
        for tab in ["Category Cards", "Tasks", "Task Types", "After This Week", "Days and Dates"] {
            let t = app.buttons[tab].firstMatch
            if t.waitForExistence(timeout: 2) {
                if !t.isHittable { app.buttons["Task Types"].firstMatch.swipeLeft() }
                if t.isHittable { t.tap() }
            }
            let slug = tab.replacingOccurrences(of: " ", with: "")
            snap("12-help-\(slug)-1")
            app.swipeUp()
            snap("12-help-\(slug)-2")
            app.swipeUp()
            snap("12-help-\(slug)-3")
            app.swipeDown(); app.swipeDown()
        }
        // close Help and Settings
        for _ in 0..<2 {
            let d = app.buttons["Done"].firstMatch
            if d.exists && d.isHittable { d.tap() }
            Thread.sleep(forTimeInterval: 0.6)
        }
        snap("12-closed-help")
        // Goal 4: Books to read, as a List that carries over
        openCard("Self")
        addTask("Books to read", smart: false)
        hideKeyboard()
        let opts = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Task options' AND label CONTAINS 'Checkbox'")).firstMatch
        if tapIf(opts) {
            tapIf(app.buttons["List"].firstMatch)
            tapIf(app.buttons["Carry Over"].firstMatch)
            snap("12-books-options")
            tapIf(app.buttons["Done"].firstMatch)
        }
        snap("12-books-list")
        let itemField = app.textFields.matching(NSPredicate(format: "placeholderValue CONTAINS[c] 'item' OR placeholderValue CONTAINS[c] 'Add'")).allElementsBoundByIndex
        for f in itemField { print("REVIEW: field placeholder=\(f.placeholderValue ?? "") id=\(f.identifier)") }
        for title in ["The Overstory", "Braiding Sweetgrass", "Klara and the Sun"] {
            let sub = app.buttons["Add sub-task to Books to read"].firstMatch
            let item = app.textFields.matching(NSPredicate(format: "placeholderValue CONTAINS[c] 'item'")).firstMatch
            if item.exists && item.isHittable { item.tap() } else if sub.exists && sub.isHittable { sub.tap() } else { print("REVIEW: no way to add item found"); break }
            dismissKeyboardTip()
            app.typeText(title)
            app.typeText("\n")
            Thread.sleep(forTimeInterval: 0.5)
        }
        snap("12-books-items")
        hideKeyboard()
        snap("12-books-done")
    }

    /// Goal 5 (events beside tasks), Goal 6 (week after next), Goal 7 (last week).
    func test13_eventsAheadBack() {
        app.launch()
        tapIf(app.buttons["Calendar and events"])
        snap("13-events")
        let weeks = app.buttons["Weeks"].firstMatch
        if tapIf(weeks) { snap("13-events-weeks") }
        let ev = app.buttons["Events"].firstMatch
        tapIf(ev)
        tapDone()
        snap("13-events-closed")
        // Goal 6: two weeks ahead
        tapIf(app.buttons["Next week"])
        tapIf(app.buttons["Next week"])
        snap("13-week-after-next")
        openCard("School")
        addTask("Report cards due", smart: false)
        hideKeyboard()
        snap("13-report-cards")
        closeCard("School")
        tapIf(app.buttons["Back to This Week"])
        snap("13-this-week-again")
        // Goal 7: last week
        tapIf(app.buttons["Previous week"])
        snap("13-last-week")
        openCard("School")
        snap("13-last-week-school")
        tapIf(app.buttons["Previous week"])
        snap("13-two-weeks-ago")
        tapIf(app.buttons["Back to This Week"])
        snap("13-back")
    }

    /// Goal 9 (rent on the 1st, monthly), Goal 10 (a lesson idea note), Goal 8 (make it look like mine).
    func test14_monthlyNoteLook() {
        app.launch()
        openCard("Home")
        addTask("Pay rent on the 1st every month", smart: true)
        snap("14-rent-smart")
        hideKeyboard()
        let rentOpts = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Task options'")).element(boundBy: 1)
        if tapIf(rentOpts) {
            snap("14-rent-options")
            if tapIf(app.buttons["Add a date"].firstMatch) {
                snap("14-rent-date")
                app.swipeUp()
                snap("14-rent-date-2")
                for l in ["Cancel", "Done"] { let b = app.buttons[l].firstMatch; if b.exists && b.isHittable { b.tap(); break } }
            }
            tapDone()
        }
        snap("14-rent-after")
        // Goal 10: a note. Try long-press on a task, and the card's edit button.
        let laundry = app.staticTexts["Laundry"].firstMatch
        if laundry.waitForExistence(timeout: 2) {
            laundry.press(forDuration: 1.2)
            snap("14-longpress-task")
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.07)).tap()
        }
        if laundry.exists && laundry.isHittable { laundry.tap(); snap("14-tap-task") }
        hideKeyboard()
        if tapIf(app.buttons["Edit Home"]) { snap("14-edit-home") ; app.swipeUp(); snap("14-edit-home-2") }
        tapDone()
        closeCard("Home")
        snap("14-home-closed")
        // Goal 8: looks
        tapIf(app.buttons["Settings"])
        tapIf(app.buttons["Seasonal"].firstMatch)
        tapDone()
        snap("14-seasonal")
        tapIf(app.buttons["Settings"])
        tapIf(app.buttons["Retro"].firstMatch)
        tapDone()
        snap("14-retro")
        tapIf(app.buttons["Settings"])
        tapIf(app.buttons["Seasonal"].firstMatch)
        tapDone()
        snap("14-final-look")
    }

    /// Goal 4: a "Books to read" list that lasts (List + Carry Over, per Help).
    func test15_books() {
        app.launch()
        openCard("Self")
        addTask("Books to read", smart: false)
        hideKeyboard()
        let opts = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Task options' AND label CONTAINS 'Checkbox'")).firstMatch
        if tapIf(opts) {
            tapIf(app.buttons["List"].firstMatch)
            tapIf(app.buttons["Carry Over"].firstMatch)
            snap("15-books-options")
            tapDone()
        }
        snap("15-books-list")
        let addItem = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Add Item'")).firstMatch
        let addItemField = app.textFields.matching(NSPredicate(format: "placeholderValue CONTAINS[c] 'Item' OR label CONTAINS[c] 'Add Item'")).firstMatch
        if addItemField.exists && addItemField.isHittable { addItemField.tap() } else { tapIf(addItem) }
        dismissKeyboardTip()
        for title in ["The Overstory", "Braiding Sweetgrass", "Klara and the Sun"] {
            app.typeText(title)
            app.typeText("\n")
            Thread.sleep(forTimeInterval: 0.5)
        }
        app.typeText("\n")
        snap("15-books-items")
        hideKeyboard()
        closeCard("Self")
        tapIf(app.buttons["Next week"])
        openCard("Self")
        snap("15-books-next-week")
        tapIf(app.buttons["Back to This Week"])
    }

    /// End of my first day: look at everything.
    func test16_endOfDay() {
        app.launch()
        // Would "2x" work where "twice" didn't? (then undo it)
        openCard("Self")
        addTask("Yoga 2x per week", smart: true)
        snap("16-yoga-2x-smart")
        tapIf(app.buttons["Undo Smart Add"].firstMatch)
        hideKeyboard()
        closeCard("Self")
        // a warmer, planner-like look
        tapIf(app.buttons["Settings"])
        tapIf(app.buttons["Seasonal, now Fall"].firstMatch)
        tapDone()
        snap("16-end-closed")
        tapIf(app.buttons["Open all cards"])
        snap("16-end-open")
        app.swipeUp()
        snap("16-end-open-2")
    }

    /// The best part of paper: crossing things off. Laundry done, one yoga session done.
    func test17_crossOff() {
        app.launch()
        openCard("Home")
        tapIf(app.buttons["Complete Laundry"].firstMatch)
        snap("17-laundry-done")
        closeCard("Home")
        openCard("Self")
        tapIf(app.buttons["+1"].firstMatch)
        snap("17-yoga-one")
        closeCard("Self")
        snap("17-week")
    }
}
