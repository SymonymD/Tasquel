@preconcurrency import EventKit
import Foundation
import Observation
import SwiftUI

// MARK: - Feature Access

/// Single gate for calendar integration, so it can become a paid unlock later
/// without restructuring (see docs/plans/2026-10-10-calendar-integration.md).
enum FeatureAccess {
    static let isCalendarUnlocked = true
}

// MARK: - Value Types

/// A calendar event as Tasquel needs it. Read-only and never persisted.
struct CalendarEvent: Identifiable, Equatable, Sendable {
    /// Event identifier plus start time, so each occurrence of a recurring event is distinct.
    let id: String
    let eventIdentifier: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let calendarID: String
    let color: Color
}

/// A calendar the user can choose to include.
struct CalendarInfo: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let sourceTitle: String
    let color: Color
    /// Birthdays, holidays, and other subscribed calendars: left out of the default selection.
    let isSubscribed: Bool
}

enum CalendarAuthorization: Equatable, Sendable {
    case notDetermined
    case authorized
    case denied
    case restricted
    /// Granted to an earlier build that only asked to add events; reading needs full access.
    case writeOnly
}

// MARK: - Providers

/// Where events come from: EventKit in the app, a fake in tests.
protocol EventProviding: AnyObject, Sendable {
    func authorization() -> CalendarAuthorization
    func requestAccess() async -> Bool
    func calendars() async -> [CalendarInfo]
    func events(from start: Date, to end: Date, calendarIDs: Set<String>) async -> [CalendarEvent]
    /// Called (on any thread) when the underlying calendar data changes.
    func observeChanges(_ onChange: @escaping @Sendable () -> Void)
}

/// Reads from the device's calendars. All event-store access happens on one serial
/// queue, so fetching never blocks the main thread.
final class EventKitProvider: EventProviding, @unchecked Sendable {
    private let store = EKEventStore()
    private let queue = DispatchQueue(label: "com.symonym.Tasquel.calendar")
    private var observer: NSObjectProtocol?

    func authorization() -> CalendarAuthorization {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .notDetermined: .notDetermined
        case .fullAccess: .authorized
        case .writeOnly: .writeOnly
        case .restricted: .restricted
        case .denied: .denied
        @unknown default: .denied
        }
    }

    func requestAccess() async -> Bool {
        (try? await store.requestFullAccessToEvents()) ?? false
    }

    func calendars() async -> [CalendarInfo] {
        await withCheckedContinuation { continuation in
            queue.async { [self] in
                let infos = store.calendars(for: .event).map { calendar in
                    CalendarInfo(
                        id: calendar.calendarIdentifier,
                        title: calendar.title,
                        sourceTitle: calendar.source?.title ?? "Other",
                        color: Color(cgColor: calendar.cgColor),
                        isSubscribed: calendar.type == .birthday || calendar.type == .subscription
                            || calendar.source?.sourceType == .subscribed
                    )
                }
                continuation.resume(returning: infos)
            }
        }
    }

    func events(from start: Date, to end: Date, calendarIDs: Set<String>) async -> [CalendarEvent] {
        await withCheckedContinuation { continuation in
            queue.async { [self] in
                let calendars = store.calendars(for: .event).filter { calendarIDs.contains($0.calendarIdentifier) }
                guard !calendars.isEmpty else { return continuation.resume(returning: []) }
                let predicate = store.predicateForEvents(withStart: start, end: end, calendars: calendars)
                let events = store.events(matching: predicate).map { event in
                    CalendarEvent(
                        id: "\(event.eventIdentifier ?? UUID().uuidString)@\(event.startDate.timeIntervalSinceReferenceDate)",
                        eventIdentifier: event.eventIdentifier ?? "",
                        title: event.title ?? "Untitled",
                        start: event.startDate,
                        end: event.endDate,
                        isAllDay: event.isAllDay,
                        calendarID: event.calendar.calendarIdentifier,
                        color: Color(cgColor: event.calendar.cgColor)
                    )
                }
                continuation.resume(returning: events)
            }
        }
    }

    func observeChanges(_ onChange: @escaping @Sendable () -> Void) {
        observer = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged, object: store, queue: nil
        ) { _ in onChange() }
    }
}

