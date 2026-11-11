import XCTest

/// Accessibility review (1.0.3): audits, VoiceOver tree, Dynamic Type, folding lists,
/// reorder handle, rename fields, This week only.
final class ReviewAccessUITests: XCTestCase {

    // MARK: - Helpers

    private var shotDir: String { ProcessInfo.processInfo.environment["SHOT_DIR"] ?? NSTemporaryDirectory() }

    @MainActor
    private func shot(_ name: String) {
        Thread.sleep(forTimeInterval: 0.7)
        let data = XCUIScreen.main.screenshot().pngRepresentation
        try? data.write(to: URL(fileURLWithPath: "\(shotDir)/\(name).png"))
    }

    @MainActor
    private func dumpTree(_ app: XCUIApplication, _ name: String) {
        try? app.debugDescription.write(toFile: "\(shotDir)/\(name).txt", atomically: true, encoding: .utf8)
    }

    /// Runs the audit, logging every issue (without failing), and returns them.
    @MainActor
    @discardableResult
    private func audit(_ app: XCUIApplication, _ state: String) -> [String] {
        var issues: [String] = []
        try? app.performAccessibilityAudit(for: .all) { issue in
            let el = issue.element
            let line = "\(state) | \(issue.auditType) | \(issue.compactDescription) | label=\(el?.label ?? "") id=\(el?.identifier ?? "") frame=\(el.map { NSCoder.string(for: $0.frame) } ?? "")"
            print("REVIEW: audit \(line)")
            issues.append(line)
            return true
        }
        print("REVIEW: audit \(state) total=\(issues.count)")
        return issues
    }

