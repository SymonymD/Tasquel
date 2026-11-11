# Tasquel 1.0.3 review: your brief (read all of it first)

You're one of seven reviewers testing **Tasquel 1.0.3** in the iOS Simulator the way an Apple App Reviewer and a picky first-time user would. The developer wants to find usability problems and rejection risks *before* App Review and real users do.

**Your role: Update from the live version.** 

Real users don't start fresh: they update, with months of data saved. App Review only does fresh installs, so a broken update reaches users. Your job is to update from the live version to the new one and check that nothing is lost or changed.

Your copies:
- **Live version** (`release-1.0.2`), in `/private/tmp/claude-501/-Volumes-T7-Design-JB-Portfolio-SYMONYM-Tasquel/c2c1eb9b-b059-49df-87cc-82751dbd8d02/scratchpad/applereview-2026-11-10/Update/old-project`, built with `-derivedDataPath /private/tmp/claude-501/-Volumes-T7-Design-JB-Portfolio-SYMONYM-Tasquel/c2c1eb9b-b059-49df-87cc-82751dbd8d02/scratchpad/applereview-2026-11-10/Update/old-derived`.
- **New version**, in `/private/tmp/claude-501/-Volumes-T7-Design-JB-Portfolio-SYMONYM-Tasquel/c2c1eb9b-b059-49df-87cc-82751dbd8d02/scratchpad/applereview-2026-11-10/Update/project`.

Both have the same bundle ID. Installing the new build over the old one keeps the app's data, just like an App Store update. `xcodebuild test` installs over the existing app too; it doesn't erase data.

1. **Use the live version like a long-time user,** through a UI test in the old copy's UI test folder. Create every kind of item, with every option, mode and setting the app has, including anything that changed in this release (see "what changed"). Leave some things half-done: completed items, edited items, deleted items with Undo gone.
   - Launch **without** the throwaway-data or demo-data flags, so the data is saved where a real user's is. Your simulator is new, so nothing real is at risk.
   - Demo-data flags often don't save to disk, so create the data through the UI.
2. **Record the "before":** take a screenshot of every screen. Copy the saved data with `cp -R "$(xcrun simctl get_app_container <UDID> <bundle id> data)" /private/tmp/claude-501/-Volumes-T7-Design-JB-Portfolio-SYMONYM-Tasquel/c2c1eb9b-b059-49df-87cc-82751dbd8d02/scratchpad/applereview-2026-11-10/Update/shots/data-before`.
3. **Update:** build the new copy and install it over the old one (`xcrun simctl install <UDID> <path to new .app>`, or run a new-copy UI test). Don't delete the app first.
4. **Check the "after":**
   - Every item, option and setting is still there and still means the same thing.
   - Nothing is duplicated, moved to another day, reset to a default or lost.
   - Copy the data again (`data-after`) and compare the two. New fields are fine; changed or missing old values are findings.
   - Relaunch twice, then edit something and relaunch again: the first save in the new version rewrites the old file.
5. **Check new features on old data:** the new or changed features should work on items made by the live version, not only on new ones.

If the app also syncs (iCloud, CloudKit, an account), this covers local data only; say so in your report.

Leave a script, `/private/tmp/claude-501/-Volumes-T7-Design-JB-Portfolio-SYMONYM-Tasquel/c2c1eb9b-b059-49df-87cc-82751dbd8d02/scratchpad/applereview-2026-11-10/Update/shots/update_check.sh`, that repeats steps 1–4 from scratch: build the live version, seed the data, update, run the checks. It's re-run after the fixes, because a fix can change how data is saved.

In this app: the live version is 1.0.2 (10), on branch `release-1.0.2` (its last commit only changed a document). Saved data is `Documents/checklist.json` (all weeks and tasks) and `Documents/settings.json` in the app's data container, plus UserDefaults (the container's `Library/Preferences`). A fresh simulator shows onboarding on the first launch without `-isolatedData`; go through it (the old copy's `TasquelUITests/GoalUITests.swift` has a `launchFresh` that taps through it). This release adds two saved task fields: `modeBeforeThisWeekOnly` (This week only remembers each task's mode) and `isListFolded` (folded lists). Old data has neither, so check that: lists from 1.0.2 load open and can be folded; a card that had This week only turned on in 1.0.2 (whose tasks 1.0.2 made one-time for good) behaves sensibly when it's turned off in 1.0.3 (there is no remembered mode to put back, so the tasks should stay one-time, with nothing lost or crashing); and repeating and carry-over tasks from 1.0.2 still copy into next week correctly.

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

