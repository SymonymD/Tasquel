//
//  ReviewCodeDateTests.swift
//  TasquelTests
//
//  Pre-ship code review, 2026-11-15: dates, DST weeks, year ends, week-start switches,
//  time zones, reminders, Smart Add's typed dates. Every test uses a fixed calendar and
//  time zone (America/New_York unless it says otherwise) and asserts what should happen.
//

import Testing
import Foundation
@testable import Tasquel

// MARK: - Helpers (copies of the private ones in TasquelTests.swift)

private func reviewTempDirectory() -> URL {
    let url = FileManager.default.temporaryDirectory.appending(path: "ReviewCode-\(UUID().uuidString)")
    try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

@MainActor
private func reviewStore(_ clock: TestClock, directory: URL = reviewTempDirectory(),
                         defaults: UserDefaults? = nil) -> ChecklistStore {
    let defaults = defaults ?? UserDefaults(suiteName: "ReviewCode-\(UUID().uuidString)")!
    return ChecklistStore(directory: directory, defaults: defaults, now: { clock.now }, calendar: { clock.calendar })
}

private func calendar(_ zone: String) -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: zone)!
    return calendar
}

/// A moment by local wall-clock time in `clock`'s zone (the first one, for an hour that
/// happens twice on the night clocks go back).
private func moment(_ clock: TestClock, _ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int = 0) -> Date {
    clock.calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
}

private func day(_ y: Int, _ m: Int, _ d: Int) -> DayKey { DayKey(year: y, month: m, day: d) }

/// Every task in every saved week, with the week it's in.
@MainActor
private func allTasks(_ store: ChecklistStore) -> [(week: DayKey, task: ChecklistTask)] {
    store.weeks.flatMap { week in week.categories.flatMap { $0.tasks.map { (week.startDay, $0) } } }
}

/// DST Sundays in New York this release has to live through.
private let dstSundays: [DayKey] = [day(2026, 3, 8), day(2026, 11, 1), day(2027, 3, 14), day(2027, 11, 7)]

/// Zones with DST at 2 AM (New York), none (Tokyo, Kiritimati at +14), DST at midnight (Santiago,
/// Havana, Asunción), half-hour DST (Lord Howe), and a :30 offset (St John's).
private let zones = ["America/New_York", "Asia/Tokyo", "Pacific/Kiritimati", "America/Santiago", "America/Havana",
                     "America/Asuncion", "Australia/Lord_Howe", "America/St_Johns", "Asia/Beirut", "Pacific/Apia"]

// MARK: - Days and weeks in every zone

struct ReviewCodeDayKeyTests {
    @Test("Every day of 2026–2028 round-trips through its midnight in zones with and without DST")
    func dayKeyRoundTrip() {
        for zone in zones {
            let cal = calendar(zone)
            var key = day(2026, 1, 1)
            while key <= day(2028, 12, 31) {
                let back = DayKey(key.date(in: cal), in: cal)
                #expect(back == key, "\(zone): \(key) came back as \(back)")
                #expect(key.adding(days: 1).adding(days: -1) == key)
                #expect(key.days(to: key.adding(days: 7)) == 7)
                key = key.adding(days: 1)
            }
        }
    }

    @Test("The week holding each day of 2026–2028 starts on the right weekday, at midnight, noon and 23:30, both week starts")
    func weekStartEveryDay() {
        for zone in zones {
            let cal = calendar(zone)
            for firstWeekday in [Week.monday, Week.sunday] {
                var key = day(2026, 1, 1)
                while key <= day(2028, 12, 31) {
                    let midnight = key.date(in: cal)
                    for time in [midnight,
                                 cal.date(bySettingHour: 12, minute: 0, second: 0, of: midnight)!,
                                 cal.date(bySettingHour: 23, minute: 30, second: 0, of: midnight)!] {
                        let start = DayKey(Week.startOfWeek(containing: time, firstWeekday: firstWeekday, calendar: cal), in: cal)
                        let gap = start.days(to: key)
                        let weekday = cal.component(.weekday, from: start.date(in: cal))
                        #expect((0...6).contains(gap) && weekday == firstWeekday,
                                "\(zone) start \(firstWeekday): \(key) at \(time) is in a week starting \(start)")
                    }
                    key = key.adding(days: 1)
                }
            }
        }
    }
}

// MARK: - The store in DST weeks (New York)

