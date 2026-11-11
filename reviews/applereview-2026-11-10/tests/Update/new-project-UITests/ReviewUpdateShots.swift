import XCTest

/// Update review: the same read-only walk in both copies (live 1.0.2 and new), on the real
/// storage ReviewUpdateSeed filled. For each week (this, next, the one after) and each card it
/// takes a screenshot and writes the accessibility tree, so before and after can be compared
/// (`update_check.sh` strips frames and diffs them). It opens and closes cards only: nothing
/// is changed or saved by it. SHOT_DIR is the folder, SHOT_PREFIX names the files.
final class ReviewUpdateShots: XCTestCase {
    @MainActor
    func testDumpScreens() throws {
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
        let env = ProcessInfo.processInfo.environment
        let dir = env["SHOT_DIR"] ?? NSTemporaryDirectory()
        let prefix = env["SHOT_PREFIX"] ?? "shots"
        let app = XCUIApplication()
        app.launchArguments = []
        app.launch()
        XCTAssertFalse(app.staticTexts["Welcome to Tasquel"].waitForExistence(timeout: 3), "no onboarding for an existing user")
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 8))
        sleep(1)

        func save(_ name: String) {
            sleep(1)
            try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/\(prefix)-\(name).png"))
            try? app.debugDescription.write(toFile: "\(dir)/\(prefix)-\(name).txt", atomically: true, encoding: .utf8)
        }

        let cards = ["Errands", "Fitness", "Work", "Trip", "Study", "Appointments"]
        for (week, label) in [(0, "w0"), (1, "w1"), (2, "w2")] {
            if week > 0 { app.buttons["Next week"].tap(); sleep(1) }
            save("\(label)-home")
            for card in cards {
                let open = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open \(card),")).firstMatch
                guard open.waitForExistence(timeout: 2) else {
                    print("REVIEW: \(prefix) \(label) no card \(card)")
                    continue
                }
                open.tap()
                _ = app.buttons["Close \(card)"].waitForExistence(timeout: 3)
                save("\(label)-\(card)")
                // A long card can push others off screen: scroll down for a second look.
                app.buttons["Close \(card)"].tap()
                sleep(1)
            }
        }
        app.buttons["Previous week"].tap(); sleep(1)
        app.buttons["Previous week"].tap(); sleep(1)
        app.buttons["Settings"].tap()
        sleep(1)
        save("settings")
        app.buttons["Done"].firstMatch.tap()
        app.terminate()
    }
}