The spec is in `/private/tmp/claude-501/-Volumes-T7-Design-JB-Portfolio-SYMONYM-Tasquel/c2c1eb9b-b059-49df-87cc-82751dbd8d02/scratchpad/applereview-2026-11-10/Update/project/CLAUDE.md` (the full spec: read "Key behaviors" and "UI Patterns" plus everything about your area; it's long and dense) and `/private/tmp/claude-501/-Volumes-T7-Design-JB-Portfolio-SYMONYM-Tasquel/c2c1eb9b-b059-49df-87cc-82751dbd8d02/scratchpad/applereview-2026-11-10/Update/project/Tasquel/HelpSheet.swift` (the in-app Help, which is what users are told). **Read it first:**
- **A bug** is anything that contradicts the spec.
- **A usability issue** is anything the spec describes that is confusing or awkward in practice.

## Rules
- Work **only** in your own project copy, derived-data folder, shots folder and simulator(s):
  - copy: `/private/tmp/claude-501/-Volumes-T7-Design-JB-Portfolio-SYMONYM-Tasquel/c2c1eb9b-b059-49df-87cc-82751dbd8d02/scratchpad/applereview-2026-11-10/Update/project`
  - derived data: `/private/tmp/claude-501/-Volumes-T7-Design-JB-Portfolio-SYMONYM-Tasquel/c2c1eb9b-b059-49df-87cc-82751dbd8d02/scratchpad/applereview-2026-11-10/Update/derived`
  - shots: `/private/tmp/claude-501/-Volumes-T7-Design-JB-Portfolio-SYMONYM-Tasquel/c2c1eb9b-b059-49df-87cc-82751dbd8d02/scratchpad/applereview-2026-11-10/Update/shots`
  - simulator(s): `CCB7CB84-384B-40B2-BDA2-BDD00700B3C5` (iPhone 17 Pro)
- Never build, edit or test anything in `/Volumes/T7/Design/JB Portfolio/SYMONYM/Tasquel/Tasquel`; that's the real project. Never touch another reviewer's simulator.
- **Never tap these.** They reach the real world and can't be taken back:
  - **Settings ▸ Feature Ideas ▸ Send Anonymously** (in Retro: "> Send"). It posts to the live survey server. Ticking boxes and typing a comment are fine; never send.
  - On the live website pages that Settings ▸ Support and Privacy open in Safari: reading is fine, but never submit anything there.
  Opening their screens to check layout is fine.
- **Don't fix the app.** Find, reproduce and explain. You may read any source in your copy to name the likely cause.
- **Simulator limits:** Apple Intelligence isn't in the simulator: test Smart Add with `-smartAddRules`. Haptics can't be felt. Calendar access: prefer `-fakeCalendar`; granting access in your own simulator is harmless (it has no real events, and the app only reads them). Use only the simulator(s) given to you: they run iOS 26.3. The iOS 26.0 runtime on this Mac is a beta that crashes the app at launch, which isn't an app bug.
- **Time:** aim to finish in about an hour. If you're running long, stop testing and write the report with what you have.

## Driving the app
Add your own XCUITest file(s) to `TasquelUITests` in your copy. Name them `ReviewUpdate*.swift` so they're easy to collect. Build and run:

```
cd /private/tmp/claude-501/-Volumes-T7-Design-JB-Portfolio-SYMONYM-Tasquel/c2c1eb9b-b059-49df-87cc-82751dbd8d02/scratchpad/applereview-2026-11-10/Update/project
xcodebuild -project Tasquel.xcodeproj -scheme Tasquel -destination 'id=<your simulator UDID>' \
  -derivedDataPath /private/tmp/claude-501/-Volumes-T7-Design-JB-Portfolio-SYMONYM-Tasquel/c2c1eb9b-b059-49df-87cc-82751dbd8d02/scratchpad/applereview-2026-11-10/Update/derived -parallel-testing-enabled NO \
  -test-timeouts-enabled YES -maximum-test-execution-time-allowance 240 \
  -only-testing:TasquelUITests/<YourClass>/<testName> test > /private/tmp/claude-501/-Volumes-T7-Design-JB-Portfolio-SYMONYM-Tasquel/c2c1eb9b-b059-49df-87cc-82751dbd8d02/scratchpad/applereview-2026-11-10/Update/shots/run.log 2>&1
grep -E "error:|Test Case|REVIEW" /private/tmp/claude-501/-Volumes-T7-Design-JB-Portfolio-SYMONYM-Tasquel/c2c1eb9b-b059-49df-87cc-82751dbd8d02/scratchpad/applereview-2026-11-10/Update/shots/run.log
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
Write it to `/private/tmp/claude-501/-Volumes-T7-Design-JB-Portfolio-SYMONYM-Tasquel/c2c1eb9b-b059-49df-87cc-82751dbd8d02/scratchpad/applereview-2026-11-10/Update/report.md`, then return the same text as your final message.

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
   - evidence: screenshot paths in `/private/tmp/claude-501/-Volumes-T7-Design-JB-Portfolio-SYMONYM-Tasquel/c2c1eb9b-b059-49df-87cc-82751dbd8d02/scratchpad/applereview-2026-11-10/Update/shots`, the test name and its output
   - likely cause, as file:line in your copy
   - a suggested fix
2. **Checked and fine:** one line each, so we know what's covered.
3. **Your test files:** their paths, which test reproduces which finding, and which tests cover the "Checked and fine" areas.
4. **Couldn't check in a simulator:** things in your area that only a real device shows, such as haptics, Apple Intelligence, the camera, how a gesture or animation feels under a finger, real-world speed, notifications arriving. One line each, written as something to try ("drag a task to the bottom of a long card: does the scrolling feel too fast?"). These become the user's phone checklist.

Keep the report under about 1,200 words and put the detail in the evidence files. Quality over quantity: three real, well-evidenced findings beat fifteen guesses.
