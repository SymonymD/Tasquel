# AI Dev Recap — Tasquel

> Session history for continuity across context resets. Read this file at the start of any new session.

## Maintenance Instructions

**For the user**: Before a rate limit reset or ending a session, ask Claude to update this file. Prompt:

> "Update AI_DEV_RECAP.md with work done this session before we wrap up."

**For Claude**: When asked to update this file:
1. Run `git log --oneline --reverse` to get the full commit history
2. Read the current `AI_DEV_RECAP.md`
3. Update these sections:
   - **Current State**: Update line counts, add new files if created
   - **Features Implemented**: Add any new features built this session
   - **Commit History**: Append new commits
   - **Key Decisions & Gotchas**: Add any new issues encountered and their solutions
   - **Planned / Not Yet Implemented**: Move items to "implemented" if done, add new planned items
   - **Last Session Summary** (bottom of file): Replace with a brief summary of what was done, what's in progress, and what the user wanted to do next
4. Commit and push: `git add AI_DEV_RECAP.md && git commit -m "Update AI dev recap" && git push`

## Project

**Tasquel** — Weekly checklist iOS app (iPhone + iPad), SwiftUI, iOS 26.2, Xcode 26.2.
Bundle ID: `com.symonym.Tasquel`
Repo: https://github.com/SymonymD/Vikov.git
Simulator: iPhone 17 Pro (ID: `66BC7B60-5C39-4599-BAD6-839C1BA81204`, iOS 26.2)
Figma File Key: `m5BPKMcJmfaMXsMmpAFzjF`

## Current State (as of 2026-02-15)

All features below are implemented and building successfully. Uncommitted changes in working tree (major UI redesign from List to card-based grid).

### Files

| File | Lines | Purpose |
|------|-------|---------|
| `Tasquel/TasquelApp.swift` | ~15 | `@main` App struct, unchanged from template |
| `Tasquel/Models.swift` | ~181 | All data models: `TaskMode`, `TaskType`, `SubTask`, `ChecklistTask`, `Category`, `Week`, `CategoryTemplate`, `AppearanceMode` |
| `Tasquel/ChecklistStore.swift` | ~451 | `@Observable` store: persistence, business logic, CRUD, rollover, goal tracking, future week sync |
| `Tasquel/ContentView.swift` | ~1421 | All SwiftUI views: card-based grid, expanded cards, task rows, goal progress, sheets, 4-step onboarding |
| `CLAUDE.md` | ~91 | Architecture reference for Claude Code |

### Features Implemented

1. **Weekly checklist structure**: Weeks → Categories → Tasks → Sub-tasks
2. **Three task modes**: Carry Over (rolls if incomplete), Repeating (every week, resets), One-Time (never carries)
3. **JSON persistence**: Two files — `checklist.json` (week data), `settings.json` (preferences)
4. **Weekly rollover**: `ensureWeekExists(for:)` creates new weeks from prior week's categories. Respects all three task modes.
5. **Week navigation**: Centered capsule with previous/next arrows + calendar date picker below title
6. **Edit mode**: Pencil/checkmark toggle in bottom-right. Enables:
   - Add categories (dashed-border card appears in grid)
   - Inline task title editing (double-tap or tap in edit mode)
   - Inline mode icons per task (carry-over, repeating, one-time + delete)
   - Task type picker (checkbox/goal) via context menu
   - Sub-task management (add, edit, delete, complete)
   - Category removal via context menu (save, remove this week, delete entirely)
7. **Saved category templates**: Categories saved for reuse. Add Category sheet shows "Create New" first, then saved.
8. **Appearance toggle**: System (default) / Light / Dark in Settings
9. **Four-step onboarding**:
   - Screen 1: Brief Tasquel summary (auto carry-over focus)
   - Screen 2: Granular feature breakdown (task modes, checkbox vs goal)
   - Screen 3: Username input (1–20 chars, stored in UserDefaults)
   - Screen 4: Category setup grid (2-column grid of defaults to accept/delete + add custom) with "Let's Go!" button