@MainActor @Suite(.serialized)
struct ReviewCodeDSTWeekTests {
    @Test("On each DST Sunday the current week is the Monday before; at 00:30 Monday the new week is current")
    func currentWeekAroundDST() {
        for sunday in dstSundays {
            let clock = TestClock(sunday.year, sunday.month, sunday.day, hour: 1)
            clock.now = clock.now.addingTimeInterval(30 * 60)  // 01:30, before the change
            let store = reviewStore(clock)
            let monday = sunday.adding(days: -6)
            #expect(store.selectedWeek?.startDay == monday, "\(sunday) 01:30")
            #expect(store.currentDay == sunday)
            for hour in [3, 12, 23] {
                clock.now = moment(clock, sunday.year, sunday.month, sunday.day, hour, 30)
                store.navigateToDate(clock.now)
                #expect(store.selectedWeek?.startDay == monday, "\(sunday) \(hour):30")
                #expect(store.currentDay == sunday)
            }
            let next = sunday.adding(days: 1)
            clock.now = moment(clock, next.year, next.month, next.day, 0, 30)
            store.navigateToDate(clock.now)
            store.ensureWeekExists(for: clock.now)
            #expect(store.selectedWeek?.startDay == next, "Monday after \(sunday)")
            #expect(store.selectedWeek.map(store.isCurrentWeek) == true)
            #expect(store.weeks.map(\.startDay).sorted() == [monday, next], "no extra week")
        }
    }

    @Test("With Sunday starts, a week starting on a DST Sunday is current from 00:30 that Sunday")
    func sundayStartOnDSTSunday() {
        for sunday in dstSundays {
            let clock = TestClock(sunday.year, sunday.month, sunday.day, hour: 0)
            clock.now = clock.now.addingTimeInterval(30 * 60)
            let store = reviewStore(clock)
            store.setWeekStartsOnSunday(true)
            #expect(store.selectedWeek?.startDay == sunday)
            clock.now = moment(clock, sunday.year, sunday.month, sunday.day, 23, 30)
            store.navigateToDate(clock.now)
            #expect(store.selectedWeek?.startDay == sunday)
            #expect(store.dayHasGoneBy(1) == false, "Sunday is today, not gone by")
        }
    }

    @Test("A Saturday task is late on the DST Sunday; a Sunday task is today's; a task given Saturday on Sunday isn't late")
    func lateAndTodayOnDSTSunday() throws {
        for sunday in dstSundays {
            let clock = TestClock(sunday.year, sunday.month, sunday.day, hour: 12)
            let store = reviewStore(clock)
            let card = try #require(store.selectedWeek?.categories.first)
            let start = try #require(store.selectedWeek?.startDay)
            var saturday = ChecklistTask(title: "Sat")
            saturday.dayOfWeek = 7
            var sundayTask = ChecklistTask(title: "Sun")
            sundayTask.dayOfWeek = 1
            #expect(saturday.isLate(inWeekStarting: start, firstWeekday: Week.monday, today: store.currentDay))
            #expect(!sundayTask.isLate(inWeekStarting: start, firstWeekday: Week.monday, today: store.currentDay))
            #expect(sundayTask.day(inWeekStarting: start, firstWeekday: Week.monday) == store.currentDay)
            // An existing task given Saturday on Sunday: not late (daySetOn).
            let id = try #require(store.addTask(categoryID: card.id, title: "Trash", mode: .repeating))
            store.setTaskDay(categoryID: card.id, taskID: id, day: 7)
            let trash = try #require(store.viewedTask(card.id, id))
            #expect(!trash.isLate(inWeekStarting: start, firstWeekday: Week.monday, today: store.currentDay))
            #expect(store.dayHasGoneBy(7) && !store.dayHasGoneBy(1))
        }
    }

    @Test("A task whose last day is the DST Sunday stays through 23:30 and is gone at 00:30 Monday")
    func expiryAcrossDST() throws {
        for sunday in dstSundays {
            let monday = sunday.adding(days: -6)
            let clock = TestClock(monday.year, monday.month, monday.day)  // the Monday before, noon
            let store = reviewStore(clock)
            let card = try #require(store.selectedWeek?.categories.first)
            let id = try #require(store.addTask(categoryID: card.id, title: "Ends Sunday"))
            store.setTaskDate(categoryID: card.id, taskID: id, lastDay: sunday)
            clock.now = moment(clock, sunday.year, sunday.month, sunday.day, 23, 30)
            store.navigateToDate(clock.now)
            #expect(store.viewedTask(card.id, id) != nil, "\(sunday) 23:30: still its last day")
            let progress = try #require(store.viewedTask(card.id, id)?.expiryProgress(on: store.currentDay))
            #expect(progress == 1, "the ring is full on its last day")
            let next = sunday.adding(days: 1)
            clock.now = moment(clock, next.year, next.month, next.day, 0, 30)
            store.navigateToDate(clock.now)
            store.ensureWeekExists(for: clock.now)
            #expect(!allTasks(store).contains { $0.task.title == "Ends Sunday" && $0.week >= next }, "gone from the new week")
        }
    }

