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

## Current State (as of 2026-02-15)

All features below are implemented and building successfully. Not yet committed/pushed (uncommitted changes in working tree).

### Files

| File | Lines | Purpose |
|------|-------|---------|
| `Tasquel/TasquelApp.swift` | ~15 | `@main` App struct, unchanged from template |
| `Tasquel/Models.swift` | ~181 | All data models: `TaskMode`, `TaskType`, `SubTask`, `ChecklistTask`, `Category`, `Week`, `CategoryTemplate`, `AppearanceMode` |
| `Tasquel/ChecklistStore.swift` | ~451 | `@Observable` store: persistence, business logic, CRUD, rollover, goal tracking, future week sync |
| `Tasquel/ContentView.swift` | ~1690 | All SwiftUI views: root, task rows, goal progress, sheets, 4-step onboarding |
| `CLAUDE.md` | ~91 | Architecture reference for Claude Code |

### Features Implemented

1. **Weekly checklist structure**: Weeks → Categories → Tasks → Sub-tasks
2. **Three task modes**: Carry Over (rolls if incomplete), Repeating (every week, resets), One-Time (never carries)
3. **JSON persistence**: Two files — `checklist.json` (week data), `settings.json` (preferences)
4. **Weekly rollover**: `ensureWeekExists(for:)` creates new weeks from prior week's categories. Respects all three task modes.
5. **Week navigation**: Floating bottom-left capsule with previous/next arrows + calendar date picker
6. **Edit mode**: Pencil/checkmark toggle in top-right toolbar. Enables:
   - Add/remove categories (top of list, under header)
   - Inline task title editing
   - Task mode picker (tap mode badge)
   - Task type picker (checkbox/goal)
   - Sub-task management (add, edit, delete, complete)
   - Category removal sheet with X dismiss (remove this week vs delete entirely)
7. **Saved category templates**: Categories saved for reuse. Add Category sheet shows "Create New" first, then saved.
8. **Appearance toggle**: System (default) / Light / Dark in Settings
9. **Four-step onboarding**:
   - Screen 1: Brief Tasquel summary (auto carry-over focus)
   - Screen 2: Granular feature breakdown (task modes, checkbox vs goal)
   - Screen 3: Username input (1–20 chars, stored in UserDefaults)
   - Screen 4: Category setup grid (2-column grid of defaults to accept/delete + add custom) with "Let's Go!" button
10. **Help sheet**: Detailed instructions on all features including task types, accessed from Settings
11. **Swipe actions**: Left-swipe = delete, right-swipe = mode selection buttons (all 3 modes shown)
12. **Context menus**: On category headers (save, remove, delete) and tasks (mode, type, edit, subtasks, delete)
13. **iOS 26 Liquid Glass**: Auto-adopted via Xcode 26 (NavigationStack, toolbars, controls)
14. **Goal-based tasks** (NEW):
    - `TaskType` enum: `.checkbox` (default), `.goal`
    - Goal fields on `ChecklistTask`: `goalTarget`, `goalProgress`, `goalUnit`
    - Progress ring indicator on left (replaces checkbox)
    - Inline progress section: ProgressView bar, fraction display, "Add progress" input
    - Inline goal setup: Target/Unit text fields when no target set (not a popup)
    - Auto-completion when progress >= target
    - Task type picker in AddTaskRow menu and edit mode
15. **Username** (NEW): Persisted via UserDefaults, editable in Settings, collected during onboarding
16. **Double-tap editing** (NEW): Double-tap task title to edit inline + auto-expand subtasks
17. **Date banner** (NEW): Shows today's date with ordinal suffix (e.g. "Sunday, 15th"), "Today" label on current week, "Today" navigation button on other weeks
18. **Past week read-only** (NEW): Past weeks hide AddTaskRow, AddCategory, and edit button
19. **Future week full editing** (NEW): Same capabilities as current week — add/remove tasks and categories
20. **Future week sync** (NEW): `syncFutureWeek(for:)` ensures all categories and recurring tasks from the source week appear in future weeks. Auto-expands categories on week navigation.

### UI Layout

