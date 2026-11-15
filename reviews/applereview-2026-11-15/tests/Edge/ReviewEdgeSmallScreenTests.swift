import XCTest
import UIKit

/// Review 2026-11-15 (Edge cases and small screens), on an iPhone SE: the moved pop-up and
/// Add Category with the keyboard up, 20+ categories with two pinned, a list of 100 items
/// with duplicates pasted at once.
final class ReviewEdgeSmallScreenTests: ReviewEdgeCase {
    /// A new task for a day gone by, added with Return: the keyboard stays up (Return adds
    /// and keeps editing), the screen goes to next week and the pop-up shows. Its OK and Back
    /// to This Week must be on screen, not under the keyboard; Back goes back.
    @MainActor
    func testMovedPopUpWithKeyboardUpOnSE() throws {
        try XCTSkipIf(Calendar(identifier: .gregorian).component(.weekday, from: Date()) == 2, "nothing has gone by on a Monday")
        let app = launch("America/New_York", id: "edge-moved-\(UUID().uuidString)")
        open("Errands", in: app)
        let thisWeek = weekTitle(app)
        let field = app.addTaskField
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        if app.keyboards.count == 0 { field.tap() }
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "New task options:")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["DAY"].waitForExistence(timeout: 3))
        app.buttons["Monday"].tap()
        app.buttons["Done"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["DAY"].waitForNonExistence(timeout: 3))
        let again = app.addTaskField
        if app.keyboards.count == 0 { again.tap() }
        again.typeText("Call the dentist about the crown that came loose\n")
        let ok = app.buttons["Moved OK"], back = app.buttons["Moved Back to This Week"]
        XCTAssertTrue(ok.waitForExistence(timeout: 5), "the pop-up")
        sleep(1)
        shot("edge-moved-popup-keyboard-SE")
        let keyboardTop = app.keyboards.firstMatch.exists ? app.keyboards.firstMatch.frame.minY : app.windows.firstMatch.frame.maxY
        print("REVIEW moved: keyboard=\(app.keyboards.firstMatch.exists) top=\(keyboardTop) ok=\(ok.frame) back=\(back.frame) hittable=\(ok.isHittable),\(back.isHittable)")
        XCTAssertTrue(ok.isHittable && back.isHittable, "both buttons can be tapped")
        XCTAssertLessThanOrEqual(back.frame.maxY, keyboardTop, "not under the keyboard")
        back.tap()
        sleep(2)
        XCTAssertEqual(weekTitle(app), thisWeek, "Back to This Week goes back")
        shot("edge-moved-back-SE")
        let house = app.buttons.matching(NSPredicate(format: "identifier == %@", "Bar Back to This Week")).firstMatch
        XCTAssertFalse(house.exists && house.isHittable, "no house on this week")
    }

    /// Add Category on the SE with the keyboard up: the name field, Just this week, Cancel and
    /// Add Category all stay on screen; an add keeps the sheet, clears the field and says so;
    /// a 60-character name fits.
    @MainActor
    func testAddCategoryWithKeyboardUpOnSE() throws {
        let app = launch("America/New_York", id: "edge-addcat-\(UUID().uuidString)")
        app.buttons["Edit"].tap()
        let addCard = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Add Category")).firstMatch
        XCTAssertTrue(addCard.waitForExistence(timeout: 3))
        addCard.tap()
        app.buttons["Create New Category"].tap()
        let name = app.textFields["Category name"]
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        let long = "Home renovation projects and contractor calls for the spring"
        name.typeText(long)
        sleep(1)
        shot("edge-addcat-keyboard-SE")
        let toggle = app.switches.firstMatch
        // The sheet's button, not the Edit grid's Add Category tile behind the sheet.
        let add = app.buttons.matching(NSPredicate(format: "label == %@", "Add Category")).allElementsBoundByIndex
            .first { $0.frame.minY > toggle.frame.maxY - 1 } ?? app.buttons["Add Category"].firstMatch
        let keyboardTop = app.keyboards.firstMatch.exists ? app.keyboards.firstMatch.frame.minY : app.windows.firstMatch.frame.maxY
        print("REVIEW addcat keyboardTop=\(keyboardTop) toggle=\(toggle.frame) add=\(add.frame) hittable=\(toggle.isHittable),\(add.isHittable)")
        XCTAssertTrue(add.isHittable, "Add Category can be tapped with the keyboard up")
        XCTAssertLessThanOrEqual(add.frame.maxY, keyboardTop)
        add.tap()
        let added = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Added ")).firstMatch
        XCTAssertTrue(added.waitForExistence(timeout: 3), "the sheet says it was added")
        print("REVIEW addcat note: \(added.label) field='\(name.value ?? "")'")
        shot("edge-addcat-added-SE")
        app.navigationBars["Add Category"].buttons["Done"].tap()
        let card = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open \(long),")).firstMatch
        for _ in 0..<5 where !card.exists { app.swipeUp() }
        XCTAssertTrue(card.waitForExistence(timeout: 3), "the long-named card is there")
        shot("edge-addcat-longcard-SE")
    }

    /// 24 categories with two pinned: the pinned ones come first, a third pin can't be
    /// made, and the last card can be reached and opened.
    @MainActor
    func testTwentyFourCategoriesWithTwoPinned() throws {
        let app = launch("America/New_York", id: "edge-many-\(UUID().uuidString)")
        app.buttons["Edit"].tap()
        let addCard = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Add Category")).firstMatch
        XCTAssertTrue(addCard.waitForExistence(timeout: 3))
        addCard.tap()
        app.buttons["Create New Category"].tap()
        let name = app.textFields["Category name"]
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        for index in 1...18 {
            name.typeText(String(format: "Card %02d\n", index))
            Thread.sleep(forTimeInterval: 0.5)
        }
        app.navigationBars["Add Category"].buttons["Done"].tap()
        sleep(1)
        // Cards only ("Open Errands, …"), not the header's "Open all cards".
        let cards = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@ AND label CONTAINS %@", "Open ", ","))
        // Pin the last one added and one in the middle.
        if app.buttons["Edit"].exists { app.buttons["Edit"].tap() }
        let last = app.buttons["Pin Card 18"]
        for _ in 0..<8 where !(last.exists && last.isHittable) { app.swipeUp(velocity: .slow) }
        XCTAssertTrue(last.isHittable, "Card 18's pin can be reached")
        last.tap()
        let middle = app.buttons["Pin Card 09"]
        for _ in 0..<8 where !(middle.exists && middle.isHittable) { app.swipeDown(velocity: .slow) }
        middle.tap()
        let third = app.buttons["Pin Work"]
        for _ in 0..<8 where !(third.exists && third.isHittable) { app.swipeDown(velocity: .slow) }
        XCTAssertFalse(third.isEnabled, "two pins at most")
        app.buttons["Done Editing"].tap()
        sleep(1)
        for _ in 0..<8 { app.swipeDown(velocity: .fast) }
        shot("edge-many-top-SE")
        let ordered = cards.allElementsBoundByIndex.filter { $0.isHittable }.sorted {
            ($0.frame.minY, $0.frame.minX) < ($1.frame.minY, $1.frame.minX)
        }.map(\.label)
        print("REVIEW many first cards: \(ordered.prefix(4))")
        XCTAssertTrue(ordered.first?.hasPrefix("Open Card 09,") ?? false, "pinned first, in their own order")
        XCTAssertTrue(ordered.dropFirst().first?.hasPrefix("Open Card 18,") ?? false)
        XCTAssertGreaterThanOrEqual(cards.count, 20)
    }

    /// A list of 100 items, ten of them the same, pasted at once: every line becomes an item,
    /// the duplicates are marked, and the app stays responsive.
    @MainActor
    func testHundredItemListWithDuplicatesPasted() throws {
        let app = launch("America/New_York", id: "edge-hundred-\(UUID().uuidString)")
        open("Errands", in: app)
        let field = app.addTaskField
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        if app.keyboards.count == 0 { field.tap() }
        field.typeText("Groceries")
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "New task options")).firstMatch.tap()
        app.buttons["List"].firstMatch.tap()
        app.buttons["Add Task"].tap()
        let item = app.textFields["Add item"]
        XCTAssertTrue(item.waitForExistence(timeout: 3))
        var lines = (1...90).map { "Item \($0)" }
        lines += Array(repeating: "Milk", count: 10)
        UIPasteboard.general.string = lines.joined(separator: "\n") + "\n"
        item.press(forDuration: 1.2)
        let paste = app.menuItems["Paste"]
        XCTAssertTrue(paste.waitForExistence(timeout: 3), "the edit menu offers Paste")
        let start = Date()
        paste.tap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["Allow Paste"]
        if allow.waitForExistence(timeout: 2) { allow.tap() } else if app.buttons["Allow Paste"].exists { app.buttons["Allow Paste"].tap() }
        let groceries = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Groceries")).firstMatch
        XCTAssertTrue(groceries.waitForExistence(timeout: 30))
        sleep(2)
        let elapsed = Date().timeIntervalSince(start)
        shot("edge-hundred-pasted-SE")
        // Still typing (the keyboard is up): the field being typed in should be in view,
        // below the 100 new items, not left 4,000pt under the screen.
        let typing = app.textFields["Add item"]
        let keyboardTop = app.keyboards.firstMatch.exists ? app.keyboards.firstMatch.frame.minY : app.windows.firstMatch.frame.maxY
        print("REVIEW hundred field after paste: keyboard=\(app.keyboards.count) field=\(typing.frame) keyboardTop=\(keyboardTop) hittable=\(typing.isHittable)")
        XCTAssertTrue(app.keyboards.count > 0, "still typing after the paste")
        XCTAssertTrue(typing.frame.minY < keyboardTop && typing.frame.maxY > 0,
                      "the Add Item field being typed in stays in view (it's at y=\(typing.frame.minY), the keyboard at \(keyboardTop))")
        let milk = app.staticTexts.matching(NSPredicate(format: "label == %@", "Milk"))
        let marked = app.staticTexts.matching(NSPredicate(format: "label == %@ AND value == %@", "Milk", "duplicate"))
        print("REVIEW hundred: elapsed=\(elapsed) milk=\(milk.count) marked=\(marked.count) note=\(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "already in")).firstMatch.label)")
        // Fold it: the count says how many items there are.
        let fold = app.buttons["Fold Groceries"]
        XCTAssertTrue(fold.waitForExistence(timeout: 5))
        let foldStart = Date()
        fold.tap()
        let folded = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Groceries")).firstMatch
        sleep(1)
        print("REVIEW hundred folded: '\(folded.label)' value=\(folded.value ?? "") foldTime=\(Date().timeIntervalSince(foldStart))")
        shot("edge-hundred-folded-SE")
        XCTAssertTrue(folded.label.contains("0 of 100") || (folded.value as? String ?? "").contains("0 of 100"),
                      "all 100 lines became items (\(folded.label))")
        fold.tap()
        sleep(1)
        XCTAssertEqual(marked.count, 10, "the ten Milks are marked duplicate")
    }
}

