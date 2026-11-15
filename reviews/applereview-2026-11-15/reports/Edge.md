## Edge reviewer report: Tasquel 1.1 on the iPhone SE (3rd gen) simulator, iOS 26.3

All paths below are under the work root's `Edge/`. Screenshots are in `shots/` (the cited ones are copied, shrunk, to `evidence/Edge/`). Each finding failed its test at least twice. The Mac's load stayed between 150 and 550, so two of the runs failed with simulator launch errors ("RequestDenied"); I re-ran those tests rather than count them.

### 1. Findings, most severe first

**F1. After a trip back west across the week boundary, next week stops following this week.** Major, though it needs a rare trigger. The behaviour isn't new in 1.1.
- Steps:
  1. With `TZ=America/New_York` (Sunday): Errands ▸ add "Plain carry" ▸ Carry Over.
  2. Relaunch with `TZ=Asia/Tokyo` (or `Pacific/Kiritimati`), where it's already Monday. The new week is current and the task carried over correctly.
  3. Relaunch in New York. This week is current again. Check off Plain carry and add another Carry Over task.
  4. Tap › to go to next week.
- Expected: Plain carry is gone from next week, as it is without the trip.
- Actual: it's still there, unchecked. The new carry-over task does arrive.
- Evidence: `edge-travel-west-1-thisweek.png` (checked off this week), `tokyo-edge-travel-west-2-nextweek.png` (still in next week). `testFlyingBackFromTokyoKeepsNextWeekFollowingThisWeek` and `testFlyingBackWestKeepsNextWeekFollowingThisWeek` both fail with `REVIEW west next week tasks: ["Complete Plain carry", "Complete Added after the trip"]`. The no-trip control, `testWithoutTravelNextWeekFollowsThisWeek`, passes.
- Cause: `ChecklistStore.swift:712` (`ensureWeekExists`) sets `didFinalSync = true` while the week is current in Tokyo. Back in New York, `:922` (`isFuture = isFutureWeek && didFinalSync != true`) treats the now-future week as the user's own. From then on, untouched copies no longer follow or leave with their source.
- Fix: when a saved week with `didFinalSync` is found in the future and no week-start change moved it there, reset it to false. Tasks the user edited stay protected by `isUserEdited`.

