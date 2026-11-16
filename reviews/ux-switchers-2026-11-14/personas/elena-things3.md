# Elena's first day with Tasquel: user-research report (designer, Things 3 switcher)

**Setup and caveats.** Driven only through screenshots and accessibility trees, with 16 XCUITest steps (test00–test16). The Mac was very overloaded (load average 500–900), so each run took 3–5 minutes and the session ran about 75 minutes. Not tried: Smart Add (the sparkles), renaming a category, dragging to reorder. Knowledge of Things 3 comes from training: confident about Today, Evening, Upcoming, Anytime, Someday, Logbook, Areas, Projects with headings, checklists, deadlines, tags, notes, Quick Find, Magic Plus and Mac sync; less sure that Things still has no counters/goals and no themes beyond light and dark.

Evidence folder: `evidence-elena/`. Each `.png` has a matching `.txt` accessibility tree; each test's log is in `run-<test>.log`.

## 1. First impressions
- **First minute (welcome sheet, `00-first-launch.png`):** "Weekly checklists… you choose what happens when the week ends: it stays behind, it carries over… or it comes back every week."
  - *Elena:* "So it's not a GTD inbox. It's a week planner. Things sorts by *when* (Today, Upcoming, Someday); this sorts by *which week*. Calm white, a blue pill button: more stock iOS than Things, but clean."
- **The tour** (5 pages, `01-tour-p1..p5.png`) was clear and nicely illustrated: three kinds of task (checkbox, goal "50/50", list); carry-over and repeating; category cards ("Tap Edit at the bottom to add or delete categories"); calendar alongside. Calendar events turned on at page 5 (`02-cal-turned-on.png`).
- **After the tour** (`02-home.png`): a 2-column grid of category cards for "Week of Nov 9", with day pills under the title (only today labelled "14th").
  - **Familiar:** checkboxes, rounded calm cards, checklists inside a task.
  - **Foreign:** no Inbox, Today, Upcoming or Someday lists; time is "this week vs another week" plus a weekday; "AFTER THIS WEEK" is a whole new idea.

## 2. Goal by goal
1. **Areas (Clients, Home, Health) with icons: done, with some trouble.**
   - Five starter categories (Errands, Work, Fitness, Study, Appointments). Edit mode shows only − and pin; no rename appeared when tapping a title (`02-edit.png`, `03-edit-tap-work-title.png`). Long-pressing a card did nothing visible (`03-longpress-work.png`).
   - Path that worked: Edit ▸ "Add Category" ▸ "Create New Category" ▸ "Category name" plus an "Icon: Folder" button. Its menu has "Choose Emoji…", Folder, Star, Heart, Home, Work… (`03-add-category.png`, `04-icon-picker.png`, `05-a-Clients-ready.png`). Chose Work, Home and Heart.
   - Friction: adding a category closes the sheet and leaves Edit mode, so three areas meant three round trips (`05-a-Clients-added.png`); the five starters had to be deleted one at a time, with a confirm each (delete does stay in Edit mode).
   - Result: `06-home-three-areas.png`. *"In Things I just type a new Area. Here I had to throw away five I didn't ask for."*
2. **"Acme website redesign" with three steps: done fairly easily.**
   - Open card ▸ "Add task" ▸ "New task options: Checkbox, One-Time". The popover has TYPE (Checkbox / Goal / List), AFTER THIS WEEK (One-Time / Carry Over / Repeating), DAY (Any, M–S, calendar) and an "Add Task" button.
   - Chose List + Carry Over; after Add Task, an "Add Item" field opened and Return added each step (`08-type-options.png`, `09-list-carry.png`, `09-steps.png`).
   - Lovely touches: "1 of 3", a progress ring, folding the list. The add row then read "Add Carry-Over List" (the type sticks for the next task in that card).
   - Missing compared with a Things project: no notes, no headings, no per-step dates.
3. **Deadline about ten days out: looked done, but Help showed it isn't a deadline.**
   - Steps or list items have no options, so only the whole Acme task could be dated: Task options ▸ calendar ▸ "Until… Pick the task's last day" (Date/Week tabs) ▸ Nov 24 ▸ Set ▸ "Carries over until Tue, Nov 24" (`10-add-date.png`, `11-a-until-set.png`).
   - On the row: only a tiny green calendar glyph and a ring; no date text. VoiceOver says "expires in 10 days" (`11-a-acme-with-deadline.png/.txt`).
   - Help ▸ Days and Dates: "For a task you only need until a certain day… The day after, it's gone, and it doesn't carry over or repeat after that."
   - **So the client project will disappear on Nov 25 if it isn't finished.** The opposite of a Things deadline. Not possible as meant.
