# Regression review of the 1.0.3 fixes

(Saved from the regression reviewer's final message, iPhone 17 Pro, iOS 26.3. Its brief is `briefs/Regression.md`; the diff it read is `fixes.diff`.)

I found two regressions caused by this round of fixes and one polish item. The header, Undo, folding and the accessibility-size layout all held up. The Mac's load average was 113–186 during the run, so I kept the runs short. Two tests failed because of my own test code, not the app (see the end).

## 1. A repeating goal whose step is counted while This week only is on stops following its task after the switch goes off
**Minor.** No data is lost, but the copy quietly stops syncing. The spec says "A repeating copy keeps its own progress while following its source".
- **Setup:** `-demoData -demoFirstCard Fitness`, default text size.
- **Steps:**
  1. Open Fitness and go to next week (Run is a repeating goal, 0/3).
  2. Edit Fitness, turn This week only on, then tap Done.
  3. Tap Run's +1 (it shows 1/3).
  4. Edit Fitness, turn This week only off (Run says Repeating again).
  5. Go back to this week and rename Run to "Run club".
  6. Go to next week.
- **Expected:** next week shows "Run club" at 1/3.
- **Actual:** next week still shows "Run" (1/3). Seen in runs 2 and 3.
- **Control:** the same steps without the +1 (`testUntouchedCopyFollowsAfterThisWeekOnlyOnOff`) pass, so the step is what breaks it.
- **Evidence:** `evidence/Regression/twonly-goal-next-week-after-rename.png`. The log line is "REVIEW: next week shows Run club? false Run? true".
- **Likely cause:** `ChecklistStore.swift:1586`, `if …tasks[ti].mode != .repeating { markEdited(…) }`.
  - In a This week only card the task's mode is `.oneTime`, so the new `markEdited` sets `modeBeforeThisWeekOnly.wasUserEdited = true`.
  - Turning the switch off then restores `isUserEdited = true`.
- **Fix:** test `syncMode` instead of `mode`.

## 2. At XXXL, a list's name breaks mid-word in the card's edit mode
**Minor.** A visible layout break at the largest standard text size; it goes away when edit mode ends.
- **Setup:** `-demoData -demoFirstCard Errands -UIPreferredContentSizeCategoryName UICTContentSizeCategoryXXXL`.
- **Steps:** open Errands, fold Groceries, tap the card's edit button.
- **Actual:**
  - The name column shrinks to 48pt and reads "Gro / ceri / es / 2 of / 5".
  - A list has four icons in edit mode (chevron, type/mode, trash, handle), and icons only move to their own line at accessibility sizes.
- **Evidence:** `evidence/Regression/rows-xxxl-edit-from-video.png`. `testRowsAtXXXL` fails: "48.0 is not greater than 60.0 – Groceries's name keeps room (edit)".
- **Likely cause:** `stacksIcons` is only `dynamicTypeSize.isAccessibilitySize`.
- **Fix:** also stack the icons when they'd leave the name less than about a word's width, for example in edit mode from `.xxLarge` up.

## 3. A short rename that wraps onto a second line scrolls the card up 16pt even though the field was in full view
**Polish.** This is arguably the intended "keep it clear of Done".
- **Steps:** tap "Plan Mom's birthday" and type " and cake".
- **Actual:**
  - On "n" the field grows from 22 to 44pt and the card scrolls 16.3pt up.
  - The field's bottom was at 487 with the keyboard top at 583, so only the Done-button clearance band was in the way.
- **Evidence:** `evidence/Regression/rename-short-typed.png` and `testShortRenameDoesNotJumpCard`.
- **Likely cause:** `keepRenameFieldInView` calls `scrollTo` with no anchor, which counts the Done-button band as hidden.

## Checked and fine
- **Header on iPhone:** the mark sits at x=12, the title is centered and Open/Close All is 12pt from the right, in System and Retro. The mark goes back to this week.
- **Default size:** every task type, open and folded, in and out of edit mode, with no overlap. The type/mode popover fits.
- **AccessibilityXXXL:** the icons sit on their own line under the name, aligned right and on screen, for every type. The folded count, the popover, long sub-task renames and the chevron in edit mode all work.
- **XXXL outside edit mode:** no overlap.
- **Folded-list VoiceOver label:** "Groceries, 2 of 5 items checked", and it updates after deletes and Undo.
- **Undo:**
  - Delete an item, fold, then Undo: the item comes back and the list stays folded.
  - Checking a task, or a goal +1, after a delete ends the Undo.
  - A rename after a delete brings the Undo back, and Undo keeps it.
- **This week only:**
  - On and off leaves untouched copies following their task.
  - A rename made while it's on survives turning it off and a relaunch.
- **Rename and keyboard:** Return saves; Done saves a long rename; a long rename near the bottom grows clear of the keyboard.
- **Help:** the new wording.

## Test files
`tests/Regression/ReviewRegressionTests.swift`.
- **Findings:**
  - 1: `testRepeatingGoalStepWhileThisWeekOnlyStillFollowsItsTask`
  - 2: `testRowsAtXXXL`
  - 3: `testShortRenameDoesNotJumpCard`
- **Checked and fine:** `testHeaderOnIPhoneUnchanged`, `testRowsAtDefaultSize`, `testRowsAtAccessibilityXXXL`, `testUndoSubtaskDeleteThenFoldKeepsFoldAndCount`, `testCheckingAfterDeleteStillEndsUndo`, `testGoalStepEndsUndoRenameKeepsIt`, `testUntouchedCopyFollowsAfterThisWeekOnlyOnOff`, `testThisWeekOnlyRenameSurvivesOffAndRelaunch`.
- **Unfinished (test code):** `testJourneyFoldReorderRenameRelaunch` (the handle drag didn't move the task) and `testRenameSavedByWeekSwipeAndEditButton` (`swipeLeft` didn't change the week).

## Couldn't check in a simulator
- Drag a task by its handle at AccessibilityXXXL, where the handle is on its own line under the name.
- Paste several lines from Notes into Add item and into a rename field.
- With a hardware keyboard, press Escape and Tab in rename fields.
- Swipe the week while a rename field is open.
- Type a name until it wraps just above the keyboard's Done button: does the 16pt scroll feel like a jump?
- Fold and unfold a long list near the bottom of the screen.

## After the reviewer (added by the orchestrator)
- **1, fixed:** `updateGoalProgress` now checks `syncMode`. A new unit test, `repeatingGoalStepWhileThisWeekOnlyStillFollows`, covers it, and the reviewer's test passes.
- **2, fixed:** the icons also stack in a card's edit mode from XL text up.
  - Re-run at XXXL in edit mode, the name has 300pt on one line with the icons on the line below.
  - `testRowsAtXXXL` now fails only its side-by-side check ("name and icons don't overlap"). That check assumes icons beside the name below accessibility sizes, so it's a test artifact of the new rule; its "name keeps room" check passes.
- **3, left as designed:** the scroll keeps a grown field clear of the round Done button.
- **Re-run on the fixed code:** all 8 "checked and fine" tests passed again.
