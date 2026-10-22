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

**Tasquel** — Weekly checklist iOS app (iPhone + iPad), SwiftUI, iOS 26.0 deployment target (was 26.2 until 2026-10-21).
Bundle ID: `com.symonym.Tasquel`
Repo: https://github.com/SymonymD/Tasquel
Simulator: Use an available iPhone 17 Pro runtime; simulator IDs vary by machine/session.
Figma File Key: `m5BPKMcJmfaMXsMmpAFzjF`

## Current State (as of 2026-10-21)

Everything is merged to `main` and pushed, including the branch `audit-fixes-2026-10-19` (audit fixes, accessibility, app icon, follow-ups). ~9,100 lines of Swift across app and tests; 94 unit tests (Swift Testing) and 11 UI tests (`TasquelUITests`, `CalendarUITests`, `GoalUITests`). The user's iPhone 16 Pro Max runs the branch (install via `devicectl`, see memory). The app icon is an Icon Composer file, `Tasquel/AppIcon.icon` (the empty `AppIcon.appiconset` was removed). Old merged branches (`audit-fixes-and-test-isolation`, `calendar-integration-and-card-rework`, `final-sync-and-gregorian`, `final-sync-legacy-weeks`) still exist locally and on GitHub; delete them only when the user says so.

There are **two clones on the T7**: this one (`/Volumes/T7/Design/JB Portfolio/SYMONYM/Tasquel/Tasquel`, where work happens) and `/Volumes/T7/Design/SYMONYM/Tasquel/Tasquel` (fast-forwarded to `a6286ec` on 2026-10-19; it also holds an old stash from `7b0c956`). Pull before working in the second one.

### Files

| File | Lines | Purpose |
|------|-------|---------|
| `Tasquel/TasquelApp.swift` | 22 | `@main` App struct; owns the one `ChecklistStore` and `CalendarService` (shared by iPad windows) |
| `Tasquel/Models.swift` | 469 | Data models and enums, lenient task decoding, `DayKey`, `GoalNumber` |
| `Tasquel/ChecklistStore.swift` | 1103 | `@Observable` store: persistence, rollover, future-week previews and sync, validation, load/save error handling |
| `Tasquel/Theme.swift` | 166 | Theme colors/fonts (retro palette with contrast-safe text colors) and `ScanlineOverlay` |
| `Tasquel/ContentView.swift` | 1178 | Root view: header, week paging, card grid (order, expansion, drag), bottom bar, events panel, day changes, error screens |
| `Tasquel/CategoryCard.swift` | 450 | `CategoryGridCard` (one card for both states), completion ring, collapsed/expanded content, `AnimatableFont` |
| `Tasquel/CategoryGridLayout.swift` | 98 | Custom `Layout`: two-column grid, full-width rows for expanded cards (and every card at accessibility text sizes) |
| `Tasquel/TaskRowCard.swift` | 909 | Task, sub-task and add-task rows, goal editing, expanded-card sizing, `touchTarget()` |
| `Tasquel/TaskOptionsPicker.swift` | 165 | Type/mode picker and `OptionButtonLabel` |
| `Tasquel/CategorySymbols.swift` | 38 | Category icons with names, `CategorySymbolMenu` |
| `Tasquel/SavedCategoriesView.swift` | 152 | Settings ▸ Saved Categories editor |
| `Tasquel/AddCategorySheet.swift` | 229 | Add Category and Date Picker sheets |
| `Tasquel/SettingsSheet.swift` | 335 | Standard and retro settings layouts, `AppInfo` |
| `Tasquel/HelpSheet.swift` | 137 | Help guide |
| `Tasquel/OnboardingSheet.swift` | 340 | Onboarding flow |
| `Tasquel/CalendarService.swift` | 314 | EventKit/fake providers, week event cache, `FeatureAccess` |
| `Tasquel/CalendarSettings.swift` | 141 | Calendar settings rows and picker |
| `Tasquel/CalendarEventsPanel.swift` | 155 | The week's events in the bottom bar |
| `Tasquel/WeekCarryOverAnimation.swift` | 253 | Welcome carry-over animation (`KeyframeAnimator`) |
| `Tasquel/AppIcon.icon` | — | Icon Composer app icon (glass layers) |
| `TasquelTests/TasquelTests.swift` | 1778 | 94 unit tests |
| `TasquelUITests/*.swift` | 556 | 11 UI tests (journey, calendar panel, goals) |
| `CLAUDE.md` / `AGENTS.md` | 110 | Architecture reference for Claude Code / Codex (keep in sync) |

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
28. **Grid layout**: Collapsed cards form two-column rows; each expanded card takes a full-width row. Expanding the right-hand card of a row moves it into its left neighbor's slot (via `categoryDisplayOrder`) so it opens in place. Implemented by `CategoryGridLayout` since 2026-10-05 (see item 44).
29. **Expanded card size bumps**: When expanded, header sizes grow — title 15→20pt, pie chart 17→20pt, "Completed" 12→15pt (all `@ScaledMetric`, animated via `AnimatableFont`); name is semibold in both states. Task title 16pt, subtask title 14pt, mode/type icons 16pt, collapse icon 20pt `rectangle.compress.vertical`. (The old dimmed overlay on neighbor cards is gone.)
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
40. **Expand/collapse animation**: One `ContentView.cardSpring` (`.spring(duration: 0.45, bounce: 0.12)`) for expand, collapse, and neighbor reflow (was `.easeOut(duration: 0.7)`).
41. **Welcome animation (2026-10-05)**: `WeekCarryOverAnimation` replaced the clock-to-checkmark `CarryOverAnimation`/`ClockHandsShape`. A "This week" card checks off two tasks; the third turns orange with the carry-over arrow, lifts while the week slides away and "Next week" slides in beneath it, then lands and checks off green. Built as one `KeyframeAnimator` timeline (6s loop, every track the same length); Reduce Motion shows the finished frame (`Values.finished`). Cards use system colors for dark mode. Unit tests cover loop length and that the resting frame matches the Reduce Motion frame.
42. **Independent category expansion across weeks**: `expandedCategoryKeys: Set<CategoryLayoutKey>` allows multiple cards open at once. Keys use category name plus occurrence (rather than UUID, which changes on rollover), so expanded state follows matching categories when navigating between weeks. This is view state, not persistence across app relaunches. UI tests cover neighboring cards and week navigation.
43. **Audit-driven safety and UX fixes**: Unreadable week/settings JSON now shows a retryable error and is not overwritten; past-week mutations are rejected in the store; goal values must be finite and valid. Task/subtask/category deletion and destructive goal-to-checkbox changes require confirmation. Completed task titles retain normal contrast, and goal target/progress/unit can be edited after setup. Navigation and category cards have clearer accessibility labels; the bottom bar and card sizing were refined.

