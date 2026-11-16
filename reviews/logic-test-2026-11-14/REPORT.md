# Tasquel 1.1 logic and new-user test: 2026-11-14

Before submitting 1.1, the user asked for:
- a logic test of the 1.1 additions, looking for conflicts among them and with older features, using three personas with several goals each;
- a test as a brand-new user who skipped the welcome tour and Help.

The code tested was `release-1.1` at 8897d91, plus that day's uncommitted work: dates in the options popup, the date clock, Smart Add dates, and the 2026-11-10 review leftovers (11, 16, 17, 21, 22).

## How it was tested
- **Three persona testers**, one each for Maya (grad student), Dan (parent running the household) and Priya (freelancer training for a race). Each wrote scenario tests of the data layer (`ChecklistStore`) with a fake clock, playing several weeks per goal. After every step they checked:
  - task IDs are unique;
  - copies follow the rules;
  - dated tasks are gone on time;
  - there's one reminder per task;
  - there are at most two pins;
  - duplicates are flagged;
  - everything survives saving and reloading.
- **A new-user tester** drove a fresh install with XCUITest. It skipped the welcome tour and learned the app only from screenshots and on-screen labels (no code, Help, notes or existing tests).
- **I re-ran** all 66 persona tests together in one copy. The same 112 checks failed that the testers reported, so every finding below is reproduced. Which findings are already in the live version was settled with `git blame` and `git merge-base`.

Tests: `tests/` (`PersonaMayaTests`, `PersonaDanTests`, `PersonaPriyaTests`: unit tests that reproduce every finding; `NewUserExploreTests`: the exploration steps, meant to run in order). New-user screenshots: `evidence-new-user/`.

## Fix before submitting (new in 1.1 or today; recommended)
1. **"until 12/15" and "due 12/15" are offered as today.**
   - Foundation's detector reads them as a range starting now, and `TypedDate.find` takes `match.date`. "Run 3x per week until 12/15" would end today.
   - Checked on the Mac: the duration is 31 days, and the date is now.
   - Fix: use the end of a range (`date + duration`).
   - Repro: `PersonaPriyaTests/reproUntilDateIsToday`.
2. **Fractions are read as dates.**
   - "Run 3/4 mile" is offered as Mar 4. "Swim 1/2 mile 3x per week" is offered as Jan 2 and named "Swim mile 1/2".
   - Fix: skip a slash date followed by a unit or "of"; when Smart Add changes the words, keep the date where it was typed.
   - Repro: `reproFractionAsDate`.
3. **Reminders go stale or wrong.** They read saved later weeks that haven't caught up with the week before; a saved later week syncs only when viewed. Results:
   - a reminder for a task already checked off;
   - one on the old date as well as the new one;
   - one under the old name as well as the new one;
   - one for a copy that was deleted;
   - one for a task in a This week only card that ends first.

   Cause: `expiryReminders` (`ChecklistStore.swift` ~955–985) reads `weeks` as saved, and its fallback ignores the saved week. Fix: decide each reminder from its week as sync would leave it (`previewWeek(for:)`). Found by all three personas.
4. **Two reminders for one task, or one shared by two tasks.**
   - Cause: the key is card, title and date (:963).
   - A renamed copy gets its own reminder. Two same-named tasks share one, so checking the first silences the second's.
   - Fix: key by the original task (follow `carriedFrom`/`repeatsFrom`) plus the date.
5. **More than two pins.**
   - Through sync: copies keep `isPinned` (`carriedCopy`, `resetRecurringTask`), and a card re-added by sync keeps its pin.
   - Through Undo: a pin is also made in Undo's snapshot, which still holds the deleted pinned item.
   - Fix: cap pins in `arriving(_:in:)`, on a card re-added by sync, and in the snapshot.
6. **Moving a date to a later week keeps the day the old date set.** The task shows "Thu · late" after its last day.
   - Fix: in `setTaskDate`, clear a day that came from the old date.
7. **A new task dated through the add row and Smart Add can stay One-Time and vanish before its date.**
   - The row's `pickedMode` only marks a change. Separately, a picked date can override Smart Add's Repeating.
   - Fix: apply `dateMode`/`dateWeekday` in `addParsedTask` whenever `lastDay` is set: one place for the rule.
