## iPad review: Tasquel 1.1 (iPad Pro 13" B37B6649 and 11" 0501F1B0, iOS 26.3, `-demoData`, light mode)

All paths below are relative to the work root's `IPad/`. Screenshots are in `shots/` (the cited ones are copied, shrunk, to `evidence/IPad/`) and run logs are `shots/*.log`.

### 1. Findings, most severe first

**F1. An open card switches lanes when another card opens or closes in landscape: Major**
- **Device:** 13" and 11", landscape, 4 columns.
- **Steps:**
  1. Open Work. It takes the left half.
  2. Open Errands.
  3. Close Errands.
- **Expected:** Work stays where it is. The brief says cards shouldn't "jump … or lose their place", and the spec says an opened card keeps its place.
- **Actual:** At step 2, Errands takes the left lane and Work, which may be the card you're working in, jumps to the right half (x −8 → 668 on the 13", −8 → 585 on the 11"). At step 3, Work jumps back to the left. Errands, which was the top-left card, also moves to the right lane when Work opens.
- **Evidence:** `lanes-01-work-open.png`, `lanes-02-errands-open.png`, `lanes-03-errands-closed.png`. Test `ReviewIPadLanesTests/testOpeningAnotherCardKeepsOpenCardInItsLane` fails both lane checks: `("668.0") is not equal to ("-8.0") - Work stays in its lane when Errands opens` (`shots/lanes1.log`, `shots/ipad11.log`).
- **Likely cause:** `Tasquel/CategoryGridLayout.swift:165-176`. `frames()` re-deals every open card in grid order on every layout pass, each into the shorter lane with ties going left (lines 152-154 and 168). So an open card's lane depends on which cards before it are open.
- **Fix:** keep each open card's lane once it is placed. For example, ContentView records a lane per `CategoryLayoutKey` when the card opens and passes it in as a `LayoutValueKey`. Only a newly opened card picks the shorter lane.

**F2. Turning from landscape to portrait leaves closed cards alone in rows of three: Minor**
- **Device:** 13" and 11".
- **Steps:**
  1. In landscape, open Work and Study.
  2. Rotate to portrait.
- **Expected:** the same layout as opening those cards in portrait: open cards at the start of their rows, and Errands, Fitness and Appointments sharing one row (`pack-0-opened-in-portrait.png`).
- **Actual:** Errands sits alone at the top, Fitness alone between the two open cards, and Appointments alone at the bottom, with two thirds of each row empty. It stays that way until every card is closed.
- **Evidence:** `rotate-02-portrait.png`, `pack-1-opened-in-landscape-turned.png`. Test `ReviewIPadLanesTests/testRotatingToPortraitPacksClosedCards` fails on both sizes: `("111.0") is not equal to ("783.5")`.
- **Likely cause:** `Tasquel/ContentView.swift:1916`. `orderOpening` returns nil in half-width mode, so no display order is kept. Nothing reflows when `gridColumns` changes: `isLandscape` is set at line 635, and `reopenCards` only runs on leaving Edit or a sort change (line 1867).
- **Fix:** add `.onChange(of: gridColumns) { reopenCards(expandedCategoryKeys) }`.

**F3. The bottom bar rides up on the keyboard behind the Add Category sheet: Polish**
- **Device:** 13", landscape and portrait.
- **Steps:** Edit ▸ Add Category ▸ Create New Category, then tap the name field.
- **Expected:** on iPad the main screen shows around the form sheet, so its bar (Settings, the week selector, green Done) should stay at the bottom, behind the keyboard.
- **Actual:** the bar moves from y 960 to y 462 and floats just above the keyboard, dimmed. Seen in 3 runs.
- **Evidence:** `shots/addcat-1-added.png`, `shots/addcat-2-rotated.png`, `bar-behind-sheet-keyboard.png`. Test `ReviewIPadScreensTests/testBarStaysDownWhileTypingInAddCategorySheet` fails: `bar before 960.0 now 462.0` (`shots/bar1.log`).
- **Likely cause:** `Tasquel/ContentView.swift:231`. The bar's VStack ignores only `.container` at the bottom, not `.keyboard`. `isKeyboardVisible` stays false while a sheet is up, so the bar is never removed.
- **Fix:** use `.ignoresSafeArea([.container, .keyboard], edges: .bottom)`.

