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

**Tasquel** — Weekly checklist iOS app (iPhone + iPad), SwiftUI, iOS 26.2 deployment target.
Bundle ID: `com.symonym.Tasquel`
Repo: https://github.com/SymonymD/Tasquel
Simulator: Use an available iPhone 17 Pro runtime; simulator IDs vary by machine/session.
Figma File Key: `m5BPKMcJmfaMXsMmpAFzjF`

## Current State (as of 2026-10-04)

The current working tree includes the changes below, but they have not been committed. The last full simulator test run passed (21 test definitions / 24 executions, 0 failures). The updated looping welcome animation builds successfully, and its three focused geometry tests pass.

### Files

| File | Lines | Purpose |
|------|-------|---------|
| `Tasquel/TasquelApp.swift` | ~15 | `@main` App struct, unchanged from template |
| `Tasquel/Models.swift` | 206 | Data models and enums |
| `Tasquel/ChecklistStore.swift` | 539 | `@Observable` store, persistence, CRUD, rollover, validation, and load-error safeguards |
| `Tasquel/Theme.swift` | 140 | Theme functions and `ScanlineOverlay` |
| `Tasquel/ContentView.swift` | 693 | Root view, week grid/layout state, navigation, and bottom bar |
| `Tasquel/CategoryCard.swift` | 294 | Collapsed/expanded category cards and deletion confirmations |
| `Tasquel/TaskRowCard.swift` | 563 | Task, subtask, and add-task rows; goal editing and confirmations |
| `Tasquel/AddCategorySheet.swift` | 188 | Add Category and Date Picker sheets |
| `Tasquel/SettingsSheet.swift` | 249 | Standard and retro settings layouts |
| `Tasquel/HelpSheet.swift` | 137 | Help sheet and rows |
| `Tasquel/RemoveCategorySheet.swift` | 52 | Legacy removal sheet (expanded card no longer presents it) |
| `Tasquel/FeedbackSheet.swift` | 219 | Feedback UI/webhook code; currently not linked from Settings |
| `Tasquel/OnboardingSheet.swift` | 484 | Onboarding, looping clock-to-check animation, and its dedicated Xcode preview |
| `TasquelTests/TasquelTests.swift` | 353 | Rollover, safety, and clock-shape tests |
| `TasquelUITests/TasquelUITests.swift` | 111 | UI journey and category expansion tests |
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
   - Inline mode icons per task (carry-over, repeating, one-time + delete) — shown IN edit mode
   - Task type icons (checkbox/goal) — shown when NOT in edit mode
   - Sub-task management (add, edit, delete, complete)
   - Category removal via context menu (save, remove this week, delete entirely)
7. **Saved category templates**: Categories saved for reuse. Add Category sheet shows "Create New" first, then saved.
8. **Appearance system**: System / Light / Dark / Retro in Settings — fully reactive theme system
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
    - Inline progress section: ProgressView bar, fraction display, "Add progress" input — always visible (not behind a tap)
    - Inline goal setup: Target/Unit text fields when no target set (not a popup)
    - Auto-completion when progress >= target
    - Task type picker via inline icons and context menu
14. **Username**: Persisted via UserDefaults, editable in Settings, collected during onboarding
15. **Double-tap editing**: Double-tap task title to edit inline
16. **Date banner**: Shows today's date with ordinal suffix (e.g. "Monday, Feb 16th"), "Go to Today" button on non-current weeks
17. **Past week read-only**: Past weeks hide AddTaskRow, AddCategory, and edit button
18. **Future week full editing**: Same capabilities as current week — add/remove tasks and categories
19. **Future week sync**: `syncFutureWeek(for:)` ensures all categories and recurring tasks from the source week appear in future weeks.
20. **Card-based grid UI** (Figma redesign):
    - Replaced `NavigationStack` + `List` with `ZStack` + `ScrollView` + `LazyVGrid`
    - Collapsed cards in 2-column grid with SF Symbol, name, pie chart completion icon, completed count, task dot previews, expand arrow (↗)
    - Multiple categories can remain expanded simultaneously (see item 42)
    - Expanded card shows all tasks with circles (filled green = done, empty = not), subtasks, add-task field, edit/checkmark toggle
    - Edit mode shows inline HStack of mode icons (carry-over, repeating, one-time) + red trash per task
    - Dashed-border "Add Category" card appears in grid during edit mode
    - Cards use theme-adaptive backgrounds with subtle shadow
    - Bottom bar: settings gear (left), date with "Go to Today" (center), edit pencil/checkmark (right)
    - Removed swipe actions (not supported outside List), replaced with inline edit-mode icons + context menus
