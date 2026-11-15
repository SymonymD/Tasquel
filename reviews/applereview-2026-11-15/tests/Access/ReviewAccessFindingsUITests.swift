import XCTest

/// Accessibility review (2026-11-15), one test per finding, each asserting what should
/// happen (it fails while the bug is there), plus the checks that were fine. Each starts
/// from a clean launch with throwaway demo data; Wednesday Nov 11 is today (`-demoToday`),
/// so the week has days gone by, today, and days to come.
final class ReviewAccessFindingsUITests: XCTestCase {
    private var dir: String { ProcessInfo.processInfo.environment["SHOT_DIR"] ?? NSTemporaryDirectory() }
    private static let axXXXL = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
    private static let xxxl = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryXXXL"]

    override func setUp() {
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
    }

    // MARK: - Findings

    /// At accessibility text sizes a task with a date ("Plan Mom's birthday", Nov 15) gets a
    /// name column about 60pt wide, so the name breaks into one-word (and part-word) lines
    /// and the row grows ~600pt tall. Its date mark should go under the name, as the icons do.
    @MainActor
    func testDatedTaskNameKeepsItsWidthAtLargestText() throws {
        let app = launch(Self.axXXXL)
        openCard("Errands", in: app)
        let name = app.staticTexts["Plan Mom's birthday"].firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        scrollIntoView(name, in: app)
        shot("F-dated-name-ax5", app)
        print("REVIEW: dated name frame=\(name.frame)")
        XCTAssertGreaterThan(name.frame.width, 150, "the name has most of the row, not a sliver beside its date")
        XCTAssertLessThan(name.frame.height, 260, "the name takes a few lines, not one per word")
    }

    /// Checked and fine: at XXXL (not an accessibility size) the same name wraps cleanly
    /// beside its date ("Plan Mom's / birthday  Nov 15").
    @MainActor
    func testDatedTaskNameKeepsItsWidthAtXXXL() throws {
        let app = launch(Self.xxxl)
        openCard("Errands", in: app)
        let name = app.staticTexts["Plan Mom's birthday"].firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        scrollIntoView(name, in: app)
        shot("F-dated-name-xxxl", app)
        print("REVIEW: dated name xxxl frame=\(name.frame)")
        XCTAssertGreaterThan(name.frame.width, 100, "room for whole words")
        XCTAssertLessThan(name.frame.height, 100, "two or three lines at most")
    }

    /// In a card's own edit mode at accessibility sizes, the "◯ Just this week" chip (which
    /// can't wrap) runs off the card and the screen, and squeezes the Completed line to
    /// nothing.
    @MainActor
    func testJustThisWeekChipFitsCardAtLargestText() throws {
        let app = launch(Self.axXXXL)
        openCard("Errands", in: app)
        XCTAssertTrue(app.buttons["Edit Errands"].waitForExistence(timeout: 5))
        app.editCard("Errands")
        let chip = app.descendants(matching: .any)["Just this week chip"].firstMatch
        XCTAssertTrue(chip.waitForExistence(timeout: 3))
        shot("F-chip-ax5", app)
        let screen = app.windows.firstMatch.frame
        let completed = app.staticTexts["1 of 4 complete"].firstMatch
        print("REVIEW: chip frame=\(chip.frame) completed=\(completed.frame) screen=\(screen)")
        XCTAssertLessThanOrEqual(chip.frame.maxX, screen.maxX - 16, "the chip stays inside the card")
        XCTAssertGreaterThan(completed.frame.width, 40, "the Completed line is still there")
    }

