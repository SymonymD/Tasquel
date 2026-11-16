# Tasquel 1.1 first-use study: "Sam" (45, teacher, 10 years of a paper bullet-journal weekly planner)

Evidence: `evidence-sam/` (each `.png` has a matching `.txt` accessibility tree; shrunk copies in `small/`). No app code was changed. The run took about 62 minutes; the Mac's load average was 600–900, so each test run took 3–4 minutes.

## 1. First impressions
**First minute (tour page 1 and the screen behind it):** "Weekly task planner" and "Week of Nov 9" got my attention straight away, because to-do apps never have a week. The tour line "it stays behind, it carries over if it's unfinished, or it comes back every week" read to me as my ">" migration, done by the app. The cards looked like the sections of my spread. The coloured pills under the week name confused me: they don't show what's on each day the way my daily columns do.

**After the tour (01-tour-p1…p5, 02-tour-calendar-on):** The tour was clear and short.
- **Familiar:** the week as the unit, sections, migration, and appointments alongside.
- **Foreign:**
  - I decide each task's fate when I write it, not on Sunday night when I review.
  - The app came with *its* sections (Errands, Work, Fitness, Study, Appointments) where I expected a blank page.
  - The tour's last button, "Let's Go!", took me a second to spot.

## 2. Per goal
**Goal 1: Sections School, Home, Self.** *Done with trouble.*
- The tour said "Tap Edit at the bottom to add or delete categories", so I tapped Edit (02-edit). I wanted to rename Work to School, so I tapped the Work card and then long-pressed it. Nothing happened either time (03-edit-tap-work, 03-edit-longpress-work).
- I fell back on "Add Category", then "Create New Category", which shows an "Icon: Folder" button and a "Category name" field (03-add-category, 04-create-typed).
- The icon menu has no school, pencil or apple icon (05-icon-picker). I used "Choose Emoji…" and picked 🍎 (06-emoji-picker), then "Home" for Home and "Heart" for Self.
- Each Add Category press closes the sheet *and* leaves Edit mode. I had to go Edit, then Add Category, then Create New Category three separate times (06-School-added).
- Deleting the 5 defaults took 5 confirmations reading "Delete Errands? This removes the category and its tasks…" (07-delete-confirm). The result is 07-my-spread.
- I only found out later, in Help ▸ Cards, that renaming lives on the *open card's* edit button ("Rename a Category"). The bottom Edit button misled me.

**Goal 2: Fill this week.** *Done with trouble.*
- "Grade essays by Thursday" with the sparkles (Smart Add) became a task with a day badge reading "Thu · late". Today is Saturday, so it took the past Thursday, and the name still says "by Thursday" (08-sparkles-grade).
- "Email parents…" and "Laundry" went in with Return, which was easy.
- "Yoga twice this week" with sparkles came back as "Added Yoga twice this week · one-time", a plain checkbox (09-yoga-smart).
- I fixed it by hand: Task options, then Goal. The "Quantity / Target / Set" fields sit *behind* the popover, so I had to close it, type 2 and tap Set (10-yoga-goal, 10-yoga-after, 11-yoga-set).
- Later, "Yoga 2x per week" did work: "Added Yoga · repeating goal of 2" (16-yoga-2x-smart). This is rules mode, so treat it as a floor.

**Goal 3: Migration.** *Done easily; this is the best moment in the app.*
- The row-end "Task options" popover has TYPE / AFTER THIS WEEK / DAY. "Carry Over" explains itself: "Moves to next week if unfinished" (09-after-carry).
- Tapping › to "Week of Nov 16" showed "Email parents" already waiting, with the orange arrow (10-next-week-school).

**Goal 4: "Books to read" with three titles.** *Needed Help; then done.*
- Help ▸ Types and Modes taught me List + Carry Over: "A list or sub-tasks bring only what's left."
- I added the list in Self with 3 items (15-books-items). It shows up next week with all three (15-books-next-week).
- It still lives inside a weekly section rather than on its own page.

**Goal 5: This week's events beside my tasks.** *Done, but not "beside".*
- The calendar button opens a "This Week's Events" sheet listing Team Standup, Dentist and Lake Trip (13-events).
- The sheet covers the cards, and tasks are grouped by section, not by day. On paper my events and tasks share a day column.
- The header says "3 events" next to 4 rows, because Lake Trip shows on both Friday and Saturday.

**Goal 6: Report cards in the week after next.** *Done easily.* Two taps on › opened "Week of Nov 23". I added the task in School, and "Email parents" was already there too (13-report-cards). A green house button brings you back. The Weeks tab has a month grid for jumping to a week (13-events-weeks).

**Goal 7: Look back at last week.** *Found, but it looked wrong.*
- ‹ goes to Week of Nov 2, which is view-only according to Help.
- That week shows **all 8 cards**: the 5 defaults I deleted plus School, Home and Self, which I only created today. Oct 26 is the same (13-last-week, 13-two-weeks-ago).
- There's no place to reflect: no week summary and no notes.

**Goal 8: Make it feel like my planner.** *Partly.*
- An emoji per section works.
- The built-in icon set is small.
- Colours per section: not found. I looked in Add Category, the card's edit mode (14-edit-home) and Settings.
- Themes: Seasonal "Fall" (cream with falling leaves) felt most like paper (16-end-closed). Retro is a green terminal look (14-retro).

**Goal 9: "Pay rent on the 1st", every month.** *Not possible in Tasquel.*
- Smart Add answered "Added Pay rent on the 1st every month · one-time" (14-rent-smart).
- The only modes are One-Time, Carry Over and Repeating (weekly).
- "Add a date" opens an "Until" picker: "Pick the task's last day" (14-rent-date). Help ▸ Dates confirms dates are expirations, not due dates or monthly repeats.

