import XCTest

/// Sheet sizes on iPad: the emoji picker (sized for a phone's 200pt detent) and the others.
final class ReviewIPadSheetsTests: ReviewIPadBase {

    /// Choose Emoji… from a card's edit mode on iPad: the picker should be a small sheet or
    /// popover, not a big form sheet holding one 72pt field.
    @MainActor
    func testEmojiPickerSheetSizeOnIPad() throws {
        launch(["-demoData", "-demoFirstCard", "Errands"], orientation: .landscapeLeft)
        openCard("Errands")
        sleep(1)
        app.buttons["Edit Errands"].tap()
        let name = app.textFields["Category name"]
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        let menu = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Icon:")).firstMatch
        XCTAssertTrue(menu.waitForExistence(timeout: 3))
        menu.tap()
        app.buttons["Choose Emoji…"].tap()
        let picker = app.navigationBars["Emoji Icon"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        sleep(1)
        shot("emoji-sheet-landscape")
        let hint = app.staticTexts["Pick an emoji from the keyboard."]
        log("emoji nav \(picker.frame) hint \(hint.frame) window \(windowFrame) keyboard \(app.keyboards.firstMatch.frame)")
        XCUIDevice.shared.orientation = .portrait
        sleep(1)
        shot("emoji-sheet-portrait")
        log("emoji portrait nav \(picker.frame) window \(windowFrame) keyboard \(app.keyboards.firstMatch.frame)")
        XCTAssertTrue(picker.exists, "the picker survives rotation")
    }
}