### 2. Checked and fine
- **Type/mode/day popup and its "Until" calendar:** opened from the top, middle and bottom rows, landscape lanes and portrait, on both sizes and in a 375pt window. All controls are inside the window and tappable, and the popover flips above bottom rows.
- **Rotating with the popup open:** it stays whole and re-anchored.
- **Rotating mid-rename:** the words are kept and the field stays above the keyboard.
- **"Added to next week":** the screen pages to next week and the pop-up is centered with OK and Back to This Week inside the window. Back returns to this week, the house goes, the open cards stay open and in the same lanes, and the task is in next week only (both sizes).
- **The bar's house:** the same 16pt from the arrow buttons on both sides (about 10pt from the selector's glass), portrait and landscape, both sizes.
- **What's New pill:** at window widths 1376, 652 and 375 it sits between the mark (and the window controls) and the title, with no overlap, and is tappable.
- **Help:** in a 375pt window the tab pills scroll and center the picked tab. With Modes picked, rotating and rotating back keeps the page whole and not offset.
- **Add Category:** a form sheet (580pt wide). After an add it stays open with "Added School · add another, or tap Done", the field cleared and the keyboard up. This survives rotation. Done closes it, School is in the week, and Edit ends.
- **Resizing with two cards open:** wide to 871, 636, 375 and back to full keeps both cards open, with no overlap and nothing past the window edge. Lanes come back at full width.
- **Rotating with open cards:** landscape to portrait to landscape keeps them open and apart.
- **Several cards open:** with every card but the first open, the first stays in view (it moves under the left lane).
- **New Window:** the app supports multiple windows (the home-screen icon menu has New Window and Show All Windows).

### 3. Test files (in `tests/IPad/`)
- **`ReviewIPadLanesTests.swift`:**
  - F1: `testOpeningAnotherCardKeepsOpenCardInItsLane`
  - F2: `testRotatingToPortraitPacksClosedCards`
  - Checked and fine: `testRotatingWithOpenCardsKeepsThemOpenAndApart`, `testResizingWindowWithOpenCards`, `testClosedFirstCardStaysInViewWhenOthersOpen`
  - `testExploreLandscapeGrid` only dumps the accessibility tree; it asserts nothing.
  - It also holds the shared helpers: `launchDemo` returns the window to full size, because iPadOS keeps a resized window's size across launches, and `resizeWindow` drags the window's corner handle.
- **`ReviewIPadScreensTests.swift`:**
  - F3: `testBarStaysDownWhileTypingInAddCategorySheet`
  - Checked and fine: `testOptionsPopupFromTopMiddleBottomRows`, `testAddedToNextWeekPopupAndPaging`, `testBarHouseSameGapBothSides`, `testWhatsNewPillInResizedWindows`, `testHelpTabsInNarrowWindow`, `testHelpPageSurvivesRotationAndResize`, `testAddCategorySheetStaysOpen`, `testRotatingWithOptionsPopupOpen`, `testRotatingWhileRenaming`
- **`ReviewIPadWindowsTests.swift`:** `testTwoWindowsStayInSync` opens New Window from the icon menu. It is exploratory only and doesn't yet check that the two windows stay in sync (see section 4).
- **Run script:** `run.sh <UDID> <log> <Class/test>…`.

### 4. Couldn't check in a simulator (phone checklist)
- **Hardware keyboard** (it can't be connected without the Simulator app):
  - Press Escape in a task, sub-task or card rename field: does the old name come back?
  - Press Return and Tab in rename and Add Task fields.
  - Open a popup and its calendar with the keyboard attached: are they placed without depending on the on-screen keyboard?
- **Two windows side by side:** open New Window from the icon's menu, check a task off in one window and see whether the other updates. New Window opened, but the second window couldn't be told apart or arranged in a test.
- **Split View or Stage Manager next to another app:** check the lanes at that width.
- **Pointer/trackpad:**
  - Do the day pills, the house, the What's New pill and card corners highlight on hover?
  - Does clicking a card's name close it?
- **Lanes animation:** open a second card in landscape and watch the reflow spring. Does the lane swap in F1 feel jarring at real speed?
- **The house in a resized window:** at narrow widths, does it still sit beside the selector without crowding Settings or Edit?
- **What's New pill slide-out on iPad:** in a freshly resized window with the window controls showing, does it come out cleanly from behind the mark?
- **Turkey on iPad (Thanksgiving week):** with the window controls showing, does it run out without being clipped?
