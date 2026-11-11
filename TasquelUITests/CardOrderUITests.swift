import XCTest

/// Card order while cards are open. Opening a card that isn't first in its row moves it to
/// the start of the row for as long as it's open; that's only for show, and it mustn't leak
/// into the saved order or hold back sorting.
final class CardOrderUITests: XCTestCase {
    private var app: XCUIApplication!

    @MainActor
    override func setUp() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchArguments = ["-isolatedData"]
        app.launch()
        if app.staticTexts["Welcome to Tasquel"].waitForExistence(timeout: 3) { app.buttons["Skip"].tap() }
        XCTAssertTrue(card("Work").waitForExistence(timeout: 5))
    }

    /// Leaving Edit reopens a card where it was open: Work (right column) opens at the
    /// start of its row, and is there again after Edit.
    @MainActor
    func testLeavingEditReopensCardInPlace() throws {
        card("Work").tap()
        let close = app.buttons["Close Work"]
        XCTAssertTrue(close.waitForExistence(timeout: 3))
        sleep(1)
        let top = close.frame.minY
        app.buttons["Edit"].tap()
        sleep(1)
        app.buttons["Done Editing"].tap()
        XCTAssertTrue(close.waitForExistence(timeout: 3))
        sleep(1)
        XCTAssertEqual(close.frame.minY, top, accuracy: 2, "Work reopens where it was")
    }

    /// Dragging a closed card while Work is open saves only that move: Work goes back
    /// beside Errands when it's closed.
    @MainActor
    func testDraggingWhileACardIsOpenKeepsTheOthersOrder() throws {
        card("Work").tap()
        XCTAssertTrue(app.buttons["Close Work"].waitForExistence(timeout: 3))
        sleep(1)
        card("Appointments").press(forDuration: 1.0, thenDragTo: card("Study"))
        sleep(1)
        app.buttons["Close Work"].tap()
        sleep(1)
        let errands = card("Errands").frame, work = card("Work").frame
        XCTAssertEqual(work.minY, errands.minY, accuracy: 2, "Work is back in Errands' row")
        XCTAssertGreaterThan(work.minX, errands.minX, "to the right of Errands, as before")
        XCTAssertLessThan(card("Appointments").frame.minY + 1, card("Study").frame.maxY, "Appointments moved before Study")
    }

    /// Choosing a sort with a card open applies it when Settings closes, with the open card
    /// still open.
    @MainActor
    func testSortChangeAppliesWhileACardIsOpen() throws {
        // Appointments edited last.
        card("Appointments").tap()
        let field = app.addTaskField
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText("Dentist\n")
        app.buttons["Done"].firstMatch.tap()
        app.buttons["Close Appointments"].tap()
        card("Work").tap()
        XCTAssertTrue(app.buttons["Close Work"].waitForExistence(timeout: 3))

        app.buttons["Settings"].tap()
        let sort = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Sort Cards")).firstMatch
        for _ in 0..<4 where !sort.isHittable { app.collectionViews.firstMatch.swipeUp(velocity: .slow) }
        sort.tap()
        app.buttons["Recently Edited First"].tap()
        app.buttons["Done"].firstMatch.tap()
        sleep(2)

        XCTAssertTrue(app.buttons["Close Work"].exists, "Work stays open")
        let appointments = card("Appointments").frame
        for other in ["Errands", "Fitness", "Study"] {
            let frame = card(other).frame
            XCTAssertTrue(appointments.minY < frame.minY - 1 || (abs(appointments.minY - frame.minY) < 2 && appointments.minX < frame.minX),
                          "Appointments, edited last, comes before \(other)")
        }
    }

    /// Pinned in Edit, Study and Appointments go to the start of the grid; a third card
    /// can't be pinned. A task pinned in its card's edit mode goes to the top of the card.
    @MainActor
    func testPinningCardsAndTasks() throws {
        app.buttons["Edit"].tap()
        let pinStudy = app.buttons["Pin Study"]
        XCTAssertTrue(pinStudy.waitForExistence(timeout: 3))
        pinStudy.tap()
        app.buttons["Pin Appointments"].tap()
        sleep(1)
        XCTAssertEqual(app.buttons["Pin Study"].label, "Unpin Study")
        XCTAssertFalse(app.buttons["Pin Work"].isEnabled, "two cards is the most")
        app.buttons["Done Editing"].tap()
        sleep(1)

        let study = card("Study").frame, appointments = card("Appointments").frame
        for other in ["Errands", "Work", "Fitness"] {
            XCTAssertLessThan(study.minY, card(other).frame.minY - 1, "Study comes before \(other)")
            XCTAssertLessThan(appointments.minY, card(other).frame.minY - 1, "so does Appointments")
        }
        XCTAssertLessThan(study.minX, appointments.minX, "in the order they were in")
        XCTAssertTrue(card("Study").label.contains("pinned"))

        card("Errands").tap()
        let field = app.addTaskField
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText("Dry cleaning\n")
        field.typeText("Donations\n")
        field.typeText("Groceries\n")
        app.buttons["Done"].firstMatch.tap()
        app.buttons["Edit Errands"].tap()
        let pinGroceries = app.buttons["Pin Groceries"]
        XCTAssertTrue(pinGroceries.waitForExistence(timeout: 3))
        pinGroceries.tap()
        app.buttons["Done editing Errands"].tap()
        sleep(1)
        XCTAssertLessThan(app.staticTexts["Groceries"].frame.minY, app.staticTexts["Dry cleaning"].frame.minY,
                          "the pinned task is at the top of the card")
    }

    private func card(_ name: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open \(name),")).firstMatch
    }
}
