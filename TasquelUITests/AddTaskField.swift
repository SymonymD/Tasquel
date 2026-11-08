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

    /// A card's Add task row, open (the field) or not (its +): the card is open and can be
    /// added to.
    var addTaskRow: XCUIElement {
        descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@ OR (elementType == %d AND label == %@)",
                                  "Add task", XCUIElement.ElementType.button.rawValue, "Add task"))
            .firstMatch
    }
}
