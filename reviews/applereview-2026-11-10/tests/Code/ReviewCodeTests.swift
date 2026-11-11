//
//  ReviewCodeTests.swift
//  TasquelTests
//
//  Pre-ship code review (1.0.3). Each finding has its own test that asserts what should
//  happen, so it fails while the bug is there and passes once it's fixed. The other tests
//  cover what was checked and found fine.
//

import Testing
import Foundation
import SwiftUI
@testable import Tasquel

// MARK: - Helpers (copies of the private ones in TasquelTests.swift)

private func reviewTempDirectory() -> URL {
    let url = FileManager.default.temporaryDirectory.appending(path: "ReviewCode-\(UUID().uuidString)")
    try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func reviewStore(directory: URL = reviewTempDirectory(), clock: TestClock, defaults: UserDefaults? = nil) -> ChecklistStore {
    let defaults = defaults ?? UserDefaults(suiteName: "ReviewCode-\(UUID().uuidString)")!
    return ChecklistStore(directory: directory, defaults: defaults, now: { clock.now }, calendar: { clock.calendar })
}

private func card(_ store: ChecklistStore, _ name: String) -> Tasquel.Category? {
    store.selectedWeek?.categories.first { $0.name == name }
}

private func reviewRules(_ text: String) -> ParsedTask {
    TaskTextHints.refine(TaskTextHints.dropInvented(ParsedTask(title: text, mode: .oneTime), from: text), from: text)
}

// MARK: - Finding: edits made while This week only is on are undone when it goes off

/// Turning This week only off (or adding a carry-over/repeating task, which turns it off)
/// puts back each task's `isUserEdited` from before it was turned on (`restoreModes`), so
/// a change the user made to a copy in the meantime no longer counts as theirs: next sync
/// overwrites it with the source.
struct ReviewCodeThisWeekOnlyEditTests {
    private let clock = TestClock(2099, 3, 4)  // a Wednesday, New York
    private var nextWeek: Date { clock.weeks(1, from: clock.now) }

    @Test("A copy renamed while This week only is on keeps its name after it's turned off")
    func renameWhileThisWeekOnlySurvivesTurningItOff() throws {
        let store = reviewStore(clock: clock)
        store.addCategory(name: "Trip", symbol: "airplane")
        store.addTask(categoryID: card(store, "Trip")!.id, title: "Stretch", mode: .repeating)

        store.navigateToDate(nextWeek)
        let tripID = try #require(card(store, "Trip")?.id)
        store.setCategoryThisWeekOnly(tripID, true)
        let copy = try #require(card(store, "Trip")?.tasks.first)
        store.renameTask(categoryID: tripID, taskID: copy.id, newTitle: "Yoga")
        store.setCategoryThisWeekOnly(tripID, false)
        #expect(card(store, "Trip")?.tasks.map(\.title) == ["Yoga"])

        // Away and back: next week syncs with this week again.
        store.navigateToDate(clock.now)
        store.navigateToDate(nextWeek)
        print("REVIEW: rename after TWO off -> \(card(store, "Trip")?.tasks.map(\.title) ?? [])")
        #expect(card(store, "Trip")?.tasks.map(\.title) == ["Yoga"], "the user's rename is kept")
    }

    @Test("Items added to a repeating list while This week only is on survive adding a repeating task")
    func listItemsSurviveTurningOffByAddingTask() throws {
        let store = reviewStore(clock: clock)
        store.addCategory(name: "Trip", symbol: "airplane")
        let tripNow = card(store, "Trip")!.id
        let packing = store.addTask(categoryID: tripNow, title: "Packing", mode: .repeating, type: .list)!
        store.addSubtask(categoryID: tripNow, taskID: packing, title: "Passport")

        store.navigateToDate(nextWeek)
        let tripID = try #require(card(store, "Trip")?.id)
        store.setCategoryThisWeekOnly(tripID, true)
        let copy = try #require(card(store, "Trip")?.tasks.first)
        store.addSubtask(categoryID: tripID, taskID: copy.id, title: "Sunscreen")
        // Adding a repeating task turns This week only off (the picker's hint says so).
        store.addTask(categoryID: tripID, title: "Stretch", mode: .repeating)
        #expect(card(store, "Trip")?.isThisWeekOnly == false)

        store.navigateToDate(clock.now)
        store.navigateToDate(nextWeek)
        let items = card(store, "Trip")?.tasks.first { $0.title == "Packing" }?.subtasks.map(\.title)
        print("REVIEW: list items after TWO off -> \(items ?? [])")
        #expect(items == ["Passport", "Sunscreen"], "the item the user added is kept")
    }

    @Test("Progress on a carried goal while This week only is on survives turning it off")
    func goalProgressSurvivesTurningOff() throws {
        let store = reviewStore(clock: clock)
        store.addCategory(name: "Trip", symbol: "airplane")
        let tripNow = card(store, "Trip")!.id
        let run = store.addTask(categoryID: tripNow, title: "Run", mode: .carryOver, type: .goal)!
        store.setGoalTarget(categoryID: tripNow, taskID: run, target: 10, kind: .custom, unit: "km")

        store.navigateToDate(nextWeek)
        let tripID = try #require(card(store, "Trip")?.id)
        store.setCategoryThisWeekOnly(tripID, true)
        let copy = try #require(card(store, "Trip")?.tasks.first)
        store.updateGoalProgress(categoryID: tripID, taskID: copy.id, progress: 6)
        store.setCategoryThisWeekOnly(tripID, false)

        store.navigateToDate(clock.now)
        store.navigateToDate(nextWeek)
        let progress = card(store, "Trip")?.tasks.first?.goalProgress
        print("REVIEW: goal progress after TWO off -> \(String(describing: progress))")
        #expect(progress == 6, "the progress the user counted is kept")
    }

    // Checked and fine

    @Test("Untouched copies follow their task again once This week only is off")
    func untouchedCopyStillFollows() throws {
        let store = reviewStore(clock: clock)
        store.addCategory(name: "Trip", symbol: "airplane")
        let stretch = store.addTask(categoryID: card(store, "Trip")!.id, title: "Stretch", mode: .repeating)!
        store.navigateToDate(nextWeek)
        let tripID = try #require(card(store, "Trip")?.id)
        store.setCategoryThisWeekOnly(tripID, true)
        store.setCategoryThisWeekOnly(tripID, false)
        #expect(card(store, "Trip")?.tasks.map(\.mode) == [.repeating])
        #expect(card(store, "Trip")?.tasks.first?.isUserEdited == false)
        store.navigateToDate(clock.now)
        store.renameTask(categoryID: card(store, "Trip")!.id, taskID: stretch, newTitle: "Yoga")
        store.navigateToDate(nextWeek)
        #expect(card(store, "Trip")?.tasks.map(\.title) == ["Yoga"])
    }

    @Test("Turning it on in this week takes untouched copies out of a saved next week; off brings them back")
    func onAndOffInThisWeekReachesSavedNextWeek() throws {
        let store = reviewStore(clock: clock)
        store.addCategory(name: "Trip", symbol: "airplane")
        let tripNow = card(store, "Trip")!.id
        store.addTask(categoryID: tripNow, title: "Stretch", mode: .repeating)
        store.addTask(categoryID: tripNow, title: "Pack", mode: .carryOver)
        store.navigateToDate(nextWeek)
        store.addTask(categoryID: card(store, "Trip")!.id, title: "Mine", mode: .oneTime)  // saves next week
        store.navigateToDate(clock.now)
        store.setCategoryThisWeekOnly(tripNow, true)
        store.navigateToDate(nextWeek)
        #expect(card(store, "Trip")?.tasks.map(\.title) == ["Mine"], "only the user's own task is left")
        store.navigateToDate(clock.now)
        store.setCategoryThisWeekOnly(tripNow, false)
        #expect(card(store, "Trip")?.tasks.map(\.mode) == [.repeating, .carryOver])
        store.navigateToDate(nextWeek)
        #expect(Set(card(store, "Trip")?.tasks.map(\.title) ?? []) == ["Mine", "Stretch", "Pack"])
    }
}

// MARK: - Finding: Undo after folding a list unfolds it

struct ReviewCodeFoldTests {
    private let clock = TestClock(2099, 3, 4)
    private var nextWeek: Date { clock.weeks(1, from: clock.now) }

    private func makeStore() -> (ChecklistStore, UUID, UUID, UUID) {
        let store = reviewStore(clock: clock)
        store.addCategory(name: "Home", symbol: "house")
        let home = card(store, "Home")!.id
        let list = store.addTask(categoryID: home, title: "Groceries", mode: .repeating, type: .list)!
        store.addSubtask(categoryID: home, taskID: list, title: "Milk")
        let other = store.addTask(categoryID: home, title: "Call Sam", mode: .oneTime)!
        return (store, home, list, other)
    }

    @Test("Undoing a delete doesn't unfold a list folded after the delete")
    func undoKeepsLaterFold() {
        let (store, home, list, other) = makeStore()
        store.deleteTask(categoryID: home, taskID: other)
        store.setListFolded(categoryID: home, taskID: list, folded: true)
        #expect(store.lastDelete != nil, "folding keeps the Undo (by design)")
        store.undoLastDelete()
        #expect(card(store, "Home")?.tasks.map(\.title) == ["Groceries", "Call Sam"], "the task is back")
        let folded = card(store, "Home")?.tasks.first?.isListFolded
        print("REVIEW: fold after undo -> \(String(describing: folded))")
        #expect(folded == true, "the list the user folded after the delete stays folded")
    }

    // Checked and fine

    @Test("A fold reaches untouched copies in saved later weeks, over an unsaved week, not edited ones")
    func foldReachesCopiesOverSkippedWeek() throws {
        let (store, home, list, _) = makeStore()
        let inTwoWeeks = clock.weeks(2, from: clock.now)
        let inThreeWeeks = clock.weeks(3, from: clock.now)
        // Saves weeks +2 and +3 (week +1 stays a preview).
        store.navigateToDate(inTwoWeeks)
        store.addTask(categoryID: card(store, "Home")!.id, title: "Plan", mode: .oneTime)
        store.navigateToDate(inThreeWeeks)
        let edited = try #require(card(store, "Home")?.tasks.first { $0.title == "Groceries" })
        store.renameSubtask(categoryID: card(store, "Home")!.id, taskID: edited.id, subtaskID: edited.subtasks[0].id, newTitle: "Oat milk")
        store.navigateToDate(clock.now)
        store.setListFolded(categoryID: home, taskID: list, folded: true)
        store.navigateToDate(nextWeek)
        #expect(card(store, "Home")?.tasks.first { $0.title == "Groceries" }?.isListFolded == true, "preview")
        store.navigateToDate(inTwoWeeks)
        #expect(card(store, "Home")?.tasks.first { $0.title == "Groceries" }?.isListFolded == true, "saved copy")
        store.navigateToDate(inThreeWeeks)
        #expect(card(store, "Home")?.tasks.first { $0.title == "Groceries" }?.isListFolded == false, "the user's own copy keeps its fold")
    }

    @Test("Folding isn't an edit: the copy keeps following, and a past week can't be folded")
    func foldIsNotAnEditAndPastIsReadOnly() throws {
        let (store, home, list, _) = makeStore()
        store.navigateToDate(nextWeek)
        let copy = try #require(card(store, "Home")?.tasks.first)
        store.setListFolded(categoryID: card(store, "Home")!.id, taskID: copy.id, folded: true)
        #expect(card(store, "Home")?.tasks.first?.isUserEdited == false)
        store.navigateToDate(clock.now)
        store.renameTask(categoryID: home, taskID: list, newTitle: "Shopping")
        store.navigateToDate(nextWeek)
        #expect(card(store, "Home")?.tasks.first?.title == "Shopping", "still follows")
        #expect(card(store, "Home")?.tasks.first?.isListFolded == true, "and keeps its own fold")

        // A week later, this week is past: its list can't be folded.
        clock.now = clock.weeks(1, from: clock.now)
        store.navigateToDate(clock.weeks(-1, from: clock.now))
        let past = try #require(card(store, "Home"))
        store.setListFolded(categoryID: past.id, taskID: past.tasks[0].id, folded: true)
        #expect(card(store, "Home")?.tasks.first?.isListFolded == false)
    }

    @Test("checklist.json from 1.0.2 (no new fields) loads, and the new fields round-trip")
    func oldFileLoadsAndNewFieldsSave() throws {
        let directory = reviewTempDirectory()
        let defaults = UserDefaults(suiteName: "ReviewCode-\(UUID().uuidString)")!
        // 2099-03-02 is the Monday of the clock's week.
        let old = """
        [{"id":"A1B2C3D4-E5F6-7890-ABCD-EF1234567890","startDay":"2099-03-02","startDate":"2099-03-02T05:00:00Z","didFinalSync":true,
          "categories":[{"id":"B1B2C3D4-E5F6-7890-ABCD-EF1234567890","name":"Trip","symbol":"airplane","isThisWeekOnly":true,
          "tasks":[{"id":"C1B2C3D4-E5F6-7890-ABCD-EF1234567890","title":"Packing","isCompleted":false,"isUserEdited":true,
          "mode":"oneTime","subtasks":[{"id":"D1B2C3D4-E5F6-7890-ABCD-EF1234567890","title":"Passport","isCompleted":true}],"taskType":"list"}]}]}]
        """
        try Data(old.utf8).write(to: directory.appending(path: "checklist.json"))
        let store = reviewStore(directory: directory, clock: clock, defaults: defaults)
        #expect(store.persistenceError == nil)
        let task = try #require(card(store, "Trip")?.tasks.first)
        #expect(task.isListFolded == false && task.modeBeforeThisWeekOnly == nil)
        store.setListFolded(categoryID: card(store, "Trip")!.id, taskID: task.id, folded: true)
        // A field with a value from a newer build mustn't stop the file loading.
        var text = try String(contentsOf: directory.appending(path: "checklist.json"), encoding: .utf8)
        text = text.replacingOccurrences(of: "\"isListFolded\" : true", with: "\"isListFolded\" : \"yes\", \"modeBeforeThisWeekOnly\" : {\"mode\" : \"someday\"}")
        try Data(text.utf8).write(to: directory.appending(path: "checklist.json"))
        let reloaded = reviewStore(directory: directory, clock: clock, defaults: defaults)
        #expect(reloaded.persistenceError == nil)
        #expect(card(reloaded, "Trip")?.tasks.first?.subtasks.map(\.title) == ["Passport"])
    }
}

// MARK: - Dates and time zones: daylight-saving weeks

/// Week starts, stepping a week at a time, today and rollover in the weeks the clocks
/// change, in New York (2026: forward Sun 8 Mar, back Sun 1 Nov), Sydney (back Sun 5 Apr,
/// forward Sun 4 Oct), Santiago (clocks jump at midnight, so a Sunday has no 00:00) and
/// Tokyo (no DST).
struct ReviewCodeDSTTests {
    /// (zone, a Wednesday in the week the clocks change, Monday of that week)
    static let cases: [(String, DayKey, DayKey)] = [
        ("America/New_York", DayKey(year: 2026, month: 3, day: 4), DayKey(year: 2026, month: 3, day: 2)),
        ("America/New_York", DayKey(year: 2026, month: 3, day: 11), DayKey(year: 2026, month: 3, day: 9)),
        ("America/New_York", DayKey(year: 2026, month: 10, day: 28), DayKey(year: 2026, month: 10, day: 26)),
        ("America/New_York", DayKey(year: 2026, month: 11, day: 4), DayKey(year: 2026, month: 11, day: 2)),
        ("Australia/Sydney", DayKey(year: 2026, month: 4, day: 1), DayKey(year: 2026, month: 3, day: 30)),
        ("Australia/Sydney", DayKey(year: 2026, month: 9, day: 30), DayKey(year: 2026, month: 9, day: 28)),
        ("America/Santiago", DayKey(year: 2026, month: 9, day: 2), DayKey(year: 2026, month: 8, day: 31)),
        ("America/Santiago", DayKey(year: 2026, month: 4, day: 1), DayKey(year: 2026, month: 3, day: 30)),
        ("Asia/Tokyo", DayKey(year: 2026, month: 3, day: 4), DayKey(year: 2026, month: 3, day: 2)),
        ("Asia/Tokyo", DayKey(year: 2026, month: 12, day: 30), DayKey(year: 2026, month: 12, day: 28)),
    ]

    private func zoneCalendar(_ zone: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone)!
        return calendar
    }

    @Test("Every hour of the week (and the days around it) finds that week's start, Monday or Sunday",
          arguments: cases)
    func everyHourFindsItsWeek(zone: String, wednesday: DayKey, monday: DayKey) {
        let clock = TestClock(wednesday.year, wednesday.month, wednesday.day, timeZone: zone)
        let store = reviewStore(clock: clock)
        let calendar = zoneCalendar(zone)
        for sunday in [false, true] {
            store.setWeekStartsOnSunday(sunday)
            let start = sunday ? monday.adding(days: -1) : monday
            // Ten days, every half hour, from the day before the week to the days after it.
            var moment = start.adding(days: -1).date(in: calendar)
            let end = start.adding(days: 9).date(in: calendar)
            while moment < end {
                let day = DayKey(moment, in: calendar)
                let offset = calendar.dateComponents([.day], from: start.date(in: calendar), to: day.date(in: calendar)).day!
                let expected = start.adding(days: Int((Double(offset) / 7).rounded(.down)) * 7)
                let found = store.weekStartDay(containing: moment)
                if found != expected { print("REVIEW: DST \(zone) sunday=\(sunday) \(moment) -> \(found), expected \(expected)") }
                #expect(found == expected)
                moment = moment.addingTimeInterval(30 * 60)  // real time passing, on purpose
            }
        }
    }

    @Test("Paging a week at a time through the clock change lands on each next week, and back", arguments: cases)
    func pagingThroughTheChange(zone: String, wednesday: DayKey, monday: DayKey) {
        let clock = TestClock(wednesday.year, wednesday.month, wednesday.day, timeZone: zone)
        let store = reviewStore(clock: clock)
        for sunday in [false, true] {
            store.setWeekStartsOnSunday(sunday)
            store.navigateToDate(clock.now)
            let start = sunday ? monday.adding(days: -1) : monday
            #expect(store.selectedWeek?.startDay == start)
            // As ContentView's arrows do: a week of the store's calendar from selectedDate.
            for step in 1...3 {
                store.navigateToDate(store.calendar.date(byAdding: .weekOfYear, value: 1, to: store.selectedDate)!)
                #expect(store.selectedWeek?.startDay == start.adding(days: 7 * step))
            }
            for step in (0...2).reversed() {
                store.navigateToDate(store.calendar.date(byAdding: .weekOfYear, value: -1, to: store.selectedDate)!)
                #expect(store.selectedWeek?.startDay == start.adding(days: 7 * step))
            }
            // The pager's neighbors are a week from the week's first midnight.
            let first = start.date(in: store.calendar)
            #expect(store.weekStartDay(containing: store.calendar.date(byAdding: .weekOfYear, value: 1, to: first)!) == start.adding(days: 7))
            #expect(store.weekStartDay(containing: store.calendar.date(byAdding: .weekOfYear, value: -1, to: first)!) == start.adding(days: -7))
        }
    }

    @Test("Late Sunday of the change week is still that week; the new week starts at Monday midnight", arguments: cases)
    func rolloverAtTheWeekEnd(zone: String, wednesday: DayKey, monday: DayKey) {
        let calendar = zoneCalendar(zone)
        let clock = TestClock(wednesday.year, wednesday.month, wednesday.day, timeZone: zone)
        let store = reviewStore(clock: clock)
        let work = store.selectedWeek!.categories[0].id
        store.addTask(categoryID: work, title: "Report", mode: .carryOver)
        store.addTask(categoryID: work, title: "Stretch", mode: .repeating)
        // Sunday 23:30, then Monday 00:30 (the store's clock, as if the app stayed open).
        // Wall-clock times (a fixed number of minutes after midnight is another hour on a
        // 23- or 25-hour day).
        clock.now = calendar.date(bySettingHour: 23, minute: 30, second: 0, of: monday.adding(days: 6).date(in: calendar))!
        store.navigateToDate(clock.now)
        #expect(store.selectedWeek?.startDay == monday)
        #expect(store.selectedWeek.map(store.isCurrentWeek) == true)
        clock.now = calendar.date(bySettingHour: 0, minute: 30, second: 0, of: monday.adding(days: 7).date(in: calendar))!
        store.navigateToDate(clock.now)
        #expect(store.selectedWeek?.startDay == monday.adding(days: 7))
        #expect(store.selectedWeek?.categories.first?.tasks.map(\.title) == ["Report", "Stretch"])
        #expect(store.weeks.count == 2, "one new week, no duplicate")
    }

    @Test("A change week's events fall on the right days (a 23- or 25-hour Sunday)", arguments: cases)
    func eventsGroupByCalendarDay(zone: String, wednesday: DayKey, monday: DayKey) {
        let calendar = zoneCalendar(zone)
        let weekStart = monday.date(in: calendar)
        // Wall-clock times on the week's Sunday (01:05, not 00:00: Santiago's Sunday has no midnight).
        func at(_ day: Int, _ hour: Int, _ minute: Int) -> Date {
            calendar.date(bySettingHour: hour, minute: minute, second: 0, of: monday.adding(days: day).date(in: calendar))!
        }
        let late = CalendarEvent(id: "late", eventIdentifier: "late", title: "Late", start: at(6, 23, 15), end: at(6, 23, 45),
                                 isAllDay: false, calendarID: "c", color: .blue)
        let early = CalendarEvent(id: "early", eventIdentifier: "early", title: "Early", start: at(6, 1, 5), end: at(6, 1, 35),
                                  isAllDay: false, calendarID: "c", color: .blue)
        let days = EventGrouping.days(for: [late, early], weekStart: weekStart, calendar: calendar)
        #expect(days.count == 1)
        #expect(days.first.map { DayKey($0.date, in: calendar) } == monday.adding(days: 6))
        #expect(days.first?.events.count == 2)
    }

    @Test("The week's saved day doesn't move when the device's time zone changes")
    func savedDayStaysOverZoneChange() {
        let directory = reviewTempDirectory()
        let defaults = UserDefaults(suiteName: "ReviewCode-\(UUID().uuidString)")!
        let clock = TestClock(2026, 11, 1, hour: 1, timeZone: "America/New_York")  // the repeated hour
        let store = reviewStore(directory: directory, clock: clock, defaults: defaults)
        #expect(store.selectedWeek?.startDay == DayKey(year: 2026, month: 10, day: 26))
        store.addTask(categoryID: store.selectedWeek!.categories[0].id, title: "Pack")
        for zone in ["Asia/Tokyo", "Pacific/Kiritimati", "Pacific/Pago_Pago"] {
            clock.calendar.timeZone = TimeZone(identifier: zone)!
            let reloaded = reviewStore(directory: directory, clock: clock, defaults: defaults)
            #expect(reloaded.weeks.contains { $0.startDay == DayKey(year: 2026, month: 10, day: 26) }, "\(zone)")
            #expect(reloaded.weeks.filter { $0.startDay == DayKey(year: 2026, month: 10, day: 26) }.count == 1)
        }
    }
}

