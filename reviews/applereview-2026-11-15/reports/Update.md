## Tasquel 1.1 review: Update from the live version (1.0.3 (11) to 1.1)

I found no data loss, nothing duplicated, nothing moved and nothing reset. There is one Minor finding and one Polish nit, both caused by the update itself. The app has no iCloud or account sync, so this covers local data only.

How I tested:
- **Data level.** I compiled each copy's `Models.swift` and `ChecklistStore.swift` for macOS. 1.0.3's code saved a long-time user's data, making the same store calls the UI makes. 1.1's code loaded it on the same day, launched four times, made one edit, and rolled it forward to Nov 16, Nov 23 and Dec 1. 1.0.3's code rolled the same data forward over the same dates. I did this once with Monday as the week's start and once with Sunday.
- **Simulator** (iPhone 17 Pro, iOS 26.3, Dark, Monday start). I used 1.0.3 through its UI with no throwaway flags, copied the data, installed 1.1 over it without deleting the app, ran checks, copied the data again and compared.
- The new build was made as **1.1 (12)** with a `MARKETING_VERSION=1.1 CURRENT_PROJECT_VERSION=12` override on the command line. With the project's 1.0.3 number, the What's New logic can't run.

### 1. Findings

**1. Updaters never see the Thanksgiving turkey until they've opened What's New twice from the header.** Minor.
- **Device:** iPhone 17 Pro sim, Dark, Monday start, updated from 1.0.3. `-demoTurkey` stands in for Thanksgiving week.
- **Steps:**
  1. Use 1.0.3, then install 1.1 over it.
  2. Launch with `-demoTurkey`: the "What's New?" pill slides out, but no turkey appears in 10 s.
  3. Open What's New from the pill twice.
  4. Relaunch with `-demoTurkey`: the turkey runs, says AAH! and goes back.
- **Reproduced twice:** on the real first launch after the update, and again with `-demoWhatsNew -demoTurkey`.
- **Expected:** the spec says "The turkey waits while it's out", which reads as a short delay. The turkey is meant to come once per app open in Thanksgiving week.
- **Actual:** the pill stays until it's opened twice from the header, with no limit on launches or days. Until then, the turkey never appears. 1.1 is likely to ship just before or during Thanksgiving week (Nov 23–29), so most updaters will miss the turkey for the whole week. The feathered mark itself still shows.
- **Evidence (header frames 3–9 s after launch), in `evidence/Update/`:**
  - `turkey-updater-pill-pending-sheet.png`: pill out, no turkey.
  - `turkey-demoWhatsNew-repro-sheet.png`: the second reproduction.
  - `turkey-updater-pill-done-sheet.png`: the control, turkey runs once the pill is gone.
  - XCUITest can't see the turkey (its view is hidden from accessibility, and it's an animation), so `tests/Update/scripts/turkey_check.sh <name>` (optionally with `EXTRA_ARGS=-demoWhatsNew`) records the screen and makes the frames.
- **Likely cause:** `Tasquel/ContentView.swift:815` (`&& !store.showsWhatsNewButton`), together with `ChecklistStore.swift:188–189` (the pill shows until `whatsNewButtonOpens` reaches 2, and never expires on its own).
- **Suggested fix (one simple rule):** in Thanksgiving week, run the turkey first and slide the pill out after it's back behind the mark. Alternatively, let the pill retire after a few launches. Then the turkey can't be blocked for the week.

**2. What's New's footer points to "Settings ▸ What's New", but the row is "What's New in 1.1" under Settings ▸ Help.** Polish.
- **Where:** `WhatsNew.swift:136–137`, seen in `evidence/Update/after-whatsnew-sheet1.png`. The spec and the brief both say Settings ▸ Help.
- **Fix:** say "Settings ▸ Help ▸ What's New".