    /// The demo week, optionally at a text size, with Errands first.
    @MainActor
    private func launchDemo(size: String? = nil, extra: [String] = []) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        var args = ["-demoData", "-demoFirstCard", "Errands"] + extra
        if let size { args += ["-UIPreferredContentSizeCategoryName", size] }
        app.launchArguments = args
        app.launch()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 8))
        return app
    }

    @MainActor
    private func openCard(_ app: XCUIApplication, _ name: String) {
        let card = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open \(name),")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5), "card \(name)")
        card.tap()
    }

    /// Scrolls the grid (short swipes from the middle) until `element` is hittable.
    @MainActor
    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication, up: Bool = false, tries: Int = 8) {
        var n = 0
        while !(element.exists && element.isHittable) && n < tries {
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: up ? 0.35 : 0.65))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: up ? 0.6 : 0.4))
            start.press(forDuration: 0.05, thenDragTo: end)
            n += 1
        }
    }

    // MARK: - Findings

    /// At the largest text size a folded list's row keeps its name readable: the name, the
    /// "2 of 5" count, the chevron and the type/mode button sit side by side without
    /// overlapping, inside the screen, and the name gets room for more than a letter or two.
    @MainActor
    func testFoldedCountFitsAtLargestTextSize() throws {
        let app = launchDemo(size: "UICTContentSizeCategoryAccessibilityXXXL")
        openCard(app, "Errands")
        let fold = app.buttons["Fold Groceries"]
        XCTAssertTrue(fold.waitForExistence(timeout: 5))
        scrollTo(fold, in: app)
        fold.tap()
        let count = app.staticTexts.matching(NSPredicate(format: "value == %@", "2 of 5 items checked")).firstMatch
        XCTAssertTrue(count.waitForExistence(timeout: 3))
        scrollTo(count, in: app)
        shot("F1-folded-count-axxxxl")
        let title = app.staticTexts["Groceries"].firstMatch
        let options = app.buttons["Task options: List, Repeating"].firstMatch
        let screen = app.windows.firstMatch.frame
        print("REVIEW: F1 title=\(title.frame) count=\(count.frame) fold=\(fold.frame) options=\(options.frame) screen=\(screen)")
        XCTAssertLessThanOrEqual(title.frame.maxX, count.frame.minX + 1, "name and count don't overlap")
        XCTAssertLessThanOrEqual(count.frame.maxX, fold.frame.minX + 1, "count and chevron don't overlap")
        XCTAssertLessThanOrEqual(options.frame.maxX, screen.maxX, "the type/mode button is on screen")
        XCTAssertGreaterThanOrEqual(title.frame.width, 120, "the name has room to wrap at word breaks")
        XCTAssertTrue(fold.isHittable && options.isHittable)
    }

    /// At the largest text size, a card's own edit mode (lists left open) keeps every
    /// task's delete button and the card's Done button on the screen.
    @MainActor
    func testEditModeAtLargestTextSizeKeepsButtonsOnScreen() throws {
        let app = launchDemo(size: "UICTContentSizeCategoryAccessibilityXXXL")
        openCard(app, "Errands")
        let edit = app.buttons["Edit Errands"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        edit.tap()
        let done = app.buttons["Done editing Errands"]
        XCTAssertTrue(done.waitForExistence(timeout: 3))
        shot("F2-edit-unfolded-axxxxl")
        dumpTree(app, "F2-edit-unfolded-axxxxl")
        let screen = app.windows.firstMatch.frame
        print("REVIEW: F2 done=\(done.frame) screen=\(screen)")
        XCTAssertLessThanOrEqual(done.frame.maxX, screen.maxX, "Done editing is on the screen")
        for name in ["Groceries", "Plan Mom's birthday", "Drop off donations", "Pick up dry cleaning"] {
            let del = app.buttons["Delete \(name)"]
            XCTAssertTrue(del.exists)
            print("REVIEW: F2 delete \(name) \(del.frame)")
            XCTAssertLessThanOrEqual(del.frame.maxX, screen.maxX, "Delete \(name) is on the screen")
        }
    }

    /// One item: "0 of 1 item checked", not "items".
    @MainActor
    func testFoldedCountSingularItem() throws {
        let app = launchDemo()
        openCard(app, "Errands")
        let field = app.addTaskField
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.typeText("Hardware")
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "New task options")).firstMatch.tap()
        app.buttons["List"].firstMatch.tap()
        app.buttons["Add Task"].tap()
        let item = app.textFields["Add item"]
        XCTAssertTrue(item.waitForExistence(timeout: 3))
        item.typeText("Screws\n")
        Thread.sleep(forTimeInterval: 0.5)
        app.buttons["Fold Hardware"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "value BEGINSWITH %@", "0 of 1")).firstMatch
            .waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "value == %@", "0 of 1 item checked")).firstMatch.exists,
                      "found: \(app.staticTexts.matching(NSPredicate(format: "value BEGINSWITH %@", "0 of 1")).firstMatch.label)")
    }

    // MARK: - Checked and fine (re-runnable)

    /// Folded: the items and Add Item are gone from the accessibility tree, the count reads
    /// "2 of 5 items checked", and the chevron says what it does with the list's name as value.
    @MainActor
    func testFoldedListHidesItemsFromVoiceOver() throws {
        let app = launchDemo()
        openCard(app, "Errands")
        let fold = app.buttons["Fold Groceries"]
        XCTAssertTrue(fold.waitForExistence(timeout: 3))
        XCTAssertEqual(fold.label, "Collapse list")
        XCTAssertEqual(fold.value as? String, "Groceries")
        XCTAssertTrue(app.staticTexts["Eggs"].exists)
        fold.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "value == %@", "2 of 5 items checked")).firstMatch.waitForExistence(timeout: 2))
        XCTAssertEqual(fold.label, "Expand list")
        XCTAssertEqual(fold.value as? String, "Groceries")
        for item in ["Eggs", "Spinach", "Coffee beans", "Oat milk", "Lemons"] {
            XCTAssertFalse(app.staticTexts[item].exists, "\(item) is folded away")
        }
        XCTAssertFalse(app.buttons["Add item to Groceries"].exists, "Add Item is folded away")
        XCTAssertFalse(app.textFields["Add item"].exists)
        XCTAssertTrue(fold.isHittable)
        XCTAssertGreaterThanOrEqual(fold.frame.width, 40)
        XCTAssertGreaterThanOrEqual(fold.frame.height, 40)
    }

    /// In a card's edit mode the reorder handle isn't announced (VoiceOver gets Move Up /
    /// Move Down on the checkbox), the chevron stays, and the This week only switch is a
    /// labeled, reachable switch.
    @MainActor
    func testEditModeHandleHiddenAndSwitchLabeled() throws {
        let app = launchDemo()
        openCard(app, "Errands")
        app.buttons["Edit Errands"].tap()
        XCTAssertTrue(app.buttons["Done editing Errands"].waitForExistence(timeout: 3))
        let handles = app.descendants(matching: .any).matching(NSPredicate(
            format: "label CONTAINS[c] %@ OR label CONTAINS[c] %@ OR identifier CONTAINS[c] %@",
            "line.3", "reorder", "line.3"))
        XCTAssertEqual(handles.count, 0, "the handle is hidden from VoiceOver")
        XCTAssertTrue(app.buttons["Fold Groceries"].exists, "the chevron stays in edit mode")
        XCTAssertTrue(app.buttons["Delete Groceries"].exists)
        XCTAssertTrue(app.buttons["Complete Groceries"].exists)
        let toggle = app.switches["This week only"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 3))
        scrollTo(toggle, in: app)
        XCTAssertTrue(toggle.isHittable)
        XCTAssertEqual(toggle.value as? String, "0")
    }

    /// A rename field by its identifier, whether it shows up as a text field or a text view.
    @MainActor
    private func field(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier == %@ AND (elementType == %d OR elementType == %d)", id,
            XCUIElement.ElementType.textField.rawValue, XCUIElement.ElementType.textView.rawValue)).firstMatch
    }

    /// The wrapping rename fields are text views with a name: "Task name", "Item", "Sub-task".
    @MainActor
    func testRenameFieldsAreLabeled() throws {
        let app = launchDemo()
        openCard(app, "Errands")
        // Let the card finish opening: a tap aimed at the name mid-spring landed on Eggs.
        XCTAssertTrue(app.buttons["Edit Errands"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1.5)
        app.staticTexts["Groceries"].firstMatch.tap()
        let taskName = field(app, "Task name")
        XCTAssertTrue(taskName.waitForExistence(timeout: 3))
        XCTAssertEqual(taskName.label, "Task name")
        XCTAssertEqual(taskName.value as? String, "Groceries")
        app.buttons["Done"].firstMatch.tap()  // keyboard Done
        XCTAssertTrue(taskName.waitForNonExistence(timeout: 3))

        app.staticTexts["Coffee beans"].firstMatch.tap()
        let item = field(app, "Item")
        XCTAssertTrue(item.waitForExistence(timeout: 3))
        XCTAssertEqual(item.label, "Item")
        app.buttons["Done"].firstMatch.tap()
        XCTAssertTrue(item.waitForNonExistence(timeout: 3))

        let sub = app.staticTexts["Book dinner"].firstMatch
        scrollTo(sub, in: app)
        sub.tap()
        let subField = field(app, "Sub-task")
        XCTAssertTrue(subField.waitForExistence(timeout: 3))
        XCTAssertEqual(subField.label, "Sub-task")
    }

    // MARK: - Exploration

    @MainActor
    func testExploreDefaultSize() throws {
        let app = launchDemo()
        shot("A01-grid-default")
        dumpTree(app, "A01-grid-default")
        audit(app, "grid-default")

        openCard(app, "Errands")
        shot("A02-errands-open")
        dumpTree(app, "A02-errands-open")
        audit(app, "errands-open")

        let fold = app.buttons["Fold Groceries"]
        XCTAssertTrue(fold.waitForExistence(timeout: 3))
        print("REVIEW: fold label=\(fold.label) value=\(String(describing: fold.value)) frame=\(fold.frame)")
        fold.tap()
        shot("A03-groceries-folded")
        dumpTree(app, "A03-groceries-folded")
        audit(app, "groceries-folded")

        app.buttons["Edit Errands"].tap()
        shot("A04-errands-edit")
        dumpTree(app, "A04-errands-edit")
        audit(app, "errands-edit")
        app.buttons["Done editing Errands"].tap()

        // Rename field
        app.staticTexts["Groceries"].firstMatch.tap()
        Thread.sleep(forTimeInterval: 0.6)
        shot("A05-rename-task")
        dumpTree(app, "A05-rename-task")
        audit(app, "rename-task")
    }

    @MainActor
    func testExploreAXXXXL() throws {
        let app = launchDemo(size: "UICTContentSizeCategoryAccessibilityXXXL")
        shot("B01-grid-axxxxl")
        dumpTree(app, "B01-grid-axxxxl")
        audit(app, "grid-axxxxl")

        openCard(app, "Errands")
        shot("B02-errands-open-axxxxl")
        dumpTree(app, "B02-errands-open-axxxxl")
        audit(app, "errands-open-axxxxl")

        let fold = app.buttons["Fold Groceries"]
        XCTAssertTrue(fold.waitForExistence(timeout: 3))
        scrollTo(fold, in: app)
        fold.tap()
        shot("B03-groceries-folded-axxxxl")
        dumpTree(app, "B03-groceries-folded-axxxxl")
        audit(app, "groceries-folded-axxxxl")

        let edit = app.buttons["Edit Errands"]
        scrollTo(edit, in: app, up: true)
        edit.tap()
        shot("B04-errands-edit-axxxxl")
        dumpTree(app, "B04-errands-edit-axxxxl")
        audit(app, "errands-edit-axxxxl")
        let toggle = app.switches["This week only"]
        scrollTo(toggle, in: app)
        shot("B05-errands-edit-toggle-axxxxl")
        audit(app, "errands-edit-toggle-axxxxl")
    }

    @MainActor
    func testExploreXXXL() throws {
        let app = launchDemo(size: "UICTContentSizeCategoryXXXL")
        shot("C01-grid-xxxl")
        audit(app, "grid-xxxl")
        openCard(app, "Errands")
        shot("C02-errands-open-xxxl")
        dumpTree(app, "C02-errands-open-xxxl")
        audit(app, "errands-open-xxxl")
        let fold = app.buttons["Fold Groceries"]
        XCTAssertTrue(fold.waitForExistence(timeout: 3))
        fold.tap()
        shot("C03-groceries-folded-xxxl")
        audit(app, "groceries-folded-xxxl")
        app.buttons["Edit Errands"].tap()
        shot("C04-errands-edit-xxxl")
        audit(app, "errands-edit-xxxl")
    }
}