21. **Pie chart completion icon**: `chart.pie.fill` on each card — green (all complete), orange (partial), red (none complete)
22. **Always-visible subtask creation**: "+" add sub-task field always visible below checkbox tasks (not gated behind existing subtasks)
23. **Auto-complete parent from subtasks**: When all subtasks are completed, parent task auto-completes. When a subtask is unchecked, parent auto-uncompletes.
24. **Dual inline icon system**: Task type icons (checkbox/goal) shown when NOT in edit mode; task mode icons (carry-over/repeating/one-time + delete) shown IN edit mode. Both always show both options with active one highlighted blue.
25. **Theme system** (function-based, fully reactive):
    - `Theme` enum with static functions taking `AppearanceMode` parameter — SwiftUI observation-compatible
    - System/Light: adaptive UIKit colors (`Color(.label)`, `Color(.systemBackground)`, etc.)
    - Dark: explicit white/gray/dark colors
    - Retro: terminal phosphor colors via `retroPalette()` function
    - Every view has `private var theme: AppearanceMode { store.appearanceMode }` computed property
    - Color functions: `textPrimary`, `textSecondary`, `textTertiary`, `accent`, `background`, `cardFill`, `cardBorder`, `cardShadow`, `dotComplete`, `completionAll/Some/None`
26. **Retro terminal theme**:
    - Monospaced font throughout (`.system(.body, design: .monospaced)`)
    - Terminal-style card borders (`[ CATEGORY ]`, `[ ] Task`, `[OPEN]`)
    - Cursor-blinking title with trailing underscore (`> Week of 2/16/26_`)
    - CRT-style scanline overlay on cards
    - Settings and Help sheets have dual rendering paths (standard List vs retro ScrollView with terminal-styled sections)
27. **Retro color palette**: 6 terminal phosphor colors (green, amber, blue, white, red, purple), each with 3 brightness levels (bright, dim, faint). Selectable in Settings when retro theme is active. Persisted via `settings.json`.
28. **Grid layout**: Collapsed cards form two-column rows; each expanded card takes a full-width row. The layout tracks visual order so expanding a right-hand neighbor does not trade places with an already-expanded card.
29. **Expanded card size bumps**: When expanded, font/icon sizes increase — category icon `.body` + `scaleEffect(1.1)`, title `.title3`, edit/pie icons 20pt, task title 16pt, subtask title 14pt, mode/type icons 16pt, collapse icon 20pt white `rectangle.compress.vertical`. Collapsed cards get dimmed overlay (`Color.black.opacity(0.15)`).
30. **Edit-mode category removal**: Red minus circle (`minus.circle.fill`) overlay in top-right corner of collapsed cards during edit mode. Tapping deletes the category.
31. **Add category button fills empty slot**: When category count is odd, the dashed "Add Category" card fills the empty right slot in the last row instead of creating a new row.
32. **Add category callback pattern**: AddCategorySheet uses `onAdd` closure instead of calling `store.addCategory` directly — prevents store mutation inside sheet from interfering with dismiss.
33. **Saved category duplicate feedback**: Templates already in the current week show "Added" label and are disabled in the Add Category sheet.
34. **Starter category migration**: On init, missing starters are added to both `savedCategories` and the current week (one-time migration via `didMigrateStarters_v1` UserDefaults key). Prevents missing categories on existing installs.
35. **Dark theme sheets**: Settings, Help, and AddCategory sheets match dark card theme — `.scrollContentBackground(.hidden)` + `Theme.background()` + `.listRowBackground(Theme.cardFill())`.
36. **Exit edit mode on add**: "Add to Week & Save" in AddCategorySheet exits edit mode automatically — "Save" implies done editing.
37. **Help sheet section fix**: Unrolled `ForEach` around `Section` in Help sheet to fix missing bottom corner rounding on middle sections.
38. **Theme-aware collapse icon**: Collapse button in expanded cards uses `.white` in dark/retro themes, `Color(.secondaryLabel)` in light.
39. **Expanded card depth effect**: Expanded card shadow `radius: 10, x: 2, y: 2`. Collapsed cards when dimmed get reduced shadow `radius: 2, y: 1` and lighter dimming `opacity(0.08)`. Creates subtle forward/back depth illusion.
40. **Expand/collapse animation**: `.easeOut(duration: 0.7)` for smooth card transitions.
41. **Looping welcome animation**: `CarryOverAnimation` draws an analog clock whose two hands begin at noon, sweep to 10:10, then become a standard checkmark while the clock face becomes a task circle. The checkmark bend is exactly at the circle center; its short arm uses a 315° hand angle and the longer arm uses 405°. After a one-second hold, the illustration fades out, resets invisibly, and loops. Reduce Motion still shows the finished state without movement. A dedicated `#Preview("Welcome animation")` makes the loop directly inspectable in Xcode, and `ClockHandsShape` geometry has focused unit tests.
42. **Independent category expansion across weeks**: `expandedCategoryKeys: Set<CategoryLayoutKey>` allows multiple cards open at once. Keys use category name plus occurrence (rather than UUID, which changes on rollover), so expanded state follows matching categories when navigating between weeks. This is view state, not persistence across app relaunches. UI tests cover neighboring cards and week navigation.
43. **Audit-driven safety and UX fixes**: Unreadable week/settings JSON now shows a retryable error and is not overwritten; past-week mutations are rejected in the store; goal values must be finite and valid. Task/subtask/category deletion and destructive goal-to-checkbox changes require confirmation. Completed task titles retain normal contrast, and goal target/progress/unit can be edited after setup. Navigation and category cards have clearer accessibility labels; the bottom bar and card sizing were refined.

