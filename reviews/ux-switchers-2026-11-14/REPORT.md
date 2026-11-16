# Switcher study: six people try Tasquel 1.1 on day one

**Date:** Saturday, 2026-11-14 · **Build:** `release-1.1` at a8358ad (still labeled 1.0.3 (11))
**Aims:** how well people coming from other apps adapt, what Tasquel offers that their apps don't, and what 1.2 should do.

## How it was run
- Six AI testers, each with a persona, an old app, and about 10 goals taken from that app.
- Each tester had its own simulator (iPhone 17 Pro, iOS 26.3) and fresh data (`-isolatedDataID switcher-1`), plus the fake calendar.
- Smart Add ran in rules mode (`-smartAddRules`); the simulator has no Apple Intelligence. What it understood is a floor.
- Testers learned only from screenshots and the accessibility tree: no source, docs or tests. Each one drove the app with XCUITests it wrote itself.
- The Mac was badly overloaded (load average 500–900), so each session took 60–90 minutes. A few "ignored tap" reports are probably timing.
- **The test day was a Saturday.** That made "this week's Tuesday has passed" problems show up for everyone; on a Monday they would be rarer.
- I checked every bug claim against the code or the screenshots. See `verification-notes.md`.

| Tester | Persona | Coming from | Tour / Help |
|---|---|---|---|
| Riley | office manager, 34 | Apple Notes checklists | watched the tour; Help when stuck |
| Jordan | parent | Apple Reminders | skimmed the tour |
| Marcus | product manager | Todoist (5 years) | skipped the tour |
| Elena | freelance designer | Things 3 | watched the tour |
| Dev | grad student, runner | Streaks | skipped the tour |
| Sam | teacher, 45 | paper bullet-journal weekly planner | watched the tour; Help freely |

Full reports: `personas/`. Tests: `tests/`. Key screenshots, each with its accessibility tree: `evidence/`.

## The headline
**Nobody would switch outright, and all six would keep Tasquel next week alongside their app, for the same job: weekly routines and personal to-dos.**

| Tester | Keeps it for | Keeps the old app for | What would send them back |
|---|---|---|---|
| Riley | to-dos (Carry Over) | groceries (sharing, list reset) | a bill vanishing the day after its date |
| Jordan | family chores, the week at a glance | anything with a time, a place, a spouse or Siri | a task disappearing on Monday because it was One-Time |
| Marcus | Personal: gym counter, weekly repeats | work (sync, priorities, labels, Inbox) | a task he just typed showing up "late" |
| Elena | Home and Health routines, weekly goals | client work (deadlines, Someday, notes, Mac sync) | a deadline that deletes a project |
| Dev | to-dos and chores | habits (streaks, per-day counts, time reminders) | no streak after a run, no morning nudge |
| Sam | the weekly to-do part | notes, the monthly page, rent | ideas having nowhere to go |

## What Tasquel gives them that their apps don't
Ranked by how many testers named it, and how high.

1. **The end-of-week rule per task (One-Time / Carry Over / Repeating).** All six named it, and five ranked it first.
   - Marcus: "The app does half my Sunday review for me."
   - Sam: "No more rewriting." It's Sam's ">" migration done by the app.
   - Riley: "The real win over my never-ending Notes To do."
2. **Goals that count** ("Gym 0/3", "Read 20m / 2h 20m", +1 / −). Five testers; Marcus and Elena say their apps have nothing like it.
3. **Next week already filled in** with repeats and carry-overs, so planning is just flipping a page, and future weeks can be filled ahead (Sam, Marcus, Riley, Elena).
4. **The card dashboard:** rings, mini lists on closed cards, Open/Close All, the day filter. Elena: "Better than Things here."
5. **The Seasonal look** (Elena: "on par with Things and more charming"; Sam: "felt most like paper"), plus Undo everywhere, multi-line paste, and Smart Add when it works.