/// Another language and region on the SE: right-to-left Arabic (Saudi Arabia, whose calendar
/// is Islamic) and German (commas as decimals). The app isn't translated, so the words stay
/// English; the week, the day strip and the dates must still agree with each other.
final class ReviewEdgeLocaleTests: ReviewEdgeCase {
    /// Region Saudi Arabia (its calendar is Islamic): the week title is written in the
    /// Islamic calendar ("Week of 29 Jmd. I") while the day strip under it shows Gregorian
    /// day numbers (9 … 15th); the two should agree. (The app isn't translated, so Arabic
    /// stays left-to-right English.) This asserts the Gregorian reading the strip uses.
    @MainActor
    func testIslamicCalendarRegionTitleMatchesDayStrip() throws {
        let app = launch("America/New_York", id: "edge-ar-\(UUID().uuidString)",
                         extra: ["-AppleLanguages", "(ar)", "-AppleLocale", "ar_SA"])
        sleep(1)
        let title = weekTitle(app)
        let pills = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "Day ")).allElementsBoundByIndex.map { "\($0.identifier)=\($0.label)" }
        print("REVIEW ar title: \(title) pills: \(pills)")
        shot("edge-locale-ar-SA-grid")
        open("Errands", in: app)
        add(["Pay rent"], in: app)
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Task options:")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["DAY"].waitForExistence(timeout: 3))
        app.buttons["Add a date"].tap()
        XCTAssertTrue(app.staticTexts["Until"].waitForExistence(timeout: 3))
        sleep(1)
        let days = app.buttons.allElementsBoundByIndex.map(\.label).filter { $0.contains("Jumada") || $0.contains("November") }.prefix(3)
        print("REVIEW ar calendar day labels: \(Array(days))")
        shot("edge-locale-ar-SA-calendar")
        app.buttons["Cancel"].firstMatch.tap()
        // The Monday the strip shows, by the Gregorian calendar the app keeps weeks in.
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = TimeZone(identifier: "America/New_York")!
        let weekday = gregorian.component(.weekday, from: Date())
        let monday = gregorian.date(byAdding: .day, value: -((weekday + 5) % 7), to: Date())!
        let shown = gregorian.component(.day, from: monday)
        XCTAssertTrue(title.range(of: "\\b\(shown)\\b", options: .regularExpression) != nil,
                      "the title (\(title)) and the day strip (Monday \(shown)) show the same date")
    }

    @MainActor
    func testGermanRegionDatesAndDecimals() throws {
        let app = launch("Europe/Berlin", id: "edge-de-\(UUID().uuidString)",
                         extra: ["-AppleLanguages", "(de)", "-AppleLocale", "de_DE", "-smartAddRules"])
        print("REVIEW de title: \(weekTitle(app))")
        open("Errands", in: app)
        let field = app.addTaskField
        if app.keyboards.count == 0 { field.tap() }
        field.typeText("Zahnarzt 31.12.")
        app.buttons["Smart Add"].tap()
        let setDate = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Set date to")).firstMatch
        print("REVIEW de offered 31.12.: \(setDate.waitForExistence(timeout: 8)) \(setDate.exists ? setDate.label : "")")
        shot("edge-locale-de-smartadd")
        if setDate.exists { setDate.tap(); sleep(2); if app.buttons["Moved OK"].exists { app.buttons["Moved OK"].tap() } }
        print("REVIEW de week now: \(weekTitle(app)) tasks=\(taskTitles(app))")
        shot("edge-locale-de-after")
    }
}

