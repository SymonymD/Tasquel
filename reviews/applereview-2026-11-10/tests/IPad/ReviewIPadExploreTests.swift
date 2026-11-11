import XCTest

/// Exploration: dumps the tree and takes pictures of the main iPad states.
final class ReviewIPadExploreTests: ReviewIPadBase {
    @MainActor
    func testExploreLayout() throws {
        launch(["-demoData", "-demoFirstCard", "Errands"], orientation: .landscapeLeft)
        log("window \(windowFrame)")
        shot("explore-01-landscape-closed")
        openCard("Errands")
        shot("explore-02-landscape-errands-open")
        print(app.debugDescription)
        app.buttons["Fold Groceries"].tap()
        shot("explore-03-landscape-groceries-folded")
        app.buttons["Edit Errands"].tap()
        shot("explore-04-landscape-edit")
        XCUIDevice.shared.orientation = .portrait
        shot("explore-05-portrait-edit")
        print(app.debugDescription)
    }
}
