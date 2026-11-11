# Tasquel 1.0.3 review: Settings and themes

(Saved from the reviewer's final message. The harness refused report files: "subagents should return findings as text".)

Device: iPhone 17 Pro Max simulator, iOS 26.3, portrait. The Mac ran at a load average of about 1,000 during the run, so everything was slow. Shots are in the reviewer's `Settings/shots/`, with small copies in `shots/small/`; the ones cited are copied to `evidence/Settings/`.

## Findings

### 1. Match App Icon to Theme fails silently, and the icon can stay out of step with the theme
**Severity: Major** (a broken feature with no feedback; confirm on a phone)
- **Settings:** Match App Icon to Theme on (the default), `-demoData`.
- **Steps:** Settings ▸ Retro, close Settings, go to the home screen. Then try Settings ▸ Light, and the switch off and on.
- **Expected:** Retro gives the retro icon, with iOS's alert. Light, or the switch turned off, puts the standard icon back.
- **Actual:** reproduced in 4 runs and 5 launches. The iOS alert never appeared.
  - After a fresh install, Retro never got the retro icon. That was three launches, the last on unprobed code (batch4).
  - A temporary probe in my copy logged `setAlternateIconName` failing with "Resource temporarily unavailable" on the first try and again on the 1 s retry (`shots/icon-probe.log`). It was the first icon change in that launch, not one "too soon after another" as the code comment assumes.
  - In the first run, one change to Retro did go through. After that the icon stayed retro through Light, the switch off, a relaunch, and the switch back on. Settings showed Light with the switch on while the home screen showed the retro icon.
- **Evidence:**
  - `shots/icon-home-screen.png` and `shots/icon-2-light-home.png` (batch2): the retro icon in Light.
  - `shots/icon-1-retro-home.png`: the standard icon in Retro.
  - The test fails at "Retro gives the retro icon" (`batch3.log`, `batch4.log`) and at "Light puts the standard icon back" (`batch2.log`).
- **Likely cause:** `Tasquel/AppIconSwitcher.swift:20-30`.
  - After one retry it gives up. Both errors are swallowed (`try?`).
  - Nothing brings the icon back in line with the setting later: the switcher runs only from Settings (`SettingsSheet.swift:283`, `:327-329`). One refused call leaves the icon wrong until the user picks a theme again.
- **Suggested fix:**
  - Retry with a backoff (1, 2, 4 s).
  - Run `update(for: store.appearanceMode, matchingTheme:)` once each time the app becomes active, from `TasquelApp` (one per app, so iPad windows still don't race). It does nothing when the icon already matches.
  - Consider making the change after the Settings sheet closes rather than while it's up.

### 2. Help still says to "hold" the reorder handle
**Severity: Polish**
- **Steps:** Settings ▸ How to Use Tasquel ▸ Rename, Reorder and Delete.
- **Expected:** wording that matches 1.0.3: the task lifts as soon as you touch the handle.
- **Actual:** it says "hold and drag the handle to reorder", which suggests a wait (that was 1.0.2's drag and drop). The same wording is used for cards, which really do need a 0.5 s hold.
- **Cause:** `Tasquel/HelpSheet.swift:31`.
- **Suggested fix:** "touch and drag the handle to move it".

### 3. Two Settings surfaces lose the Retro and Dark styling
**Severity: Polish**
- **Week Starts On:** in Retro it stays the system's grey segmented control. Next to it, the switches and the Sort menu take the phosphor accent (`shots/icon-retro-settings.png`).
  - Cause: `SettingsSheet.swift:403-412`.
  - Fix: tint it, or use retro `[SUN] [MON]` buttons.
- **Show Welcome Tour:** it's plain system dark, black with blue buttons and dots, even in Dark (navy everywhere else) and Retro (`shots/tour-dark-*.png`). Help, by contrast, is themed.
  - Cause: `OnboardingSheet.swift`, which has no `Theme` use.
  - Fix: optionally pass the theme's background and accent into the tour.

## Checked and fine
- **Themes, switched from Settings with Errands open and Groceries folded** (Light, Dark, System, Retro Green, Red and White; Amber in the Help test):
  - the open card restyles at once;
  - the chevron and "2 of 5" stay, and the items stay hidden;
  - the rename field wraps to 4 lines and the keyboard's Done saves it;
  - edit mode keeps the chevron with the handles;
  - in Light and Dark, the lifted task moves above the folded list and the fold survives;
  - no placeholder or developer text.
- **Contrast audit:**
  - It reports "failed" on Retro texts in every colour, even White on black. That's the scanline overlay confusing the audit; the screenshots are clearly readable.
  - Light and Dark only get "nearly passed", on system secondary text.
- **System theme, device switched to Dark and back while Settings was open:** Settings and the main screen follow both ways, and the fold stays.
- **Week ▸ Sunday, relaunch, then Monday:**
  - the title moves by a day;
  - the folded repeating list shows "1 of 2" in this week and next week every time;
  - the This week only card stays this week only and is absent next week.
- **Sort Cards (Recently Edited First):** folding a list isn't counted as an edit; the order is unchanged.
- **Help:** the List entry describes folding, in both the standard and Retro layouts.
- **Welcome Tour:** 8 pages (no Smart Add page in the simulator), Close and Done, back to Settings.
- **Feature Ideas:** ticks and a comment work. Send Anonymously is shown and enabled; I never tapped it.
- **Version and Build:** 1.0.2 (10), matching the project.
- **Support and Privacy Policy:** both open the right Tasquel pages in Safari, which load fully. I didn't submit anything.
- **Import, export or reset:** Settings has none.

## Test files
In `tests/Settings/` (from `TasquelUITests/` in the reviewer's copy), plus `tests/Settings/scripts/`:
- **`ReviewSettingsSupport.swift`:** shared helpers.
- **`ReviewSettingsRowsTests.swift`:**
  - `testMatchAppIconToTheme` reproduces **Finding 1**. It checks the home-screen icon colour after each step and fails while the bug is there.
  - These pass: `testHelpListEntryDescribesFolding`, `testWelcomeTourFromSettings`, `testFeatureIdeasTickAndComment` (it never sends), `testVersionMatchesProject` (update it to 1.0.3 / 11 after the bump), and `testSupportAndPrivacyLinksOpenSafari`.
- **`ReviewSettingsThemeTests.swift`:** the theme tour.
  - `testThemeLight`, `testThemeDark`, `testThemeRetroRed` and `testThemeRetroWhite` passed.
  - `testThemeRetroGreen` only failed at the drag, which was my test's geometry (since fixed).
  - Not run for lack of time: `testThemeSystemLight`, `testThemeRetroAmber`, `testThemeRetroBlue` and `testThemeRetroPurple`.
- **`ReviewSettingsWeekTests.swift`:** `testWeekStartKeepsFoldedListsAndThisWeekOnly` and `testFoldingIsNotAnEditForSortCards`, both passing.
- **`ReviewSettingsSystemDarkTests.swift`:** `testSystemDarkModeSwitchWhileOpen`, passing. It needs `scripts/appearance_helper.sh` running beside it, which flips the simulator's appearance with `simctl`.
- **Runner:** `scripts/runtwb.sh <log> <Class/test>…` runs tests without building, after a `build-for-testing`.

I removed the temporary probe from `AppIconSwitcher.swift`, so the source matches the original. The simulator's appearance is back to Light.

## Couldn't check in a simulator
- On a phone, switch Retro ⇄ Light five times, quickly and slowly: does the icon change every time, with iOS's alert?
- Pick Retro and close Settings at once: does the icon still change?
- Lift a task in Dark and in Retro: is the lifted card distinct enough (dark shadow on navy; outline only in Retro)? Do the medium haptic on the lift and the ticks as it passes tasks feel right?
- Leave automatic Light/Dark on, with Tasquel open in System, and wait for sunset: does it switch without a flash?
- Retro on an OLED screen: do the scanlines or the White and Red colours make small text hard to read?
- Open Support on cellular: does the page load fully, and are its links live (read only)?
