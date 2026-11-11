# Code review: Tasquel 1.0.3

(Saved from the reviewer's final message. The reviewer's tool was refused when it tried to write this file.)

I found two bugs, both in what changed since 1.0.2. Edits made while a card is This week only are silently undone once the switch goes off (Rejection risk, data loss). Undo of a delete also unfolds a list that was folded after the delete (Minor).

How I worked: I read the code and used my simulator only for unit tests (iPhone 17 Pro, iOS 26.3). I read the whole 1.0.2→1.0.3 diff and the code behind it: store, models, sync, This week only, folding, reorder, auto-scroller and the Smart Add rules. I also went through the App Review checklist.

The four tests for these findings fail in each of 3 separate runs. All 181 existing unit tests pass.

## 1. Findings

### F1. Edits made while This week only is on are undone once it's turned off
- **Severity:** Rejection risk (silent data loss). An App Reviewer is unlikely to reach it, but anyone planning next week will.
- **Device and settings:** any device; this is store logic. Tested with a New York clock.
- **Steps:**
  1. This week, have a card "Trip" with a repeating task "Stretch", or a repeating list "Packing" holding "Passport".
  2. Go to next week, open Trip's own edit mode and turn This week only on.
  3. Rename "Stretch" to "Yoga", or add "Sunscreen" to Packing, or count progress on a carried goal (6 km).
  4. Turn This week only off, or add a repeating or carry-over task, which also turns it off.
  5. Go to this week and back. Or just wait until next week becomes the current week, when it gets its final sync.
- **Expected:** "Yoga", "Sunscreen" and the 6 km stay. The spec says turning it off gives the tasks "their modes back exactly as before", so only the mode should go back.
- **Actual:**
  - the name goes back to "Stretch";
  - "Sunscreen" is deleted, leaving just "Passport";
  - the progress goes back to the source's, which is none.
- **Evidence:** these three tests fail, and print `REVIEW: rename after TWO off -> ["Stretch"]`, `list items after TWO off -> ["Passport"]` and `goal progress after TWO off -> nil`:
  - `ReviewCodeThisWeekOnlyEditTests/renameWhileThisWeekOnlySurvivesTurningItOff`
  - `listItemsSurviveTurningOffByAddingTask`
  - `goalProgressSurvivesTurningOff`
- **Likely cause (`ChecklistStore.swift`):**
  - In `restoreModes`, line 1183 sets `isUserEdited = saved.wasUserEdited`. That value was recorded when the switch went on (`madeOneTime`, line 1167), so any edit made since is thrown away.
  - The copy then looks untouched, and sync makes it follow its source again. For repeating tasks, `syncRecurringTasks` (line 974) calls `followingRepeating`, which takes the source's title (line 1014) and drops items the source doesn't have (line 1024).
  - For carry-over copies, `following` (lines 913 and 916) does the same with the title and the goal progress.
  - Adding a repeating or carry-over task takes the same path, through `keepCategory` (line 1158).
- **Suggested fix:** one rule, so an edit made while the card is This week only still counts after it goes off. Wherever a change sets `isUserEdited = true`, also set `modeBeforeThisWeekOnly?.wasUserEdited = true`. That covers renaming, changing the type, the goal's target, step and progress, and adding, renaming or deleting a sub-task. A single helper keeps it in one place, and `restoreModes` itself needs no change.

### F2. Undo of a delete also unfolds a list folded after it
- **Severity:** Minor.
- **Device and settings:** any.
- **Steps:**
  1. Delete a task. "Deleted … · Undo" appears.
  2. Within 5 seconds, fold a list in any card. By design, folding keeps the Undo.
  3. Tap Undo.
- **Expected:** the task comes back and the list stays folded. The spec says folding "isn't an edit" and "a delete's Undo stays".
- **Actual:** the list unfolds too, and so do its copies in later weeks.
- **Evidence:** `ReviewCodeFoldTests/undoKeepsLaterFold` fails, printing `REVIEW: fold after undo -> Optional(false)`.
- **Likely cause:**
  - `undoLastDelete` (`ChecklistStore.swift:1683`) puts back the whole `weeksBeforeDelete` snapshot.
  - `setListFolded` (lines 1412–1419) and `foldLaterCopies` change `weeks` without updating that snapshot.
- **Suggested fix:** in `setListFolded`, apply the same fold to `weeksBeforeDelete`, running `foldLaterCopies` on it too. Ending the Undo when folding would be simpler, but it changes the spec.

## 2. Checked and fine
- **Dates and daylight saving** (unit tests with a fixed Gregorian calendar for each time zone):
  - No days are computed as a fixed number of seconds. The only `addingTimeInterval` is the debug-only demo clock.
  - Every half hour across the weeks the clocks change finds the right week start, with weeks starting Monday or Sunday. Zones tested:
    - New York (8 March and 1 November 2026);
    - Sydney;
    - Santiago, whose clock-change Sunday has no midnight;
    - Tokyo, which has no DST (also the year-end week).
  - Paging one week forward or back through each change lands on the right week.
  - Sunday 23:30 is still that week; Monday 00:30 starts the new week, with no duplicate week.
  - Calendar events fall on the right day of a 23- or 25-hour Sunday.
  - A saved week's start day doesn't move when the time zone changes.
- **Folding lists:**
  - the fold is saved and isn't an edit, so the copy keeps following its source;
  - it reaches untouched copies in later saved weeks, even across an unsaved week in between, but not copies the user edited;
  - past weeks can't be folded;
  - a 1.0.2 `checklist.json` loads;
  - bad values in `isListFolded` or `modeBeforeThisWeekOnly` don't stop the file loading.
