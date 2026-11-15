## Accessibility review: Tasquel 1.1 (iPhone 17 sim, iOS 26.3)

Shots folder (SH): the work root's `Access/shots` (the cited ones are copied, shrunk, to `evidence/Access/`). Copy (CP): the work root's `Access/project`. Every finding below was reproduced at least twice. I never opened the Simulator app.

### 1. Findings, most severe first

**F1. At accessibility text sizes, a task with a date breaks its name a few letters per line.** Severity: **Major** (close to an accessibility blocker).
- Setup: `-demoData -demoToday 2026-11-11`, AccessibilityXXXL.
- Steps: open Errands and scroll to "Plan Mom's birthday".
- Expected: the name uses the row's width, and the "📅 Nov 15" mark goes under it.
- Actual: the name gets a 62pt column and reads "Pl / an / M / o / m' / s / bir / th / day". The row is 620pt tall. At XXXL it wraps cleanly.
- Evidence: `F-dated-name-ax5.png`. `testDatedTaskNameKeepsItsWidthAtLargestText` reports frame w=62.7 h=620.7 (same in two runs).
- Cause: CP `Tasquel/TaskRowCard.swift:348-359`. The name and `markButton` sit in an HStack, and the mark is `.fixedSize()` (:616). `stacksIcons` (:750-762) moves only the icons to their own line, never the mark. The day marks ("Today", "Fri · late") will hit the same problem.
- Fix: when the row's width minus the mark is less than the widest word (and always at accessibility sizes), put the mark on its own line under the name.

**F2. In card edit mode at accessibility sizes, the "Just this week" chip runs off the card and the Completed line disappears.** Severity: **Major**.
- Steps: AccessibilityXXXL, open Errands, tap Edit Errands.
- Actual: the chip ends at x=412.6 on a 402pt screen, so its text is cut off at the edge. "1 of 4 complete" is squeezed to 0.3pt wide. The name field shows "Err…" (the audit reports "Text clipped").
- Evidence: `F-chip-ax5.png`, `ax5-06-card-edit.png`, `testJustThisWeekChipFitsCardAtLargestText`.
- Cause: CP `Tasquel/CategoryCard.swift:78-92`. The Completed line (`lineLimit(1)`) shares an HStack with a chip that is `.fixedSize()` (:314).
- Fix: at accessibility sizes, put the chip on its own line under Completed (a VStack or `ViewThatFits`), and let it wrap.

**F3. Add Category at accessibility sizes breaks words in the middle.** Severity: **Major**. This is new in 1.1: Edit beside the heading, and the "Added" / green + rows.
- Steps: AccessibilityXXXL, Edit, then Add Category.
- Actual: the heading reads "Saved / Cate- / gories" (187pt tall; one header line is 80pt). Rows read "Er- / rands" and "Wo / rk", next to "Added".
- Evidence: `F-saved-heading-ax5.png`, `ax5-08-add-category.png`, `testSavedCategoriesHeadingDoesNotBreakMidWordAtLargestText` (failed in two runs).
- Cause: CP `Tasquel/AddCategorySheet.swift:163-173` (heading, Spacer, Edit in one HStack) and :210-223 (row Label, Spacer, "Added" / +).
- Fix: at accessibility sizes, put Edit under the heading and the row's status under the name, or use `ViewThatFits`.

**F4. Small coloured text is below 4.5:1 contrast, worst in Seasonal light.** Severity: **Minor**.
- How measured: pixels from the screenshots (`testSeasonalTodayPillTextContrast`), checked against ratios computed from the palette.
- Today's date on its pill: spring 3.08, summer 3.30, fall 4.00, winter 3.88.
- The dated row's "Nov 15" (and the "Today" mark, same colour): spring 3.45, summer 3.83, fall 4.40, winter 4.45.
- Past-day dates: spring 4.42, summer 4.11.
- The late / duplicate orange (#C75E00) is 4.18:1 on white and 3.96:1 on Fall's card.
- In Spring, past days and today are both green, which undoes the 2026-11-15 swap meant to stop green past days reading as "done".
- Evidence: `F-seasonal-{spring,summer,fall,winter}-light.png` (and `…-light-card.png` in SH).
- Cause: `Theme.expirySet` returns `season.done` (CP `Tasquel/Theme.swift:126`). It is used as text at `WeekDayStrip.swift:111` and `TaskRowCard.swift:846,867`, but `done` is only tested for 3:1, as an icon colour (`TasquelTests.swift:2463`). `pastDayDate` uses the season's accent (Theme.swift:142). `strongOrange` is at Theme.swift:112.
- Fix: add a darker per-season text green and past-day colour, deepen the light orange to reach 4.5:1, and test all of them at 4.5:1 against both the card and the header.

**F5. The "What's New?" pill text stays 9pt at every text size.** Severity: **Minor**.
- Evidence: the pill is 73.3pt wide at both the default size and AccessibilityXXXL. `F-whatsnew-default.png`, `F-whatsnew-ax5.png`, `testWhatsNewPillGrowsWithTextSize` (failed in two runs).
- Cause: CP `Tasquel/ContentView.swift:853`, `.font(.system(size: 9…))`.
- Fix: make the size a `@ScaledMetric(relativeTo: .caption2)`, capped at about xxxLarge.

**F6. Day-pill tap areas are 32pt wide, not 44pt.** Severity: **Minor**.
- Evidence: every pill except today's is 32×44 (today's is 37.8 wide), with dead 8pt gaps between them. Seven 44pt targets would fit. `testDayPillTapTargetsAre44ptWide`.
- Cause: CP `Tasquel/WeekDayStrip.swift:42`, `touchTarget(width: width + 8, …)`.
- Related: the audit also flags "Show All" (47×14pt). Its `.touchTarget()` (:68) is outside the Button's label, which this same file's comment says takes no taps. I didn't confirm that with a tap.

