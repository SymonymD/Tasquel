# Accessibility review: Tasquel 1.0.3

(Saved from the reviewer's final message. The harness refused report files: "Subagents should return findings as text".)

All testing was on the iPhone 17 simulator (iOS 26.3), portrait, System theme in light mode, launched with `-demoData -demoFirstCard Errands`. Screenshots and UI trees are in the reviewer's `Access/shots` folder (`*_s.png` are small copies); the ones cited are copied to `evidence/Access/`. The Mac was badly overloaded the whole time: load average 600 to 1,000, two runs where the test runner never started, and one where it was killed before connecting. So fewer tests got through than planned; "Not run" at the end lists what's missing.

## Findings

### 1. A folded list loses its name and pushes the card off the screen at large text sizes
**Rejection risk** (an accessibility blocker).
- **Settings:** Text Size AccessibilityXXXL. Part of it also happens at XXXL, the largest standard size.
- **Steps:** open Errands, tap the Groceries chevron to fold the list, then tap the card's edit button.
- **Expected:** "Groceries" stays readable, "2 of 5" fits beside it, and every control stays on the screen.
- **Actual, folded:**
  - The name shrinks to a column 1 pt wide and 559 pt tall, so none of it shows. The row reads only "○ 2 of 5 >".
  - The row makes the whole card wider than the 402-pt screen:
    - every task's type/mode button now ends at x=445;
    - the card's edit button and progress ring are cut off.
- **Actual, folded and in the card's edit mode:**
  - Done editing sits at x=453–513, and every trash can at x=445–511. All of them are off the screen.
  - So the user can't delete a task or leave edit mode by tapping.
- **At XXXL:** in edit mode, the folded list's name also vanishes.
- **Recovery:** unfolding the list restores the layout.
- **It's the fold:** with the list unfolded, Delete and Done editing stay on screen (`testEditModeAtLargestTextSizeKeepsButtonsOnScreen` passes).
- **Evidence:**
  - Screenshots: `B03-groceries-folded-axxxxl_s.png`, `B04-errands-edit-axxxxl_s.png`, `B05-errands-edit-toggle-axxxxl_s.png`, `F1-folded-count-axxxxl.png`, `C04-errands-edit-xxxl_s.png`.
  - UI tree: `B04-errands-edit-axxxxl.txt`.
  - `testFoldedCountFitsAtLargestTextSize` fails. It reproduced twice with identical frames: `title=(75,334, 1.0×558.7) count=(86,584, 123.7×59.3) fold=(219.8, 66×66) options=(286, 159.7×66)`. The assertions report 445.7 > 402 (the type/mode button is off screen) and 1.0 < 120 (no room for the name).
- **Likely cause:**
  - `TaskRowCard.swift:206` puts `foldedCount` in the title row.
  - `TaskRowCard.swift:430-438` draws it at `.expandedCard(.caption1)` with no cap (about 46 pt at AXXXXL) and makes it `.fixedSize()` (line 436).
  - So the count, the chevron and the type/mode button need more width than the row has. The name gives up its width first, then the card overflows.
- **Suggested fix:**
  - At accessibility sizes, or whenever the row doesn't fit, put the count on its own line under the name (`ViewThatFits`, or an `AnyLayout` VStack).
  - Cap the count's font.
  - Don't fix its width with `fixedSize` horizontally.

### 2. List names still break mid-word, because the icon cap doesn't work
**Major.**
- **Settings:** XXXL and AccessibilityXXXL.
- **Steps:** open Errands at the large size.
- **Expected:** the spec says that at the largest text sizes "the icons stop growing, leaving the title room to wrap at word breaks".
- **Actual:**
  - At AXXXXL, "Groceries" wraps as "Gr / oc / eri / es", and "Drop off donations" as "donation / s".
  - At XXXL with the list folded, "Grocerie / s".
  - In the card's edit mode at AXXXXL, even with the list unfolded, the list's name disappears and every task's reorder handle is pushed past the right edge.
  - The type/mode button is 159.7 pt wide at AXXXXL, and the new chevron adds another 66 pt to each list row.
- **Evidence:** `B02-errands-open-axxxxl_s.png`, `B05-errands-edit-toggle-axxxxl_s.png`, `C03-groceries-folded-xxxl_s.png`, `F2-edit-unfolded-axxxxl_s.png`, plus the UI trees `B02-errands-open-axxxxl.txt` and `F2-edit-unfolded-axxxxl.txt`.
- **Likely cause:**
  - The `.dynamicTypeSize(...DynamicTypeSize.accessibility1)` cap at `TaskRowCard.swift:224` has no effect.
  - `Font.expandedCard` and `expandedCardScaled` (`TaskRowCard.swift:26-43`) take their size from the global `TextSizeSetting.shared` (set at `ContentView.swift:267-268`), not from the environment.
  - So `TaskOptionsLabel` (`TaskOptionsPicker.swift:19`) and the row icons keep growing.
- **Suggested fix:**
  - Give `expandedCard` a cap, or use `min(size, .accessibility1)` for the icon row.
  - At accessibility sizes, consider stacking the icons under the name.

### 3. VoiceOver isn't told that a task's name can be renamed
**Minor.** Not new in 1.0.3, but the rename fields are part of this release.
- **Expected:** the name is announced as something you can act on: a button with "double-tap to rename", or a Rename action.
- **Actual:** it's a plain StaticText "Groceries" (`B02-errands-open-axxxxl.txt`, line 19), with no button trait and no hint. Help tells sighted users to "Tap a task's … name to rename it".
- **Cause:** `.onTapGesture` on a `Text`, at `TaskRowCard.swift:192-203` and `1461-1475`.
- **Suggested fix:** add `.accessibilityAddTraits(.isButton)` and a hint, or an `.accessibilityAction(named: "Rename")`.

### 4. "0 of 1 items checked"
**Polish.**
- **Steps:** make a list with one item and fold it.
- **Actual:** VoiceOver says "0 of 1 items checked".
- **Evidence:** `testFoldedCountSingularItem` fails with `found: 0 of 1 items checked`.
- **Cause:** `TaskRowCard.swift:437`.
- **Suggested fix:** say "item" when the total is 1.

### 5. Contrast of today's day pill ("10th")
**Polish.** Not new in this release.
- **Actual:** the audit reports "Contrast nearly passed" at every size, and "Contrast failed" once at AXXXXL. The pill's blue text sits on light blue (`WeekDayStrip.swift`).
- **Suggested fix:** darken the text or tint the pill less.

## Checked and fine
- **Chevron:** VoiceOver hears "Collapse list" or "Expand list", with the list's name as its value (`testFoldedListHidesItemsFromVoiceOver`).
- **Folded count:** it reads "2 of 5 items checked".
- **Folded content:** the items and Add Item are gone from the accessibility tree.
- **Chevron size:** 66×66 at AXXXXL. At the default size it's at least 41×41, with a 44-pt hit area. It stays in a card's edit mode.
- **Reorder handle:** in edit mode it isn't in the accessibility tree, while Delete, the checkbox and the chevron are (`testEditModeHandleHiddenAndSwitchLabeled`). Move Up / Move Down sit on the checkbox or goal ring (`TaskRowCard.swift:342-353`).
- **This week only:** a real switch labeled "This week only", with value 0/1. It can be scrolled to at AXXXXL, and the audit found nothing on it.
- **Rename fields:** the code gives them the identifiers and labels "Task name", "Item" and "Sub-task" (`TaskRowCard.swift:176-177`, `1446-1447`). In the UI tree they show up as text fields, not text views.
- **Reduce Motion:** the fold honors it (`TaskRowCard.swift:424`).
- **Unfolded edit mode at AXXXXL:** Delete and Done editing stay on the screen.
- **Automated audit, AXXXXL and XXXL:** run on the grid, an open card, a folded list, edit mode and the switch. Nothing on the new controls.
  - False positives: the contrast failures on "Oat milk", "Lemons", "bags" and "Pick up dry cleaning" are rows under the glass bar or header; "Hit area too small" is the goal's bar, which isn't interactive.
  - By design: "Dynamic Type partially unsupported" on the week title and day strip, which are capped on purpose.
  - Part of finding 1: "Text clipped" on the category name in edit mode at AXXXXL.
- **Color alone:** done and not done don't rely on it: filled vs outlined circles, and done tasks are struck through.

## Test files
`tests/Access/ReviewAccessUITests.swift` and `tests/Access/ReviewAccessSettingsUITests.swift`.

- **Finding 1:** `testFoldedCountFitsAtLargestTextSize` (fails now).
- **Finding 2:** shown by the screenshots from `testExploreAXXXXL` and `testExploreXXXL`.
  - `testEditModeAtLargestTextSizeKeepsButtonsOnScreen` passes. It checks Delete and Done; it can't check the handle, which is hidden from accessibility.
- **Finding 4:** `testFoldedCountSingularItem` (fails now).
- **Checked and fine, passing:** `testFoldedListHidesItemsFromVoiceOver`, `testEditModeHandleHiddenAndSwitchLabeled`.
- **`testRenameFieldsAreLabeled`: not yet passing, because of my test.** Its tap on "Groceries" was computed mid-spring while the card opened and landed at (93, 271), on Eggs, so an Item rename opened instead. I added a wait for the card to settle and match either a text field or a text view, but haven't re-run it.
- **Exploration:** `testExploreDefaultSize`, `testExploreAXXXXL`, `testExploreXXXL` log the audits and save the trees and screenshots.
- **System settings:** `ReviewAccessSettingsUITests.testAssistiveDisplaySettingsKeepLayout` turns on Bold Text, Button Shapes, Reduce Transparency, Increase Contrast and Reduce Motion in the Settings app. It then checks the week, an open card, a folded list, edit mode and Add task in Light, Dark and Retro, and turns the settings off afterwards. It was written but not run.

## Not run, because of the machine's load
- `testExploreDefaultSize`: the audit at the default size.
- `testAssistiveDisplaySettingsKeepLayout`: the system settings above. The code suggests Increase Contrast won't change the Dark and Retro themes, whose text colors are fixed (`Theme.swift:122-135`, `.white.opacity(0.6)`).
- `testRenameFieldsAreLabeled`: the re-run after the fix above.

## Couldn't check in a simulator (phone checklist)
- With VoiceOver, fold Groceries. Does focus stay on the chevron, and do you hear "Expand list, Groceries"?
- With VoiceOver, in a card's edit mode, swipe up and down on a task's checkbox. Are Move Up and Move Down offered, and does the task move?
- With VoiceOver, double-tap a task's name. Does renaming start, and does Return save?
- With Voice Control, can you reorder tasks at all? The handle isn't exposed; try "Drag from" with the grid.
- With Reduce Motion on, drag a task. Is the 3% lift and the sliding comfortable? They animate whatever the setting (`CategoryCard.swift`, `moveLifted` and `drop`).
- Lift a task, move it, drop it. Do you feel the haptics: medium on the lift, a tick at each place, light on the drop?
- At the largest text size on a real phone, fold a list. Can you still find the chevron to open it again?