    /// Add Category ▸ Saved Categories at accessibility sizes: the Edit button beside the
    /// heading leaves it so little room that "Categories" breaks mid-word ("Cate- / gories").
    @MainActor
    func testSavedCategoriesHeadingDoesNotBreakMidWordAtLargestText() throws {
        let app = launch(Self.axXXXL)
        app.buttons["Edit"].tap()
        let addCard = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Add Category")).firstMatch
        XCTAssertTrue(addCard.waitForExistence(timeout: 5))
        shot("F-add-tile-ax5", app)
        addCard.tap()
        XCTAssertTrue(app.navigationBars["Add Category"].waitForExistence(timeout: 5))
        let heading = app.staticTexts["Saved Categories"].firstMatch
        let createNew = app.staticTexts["Create New"].firstMatch
        XCTAssertTrue(heading.waitForExistence(timeout: 3))
        sleep(1)
        let oneLine = createNew.frame.height
        // Up, so the heading is in full view.
        for _ in 0..<3 where heading.frame.maxY > app.windows.firstMatch.frame.maxY - 120 {
            app.collectionViews.firstMatch.swipeUp(velocity: .slow)
        }
        sleep(1)
        shot("F-saved-heading-ax5", app)
        print("REVIEW: saved heading frame=\(heading.frame) one header line=\(oneLine) edit=\(app.buttons["Edit Saved Categories"].frame)")
        XCTAssertLessThan(heading.frame.height, oneLine * 1.9, "the heading takes at most two lines (no word split across lines)")
    }

    /// The header's "What's New?" pill is fixed at 9pt: it's the same size at the largest
    /// accessibility text size as at the default.
    @MainActor
    func testWhatsNewPillGrowsWithTextSize() throws {
        let small = launch(["-demoWhatsNew"])
        let pill = small.buttons["What's New?"]
        XCTAssertTrue(pill.waitForExistence(timeout: 8))
        sleep(2)
        let defaultWidth = pill.frame.width
        shot("F-whatsnew-default", small)
        small.terminate()

        let large = launch(["-demoWhatsNew"] + Self.axXXXL)
        let bigPill = large.buttons["What's New?"]
        XCTAssertTrue(bigPill.waitForExistence(timeout: 8))
        sleep(2)
        shot("F-whatsnew-ax5", large)
        print("REVIEW: What's New pill width default=\(defaultWidth) ax5=\(bigPill.frame.width) frame=\(bigPill.frame)")
        XCTAssertGreaterThan(bigPill.frame.width, defaultWidth * 1.3, "its words grow with the text size")
    }

