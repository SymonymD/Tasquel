#!/usr/bin/env python3
"""Fill the /applereview brief template once per reviewer for Tasquel 1.1."""
import re, pathlib

SKILL = pathlib.Path("/Users/johnfentner/.claude/skills/applereview/references")
W = pathlib.Path("/private/tmp/claude-501/-Volumes-T7-Design-JB-Portfolio-SYMONYM-Tasquel/3a12228a-12a9-4d7a-ac59-5b0e1bbb8e3b/scratchpad/applereview-2026-11-15")
REAL = "/Volumes/T7/Design/JB Portfolio/SYMONYM/Tasquel/Tasquel"
DIFF = W / "changes-since-1.0.3.diff"

template = (SKILL / "reviewer-brief.md").read_text().split("\n---\n", 1)[1].lstrip()
roles_md = (SKILL / "roles.md").read_text()

def role_text(heading):
    m = re.search(r"^## " + re.escape(heading) + r"\n(.*?)(?=^## |\Z)", roles_md, re.S | re.M)
    return m.group(1).strip().rstrip("-").strip()

def setup(tag):
    vals = {}
    for line in (W / f"setup-{tag}.txt").read_text().splitlines():
        if "=" in line:
            k, v = line.split("=", 1)
            vals[k] = v
    return vals

