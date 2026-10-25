# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Tasquel is a weekly checklist iOS app (iPhone + iPad) built with SwiftUI, targeting iOS 26.0. Bundle ID: `com.symonym.Tasquel`. No external dependencies — pure Apple frameworks.

Users organize tasks into categories within weekly views. Tasks support three modes (carry-over, repeating, one-time), sub-tasks, and automatic weekly rollover. Categories are saved as reusable templates.

## Build & Test Commands

```bash
# Build
xcodebuild -project Tasquel.xcodeproj -scheme Tasquel -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# Run unit tests (Swift Testing framework)
xcodebuild -project Tasquel.xcodeproj -scheme Tasquel -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test

# Run a single test
xcodebuild -project Tasquel.xcodeproj -scheme Tasquel -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:TasquelTests/TasquelTests/testExample test
```

Simulator: iPhone 17 Pro (iOS 26.3; an iOS 26.0 runtime is installed for checking the minimum). Files added to the `Tasquel/` folder are auto-discovered by the build system (`PBXFileSystemSynchronizedRootGroup`).

## Architecture

### File Structure

| File | Purpose |
|------|---------|
| `Tasquel/TasquelApp.swift` | `@main` App struct; owns the shared store and calendar service |
| `Tasquel/Models.swift` | All data models (value types + enums) |
| `Tasquel/ChecklistStore.swift` | `@Observable` store — business logic, persistence, state |
| `Tasquel/Theme.swift` | `Theme` color/font functions for all appearance modes + `ScanlineOverlay` |
| `Tasquel/ContentView.swift` | Root view: title, week nav capsule, category grid layout, bottom bar, load-error screen |
| `Tasquel/CategoryCard.swift` | `CategoryCard` (collapsed) + `ExpandedCategoryCard`, deletion confirmations |
| `Tasquel/TaskRowCard.swift` | `TaskRowCard`, `SubTaskRowCard`, `AddTaskRowCard`, goal editing |
| `Tasquel/TaskOptionsPicker.swift` | Two-column type/mode picker (popover) and the task row's type+mode icon capsule |
| `Tasquel/CategorySymbols.swift` | Category icon list with readable names, `CategorySymbolMenu` (icons plus Choose Emoji…), `CategoryIcon` (draws a `symbol` that is an SF Symbol name or a single emoji; always use it, never `Image(systemName:)`, for category icons) |
| `Tasquel/SavedCategoriesView.swift` | Settings ▸ Saved Categories: rename and re-icon in place, reorder, add, delete templates; `SavedCategoryRow` (the in-place editing row, also used by Add Category) |
| `Tasquel/AddCategorySheet.swift` | `AddCategorySheet` (saved templates + create new; Edit Saved Categories edits and removes them in place) + `DatePickerSheet` |
| `Tasquel/SettingsSheet.swift` | Settings (standard List + retro layouts); `AppInfo` holds the Support/Privacy URLs and reads the version |
| `Tasquel/HelpSheet.swift` | Help guide |
| `Tasquel/OnboardingSheet.swift` | Onboarding: welcome, then one page each for task types, task modes, category cards and calendar events, each with an animation |
| `Tasquel/CategoryGridLayout.swift` | Custom `Layout`: two-column card grid, expanded cards take a full row |
| `Tasquel/CalendarService.swift` | Calendar integration: EventKit/fake providers, day grouping, permission, per-week event cache, `FeatureAccess` |
| `Tasquel/CalendarSettings.swift` | Settings rows and calendar picker for calendar integration |
| `Tasquel/CalendarEventsPanel.swift` | The week's events, shown inside the bottom bar when its calendar toggle is on |
| `Tasquel/WeekCarryOverAnimation.swift` | Welcome illustration: `KeyframeAnimator` loop showing an unfinished task carrying into next week |
| `Tasquel/FeatureAnimations.swift` | Onboarding feature animations (`TaskTypesAnimation`, `TaskModesAnimation`, `CategoryCardsAnimation`, `CalendarEventsAnimation`) and the shared `Illustration` parts / `IllustrationCheck` all the onboarding animations draw with |
| `Tasquel/ParsedTask.swift` | Smart Add, platform-neutral half: `ParsedTask`, the `TaskTextParser` protocol, `store.addParsedTask` (one save, only into the week it was typed in), and `TaskTextHints` (rules for clear schedule phrases like "3x per week", "every Monday", "until done" that override the model when they match). Only the ✨ Smart Add button reads the words; Return adds text exactly as typed |
| `Tasquel/AppleIntelligenceTaskParser.swift` | Smart Add's parser: the only file that imports FoundationModels (on-device model, `@Generable TaskDraft`). Optional by design (no Apple Intelligence, or a future Android build): the add-task row hides Smart Add when `isAvailable` is false |
| `Tasquel/PrivacyInfo.xcprivacy` | Privacy manifest (no tracking or collected data; UserDefaults reason CA92.1) |