    @Test("The reminder for a task ending the Monday after a DST Sunday is due at 9 AM local that Sunday")
    func reminderTimeOnDSTSunday() throws {
        for sunday in dstSundays {
            let clock = TestClock(sunday.year, sunday.month, sunday.day, hour: 7)
            let store = reviewStore(clock)
            let card = try #require(store.selectedWeek?.categories.first)
            let id = try #require(store.addTask(categoryID: card.id, title: "Return library books"))  // carry-over
            store.setTaskDate(categoryID: card.id, taskID: id, lastDay: sunday.adding(days: 1))
            clock.now = moment(clock, sunday.year, sunday.month, sunday.day, 8, 59)
            let due = store.expiryReminders
            #expect(due.count == 1 && due.first?.day == sunday, "\(sunday) 8:59: one reminder for today, got \(due)")
            #expect(due.first?.title == "Return library books expires tomorrow")
            clock.now = moment(clock, sunday.year, sunday.month, sunday.day, 9, 1)
            #expect(store.expiryReminders.isEmpty, "\(sunday) 9:01: its time has passed")
        }
    }
}

// MARK: - Dates that move a task, across DST and year ends

@MainActor @Suite(.serialized)
struct ReviewCodeDatesWeekTests {
    @Test("A one-time task dated the Tuesday after the fall-back Sunday moves into that week, on Tuesday")
    func movesAcrossFallBack() throws {
        let clock = TestClock(2026, 10, 28)  // Wednesday
        let store = reviewStore(clock)
        let card = try #require(store.selectedWeek?.categories.first)
        let id = try #require(store.addTask(categoryID: card.id, title: "Vote", mode: .oneTime))
        store.setTaskDate(categoryID: card.id, taskID: id, lastDay: day(2026, 11, 3))
        let placed = allTasks(store).filter { $0.task.title == "Vote" }
        #expect(placed.map(\.week) == [day(2026, 11, 2)])
        #expect(placed.first?.task.dayOfWeek == 3)
        #expect(store.addedElsewhere?.weekStart == day(2026, 11, 2))
        // The DST Sunday itself is this week's last day: it stays, on Sunday.
        let id2 = try #require(store.addTask(categoryID: card.id, title: "Clocks back", mode: .oneTime))
        store.setTaskDate(categoryID: card.id, taskID: id2, lastDay: day(2026, 11, 1))
        #expect(store.viewedTask(card.id, id2)?.dayOfWeek == 1)
    }

    @Test("Year end 2026: a date in the week of Dec 28 stays on its day; Jan 4 moves into 2027's first week")
    func yearEnd2026() throws {
        let clock = TestClock(2026, 12, 30)  // Wednesday
        let store = reviewStore(clock)
        #expect(store.selectedWeek?.startDay == day(2026, 12, 28))
        let card = try #require(store.selectedWeek?.categories.first)
        let sat = try #require(store.addTask(categoryID: card.id, title: "Party", mode: .oneTime))
        store.setTaskDate(categoryID: card.id, taskID: sat, lastDay: day(2027, 1, 2))
        #expect(store.viewedTask(card.id, sat)?.dayOfWeek == 7, "Jan 2 is this week's Saturday")
        let mon = try #require(store.addTask(categoryID: card.id, title: "Back to work", mode: .oneTime))
        store.setTaskDate(categoryID: card.id, taskID: mon, lastDay: day(2027, 1, 4))
        #expect(allTasks(store).filter { $0.task.title == "Back to work" }.map(\.week) == [day(2027, 1, 4)])
        #expect(store.weekOfDate(day(2027, 1, 3)) == day(2026, 12, 28))
    }

