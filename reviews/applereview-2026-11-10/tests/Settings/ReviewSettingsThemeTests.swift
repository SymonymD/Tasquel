import XCTest

/// Every theme, switched from Settings while a card is open: the folded list's chevron and
/// count, the wrapping rename field, the reorder handle and the lifted task.
final class ReviewSettingsThemeTests: ReviewSettingsBase {

    @MainActor func testThemeLight() { themeTour("Light") }
    @MainActor func testThemeDark() { themeTour("Dark") }
    @MainActor func testThemeSystemLight() { themeTour("System") }
    @MainActor func testThemeRetroGreen() { themeTour("Retro", color: "Green") }
    @MainActor func testThemeRetroAmber() { themeTour("Retro", color: "Amber", quick: true) }
    @MainActor func testThemeRetroBlue() { themeTour("Retro", color: "Blue", quick: true) }
    @MainActor func testThemeRetroWhite() { themeTour("Retro", color: "White", quick: true) }
    @MainActor func testThemeRetroRed() { themeTour("Retro", color: "Red", quick: true) }
    @MainActor func testThemeRetroPurple() { themeTour("Retro", color: "Purple", quick: true) }

    /// Opens Errands, folds Groceries, then switches theme from Settings with the card open.
    @MainActor
    private func themeTour(_ mode: String, color: String? = nil, quick: Bool = false) {
        let tag = (mode + (color ?? "")).lowercased()
        launchDemo(["-demoAppearance", (mode == "Light" || mode == "System") ? "dark" : "light"])
        openCard("Errands")
        let fold = app.buttons["Fold Groceries"]
        XCTAssertTrue(fold.waitForExistence(timeout: 3), "the list has a chevron")
        fold.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "value == %@", "2 of 5 items checked")).firstMatch.waitForExistence(timeout: 2), "folded count")

        chooseTheme(mode, color: color, shotName: "theme-\(tag)-settings")
        if color != nil { dismissIconAlert(timeout: 2) }

        // The open card took the theme, and the fold and its count are still there.
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "value == %@", "2 of 5 items checked")).firstMatch.waitForExistence(timeout: 2), "still folded after the theme change")
        XCTAssertEqual(app.buttons["Fold Groceries"].label, "Expand list")
        XCTAssertFalse(app.staticTexts["Coffee beans"].exists, "items still hidden")
        shot("theme-\(tag)-folded")
        auditContrast("\(tag) main")

        // Wrapping rename field.
        let title = app.staticTexts["Plan Mom's birthday"]
        XCTAssertTrue(title.waitForExistence(timeout: 2))
        title.tap()
        let field = app.textFields["Task name"]
        XCTAssertTrue(field.waitForExistence(timeout: 3), "rename field")
        let oneLine = field.frame.height
        field.typeText(" with cake, balloons, a dinner booking and invitations")
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertGreaterThan(field.frame.height, oneLine * 1.5, "the rename field wraps")
        shot("theme-\(tag)-rename")
        app.buttons["Done"].firstMatch.tap()  // the keyboard's Done saves it
        XCTAssertTrue(app.staticTexts["Plan Mom's birthday with cake, balloons, a dinner booking and invitations"]
            .waitForExistence(timeout: 3), "renamed")

        if quick { return }

        // The card's edit mode: handles, the This week only switch, the fold chevron.
        app.buttons["Edit Errands"].tap()
        XCTAssertTrue(app.buttons["Delete Groceries"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Fold Groceries"].exists, "the chevron stays in edit mode")
        shot("theme-\(tag)-edit")
        auditContrast("\(tag) edit")

        // Lift Drop off donations and move it up past the folded Groceries (a tall goal row: its
        // middle, not the handle, has to pass Groceries' middle, so the handle goes well above).
        let groceries = app.buttons["Delete Groceries"]
        handle(of: "Drop off donations").press(forDuration: 0.2,
            thenDragTo: groceries.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).withOffset(CGVector(dx: -120, dy: -60)),
            withVelocity: .slow, thenHoldForDuration: 1.0)
        let moved = NSPredicate { [app] _, _ in
            app!.buttons["Delete Drop off donations"].frame.minY < app!.buttons["Delete Groceries"].frame.minY
        }
        wait(for: [XCTNSPredicateExpectation(predicate: moved, object: nil)], timeout: 4)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "value == %@", "2 of 5 items checked")).firstMatch.exists, "Groceries stays folded after the move")
        shot("theme-\(tag)-moved")
        app.buttons["Done editing Errands"].tap()
    }
}
