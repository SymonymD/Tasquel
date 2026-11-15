# Tasquel 1.1 review: your brief (read all of it first)

You're one of seven reviewers testing **Tasquel 1.1** in the iOS Simulator the way an Apple App Reviewer and a picky first-time user would. The developer wants to find usability problems and rejection risks *before* App Review and real users do.

**Your role: Edge cases and small screens.** 

On the smallest iPhone:
- **Layout:** everything fits; no buttons are pushed off the screen by the keyboard; sheets work at their smallest size.
- **Content:** very long names and text, emoji, an empty state for every screen, hundreds of items, the maximum values fields accept, and pasted multi-line text.
- **Time and place:**
  - dates around midnight, week boundaries, month and year ends;
  - **other time zones:** launch with `app.launchEnvironment["TZ"]` set to a zone far ahead (`Pacific/Kiritimati`, UTC+14) and one far behind (`Pacific/Pago_Pago`, UTC−11). "Today" is then a different date than at home, often across a week boundary. Check that today, the current week and every item's day are right;
  - **travel:** create items in one zone, then relaunch in another. Nothing should move to a different day, get duplicated or disappear;
  - **daylight saving:** the simulator's clock can't be moved, so the DST weeks themselves are tested in unit tests (see Code review). In the app, use a zone with DST (`America/New_York`) and one without (`Asia/Tokyo`, `America/Phoenix`) and compare;
  - another locale, with commas as decimals and translated text lengths;
  - right-to-left.
- **Lifecycle:**
  - backgrounding mid-edit, then relaunching;
  - force-quitting right after a change: did it save?
  - first launch versus later launches;
  - permissions denied, then granted later in Settings.
- **Interruptions:** a sheet opened while the keyboard is up; Control Center or Notification Center pulled down mid-task (simulate with backgrounding).