### UI Layout (Post-Redesign)

- **Root**: `ZStack` with `Theme.background()` adaptive background
- **Title**: "Week of M/d/yy" centered, `.title.bold()` (monospaced with cursor in retro mode)
- **Navigation capsule**: Centered `HStack` with `< calendar >` in theme-adaptive capsule
- **Content**: `ScrollView` + unified HStack rows (2 columns, 8pt spacing)
- **Expanded card**: Takes a full-width row; other expanded cards stay open. Visual ordering prevents neighbors from unexpectedly swapping positions. Bumped font/icon sizes (title `.title3`, icons 16–20pt)
- **Bottom bar**: `HStack` — gear circle (left), date text (center), pencil/checkmark circle (right)
- **Edit-done button**: Green-tinted `checkmark` with green background + ring when active
- **Add Category**: Dashed-border card in grid during edit mode
- **Card backgrounds**: Theme-adaptive fill in `RoundedRectangle(cornerRadius: 16)` with soft shadow (retro uses dark bg + colored border)
- **Inline icons per task**:
  - Normal mode: checkbox + goal type icons (switch task type)
  - Edit mode: carry-over + repeating + one-time mode icons + trash (switch task mode, delete)

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
5259ced Add goal tasks, username, 4-step onboarding, floating nav, and future week sync
53ca1c3 Redesign UI to Figma card-based grid layout
e4ff1bb Add pie chart completion icon, subtask improvements, goal inline display, and dual icon system
0dca498 Add retro terminal theme with 6-color palette and reactive theme system
3174d6a Stable grid animation, onboarding carousel, and UI polish
c37a93a Fix add category, grid layout bugs, and expanded card sizing
7b0c956 Dark theme sheets, depth effects, onboarding animation, and UI polish
b802c3f Bug fixes, file split, CarryOverAnimation v3, feedback sheet, unit tests
d19b04f Resolve merge conflicts: keep upstream file split, fix repo URL
de4d5f7 Fix duplicate redeclarations, remove VIKOV.xcodeproj, add #Preview
```

The 2026-10-04 changes in the working tree are not yet committed.

## Development Workflow

- Build/test from the project directory: `xcodebuild -project Tasquel.xcodeproj -scheme Tasquel -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test`
- Use `xcrun simctl list devices available` to find a current simulator ID; the old IDs and DerivedData path below may no longer exist.
- An isolated iPhone 17 Pro motion-preview simulator used this session had ID `F9A016AE-9AA7-445B-85B5-89F7C4E6D243` (iOS 26.3). The latest looping sequence is recorded at `/private/tmp/tasquel-clock-to-check-loop.mov` (temporary file, not in repo).
- New files in `Tasquel/` are auto-discovered (`PBXFileSystemSynchronizedRootGroup`)

24. **`deleteCategoryEntirely` bug (fixed)**: Method looked up category by ID *after* calling `deleteCategory`, which removes it. The template removal never ran. Fix: capture `categoryName` before deletion. Same bug was present inline in `CategoryCard`, `ExpandedCategoryCard`, and `RemoveCategorySheet` context menus — all now route through `store.deleteCategoryEntirely`.
25. **CarryOverAnimation v3**: Replaced `DispatchQueue.main.asyncAfter` chain with `async/await` + `.task(id: loopCount)`. Benefits: (a) SwiftUI cancels the task when view disappears, preventing multiple loops from stacking; (b) clean `guard !Task.isCancelled` gates prevent stale state updates; (c) added fade-out before loop restart so the instant state reset is invisible. Also fixed ring `rotationEffect` to always start at −90° (12 o'clock).
26. **File split**: ContentView.swift was 2,270 lines. Split into 9 focused files (Theme.swift, CategoryCard.swift, TaskRowCard.swift, AddCategorySheet.swift, SettingsSheet.swift, HelpSheet.swift, RemoveCategorySheet.swift, OnboardingSheet.swift, FeedbackSheet.swift). ContentView.swift is now 372 lines. Works automatically via `PBXFileSystemSynchronizedRootGroup`.
27. **FeedbackSheet**: Standard + retro dual-layout sheet. POSTs `{"name": ..., "feedback": ...}` JSON to a Google Apps Script webhook URL. Shows inline status (sending / success / failure). Auto-dismisses 1.5s after success. Webhook URL is a constant in FeedbackSheet.swift — replace with deployed Apps Script URL before shipping. The Settings entry point is currently removed, so the sheet is not reachable from the app UI.

## Key Decisions & Gotchas

1. **Simulator name**: `iPhone 16` doesn't exist in Xcode 26.2 — use `iPhone 17 Pro`
2. **Init order in ChecklistStore**: Must seed `savedCategories` BEFORE `ensureWeekExists(for:)`, otherwise first week gets 0 categories
3. **No simctl tap**: `xcrun simctl io input tap` doesn't exist — can't programmatically interact with UI, only screenshot
4. **`.quaternary` type mismatch**: Can't use `.quaternary` in ternary with `Color` — use `Color.secondary` instead
5. **Settings JSON UUIDs**: When manually editing `settings.json` for testing, UUIDs must be valid format (e.g., `A1B2C3D4-E5F6-7890-ABCD-EF1234567890`), not short strings
6. **GitHub auth**: Uses `gh` CLI (installed via Homebrew), HTTPS protocol, account `SymonymD`
7. **Monday-based weeks**: Must set `calendar.firstWeekday = 2` in `mondayOfWeek(containing:)` — US locale defaults to Sunday which caused Sunday dates to map to the wrong week
8. **Future week stale data**: `ensureWeekExists` only creates a week once. If you navigate to a future week, go back, add recurring tasks, then navigate forward again, those tasks won't appear unless explicitly synced. Fixed with `syncFutureWeek(for:)` which runs on every future-week navigation.
9. **Category UUIDs differ per week**: Each week gets fresh category UUIDs from rollover. The current UI instead tracks expansion by category name plus occurrence, allowing multiple open cards and retaining their open state when navigating between weeks. This state is in memory only.
10. **SourceKit false positives**: Cross-file resolution errors like `Cannot find 'Category' in scope` or `Category (aka 'OpaquePointer')` are transient SourceKit issues — all builds succeed. Ignore these diagnostics.
11. **Swipe actions require List**: `swipeActions` modifier only works inside `List`. After migrating to `ScrollView` + `LazyVGrid`, swipe actions were replaced with inline edit-mode icons and context menus.
12. **Rollover resets completed tasks on test data**: When writing test data directly to `checklist.json`, the `ensureWeekExists` init logic may strip completed carry-over tasks and one-time tasks. Completed tasks show as red dots because rollover reset them. This is correct app behavior — only affects manual test data injection.
13. **Inline icon context matters**: Task type icons (checkbox/goal) show when NOT in edit mode so users can always switch type. Task mode icons (carry-over/repeating/one-time) show IN edit mode. Initially had this reversed — user corrected that mode changes are an "editing" action while type switching should be always available.
14. **Theme static var not observable**: `nonisolated(unsafe) static var mode` on Theme couldn't be tracked by SwiftUI observation. Fixed by converting all Theme properties to functions taking `AppearanceMode` parameter, with each view reading `store.appearanceMode` via computed property.
15. **`.buttonStyle(.plain)` suppresses taps in List**: Appearance toggle buttons in Settings became untappable. Fixed by removing `.buttonStyle(.plain)` from buttons inside List rows.
16. **Sheets don't inherit preferredColorScheme**: Sheets have their own window and need `.preferredColorScheme()` applied directly — won't inherit from parent view hierarchy.
17. **awk bulk Theme replacement pitfall**: `Theme.cardBorder` was a substring of `Theme.cardBorderWidth`, causing awk to produce `Theme.cardBorder(theme)Width`. Must handle longer names first or use exact-match patterns.
18. **`nil == nil` in optional comparisons**: `row.right?.id == expandedCategoryID` evaluates to `true` when both are `nil`. This hid category cards in odd-numbered rows. Fix: guard with `expandedCategoryID != nil &&` before the comparison.
19. **Multiple buttons in List rows fire simultaneously**: Two buttons (Cancel + Add to Week & Save) in the same `HStack` inside a `List` row. Without `.buttonStyle(.borderless)`, SwiftUI treats the entire row as a single tap target and fires ALL button actions. Cancel would reset `isCreatingNew`, then `createNew` would see an empty name and bail. Fix: add `.buttonStyle(.borderless)` to each button.
20. **Store mutations inside sheets break dismiss**: Calling `store.addCategory` (which mutates `@Observable` state) inside a sheet triggers parent view re-render, which can swallow the subsequent `dismiss()`. Fix: use callback pattern — sheet fires `onAdd` closure, parent handles the mutation.
21. **`print()` invisible in simctl logs**: `print()` output doesn't appear in `log show` for simctl-launched apps. Use `os.Logger` for debugging.
22. **`let` bindings in computed `some View` properties**: Causes "no return statements" compile error. Fix: extract to separate computed property helpers or functions.
23. **`Section` inside `ForEach` breaks List corner rounding**: SwiftUI loses section boundary info. Fix: unroll sections as direct List children (e.g. `helpSection(0)` through `helpSection(5)`).
24. **Welcome animation visibility in Xcode (fixed)**: The app-level welcome sheet still appears only while `hasSeenWelcome == false`, but `OnboardingSheet.swift` now has a dedicated `#Preview("Welcome animation")`. Use that preview to inspect the continuously looping motion without resetting onboarding or user data.
25. **Data-load failure safety**: Do not allow default state to overwrite unreadable `checklist.json` or `settings.json`. `ChecklistStore` now exposes `persistenceError`, blocks saves after decode failure, and offers retry from the root view.
26. **Test isolation (fixed 2026-10-05)**: `ChecklistStore.init(directory:defaults:)` is injectable. Unit tests use `makeIsolatedStore()` (temp directory + throwaway `UserDefaults` suite), so they no longer read or overwrite the simulator's real `checklist.json`/`settings.json` and run safely in parallel. All 17 unit tests pass. `retryLoadingData()` now runs the same setup as launch (starter seeding, current week, migration).