WHAT_CHANGED = f"""The full diff since the live version (1.0.3) is `{DIFF}` (your copy has no git history; 40 app files, about +6,000 lines). The user-facing list is `Tasquel/WhatsNew.swift` in your copy. In a user's words:
1. **Days for tasks:** the type/mode popup has a Day row (Any, then one letter a day). A task with a day shows "Fri" after its name; on its day "Today" (green); once its day has gone by unfinished in this week, "Tue · late". Tasks sort by day within a card. The day strip under the week title shows each day's date (today green, past days blue); tapping a day pill filters every card to that day's tasks plus those with no day ("Thursday and tasks with no day · Show All"); today's pill also shows late tasks. Cards holding today's unchecked tasks wiggle once when the app opens (not with throwaway data).
2. **A day that has gone by:** a *new* task given a weekday already past this week goes into **next week's** card of the same name on that day. The screen then pages to next week, a pop-up says "Added to next week" (OK / Back to This Week), and that card shows a note with Undo. An *existing* task given a past day stays put and isn't marked late.
3. **Dates:** a calendar cell at the end of the popup's Day row ("Until"), and in a card's own edit mode a clock that replaces the type/mode button ("Expires", Date | Week). A task is gone the day after its date; its checkbox becomes a ring filling green as the days pass; a reminder notification comes at 9 AM the day before (Settings ▸ Reminders ▸ Expiration Reminders). **A one-time task dated after its week moves into its date's week** (pop-up "Moved to the week of …"); a carry-over one carries until then; a repeating one repeats until then. Dated rows show "Nov 28". A day and a date are one choice for one-time and carry-over tasks. Go to Week rings days with dated tasks (purple) and day tasks (green).
4. **Smart Add** (✨ only; Return adds text as typed): written dates ("dentist december 15" adds the task and offers "Until Tue, Dec 15?  Set Date", which stays until answered); "by / due / until / till / before <date>" makes it Carry Over; "today", "tomorrow", a day at the end ("Call mom Sunday"), "remind me to" is dropped, "twice this week", "Gym Mon Wed Fri"; parts joined by commas / and / then become a list named by the first part ("Go to the zoo and harass penguins"); with List picked first, the parts are the list's name and items; numbers that name things stay ("Exam 3"). The "Added … · Undo" note lasts 8 s.
5. **Pins:** up to two cards (in Edit, a pin at a card's top-leading corner) and two tasks a card (in the card's own edit mode, a pin between the type/mode button and the trash). Pinned ones show first, with a small orange pin; unpinned, they go back to their place.
6. **Duplicates:** tasks in one card (same day or both none) or items in one list with the same name get "⧉ Duplicate"; adding one shows a note with Undo.
7. **Renaming:** clearing a name and pressing Return deletes it (with Undo); Escape on a hardware keyboard cancels a rename.
8. **Card ring** counts goal progress and checked list items.
9. **Card edit mode:** the clock, pin, trash and handle run out one after another; the old "This week only" switch is now a "◯ / ✓ Just this week" chip on the Completed line, and the line says "· Just this week".
10. **Edit mode and Add Category:** the Add Category tile is first (top left); the sheet stays open after an add ("Added X · add another, or tap Done"); Create New has a "Just this week" toggle above Cancel / Add Category, off each time; Saved Categories has Edit / Done beside its heading, a green + on rows you can add, and "Removed X" after a removal.
11. **Bottom bar:** on another week a green house grows out of the week selector's glass and goes back to this week (left of the selector on later weeks, at Edit's place on earlier ones).
12. **Header:** a "What's New?" pill slides out from behind the Tasquel mark for people who updated (twice, then gone); What's New is also in Settings ▸ Help. Holiday marks on the Tasquel mark (Thanksgiving feathers and a turkey that runs out once per app open in Thanksgiving week; string lights; confetti).
13. **Looks:** Settings ▸ Appearance ▸ Seasonal (colors and backdrop by season, light and dark); Retro text fields look like DOS (bracket frames, underscore cursor).
14. **Help** is in tabs (Q&A first, then Weeks, Cards, Tasks, Types, Modes, Dates), as pills over swipeable pages.
15. **iPad landscape (4 columns):** an open card takes half the width, in two lanes.
16. **Goal editor:** a Unit row when a custom unit doesn't fit; an orange "Already 8 of 7: saving marks it done" line.
17. **Order holds while you work:** a card's task order doesn't change while Add Task is in use or a task's popup is open; then tasks move into place.
18. **Speed:** scrolling, opening cards and checking tasks are much faster. Weeks before you started show no cards; past weeks no longer have a "Past week · view only" banner.
19. **Later weeks:** renaming next week's copy of a task changes only its name; picking a task's mode in the popup brings back a copy deleted from later weeks.

Saved data changed: new task fields `hasOwnTitle`, `isPinned`, `expiresOn`, `expirySetOn`, `expiresWithWeek`, `dayOfWeek`, `daySetOn`; a category's `isPinned`; settings.json `remindsBeforeExpiry` and the appearance value `seasonal`; UserDefaults `lastLaunchedVersion` and `whatsNewButtonOpens`. Data saved by 1.0.3 has none of them."""

APP_SUMMARY = """Tasquel is a weekly checklist for iPhone and iPad (iOS 26). Each week holds categories, shown as cards in a grid (two columns on iPhone, three or four on iPad); a card opens to full width to show its tasks. Tasks have a type (checkbox with sub-tasks, goal with a target and −/+ steps, or list with items) and a mode (Carry Over: moves to next week until done; Repeating: every week; One-Time: never carries), and now optionally a day and a date. Weeks page by swiping sideways or with the arrows of the week selector in the bottom bar; past weeks are view only; future weeks are previews until edited and follow the week before. There's Smart Add (Apple Intelligence reads a typed task), calendar events for the week, themes (System, Light, Dark, Retro with colors, Seasonal), Settings, Help, What's New, a welcome tour and onboarding. iPhone is portrait only; iPad turns every way. Everything is stored on the device.

**Today is Sunday, 2026-11-15.** Weeks start on Monday by default (Settings ▸ Week), so today is the last day of the week of Nov 9 and every other weekday this week has already gone by: a new task given Monday–Saturday goes into next week (by design, item 2 above). With Sunday as the week's start, today is the first day instead. `-demoData -demoToday 2026-11-11` makes a Wednesday today, for a mid-week view. Thanksgiving week is Nov 23–29 (Monday start); `-demoTurkey` shows it on any day."""

