# Tasquel 1.1 review: 2026-11-15

Seven reviewers in simulators (iOS 26.3), on `release-1.1` at 1be5fdc (the project still says 1.0.3 (11)):
- **Everyday flows:** iPhone 17 Pro.
- **Settings and themes:** iPhone 17 Pro Max.
- **iPad:** iPad Pro 13-inch (M5) and 11-inch (M5).
- **Accessibility:** iPhone 17.
- **Edge cases and small screens:** iPhone SE (3rd generation).
- **Code review:** reading the code, plus unit tests on an iPhone 17 Pro.
- **Update from the live 1.0.3 (11):** iPhone 17 Pro, plus a data-level check on macOS.

Today was Sunday, Nov 15: the last day of a Monday-start week, so most weekdays had gone by.

## Status
- **26 findings after merging duplicates:** 2 rejection risk, 6 major, 10 minor, 8 polish. Most are new in 1.1, in its date, day and layout work; finding 9 is older. (27 and 28, from the baseline, turned out to be test artifacts: see below.)
- **How they were checked:**
  - Re-run by me: findings 1 (three of the code reviewer's unit tests fail as reported), 2, 6 and 10 (the Everyday reviewer's UI tests fail as reported) and 25 (the leap-day unit test).
  - Confirmed from the screenshots and the code: every other Rejection-risk, Major and Minor finding.
  - Polish findings: from screenshots and code.
  - Not reproduced or test artifacts: 5 (listed below).
- **Tests before the review, on 1be5fdc:** 279 unit tests passed; 97 UI tests, 0 failures (2 skipped: iPad-only rotation and the screenshot script).
- **Update from 1.0.3: no data lost.** 1.0.3's files load in 1.1 with no old value changed, at the data level (both week starts, rolled forward 1, 2 and 3 weeks) and through a real install over 1.0.3. The What's New pill shows for updaters, twice, and never on a fresh install. Two small update findings: 17 and 21.
- **Baseline: the 2026-11-10 review's tests, re-run on 1.1.** Its 19 unit tests pass (298 unit tests in all). Of its 74 iPhone UI tests, 46 pass and 28 fail:
  - **1 issue came back (1 test):** a dated row's name squeezed at the largest text size (now finding 3).
  - **1 is as designed:** a fold set on next week's copy (one fold per list, decided 2026-11-10).
  - **27 are test artifacts:** 3 rename tests (27 and 28 below) never passed on 1.0.3 either, as the Nov 10 review had recorded (a helper built 1.0.3 to check);  8 look for the old "This week only" switch (now a chip); 5 were already out of date on Nov 10; 3 tapped the trash before 1.1's edit icons ran out (they pass with a 0.6 s wait, so delete and Undo work); 4 meet changed screens (Help in tabs, version 1.0.2, Sort Cards, the reorder handle's place); 3 depend on a date, iOS's own Settings, or a missing helper script.
  - The 22 iPad tests weren't re-run (time and load).
  - Nov 10's open items still open: 8 (app icon), 11 and 21 (iPad, not re-run), 13 (as designed).
- **The Mac was overloaded again:** a load average of 150–570 for the first hour, with four simulators and builds at once in wave 1. Reviewers lost runs to launch errors and re-ran them. Quitting the Simulator app, to stop its windows popping up, shut down two reviewers' simulators mid-run; both re-ran.

