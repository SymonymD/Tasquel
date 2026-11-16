# Tasquel 1.1 first-time user research: "Jordan" (parent, Apple Reminders switcher)

**Setup and caveats.** Driven only through screenshots and `app.debugDescription`; no app source, unit tests or docs. About 80 minutes against the 60 aimed for, mostly waiting on builds and runs (load average 600+). Evidence in `evidence-jordan/`: `NN-name.png` plus a matching `.txt` hierarchy, run logs `run-*.log`. Smart Add ran with `-smartAddRules`, so what it understood is a floor. Today in the app was Saturday, Nov 14.

## 1. First impressions
**First minute (`00-first-launch`, `01-after-tour`):** "Week of Nov 9", a row of seven day pills, five preset cards (Errands, Work, Fitness, Study, Appointments), and a bottom bar with Settings, ‹, a calendar button, › and Edit. No "+ New Reminder", no My Lists, no Today/Scheduled/Flagged tiles. "This is a weekly planner board, not a reminders app. The cards are like my lists, but everything belongs to a week." The Mon–Fri pills were already green with zero tasks; read as "days completed", which confused me.

**After the 5-page tour (`01-tour-01`…`05`):** "Welcome to Tasquel", "Three Kinds of Task", "You Decide What Happens Next", "Organized by Category", "Your Calendar, Alongside", ending on "Let's Go!".
- **Familiar:** lists become category cards; subtasks; repeating.
- **Foreign:** the one-time / carry-over / repeating choice, Goals, swiping between weeks.
- **Most noticed:** the tour never mentions times, alerts or notifications — the core of how I use Reminders.

## 2. Per goal
1. **Take out trash, every Tuesday: done easily.** No Family card, so followed the tour's "Tap Edit at the bottom to add or delete categories": Edit → "Add Category" → "Create New Category" → "Category name" → Family (`03`–`06`). Then "Add Task", typed the name, Return (`07`). The options pill ("Task options: Checkbox, One-Time") opens TYPE / AFTER THIS WEEK / DAY. Picked Repeating + T; hint "Comes back every week, unchecked" (`08-trash-options`, `09-tuesday`). Clear and good.
   - But the row immediately shows **"Tue · late"** (`09-trash-done`), because this week's Tuesday has passed.
   - No time ("Tuesday 7 PM") and no alert.
2. **Dentist this Thursday 3 PM, with a reminder: done with trouble; time and custom alert not possible.**
   - **Try 1:** "Dentist appointment Thursday at 3pm" + sparkles. Filed under the Thursday that already passed (Nov 12): "Thu · late" (`10-dentist-smartadd`, `11-appointments`). Ignored "3pm" and left "Thursday at 3pm" in the title.
   - **Try 2:** the options popover has no time.
   - **Try 3:** the calendar icon ("Add a date") opens "Until … Pick the task's last day" (`12-dentist-addadate`). Picked Nov 19: "Until Thu, Nov 19, then it's gone". The task silently switched to Carry Over ("Carries over until Thu, Nov 19", `13-dentist-set`). "Then it's gone" scared me: I want it *on* Thursday, not deleted after.
   - The row shows no date text, only a small green calendar icon (`13-dentist-after`).
   - The only reminder: Settings ▸ Reminders: "A notification at 9 AM the day before a task's date, its last day" (`18-settings-01`). So Wednesday 9 AM, never "1 hour before".
   - Never saw a notification-permission prompt.
3. **Renew passport by ~Dec 26, with a reminder: done with trouble.** Smart Add "Renew passport by December 26" offered "Until Sat, Dec 26? [Set Date]" (`14-passport-smartadd`). As soon as I typed the next task, the suggestion vanished and the passport was left undated (`14-family-three`). Went back: options → calendar → "Next month" → Dec 26 → Set: "Carries over until Sat, Dec 26" (`15-passport-set`). Reminder is the fixed 9 AM the day before; the row never shows "Dec 26".
4. **Family list with 3 tasks + party steps: done easily.** Return chains the next task. "+" ("Add sub-task to Plan Ava's party") opens "Add Sub-task", and Return chains there too (`14-family-final`). As good as Reminders.
5. **Flag "Sign permission slip": done with trouble; a real flag isn't in Tasquel.**
   - Long-press: nothing (`15-slip-longpress`).
   - Swipe left: **changed the whole week** to Nov 16 (`15-slip-swipeleft`). Expected Flag/Delete swipe actions.
   - Options popover: no flag or priority.
   - Later found the pencil ("Edit Family") → "Pin … to the top" (`17-edit-family`). Pin only moves the task to the top; nothing on the row is coloured or marked (`22-pin-after`).
   - First pin tap didn't register (`19-slip-pinned-edit`, `19-slip-pinned`); the second worked.
