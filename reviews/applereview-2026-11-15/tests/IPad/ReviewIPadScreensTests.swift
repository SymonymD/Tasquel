import XCTest

/// iPad review, 2026-11-15: popups, the moved pop-up, the bar's house, What's New, Help and
/// Add Category on iPad, in both orientations and resized windows.
final class ReviewIPadScreensTests: XCTestCase {
    typealias L = ReviewIPadLanesTests

    override func setUpWithError() throws {
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
        super.tearDown()
    }

    private func optionsButtons(_ app: XCUIApplication) -> [XCUIElement] {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Task options:")).allElementsBoundByIndex
            // Not under the frosted header or the bottom bar (taps there don't reach rows).
            .filter { $0.isHittable && $0.frame.minY > 125 && $0.frame.maxY < app.windows.firstMatch.frame.maxY - 90 }
            .sorted { $0.frame.minY < $1.frame.minY }
    }

    /// The popup's parts are all inside the window and can be tapped.
    private func assertPopupOnScreen(_ app: XCUIApplication, _ when: String) {
        let window = app.windows.firstMatch.frame
        XCTAssertTrue(app.staticTexts["DAY"].waitForExistence(timeout: 3), "\(when): the popup opened")
        Thread.sleep(forTimeInterval: 0.6)
        let dateCell = app.buttons.matching(NSPredicate(format: "label == %@ OR label BEGINSWITH %@", "Add a date", "Date: ")).firstMatch
        for element in [app.staticTexts["DAY"], dateCell, app.buttons["Done"].firstMatch,
                        app.buttons["Carry Over"].firstMatch, app.buttons["Checkbox"].firstMatch] {
            let f = element.frame
            print("REVIEW \(when) \(element.label) \(f)")
            XCTAssertTrue(window.insetBy(dx: -1, dy: -1).contains(f), "\(when): \(element.label) \(f) inside window \(window)")
        }
        XCTAssertTrue(app.buttons["Done"].firstMatch.isHittable, "\(when): Done can be tapped")
    }