## Fixed (2026-11-15, after the review)
You picked 1–8, plus 27 and 28 (which turned out to be test artifacts, so nothing to fix).
- **1, week-start switch:** after the shift, a one-time task in a current or later week keeps its real date (its date, or the day it was for in its old week); where that's no longer in its week it goes into the week that holds it, into the card of the same name (`ChecklistStore.keepDatesAfterWeekShift`). Dates gone by stay as they are; carry-over and repeating copies aren't moved; with no card of that name there, the task stays without a date that would expire it; the move isn't counted as a card edit. Tests: the code reviewer's `ReviewCodeDateTests.swift`, now in `TasquelTests/` (the leap-day test disabled: 25 isn't fixed).
- **2, keyboard left behind:** the popup's Add Task adds once the popup has closed, and a task that goes into another week ends the field's focus before the screen follows it (also Smart Add's path). Test: `ReviewFixesUITests.testPopupAddToAnotherWeekPutsTheKeyboardAway`.
- **3, marks squeezing names:** a day or date mark sits beside the name only when the whole name and the mark fit on one line, under it otherwise and at accessibility sizes (`stacksMark`); `stacksIcons` no longer counts the mark. Test: `testDatedNameKeepsItsWidthAtLargestText`.
- **4, the chip:** under the Completed line at accessibility sizes, and may wrap. Test: `testJustThisWeekChipFitsAtLargestText`.
- **5, Add Category at accessibility sizes:** Edit under the heading, Added / + under the name. Test: `testAddCategoryHeadingKeepsWholeWordsAtLargestText`.
- **6, Add Category's Done:** with a name typed it adds and closes. Test: `testAddCategoryDoneWithANameTypedAddsAndCloses`.
- **7, Seasonal Settings in dark:** the list is rebuilt when light or dark changes. Test: `testSeasonalSettingsRowsFollowTheDarkSwitch`.
- **8, iPad lanes** (a helper, in a copy): a card opens in the lane it was sitting in while closed and keeps it while open; the first card opened takes the shorter lane (`CategoryGridLayout`'s cache, by category ID). **A rule change to confirm:** the brief's "only a newly opened card picks the shorter lane" still moved Work, since Errands opens on a tie. Tests: three `laneFrames` unit tests.
- **27 and 28:** no change to the app; the old tests are corrected (`tests/Baseline/ReviewRegressionTests.swift`).
- Spec (CLAUDE.md) updated for 1, 2, 3, 4, 5, 6, 7 and 8.
- Also in the same uncommitted work: the turkey and feathered mark only in the US, its territories and Canada; the seasonal screenshots (`-demoDaysAndPins`, `scripts/app-store-screenshots.sh … seasonal`).

**Second batch (while you were out, 2026-11-15 evening), the findings that needed no decision, then your answers:**
- **9, the trip west:** a week that's in the future again follows the week before again, and gets its final sync once more when it's current (`syncSavedWeek`). Your go. Test: `flyingBackWestKeepsNextWeekFollowing` (unit).
- **10:** a moved task's note and its Undo last 14 s (the pop-up's 6 plus their own 8).
- **11:** a list's Add Item field scrolls back into view after each add.
- **12, calendars:** every date shown is Gregorian, in the phone's language (`Locale.gregorian`); my default, since you had no preference.
- **14:** the What's New pill's words grow with the text size, up to 13pt.
- **16:** the Reminders footer is checked again whenever the app comes back, with Open Settings under the switch; coming back, the app also schedules reminders again (`ExpiryNotifications.recheck`), so turning notifications on in iOS Settings takes effect without a relaunch.
- **17, turkey first:** in Thanksgiving week the turkey runs first each time the app opens, then the What's New pill slides out. Your call.
- **18:** a new number of columns (rotating or resizing an iPad) lays out the open cards again.
- **19:** "the week of Nov 6, 2028" when it isn't this year.
- **20:** "Tomorrow is in next week" instead of "Monday had already gone by".
- **21:** "Settings ▸ Help ▸ What's New".
- **22:** Settings, Help and Add Category take the season's color in Seasonal.
- **23:** the popup's icon column grows with the text.
- **24:** the bottom bar ignores the keyboard's safe area, so it stays down behind a sheet's keyboard.
- **25:** an undated "2/29" is the next Feb 29 (the code reviewer's test re-enabled).
- **Lane rule (8):** you confirmed it.
- **13, contrast (you approved the proposals, https://claude.ai/artifact/B5Wfrvm6adc9PmnQzvC8i6):** in Seasonal light, small text in the done green (today's date, "Today", date marks) uses each season's deeper `doneText`, and past days' dates its `pastDay` (Spring's a plum, no longer green like today); the late and Duplicate orange is #B05300 in every light look. `SeasonTests` checks them at 4.5:1 on the card and the header. Seasonal screenshots 08–11 re-taken.
- **15, day pill taps:** the day filter is off in 1.1 (your call: it wasn't clear what a tap did), so the pills only show the days and take no taps; 1.2's plan makes the whole strip one button. What's New, Help and the submission notes no longer mention it. 26 is in the web copy.

**Regression reviewer (after the first batch), six findings, five caused by the fixes, all fixed:**
- Fix 1: a Just this week card's dated or day task was left behind by a week-start switch. Now the card stops being just this week, the later week gets it back, and the task moves there. A moved task now arrives unpinned (it could make a third pin).
- Fix 8: lanes swapped after paging two weeks away and back, or after Edit. Open cards' lanes are now kept by card name for every page (`CategoryLaneMemory`), forgotten when a card is closed, on Close All, or when the columns change.
- Fix 7: Settings jumped to the top when the phone switched light/dark. Now only Seasonal rebuilds the list (its rows' fill is the only one that differs between light and dark; nothing less redrew them), so every other look keeps its place. **A trade-off to know:** in Seasonal, Settings goes back to the top when the phone switches light/dark while it's open.
- Fix 3: the mark's placement now counts the name's "⧉ Duplicate" and pin.
- Older polish: the Completed line wraps at accessibility sizes in a card's edit mode. Settings ▸ Saved Categories' name field still cuts long names at the largest size (left as polish).
- Its tests: `tests/Regression/` (its two unit tests are now in `TasquelTests/`).

**Regression check (after both batches and the regression fixes):**
- **Unit tests:** 312 of 312 pass, including the code reviewer's date tests (now in `TasquelTests/ReviewCodeDateTests.swift`, leap day re-enabled), the trip-west test, the regression reviewer's week-shift tests and three lane tests.
- **Full UI suite on the final code:** 104 tests, 3 skipped, 97 passed, 4 failed. Two expected the old wording ("Monday had already gone by" on a Sunday, and "Settings ▸ What's New"): updated, both pass. A Smart Add date test failed once and passed on re-run. My Seasonal Settings test showed the rows' color fix (replacing the list rebuild, which lost the scroll position) didn't redraw the rows; Seasonal now rebuilds the list on a light/dark change and every other look keeps its place. That test, the regression reviewer's Settings-keeps-its-place test and the Settings UI tests all pass.
- **Every reviewer's tests on a fresh copy of the final code:** Edge 21 of 21 and iPad 16 of 16 pass (rotation, the bar behind Add Category, the trip west, tomorrow, the year, the calendar region, the 100-line paste). iPhone: 34 of 42 pass; the 8 failures are 13 and 15 (yours to decide), Add Category's Done with a taken name (as designed), the Undo test's position check (10 was fixed by timing: its own later check, Undo still there after the pop-up, passes), the week-start test's logging line after it found both tasks where they belong (a test artifact), and three Seasonal dark-mode tests whose simulator never went dark (their screenshots are light even in System appearance: test artifacts; 7 is covered by `ReviewFixesUITests` and the regression reviewer's Settings test, both passing in dark).
- **The regression reviewer's tests on the final code:** 16 of 17 iPhone and 9 of 9 iPad pass (lanes after paging and after Edit, Settings keeping its place in dark, the mark with a duplicate). The one failure is Saved Categories' name field at the largest size, left as polish.
- **Update check:** not re-run; no fix changes how data is saved or loaded (the week-start fix changes which week a task sits in after a switch).
- **On your phone:** not installed yet (the phone was away); see "Try on your phone".

## Fix together
- **1 and 9** both decide where a saved week's tasks belong after the week moves under them (a week-start switch, or a time-zone change). Both touch `ChecklistStore` week placement and `didFinalSync`.
- **3, 4 and 5** are the same pattern at large text sizes: something `.fixedSize()` sharing a line with words that then get no room. One rule (move it to its own line when the words wouldn't fit) covers all three; 3 also fixes the SE squeeze.
- **2 and the known iPad issue** (typing then tapping the type/mode button adds the words) are both about the Add Task field's focus when the options popup opens or closes.
- **10 and 20** are both about the "Added to next week" pop-up and its note.

## Findings

### Rejection risk

1. **Changing Settings ▸ Week deletes dated tasks in later weeks, and moves next week's day tasks a week late.** New in 1.1. Found by Code, Everyday and Settings.
   - Steps: on a Sunday with weeks starting Monday, give a One-Time task the date Thu Nov 19 (it moves into next week), then switch to Sunday starts.
   - Expected: it's in the week that holds Nov 19. Saw: it's gone from every week, also after switching back and after a relaunch, and its reminder is cancelled. A task given Thursday goes to Nov 26 instead of Nov 19. On a weekday, switching the other way loses a task dated next Sunday.
   - Evidence: `evidence/Settings/weekstart.png`, `evidence/Everyday/finding-ws-03-next-week-after-switch.png`; unit tests `ReviewCodeWeekStartSwitchTests` (3 fail; I re-ran them).
   - Cause: `ChecklistStore.swift:568-591` (`setWeekStartsOnSunday`) shifts every saved week's start by the same days (+6 on a Sunday) but not the tasks' `expiresOn` or `dayOfWeek`; `removeExpiredTasks` (`:1054-1064`) then deletes a task whose date is now before its week.
   - Suggested fix: before the shift, note each task's real date (its date, or its week's start plus its day); after it, put any task outside its week into the week holding that date (`moveToItsDatesWeek`'s logic). Never let the shift itself expire a task.
   - Also affects: reminders (worked out from the weeks), Go to Week's marks, sync of later weeks (carried copies' links), pins in later weeks, Just this week cards (no next week to move into). The spec lists "week-start switches with dated tasks" for 1.2; deleting the task is what makes it worth fixing now.
   - Shares code with: 9.

2. **Adding a task from the options popup when it goes to another week leaves a keyboard that can't be put away, and the bottom bar disappears.** New in 1.1. Found by Everyday.
   - Steps: type "Return library books" in Add Task, tap the type/mode button, pick a day already gone by (or a date next week), then the popup's Add Task.
   - Expected: next week, no keyboard (as with Return). Saw: the keyboard stays up with no field focused; the bar is gone; the keyboard-down button does nothing; only opening another Add Task field and closing it gets out.
   - Evidence: `evidence/Everyday/finding-kb-01-popup-add-next-week.png`, `finding-kb-02b-after-keyboard-down.png`; `ReviewEverydayFindingsTests.testPopupAddToNextWeekLeavesNoKeyboard`. I re-ran it: it fails the same way, and the bar's Previous week button is gone.
   - Cause: the popup's `onAdd` (`TaskRowCard.swift:2630-2633`) closes the popover while the field still has focus; `addTask` (`:3057`) only skips re-focusing it, and the screen pages away, leaving the keyboard on a field that's gone.
   - Suggested fix: when the task goes to another week, set `isFocused = false` before `showOptions = false` (or have `addedElsewhereFollower` wait for the popover to close, then dismiss the keyboard).
   - Also affects: Smart Add and Return adds that go to next week (fine today), the popup's Add Task for this week (keeps typing, by design).
   - Shares code with: the known iPad issue.

### Major

3. **A day or date mark beside a task's name squeezes the name: at the largest text sizes to a few letters per line, on an SE to a narrow column.** New in 1.1. Found by Accessibility and Edge.
   - At AccessibilityXXXL "Plan Mom's birthday" reads "Pl / an / M / o / m's / bir / th / day" (a 62pt column, 620pt tall). On an SE at the default size a nine-word name beside "Sun · late" takes 7 lines in a ~70pt column.
   - Evidence: `evidence/Access/F-dated-name-ax5.png`, `evidence/Edge/keep-edge-late-long-names-SE.png`; `testDatedTaskNameKeepsItsWidthAtLargestText`, `testLateMarkAndLongNamesOnSE`.
   - Cause: `TaskRowCard.swift:348-359` puts the `.fixedSize()` mark (`:616`) beside the whole name; `stacksIcons` (`:750-762`) moves only the icons.
   - Suggested fix: put the mark on its own line under the name when the column beside it would be narrower than the widest word, and always at accessibility sizes.
   - Also affects: every day and date mark in open cards ("Today", "Fri · late", "Nov 28"); `markWidth` in `stacksIcons`. Closed cards and edit mode don't show these marks.

4. **In a card's edit mode at the largest text sizes, the Just this week chip runs off the card and the Completed line disappears.** New in 1.1. Found by Accessibility.
   - Evidence: `evidence/Access/F-chip-ax5.png`; `testJustThisWeekChipFitsCardAtLargestText`.
   - Cause: `CategoryCard.swift:78-92`, the one-line Completed text beside a `.fixedSize()` chip (`:314`).
   - Suggested fix: at accessibility sizes, the chip on its own line under Completed.
   - Also affects: the chip's place outside accessibility sizes (chosen so nothing moves as editing starts).

5. **Add Category at the largest text sizes breaks words mid-word: "Saved / Cate- / gories", "Er- / rands".** New in 1.1 (Edit beside the heading, Added / + beside names). Found by Accessibility.
   - Evidence: `evidence/Access/F-saved-heading-ax5.png`; `testSavedCategoriesHeadingDoesNotBreakMidWordAtLargestText`.
   - Cause: `AddCategorySheet.swift:163-173` (heading, Spacer, Edit) and `:210-223` (name, Spacer, Added / +).
   - Suggested fix: at accessibility sizes, Edit under the heading and the status under the name (`ViewThatFits`).
   - Also affects: Settings ▸ Saved Categories, which shares `SavedCategoryRow`.

6. **Add Category: tapping Done (✓) with a name typed adds it but leaves the sheet open.** New in 1.1 (the sheet now stays open after an add). Found by Everyday.
   - Expected: added, and the sheet closes. Saw: "Added Garden · add another, or tap Done", right after the user tapped Done.
   - Evidence: `evidence/Everyday/finding-cat-01-done-with-typed-name.png`; `testAddCategoryDoneWithTypedNameCloses`. I re-ran it: the sheet stays open.
   - Cause: `finish()` (`AddCategorySheet.swift:193-199`) calls `createNew()`, which now keeps the sheet open.
   - Suggested fix: dismiss after a successful `createNew()` from Done.
   - Also affects: Edit ending when the sheet closes after an add (`addedCategoryInSheet`).

7. **Seasonal: Settings becomes unreadable when the phone switches to Dark while it's open.** New in 1.1. Found by Settings.
   - Steps: pick Seasonal in Settings, then switch the phone to Dark with Settings still open. The rows stay cream under white words; reopening Settings fixes it. If Seasonal was chosen before Settings opened, it's fine.
   - Evidence: `evidence/Settings/seasonalpicked.png`; `testSeasonalPickedInOpenSettingsFollowsDarkSwitch`.
   - Cause: the rows' `.listRowBackground(darkCardBg)` (`SettingsSheet.swift:91`, `:105-183`) keeps the light value while `.preferredColorScheme` (`:86`) turns the sheet dark.
   - Suggested fix: pick the row color from the sheet's own `colorScheme`, or `.id(effectiveScheme)` on the List.
   - Also affects: Help (`darkHelpBg`), same pattern.

8. **iPad landscape: an open card jumps to the other lane when another card opens or closes.** New in 1.1. Found by iPad.
   - Steps: open Work (left half), then Errands: Errands takes the left lane and Work jumps right; close Errands and Work jumps back.
   - Evidence: `evidence/IPad/lanes-01-work-open.png`, `lanes-02-errands-open.png`, `lanes-03-errands-closed.png`; `testOpeningAnotherCardKeepsOpenCardInItsLane`.
   - Cause: `CategoryGridLayout.swift:165-176` re-deals every open card into the shorter lane on each layout pass.
   - Suggested fix: keep each open card's lane once placed (a lane per `CategoryLayoutKey`, passed as a `LayoutValueKey`); only a newly opened card picks the shorter lane.
   - Also affects: the half-width rule in the spec ("an opened card keeps its place"), closed cards' packing, finding 18. A design call on what "keeps its place" means.
   - Shares code with: 18.

### Minor

9. **After a trip back west across the week boundary, next week stops following this week.** Older than 1.1. Found by Edge.
   - Steps: Sunday in New York, add a carry-over task; open the app in Tokyo (already Monday); back in New York, check it off. Next week still has it, unchecked.
   - Evidence: `evidence/Edge/tokyo-edge-travel-west-2-nextweek.png`; `testFlyingBackFromTokyoKeepsNextWeekFollowingThisWeek`.
   - Cause: `ensureWeekExists` (`ChecklistStore.swift:712`) marks a week built while current `didFinalSync`; back west it's a future week that sync treats as the user's own (`:922`).
   - Suggested fix: a future week with `didFinalSync` that no week-start change moved there gets the flag cleared.
   - Shares code with: 1.

10. **The "Added to next week" pop-up covers the card's note and its Undo for 6 of the Undo's 8 seconds.** New in 1.1. Found by Everyday.
    - Evidence: `evidence/Everyday/finding-undo-01-popup-over-note.png`; `testUndoOutlastsTheMovedPopUp`. I re-ran it: the pop-up covers the Undo.
    - Cause: the pop-up (`ContentView.swift:1753-1768`, 6 s) and the note (`TaskRowCard.swift:2458-2476`, 8 s) start together, in the same place.
    - Suggested fix: start the note's 8 s when the pop-up closes, or give the pop-up an Undo for adds.
    - Shares code with: 20.

11. **Pasting many lines into a list leaves the field being typed in far below the screen.** Found by Edge.
    - Cause: `submitTypedSubtask` / `addSubtask` (`TaskRowCard.swift:1500-1534`) never scroll; Add Task does (`keepFieldInView`).
    - Suggested fix: scroll the item field into view after an add, as Add Task does.

12. **With a Saudi Arabia region, the week title uses the Islamic calendar and the day pills the Gregorian one.** Found by Edge.
    - Cause: `displayTitle` (`Models.swift:672`) and `ExpiryPicker` use `Calendar.current`; the day strip shows Gregorian `DayKey` days.
    - Suggested fix: one calendar for every date shown (likely Gregorian, as the weeks are).

13. **Small colored text is under 4.5:1 in Seasonal light:** today's pill date (spring 3.08), the green "Today" / date marks (spring 3.45), past-day dates (summer 4.11), the late/duplicate orange (4.18 on white). In Spring, past days and today are both green. Found by Accessibility.
    - Cause: `Theme.expirySet` gives `season.done`, tested only at 3:1 as an icon color (`Theme.swift:126`; `TasquelTests.swift:2463`).
    - Suggested fix: per-season text colors tested at 4.5:1 on the card and the header.

14. **The What's New pill's words stay 9pt at every text size.** Found by Accessibility. `ContentView.swift:853`. Suggested fix: a scaled size, capped near xxxLarge.

15. **Day pills' tap areas are 32pt wide, not 44.** Found by Accessibility. `WeekDayStrip.swift:42`. Seven 44pt targets fit.

16. **The Reminders footer doesn't change after "Don't Allow", and has no Open Settings button.** Found by Settings. `SettingsSheet.swift:367` reads the permission once. Suggested fix: check again after the prompt and on returning to the app; add Open Settings like Calendars.

17. **Updaters don't see the Thanksgiving turkey until they've opened What's New twice.** Found by Update. The turkey waits while the pill is out (`ContentView.swift:815`), and the pill never leaves on its own (`ChecklistStore.swift:188-189`). Suggested fix: the turkey first, then the pill; or retire the pill after a few launches.

18. **iPad: turning from landscape to portrait leaves closed cards alone in rows of three.** Found by iPad. Nothing reflows when the columns change (`ContentView.swift:1916`). Suggested fix: `reopenCards` on a column change. Shares code with: 8.


### Polish
19. **"Moved to the week of Nov 6" leaves out the year** for a date in a later year (`weekPhrase`, `ContentView.swift:1747-1750`). Edge.
20. **"Call mom tomorrow" on a Sunday says Monday "had already gone by".** The task goes to Monday correctly. (`TaskRowCard.swift:2951-2954`.) Edge and Everyday.
21. **What's New says "Settings ▸ What's New";** the row is Settings ▸ Help ▸ What's New in 1.1 (`WhatsNew.swift:136-137`). Update and Settings.
22. **Seasonal: row icons in Settings and Help, and Add Category's Create New and Edit, stay system blue** while switches take the season's color (`AddCategorySheet.swift:70`). Settings.
23. **The type/mode popup's icons spill over their rows at AccessibilityXXXL** (a fixed 22pt frame, `TaskOptionsPicker.swift:368`). Accessibility.
24. **iPad: the bottom bar rides up on the keyboard behind the Add Category sheet** (`ContentView.swift:231` ignores only the container's safe area). iPad.
25. **"2/29" typed in a year without a Feb 29 isn't offered as a date** (`TypedDate.swift:102-107`). Code. I re-ran its test.
26. **The live privacy policy still says "Coming Soon" survey.** Settings. Fixed in the 1.1 web copy.

## Questioned, left as designed
- **Add Category's Done with a taken name keeps the sheet open,** showing the red "already exists" line (by design, per `finish()`'s comment). A reviewer read it as "does nothing". Worth a decision: close anyway, or say it louder.
- **Smart Add without the model** (the simulator's rules mode) is what all Smart Add checks ran on; the model's wording is a phone check.

## Not reproduced / test artifacts
- Everyday: adding a task for a day gone by with Return (a control test that passed for the reviewer) hung once for 60 s in my re-run, at a load average of ~200; three more runs passed in 25 s. Likely the load, but it's on the phone checklist.
- Settings: Smart Add's Set Date once took two taps, under a load average of ~400 (`runB.log`). Not seen again.
- Edge: a third pin's tap landed mid-scroll in 1 of 3 runs: the test's timing.
- Edge: German "Zahnarzt 31.12." offered no date in one run; not repeated.
- Accessibility: the walk-through test failed only because the Dates Help tab needed a scroll: the test.
- Baseline: 27 of the old tests' failures are test artifacts (listed under Status).
- 27 (swiping weeks while renaming) and 28 (a short rename moving the card), first graded as regressions: both old tests fail the same way on 1.0.3. The swipe landed on the keyboard (from a row under it); from a row above it the swipe changes the week and saves the rename. The 12pt move is a rename that wraps a line scrolling clear of the round keyboard-down button, accepted as designed on Nov 10. The tests are corrected in `tests/Baseline/ReviewRegressionTests.swift`.

## Checked and fine
- **Update from 1.0.3:** every old value kept, both week starts, 1–3 weeks of rollover; This week only cards become Just this week and turn off cleanly; old tasks have no day, date or pin; no notification prompt at launch.
- **Days:** the Day row, "Next Thu" placeholder, Added to next week pop-up and Back to This Week; Sunday starts; an existing task given a past day isn't late; the day filter and Show All; today's pill with late tasks.
- **Dates:** one-time dates move to their week (next week, 75 days, two years, across the year end and the DST change); carry-over dates carry until then; Go to Week's rings; gone the day after.
- **Smart Add:** "Call mom Sunday", "Gym Mon Wed Fri", "dentist december 15" with Set Date, "Pay rent by december 1", "by friday", "before / till / by 11/25", year-end dates, Undo.
- **Dates in code:** no 86,400-second days; DayKeys round-trip in 10 zones over 2026–2028; DST weeks (Mar and Nov 2026, 2027) for current week, late, Today, expiry and the 9 AM reminder; time-zone travel east.
- **Pins, duplicates, clear-to-delete, Just this week chip, Add Category several times, saving on force-quit and backgrounding.**
- **Themes:** System, Light, Dark, all four seasons, Retro in six colors with DOS fields; the system dark switch with Settings open (when Seasonal was already picked); appearance kept across a relaunch; Support and Privacy links.
- **iPad:** popups and the Until calendar from top, middle and bottom rows; rotating with a popup open or mid-rename; the moved pop-up; the house's spacing; the What's New pill in narrow windows; Help tabs in a 375pt window; Add Category as a form sheet; resizing with open cards.
- **Accessibility:** day pills' labels and Selected; the chip's on/off value; the expiration ring's value; the house's button; Help tabs' names; the default-size audit clean; Reduce Motion in code; contrast in Dark and Seasonal dark.
- **App Review checklist:** privacy manifest, the notification prompt only on a first date or the Settings switch, calendar purpose string, no placeholder text, launch arguments debug-only, Support and Privacy pages up.

## Try on your phone
1. **Add a task from the options popup to next week.** Type a task, tap its type/mode button, pick a day that has gone by (or a date next week), tap Add Task. The screen should go to next week with no keyboard left up and the bottom bar back (fix 2). Then add one for this week from the popup and start typing the next right away: does the first letter ever land on the task just added? (Add Task now waits a third of a second.)
2. **Switch Settings ▸ Week to Sunday and back, on your real data.** Is every dated and day task still on its date, nothing late that shouldn't be, nothing pinned three times (fix 1)?
3. **Give a task a date for tomorrow.** Is the notification prompt asked then, and does "… expires tomorrow" arrive at 9 AM? Deny notifications, turn them on in iOS Settings, come back: do the footer and Open Settings update, and do reminders arrive for tasks already dated (fix 16)?
4. **Thanksgiving week, the turkey first.** Launch with `-demoTurkey -demoWhatsNew`: the turkey should run, then the What's New pill slide out (fix 17).
5. **With Apple Intelligence: Smart Add "Go to the zoo and harass penguins", "dentist december 15", "lease ends August 31st", "Call mom tomorrow".** Are the names, lists and Set Date offers right?
6. **Leave the app open past midnight into Monday.** Does it move to the new week, and do Today and late marks update?
7. **Open the app on a day with tasks due.** Does each card with today's tasks wiggle once, and does Today pulse?
8. **iPad landscape:** open two cards, then page two weeks away and back, and go in and out of Edit. Do the cards keep their lanes (fix 8)? With a hardware keyboard, does Escape in a rename field bring the old name back?
9. **Seasonal, then Dark Mode from Control Center with Settings scrolled down.** Do the rows go dark, and does Settings keep its place (fix 7)?
10. **Add a task for a day gone by, with Return, a few times.** Does the screen ever freeze after the jump to next week? (One simulator run hung under heavy load.)

## Files
- Reports: `reports/` (one per reviewer). Briefs: `briefs/`. The diff they read: `changes-since-1.0.3.diff`.
- Tests: `tests/<role>/`. Update: `tests/Update/` (seed and check tests, `scripts/update_check.sh`, data snapshots).
- Evidence: `evidence/<role>/`.
- Plan: `plan.md`. App Store text: `submission-notes.md`.