- **This week only:**
  - untouched copies follow their task again after it's turned on and off;
  - turning it on in this week removes untouched copies from a saved next week, and turning it off brings them back.
- **Reordering tasks:**
  - the landing place is right with tasks of mixed heights, in both directions and to either end;
  - a drop is ignored if the card's tasks changed during the drag;
  - the drag ends when edit mode ends or the card goes away;
  - `isReorderingTask` is set at the first touch, before the week swipe's 20 pt;
  - holding to move a card only works on closed cards;
  - next week keeps its own order (`userOrderedCategories`);
  - the display link stops when the drag ends.
- **Smart Add sessions:**
  - the right total, step, days and mode for "Swim 45 min 3x/week", "Run 4 times a week 30 min", "Pomodoro 4x 25 min", "Tennis twice 1 hour", "Read 20 pages 3 times a week" and "Yoga 3 classes of 60 min";
  - "8 times" and "5 days a week" aren't read as sessions;
  - a list's own title is dropped from its items.
- **Rename fields:** Return saves without the line break. Return in an empty field keeps the old name.
- **App Review checklist:**
  - **Privacy manifest:** UserDefaults (CA92.1) and active keyboards (54BD.1) are declared. No file-timestamp, boot-time or disk-space APIs are used. Tracking is off, and the survey's two data types are declared.
  - **Build settings:** the calendar purpose string is clear, and `ITSAppUsesNonExemptEncryption` is NO.
  - **Links:** the Support and Privacy URLs return 200, and Support has contact details.
  - **Debug-only paths:** every launch argument is inside `#if DEBUG`.
  - **Text:** no "coming soon", "lorem" or "TODO", and no other platforms named.
  - **Payments and accounts:** no In-App Purchase and no accounts.
- **Existing tests:**
  - **What they cover:** This week only modes coming back and surviving a relaunch, folding basics, the session phrases, the reorder maths and the auto-scroll speed.
  - **Riskiest gaps:**
    - edits made while This week only is on (F1);
    - the Undo snapshot versus saves that aren't edits (F2);
    - DST weeks: there were no DST tests before mine;
    - `TaskAutoScroller.begin` finding the right scroll view, which only a UI test can show;
    - a drag the system cancels (the `isHoldingHandle` reset).

## 3. My test file
`tests/Code/ReviewCodeTests.swift` (from `TasquelTests/` in the reviewer's copy). Run it with `-only-testing:TasquelTests`.

- **F1:** in `ReviewCodeThisWeekOnlyEditTests`, `renameWhileThisWeekOnlySurvivesTurningItOff`, `listItemsSurviveTurningOffByAddingTask` and `goalProgressSurvivesTurningOff`.
- **F2:** `ReviewCodeFoldTests/undoKeepsLaterFold`.
- **Checked and fine (all pass):**
  - `ReviewCodeThisWeekOnlyEditTests`: `untouchedCopyStillFollows`, `onAndOffInThisWeekReachesSavedNextWeek`
  - `ReviewCodeFoldTests`: `foldReachesCopiesOverSkippedWeek`, `foldIsNotAnEditAndPastIsReadOnly`, `oldFileLoadsAndNewFieldsSave`
  - `ReviewCodeDSTTests`: `everyHourFindsItsWeek`, `pagingThroughTheChange`, `rolloverAtTheWeekEnd`, `eventsGroupByCalendarDay` (each over 10 zone and week cases), and `savedDayStaysOverZoneChange`
  - `ReviewCodeSmartAddTests`: `morePhrasings`; `probe` only prints what the rules make of other phrasings
  - `ReviewCodeReorderTests`: `mixedHeights`, `autoScrollEdges`, `moveTaskKeepsOrderAcrossSync`

I wrote no UI tests, since my role was reading the code.

## 4. Couldn't check in a simulator (phone checklist)
- **Auto-scroll:** drag a task by its handle to the bottom of a long card. Is 900 pt/s at the edge too fast, and does the task stay under your finger while the cards scroll?
- **Thumb on a handle:** in a card's edit mode, scroll with your thumb starting on a handle at the right edge. Does it lift a task (it lifts at the first touch) and drop it somewhere you didn't mean?
- **Haptics:** there's a firm tap on lift, ticks as tasks slide past, and a light tap on drop. Is it too much on a long drag?
- **Interrupted drag:** pull down Control Center, or take a call, in the middle of a drag. Does the task land where it was, and does swiping between weeks still work afterwards?
- **Smart Add titles:** with Apple Intelligence on, try:
  - "Gym 3 times a week, 45 min each"
  - "gym 3x 45 min per session"
  - "Study 2 hours for 3 sessions"

  Is the title just "Gym" or "Study"? The rules alone leave "Gym , each", "Gym per session" and "Study for", so this only shows on a device if the model keeps those words in its title.
- **Smart Add lists:** with Apple Intelligence on, add "Bugs" and "Groceries: milk, eggs". Is the list's own title never added as an item?
- **Smart Add highlight:** Smart Add a task, then tick another task in the same card within a second. Does the tick show at once? `TaskRowCard.swift:331` changes the store inside `withAnimation` after an `await`, which the spec's own rule forbids.
- **Rename fields:** does Return save a long name on the iPhone keyboard, on an iPad with a hardware keyboard, and with dictation?
- **Fold animation:** fold and unfold a long list with Reduce Motion off and on. Does anything below it jump?
