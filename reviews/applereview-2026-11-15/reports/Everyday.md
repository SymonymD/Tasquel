# Everyday flows: Tasquel 1.1 review (iPhone 17 Pro sim 7C792104…, iOS 26.3, Monday start unless noted, today Sun 2026-11-15)

Shots folder (S): the work root's `Everyday/shots` (the cited ones are copied, shrunk, to `evidence/Everyday/`). Run logs are `S/batch*.log`.

## 1. Findings, most severe first

### F1. Adding from the options popup to another week leaves a keyboard that can't be put away, and the bottom bar disappears. Rejection risk
- **Steps:** Open Errands. Type "Return library books", then tap the type/mode button. Either pick One-Time ▸ calendar ▸ Wed Nov 18 ▸ Set, or pick Thursday in the Day row. Then tap the popup's **Add Task**.
- **Expected:** The screen goes to next week with no keyboard, as happens when you add with Return (`testReturnAddForPastDayClosesKeyboard` passes).
- **Actual:** The keyboard stays up with no text field focused. XCUITest says "Neither element nor any descendant has keyboard focus".
  - The bar (Settings, the week arrows, the house, Edit) is gone.
  - The keyboard-down button does nothing, even tapped twice.
  - Swiping back to this week keeps the keyboard up.
  - The only way out: open some Add Task field, then tap keyboard-down.
- **Reproduced:** 5 times, in both the date version and the day version.
- **Evidence:**
  - `finding-kb-01-popup-add-next-week.png`, `finding-kb-02b-after-keyboard-down.png`, `finding-kb-10-popup-add-past-day.png`, `finding-kb-20-after-swipe.png`, `S/dates-03-popup.png`
  - Tests: `testPopupAddToNextWeekLeavesNoKeyboard`, `testPopupAddForPastDayLeavesNoKeyboard`, `testStrayKeyboardWaysOut` (logs the ways out), and `ReviewEverydayDatesTests.testOneTimeDateNextWeekWhileAdding` (also fails on this).
- **Likely cause:**
  - In the popup's `onAdd` (TaskRowCard.swift:2630-2633), the field still has focus while the popover closes.
  - `changeWeek`'s `dismissKeyboard()` (ContentView.swift:576, 452) runs during the popover's dismissal. UIKit then hands the keyboard back to a responder that's no longer in the chain.
  - `addTask` keeps `isFocused` when `nextWeek != nil` (TaskRowCard.swift:3057).
- **Fix:**
  - When the task goes to another week, set `isFocused = false` before `showOptions = false`.
  - Or, in `addedElsewhereFollower`, wait for the popover to finish closing (~0.35 s) before `changeWeek`, then call `dismissKeyboard()` again.

### F2. Switching Settings ▸ Week to Sunday on a Sunday moves next week's day task a week late and deletes a dated task. Major (data loss)
- **Steps:**
  - With a Monday start, add "Call dentist" for Thursday. It goes to the week of Nov 16, so Thu Nov 19.
  - Add "Review deck" this week and set the clock to Fri Nov 20. It moves to the week of Nov 16.
  - Switch to a Sunday start.
- **Expected:** Nov 15–21 is now this week, so both tasks are in it, on the 19th and the 20th.
- **Actual:**
  - This week's Work card is empty.
  - "Call dentist" is in the week of Nov 22, so Thu Nov 26.
  - "Review deck" is gone. Switching back to Monday doesn't bring it back.
- **Reproduced:** twice.
- **Evidence:** `finding-ws-01-next-week-before.png`, `finding-ws-03-next-week-after-switch.png`, test `testWeekStartSwitchKeepsNextWeeksDayTask`.
- **Cause:** `setWeekStartsOnSunday` (ChecklistStore.swift:568-591) shifts every saved week by +6 days. `dayOfWeek` and `expiresOn` don't move with it, so `removeExpiredTasks` then drops the dated task, whose date now falls before its new week's start.
- **Note:** The spec lists "week-start switches with dated tasks" for 1.2. But it silently deletes the task, and the day-task half comes from the new "day gone by" rule.
- **Fix:** Before shifting, work out each future task's real date (its date, or the old week start plus its day). Afterwards, put it in the week holding that date. At the very least, never let a shift expire a task.

### F3. Add Category: Done (✓) doesn't close the sheet when the name field has text. Major (usability)
- **Steps:** Edit ▸ Add Category ▸ Create New. Type "Garden" without pressing Return, then tap ✓.
- **Expected:** Garden is added and the sheet closes.
- **Actual:** Garden is added, but the sheet stays open saying "Added Garden · add another, or tap Done". The user just tapped Done.
- **Worse case:** With a taken name typed ("Work"), ✓ does nothing at all. The red "already exists" line stays, and nothing else happens.
- **Reproduced:** twice each.
- **Evidence:** `finding-cat-01-done-with-typed-name.png`, `finding-cat-02-done-with-taken-name.png`, tests `testAddCategoryDoneWithTypedNameCloses` and `testAddCategoryDoneWithTakenName`.
- **Cause:** `finish()` in AddCategorySheet.swift:193-199 calls `createNew()` but never `dismiss()`, and `createNew` returns silently when the name is taken.
- **Fix:**
  - After a successful `createNew()`, call `dismiss()`.
  - With a taken name, close anyway, or move focus to the message so the user sees why.

### F4. The "Added to next week" pop-up covers the card's note and its Undo for most of the Undo's life. Minor
- **Steps:** Add a task for Thursday with Return, then just read the pop-up and let it close on its own.
- **Actual:**
  - The pop-up (y 270–436 pt) sits right on top of the note "Thursday had already gone by… Undo" (Undo at y 303).
  - The pop-up lasts 6 s and the note 8 s, so about 2 s of Undo are left once it closes. In one run the Undo was gone 2 s after the pop-up.