4. **Plan today: marking was easy; the Today view was found but isn't quite Today.**
   - Options ▸ DAY ▸ "S" (Saturday) on "Send Acme invoice" and "Book dentist" (`11-b-invoice-options.png`).
   - Tapping the "14th" pill shows "Saturday and tasks with no day · Show All" (`11-c-today-filter.png`). Undated Acme shows up in "Today" too.
   - The two "S" and two "T" letters are ambiguous at a glance.
5. **Someday ("Learn ceramics"): not possible.**
   - Every date picker is "Until", never "start later" (`11-d-ceramics-date.png`, `11-d-ceramics-week.png`). Settings has nothing like it.
   - Workaround: ">" six times to Week of Dec 21 and added it there (`13-b-ceramics-future.png`). That is a scheduled one-time task, not Someday; a carry-over task would nag every week.
6. **This Evening: not possible.** Only weekday granularity; no time of day (`08-type-options.png`).
7. **Tomorrow, then next week: tomorrow easy; next week not found and Help didn't answer it.**
   - "Change day of Book dentist" reopens the same popover; tapping S (Sunday) gives "Book dentist ⏱ Sun" (`12-b-dentist-sunday.png`, `13-a-change-day.png`).
   - For next week, tried: the popover (no "next week"); long-press on the task and on a list item (nothing, `10-longpress-item.png`); swipe left on the row, which **switched the whole screen to Week of Nov 16** (`12-a-swipe-left.png`); the date picker (only "Until", `12-c-dentist-date.png`).
   - Only real path: retype the task in next week, or make it Carry Over and leave it unfinished.
8. **Appearance: done easily, and the best surprise.**
   - Settings ▸ Appearance: System, Light, Dark, "Seasonal, now Fall", Retro, plus "Match App Icon to Theme".
   - Dark is a tasteful navy (`14-a-home-Dark.png`). Retro is a full green-terminal skin with six terminal colours (`14-a-home-Retro.png`, `14-a-settings-Retro.png`). Seasonal Fall has warm cream cards and drifting leaves (`16-final-closed.png`).
   - *Against Things' polish:* Seasonal is on par and more charming; Retro is fun but not for me; Light is plainer than Things.
9. **Focus on long lists: done easily.** Closed cards keep a mini-summary of open tasks; lists fold ("1 of 3"); "Open all cards" / "Close all cards"; day filter; pin tasks and cards to the top (`13-c-folded.png`, `13-c-closed.png`, `16-final-open-all.png`). Better than Things here.
10. **Logbook: partial, with trouble.** Checked tasks stay struck through in their week (`13-c-checked.png`). "<" shows past weeks read-only (`13-d-last-week.png`); Help confirms "Past weeks are view only". No list of everything finished and no search.

**Help:** one visit (Settings ▸ Help ▸ "How to Use Tasquel"; tabs Weeks / Cards / Tasks / Types / Modes / Dates), after 3+ honest tries each on next week, Someday and Logbook (`15-b-help-1.png`, `16-help-*.png`).
- **Answered:** Logbook (partly: past weeks); the deadline (it expires, which was bad news).
- **Not answered:** next week, Someday, Evening.
- Paragraphs are very dense, e.g. "the green house that comes out of the arrows on another week (to their left on a later week, where Edit is on an earlier one)".

