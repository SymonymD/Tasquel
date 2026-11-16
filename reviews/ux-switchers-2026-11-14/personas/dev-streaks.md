# Dev (26, grad student and runner, daily Streaks user) tries Tasquel 1.1

**Short version:** Wouldn't switch. Run (3×/week), Read and Meditate set up fine, and mixing in to-dos is good. But couldn't log 3 glasses of water. Gym on Mon/Wed/Fri took three tasks flagged "Duplicate". No streak, no 7 AM reminder and no Apple Health.

No app code was changed. About 75 minutes, mostly waiting on builds and runs (load average 600–900 with six testers). A step runner (`test90_script`) read a step list at run time; each run's steps are saved as `steps-<name>.txt` and its log as `run-<name>.log` in `evidence-dev/`. Shot names below refer to `.png`/`.txt` files there.

## 1. First impressions (first minute)
- **The tour:** first page said "Your weekly task planner that keeps you on track… it stays behind, it carries over if it's unfinished, or it comes back every week." Tapped Skip (00-first-launch).
- **Home:** "Week of Nov 9", a row of day pills, five cards: Errands, Work, Fitness, Study, Appointments. Each says "Completed: 0/0" and "No tasks yet · Tap to add" (01a-home).
- **Read:** a to-do app organised by week, not a habit tracker. No grid of round habit buttons to tap, no streak numbers.
- **Familiar:** a small progress ring on each card. Mostly foreign: "categories" and "weeks" where "habits" and "days" were expected.

## 2. Per goal
**Goal 1 – Run 3×/week, log today: done, with mild trouble.**
- Fitness ▸ "Add Task". Next to the field: a "Smart Add" sparkle and a pill, "New task options: Checkbox, One-Time".
- The pill opens TYPE (Checkbox / Goal / List), AFTER THIS WEEK (One-Time / Carry Over / Repeating) and DAY (Any, M–S, calendar) (03a).
- Picked Goal + Repeating ("Comes back every week, unchecked"). No number field appeared, only the placeholder "Add repeating goal" (04b). Where do I put 3?
- After "Add Task", an inline row appeared: "Quantity ⌃⌄", "Target", "Set" (05b). Units are Quantity / Time / Custom (06b). Set 3.
- Logging: tapping the name "Run" opened rename with the keyboard (07c). The real control is "+1" under a "0/3" bar. After +1 it shows 1/3 with a partial ring (08a).
- Misleading: tapping the name renames instead of logging.

**Goal 2 – Read 20 min/day, log 20: done easily.**
- "Read 20 minutes a day" in Study with Smart Add → "Added Read · repeating goal of 2h 20m", with a "+20m" button (08c). +20m gave "20m / 2h 20m" (09a).
- Clever, but a daily habit became a weekly total: reading 2h20 on Sunday would count as a perfect week.

**Goal 3 – Water 8/day, log 3 glasses: not possible in Tasquel.**
- **Setup:** created a "Habits" card via Edit ▸ Add Category ▸ Create New Category (10a, 11c, 12b). Edit mode closed by itself.
- **Smart Add:** "Drink 8 glasses of water a day" → "repeating goal of 56 glasses" with a "+8" button (12c). Each tap logs a whole day.
- **Try 1:** long-press +8 for a custom amount. It just added 8 → "8/56" (13b).
- **Try 2:** the sliders ("Edit goal") show "Target [Custom] 56 [glasses], Step 8, Days 5|7, Step × 7 days = Target" (13c). Set Step to 1. Target silently became 7. After "Save Goal" the habit was struck through as "Done, 8 of 7 glasses" (14a, 14b). A real "wait, what?" moment.
- **Try 3:** set Target back to 56; Step jumped to 8 ("Target ÷ 7 days = 8 a step") (15a, 15b). Step 1 then Target 56 in one edit did the same (16a, 16b).
- **Help, visit 1 of 1:** Settings ▸ "How to Use Tasquel" ▸ Types ▸ Goal (19a) explains the rule exactly: "Type a step and the target becomes the step times the days… type the target and the step goes back to automatic." Help answered *why*, but confirmed it can't be done. Ended with 56/week, +8 per tap, 3 glasses unloggable.

