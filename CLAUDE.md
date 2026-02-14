# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

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
| `Tasquel/ContentView.swift` | All SwiftUI views (root view + subviews) |

### Data Models (`Models.swift`)

- **`TaskMode`** — enum: `.carryOver` (rolls if incomplete), `.repeating` (every week), `.oneTime` (never carries)
- **`SubTask`** — nested checklist item within a task
- **`ChecklistTask`** — task with title, completion, mode, and subtasks array
- **`Category`** — named group of tasks with SF Symbol icon
- **`Week`** — date-anchored container of categories (Monday-based)
- **`CategoryTemplate`** — saved category name+symbol for reuse
- **`AppearanceMode`** — enum: `.system`, `.light`, `.dark`

### Store (`ChecklistStore.swift`)

Single `@Observable` store owns all app state. Two JSON files for persistence:

- **`checklist.json`** — array of `Week` objects (all task data)
- **`settings.json`** — `CategoryTemplate` list, appearance mode, onboarding flag

Key behaviors:
- **Weekly rollover**: `ensureWeekExists(for:)` creates new weeks by rolling forward categories from the most recent prior week. Repeating tasks always carry (reset). Carry-over tasks carry only if incomplete. One-time tasks never carry.
- **Init order matters**: Settings load first → seed starter categories if empty → load weeks → ensure current week exists.

### Views (`ContentView.swift`)

All views live in one file. Key components:

- **`ContentView`** — NavigationStack root, toolbar groups, sheet presentation, onboarding trigger
- **`CategoryHeader`** — section header with icon, name, completion count, edit-mode remove button
- **`TaskRow`** — task with completion toggle, inline editing, mode picker, subtask expansion
- **`SubTaskRow`** — indented sub-task with checkbox
- **`AddTaskRow`** — inline text field with mode picker
- **`AddCategorySheet`** — saved templates + create new
- **`RemoveCategorySheet`** — remove (this week) vs delete entirely, with X dismiss
- **`OnboardingSheet`** — two-step: welcome instructions → category setup (create own or skip defaults)
- **`DatePickerSheet`**, **`SettingsSheet`**, **`HelpSheet`** — supporting sheets

### UI Patterns

- **iOS 26 Liquid Glass**: auto-adopted via Xcode 26 recompile (NavigationStack, toolbars, controls)
- **Toolbar layout**: Leading = `[< calendar >]` grouped; Trailing = `[edit/done gear]` grouped
- **Edit mode**: toggled via pencil/checkmark button. Enables category add/remove, inline task editing, mode picker, subtask management
- **Collapsible sections**: `Section(isExpanded:)` with `Set<UUID>` tracking
- **Swipe actions**: right-swipe cycles task modes, left-swipe deletes
- **Context menus**: on category headers and task rows

## Swift Configuration

- Default actor isolation: `MainActor`
- Approachable Concurrency enabled
- Upcoming feature: Member Import Visibility
- No external dependencies — pure Apple frameworks

## Test Targets

- `TasquelTests` — Swift Testing with `@Test` macro
- `TasquelUITests` — XCTest
