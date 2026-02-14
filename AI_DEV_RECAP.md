# AI Dev Recap — VIKOV

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

**VIKOV** — Weekly checklist iOS app (iPhone + iPad), SwiftUI, iOS 26.2, Xcode 26.2.
Bundle ID: `com.symonym.VIKOV`
Repo: https://github.com/SymonymD/Vikov.git
Simulator: iPhone 17 Pro (ID: `66BC7B60-5C39-4599-BAD6-839C1BA81204`, iOS 26.2)

## Current State (as of 2026-02-14)

All features below are implemented, built, tested in simulator, and pushed to GitHub `main`.

### Files

| File | Lines | Purpose |
|------|-------|---------|
| `VIKOV/VIKOVApp.swift` | ~15 | `@main` App struct, unchanged from template |
| `VIKOV/Models.swift` | ~140 | All data models: `TaskMode`, `SubTask`, `ChecklistTask`, `Category`, `Week`, `CategoryTemplate`, `AppearanceMode` |
| `VIKOV/ChecklistStore.swift` | ~340 | `@Observable` store: persistence, business logic, CRUD, rollover |
| `VIKOV/ContentView.swift` | ~1050 | All SwiftUI views: root, task rows, sheets, onboarding |
| `CLAUDE.md` | ~90 | Architecture reference for Claude Code |

### Features Implemented

1. **Weekly checklist structure**: Weeks → Categories → Tasks → Sub-tasks
2. **Three task modes**: Carry Over (rolls if incomplete), Repeating (every week, resets), One-Time (never carries)
3. **JSON persistence**: Two files — `checklist.json` (week data), `settings.json` (preferences)
4. **Weekly rollover**: `ensureWeekExists(for:)` creates new weeks from prior week's categories. Respects all three task modes.
5. **Week navigation**: Previous/next arrows + calendar date picker for any week
6. **Edit mode**: Pencil/checkmark toggle in toolbar. Enables:
   - Add/remove categories (top of list, under header)
   - Inline task title editing
   - Task mode picker (tap mode badge)
   - Sub-task management (add, edit, delete, complete)
   - Category removal sheet with X dismiss (remove this week vs delete entirely)
7. **Saved category templates**: Categories saved for reuse. Add Category sheet shows saved + create new.
8. **Appearance toggle**: System/Light/Dark in Settings
9. **Two-step onboarding**: Welcome instructions → Category setup (create custom or skip for defaults)
10. **Help sheet**: Detailed instructions on all features, accessed from Settings
11. **Swipe actions**: Right-swipe cycles task modes, left-swipe deletes
12. **Context menus**: On category headers (save, remove, delete) and tasks (mode, edit, subtasks, delete)
13. **iOS 26 Liquid Glass**: Auto-adopted via Xcode 26 (NavigationStack, toolbars, controls)

### UI Layout

- **Toolbar leading**: `[< chevron]  [calendar]  [> chevron]` grouped
- **Toolbar trailing**: `[pencil/green checkmark]  [gear settings]` grouped
- **Edit-done button**: Green-tinted `checkmark.circle.fill` when active
- **Add Category**: Appears at top of list (under header) in edit mode only
- **Collapsible sections**: `Section(isExpanded:)` with `Set<UUID>` tracking

## Commit History

```
baa06f1 Initial Commit
17c8ea7 Add weekly checklist MVP: models, store with JSON persistence, and full UI
6917ea3 Redesign UI for iOS 26 with Liquid Glass, starter categories, and task modes
bb21900 Add saved categories, welcome alert, help guide, appearance toggle
d2b7614 Add Edit mode, one-time tasks, sub-tasks, and inline editing
2f773c0 Move Add Category to top, green edit-done button, onboarding flow, dismissable remove sheet
2b8dace Update CLAUDE.md with full current architecture
```

## Development Workflow

- Build after each checkpoint: `xcodebuild -project VIKOV.xcodeproj -scheme VIKOV -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
- Install to sim: `xcrun simctl install 66BC7B60-5C39-4599-BAD6-839C1BA81204 ~/Library/Developer/Xcode/DerivedData/VIKOV-enfbpsqjcwhtrgdnotmnlfnayzgj/Build/Products/Debug-iphonesimulator/VIKOV.app`
- Launch: `xcrun simctl launch 66BC7B60-5C39-4599-BAD6-839C1BA81204 com.symonym.VIKOV`
- Screenshot: `xcrun simctl io 66BC7B60-5C39-4599-BAD6-839C1BA81204 screenshot /tmp/vikov.png`
- Fresh install test: `xcrun simctl uninstall ... && xcrun simctl install ...`
- New files in `VIKOV/` are auto-discovered (`PBXFileSystemSynchronizedRootGroup`)

## Key Decisions & Gotchas

1. **Simulator name**: `iPhone 16` doesn't exist in Xcode 26.2 — use `iPhone 17 Pro`
2. **Init order in ChecklistStore**: Must seed `savedCategories` BEFORE `ensureWeekExists(for:)`, otherwise first week gets 0 categories
3. **No simctl tap**: `xcrun simctl io input tap` doesn't exist — can't programmatically interact with UI, only screenshot
4. **`.quaternary` type mismatch**: Can't use `.quaternary` in ternary with `Color` — use `Color.secondary` instead
5. **Settings JSON UUIDs**: When manually editing `settings.json` for testing, UUIDs must be valid format (e.g., `A1B2C3D4-E5F6-7890-ABCD-EF1234567890`), not short strings
6. **GitHub auth**: Uses `gh` CLI (installed via Homebrew), HTTPS protocol, account `SymonymD`

## Planned / Not Yet Implemented

- Calendar integration (paid upgrade toggle exists in Settings, marked "Coming Soon")
- Unit tests (test targets exist but no tests written yet)
- iPad-specific layout optimizations
- Data export/import

## Last Session Summary (2026-02-14)

**What was done**: Built the entire VIKOV app from scratch across 6 development checkpoints. Started from a Figma screenshot, then pivoted to iOS 26 design guidelines. Implemented full weekly checklist with three task modes, sub-tasks, JSON persistence, weekly rollover, edit mode, saved category templates, two-step onboarding, appearance toggle, help guide, and all supporting UI. Set up GitHub repo and pushed.

**Nothing in progress**: All requested features are complete and committed.

**User's likely next steps**: No specific next task was mentioned. Potential areas: writing unit tests, iPad layout, calendar integration, or new feature requests.
