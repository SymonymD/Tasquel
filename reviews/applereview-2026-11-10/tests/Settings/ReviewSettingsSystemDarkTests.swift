import XCTest

/// The device switching to Dark while Tasquel is open (in System), with Settings open over a
/// card with a folded list, and back to Light.
final class ReviewSettingsSystemDarkTests: ReviewSettingsBase {

    @MainActor
    func testSystemDarkModeSwitchWhileOpen() {
        setDeviceAppearance(dark: false)
        launchDemo(["-demoAppearance", "system"])
        openCard("Errands")
        app.buttons["Fold Groceries"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "value == %@", "2 of 5 items checked")).firstMatch.waitForExistence(timeout: 2))
        openSettings()
        XCTAssertGreaterThan(brightness(atY: 0.9), 0.7, "Settings is light to start")
        shot("sysdark-0-settings-light")

        setDeviceAppearance(dark: true)
        app.activate()
        XCTAssertTrue(app.buttons["System"].waitForExistence(timeout: 5), "Settings is still open")
        sleep(1)
        shot("sysdark-1-settings-dark")
        XCTAssertLessThan(brightness(atY: 0.9), 0.3, "open Settings followed the device to Dark")
        closeSettings()
        shot("sysdark-2-main-dark")
        XCTAssertLessThan(brightness(atY: 0.5, x: 0.05), 0.3, "the main screen is dark")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "value == %@", "2 of 5 items checked")).firstMatch.exists, "still folded")
        auditContrast("system-dark main")

        // And back to Light, with Settings open again.
        openSettings()
        setDeviceAppearance(dark: false)
        app.activate()
        XCTAssertTrue(app.buttons["System"].waitForExistence(timeout: 5))
        sleep(1)
        shot("sysdark-3-settings-light-again")
        XCTAssertGreaterThan(brightness(atY: 0.9), 0.7, "open Settings followed the device back to Light")
        closeSettings()
        shot("sysdark-4-main-light-again")
    }

    /// Asks the shell helper (scripts/appearance_helper.sh, run beside the test) to switch the
    /// simulator to Light or Dark with `simctl ui appearance`, and waits until it has.
    @MainActor
    private func setDeviceAppearance(dark: Bool) {
        let want = dark ? "dark" : "light"
        let request = URL(fileURLWithPath: "\(shotDir)/appearance-request")
        let done = URL(fileURLWithPath: "\(shotDir)/appearance-done")
        try? FileManager.default.removeItem(at: done)
        try? want.write(to: request, atomically: true, encoding: .utf8)
        for _ in 0..<40 {
            if (try? String(contentsOf: done, encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines) == want { sleep(1); return }
            Thread.sleep(forTimeInterval: 0.5)
        }
        XCTFail("no appearance helper answered for \(want)")
    }

    /// How light the screen is at a point (0–1).
    @MainActor
    private func brightness(atY y: Double, x: Double = 0.5) -> CGFloat {
        let image = XCUIScreen.main.screenshot().image
        guard let cg = image.cgImage, let data = cg.dataProvider?.data, let bytes = CFDataGetBytePtr(data) else { return -1 }
        let px = Int(Double(cg.width) * x), py = Int(Double(cg.height) * y)
        let offset = py * cg.bytesPerRow + px * (cg.bitsPerPixel / 8)
        return (CGFloat(bytes[offset]) + CGFloat(bytes[offset + 1]) + CGFloat(bytes[offset + 2])) / (3 * 255)
    }
}