// MARK: - System accessibility settings (Settings app)

final class ReviewAccessSettingsUITests: XCTestCase {
    private var shotDir: String { ProcessInfo.processInfo.environment["SHOT_DIR"] ?? NSTemporaryDirectory() }

    @MainActor
    private func shot(_ name: String) {
        Thread.sleep(forTimeInterval: 0.8)
        try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(shotDir)/\(name).png"))
    }

    /// Sets switches in Settings ▸ Accessibility ▸ <page>.
    @MainActor
    private func setSwitches(page: String, _ names: [String], on: Bool) {
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        settings.terminate()
        settings.launch()
        let acc = settings.staticTexts["Accessibility"].firstMatch
        var n = 0
        while !acc.isHittable && n < 6 { settings.swipeUp(); n += 1 }
        acc.tap()
        let pageCell = settings.staticTexts[page].firstMatch
        XCTAssertTrue(pageCell.waitForExistence(timeout: 4), page)
        n = 0
        while !pageCell.isHittable && n < 6 { settings.swipeUp(); n += 1 }
        pageCell.tap()
        for name in names {
            let sw = settings.switches[name].firstMatch
            XCTAssertTrue(sw.waitForExistence(timeout: 4), name)
            n = 0
            while !sw.isHittable && n < 6 { settings.swipeUp(); n += 1 }
            let isOn = (sw.value as? String) == "1"
            if isOn != on {
                // Tap the switch itself (the right end of the row).
                sw.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
                Thread.sleep(forTimeInterval: 0.5)
            }
            print("REVIEW: settings \(name) -> \(sw.value ?? "?")")
        }
        settings.terminate()
    }