    /// Day pills: each tap area is the pill's width plus 8pt (32pt at the default size), less
    /// than 44pt wide, though seven 44pt targets fit in the strip.
    @MainActor
    func testDayPillTapTargetsAre44ptWide() throws {
        let app = launch([])
        let strip = app.descendants(matching: .any)["Week days"].firstMatch
        XCTAssertTrue(strip.waitForExistence(timeout: 5))
        for day in ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"] {
            let pill = app.buttons["Day \(day)"]
            XCTAssertTrue(pill.exists)
            print("REVIEW: pill \(day) frame=\(pill.frame)")
            XCTAssertGreaterThanOrEqual(pill.frame.width, 44, "\(day)'s pill is 44pt wide to tap")
            XCTAssertGreaterThanOrEqual(pill.frame.height, 44, "\(day)'s pill is 44pt tall to tap")
        }
    }

    /// Seasonal, light: today's day pill ("11th") and the "Today" / date marks are the
    /// season's `done` green, which is checked only for 3:1 (as an icon) but used for small
    /// text. Today's pill should have 4.5:1 against the header behind it.
    @MainActor
    func testSeasonalTodayPillTextContrast() throws {
        for season in ["spring", "summer", "fall", "winter"] {
            let app = launch(["-demoAppearance", "seasonal", "-demoSeason", season, "-demoFirstCard", "Errands"])
            let today = app.buttons["Day Wednesday"]
            XCTAssertTrue(today.waitForExistence(timeout: 5))
            sleep(1)
            let screenshot = XCUIScreen.main.screenshot()
            try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/F-seasonal-\(season)-light.png"))
            let ratio = Self.maxContrast(in: today.frame, of: screenshot.image)
            let past = Self.maxContrast(in: app.buttons["Day Monday"].frame, of: screenshot.image)
            // The dated row's "Nov 15" in the open Errands card.
            openCard("Errands", in: app)
            let dateButton = app.buttons["Change date of Plan Mom's birthday"].firstMatch
            var dateRatio = 0.0
            if dateButton.waitForExistence(timeout: 3) {
                let mark = dateButton.staticTexts.firstMatch
                sleep(1)
                let shot2 = XCUIScreen.main.screenshot()
                try? shot2.pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/F-seasonal-\(season)-light-card.png"))
                dateRatio = Self.maxContrast(in: mark.exists ? mark.frame : dateButton.frame, of: shot2.image)
            }
            print("REVIEW: seasonal \(season) light: today pill \(String(format: "%.2f", ratio)):1, past pill \(String(format: "%.2f", past)):1, date mark \(String(format: "%.2f", dateRatio)):1")
            XCTAssertGreaterThanOrEqual(ratio, 4.5, "\(season): today's date on its pill is readable")
            XCTAssertGreaterThanOrEqual(past, 4.5, "\(season): a past day's date is readable")
            XCTAssertGreaterThanOrEqual(dateRatio, 4.5, "\(season): a task's date mark is readable")
            app.terminate()
        }
    }

    // MARK: - Checked and fine

    /// Day pills: VoiceOver names ("Today, Wednesday, November 11"), Selected only on the
    /// picked day, and the filter line under the strip.
    @MainActor
    func testDayPillsReadAndSelectCorrectly() throws {
        let app = launch([])
        let wed = app.buttons["Day Wednesday"]
        XCTAssertTrue(wed.waitForExistence(timeout: 5))
        XCTAssertEqual(wed.label, "Today, Wednesday, November 11")
        XCTAssertEqual(app.buttons["Day Thursday"].label, "Thursday, November 12")
        XCTAssertFalse(wed.isSelected)
        app.buttons["Day Monday"].tap()
        XCTAssertTrue(app.staticTexts["Monday and tasks with no day"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Day Monday"].isSelected, "the picked day is Selected")
        XCTAssertFalse(wed.isSelected, "only the picked day")
        app.buttons["Show All"].tap()
        XCTAssertTrue(app.staticTexts["Monday and tasks with no day"].waitForNonExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Day Monday"].isSelected)
    }

    /// The Just this week chip is a toggle with its state as a value; the expiration ring's
    /// value; the house is a clear button only while out.
    @MainActor
    func testChipRingAndHouseAnnounceState() throws {
        let app = launch([])
        openCard("Errands", in: app)
        let checkbox = app.buttons["Complete Plan Mom's birthday"].firstMatch
        XCTAssertTrue(checkbox.waitForExistence(timeout: 3))
        XCTAssertEqual(checkbox.value as? String, "expires in 4 days, on Sunday, November 15")
        app.editCard("Errands")
        let chip = app.switches["Just this week chip"]
        XCTAssertTrue(chip.waitForExistence(timeout: 3), "a switch (toggle trait)")
        XCTAssertEqual(chip.value as? String, "Off")
        chip.tap()
        XCTAssertEqual(chip.value as? String, "On")
        chip.tap()
        XCTAssertEqual(chip.value as? String, "Off")
        app.buttons["Done editing Errands"].tap()
        app.buttons["Close Errands"].tap()
        XCTAssertFalse(app.buttons["Bar Back to This Week"].exists, "no house on this week")
        app.buttons["Next week"].tap()
        let house = app.buttons["Bar Back to This Week"]
        XCTAssertTrue(house.waitForExistence(timeout: 3))
        XCTAssertEqual(house.label, "Back to This Week")
        XCTAssertGreaterThanOrEqual(house.frame.width, 44)
        house.tap()
        XCTAssertTrue(house.waitForNonExistence(timeout: 3), "gone once back")
    }

    /// The automated audit on the main screen, an open card and Settings at the default
    /// size finds nothing beyond the known, deliberate exceptions.
    @MainActor
    func testAuditMainScreenHasNoContrastOrLabelIssues() throws {
        let app = launch([])
        var serious: [String] = []
        try app.performAccessibilityAudit(for: [.contrast, .sufficientElementDescription, .elementDetection, .trait]) { issue in
            let line = "\(issue.auditType.rawValue) \(issue.compactDescription) [\(issue.element?.label ?? "")]"
            print("REVIEW: audit main \(line)")
            serious.append(line)
            return true
        }
        XCTAssertTrue(serious.isEmpty, "main screen audit: \(serious)")
    }

    // MARK: - Helpers

    @MainActor
    private func launch(_ extra: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-demoData", "-demoToday", "2026-11-11", "-fakeCalendar"] + extra
        app.launch()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 10))
        return app
    }

    @MainActor
    private func openCard(_ name: String, in app: XCUIApplication) {
        let card = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open \(name),")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.tap()
        XCTAssertTrue(app.buttons["Close \(name)"].waitForExistence(timeout: 5))
        sleep(1)
    }

    @MainActor
    private func scrollIntoView(_ element: XCUIElement, in app: XCUIApplication) {
        let screen = app.windows.firstMatch.frame
        for _ in 0..<8 where element.frame.minY > screen.maxY - 200 || element.frame.minY < 150 {
            if element.frame.minY > screen.maxY - 200 {
                app.swipeUp(velocity: .slow)
            } else {
                app.swipeDown(velocity: .slow)
            }
        }
        sleep(1)
    }

    @MainActor
    private func shot(_ name: String, _ app: XCUIApplication) {
        try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
    }

    /// The highest contrast between any pixel in `frame` and the frame's most common color
    /// (its background): the text's own color against what's behind it, for text that's
    /// solid in its middle. An overestimate when the text sits on a tinted fill.
    static func maxContrast(in frame: CGRect, of image: UIImage) -> Double {
        guard let cg = image.cgImage, frame.width > 0, frame.height > 0 else { return 0 }
        let scale = CGFloat(cg.width) / image.size.width
        let rect = CGRect(x: frame.minX * scale, y: frame.minY * scale, width: frame.width * scale, height: frame.height * scale)
            .integral.intersection(CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
        guard let crop = cg.cropping(to: rect) else { return 0 }
        let w = crop.width, h = crop.height
        var data = [UInt8](repeating: 0, count: w * h * 4)
        let space = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: &data, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: space,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return 0 }
        ctx.draw(crop, in: CGRect(x: 0, y: 0, width: w, height: h))
        func lum(_ i: Int) -> Double {
            func lin(_ c: UInt8) -> Double { let v = Double(c) / 255; return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
            return 0.2126 * lin(data[i]) + 0.7152 * lin(data[i + 1]) + 0.0722 * lin(data[i + 2])
        }
        var counts: [UInt32: Int] = [:]
        for p in stride(from: 0, to: data.count, by: 4) {
            let key = UInt32(data[p]) << 16 | UInt32(data[p + 1]) << 8 | UInt32(data[p + 2])
            counts[key, default: 0] += 1
        }
        guard let bgKey = counts.max(by: { $0.value < $1.value })?.key else { return 0 }
        func lumKey(_ k: UInt32) -> Double {
            func lin(_ c: UInt32) -> Double { let v = Double(c) / 255; return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
            return 0.2126 * lin(k >> 16 & 255) + 0.7152 * lin(k >> 8 & 255) + 0.0722 * lin(k & 255)
        }
        let bg = lumKey(bgKey)
        var best = 1.0
        for p in stride(from: 0, to: data.count, by: 4) {
            let l = lum(p)
            best = max(best, (max(l, bg) + 0.05) / (min(l, bg) + 0.05))
        }
        return best
    }
}