/// Sample events relative to the current week, for UI tests (`-fakeCalendar`).
final class FakeEventProvider: EventProviding, @unchecked Sendable {
    func authorization() -> CalendarAuthorization { .authorized }
    func requestAccess() async -> Bool { true }

    func calendars() async -> [CalendarInfo] {
        [
            CalendarInfo(id: "home", title: "Home", sourceTitle: "iCloud", color: .blue, isSubscribed: false),
            CalendarInfo(id: "work", title: "Work", sourceTitle: "iCloud", color: .orange, isSubscribed: false),
            CalendarInfo(id: "birthdays", title: "Birthdays", sourceTitle: "Other", color: .gray, isSubscribed: true),
        ]
    }

    func events(from start: Date, to end: Date, calendarIDs: Set<String>) async -> [CalendarEvent] {
        let calendar = Calendar.current
        func at(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
            let date = calendar.date(byAdding: .day, value: day, to: start)!
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date)!
        }
        let all = [
            CalendarEvent(id: "standup", eventIdentifier: "standup", title: "Team Standup", start: at(0, 9, 30), end: at(0, 10), isAllDay: false, calendarID: "work", color: .orange),
            CalendarEvent(id: "dentist", eventIdentifier: "dentist", title: "Dentist", start: at(2, 15), end: at(2, 16), isAllDay: false, calendarID: "home", color: .blue),
            CalendarEvent(id: "trip", eventIdentifier: "trip", title: "Lake Trip", start: at(4, 0), end: at(6, 0), isAllDay: true, calendarID: "home", color: .blue),
            CalendarEvent(id: "bday", eventIdentifier: "bday", title: "Sam's Birthday", start: at(3, 0), end: at(4, 0), isAllDay: true, calendarID: "birthdays", color: .gray),
        ]
        return all.filter { calendarIDs.contains($0.calendarID) && $0.start < end && $0.end > start }
    }

    func observeChanges(_ onChange: @escaping @Sendable () -> Void) {}
}

// MARK: - Grouping by Day

/// One event as listed under a day.
struct DayEvent: Identifiable, Equatable {
    let event: CalendarEvent
    /// "All day", a start time, "Until 3 PM", or "Continues".
    let timeLabel: String
    var id: String { event.id }
}

struct EventDay: Identifiable, Equatable {
    let date: Date
    let events: [DayEvent]
    var id: Date { date }
}

enum EventGrouping {
    /// Groups a week's events into days (Monday–Sunday), skipping empty days.
    /// All-day and multi-day events appear on every day they cover within the week.
    nonisolated static func days(
        for events: [CalendarEvent],
        weekStart: Date,
        calendar: Calendar = .current,
        timeFormatter: (Date) -> String = { $0.formatted(date: .omitted, time: .shortened) }
    ) -> [EventDay] {
        (0..<7).compactMap { offset -> EventDay? in
            guard let dayStart = calendar.date(byAdding: .day, value: offset, to: weekStart),
                  let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return nil }
            let dayEvents = events
                .filter { $0.start < dayEnd && $0.end > dayStart }
                .map { event -> DayEvent in
                    let label: String
                    if event.isAllDay {
                        label = "All day"
                    } else if event.start >= dayStart {
                        label = timeFormatter(event.start)
                    } else if event.end < dayEnd {
                        label = "Until \(timeFormatter(event.end))"
                    } else {
                        label = "Continues"
                    }
                    return DayEvent(event: event, timeLabel: label)
                }
                .sorted { lhs, rhs in
                    let lhsAllDay = lhs.event.isAllDay || lhs.event.start < dayStart
                    let rhsAllDay = rhs.event.isAllDay || rhs.event.start < dayStart
                    if lhsAllDay != rhsAllDay { return lhsAllDay }
                    if lhs.event.start != rhs.event.start { return lhs.event.start < rhs.event.start }
                    return lhs.event.title < rhs.event.title
                }
            return dayEvents.isEmpty ? nil : EventDay(date: dayStart, events: dayEvents)
        }
    }
}