    @MainActor
    private func setAll(_ on: Bool) {
        setSwitches(page: "Display & Text Size",
                    ["Bold Text", "Button Shapes", "Reduce Transparency", "Increase Contrast"], on: on)
        setSwitches(page: "Motion", ["Reduce Motion"], on: on)
    }

    /// With Bold Text, Button Shapes, Reduce Transparency, Increase Contrast and Reduce
    /// Motion on, the week, an open card, a folded list, edit mode and Add task still work
    /// and lay out (screenshots), and the audit is logged.
    @MainActor
    func testAssistiveDisplaySettingsKeepLayout() throws {
        setAll(true)
        addTeardownBlock { @MainActor in self.setAll(false) }

        for appearance in ["light", "dark", "retro"] {
            let app = XCUIApplication()
            app.launchArguments = ["-demoData", "-demoFirstCard", "Errands", "-demoAppearance", appearance]
            app.launch()
            XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 8))
            shot("S-\(appearance)-01-grid")
            app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Errands,")).firstMatch.tap()
            shot("S-\(appearance)-02-open")
            let fold = app.buttons["Fold Groceries"]
            XCTAssertTrue(fold.waitForExistence(timeout: 3))
            fold.tap()
            XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "value == %@", "2 of 5 items checked")).firstMatch.waitForExistence(timeout: 2))
            shot("S-\(appearance)-03-folded")
            app.buttons["Edit Errands"].tap()
            XCTAssertTrue(app.switches["This week only"].waitForExistence(timeout: 3))
            shot("S-\(appearance)-04-edit")
            app.buttons["Done editing Errands"].tap()
            let field = app.addTaskField
            XCTAssertTrue(field.waitForExistence(timeout: 3), "Add task opens with Reduce Motion")
            shot("S-\(appearance)-05-addtask")
            try? app.performAccessibilityAudit(for: .all) { issue in
                print("REVIEW: audit settings-\(appearance) | \(issue.auditType) | \(issue.compactDescription) | label=\(issue.element?.label ?? "")")
                return true
            }
            app.terminate()
        }
    }
}
