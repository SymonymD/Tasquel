# Riley (34, office manager, years of Apple Notes checklists): first day with Tasquel 1.1

Evidence folder: `evidence-riley/`. Each step has a `<name>.png` and `<name>.txt`; the `run-*.log` / `out*.txt` files hold the `REVIEW:` lines. Driven from screenshots and the accessibility tree only; no app source, unit tests or docs. The Mac was heavily loaded (load average 600–900), so each run took 3–6 minutes; the session ran about 90 minutes.

## 1. First impressions
**First minute, before the tour** (`00-first-launch`, `02-home`): the welcome page says "Your weekly task planner that keeps you on track." Behind it, a grid of five boxes I didn't make: Errands, Work, Fitness, Study, Appointments, each "Completed: 0/0 · No tasks yet · Tap to add", under "Week of Nov 9" and a row of seven pills (five green, one "14th").
- Read: "This is a planner, not a notes app. Everything lives inside a *week*."
- Familiar: the round tap-circles.
- Foreign: no compose button bottom-right and no search bar at the top (both in Notes); pre-made categories; the green pills; the little diagonal arrows; "Completed: 0/0".

**Tour, all 5 pages with Next** (`01-tour-1…4`, `01-tour-end`): "Welcome to Tasquel", "Three Kinds of Task", "You Decide What Happens Next", "Organized by Category", "Your Calendar, Alongside".
- It did its job. Two lines saved me later: "fill a list like Groceries", and "tap the icons at the end of a task to choose".
- But it's a lot of vocabulary for a grocery list: type, mode, one-time, carry over, repeating.
- Didn't turn on calendar events. Quitting on the last page without "Let's Go!" restarts the tour next launch. Fine.

## 2. Per goal
**G1 Grocery list + shopping: done easily** (only because of the tour)
1. Opened Errands (cart icon), tapped "Add Task". Typed "Groceries"; a sparkles button appeared.
2. Tapped the two tiny icons after the field ("New task options: Checkbox, One-Time"). Popover: TYPE (Checkbox / Goal / List), AFTER THIS WEEK (One-Time / Carry Over / Repeating), DAY (Any M T W T F S S, plus a calendar).
3. Picked List, then "Add Task". Focus jumped straight to "Add Item".
4. milk⏎ eggs⏎ bread⏎ bananas⏎ coffee⏎. Exactly like Notes; the best moment of the day.
5. Tapped milk and bread: green fill and strikethrough, staying in place.
- Misleading: the icon pair (a check-circle and a "1") doesn't say "list". Without the tour I'd have typed five separate tasks.
- Evidence: `03-add-task`, `04-typed-groceries`, `04-options`, `04-list-chosen`, `04-groceries-added`, `05-items-typed`, `05-items-done`, `06-bread-checked`.

**G2 Reset the list for next week: needed Help. The Notes way isn't possible.**
- Try 1: long-press "Groceries". Nothing (`06-longpress-groceries`).
- Try 2: swiped left on the Groceries row, expecting actions. The whole screen slid to "Week of Nov 16", and Groceries wasn't there (`07-swipe-groceries`). A second of panic; tapped the green house to come back. Learned a One-Time list stays behind.
- Try 3: task options → Repeating. Hint: **"Comes back every week, unchecked"** (`07-repeating-chosen`).
- Next week showed **milk and bread still checked** (`07-next-week`, and after a relaunch `08-nextweek-before`). Unchecked them by hand there (`08-nextweek-unchecked`); this week stayed as it was (`08-thisweek-after`).
- Try 4: the pencil "Edit Errands" offers clock, pin, trash, drag handle. No "Uncheck All" (`08-edit-errands`).
- Help ▸ "After This Week": "a repeating list keeps its items, with checked ones still checked." Help explained the behaviour, but it's the opposite of what I want for groceries, and it contradicts the popover hint. Carry Over ("brings only what's left") isn't right either: bought items vanish from the list.

**G3 To-dos where they belong: done, with a little trouble**
1. "Call dentist" into Appointments, "Return Amazon package" into Errands (`09-dentist`, `09-amazon`).
2. "Pay water bill" had no card. Edit → "Add Category" tile (`09-edit-mode`).
3. The sheet (`10-add-category`) has "Create New Category" and "Saved Categories" (only the existing five; no suggestions like Home or Bills).
4. Typed "Home", Return: created the card, closed the sheet and left edit mode in one go (`11-create-new`, `12-home-return`).
- Trouble: realised the default **One-Time means unfinished to-dos silently drop off next week**. In Notes nothing disappears unless I delete it. Switched all three to Carry Over ("Moves to next week if unfinished"). Next week they're all there (`14-todos-carry`, `14-next-week`).

