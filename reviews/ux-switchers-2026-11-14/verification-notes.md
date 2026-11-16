# My checks of tester findings (code reading; repro on sim still to do where marked)

## Sam
- S1 Past weeks before install show every Saved Category (deleted defaults + new ones): CONFIRMED in code.
  Past weeks are never stored; previewWeek/makeWeek (ChecklistStore.swift:703) seeds a week with no earlier stored
  week from `savedCategories`, which keeps deleted cards. Display only, no data harm. Every new user who taps ‹ sees it.
  Fix idea: a past week with no stored week at/before it shows an empty state ("Tasquel wasn't in use this week"),
  or seeds from the earliest stored week instead of Saved Categories.
- S2 "Yoga twice this week" → one-time: CONFIRMED rules gap. weeklyCount (ParsedTask.swift:548) needs
  "(a|an|per|each|every|/) week"; "this week" not accepted. Small fix: allow "this week". (AI mode on device may differ.)
- S3 "by Thursday" on Saturday → "Thu · late", name keeps "by Thursday": BY DESIGN (day = weekday within the week;
  cleanTitle keeps day words on purpose). Design question for 1.2: past day in current week → next week, or strip "by <day>".
- S4 🍎 emoji shows "?" box: likely simulator font. Check on phone.
- S5 Goal Target/Set row appears behind the options popover (10-yoga-goal): CONFIRMED visually; user must tap Done first. Idea: put Target in the popover or focus it after Done.
- S6 Add Category closes sheet and leaves Edit mode: TO CHECK (behavior choice).
- S7 "3 events" for 4 rows (multi-day event listed twice): likely intended.
- S8 +1 on goal stayed 0/2: NOT A BUG. Test tapped buttons["+1"]; the real label is "Add 1", so tapIf skipped it.

## Elena
- E1 About says 1.0.3 next to What's New in 1.1: EXPECTED, version bump to 1.1 (12) is pending.
- E2 Past weeks show all saved cards: same as S1 (CONFIRMED).
- E3 Retro labels carry decorations ("> Match App Icon to Theme", "[APPEARANCE]", "> SETTINGS_"): CONFIRMED in code.
  SettingsSheet.swift:55, 214–249 (retroLinkLabel/retroLink), 288 (retroSection "[\(title)]"), 315; no plain
  accessibilityLabel. CLAUDE.md says "Retro text has plain-language labels", so Settings (and Help's "> item"
  HelpSheet.swift:167/173) are gaps. How much VoiceOver speaks depends on punctuation level. Small Retro-only fix.
- E4 Help tab pills: visible "Weeks", label "Weekly Checklist" (HelpSheet.swift:143): CONFIRMED. Breaks label-in-name
  (WCAG 2.5.3, Voice Control "tap Modes"). Fix: label = visible short name, long title as hint (or "Weeks, Weekly Checklist").
- E5 Until / expires / Expiration wording mixed: CONFIRMED (copy). Bigger point: Until reads as a deadline; the task is DELETED after it.
- E6 Icon menu under keyboard in Create New Category: minor, not checked.
- E7 Swipe on a task row changes week: BY DESIGN (documented).

## Dev
- D1 Edit goal panel overflows with a Custom unit (unit field + Save Goal clipped on 402pt iPhone 17 Pro): CONFIRMED (13c-edit-goal.png).
  TaskRowCard.swift:1199 editGoalForm Target row = label 64·1.15 + unit menu (fixedSize) + number field 90·1.15 + unit name
  minWidth 64·1.15 in one HStack, inside 24·1.15 leading pad: ~360pt+ in a ~338pt card. The too-wide row widens the
  VStack, so the button row (ViewThatFits) is clipped too. Same row existed in older code (pre-1.1). 1.1 FIX CANDIDATE:
  put the unit name under the number when the row doesn't fit (ViewThatFits), as the buttons already do.