In this app: **time zones and week boundaries with the new days and dates** — a day task and a dated task made in New York, then relaunched in `Pacific/Kiritimati` (UTC+14, already Monday there: a new week) and `Pacific/Pago_Pago`; a task for a day gone by near the week's end; dates at month and year ends (Dec 31 → a week across the new year), a date years away, Feb 29; Smart Add dates ("12/31", "dec 31", "by friday", "tomorrow" on the week's last day, which is today); Sunday vs Monday week start with dated tasks. Long names beside "Tue · late", "Nov 28" and "⧉ Duplicate" on the SE; the moved pop-up and Add Category on the small screen with the keyboard up; 20+ categories with two pinned; a list of 100 items with duplicates. (The SE's largest-text arrows and strip are already known.)

**Look hardest at what changed since the last release:**
The full diff since the live version (1.0.3) is `/private/tmp/claude-501/-Volumes-T7-Design-JB-Portfolio-SYMONYM-Tasquel/3a12228a-12a9-4d7a-ac59-5b0e1bbb8e3b/scratchpad/applereview-2026-11-15/changes-since-1.0.3.diff` (your copy has no git history; 40 app files, about +6,000 lines). The user-facing list is `Tasquel/WhatsNew.swift` in your copy. In a user's words:
1. **Days for tasks:** the type/mode popup has a Day row (Any, then one letter a day). A task with a day shows "Fri" after its name; on its day "Today" (green); once its day has gone by unfinished in this week, "Tue · late". Tasks sort by day within a card. The day strip under the week title shows each day's date (today green, past days blue); tapping a day pill filters every card to that day's tasks plus those with no day ("Thursday and tasks with no day · Show All"); today's pill also shows late tasks. Cards holding today's unchecked tasks wiggle once when the app opens (not with throwaway data).
2. **A day that has gone by:** a *new* task given a weekday already past this week goes into **next week's** card of the same name on that day. The screen then pages to next week, a pop-up says "Added to next week" (OK / Back to This Week), and that card shows a note with Undo. An *existing* task given a past day stays put and isn't marked late.
3. **Dates:** a calendar cell at the end of the popup's Day row ("Until"), and in a card's own edit mode a clock that replaces the type/mode button ("Expires", Date | Week). A task is gone the day after its date; its checkbox becomes a ring filling green as the days pass; a reminder notification comes at 9 AM the day before (Settings ▸ Reminders ▸ Expiration Reminders). **A one-time task dated after its week moves into its date's week** (pop-up "Moved to the week of …"); a carry-over one carries until then; a repeating one repeats until then. Dated rows show "Nov 28". A day and a date are one choice for one-time and carry-over tasks. Go to Week rings days with dated tasks (purple) and day tasks (green).
4. **Smart Add** (✨ only; Return adds text as typed): written dates ("dentist december 15" adds the task and offers "Until Tue, Dec 15?  Set Date", which stays until answered); "by / due / until / till / before <date>" makes it Carry Over; "today", "tomorrow", a day at the end ("Call mom Sunday"), "remind me to" is dropped, "twice this week", "Gym Mon Wed Fri"; parts joined by commas / and / then become a list named by the first part ("Go to the zoo and harass penguins"); with List picked first, the parts are the list's name and items; numbers that name things stay ("Exam 3"). The "Added … · Undo" note lasts 8 s.
5. **Pins:** up to two cards (in Edit, a pin at a card's top-leading corner) and two tasks a card (in the card's own edit mode, a pin between the type/mode button and the trash). Pinned ones show first, with a small orange pin; unpinned, they go back to their place.
6. **Duplicates:** tasks in one card (same day or both none) or items in one list with the same name get "⧉ Duplicate"; adding one shows a note with Undo.
7. **Renaming:** clearing a name and pressing Return deletes it (with Undo); Escape on a hardware keyboard cancels a rename.
8. **Card ring** counts goal progress and checked list items.
9. **Card edit mode:** the clock, pin, trash and handle run out one after another; the old "This week only" switch is now a "◯ / ✓ Just this week" chip on the Completed line, and the line says "· Just this week".
10. **Edit mode and Add Category:** the Add Category tile is first (top left); the sheet stays open after an add ("Added X · add another, or tap Done"); Create New has a "Just this week" toggle above Cancel / Add Category, off each time; Saved Categories has Edit / Done beside its heading, a green + on rows you can add, and "Removed X" after a removal.
11. **Bottom bar:** on another week a green house grows out of the week selector's glass and goes back to this week (left of the selector on later weeks, at Edit's place on earlier ones).
12. **Header:** a "What's New?" pill slides out from behind the Tasquel mark for people who updated (twice, then gone); What's New is also in Settings ▸ Help. Holiday marks on the Tasquel mark (Thanksgiving feathers and a turkey that runs out once per app open in Thanksgiving week; string lights; confetti).
13. **Looks:** Settings ▸ Appearance ▸ Seasonal (colors and backdrop by season, light and dark); Retro text fields look like DOS (bracket frames, underscore cursor).
14. **Help** is in tabs (Q&A first, then Weeks, Cards, Tasks, Types, Modes, Dates), as pills over swipeable pages.
15. **iPad landscape (4 columns):** an open card takes half the width, in two lanes.
16. **Goal editor:** a Unit row when a custom unit doesn't fit; an orange "Already 8 of 7: saving marks it done" line.
17. **Order holds while you work:** a card's task order doesn't change while Add Task is in use or a task's popup is open; then tasks move into place.
18. **Speed:** scrolling, opening cards and checking tasks are much faster. Weeks before you started show no cards; past weeks no longer have a "Past week · view only" banner.
19. **Later weeks:** renaming next week's copy of a task changes only its name; picking a task's mode in the popup brings back a copy deleted from later weeks.

Saved data changed: new task fields `hasOwnTitle`, `isPinned`, `expiresOn`, `expirySetOn`, `expiresWithWeek`, `dayOfWeek`, `daySetOn`; a category's `isPinned`; settings.json `remindsBeforeExpiry` and the appearance value `seasonal`; UserDefaults `lastLaunchedVersion` and `whatsNewButtonOpens`. Data saved by 1.0.3 has none of them.


**The main thing to look for:** how one action affects *other* elements. After every action, look beyond the thing you touched:
- other items, lists and cards: their state, order, counts and content;
- bars, headers and titles;
- open sheets, popovers and menus;
- the keyboard and which field has focus;
- banners and Undo messages;
- the scroll position;
- other screens, tabs, days and weeks;
- Settings;
- whether everything survives a relaunch.

Things left behind, things that move or vanish, stale state, and controls that stop working are exactly what we want.

## The app
Tasquel is a weekly checklist for iPhone and iPad (iOS 26). Each week holds categories, shown as cards in a grid (two columns on iPhone, three or four on iPad); a card opens to full width to show its tasks. Tasks have a type (checkbox with sub-tasks, goal with a target and −/+ steps, or list with items) and a mode (Carry Over: moves to next week until done; Repeating: every week; One-Time: never carries), and now optionally a day and a date. Weeks page by swiping sideways or with the arrows of the week selector in the bottom bar; past weeks are view only; future weeks are previews until edited and follow the week before. There's Smart Add (Apple Intelligence reads a typed task), calendar events for the week, themes (System, Light, Dark, Retro with colors, Seasonal), Settings, Help, What's New, a welcome tour and onboarding. iPhone is portrait only; iPad turns every way. Everything is stored on the device.