## Figma Reference

- **File key**: `m5BPKMcJmfaMXsMmpAFzjF`
- **State_Default** (node `91:926`): 2-column grid of dark rounded cards, title centered, nav capsule, bottom bar
- **State_Category-Expand** (node `92:90`): Expanded category card full-width with task list, remaining cards in grid below
- **State_Category_Tasks_Edit** (node `93:370`): Edit mode with inline mode icons + delete on each task row

## Planned / Not Yet Implemented

- **Calendar integration (paid upgrade)**: Pull user's calendar events into Tasquel. Key design decisions still open: (1) events as tasks vs read-only reference vs user choice per-category, (2) payment model (one-time vs subscription), (3) calendar source — Apple EventKit recommended since it covers all calendars synced to device (iCloud, Google, Exchange) without extra OAuth. Existing Settings already has a "Coming Soon" toggle placeholder.
- **Feedback webhook setup**: `FeedbackSheet.swift` is built. Need to: (1) create Google Apps Script project, (2) deploy as Web App, (3) replace `webhookURL` constant with deployed URL. Apps Script template is in the comment header of `FeedbackSheet.swift`.
- **Feedback entry point**: The Send Feedback button was removed from Settings during this session; `FeedbackSheet` remains in the project but is not currently reachable. Decide whether to reconnect it after the webhook is configured.
- **Expansion persistence on relaunch**: Expanded cards retain state while switching weeks in one session, but the state is not stored on disk across launches.
- iPad-specific layout optimizations
- Data export/import

## Last Session Summary (2026-10-04)

**What was done**: Audited the SwiftUI architecture and UX flow, then implemented the safety and interaction fixes listed above. Category cards can now expand independently, keep their visual order, and retain open state when changing weeks. The welcome illustration was redesigned as a two-handed clock that sweeps from noon to 10:10 and morphs into a checkmark. It now loops with a clean fade/reset, uses a steeper conventional checkmark centered in the circle, and has a dedicated replayable Xcode preview. Added unit/UI coverage, built and exercised the app in the simulator, and recorded the final loop.

**In progress / next**: Review the final loop with the user and adjust timing/geometry if requested. The implementation and tests are uncommitted. Other open work: feedback webhook/entry point, calendar integration, iPad layout, expansion persistence across relaunch, and data export/import.