**F7. In the type/mode popup at AccessibilityXXXL, the icons spill over their rows' borders and touch the words.** Severity: **Polish**.
- Evidence: `crop-options.png`.
- Cause: CP `Tasquel/TaskOptionsPicker.swift:368`, a fixed `.frame(width: 22)` around a scaled symbol. Use a `@ScaledMetric` width.

### 2. Checked and fine
- **Day pills:** read as "Today, Wednesday, November 11" and "Thursday, November 12". "Selected" appears only on the picked pill. The filter line shows, and Show All clears it.
- **Just this week chip:** it's a switch, and its value reads Off / On correctly.
- **Expiration ring:** the checkbox value is "expires in 4 days, on Sunday, November 15".
- **Bar house:** there's no element on this week. Out, it's "Back to This Week" at 45pt, and it's gone after the tap.
- **Main screen audit at default size** (contrast, labels, traits, element detection): clean.
- **Help tab pills:** named as they're shown ("Q&A", "Weeks"…), 44pt tall, "Selected" on the current one.
- **Popup Day row:** full day names and "Any day", with TYPE / AFTER THIS WEEK / DAY marked as headings. At accessibility sizes it's one column and scrolls.
- **Reduce Motion (code review only):** the pulse (TaskRowCard:823), wiggle (ContentView:434) and turkey (:815) are all off. The What's New pill (:845), the house (:1279/1315) and the moved pop-up only fade.
- **Dated name at XXXL:** wraps cleanly.
- **Seasonal dark:** all the colours above are at least 5.8:1 (computed).
- **System light green** #1F8533: 4.71:1.
- **Past-day blue:** #0060DF on its fill is 4.67:1, and 5.05 in Dark.
- **What's New pill colours:** white on #0060DF is 5.6:1.
- **Audit noise I didn't count:** "partially unsupported Dynamic Type" comes from deliberate caps. "Contrast failed" on the glass sheets and popovers is the translucent background. Subtask names being 19pt tall is pre-existing.

### 3. Test files (in `tests/Access/`)
- `ReviewAccessFindingsUITests.swift`
  - F1: `testDatedTaskNameKeepsItsWidthAtLargestText`
  - F2: `testJustThisWeekChipFitsCardAtLargestText`
  - F3: `testSavedCategoriesHeadingDoesNotBreakMidWordAtLargestText`
  - F4: `testSeasonalTodayPillTextContrast` (measures contrast from screenshot pixels)
  - F5: `testWhatsNewPillGrowsWithTextSize`
  - F6: `testDayPillTapTargetsAre44ptWide`
  - Fine (passing): `testDayPillsReadAndSelectCorrectly`, `testChipRingAndHouseAnnounceState`, `testAuditMainScreenHasNoContrastOrLabelIssues`, `testDatedTaskNameKeepsItsWidthAtXXXL`
- `ReviewAccessExploreUITests.swift`: walks every screen (default, AccessibilityXXXL, XXXL) and saves screenshots, accessibility trees and audit output (`SH/{def,ax5}-NN-*.{png,tree.txt,audit.txt}`). It's exploratory and asserts nothing.
  - Its default-size run failed only because the off-screen "Dates" Help tab needed a scroll first. That's a problem in the test, not the app.
- Logs (SH): `run-findings2.log`, `run-findings3.log`, `run-explore.log`.

### 4. Couldn't check in a simulator (phone checklist)
- With VoiceOver on, add a task for a day that has gone by. Do you hear both "Week of Nov 16" and the "had already gone by" note, or does one cut the other off? Can you reach the pop-up's OK before it closes itself at 6 s? (It has no VoiceOver exception, unlike the Undo messages: ContentView.swift:1763.)
- With VoiceOver, in Help ▸ Q&A ▸ "Where do finished tasks go?": does its checkmark icon announce "Selected"? (The tree shows a `checkmark.circle` image with the Selected trait.)
- With Voice Control, say "Tap Edit" in Add Category. Its label is "Edit Saved Categories": does it work?
- Turn on Increase Contrast, Reduce Transparency, Bold Text and Button Shapes. Are the header glass, What's New pill, day pills and house still readable, and do the plain buttons show shapes? The app reads none of these settings itself.
- With Reduce Motion on, open the app in Thanksgiving week and on a day with tasks: no wiggle, pulse or turkey, and do the house and What's New pill only fade?
- At AccessibilityXXXL, check the moved pop-up and the goal editor's Unit row and "Already 8 of 7" warning. I ran out of time for these.