44. **Category card animation rework (2026-10-05, uncommitted)**:
    - `CategoryGridLayout` (custom `Layout`) places every card directly; `.categoryGridFullWidth(_:)` marks expanded cards. Replaces the old row-of-HStacks structure, so cards keep a stable identity and SwiftUI animates position and size: the tapped card grows in place and neighbors slide instead of popping. Row rule is unit-tested (`CategoryGridLayout.rows(fullWidth:)`).
    - Cards are keyed by `CategoryLayoutKey` (name + occurrence), so the same card view persists across weeks.
    - `CategoryGridCard` is one card for both states. Header (icon, name, edit button, pie chart) and "Completed" line are shared and resize smoothly; the pie chart rides the card's trailing edge. The edit button sits in space that opens beside the pie chart, so it slides out from behind it.
    - Below the header, collapsed (task dots) and expanded (task list, add task, collapse button) content are both always mounted and cross-faded via `CardContentCrossFade`; only the visible one takes space.
    - `.geometryGroup()` on the card keeps contents moving with the card's animated frame. `zIndex` keeps the most recently toggled card above sliding neighbors.
    - Removed unused `BookingCalendarAnimation` (~230 lines) from `ContentView.swift`.
45. **Repo hygiene (2026-10-05)**: `.gitignore` added (AppleDouble `._*` files from the exFAT T7 drive, `.DS_Store`, Xcode user data, `.superpowers/`); previously tracked `._*` files untracked. `AGENTS.md` mirrors `CLAUDE.md` for Codex.
46. **Week swiping (2026-10-06, uncommitted)**:
    - Horizontal drag on the week grid moves it with the finger (`weekDragOffset`); release past 25% of the width or a flick past 50% (predicted end) pages to the adjacent week; shorter drags spring back. The drag axis is locked on first movement (`weekSwipeAxis`), so vertical drags only scroll. Gesture is a `simultaneousGesture` so the `ScrollView` still scrolls.
    - `changeWeek(to:)` animates the current week off-screen (0.16s ease-in), then the new week arrives from the opposite edge via an insertion-only transition (`weekArrivalOffset`, spring 0.35s). The ‹ › arrows, Go to Today, and the date picker all route through it, so the slide always matches the direction of travel. Reduce Motion uses a fade. `isChangingWeek` blocks overlapping changes.
    - The grid is `.disabled` during a horizontal swipe / week change so a swipe that starts on a card or checkbox doesn't tap it (see gotcha 36).
    - Side effects: changing weeks resets the grid's scroll position to the top (grid has `.id(week.startDate)`); a long sideways drag inside a text field could change weeks (not observed).