**Goal 10: A lesson-idea note.** *Not found.*
- Long-press on a task does nothing (14-longpress-task).
- Tapping a task only opens its "Task name" for renaming (14-tap-task).
- The card's edit mode has clock, pin, trash and handle, with no notes (14-edit-home). Help never mentions notes.
- The only workaround is an "Ideas" (lightbulb) section of checkboxes, but an idea isn't a task.

**Help visits:**
- Settings ▸ "How to Use Tasquel", Weeks tab: helped with navigation, the day pills and "Future weeks can be filled in ahead of time" (11-help-1).
- The Cards, Tasks, Types, Modes and Dates tabs (12-help-*): helped with goals 4 and 9 and explained renaming. They said nothing about notes or monthly tasks.
- The Help text is thorough but long; it's dense reading for a first day.

**End of first day:** I crossed off Laundry: a filled dot, the text struck through, and the card's ring fills (17-laundry-done). That felt satisfying. I tapped "+1" on Yoga once and it stayed at 0/2 (17-yoga-one). I couldn't tell whether my tap missed, so I'm not calling it a bug.

## 3. Translation table
| Paper | Tasquel |
|---|---|
| Weekly spread | "Week of …" screen with cards |
| Daily columns | Day pills that filter tasks; a task can carry a Day badge ("Thu") |
| Sections | Categories (cards) |
| • task | Checkbox task |
| X crossed off | Circle fills and the text is struck through; card ring and "Completed: x/y" |
| > migrated | Carry Over, chosen up front; previews in later weeks |
| < scheduled to future | Navigate to that week and add the task (Until dates are expirations, not due dates) |
| Recurring weekly | Repeating |
| Habit grid | Goal with a count (0/2, −/+1); no grid across days or weeks |
| Collection page | List task with Carry Over, inside a section |
| Monthly page | Missing (the Weeks month grid only jumps between weeks) |
| Monthly recurring | Missing |
| Notes / ideas – | Missing |
| Events | Calendar sheet with the week's events |
| Weekly review / reflection | Past weeks are view-only; no review step, no notes |
| Colours / washi / handwriting | Emoji per section; Seasonal / Retro themes; no colours per section |

## 4. What I'd miss from paper (ranked)
1. Notes and ideas that aren't tasks: *dealbreaker* (I jot lesson ideas every day).
2. A monthly page and monthly recurring items like rent: *dealbreaker* for bills, *annoying* otherwise.
3. The Sunday review: deciding migration item by item at the end of the week, and seeing an item's ">" history: *annoying*.
4. Events and tasks together, laid out by day: *annoying*.
5. A habit grid I can see across the week: *annoying*.
6. Colours per section and decoration: *nice to have*.

## 5. What Tasquel gives me that paper doesn't (ranked)
1. Automatic migration, already previewed in next week and beyond. No more rewriting. This is real value.
2. Planning weeks ahead with a tap.
3. Goals that count themselves (0/2) and lists that check themselves off.
4. Events from my calendar without copying them over.
5. The Seasonal look and undo on deletes. Pleasant, but small.

## 6. Ideas for 1.2
- **A note type**: text that never needs checking off and carries over or pins like a task (§4.1, goal 10).
- **Monthly repeat** ("on the 1st", "every month"), and a due date that isn't an Until date (§4.2, goal 9).
- **"Week in review" on the first open of a new week**: list last week's unfinished items with Carry / Drop / Schedule, and show how many times an item has carried, the ">" count (§4.3, goal 7).
- **A Day view** that merges the day's events with its tasks; at minimum, show events when a day pill is tapped (§4.4, goal 5).
- **Show a goal's ticks per day** as a little habit row (§4.5).
- **Rename from the Edit tile**, keep the Add Category sheet open to add several in a row, and offer "Start blank" in the tour (goal 1).
- **Colours per section** and more icons, including school (§4.6, goal 8).
- **Collections** as cards that aren't tied to a week (goal 4).
- **Smart Add on a weekend**: read "by Thursday" as the next Thursday, or ask, and remove the day words from the name (goal 2).

## 7. Anything that looked broken or wrong
1. **Past weeks on a fresh install show every category**: the 5 deleted defaults *and* the sections created today (13-last-week, 13-two-weeks-ago). This contradicts the delete message's "Past weeks keep their history".
2. **Smart Add entered on Saturday**: "by Thursday" became the past Thursday, so the task was born "late", and the name kept "by Thursday" (08-sparkles-grade).
3. **Smart Add (rules mode) ignored "twice"**, while "2x per week" worked (09-yoga-smart vs 16-yoga-2x-smart).
4. **The 🍎 emoji draws as "?" in a box** on the card, and "School" sits off-centre next to Home and Self (07-my-spread). The simulator's emoji keyboard also showed "?" (06-emoji-picker), so this is probably the simulator's font. Check it on a phone.
5. **Choosing Goal in the options popover** reveals the Target field *behind* the popover (10-yoga-goal).
6. **Add Category exits Edit mode** after each category (06-School-added).
7. **The events count says "3 events" for 4 rows** (13-events). Minor; it may be intended.

## 8. Verdict
I'd keep it next week, *for the weekly to-do part*, mainly because migration is automatic and visible. I would not switch: my notebook stays for notes, the monthly page and rent. Without a note type and monthly items, by week three I'd be back to paper, with Tasquel as a nice extra. What would send me back sooner is losing ideas, because there's nowhere to put them.

## 9. Test file
`ux/sam/TasquelUITests/SwitcherTests.swift` (test00–test17). test05 and test12 failed partway; test06 and test15 redo them.