**Goal 4 – Meditate daily: done easily (but not as a daily check).** Smart Add "Meditate every day" → "Added Meditate · repeating goal of 7" with +1 (20b). +1 gave 1/7 (21c). A weekly count, not a per-day tick: could tap 7 times on Monday.

**Goal 5 – Undo an accidental log: done easily.** "−" ("Remove 8") took water from 8 back to 0/56 (20a). Always visible next to +.

**Goal 6 – Week progress at a glance: done with trouble (partial).**
- Closed cards show only "Completed: 0/N", task names with red circles and a small card ring (20f, 22e).
- Run 1/3, Read 20m and Meditate 1/7 aren't visible until a card is opened. Goals don't count as "complete" until they hit target, so every card reads 0/N.
- "Open all cards" shows everything, but as a long scroll (21a, 21b). Streaks shows every ring on one screen.

**Goal 7 – Streaks / history: not possible.** "Previous week" shows "Week of Nov 2", view-only (21g). "Go to week" opens a month calendar (21h). Would have to flip back week by week. No streak count anywhere. Settings ▸ Feature Ideas lists "Stats & Charts – See how your weeks, goals and habits went" as not built yet (17a).

**Goal 8 – Gym Mon/Wed/Fri: done with trouble (3 tries, Help gave the hint).**
- **Try 1:** Smart Add "Gym every Monday, Wednesday and Friday" → "Added Gym · repeating goal of 3", days dropped (20c).
- **Try 2:** options popover, Checkbox + Repeating, tapping Monday, Wednesday, Friday. Day is single-choice, so only Friday stuck; today is Saturday, so instantly "Fri · late" (21e, 21f). Placeholder "Add Repeating Task for Fri" hinted at one day only.
- **Try 3:** following Help ▸ Days ("Smart Add picks up 'on Friday' or 'every Monday'"): "Gym every Monday" and "Gym every Wednesday" separately (22a, 22b). They show on Monday (day pill ▸ "Monday and tasks with no day", 22c). But now three "Gym" tasks plus the stray Gym goal, each tagged orange "Duplicate", and Mon/Wed say "late" on day one.

**Goal 9 – 7 AM meditate reminder: not found / not possible.** Looked in: Meditate's options popover (no time or bell, 21d); Settings ▸ Reminders (only "Expiration Reminders – A notification at 9 AM the day before a task's date…", 16c); card edit mode (a clock that sets an *expiration*, plus pin and trash, 22d). Help ▸ Days and Dates mentions only the 9 AM notice (19c).

**Goal 10 – To-dos alongside habits: done easily.** "Sign up for 10K" with Return in Fitness, "Buy running shoes" in Errands (20d, 20e). Default Checkbox / One-Time, with sub-task "+". They live well next to habits — the one thing Streaks can't do. Downside: cards get crowded: Fitness shows "Gym, Gym, Gym MWF, Run, Gym, +1 more" (22e).

## 3. Translation table
| Streaks concept (from memory, may be dated) | Tasquel |
|---|---|
| A habit | A Repeating task in a category card |
| Daily habit | Goal, Repeating, target 7/week, +1 (Smart Add "every day") |
| X times per week | Goal, Repeating, target X (good fit) |
| Timed habit | Goal with Time unit; "+20m" button, no timer |
| N per day, logged one at a time (water) | **Missing:** step locked to target ÷ days, so +8 only |
| Specific weekdays | One task per weekday (single-choice Day), flagged "Duplicate" |
| Tap the habit to complete | "+1"/"+20m" button or checkbox circle; tapping the name renames |
| Undo a tap | "−" button (good) |
| Ring per habit on the home grid | Ring per card only; per-goal ring and bar only inside an open card |
| Streak count | **Missing** |
| Per-habit history / calendar | Week-by-week view-only past weeks; no per-task history |
| Reminder at a time | **Missing** (only 9 AM expiration notices) |
| Apple Health link | **Missing** |
| Stats | **Missing** ("Stats & Charts" is a Feature Idea) |