**What this means for 1.2:** Tasquel's natural place is as a **weekly routine layer** next to a main app. It isn't a Todoist or Things replacement. 1.2 does best by deepening that role (review, history, lists that reset, due dates, moving tasks) rather than chasing sync, labels and priorities.

## Bugs found and confirmed (candidates for 1.1)
| # | Bug | New in 1.1? | Seen by | Where | Fix |
|---|---|---|---|---|---|
| 1 | **A task name breaks mid-word in card edit mode** when it has a day ("Send invoic / e", "Take / out / trash") | **yes** (day marks) | Marcus, Jordan | `TaskRowCard.swift:345` puts the day/date mark as a fixed-size view *beside* the name; `stacksIcons` (`:731`) counts it as one more word instead of subtracting its width | In `stacksIcons`, take the mark's width plus 8 from `besideIcons`; add a UI test with a dated task in card edit mode |
| 2 | **The Repeating hint is wrong for lists:** "Comes back every week, unchecked", but a repeating list keeps its checks (deliberate since d4016f8) | no | Riley | `Models.swift:33` (`SyncMode.hint`) | A list-specific hint, e.g. "Comes back every week, checks and all" |
| 3 | **Help tab names differ for VoiceOver:** pill "Weeks", label "Weekly Checklist". Voice Control's "tap Modes" fails (label in name) | **yes** (Help tabs) | Elena | `HelpSheet.swift:143` | Label = the visible name; the long title as hint |
| 4 | **Weeks before first use show every saved card,** including deleted starters and cards made today (8 empty cards) | no | Sam, Elena | `ChecklistStore.swift:703`: `makeWeek` seeds a week with no earlier week from `savedCategories` (which keeps deleted cards); past weeks are previews | A past week with no stored week on or before it shows no cards, with a line such as "Nothing was planned this week" |
| 5 | **The Edit goal panel runs off the screen with a Custom unit** (the unit field and Save Goal are cut off on a 402 pt iPhone) | no | Dev | `TaskRowCard.swift:1199`: Target row = label 74 + unit menu + number 104 + unit name ≥74 in one HStack, ~20 pt too wide | `ViewThatFits`: put the unit name under the number when the row doesn't fit (as the buttons below already do) |
| 6 | **Retro puts symbols in Settings/Help labels** ("> Match App Icon to Theme", "[APPEARANCE]", "> SETTINGS_") | no | Elena | `SettingsSheet.swift:55, 214–315`; `HelpSheet.swift:167/173`. CLAUDE.md says Retro has plain labels | Plain `accessibilityLabel` on the decorated texts |
| 7 | Smart Add rules gaps: "Yoga twice **this** week" → one-time; "Gym Mon Wed Fri" (no commas) not read | no | Sam, Marcus | `ParsedTask.swift:548` (count needs a/per/each/every week); `:405` (day list needs separators) | Allow "this week"; allow spaces between day names |

Smaller items, confirmed but cosmetic: after choosing Goal in the options popover, the Target / Set row appears *behind* the popover (Sam). The bottom bar's green Done tint shows through the half-height Add Category sheet (Jordan; iOS 26 glass; check on the phone).

**Checked and not bugs:**
- "VoiceOver reads symbol names" ("Move", "Do Not Disturb"): those images are children of buttons labeled "Icon: Folder", "Light", "Dark".
- "No notification permission prompt": `-isolatedDataID` is throwaway data, which never asks (by design).
- "+1 did nothing": the test looked for "+1"; the label is "Add 1".
- "Tapping the day chip renamed the task": the test tapped the centre of the chip button's frame, which covers the whole wrapped title. A finger on the chip works. The oversized frame may still be worth a look for Voice Control.
- "About says 1.0.3": the bump to 1.1 (12) is still pending.

## By design, but people tripped on it
These follow rules you chose; the question is whether the rules or their presentation should change in 1.2.

