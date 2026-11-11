# Tasquel 1.0.3 review: your brief (read all of it first)

You're one of seven reviewers testing **Tasquel 1.0.3** in the iOS Simulator the way an Apple App Reviewer and a picky first-time user would. The developer wants to find usability problems and rejection risks *before* App Review and real users do.

**Your role: Code review.** 

You don't drive the app; you read it. Trace how each user action changes state, and what else on the screen depends on that state. Look for:
- an action that updates one view but leaves another stale;
- state that survives when it shouldn't (another week, item or window);
- edits lost when a view goes away;
- races between animations and data changes.

Also check:
- **Crash risks:** force unwraps, out-of-range indexing, `fatalError` in reachable paths, and decoding that throws away the whole file when one field is wrong.
- **Data safety:** saves that can fail silently, migrations for old data, what a new field means in old files, and whether a failed load can overwrite good data.
- **Dates and time zones:**
  - days computed as a fixed 86,400 seconds (`86400`, `60 * 60 * 24`, `addingTimeInterval` by days) instead of with `Calendar`, which goes wrong in the daylight-saving weeks;
  - week starts and day keys that depend on the device's time zone or first weekday;
  - saved dates that move when the time zone changes.

  Write unit tests with a fixed `Calendar` and time zone (`America/New_York`) for the DST weeks: the Sunday clocks go forward (March) and back (November), plus the weeks around them. Also test a zone without DST.
- **Concurrency:** UI or state changed off the main actor, and state changed after an `await` while a view is mid-animation.
- **Everything in `app-review-checklist.md`:** privacy manifest, purpose strings, entitlements, links, placeholder text, In-App Purchase rules and the rest. Each item there is a rejection reason seen in practice.
- **Tests:** what the existing tests cover, and the riskiest behavior they don't.

Report the same way as the others, with file:line and a concrete scenario for each finding ("open X, then Y: Z is lost"). A finding is a scenario you can describe, not a style preference.

