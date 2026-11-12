import XCTest

extension XCUIApplication {
    /// The Add task field. In a card it waits behind a + until that's tapped, so asking for
    /// it opens it (and it takes the keyboard).
    var addTaskField: XCUIElement { openAddTaskField() }

    @discardableResult
    func openAddTaskField(timeout: TimeInterval = 3) -> XCUIElement {
        let field = textFields["Add task"]
        if field.exists { return field }
        let plus = buttons["Add task"].firstMatch
        if plus.waitForExistence(timeout: timeout) {
            plus.tap()
            _ = field.waitForExistence(timeout: timeout)
        }
        return field
    }

    /// A row in Settings, scrolled into view first: the list builds only the rows on screen,
    /// and one more Appearance row (Seasonal) put Saved Categories below an iPhone's first screen.
    func settingsButton(_ label: String) -> XCUIElement {
        let button = buttons[label]
        _ = buttons["System"].waitForExistence(timeout: 3)  // Settings is open
        let list = collectionViews.firstMatch.exists ? collectionViews.firstMatch : self
        for _ in 0..<6 where !(button.exists && button.isHittable) {
            list.swipeUp(velocity: .slow)
        }
        return button
    }

    /// Starts a card's own edit mode and waits for its task icons (clock, pin, trash, handle)
    /// to run out to their places: until then they're stacked on the handle and hidden, and
    /// a tap on one misses (an invisible button takes no taps).
    func editCard(_ name: String) {
        buttons["Edit \(name)"].tap()
        Thread.sleep(forTimeInterval: 0.6)
    }

    /// A card's Add task row, open (the field) or not (its +): the card is open and can be
    /// added to.
    var addTaskRow: XCUIElement {
        descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@ OR (elementType == %d AND label == %@)",
                                  "Add task", XCUIElement.ElementType.button.rawValue, "Add task"))
            .firstMatch
    }
}