**Today is Sunday, 2026-11-15.** Weeks start on Monday by default (Settings ▸ Week), so today is the last day of the week of Nov 9 and every other weekday this week has already gone by: a new task given Monday–Saturday goes into next week (by design, item 2 above). With Sunday as the week's start, today is the first day instead. `-demoData -demoToday 2026-11-11` makes a Wednesday today, for a mid-week view. Thanksgiving week is Nov 23–29 (Monday start); `-demoTurkey` shows it on any day.

The spec is in `/private/tmp/claude-501/-Volumes-T7-Design-JB-Portfolio-SYMONYM-Tasquel/3a12228a-12a9-4d7a-ac59-5b0e1bbb8e3b/scratchpad/applereview-2026-11-15/Edge/project/CLAUDE.md` (the full spec: read "Key behaviors" and "UI Patterns" plus everything about your area; it's long and dense), `/private/tmp/claude-501/-Volumes-T7-Design-JB-Portfolio-SYMONYM-Tasquel/3a12228a-12a9-4d7a-ac59-5b0e1bbb8e3b/scratchpad/applereview-2026-11-15/Edge/project/Tasquel/HelpSheet.swift` (the in-app Help, which is what users are told) and `/private/tmp/claude-501/-Volumes-T7-Design-JB-Portfolio-SYMONYM-Tasquel/3a12228a-12a9-4d7a-ac59-5b0e1bbb8e3b/scratchpad/applereview-2026-11-15/Edge/project/Tasquel/WhatsNew.swift` (what updaters are told is new). **Read it first:**
- **A bug** is anything that contradicts the spec.
- **A usability issue** is anything the spec describes that is confusing or awkward in practice.

## Rules
- Work **only** in your own project copy, derived-data folder, shots folder and simulator(s):
  - copy: `/private/tmp/claude-501/-Volumes-T7-Design-JB-Portfolio-SYMONYM-Tasquel/3a12228a-12a9-4d7a-ac59-5b0e1bbb8e3b/scratchpad/applereview-2026-11-15/Edge/project`
  - derived data: `/private/tmp/claude-501/-Volumes-T7-Design-JB-Portfolio-SYMONYM-Tasquel/3a12228a-12a9-4d7a-ac59-5b0e1bbb8e3b/scratchpad/applereview-2026-11-15/Edge/derived`
  - shots: `/private/tmp/claude-501/-Volumes-T7-Design-JB-Portfolio-SYMONYM-Tasquel/3a12228a-12a9-4d7a-ac59-5b0e1bbb8e3b/scratchpad/applereview-2026-11-15/Edge/shots`
  - simulator(s): `4A774800-B6EC-42DC-BB04-2DA9F039844D` (iPhone SE (3rd generation))
- Never build, edit or test anything in `/Volumes/T7/Design/JB Portfolio/SYMONYM/Tasquel/Tasquel`; that's the real project. Never touch another reviewer's simulator.
- **Never tap these.** They reach the real world and can't be taken back:
  - **Settings ▸ Feature Ideas ▸ Send Anonymously** (in Retro: "> Send"). It posts to the live survey server (`https://jbfentner.com/tasquel/survey`). Ticking boxes and typing a comment are fine; never send.
  - On the live website pages that Settings ▸ Support and Privacy open in Safari: reading is fine, but never submit anything there.
  - There's no StoreKit, mail or sharing. EventKit only reads. Notification permission prompts are fine to answer in your own simulator.
  Opening their screens to check layout is fine.
- **Don't fix the app.** Find, reproduce and explain. You may read any source in your copy to name the likely cause.
- **Time:** aim to finish in about an hour. If you're running long, stop testing and report what you have.
- **The Mac is shared** with other reviewers. If a test run hangs before the app starts, check `uptime`: with a load average in the hundreds, wait a few minutes rather than retrying at once.
- **Simulator limits:** Apple Intelligence isn't in the simulator: test Smart Add with `-smartAddRules` (the rules the app applies after the model; real wording quality is a phone check). Haptics can't be felt. Calendar access: prefer `-fakeCalendar`. Your simulators run iOS 26.3; the user's phone runs iOS 27.2, which can differ in animation timing. Animations (the house, the What's New pill, the turkey, the edit-mode icons) can't be seen by XCUITest: record the simulator (`xcrun simctl io <UDID> recordVideo`) and look at frames if you need to.
- **Throwaway data turns some things off on purpose:** with `-isolatedData`, `-isolatedDataID` or `-demoData` there's no "Today" pulse, no opening card wiggle, no turkey (unless `-demoTurkey`), and no reminder scheduling or notification prompt, so XCUITest can settle. To check those, launch without those flags (your simulator is fresh, so nothing real is at risk) and reset with `xcrun simctl uninstall <UDID> com.symonym.Tasquel`.