- **Title**: "Week of..." in `.large` display mode (left-aligned, big)
- **Toolbar top-right**: `[pencil / green checkmark]` (no border on pencil)
- **Floating bottom-left**: Navigation capsule `[< chevron]  [calendar]  [> chevron]` with `.regularMaterial`, scaled 110%
- **Floating bottom-right**: Settings gear button with `.regularMaterial` circle
- **Edit-done button**: Green-tinted `checkmark` with green background when active
- **Add Category**: Appears at top of list (under header) in edit mode only
- **Collapsible sections**: `Section(isExpanded:)` with `Set<UUID>` tracking, auto-expanded on week navigation

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
- Install to sim: `xcrun simctl install 66BC7B60-5C39-4599-BAD6-839C1BA81204 ~/Library/Developer/Xcode/DerivedData/Tasquel-enfbpsqjcwhtrgdnotmnlfnayzgj/Build/Products/Debug-iphonesimulator/Tasquel.app`
- Launch: `xcrun simctl launch 66BC7B60-5C39-4599-BAD6-839C1BA81204 com.symonym.Tasquel`
- Screenshot: `xcrun simctl io 66BC7B60-5C39-4599-BAD6-839C1BA81204 screenshot /tmp/tasquel.png`
- Fresh install test: `xcrun simctl uninstall ... && xcrun simctl install ...`
- New files in `Tasquel/` are auto-discovered (`PBXFileSystemSynchronizedRootGroup`)

## Key Decisions & Gotchas

1. **Simulator name**: `iPhone 16` doesn't exist in Xcode 26.2 — use `iPhone 17 Pro`
2. **Init order in ChecklistStore**: Must seed `savedCategories` BEFORE `ensureWeekExists(for:)`, otherwise first week gets 0 categories
3. **No simctl tap**: `xcrun simctl io input tap` doesn't exist — can't programmatically interact with UI, only screenshot
4. **`.quaternary` type mismatch**: Can't use `.quaternary` in ternary with `Color` — use `Color.secondary` instead
5. **Settings JSON UUIDs**: When manually editing `settings.json` for testing, UUIDs must be valid format (e.g., `A1B2C3D4-E5F6-7890-ABCD-EF1234567890`), not short strings
6. **GitHub auth**: Uses `gh` CLI (installed via Homebrew), HTTPS protocol, account `SymonymD`
7. **Monday-based weeks** (NEW): Must set `calendar.firstWeekday = 2` in `mondayOfWeek(containing:)` — US locale defaults to Sunday which caused Sunday dates to map to the wrong week
8. **Future week stale data** (NEW): `ensureWeekExists` only creates a week once. If you navigate to a future week, go back, add recurring tasks, then navigate forward again, those tasks won't appear unless explicitly synced. Fixed with `syncFutureWeek(for:)` which runs on every future-week navigation.
9. **Category UUIDs differ per week** (NEW): Each week gets fresh category UUIDs from rollForward. The `expandedCategories` `Set<UUID>` must be refreshed on week navigation or all sections appear collapsed.
10. **SourceKit false positives** (NEW): Cross-file resolution errors like `Cannot find 'Category' in scope` or `Category (aka 'OpaquePointer')` are transient SourceKit issues — all builds succeed. Ignore these diagnostics.

## Planned / Not Yet Implemented

- Calendar integration (paid upgrade toggle exists in Settings, marked "Coming Soon")
- Unit tests (test targets exist but no tests written yet)
- iPad-specific layout optimizations
- Data export/import
- Uncommitted changes need to be committed and pushed

## Last Session Summary (2026-02-15)

**What was done**: Major feature additions and UI overhaul across multiple feedback rounds:
- Added **goal-based tasks** (TaskType enum, progress tracking, inline goal setup, auto-completion)
- Added **username** support (UserDefaults, onboarding step, Settings editing)
- Rewrote **onboarding** from 2-step to 4-step flow (overview → features → name → category grid with "Let's Go!")
- Reworked **navigation layout**: floating bottom-left capsule (10% larger), floating bottom-right settings, edit top-right, large left-aligned title
- Added **double-tap** task editing, **date banner** with ordinal suffix, **past week read-only** mode
- Fixed **Monday-based week** calculation bug (Sunday mapping to wrong week)
- Fixed **future week sync** — recurring tasks and categories now sync on navigation
- Fixed **category expansion** on week navigation (auto-expand all categories)
- Swapped swipe directions (left=delete, right=modes)
- Removed edit button border, added "Today" label to current week

**In progress**: User was about to share Figma screenshots for further UI refinement. All changes build successfully but are uncommitted.

**User's likely next steps**: Figma-driven UI refinement, commit/push changes, potentially more onboarding/layout tweaks based on visual review.
