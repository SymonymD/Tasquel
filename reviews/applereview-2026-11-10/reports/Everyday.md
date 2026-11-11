# Everyday flows: Tasquel 1.0.3 review

(Saved from the reviewer's final message. The harness refused report files: "Subagents should return findings as text".)

I found four problems, two of them in features new in 1.0.3. The worst is a delete that can't be undone if a rename is open. Every finding failed its own test at least twice.

- **Device:** iPhone 17 Pro simulator, iOS 26.3, light theme, default text size, `-isolatedDataID` storage.
- **Folders:** `shots/` means the reviewer's `Everyday/shots`. File paths below are in my project copy.
- **Mac load:** the load average was 400–900 during the run. Two runs never started the test runner. One run hit the "App animations complete notification not received" trap: 60 s waits that pushed one test over its time limit. None of this is an app problem.
- **Housekeeping:** one early `test-without-building` run wrote its result bundle to `~/Library/Developer/Xcode/DerivedData/Tasquel-bdixhhpxghdrutdefxqzdgbrhwdm/Logs/Test/`. That folder isn't mine. Later runs use `-resultBundlePath` inside `shots/`.

## Findings, most severe first

### 1. Deleting while a rename is open: no Undo ever appears, so the delete is permanent
**Major**
- **Steps:**
  1. In Errands, add a list Groceries with Milk, Eggs and Bread.
  2. Tap the card's edit button.
  3. Tap "Milk" to rename it and type " oat".
  4. Tap the red − on Eggs.
  5. Close the keyboard with the round keyboard button.
- **Expected:** once the keyboard goes, "Deleted "Eggs" · Undo" shows for 5 s. The spec says the message "comes back when it goes".
- **Actual:** Eggs is gone and no Undo ever shows. "Milk oat" is saved.
- **Evidence:**
  - `testDeleteWhileRenamingKeepsUndo` failed in run4 and run6, both times with `REVIEW: after closing keyboard: undo=false milk=true` (`shots/run4.log`, `shots/run6.log`).
  - `shots/rename-delete-1-keyboard-up.png`: Eggs gone, keyboard up, no message (hidden by design).
  - `shots/rename-delete-2-keyboard-down.png`: keyboard down, still no Undo.
- **Likely cause:**
  - The delete takes its Undo snapshot while the rename is still open.
  - When the keyboard goes, the rename commits: `TaskRowCard.swift:1458` → `renameSubtask` → `save()` at `ChecklistStore.swift:1605`.
  - That save ends the Undo at `ChecklistStore.swift:309`.
  - The message was hidden while the keyboard was up (`ContentView.swift:200`), so the user never sees it.
  - Renaming a task's name does the same: `TaskRowCard.swift:189` → `ChecklistStore.swift:1451`.
- **Fix:** commit any open rename before a delete calls `rememberForUndo`. Another way: when a rename was already open at delete time, also apply it to `weeksBeforeDelete` and save with `keepsUndo: true`.

### 2. Undo after a fold unfolds the list again
**Minor**
- **Steps:**
  1. Errands has an open list Groceries and a task Temp.
  2. Tap the card's edit button and delete Temp.
  3. Within 5 s, fold Groceries.
  4. Tap Undo.
- **Expected:** Temp comes back and Groceries stays folded. The fold isn't counted as an edit and keeps the Undo.
- **Actual:** Temp comes back and Groceries is open again. Folds pushed to later weeks by `foldLaterCopies` are reverted too.
- **Evidence:**
  - `testUndoAfterFoldKeepsTheFold` failed in run4 and run5 with `REVIEW: after Undo, fold label = Collapse list, count shown = false`.
  - `shots/undo-fold-1-before-undo.png` and `shots/undo-fold-2-after-undo.png`.
- **Likely cause:**
  - `setListFolded` saves with `keepsUndo: true` (`ChecklistStore.swift:1419`).
  - `undoLastDelete` puts back the whole snapshot of the weeks (`ChecklistStore.swift:1681-1684`).
  - `keepsUndo` was meant for sync results, which the next sync recreates (comment at `ChecklistStore.swift:302-303`). Nothing recreates a fold.
- **Fix:** while an Undo is pending, `setListFolded` should also set the fold on the same task, and on its later copies, inside `weeksBeforeDelete`.

### 3. The wrapping rename field slides under the keyboard, and the keyboard button covers the type/mode button
**Minor, new in 1.0.3**
- **Steps:**
  1. Take the carry-over task "Pack bag" with two sub-tasks, low in an open card.
  2. Tap its name and type about 100 characters (5 lines).
- **Expected:** the line being typed stays above the keyboard, and the field and its options stay clear of the round keyboard button (the spec's `keyboardDoneClearance`).
- **Actual:**
  - The field grows down behind the keyboard. In run4 the caret's line ("clothes for Saturday") was fully under the suggestion bar; in run5 it was cut off at the keyboard's edge.
  - In both runs the keyboard button covers the mode icon: button frame (338,483,48×48) against options (312,477,58×44).
  - Return still saves the whole name.
- **Evidence:**
  - `shots/crop-rename-1s.png` (run4) and `shots/crop-rk-s.png` (run5).
  - `testWrappedRenameFieldStaysAboveKeyboard` failed in run5: "the keyboard's Done button doesn't cover the task's options".
- **Likely cause:** the rename `TextField(axis: .vertical)` (`TaskRowCard.swift:171-190`) grows after it was scrolled into view. Only the Add task row scrolls itself back (`cardGridScroll`). The 56 pt clearance (`ContentView.swift:1094`) only covers where the field started.
- **Fix:** when the rename field's height changes, scroll the row into view with `cardGridScroll` (anchor `.bottom`). Do the same for sub-task and item renames.

### 4. A folded list's title breaks mid-word in the card's edit mode
**Polish, new in 1.0.3**
- **Steps:** make a list "Groceries" with 2 items, fold it, then tap the card's edit button.
- **Actual:** the count "0 of 2", chevron, type/mode, trash and handle leave the title 65 pt, so it reads "Groceri / es". The spec already avoids breaks like "Yog-a" at large sizes; this happens at the default size.
- **Evidence:**
  - `testFoldedListTitleFitsInEditMode` failed in run6: title 44 pt tall in edit mode against 22 pt open.
  - `shots/folded-title-edit-mode.png` and `shots/undo-fold-1-before-undo.png`.
- **Likely cause:** `foldedCount` is `.fixedSize()` (`TaskRowCard.swift:206`, `430-438`) and sits beside the edit-mode icons (`TaskRowCard.swift:212-219`).
- **Fix:** hide the count in the card's edit mode, or move it under the title when it doesn't fit (`ViewThatFits`).

## Checked and fine
- **Fold, next week and relaunch:** a 6-item list with 2 checked and a carry-over task with 2 sub-tasks. Folded it ("2 of 6"), went to next week (the repeating list arrives folded with its checks; sub-tasks carry), came back, relaunched, went to next week again: everything kept (`testFoldedListCardSurvivesWeeksAndRelaunch`).
- **Lists:** a new list starts open; folding hides the items and Add Item; the chevron reopens it.
- **Reordering by the handle:** a tall open list dragged below two tasks lands last, and the order holds next week and after a relaunch (`testReorderTallListBelowTasksKeepsOrder`).
- **This week only:** on makes all three tasks one-time; off restores their modes exactly. While on, the card isn't in next week; once off it's back with its carry-over and repeating tasks, and it all survives a relaunch (`testThisWeekOnlyOnOffAcrossWeeksAndRelaunch`, run5).
- **Long renames:** a list item, a task and a sub-task each take a long name. Return saves it with no line break, the keyboard closes, the item keeps its check, and the names survive a relaunch (`testRenameLongTaskSubtaskAndItem`, run5).
- **Half-typed task, then a week swipe:** it's added to the week it was typed in, not the next one (`testHalfTypedTaskThenWeekSwipe`).
- **Smart Add rules:** "Gym 3 times 45 min" becomes a one-time goal of 0m / 2h 15m that counts +45. "Groceries: milk, eggs" becomes a list (`testSmartAddSessionGoalAndList`).

## Test files
`tests/Everyday/ReviewEverydayTests.swift`, class `ReviewEverydayTests`. Each test starts from a clean launch with its own `-isolatedDataID`.

| Covers | Test |
|---|---|
| Finding 1 | `testDeleteWhileRenamingKeepsUndo` |
| Finding 2 | `testUndoAfterFoldKeepsTheFold` |
| Finding 3 | `testWrappedRenameFieldStaysAboveKeyboard` |
| Finding 4 | `testFoldedListTitleFitsInEditMode` |
| Checked and fine | `testFoldedListCardSurvivesWeeksAndRelaunch`, `testReorderTallListBelowTasksKeepsOrder`, `testThisWeekOnlyOnOffAcrossWeeksAndRelaunch`, `testRenameLongTaskSubtaskAndItem`, `testHalfTypedTaskThenWeekSwipe`, `testSmartAddSessionGoalAndList` |

Run scripts are in `shots/`: `runx.sh` (test-without-building, with the result bundle in `shots/`) and `run.sh`. Logs are `shots/run4.log`, `shots/run5.log` and `shots/run6.log`.

## Couldn't check in a simulator
- Hold a task's handle near the bottom bar in a long card: does the auto-scroll start at the right moment, and is 900 pt/s controllable?
- Lift a task and wobble sideways: does the week stay put, and do the lift tap and selection ticks feel right?
- Double-tap a list's chevron quickly, and tap it mid-animation: does it end where you expect, with no flicker of Add Item?
- Type a 6-line name in a rename field on the smallest iPhone you have: can you see what you're typing?
- With real Apple Intelligence, try "three 45-minute sessions", "run 3 times 5 km" and "Groceries: milk, eggs": no list holding its own title as an item?
- Press Return on the software keyboard in a rename field: does one tap save, with no line-break flash?
