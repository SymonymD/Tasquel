# Tasquel 1.0.3 review plan: 2026-11-10

The first run of `/applereview`. The briefs as sent are in `briefs/`, and the diff the reviewers read is `changes-since-1.0.2.diff`.

## What was reviewed
- Branch `release-1.0.3` at b48a845, plus folding lists, which wasn't committed yet. The project still said 1.0.2 (10).
- Live version: 1.0.2 (10), branch `release-1.0.2`. Its last commit, cc594b0, changed only a document.
- Changes since 1.0.2:
  - folding lists (new);
  - direct task reordering with auto-scroll;
  - This week only remembers modes;
  - Smart Add sessions, and lists no longer get their own title as an item;
  - wrapping rename fields.
- New saved task fields: `modeBeforeThisWeekOnly` and `isListFolded`.

## Preflight facts
- Project: `Tasquel.xcodeproj`, scheme `Tasquel`, targets Tasquel, TasquelTests (Swift Testing), TasquelUITests (XCTest).
- Bundle ID: `com.symonym.Tasquel`. iOS 26.0 and later. iPhone and iPad (`TARGETED_DEVICE_FAMILY` 1,2).
- Spec: `CLAUDE.md` and `Tasquel/HelpSheet.swift`. `AGENTS.md` has nothing in it for the app.
- Test hooks: `-isolatedData`, `-isolatedDataID <name>`, `-demoData` (with `-demoAppearance`, `-demoFirstCard`, `-demoToday`), `-fakeCalendar`, `-smartAddRules`, `-smartAddDelay <s>`.
- UI test helpers: `app.addTaskField` (`TasquelUITests/AddTaskField.swift`) and `launchFresh` in `GoalUITests.swift`.
- Never tap:
  - Settings ▸ Feature Ideas ▸ Send Anonymously (Retro: "> Send"). It posts to `https://jbfentner.com/tasquel/survey`, and `isLive` is true.
  - Support and Privacy open jbfentner.com pages, which are read-only.
  - There's no StoreKit, no mail and no sharing. EventKit only reads.
- Simulators: iOS 26.3 (23D8133). The 26.0 runtime is a beta that crashes the app.
- Mac: 32 GB and 10 cores, so all seven reviewers ran in one wave.
- Tests before the review, on the same code:
  - unit tests: 181 passed;
  - UI tests: 73 passed (ScreenshotTests skipped), at about 06:40 on 2026-11-10.
- Baseline: none. There were no earlier `reviews/applereview-*` folders, and the Oct 27 reviewers' tests were lost.

## Team and devices
| Role | Device |
|---|---|
| Everyday flows | iPhone 17 Pro |
| Settings and themes | iPhone 17 Pro Max |
| iPad | iPad Pro 13-inch (M5) and iPad Pro 11-inch (M5) |
| Accessibility | iPhone 17 |
| Edge cases and small screens | iPhone SE (3rd generation) |
| Code review | none (an iPhone 17 Pro simulator only for unit tests) |
| Update from the live version | iPhone 17 Pro, from `release-1.0.2` |

## Project-specific notes for next time
- The copies have no `.git`, so give reviewers the diff as a file.
- Point the Code reviewer at `TestClock` in TasquelTests.swift, and say that `makeIsolatedStore` is private there.
- Open cards aren't remembered across launches, so relaunch tests must open the card again.