## 4. What I'd miss from Streaks (ranked)
1. Streak counts and history ("how many weeks did I hit 3 runs"). *Dealbreaker.*
2. Per-task time reminders (7 AM meditate). *Dealbreaker.*
3. Logging partial counts (3 of 8 glasses). *Dealbreaker* for water.
4. All habit rings visible on one screen. *Annoying.*
5. One habit on several weekdays without duplicates or "late" warnings. *Annoying.*
6. Apple Health auto-logging of runs. *Annoying.*
7. True daily habits: one tick per day, not 7 per week that can be bunched. *Annoying.*
8. Tap the habit itself to log. *Nice to have.*

## 5. What Tasquel gives me that Streaks doesn't (ranked)
1. To-dos and habits on one weekly board, with categories ("Buy running shoes" next to Run). Real value.
2. Smart Add. "Read 20 minutes a day" became a sensible goal with a +20m step; "every Monday" sets a day.
3. Weekly framing for "3×/week" goals (1/3 bar). Natural for a runner.
4. Carry Over for unfinished to-dos, sub-tasks and Lists.
5. Week calendar, day filter on the pills, themes. Minor for me.

Valuable as a weekly to-do app, thin as a habit tracker.

## 6. Ideas for 1.2
- **Decouple step from target** (goal 3, 13c–16b). Let Step be any number while Target stays, or offer a "per day" target ("8 a day": today 3/8, week 3/56). At minimum, warn before Step silently rewrites Target.
- **Long-press + for a custom amount** (13b).
- **Multi-select Day for one task** (M W F), and have Smart Add "every Monday, Wednesday and Friday" make one task (20c, 21e). Don't flag same-name tasks on different days as "Duplicate" (22b). Don't mark a newly created repeating task "late" for days that passed before it existed (21f, 22b).
- **Show goal progress on closed cards** ("Run 1/3", "Read 20m/2h20m") or a compact "habits" view with every ring (20f, 22e).
- **Streaks and history** (goal 7, 21g): a "weeks in a row" chip on repeating goals and a per-task history sheet. Promote "Stats & Charts" (17a).
- **Per-task time reminders** (goal 9).
- **A daily-habit mode:** a row of 7 day-dots instead of a 0/7 count (goal 4).
- **Tap the task's ring/circle to log one step** for goals (07c).
- **Optional Apple Health** for runs and water, isolated and Apple-only.

## 7. Things that looked broken or wrong
- **Edit goal panel overflows the screen.** Unit field ("gla…") spans x 356–430 and "Save Goal" spans 214–430 on a 402-pt-wide screen; both clipped (13c-edit-goal.png, 14a-step-1.png).
- **Changing Step silently redefines the habit**; ends up marked Done at "8 of 7 glasses" (14b-saved.png).
- **Smart Add drops listed weekdays.** "Gym every Monday, Wednesday and Friday" became "goal of 3" (20c-gym-smart.png).
- **"Duplicate" and "late" badges on intentional per-day tasks** (22b-fitness-top.png).
- **About shows "Version, 1.0.3 / Build, 11"** next to "What's New in 1.1" (17a-feature-ideas.txt).
- **VoiceOver labels leak SF Symbol names:** new-category folder icon read as "Move" (11c-typed-habits.txt); Dark-theme moon "Do Not Disturb", sun "Brightness Higher", Privacy hand "Block" (16c-settings.txt); repeat icon "Repeat 1"; raw "target" and "1.circle" (03a-options-menu.txt).
- **Minor:** a tap in the status-bar area didn't dismiss the options popover (03b); the next tap landed on "Repeating" by accident (03c).

## 8. Verdict
Wouldn't switch. Run, Read and Meditate worked well enough, and "Buy running shoes" next to habits is good. But within one evening: water can't be logged a glass at a time; gym days came out as duplicate tasks marked "late"; no streak, no 7 AM reminder, no Health link. After a week might keep it for to-dos and grad-school chores; habits would go back to Streaks. What would win me: per-day counts with a free step, multi-day tasks, streaks and history, and time reminders.

## 9. Test file
`ux/dev/TasquelUITests/SwitcherTests.swift` (tests 00–03 plus the step runner `test90_script`).