## 3. Translation table
| Things | Tasquel |
|---|---|
| Inbox | missing (each task must go in a card) |
| Today | day pill filter ("Saturday and tasks with no day") |
| This Evening | missing |
| Upcoming | future weeks via arrows / Calendar ▸ Weeks; no list across weeks |
| Anytime | tasks with no day in this week |
| Someday | missing (workaround: a far-future week) |
| Logbook | struck-through tasks in their week; read-only past weeks; no list or search |
| Areas | category cards (icon or emoji; Saved Categories) |
| Projects | List task (Carry Over) + "1 of 3" progress; no headings or notes |
| Checklist | list items / "Add sub-task" (+) |
| Deadline | "Until" date: the task **expires**, it isn't flagged as due |
| When / start date | weekday pill only; no defer |
| Repeating | Repeating mode (weekly, per day) |
| Tags, Notes, Quick Find | missing (none seen) |
| Magic Plus / Quick Entry | "Add task" row + Smart Add sparkles (not tested) |
| Calendar in Today | Calendar button sheet (Events / Weeks) |
| Reminders | Expiration Reminders only (9 AM the day before a task's last day) |
| Mac/iPad sync | missing ("Sync Across Devices" is only a Feature Idea) |
| Import | none seen |

## 4. What I'd miss from Things (ranked)
1. Real deadlines: due, stays, turns red. *Dealbreaker:* today's "Until" can silently drop client work.
2. Mac sync / Things Cloud. *Dealbreaker* for a freelancer who plans at her desk.
3. Someday / Later backlog. *Dealbreaker:* the idea list has nowhere to live.
4. Move to tomorrow / next week / pick a date ("When"). *Annoying.*
5. Notes on tasks (links, briefs). *Annoying.*
6. A true Today list (today only, across areas). *Annoying.*
7. Logbook with search across weeks. *Annoying.*
8. Project headings and per-step dates. *Annoying.*
9. Quick Find / search. *Annoying.*
10. This Evening. *Nice to have.*
11. Tags. *Nice to have.*

## 5. What Tasquel gives me that Things doesn't (ranked)
1. A clean week every Monday, with per-task "after this week" behaviour (one-time / carry over / repeating). Things just piles up. The core idea, and it's good.
2. A glanceable dashboard: area cards with progress rings and mini-summaries, open or closed. Great for focus.
3. Goals with counts (e.g. "50/50") and repeating lists that reset.
4. Themes: Seasonal is genuinely delightful.
5. Week-by-week calendar events in one sheet, plus a week jumper.
6. Past weeks as a read-only journal.

For client work, that's modest. For routines (Home, Health) it's real value.

## 6. Ideas for 1.2
1. **Split "Due" from "Expires"** (§4.1, goal 3): Due stays, shows "Nov 24 · 10 days left" on the row, goes red when late. Expires keeps today's behaviour but says "disappears after Nov 24" in the picker. Today the picker says "Until" while VoiceOver says "expires", which is ambiguous.
2. **"Move to…"** in task options: Tomorrow / Next Week / Pick a Week / Later (§4.3–4.4, goal 7).
3. **A "Later" shelf**: tasks outside any week, reviewed when you choose (Someday); a special card or a drawer (§4.3, goal 5).
4. **Row swipe actions** (left = move, right = done) instead of swipe-to-change-week on task rows; keep swiping on empty space or the header for weeks (goal 7, `12-a-swipe-left.png`).
5. **A "Done" view**: everything checked off, grouped by week, searchable (§4.7, goal 10).
6. **A "Today only" toggle** on the day filter that hides no-day tasks (goal 4).
7. **Notes field** on tasks and lists (§4.5, §4.8).
8. **Smoother onboarding for switchers**: rename or re-icon starter categories in place, or offer "start empty"; keep Add Category open to add several at once; paste multiple lines to create several tasks or list items.
9. **Help as Q&A**: "How do I move a task to next week?", "Where do finished tasks go?", "Is there a Someday?". Keep the long text behind "More".
10. **Evening**: an optional "Evening" chip after the weekday (nice to have).

## 7. Things that looked broken or wrong
1. **Version mismatch:** Settings ▸ About shows "Version, 1.0.3" next to "What's New in 1.1" (`13-e-settings-3.txt`). May just be an unbumped build number.
2. **Past week shows categories that didn't exist yet:** Week of Nov 2 shows Clients, Home and Health, created on Nov 14, alongside the five deleted (`13-d-last-week.png`).
3. **Retro theme leaks into accessibility labels:** "> How to Use Tasquel", "> Saved Categories", "> Match App Icon to Theme", "[APPEARANCE]" (`14-a-settings-Retro.txt`). VoiceOver would read the symbols.
4. **Help tab names differ between screen and accessibility:** visible "Weeks / Cards / Types / Modes / Dates" vs labels "Weekly Checklist / Category Cards / Task Types / After This Week / Days and Dates". Breaks Voice Control "tap Modes" (label-in-name).
5. **Mixed date wording:** "Until" / "Pick the task's last day" on screen, "expires in 10 days" in VoiceOver, "Expiration Reminders" in Settings (`11-a-acme-with-deadline.txt`).
6. **Icon menu under the keyboard:** in Create New Category the keyboard stays up and hides the lower half of the menu (`04-icon-picker.png`). Minor.
7. **Swipe on a task row changes the week** (`12-a-swipe-left.png`). Documented, but easy to trigger by accident for anyone used to row swipes.
8. Not app bugs (simulator only): the "Ready for Apple Intelligence" banner covered Skip on tour page 2 (`01-tour-p2.png`); the iOS keyboard slide-to-type tip appeared (`05-a-Clients-ready.png`).

## 8. Verdict
Wouldn't switch client work. The "deadline" that deletes a project, no Someday, no defer, no notes and no Mac sync would send me back to Things within days. *Would* keep Tasquel next week for Home and Health routines and weekly goals: there the week reset, goal counters, collapsible cards and the Seasonal look beat Things. Fix due dates, add Move to… and a Later shelf, and it could become my weekly planning layer next to Things, maybe more.

## 9. Test file
`ux/elena/TasquelUITests/SwitcherTests.swift` (test00–test16). Data ID `switcher-1`; theme left on Seasonal.