def spec_files(copy):
    return (f"`{copy}/CLAUDE.md` (the full spec: read \"Key behaviors\" and \"UI Patterns\" plus everything about your area; it's long and dense), "
            f"`{copy}/Tasquel/HelpSheet.swift` (the in-app Help, which is what users are told) and `{copy}/Tasquel/WhatsNew.swift` (what updaters are told is new)")

NEVER_TAP = """  - **Settings ▸ Feature Ideas ▸ Send Anonymously** (in Retro: "> Send"). It posts to the live survey server (`https://jbfentner.com/tasquel/survey`). Ticking boxes and typing a comment are fine; never send.
  - On the live website pages that Settings ▸ Support and Privacy open in Safari: reading is fine, but never submit anything there.
  - There's no StoreKit, mail or sharing. EventKit only reads. Notification permission prompts are fine to answer in your own simulator."""

SIM_LIMITS = """- **Simulator limits:** Apple Intelligence isn't in the simulator: test Smart Add with `-smartAddRules` (the rules the app applies after the model; real wording quality is a phone check). Haptics can't be felt. Calendar access: prefer `-fakeCalendar`. Your simulators run iOS 26.3; the user's phone runs iOS 27.2, which can differ in animation timing. Animations (the house, the What's New pill, the turkey, the edit-mode icons) can't be seen by XCUITest: record the simulator (`xcrun simctl io <UDID> recordVideo`) and look at frames if you need to.
- **Throwaway data turns some things off on purpose:** with `-isolatedData`, `-isolatedDataID` or `-demoData` there's no "Today" pulse, no opening card wiggle, no turkey (unless `-demoTurkey`), and no reminder scheduling or notification prompt, so XCUITest can settle. To check those, launch without those flags (your simulator is fresh, so nothing real is at risk) and reset with `xcrun simctl uninstall <UDID> com.symonym.Tasquel`."""

LAUNCH_ARGS = """Debug builds only. From the spec (CLAUDE.md ▸ Testing Launch Arguments):
- `-isolatedData`: throwaway storage, fresh on every launch, onboarding first. `launchFresh` (in `TasquelUITests/GoalUITests.swift`) taps through onboarding.
- `-isolatedDataID <name>`: the same throwaway storage across launches. **Use it for relaunch checks.** Open cards aren't remembered across launches (by design), so open the card again after a relaunch.
- `-demoData`: throwaway storage, no onboarding, the current week filled with sample tasks (Errands has a Groceries list; "Plan Mom's birthday" expires in four days). `-demoAppearance <system|light|dark|retro>`, `-demoFirstCard <name>` (that card first), `-demoToday yyyy-MM-dd` (that day is today by the store's clock; only with `-demoData`).
- `-fakeCalendar`: sample calendar events instead of the real calendar.
- `-smartAddRules`: Smart Add without the model (2 s pause; `-smartAddDelay <seconds>` changes it).
- `-demoWhatsNew`: the header's What's New pill as if just updated. `-demoTurkey`: any day is Thanksgiving week for the turkey. `-demoHoliday <thanksgiving|holidaySeason|newYear>`: that holiday mark. `-demoSeason <spring|summer|fall|winter>`: that season for Seasonal.

Useful in the UI tests: `app.addTaskField` (`TasquelUITests/AddTaskField.swift`) taps a card's + and returns the Add task field. Closed cards are buttons labeled "Open <Card>, …". A task's options button is "Task options: <Type>, <Mode>". Checkboxes are "Complete <title>" / "Mark <title> incomplete". A list's chevron has the identifier "Fold <list title>". New identifiers: day pills "Day Thursday", the day strip "Week days", "Just this week chip", "Pin <card or task>", "Expiration <task>", the bar's house "Bar Back to This Week", the moved pop-up's "Moved OK" and "Moved Back to This Week". The existing files in `TasquelUITests/` (CardStateUITests, AddTaskUITests, SmartAddUITests, ThisWeekOnlyUITests, BottomBarUITests, CardOrderUITests) show many more patterns; read one or two before writing your own."""

