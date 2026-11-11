# Tasquel 1.0.3 review: 2026-11-10

Seven reviewers in simulators (iOS 26.3):
- **Everyday flows:** iPhone 17 Pro.
- **Settings and themes:** iPhone 17 Pro Max.
- **iPad:** iPad Pro 13-inch (M5); the 11-inch was booted but not used.
- **Accessibility:** iPhone 17.
- **Edge cases and small screens:** iPhone SE (3rd generation).
- **Code review:** reading the code, plus unit tests on an iPhone 17 Pro.
- **Update from the live 1.0.2 (10):** iPhone 17 Pro. Its simulator never started the test runner, so it checked the update with the app's own data code instead.

Reviewed: `release-1.0.3` at b48a845 plus folding lists, which isn't committed yet. The project still says 1.0.2 (10).

## Status
- **23 findings after merging duplicates:** 2 rejection risk, 5 major, 10 minor, 6 polish. Eight of them are in 1.0.2 too; the rest are new in 1.0.3, mostly in folding lists and This week only.
- **How they were checked:**
  - 8 I re-ran myself, and each failed again as reported.
  - 8 more are confirmed by the code or a screenshot.
  - 7 rest on the reviewer's own repeated runs.
  - None turned out to be a test mistake. Two notes from reviewers did, and they're listed under "Not reproduced / test artifacts".
- **Tests before the review, on this code:** unit tests 181 of 181 passed; UI tests 73 of 73 passed.
- **Update from 1.0.2: no data lost.** 1.0.2's saved file loads unchanged in the new build, and the current, next and following weeks come out the same as in 1.0.2, also a week and two weeks later. The only addition is the new fold setting, set to open. Two small This week only leftovers are listed below (findings 14 and 15).
- **Baseline:** none. This is the first `/applereview`, and the Oct 27 tests were lost.
- **The Mac was badly overloaded:** a load average of 600–1,000 for the first 45 minutes, because seven simulators and builds ran at once. Reviewers lost time to stalled test runs, and some planned tests didn't run (listed under "Not reproduced / test artifacts").

## Fixes made (2026-11-10, after the review)
You picked findings 1–7, plus 9, 10, 12, 13, 14, 15, 18, 19, 21 and 23.

**Fixed and checked:**
- **1 and 3, folded list and row icons at large text sizes:**
  - The count is now part of the name's text ("Groceries  2 of 5", non-breaking).
  - Row icons stop growing at 1.6×.
  - At accessibility sizes, and in a card's edit mode from XL up, the icons sit on their own line under the name.
- **2, edits while This week only is on:** every edit also updates what the card remembers.
- **4 and 10, Undo:** a rename or fold made after a delete is made in the copy Undo puts back too, so it keeps the Undo. Other changes still end it.
- **5, pasting:** every pasted line is added in one pass.
- **6 and 9, rename fields:** a typed Return or Tab saves wherever the cursor is, with no added space.
- **7, iPad:** the Tasquel mark moves clear of the window controls, using UIKit's corner-adapted safe area.
- **12, rename field:** it scrolls back into view as it grows.
- **14, 1.0.2 data:** carry-over and repeating tasks in a This week only card load as one-time.
- **18, VoiceOver count:** VoiceOver now says "1 item". The count is now the name's value rather than part of its label, so Voice Control's "tap Groceries" still works.
- **19, Help:** "drag a task by its handle to move it".
- **23, right to left:** the chevron uses `chevron.forward`.

**Not fixed:**
- **21, Escape:** neither `onKeyPress` nor a hidden cancel-shortcut button reached the wrapping rename field in the simulator. I took that code back out, so it's open for 1.1.
- **13 and 15, the fold rules:** these turned out to be design questions, not bugs, and are waiting for your answer.

