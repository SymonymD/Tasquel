import XCTest

/// iPad review, 2026-11-15: the landscape half-width lanes (four columns), rotation, and
/// what one card opening does to the others.
final class ReviewIPadLanesTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
        super.tearDown()
    }

    // MARK: Helpers

    static func shot(_ name: String) {
        let dir = ProcessInfo.processInfo.environment["SHOT_DIR"] ?? NSTemporaryDirectory()
        try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
    }

    static func launchDemo(_ extra: [String] = [], orientation: UIDeviceOrientation = .landscapeLeft) -> XCUIApplication {
        XCUIDevice.shared.orientation = orientation
        let app = XCUIApplication()
        app.launchArguments = ["-demoData"] + extra
        app.launch()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 15))
        Thread.sleep(forTimeInterval: 1)
        // iPadOS keeps a resized window's size across launches: start from a full window.
        let screen = XCUIApplication(bundleIdentifier: "com.apple.springboard").windows.firstMatch.frame
        if app.windows.firstMatch.frame.width < screen.width - 1 { resizeWindow(app, toScreen: screen) }
        return app
    }

    /// A closed card's button ("Open Errands, …").
    static func closedCard(_ name: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open \(name),")).firstMatch
    }

    /// An open card's frame: from its name heading to its Add task row is enough to tell
    /// lanes apart; the card's own Edit button marks its top right.
    static func openCardFrame(_ name: String, in app: XCUIApplication) -> CGRect {
        let edit = app.buttons["Edit \(name)"]
        return edit.exists ? edit.frame : .null
    }

    static func names(in app: XCUIApplication) -> [String] {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open ")).allElementsBoundByIndex.compactMap { el in
            let label = el.label
            guard label.contains(",") else { return nil }
            return String(label.dropFirst(5).prefix { $0 != "," })
        }
    }

    // MARK: Exploration

    @MainActor
    func testExploreLandscapeGrid() throws {
        let app = Self.launchDemo()
        Self.shot("lanes-00-landscape-closed")
        print("REVIEW window \(app.windows.firstMatch.frame)")
        let cards = Self.names(in: app)
        print("REVIEW cards \(cards)")
        for name in cards {
            print("REVIEW card \(name) \(Self.closedCard(name, in: app).frame)")
        }
        print(app.debugDescription)
    }

    /// The open card's span: from its Edit button's top (top right of the card) to the
    /// lowest Add task row in the same columns.
    static func openSpan(_ name: String, in app: XCUIApplication) -> CGRect {
        let edit = app.buttons["Edit \(name)"]
        guard edit.exists else { return .null }
        let heading = app.staticTexts.matching(NSPredicate(format: "label == %@", name)).allElementsBoundByIndex
            .filter { $0.frame.minY >= edit.frame.minY - 20 && $0.frame.maxY <= edit.frame.maxY + 20 && $0.frame.maxX < edit.frame.minX }
            .max { $0.frame.minX < $1.frame.minX }
        let left = (heading?.frame.minX ?? edit.frame.minX - 300) - 40
        let rows = app.buttons.matching(NSPredicate(format: "label == %@", "Add task")).allElementsBoundByIndex
            .filter { $0.frame.minX >= left - 10 && $0.frame.minX < edit.frame.maxX && $0.frame.minY > edit.frame.minY }
        let bottom = rows.map(\.frame.maxY).min() ?? edit.frame.maxY
        return CGRect(x: left, y: edit.frame.minY, width: edit.frame.maxX - left, height: bottom - edit.frame.minY)
    }

    static func open(_ name: String, in app: XCUIApplication) {
        let card = closedCard(name, in: app)
        XCTAssertTrue(card.waitForExistence(timeout: 5), "\(name) is closed and there")
        card.tap()
        XCTAssertTrue(app.buttons["Edit \(name)"].waitForExistence(timeout: 5), "\(name) opened")
        Thread.sleep(forTimeInterval: 1.2)
    }

    static func close(_ name: String, in app: XCUIApplication) {
        // An open card closes from a tap on its name (the heading).
        let edit = app.buttons["Edit \(name)"]
        let heading = app.staticTexts.matching(NSPredicate(format: "label == %@", name)).allElementsBoundByIndex
            .filter { abs($0.frame.midY - edit.frame.midY) < 30 && $0.frame.maxX < edit.frame.minX }
            .max { $0.frame.minX < $1.frame.minX }
        XCTAssertNotNil(heading, "\(name)'s heading")
        heading?.tap()
        XCTAssertTrue(closedCard(name, in: app).waitForExistence(timeout: 5), "\(name) closed")
        Thread.sleep(forTimeInterval: 1.2)
    }

    /// Opening a second card in landscape leaves an open card where it is: the one being
    /// worked in doesn't jump to the other lane (the brief: "check the cards don't jump").
    @MainActor
    func testOpeningAnotherCardKeepsOpenCardInItsLane() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "iPad only")
        let app = Self.launchDemo()
        Self.open("Work", in: app)
        let workBefore = Self.openSpan("Work", in: app)
        print("REVIEW Work alone \(workBefore)")
        Self.shot("lanes-01-work-open")
        print("REVIEW closed after Work: " + Self.names(in: app).map { "\($0) \(Self.closedCard($0, in: app).frame)" }.joined(separator: "; "))

        Self.open("Errands", in: app)
        let workAfter = Self.openSpan("Work", in: app)
        let errands = Self.openSpan("Errands", in: app)
        print("REVIEW Work after Errands opened \(workAfter), Errands \(errands)")
        Self.shot("lanes-02-errands-open")
        XCTAssertEqual(workAfter.minX, workBefore.minX, accuracy: 2, "Work stays in its lane when Errands opens")
        XCTAssertEqual(workAfter.minY, workBefore.minY, accuracy: 2, "Work stays at its height when Errands opens")

        Self.close("Errands", in: app)
        let workClosedOther = Self.openSpan("Work", in: app)
        print("REVIEW Work after Errands closed \(workClosedOther)")
        Self.shot("lanes-03-errands-closed")
        XCTAssertEqual(workClosedOther.minX, workAfter.minX, accuracy: 2, "Work stays put when Errands closes")
    }

    /// Every card's frame on screen (closed: its button; open: its span), for overlap checks.
    static func allFrames(in app: XCUIApplication, open: [String]) -> [(String, CGRect)] {
        var result = names(in: app).map { ($0, closedCard($0, in: app).frame) }
        for name in open { result.append((name + " (open)", openSpan(name, in: app))) }
        return result
    }

    static func assertNoOverlap(_ frames: [(String, CGRect)], _ when: String, file: StaticString = #filePath, line: UInt = #line) {
        for i in frames.indices {
            for j in frames.indices where j > i {
                let a = frames[i].1.insetBy(dx: 2, dy: 2), b = frames[j].1.insetBy(dx: 2, dy: 2)
                XCTAssertFalse(a.intersects(b), "\(when): \(frames[i].0) \(frames[i].1) overlaps \(frames[j].0) \(frames[j].1)", file: file, line: line)
            }
        }
    }

    static func resizeWindow(_ app: XCUIApplication, toScreen screen: CGRect) {
        let window = app.windows.firstMatch.frame
        let origin = XCUIApplication(bundleIdentifier: "com.apple.springboard").coordinate(withNormalizedOffset: .zero)
        origin.withOffset(CGVector(dx: window.maxX - 6, dy: window.maxY - 6))
            .press(forDuration: 0.3, thenDragTo: origin.withOffset(CGVector(dx: screen.maxX - 2, dy: screen.maxY - 2)))
        Thread.sleep(forTimeInterval: 1.5)
        print("REVIEW restored window \(app.windows.firstMatch.frame) screen \(screen)")
    }

    /// Resizes the app's window by its bottom-trailing handle (iPadOS 26 windowed apps).
    static func resizeWindow(_ app: XCUIApplication, toWidth width: CGFloat, height: CGFloat? = nil) {
        let window = app.windows.firstMatch.frame
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let origin = springboard.coordinate(withNormalizedOffset: .zero)
        let corner = origin.withOffset(CGVector(dx: window.maxX - 6, dy: window.maxY - 6))
        let target = origin.withOffset(CGVector(dx: window.minX + width - 6, dy: window.minY + (height ?? window.height) - 6))
        corner.press(forDuration: 0.3, thenDragTo: target)
        Thread.sleep(forTimeInterval: 1.5)
    }

    /// Rotating with open cards keeps them open and nothing overlaps, both ways.
    @MainActor
    func testRotatingWithOpenCardsKeepsThemOpenAndApart() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "iPad only")
        let app = Self.launchDemo()
        Self.open("Work", in: app)
        Self.open("Study", in: app)
        Self.shot("rotate-01-landscape-two-open")
        Self.assertNoOverlap(Self.allFrames(in: app, open: ["Work", "Study"]), "landscape")
        print("REVIEW landscape " + Self.allFrames(in: app, open: ["Work", "Study"]).map { "\($0.0) \($0.1)" }.joined(separator: "; "))

        XCUIDevice.shared.orientation = .portrait
        Thread.sleep(forTimeInterval: 2)
        Self.shot("rotate-02-portrait")
        XCTAssertTrue(app.buttons["Edit Work"].exists && app.buttons["Edit Study"].exists, "both still open in portrait")
        Self.assertNoOverlap(Self.allFrames(in: app, open: ["Work", "Study"]), "portrait")
        print("REVIEW portrait " + Self.allFrames(in: app, open: ["Work", "Study"]).map { "\($0.0) \($0.1)" }.joined(separator: "; "))

        XCUIDevice.shared.orientation = .landscapeRight
        Thread.sleep(forTimeInterval: 2)
        Self.shot("rotate-03-landscape-again")
        XCTAssertTrue(app.buttons["Edit Work"].exists && app.buttons["Edit Study"].exists, "both still open in landscape")
        Self.assertNoOverlap(Self.allFrames(in: app, open: ["Work", "Study"]), "landscape again")
        print("REVIEW landscape again " + Self.allFrames(in: app, open: ["Work", "Study"]).map { "\($0.0) \($0.1)" }.joined(separator: "; "))
    }

    /// Resizing the window from wide to narrow and back with open cards: they stay open,
    /// nothing overlaps or is cut off at the window's edge.
    @MainActor
    func testResizingWindowWithOpenCards() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "iPad only")
        let app = Self.launchDemo()
        Self.open("Errands", in: app)
        Self.open("Fitness", in: app)
        let full = app.windows.firstMatch.frame
        print("REVIEW window full \(full)")
        for (i, width) in [1000.0, 760.0, 520.0, 400.0, 1376.0].enumerated() {
            Self.resizeWindow(app, toWidth: width)
            let w = app.windows.firstMatch.frame
            print("REVIEW resized to \(width): window \(w)")
            Self.shot("resize-0\(i)-\(Int(width))")
            XCTAssertTrue(app.buttons["Edit Errands"].exists && app.buttons["Edit Fitness"].exists, "both open at \(width)")
            let frames = Self.allFrames(in: app, open: ["Errands", "Fitness"])
            print("REVIEW at \(Int(width)) " + frames.map { "\($0.0) \($0.1)" }.joined(separator: "; "))
            Self.assertNoOverlap(frames, "at \(Int(width))")
            for (name, f) in frames where !f.isNull {
                XCTAssertLessThanOrEqual(f.maxX - 8, w.maxX, "\(name) within the window at \(Int(width))")
            }
        }
    }

    /// With every card but the first open in landscape, the first card (closed) stays near
    /// the top, not sent below all the open cards, where it's off screen.
    @MainActor
    func testClosedFirstCardStaysInViewWhenOthersOpen() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "iPad only")
        let app = Self.launchDemo()
        let before = Self.closedCard("Errands", in: app).frame
        for name in ["Work", "Fitness", "Study"] { Self.open(name, in: app) }
        Self.shot("lanes-10-three-open")
        let errands = Self.closedCard("Errands", in: app)
        let window = app.windows.firstMatch.frame
        print("REVIEW Errands before \(before) after \(errands.frame) hittable \(errands.isHittable) window \(window)")
        print("REVIEW " + Self.allFrames(in: app, open: ["Work", "Fitness", "Study"]).map { "\($0.0) \($0.1)" }.joined(separator: "; "))
        XCTAssertLessThan(errands.frame.minY, window.height * 0.75, "the first card, closed, is still in view near the top")
    }

    /// Cards opened in landscape, then the iPad turned to portrait: the closed cards share
    /// rows as they do when the same cards are opened in portrait (each open card at the
    /// start of its row), not one closed card alone in a row of three.
    @MainActor
    func testRotatingToPortraitPacksClosedCards() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "iPad only")
        // Opened in portrait: the reference.
        let app = Self.launchDemo(orientation: .portrait)
        Self.open("Work", in: app)
        Self.open("Study", in: app)
        let e1 = Self.closedCard("Errands", in: app).frame, f1 = Self.closedCard("Fitness", in: app).frame
        print("REVIEW opened in portrait: Errands \(e1) Fitness \(f1)")
        Self.shot("pack-0-opened-in-portrait")
        XCTAssertEqual(e1.minY, f1.minY, accuracy: 2, "opened in portrait, Errands and Fitness share a row")
        app.terminate()

        // Opened in landscape, then turned.
        let app2 = Self.launchDemo(orientation: .landscapeLeft)
        Self.open("Work", in: app2)
        Self.open("Study", in: app2)
        XCUIDevice.shared.orientation = .portrait
        Thread.sleep(forTimeInterval: 2.5)
        let e2 = Self.closedCard("Errands", in: app2).frame, f2 = Self.closedCard("Fitness", in: app2).frame
        print("REVIEW opened in landscape then portrait: Errands \(e2) Fitness \(f2)")
        Self.shot("pack-1-opened-in-landscape-turned")
        XCTAssertEqual(e2.minY, f2.minY, accuracy: 2, "turned to portrait, Errands and Fitness share a row too")
    }
}