ALREADY_KNOWN = """- The project still says version 1.0.3 (11); it becomes 1.1 (12) after this review. Don't report the version number.
- **iPad:** typing a task's words and then tapping its type/mode button adds the words at once as a checkbox (the button closes the keyboard first, and closing the keyboard adds what's typed), so the type picked applies to the next task. `CardStateUITests.testAddFieldSaysPickedType` fails on iPad for this. Known; you may note how it feels, but don't spend time on it.
- **iPhone SE at the largest text size:** the week arrows are 40pt (< 44) and the day strip is 347.75pt wide (> 343). Known.
- Left open from the 1.0.3 review: Match App Icon to Theme can fail silently; the Welcome Tour is plain system dark in every theme; turning Just this week on and straight off moves next week's own tasks.
- By design (the user's decisions; report only if it's broken, not because it's surprising): a new task for a weekday already gone by this week goes into next week; a one-time task dated after its week moves into its date's week; renamed later copies still leave with their source; card order is a snapshot that doesn't change while you use the cards; duplicates are flagged only within one card (and same day); Smart Add reads words only from the ✨ button; open cards aren't remembered across launches; deleting a task doesn't ask (Undo for 5 s); no swipe actions or long-press menus on tasks; a repeating list keeps its checks; typing a goal's Step recalculates its Target.
- Flaky UI tests under load: `GoalUITests.testReorderTasksByHandle` (drag timing) and `testEditGoalFieldsFocusOnFirstTap`."""