// MARK: - Smart Add sessions

struct ReviewCodeSmartAddTests {
    @Test("Session phrasings beyond the documented ones get the right total, step and days")
    func morePhrasings() {
        func check(_ text: String, _ target: Double, _ step: Double?, _ days: Int?, _ mode: TaskMode) {
            let t = reviewRules(text)
            #expect(t.type == .goal, "\(text)")
            #expect(t.goalTarget == target, "\(text)")
            #expect(t.goalStep == step, "\(text)")
            #expect(t.goalDays == days, "\(text)")
            #expect(t.mode == mode, "\(text)")
        }
        check("Swim 45 min 3x/week", 135, 45, 3, .repeating)
        check("Run 4 times a week 30 min", 120, 30, 4, .repeating)
        check("Pomodoro 4x 25 min", 100, 25, 4, .oneTime)
        check("Tennis twice 1 hour", 120, 60, 2, .oneTime)
        check("Read 20 pages 3 times a week", 60, 20, 3, .repeating)
        check("Yoga 3 classes of 60 min", 180, 60, 3, .oneTime)
        check("Gym 8 times 45 min", 45, nil, nil, .oneTime)  // more than seven: not sessions
        check("Piano 30 min 5 days a week", 150, 30, 5, .repeating)  // days, not sessions
        #expect(reviewRules("Gym 3 times 45 min tomorrow").title == "Gym")
    }