8. **A date typed while viewing a later week becomes next year's**, and the slash-date reader uses the real clock.
   - Fix: judge "gone by" against today, and take the year from the store's clock.
9. **Settings ▸ Reminders still says dates are set "with the clock in a card's edit mode".** Fix the wording (`SettingsSheet.swift:358`).
10. **Undo just after midnight brings back a task past its last day.** Fix: `removeExpiredTasks()` after `undoLastDelete`.

## Decisions needed (two rules collide)
11. **Dating a task in a This week only card past this week turns the card into an every-week card**, silently: "a date after its week makes Carry Over" meets "a carry-over turns This week only off".
    - (a) The hint says so ("…and this card comes back next week"), as the mode hint already does.
    - (b) In those cards, offer dates only within this week.
    - Recommended: (a).
12. **Picking One-Time for a task dated weeks out**: it's gone after this week, before its date, with no reminder.
    - (a) The hint warns.
    - (b) The date wins and it stays Carry Over.
13. **Switching the week start with dated tasks present.** Rare, but:
    - a task dated on the old week's Sunday shows late and is gone before its date;
    - a whole-week date runs a day into the next week.

    Fix: re-apply the date rules after the switch. Medium effort: now or 1.2.
14. **A dated task's history.** When its date passes it's removed from the current week, so the week, once over, no longer shows it (only if the app was opened that day), and the ring drops mid-week. The spec says past weeks keep it. Suggested for 1.2: hide rather than delete.

## For 1.2 (already in the live version, or design questions)
- Two same-named carry-over tasks: the second doesn't reach an already-saved next week (`syncCarryOverTasks` title match, live since 1.0.x). It contradicts Duplicates' "nothing merged".
- Repeating lists follow items by name (live since Oct): removing a duplicate "Milk" doesn't reach next week, and a second "Eggs" never arrives. A deleted item that was checked stays in next week's copy.
- Next week's card ring starts half full from a repeating list's kept checks (the 1.1 ring meets the older list rule).
- Filtering by today's day hides late tasks.
- Undo loses a fold or pin made in a later week that wasn't saved yet.

## New user (fresh install, no tour, no Help)
- **Easy:**
  - adding tasks;
  - making one repeat (once the options pill was found);
  - a list;
  - a goal and logging it;
  - checking off;
  - renaming;
  - pinning or moving a card;
  - next and last week;
  - a new card;
  - dark mode.
- **With trouble:**
  - **A birthday on a date.** It works, but it's a "last day": the task shows every week until then. Five words name the one feature ("Add a date", "Until", "Expires", "last day", "Carries over until"). The switch to Carry Over is silent, and the reminder time appears only in Settings.
  - **Delete.** Swiping left changes the week; long-press does nothing; delete is only in the card's edit mode.
  - **A Friday task on a Saturday.** It's late at once, and nothing warned.
- **Top suggestions:**
  - the task options pill reads as a status badge (a check and a "1"): show the mode as a word;
  - swipe actions or a long-press menu on tasks;
  - one name for dates, and a reminder line in the calendar;
  - a longer Undo;
  - a visible way back to this week;
  - dim past days in the Day row;
  - focus the field when "Tap to add" opens a card;
  - open-task bullets in closed cards are red and read as errors.
- **Not bugs:**
  - no notification prompt appeared because test mode skips it (`requestPermissionIfNeeded`). Check on a device.
  - About says 1.0.3 (11): the version bump is still to do.

## Status (2026-11-14, after fixes)
The user picked 1–10, recommendation (a) for 11 (the hint says the card comes back) and the warning hint for 12. 13 and 14 and the 1.2 list stay open.
- The fixes are in the uncommitted working tree; see the "Fixes from the 2026-11-14 logic test" bullet in `CLAUDE.md`.
- The regression tests are `LogicTestFixesTests` in `TasquelTests.swift`, 8 tests. Unit tests: 251 passed.
- Persona tests re-run against the fixes, with their `TypedDate.find` calls updated to pass `today:`: 112 failed checks became 38. Every one left is either:
  - an item kept open (11 and 12 as behavior, 13, 14, the 1.2 list);
  - or a test expecting behavior a fix changed on purpose:
    - two same-named tasks now get two reminders;
    - a day set by the old date is cleared when the date moves later;
    - pinning while Undo's copy would make a third pin ends the Undo;
    - "until 12/15" keeps "until" in its phrase.