**F2. After pasting lines into a list, the field you're typing in is left about 3,000pt below the screen.** Minor.
- Steps: Errands ▸ make a List called "Groceries" ▸ paste 100 lines (90 items plus "Milk" ×10) into Add Item.
- What works: all 100 items are added, the ten Milks are marked Duplicate, and the note appears.
- Actual: the screen stays on Items 1–6 with the keyboard up. The focused field is at y=3601 (the keyboard's top is at 451), so the next typing happens out of sight.
- Evidence: `edge-hundred-pasted-SE.png`; `testHundredItemListWithDuplicatesPasted` prints `field=(87.5, 3601.5…) hittable=false`.
- Cause: `TaskRowCard.swift:1500–1534` (`submitTypedSubtask` / `addSubtask`) never scrolls. The Add Task row does, through `keepFieldInView()` at `:3060` and `:3075`.
- Fix: scroll the item field into view after each add, the same way.

**F3. Long names beside a day or date mark are squeezed into a narrow column on the SE.** Minor.
- A nine-word name beside "Sun · late" gets a column about 70pt wide and runs to 7 lines (155pt). Beside "Nov 28" it takes 5 lines (110pt). A plain name of the same length takes 3 lines (66pt).
- "⧉ Duplicate" goes under the name and doesn't have this problem.
- Evidence: `keep-edge-late-long-names-SE.png`, `edge-squeeze-SE.png`; `testLateMarkAndLongNamesOnSE` and `testLongNameBesideDayOrDateMarkIsNotSqueezed`.
- Cause: `TaskRowCard.swift:348–359` puts the mark beside the whole name. `stacksIcons` (`:752`) only checks whether the widest word fits.
- Fix: when the column beside the mark would be narrow, put the mark on its own line under the name. It can stay a button.

**F4. With the Saudi Arabia region, the week title uses the Islamic calendar but the day strip uses the Gregorian one.** Minor.
- Launched with `-AppleLocale ar_SA`. The layout stays left-to-right English because the app isn't translated, which is fine.
- What shows:
  - Header: "Week of 29 Jmd. I".
  - Day strip pills: 9 … 15th.
  - VoiceOver on those same pills reads "Monday, 29 Jumada I".
  - The Until calendar shows "Jumada I 1448 AH".
- Evidence: `edge-locale-ar-SA-grid.png`, `edge-locale-ar-SA-calendar.png`; `testIslamicCalendarRegionTitleMatchesDayStrip`.
- Cause: `Models.swift:672` (`displayTitle`) and `ExpiryPicker` use `Calendar.current`, while `WeekDayStrip.swift:97` and `:109` show the Gregorian `DayKey.day`.
- Fix: use one calendar for everything shown. The test assumes Gregorian; flip it if the fix goes the other way.

**F5. A date in a later year: the pop-up leaves out the year.** Polish.
- Setting a date 24 months out (as far as the calendar goes) gives the header "Week of Nov 6, 2028" but the pop-up "Moved to the week of Nov 6". That reads as a date that has already gone by this year.
- Evidence: `edge-far-moved.png`; `testDateTwoYearsAwayMovesAndStaysQuick`.
- Cause: `weekPhrase`, `ContentView.swift:1747–1750`, formats only month and day.
- Fix: add the year when it isn't this year, as the header does.

**F6. "tomorrow" on the week's last day: the pop-up says Monday "had already gone by".** Polish.
- On a Sunday with Monday week start, Smart Add "Call mom tomorrow" correctly goes to next Monday.
- But the pop-up says "Monday had already gone by this week." and the note says "…here, as Monday had gone by". That reads as if the app misread "tomorrow".
- Evidence: `edge-tomorrow-on-sunday.png`; `testTomorrowOnTheWeeksLastDay`.
- Cause: `TaskRowCard.swift:2903` and `:2951–2953`. `ParsedTask.swift:222` keeps only the weekday, so it no longer knows the user said "tomorrow".
- Fix: when the day is tomorrow, say something like "Tomorrow is in next week".

### 2. Checked and fine
- Pago Pago, Kiritimati, Tokyo and Phoenix: the header week and today's pill match each zone's own date.
- New York → Kiritimati:
  - the new week is current;
  - the repeating Sunday task and the carry-over arrive once each, not late;
  - the one-time task stays in its week;
  - last week keeps all three, view only.
- Sunday week start, Pago Pago → Kiritimati in the same week: "Sun · late" is right.
- "before 11/25", "till nov 25" and "by 11/25" all become Carry Over, with the word and the date taken out of the name.
- Year end:
  - "Party 12/31" moves to the week of Dec 28 (Dec 27 with Sunday start), and that week's day strip runs 28 … 3.
  - The week after is titled "Week of Jan 4, 2027", and Party is gone after its date.
- "tomorrow" with Sunday start stays in this week.
- "by friday" on a Sunday goes to next Friday.
- A date 24 months out: the move took about 4 s under load; Back to This Week and Go to Week stayed quick.
- Force-quitting right after a change: the change is saved.
- Sending the app to the background with typed words adds them as a task and saves it.
- The moved pop-up on the SE: the keyboard closes, OK and Back to This Week can be tapped, Back works, and there's no house on this week.
- Add Category with the keyboard up on the SE: every control stays above the keyboard, a 60-character name works, and the "Added … · add another" note shows.
- 24 cards with two pinned: the pins at the bottom can be reached, pinned cards come first in their own order, and a third pin is disabled. That last check passed in 2 of 3 runs; in the third, the second pin's tap landed mid-scroll, which is my test's timing, not the app.
- German region: the title reads "Week of 9. Nov". Typing "Zahnarzt 31.12." offers no date (one run only, not reported as a finding).

### 3. Test files (in `tests/Edge/`)
- `ReviewEdgeSupport.swift`: shared helpers (`ReviewEdgeCase`).
- `ReviewEdgeTimeZoneTests.swift`:
  - F1: `testFlyingBackFromTokyo…`, `testFlyingBackWest…`;
  - fine: `testTravelEast…`, `testWithoutTravel…`, `testFarZonesShowTheirOwnToday`;
  - `ReviewEdgeLifecycleTests` (force quit, background).
- `ReviewEdgeDatesTests.swift`:
  - F3: `testLateMarkAndLongNamesOnSE`;
  - F6: `testTomorrowOnTheWeeksLastDay`;
  - fine: deadline words, year end, Sunday start, "by friday";
  - `ReviewEdgeFarDateTests` (F5).
- `ReviewEdgeSmallScreenTests.swift`:
  - F2: the 100-item paste;
  - fine: the moved pop-up, Add Category, 24 cards;
  - `ReviewEdgeLocaleTests` (F4, German);
  - `ReviewEdgeLongNameTests` (F3).
- Some tests depend on today's date and skip on other days: F1, east travel, the late mark, "tomorrow" and "by friday" need a Sunday in New York, as today was.

### 4. Couldn't check in a simulator (phone checklist)
- Leave the app open past midnight from Sunday into Monday: does it move to the new week, do late marks update, does the house appear?
- Change the time zone in iOS Settings while the app is open: do today and the week follow without a relaunch?
- Fly across zones: does the expiration reminder still arrive at 9 AM local time?
- First open in a new week after travel: do the card wiggle and the Today pulse play?
- Deny notifications, then allow them in iOS Settings: does the Reminders footer update when you come back?
- Paste 100 lines into a list on the phone: how fast is it, and where does the screen end up?
- Is a long "· late" task name readable on a real SE?
- With Apple Intelligence: do "tomorrow", "by friday", "12/31" and "dec 31" come out the same as with the rules?
