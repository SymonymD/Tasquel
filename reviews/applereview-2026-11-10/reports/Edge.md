# Edge cases and small screens: Tasquel 1.0.3 review

(Saved from the reviewer's final message. The harness refused report files: subagents must return findings as text.)

I found six bugs, all reproduced at least twice: three Major, three Minor, no crashes or hangs. Three come from 1.0.3 changes (F2, F3, F5). F1 and F6 also exist in 1.0.2. The open question about the bottom bar on a Home-button iPhone is answered in F6.

Device: iPhone SE (3rd generation), iOS 26.3, Light, English unless noted. Shots are in the reviewer's `Edge/shots` (called `shots/` below), with logs `shots/run1.log` to `shots/run5.log`. All tests are in the class `ReviewEdgeTests`.

## 1. Findings, most severe first

### F1. Pasting several lines into Add Task or Add Item makes only the first two separate. The rest becomes one task. (Major, also in 1.0.2)
- **Steps:** open Errands, tap Add Task, paste 8 lines ("Line 1" to "Line 8", like a list copied from Notes), then close the keyboard. Add Item on a list does the same.
- **Expected:** 8 tasks or items, one per line, as when Return is typed after each one.
- **Actual:** you get "Line 1", "Line 2", and a third entry holding "Line 3⏎…⏎Line 8", shown as a six-line task. Pasting 120 lines into a list gave "0 of 4": Solo, Item 1, Item 2, and one 118-line item.
- **Evidence:** `shots/paste-task-after.png`, `shots/paste-item-after.png`, `shots/fold-121.png`. The REVIEW lines in run4 list each row. Seen 3 times.
- **Tests:** `testPasteLinesIntoAddTaskAddsOneTaskPerLine`, `testPasteLinesIntoAddItemAddsOneItemPerLine`, `testFoldedCountZeroOneAndManyItems`.
- **Likely cause:** `submitTyped` (TaskRowCard.swift:2007) and `submitTypedSubtask` (TaskRowCard.swift:927) handle one line per change. They rely on `onChange` firing again after `newTitle = rest`, and SwiftUI stops after a couple of rounds. When the keyboard closes, the leftover text is added whole, because only `.whitespaces` is trimmed, not newlines.
- **Fix:** in one pass, split on newlines, add every complete line, and keep only the text after the last line break in the field.

### F2. At the largest text size, a folded list loses its name and its card runs off the screen. (Major, accessibility, new in 1.0.3)
- **Steps:** launch with `-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityXXXL`, open Errands (demo data), tap Groceries' chevron.
- **Expected:** the list's name stays readable, and the chevron and type/mode button stay on the screen.
- **Actual:**
  - The name gets 0 pt of width and disappears; the row shows only "2 of 5" in large text and the chevron.
  - The type/mode button ends at x = 445 on a 375 pt screen, and the card's right edge is off the screen.
  - Even with the list open, the new 66 pt chevron leaves the name a 33 pt column, so "Groceries" wraps one letter per line.
- **Evidence:** `shots/axxxl-groceries-folded.png`, `shots/axxxl-groceries-open.png`, `shots/long-list-title-folded-axxxl.png`. Seen 2 times (run2, run3).
- **Tests:** `testFoldedListKeepsTitleAndButtonsAtLargestText`, `testLongListTitleBesideFoldedCountLargestText`.
- **Likely cause:** `foldedCount` (TaskRowCard.swift:430, placed at :206) is `.fixedSize()` in an uncapped `.expandedCard(.caption1)`. It sits outside the icons' `.dynamicTypeSize(...accessibility1)` cap (:224). The title has only `.frame(maxWidth: .infinity)`, so it shrinks to nothing.
- **Fix:** at accessibility sizes, show the count under the title or inside the capped icon group, and give the title `.layoutPriority(1)`.

### F3. Pressing Return with the caret inside a word in a rename field inserts a space. (Major, new in 1.0.3)
- **Steps:** tap "Plan Mom's birthday" to rename it and type "Grocries". Hold the space bar and slide to move the caret back into the word, type "e", press Return.
- **Expected:** "Groecries" is saved as typed. The spec says a line break means Return and saves the name without it.
- **Actual:** "Groe cries" is saved, with a space wherever the caret was. Fixing a typo mid-word and pressing Return always does this.
- **Evidence:** run4 and run5 logs both show `saved name 'Groe cries' (field held 'Groecries')`; shots `shots/rename-midword-before-return.png` and `shots/rename-midword-after-return.png`. Seen 2 times.
- **Test:** `testReturnMidWordInRenameAddsNoSpace`.
- **Likely cause:** `RenameField.submitted` (TaskRowCard.swift:1250) joins the pieces around every newline with " ", so it can't tell a typed Return from pasted lines. It's called from TaskRowCard.swift:185 and :1454.
- **Fix:** compare against the previous text in `onChange(of: editedTitle) { old, new in … }`. If exactly one newline was inserted, remove it with no space; join with spaces only for pasted text.

### F4. Undoing a delete also opens a list that was folded after the delete. (Minor)
- **Steps:** open Errands (demo), tap the card's edit button, delete "Plan Mom's birthday". While the Undo message is up, fold Groceries (the Undo stays, by design), then tap Undo.
- **Expected:** the task comes back and Groceries stays folded.
- **Actual:** the task comes back and Groceries springs open again.
- **Evidence:** `shots/undo-after-fold.png`; the run3 and run5 logs both show `after Undo the list is Collapse list`. Seen 2 times.
- **Test:** `testUndoDeleteKeepsLaterFold`.
- **Likely cause:** `undoLastDelete` restores the whole `weeksBeforeDelete` snapshot (ChecklistStore.swift:1681–1690). `setListFolded` keeps the Undo alive with `save(keepsUndo: true)` (:1419), so the snapshot predates the fold.
- **Fix:** after restoring, re-apply the current `isListFolded` values by task ID, or end the Undo when a list is folded.

### F5. Folding a list this week overrides the fold set on next week's copy. (Minor, new in 1.0.3)
- **Steps:** go to next week (demo) and fold Groceries. Go back to this week, fold Groceries, then open it again. Go to next week.
- **Expected:** next week's Groceries is still folded. The spec says a fold changed in a later week stays.
- **Actual:** next week's Groceries is open.
- **Evidence:** `shots/fold-nextweek-after-thisweek.png`. Seen 2 times (run2, run3).
- **Test:** `testFoldSetInNextWeekStaysAfterFoldingThisWeek`.
- **Likely cause:** `foldLaterCopies` (ChecklistStore.swift:1426) overwrites every copy that isn't `isUserEdited`, and folding a copy never marks it as the user's own.
- **Fix:** remember on the copy that its fold was set in its own week, and skip those copies.

### F6. On a Home-button iPhone, the bottom bar runs into the screen's bottom edge. (Minor, also in 1.0.2)
- **Open question answered:** the bar isn't placed wrongly after onboarding. It sits in the same place after onboarding, on a normal launch, on a relaunch, and after closing Settings.
- **The real problem:** that place is 0 pt from the edge. Settings, the week selector and Edit all end at y = 667 on a 667 pt screen, and their glass shapes are cut flat by the edge.
- **Evidence:** `shots/bar-no-onboarding.png`, `shots/bar-after-onboarding.png`, `shots/small/bar-bottom-crop.png`. Seen 3 times (run1 to run3).
- **Tests:** `testBottomBarClearsBottomEdgeOnHomeButtonIPhone` (fails). `testBottomBarSitsAtBottomAfterOnboarding` and `testBottomBarAfterOnboardingThenRelaunch` pass.
- **Likely cause:** ContentView.swift:747, `.padding(.bottom, homeIndicatorInset)`, which is 0 on these phones.
- **Fix:** use `max(homeIndicatorInset, 8)` there. The Undo message (ContentView.swift:206) and the grid padding (:1080) follow `bottomBarHeight`, so they adjust by themselves.

## 2. Checked and fine
- **Bar placement:** the same after onboarding (fresh `-isolatedData`), on a relaunch, and after Settings.
- **Long title:** a 90-character list title beside "0 of 2", the chevron and the type/mode button at default size wraps, and everything stays on the screen.
- **Small lists:** a folded empty list shows no count and no Add Item; with 1 item it shows "0 of 1".
- **Folding while renaming an item:** the rename is saved and the keyboard closes.
- **Folding while renaming the list's own name:** it folds, the rename stays open, and it saves when the keyboard closes. Seen in run3; in run4 the test tapped the name too early.
- **Pasted multi-line text in a rename field:** joined with spaces and saved.
- **Force-quit:** right after folding, the fold is kept. Backgrounding mid-rename and then killing the app keeps the rename.
- **Travel from Kiritimati (UTC+14) to Pago Pago (UTC−11):** same week, today moves from Wednesday the 11th to Tuesday the 10th, nothing is duplicated or lost, and the fold is kept.
- **Week boundary across zones:** Sunday Nov 8 at UTC+14, then Tuesday Nov 10 at UTC−11. The repeating list arrives folded, the carry-over arrives, and the This week only card stays behind. Last week is view only, every list open, no chevron.
- **Keyboard and picker on the SE:** in a This week only card with the keyboard up, the picker's hint and Add Task sit above the keyboard.
- **Reorder auto-scroll upward on the SE:** task 14 of 14 can be dragged to the top.
- **Right to left (forced):** the row mirrors. The folded chevron still points right as in left-to-right, which only matters once there's a right-to-left translation.

Not covered: German decimal commas (my test couldn't find the target field), daylight-saving zones, and permissions denied then granted.

## 3. Test files
All tests are in `tests/Edge/ReviewEdgeTests.swift` (from `TasquelUITests/` in the reviewer's copy).

| Covers | Tests |
|---|---|
| F1 | `testPasteLinesIntoAddTaskAddsOneTaskPerLine`, `testPasteLinesIntoAddItemAddsOneItemPerLine`, `testFoldedCountZeroOneAndManyItems` |
| F2 | `testFoldedListKeepsTitleAndButtonsAtLargestText`, `testLongListTitleBesideFoldedCountLargestText` |
| F3 | `testReturnMidWordInRenameAddsNoSpace` |
| F4 | `testUndoDeleteKeepsLaterFold` |
| F5 | `testFoldSetInNextWeekStaysAfterFoldingThisWeek` |
| F6 | `testBottomBarClearsBottomEdgeOnHomeButtonIPhone` |
| Checked and fine | `testBottomBarSitsAtBottomAfterOnboarding`, `testBottomBarAfterOnboardingThenRelaunch`, `testLongListTitleBesideFoldedCount`, `testFoldWhileRenamingItemSavesIt`, `testFoldWhileRenamingListTitle` (made less timing-sensitive after run4, not re-run), `testRenamePasteMultilineJoins`, `testForceQuitRightAfterFoldAndRename`, `testTravelKiritimatiToPagoPago`, `testWeekBoundaryRolloverAcrossZones`, `testPickerFitsWithKeyboardInThisWeekOnlyCard`, `testReorderAutoScrollUpOnSmallScreen`, `testRightToLeftFoldedList` |
| Unfinished (test selector problems, not app bugs) | `testGermanDecimalCommaGoal`, `testBackgroundWhileTypingItem` |

During the first half hour the Mac's load average was in the hundreds to about 980, so the first runs stalled for 10 to 15 minutes before starting.

## 4. Couldn't check in a simulator (phone checklist)
- On an SE, does the bottom bar look clipped at the bottom edge, and is Settings easy to hit there?
- Drag a task to the top or bottom of a long card on an SE: is the scrolling (up to 900 pt/s) too fast for such a short screen?
- While reordering, do the lift, place and drop haptics come through? Folding has no haptic: does it feel like it needs one?
- Paste a shopping list from Notes into Add Item (F1).
- On iPad with a hardware keyboard, move the caret with the arrow keys in a rename and press Return (F3).
- Change the time zone (Settings ▸ General ▸ Date & Time) or fly with the app open: does today move without a relaunch?
- Leave the app open across Sunday midnight: does it move to the new week, with folded lists carried over?
