import XCTest

/// Keyboards in sheets, especially in a sheet over a sheet (Choose Emoji… in Add Category or
/// Saved Categories, Settings ▸ New Saved Category). Such a keyboard lifts the main screen's
/// safe area; the main screen used to chase that with its bottom bar and hang, and both
/// sheets closed. Each test also checks the bottom bar is back in place afterwards.
final class EmojiPickerUITests: XCTestCase {
    @MainActor
    func testChooseEmojiWhileCreatingCategory() throws {
        let app = launch()
        app.buttons["Edit"].tap()
        let addCard = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Add Category")).firstMatch
        XCTAssertTrue(addCard.waitForExistence(timeout: 3))
        addCard.tap()
        app.buttons["Create New Category"].tap()
        let name = app.textFields["Category name"]
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        name.typeText("Garden")  // the name field has the keyboard, as when recording

        chooseEmoji("🌱", in: app)

        XCTAssertTrue(app.navigationBars["Add Category"].exists, "Add Category stays open")
        XCTAssertTrue(app.buttons["Icon: 🌱"].waitForExistence(timeout: 3), "the emoji is the new icon")
        name.tap()
        name.typeText("\n")  // Return adds it
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Garden,")).firstMatch
            .waitForExistence(timeout: 3), "the category is added")
    }

    @MainActor
    func testChooseEmojiForSavedCategory() throws {
        let app = launch()
        app.buttons["Settings"].tap()
        app.buttons["Saved Categories"].tap()
        let icon = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Icon:")).firstMatch
        XCTAssertTrue(icon.waitForExistence(timeout: 3))
        icon.tap()
        app.buttons["Choose Emoji…"].tap()
        let picker = app.navigationBars["Emoji Icon"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        app.textFields["Emoji"].typeText("🛒")
        XCTAssertTrue(picker.waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Icon: 🛒"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.navigationBars["Saved Categories"].exists, "Settings stays open")
    }

    /// A card's rename mode: Choose Emoji… opens straight from the main screen.
    @MainActor
    func testChooseEmojiWhileRenamingCard() throws {
        let app = launch()
        let barFrame = app.buttons["Settings"].frame
        let errands = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Errands,")).firstMatch
        XCTAssertTrue(errands.waitForExistence(timeout: 5))
        errands.tap()
        XCTAssertTrue(app.addTaskRow.waitForExistence(timeout: 3), "the card is open")
        let editCard = app.buttons["Edit Errands"]
        XCTAssertTrue(editCard.waitForExistence(timeout: 3))
        sleep(1)  // the edit button fades in as the card opens
        editCard.tap()
        let name = app.textFields["Category name"]
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        name.tap()  // the card's name field has the keyboard

        chooseEmoji("🧺", in: app)

        XCTAssertTrue(app.buttons["Icon: 🧺"].waitForExistence(timeout: 3), "the card's icon is the emoji")
        app.buttons["Done editing Errands"].tap()
        dismissKeyboardIfUp(app)
        assertBottomBar(in: app, at: barFrame)
    }

    /// Renaming a card, then choosing an emoji for it straight away: the new name is kept
    /// and the picker stays open (the rename used to rebuild the card and close it).
    @MainActor
    func testRenameCardThenChooseEmoji() throws {
        let app = launch()
        let errands = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Errands,")).firstMatch
        XCTAssertTrue(errands.waitForExistence(timeout: 5))
        errands.tap()
        XCTAssertTrue(app.addTaskRow.waitForExistence(timeout: 3), "the card is open")
        let editCard = app.buttons["Edit Errands"]
        XCTAssertTrue(editCard.waitForExistence(timeout: 3))
        sleep(1)  // the edit button fades in as the card opens
        editCard.tap()
        let name = app.textFields["Category name"]
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        name.tap()
        name.typeText("2")  // "Errands2", not yet committed

        chooseEmoji("🧺", in: app)

        XCTAssertTrue(app.buttons["Icon: 🧺"].waitForExistence(timeout: 3), "the card's icon is the emoji")
        XCTAssertTrue(app.buttons["Done editing Errands2"].exists, "the new name is kept")
    }

    /// Settings ▸ Saved Categories ▸ New Saved Category: a sheet over Settings that opens
    /// with the keyboard, and its own Choose Emoji… (a third sheet).
    @MainActor
    func testNewSavedCategoryWithEmoji() throws {
        let app = launch()
        let barFrame = app.buttons["Settings"].frame
        app.buttons["Settings"].tap()
        app.buttons["Saved Categories"].tap()
        app.buttons["New Saved Category"].tap()
        // The rows behind have name fields too: the editor's is the one with the keyboard.
        let name = app.textFields.matching(NSPredicate(format: "hasKeyboardFocus == true")).firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: 3), "the editor opens with its keyboard")
        sleep(1)
        XCTAssertTrue(name.exists, "the editor keeps its keyboard")
        name.typeText("Garden")

        chooseEmoji("🌻", in: app, icon: "Icon: Folder")

        app.buttons["Save"].tap()
        XCTAssertTrue(app.textFields.matching(NSPredicate(format: "value == %@", "Garden")).firstMatch
            .waitForExistence(timeout: 3), "the new saved category is listed")
        app.navigationBars.buttons.element(boundBy: 0).tap()  // back to Settings
        app.buttons["Done"].firstMatch.tap()
        assertBottomBar(in: app, at: barFrame)
    }

    /// Add Category ▸ Edit Saved Categories: a saved category's icon menu in place.
    @MainActor
    func testChooseEmojiInEditSavedCategories() throws {
        let app = launch()
        let barFrame = app.buttons["Settings"].frame
        app.buttons["Edit"].tap()
        let addCard = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Add Category")).firstMatch
        XCTAssertTrue(addCard.waitForExistence(timeout: 3))
        addCard.tap()
        let edit = app.buttons["Edit Saved Categories"]
        for _ in 0..<3 where !edit.isHittable { app.collectionViews.firstMatch.swipeUp(velocity: .slow) }
        edit.tap()

        chooseEmoji("🎯", in: app)

        XCTAssertTrue(app.navigationBars["Add Category"].exists, "Add Category stays open")
        app.buttons["Done"].firstMatch.tap()
        app.buttons["Done Editing"].tap()
        assertBottomBar(in: app, at: barFrame)
    }

    /// Typing in Settings (the Feature Ideas comment) and closing it with the keyboard up.
    @MainActor
    func testTypingInSettingsLeavesBottomBarInPlace() throws {
        let app = launch()
        let barFrame = app.buttons["Settings"].frame
        app.buttons["Settings"].tap()
        let comment = app.textFields["Anything else? (optional)"]
        for _ in 0..<6 where !comment.exists || !comment.isHittable { app.collectionViews.firstMatch.swipeUp(velocity: .slow) }
        comment.tap()
        comment.typeText("Widgets please")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 2))
        app.buttons["Done"].firstMatch.tap()
        assertBottomBar(in: app, at: barFrame)
    }

    /// Saving a new category doesn't flash "already exists" while the sheet closes (the
    /// name it just saved counted as taken).
    @MainActor
    func testCreatingCategoryDoesNotFlashNameTaken() throws {
        let app = launch()
        app.buttons["Edit"].tap()
        let addCard = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Add Category")).firstMatch
        XCTAssertTrue(addCard.waitForExistence(timeout: 3))
        addCard.tap()
        app.buttons["Create New Category"].tap()
        let name = app.textFields["Category name"]
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        name.typeText("Garden\n")  // Return adds it
        let taken = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "already")).firstMatch
        var sawTaken = false
        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline, !sawTaken {
            sawTaken = taken.exists
        }
        XCTAssertFalse(sawTaken, "no name-taken warning while the sheet closes")
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open Garden,")).firstMatch
            .waitForExistence(timeout: 3))
    }

    // MARK: Helpers

    /// The bottom bar is showing, where it was at launch.
    @MainActor
    private func assertBottomBar(in app: XCUIApplication, at frame: CGRect, file: StaticString = #filePath, line: UInt = #line) {
        let settings = app.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 3), "the bottom bar is back", file: file, line: line)
        sleep(1)
        XCTAssertEqual(settings.frame, frame, "the bottom bar is where it was", file: file, line: line)
        XCTAssertTrue(app.buttons["Edit"].isHittable || app.buttons["Done Editing"].isHittable, file: file, line: line)
    }

    /// Closes the keyboard with the bottom bar's Done button, if it's still up (it may be
    /// closing by itself as the card stops editing).
    @MainActor
    private func dismissKeyboardIfUp(_ app: XCUIApplication) {
        sleep(1)
        guard app.keyboards.firstMatch.exists else { return }
        let done = app.buttons["Done"].firstMatch
        if done.waitForExistence(timeout: 1), done.isHittable { done.tap() }
    }

    @MainActor
    private func launch() -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-isolatedData"]
        app.launch()
        if app.staticTexts["Welcome to Tasquel"].waitForExistence(timeout: 3) { app.buttons["Skip"].tap() }
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 5))
        return app
    }

    /// Opens the icon menu, chooses Choose Emoji…, and types `emoji` into the picker.
    @MainActor
    private func chooseEmoji(_ emoji: String, in app: XCUIApplication, icon: String? = nil) {
        let menu = icon.map { app.buttons[$0] }
            ?? app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Icon:")).firstMatch
        XCTAssertTrue(menu.waitForExistence(timeout: 3))
        menu.tap()
        let choose = app.buttons["Choose Emoji…"]
        XCTAssertTrue(choose.waitForExistence(timeout: 3))
        choose.tap()
        let picker = app.navigationBars["Emoji Icon"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5), "the emoji picker opens")
        sleep(1)
        XCTAssertTrue(picker.exists, "the emoji picker stays open")
        app.textFields["Emoji"].typeText(emoji)
        XCTAssertTrue(picker.waitForNonExistence(timeout: 3), "picking an emoji closes the picker")
    }
}
