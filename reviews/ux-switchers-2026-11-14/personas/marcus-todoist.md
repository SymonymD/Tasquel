# Tasquel 1.1 user research: "Marcus", product manager, Todoist power user (5 years)

Driven only through screenshots and the accessibility tree; no source, tests or docs read. The Mac was very overloaded (load average 500–900), so the session took about 85 minutes instead of 60. Evidence in `evidence-marcus/` as `<name>.png` plus `<name>.txt` (the hierarchy); shrunk copies in `small/`.

## 1. First impressions (first minute)
- **What I thought it was:** a week-at-a-glance board, not a task inbox. The tour's first page had already said: "Your weekly task planner that keeps you on track… For each task, you choose what happens when the week ends: it stays behind, it carries over if it's unfinished, or it comes back every week." Tapped Skip (00-first-launch).
- **What I saw (01a-home-after-skip):** "Week of Nov 9" header, seven day pills (past days green, today "14th"), a 2-column grid of cards (Errands, Work, Fitness, Study, Appointments), each "Completed: 0/0 · No tasks yet · Tap to add". Bottom bar: gear, ‹ calendar ›, Edit.
- **Familiar:** the cards are obviously my projects.
- **Foreign:** no red + Quick Add, no Inbox, no Today/Upcoming, no search. Time is cut into weeks, not a timeline of due dates. First thought: "a habit tracker crossed with a weekly paper planner." Interesting, but not where I'd keep 200 tasks.

## 2. Per goal
**1. Set up Work, Personal, Side Project — done easily** (02a, 03a, 04a, 05a, 05b, 06c, 07a–c)
- Path: Edit → dashed "Add Category" tile → sheet → "Create New Category" → "Category name" → "Add Category". Projects are called "Category".
- Annoying: after each add, the sheet closes and Edit mode exits, so Edit → Add Category → Create New three separate times (05b).
- Deleting the four defaults was clear. "Delete Errands?" explains: "Past weeks keep their history… its tasks won't return". Each delete shows a toast, "Deleted “Appointments” Undo".
- The "This week only" toggle surprised me: a project that exists for one week?

**2. Natural-language quick add — needed Help** (08a, 09a–d, 10a, 11a–e, 12a–e, 13b, 14-*, 16b–f, 17c)
- **Try 1 failed.** Work → "Add Task", typed "Send invoice every Friday", hit Return, as in Todoist. Got the literal title, "Checkbox, One-Time", no day. All three phrases went in literally (09d).
- **Missed:** a sparkles "Smart Add" button *did* appear once I'd typed (09a), but Return "adds exactly what you typed". Nothing hints at this. In Todoist, Enter *is* the parse.
- **Tries 2 and 3** (no luck): Settings (11c–e: nothing about smart input), then the card's pencil, a long-press on Add Task, and the logo (12a–e).
- **Help #1:** Settings ▸ How to Use Tasquel ▸ Tasks: "type a task in your own words and tap the sparkles button".
- What Smart Add (rules mode, a floor) made of each phrase:

| Phrase | Result | Evidence |
|---|---|---|
| "Send invoice every Friday" | "Send invoice", Repeating, day Fri, but shown at once as **"Fri · late"** (today is Saturday) | 16b |
| "Gym Mon Wed Fri" | Not understood: one-time, title as typed | 16c |
| "Gym Mon, Wed, Fri" (comma form from Help's example) | "Gym", repeating **goal of 3** (0/3, +1). Not pinned to Mon/Wed/Fri | 17c |
| "Call mom Sunday" | Day Sun, but title stays **"Call mom Sunday"**; renamed by tapping the title | 16d, 18a |
| "Standup notes every weekday" | "Standup notes", repeating **goal of 5**. Not daily checkboxes | 16e |
| "Draft Q1 roadmap by Dec 12" | Title kept, one-time, plus a prompt "Until Sat, Dec 12? [Set Date]" | 16f |

- The "Set Date" prompt was gone after the app relaunched (17a), so the date was set by hand: options → calendar ("Until", "Pick the task's last day") → Dec 12 → Set (18e, 19a).
- The roadmap then quietly became Carry Over, and its row shows only a green calendar icon, no "Dec 12" (19c).

**3. Make "Draft Q1 roadmap" p1 — not possible** (10a, 19e, 19f, 20a, 20d)
- Tries: the options popover (only Type / After This Week / Day), a long-press on the title (nothing), a swipe on the row.
- The swipe **flipped the whole board to next week**. "Call mom" vanished; a second of panic (19f).
- Closest substitute is Pin (card pencil → pin, "Up to two tasks a card can be pinned"). It moves the task to the top, but in normal view nothing marks it as pinned (20d).

**4. Move "Call mom" to Personal — not possible; workaround** (20b, 22b, 22f)
- Try 1: dragged its handle in card edit mode toward the Personal card. That card is half-hidden behind the bottom bar; nothing happened (20b).
- Try 2: no "Move" in the options popover. Try 3: Help ▸ Tasks says nothing about moving tasks between cards.
- Workaround: trash it in Work, Smart Add it again in Personal. Title kept "Sunday" again (22f).

**5. Only today's tasks across projects — done with Help; labels and filters not found** (23a–e)
- Tapping "14th" shows "Saturday and tasks with no day · Show All"; Add Task becomes "Add Task for Sat".
- Yesterday's unfinished "Send invoice (Fri · late)" is **hidden** in the Today view. Todoist puts overdue first.
- No labels, no saved filters.

**6. Reorder tasks — done with trouble; reorder projects — done easily** (20c, 22j, 22k)
- Tasks: card pencil → drag handle. Dragged Gym to the top; it stopped below Send invoice and Call mom, because "tasks with a day come first". Nothing on screen says so.
- Projects: Edit → "Hold and drag a card to move it". Worked first time.

**7. Delete by mistake, then undo — done easily** (21b, 21d). The trash doesn't ask. "Deleted “Standup notes” Undo" brought it back with its progress.

**8. Sunday review and planning next week — planning easy, review weak** (24c, 24d, 25a–d)
- Review: closed cards show green dots for done and red circles for open, plus "Completed: 1/4" per card. No cross-card summary of done / carried over / dropped. "Go to Week" is just a month calendar.
- Planning: › next week already holds the carried-over roadmap and the repeating tasks, reset. "Prep sprint planning on Monday" parsed cleanly. Adding "Book dentist" was easy.

**9. Karma, streaks, completed count — not possible** (24b, 11e-settings-scrolled2.txt). Only per-card "Completed x/y" and the card ring. Goals in progress (Gym 2/3) don't count toward x/y. Feature Ideas lists "Stats & Charts" as not built yet.

**10. Speed test: one task with a day** (26b)
- From the closed home screen: card → Add Task → type → sparkles = **3 taps plus typing** (~6.5 s at test speed).
- On a Saturday, "Call dentist Tuesday" became **"Tue · late"**. Next Tuesday takes 4 taps (› first), and you have to think about which week you're in.
- Todoist (from memory): + → "Call dentist tue" → Enter = 2 taps, lands in Inbox as *next* Tuesday.

## 3. Translation table
| Todoist | Tasquel |
|---|---|
| Project | Category (card) |
| Inbox | missing: you must open a card first |
| Quick Add (global +, Enter parses) | per-card "Add Task" plus the sparkles "Smart Add"; Return adds the text literally |
| Natural-language dates | days of *this* week, "every <day>", and a date offered as "Until …?" |
| Due date | Day (within the week) or "Until" (last day; task disappears after it) |
| Due time ("4pm") | missing |
| Priority p1–p4 | missing; Pin to top (max 2 per card, no marker) |
| Labels @ | missing |
| Filters | a day pill shows that day plus undated tasks; no queries |
| Today | today's pill (overdue excluded) |
| Upcoming | › next week / Go to Week |
| Recurring "every weekday" / "every 2nd Monday" | Repeating = every week (plus a day), or a repeating goal of N; no intervals |
| Sub-tasks | + on a task |
| Move to project | missing |
| Undo | toast Undo (delete, Smart Add) |
| Karma / streaks | missing ("Stats & Charts" in Feature Ideas) |
| Weekly review | carry-over / repeating modes do the rollover; no review screen |
| Reminders | 9 AM the day before an "Until" date |
| Sync / desktop | missing ("Sync Across Devices" in Feature Ideas) |

## 4. What I'd miss from Todoist (ranked)
1. Quick add that parses on Enter and treats "Tuesday" as the next Tuesday — *dealbreaker*.
2. Sync with desktop and web — *dealbreaker*.
3. Priorities, labels and filters — *dealbreaker*.
4. A Today view that includes overdue tasks — *annoying*.
5. Moving a task to another project — *annoying*.
6. An Inbox: capture now, file later — *annoying*.
7. Flexible recurrence (daily weekdays, every 2nd Monday, monthly) and due times — *annoying*.
8. Due date text on the row — *nice to have*.
9. Karma and streaks — *nice to have*.

## 5. What Tasquel gives me that Todoist doesn't (ranked)
1. **An end-of-week rule per task (One-Time / Carry Over / Repeating).** The app does half my Sunday review. The real idea; I'd value it a lot.
2. **Counted goals** ("Gym 0/3", "Standup 0/5" with +1): habit-style weekly targets inside the task list.
3. Next week comes pre-filled with repeats and carry-overs; planning is flipping one page.
4. A glanceable grid of categories with completion rings and mini lists.
5. Undo on everything, and Smart Add's "Added … · repeating Undo" note.
6. On-device parsing ("nothing is sent anywhere"), "Until" dates for temporary tasks, List-type tasks, themes. Low value for me.

Items 1–2 are compelling for habits and personal life. For work task management, it's little.

## 6. Ideas for 1.2
- **Smart Add relative to today.** On Sat/Sun, "Tuesday" should mean next week's Tuesday, or ask "This Tue (passed) or next?". "every Friday" made after Friday shouldn't start "late". (16b, 26b)
- **Return uses Smart Add** whenever available, or a setting. At least hint in the placeholder, e.g. "Add Task — try 'Gym Mon, Wed, Fri' ✨". (09a)
- **Consistent title clean-up.** Remove bare day names ("Call mom Sunday" → "Call mom") and "by Dec 12". Accept "Mon Wed Fri" without commas; offer "on those days" as well as "goal of 3". Let "every weekday" choose between daily checkboxes and a goal of 5. (16c, 16d, 16e, 26b)
- **A global +** in the bottom bar that adds to the last-used card (or an Inbox card), with "#Work" in Smart Add to pick the card.
- **"Move to…"** in the task options popover, and/or drag between cards. (20b)
- **A visible "Important" flag or star** with a filter; show the pin icon in normal view too. (20d)
- **Today pill includes late tasks:** "Saturday, late, and tasks with no day". (23a)
- **Show "Dec 12" on the row**, not just an icon. Keep the "Set Date" suggestion until it's acted on. (19c, 17a)
- **A Sunday review sheet:** done / carrying over / dropping per card, then "Plan next week".
- **Streaks on repeating goals** ("Gym: 3 weeks in a row") and a weekly done count.
- **Swiping on a task row should act on the task** or do nothing, not flip the week. (19f)
- **Keep the Add Category sheet open** to add several. (05b)

## 7. Anything broken or wrong
1. **A word breaks mid-word next to the day badge:** "Send invoic / e" (12a-card-pencil, 20a-pinned-roadmap, 21a-deleted-callmom).
2. **New tasks are "late" the moment they're made** on a weekend: "Fri · late" (11b, 16b), "Tue · late" (26b-speed-result).
3. **The Smart Add "Until Sat, Dec 12? Set Date" prompt vanishes after a relaunch** (16f vs 17a).
4. **About says "Version 1.0.3, Build 11"** while Help offers "What's New in 1.1".
5. **Today's filter hides overdue tasks** (23a-today-pill).
6. **Inconsistent title stripping:** "on Monday" removed (25b), but "Sunday" and "Tuesday" stay (16d, 26b).
7. **In card edit mode, the floating bottom bar covers the cards below**, so there's nothing to drag onto (20a).
8. **Low confidence, probably the overloaded machine:** taps right after an animation were ignored a few times (a trash tap didn't delete, 17c, 21a; once Edit didn't open). With a 1-second pause everything worked (18c, 22b).

## 8. Verdict
Wouldn't switch the work system: no sync, no priorities, labels or filters, no Inbox, and "Tuesday" landing in the past — back in Todoist by Monday morning. Would keep Tasquel next week for Personal: the gym counter, weekly repeats and carry-over are nicer than Todoist's recurring tasks for habits. What would send me back for good: the first time a task I just typed shows up "late", or needing the list on my laptop. What would win me over: Smart Add on Return that understands "next Tuesday", a global +, and a real Sunday review screen.

## 9. Test file
`ux/marcus/TasquelUITests/SwitcherTests.swift` (test00–test26). No app code changed.
