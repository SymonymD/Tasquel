import XCTest

/// Settings while it's open: the appearance it shows, and the Feature Ideas draft (never
/// sent here: Send posts to a live server).
final class SettingsUITests: XCTestCase {
    private var app: XCUIApplication!

    @MainActor
    override func setUp() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchArguments = ["-isolatedData"]
        app.launch()
        if app.staticTexts["Welcome to Tasquel"].waitForExistence(timeout: 3) { app.buttons["Skip"].tap() }
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 5))
    }

    /// Choosing System with Settings open shows the device's appearance in Settings right
    /// away (it used to keep the Dark it had until reopened). The simulator is in Light.
    @MainActor
    func testSystemAppearanceAppliesToOpenSettings() throws {
        app.buttons["Settings"].tap()
        let dark = app.buttons["Dark"]
        XCTAssertTrue(dark.waitForExistence(timeout: 3))
        dark.tap()
        sleep(1)
        XCTAssertLessThan(settingsBrightness(), 0.3, "Settings went dark")
        app.buttons["System"].tap()
        sleep(1)
        XCTAssertGreaterThan(settingsBrightness(), 0.7, "and back to the device's Light with System")
    }

    /// Ticks and a comment in Feature Ideas are still there after closing and reopening
    /// Settings, and a growing comment keeps its last line above the keyboard.
    @MainActor
    func testFeatureIdeasDraftIsKept() throws {
        app.buttons["Settings"].tap()
        let stats = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Stats & Charts")).firstMatch
        for _ in 0..<6 where !(stats.exists && stats.isHittable) { app.collectionViews.firstMatch.swipeUp(velocity: .slow) }
        sleep(1)  // the list has stopped moving
        stats.tap()
        sleep(1)
        XCTAssertTrue(stats.isSelected, "ticked")
        // The only text field on the Settings page (found this way with or without text).
        let comment = app.collectionViews.textFields.firstMatch
        for _ in 0..<4 where !(comment.exists && comment.isHittable) { app.collectionViews.firstMatch.swipeUp(velocity: .slow) }
        sleep(1)
        comment.tap()
        comment.typeText("Widgets\nA watch app\nShared lists\nDark icons")
        sleep(1)
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.exists)
        XCTAssertLessThanOrEqual(comment.frame.maxY, keyboard.frame.minY + 1, "the comment's last line is above the keyboard")

        app.buttons["Done"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 3))
        app.buttons["Settings"].tap()
        for _ in 0..<6 where !(stats.exists && stats.isHittable) { app.collectionViews.firstMatch.swipeUp(velocity: .slow) }
        sleep(1)
        XCTAssertTrue(stats.isSelected, "still ticked after reopening Settings")
        for _ in 0..<4 where !comment.exists { app.collectionViews.firstMatch.swipeUp(velocity: .slow) }
        XCTAssertTrue((comment.value as? String ?? "").hasPrefix("Widgets"), "and the comment is kept")
    }

    /// How light the Settings sheet's background is, near the bottom of the screen (0–1).
    private func settingsBrightness() -> CGFloat {
        let image = XCUIScreen.main.screenshot().image
        guard let cg = image.cgImage else { return -1 }
        let x = cg.width / 2, y = Int(Double(cg.height) * 0.9)
        guard let data = cg.dataProvider?.data, let bytes = CFDataGetBytePtr(data) else { return -1 }
        let offset = y * cg.bytesPerRow + x * (cg.bitsPerPixel / 8)
        let r = CGFloat(bytes[offset]), g = CGFloat(bytes[offset + 1]), b = CGFloat(bytes[offset + 2])
        return (r + g + b) / (3 * 255)
    }
}