    /// Prints what the rules alone (the simulator's Smart Add) make of other phrasings;
    /// on a device the model's title is used instead. Not asserted.
    @Test("Probe: what the rules make of session phrasings")
    func probe() {
        for text in ["Gym 3 times 45 min each", "Gym 3 times a week, 45 min each", "gym 3x 45 min per session",
                     "Swim 45 min 3x/week", "Swim 2 km 3x/week", "Study 2 hours for 3 sessions", "Run 4 times a week 30 min",
                     "Pomodoro 4x 25 min", "Take 2 pills 3 times", "Bench press 3 sets of 10 reps", "Walk dog 2 times 20 min a day",
                     "Piano 30 min 5 days a week", "Tennis twice 1 hour", "Read 20 pages 3 times a week", "Yoga 3 classes of 60 min",
                     "Call mom 10 min", "Gym 8 times 45 min", "3 x 10 min stretches", "Gym 3 times 45 min tomorrow",
                     "Groceries: milk, eggs", "Packing list", "Gym three 45-minute workouts a week"] {
            let t = reviewRules(text)
            print("REVIEW: smartAdd '\(text)' -> title='\(t.title)' type=\(t.type) mode=\(t.mode) target=\(String(describing: t.goalTarget)) step=\(String(describing: t.goalStep)) days=\(String(describing: t.goalDays)) unit='\(t.goalUnit)' items=\(t.items)")
        }
    }
}