In this app: read the whole diff since the live version first (`/private/tmp/claude-501/-Volumes-T7-Design-JB-Portfolio-SYMONYM-Tasquel/c2c1eb9b-b059-49df-87cc-82751dbd8d02/scratchpad/applereview-2026-11-10/changes-since-1.0.2.diff`), especially `ChecklistStore.swift` (This week only's saved modes, `setListFolded` and `foldLaterCopies`), `CategoryCard.swift` (`TaskReorder`), `TaskAutoScroller.swift` and `ParsedTask.swift` (Smart Add sessions). The App Review checklist is `/Users/johnfentner/.claude/skills/applereview/references/app-review-checklist.md`. Unit tests are Swift Testing in `TasquelTests/`; add yours as `TasquelTests/ReviewCode*.swift` (use a fixed `Calendar` and time zone; `TestClock` in TasquelTests.swift shows how, and `makeIsolatedStore` there is `private`, so write your own copy of it) and run them on your simulator with `-only-testing:TasquelTests`.

**Look hardest at what changed since the last release:**
The full diff since the live version (1.0.2) is `/private/tmp/claude-501/-Volumes-T7-Design-JB-Portfolio-SYMONYM-Tasquel/c2c1eb9b-b059-49df-87cc-82751dbd8d02/scratchpad/applereview-2026-11-10/changes-since-1.0.2.diff` (your copy has no git history). In a user's words:
1. **Folding lists (new):** a list task has a chevron just before its type/mode button. Folded, its items and its Add Item row are hidden and the row shows how many items are checked ("2 of 5"). A new list starts open. The fold is saved, isn't counted as an edit, and carries into next week's copies; past weeks show every list open. Folding adds an item that was typed but not yet added.
2. **Reordering tasks:** in a card's own edit mode, each task's handle lifts the task at the first touch; it follows the finger, the other tasks slide to make room, and letting go drops it. While a task is held, the week doesn't swipe, and holding it near the top or bottom of the screen scrolls the cards.
3. **This week only** (the switch in a card's own edit mode): turning it on makes the card's carry-over and repeating tasks one-time but remembers each task's mode; turning it off puts the modes back exactly. Adding a carry-over or repeating task to such a card, or changing a task to one, turns it off. Copies that later weeks receive into a This week only card arrive one-time.
4. **Smart Add:** sessions ("Gym 3 times 45 min" becomes a 135-minute goal that counts 45 a tap over 3 days; "3x a week for 45 minutes", "three 45-minute sessions", "run 3 times 5 km"), and a list no longer gets its own title as an item.
5. **Rename fields** for tasks, sub-tasks and list items wrap onto more lines (up to 8); Return saves.

Saved data changed: two new task fields in `checklist.json`, `modeBeforeThisWeekOnly` and `isListFolded`.


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
Tasquel is a weekly checklist for iPhone and iPad (iOS 26). Each week holds categories, shown as cards in a grid (two columns on iPhone); a card opens to full width to show its tasks. Tasks have a type (checkbox with sub-tasks, goal with a target and −/+ steps, or list with items) and a mode (carry-over: moves to next week until done; repeating: every week; one-time). Weeks page by swiping sideways or with the arrows in the bottom bar; past weeks are view only; future weeks are previews until edited and follow the week before. There's Smart Add (Apple Intelligence reads a typed task), calendar events for the week, themes (System, Light, Dark, Retro with colors), Settings, Help, a welcome tour and onboarding. iPhone is portrait only; iPad turns every way. Everything is stored on the device.

The spec is in `/private/tmp/claude-501/-Volumes-T7-Design-JB-Portfolio-SYMONYM-Tasquel/c2c1eb9b-b059-49df-87cc-82751dbd8d02/scratchpad/applereview-2026-11-10/Code/project/CLAUDE.md` (the full spec: read "Key behaviors" and "UI Patterns" plus everything about your area; it's long and dense) and `/private/tmp/claude-501/-Volumes-T7-Design-JB-Portfolio-SYMONYM-Tasquel/c2c1eb9b-b059-49df-87cc-82751dbd8d02/scratchpad/applereview-2026-11-10/Code/project/Tasquel/HelpSheet.swift` (the in-app Help, which is what users are told). **Read it first:**
- **A bug** is anything that contradicts the spec.
- **A usability issue** is anything the spec describes that is confusing or awkward in practice.

## Rules
- Work **only** in your own project copy, derived-data folder, shots folder and simulator(s):
  - copy: `/private/tmp/claude-501/-Volumes-T7-Design-JB-Portfolio-SYMONYM-Tasquel/c2c1eb9b-b059-49df-87cc-82751dbd8d02/scratchpad/applereview-2026-11-10/Code/project`
  - derived data: `/private/tmp/claude-501/-Volumes-T7-Design-JB-Portfolio-SYMONYM-Tasquel/c2c1eb9b-b059-49df-87cc-82751dbd8d02/scratchpad/applereview-2026-11-10/Code/derived`
  - shots: `/private/tmp/claude-501/-Volumes-T7-Design-JB-Portfolio-SYMONYM-Tasquel/c2c1eb9b-b059-49df-87cc-82751dbd8d02/scratchpad/applereview-2026-11-10/Code/shots`
  - simulator(s): `27F04AC7-7394-41CA-AFAF-675D0A0131C1` (iPhone 17 Pro (only for running unit tests))
- Never build, edit or test anything in `/Volumes/T7/Design/JB Portfolio/SYMONYM/Tasquel/Tasquel`; that's the real project. Never touch another reviewer's simulator.
- **Never tap these.** They reach the real world and can't be taken back:
  - **Settings ▸ Feature Ideas ▸ Send Anonymously** (in Retro: "> Send"). It posts to the live survey server. Ticking boxes and typing a comment are fine; never send.
  - On the live website pages that Settings ▸ Support and Privacy open in Safari: reading is fine, but never submit anything there.
  Opening their screens to check layout is fine.
- **Don't fix the app.** Find, reproduce and explain. You may read any source in your copy to name the likely cause.
- **Simulator limits:** Apple Intelligence isn't in the simulator: test Smart Add with `-smartAddRules`. Haptics can't be felt. Calendar access: prefer `-fakeCalendar`; granting access in your own simulator is harmless (it has no real events, and the app only reads them). Use only the simulator(s) given to you: they run iOS 26.3. The iOS 26.0 runtime on this Mac is a beta that crashes the app at launch, which isn't an app bug.
- **Time:** aim to finish in about an hour. If you're running long, stop testing and write the report with what you have.

## Driving the app
Add your own XCUITest file(s) to `TasquelUITests` in your copy. Name them `ReviewCode*.swift` so they're easy to collect. Build and run:

```
cd /private/tmp/claude-501/-Volumes-T7-Design-JB-Portfolio-SYMONYM-Tasquel/c2c1eb9b-b059-49df-87cc-82751dbd8d02/scratchpad/applereview-2026-11-10/Code/project
xcodebuild -project Tasquel.xcodeproj -scheme Tasquel -destination 'id=<your simulator UDID>' \
  -derivedDataPath /private/tmp/claude-501/-Volumes-T7-Design-JB-Portfolio-SYMONYM-Tasquel/c2c1eb9b-b059-49df-87cc-82751dbd8d02/scratchpad/applereview-2026-11-10/Code/derived -parallel-testing-enabled NO \
  -test-timeouts-enabled YES -maximum-test-execution-time-allowance 240 \
  -only-testing:TasquelUITests/<YourClass>/<testName> test > /private/tmp/claude-501/-Volumes-T7-Design-JB-Portfolio-SYMONYM-Tasquel/c2c1eb9b-b059-49df-87cc-82751dbd8d02/scratchpad/applereview-2026-11-10/Code/shots/run.log 2>&1
grep -E "error:|Test Case|REVIEW" /private/tmp/claude-501/-Volumes-T7-Design-JB-Portfolio-SYMONYM-Tasquel/c2c1eb9b-b059-49df-87cc-82751dbd8d02/scratchpad/applereview-2026-11-10/Code/shots/run.log
```

Give the Bash tool a long timeout (up to 600000 ms). The first build takes a few minutes, and later ones are incremental. Write to a log file as above: piping xcodebuild through grep hides all progress until it ends.

Your tests are kept and re-run after the fixes, to check that a fix didn't break something elsewhere. So write them to be re-run:
- give each finding its own test, named after it (`testUndoBannerStaysAfterRename`);
- **assert what should happen**, so the test fails while the bug is there and passes once it's fixed;
- keep the tests behind "Checked and fine" too, asserting what you saw work;
- make each test start from a clean launch and not depend on another test having run first.

### Launch arguments
Debug builds only. From the spec (CLAUDE.md ▸ Testing Launch Arguments):
- `-isolatedData`: throwaway storage, fresh on every launch, onboarding first. The existing UI tests' `launchFresh` helper (e.g. in `TasquelUITests/GoalUITests.swift`) taps through onboarding.
- `-isolatedDataID <name>`: the same throwaway storage across launches. **Use it for relaunch checks.** Open cards aren't remembered across launches (by design), so open the card again after a relaunch.
- `-demoData`: throwaway storage, no onboarding, the current week filled with sample tasks (Errands has a list, Groceries). `-demoAppearance <system|light|dark|retro>`, `-demoFirstCard <name>` (that card first), `-demoToday yyyy-MM-dd` (that day is today, by the store's clock).
- `-fakeCalendar`: sample calendar events instead of the real calendar.
- `-smartAddRules`: Smart Add without the Apple Intelligence model (the rules it applies after the model, with a 2 s pause; `-smartAddDelay <seconds>` changes the pause). Needed in a simulator, which has no model.

Useful in the UI tests: `app.addTaskField` (`TasquelUITests/AddTaskField.swift`) taps a card's + and returns the Add task field. Closed cards are buttons labeled "Open <Card>, …". A task's type/mode button is "Task options: <Type>, <Mode>". A list's chevron has the identifier "Fold <list title>". Checkboxes are "Complete <title>" / "Mark <title> incomplete". The existing files in `TasquelUITests/` show many more patterns; read one or two before writing your own.

Also available in any app (pass through `app.launchArguments`):
- **Text size:** `-UIPreferredContentSizeCategoryName`, `UICTContentSizeCategoryAccessibilityXXXL` (also `…AccessibilityL`, `…XL`, `…XXL`, `UICTContentSizeCategoryXXXL`).
- **Another language:** `-AppleLanguages`, `(de)`, `-AppleLocale`, `de_DE`. Try `(ar)` for right-to-left.

`/Users/johnfentner/.claude/skills/applereview/references/simulator-tips.md` has everything else: dark mode, screenshots, recordings, rotation, relaunch, the accessibility audit, and the simulator traps that look like app bugs but aren't. **Read it before your first run.**

### Already known (don't report these)
- The project still says version 1.0.2 (10); it becomes 1.0.3 (11) after this review. Don't report the version number.
- Flaky UI tests: `GoalUITests.testReorderTasksByHandle` (drag timing) and `testEditGoalFieldsFocusOnFirstTap` (a Return/animation race).
- Open cards aren't remembered across launches, by design.
- Deleting a task or sub-task doesn't ask for confirmation, by design: it shows an Undo message for 5 seconds.
- No swipe actions or long-press menus on tasks, by design (the spec explains why).

### Before reporting anything
- **Reproduce it at least twice.**
- **Separate app bugs from problems in your own test code.** Timing, typing too fast, a wrong label and off-screen elements are test problems. If something is merely off-screen, scroll first.
- **Look at your screenshots.** Many problems are visual and pass every assertion.
- **A hang is serious.** If a query fails with "main thread busy" or "Timed out while evaluating UI query", the app hung. Record exactly what led to it.

## Your report
Write it to `/private/tmp/claude-501/-Volumes-T7-Design-JB-Portfolio-SYMONYM-Tasquel/c2c1eb9b-b059-49df-87cc-82751dbd8d02/scratchpad/applereview-2026-11-10/Code/report.md`, then return the same text as your final message.

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
   - evidence: screenshot paths in `/private/tmp/claude-501/-Volumes-T7-Design-JB-Portfolio-SYMONYM-Tasquel/c2c1eb9b-b059-49df-87cc-82751dbd8d02/scratchpad/applereview-2026-11-10/Code/shots`, the test name and its output
   - likely cause, as file:line in your copy
   - a suggested fix
2. **Checked and fine:** one line each, so we know what's covered.
3. **Your test files:** their paths, which test reproduces which finding, and which tests cover the "Checked and fine" areas.
4. **Couldn't check in a simulator:** things in your area that only a real device shows, such as haptics, Apple Intelligence, the camera, how a gesture or animation feels under a finger, real-world speed, notifications arriving. One line each, written as something to try ("drag a task to the bottom of a long card: does the scrolling feel too fast?"). These become the user's phone checklist.

Keep the report under about 1,200 words and put the detail in the evidence files. Quality over quantity: three real, well-evidenced findings beat fifteen guesses.