47. **Task row and editing changes (2026-10-10, uncommitted)**: Expanded cards draw everything 15% larger (`expandedCardScale`, `Font.expandedCard`). Task rows show a mode icon (tap for Carry Over / Repeating / One-Time; highlighted for checkbox tasks), a goal icon that toggles goal ↔ checkbox, and a trash can in edit mode. A card's own edit button edits only its tasks; the bottom-bar edit mode is for categories, collapses all cards, and blocks opening them. Deleting a category removes it from the current and future weeks (past weeks keep history) and keeps its template; `RemoveCategorySheet.swift` was removed. "This Week Only" categories (`isThisWeekOnly`) don't roll forward.
48. **Calendar integration (2026-10-10, uncommitted)**: See `docs/plans/2026-10-10-calendar-integration.md`. Settings toggle + calendar picker; a calendar toggle next to Settings expands the bottom bar to list the viewed week's events (tap opens the Calendar app at the event's date); refresh on calendar changes and foregrounding; `FeatureAccess.isCalendarUnlocked` for a future paywall. Launch arguments `-fakeCalendar` and `-isolatedData` for tests.
49. **Week start setting and header swap (2026-10-10, uncommitted)**: Settings ▸ Week Starts On (Sunday/Monday); switching moves every saved week by one day so tasks stay with their week. The header now shows today's date and the bottom bar shows "Week of …" (with Go to Today on other weeks).