/// Long names beside the day and date marks on the SE (default text size): the mark sits
/// beside the whole name, so the name gets a narrow column. It should keep enough width to
/// read as a sentence (the duplicate mark, under the name, shows how it could look).
final class ReviewEdgeLongNameTests: ReviewEdgeCase {
    @MainActor
    func testLongNameBesideDayOrDateMarkIsNotSqueezed() throws {
        let app = launch("America/New_York", id: "edge-squeeze-\(UUID().uuidString)")
        open("Errands", in: app)
        let dayTask = "Pick up the dry cleaning from the shop across town"
        let dateTask = "Renew the passport at the post office downtown"
        let plain = "Buy a birthday present for grandma and wrap it"
        add([dayTask, dateTask, plain], in: app)
        setOptions(of: dayTask, mode: "Carry Over", day: "Friday", in: app)
        setDate(of: dateTask, mode: "Carry Over", daysAhead: 13, in: app)
        sleep(1)
        shot("edge-squeeze-SE")
        // XCUITest's frame for a name includes its mark, so compare heights (lines): the
        // plain name of about the same length takes 3 lines; beside a mark it shouldn't
        // need more than one more.
        let plainFrame = app.staticTexts[plain].frame
        for name in [dayTask, dateTask] {
            let frame = app.staticTexts[name].frame
            print("REVIEW squeeze \(name): \(frame) value=\(app.staticTexts[name].value ?? "") plain=\(plainFrame)")
            XCTAssertLessThanOrEqual(frame.height, plainFrame.height + 24,
                                     "“\(name)” beside its mark takes at most one line more than a plain name (\(frame.height)pt vs \(plainFrame.height)pt)")
        }
    }
}