    @Test("Year end 2027 with Sunday starts: Jan 1 2028 (a Saturday) is in the week of Dec 26")
    func yearEnd2027SundayStart() throws {
        let clock = TestClock(2027, 12, 29)
        let store = reviewStore(clock)
        store.setWeekStartsOnSunday(true)
        #expect(store.selectedWeek?.startDay == day(2027, 12, 26))
        #expect(store.weekOfDate(day(2028, 1, 1)) == day(2027, 12, 26))
        #expect(store.weekOfDate(day(2028, 1, 2)) == day(2028, 1, 2))
        let card = try #require(store.selectedWeek?.categories.first)
        let id = try #require(store.addTask(categoryID: card.id, title: "Brunch", mode: .oneTime))
        store.setTaskDate(categoryID: card.id, taskID: id, lastDay: day(2028, 1, 2))
        #expect(allTasks(store).filter { $0.task.title == "Brunch" }.map(\.week) == [day(2028, 1, 2)])
    }
}

// MARK: - Week-start switches with dated tasks (finding)

@MainActor @Suite(.serialized)
struct ReviewCodeWeekStartSwitchTests {
    /// The week (Monday start) a dated one-time task was moved into, then Week Starts On
    /// Sunday picked on a Sunday: every saved week moves six days later, so the week of Nov 16
    /// becomes the week of Nov 22, past the task's date, and the task is deleted as expired.
    @Test("Switching to Sunday starts on a Sunday keeps a one-time task dated next Thursday")
    func sundaySwitchKeepsNextWeeksDatedTask() throws {
        let directory = reviewTempDirectory()
        let clock = TestClock(2026, 11, 15)  // Sunday, Monday starts
        let store = reviewStore(clock, directory: directory)
        let card = try #require(store.selectedWeek?.categories.first)
        let id = try #require(store.addTask(categoryID: card.id, title: "Dentist", mode: .oneTime))
        store.setTaskDate(categoryID: card.id, taskID: id, lastDay: day(2026, 11, 19))
        #expect(allTasks(store).filter { $0.task.title == "Dentist" }.map(\.week) == [day(2026, 11, 16)])

        store.setWeekStartsOnSunday(true)
        store.navigateToDate(clock.now)  // any later navigation, or the next launch
        let after = allTasks(store).filter { $0.task.title == "Dentist" }
        print("REVIEW: after the switch, Dentist is in \(after.map { "\($0.week)" }); weeks \(store.weeks.map { "\($0.startDay)" })")
        #expect(after.map(\.week) == [day(2026, 11, 15)], "still there, in the week holding Nov 19")

        let relaunched = reviewStore(clock, directory: directory)
        #expect(allTasks(relaunched).contains { $0.task.title == "Dentist" }, "still there after a relaunch")
    }

    /// On a weekday, Sunday → Monday moves weeks one day later: a task dated Sunday the 15th,
    /// in the Sunday week of Nov 15, lands in the Monday week of Nov 16 and is deleted.
    @Test("Switching to Monday starts keeps a one-time task dated next Sunday")
    func mondaySwitchKeepsSundayDatedTask() throws {
        let clock = TestClock(2026, 11, 11)  // Wednesday
        let store = reviewStore(clock)
        store.setWeekStartsOnSunday(true)
        #expect(store.selectedWeek?.startDay == day(2026, 11, 8))
        let card = try #require(store.selectedWeek?.categories.first)
        let id = try #require(store.addTask(categoryID: card.id, title: "Brunch", mode: .oneTime))
        store.setTaskDate(categoryID: card.id, taskID: id, lastDay: day(2026, 11, 15))
        #expect(allTasks(store).filter { $0.task.title == "Brunch" }.map(\.week) == [day(2026, 11, 15)])

        store.setWeekStartsOnSunday(false)
        store.navigateToDate(clock.now)
        let after = allTasks(store).filter { $0.task.title == "Brunch" }
        print("REVIEW: after the switch, Brunch is in \(after.map { "\($0.week)" })")
        #expect(after.map(\.week) == [day(2026, 11, 9)], "still there, in the Monday week holding Nov 15")
    }