50. **Task types and modes (2026-10-17/18)**: Type (Checkbox / Goal / List) and mode (One-Time / Carry Over / Repeating) are independent, picked in a two-column popover (`TaskOptionsPicker`). List tasks hold items as sub-tasks and check themselves off; repeating lists keep checked items. Goal units (quantity / time / custom) with Add Progress and an edit form with Delete.
51. **Carry-over linking**: carried copies record `carriedFrom`; deleted copies are remembered in `Week.dismissedCarryOvers`; unlinked copies from older builds are adopted by title.
52. **Cards and layout**: hold-and-drag reordering of closed cards (custom gesture, cancellation-safe), card rename/icon in card edit mode, completion ring, saved-category editor in Settings, text that follows Dynamic Type, flush bottom bar with today's date, "Week of …" in the header. No long-press menus on cards or tasks; one tap on a task name renames it.
53. **Pre-submission fixes (2026-10-19)**:
    - Future weeks are previews until edited (`previewWeek`, `editableSelectedWeekIndex()`); repeating tasks deleted from a future week are kept out via `Week.dismissedRepeating`.
    - Weeks are identified by `Week.startDay` (`DayKey`, "yyyy-MM-dd"); old files migrate on first load and are re-saved. The store takes injectable `now`/`calendar`, and past/current/future checks moved to the store.
    - Goal values capped at 999,999; `GoalNumber` parses comma decimals per locale.
    - Repeating copies link to their source (`repeatsFrom`) and follow renames and goal setup; next week keeps this week's task order.
    - A saved future week gets one final full sync when it becomes current (`Week.didFinalSync`; older files: current/past weeks are marked done on load, future ones not).
    - Week dates always use `Calendar.weekDates(in:)` (Gregorian, user's time zone), whatever the device calendar.
    - Goal editor: red Delete and green Save Goal in the picker's button style (`OptionButtonLabel`); bottom bar is flat with only a top border.
    - Unused code removed (FeedbackSheet, dead store/model functions, Xcode's template UI tests that used real simulator data).
    - Help "Upcoming Features" removed; Settings has Support/Privacy links (`AppInfo`; pages live at jbfentner.com/tasquel, /support, /privacy), bundle version, and hides the calendar section when locked; VoiceOver labels for checkboxes and goal progress; `PrivacyInfo.xcprivacy` (UserDefaults CA92.1).
54. **Audit fixes (2026-10-19, `e0a18d4`)**:
    - Copies the user changed in a future week (`ChecklistTask.isUserEdited`) are never followed, removed or adopted by sync; a followed goal target or list re-decides completion.
    - Deleting a category from a future week removes it from that week on (`Week.dismissedCategories` keeps sync from adding it back); this-week-only categories only from their week.
    - One store per app (in `TasquelApp`), so iPad windows can't overwrite each other.
    - Load-error screen has Start Fresh (`setAsideUnreadableData()` renames the bad file); task decoding is lenient; save failures show an alert (`saveError`); onboarding keeps categories that have tasks.
    - Midnight while open: `significantTimeChangeNotification` refreshes today and moves to the new week; a week that became current on screen gets its final sync before the first edit. Week-start switch on a Sunday no longer revives deleted categories.
    - Rename saved when finishing with the card checkmark / leaving edit mode; keyboard dismissed before changing week.
    - Card drag: frames kept per week, no save without a move, gesture masks instead of `if` branches (stable card identity). Events panel resets after a cancelled drag (`@GestureState`). Previews keep their IDs (`lastPreviews`). Test launch arguments only in DEBUG.
55. **Accessibility (2026-10-19, `3bb1081`)**: closed cards show done as a filled dot and not done as an outline; retro text colors keep 4.5:1 on a card (red/purple lightened, `retroRed`, black text on retro pills; `glow` only for the shadow); `touchTarget()` gives small controls a 44pt hit area without changing layout (and fixed the task checkbox's off-center area); category names wrap to two lines; every card full width at accessibility text sizes; Reduce Motion turns off the card spring and sliding transitions.
56. **App icon (2026-10-21, `42b12bf`)**: the user's Icon Composer file `AppIcon.icon` replaces the empty asset catalog icon; `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` already matched.
57. **Follow-ups (2026-10-21)**: bottom-bar date is localized (`ContentView.dateString`; ordinal suffix only in English when the day comes last) and shortens on narrow screens via `ViewThatFits`; `print` replaced by `os.Logger`; a preview added for a refused edit is dropped on the next navigation (`unsavedPreviewID`); deleted repeating tasks are remembered by source ID, so a new task with the same name still repeats (titles only for copies without `repeatsFrom`); deployment target 26.0.

### UI Layout (current)

- **Header**: "Week of M/d/yy" (monospaced with cursor in retro), expand/collapse-all button, week capsule `‹ calendar ›`
- **Content**: `ScrollView` + `CategoryGridLayout` (2 columns, 8pt spacing; one column at accessibility text sizes). Closed cards: icon, name, completion ring, "Completed" line, task dots, ↗. Hold and drag a closed card to reorder. Expanded cards take a full row; several can be open.
- **Card edit button** (beside the ring, open cards only): edits that card's tasks, name and icon.
- **Bottom bar**: flat translucent bar with a top border — Settings and calendar toggle (left), today's date / Go to Today (center), grid-icon Edit (right; category management: add card, remove badges, all cards closed). Morphs into a keyboard Done button while typing.
- **Task rows**: checkbox (or goal ring), title (tap to rename), add sub-task, type/mode capsule (opens the picker), trash in edit mode.

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
50ee264 Audit fixes, independent card expansion, clock welcome animation, test isolation
800ce9b Replace clock welcome animation with week carry-over animation
0bcc736 Calendar integration, card animation rework, week swiping, week start setting
0ad0c5b Docs: drop resolved cleanup items (booking.lottie removed, RemoveCategorySheet deleted)
7e8aee3 Goal units, Add Progress flow, and a keyboard Done button
2e7e629 Inline goal unit menu; bottom bar morphs into a keyboard Done button
c7ca019 Auto-add on task option pick, drop One-Time, keep new-task options clear of Done
e092b2a One task type menu: Checkbox, Carry Over, Repeating, Goal
c89b559 Give each task type its own icon color
34c33a6 Add List task type
b367b68 Carry over tasks into weeks that already exist
6e25302 Say item instead of sub-task in lists
65f86b3 Adopt carry-over copies made before they linked to their source
9a13a32 Fix Help crash: render sections from the array
99d1f09 Type/mode picker, text size, card rename and reorder, saved category editor
d4016f8 Drop card long-press menu, grid icon for edit mode, repeating lists keep checks
e72f8fa Drag closed cards to reorder without edit mode; fix stuck dimmed card
25287f7 Smoother card dragging with a custom hold-and-drag gesture
827c592 Keep a held card following the finger; drop it if the gesture is cancelled
f767564 Don't change week when a lifted card is dragged sideways
8f358a6 Edit mode: no adding, sub-task delete on the left
54bb28f Flush bottom bar with today's date, week title in header, one-tap title editing
53420ec Goal fields: larger tap area, amount selected on focus
d19a09e One tap on a task name renames it, outside edit mode too
ee1c1b0 Drop task long-press menu, Delete beside Save Goal, reset cancelled swipes and drags
c30bc45 Future weeks stay previews until edited
4740a81 Identify weeks by calendar date, not by moment
f5e3e60 Test that removing every starter in onboarding keeps them removed
5501006 Goal input: cap values, read comma decimals
cc1c37b Help and onboarding text for App Review
059ae61 Settings: Support and Privacy links, real version, no Coming Soon
c1b9b27 VoiceOver: checkbox labels say the action, goals read progress
10f8a35 Card grid rework, week swiping, calendar events, week start setting
c563987 Fix Swift 6 concurrency warnings
9878d5f Declare no non-exempt encryption; note future upgrade ideas
ebafc52 Add privacy manifest, ignore .claude/
a84d552 Docs: week storage, future-week previews, starter seeding
865f025 Repeating tasks follow their source; next week keeps this week's order
cae1a44 Goal editor: red Delete, green Save Goal
5bf3a59 Goal editor: Delete and Save Goal as equal-width tinted buttons
9ff039c Bottom bar: flat with only a top border
57b6464 Goal editor buttons match the type/mode picker's buttons
ed79dda Support and Privacy URLs confirmed live
66064f0 Remove unused code
8e9982e Merge main into calendar-integration-and-card-rework
031a91d Final sync when a saved week becomes current; Gregorian week dates
a6286ec Final sync: leave weeks saved before the flag alone unless still future
1a5e23d Update AI dev recap
e0a18d4 Audit fixes: keep edits to future copies, scope category deletion, safer loading
3bb1081 Accessibility: shape-coded dots, retro contrast, 44pt tap areas, Reduce Motion
42b12bf App icon (Icon Composer), replacing the empty asset catalog icon
```

## Development Workflow

- Build/test from the project directory: `xcodebuild -project Tasquel.xcodeproj -scheme Tasquel -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test`
- Use `xcrun simctl list devices available` to find a current simulator ID; the old IDs and DerivedData path below may no longer exist.
- **Checking motion without watching it**: record the simulator with `xcrun simctl io <id> recordVideo` while a temporary UI test drives the taps (build with `build-for-testing` first, then `test-without-building` so the video is short), then extract frames with `AVAssetImageGenerator` in a small Swift script (`ffmpeg` is not installed). For `KeyframeAnimator` views, `KeyframeTimeline(...).value(time:)` renders exact frames without a simulator. Make temporary UI tests assert outcomes (e.g. the card actually collapsed), not just tap. Delete them afterwards.
- **Fresh-install checks** (e.g. onboarding): `xcrun simctl clone` the simulator, uninstall the app on the clone, test there, then delete the clone — never wipe the user's simulator data.
- **Ask the user before running simulator tests/recordings** — they collide with Xcode previews (gotcha 33). Use the iPhone 17 Pro simulator (`6F2B8302-…`), not the iPhone 17 Pro Max the user runs the app on (`5CF3C145-…`).
- New files in `Tasquel/` are auto-discovered (`PBXFileSystemSynchronizedRootGroup`)

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
24. **Welcome animation visibility in Xcode**: The app-level welcome sheet appears only while `hasSeenWelcome == false`. Use `#Preview("Week carry-over")` in `WeekCarryOverAnimation.swift`, or `#Preview("Onboarding")` in `OnboardingSheet.swift` (Live mode to tap through), without resetting user data.
25. **Data-load failure safety**: Do not allow default state to overwrite unreadable `checklist.json` or `settings.json`. `ChecklistStore` now exposes `persistenceError`, blocks saves after decode failure, and offers retry from the root view.
26. **Test isolation (fixed 2026-10-05)**: `ChecklistStore.init(directory:defaults:)` is injectable. Unit tests use `makeIsolatedStore()` (temp directory + throwaway `UserDefaults` suite), so they no longer read or overwrite the simulator's real `checklist.json`/`settings.json` and run safely in parallel. Tests that build a store must use `makeIsolatedStore()`. `retryLoadingData()` now runs the same setup as launch (starter seeding, current week, migration).
27. **Layout animation needs stable identity**: Cards nested in per-row `HStack`s with position-keyed rows were treated as new views when they changed rows, so they popped instead of sliding. A custom `Layout` with every card as a direct subview fixes this.
28. **Inserted views appear at their final position**: A view inserted mid-animation (e.g. via `if`) is placed at its end position while its container is still moving, so it looks detached. Keep both versions mounted and toggle opacity/space instead (`CardContentCrossFade`), or anchor new elements to something that already moves (the edit button is an overlay on the pie chart).
29. **`.geometryGroup()`**: Without it, children of an animating container interpolate their own positions and can run ahead of it (the "Completed" line left the card's edge). `.geometryGroup()` on the card makes contents animate within its frame.
30. **Named font styles don't animate**: `.subheadline` → `.title3` jumps. Animate the point size instead (`AnimatableFont` modifier with `animatableData`), sized with `@ScaledMetric` for Dynamic Type. Weight can't interpolate, so keep it constant.
31. **Toggling `accessibilityHidden` corrupts frames**: Switching `.accessibilityHidden(isHidden)` on a container made the collapse button report the whole content area as its frame, so taps (and VoiceOver) missed it and collapsing broke. Keep `accessibilityHidden` constant on inner content; handle visibility at the card level.
32. **Removal transitions keep their layout space**: A view leaving via `.opacity` still occupies space until the transition finishes, holding a collapsing card at its old size. Use a transition/modifier that drops the view's height immediately while it fades.
33. **Xcode previews break if the preview simulator is touched from the CLI** (still failing as of 2026-10-07; Xcode had been running for 5+ days without the recommended restart): After heavy `xcodebuild`/`simctl` work, a preview showed "Failed to launch"; shutting down the preview device set (`xcrun simctl --set previews shutdown all`) got it loading, but the canvas then ignored taps. The preview app itself was healthy (main thread idle), so the canvas's input connection was stale. Recommended fix: quit and reopen Xcode (not yet confirmed by the user). Avoid simulator work while the user is using previews.
34. **"A build only device cannot be used to run this target"**: Xcode's run destination was "Any iOS Device (arm64)". Pick an iOS Simulator in the toolbar's destination menu.
35. **`LayoutValueKey` and default MainActor isolation**: The key type must be `nonisolated` or the build warns (an error in Swift 6 mode) because `Layout` reads it from a nonisolated context.
36. **`allowsHitTesting(false)` doesn't cancel a touch in progress**: When content moves with the finger, a swipe that starts on a button ends "inside" it and fires the button. Disabling hit testing mid-drag didn't stop it; `.disabled(...)` did, because a button checks `isEnabled` when the touch ends. No visible dimming on the plain-styled buttons.
37. **Removal transitions use stale state; transactions are per property** (known SwiftUI behavior, designed around rather than reproduced here): A removed view animates with the transition from its last render, so a direction flag set in the same update as the change is ignored for removal (insertion reads the new state). Setting the same property twice in one update ("jump, then animate back") coalesces into one animation from the old value. Work-around used for week paging: different properties for out/in, outgoing via an offset animation, incoming via an insertion transition, and the snap-back in a `disablesAnimations` transaction.
38. **Running on the user's iPhone (2026-10-07, unresolved)**: Their iPhone 16 Pro Max (iOS 26.5.2, Developer Mode on) is paired but `devicectl` shows it `unavailable`, with no connection since 2026-03-24, so it doesn't appear as a run destination. The Mac is on the 10.0.0.x LAN via Ethernet and Wi-Fi. Fix: connect once by cable, then enable "Connect via network" in Window ▸ Devices and Simulators. Xcode is 26.2 (older than the phone's iOS 26.5) and may need updating if it can't prepare the device. Check with `xcrun devicectl list devices`.
39. **`.disabled` cancels gestures attached inside it**: The events panel disables its event buttons while being dragged (so a drag can't open an event). With the swipe-down gesture attached inside the disabled subtree, the drag cancelled itself as soon as it started. Attach the gesture outside `.disabled`.
40. **A vertical `ScrollView` swallows vertical drags even when its content fits**, so a parent swipe-down gesture never fires. The events panel only uses a `ScrollView` when the list is taller than its maximum height. (XCUITest's `swipeDown()` on a small element also drags only a short distance; use `press(forDuration:thenDragTo:withVelocity:)`.)
41. **Peeking saved stale future weeks (fixed 2026-10-19)**: navigating to a future week used to save it, freezing its carry-overs. Now only an edit saves a future week. When adding a store mutation, start it with `editableSelectedWeekIndex()`, never `weeks.firstIndex(where: selectedWeek.id)`, or edits to a previewed week are lost.
42. **Weeks as moments broke across time zones (fixed 2026-10-19)**: compare `startDay`, never `startDate`. `Week.startDate` uses `Calendar.current`; store code should use its injected `calendar`.
43. **Swift Testing runs tests in parallel**: don't use a global clock or `NSTimeZone.default`; pass a `TestClock` to `makeIsolatedStore(clock:)`.
44. **SwiftUI `DragGesture.onEnded` isn't called when iOS cancels the touch**: track gesture-driven state with `@GestureState` and react to it resetting (card drag, week swipe), or the state sticks (a frozen grid).
45. **New stored flags must say what old data means (2026-10-19)**: `didFinalSync` was first read as "nil = needs a final sync", so the user's existing current week re-synced on launch and got back a repeating task they had renamed. Fixed by filling in the flag on load from what the week is now (current/past → done, future → pending). When adding a flag, decide the meaning of "missing" explicitly, and test with a file from the old format (`FinalSyncTests.legacyWeeks` builds one).
46. **Back up the phone's data before installing a build that migrates or syncs it**: `devicectl device copy from … --source Documents/checklist.json` (and `settings.json`) to the scratchpad, then compare weeks/tasks after the first launch. A backup is restored with `devicectl device copy to … --destination Documents/checklist.json`, then relaunch with `--terminate-existing`.
47. **Repeating tasks were matched by title**: renaming one added a second copy to a saved future week. They now link by `repeatsFrom`, and a copy also matches a source that repeats the same task (a week in between saved later). Carry-over copies use `carriedFrom`; each sync only handles copies of its own mode.
48. **AppleDouble files inside `.git` on the exFAT T7**: `._pack-*.idx` files make git print "non-monotonic index" errors. They're macOS metadata, not git data: `find .git -name "._*" -type f -delete`.
49. **Test relaunches need the same `UserDefaults`**: `makeIsolatedStore()` makes a new defaults suite each time, so the one-time starter migration runs again and re-adds deleted categories. Pass `defaults:` to reuse one across a simulated relaunch.
50. **Sync must not undo the user's own edits to a copy**: anything that changes a task in its own week sets `isUserEdited`; sync skips those copies. Exception: progress on a repeating copy doesn't set it (the copy still follows its source's target).
51. **`if`/`else` in a `ViewModifier` rebuilds the view**: switching branches gives the content a new identity (lost state, no resize animation). Keep one structure and switch gestures with `including:` masks.
52. **Small tap targets**: use `.touchTarget()` inside a button's label; it adds an invisible centered hit area without changing layout. `Rectangle().size(...)` as a content shape starts at the view's top-left corner, not its center.
53. **Refused edits on a preview**: `editableSelectedWeekIndex()` adds the preview to `weeks` before the edit is validated; `unsavedPreviewID` drops it again on the next navigation if nothing saved.
54. **Icon Composer icons**: an `.icon` file in the synced `Tasquel/` folder is picked up automatically; its name must match `ASSETCATALOG_COMPILER_APPICON_NAME`, and there must be no `AppIcon.appiconset` with the same name.


### Historical notes (files since removed or rewritten)

H1. **`deleteCategoryEntirely` bug (fixed)**: Method looked up category by ID *after* calling `deleteCategory`, which removes it. The template removal never ran. Fix: capture `categoryName` before deletion. Same bug was present inline in `CategoryCard`, `ExpandedCategoryCard`, and `RemoveCategorySheet` context menus — all now route through `store.deleteCategoryEntirely`.
H2. **CarryOverAnimation v3**: Replaced `DispatchQueue.main.asyncAfter` chain with `async/await` + `.task(id: loopCount)`. Benefits: (a) SwiftUI cancels the task when view disappears, preventing multiple loops from stacking; (b) clean `guard !Task.isCancelled` gates prevent stale state updates; (c) added fade-out before loop restart so the instant state reset is invisible. Also fixed ring `rotationEffect` to always start at −90° (12 o'clock).
H3. **File split**: ContentView.swift was 2,270 lines. Split into 9 focused files (Theme.swift, CategoryCard.swift, TaskRowCard.swift, AddCategorySheet.swift, SettingsSheet.swift, HelpSheet.swift, RemoveCategorySheet.swift, OnboardingSheet.swift, FeedbackSheet.swift). ContentView.swift is now 372 lines. Works automatically via `PBXFileSystemSynchronizedRootGroup`.
H4. **FeedbackSheet**: Standard + retro dual-layout sheet. POSTs `{"name": ..., "feedback": ...}` JSON to a Google Apps Script webhook URL. Shows inline status (sending / success / failure). Auto-dismisses 1.5s after success. Webhook URL is a constant in FeedbackSheet.swift — replace with deployed Apps Script URL before shipping. The Settings entry point is currently removed, so the sheet is not reachable from the app UI.

## Figma Reference

- **File key**: `m5BPKMcJmfaMXsMmpAFzjF`
- **State_Default** (node `91:926`): 2-column grid of dark rounded cards, title centered, nav capsule, bottom bar
- **State_Category-Expand** (node `92:90`): Expanded category card full-width with task list, remaining cards in grid below
- **State_Category_Tasks_Edit** (node `93:370`): Edit mode with inline mode icons + delete on each task row

## Planned / Not Yet Implemented

- **Layout at extreme sizes (from the 2026-10-19 audit)**: events panel in landscape; goal editor at the largest text sizes; date picker on iPhone SE; no auto-scroll while dragging a card to the screen edge.
- **Contrast left as Apple's**: dark mode's tertiary text and white on the blue Set/Add pills are below 4.5:1, matching system colors.
- **Deferred**: keyboard toolbar Done (the floating Done button exists).
- **iCloud sync** (user: later).
- **Future / paid upgrade ideas (2026-10-14, not to be built yet)**:
  - Home and lock screen widgets that tick tasks off without opening the app (likely the most wanted)
  - History and stats: streaks, goal progress over time (past weeks are already kept)
  - Reminders: a Sunday nudge to plan the week; per-task reminders
  - More themes and alternate app icons
  - Apple Watch app; Siri and Shortcuts support
  - iCloud sync between iPhone and iPad (users tend to expect it, so maybe free)
- **In-app feedback**: `FeedbackSheet.swift` (Google Apps Script webhook) was never linked and was removed on 2026-10-19; recover it from git history (before the cleanup commit) if wanted.
- **Expansion persistence on relaunch**: Expanded cards retain state while switching weeks in one session, but the state is not stored on disk across launches.
- **Card animation follow-ups**: verify with categories that have many tasks, in light and retro themes, and in edit mode; renaming a category closes its expanded card (expansion is keyed by name); consider keeping the grid's scroll position when changing weeks; consider haptic feedback on week change.
- iPad-specific layout optimizations
- Data export/import

## Last Session Summary (2026-10-19 → 2026-10-21, Claude Code)

**What was done**:
- Reviewed this recap and audited the app (data logic, views, accessibility, release readiness).
- Fixed the audit's data bugs and medium items (item 54), the accessibility items (item 55) and the follow-ups (item 57), with 16 new unit tests; lowered the deployment target to 26.0. Each build was installed on the user's iPhone; their data was backed up first and compared after the first launch (unchanged).
- The user made the app icon in Icon Composer (item 56).

**In progress / next**:
- Decide whether to delete the old merged branches (including `audit-fixes-2026-10-19`).
- Hand checks on the phone: card open/close animation, rename via checkmark, drag after a week swipe, retro red/purple shades, the new dot outlines.
- Layout items above when wanted; iCloud sync later.