10. **Help sheet**: Detailed instructions on all features including task types and card grid, accessed from Settings
11. **Context menus**: On category cards (save, remove, delete) and task rows (mode, type, edit, subtasks, delete)
12. **iOS 26 Liquid Glass**: Auto-adopted via Xcode 26 (controls, sheets, materials)
13. **Goal-based tasks**:
    - `TaskType` enum: `.checkbox` (default), `.goal`
    - Goal fields on `ChecklistTask`: `goalTarget`, `goalProgress`, `goalUnit`
    - Progress ring indicator on left (replaces checkbox)
    - Inline progress section: ProgressView bar, fraction display, "Add progress" input
    - Inline goal setup: Target/Unit text fields when no target set (not a popup)
    - Auto-completion when progress >= target
    - Task type picker in AddTaskRow menu and context menu
14. **Username**: Persisted via UserDefaults, editable in Settings, collected during onboarding
15. **Double-tap editing**: Double-tap task title to edit inline
16. **Date banner**: Shows today's date with ordinal suffix (e.g. "Sunday, Feb 15th"), "Go to Today" button on non-current weeks
17. **Past week read-only**: Past weeks hide AddTaskRow, AddCategory, and edit button
18. **Future week full editing**: Same capabilities as current week — add/remove tasks and categories
19. **Future week sync**: `syncFutureWeek(for:)` ensures all categories and recurring tasks from the source week appear in future weeks.
20. **Card-based grid UI** (NEW — Figma redesign):
    - Replaced `NavigationStack` + `List` with `ZStack` + `ScrollView` + `LazyVGrid`
    - Collapsed cards in 2-column grid with SF Symbol, name, yellow clock icon, completed count, task dot previews, expand arrow (↗)
    - Single expanded category (`UUID?`) instead of `Set<UUID>` — tapping a card expands it full-width
    - Expanded card shows all tasks with circles (filled green = done, empty = not), subtasks, add-task field, edit/checkmark toggle
    - Edit mode shows inline HStack of mode icons (carry-over, repeating, one-time) + red trash per task
    - Dashed-border "Add Category" card appears in grid during edit mode
    - Cards use `Color(.secondarySystemGroupedBackground)` with subtle shadow for adaptive light/dark backgrounds
    - Bottom bar: settings gear (left), date with "Go to Today" (center), edit pencil/checkmark (right)
    - Removed swipe actions (not supported outside List), replaced with inline edit-mode icons + context menus

### UI Layout (Post-Redesign)

- **Root**: `ZStack` with `Color(.systemBackground)` background
- **Title**: "Week of M/d/yy" centered, `.title.bold()`
- **Navigation capsule**: Centered `HStack` with `< calendar >` in `.regularMaterial` capsule
- **Content**: `ScrollView` + `LazyVGrid` (2 flexible columns, 16pt spacing)
- **Expanded card**: Full-width `VStack` at top of scroll, collapsed cards in grid below
- **Bottom bar**: `HStack` — gear circle (left), date text (center), pencil/checkmark circle (right)
- **Edit-done button**: Green-tinted `checkmark` with green background + ring when active
- **Add Category**: Dashed-border card in grid during edit mode
- **Card backgrounds**: `secondarySystemGroupedBackground` in `RoundedRectangle(cornerRadius: 16)` with soft shadow

## Commit History

```
baa06f1 Initial Commit
17c8ea7 Add weekly checklist MVP: models, store with JSON persistence, and full UI
6917ea3 Redesign UI for iOS 26 with Liquid Glass, starter categories, and task modes
bb21900 Add saved categories, welcome alert, help guide, appearance toggle
d2b7614 Add Edit mode, one-time tasks, sub-tasks, and inline editing
2f773c0 Move Add Category to top, green edit-done button, onboarding flow, dismissable remove sheet
2b8dace Update CLAUDE.md with full current architecture
207a2cf Add AI dev recap for session continuity
3106482 Rename app from VIKOV to Tasquel
```

## Development Workflow