    /// On a Sunday (Monday starts), "Gym Thursday" goes into next week's card, on Thursday the
    /// 19th (a day gone by this week). After Week Starts On Sunday, the 19th is in the current
    /// week, but the task's week moved six days to Nov 22, so it's now for Thursday the 26th.
    @Test("Switching to Sunday starts on a Sunday keeps next week's day task on its date")
    func sundaySwitchKeepsDayTaskDate() throws {
        let clock = TestClock(2026, 11, 15)
        let store = reviewStore(clock)
        let card = try #require(store.selectedWeek?.categories.first)
        var parsed = ParsedTask(title: "Gym")
        parsed.day = 5
        let placed = try #require(store.placeParsedTask(parsed, categoryID: card.id))
        #expect(placed.weekStart == day(2026, 11, 16))
        store.setWeekStartsOnSunday(true)
        store.navigateToDate(clock.now)
        let found = try #require(allTasks(store).first { $0.task.title == "Gym" })
        let date = found.task.day(inWeekStarting: found.week, firstWeekday: Week.sunday)
        print("REVIEW: after the switch, Gym is in the week of \(found.week), on \(date.map { "\($0)" } ?? "-")")
        #expect(date == day(2026, 11, 19), "still Thursday the 19th")
    }

    @Test("Checked: a carry-over task dated inside the current week survives a switch to Sunday starts on a Sunday")
    func carryOverSurvivesSwitch() throws {
        let clock = TestClock(2026, 11, 15)
        let store = reviewStore(clock)
        let card = try #require(store.selectedWeek?.categories.first)
        let id = try #require(store.addTask(categoryID: card.id, title: "Rent", mode: .carryOver))
        store.setTaskDate(categoryID: card.id, taskID: id, lastDay: day(2026, 11, 20))
        store.setWeekStartsOnSunday(true)
        store.navigateToDate(clock.now)
        #expect(store.selectedWeek?.startDay == day(2026, 11, 15))
        #expect(store.selectedWeek?.categories.flatMap(\.tasks).contains { $0.title == "Rent" } == true)
    }
}

// MARK: - Time zones

@MainActor @Suite(.serialized)
struct ReviewCodeTimeZoneTests {
    @Test("A date and a day kept as DayKeys don't move when flying Tokyo → New York; late is judged by the local day")
    func flyingKeepsDatesAndDays() throws {
        let directory = reviewTempDirectory()
        // Tuesday Nov 10, 09:00 in Tokyo (Monday Nov 9, 19:00 in New York).
        let clock = TestClock(2026, 11, 10, hour: 9, timeZone: "Asia/Tokyo")
        let store = reviewStore(clock, directory: directory)
        let card = try #require(store.selectedWeek?.categories.first)
        let id = try #require(store.addTask(categoryID: card.id, title: "Call home"))
        store.setTaskDay(categoryID: card.id, taskID: id, day: 2)  // Monday, already gone by in Tokyo
        let start = try #require(store.selectedWeek?.startDay)
        let set = try #require(store.viewedTask(card.id, id))
        #expect(!set.isLate(inWeekStarting: start, firstWeekday: Week.monday, today: store.currentDay), "given Monday on Tuesday")
        store.setTaskDate(categoryID: card.id, taskID: id, lastDay: day(2026, 11, 12))

        clock.calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let reloaded = reviewStore(clock, directory: directory)
        let task = try #require(reloaded.selectedWeek?.categories.flatMap(\.tasks).first { $0.title == "Call home" })
        #expect(reloaded.currentDay == day(2026, 11, 9))
        #expect(task.expiresOn == day(2026, 11, 12), "the date didn't move")
        #expect(task.dayOfWeek == 5, "the date inside the week made it Thursday's, and that didn't move")
        #expect(reloaded.weeks.map(\.startDay) == [day(2026, 11, 9)], "no week added")
        #expect(task.expiryProgress(on: reloaded.currentDay).map { $0 >= 0 && $0 <= 1 } == true)
    }
}

// MARK: - Smart Add's typed dates

struct ReviewCodeTypedDateTests {
    private let cal = calendar("America/New_York")
    private func find(_ text: String, today: DayKey) -> TypedDate? {
        TypedDate.find(in: text, earliest: today, today: today, calendar: cal, locale: Locale(identifier: "en_US"))
    }

    @Test("On New Year's Eve, 'jan 2' is next year's and 'dec 31' is today")
    func yearEnd() throws {
        let today = day(2026, 12, 31)
        #expect(try #require(find("Party jan 2", today: today)).day == day(2027, 1, 2))
        #expect(try #require(find("Fireworks dec 31", today: today)).day == day(2026, 12, 31))
        #expect(try #require(find("Taxes 1/15", today: today)).day == day(2027, 1, 15))
        #expect(find("Leap day 2/29", today: today) == nil, "2027 has no Feb 29")
    }