6. **What do I need to do today: done easily, with a caveat.** "14th" pill: "Saturday and tasks with no day · Show All" (`16-today-pill`). Close to Today, but every undated task counts as "today", and there's no Scheduled list. The calendar button opens "Go to Week" with coloured rings on dated days, not a list (`16-calendar-btn`).
7. **Share Groceries with my spouse: not possible.** Card long-press (nothing, `17-card-longpress`), the pencil (rename, pin, trash only, `17-edit-family`), Settings (`18-settings-01..06`). Feature Ideas lists "Sync Across Devices: Your tasks on your iPhone and iPad" — own devices, not sharing.
8. **Check off the slip, find it again later: done easily.** Stays in place, struck through; the card reads "1 of 5 complete" (`19-slip-checked`, `19-closed-cards`). Gone next week (one-time); the previous week still has it (`19-next-week-family`, `19-back-this-week`). No search, no "Completed" list.
   - **Bigger surprise:** "Buy birthday gift" and "Plan Ava's party" are also missing from next week, because new tasks default to One-Time. Coming from Reminders, I'd lose unfinished tasks on Monday.
9. **"remind me to call the plumber tomorrow at 9": done, but nothing understood.** Fastest path: tap a card, Add Task, type, sparkles. No global add button. Result: "Added Remind me to call the plumber tomorrow at 9 · one-time" (`20-plumber-smartadd`). No day (tomorrow is Sunday, in this week), no time, "Remind me to" stays in the title.
10. **Siri / Shortcuts / widget: not found.** Nothing in Settings. Long-pressing the app icon shows only "Edit Home Screen" and "Remove App" (`22-icon-longpress`). Didn't check the widget gallery or the Shortcuts app.

**Help:** opened once, as a last resort after the tries for time, flag and share (`21-help-tab01..06`; full text in `21-help-alltext.txt`).
- **Time:** answered, as a no: "At 9 AM the day before its last day, a notification reminds you."
- **Flag:** "Pin a Task" confirms pinning is all there is (up to two per card).
- **Share and Siri:** nothing.
- Help explains `Tue · late` and "Thursday = this week" ("Smart Add picks up 'on Friday'"). Consistent, but wrong for someone adding on a Saturday.

## 3. Translation table
| Reminders | Tasquel |
|---|---|
| Lists (Family, Work) | Category cards (Edit → Add Category) |
| Shared list (Groceries) | **missing** |
| Groceries items | "List" task type inside a card (not tested in depth) |
| Due date | "Until" last-day date (the task is then "gone"), or a weekday within the week |
| Due time | **missing** |
| Alert / early reminder | Only a global "Expiration Reminders" at 9 AM the day before the last day |
| Repeat weekly on Tuesday | Repeating + Day T (good) |
| Repeat daily / monthly / yearly | **missing**; only weekly. Goals cover habits. |
| Location reminder | **missing** |
| Siri "remind me to…" | **missing**; no App Shortcuts, widget or quick actions |
| Today | Today's day pill (plus all undated tasks) |
| Scheduled | Partly: rings in the Go to Week calendar, no list |
| Flagged / priority | **missing**; Pin a Task (position only) |
| Subtasks | "+" Add sub-task (good) |
| Completed / Show Completed | Stays checked in its own week; no list, no search |
| Search, tags, notes, URL | not found |
| Natural-language quick entry | Smart Add: weekdays and dates only (rules mode); time ignored |
| Import existing data | **missing**: had to retype everything |

