# Tasquel 1.1 review plan: 2026-11-15

The second run of `/applereview`. The briefs as sent are in `briefs/`, and the diff the reviewers read is `changes-since-1.0.3.diff`.

## What was reviewed
- Branch `release-1.1` at 1be5fdc. The project still says 1.0.3 (11); next is 1.1 (12).
- Live version: 1.0.3 (11), branch `release-1.0.3` at 840f3c8, the merge-base of `release-1.1`.
- Changes since 1.0.3: 40 app files, +6,078 / −624 lines. Days for tasks and the day filter, a day gone by → next week, dates and expiration with reminders, far-off dates (a one-time task moves to its date's week), Smart Add words and dates, pins, duplicates, clear-to-delete, Escape, the card ring, the edit-mode icons, Add Category rework and the Just this week chip, the bar's house, the What's New pill and sheet, holiday marks and the turkey, Seasonal, Retro DOS fields, Help in tabs, iPad landscape half-width lanes, goal editor fixes, order holds, performance.
- New saved fields: task `hasOwnTitle`, `isPinned`, `expiresOn`, `expirySetOn`, `expiresWithWeek`, `dayOfWeek`, `daySetOn`; category `isPinned`; settings `remindsBeforeExpiry`, appearance `seasonal`; UserDefaults `lastLaunchedVersion`, `whatsNewButtonOpens`.

## Preflight facts
- Project: `Tasquel.xcodeproj`, scheme `Tasquel`, targets Tasquel, TasquelTests (Swift Testing), TasquelUITests (XCTest).
- Bundle ID `com.symonym.Tasquel`. iOS 26.0 and later. iPhone and iPad (`TARGETED_DEVICE_FAMILY` 1,2).
- Spec: `CLAUDE.md`, `Tasquel/HelpSheet.swift`, `Tasquel/WhatsNew.swift`. `AGENTS.md` has nothing for the app.
- Test hooks: `-isolatedData`, `-isolatedDataID <name>`, `-demoData` (with `-demoAppearance`, `-demoFirstCard`, `-demoToday`, the last only with `-demoData`), `-fakeCalendar`, `-smartAddRules`, `-smartAddDelay`, `-demoWhatsNew`, `-demoTurkey`, `-demoHoliday`, `-demoSeason`.
- Throwaway data turns off on purpose: the Today pulse, the opening wiggle, the turkey (unless `-demoTurkey`), reminder scheduling and the notification prompt.
- Never tap: Settings ▸ Feature Ideas ▸ Send Anonymously (Retro "> Send"), which posts to `https://jbfentner.com/tasquel/survey`. Support and Privacy open read-only pages. No StoreKit, mail or sharing; EventKit only reads.
- Runtimes: iOS 18.3, 18.6, 26.0 (final, 23A343), 26.3 (23D8133, used). The user's phone runs iOS 27.2.
- Mac: 10 cores, so about three simulators at once, in waves.
- Tests before the review, on 1be5fdc: 279 unit tests passed; 97 UI tests, 2 skipped (iPad-only rotation, ScreenshotTests), 0 failures.
- Review day: Sunday 2026-11-15, the last day of a Monday-start week, so most weekdays had gone by.
- Baseline: the 2026-11-10 review's tests (Access, Edge, Everyday, Regression, Settings, IPad UI tests; Code unit tests), re-run in a Baseline copy.

## Team, devices and waves
| Role | Device | Wave |
|---|---|---|
| Everyday flows | iPhone 17 Pro | 1 |
| Update from 1.0.3 | iPhone 17 Pro | 1 |
| Edge cases and small screens | iPhone SE (3rd generation) | 1 |
| Code review | iPhone 17 Pro, unit tests only | 1 |
| iPad | iPad Pro 13-inch (M5), iPad Pro 11-inch (M5) | 2 |
| Accessibility | iPhone 17 | 2 |
| Settings and themes | iPhone 17 Pro Max | 3 |
| Baseline (run by the lead) | iPhone 17 Pro | 3 |

## Known before the review (in every brief)
- iPad: typing a task's words then tapping its type/mode button adds them as a checkbox at once (`testAddFieldSaysPickedType` fails on iPad).
- iPhone SE at the largest text: week arrows 40pt, day strip 347.75pt.
- Open from the 1.0.3 review: Match App Icon to Theme can fail silently; the Welcome Tour isn't themed; Just this week on and straight off moves next week's own tasks.
- Design rules the switcher study found surprising, listed as by design.

## Project-specific notes for next time
- The copies have no `.git`, so give reviewers the diff as a file.
- `-demoToday` works only with `-demoData`.
- Point the Code reviewer at `TestClock` in TasquelTests.swift; `makeIsolatedStore` is private there.
- Open cards aren't remembered across launches, so relaunch tests must open the card again.
- `make_briefs.py` (in the work root) filled the briefs from the skill's template and roles; reuse it with a new WHAT_CHANGED.