    /// `slashDates` builds the date in this year first (TypedDate.swift:106), and 2027 has no
    /// Feb 29, so "2/29" typed any day of 2027 is never offered, though Feb 29 2028 comes next.
    @Test("Typed in 2027, '2/29' is Feb 29 2028")
    func leapDayNextYear() throws {
        #expect(find("Leap day 2/29", today: day(2027, 12, 31))?.day == day(2028, 2, 29))
    }

    @Test("A range counts by its end: 'until 12/15' and 'due December 15' are Dec 15, not the 16th")
    func rangeEnds() throws {
        let today = day(2026, 11, 15)
        for text in ["Pay rent until 12/15", "Pay rent due 12/15", "Pay rent by December 15", "Pay rent until December 15"] {
            let found = try #require(find(text, today: today), "\(text)")
            #expect(found.day == day(2026, 12, 15), "\(text) gave \(found.day)")
        }
    }

    /// Smart Add treats "till" and "before" as deadline words (TaskRowCard `setTypedDate`), but
    /// `TypedDate.title` strips only on/by/due/until/for, so Set Date renames the task to
    /// "Pay rent till" / "Pay rent before".
    @Test("Set Date's new name drops a deadline word before the date: till and before too")
    func deadlineWordsLeaveTheName() throws {
        let today = day(2026, 11, 15)
        for word in ["by", "due", "until", "till", "before"] {
            let found = try #require(find("Pay rent \(word) December 15", today: today), "\(word)")
            print("REVIEW: 'Pay rent \(word) December 15' → title '\(found.titleWithoutDate)', phrase '\(found.phrase)', day \(found.day)")
            #expect(found.titleWithoutDate == "Pay rent", "'\(word)': got '\(found.titleWithoutDate)'")
            #expect(found.day == day(2026, 12, 15))
        }
    }
}

// MARK: - Holidays and What's New (checked)

struct ReviewCodeHolidayTests {
    private let cal = calendar("America/New_York")

    @Test("Thanksgiving is the 4th Thursday (US) and 2nd Monday of October (CA), 2026–2028")
    func thanksgivingDays() {
        #expect(Thanksgiving.day(in: 2026, region: "US") == day(2026, 11, 26))
        #expect(Thanksgiving.day(in: 2027, region: "US") == day(2027, 11, 25))
        #expect(Thanksgiving.day(in: 2028, region: "US") == day(2028, 11, 23))
        #expect(Thanksgiving.day(in: 2026, region: "CA") == day(2026, 10, 12))
        #expect(Thanksgiving.isWeek(of: day(2026, 11, 23), firstWeekday: 2, calendar: cal, region: "US"))
        #expect(Thanksgiving.isWeek(of: day(2026, 11, 29), firstWeekday: 2, calendar: cal, region: "US"))
        #expect(!Thanksgiving.isWeek(of: day(2026, 11, 29), firstWeekday: 1, calendar: cal, region: "US"), "Sunday starts a new week")
        #expect(Thanksgiving.isWeek(of: day(2026, 11, 22), firstWeekday: 1, calendar: cal, region: "US"))
        #expect(!Thanksgiving.isWeek(of: day(2026, 11, 15), firstWeekday: 2, calendar: cal, region: "US"))
    }

    @Test("Lights two weeks then confetti across 2026/27 and 2028/29 (Christmas on a Monday holds New Year's Eve)")
    func holidayWeeks() {
        let of = { (d: DayKey, first: Int) in HolidayMark.of(d, firstWeekday: first, calendar: cal, region: "US") }
        #expect(of(day(2026, 12, 13), 2) == nil)
        #expect(of(day(2026, 12, 14), 2) == .holidaySeason)
        #expect(of(day(2026, 12, 27), 2) == .holidaySeason)
        #expect(of(day(2026, 12, 28), 2) == .newYear)
        #expect(of(day(2027, 1, 3), 2) == .newYear)
        #expect(of(day(2027, 1, 4), 2) == nil)
        #expect(of(day(2028, 12, 31), 2) == .holidaySeason, "Christmas week Dec 25–31 2028 holds New Year's Eve")
        #expect(of(day(2029, 1, 1), 2) == .newYear, "then New Year's Day's week")
        #expect(of(day(2029, 1, 8), 2) == nil)
    }

