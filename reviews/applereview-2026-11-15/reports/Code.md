## Tasquel 1.1 code review: dates, data safety and the App Review checklist

The release's new date logic holds up in DST weeks, at year ends, with time-zone changes and with 1.0.3 data. One real problem: **changing the week start silently deletes dated tasks in later weeks** (and moves day tasks a week late). Two of my tests reproduced it, across two separate runs. One small Smart Add date bug. Nothing on the App Review checklist fails.

Full unit run (`-only-testing:TasquelTests`, iPhone 17 Pro sim `54D3836A…`): 304 tests. All 279 existing tests pass. The only failures are my 4 tests for the findings below, which are written to fail until the bugs are fixed. Log: `<work root>/Code/shots/unit-all.log`

## 1. Findings

### F1. Changing Week Starts On deletes dated one-time tasks in later weeks and moves next week's day tasks a week late
- **Severity:** Rejection risk (silent data loss). It's a narrow path, and CLAUDE.md lists "week-start switches with dated tasks" as left for 1.2, but the result is deletion, not just a misplaced task.
- **Device:** any device, Monday start, today Sun Nov 15 2026.
- **Steps:**
  1. In a card, add "Dentist" as One-Time and give it the date Thu Nov 19. It moves to next week ("Moved to next week").
  2. Settings ▸ Week ▸ Sunday.
  3. Page to any week, or relaunch.
- **Expected:** Dentist is in the week holding Nov 19 (Nov 15–21).
- **Actual:** Dentist is gone from every week. The log line `REVIEW: after the switch, Dentist is in []; weeks ["2026-11-22", "2026-11-15"]` shows it, and it's still gone after a relaunch. Its reminder is cancelled too.
- **On a weekday too:** with Sunday starts on Wed Nov 11, a One-Time task dated Sun Nov 15 is deleted after switching to Monday starts.
- **Day tasks:** on Sunday, "Gym" for Thursday goes into next week (Nov 19), by design. After the switch it's in the week of Nov 22, on Thu Nov 26: `REVIEW: … Gym is in the week of 2026-11-22, on 2026-11-26`.
- **Cause:**
  - `ChecklistStore.swift:573-580` moves every saved week by the same shift: +6 days on a Sunday, ±1 on other days.
  - A week moved past its tasks' dates then loses them in `removeExpiredTasks` (`:1054-1064`, cutoff `:1043-1045`).
  - `caughtUp` (`:772`) already hides them from previews.
  - `dayOfWeek` keeps the weekday, so the six-day move puts day tasks a week later.
- **Fix:** after the shift in `setWeekStartsOnSunday`, re-place every task in a current or later week whose date or day falls outside its week:
  - a One-Time dated task goes to `weekOfDate(expiresOn)`'s card of that name (as `moveToItsDatesWeek` does, via `addTask(_:toWeekStarting:categoryNamed:)`);
  - on the six-day shift, next week's day tasks whose day now falls in the current week come back into it.

  Keep the three tests as regression tests.

### F2. "2/29" typed in a year without Feb 29 is never offered as a date
- **Severity:** Polish.
- **Device:** any device, Smart Add.
- **Steps:** at any time in 2027, ✨ "Leap day 2/29".
- **Expected:** "Until Tue, Feb 29?" (2028).
- **Actual:** no date offered.
- **Cause:** `TypedDate.swift:102-107` builds the date in this year first. Feb 29 2027 rolls to March 1 and is rejected, so the next-year step at `:55-60` never sees it.
- **Fix:** for a date without a year, try this year and then next year before rejecting it.

## 2. Checked and fine
- No 86,400-second day arithmetic in app code. `DayKey` math goes through a UTC calendar, and every other date uses `Calendar`.
- `DayKey` round-trips through midnight for every day of 2026–2028 in 10 zones: New York, Tokyo, Kiritimati, plus Santiago, Havana and Asunción, where DST changes at midnight, then Lord Howe, St John's, Beirut and Apia.
- `Week.startOfWeek` picks the right Monday or Sunday at 00:00, 12:00 and 23:30 for every one of those days, both week starts, including year ends.
- **DST Sundays** (Mar 8 and Nov 1 2026, Mar 14 and Nov 7 2027):
  - the current week is the Monday before; at 00:30 Monday the new week is current, with no duplicate week; Sunday-start weeks work too;
  - "late", "Today", `daySetOn` and `dayHasGoneBy` are right;
  - a task is there through 23:30 of its last day and gone at 00:30, with the ring full on its last day;
  - the reminder is due at 9 AM local the day before: there at 8:59, gone at 9:01.