## Driving the app
Add your own XCUITest file(s) to `TasquelUITests` in your copy. Name them `ReviewEdge*.swift` so they're easy to collect. Build and run:

```
cd /private/tmp/claude-501/-Volumes-T7-Design-JB-Portfolio-SYMONYM-Tasquel/3a12228a-12a9-4d7a-ac59-5b0e1bbb8e3b/scratchpad/applereview-2026-11-15/Edge/project
xcodebuild -project Tasquel.xcodeproj -scheme Tasquel -destination 'id=<your simulator UDID>' \
  -derivedDataPath /private/tmp/claude-501/-Volumes-T7-Design-JB-Portfolio-SYMONYM-Tasquel/3a12228a-12a9-4d7a-ac59-5b0e1bbb8e3b/scratchpad/applereview-2026-11-15/Edge/derived -parallel-testing-enabled NO \
  -test-timeouts-enabled YES -maximum-test-execution-time-allowance 240 \
  -only-testing:TasquelUITests/<YourClass>/<testName> test > /private/tmp/claude-501/-Volumes-T7-Design-JB-Portfolio-SYMONYM-Tasquel/3a12228a-12a9-4d7a-ac59-5b0e1bbb8e3b/scratchpad/applereview-2026-11-15/Edge/shots/run.log 2>&1
grep -E "error:|Test Case|REVIEW" /private/tmp/claude-501/-Volumes-T7-Design-JB-Portfolio-SYMONYM-Tasquel/3a12228a-12a9-4d7a-ac59-5b0e1bbb8e3b/scratchpad/applereview-2026-11-15/Edge/shots/run.log
```

Give the Bash tool a long timeout (up to 600000 ms). The first build takes a few minutes, and later ones are incremental. Write to a log file as above: piping xcodebuild through grep hides all progress until it ends.

Your tests are kept and re-run after the fixes, to check that a fix didn't break something elsewhere. So write them to be re-run:
- give each finding its own test, named after it (`testUndoBannerStaysAfterRename`);
- **assert what should happen**, so the test fails while the bug is there and passes once it's fixed;
- keep the tests behind "Checked and fine" too, asserting what you saw work;
- make each test start from a clean launch and not depend on another test having run first.