// MARK: - Reordering (checked and fine)

struct ReviewCodeReorderTests {
    @Test("A short task passes a tall one only at the tall one's middle, both ways, and lands at the end")
    func mixedHeights() {
        let ids = (0..<3).map { _ in UUID() }
        let spacing: CGFloat = 14
        let heights: [CGFloat] = [40, 200, 40]
        var y: CGFloat = 0
        var frames: [UUID: CGRect] = [:]
        for (i, id) in ids.enumerated() {
            frames[id] = CGRect(x: 0, y: y, width: 300, height: heights[i])
            y += heights[i] + spacing
        }
        var down = TaskReorder(taskID: ids[0], order: ids, frames: frames, from: 0)
        let toTallMiddle = frames[ids[1]]!.midY - frames[ids[0]]!.midY
        down.distance = toTallMiddle - 2
        #expect(down.landing == 0)
        down.distance = toTallMiddle + 2
        #expect(down.landing == 1)
        down.distance = down.clamped(10_000)
        #expect(down.landing == 2)
        down.target = 2
        #expect(down.offset(for: ids[1], spacing: spacing) == -(40 + spacing))
        #expect(down.offset(for: ids[2], spacing: spacing) == -(40 + spacing))

        var tallUp = TaskReorder(taskID: ids[1], order: ids, frames: frames, from: 1)
        tallUp.distance = tallUp.clamped(-10_000)
        #expect(tallUp.landing == 0)
        tallUp.distance = 0
        #expect(tallUp.landing == 1, "back where it started")
    }