- Notification triggers are floating Gregorian DateComponents (`ExpiryNotifications.swift:67-70`), so they follow time-zone changes.
- One-Time dates move into their date's week correctly across the November DST change and the 2026/27 and 2027/28 year ends (with Sunday starts).
- Flying Tokyo → New York leaves `expiresOn`, `dayOfWeek` and weeks unchanged.
- **Typed dates:**
  - year end: "jan 2" typed on Dec 31 is next year's;
  - "until/due/by 12/15" means Dec 15 (no off-by-one);
  - "till" and "before" are taken out of the name.
- Thanksgiving (US and CA) and the lights/confetti weeks are right for 2026–2029. What's New compares versions correctly, and the pill shows for updaters only.
- **1.0.3 data:** files load with the new defaults (reminders on); a bad value in a new field drops only that field, not the file.
- **Checklist:**
  - privacy manifest declares UserDefaults CA92.1 and active keyboards 54BD.1; no other required-reason APIs are used; tracking is false; local notifications need no entry;
  - the notification permission is asked only on the first date set or when the switch is turned on (`TaskRowCard.swift:588,1002,2389,2705`, `SettingsSheet.swift:358`), never at launch;
  - the calendar purpose string is specific; `ITSAppUsesNonExemptEncryption` is NO; there are no background modes;
  - every launch argument is under `#if DEBUG`;
  - no "coming soon", TODO, lorem or Android strings;
  - Support and Privacy return 200, and Support has a mailto;
  - no IAP; no `fatalError`, `try!` or unguarded indexing found in reachable paths.
- **Tests:** there were no existing tests for DST weeks or for week-start switches with dated tasks. That switch is the riskiest untested behavior, and it's where F1 was.

## 3. Test files
`tests/Code/ReviewCodeDateTests.swift` (unit tests only).

| Suite | Tests | Covers | Result now |
|---|---|---|---|
| `ReviewCodeWeekStartSwitchTests` | `sundaySwitchKeepsNextWeeksDatedTask`, `mondaySwitchKeepsSundayDatedTask`, `sundaySwitchKeepsDayTaskDate` | F1 | fail |
| `ReviewCodeWeekStartSwitchTests` | `carryOverSurvivesSwitch` | checked | pass |
| `ReviewCodeTypedDateTests` | `leapDayNextYear` | F2 | fails |
| `ReviewCodeTypedDateTests` | `yearEnd`, `rangeEnds`, `deadlineWordsLeaveTheName` | checked | pass |
| `ReviewCodeDayKeyTests` | | zones, both week starts | pass |
| `ReviewCodeDSTWeekTests` | | the DST weeks | pass |
| `ReviewCodeDatesWeekTests` | | moves across DST and year ends | pass |
| `ReviewCodeTimeZoneTests` | | the flight | pass |
| `ReviewCodeHolidayTests` | | Thanksgiving, holiday marks, What's New | pass |
| `ReviewCodeOldDataTests` | | 1.0.3 files, lenient decoding | pass |

Logs (work root) `Code/shots/`: `unit1.log`, `unit2.log`, `unit-all.log`.

## 4. Couldn't check in a simulator (phone checklist)
- Give a task tomorrow's date: does "… expires tomorrow" arrive at 9 AM today, and at 9 AM local after changing the time zone in iOS Settings ▸ General ▸ Date & Time?
- At the first prompt pick Don't Allow, then turn notifications on for Tasquel in iOS Settings and go back to Tasquel without force-quitting. Do reminders for dated tasks you already have get scheduled? The code suggests not until the reminder list changes or the app relaunches: `update` skips an unchanged list (`ExpiryNotifications.swift:41`), and nothing reschedules when the app returns.
- Set the first date from the edit-mode clock: does the permission alert over the closing popover look right, and is the date kept?
- With Apple Intelligence: try ✨ "pay rent till dec 15" and "dentist december 15". Are the names and the Until/Set Date offers right?
- Leave the app open across midnight on a DST night (or any midnight): does a task whose last day was yesterday disappear, and does the day strip move to the new day?
