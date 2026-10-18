# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

## Project Overview

Tasquel is a weekly checklist iOS app (iPhone + iPad) built with SwiftUI, targeting iOS 26.2. Bundle ID: `com.symonym.Tasquel`. No external dependencies — pure Apple frameworks.

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

Simulator: iPhone 17 Pro (iOS 26.2). Files added to the `Tasquel/` folder are auto-discovered by the build system (`PBXFileSystemSynchronizedRootGroup`).

## Architecture

### File Structure

| File | Purpose |
|------|---------|
| `Tasquel/TasquelApp.swift` | `@main` App struct, single `WindowGroup` |
| `Tasquel/Models.swift` | All data models (value types + enums) |
| `Tasquel/ChecklistStore.swift` | `@Observable` store — business logic, persistence, state |
| `Tasquel/Theme.swift` | `Theme` color/font functions for all appearance modes + `ScanlineOverlay` |
| `Tasquel/ContentView.swift` | Root view: title, week nav capsule, category grid layout, bottom bar, load-error screen |
| `Tasquel/CategoryCard.swift` | `CategoryCard` (collapsed) + `ExpandedCategoryCard`, deletion confirmations |
| `Tasquel/TaskRowCard.swift` | `TaskRowCard`, `SubTaskRowCard`, `AddTaskRowCard`, goal editing |
| `Tasquel/TaskOptionsPicker.swift` | Two-column type/mode picker (popover) and the task row's type+mode icon capsule |
| `Tasquel/CategorySymbols.swift` | Category icon list with readable names, `CategorySymbolMenu` |
| `Tasquel/SavedCategoriesView.swift` | Settings ▸ Saved Categories: rename, re-icon, reorder, add, delete templates |
| `Tasquel/AddCategorySheet.swift` | `AddCategorySheet` (saved templates + create new) + `DatePickerSheet` |
| `Tasquel/SettingsSheet.swift` | Settings (standard List + retro layouts) |
| `Tasquel/HelpSheet.swift` | Help guide |
| `Tasquel/OnboardingSheet.swift` | Onboarding flow (welcome, how it works, name, categories) |
| `Tasquel/CategoryGridLayout.swift` | Custom `Layout`: two-column card grid, expanded cards take a full row |
| `Tasquel/CalendarService.swift` | Calendar integration: EventKit/fake providers, day grouping, permission, per-week event cache, `FeatureAccess` |
| `Tasquel/CalendarSettings.swift` | Settings rows and calendar picker for calendar integration |
| `Tasquel/CalendarEventsPanel.swift` | The week's events, shown inside the bottom bar when its calendar toggle is on |
| `Tasquel/WeekCarryOverAnimation.swift` | Welcome illustration: `KeyframeAnimator` loop showing an unfinished task carrying into next week |
| `Tasquel/FeedbackSheet.swift` | Feedback webhook sheet — currently not linked from the UI |

### Data Models (`Models.swift`)

- **`TaskMode`** — `.carryOver` (rolls if incomplete), `.repeating` (every week), `.oneTime` (never carries)
- **`TaskType`** — `.checkbox`, `.goal` (target/progress/unit) or `.list` (items stored as sub-tasks; checks itself off). Type and mode are independent.
- **`SubTask`**, **`ChecklistTask`**, **`Category`** (name + SF Symbol + tasks)
- **`Week`** — date-anchored container of categories (Monday-based)
- **`CategoryTemplate`** — saved category name+symbol for reuse
- **`AppearanceMode`** — `.system`, `.light`, `.dark`, `.retro`; **`RetroColor`** — retro phosphor palette

### Store (`ChecklistStore.swift`)

Single `@Observable` store owns all app state. `init(directory:defaults:)` defaults to the Documents folder and `UserDefaults.standard`; **tests must pass a temp directory and a throwaway defaults suite** so they never touch real data.

- **`checklist.json`** — array of `Week` objects (all task data)
- **`settings.json`** — templates, appearance mode, retro color, onboarding flag
- `UserDefaults` — `userName`, `didMigrateStarters_v1`

Key behaviors:
- **Weekly rollover**: `ensureWeekExists(for:)` creates new weeks by rolling forward categories from the most recent prior week. Repeating tasks always carry (reset). Carry-over tasks carry only if incomplete. One-time tasks never carry. Category UUIDs change every week.
- **Load order** (`loadAndPrepare`, used by init and `retryLoadingData`): settings → seed starter templates → weeks → ensure current week → starter migration.
- **Load-failure safety**: if either JSON file fails to decode, `persistenceError` is set, all saves are blocked (so defaults never overwrite the file), and `ContentView` shows a retry screen.
- **Past weeks are read-only**: every mutation guards `!week.isPastWeek`.

### UI Patterns

- **Card grid** (`ScrollView`, not `List`): collapsed cards in 2-column rows; an expanded card takes a full-width row. Multiple cards can be open; expansion is tracked by `CategoryLayoutKey` (name + occurrence) since UUIDs change per week, so open cards persist across week navigation (in memory only).
- **Bottom bar**: settings (left), date / go-to-today (center), edit/done (right), on a Liquid Glass capsule (bordered box in retro).
- **Edit mode (bottom bar)**: category management — add-category card and delete badges; all cards collapse and can't open. A card's own edit button edits only that card's tasks (trash cans, renaming). Deleting a category removes it from the current and all future weeks (past weeks keep history) and keeps its saved template.
- **Week paging**: last/this/next week are laid side by side (`PagerTrack`); drag offset lives in `WeekPagerState` so dragging doesn't rebuild pages.
- **Header / bottom bar**: the header shows today's date; the bottom bar shows Settings, the calendar toggle (when calendar events are on), the viewed week ("Week of …", with Go to Today on other weeks), and Edit.
- **Calendar events**: the bottom bar's calendar toggle expands the bar to show the viewed week's events (`CalendarEventsPanel`), fed by `CalendarService`; tapping an event opens the Calendar app at its date. Event data is never persisted.
- **Week start**: Sunday or Monday (Settings ▸ Week). Use `store.startOfWeek(containing:)`, never a hard-coded Monday; changing the setting moves saved weeks by one day.
- **Destructive actions** (delete task/sub-task/category/template, goal → checkbox) go through `confirmationDialog`.
- **No swipe actions** (they require `List`); use context menus and edit-mode controls.
- **Retro theme**: every view branches on `Theme.isRetro(theme)` for monospaced fonts/terminal styling.

## Swift Configuration

- Default actor isolation: `MainActor`
- Approachable Concurrency enabled
- Upcoming feature: Member Import Visibility
- No external dependencies — pure Apple frameworks

## Testing Launch Arguments

- `-isolatedData`: the app uses throwaway storage (never the simulator's real data). Fresh data shows onboarding first.
- `-fakeCalendar`: sample calendar events instead of EventKit.

## Test Targets

- `TasquelTests` — Swift Testing with `@Test` macro
- `TasquelUITests` — XCTest
