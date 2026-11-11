import XCTest

/// Resized windows (iPadOS 26 windowed apps): a narrow (compact width) window and a wide,
/// short one. The window is resized by dragging its bottom-right grip.
final class ReviewIPadWindowSizeTests: ReviewIPadBase {

    /// Drags the window's bottom-right corner so the window is `width` × `height` points.
    @MainActor
    func resizeWindow(width: CGFloat, height: CGFloat) {
        let frame = windowFrame
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let origin = springboard.coordinate(withNormalizedOffset: .zero)
        let grip = origin.withOffset(CGVector(dx: frame.maxX - 6, dy: frame.maxY - 6))
        let target = origin.withOffset(CGVector(dx: frame.minX + width - 6, dy: frame.minY + height - 6))
        grip.press(forDuration: 0.6, thenDragTo: target, withVelocity: .slow, thenHoldForDuration: 0.3)
        Thread.sleep(forTimeInterval: 2)
        log("resized window from \(frame) to \(windowFrame)")
    }

    /// A narrow window: closed cards in 2 columns, nothing past the window's edges.
    @MainActor
    func testNarrowWindowLayout() throws {
        reviewSetWindowedApps(true)
        launch(["-demoData", "-demoFirstCard", "Errands"], orientation: .landscapeLeft)
        resizeWindow(width: 480, height: 900)
        shot("narrow-01-closed")
        let window = windowFrame
        XCTAssertLessThan(window.width, 700, "the window got narrow")
        let work = card("Work"), fitness = card("Fitness")
        XCTAssertTrue(work.waitForExistence(timeout: 3))
        log("narrow Work \(work.frame) Fitness \(fitness.frame)")
        XCTAssertTrue(contains(window, work.frame), "cards inside the window")
        openCard("Errands")
        shot("narrow-02-errands-open")
        for label in ["Settings", "Edit"] {
            let b = app.buttons[label].firstMatch
            XCTAssertTrue(b.exists && contains(window, b.frame), "\(label) inside the window: \(b.frame)")
        }
    }

    /// A narrow window with the keyboard up (typing a new task): the new task's options open
    /// wholly on screen, as they do in a full-size window.
    @MainActor
    func testNarrowWindowNewTaskOptionsWithKeyboard() throws {
        reviewSetWindowedApps(true)
        launch(["-demoData", "-demoFirstCard", "Errands"], orientation: .landscapeLeft)
        resizeWindow(width: 480, height: 1000)
        openCard("Errands")
        let field = app.addTaskField
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText("Buy stamps")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "New task options")).firstMatch.tap()
        let add = app.buttons["Add Task"]
        XCTAssertTrue(add.waitForExistence(timeout: 4), "the picker opens")
        Thread.sleep(forTimeInterval: 1)
        shot("narrow-03-new-options-keyboard")
        let screen = XCUIApplication(bundleIdentifier: "com.apple.springboard").windows.firstMatch.frame
        let kb = app.keyboards.firstMatch
        log("narrow options: Add Task \(add.frame) Checkbox \(app.buttons["Checkbox"].firstMatch.frame) keyboard \(kb.exists ? kb.frame : .zero) window \(windowFrame) screen \(screen)")
        for label in ["Checkbox", "Goal", "List", "Carry Over", "Repeating", "One-Time", "Add Task"] {
            let b = app.buttons[label].firstMatch
            XCTAssertTrue(b.exists && b.isHittable, "\(label) can be tapped: \(b.frame)")
            if kb.exists { XCTAssertLessThanOrEqual(b.frame.maxY, kb.frame.minY + 1, "\(label) not under the keyboard") }
        }
    }

    /// A narrow window: a list row's options with its Add Item keyboard up.
    @MainActor
    func testNarrowWindowListOptionsWithKeyboard() throws {
        reviewSetWindowedApps(true)
        launch(["-demoData", "-demoFirstCard", "Errands"], orientation: .landscapeLeft)
        resizeWindow(width: 480, height: 1000)
        openCard("Errands")
        let addItem = app.buttons["Add item to Groceries"].firstMatch
        XCTAssertTrue(addItem.waitForExistence(timeout: 3))
        addItem.tap()
        Thread.sleep(forTimeInterval: 1)
        let itemField = renameField("Add item")
        XCTAssertTrue(itemField.waitForExistence(timeout: 3))
        itemField.typeText("Bread")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        app.buttons["Task options: List, Repeating"].tap()
        let oneTime = app.buttons["One-Time"].firstMatch
        XCTAssertTrue(oneTime.waitForExistence(timeout: 4), "the picker opens")
        Thread.sleep(forTimeInterval: 1)
        shot("narrow-04-list-options-keyboard")
        let kb = app.keyboards.firstMatch
        log("narrow list options: keyboard up \(kb.exists) \(kb.exists ? kb.frame : .zero) Checkbox \(app.buttons["Checkbox"].firstMatch.frame) One-Time \(oneTime.frame)")
        for label in ["Checkbox", "Goal", "List", "Carry Over", "Repeating", "One-Time"] {
            let b = app.buttons[label].firstMatch
            XCTAssertTrue(b.exists && b.isHittable, "\(label) can be tapped: \(b.frame)")
            if kb.exists { XCTAssertLessThanOrEqual(b.frame.maxY, kb.frame.minY + 1, "\(label) not under the keyboard") }
        }
    }

    /// A wide, short window: closed cards in 4 columns, an open card's rename field wraps.
    @MainActor
    func testWideShortWindowLayout() throws {
        reviewSetWindowedApps(true)
        launch(["-demoData", "-demoFirstCard", "Errands"], orientation: .landscapeLeft)
        resizeWindow(width: 1300, height: 560)
        shot("wide-01-closed")
        openCard("Errands")
        shot("wide-02-open")
        XCTAssertTrue(app.buttons["Settings"].exists && contains(windowFrame, app.buttons["Settings"].frame))
    }
}