| What happened | Rule | Testers |
|---|---|---|
| A day name typed on a weekend lands on this week's past day and is **"late" at birth** ("by Thursday", "Call dentist Tuesday", "every Friday", a repeating Tue task) | a day is a weekday *of the viewed week*; late = its day has passed unfinished | **4** (Sam, Dev, Marcus, Jordan) |
| An **"Until" date read as a deadline;** the task is gone the day after. The date isn't written on the row | Until = last day, then it's gone | **5** (Elena, Marcus, Riley, Jordan, Sam); 4 wanted the date on the row |
| **Swiping a task row flips the whole week** (two "panicked"; all four expected row actions) | swipe anywhere changes week | **4** (Elena, Marcus, Riley, Jordan) |
| **One-Time default:** unfinished to-dos stay behind on Monday ("silently drop off") | new tasks are One-Time unless changed (sticky per card) | 2 (Riley, Jordan), both rated it scary |
| Smart Add keeps day and time words in the title ("call mom Sunday", "by Thursday", "Remind me to … tomorrow at 9"); Return doesn't parse | only "on/this <day>", today, tonight, tomorrow or this weekend *at the end* are taken out (`ParsedTask.swift:584`), so a bare "Sunday", "by Thursday" and a mid-sentence "tomorrow" stay; only the sparkles parse | 5 (Sam, Marcus, Riley, Jordan, Dev) |
| "Mon, Wed, Fri" → a goal of 3, not three days; same-name tasks on different days marked **Duplicate** | a task has one day; duplicates = same name in a card | 2 (Dev, Marcus) |
| Typing a Step of 1 made the target 7, so the goal read "**Done, 8 of 7**" | step × days = target (your rule) | Dev |
| The Today pill hides late tasks and counts every undated task as today | filter = that day + no day (hiding late tasks is already on CLAUDE.md's "Left for 1.2") | 3 (Marcus, Elena, Jordan) |
| Pinned tasks show no mark on the row | a pin only orders | 2 (Marcus, Jordan) |
| Green past-day pills on an empty week read as "days completed" | past days are green | 2 (Jordan, Riley) |
| The Smart Add "Until …? Set Date" offer vanishes after the next add or a relaunch | notes last 4 s | 2 (Marcus, Jordan) |

## Switching friction in onboarding and setup
- **Category setup took round trips for everyone who built their own** (Sam, Elena, Marcus; mild for Riley and Jordan).
  - Five starter cards had to be deleted one at a time, each with a confirm.
  - Add Category closes the sheet *and* leaves Edit mode after each one.
  - Renaming isn't in Edit mode; it's on the open card's pencil, and Sam and Elena both tapped the Edit tile expecting it.
  - Ideas: "Start blank / pick your cards" in the tour, keep the sheet open to add several, rename from the Edit tile.
- **List was invisible without the tour** (Riley: "the icon pair doesn't say list"); Marcus never found that Smart Add exists until Help. Ideas: a word on the type/mode chip; a placeholder hint ("try 'Gym Mon, Wed, Fri' ✨"; "paste a list").
- **Help worked:** every tester who opened it got an answer or a clear no. But it's dense (Sam, Elena), and they came with questions ("How do I move a task to next week?", "Is there a Someday?"). Idea: a few question-shaped entries at the top.

## What they'd miss (missing capabilities)
| Capability | Dealbreaker for | Also wanted by | Count |
|---|---|---|---|
| History, streaks, stats, a week review | Dev | Sam, Marcus, Elena (Logbook) | 4 |
| Search (across weeks, incl. done) | — | Riley (soon a dealbreaker), Elena, Marcus, Jordan | 4 |
| Time of day + per-task reminder | Jordan, Dev | Marcus | 3 |
| Sync across own devices | Elena, Marcus | Riley | 3 |
| Notes / ideas that aren't tasks | Sam | Elena, Riley | 3 |
| Monthly / yearly repeats (rent, bills, birthdays) | Sam (bills) | Marcus, Jordan | 3 |
| Move a task (tomorrow / next week / another card / Later) | — | Elena, Marcus, (Sam, Jordan) | 2–4 |
| Sharing a list with another person | Riley, Jordan | — | 2 |
| Someday / Inbox / backlog | Elena | Marcus | 2 |
| Priorities, labels, filters | Marcus | Jordan (flag) | 2 |
| Siri, widget, import from Reminders | Jordan | — | 1 |
| Per-day counts / free step; multi-day tasks | Dev | Marcus (multi-day) | 2 |
| Uncheck All / a list that resets | Riley (groceries) | — | 1 |
| Location reminders | — | Jordan | 1 |

## 1.2 recommendations
Ordered by testers affected × how much it fits Tasquel's role. Links are to existing idea memories.

**A. Small changes that remove day-one distrust** (each touches one rule or one piece of text)
1. **A day already gone never lands in the past.** A day typed on Smart Add or picked after it has passed this week goes to next week (note: "Added to next week · Undo"), or at least a task made after its day isn't "late". (4 testers)
2. **Make the date's meaning visible.** Write "Nov 28" on the row, and offer **Due** (stays, turns late) beside **Until** (then it's gone). Reword the picker. (5 testers) → [[idea-far-off-dates]]
3. **A swipe on a task row doesn't change the week**: only on the header or empty space, or give rows their own actions. (4 testers)
4. **Unfinished tasks follow you by default:** Carry Over as the default for new tasks, a per-card default, or a one-time question in the tour. (Riley, Jordan)
5. **Smart Add polish:** strip a bare day name and "by <day>" at the end (a start like "Friday team lunch" still stays), and "Remind me to"; read "this week", "Mon Wed Fri", "tomorrow" mid-sentence; keep the Set Date offer until it's answered; a placeholder hint. (5 testers)
6. **Onboarding for switchers:** start blank or pick starter cards; Add Category stays open; rename from Edit. (3–5 testers)
7. **Uncheck All on a list** (keeps your "checks are kept" default). (Riley)
8. **Show a pin on pinned rows; let the Today pill include late tasks.** (2–3 testers each)

