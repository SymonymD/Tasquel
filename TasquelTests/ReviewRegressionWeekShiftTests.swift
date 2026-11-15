//
//  ReviewRegressionWeekShiftTests.swift
//  TasquelTests
//
//  Regression review after the 2026-11-15 fixes: what fix 1 (`keepDatesAfterWeekShift`)
//  could disturb. America/New_York, the store's own clock. Each test asserts what should
//  happen and prints REVIEW lines with what it saw.
//

import Testing
import Foundation
@testable import Tasquel

private func regressionDirectory() -> URL {
    let url = FileManager.default.temporaryDirectory.appending(path: "ReviewRegression-\(UUID().uuidString)")
    try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

@MainActor
private func regressionStore(_ clock: TestClock, directory: URL = regressionDirectory(),
                             defaults: UserDefaults? = nil) -> ChecklistStore {
    let defaults = defaults ?? UserDefaults(suiteName: "ReviewRegression-\(UUID().uuidString)")!
    return ChecklistStore(directory: directory, defaults: defaults, now: { clock.now }, calendar: { clock.calendar })
}

private func day(_ y: Int, _ m: Int, _ d: Int) -> DayKey { DayKey(year: y, month: m, day: d) }

@MainActor
private func found(_ store: ChecklistStore, _ title: String) -> [(week: DayKey, card: String, task: ChecklistTask)] {
    store.weeks.flatMap { week in
        week.categories.flatMap { card in card.tasks.filter { $0.title == title }.map { (week.startDay, card.name, $0) } }
    }
}

@MainActor
private func weekDays(_ clock: TestClock, plus days: Int) -> Date {
    clock.calendar.date(byAdding: .day, value: days, to: clock.now)!
}

@MainActor @Suite(.serialized)
struct ReviewRegressionWeekShiftTests {

    /// Finding: a pinned one-time day task moved by the switch keeps its pin, and the card it
    /// lands in already has two: three pinned tasks in one card (the limit is two;
    /// `moveToItsDatesWeek` unpins for this reason, `keepDatesAfterWeekShift` doesn't).
    @Test("After a week-start switch a card never holds more than two pinned tasks")
    func switchNeverMakesAThirdPin() throws {
        let clock = TestClock(2026, 11, 15)  // Sunday, Monday starts
        let store = regressionStore(clock)
        let card = try #require(store.selectedWeek?.categories.first)
        for title in ["Groceries", "Dry cleaning"] {
            let id = try #require(store.addTask(categoryID: card.id, title: title, mode: .oneTime))
            store.setTaskPinned(categoryID: card.id, taskID: id, pinned: true)
        }
        // Next week: a pinned one-time task for Wednesday (Nov 18).
        store.navigateToDate(weekDays(clock, plus: 7))
        let next = try #require(store.selectedWeek?.categories.first { $0.name == card.name })
        let vet = try #require(store.addTask(categoryID: next.id, title: "Call the vet", mode: .oneTime))
        store.setTaskDay(categoryID: next.id, taskID: vet, day: 4)
        let nextID = try #require(store.selectedWeek?.categories.first { $0.name == card.name }?.id)
        store.setTaskPinned(categoryID: nextID, taskID: vet, pinned: true)
        #expect(found(store, "Call the vet").first?.task.isPinned == true)
        store.navigateToDate(clock.now)

        store.setWeekStartsOnSunday(true)
        store.navigateToDate(clock.now)
        let current = try #require(store.selectedWeek?.categories.first { $0.name == card.name })
        let pinned = current.tasks.filter(\.isPinned).map(\.title)
        print("REVIEW: after the switch the current \(card.name) (week of \(store.selectedWeek!.startDay)) has pinned \(pinned); vet in \(found(store, "Call the vet").map { "\($0.week)" })")
        #expect(found(store, "Call the vet").map(\.week) == [day(2026, 11, 15)], "moved into the week holding Nov 18")
        #expect(pinned.count <= Category.maxPins, "at most two pinned tasks in a card")
    }

    /// Finding: Sunday starts, on a Sunday, a Just this week card's task for Wednesday (Nov 18).
    /// Switching to Monday starts makes the current week Nov 9–15, which ends today, and there's
    /// no card of that name next week, so the task stays in this week: shown for a Wednesday
    /// gone by, and gone tomorrow, before its day.
    @Test("A Just this week card's day task is still in front of you on its day after a switch to Monday starts")
    func justThisWeekDayTaskSurvivesSwitch() throws {
        let directory = regressionDirectory()
        let defaults = UserDefaults(suiteName: "ReviewRegression-\(UUID().uuidString)")!
        let clock = TestClock(2026, 11, 15)
        let store = regressionStore(clock, directory: directory, defaults: defaults)
        store.setWeekStartsOnSunday(true)
        #expect(store.selectedWeek?.startDay == day(2026, 11, 15))
        store.addCategory(name: "Trip", symbol: "airplane", thisWeekOnly: true)
        let trip = try #require(store.selectedWeek?.categories.first { $0.name == "Trip" })
        var parsed = ParsedTask(title: "Pack bags")
        parsed.day = 4  // Wednesday, Nov 18: ahead in a Sunday week
        parsed.mode = .oneTime
        let placed = try #require(store.placeParsedTask(parsed, categoryID: trip.id))
        #expect(placed.weekStart == day(2026, 11, 15))
        // A dated one in the same card, Friday Nov 20 (inside the Sunday week).
        let tickets = try #require(store.addTask(categoryID: trip.id, title: "Print tickets", mode: .oneTime))
        store.setTaskDate(categoryID: trip.id, taskID: tickets, lastDay: day(2026, 11, 20))
        // A regular card's task for the same day, for comparison: it goes to next week.
        let other = try #require(store.selectedWeek?.categories.first { $0.name != "Trip" })
        var errand = ParsedTask(title: "Return books")
        errand.day = 4
        errand.mode = .oneTime
        _ = try #require(store.placeParsedTask(errand, categoryID: other.id))

        store.setWeekStartsOnSunday(false)
        store.navigateToDate(clock.now)
        let after = found(store, "Pack bags")
        let start = try #require(store.selectedWeek?.startDay)
        let late = after.first.map { $0.task.isLate(inWeekStarting: $0.week, firstWeekday: Week.monday, today: store.currentDay) } ?? false
        print("REVIEW: after Sunday→Monday on a Sunday, Pack bags is in \(after.map { "\($0.week) \($0.card)" }) (current \(start)), late \(late), its day \(after.first.flatMap { $0.task.day(inWeekStarting: $0.week, firstWeekday: Week.monday) }.map { "\($0)" } ?? "-"); Return books in \(found(store, "Return books").map { "\($0.week)" })")
        #expect(found(store, "Return books").map(\.week) == [day(2026, 11, 16)], "a regular card's task went into next week")
        #expect(!late, "not shown late for a Wednesday that had gone by before it was ever meant for")

        // Monday: the next launch.
        clock.now = weekDays(clock, plus: 1)
        let monday = regressionStore(clock, directory: directory, defaults: defaults)
        let shown = monday.selectedWeek?.categories.flatMap(\.tasks).contains { $0.title == "Pack bags" } ?? false
        print("REVIEW: on Monday Nov 16 the current week (\(monday.selectedWeek!.startDay)) has Pack bags: \(shown); cards \(monday.selectedWeek!.categories.map(\.name))")
        #expect(shown, "still in front of you in the week holding Wednesday the 18th")
        let ticketsShown = monday.selectedWeek?.categories.flatMap(\.tasks).contains { $0.title == "Print tickets" } ?? false
        print("REVIEW: on Monday, Print tickets (until Nov 20) in the current week: \(ticketsShown); in \(found(monday, "Print tickets").map { "\($0.week)" }); reminders \(monday.expiryReminders.map(\.title))")
        #expect(ticketsShown, "a task dated Friday the 20th is there until then")
    }

    @Test("Checked: switching Monday → Sunday → Monday on a Sunday puts a day task and a dated task back where they were")
    func switchBackAndForthRoundTrips() throws {
        let directory = regressionDirectory()
        let defaults = UserDefaults(suiteName: "ReviewRegression-\(UUID().uuidString)")!
        let clock = TestClock(2026, 11, 15)
        let store = regressionStore(clock, directory: directory, defaults: defaults)
        let card = try #require(store.selectedWeek?.categories.first)
        var gym = ParsedTask(title: "Gym")
        gym.day = 5  // Thursday: gone by, so next week (Nov 19)
        _ = try #require(store.placeParsedTask(gym, categoryID: card.id))
        let id = try #require(store.addTask(categoryID: card.id, title: "Dentist", mode: .oneTime))
        store.setTaskDate(categoryID: card.id, taskID: id, lastDay: day(2027, 1, 14))
        let far = try #require(found(store, "Dentist").first?.week)
        #expect(far == day(2027, 1, 11))
        let reminders = store.expiryReminders.map(\.id)
        let marksBefore = store.calendarMarks(weekStartingOn: far)
        let editTimes = store.categoryEditTimes

        store.setWeekStartsOnSunday(true)
        store.navigateToDate(clock.now)
        print("REVIEW: Sunday starts: Gym \(found(store, "Gym").map { "\($0.week)" }), Dentist \(found(store, "Dentist").map { "\($0.week)" })")
        #expect(found(store, "Gym").map(\.week) == [day(2026, 11, 15)])
        #expect(found(store, "Dentist").map(\.week) == [day(2027, 1, 10)])
        #expect(store.calendarMarks(weekStartingOn: day(2027, 1, 10))[day(2027, 1, 14)] != nil, "Go to Week marks the date")
        #expect(store.expiryReminders.map(\.id) == reminders, "the same reminder")
        #expect(store.categoryEditTimes == editTimes, "the move isn't a card edit")

        store.setWeekStartsOnSunday(false)
        store.navigateToDate(clock.now)
        let gymAfter = found(store, "Gym")
        print("REVIEW: back to Monday: Gym \(gymAfter.map { "\($0.week)" }), Dentist \(found(store, "Dentist").map { "\($0.week)" })")
        #expect(gymAfter.map(\.week) == [day(2026, 11, 16)])
        #expect(gymAfter.first?.task.day(inWeekStarting: day(2026, 11, 16), firstWeekday: Week.monday) == day(2026, 11, 19))
        #expect(found(store, "Dentist").map(\.week) == [far])
        #expect(store.calendarMarks(weekStartingOn: far) == marksBefore)
        #expect(store.categoryEditTimes == editTimes)

        let relaunched = regressionStore(clock, directory: directory, defaults: defaults)
        #expect(found(relaunched, "Gym").map(\.week) == [day(2026, 11, 16)], "kept after a relaunch")
        #expect(found(relaunched, "Dentist").map(\.week) == [far])
    }

    @Test("Checked: on a Wednesday, Monday → Sunday starts moves next week's Sunday task into the week holding Nov 22")
    func weekdaySwitchMovesSundayTask() throws {
        let clock = TestClock(2026, 11, 11)  // Wednesday, Monday starts
        let store = regressionStore(clock)
        store.navigateToDate(weekDays(clock, plus: 7))
        let card = try #require(store.selectedWeek?.categories.first)
        let id = try #require(store.addTask(categoryID: card.id, title: "Brunch", mode: .oneTime))
        store.setTaskDay(categoryID: card.id, taskID: id, day: 1)  // Sunday Nov 22
        let carry = try #require(store.selectedWeek?.categories.first.flatMap { c in
            store.addTask(categoryID: c.id, title: "Laundry", mode: .carryOver) })
        _ = carry
        store.navigateToDate(clock.now)
        store.setWeekStartsOnSunday(true)
        store.navigateToDate(clock.now)
        let after = found(store, "Brunch")
        print("REVIEW: Brunch after the switch: \(after.map { "\($0.week)" }); Laundry \(found(store, "Laundry").map { "\($0.week)" })")
        #expect(after.map(\.week) == [day(2026, 11, 22)])
        #expect(after.first?.task.day(inWeekStarting: day(2026, 11, 22), firstWeekday: Week.sunday) == day(2026, 11, 22))
        // Laundry stays in its week; the week of Nov 22, saved for Brunch, holds its carried copy.
        let laundry = found(store, "Laundry")
        #expect(laundry.filter { $0.week == day(2026, 11, 15) }.count == 1, "a carry-over task isn't moved or doubled")
        #expect(laundry.filter { $0.week != day(2026, 11, 15) }.allSatisfy { $0.task.carriedFrom != nil }, "later ones are its copies")
    }
}