### 2. Checked and fine
- 1.0.3 data loaded by 1.1: 0 old values changed or lost at the data level (Monday and Sunday start) and in the simulator (`data-before` vs `data-after`, three 1.1 launches). The only new things are the three UserDefaults keys.
- Rollover of 1, 2 and 3 weeks: 1.1 gives the same weeks as 1.0.3 for every old field, with both week starts.
- Kept with their meaning in the simulator:
  - checked and unchecked sub-tasks, a checked task, a carry-over and a repeating task
  - a 3/7 goal and a folded list ("1 of 3 items checked")
  - a renamed task, a deleted task and a deleted card (Study), which stay gone
  - the reordered card (Appointments before Work), held through 3 launches
  - Dark appearance, and no onboarding for the updater
- Next week from 1.0.3: the renamed copy "Report v2" is kept, and the deleted repeating copy (Standup) stays deleted.
- Old tasks have no day, date or pin; nothing shows "late" or "Today".
- The two old "Call mom" tasks show "⧉ Duplicate" (expected); nothing else does.
- 1.0.3's This week only card (Trip) shows "Just this week" (switch value On). Turning it off restores Carry Over and Repeating, survives a relaunch, and the card comes back in next week.
- What's New pill:
  - shows for the updater and stays through relaunches until it's opened twice
  - then it's gone, also after a relaunch, and Settings still has What's New
  - never shows on a fresh 1.1 install (two launches)
- `lastLaunchedVersion` is "1.1" after the first launch. `didMigrateStarters_v1` is kept.
- No notification prompt at launch, and no reminders until a date is set. At the data level `expiryReminders` is empty for old data and has exactly one after a date three weeks out.
- New features on old items:
  - Friday on old Standup shows "Fri", not late, and stays put
  - a task pin and a card pin show first
  - a date on an old carry-over goal stays carry-over until then, and next week's copy takes the day and date
  - all survive two relaunches
- The first save in 1.1 rewrites the file with the new fields. A diff after editing shows only the intended changes (Trip off, Standup's day, the pins).

### 3. Test files (in `tests/Update/`)
- `old-project-UITests/ReviewUpdateSeedUITests.swift`, `testSeedLiveVersionData`: the 1.0.3 user, through the UI. `TEST_RUNNER_SEED_SUNDAY=1` gives Sunday start and Retro, but that variant hasn't been run in the simulator; Sunday was checked at data level only.
- `new-project-UITests/ReviewUpdateCheckUITests.swift`, all covering "Checked and fine":
  - `testUpdateKeepsLiveVersionData`
  - `testWhatsNewPillTwiceThenGone`
  - `testNewFeaturesWorkOnOldItems`
  - `testFreshInstallHasNoWhatsNewPill`

  All passed. They need the seeded data (they skip without it) and must be built with the 1.1 version override until the project is bumped.
- `scripts/update_check.sh [monday|sunday] [data|sim|all]` repeats everything from scratch: builds, data-level check, seed, `data-before`, install over, turkey check, checks, `data-after` and `data-after-edit`, fresh install. Its data part was run (all passed). The simulator steps were each run by hand, but the script's `sim` mode itself hasn't been run end to end. (It refers to the work root's paths; adjust them to re-run.)
- Supporting files: `scripts/compare_data.py`, `scripts/datacheck/driver.swift` (with `stubs_new.swift`), and `scripts/turkey_check.sh` (Finding 1).
- Data snapshots: `data-before`, `data-after` and `data-after-edit`.

Not covered in the simulator UI (data level only):
- **Sunday start and Retro.**
- **A date set from the date picker.**

### 4. Couldn't check in a simulator
- Update through TestFlight on your phone over your real months of data: is every week, card and task the same as before?
- Right after updating, does the pill slide out smoothly on iOS 27.2, and does the title move over cleanly?
- In Thanksgiving week on the phone, does the turkey run once you've opened What's New twice?
- Add a date to an old task: does the permission prompt come then, and does the 9 AM reminder arrive the day before?
- After restoring a 1.0.3 iCloud backup to another phone and installing 1.1, does the pill show once?
