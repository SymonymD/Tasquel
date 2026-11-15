## Settings and themes review: Tasquel 1.1 (iPhone 17 Pro Max sim 8954FBD1, iOS 26.3)

All paths below are under the work root's `Settings/` (SHOTS = `shots/`, TESTS = `project/TasquelUITests/`). The cited screenshots are copied, shrunk, to `evidence/Settings/`; the tests to `tests/Settings/`.

### 1. Findings, most severe first

**F1. Changing Settings ▸ Week deletes a dated task for good. Rejection risk (data loss).**
- **Device and settings:** iPhone 17 Pro Max, fresh data (`-isolatedDataID`, `-smartAddRules`). Today is Sunday, Nov 15.
- **Steps:**
  1. In Fitness, Smart Add "Dentist 11/20", then Set Date. The one-time task moves into the week of Nov 16 and shows "Fri · Nov 20".
  2. Settings ▸ Week Starts On ▸ Sunday.
  3. Go to the week of Nov 15 (Sunday start), which holds Nov 20. Then check Nov 22 and Nov 29.
  4. Switch back to Monday and look at the week of Nov 16.
- **Expected:** Dentist is in the week that holds Nov 20, whichever day the week starts on.
- **Actual:** Dentist isn't in any of those weeks. Switching back to Monday doesn't bring it back. It is deleted.
- **Evidence:**
  - Screenshots: `SHOTS/weekstart-1-moved-monday.png`, `SHOTS/weekstart-2-sunday-week-of-date.png`, `SHOTS/weekstart-4-back-to-monday.png`, all four side by side in `weekstart.png`.
  - Test `testWeekStartSwitchKeepsDatedTaskInItsWeek` failed at both asserts, twice (`SHOTS/runA.log`, `SHOTS/runC.log`).
- **Likely cause:**
  - `ChecklistStore.swift:568-591` moves every saved week by +6 days on a Sunday (−1 on other days) but leaves `expiresOn` where it was. The task ends up in a week that starts after its own date.
  - `expiryCutoff` (`:1043-1049`) then treats it as expired, and `removeExpiredTasks` (`:1054-1064`, called from `navigateToDate` `:887` and at launch) deletes it.
  - The spec lists "week-start switches with dated tasks" as left for 1.2. But 1.1's "a one-time task moves into its date's week" makes this a permanent loss on every switch.
- **Suggested fix:** after the shift, put each dated task back into the week that holds its `expiresOn` (the same logic as `moveToItsDatesWeek`). At minimum, don't run the expiry removal for tasks the switch just moved.

**F2. Seasonal: Settings becomes unreadable when the phone switches to Dark. Major.**
- **Device and settings:** `-demoData -demoSeason fall`, appearance System, phone in Light.
- **Steps:**
  1. Open Settings and pick Seasonal.
  2. With Settings still open, switch the phone to Dark.
- **Expected:** all of Settings goes to the season's dark palette.
- **Actual:**
  - The sheet's background and text turn dark, but the section rows stay cream. White words on cream can't be read: System, Light, Dark, Retro, Match App Icon, Week Starts On, Expiration Reminders, Saved Categories.
  - Closing and reopening Settings fixes it.
  - If Seasonal was already chosen before Settings opened, the switch works (`testSeasonalSettingsRowsFollowDarkSwitch` passes).
- **Evidence:**
  - Screenshots: `seasonalpicked-1-switched-dark.png`, `SHOTS/darkswitch-Seasonal-1-settings-dark.png`, `SHOTS/seasonalpicked-2-reopened.png`, side by side in `seasonalpicked.png`.
  - Reproduced three times, by `testSeasonalPickedInOpenSettingsFollowsDarkSwitch` and `testSystemDarkModeSwitchWhileSettingsIsOpen`. Row brightness stays 0.97 after the switch (`runA.log`, `runC.log`).
- **Likely cause:**
  - `SettingsSheet.swift:91` and its `.listRowBackground(darkCardBg)` calls (`:105-183`) give the rows the season's dynamic card color. That color keeps its light value while `.preferredColorScheme(store.colorScheme ?? systemColorScheme)` (`:86`, fed from `ContentView.swift:292` and `:931`) turns the sheet dark.
- **Suggested fix:** choose the row color from the sheet's own `@Environment(\.colorScheme)` (the Tone's light or dark hex), or put `.id(effectiveScheme)` on the List so the rows rebuild. Check Help (`darkHelpBg`) for the same pattern.

**F3. Reminders footer doesn't update after "Don't Allow". Minor.**
- **Device and settings:** fresh install, no throwaway data.
- **Steps:**
  1. Open Settings and turn Expiration Reminders off, then on.
  2. The notification prompt appears. Tap Don't Allow.
- **Expected:** the footer says "Notifications are off for Tasquel…" straight away. The spec says the footer reports this.
- **Actual:**
  - The footer is unchanged until Settings is closed and reopened.
  - Going to the iOS Settings app and coming back doesn't refresh it either.
  - There's no Open Settings button, though the Calendar row has one (`CalendarSettings.swift:45`).
- **Evidence:**
  - Screenshots: `SHOTS/reminders-1-prompt.png`, `reminders-2-after-deny.png`, `SHOTS/reminders-3-reopened.png`, side by side in `reminders.png`.
  - Test `testRemindersFooterSaysNotificationsOffAfterDenying` failed at line 173, twice (`SHOTS/runA.log`, `SHOTS/runD.log`).
