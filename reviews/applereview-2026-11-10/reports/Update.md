# Update reviewer: 1.0.2 (10) to the new build

(Saved from the reviewer's final message. Its tool was refused when it tried to write this file.)

**Read this first: no UI test ran, so there are no screenshots.** My simulator (iPhone 17 Pro, iOS 26.3) never launched the XCUITest runner. On three tries xcodebuild hung at install or launch ("Invalid device state") while the host load average sat at 700–1000. About 35 minutes went on that.

To test the update path anyway, I compiled the app's own unmodified `ChecklistStore.swift` and `Models.swift` from each copy for macOS. A small driver makes the same store calls the UI makes (addTask, addSubtask, toggles, rename, delete, setCategoryThisWeekOnly, navigateToDate). 1.0.2's code wrote the files and the new code read them. I moved the store's clock by +7 and +14 days to get a real rollover. The runs are deterministic, and each was run at least twice. The app has no sync, so this covers local data only.

## Findings

### 1. A carry-over copy from 1.0.2 in a "This week only" card still says Carry Over, then quietly doesn't carry
- **Severity:** Minor. The label misleads and the task drops out a week later, but the user can recover it.
- **Device:** store code, on the files 1.0.2 writes.
- **Steps (in 1.0.2):**
  1. This week, Study: add the carry-over task Essay.
  2. Next week, Study's edit mode: turn This week only on.
  3. Back in this week: add the carry-over list Flashcards (item Deck 1) to Study.
  4. Open next week. Sync copies Flashcards into the This week only card, still carry-over.
  5. Update to the new build.
- **Expected:** the new rule (`arriving`, spec "This week only on a card") makes such copies One-Time and remembers Carry Over. The new build does exactly that on its own data with the same steps (`Flashcards | list oneTime … before=carryOver/false`).
- **Actual:** with 1.0.2 data, next week's Study shows `Flashcards | list carryOver` under the note "It won't come back next week". A week later (+7 days) the week after has no Study and no Flashcards. The unfinished task that was labelled Carry Over is gone.
  - 1.0.2 loses it the same way, so this isn't a regression.
  - But the new build fixes only new arrivals and leaves the old ones misleading.
- **Evidence:**
  - `Update/shots/evidence/weeks-new-on-1.0.2-data-today.txt` (week+1, Study)
  - `Update/shots/evidence/weeks-new-on-1.0.2-data-plus7days.txt`
  - `Update/shots/evidence/weeks-new-on-new-data-today.txt` (contrast with the new build's own data)
  - `update_check.sh --store-only` prints "FINDING still there: carry-over copy in a This week only card".
  - UI test, not run: `ReviewUpdateCheck/testOldCarryOverCopyInThisWeekOnlyCardIsOneTime`. The matching seed steps are in `ReviewUpdateSeed`.
- **Likely cause:**
  - `arriving()` (`ChecklistStore.swift:1174`) is applied only when sync appends a copy (the append sites around lines 867 and 1001).
  - `loadAndPrepare` (`ChecklistStore.swift:156–171`) never fixes up tasks already in a This week only card.
- **Suggested fix:** in `loadAndPrepare`, next to `saveThisWeekOnlyCategories()`, pass every non-one-time task in a current or future This week only card through `madeOneTime`. Keep its `isUserEdited`, don't note an edit, and save once. `syncMode` keeps it following its source, like a new arrival.

### 2. Turning This week only on and straight off rebuilds next week's card: a fold made there is lost and next week's own task moves
- **Severity:** Minor. One action visibly changes another week.
- **Device:** store code, on 1.0.2 data and on new data.
- **Steps:**
  1. Next week: fold Groceries (a carry-over list copied from this week). Errands there also has its own "Next week task", last.
  2. This week, Errands' edit mode: turn This week only on, then off.
  3. Open next week.
- **Expected:** the spec says "a fold changed in a later week stays (sync never touches it)" and that turning the switch off gives the tasks back "exactly as before". Next week should be unchanged.
- **Actual:** this week's modes come back correctly, but next week's untouched copies were deleted and made again.
  - Groceries is open again (`folded=false`).
  - Next week's order went from Groceries, Laundry, Buy stamps, Weekly list, Next week task to Groceries, **Next week task**, Laundry, Buy stamps, Weekly list.
  - It reproduces identically every run. 1.0.2 was worse here (it lost the modes for good).
- **Evidence:**
  - `Update/shots/evidence/action-fold-in-next-week-only.txt` (folded before)
  - `Update/shots/evidence/action-roundtrip-loses-next-week-fold.txt` (open after)
  - `Update/shots/evidence/action-roundtrip-errands.txt` (the order)
  - `Update/shots/evidence/action-roundtrip-in-1.0.2-control.txt` (1.0.2)
  - UI test, not run: `ReviewUpdateRoundTripTests/testThisWeekOnlyRoundTripKeepsNextWeeksFoldAndOrder`.
- **Likely cause:**
  - Turning it on removes later weeks' copies that aren't `isUserEdited` (`ChecklistStore.swift:1137–1146`). A fold deliberately isn't an edit (`setListFolded`, line 1412).
  - Turning it off restores only this week (`restoreModes`, line 1179). Sync then recreates next week's copies from this week's tasks, with this week's fold, and `orderLikeSource` (line 882) places them around the user's own task.
- **Suggested fix:** when turning it on, keep a later copy whose fold differs from its source's, as the user's own. Or keep the removed copies with the card, like `modeBeforeThisWeekOnly`, and put them back in place when it's turned off.

## Checked and fine
All of these are store-level checks on 1.0.2 data read by the new build.
- **Decoding:** 1.0.2's `checklist.json` decodes and re-encodes with every old value identical.
  - The only addition is `isListFolded: false` on all 26 tasks; `modeBeforeThisWeekOnly` is absent, as it should be.
  - `compare_data.py` finds 0 unexpected differences.
- **Same data in both versions:** 1.0.2's code and the new code give identical current, next and following weeks:
  - today;
  - at +7 days (rollover plus the saved week's final sync);
  - at +14 days (a skipped week).
- **Carry-over copies into next week:** Groceries keeps its unchecked items, Buy stamps is renamed, and the Stretch time goal stays at 9m/1h.
- **Repeating copies into next week:**
  - Laundry's sub-tasks are reset.
  - Run starts again at 0/10.
  - Read keeps its custom unit "pages", step 10 and 5 days.
  - Repeating lists keep their checks, as in 1.0.2 (`keepsItems`).
- **What doesn't come along:** the done one-time task stays behind and the deleted task stays deleted. Nothing is duplicated or moved to another day.
- **Folding:** 1.0.2 lists load open. Folding one also folds next week's copy (saved by 1.0.2) and the preview week after it.
- **A card that had This week only on in 1.0.2:** turning it off keeps its tasks one-time, loses nothing and doesn't crash. The card comes back next week, empty.
- **This week only on/off for a 1.0.2 card that never had it:** modes and `isUserEdited` come back exactly.
- **Settings:** Dark and Sort Cards are kept, saved categories are unchanged, and the diff changes no UserDefaults keys.
- **Sync:** for old data `syncMode` equals `mode`, so follow, remove and dismiss work as they did in 1.0.2.

## Test files
- **Old copy (`old-project/TasquelUITests/`):**
  - `ReviewUpdateSeed.swift`: `testSeedLiveData` uses real storage, goes through onboarding, and creates every type, mode and state, plus Finding 1's setup and Dark.
  - `ReviewUpdateShots.swift`: `testDumpScreens` takes a screenshot and the accessibility tree for every card over three weeks, plus Settings.
- **New copy (`project/TasquelUITests/`):**
  - `ReviewUpdateShots.swift`: the same walk.
  - `ReviewUpdateCheck.swift`, covering the areas above:
    - `testOldDataLoadsIntactAcrossRelaunches`
    - `testCarryOverAndRepeatingCopiesFromOldData`
    - `testOldSettingsKept`
    - `testFirstSaveInNewVersionKeepsEverything`
    - `testOldListsLoadOpenAndFold`
    - `testThisWeekOnlyOffOnOldCardKeepsTasksOneTime`
    - `testThisWeekOnlyRoundTripOnOldTasks`
    - `testOldCarryOverCopyInThisWeekOnlyCardIsOneTime` (Finding 1)
  - `ReviewUpdateRoundTripTests.swift`: `testThisWeekOnlyRoundTripKeepsNextWeeksFoldAndOrder` (Finding 2).
  - **None of these UI tests has been run yet**, so the first run may need label or timing fixes.
- **`shots/update_check.sh`:**
  - Step 0 needs no simulator and has run (output in `shots/run-072458/`). It reports the same results as 1.0.2 at +0, +7 and +14 days and flags both findings.
  - Steps 1–5 are written but haven't run: build both copies, uninstall, seed with 1.0.2, copy data-before, `simctl install` the new build over it, the same walk, data-after, tree diff, the checks, and data compares after the edits.
- **Helpers:**
  - `shots/compare_data.py`: diff of the saved JSON and plist files.
  - `shots/storeharness/`: the store driver and the 1.0.2 seed.
  - `shots/roundtrip/`: decode and re-encode.
  - `shots/shift_weeks.py`: an alternative way to move the data back a week; not used.
- **Store-level snapshots:**
  - `shots/data-before/`: as 1.0.2 saved it.
  - `shots/data-after/`: the new build after launch.
  - `shots/data-after-old-control/`: 1.0.2 after launch.

## Couldn't check in a simulator (phone checklist)
- Install the 1.0.3 TestFlight build over App Store 1.0.2 on a phone with real data. Does onboarding stay away? Is every card, task, check, goal amount, item and setting still there, in the same order?
- After updating, look at last, this and next week. Is anything missing, doubled or on the wrong week?
- Fold a list made in 1.0.2, then open next week. Does it show "2 of 5", and is it still folded after a relaunch?
- Turn off This week only on a card that had it on before the update. Do its tasks stay one-time, with nothing gone?
- Leave the updated app over a week change (Monday or Sunday morning). Do carry-over and repeating tasks each arrive once?
- Drag an old task by its handle in a long card. Does the auto-scroll speed feel right?
- Rename a long old task. Does the field wrap, and does Return save?
- Take before and after screenshots of every screen; my simulator never got that far.