    @Test("Auto-scroll: no speed in the middle, full speed past either edge")
    func autoScrollEdges() {
        #expect(TaskAutoScroller.velocity(fingerY: 400, top: 100, bottom: 700) == 0)
        #expect(TaskAutoScroller.velocity(fingerY: 0, top: 100, bottom: 700) == -TaskAutoScroller.maxSpeed)
        #expect(TaskAutoScroller.velocity(fingerY: 900, top: 100, bottom: 700) == TaskAutoScroller.maxSpeed)
    }

    @Test("Moving a task saves the new order, and next week's sync keeps the user's order")
    func moveTaskKeepsOrderAcrossSync() throws {
        let clock = TestClock(2099, 3, 4)
        let store = reviewStore(clock: clock)
        let work = store.selectedWeek!.categories[0].id
        let a = store.addTask(categoryID: work, title: "A", mode: .repeating)!
        store.addTask(categoryID: work, title: "B", mode: .repeating)
        let c = store.addTask(categoryID: work, title: "C", mode: .repeating)!
        let nextWeek = clock.weeks(1, from: clock.now)
        store.navigateToDate(nextWeek)
        let next = try #require(store.selectedWeek?.categories[0])
        store.moveTask(categoryID: next.id, taskID: next.tasks[2].id, to: next.tasks[0].id)
        #expect(store.selectedWeek?.categories[0].tasks.map(\.title) == ["C", "A", "B"])
        store.navigateToDate(clock.now)
        store.moveTask(categoryID: work, taskID: a, to: c)
        store.navigateToDate(nextWeek)
        #expect(store.selectedWeek?.categories[0].tasks.map(\.title) == ["C", "A", "B"], "next week's own order stays")
    }
}