    private func assertCalendarOnScreen(_ app: XCUIApplication, _ when: String) {
        let window = app.windows.firstMatch.frame
        app.buttons.matching(NSPredicate(format: "label == %@ OR label BEGINSWITH %@", "Add a date", "Date: ")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Until"].waitForExistence(timeout: 3), "\(when): the calendar opened")
        Thread.sleep(forTimeInterval: 0.6)
        for element in [app.staticTexts["Until"], app.buttons["Set"].firstMatch, app.buttons["Cancel"].firstMatch] {
            print("REVIEW \(when) calendar \(element.label) \(element.frame)")
            XCTAssertTrue(window.insetBy(dx: -1, dy: -1).contains(element.frame), "\(when): calendar \(element.label) inside window")
        }
        XCTAssertTrue(app.buttons["Set"].firstMatch.isHittable, "\(when): Set can be tapped")
    }

    /// The type/mode/day popup and its date calendar, from rows at the top, middle and
    /// bottom of the screen, in landscape lanes and in portrait: fully on screen.
    @MainActor
    func testOptionsPopupFromTopMiddleBottomRows() throws {
        for orientation in [UIDeviceOrientation.landscapeLeft, .portrait] {
            let tag = orientation == .portrait ? "portrait" : "landscape"
            let app = L.launchDemo(orientation: orientation)
            for name in ["Errands", "Work", "Study"] { L.open(name, in: app) }
            let rows = optionsButtons(app)
            XCTAssertGreaterThan(rows.count, 3)
            let picks = [("top", rows.first!), ("middle", rows[rows.count / 2]), ("bottom", rows.last!)]
            for (place, button) in picks {
                print("REVIEW \(tag) \(place) row button \(button.label) \(button.frame)")
                button.tap()
                assertPopupOnScreen(app, "\(tag) \(place)")
                L.shot("popup-\(tag)-\(place)")
                assertCalendarOnScreen(app, "\(tag) \(place)")
                L.shot("popup-\(tag)-\(place)-calendar")
                app.buttons["Cancel"].firstMatch.tap()
                _ = app.staticTexts["Until"].waitForNonExistence(timeout: 3)
                if app.buttons["Done"].firstMatch.exists { app.buttons["Done"].firstMatch.tap() }
                XCTAssertTrue(app.staticTexts["DAY"].waitForNonExistence(timeout: 3), "closed")
                Thread.sleep(forTimeInterval: 0.6)
            }
            app.terminate()
        }
    }

    /// A new task given a day gone by (Monday, on a Sunday): the screen pages to next week,
    /// "Added to next week" pops up in the window, Back to This Week returns, and the
    /// landscape lanes and open cards survive both pages.
    @MainActor
    func testAddedToNextWeekPopupAndPaging() throws {
        try XCTSkipIf(Calendar(identifier: .gregorian).component(.weekday, from: Date()) == 2, "nothing has gone by on a Monday")
        let app = L.launchDemo(orientation: .landscapeLeft)
        L.open("Errands", in: app)
        L.open("Work", in: app)
        let errandsBefore = L.openSpan("Errands", in: app)
        let thisWeek = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Week of")).firstMatch.label
        // Errands's add row: the one under Errands's span.
        let plus = app.buttons.matching(NSPredicate(format: "label == %@", "Add task")).allElementsBoundByIndex
            .min { abs($0.frame.minX - errandsBefore.minX) + abs($0.frame.minY - errandsBefore.maxY) < abs($1.frame.minX - errandsBefore.minX) + abs($1.frame.minY - errandsBefore.maxY) }!
        plus.tap()
        let field = app.textFields["Add task"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.typeText("Call dentist")
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "New task options:")).allElementsBoundByIndex
            .min { abs($0.frame.midY - field.frame.midY) < abs($1.frame.midY - field.frame.midY) }!.tap()
        // Monday has gone by (today is Sunday): the popup's Add Task adds it to next week.
        XCTAssertTrue(app.staticTexts["DAY"].waitForExistence(timeout: 3))
        app.buttons["Monday"].tap()
        L.shot("moved-00-monday-picked")
        app.buttons["Add Task"].firstMatch.tap()
        let popup = app.staticTexts["Added to next week"]
        XCTAssertTrue(popup.waitForExistence(timeout: 5), "the pop-up says where the screen went")
        Thread.sleep(forTimeInterval: 0.8)
        L.shot("moved-01-popup")
        let window = app.windows.firstMatch.frame
        let ok = app.buttons["Moved OK"], back = app.buttons["Moved Back to This Week"]
        print("REVIEW popup \(popup.frame) ok \(ok.frame) back \(back.frame) window \(window)")
        XCTAssertTrue(window.contains(ok.frame) && window.contains(back.frame), "its buttons are in the window")
        XCTAssertEqual(popup.frame.midX, window.midX, accuracy: 30, "centered in the window")
        XCTAssertNotEqual(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Week of")).firstMatch.label, thisWeek)
        XCTAssertTrue(app.buttons["Edit Errands"].exists, "Errands is open on next week too")
        XCTAssertTrue(app.staticTexts["Call dentist"].exists, "the task is on next week")
        // Back to This Week.
        back.tap()
        XCTAssertTrue(popup.waitForNonExistence(timeout: 3))
        Thread.sleep(forTimeInterval: 1.5)
        L.shot("moved-02-back")
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Week of")).firstMatch.label, thisWeek, "back on this week")
        XCTAssertFalse(app.staticTexts["Call dentist"].exists, "not on this week")
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "identifier == %@", "Bar Back to This Week")).firstMatch.exists, "house gone")
        XCTAssertTrue(app.buttons["Edit Errands"].exists && app.buttons["Edit Work"].exists, "the open cards stay open")
        let errandsAfter = L.openSpan("Errands", in: app)
        XCTAssertEqual(errandsAfter.minX, errandsBefore.minX, accuracy: 2, "Errands keeps its lane")
    }

    /// On iPad the bar's house stops 10pt from the week selector on both sides: left of it
    /// on a later week, right of it on an earlier one.
    @MainActor
    func testBarHouseSameGapBothSides() throws {
        for orientation in [UIDeviceOrientation.portrait, .landscapeLeft] {
            let tag = orientation == .portrait ? "portrait" : "landscape"
            let app = L.launchDemo(orientation: orientation)
            let house = app.buttons.matching(NSPredicate(format: "identifier == %@", "Bar Back to This Week")).firstMatch
            let prev = app.buttons["Previous week"], next = app.buttons["Next week"]
            next.tap()
            XCTAssertTrue(house.waitForExistence(timeout: 3))
            Thread.sleep(forTimeInterval: 1.5)
            L.shot("house-\(tag)-later")
            let leftGap = prev.frame.minX - house.frame.maxX
            print("REVIEW \(tag) later: house \(house.frame) prev \(prev.frame) gap \(leftGap)")
            house.tap()
            XCTAssertTrue(house.waitForNonExistence(timeout: 3))
            Thread.sleep(forTimeInterval: 1)
            prev.tap()
            XCTAssertTrue(house.waitForExistence(timeout: 3))
            Thread.sleep(forTimeInterval: 1.5)
            L.shot("house-\(tag)-earlier")
            let rightGap = house.frame.minX - next.frame.maxX
            print("REVIEW \(tag) earlier: house \(house.frame) next \(next.frame) gap \(rightGap) edit? \(app.buttons["Edit"].exists) settings \(app.buttons["Settings"].frame)")
            XCTAssertEqual(leftGap, rightGap, accuracy: 2, "\(tag): the same gap on both sides")
            app.terminate()
        }
    }

    /// The What's New pill beside the mark (and the window's controls when windowed), in a
    /// full window and resized ones: it doesn't cover the title or the mark.
    @MainActor
    func testWhatsNewPillInResizedWindows() throws {
        let app = L.launchDemo(["-demoWhatsNew"], orientation: .landscapeLeft)
        let pill = app.buttons["What's New?"]
        XCTAssertTrue(pill.waitForExistence(timeout: 8))
        let title = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Week of")).firstMatch
        for (i, width) in [1376.0, 900.0, 700.0, 520.0, 1376.0].enumerated() {
            if i > 0 { L.resizeWindow(app, toWidth: width) }
            Thread.sleep(forTimeInterval: 2)
            let window = app.windows.firstMatch.frame
            L.shot("whatsnew-\(i)-\(Int(width))")
            let mark = app.buttons.matching(NSPredicate(format: "label == %@", "This Week")).firstMatch
            print("REVIEW whatsnew at \(Int(width)): window \(window) pill \(pill.frame) exists \(pill.exists) title \(title.frame) mark \(mark.frame)")
            XCTAssertTrue(pill.exists, "the pill is there at \(Int(width))")
            if pill.exists {
                XCTAssertFalse(pill.frame.insetBy(dx: 2, dy: 2).intersects(title.frame), "pill clear of the title at \(Int(width))")
                XCTAssertTrue(window.insetBy(dx: -1, dy: -1).contains(pill.frame), "pill inside the window at \(Int(width))")
                XCTAssertTrue(pill.isHittable, "pill can be tapped at \(Int(width))")
            }
        }
        pill.tap()
        let sheet = app.buttons["Continue"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 3))
        Thread.sleep(forTimeInterval: 1)
        L.shot("whatsnew-sheet")
    }

    /// Help's tabs in a narrow window: every pill can be reached and opens its page.
    @MainActor
    func testHelpTabsInNarrowWindow() throws {
        let app = L.launchDemo(orientation: .landscapeLeft)
        L.resizeWindow(app, toWidth: 400)
        let window = app.windows.firstMatch.frame
        print("REVIEW help window \(window)")
        app.buttons["Settings"].tap()
        let help = app.settingsButton("How to Use Tasquel")
        help.tap()
        XCTAssertTrue(app.staticTexts["Is there a Someday list?"].waitForExistence(timeout: 3))
        Thread.sleep(forTimeInterval: 1)
        L.shot("help-narrow-0")
        let expected = ["Weeks": "Navigate Weeks", "Cards": "Close All Cards", "Tasks": "Smart Add"]
        for tab in ["Q&A", "Weeks", "Cards", "Tasks", "Types", "Modes", "Dates"] {
            let pill = app.buttons[tab].firstMatch
            print("REVIEW help pill \(tab) exists \(pill.exists) frame \(pill.frame)")
        }
        for tab in ["Weeks", "Cards", "Tasks", "Types", "Modes", "Dates"] {
            let pill = app.buttons[tab].firstMatch
            XCTAssertTrue(pill.waitForExistence(timeout: 2), "\(tab) pill")
            // The row scrolls sideways where the pills don't fit (by design).
            for _ in 0..<3 where !window.insetBy(dx: -1, dy: -1).contains(pill.frame) {
                let origin = app.coordinate(withNormalizedOffset: .zero)
                origin.withOffset(CGVector(dx: window.maxX - 40, dy: pill.frame.midY))
                    .press(forDuration: 0.05, thenDragTo: origin.withOffset(CGVector(dx: window.minX + 60, dy: pill.frame.midY)))
                Thread.sleep(forTimeInterval: 0.6)
            }
            print("REVIEW help pill \(tab) before tap \(pill.frame)")
            pill.tap()
            Thread.sleep(forTimeInterval: 0.8)
            XCTAssertTrue(pill.isSelected, "\(tab) selected after tap")
            if let entry = expected[tab] { XCTAssertTrue(app.staticTexts[entry].waitForExistence(timeout: 2), "\(tab) shows \(entry)") }
            XCTAssertTrue(window.insetBy(dx: -1, dy: -1).contains(pill.frame), "\(tab) pill inside the window: \(pill.frame)")
        }
        L.shot("help-narrow-dates")
    }

    /// Add Category on iPad: a sheet of sensible size that stays open after an add, with
    /// the field cleared and keeping the keyboard.
    @MainActor
    func testAddCategorySheetStaysOpen() throws {
        let app = L.launchDemo(orientation: .landscapeLeft)
        app.buttons["Edit"].tap()
        let tile = app.buttons["Add Category"].firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 3))
        print("REVIEW tile \(tile.frame)")
        tile.tap()
        let create = app.buttons["Create New Category"]
        XCTAssertTrue(create.waitForExistence(timeout: 3))
        create.tap()
        let field = app.textFields["Category name"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        Thread.sleep(forTimeInterval: 1)
        let nav = app.navigationBars["Add Category"]
        print("REVIEW sheet nav \(nav.frame) window \(app.windows.firstMatch.frame)")
        XCTAssertLessThan(nav.frame.width, app.windows.firstMatch.frame.width * 0.8, "a form sheet, not stretched across")
        field.tap()
        field.typeText("School")
        L.shot("addcat-0-typed")
        app.buttons.matching(NSPredicate(format: "label == %@", "Add Category")).allElementsBoundByIndex
            .filter { $0.isHittable && $0.frame.minY > field.frame.minY }.first?.tap()
        let added = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Added School")).firstMatch
        XCTAssertTrue(added.waitForExistence(timeout: 3), "says it was added")
        Thread.sleep(forTimeInterval: 0.8)
        L.shot("addcat-1-added")
        XCTAssertTrue(field.exists, "the sheet stays open")
        XCTAssertEqual((field.value as? String) ?? "", "Category name", "the field is cleared (placeholder)")
        XCTAssertTrue(app.keyboards.firstMatch.exists, "keeps the keyboard")
        // Rotate with the sheet up.
        XCUIDevice.shared.orientation = .portrait
        Thread.sleep(forTimeInterval: 2)
        L.shot("addcat-2-rotated")
        XCTAssertTrue(field.exists && added.exists, "sheet and note survive rotating")
        // The sheet's own Done (a checkmark in its bar).
        let sheetDone = nav.buttons.allElementsBoundByIndex.last!
        print("REVIEW sheet done \(sheetDone.label) \(sheetDone.frame)")
        sheetDone.tap()
        Thread.sleep(forTimeInterval: 1.5)
        L.shot("addcat-3-closed")
        XCTAssertFalse(field.exists, "the sheet closed")
        XCTAssertTrue(L.closedCard("School", in: app).waitForExistence(timeout: 3), "School is in the week")
        XCTAssertFalse(app.buttons["Add Category"].exists, "Edit ended once the sheet closed after an add")
    }

    /// Help open on a tab, then the iPad turned (and the window resized): the page shown is
    /// still the picked tab's, whole, not offset between two pages.
    @MainActor
    func testHelpPageSurvivesRotationAndResize() throws {
        let app = L.launchDemo(orientation: .landscapeLeft)
        app.buttons["Settings"].tap()
        app.settingsButton("How to Use Tasquel").tap()
        XCTAssertTrue(app.staticTexts["Is there a Someday list?"].waitForExistence(timeout: 3))
        app.buttons["Modes"].firstMatch.tap()
        let entry = app.staticTexts["Carry Over"].firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 3))
        Thread.sleep(forTimeInterval: 0.8)
        let nav = app.navigationBars.firstMatch
        let before = entry.frame.minX - nav.frame.minX
        print("REVIEW help modes entry \(entry.frame) nav \(nav.frame)")
        L.shot("help-rotate-0")
        XCUIDevice.shared.orientation = .portrait
        Thread.sleep(forTimeInterval: 2.5)
        L.shot("help-rotate-1-portrait")
        print("REVIEW help after rotate entry \(entry.frame) hittable \(entry.isHittable) nav \(app.navigationBars.firstMatch.frame) modes selected \(app.buttons["Modes"].firstMatch.isSelected)")
        XCTAssertTrue(app.buttons["Modes"].firstMatch.isSelected, "Modes still picked")
        XCTAssertTrue(entry.isHittable, "Modes' page still on screen after rotating")
        XCTAssertEqual(entry.frame.minX - app.navigationBars.firstMatch.frame.minX, before, accuracy: 4, "the page isn't offset after rotating")
        XCUIDevice.shared.orientation = .landscapeLeft
        Thread.sleep(forTimeInterval: 2.5)
        L.shot("help-rotate-2-landscape")
        print("REVIEW help after rotate back entry \(entry.frame) hittable \(entry.isHittable) nav \(app.navigationBars.firstMatch.frame)")
        XCTAssertTrue(entry.isHittable, "Modes' page on screen after rotating back")
        XCTAssertEqual(entry.frame.minX - app.navigationBars.firstMatch.frame.minX, before, accuracy: 4, "not offset after rotating back")
    }

    /// Turning the iPad with a task's popup open: the popup stays whole on screen (or closes),
    /// never half off the window.
    @MainActor
    func testRotatingWithOptionsPopupOpen() throws {
        let app = L.launchDemo(orientation: .landscapeLeft)
        L.open("Work", in: app)
        L.open("Study", in: app)
        let rows = optionsButtons(app)
        rows.last!.tap()
        assertPopupOnScreen(app, "before rotating")
        XCUIDevice.shared.orientation = .portrait
        Thread.sleep(forTimeInterval: 2.5)
        L.shot("rotate-popup-portrait")
        if app.staticTexts["DAY"].exists {
            assertPopupOnScreen(app, "after rotating")
        } else {
            print("REVIEW popup closed on rotating")
        }
        XCUIDevice.shared.orientation = .landscapeLeft
        Thread.sleep(forTimeInterval: 2.5)
        L.shot("rotate-popup-landscape")
        if app.staticTexts["DAY"].exists { assertPopupOnScreen(app, "after rotating back") }
    }

    /// Renaming a task, then turning the iPad: the rename field keeps its words and stays
    /// above the keyboard.
    @MainActor
    func testRotatingWhileRenaming() throws {
        let app = L.launchDemo(orientation: .portrait)
        L.open("Appointments", in: app)
        L.open("Work", in: app)
        L.open("Study", in: app)
        let name = app.staticTexts["Call the vet"]
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        if !name.isHittable { app.swipeUp(velocity: .slow) }
        name.tap()
        let field = app.textFields["Task name"]
        XCTAssertTrue(field.waitForExistence(timeout: 3), "rename field")
        field.typeText(" today")
        XCUIDevice.shared.orientation = .landscapeLeft
        Thread.sleep(forTimeInterval: 3)
        L.shot("rename-rotated-landscape")
        let f = app.textFields["Task name"]
        let kb = app.keyboards.firstMatch
        print("REVIEW rename after rotate field \(f.frame) value \(String(describing: f.value)) keyboard \(kb.exists ? kb.frame : .null)")
        XCTAssertEqual(f.value as? String, "Call the vet today", "words kept")
        if kb.exists { XCTAssertLessThanOrEqual(f.frame.maxY, kb.frame.minY + 1, "field above the keyboard") }
        XCTAssertGreaterThan(f.frame.minY, 90, "field below the header")
    }

    /// Typing in Add Category's form sheet: the main screen's bottom bar (Settings, the week
    /// selector, Done), visible around the sheet on iPad, stays at the bottom behind the
    /// keyboard instead of riding up on top of it.
    @MainActor
    func testBarStaysDownWhileTypingInAddCategorySheet() throws {
        let app = L.launchDemo(orientation: .landscapeLeft)
        let settings = app.buttons["Settings"]
        let barY = settings.frame.minY
        app.buttons["Edit"].tap()
        app.buttons["Add Category"].firstMatch.tap()
        app.buttons["Create New Category"].tap()
        let field = app.textFields["Category name"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 3))
        Thread.sleep(forTimeInterval: 1)
        L.shot("bar-behind-sheet-keyboard")
        print("REVIEW bar before \(barY) now \(settings.frame) keyboard \(keyboard.frame)")
        XCTAssertEqual(settings.frame.minY, barY, accuracy: 2, "the bar stays where it was, behind the keyboard")
    }
}