### Launch arguments
Debug builds only. From the spec (CLAUDE.md ▸ Testing Launch Arguments):
- `-isolatedData`: throwaway storage, fresh on every launch, onboarding first. `launchFresh` (in `TasquelUITests/GoalUITests.swift`) taps through onboarding.
- `-isolatedDataID <name>`: the same throwaway storage across launches. **Use it for relaunch checks.** Open cards aren't remembered across launches (by design), so open the card again after a relaunch.
- `-demoData`: throwaway storage, no onboarding, the current week filled with sample tasks (Errands has a Groceries list; "Plan Mom's birthday" expires in four days). `-demoAppearance <system|light|dark|retro>`, `-demoFirstCard <name>` (that card first), `-demoToday yyyy-MM-dd` (that day is today by the store's clock; only with `-demoData`).
- `-fakeCalendar`: sample calendar events instead of the real calendar.
- `-smartAddRules`: Smart Add without the model (2 s pause; `-smartAddDelay <seconds>` changes it).
- `-demoWhatsNew`: the header's What's New pill as if just updated. `-demoTurkey`: any day is Thanksgiving week for the turkey. `-demoHoliday <thanksgiving|holidaySeason|newYear>`: that holiday mark. `-demoSeason <spring|summer|fall|winter>`: that season for Seasonal.

Useful in the UI tests: `app.addTaskField` (`TasquelUITests/AddTaskField.swift`) taps a card's + and returns the Add task field. Closed cards are buttons labeled "Open <Card>, …". A task's options button is "Task options: <Type>, <Mode>". Checkboxes are "Complete <title>" / "Mark <title> incomplete". A list's chevron has the identifier "Fold <list title>". New identifiers: day pills "Day Thursday", the day strip "Week days", "Just this week chip", "Pin <card or task>", "Expiration <task>", the bar's house "Bar Back to This Week", the moved pop-up's "Moved OK" and "Moved Back to This Week". The existing files in `TasquelUITests/` (CardStateUITests, AddTaskUITests, SmartAddUITests, ThisWeekOnlyUITests, BottomBarUITests, CardOrderUITests) show many more patterns; read one or two before writing your own.

Also available in any app (pass through `app.launchArguments`):
- **Text size:** `-UIPreferredContentSizeCategoryName`, `UICTContentSizeCategoryAccessibilityXXXL` (also `…AccessibilityL`, `…XL`, `…XXL`, `UICTContentSizeCategoryXXXL`).
- **Another language:** `-AppleLanguages`, `(de)`, `-AppleLocale`, `de_DE`. Try `(ar)` for right-to-left.

`/Users/johnfentner/.claude/skills/applereview/references/simulator-tips.md` has everything else: dark mode, screenshots, recordings, rotation, relaunch, the accessibility audit, and the simulator traps that look like app bugs but aren't. **Read it before your first run.**

### Already known (don't report these)
- The project still says version 1.0.3 (11); it becomes 1.1 (12) after this review. Don't report the version number.
- **iPad:** typing a task's words and then tapping its type/mode button adds the words at once as a checkbox (the button closes the keyboard first, and closing the keyboard adds what's typed), so the type picked applies to the next task. `CardStateUITests.testAddFieldSaysPickedType` fails on iPad for this. Known; you may note how it feels, but don't spend time on it.
- **iPhone SE at the largest text size:** the week arrows are 40pt (< 44) and the day strip is 347.75pt wide (> 343). Known.
- Left open from the 1.0.3 review: Match App Icon to Theme can fail silently; the Welcome Tour is plain system dark in every theme; turning Just this week on and straight off moves next week's own tasks.
- By design (the user's decisions; report only if it's broken, not because it's surprising): a new task for a weekday already gone by this week goes into next week; a one-time task dated after its week moves into its date's week; renamed later copies still leave with their source; card order is a snapshot that doesn't change while you use the cards; duplicates are flagged only within one card (and same day); Smart Add reads words only from the ✨ button; open cards aren't remembered across launches; deleting a task doesn't ask (Undo for 5 s); no swipe actions or long-press menus on tasks; a repeating list keeps its checks; typing a goal's Step recalculates its Target.
- Flaky UI tests under load: `GoalUITests.testReorderTasksByHandle` (drag timing) and `testEditGoalFieldsFocusOnFirstTap`.

### Before reporting anything
- **Reproduce it at least twice.**
- **Separate app bugs from problems in your own test code.** Timing, typing too fast, a wrong label and off-screen elements are test problems. If something is merely off-screen, scroll first.
- **Look at your screenshots.** Many problems are visual and pass every assertion.
- **A hang is serious.** If a query fails with "main thread busy" or "Timed out while evaluating UI query", the app hung. Record exactly what led to it.

## Your report
Return it as your final message. Don't write it to a file (the harness doesn't allow it); it's saved for you.

1. **Findings, most severe first.** Give each one:
   - a title
   - a severity:
     - **Rejection risk:** a crash, hang, data loss, broken feature, misleading UI, a privacy or guideline problem, or an accessibility blocker.
     - **Major:** a user is likely to get confused or stuck, or an action visibly breaks another element.
     - **Minor:** noticeable, but the user can recover.
     - **Polish:** a visual nit.
   - device and settings
   - exact steps
   - expected vs actual
   - evidence: screenshot paths in `/private/tmp/claude-501/-Volumes-T7-Design-JB-Portfolio-SYMONYM-Tasquel/3a12228a-12a9-4d7a-ac59-5b0e1bbb8e3b/scratchpad/applereview-2026-11-15/Edge/shots`, the test name and its output
   - likely cause, as file:line in your copy
   - a suggested fix
2. **Checked and fine:** one line each, so we know what's covered.
3. **Your test files:** their paths, which test reproduces which finding, and which tests cover the "Checked and fine" areas.
4. **Couldn't check in a simulator:** things in your area that only a real device shows, such as haptics, Apple Intelligence, the camera, how a gesture or animation feels under a finger, real-world speed, notifications arriving. One line each, written as something to try ("drag a task to the bottom of a long card: does the scrolling feel too fast?"). These become the user's phone checklist.

Keep the report under about 1,200 words and put the detail in the evidence files. Quality over quantity: three real, well-evidenced findings beat fifteen guesses.