## 4. What I'd miss from Reminders (ranked)
1. Timed alerts ("3 PM, 1 hour before"): *dealbreaker*.
2. Shared Groceries list with my spouse: *dealbreaker*.
3. Siri capture while driving or cooking: *dealbreaker*.
4. Import of my existing lists: *dealbreaker for switching*; at best alongside Reminders.
5. Location "when I get home": *annoying*.
6. Unfinished tasks following me by default, instead of staying behind as One-Time: *annoying*.
7. A real flag/priority plus a Flagged list: *annoying*.
8. Widget / Lock Screen: *annoying*.
9. Seeing the date and time on the row: *annoying*.
10. Monthly or yearly repeats (bills, birthdays): *nice to have*.
11. Search and a Completed list: *nice to have*.

## 5. What Tasquel gives me that Reminders doesn't (ranked)
1. A real weekly reset. Chores like trash come back unchecked every week, and the whole week shows as cards with "1 of 5" counts. Genuinely valuable for the kids' routines.
2. An explicit choice per task of what happens to unfinished work (one-time / carry over / repeating).
3. Countdown rings on dated tasks that fill as the deadline nears.
4. Goals with progress (e.g. kids' reading minutes): mild interest.
5. Undo after deleting, duplicate warnings, themes: nice touches.

For my life it's a pleasant *weekly chore board*, not a replacement.

## 6. Ideas for 1.2
- **Time of day plus a per-task alert** ("at 3 PM, 1 hour before"), shown on the row. (Goals 2, 9)
- **Smart Add fixes:** a weekday already passed goes to next week, not late; strip date and time words and "Remind me to" from the title; understand "tomorrow" and "at 9". (`10-`, `20-`)
- **Keep the "Set Date" suggestion** until tapped or dismissed (`14-`).
- **Show "by Dec 26" / "Thu 19" as text** on the row. Reword "then it's gone" (`12-`/`13-`).
- **Carry Over as the default** for new tasks, or ask once at onboarding ("Should unfinished tasks follow you?"). (Goal 8)
- **"Import from Reminders"** during onboarding: lists to cards, weekly repeats to Repeating, due dates to Until dates.
- **Shared categories via iCloud** (goal 7).
- **App Shortcuts / Siri "Add to Tasquel"** and a Today widget (goals 9, 10).
- **Swipe actions on task rows** (Pin, Delete, Details) instead of changing week (`15-slip-swipeleft`).
- **An "Important" mark visible on the row**, plus a cross-card filter (goal 5).
- **An "Upcoming" list** next to the day pills, and a global search that includes completed tasks (goals 6, 8).

## 7. Things that looked broken or wrong
1. **"Thursday at 3pm" lands on a past Thursday** (Saturday entry): "Thu · late" (`10-dentist-smartadd`, `11-appointments`).
2. **The Set Date suggestion disappears** as soon as you type the next task (`14-passport-smartadd` → `14-family-three`).
3. **A repeating Tuesday task is "late" at birth** (created Saturday) (`09-trash-done`).
4. **First pin tap in edit mode didn't take** (`19-slip-pinned-edit`); the second did (`22-pin-after`). Maybe test timing.
5. **Tapping the "Thu · late" chip** on a wrapped title went into rename mode instead (`11-dentist-daychip`).
6. **Swiping left on a task row changes the week** (`15-slip-swipeleft`).
7. **Edit-mode rows squeeze titles** to 3–4 lines ("Take / out / trash"), and the floating bottom bar covers the last rows (`17-edit-family`).
8. **The bottom bar shows through** the Add Category sheet (`04-add-category`).
9. **Past-day pills are green on a fresh install** with zero tasks; reads as "completed" (`01-after-tour`).
10. **Version mismatch:** "Version 1.0.3 / Build 11" next to "What's New in 1.1" (`18-settings-03`/`04`).
11. **No notification-permission prompt** appeared, though "Expiration Reminders" is on and dates were set.

## 8. Verdict
Wouldn't switch. After a week might still open it for the repeating family chores and the week at a glance, but Reminders stays for anything with a time, a place, my spouse, or Siri. Three things would send me back: the dentist reminder coming at 9 AM the day before instead of at 2 PM; Groceries not shared; "Plan Ava's party" disappearing on Monday because it was One-Time.

## 9. Test file
`ux/jordan/TasquelUITests/SwitcherTests.swift` (test00–test22). The test01 tour step only replays on fresh data (change `dataID`). No app code changed.