### Data Models (`Models.swift`)

- **`TaskMode`** — `.carryOver` (rolls if incomplete), `.repeating` (every week), `.oneTime` (never carries)
- **`TaskType`** — `.checkbox`, `.goal` (target/progress/unit) or `.list` (items stored as sub-tasks; checks itself off). Type and mode are independent.
- **`SubTask`**, **`ChecklistTask`**, **`Category`** (name + SF Symbol + tasks)
- **`Week`** — container of categories, identified by `startDay` (a `DayKey`: Gregorian year-month-day, saved as `"yyyy-MM-dd"`), not by a moment, so time-zone changes can't duplicate weeks. `startDate` is computed (midnight in the current time zone) and still written for older builds; files without `startDay` get it from `startDate` in the current time zone on first load and are re-saved. `dismissedCarryOvers` / `dismissedRepeating` record tasks the user deleted from that week.
- **`GoalNumber`** — locale-aware goal amount parsing/formatting; goal values are capped at `GoalUnitKind.maxValue` (999,999)
- **`CategoryTemplate`** — saved category name+symbol for reuse
- **`AppearanceMode`** — `.system`, `.light`, `.dark`, `.retro`; **`RetroColor`** — retro phosphor palette

### Store (`ChecklistStore.swift`)

Single `@Observable` store owns all app state. `init(directory:defaults:now:calendar:)` defaults to the Documents folder, `UserDefaults.standard`, `Date()` and `Calendar.current`; **tests must pass a temp directory and a throwaway defaults suite** (`makeIsolatedStore()`) so they never touch real data, and a `TestClock` when they depend on today or the time zone. Past/current/future checks live on the store (`isPastWeek(_:)`, `isCurrentWeek(_:)`, `isFutureWeek(_:)`) so they use that clock. Week dates always use `Calendar.weekDates(in:)` (Gregorian, user's time zone), never `Calendar.current`, so non-Gregorian device calendars find the same weeks.

- **`checklist.json`** — array of `Week` objects (all task data)
- **`settings.json`** — templates, appearance mode, retro color, onboarding flag
- `UserDefaults` — `didMigrateStarters_v1` (an old `userName` key may linger; nothing reads it)
- **Removed saved categories** are remembered in settings (`removedSavedCategoryNames`), so deleting a card with that name doesn't save it again.
- **Week start without settings.json** (Start Fresh after it couldn't be read) is inferred from the most recent saved week's weekday, so Sunday weeks stay reachable.
- **Starter categories** are added to saved categories only on first launch; `offeredStarterNames` in settings remembers which were offered, so ones the user removes (even all of them) never come back. Onboarding doesn't choose categories; a new user starts with the starters.

Key behaviors:
- **Weekly rollover**: a week is built by rolling forward categories from the most recent saved prior week. Repeating tasks always carry (reset). Carry-over tasks carry only if incomplete. One-time tasks never carry. Category UUIDs change every week.
- **Future weeks are previews until edited**: only the current week is created by looking at it (`ensureWeekExists` at launch / navigation). Any other unsaved week is `previewWeek(for:)` (cached so IDs stay stable) and `selectedWeek` returns it. Every mutation goes through `editableSelectedWeekIndex()`, which saves the preview first. Saved future weeks keep syncing with the week before (`syncWithPreviousWeek`): untouched carried copies (`carriedFrom`) follow or leave with their source (a task the user added or changed in its week has `isUserEdited` and is never followed, removed or adopted), missing ones are added unless dismissed, and missing repeating tasks are added unless in `dismissedRepeating`. When a saved week becomes current it gets one final full sync (follow/remove untouched copies, no categories re-added) and is marked `didFinalSync`, so later edits to the current week are never undone.
- **Load order** (`loadAndPrepare`, used by init and `retryLoadingData`): settings → seed starter templates → weeks → ensure current week → starter migration.
- **Load-failure safety**: if either JSON file fails to decode, `persistenceError` is set, all saves are blocked (so defaults never overwrite the file), and `ContentView` shows a retry screen with Start Fresh (`setAsideUnreadableData()` renames the bad file, never deletes it). Task decoding is lenient (missing fields and unknown enum values get defaults). Save failures set `saveError` (an alert, only for the first failure in a run of them) and `isSaveFailing` (a lasting "Changes aren't being saved" notice under the week bar); failures are tracked per file, so both clear only when both files have saved, and a successful save retries the other file. The load-error screen also links to Support.
- **One store per app**: `TasquelApp` owns the store and calendar service and passes them to `ContentView`, so iPad windows share them.
- **Past weeks are read-only**: `editableSelectedWeekIndex()` returns nil for them.

### UI Patterns

- **Card grid** (`ScrollView`, not `List`): collapsed cards in 2-column rows; an expanded card takes a full-width row. Multiple cards can be open; expansion is tracked by `CategoryLayoutKey` (name + occurrence) since UUIDs change per week, so open cards persist across week navigation (in memory only).
- **Bottom bar**: settings (left), today's date / go-to-today (center), Edit/Done as text (right), flush with the bottom of the screen as a flat translucent bar with only a top border (also in retro). The grid's bottom padding follows the bar's measured height.
- **Edit mode (bottom bar)**: category management — add-category card and delete badges, with a "Hold and drag a card to move it" hint; open cards collapse (and reopen when editing ends) and can't open meanwhile. A card's own edit button edits only that card's tasks (trash cans, renaming). Deleting a category removes it from the viewed week and all later weeks (earlier weeks keep it; a future week records it in `dismissedCategories` so syncing doesn't add it back) and keeps its saved template.
- **Week paging**: last/this/next week are laid side by side (`PagerTrack`); drag offset lives in `WeekPagerState` so dragging doesn't rebuild pages.
- **Header / bottom bar**: the header shows the viewed week ("Week of …"); the bottom bar shows Settings, the calendar toggle (when calendar events are on), today's date (with Go to Today on other weeks), and Edit.
- **Calendar events**: the bottom bar's calendar toggle expands the bar to show the viewed week's events (`CalendarEventsPanel`), fed by `CalendarService`; tapping an event opens the Calendar app at its date. Event data is never persisted.
- **Week start**: Sunday or Monday (Settings ▸ Week). Use `store.startOfWeek(containing:)`, never a hard-coded Monday; changing the setting moves saved weeks by one day.
- **Destructive actions** (delete task/sub-task/category/template, goal → checkbox) go through `confirmationDialog`. Removing a saved category uses the shared `savedCategoryRemoval` dialog in both Settings and Add Category.
- **Keyboard Done**: while the keyboard is up the bottom bar becomes a small round keyboard-down button at the right (VoiceOver: "Done"); it bumps `store.keyboardDoneRequests` before closing the keyboard; rows with a typed but unadded task, sub-task or goal amount save it then (number pads have no Return key).
- **Past weeks** show "Past week · view only" under the week bar, with dimmed checkboxes.
- **Tasks**: checking a task with sub-tasks (or a list) checks them all; unchecking puts back the checks from before (cleared if there were none). Edits that change nothing (same name, same mode) don't mark a task `isUserEdited`. Typed but unadded tasks and sub-tasks are added however the keyboard closes; closing a card dismisses the keyboard first. Cards lift for dragging after a 0.5s hold. Tapping a task's or sub-task's name renames it. An open card also closes from a tap on its icon or name.
- **No swipe actions** (they require `List`); use edit-mode controls (no long-press menus on cards or tasks).
- **Text fields in cards** use `.cardField(theme, rc:)` (Theme.swift): a soft fill with 8pt rounded corners (2pt in retro); `outset: true` draws the fill around the text so a name and its rename field line up.
- **Retro theme**: every view branches on `Theme.isRetro(theme)` for monospaced fonts/terminal styling.
- **Accessibility**: small icon buttons get a 44pt hit area with `.touchTarget()` inside the label (no layout change). Retro text colors (bright/dim/faint, `retroRed`) keep 4.5:1 on a retro card; `glow` is only for the card shadow. Done/not done never relies on color alone (filled vs. outline). At accessibility text sizes every card takes a full row (`usesSingleColumn`). Reduce Motion turns off the card spring (`cardAnimation`) and sliding transitions.

## Swift Configuration

- Default actor isolation: `MainActor`
- Approachable Concurrency enabled
- Upcoming feature: Member Import Visibility
- No external dependencies — pure Apple frameworks

## Testing Launch Arguments

- Debug builds only.
- `-isolatedData`: the app uses throwaway storage (never the simulator's real data). Fresh data shows onboarding first.
- `-fakeCalendar`: sample calendar events instead of EventKit.

## Test Targets

- `TasquelTests` — Swift Testing with `@Test` macro
- `TasquelUITests` — XCTest