- **Likely cause:** `SettingsSheet.swift:367` reads `isDenied()` once, in a `.task`, when the row appears. `requestPermissionIfNeeded` (`ExpiryNotifications.swift:25-32`) returns no result.
- **Suggested fix:** make the request async and check the status again after it, and again when the app becomes active. Add an Open Settings button (`openNotificationSettingsURLString`).

**F4. The live Privacy Policy still calls Feature Ideas the "Coming Soon" survey. Minor (website).**
- **Steps:** Settings ▸ Privacy Policy.
- **Actual:** the page says "The app's optional 'Coming Soon' survey in Settings…". The app calls it Feature Ideas, and the spec says never to call it "Coming Soon" (App Review 2.1).
- **Evidence:** `links-plain-PrivacyPolicy.png`, `SHOTS/web/privacy.html`.
- **Suggested fix:** rename it on the page, and check the same wording in App Store Connect.

**F5. Two small mismatches. Polish.**
- What's New's footer says "Settings ▸ What's New". The row is Settings ▸ Help ▸ "What's New in 1.1" (`WhatsNew.swift`, footer).
- In Seasonal, Settings and Help row icons and Add Category's "Create New Category" and "Edit" stay system blue, while switches and checkmarks take the season's accent. `AddCategorySheet.swift:70` sets no tint for Seasonal.

### 2. Checked and fine
- Main screen, Settings, Help (Q&A, and Dates reached by swiping) and What's New look right in System, Light, Dark, Seasonal fall and Retro green. The new parts (day pills with dates, Fri / Nov 15 marks, pins, ⧉ Duplicate, Just this week chip, What's New pill) have no placeholder text and keep their style.
- I couldn't capture Seasonal in dark through XCUITest, because setting the phone to Dark from a test didn't take. A cold launch set dark by hand showed spring's night palette correctly (`SHOTS/sheets/manual.png`).
- Seasonal winter, spring, summer and fall (light): day filter line with Show All, card edit mode, Edit with the Add Category tile and sheet, next week with the house, Go to Week sheet.
- Retro in all 6 colors, main screen and Settings. Retro's DOS field shows the brackets and underscore cursor.
- The phone switched to Dark with Settings open in System: Settings and the main screen follow, and come back to light.
- Retro Amber, and then System, are both kept across a relaunch.
- Support and Privacy open the right pages in Safari (plain and Retro), and Settings is still open on return. Both URLs return 200.
- Sort Cards ▸ Recently Edited First with a pinned card: the pinned card stays first, and the card edited last leads the rest.
- Switching Sunday/Monday start keeps a pinned card pinned and first, in this week and next, both ways.
- Version and build show 1.0.3 (11), which is known.
- The known Match App Icon item reproduced: after Retro → System, the home-screen icon stayed Retro (`SHOTS/now.png`).
- Feature Ideas: I only viewed it (Send stays disabled with nothing ticked) and never sent. The existing `SettingsUITests.testFeatureIdeasDraftIsKept` covers ticking and typing; I didn't re-run it.

### 3. Test files (in `tests/Settings/`)
- `ReviewSettingsSupport.swift`: helpers.
- `ReviewSettingsTests.swift`:
  - F1: `testWeekStartSwitchKeepsDatedTaskInItsWeek`. It picks its date from today: on a Sunday, next week's Friday; on other days, next week's Sunday. I only ran it on a Sunday.
  - F2: `testSeasonalPickedInOpenSettingsFollowsDarkSwitch` and `testSystemDarkModeSwitchWhileSettingsIsOpen`.
  - F3: `testRemindersFooterSaysNotificationsOffAfterDenying`. It needs a never-asked permission, so run `xcrun simctl erase` first. Uninstalling doesn't reset the permission on the simulator, and without the prompt the test skips.
  - Checked and fine: `testSeasonalSettingsRowsFollowDarkSwitch`, `testAppearanceAndRetroColorSurviveRelaunch`, `testSupportAndPrivacyLinksOpenTheirPages`, `testSortCardsKeepsPinnedCardsFirst`, `testWeekStartSwitchKeepsPinnedCardsFirst`, all passing.
- `ReviewSettingsExploreTests.swift`: screenshot walks, not asserts.
  - `testExploreAppearances` (env `SHEETS`, `SHOT_PREFIX`): with `SHEETS` it can go over the 5-minute limit under load.
  - `testExploreRetroColors`.
  - `testExploreNewParts` (env `COMBOS="look:season:holiday,…"`).
  - `testExploreSeason`.
- Runner script: `run.sh`. Contact sheets: `SHOTS/sheets/`.

### 4. Couldn't check in a simulator
- Turn Dark Mode on in Control Center while Settings is open in Seasonal (F2) on iOS 27.2: does it still show cream rows?
- With a task dated tomorrow, does the 9 AM reminder arrive, and does it show as a banner while Tasquel is open?
- Deny notifications, turn them on in iOS Settings, and come back: does the footer stay stale?
- Switch Retro ↔ System with Match App Icon on: does the home-screen icon follow both ways, and does iOS's alert get in the way?
- Seasonal backdrop and holiday marks at full size on the phone: are the string lights and confetti on the 30pt mark readable?
- Thanksgiving week: do the turkey and the What's New pill slide out smoothly?
- On the Support page, does the mail link open Mail?
- Do Feature Ideas ticks give a selection haptic?
- Smart Add's "Set Date": under heavy load, a first tap once did nothing (`runB.log`). On the phone, does one tap always set the date?
