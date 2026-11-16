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
    func test01_skipAndLook() {
        app.launch()
        let skip = app.buttons["Skip"]
        if skip.waitForExistence(timeout: 5) { skip.tap() }
        allowSystemAlert()
        snap("01a-home-after-skip")
        // Just looking: scroll down a little to see if there's more
        app.swipeUp()
        snap("01b-home-scrolled")
        app.swipeDown()
    }
    func dump(_ tag: String) {
        print("REVIEW: ---- \(tag)")
    }

    func test02_editMode() {
        app.launch()
        app.buttons["Edit"].tap()
        snap("02a-edit-mode")
    }
    func test03_addCategorySheet() {
        app.launch()
        app.buttons["Edit"].tap()
        app.buttons["Add Category"].tap()
        snap("03a-add-category")
    }
    func test04_createPersonal() {
        app.launch()
        app.buttons["Edit"].tap()
        app.buttons["Add Category"].tap()
        app.buttons["Create New Category"].tap()
        snap("04a-create-new-category")
    }
    /// The small "Add Category" confirm button inside the sheet (not the dashed tile).
    func sheetAddCategoryButton() -> XCUIElement? {
        for b in app.buttons.matching(NSPredicate(format: "label == 'Add Category'")).allElementsBoundByIndex {
            if b.frame.height < 60 { return b }
        }
        return nil
    }

    func createCategory(_ name: String, shot: String) {
        app.buttons["Create New Category"].tap()
        let cont = app.buttons["Continue"]
        if cont.waitForExistence(timeout: 1) { cont.tap() }
        let field = app.textFields["Category name"]
        _ = field.waitForExistence(timeout: 3)
        field.typeText(name)
        snap(shot)
        sheetAddCategoryButton()?.tap()
    }

    func test05_addPersonalAndSideProject() {
        app.launch()
        app.buttons["Edit"].tap()
        app.buttons["Add Category"].tap()
        createCategory("Personal", shot: "05a-typed-personal")
        snap("05b-after-add-personal")
        if app.buttons["Create New Category"].waitForExistence(timeout: 2) {
            createCategory("Side Project", shot: "05c-typed-side-project")
        }
        snap("05d-after-add-side-project")
    }
    func test06_sideProjectAndDeleteDefault() {
        app.launch()
        app.buttons["Edit"].tap()
        app.buttons["Add Category"].tap()
        createCategory("Side Project", shot: "06a-typed-side-project")
        snap("06b-after-side-project")
        app.buttons["Edit"].tap()
        app.buttons["Delete Errands"].tap()
        snap("06c-delete-errands-tapped")
    }
    func test07_deleteDefaultsAndOpenWork() {
        app.launch()
        app.buttons["Edit"].tap()
        for name in ["Errands", "Fitness", "Study", "Appointments"] {
            let d = app.buttons["Delete \(name)"]
            if d.waitForExistence(timeout: 2) {
                d.tap()
                let confirm = app.buttons["Delete Category"]
                if confirm.waitForExistence(timeout: 2) { confirm.tap() }
            }
        }
        snap("07a-after-deletes")
        app.buttons["Done Editing"].tap()
        snap("07b-my-three-categories")
        app.buttons["Open Work, no tasks yet"].tap()
        snap("07c-work-opened")
    }
    func test08_addTaskInWork() {
        app.launch()
        app.buttons["Open Work, no tasks yet"].tap()
        app.buttons["Add task"].tap()
        let cont = app.buttons["Continue"]
        if cont.waitForExistence(timeout: 1) { cont.tap() }
        snap("08a-add-task-tapped")
    }
    func test09_typeWorkTasks() {
        app.launch()
        let open = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Open Work'")).firstMatch
        if open.waitForExistence(timeout: 3) { open.tap() }
        app.buttons["Add task"].tap()
        let field = app.textFields["Add task"]
        _ = field.waitForExistence(timeout: 3)
        field.typeText("Send invoice every Friday")
        snap("09a-typed-invoice")
        field.typeText("\n")
        Thread.sleep(forTimeInterval: 0.6)
        snap("09b-after-return-invoice")
        let f2 = app.textFields["Add task"]
        if f2.waitForExistence(timeout: 2) {
            f2.typeText("Standup notes every weekday\n")
            Thread.sleep(forTimeInterval: 0.6)
            snap("09c-after-standup")
            let f3 = app.textFields["Add task"]
            if f3.waitForExistence(timeout: 2) {
                f3.typeText("Draft Q1 roadmap by Dec 12\n")
                Thread.sleep(forTimeInterval: 0.6)
                snap("09d-after-roadmap")
            }
        }
    }
    func openWork() {
        let open = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Open Work'")).firstMatch
        if open.waitForExistence(timeout: 3) { open.tap() }
        Thread.sleep(forTimeInterval: 1.0)
    }

    func tapPaced(_ e: XCUIElement) {
        _ = e.waitForExistence(timeout: 3)
        e.tap()
        Thread.sleep(forTimeInterval: 1.0)
    }

    func test10_taskOptions() {
        app.launch()
        openWork()
        let opts = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Task options'")).firstMatch
        opts.tap()
        snap("10a-task-options")
    }
    func taskOptions(_ title: String) -> XCUIElement {
        // the options button sits on the same row as the task's title
        let t = app.staticTexts[title]
        let all = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Task options'")).allElementsBoundByIndex
        return all.min(by: { abs($0.frame.midY - t.frame.midY) < abs($1.frame.midY - t.frame.midY) }) ?? all[0]
    }

    func test11_fixInvoiceAndSettings() {
        app.launch()
        openWork()
        taskOptions("Send invoice every Friday").tap()
        app.buttons["Repeating"].tap()
        app.buttons["Friday"].tap()
        snap("11a-invoice-repeating-friday")
        app.buttons["Done"].firstMatch.tap()
        snap("11b-after-done")
        app.buttons["Settings"].tap()
        snap("11c-settings")
        app.swipeUp()
        snap("11d-settings-scrolled")
        app.swipeUp()
        snap("11e-settings-scrolled2")
    }
    func test12_hunt() {
        app.launch()
        openWork()
        app.buttons["Edit Work"].tap()
        snap("12a-card-pencil")
        // leave card edit mode
        let done = app.buttons.matching(NSPredicate(format: "label == 'Done' OR label == 'Done Editing'")).firstMatch
        if done.waitForExistence(timeout: 2) { done.tap() }
        snap("12b-after-pencil-done")
        let add = app.buttons["Add task"]
        if add.waitForExistence(timeout: 2) { add.press(forDuration: 1.2) }
        snap("12c-longpress-add")
        app.tap() // nothing
        let logo = app.buttons["This Week"]
        if logo.waitForExistence(timeout: 2) { logo.tap() }
        snap("12d-logo-tapped")
        if logo.exists { logo.press(forDuration: 1.2) }
        snap("12e-logo-longpress")
    }
    func test13_help() {
        app.launch()
        let doneEdit = app.buttons["Done editing Work"]
        if doneEdit.waitForExistence(timeout: 2) { doneEdit.tap() }
        snap("13a-home")
        app.buttons["Settings"].tap()
        let help = app.buttons["How to Use Tasquel"]
        var n = 0
        while !help.isHittable && n < 5 { app.swipeUp(); n += 1 }
        help.tap()
        snap("13b-help")
        for i in 0..<4 { app.swipeUp(); snap("13c-help-\(i)") }
    }
    func test14_helpTabs() {
        app.launch()
        app.buttons["Settings"].tap()
        let help = app.buttons["How to Use Tasquel"]
        var n = 0
        while !help.isHittable && n < 5 { app.swipeUp(); n += 1 }
        help.tap()
        let tabs = app.buttons.matching(NSPredicate(format: "label IN {'Tasks','Task Types','After This Week','Days and Dates','Category Cards'}")).allElementsBoundByIndex.map { $0.label }
        print("REVIEW: tabs \(tabs)")
        // find all tabs (scroll the tab row)
        for name in ["Category Cards", "Tasks", "Task Types", "After This Week", "Days and Dates"] {
            let t = app.buttons[name]
            if !t.exists { continue }
            if !t.isHittable { app.buttons["Weekly Checklist"].swipeLeft() }
            if t.isHittable { t.tap() } else { continue }
            let slug = name.replacingOccurrences(of: " ", with: "")
            snap("14-\(slug)-0")
            for i in 1...3 { app.swipeUp(); snap("14-\(slug)-\(i)") }
        }
        // whatever is to the right of Days and Dates
        let all = app.buttons.allElementsBoundByIndex.map { $0.label }
        print("REVIEW: buttons \(all)")
    }
    func smartAdd(_ text: String, shot: String) {
        var field = app.textFields["Add task"]
        if !field.waitForExistence(timeout: 2) {
            app.buttons["Add task"].tap()
            field = app.textFields["Add task"]
            _ = field.waitForExistence(timeout: 2)
        }
        if !field.hasFocus { field.tap() }
        field.typeText(text)
        Thread.sleep(forTimeInterval: 0.4)
        let sp = app.buttons["Smart Add"]
        if sp.waitForExistence(timeout: 2) { sp.tap() } else { print("REVIEW: no Smart Add button for \(text)") }
        Thread.sleep(forTimeInterval: 1.5)
        snap(shot)
    }

    func test15_smartAddAll() {
        app.launch()
        openWork()
        app.buttons["Edit Work"].tap()
        for t in ["Send invoice every Friday", "Standup notes every weekday", "Draft Q1 roadmap by Dec 12"] {
            let d = app.buttons["Delete \(t)"]
            if d.waitForExistence(timeout: 2) { d.tap() }
        }
        snap("15a-deleted-literal")
        app.buttons["Done editing Work"].tap()
        smartAdd("Send invoice every Friday", shot: "15b-sa-invoice")
        smartAdd("Gym Mon Wed Fri", shot: "15c-sa-gym")
        smartAdd("Call mom Sunday", shot: "15d-sa-callmom")
        smartAdd("Standup notes every weekday", shot: "15e-sa-standup")
        smartAdd("Draft Q1 roadmap by Dec 12", shot: "15f-sa-roadmap")
        let kb = app.buttons["Done"].firstMatch
        if kb.exists { kb.tap() }
        snap("15g-work-after-smart-add")
    }
    func test16_smartAddAll() {
        app.launch()
        openWork()
        smartAdd("Send invoice every Friday", shot: "16b-sa-invoice")
        smartAdd("Gym Mon Wed Fri", shot: "16c-sa-gym")
        smartAdd("Call mom Sunday", shot: "16d-sa-callmom")
        smartAdd("Standup notes every weekday", shot: "16e-sa-standup")
        smartAdd("Draft Q1 roadmap by Dec 12", shot: "16f-sa-roadmap")
        let kb = app.buttons["Done"].firstMatch
        if kb.exists { kb.tap() }
        snap("16g-work-after-smart-add")
    }
    func test17_fixUps() {
        app.launch()
        openWork()
        snap("17a-reopened")
        let setDate = app.buttons["Set date to Saturday, December 12"]
        if setDate.waitForExistence(timeout: 2) { setDate.tap(); snap("17b-set-date-tapped") }
        else { print("REVIEW: Set Date prompt gone after relaunch") }
        // Gym retry: delete and Smart Add with commas as in Help
        app.buttons["Edit Work"].tap()
        app.buttons["Delete Gym Mon Wed Fri"].tap()
        let doneEdit = app.buttons["Done editing Work"]
        if doneEdit.waitForExistence(timeout: 2) { doneEdit.tap() }
        smartAdd("Gym Mon, Wed, Fri", shot: "17c-sa-gym-commas")
        let kb = app.buttons["Done"].firstMatch
        if kb.exists { kb.tap() }
        // rename Call mom Sunday -> Call mom
        app.staticTexts["Call mom Sunday"].tap()
        Thread.sleep(forTimeInterval: 0.5)
        snap("17d-rename-tapped")
        let tf = app.textFields.matching(NSPredicate(format: "value == 'Call mom Sunday'")).firstMatch
        if tf.waitForExistence(timeout: 2) {
            tf.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 7))
            tf.typeText("\n")
        } else { print("REVIEW: no rename field") }
        snap("17e-renamed")
    }
    func rename(_ old: String, deleteChars: Int, shot: String) {
        app.staticTexts[old].tap()
        let tf = app.textFields["Task name"]
        if tf.waitForExistence(timeout: 2) {
            tf.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: deleteChars))
            tf.typeText("\n")
        } else { print("REVIEW: no rename field for \(old)") }
        Thread.sleep(forTimeInterval: 0.5)
        snap(shot)
    }

    func test18_cleanUp() {
        app.launch()
        openWork()
        rename("Call mom Sunday", deleteChars: 7, shot: "18a-renamed-callmom")
        let kb = app.buttons["Done"].firstMatch
        if kb.exists { kb.tap() }
        app.buttons["Edit Work"].tap()
        snap("18b-edit-mode")
        app.buttons["Delete Gym Mon Wed Fri"].tap()
        snap("18c-after-delete-gym")
        app.buttons["Done editing Work"].tap()
        snap("18d-after-done-editing")
        // Roadmap: set date by hand from the options calendar
        taskOptions("Draft Q1 roadmap by Dec 12").tap()
        app.buttons["Add a date"].tap()
        snap("18e-date-picker")
    }
    func test19_dateAndPriorityHunt() {
        app.launch()
        openWork()
        taskOptions("Draft Q1 roadmap by Dec 12").tap()
        app.buttons["Add a date"].tap()
        app.buttons["Next month"].tap()
        app.buttons["Saturday, December 12"].tap()
        snap("19a-picked-dec12")
        app.buttons["Set"].tap()
        snap("19b-after-set")
        let done = app.buttons["Done"].firstMatch
        if done.exists && done.isHittable { done.tap() }
        snap("19c-after-options-done")
        rename("Draft Q1 roadmap by Dec 12", deleteChars: 10, shot: "19d-renamed-roadmap")
        let kb = app.buttons["Done"].firstMatch
        if kb.exists { kb.tap() }
        // Goal 3: p1. Try long-press and swipe on the task row
        let t = app.staticTexts["Draft Q1 roadmap"]
        if t.waitForExistence(timeout: 2) {
            t.press(forDuration: 1.2)
            snap("19e-longpress-task")
            if app.textFields["Task name"].exists { app.buttons["Done"].firstMatch.tap() }
            let t2 = app.staticTexts["Draft Q1 roadmap"]
            t2.swipeLeft()
            snap("19f-swipe-left-task")
            t2.swipeRight()
            snap("19g-swipe-right-task")
        } else { print("REVIEW: roadmap title not found") }
    }
    /// The drag handle sits just right of a task's trash button in card edit mode.
    func handle(_ title: String) -> XCUICoordinate {
        let trash = app.buttons["Delete \(title)"]
        let origin = app.coordinate(withNormalizedOffset: .zero)
        return origin.withOffset(CGVector(dx: trash.frame.maxX + 20, dy: trash.frame.midY))
    }

    func test20_pinMoveReorder() {
        app.launch()
        openWork()
        app.buttons["Edit Work"].tap()
        snap("20a0-card-edit")
        let pin = app.buttons.matching(NSPredicate(format: "identifier == 'Pin Draft Q1 roadmap' OR label BEGINSWITH 'Pin Draft Q1'")).firstMatch
        if pin.waitForExistence(timeout: 3) { pin.tap() } else { print("REVIEW: no pin for roadmap") }
        snap("20a-pinned-roadmap")
        // Goal 4: drag Call mom by its handle onto the Personal card
        let personal = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'Open Personal' OR label BEGINSWITH 'Personal'")).firstMatch
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let target = origin.withOffset(CGVector(dx: personal.frame.midX, dy: personal.frame.midY))
        print("REVIEW: personal frame \(personal.frame)")
        handle("Call mom").press(forDuration: 0.8, thenDragTo: target, withVelocity: .slow, thenHoldForDuration: 0.8)
        snap("20b-drag-callmom-to-personal")
        // Goal 6: reorder inside Work: drag Gym above Send invoice
        if app.buttons["Delete Gym"].exists && app.buttons["Delete Send invoice"].exists {
            let above = origin.withOffset(CGVector(dx: app.buttons["Delete Send invoice"].frame.maxX + 20, dy: app.buttons["Delete Send invoice"].frame.minY - 8))
            handle("Gym").press(forDuration: 0.8, thenDragTo: above, withVelocity: .slow, thenHoldForDuration: 0.6)
        }
        snap("20c-reorder-gym")
        let doneEdit = app.buttons["Done editing Work"]
        if doneEdit.exists { doneEdit.tap() }
        snap("20d-after-done")
    }
    func test21_moveUndoReorderCards() {
        app.launch()
        openWork()
        app.buttons["Edit Work"].tap()
        // Goal 4 workaround: remove from Work...
        app.buttons["Delete Call mom"].tap()
        snap("21a-deleted-callmom")
        // Goal 7: oops, delete Standup notes by mistake, then Undo
        app.buttons["Delete Standup notes"].tap()
        snap("21b-oops-deleted-standup")
        let undo = app.buttons["Undo delete"]
        if undo.waitForExistence(timeout: 3) { undo.tap() } else { print("REVIEW: no undo") }
        snap("21c-after-undo")
        let doneEdit = app.buttons["Done editing Work"]
        if doneEdit.exists { doneEdit.tap() }
        app.buttons["Close Work"].tap()
        // ...and add it in Personal
        let openP = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Open Personal'")).firstMatch
        openP.tap()
        snap("21d-personal-open")
        smartAdd("Call mom Sunday", shot: "21e-personal-callmom")
        let kb = app.buttons["Done"].firstMatch
        if kb.exists { kb.tap() }
        app.buttons["Close Personal"].tap()
        snap("21f-closed")
        // Goal 6b: reorder categories (Edit, hold and drag a card)
        app.buttons["Edit"].tap()
        let side = app.otherElements.matching(NSPredicate(format: "label BEGINSWITH 'Side Project'")).firstMatch
        let work = app.otherElements.matching(NSPredicate(format: "label BEGINSWITH 'Work'")).firstMatch
        print("REVIEW: side \(side.frame) work \(work.frame)")
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let from = origin.withOffset(CGVector(dx: side.frame.midX, dy: side.frame.midY))
        let to = origin.withOffset(CGVector(dx: work.frame.minX + 30, dy: work.frame.minY + 20))
        from.press(forDuration: 1.0, thenDragTo: to, withVelocity: .slow, thenHoldForDuration: 0.8)
        snap("21g-cards-reordered")
        app.buttons["Done Editing"].tap()
        snap("21h-home")
    }
    func test22_moveAndReorderCards() {
        app.launch()
        openWork()
        tapPaced(app.buttons["Edit Work"])
        snap("22a-card-edit")
        tapPaced(app.buttons["Delete Call mom"])
        snap("22b-deleted-callmom")
        let doneEdit = app.buttons["Done editing Work"]
        if doneEdit.exists { doneEdit.tap() }
        snap("22c")
        tapPaced(app.buttons["Close Work"])
        snap("22d-closed")
        let openP = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Open Personal'")).firstMatch
        tapPaced(openP)
        snap("22e-personal-open")
        smartAdd("Call mom Sunday", shot: "22f-personal-callmom")
        let kb = app.buttons["Done"].firstMatch
        if kb.exists { kb.tap() }
        snap("22g")
        let closeP = app.buttons["Close Personal"]
        if closeP.exists { tapPaced(closeP) }
        snap("22h-closed")
        tapPaced(app.buttons["Edit"])
        snap("22i-edit")
        let side = app.otherElements.matching(NSPredicate(format: "label BEGINSWITH 'Side Project'")).firstMatch
        let work = app.otherElements.matching(NSPredicate(format: "label BEGINSWITH 'Work'")).firstMatch
        print("REVIEW: side \(side.frame) work \(work.frame)")
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let from = origin.withOffset(CGVector(dx: side.frame.midX, dy: side.frame.midY))
        let to = origin.withOffset(CGVector(dx: work.frame.minX + 30, dy: work.frame.minY + 20))
        from.press(forDuration: 1.0, thenDragTo: to, withVelocity: .slow, thenHoldForDuration: 0.8)
        snap("22j-cards-reordered")
        app.buttons["Done Editing"].tap()
        snap("22k-home")
    }
    func test23_todayFilter() {
        app.launch()
        Thread.sleep(forTimeInterval: 1.0)
        tapPaced(app.buttons["Today, Saturday, November 14"])
        snap("23a-today-pill")
        let openAll = app.buttons["Open all cards"]
        if openAll.exists { tapPaced(openAll); snap("23b-today-all-open") }
        tapPaced(app.buttons["Sunday, November 15"])
        snap("23c-sunday-pill")
        tapPaced(app.buttons["Friday, November 13"])
        snap("23d-friday-pill")
        let showAll = app.buttons["Show All"]
        if showAll.exists { tapPaced(showAll) } else { tapPaced(app.buttons["Friday, November 13"]) }
        snap("23e-show-all")
        let closeAll = app.buttons["Close all cards"]
        if closeAll.exists { tapPaced(closeAll) }
    }
    func addOne(_ b: String, times: Int) {
        let btns = app.buttons.matching(NSPredicate(format: "label == 'Add 1'")).allElementsBoundByIndex
        let t = app.staticTexts[b]
        guard let btn = btns.min(by: { abs($0.frame.midY - t.frame.midY) < abs($1.frame.midY - t.frame.midY) }) else { return }
        for _ in 0..<times { btn.tap(); Thread.sleep(forTimeInterval: 0.4) }
    }

    func test24_doSomeWorkAndReview() {
        app.launch()
        Thread.sleep(forTimeInterval: 1.0)
        openWork()
        tapPaced(app.buttons["Complete Send invoice"])
        snap("24a-invoice-done")
        // Gym: two sessions this week; standup: 4 of 5
        let gymT = app.staticTexts["Gym"]
        let addBtns = app.buttons.matching(NSPredicate(format: "label == 'Add 1'")).allElementsBoundByIndex
        print("REVIEW: add1 buttons \(addBtns.count) gym at \(gymT.frame)")
        // tasks below Standup notes' bar
        let allAdd = app.buttons.matching(NSPredicate(format: "label == 'Add 1'")).allElementsBoundByIndex.sorted { $0.frame.minY < $1.frame.minY }
        if allAdd.count >= 2 {
            for _ in 0..<2 { allAdd[0].tap(); Thread.sleep(forTimeInterval: 0.4) }
            for _ in 0..<4 { allAdd[1].tap(); Thread.sleep(forTimeInterval: 0.4) }
        }
        snap("24b-progress")
        tapPaced(app.buttons["Close Work"])
        snap("24c-home-review")
        tapPaced(app.buttons["Go to week"])
        snap("24d-go-to-week")
        let weeks = app.buttons["Weeks"]
        if weeks.exists { tapPaced(weeks); snap("24e-weeks") }
    }
    func test25_planNextWeek() {
        app.launch()
        Thread.sleep(forTimeInterval: 1.0)
        tapPaced(app.buttons["Next week"])
        snap("25a-next-week")
        openWork()
        smartAdd("Prep sprint planning on Monday", shot: "25b-next-sprint")
        let kb = app.buttons["Done"].firstMatch
        if kb.exists { tapPaced(kb) }
        tapPaced(app.buttons["Close Work"])
        let openP = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Open Personal'")).firstMatch
        tapPaced(openP)
        smartAdd("Book dentist", shot: "25c-next-dentist")
        let kb2 = app.buttons["Done"].firstMatch
        if kb2.exists { tapPaced(kb2) }
        let closeP = app.buttons["Close Personal"]
        if closeP.exists { tapPaced(closeP) }
        snap("25d-next-week-planned")
        let home = app.buttons["This Week"]
        tapPaced(home)
        snap("25e-back-this-week")
    }
    func test26_speedAndEndOfDay() {
        app.launch()
        Thread.sleep(forTimeInterval: 1.0)
        snap("26a-start-home")
        // Speed test from the closed home screen: card, Add Task, type, sparkles
        var taps = 0
        let t0 = Date()
        let openP = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Open Personal'")).firstMatch
        openP.tap(); taps += 1
        let add = app.buttons["Add task"]
        _ = add.waitForExistence(timeout: 3)
        add.tap(); taps += 1
        let field = app.textFields["Add task"]
        _ = field.waitForExistence(timeout: 3)
        field.typeText("Call dentist Tuesday")
        app.buttons["Smart Add"].tap(); taps += 1
        let made = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Call dentist'")).firstMatch
        _ = made.waitForExistence(timeout: 3)
        print("REVIEW: speed taps=\(taps) seconds=\(Date().timeIntervalSince(t0))")
        snap("26b-speed-result")
        let kb = app.buttons["Done"].firstMatch
        if kb.exists { tapPaced(kb) }
        // End of day look
        let closeP = app.buttons["Close Personal"]
        if closeP.exists { tapPaced(closeP) }
        snap("26c-end-of-day-closed")
        tapPaced(app.buttons["Open all cards"])
        snap("26d-end-of-day-open")
        app.swipeUp()
        snap("26e-end-of-day-open-scrolled")
    }
}