IN_APP = {
"Everyday": """In this app, the journeys to run end to end:
- A card with a checkbox (with sub-tasks), a goal and a list. Give tasks days through the options' Day row and through Smart Add (`-smartAddRules`), dates through the Day row's calendar and the edit-mode clock (a date this week, one next week, one months away, as One-Time and as Carry Over), and follow each task: where it goes, what the pop-up and the card's note say, and whether Undo takes it back cleanly. Then page forward and back, use Go to Week, and relaunch (`-isolatedDataID`).
- Pin two cards and two tasks; try a third; unpin; check the order comes back.
- Tap day pills to filter; add a task while a filter is on; Show All.
- Add Category several times in one go (with and without Just this week), then the card's own Just this week chip on and off.
- Duplicates: add the same task twice, the same item twice; Undo the note.
- Clear a name and press Return; Undo.
Today being Sunday matters: try both a Monday and a Sunday week start (Settings ▸ Week).""",
"Settings": """In this app: every appearance (System, Light, Dark, Retro and each Retro color, and the new **Seasonal** with each `-demoSeason`, in light and dark) on the new parts: day pills with dates, the "Today" / "· late" marks, dated rows, pins, "⧉ Duplicate", the moved pop-up, the bar's house, the What's New pill and sheet (`-demoWhatsNew`), Help's tabs, the holiday marks (`-demoHoliday`, `-demoTurkey`), Retro's DOS text fields and underscore cursor, Add Category's new layout, the Just this week chip. Settings ▸ Reminders ▸ Expiration Reminders (the footer when notifications are off: deny the prompt in your simulator, then check; launch without throwaway data for this). Settings ▸ Week (Sunday/Monday start) with day tasks, dated tasks and pinned cards in this and later weeks. Sort Cards with pinned cards. Settings ▸ Help ▸ What's New in 1.1. Feature Ideas (open, tick, type; **never send**).""",
"IPad": """In this app: the new **landscape half-width lanes** (four columns: open cards take half the width in two lanes; open, close, open several, rotate, resize the window from wide to narrow and back, and check the cards don't jump, overlap or lose their place); the type/mode/day popup and its date calendar from rows at the top, middle and bottom of the screen, with and without the keyboard and a hardware keyboard; the moved pop-up ("Added to next week") and the paging that follows it; the bar's house on iPad (10pt from the selector on both sides); the What's New pill beside the window controls (`-demoWhatsNew`, in a resized window); Help's tabs in a narrow window; Escape on a hardware keyboard in a rename field (should put the old name back); Add Category in a sheet that stays open.""",
"Access": """In this app: the day pills (VoiceOver "Thursday, November 12"; today's full date; the filter line), "Today" / "late" as a name's value, the dated row's mark button, pins ("pinned" as value; the card pin badge's disabled reason once two are pinned), "duplicate" as value, the Just this week chip (is its state announced?), the moved pop-up (is it announced, can it be dismissed?), the bar's house (a clear button only while out), the What's New pill (44pt target, 9pt text), Help's tab pills (named as they read for Voice Control), Add Category's green + rows and the Edit Saved Categories button, the expiration ring (value "expires in 3 days, on …"), the goal editor's warning line. Contrast: today's green pill, past days' blue dates, `Theme.late` orange, the pin orange, the Seasonal palettes (each season, light and dark). Reduce Motion: no pulse, wiggle, turkey, house fly-out (it fades), pill spring. Largest text sizes: day and date marks with long names, the moved pop-up, Add Category, the goal editor's Unit row.""",
"Edge": """In this app: **time zones and week boundaries with the new days and dates** — a day task and a dated task made in New York, then relaunched in `Pacific/Kiritimati` (UTC+14, already Monday there: a new week) and `Pacific/Pago_Pago`; a task for a day gone by near the week's end; dates at month and year ends (Dec 31 → a week across the new year), a date years away, Feb 29; Smart Add dates ("12/31", "dec 31", "by friday", "tomorrow" on the week's last day, which is today); Sunday vs Monday week start with dated tasks. Long names beside "Tue · late", "Nov 28" and "⧉ Duplicate" on the SE; the moved pop-up and Add Category on the small screen with the keyboard up; 20+ categories with two pinned; a list of 100 items with duplicates. (The SE's largest-text arrows and strip are already known.)""",
"Code": f"""In this app: read the diff since the live version first (`{DIFF}`), especially `ChecklistStore.swift` (`placeParsedTask`, `addTask(_:toWeekStarting:categoryNamed:)`, `moveToItsDatesWeek`, `setTaskDate`, `setTaskDay`, `removeExpiredTasks`, `expiryReminders`, `catchUpSavedWeeks`, pins and `arriving`, `addedElsewhere`), `Models.swift` (the new task fields and their lenient decoding; `isLate`, `daySetOn`, `expiryCutoff`), `ParsedTask.swift` and `TypedDate` (Smart Add's words and dates, `clauses`, `dropInvented`), `ExpiryNotifications.swift`, `CategoryGridLayout.swift` (`halfWidthOpen`), `ContentView.swift` (`addedElsewhereFollower`, `reconcileBarHouse`, the house's timed steps, `isEditingTasks`), `WhatsNew.swift` and `showsWhatsNewButton`, and `ThanksgivingTurkey.swift`. Date logic is where this release is riskiest: DST weeks (Nov 1 and Mar 8 2026, Mar 14 and Nov 7 2027 in New York), year ends, a week-start switch with dated tasks, and time-zone changes with `daySetOn` / `expiresOn`. The App Review checklist is `/Users/johnfentner/.claude/skills/applereview/references/app-review-checklist.md` (notifications are new in this release: check the permission timing and the privacy manifest). Unit tests are Swift Testing in `TasquelTests/`; add yours as `TasquelTests/ReviewCode*.swift` (use a fixed `Calendar` and time zone; `TestClock` in TasquelTests.swift shows how, and `makeIsolatedStore` there is `private`, so write your own copy) and run them on your simulator with `-only-testing:TasquelTests`. Don't run the UI suite.""",
"Update": """In this app: the live version is 1.0.3 (11), on branch `release-1.0.3`. Saved data is `Documents/checklist.json` (all weeks and tasks) and `Documents/settings.json` in the app's data container, plus UserDefaults (the container's `Library/Preferences/com.symonym.Tasquel.plist`). A fresh simulator shows onboarding on the first launch without `-isolatedData`; go through it (the old copy's `TasquelUITests/GoalUITests.swift` has `launchFresh`). In 1.0.3, create: every type and mode, sub-tasks, a folded list, goal progress, a This week only card (1.0.3's switch in the card's edit mode), a reordered card, edits in next week (a renamed copy, a deleted repeating task), a deleted card, Retro or Dark, Sunday week start in one run and Monday in another. Then check in 1.1: everything is kept and means the same; tasks have no day, date or pin (and nothing shows "late" or "Duplicate" unless names really match); old same-named tasks in a card now show "⧉ Duplicate" (expected); the Just this week chip shows on for the This week only card and turning it off restores the modes; **the What's New pill appears for the updater** (launched without `-demoWhatsNew`: 1.0.3 left `didMigrateStarters_v1`), twice and then gone, and never on a fresh 1.1 install; `lastLaunchedVersion` is written; reminders aren't scheduled until a date is set. Also add a day, a date, a pin to old tasks and relaunch."""
}