**Regression check after the fixes:**
- **Full suites:** 191 of 191 unit tests passed, and 73 of 73 UI tests. `testFoldingAList` timed out once under load; run alone, it passed.
- **Update check:** 1.0.2 data loads the same as in 1.0.2, apart from finding 14's intended change.
- **One regression reviewer:** `reports/Regression.md`. It found two regressions caused by the fixes, both now fixed:
  - a step counted on a repeating goal while This week only was on stopped that copy following its task (now checked by `syncMode`, with a unit test);
  - at XXXL in edit mode a list's name broke mid-word, so the icons now stack in edit mode from XL up.

  It also found a polish item, left as designed: a rename that wraps scrolls 16pt to stay clear of the round Done button.
- **Every reviewer's test, re-run on the fixed code:**
  - The tests for the fixed findings pass.
  - Several tests looked for the folded count as its own label. I updated them, in this folder too, to read the name's value instead.
  - These still fail, because they check how things were laid out before the fixes:
    - the count's frame beside the name (`testFoldedCountFitsAtLargestTextSize`'s overlap check, `testLongListTitleBesideFoldedCount`, `testFoldedListTitleFitsInEditMode`'s one-line check);
    - `testRowsAtXXXL`'s side-by-side check, now that the icons stack;
    - the iPad window-controls test's 72pt guess; the screenshot shows the mark clear, and UIKit says 66pt;
    - the Everyday rename test, whose expected name is wrong; the app saved exactly what was typed.
  - These fail as expected, because their findings weren't fixed:
    - 8, the app icon;
    - 11, rotating while typing on iPad;
    - 16, the SE's bottom bar;
    - 21, Escape;
    - 13, the fold set on next week's copy;
    - plus the tests that were never finished (German decimal commas, iPad windows).

## Findings

### Rejection risk