**G4 Water bill due the 28th: done, but with a trap found only in Help**
1. Task options → Carry Over → calendar icon at the end of DAY ("Add a date").
2. A picker titled **"Until"**: "Pick the task's last day".
3. Picked 28, Set. Popover: "Carries over until Sat, Nov 28" (`12-date-picker`, `14-picked-28`, `14-date-set`).
- Row shows only a tiny green calendar icon and a ring around the circle (`14-bill-added`). "Nov 28" isn't written anywhere on the row.
- "Won't forget": Settings ▸ Reminders ▸ "Expiration Reminders" (on by default): "A notification at 9 AM the day before a task's date, its last day" (`13-settings`). The app never asked to allow notifications; no system alert in any screenshot, so I can't tell whether the reminder would reach me.
- The trap: Help ▸ Days and Dates: "The day after, it's gone, and it doesn't carry over." If unpaid by the 28th, the bill disappears on the 29th, exactly when it's overdue. "Until / last day / expiration" suits a gift list, not a bill.

**G5 Packing list in 3 weeks: done easily.** ">" three times to "Week of Nov 30", added a "Packing" List in Home with passport, charger, sunscreen (`15-three-weeks`, `15-packing`, `15-back-this-week`). "Go to Week" also works (`19-calendar-button`). Caveats: nothing this week hints the list exists; can't reuse it for the next trip (no duplicate or template).

**G6 Share with my partner: not possible.** Tried the pencil edit mode, long-pressing the closed card (`13-longpress-card`), Settings (`13-settings-2`, `13-settings-3`). Closest: Feature Ideas ▸ "Sync Across Devices — Your tasks on your iPhone and iPad" (own devices, not a partner). Help: "share" appears only in "a day's share of the target" (`17-help-*`, `18-help-*`).

**G7 Find "dentist": not found (no search).** Pulled down on the cards (no search bar; Help says this closes all cards; `13-pull-down`); Settings; Help. Workaround: closed cards list task names, so "Call dentist" is visible under Appointments (`19-end-of-day-closed`). Fine at 10 tasks, not at 100.

**G8 Keep groceries first: done easily, once the pencil was found.** Pencil → "Pin Groceries to the top" turns orange (`16-pinned-groceries`). Main Edit → "Pin Errands to the top"; the card shows a pin (`16-pinned-errands`). Two levels of pin map nicely onto Notes' pin.

**G9 "call mom sunday": done easily.** Open card's Add Task (Errands), sparkles → "call mom Sunday ⏱ Sun", note "Added call mom Sunday · one-time" and Undo (`16-smart-add`). Stayed in Errands because that's where it was typed. Rules mode (a floor).

**G10 Peek at next week: done easily.** ">" shows "Week of Nov 16" with Groceries (repeating), Return Amazon package, Call dentist, Pay water bill; one-time "call mom" isn't there, as expected (`19-next-week-closed`). The logo ("This Week") brought me back (`19-back-via-logo`).

**Bonus, bringing data in from Notes (`20-pasted`, `20-smart-list`):** pasting three lines from a Notes checklist into Add Task made **three separate tasks**, the last line left in the field for Return. A great migration path nobody is told about. Sparkles on "Groceries: milk, eggs, bread" made a list of 3.

## 3. Translation table
| Notes concept | Tasquel |
|---|---|
| A note (Groceries, To do) | A List task inside a category card, or a whole category card |
| Folders | Category cards (flat, pre-made; Edit ▸ Add Category) |
| Checklist circle | The same circle: a Checkbox task or a List item |
| Return for the next line | The same, in Add Item / Add Task ✓ |
| Paste a list | Multi-line paste makes one task per line ✓ |
| Uncheck All | **Missing** |
| Checked items sink to the bottom | **Missing** (they stay in place) |
| Shared note / collaboration | **Missing** |
| Search | **Missing** |
| Pin a note | Pin a task (pencil) / pin a card (Edit) ✓ |
| Sort by date edited | Settings ▸ Sort Cards |
| Delete or reorder lines | The pencil's trash / red minus / drag handle |
| Indented sub-items | The "+" sub-tasks on a checkbox task |
| Reusable note (Packing) | **Missing** (a list lives in one week; no duplicate or template) |
| Free text, notes on an item | **Missing** (titles only) |
| Nothing ever disappears | **Opposite**: one-time tasks stay behind, dated tasks are "gone" the day after |
| iCloud sync to iPad/Mac | **Missing** (a Feature Idea) |
| Due date + alert (Reminders, not Notes) | "Until" date + 9 AM reminder the day before (an expiration, not a due date) |
| Locked notes | Feature Idea "Locked Categories" |