    @Test("What's New compares versions by number")
    func versions() {
        #expect(WhatsNew.isVersion("1.0.3", olderThan: "1.1"))
        #expect(WhatsNew.isVersion("1.0", olderThan: "1.1"))
        #expect(!WhatsNew.isVersion("1.1", olderThan: "1.1"))
        #expect(!WhatsNew.isVersion("1.1.0", olderThan: "1.1"))
        #expect(!WhatsNew.isVersion("1.10", olderThan: "1.9"))
    }

    @Test("What's New's pill: shown to someone updating from 1.0.x, not to a new install")
    @MainActor func whatsNewPill() {
        let clock = TestClock(2026, 11, 15)
        let updater = UserDefaults(suiteName: "ReviewCode-\(UUID().uuidString)")!
        updater.set(true, forKey: "didMigrateStarters_v1")
        let updated = ChecklistStore(directory: reviewTempDirectory(), defaults: updater, now: { clock.now },
                                     calendar: { clock.calendar }, appVersion: "1.1")
        #expect(updated.showsWhatsNewButton)
        let fresh = ChecklistStore(directory: reviewTempDirectory(), defaults: UserDefaults(suiteName: "ReviewCode-\(UUID().uuidString)")!,
                                   now: { clock.now }, calendar: { clock.calendar }, appVersion: "1.1")
        #expect(!fresh.showsWhatsNewButton)
    }
}

// MARK: - Data from 1.0.3

@MainActor @Suite(.serialized)
struct ReviewCodeOldDataTests {
    @Test("A 1.0.3 checklist.json (no new fields) loads, keeps its tasks, and gets the new defaults")
    func loads103Data() throws {
        let directory = reviewTempDirectory()
        let file = """
        [{"id":"A1B2C3D4-E5F6-7890-ABCD-EF1234567890","startDay":"2026-11-09","startDate":"2026-11-09T05:00:00Z",
          "didFinalSync":true,
          "categories":[{"id":"B1B2C3D4-E5F6-7890-ABCD-EF1234567890","name":"Work","symbol":"briefcase","isThisWeekOnly":false,
          "tasks":[{"id":"C1B2C3D4-E5F6-7890-ABCD-EF1234567890","title":"Report","isCompleted":false,
          "mode":"carryOver","subtasks":[],"taskType":"checkbox","isUserEdited":true,"isListFolded":false}]}]}]
        """
        try Data(file.utf8).write(to: directory.appending(path: "checklist.json"))
        let settings = #"{"savedCategories":[{"id":"D1B2C3D4-E5F6-7890-ABCD-EF1234567890","name":"Work","symbol":"briefcase"}],"appearanceMode":"dark","hasSeenWelcome":true,"weekStartsOnSunday":false}"#
        try Data(settings.utf8).write(to: directory.appending(path: "settings.json"))
        let store = reviewStore(TestClock(2026, 11, 15), directory: directory)
        #expect(store.persistenceError == nil)
        let task = try #require(store.selectedWeek?.categories.first?.tasks.first)
        #expect(task.title == "Report" && task.dayOfWeek == nil && task.expiresOn == nil && !task.isPinned && !task.hasOwnTitle)
        #expect(store.remindsBeforeExpiry, "reminders default on")
        #expect(store.appearanceMode == .dark)
    }

    @Test("A bad value in a new field drops only that field, not the file")
    func lenientNewFields() throws {
        let directory = reviewTempDirectory()
        let file = """
        [{"id":"A1B2C3D4-E5F6-7890-ABCD-EF1234567890","startDay":"2026-11-09","didFinalSync":true,
          "categories":[{"id":"B1B2C3D4-E5F6-7890-ABCD-EF1234567890","name":"Work","symbol":"briefcase","isPinned":"yes",
          "tasks":[{"id":"C1B2C3D4-E5F6-7890-ABCD-EF1234567890","title":"Report","isCompleted":false,"mode":"carryOver",
          "subtasks":[],"taskType":"checkbox","dayOfWeek":9,"expiresOn":"soon","daySetOn":12,"isPinned":1,"expirySetOn":"2026-11"}]}]}]
        """
        try Data(file.utf8).write(to: directory.appending(path: "checklist.json"))
        let store = reviewStore(TestClock(2026, 11, 15), directory: directory)
        #expect(store.persistenceError == nil)
        let task = try #require(store.selectedWeek?.categories.first?.tasks.first)
        #expect(task.title == "Report" && task.dayOfWeek == nil && task.expiresOn == nil && task.daySetOn == nil)
    }
}