1. **At the largest text sizes a folded list loses its name and pushes the card off the screen.** New in 1.0.3. Found by Accessibility, Edge and Everyday.
   - **Devices:** iPhone 17 and SE, at Accessibility text sizes. Part of it also happens at XXXL.
   - **What happens:**
     - Fold a list and the row shows only "○ 2 of 5 >".
     - The name gets no width at all, and the type button, the card's edit button and its ring run off the right edge.
     - In the card's edit mode, the trash cans and Done editing are off the screen too, so the user can't delete a task or leave edit mode.
     - At the default text size the folded name breaks mid-word in edit mode ("Groceri / es").
   - **Steps:** Larger Text at the maximum, open Errands, tap Groceries' chevron, then the card's edit button.
   - **Evidence:**
     - `evidence/Access/B03-groceries-folded-axxxxl_s.png` and `B04-errands-edit-axxxxl_s.png`
     - `evidence/Edge/axxxl-groceries-folded.png`
     - `evidence/Everyday/folded-title-edit-mode.png`
   - **Tests:** `ReviewAccessUITests/testFoldedCountFitsAtLargestTextSize`, `ReviewEdgeTests/testFoldedListKeepsTitleAndButtonsAtLargestText` (re-run: the title's frame was 0 wide) and `ReviewEverydayTests/testFoldedListTitleFitsInEditMode` (re-run).
   - **Cause:** the "2 of 5" count (`TaskRowCard.swift:206`, `foldedCount` at `:430`) has a fixed width and a text size with no cap. It sits in the title row beside the chevron and the type button, so the name gives up its width first and then the card overflows.
   - **Suggested fix:** when the row doesn't fit, which is always the case at accessibility sizes and in edit mode, put the count on its own line under the name, and let the name take priority for width.
   - **Also affects:** only list rows while folded. Unfolded lists and other task types don't show the count.
   - **Shares code with:** 3.

2. **Edits made while a card is This week only are undone when it's turned off.** New in 1.0.3. Found by Code.
   - **Device:** any; this is how the app saves.
   - **What happens:** in next week's This week only card, rename a repeating task, add an item to a repeating list, or count progress on a carried goal. Then turn This week only off, or add a repeating task, which also turns it off. The next time that week syncs, the name goes back, the new item is deleted and the progress resets. That happens when you visit this week and come back, or when that week becomes the current one.
   - **Steps:** see `reports/Code.md` F1.
   - **Tests:** `ReviewCodeThisWeekOnlyEditTests`: `renameWhileThisWeekOnlySurvivesTurningItOff`, `listItemsSurviveTurningOffByAddingTask` and `goalProgressSurvivesTurningOff`. I re-ran them and all three fail.
   - **Cause:**
     - Turning it off sets each task's "changed by you" mark back to what it was when the switch went on (`ChecklistStore.swift:1183`, `restoreModes`). Any edit made in between is forgotten.
     - The task then looks untouched, and sync copies the week before over it (`followingRepeating`, `following`).
   - **Suggested fix:** one rule. Any change that marks a task as changed by you also records that in what This week only remembers (`modeBeforeThisWeekOnly.wasUserEdited`). A single helper sets both, so turning it off keeps the mark.
   - **Also affects:** every edit that marks a task as yours: rename, type, goal target, step and progress, and adding, renaming or deleting sub-tasks and items. The change is to how the mark is set, so each of these needs a test that it still stops sync from following.
   - **Shares code with:** 14 and 15.

### Major

3. **Row icons keep growing at the largest text sizes, so names break mid-word.** Mostly older: the cap never worked, but 1.0.3's chevron makes lists worse. Found by Accessibility.
   - **What happens:** at Accessibility text sizes, "Groceries" wraps as "Gr / oc / eri / es" and "Drop off donations" as "donation / s". In edit mode the reorder handles go past the right edge.
   - **Evidence:** `evidence/Access/B02-errands-open-axxxxl_s.png` and `F2-edit-unfolded-axxxxl_s.png`.
   - **Cause:**
     - The icons are meant to stop growing at Accessibility 1, using `.dynamicTypeSize(...accessibility1)` at `TaskRowCard.swift:224`.
     - But the card fonts take their size from an app-wide text-size setting (`Font.expandedCard`, `expandedCardScaled`, `TaskRowCard.swift:26-43`, `TextSizeSetting.shared`), which ignores that cap. So the type/mode button reaches 160 pt and the chevron 66 pt.
   - **Suggested fix:** clamp the icon fonts the way their frames already are (`expandedCardControl`'s 1.6×). That means the row icons and the type/mode label.
   - **Also affects:** every task row's icons (+, chevron, type/mode, trash, handle). The picker uses the same label and should be checked.
   - **Shares code with:** 1.

4. **Deleting while a rename is open loses the Undo for good.** Probably also in 1.0.2. Found by Everyday.
   - **What happens:** you're renaming an item, then tap the red − on another item. When the keyboard goes, no "Deleted … · Undo" appears, so the delete can't be undone.
   - **Test:** `ReviewEverydayTests/testDeleteWhileRenamingKeepsUndo`. I re-ran it and it logged `undo=false`.
   - **Cause:** the rename is saved when the keyboard closes, after the delete. Every ordinary save ends the Undo (`ChecklistStore.swift:309`).
   - **Suggested fix:** save any open rename before a delete records its Undo.
   - **Also affects:** every delete: of a task, a sub-task, an item and a category.
   - **Shares code with:** 10.

5. **Pasting several lines into Add Task or Add Item makes only the first two separate; the rest becomes one task.** Also in 1.0.2. Found by Edge.
   - **What happens:** paste 8 lines from Notes and you get "Line 1", "Line 2", then one six-line task. Pasting 120 lines gave three items plus one 118-line item.
   - **Evidence:** `evidence/Edge/paste-task-after.png` and `paste-item-after.png`.
   - **Test:** `ReviewEdgeTests/testPasteLinesIntoAddTaskAddsOneTaskPerLine`. I re-ran it and got 3 rows.
   - **Cause:** `submitTyped` (`TaskRowCard.swift:2007`) and `submitTypedSubtask` (`:927`) take one line at a time, waiting for the field to report the change again, and SwiftUI stops reporting after a couple of rounds.
   - **Suggested fix:** split on every line break at once, and leave only the text after the last one in the field.
   - **Also affects:** typing Return in those fields, which goes through the same code. It must still keep the keyboard up and add one task.
   - **Shares code with:** 6 and 9.

6. **Return with the cursor inside a word in a rename field saves the name with a space.** New in 1.0.3. Found by Edge.
   - **What happens:** you fix "Grocries" to "Groecries" by moving the cursor and press Return, and "Groe cries" is saved.
   - **Evidence:** `evidence/Edge/rename-midword-after-return.png`.
   - **Test:** `ReviewEdgeTests/testReturnMidWordInRenameAddsNoSpace`. I re-ran it.
   - **Cause:** `RenameField.submitted` (`TaskRowCard.swift:1250`) treats every line break as pasted lines and joins the pieces with spaces.
   - **Suggested fix:** compare the text with what it was a moment before. If one line break was typed, drop it with no space. Join with spaces only for pasted text.
   - **Also affects:** the rename fields for tasks, sub-tasks and items.
   - **Shares code with:** 5 and 9.

7. **iPad: in a resized window, the window controls cover the Tasquel mark.** Since 1.0.2's header. Found by iPad.
   - **What happens:** in any window smaller than the screen, iPadOS 26's red, yellow and green controls sit on the mark, and a tap there opens the window menu instead of going back to this week. Help tells users to tap the logo.
   - **Evidence:** `evidence/IPad/window-controls-vs-mark.png`, compared with full screen in `explore-01-landscape-closed.png`.
   - **Test:** `ReviewIPadSetupTests/testWindowControlsLeaveTheTasquelMarkClear`.
   - **Cause:** the header's mark (`ContentView.swift:885`) has only a 12 pt leading inset (`:683`) and ignores the window controls' area.
   - **Suggested fix:** inset the header's leading edge by the window-controls area. The reviewer suggests UIKit's corner-adapted margins layout guide; check Apple's iPadOS 26 guidance first.
   - **Also affects:** the header on iPad only. The iPhone layout must not move.

### Minor

8. **Match App Icon to Theme can fail silently and stay wrong.** Found by Settings. Confirmed only in the overloaded simulator, so try it on your phone.
   - **What happens:** in the simulator the icon change was refused ("Resource temporarily unavailable") on the first try and on the one retry. After that, nothing puts the icon back in step with the theme until you pick a theme again.
   - **Evidence:** `evidence/Settings/icon-probe.log` and `icon-2-light-home.png` (the retro icon showing in Light).
   - **Cause:** `AppIconSwitcher.swift:20-30` retries once, discards both errors, and runs only from Settings.
   - **Suggested fix:** retry a few times with a growing pause, and check the icon once each time the app becomes active.
   - **Also affects:** nothing else. It only runs from Settings, and once per app, so iPad windows don't race.

9. **iPad: Tab on a hardware keyboard types a tab into a task's name.** New in 1.0.3; the rename fields wrap now. Found by iPad, in 2 runs; I didn't re-run it.
   - **What happens:** the name is saved as "Pick up dry cleaning soon⇥now".
   - **Evidence:** `evidence/IPad/rename-tab.png`.
   - **Cause:** wrapping fields accept tabs, and `RenameField` handles only line breaks.
   - **Suggested fix:** treat Tab like Return in rename fields, and turn any tab into a space.
   - **Shares code with:** 6 and 22.

10. **Undo after a fold unfolds the list again.** New in 1.0.3. Found by Code, Edge and Everyday.
    - **What happens:** delete a task, fold a list while "Deleted … · Undo" shows, then tap Undo. The task comes back, but the list opens again, and so do its copies in later weeks.
    - **Evidence:** `evidence/Edge/undo-after-fold.png`.
    - **Test:** `ReviewCodeFoldTests/undoKeepsLaterFold`. I re-ran it.
    - **Cause:** Undo puts back the copy of the weeks saved at the moment of the delete (`ChecklistStore.swift:1683`). Folding keeps the Undo but doesn't update that copy.
    - **Suggested fix:** while an Undo is waiting, apply the fold to that saved copy too, including later copies of the list.
    - **Shares code with:** 4.

11. **iPad: rotating while typing leaves the field behind the keyboard.** Probably also in 1.0.2. Found by iPad, in 3 runs.
    - **What happens:** the words are kept, but the field ends up under the keyboard, even after typing more.
    - **Evidence:** `evidence/IPad/rotate-typing-landscape-8s.png`.
    - **Cause:** the card scrolls the field back into view only after a task is added (`keepFieldInView`, `TaskRowCard.swift:2056`).
    - **Suggested fix:** also scroll it back when the window size or the keyboard changes.
    - **Shares code with:** 12.

12. **A long rename slides under the keyboard, and the round keyboard button covers the task's type/mode button.** New in 1.0.3. Found by Everyday.
    - **What happens:** a 5-line name grows down behind the keyboard.
    - **Evidence:** `evidence/Everyday/crop-rename-1s.png`.
    - **Test:** `ReviewEverydayTests/testWrappedRenameFieldStaysAboveKeyboard`. I re-ran it, and the keyboard button again overlapped the options.
    - **Cause:** the wrapping rename field grows after it was scrolled into view, and nothing scrolls it again.
    - **Suggested fix:** when a rename field grows, scroll its row into view, as Add Task already does.
    - **Shares code with:** 11.

13. **Folding a list this week overrides the fold you set on next week's copy.** New in 1.0.3. Found by Edge.
    - **What happens:** fold next week's Groceries, then fold and unfold this week's. Next week's opens again.
    - **Evidence:** `evidence/Edge/fold-nextweek-after-thisweek.png`.
    - **Cause:** this follows my rule as written: folding sets every untouched later copy (`foldLaterCopies`). It isn't what a user expects.
    - **Suggested fix:** a later copy follows a fold only while it still matched the list's fold before the change. A copy you folded or opened yourself keeps its own fold.
    - **Shares code with:** 15.

14. **Carry-over tasks that 1.0.2 put into a This week only card still say Carry Over, then don't carry.** 1.0.2 data. Found by Update.
    - **What happens:** after the update, such a task shows Carry Over under "It won't come back next week", and a week later it's gone. 1.0.2 loses it the same way, but 1.0.3 fixes only new arrivals.
    - **Evidence:** `evidence/Update/weeks-new-on-1.0.2-data-today.txt` and `...-plus7days.txt`.
    - **Cause:** new arrivals are made one-time when they arrive (`arriving`, `ChecklistStore.swift:1174`). Tasks already in such a card are never fixed up.
    - **Suggested fix:** at launch, make carry-over and repeating tasks in current and future This week only cards one-time, remembering their mode, the same way as new arrivals.
    - **Shares code with:** 2.

15. **Turning This week only on and straight off rebuilds next week's card,** which loses a fold made there and moves next week's own task. New in 1.0.3 for the fold. Found by Update.
    - **Evidence:** `evidence/Update/action-roundtrip-loses-next-week-fold.txt` and `action-roundtrip-errands.txt`.
    - **Cause:** turning it on deletes later weeks' untouched copies (`ChecklistStore.swift:1137-1146`); turning it off lets sync make them again, open and in this week's order.
    - **Suggested fix:** keep later copies whose fold differs from their source's, as with finding 13. Or keep the removed copies with the card and put them back when it's turned off.
    - **Shares code with:** 2 and 13.

16. **On a Home-button iPhone (SE), the bottom bar sits on the screen's bottom edge.** Also in 1.0.2. Found by Edge.
    - **What happens:** the Settings, week and Edit buttons end at the last pixel, and their glass shapes are cut flat.
    - **Evidence:** `evidence/Edge/bar-bottom-crop.png`.
    - **Test:** `ReviewEdgeTests/testBottomBarClearsBottomEdgeOnHomeButtonIPhone`. I re-ran it.
    - **Cause:** `ContentView.swift:747` pads by the home-indicator height, which is 0 on these phones.
    - **Suggested fix:** pad by at least 8 pt.
    - **Also affects:** the Undo message and the grid's bottom padding, which follow the bar's height on their own.

17. **VoiceOver isn't told that a task's name can be renamed.** Also in 1.0.2. Found by Accessibility.
    - **What happens:** the name is read as plain text, with no "button" and no hint.
    - **Cause:** a tap gesture on a `Text` (`TaskRowCard.swift:192-203`, `1461-1475`).
    - **Suggested fix:** a Rename action, or the button trait with a hint.

### Polish
18. **The folded count says "0 of 1 items checked"** (Accessibility). It should say "item" for one; `TaskRowCard.swift:437`.
19. **Help still says to "hold and drag the handle"** (Settings). In 1.0.3 the task lifts at the first touch; `HelpSheet.swift:31`.
20. **Two places aren't themed** (Settings, also in 1.0.2):
    - in Retro, Week Starts On is the system's grey control;
    - the Welcome Tour is plain system dark in every theme (`evidence/Settings/tour-dark-0.png`).
21. **iPad: Escape doesn't cancel a rename** (iPad). It should put the old name back.
22. **Today's day pill ("10th") only just passes the contrast check** (Accessibility, also in 1.0.2).
23. **Right to left: a folded list's chevron points right instead of left** (Edge). It matters only once there's a right-to-left language; my mirroring is applied twice.

## Questioned, left as designed
- **Smart Add without the model leaves stray words:** "Gym , each", "Gym per session", "Study for" (Code). These come from the simulator's rules-only Smart Add. With Apple Intelligence the model writes the title, so it's on the phone checklist rather than a finding.
- **Smart Add's highlight fade changes the store inside an animation after a pause** (`TaskRowCard.swift:331`; Code). The spec's own rule says not to do this. Nothing visibly went wrong in any run, but it's the same pattern as 1.0.1's "Added … but card shows 0/0" bug. Worth a look at some point.
- **Reorder animations ignore Reduce Motion** (Accessibility): the 3% lift and the sliding. It's a direct-manipulation drag, so it may be fine. Your call after trying it.

## Not reproduced / test artifacts
- **"GoalUITests still looks for the rename field as a text field"** (iPad side note). Not a problem: all 73 UI tests pass, and the field shows up as a text field.
- **The Accessibility rename-labels test opened an item's rename.** Its tap landed while the card was still springing open; that's a test timing problem.
- **The Update reviewer's simulator install over the live app never ran,** because the machine was overloaded. The update was checked with the app's own data code, which is deterministic. The real install is first on the phone checklist.
- **Not run for lack of time:**
  - the Accessibility audit at the default size;
  - the system display settings (Bold Text, Button Shapes, Increase Contrast and others);
  - the iPad 11-inch and two windows side by side;
  - German decimal commas;
  - four Retro colors.

## Checked and fine
- **Folding lists:**
  - a new list starts open;
  - folding hides the items and Add Item and shows "2 of 5";
  - it survives a relaunch, a force-quit and the week change, and it carries to next week's copies, also across an unsaved week;
  - past weeks show lists open;
  - folding isn't an edit, so sync keeps following and the card sort doesn't change;
  - it adds a typed item first, and saves an item being renamed;
  - VoiceOver hears "Collapse list" / "Expand list" with the name, and folded items are skipped;
  - the chevron is at least 44 pt;
  - it works in every theme and on iPad in 3 and 4 columns.
- **Reordering:**
  - the task lifts at the first touch;
  - it lands right with tasks of mixed heights and at both ends;
  - the week doesn't swipe while a task is held;
  - auto-scroll works up and down on the SE and iPhone 17 Pro;
  - the order holds next week and after a relaunch;
  - VoiceOver gets Move Up / Move Down, and the handle is hidden from it.
- **This week only:**
  - on and off restores modes exactly, survives a relaunch, and brings the card back next week;
  - a 1.0.2 card that had it on keeps its tasks one-time when it's turned off, with nothing lost.
- **Smart Add rules:** sessions ("Gym 3 times 45 min" is 2h 15m counting 45, one-time; "Swim 45 min 3x/week" repeating) and lists.
- **Rename fields:** they wrap, Return saves with no line break, and pasted lines are joined.
- **Dates:**
  - every week start is right through the daylight-saving weeks in New York, Sydney, Santiago and Tokyo;
  - travelling from UTC+14 to UTC−11 keeps everything;
  - the week boundary across zones carries tasks and folds;
  - nothing computes days as a fixed 24 hours.
- **Settings:** every theme restyles at once. Also fine:
  - System dark mode switched live;
  - Week start Sunday/Monday with folded lists and This week only cards;
  - Help describes folding;
  - the Welcome Tour;
  - Feature Ideas, ticking and typing only, never sent;
  - Support and Privacy open the right pages;
  - the version shown matches the project.
- **iPad:**
  - reorder in both orientations;
  - fold beside closed cards;
  - the type/mode popover with the keyboard up;
  - narrow (375 pt) and short (486 pt) windows;
  - popovers and Settings through rotation;
  - the emoji sheet;
  - ⌘N for a second window.
- **App Review checklist:**
  - the privacy manifest's reasons and data types;
  - the calendar purpose string;
  - export compliance (`ITSAppUsesNonExemptEncryption` NO);
  - the Support and Privacy URLs answer;
  - every launch argument is debug-only;
  - no placeholder text, no other platforms named, no purchases or accounts.

## Try on your phone
About five minutes, most important first.
1. **When 1.0.3 is on TestFlight, install it over your App Store 1.0.2.** Is every card, task, check, goal amount, item and setting still there, in the same order, with no welcome screens? Check last week, this week and next week.
2. **Fold the long lists in your Tasquel card and close the app.** Reopen it: still folded, showing "x of y"? Next Monday, are they still folded?
3. **Drag a task by its handle to the bottom of a long card.** Is the auto-scroll speed comfortable? Does the task land where you let go? Do the lift, ticks and drop haptics feel right, or too busy?
4. **In a card's edit mode, start a scroll with your thumb on a handle at the right edge.** Does it lift a task by accident?
5. **Switch the theme Retro → Light → Retro a few times in Settings.** Does the app icon change each time, with iOS's alert (finding 8)?
6. **With Apple Intelligence, Smart Add these:**
   - "Gym 3 times a week, 45 min each"
   - "Study 2 hours for 3 sessions"
   - "Bugs"
   - "Groceries: milk, eggs"

   Are the titles clean ("Gym", "Study"), and is no list given its own name as an item?
7. **Mid-drag, pull down Control Center.** Does the task land where it was, and does swiping between weeks still work after?
8. **With VoiceOver on, fold a list.** Does focus stay on the arrow, and do you hear "Expand list" and the name? In edit mode, are Move Up and Move Down offered on a task?
9. **Paste a shopping list from Notes into a list's Add Item** (finding 5). Then rename a task, fix a typo in the middle of a word and press Return (finding 6).
10. **On an iPad, if you have one:** put two Tasquel windows side by side and type in one. Does the other window's bottom bar change as if the keyboard were its own? Does an edit in one show in the other at once?

## Files
- `reports/`: each reviewer's report.
- `tests/`: every test they wrote. UI tests go in `TasquelUITests/` and Code's in `TasquelTests/`. Update has three parts: `old-project-UITests/` for the 1.0.2 copy, `new-project-UITests/`, and `scripts/`, the data-level update check.
- `evidence/`: the screenshots and data dumps cited above.
- `briefs/`: what each reviewer was told.
- `plan.md`: the preflight facts.
- `changes-since-1.0.2.diff`: the diff the reviewers read.
- `submission-notes.md`: draft App Store Connect text.