## 4. What I'd miss from Notes, ranked
1. **Sharing the grocery list with my partner.** *Dealbreaker.*
2. **A list that resets.** A repeating list keeps checks and there's no Uncheck All, so 20 items unticked by hand every week. *Dealbreaker for groceries.*
3. **Things not vanishing.** One-time is the default, and a dated bill is gone the day after its date. *Annoying, bordering on scary.*
4. **Search.** *Annoying now, a dealbreaker in a few months.*
5. **Sync to iPad/Mac.** *Annoying.*
6. **A free-text line** like "2% milk, not whole". *Nice to have.*
7. **Reusing a packing list.** *Nice to have.*
8. **Checked items moving to the bottom.** *Nice to have.*

## 5. What Tasquel gives me that Notes doesn't, ranked
1. **Carry Over.** Unfinished to-dos roll into next week while the week starts clean. The real win over a never-ending Notes "To do".
2. **A reminder before a date** (but see the permission doubt and "gone the day after").
3. **Weeks.** Plan a trip three weeks out, peek at next week, filter by day, coloured rings in "Go to Week".
4. **Smart Add and multi-line paste.** Fast entry.
5. **Cards keep home and work apart at a glance,** with names listed even when closed.
6. **Progress rings and "Completed 0/3".** Mildly motivating.
7. **Goals and habits.** Not for me.

## 6. Ideas for 1.2
- **"Reset items each week" for a repeating list,** plus "Uncheck All" on any list. Make the hint truthful for lists: it says "unchecked" while checks are kept. (G2)
- **Share one list or category with another person** (an iCloud share). (G6)
- **Search across weeks.** (G7)
- **A "Due" date alongside "Until".** A due task stays after its date and is marked overdue. Write "Nov 28" on the row. Ask for notification permission the first time a date is set. (G4)
- **A per-card default for new tasks** ("New tasks here: Carry Over"), or a one-time nudge at week's end: "3 unfinished tasks stayed behind. Bring them along?" (G3)
- **A row swipe that doesn't change the week,** or swipe actions on rows (delete, uncheck). (G2 try 2)
- **A visible label on the type/mode chip** (e.g. "Checkbox · One-Time") so lists are discoverable without the tour. (G1)
- **Duplicate a list to another week, or save it as a template.** (G5)
- **Say on the empty Add Task field that pasting a list works.** (Bonus)

## 7. Anything that looked broken or wrong
1. **The repeating-list hint contradicts behaviour.** Popover: "Comes back every week, unchecked"; next week showed milk and bread checked (`07-repeating-chosen` vs `07-next-week` / `08-nextweek-before`). Help says checks are kept by design, so the hint is wrong.
2. **No notification permission prompt was ever shown,** though Expiration Reminders is on by default and a dated task was added (`13-settings`, `14-bill-added`).
3. **Version mismatch:** About shows "Version 1.0.3, Build 11" while Help offers "What's New in 1.1".
4. **Accidental day filter:** "Thursday and tasks with no day · Show All" switched on during long-press and pull-down tries (`13-pull-down`). Low confidence; may have been a tap.
5. **The Add field placeholder changes** to "Add List" or "Add Carry-Over Task" after adding one of those (`04-groceries-added`, `14-bill-added`, `15-packing`). Help says it's sticky per card. Correct but surprising.
6. **"Week of November 30, 2026" appears twice** in the Go to Week picker (end of November and start of December) (`19-calendar-button` tree). Probably harmless.

## 8. Verdict
- **For to-dos: yes.** Carry Over, the week view and quick entry beat an endless Notes "To do". Likely still using it after a week, as long as new tasks are switched to Carry Over.
- **For groceries: no.** Can't share with my partner, and it won't reset unchecked. Groceries stay in Notes; Tasquel becomes a second app rather than a switch.
- **What would send me back fully:** an unpaid bill vanishing the day after its date; a reminder that never arrived because notifications were never allowed; needing to find something from weeks ago.

## 9. Test file
`ux/riley/TasquelUITests/SwitcherTests.swift` (test00–test20; no test12b). No app code changed.
