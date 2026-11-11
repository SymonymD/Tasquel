import XCTest

/// Settings rows other than themes: Help, the Welcome Tour, Feature Ideas (never sent),
/// links, version, Match App Icon to Theme.
final class ReviewSettingsRowsTests: ReviewSettingsBase {

    /// Help's List entry describes folding, in the standard and the Retro layout.
    @MainActor
    func testHelpListEntryDescribesFolding() {
        launchDemo(["-demoAppearance", "light"])
        openSettings()
        let help = app.buttons["How to Use Tasquel"]
        for _ in 0..<8 where !(help.exists && help.isHittable) { app.collectionViews.firstMatch.swipeUp(velocity: .slow) }
        help.tap()
        let fold = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "fold the items away")).firstMatch
        for _ in 0..<8 where !(fold.exists && fold.isHittable) { app.swipeUp(velocity: .slow) }
        XCTAssertTrue(fold.exists, "Help's List entry mentions folding")
        shot("help-list-light")
        app.navigationBars.buttons["Done"].firstMatch.tap()
        closeSettings()

        chooseTheme("Retro", color: "Amber")
        dismissIconAlert(timeout: 2)
        openSettings()
        let howTo = app.buttons["> How to Use Tasquel"]
        for _ in 0..<6 where !(howTo.exists && howTo.isHittable) { app.swipeUp(velocity: .slow) }
        howTo.tap()
        XCTAssertTrue(app.staticTexts["> HELP_"].waitForExistence(timeout: 3) || app.navigationBars["> HELP_"].exists)
        for _ in 0..<10 where !(fold.exists && fold.isHittable) { app.swipeUp(velocity: .slow) }
        XCTAssertTrue(fold.exists, "Retro Help too")
        shot("help-list-retro")
    }

    /// Settings ▸ Show Welcome Tour: every page, then Done, back in Settings.
    @MainActor
    func testWelcomeTourFromSettings() {
        launchDemo(["-demoAppearance", "dark"])
        openSettings()
        let tour = app.buttons["Show Welcome Tour"]
        for _ in 0..<8 where !(tour.exists && tour.isHittable) { app.collectionViews.firstMatch.swipeUp(velocity: .slow) }
        tour.tap()
        XCTAssertTrue(app.staticTexts["Welcome to Tasquel"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Close"].exists, "the tour says Close, not Skip")
        var page = 0
        while app.buttons["Next"].exists && page < 12 {
            shot("tour-dark-\(page)", settle: 0.6)
            app.buttons["Next"].tap()
            page += 1
        }
        shot("tour-dark-\(page)")
        let done = app.buttons["Done"].firstMatch
        XCTAssertTrue(done.exists, "the last page says Done")
        print("REVIEW: tour pages \(page + 1)")
        done.tap()
        XCTAssertTrue(app.buttons["Show Welcome Tour"].waitForExistence(timeout: 3), "back in Settings")
        closeSettings()
        XCTAssertFalse(app.staticTexts["Welcome to Tasquel"].exists)
    }

    /// Feature Ideas: ticks and a comment; Send is there and ready, and never tapped.
    @MainActor
    func testFeatureIdeasTickAndComment() {
        launchDemo(["-demoAppearance", "light"])
        openSettings()
        let sync = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Sync Across Devices")).firstMatch
        for _ in 0..<8 where !(sync.exists && sync.isHittable) { app.collectionViews.firstMatch.swipeUp(velocity: .slow) }
        sleep(1)
        sync.tap()
        XCTAssertTrue(sync.isSelected)
        let comment = app.collectionViews.textFields.firstMatch
        for _ in 0..<4 where !(comment.exists && comment.isHittable) { app.collectionViews.firstMatch.swipeUp(velocity: .slow) }
        comment.tap()
        comment.typeText("Widgets please")
        let send = app.buttons["Send Anonymously"]
        XCTAssertTrue(send.exists, "Send is there (not tapped: it posts to a live server)")
        XCTAssertTrue(send.isEnabled)
        shot("feature-ideas-light")
        app.buttons["Done"].firstMatch.tap()  // keyboard Done if any, else Settings' Done
    }

    /// The version and build shown match the project's (1.0.2 / 10 until the bump).
    @MainActor
    func testVersionMatchesProject() {
        launchDemo(["-demoAppearance", "light"])
        openSettings()
        let version = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", "1.0.2", "1.0.2")).firstMatch
        for _ in 0..<10 where !(version.exists && version.isHittable) { app.collectionViews.firstMatch.swipeUp() }
        XCTAssertTrue(version.exists, "Version 1.0.2")
        let build = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@ OR value == %@ OR label CONTAINS %@", "10", "10", "Build, 10")).firstMatch; print("REVIEW: version element \(version.debugDescription.prefix(200))"); XCTAssertTrue(build.exists, "Build 10")
        shot("about-light")
    }

    /// Support and Privacy Policy open Safari at the right pages (read only).
    @MainActor
    func testSupportAndPrivacyLinksOpenSafari() {
        launchDemo(["-demoAppearance", "light"])
        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        for row in ["Support", "Privacy Policy"] {
            openSettings()
            let link = app.buttons[row].firstMatch
            for _ in 0..<10 where !(link.exists && link.isHittable) { app.collectionViews.firstMatch.swipeUp() }
            link.tap()
            XCTAssertTrue(safari.wait(for: .runningForeground, timeout: 10), "\(row) opens Safari")
            // The page has loaded once it shows Tasquel's name (slow networks: up to 20 s).
            _ = safari.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Tasquel")).firstMatch.waitForExistence(timeout: 20)
            let address = safari.textFields.firstMatch.exists ? (safari.textFields.firstMatch.value as? String ?? "") : ""
            let urlButton = safari.buttons.matching(NSPredicate(format: "identifier == 'TabBarItemTitle' OR identifier == 'URL'")).firstMatch
            print("REVIEW: \(row) address field '\(address)' url '\(urlButton.exists ? urlButton.label : "-")'")
            shot("link-\(row.replacingOccurrences(of: " ", with: "-").lowercased())")
            let pageText = safari.staticTexts.allElementsBoundByIndex.prefix(12).map(\.label).joined(separator: " | ")
            print("REVIEW: \(row) page text: \(pageText)")
            XCTAssertFalse(pageText.localizedCaseInsensitiveContains("404") || pageText.localizedCaseInsensitiveContains("not found"),
                           "\(row) isn't a dead end")
            XCTAssertTrue(pageText.localizedCaseInsensitiveContains("Tasquel"), "\(row) shows a Tasquel page")
            app.activate()
            XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
            // Settings may still be open: close it.
            if app.navigationBars["Settings"].exists { closeSettings() }
        }
    }

    /// Match App Icon to Theme, at a person's pace: Retro gives the home screen the retro
    /// icon, Light puts the standard one back, and with the switch off Retro keeps the
    /// standard icon. Checked on the home screen after each step.
    @MainActor
    func testMatchAppIconToTheme() {
        launchDemo(["-demoAppearance", "light"])
        openSettings()
        let toggle = app.switches.matching(NSPredicate(format: "label CONTAINS %@", "Match App Icon")).firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 3))
        if toggle.value as? String == "0" { toggle.switches.firstMatch.tap(); handleIconAlert() }
        XCTAssertEqual(toggle.value as? String, "1")
        // Start from the standard icon.
        app.buttons["Light"].firstMatch.tap()
        handleIconAlert()
        closeSettings()
        XCTAssertFalse(homeIconIsRetro("icon-0-light"), "standard icon to start")

        openSettings()
        app.buttons["Retro"].firstMatch.tap()
        let alerted = handleIconAlert()
        print("REVIEW: alert on choosing Retro: \(alerted)")
        shot("icon-1-retro-settings")
        closeSettings()
        XCTAssertTrue(homeIconIsRetro("icon-1-retro"), "Retro gives the retro icon")

        openSettings()
        app.buttons["Light"].firstMatch.tap()
        print("REVIEW: alert on choosing Light: \(handleIconAlert())")
        closeSettings()
        XCTAssertFalse(homeIconIsRetro("icon-2-light"), "Light puts the standard icon back")

        openSettings()
        let off = app.switches.matching(NSPredicate(format: "label CONTAINS %@", "Match App Icon")).firstMatch
        off.switches.firstMatch.tap()
        handleIconAlert()
        XCTAssertEqual(off.value as? String, "0")
        app.buttons["Retro"].firstMatch.tap()
        print("REVIEW: alert on Retro with the switch off: \(handleIconAlert())")
        closeSettings()
        XCTAssertFalse(homeIconIsRetro("icon-3-retro-switch-off"), "switch off: Retro keeps the standard icon")

        // The switch is remembered; turning it back on in Retro switches the icon.
        relaunch()
        openSettings()
        let again = app.switches.matching(NSPredicate(format: "label CONTAINS %@", "Match App Icon")).firstMatch
        XCTAssertTrue(again.waitForExistence(timeout: 3))
        XCTAssertEqual(again.value as? String, "0", "the switch is remembered")
        app.buttons["Light"].firstMatch.tap()
        handleIconAlert()
        again.switches.firstMatch.tap()
        handleIconAlert()
        XCTAssertEqual(again.value as? String, "1")
        closeSettings()
        XCTAssertFalse(homeIconIsRetro("icon-4-light-on"), "Light with the switch on: standard icon")
    }

    /// iOS's "You have changed the icon" alert: in the app or on the home screen. Waits a
    /// moment first, as a person would. Returns whether there was one.
    @MainActor
    @discardableResult
    private func handleIconAlert() -> Bool {
        sleep(2)
        for host in [app!, springboard] {
            let alert = host.alerts.firstMatch
            if alert.waitForExistence(timeout: 2) {
                print("REVIEW: icon alert '\(alert.label)' \(alert.staticTexts.allElementsBoundByIndex.map(\.label))")
                let ok = alert.buttons["OK"]
                (ok.exists ? ok : alert.buttons.firstMatch).tap()
                sleep(1)
                return true
            }
        }
        return false
    }

    /// Presses Home and looks at Tasquel's icon: the retro one is phosphor green on black.
    @MainActor
    private func homeIconIsRetro(_ name: String) -> Bool {
        sleep(2)
        XCUIDevice.shared.press(.home)
        sleep(2)
        let icon = springboard.icons["Tasquel"]
        guard icon.waitForExistence(timeout: 5) else { XCTFail("no home-screen icon"); return false }
        let screenshot = XCUIScreen.main.screenshot()
        try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: "\(shotDir)/\(name)-home.png"))
        let frame = icon.frame
        var green = 0, total = 0
        if let cg = screenshot.image.cgImage, let data = cg.dataProvider?.data, let bytes = CFDataGetBytePtr(data) {
            let scale = CGFloat(cg.width) / XCUIScreen.main.screenshot().image.size.width
            let side = min(frame.width, frame.height) * 0.8
            let originX = frame.midX - side / 2, originY = frame.minY + (frame.width - side) / 2
            for i in stride(from: 0, to: side, by: 2) {
                for j in stride(from: 0, to: side, by: 2) {
                    let px = Int((originX + i) * scale), py = Int((originY + j) * scale)
                    guard px >= 0, py >= 0, px < cg.width, py < cg.height else { continue }
                    let o = py * cg.bytesPerRow + px * (cg.bitsPerPixel / 8)
                    let r = Int(bytes[o]), g = Int(bytes[o + 1]), b = Int(bytes[o + 2])
                    total += 1
                    if g > 150 && r < 120 && b < 120 { green += 1 }
                }
            }
        }
        let fraction = total == 0 ? 0 : Double(green) / Double(total)
        print("REVIEW: \(name) home icon green fraction \(String(format: "%.3f", fraction))")
        app.activate()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 5))
        return fraction > 0.04
    }
}
