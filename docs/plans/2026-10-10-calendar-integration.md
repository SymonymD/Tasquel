# Calendar Integration — Plan

**Status:** Implemented 2026-10-10 (phases 1–3, event details, refresh, docs; uncommitted). Not yet done: profiling the pager with many events, a pass on a real device with real accounts.
**Goal:** Show the week's calendar events inside Tasquel, so planning the week's tasks happens alongside what's already scheduled.

## Decisions (made 2026-10-10)

| Question | Decision |
|---|---|
| How events appear | A **read-only "This Week's Events" card** in the grid. Events are never copied into tasks; the calendar stays the source of truth. |
| Writing to the calendar | **Read only.** Tasquel never creates, edits, or deletes events. |
| Calendar sources | **Every calendar on the device** via Apple's EventKit (iCloud plus Google, Exchange, Outlook accounts added in iOS Settings). **The user picks which calendars to include.** |
| Pricing | **Decide later.** The feature is built behind one access check so it can become a paid unlock without restructuring. |

## User Experience

### Turning it on (Settings)
The existing "Calendar Integration · Coming Soon" row becomes a working section:

1. **Show Calendar Events** toggle. Turning it on the first time shows the iOS permission prompt (with Tasquel's explanation text).
2. Once allowed, a **Calendars** list grouped by account (iCloud, Gmail, …), each with its color dot and a checkmark. Preselected: the user's own calendars; **not** preselected: Birthdays, holiday calendars, and other subscribed calendars, which tend to crowd the view.
3. If permission was denied: an explanation and an **Open Settings** button (iOS only lets the app ask once).

### The events card
- Sits **first in the grid** (top left), so the week's commitments are seen before tasks. Uses the same card look, theme support (including retro), and expand/collapse animation as category cards.
- **Collapsed:** calendar icon, "Events", the week's event count, and the next upcoming event (or "No events this week").
- **Expanded:** events grouped by day, Monday–Sunday. Each event shows its time (or "All day"), title, and calendar color. Days with no events are omitted; today is highlighted.
- **Tap an event** to see its details in Apple's standard read-only event view (EventKitUI), with the location, notes, and attendees, without leaving the app.
- Works for **any week**, past, current, or future, and during week swiping (neighbor weeks show their events too).
- Not part of edit mode: no remove badge, can't be renamed or deleted. It's hidden by turning the Settings toggle off.

### Privacy
- Event data is read on demand and kept **in memory only**; it's never written to `checklist.json`/`settings.json` or anywhere else.
- Only the chosen calendar IDs and the on/off setting are saved.

## Technical Design

### Permission (iOS 17+ EventKit model)
- Reading events requires **full access**: `EKEventStore.requestFullAccessToEvents()`.
- Add the Info.plist text via build settings: `INFOPLIST_KEY_NSCalendarsFullAccessUsageDescription = "Tasquel shows your calendar events alongside your weekly tasks. Events stay on your device and are never changed."`
- States to handle: not determined, full access, denied, restricted (e.g., Screen Time), and write-only (granted to an earlier build; treat as "needs full access").

### `CalendarService` (new file `Tasquel/CalendarService.swift`)
- `@Observable` on the main actor; owns one `EKEventStore`.
- Exposes: `authorization`, `requestAccess()`, `availableCalendars` (grouped by source), and `events(forWeekStarting:) -> [WeekDayEvents]`.
- **Fetching** uses `predicateForEvents(withStart:end:calendars:)` for Monday 00:00 → next Monday 00:00 in the user's time zone. `events(matching:)` is synchronous, so it runs off the main thread and results are cached **per week** (the pager shows three weeks at once).
- **Refresh:** clear the cache on `EKEventStoreChanged` (events edited in Calendar), on returning to the foreground, and when the calendar selection changes.
- **Behind a protocol** (`EventProviding`) with an EventKit implementation and a fake one, so unit tests and UI tests don't depend on the simulator's real calendar. UI tests switch to the fake with a launch argument.

### Bucketing events into days (pure functions, unit-tested)
- Timed events → the day they start.
- **All-day events** → each day they cover within the week.
- **Multi-day timed events** → each day they overlap, labeled e.g. "Until 3 PM" / "Continues".
- Events that started before Monday or end after Sunday appear only on the days inside the week.
- Sort: all-day first, then by start time; stable tie-break by title.

### Settings persistence
Add to the `Settings` struct in `ChecklistStore` as **optional** fields so existing `settings.json` files still decode (the same pattern as `retroColor`):
- `calendarEventsEnabled: Bool?` (nil → off)
- `selectedCalendarIDs: [String]?` (nil → preselection not yet made)

Calendar IDs (`calendarIdentifier`) can change after an account re-sync; unknown IDs are ignored, and a calendar that disappears is simply dropped from the selection.

### Grid integration
- The grid currently lays out only category cards (`CategoryGridEntry`). Generalize the entry to `.events` or `.category(Category)` so the events card shares the layout, expand/collapse spring, `zIndex` handling, Expand All/Collapse All, and pager.
- Expansion keys: add an `.events` case alongside `CategoryLayoutKey` so the card's open state survives week changes like category cards.
- The card is a new `CalendarEventsCard` view reusing `CategoryGridCard`'s shared-header approach (the smooth resize and cross-fade work done on 2026-10-05).

### Paywall readiness
- A single `FeatureAccess.isCalendarUnlocked` (always `true` for now) gates the Settings toggle and the card. Adding StoreKit later only changes this check and adds a purchase screen.

## Implementation Phases

Each phase ends with a build, unit tests, and a check on the simulator/phone.

1. **Service and data (no UI).** `EventProviding`, the EventKit and fake providers, day bucketing, the settings fields with backward-compatible decoding, and the Info.plist text. Unit tests: bucketing edge cases (all-day, multi-day, crossing Monday/Sunday, time-zone/DST week), decoding old settings, selection persistence.
2. **Settings section.** Toggle, permission flow (including denied → Open Settings), calendar picker grouped by account with sensible defaults.
3. **Events card.** Collapsed/expanded card, first in the grid, themes including retro, empty state, accessibility labels, works in the week pager. UI tests using the fake provider.
4. **Details and refresh.** Tap → EventKitUI details sheet; refresh on calendar changes and foregrounding; profile the pager with three weeks of events (keep swiping smooth; see the 2026-10-09 performance work).
5. **Docs.** Help sheet entry, `CLAUDE.md`/`AGENTS.md`, recap.

## Testing Notes
- Simulator permission can be granted without the prompt: `xcrun simctl privacy <device> grant calendar com.symonym.Tasquel`.
- Real-calendar behavior (Google/Exchange accounts, Birthdays, recurring events, DST weeks) needs a pass on the phone.
- Run simulator UI tests only with the user's go-ahead (they interfere with Xcode previews).

## Open Questions (implemented with these defaults; revisit any time)
1. **Card position:** always first in the grid.
2. **Collapsed card content:** up to five upcoming events (the rest of this week; the first few for other weeks).
3. **Default selection:** the user's own calendars; Birthdays, holidays, and other subscribed calendars excluded. If every saved calendar disappears, the default is used again.
4. **Past weeks:** show their events.
5. **Onboarding:** not mentioned yet; Settings and the Help sheet cover it.

## Revision (2026-10-10, same day)
At the user's request the Events **card** was replaced: events now live in the **bottom bar**. A calendar toggle next to Settings (shown once calendar events are on) expands the bar to list the viewed week's events by day; tapping an event opens the Calendar app at its date (`calshow:`; iOS can't open a specific event). The in-app details sheet was dropped. The rest of the design (service, permission, picker, privacy, paywall gate) is unchanged.

## As Built
- `Tasquel/CalendarService.swift`: `FeatureAccess`, value types, `EventProviding` (EventKit + test fake), `EventGrouping.days`, `CalendarService` (permission, calendars, per-week cache, `effectiveSelection`).
- `Tasquel/CalendarSettings.swift`: Settings rows and the calendar picker.
- `Tasquel/CalendarEventsPanel.swift`: the events list shown in the expanded bottom bar.
- Test launch arguments: `-fakeCalendar` (sample events) and `-isolatedData` (throwaway storage). `CalendarUITests` uses both.
