# Tasquel 1.0.3 review: iPad

(Saved from the reviewer's final message. The harness refused report files: "Subagents should return findings as text".)

Simulators: iPad Pro 13-inch (M5), iOS 26.3 (all runs); the 11-inch was booted but every run ended up on the 13-inch. Light theme, `-demoData` unless noted. Shots folder: the reviewer's `IPad/shots` (written `shots/` below); the ones cited are copied to `evidence/IPad/`. Logs: `shots/all13.log`, `run2.log` … `run5.log`.

Testing note: the Mac's load average was 600 to 1,000, and every XCUITest step waited 30 s for "idle". `ReviewIPadHelpers.swift` skips those waits on the test side only (set `REVIEW_KEEP_QUIESCENCE=1` to keep them), and the tests pace themselves with waits and sleeps.

## 1. Findings

### F1. In a resized window, the window controls cover the Tasquel mark (This Week). Major
- **Device:** 13", Settings ▸ Multitasking & Gestures ▸ Windowed Apps (this simulator's default), any window smaller than the screen.
- **Steps:** launch, then drag the window's corner to make it smaller (or open a second window with ⌘N).
- **Expected:** the Tasquel mark at the header's top left, which goes back to this week, stays visible and tappable.
- **Actual:** iPadOS 26's red/yellow/green window controls sit right on top of it. In a 375×697 window the mark is at (12–56, 9–53) inside the window, under the controls. A tap there reaches the window menu, so the Help's "tap the Tasquel logo" no longer works. In a full-size window it's fine.
- **Evidence:** `shots/window-controls-vs-mark.png`. Also seen in `narrow-01-closed.png`, `narrow-02-errands-open.png`, `wide-01-closed.png`, `wide-02-open.png` and `windows-03-side-by-side.png` (5 tests, 3 runs). Compare `explore-01-landscape-closed.png` (full size). Test: `ReviewIPadSetupTests.testWindowControlsLeaveTheTasquelMarkClear` fails with "the window controls cover the Tasquel mark: (513.0, 119.0, 44.0, 44.0)" (run5.log).
- **Likely cause:** `ContentView.swift:885` `.overlay(alignment: .leading) { homeButton }` with only `.padding(.leading, 12)` (`ContentView.swift:683`). The custom header goes up behind the status bar and ignores the window-controls region.
- **Fix:** inset the header's leading edge by the window-controls area. Read UIKit's `layoutGuide(for: .margins(cornerAdaptation: .horizontal))` through a small representable, or put the mark in a system toolbar item, which avoids the controls by itself.

### F2. Rotating while typing leaves the field behind the keyboard, and typing doesn't bring it back. Minor
- **Device:** 13", full screen and windowed.
- **Steps:** portrait, open Errands, tap Add Task, type "Rotate me", turn to landscape.
- **Expected:** the field being typed in stays above the keyboard.
- **Actual:** the words and focus are kept, but the field ends up at y 785–807 (807 when it was 4 s after the turn), while the keyboard starts at 589. The field is still there 8 s later and after typing another character. The user types blind until the keyboard is closed.
- **Evidence:** `shots/rotate-typing-landscape-run2.png` and `rotate-typing-landscape-8s.png`, `rotate-typing-landscape-typed.png`. Test `ReviewIPadTests.testRotateWhileTypingKeepsText` failed in all13.log, run2.log and run3.log: "after rotating: field (66.5, 785.5, 1162.5, 21.0) keyboard (0.0, 589.0, 1376.0, 440.0)".
- **Likely cause:** `keepFieldInView()` (`TaskRowCard.swift:2056`) runs only after a task is added. A size change (`WindowSizeReader`, `ContentView.swift:531`) or a new keyboard frame never scrolls the focused row back into view.
- **Fix:** while a card field has focus, call the same `gridScroll.scrollTo(rowID)` on window-size or orientation changes and on `keyboardDidChangeFrame`. Do the same for rename fields.

### F3. Tab on a hardware keyboard types a tab into task names. Minor
- **Device:** 13", landscape, a hardware Tab key (XCUITest `typeKey(.tab)`, which also hides the on-screen keyboard as a real keyboard does).
- **Steps:** open Errands, tap "Pick up dry cleaning", type " soon", press Tab, type "now", press Return.
- **Expected:** Tab moves on or does nothing. Names never hold tab characters.
- **Actual:** the name saved is "Pick up dry cleaning soon⇥now".
- **Evidence:** `shots/rename-tab.png` (caret jumps a tab stop). Test `ReviewIPadTests.testRenameFieldTabAndEscapeKeys`: run2 logged "value 'Pick up dry cleaning soon<TAB>'", and run3 logged "saved name 'Pick up dry cleaning soon<TAB>now'".
- **Likely cause:** the new wrapping rename fields (`TaskRowCard.swift:173` and `:1444`, `axis: .vertical`) are text views, which insert `\t`. `RenameField.submitted` (`TaskRowCard.swift:1250`) handles only line breaks, and `commitTitle` (`:964`) trims only the ends. The Add Task, Add Item and sub-task fields wrap the same way, so they probably do it too (not tested).
- **Fix:** handle Tab with `.onKeyPress(.tab)`: save, or move to the next field. Also replace `\t` with a space in `RenameField`.

### F4. Escape does nothing in a rename field. Polish
- **Steps:** rename a task, type " later", press Escape.
- **Actual:** the field keeps focus and the edit ("…later"). iPad apps usually cancel the edit on Escape. Logged by `ReviewIPadTests.testRenameFieldEscapeKey` (run3: "field exists true focused true value 'Pick up dry cleaning later'"). The test now asserts cancel-and-keep-old-name and will fail until it's handled. Change it if you'd rather Escape save.
- **Fix:** `.onKeyPress(.escape)`: put back `task.title` and end editing.

## 2. Checked and fine
- Reorder by the handle, landscape (4 columns) and portrait (3 columns): the task lands past the target, the week doesn't change, and edit mode stays (`reorder-*-after.png`).
- Fold a list in an open card above a row of closed cards, both orientations: "2 of 5" sits just before the chevron, the items and Add Item hide, closed cards don't overlap, and it opens again (`fold-*.png`).
- List row type/mode button with Add Item typing and the keyboard up, full screen, both orientations: the keyboard closes, the picker is wholly on screen, and the typed item is added (run4).
- New-task picker with the keyboard up, landscape: on screen, and Add Task works (`new-options-landscape.png`).
- Narrow 375–386pt window: 2 columns, bars inside the window, and both pickers with the keyboard up stay above it and can be tapped (`narrow-03…`, run3).
- Wide, short 1376×486 window: the layout holds (`wide-*.png`).
- Rename field wraps: 2 lines in landscape (1162pt), 3 in portrait (818pt). It stays in the window, and Return saves the whole name without a line break (run4).
- Rotating with the type/mode popover open: it re-anchors on screen (`rotate-popover-landscape.png`).
- Rotating with Settings open: a 580pt form sheet both ways.
- Emoji picker from a card's edit mode: a small sheet above the emoji keyboard in both orientations that survives rotation (`emoji-sheet-*.png`; the "?" glyphs are a simulator font gap).
- ⌘N opens a second window (2 scenes).

## 3. Test files
In `tests/IPad/` (from `TasquelUITests/` in the reviewer's copy):
- `ReviewIPadHelpers.swift`: the base class (launch, shots, the field lookup, skipping idle waits).
- `ReviewIPadSetupTests.swift`: **F1** `testWindowControlsLeaveTheTasquelMarkClear`, plus `testA_UseFullScreenApps` (setup).
- `ReviewIPadTests.swift`:
  - findings: **F2** `testRotateWhileTypingKeepsText`, **F3** `testRenameFieldTabAndEscapeKeys`, **F4** `testRenameFieldEscapeKey`;
  - checked and fine: `testReorderByHandleLandscape/Portrait`, `testFoldListInOpenCardBesideClosedCards{Landscape,Portrait}`, `testListRowOptionsPopoverWithKeyboard`, `testNewTaskOptionsPopoverWithKeyboardLandscape`, `testRenameFieldWrapsLandscapeAndPortrait`, `testRotateWithOptionsPopoverOpen`, `testRotateWithSettingsSheet`;
  - `testReorderAutoScrollsLongCardLandscape` never got past its setup (see section 4).
- `ReviewIPadWindowSizeTests.swift`: narrow and wide windows (checked and fine). These tests turn on Windowed Apps themselves.
- `ReviewIPadSheetsTests.swift`: the emoji sheet (fine).
- `ReviewIPadWindowsTests.swift`: two windows side by side. The second window opened centered over the first and my corner drag didn't resize it, so it fails at setup. Sync is unverified.
- `ReviewIPadExploreTests.swift`: exploration only.

Window sizes are remembered between launches, and the last test left this simulator in **Full Screen Apps**; it started in Windowed Apps.

Side note, not a finding: `GoalUITests.swift:427` and `:591` still look for `app.textFields["Task name"]`, but the rename field is now a text view.

## 4. Couldn't check in a simulator (to try on a device)
- Put two Tasquel windows side by side and type in one: does the other window's bottom bar turn into the round keyboard button? `keyboardWillShow` (`ContentView.swift:219`, `:538`) doesn't check which window the keyboard is for, so I suspect it does. Try Tasquel beside another app's keyboard too.
- With two windows open, does a task added or checked in one show in the other right away?
- Drag a task by its handle and rotate the iPad before letting go: does it land where you dropped it?
- Hold a task near the bottom of a long card in landscape: does the card scroll, and is the speed comfortable? My test couldn't start the card's edit mode in full-screen landscape after closing the keyboard with the round button (2 of 3 runs). Also try: close the keyboard, then tap the card's edit button straight away. Does edit mode start on the first tap?
- With a Magic Keyboard: the bottom bar stays above the shortcuts bar, and Return, Tab and Escape behave in each field.
- With a trackpad: do the handle and chevron highlight on hover, and does click-dragging the handle reorder?
- Write into a rename field with Apple Pencil Scribble: does it wrap and save?
- Stage Manager on an external display: is the layout right at the display's sizes?
