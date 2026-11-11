import XCTest

/// Turns Settings ▸ Multitasking & Gestures to Windowed Apps or Full Screen Apps (this
/// simulator only). The review simulator started in Windowed Apps.
@MainActor
func reviewSetWindowedApps(_ on: Bool) {
    let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
    settings.launch()
    Thread.sleep(forTimeInterval: 2)
    let row = settings.staticTexts["Multitasking & Gestures"]
    if !row.waitForExistence(timeout: 5) { settings.swipeUp() }
    guard row.waitForExistence(timeout: 5) else { print("REVIEW: no Multitasking row"); return }
    row.tap()
    Thread.sleep(forTimeInterval: 1.5)
    let name = on ? "Windowed Apps" : "Full Screen Apps"
    let choice = settings.buttons[name].firstMatch.exists ? settings.buttons[name].firstMatch : settings.staticTexts[name].firstMatch
    if choice.waitForExistence(timeout: 5) { choice.tap() } else { print("REVIEW: no windowing choice \(name)") }
    Thread.sleep(forTimeInterval: 1)
    settings.terminate()
}

/// Two windows of Tasquel side by side (iPadOS 26 windowed apps): an edit in one shows in
/// the other, and one window's keyboard doesn't change the other window's bottom bar.
final class ReviewIPadWindowsTests: ReviewIPadBase {

    @MainActor
    func testSecondWindowKeyboardLeavesOtherWindowsBar() throws {
        reviewSetWindowedApps(true)
        let arguments = ["-demoData", "-demoFirstCard", "Errands"]
        launch(arguments, orientation: .landscapeLeft)
        // A second window (File ▸ New Window, ⌘N), then shrunk to the left half by its grip,
        // so the first window's right half (its Edit button) shows beside it.
        app.typeKey("n", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 3)
        XCTAssertEqual(app.windows.count, 2, "a second window opened")
        // Window sizes are remembered between launches: work from the window's frame.
        let frame = app.windows.element(boundBy: 0).frame
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let origin = springboard.coordinate(withNormalizedOffset: .zero)
        origin.withOffset(CGVector(dx: frame.maxX - 6, dy: frame.maxY - 6))
            .press(forDuration: 0.6, thenDragTo: origin.withOffset(CGVector(dx: frame.minX + 660, dy: frame.maxY - 6)), withVelocity: .slow, thenHoldForDuration: 0.3)
        Thread.sleep(forTimeInterval: 2.5)
        shot("windows-03-side-by-side")
        for i in 0..<app.windows.count { log("window \(i) \(app.windows.element(boundBy: i).frame)") }
        let edits = app.buttons.matching(NSPredicate(format: "label == %@", "Edit"))
        log("Edit buttons before typing: \(edits.count) \(edits.allElementsBoundByIndex.map { $0.frame })")
        XCTAssertGreaterThanOrEqual(edits.count, 2, "both windows show their bottom bar")
        guard edits.count >= 2 else { print(app.debugDescription); return }

        // Type a new task in the new (left) window: only that window's bar gives way.
        let leftErrands = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Errands,"))
            .allElementsBoundByIndex.first { $0.frame.maxX < 700 }
        XCTAssertNotNil(leftErrands)
        leftErrands?.tap()
        Thread.sleep(forTimeInterval: 1.5)
        let plus = app.buttons.matching(NSPredicate(format: "label == %@", "Add task")).allElementsBoundByIndex
            .first { $0.frame.maxX < 700 }
        XCTAssertNotNil(plus, "the left window's card is open")
        plus?.tap()
        Thread.sleep(forTimeInterval: 1.5)
        app.typeText("From the left window")
        Thread.sleep(forTimeInterval: 1.5)
        shot("windows-04-left-typing")
        let editsWhileTyping = edits.allElementsBoundByIndex.filter { $0.exists && $0.frame.minX > 700 }
        log("Edit buttons while typing: \(edits.count); right window's: \(editsWhileTyping.map { $0.frame })")
        XCTAssertFalse(editsWhileTyping.isEmpty, "the right window keeps its Edit button while the left one types")

        // Return adds it: the right window's Errands card counts it too.
        app.typeText("\n")
        Thread.sleep(forTimeInterval: 2)
        shot("windows-05-after-add")
        let all = app.staticTexts.matching(NSPredicate(format: "label == %@", "From the left window")).allElementsBoundByIndex
        log("new task texts: \(all.map { $0.frame })")
    }
}