- Build after each checkpoint: `xcodebuild -project Tasquel.xcodeproj -scheme Tasquel -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
- Install to sim: `xcrun simctl install 66BC7B60-5C39-4599-BAD6-839C1BA81204 ~/Library/Developer/Xcode/DerivedData/Tasquel-aviiopvkyuygsagufoplyonwfrif/Build/Products/Debug-iphonesimulator/Tasquel.app`
- Launch: `xcrun simctl launch 66BC7B60-5C39-4599-BAD6-839C1BA81204 com.symonym.Tasquel`
- Screenshot: `xcrun simctl io 66BC7B60-5C39-4599-BAD6-839C1BA81204 screenshot /tmp/tasquel.png`
- Fresh install test: `xcrun simctl uninstall ... && xcrun simctl install ...`
- New files in `Tasquel/` are auto-discovered (`PBXFileSystemSynchronizedRootGroup`)
- DerivedData path changed: `Tasquel-aviiopvkyuygsagufoplyonwfrif` (was `Tasquel-enfbpsqjcwhtrgdnotmnlfnayzgj`)

## Key Decisions & Gotchas

1. **Simulator name**: `iPhone 16` doesn't exist in Xcode 26.2 — use `iPhone 17 Pro`
2. **Init order in ChecklistStore**: Must seed `savedCategories` BEFORE `ensureWeekExists(for:)`, otherwise first week gets 0 categories
3. **No simctl tap**: `xcrun simctl io input tap` doesn't exist — can't programmatically interact with UI, only screenshot
4. **`.quaternary` type mismatch**: Can't use `.quaternary` in ternary with `Color` — use `Color.secondary` instead
5. **Settings JSON UUIDs**: When manually editing `settings.json` for testing, UUIDs must be valid format (e.g., `A1B2C3D4-E5F6-7890-ABCD-EF1234567890`), not short strings
6. **GitHub auth**: Uses `gh` CLI (installed via Homebrew), HTTPS protocol, account `SymonymD`
7. **Monday-based weeks**: Must set `calendar.firstWeekday = 2` in `mondayOfWeek(containing:)` — US locale defaults to Sunday which caused Sunday dates to map to the wrong week
8. **Future week stale data**: `ensureWeekExists` only creates a week once. If you navigate to a future week, go back, add recurring tasks, then navigate forward again, those tasks won't appear unless explicitly synced. Fixed with `syncFutureWeek(for:)` which runs on every future-week navigation.
9. **Category UUIDs differ per week**: Each week gets fresh category UUIDs from rollForward. Expansion tracking must use single `UUID?` (not `Set<UUID>`) and reset on week navigation.
10. **SourceKit false positives**: Cross-file resolution errors like `Cannot find 'Category' in scope` or `Category (aka 'OpaquePointer')` are transient SourceKit issues — all builds succeed. Ignore these diagnostics.
11. **Swipe actions require List** (NEW): `swipeActions` modifier only works inside `List`. After migrating to `ScrollView` + `LazyVGrid`, swipe actions were replaced with inline edit-mode icons and context menus.
12. **Rollover resets completed tasks on test data** (NEW): When writing test data directly to `checklist.json`, the `ensureWeekExists` init logic may strip completed carry-over tasks and one-time tasks. Completed tasks show as red dots because rollover reset them. This is correct app behavior — only affects manual test data injection.

## Figma Reference

- **File key**: `m5BPKMcJmfaMXsMmpAFzjF`
- **State_Default** (node `91:926`): 2-column grid of dark rounded cards, title centered, nav capsule, bottom bar
- **State_Category-Expand** (node `92:90`): Expanded category card full-width with task list, remaining cards in grid below
- **State_Category_Tasks_Edit** (node `93:370`): Edit mode with inline mode icons + delete on each task row

## Planned / Not Yet Implemented

- Calendar integration (paid upgrade toggle exists in Settings, marked "Coming Soon")
- Unit tests (test targets exist but no tests written yet)
- iPad-specific layout optimizations
- Data export/import
- Uncommitted changes need to be committed and pushed

## Last Session Summary (2026-02-15)

**What was done**: Complete UI redesign from List-based layout to Figma card-based grid:
- Rewrote **ContentView.swift** entirely (1690 → 1421 lines) — replaced `NavigationStack` + `List` with `ZStack` + `ScrollView` + `LazyVGrid`
- Implemented **2-column card grid** with collapsed category cards showing task dot previews
- Implemented **single expanded card** mode (`UUID?` instead of `Set<UUID>`)
- Added **inline edit mode icons** per task (3 mode icons + delete) replacing swipe actions
- Added **dashed-border "Add Category" card** in grid during edit mode
- Cards use **adaptive backgrounds** (`secondarySystemGroupedBackground`) with subtle shadows
- Fixed **expand/collapse arrows** to match Figma (↗ expand, ↙ collapse)
- Updated **Help sheet** content to reflect new card-based UI
- Verified builds in both **light and dark mode** — dark mode closely matches Figma design
- All changes build successfully (BUILD SUCCEEDED)

**In progress**: User reviewing the Figma-matched UI implementation. Uncommitted changes in working tree.

**User's likely next steps**: Review card grid UI, provide feedback for refinements, commit/push changes.