ROLES = [
    ("Everyday", "Everyday flows"),
    ("Settings", "Settings and themes"),
    ("IPad", "iPad"),
    ("Access", "Accessibility"),
    ("Edge", "Edge cases and small screens"),
    ("Code", "Code review"),
    ("Update", "Update from the live version"),
]

for tag, heading in ROLES:
    s = setup(tag)
    copy, derived, shots = s["COPY"], s["DERIVED"], s["SHOTS"]
    sims = [v for k, v in s.items() if k.startswith("SIM_")]
    sim_text = ", ".join(f"`{u}` ({name})" for u, name in (x.split("|", 1) for x in sims))
    section = role_text(heading)
    if tag == "Update":
        section = (section.replace("{{OLD_REF}}", "release-1.0.3")
                          .replace("{{OLD_COPY}}", s["OLD_COPY"])
                          .replace("{{OLD_DERIVED}}", s["OLD_DERIVED"])
                          .replace("{{COPY}}", copy)
                          .replace("{{SHOTS}}", shots))
    section = "\n\n" + section + "\n\n" + IN_APP[tag]
    filled = template
    repl = {
        "APP_NAME": "Tasquel", "VERSION": "1.1", "TEAM_SIZE": "seven",
        "ROLE_NAME": heading, "ROLE_SECTION": section,
        "WHAT_CHANGED": WHAT_CHANGED, "FOCUS_LINE": "",
        "APP_SUMMARY": APP_SUMMARY, "SPEC_FILES": spec_files(copy),
        "COPY": copy, "DERIVED": derived, "SHOTS": shots, "SIMULATORS": sim_text,
        "REAL_PROJECT": REAL, "NEVER_TAP": NEVER_TAP, "SIMULATOR_LIMITS": SIM_LIMITS,
        "UITEST_FOLDER": "TasquelUITests", "ROLE_TAG": tag,
        "PROJECT_FLAG": "-project Tasquel.xcodeproj", "SCHEME": "Tasquel",
        "UITEST_TARGET": "TasquelUITests", "LAUNCH_ARGS": LAUNCH_ARGS,
        "TIPS_PATH": str(SKILL / "simulator-tips.md"), "ALREADY_KNOWN": ALREADY_KNOWN,
    }
    for k, v in repl.items():
        filled = filled.replace("{{" + k + "}}", v)
    left = re.findall(r"\{\{[A-Z_]+\}\}", filled)
    assert not left, (tag, left)
    out = W / tag / "brief.md"
    out.write_text(filled)
    print(tag, len(filled.split()), "words ->", out)