- D2 Step 1 → target 7 → "Done, 8 of 7": BY DESIGN (user's rule: step × days = target; feedback-simple-rules), but the
  result surprised. Idea: per-day goal ("8 a day") or keep target when step typed; at least a note when it auto-completes.
- D3 Smart Add "every Monday, Wednesday and Friday" → goal of 3, days dropped: BY DESIGN (a task has one day; list = count).
  1.2: multi-day tasks.
- D4 "Duplicate" on Gym Mon / Gym Wed: BY DESIGN (same card, same name), but different days are intentional.
  Small fix idea: don't mark duplicates whose days differ.
- D5 New repeating Fri task on Saturday shows "Fri · late": BY DESIGN for the day label; question for 1.2.
- D6 SF Symbol names in tree ("Move", "Do Not Disturb"): NOT A BUG. Images are children of Buttons labeled "Icon: Folder",
  "Light", "Dark"; VoiceOver reads the Button's label.
- D7 Tap in status-bar area didn't dismiss popover: minor, not checked.

## Marcus
- M1 "Send invoic / e" mid-word break in card edit mode next to "📅 Fri · late": CONFIRMED (12a-card-pencil.png), NEW IN 1.1.
  The day/date mark is a separate fixedSize view beside the name (TaskRowCard.swift:345, HStack with titleText), so it
  takes its width from every line of the name. stacksIcons (TaskRowCard.swift:731) instead adds the day label to
  titleWords as one more word. With edit mode's 4 icons the name column is ~50pt. 1.1 FIX: in stacksIcons subtract the
  mark's measured width (+8 spacing) from besideIcons (or compare widest word + mark width); add a UI test like
  testGoalRowLayout for a day-marked task in card edit mode.
- M2 New tasks "late" the moment they're made on a weekend: BY DESIGN per rule, but 3 of 5 testers hit it (Sam, Dev, Marcus).
- M3 Smart Add "Until …? Set Date" note gone after relaunch: notes are transient (4s); BY DESIGN.
- M4 About 1.0.3 vs What's New 1.1: EXPECTED, bump pending.
- M5 Today pill hides late tasks: BY DESIGN (filter = that day + no-day). Strong 1.2 idea: include late.
- M6 "on Monday" stripped but bare "Sunday" kept: BY DESIGN (cleanTitle keeps bare day names: "Friday team lunch").
  2 testers (Sam "by Thursday", Marcus "Call mom Sunday"/"Call dentist Tuesday") wanted it stripped. Idea: strip a bare
  day name at the END of the text only.
- M7 Bottom bar covers cards in card edit mode: moot (no cross-card drag yet).
- M8 Ignored taps after animation: low confidence, overloaded Mac. Not checked.
- Rules gap: "Gym Mon Wed Fri" (no commas) not recognized; "Mon, Wed, Fri" is. weekdayList (ParsedTask.swift:405)
  needs a separator (comma, and, &, /), not plain spaces. Small 1.2 rules fix.

## Riley
- R1 Repeating hint "Comes back every week, unchecked" while a repeating list keeps its checks: CONFIRMED copy bug.
  Behaviour is deliberate since d4016f8 (2026-10-18, "A repeating list comes back next week with checked items still
  checked"); resetRecurringTask keepsItems (ChecklistStore.swift:1396). The hint is generic (Models.swift:33,
  SyncMode.hint) and is shown for lists too. 1.1 COPY FIX: for a list, "Comes back every week, checks kept" (or
  similar). 1.2 idea: "Uncheck All" on a list (and/or a per-list "reset items each week"), keeping the user's default.
- R2 No notification permission prompt: NOT A BUG in this test. -isolatedDataID counts as throwaway data
  (ChecklistStore.swift:194), which never asks or schedules (by design, CLAUDE.md Expiration). Real builds ask the
  first time a date is set.
- R3 About 1.0.3: EXPECTED.
- R4 Accidental day filter: low confidence, not checked.
- R5 Sticky Add placeholder ("Add List", "Add Carry-Over Task"): BY DESIGN (sticky per card).
- R6 "Week of November 30" twice in Go to Week: a week spanning two months shows in both month grids; likely by design.
- Strong signals: One-Time default makes unfinished to-dos "silently drop off" (Riley); Until = gone (Riley, Elena, Marcus, Sam).

## Jordan
- J1/J3 "Thursday" on Saturday → past Thursday, "late"; repeating Tue task "late" at birth: BY DESIGN (same as S3/M2).
  Now 4 of 6 testers (Sam, Dev, Marcus, Jordan).
- J2 Set Date suggestion vanishes on the next add: BY DESIGN (transient note, M3). 2 testers lost a date this way.
- J4 First pin tap in edit mode didn't take: low confidence (overloaded Mac, edit icons still running out). Not checked.
- J5 Tapping "Thu · late" chip on a wrapped title opened rename: LIKELY TEST ARTIFACT. The "Change day of …" button's
  accessibility frame is {62.7, 477.3, 197×88}, covering the whole wrapped title; XCUITest taps the frame's centre,
  which is on the name. A finger on the chip works (Elena, one-line title). Worth a look: the oversized frame also
  gives Voice Control/Switch Control a misleading target.
- J7 "Take / out / trash" in card edit mode: SAME ROOT CAUSE as M1 (day mark beside the name, not counted). CONFIRMED.
- J8 Bottom bar (Done's green tint) shows through the Add Category sheet: iOS 26 glass sheet at partial height;
  cosmetic. Check on phone.
- J9 Past-day pills green on a fresh install read as "done": BY DESIGN (WeekDayStrip: past days green like Save Goal).
  2 testers (Jordan, Riley) misread them. Design question.
- J10 About 1.0.3: EXPECTED. J11 no permission prompt: NOT A BUG in test (throwaway data, see R2).
- Default One-Time drops unfinished tasks on Monday: Jordan + Riley flagged as scary.
