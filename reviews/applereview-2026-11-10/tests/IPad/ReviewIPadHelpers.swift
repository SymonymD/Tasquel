import XCTest
import ObjectiveC

/// On a heavily loaded Mac every XCUITest step waited 30 s for the app and SpringBoard to
/// "idle". Skipping those waits (test side only; set REVIEW_KEEP_QUIESCENCE=1 to keep them)
/// leaves the tests' own waits and sleeps to do the pacing.
private enum Quiescence {
    static let skip: Void = {
        guard ProcessInfo.processInfo.environment["REVIEW_KEEP_QUIESCENCE"] == nil,
              let cls = NSClassFromString("XCUIApplicationProcess") else { return }
        let one: @convention(block) (AnyObject, Bool) -> Void = { _, _ in }
        let two: @convention(block) (AnyObject, Bool, Bool) -> Void = { _, _, _ in }
        if let m = class_getInstanceMethod(cls, NSSelectorFromString("waitForQuiescenceIncludingAnimationsIdle:")) {
            method_setImplementation(m, imp_implementationWithBlock(one))
        }
        if let m = class_getInstanceMethod(cls, NSSelectorFromString("waitForQuiescenceIncludingAnimationsIdle:isPreEvent:")) {
            method_setImplementation(m, imp_implementationWithBlock(two))
        }
    }()
}

/// Shared helpers for the iPad review tests (ReviewIPad*.swift).
class ReviewIPadBase: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        _ = Quiescence.skip
    }

    /// Launches with the given arguments, in the given orientation, skipping onboarding.
    @MainActor
    @discardableResult
    func launch(_ arguments: [String] = ["-demoData"], orientation: UIDeviceOrientation = .portrait) -> XCUIApplication {
        XCUIDevice.shared.orientation = orientation
        let app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
        Thread.sleep(forTimeInterval: 2)
        if app.staticTexts["Welcome to Tasquel"].waitForExistence(timeout: 3) {
            app.buttons["Skip"].firstMatch.tap()
        }
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 8), "the week shows")
        self.app = app
        return app
    }

    /// Writes a screenshot to the shots folder (SHOT_DIR) and attaches it.
    @MainActor
    func shot(_ name: String) {
        Thread.sleep(forTimeInterval: 0.6)
        let screenshot = XCUIScreen.main.screenshot()
        let dir = ProcessInfo.processInfo.environment["SHOT_DIR"] ?? NSTemporaryDirectory()
        try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func card(_ name: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open \(name),")).firstMatch
    }

    @MainActor
    func openCard(_ name: String) {
        let card = card(name)
        XCTAssertTrue(card.waitForExistence(timeout: 5), "\(name) card exists")
        card.tap()
        XCTAssertTrue(app.buttons["Edit \(name)"].waitForExistence(timeout: 5), "\(name) opened")
        Thread.sleep(forTimeInterval: 1.2)  // the card's spring and the edit button's fade
    }

    /// A task's reorder handle (just right of its delete button in the card's edit mode).
    @MainActor
    func handle(_ title: String) -> XCUICoordinate {
        app.buttons["Delete \(title)"].coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5))
            .withOffset(CGVector(dx: 12, dy: 0))
    }

    /// A text field or text view by identifier (wrapping fields are text views).
    @MainActor
    func renameField(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "(identifier == %@ OR label == %@) AND (elementType == %d OR elementType == %d)",
            identifier, identifier, XCUIElement.ElementType.textField.rawValue, XCUIElement.ElementType.textView.rawValue)).firstMatch
    }

    @MainActor
    var weekTitle: String {
        app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Week of")).firstMatch.label
    }

    @MainActor
    var keyboardUp: Bool { app.keyboards.firstMatch.exists }

    /// The app's window frame (the first window).
    @MainActor
    var windowFrame: CGRect { app.windows.firstMatch.frame }

    @MainActor
    func log(_ text: String) { print("REVIEW: \(text)") }

    /// Is `inner` wholly inside `outer`, give or take a point?
    func contains(_ outer: CGRect, _ inner: CGRect) -> Bool {
        outer.insetBy(dx: -1, dy: -1).contains(inner)
    }
}