**B. Features that deepen the weekly-routine role**
1. **Week review** on the first open of a new week: done / carrying / dropped per card, with Carry / Drop / Move. (Sam, Marcus, Elena; Riley's "3 unfinished stayed behind, bring them?")
2. **History and streaks** for repeating tasks and goals ("Gym: 3 weeks in a row"); the "Stats & Charts" Feature Idea. (Dev, Marcus, Sam)
3. **Move to…** next week, another card, or a Later shelf → [[idea-drag-tasks-between-categories]], [[idea-far-off-dates]] (Coming Up)
4. **Goal options:** a per-day target ("8 a day": today 3/8, the week 3/56), and progress shown on closed cards. (Dev) A step that leaves the target alone would answer Dev too, but you chose that typing a step recalculates the target (CLAUDE.md, Goal row). A per-day target gets Dev's "log 3 of 8 glasses" without undoing that rule; at the least, warn when a new step makes a goal already met.
5. **Time of day and a per-task reminder.** The notification plumbing already exists. (Jordan, Dev, Marcus)
6. **Monthly / yearly repeats** → [[idea-far-off-dates]] ("Repeat Every Year"). (Sam, Marcus, Jordan)
7. **Search** across weeks. (4 testers)
8. **Notes on a task.** (Sam, Elena, Riley)
9. **Widget and App Shortcuts** → [[idea-widget]]. (Jordan)

**C. Big infrastructure; decide on strategy, not on this study:** sync, sharing, import from Reminders, priorities and labels. Each was a dealbreaker for one or two people, but they pull Tasquel toward being a general to-do app.

Not raised: hidden categories, the iPad half-width cards (this was an iPhone-only study).

## Limits of this study
- The testers are AI personas following goal lists, not people. Their knowledge of their old apps comes from training and may be dated, which three of them said themselves.
- Smart Add was in rules mode. On a phone with Apple Intelligence, "twice", "tomorrow" and times may already work better.
- It was a Saturday, which inflated the "late at birth" problem.
- It covered day one only: nobody lived through a week rollover, which is where Tasquel's main strength shows.
- It was simulator only, on one iPhone size; the iPad and small iPhones weren't covered.