// MARK: - Calendar Service

/// Calendar permission, the list of calendars, and a per-week cache of events.
/// Event data lives only in memory.
@Observable
final class CalendarService {
    private(set) var authorization: CalendarAuthorization
    private(set) var availableCalendars: [CalendarInfo] = []
    /// Whether `availableCalendars` has been loaded since launch (or access changed).
    private(set) var hasLoadedCalendars = false
    /// Bumped whenever cached events are discarded; views reload when it changes.
    private(set) var generation = 0

    @ObservationIgnored let provider: EventProviding
    private var cachedWeeks: [CacheKey: [EventDay]] = [:]

    private struct CacheKey: Hashable {
        let weekStart: Date
        let calendarIDs: Set<String>
        let generation: Int
    }

    init(provider: EventProviding) {
        self.provider = provider
        authorization = provider.authorization()
        provider.observeChanges { [weak self] in
            Task { @MainActor [weak self] in self?.invalidate() }
        }
    }

    /// The provider for this launch: a fake for UI tests (debug builds only), otherwise EventKit.
    static func makeDefault() -> CalendarService {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-fakeCalendar") {
            return CalendarService(provider: FakeEventProvider())
        }
        #endif
        return CalendarService(provider: EventKitProvider())
    }

    var isAuthorized: Bool { authorization == .authorized }

    /// Asks for full calendar access if it hasn't been decided yet.
    func requestAccess() async {
        if authorization == .notDetermined || authorization == .writeOnly {
            _ = await provider.requestAccess()
        }
        refreshAuthorization()
        if isAuthorized { await loadCalendars() }
    }

    func refreshAuthorization() {
        authorization = provider.authorization()
    }

    func loadCalendars() async {
        guard isAuthorized else { availableCalendars = []; hasLoadedCalendars = false; return }
        availableCalendars = await provider.calendars()
            .sorted { ($0.sourceTitle, $0.title) < ($1.sourceTitle, $1.title) }
        hasLoadedCalendars = true
    }

    /// Default selection: the user's own calendars, not birthdays/holidays/subscriptions.
    var defaultSelection: [String] {
        availableCalendars.filter { !$0.isSubscribed }.map(\.id)
    }

    /// The saved selection limited to calendars that still exist (calendars can be
    /// deleted or accounts removed). Falls back to the default when none remain.
    func effectiveSelection(_ saved: [String]?) -> [String] {
        // Until the list has loaded, trust the saved selection rather than treating
        // every saved calendar as deleted (which left no calendars, so no events).
        guard hasLoadedCalendars else { return saved ?? [] }
        let available = Set(availableCalendars.map(\.id))
        let kept = (saved ?? []).filter { available.contains($0) }
        return saved == nil || kept.isEmpty ? defaultSelection : kept
    }

    /// Cached days for a week, or nil if not loaded yet (call `load`).
    func days(forWeekStarting weekStart: Date, calendarIDs: Set<String>) -> [EventDay]? {
        cachedWeeks[CacheKey(weekStart: weekStart, calendarIDs: calendarIDs, generation: generation)]
    }

    /// Fetches and caches a week's events. Safe to call repeatedly.
    func load(weekStarting weekStart: Date, calendarIDs: Set<String>) async {
        let key = CacheKey(weekStart: weekStart, calendarIDs: calendarIDs, generation: generation)
        guard isAuthorized, cachedWeeks[key] == nil,
              let weekEnd = Calendar.current.date(byAdding: .day, value: 7, to: weekStart) else { return }
        let events = await provider.events(from: weekStart, to: weekEnd, calendarIDs: calendarIDs)
        guard key.generation == generation else { return }  // invalidated while loading
        cachedWeeks[key] = EventGrouping.days(for: events, weekStart: weekStart)
    }

    /// Drops cached events, e.g. after calendar changes or returning to the app.
    func invalidate() {
        cachedWeeks.removeAll()
        generation += 1
    }
}
