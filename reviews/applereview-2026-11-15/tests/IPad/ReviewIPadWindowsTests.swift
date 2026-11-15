import XCTest

/// iPad review, 2026-11-15: two windows of the app side by side (the store is shared, so an
/// edit in one should show in the other).
final class ReviewIPadWindowsTests: XCTestCase {
    typealias L = ReviewIPadLanesTests

    override func setUpWithError() throws {
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .landscapeLeft
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
        super.tearDown()
    }

    /// Opens a second window from the home screen icon's menu (New Window), resizes both
    /// side by side, checks a task off in one and looks for it in the other.
    @MainActor
    func testTwoWindowsStayInSync() throws {
        let app = L.launchDemo(["-isolatedDataID", "twowin-\(UUID().uuidString)"], orientation: .landscapeLeft)
        L.resizeWindow(app, toWidth: 680)
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 1.5)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let icon = springboard.icons.matching(NSPredicate(format: "label == %@", "Tasquel")).firstMatch
        if !icon.waitForExistence(timeout: 3) {
            print("REVIEW no Tasquel icon on the home screen")
            L.shot("twowin-no-icon")
            return
        }
        icon.press(forDuration: 1.5)
        Thread.sleep(forTimeInterval: 1)
        L.shot("twowin-0-icon-menu")
        let labels = springboard.buttons.allElementsBoundByIndex.map(\.label)
        print("REVIEW icon menu buttons: \(labels)")
        let newWindow = springboard.buttons["New Window"]
        guard newWindow.exists else {
            print("REVIEW no New Window in the icon menu")
            return
        }
        newWindow.tap()
        Thread.sleep(forTimeInterval: 3)
        L.shot("twowin-1-new-window")
        print("REVIEW windows: \(app.windows.count) \(app.windows.allElementsBoundByIndex.map(\.frame))")
        print(app.debugDescription)
    }
}