- **Reproduced:** twice.
- **Evidence:** `finding-undo-01-popup-over-note.png`, `S/days-02-added-to-next-week.png`, test `testUndoOutlastsTheMovedPopUp`.
- **Cause:** The pop-up is placed in the upper middle with a 6 s timer (ContentView.swift:1753-1768). The note's 8 s starts at the same moment (TaskRowCard.swift:2458-2476).
- **Fix:** Either start the note's 8 s when the pop-up closes, or give the pop-up its own Undo for adds.

### F5. Smart Add "tomorrow" on a Sunday says "Monday had already gone by this week". Polish
- **Steps:** Smart Add "remind me to water plants tomorrow" on a Sunday with a Monday start.
- **Actual:** The pop-up detail and the card note say Monday "had gone by". The user meant tomorrow, Nov 16.
- **Evidence:** `smart-02-tomorrow.png`, `smart-03-next-week-note.png`, from `testSmartAddDaysOnSunday`.
- **Cause:** `handOverDetail` and `nextWeekMessage` in TaskRowCard.swift:2951-2954 phrase it the same way for every day.
- **Fix:** When the day is still ahead of today ("tomorrow"), say "Monday is in next week".

## 2. Checked and fine
- Day row Thursday on Sunday: "Add Task for Next Thu", "Added to next week" pop-up, Back to This Week, kept after relaunch.
- Sunday start: Sunday pill first, Monday stays this week ("Add Task for Mon"), Sunday task reads "Today" and sorts first, kept after relaunch.
- An existing task given a past day (Tuesday) stays put and isn't late; today's pill doesn't show it.
- Day filter: line "Thursday and tasks with no day"; adding with a past-day filter goes to next week and the filter stays; Sunday pill; Show All.
- One-Time dated next week while adding: pop-up, card note, row value Wednesday, note Undo removes it.
- Carry Over dated about 75 days out stays here and carries.
- One-Time dated about 75 days out moves to the week of Jan 25 ("Moved to the week of Jan 25"), the house shows, Back to This Week works.
- After relaunch, Go to Week shows a purple ring on Jan 29 and both tasks are in that week; both are gone the week after.
- Clock: today's date makes "Today · Nov 15"; a date next Friday moves the task, with the pop-up.
- Smart Add:
  - "Call mom Sunday" reads Today.
  - "Gym Mon Wed Fri" makes a repeating goal of 3.
  - "dentist december 15": the Set Date offer stays past 10 s and after the keyboard closes, and Set Date moves it to Dec 14.
  - "Pay rent by december 1" becomes Carry Over and stays here.
  - Undo Smart Add works.
- Pins: two cards and two tasks; a third is disabled; the order holds through a relaunch, comes back when unpinned, and next week follows.
- Add Category three times in one sheet: "Added X", Just this week off again after each add, a taken name is refused, Edit ends.
- The card's own Just this week chip on then off: the repeating mode is restored and the card comes back next week.
- Duplicates: task (case-insensitive) and list item marked; note Undo removes the duplicate and the mark.
- Clearing a task's or sub-task's name and pressing Return deletes it, with Undo restoring it in place.
- Half-typed task, then Home and back: it's added, and kept after relaunch.
- Options popup open, then Home and back: the order holds and the task moves into place after Done.

## 3. Test files (in `tests/Everyday/`)
- **ReviewEverydayBase.swift:** shared helpers.
- **ReviewEverydayFindingsTests.swift:**
  - F1: `testPopupAddToNextWeekLeavesNoKeyboard`, `testPopupAddForPastDayLeavesNoKeyboard`, `testStrayKeyboardWaysOut`; the control test `testReturnAddForPastDayClosesKeyboard` passes.
  - F2: `testWeekStartSwitchKeepsNextWeeksDayTask`.
  - F3: `testAddCategoryDoneWithTypedNameCloses`, `testAddCategoryDoneWithTakenName`.
  - F4: `testUndoOutlastsTheMovedPopUp`.
- **ReviewEverydayDaysTests.swift** (4, all pass): day row, Sunday start, filter, past day on an existing task.
- **ReviewEverydayDatesTests.swift:** `testMonthsAwayCarryOverAndOneTime` and `testClockDateThisWeekAndNextWeek` pass. `testOneTimeDateNextWeekWhileAdding` fails on F1.
- **ReviewEverydaySmartAddTests.swift** (2, pass): F5 is logged in `testSmartAddDaysOnSunday`.
- **ReviewEverydayCardsTests.swift** (4, all pass): pins, Add Category and chip, duplicates, clear name.
- **ReviewEverydayLifecycleTests.swift** (2, pass).

The Mac's load average was 130–430 during these runs. One early run of the clear-name test timed out from load and passed on its re-run.

## 4. Couldn't check in a simulator (phone checklist)
- Add a task with a date or a past day from the options popup's Add Task: does the keyboard stay up on iOS 27.2 too?
- Open the app on a weekday with tasks due: does each card with today's tasks wiggle once, and does "Today" pulse? (Both are off with throwaway data.)
- Let a day go by with a day task unfinished: does it read "Tue · late", and does today's pill show it?
- Set an expiration for tomorrow: does the 9 AM reminder arrive, and does the permission prompt come at that moment, not at launch?
- With Apple Intelligence: does "Go to the zoo and harass penguins" become a list named "Go to the zoo"? Does "dentist december 15" still offer Set Date?
- Thanksgiving week (from Nov 23): do the turkey and feathered mark show once per app open?
- Does the pop-up's 6 s, followed by the note's last 2 s, feel long enough to reach Undo?
