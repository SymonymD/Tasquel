import XCTest

/// A first-time user's session in Tasquel. Every test launches with the same throwaway
/// data (`-isolatedDataID`), so each run continues where the last one left off. To start
/// completely fresh, change `dataID`.
final class SwitcherTests: XCTestCase {
    static let dataID = "switcher-1"
    var app: XCUIApplication!
    let shotDir = ProcessInfo.processInfo.environment["SHOT_DIR"] ?? NSTemporaryDirectory()

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments = ["-isolatedDataID", Self.dataID, "-smartAddRules", "-fakeCalendar"]
    }

    /// A screenshot and the accessibility tree, saved as <name>.png and <name>.txt.
    func snap(_ name: String) {
        Thread.sleep(forTimeInterval: 0.8)
        try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(shotDir)/\(name).png"))
        try? app.debugDescription.write(toFile: "\(shotDir)/\(name).txt", atomically: true, encoding: .utf8)
    }

    /// Taps a system alert's button (notifications, calendar) if one is showing.
    func allowSystemAlert(_ button: String = "Allow") {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let b = springboard.alerts.buttons[button]
        if b.waitForExistence(timeout: 2) { b.tap() }
    }

    func test00_firstLaunch() {
        app.launch()
        snap("00-first-launch")
    }

    func test01_skipAndLook() {
        app.launch()
        let skip = app.buttons["Skip"]
        if skip.waitForExistence(timeout: 5) { skip.tap() }
        snap("01a-home")
        let fitness = app.buttons["Open Fitness, no tasks yet"]
        if fitness.waitForExistence(timeout: 3) { fitness.tap() }
        snap("01b-fitness-open")
    }

    /// Opens a card by its title, whatever its task count says.
    func openCard(_ name: String) {
        let closed = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open \(name)")).firstMatch
        if closed.waitForExistence(timeout: 3) { closed.tap() }
    }

    func test02_addRun() {
        app.launch()
        openCard("Fitness")
        let add = app.buttons["Add task"].firstMatch
        if add.waitForExistence(timeout: 3) { add.tap() }
        snap("02a-add-tapped")
        // Type the way I'd name it in Streaks
        app.typeText("Run 3 times a week")
        snap("02b-typed")
    }

    func dismissKeyboardIntro() {
        let c = app.buttons["Continue"]
        if c.waitForExistence(timeout: 1) { c.tap() }
    }

    func test03_runOptionsThenSmartAdd() {
        app.launch()
        openCard("Fitness")
        let add = app.buttons["Add task"].firstMatch
        if add.waitForExistence(timeout: 3) { add.tap() }
        dismissKeyboardIntro()
        app.typeText("Run 3 times a week")
        let opts = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'New task options'")).firstMatch
        if opts.waitForExistence(timeout: 3) { opts.tap() }
        snap("03a-options-menu")
        // Close the menu the way a person would: tap empty space at the top
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.06)).tap()
        snap("03b-menu-closed")
        let smart = app.buttons["Smart Add"]
        if smart.waitForExistence(timeout: 3) { smart.tap() }
        snap("03c-smart-add")
    }

    // MARK: - Step runner
    // So each decision doesn't need a rebuild, test90 reads `<SHOT_DIR>/script.txt`, one step per line:
    //   launch | terminate | snap <name> | tap <label> | tapn <index> <label> | tapb <label prefix>
    //   tapxy <x> <y> | type <text> | delete <n> | press <label> <seconds> | swipe <up|down|left|right> [label]
    //   wait <seconds> | alert <button> | exists <label> | drag <fromLabel> -> <toLabel>
    // Each script is kept in the evidence folder as steps-<name>.txt.

    func element(_ label: String, index: Int = 0) -> XCUIElement {
        let pred = NSPredicate(format: "label == %@ OR identifier == %@", label, label)
        let btn = app.buttons.matching(pred)
        if btn.count > index { return btn.element(boundBy: index) }
        return app.descendants(matching: .any).matching(pred).element(boundBy: index)
    }

    func test90_script() {
        let path = "\(shotDir)/script.txt"
        guard let text = try? String(contentsOfFile: path, encoding: .utf8) else {
            XCTFail("no script at \(path)"); return
        }
        for raw in text.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            let parts = line.split(separator: " ", maxSplits: 1).map(String.init)
            let cmd = parts[0], arg = parts.count > 1 ? parts[1] : ""
            print("REVIEW: step \(line)")
            switch cmd {
            case "launch": app.launch()
            case "terminate": app.terminate()
            case "snap": snap(arg)
            case "tap":
                let e = element(arg)
                if e.waitForExistence(timeout: 4) { e.tap() } else { print("REVIEW: NOT FOUND \(arg)") }
            case "tapn":
                let p = arg.split(separator: " ", maxSplits: 1).map(String.init)
                let e = element(p[1], index: Int(p[0]) ?? 0)
                if e.waitForExistence(timeout: 4) { e.tap() } else { print("REVIEW: NOT FOUND \(arg)") }
            case "tapb":
                let e = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", arg)).firstMatch
                if e.waitForExistence(timeout: 4) { e.tap() } else { print("REVIEW: NOT FOUND \(arg)") }
            case "tapxy":
                let p = arg.split(separator: " ").compactMap { Double($0) }
                app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: p[0], dy: p[1])).tap()
            case "type": app.typeText(arg)
            case "enter": app.typeText("\n")
            case "delete": app.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: Int(arg) ?? 1))
            case "press":
                let p = arg.components(separatedBy: " ")
                let secs = Double(p.last ?? "") ?? 1.0
                let label = Double(p.last ?? "") != nil ? p.dropLast().joined(separator: " ") : arg
                let e = element(label)
                if e.waitForExistence(timeout: 4) { e.press(forDuration: secs) } else { print("REVIEW: NOT FOUND \(label)") }
            case "swipe":
                let p = arg.split(separator: " ", maxSplits: 1).map(String.init)
                let target: XCUIElement = p.count > 1 ? element(p[1]) : app
                switch p[0] {
                case "up": target.swipeUp()
                case "down": target.swipeDown()
                case "left": target.swipeLeft()
                default: target.swipeRight()
                }
            case "drag":
                let p = arg.components(separatedBy: " -> ")
                let a = element(p[0]), b = element(p[1])
                if a.exists && b.exists { a.press(forDuration: 0.8, thenDragTo: b) } else { print("REVIEW: NOT FOUND drag") }
            case "field":
                // field <placeholder> : tap the text field showing this placeholder (or label)
                let pred = NSPredicate(format: "placeholderValue == %@ OR label == %@", arg, arg)
                let f = app.textFields.matching(pred).firstMatch
                if f.waitForExistence(timeout: 4) { f.tap() } else { print("REVIEW: NOT FOUND field \(arg)") }
            case "clear":
                // clear <placeholder> : tap the field and delete what's in it
                let pred = NSPredicate(format: "placeholderValue == %@ OR label == %@", arg, arg)
                let f = app.textFields.matching(pred).firstMatch
                if f.waitForExistence(timeout: 4) {
                    f.tap()
                    let n = ((f.value as? String) ?? "").count
                    f.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: max(n, 1) + 2))
                } else { print("REVIEW: NOT FOUND field \(arg)") }
            case "dump":
                print("REVIEW: dump \(app.debugDescription)")
            case "wait": Thread.sleep(forTimeInterval: Double(arg) ?? 1)
            case "alert": allowSystemAlert(arg)
            case "exists": print("REVIEW: exists \(arg) = \(element(arg).exists)")
            default: print("REVIEW: unknown step \(line)")
            }
        }
    }
}
