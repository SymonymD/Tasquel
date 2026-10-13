//
//  TasquelTests.swift
//  TasquelTests
//
//  Created by John Fentner on 2/8/26.
//

import Testing
import Foundation
import SwiftUI
@testable import Tasquel

/// A store backed by a throwaway directory and defaults suite, so tests can run
/// in parallel without reading or overwriting the app's real data.
private func makeIsolatedStore(directory: URL = makeTempDirectory()) -> ChecklistStore {
    let suite = "TasquelTests-\(UUID().uuidString)"
    return ChecklistStore(directory: directory, defaults: UserDefaults(suiteName: suite)!)
}

private func makeTempDirectory() -> URL {
    let url = FileManager.default.temporaryDirectory.appending(path: "TasquelTests-\(UUID().uuidString)")
    try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

@Test("Welcome animation loop has one shared length")
func welcomeAnimationTimelineLength() {
    let timeline = KeyframeTimeline(initialValue: WeekCarryOverAnimation.Values()) {
        WeekCarryOverAnimation.timeline
    }
    #expect(abs(timeline.duration - 6) < 0.001)
}

@Test("Reduce Motion frame matches where the animation comes to rest")
func welcomeAnimationRestingFrameMatchesReduceMotion() {
    let timeline = KeyframeTimeline(initialValue: WeekCarryOverAnimation.Values()) {
        WeekCarryOverAnimation.timeline
    }
    let resting = timeline.value(time: 5.0)
    let finished = WeekCarryOverAnimation.Values.finished
    // Springs may still be settling slightly; allow differences too small to see.
    #expect(abs(resting.check1 - finished.check1) < 0.05)
    #expect(abs(resting.check2 - finished.check2) < 0.05)
    #expect(abs(resting.carriedCheck - finished.carriedCheck) < 0.05)
    #expect(abs(resting.lift - finished.lift) < 0.05)
    #expect(abs(resting.nextWeekX - finished.nextWeekX) < 0.5)
    #expect(abs(resting.carriedY - finished.carriedY) < 0.5)
    #expect(resting.thisWeekFade < 0.01)
}

// MARK: - Category Grid Layout

@Test("Collapsed cards pair into two-column rows")
func gridPairsCollapsedCards() {
    #expect(CategoryGridLayout.rows(fullWidth: [false, false, false, false, false])
            == [[0, 1], [2, 3], [4]])
}

@Test("An expanded card gets its own row and the cards after it keep pairing")
func gridExpandedCardTakesFullRow() {
    #expect(CategoryGridLayout.rows(fullWidth: [true, false, false, false])
            == [[0], [1, 2], [3]])
}

@Test("A card waiting for a partner stays alone when an expanded card follows")
func gridHalfCardBeforeExpandedStaysAlone() {
    #expect(CategoryGridLayout.rows(fullWidth: [false, true, false, false])
            == [[0], [1], [2, 3]])
    #expect(CategoryGridLayout.rows(fullWidth: [false, false, false, true])
            == [[0, 1], [2], [3]])
}

// MARK: - Rollover Logic Tests
//
// These tests exercise ChecklistStore's rollForwardCategories behaviour directly
// by constructing Week values and calling ensureWeekExists to trigger rollover.
// They use a date well in the future so they never collide with real data on disk.

struct RolloverTests {

    // Convenience: a Monday guaranteed to be in the future (year 2099)
    private func futureMonday(weeksFromBase offset: Int = 0) -> Date {
        var components = DateComponents()
        components.year = 2099
        components.month = 1
        components.day = 5 // a Monday in 2099
        let base = Calendar.current.date(from: components)!
        return Calendar.current.date(byAdding: .weekOfYear, value: offset, to: base)!
    }

    // MARK: - Carry-over tasks

    @Test("Incomplete carry-over task rolls to next week")
    func carryOverIncompleteRolls() {
        let store = makeIsolatedStore()
        let monday = futureMonday()

        // Seed week 0 with an incomplete carry-over task
        store.weeks = [Week(startDate: monday)]
        store.weeks[0].categories = [
            Category(name: "Work", symbol: "briefcase",
                     tasks: [ChecklistTask(title: "Finish report", isCompleted: false, mode: .carryOver)])
        ]

        // Trigger rollover into week 1
        let nextMonday = futureMonday(weeksFromBase: 1)
        let nextWeek = store.ensureWeekExists(for: nextMonday)

        #expect(nextWeek.categories.first?.tasks.contains(where: { $0.title == "Finish report" }) == true,
                "Incomplete carry-over task should appear in next week")
    }

    @Test("Completed carry-over task does NOT roll to next week")
    func carryOverCompletedDoesNotRoll() {
        let store = makeIsolatedStore()
        let monday = futureMonday(weeksFromBase: 10)

        store.weeks = [Week(startDate: monday)]
        store.weeks[0].categories = [
            Category(name: "Work", symbol: "briefcase",
                     tasks: [ChecklistTask(title: "Done task", isCompleted: true, mode: .carryOver)])
        ]

        let nextWeek = store.ensureWeekExists(for: futureMonday(weeksFromBase: 11))

        #expect(nextWeek.categories.first?.tasks.contains(where: { $0.title == "Done task" }) == false,
                "Completed carry-over task should NOT appear in next week")
    }

    // MARK: - Repeating tasks

    @Test("Repeating task always rolls regardless of completion")
    func repeatingAlwaysRolls() {
        let store = makeIsolatedStore()
        let monday = futureMonday(weeksFromBase: 20)

        store.weeks = [Week(startDate: monday)]
        store.weeks[0].categories = [
            Category(name: "Fitness", symbol: "figure.run",
                     tasks: [ChecklistTask(title: "Morning run", isCompleted: true, mode: .repeating)])
        ]

        let nextWeek = store.ensureWeekExists(for: futureMonday(weeksFromBase: 21))

        #expect(nextWeek.categories.first?.tasks.contains(where: { $0.title == "Morning run" }) == true,
                "Repeating task should always appear in next week")
    }

    @Test("Repeating task resets progress to zero on rollover")
    func repeatingGoalResetsProgress() {
        let store = makeIsolatedStore()
        let monday = futureMonday(weeksFromBase: 30)

        var goalTask = ChecklistTask(title: "Push-ups", mode: .repeating)
        goalTask.taskType = .goal
        goalTask.goalTarget = 50
        goalTask.goalProgress = 50  // fully completed

        store.weeks = [Week(startDate: monday)]
        store.weeks[0].categories = [
            Category(name: "Fitness", symbol: "figure.run", tasks: [goalTask])
        ]

        let nextWeek = store.ensureWeekExists(for: futureMonday(weeksFromBase: 31))
        let rolledTask = nextWeek.categories.first?.tasks.first(where: { $0.title == "Push-ups" })

        #expect(rolledTask != nil, "Repeating goal task should appear in next week")
        #expect(rolledTask?.goalProgress == 0, "Goal progress should reset to 0 for repeating tasks")
        #expect(rolledTask?.isCompleted == false, "Repeating task should reset to incomplete")
    }

    // MARK: - One-time tasks

    @Test("One-time task never rolls to next week")
    func oneTimeNeverRolls() {
        let store = makeIsolatedStore()
        let monday = futureMonday(weeksFromBase: 40)

        store.weeks = [Week(startDate: monday)]
        store.weeks[0].categories = [
            Category(name: "Errands", symbol: "cart",
                     tasks: [ChecklistTask(title: "Buy gift", isCompleted: false, mode: .oneTime)])
        ]

        let nextWeek = store.ensureWeekExists(for: futureMonday(weeksFromBase: 41))

        #expect(nextWeek.categories.first?.tasks.contains(where: { $0.title == "Buy gift" }) == false,
                "One-time task should never appear in next week, even if incomplete")
    }

    // MARK: - Subtask behaviour

    @Test("Carry-over task carries incomplete subtasks only")
    func carryOverBringsIncompleteSubtasksOnly() {
        let store = makeIsolatedStore()
        let monday = futureMonday(weeksFromBase: 50)

        var task = ChecklistTask(title: "Project", mode: .carryOver)
        task.subtasks = [
            SubTask(title: "Done subtask", isCompleted: true),
            SubTask(title: "Pending subtask", isCompleted: false),
        ]

        store.weeks = [Week(startDate: monday)]
        store.weeks[0].categories = [
            Category(name: "Work", symbol: "briefcase", tasks: [task])
        ]

        let nextWeek = store.ensureWeekExists(for: futureMonday(weeksFromBase: 51))
        let rolledTask = nextWeek.categories.first?.tasks.first(where: { $0.title == "Project" })

        #expect(rolledTask?.subtasks.count == 1, "Only incomplete subtasks should carry over")
        #expect(rolledTask?.subtasks.first?.title == "Pending subtask", "Incomplete subtask should be present")
    }

    @Test("Repeating task resets all subtasks on rollover")
    func repeatingResetsSubtasks() {
        let store = makeIsolatedStore()
        let monday = futureMonday(weeksFromBase: 60)

        var task = ChecklistTask(title: "Weekly review", mode: .repeating)
        task.subtasks = [
            SubTask(title: "Check email", isCompleted: true),
            SubTask(title: "Update docs", isCompleted: false),
        ]

        store.weeks = [Week(startDate: monday)]
        store.weeks[0].categories = [
            Category(name: "Work", symbol: "briefcase", tasks: [task])
        ]

        let nextWeek = store.ensureWeekExists(for: futureMonday(weeksFromBase: 61))
        let rolledTask = nextWeek.categories.first?.tasks.first(where: { $0.title == "Weekly review" })

        #expect(rolledTask?.subtasks.count == 2, "All subtasks should appear in repeating task rollover")
        #expect(rolledTask?.subtasks.allSatisfy({ !$0.isCompleted }) == true,
                "All subtasks should be reset to incomplete")
    }

    // MARK: - Category structure

    @Test("All categories carry forward to next week")
    func allCategoriesRollForward() {
        let store = makeIsolatedStore()
        let monday = futureMonday(weeksFromBase: 70)

        store.weeks = [Week(startDate: monday)]
        store.weeks[0].categories = [
            Category(name: "Work", symbol: "briefcase"),
            Category(name: "Fitness", symbol: "figure.run"),
            Category(name: "Errands", symbol: "cart"),
        ]

        let nextWeek = store.ensureWeekExists(for: futureMonday(weeksFromBase: 71))
        let names = nextWeek.categories.map(\.name)

        #expect(names.contains("Work"), "Work category should roll forward")
        #expect(names.contains("Fitness"), "Fitness category should roll forward")
        #expect(names.contains("Errands"), "Errands category should roll forward")
    }

    // MARK: - Goal carry-over progress

    @Test("Carry-over goal task preserves existing progress")
    func carryOverGoalPreservesProgress() {
        let store = makeIsolatedStore()
        let monday = futureMonday(weeksFromBase: 80)

        var goalTask = ChecklistTask(title: "Read pages", mode: .carryOver)
        goalTask.taskType = .goal
        goalTask.goalTarget = 100
        goalTask.goalProgress = 40  // partially done

        store.weeks = [Week(startDate: monday)]
        store.weeks[0].categories = [
            Category(name: "Study", symbol: "book", tasks: [goalTask])
        ]

        let nextWeek = store.ensureWeekExists(for: futureMonday(weeksFromBase: 81))
        let rolledTask = nextWeek.categories.first?.tasks.first(where: { $0.title == "Read pages" })

        #expect(rolledTask != nil, "Incomplete carry-over goal task should appear in next week")
        #expect(rolledTask?.goalProgress == 40, "Carry-over goal task should preserve partial progress")
        #expect(rolledTask?.goalTarget == 100, "Carry-over goal task should preserve target")
    }

    // MARK: - Category deletion

    @Test("Deleting a category removes it from the current and future weeks, keeps past weeks and its template")
    func deleteCategoryStaysDeleted() {
        let store = makeIsolatedStore()
        let thisMonday = Week.startOfWeek(containing: Date())
        let lastMonday = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: thisMonday)!
        let nextMonday = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: thisMonday)!
        store.weeks = [lastMonday, thisMonday, nextMonday].map {
            Week(startDate: $0, categories: [Category(name: "Gone", symbol: "star"), Category(name: "Kept", symbol: "house")])
        }
        store.savedCategories = []
        store.selectedDate = nextMonday  // delete while viewing a future week

        let id = store.selectedWeek!.categories.first { $0.name == "Gone" }!.id
        store.deleteCategory(id)

        let names = { (date: Date) in store.weeks.first { Calendar.current.isDate($0.startDate, inSameDayAs: date) }!.categories.map(\.name) }
        #expect(names(lastMonday).contains("Gone"), "past weeks keep their history")
        #expect(!names(thisMonday).contains("Gone"))
        #expect(!names(nextMonday).contains("Gone"))
        #expect(names(nextMonday).contains("Kept"))

        // Revisiting the future week must not bring it back via future-week sync.
        store.navigateToDate(thisMonday)
        store.navigateToDate(nextMonday)
        #expect(!(store.selectedWeek?.categories.contains { $0.name == "Gone" } ?? true))
        #expect(store.savedCategories.contains { $0.name == "Gone" }, "kept so it can be re-added")
    }
}

struct JourneySafetyTests {
    @Test("Past weeks reject task and category changes")
    func pastWeekIsReadOnly() {
        let store = makeIsolatedStore()
        let pastDate = Calendar.current.date(byAdding: .weekOfYear, value: -2, to: Date())!
        let task = ChecklistTask(title: "Original")
        let category = Category(name: "History", symbol: "clock", tasks: [task])
        store.weeks = [Week(startDate: Week.startOfWeek(containing: pastDate), categories: [category])]
        store.selectedDate = pastDate

        store.renameTask(categoryID: category.id, taskID: task.id, newTitle: "Changed")
        store.deleteCategory(category.id)

        #expect(store.selectedWeek?.categories.first?.tasks.first?.title == "Original")
        #expect(store.selectedWeek?.categories.count == 1)
    }

    @Test("Nonpositive goal targets and progress do not change a goal")
    func invalidGoalValuesAreRejected() {
        let store = makeIsolatedStore()
        let task = ChecklistTask(title: "Read", taskType: .goal)
        let category = Category(name: "Study", symbol: "book", tasks: [task])
        store.weeks = [Week(startDate: Week.startOfWeek(containing: Date()), categories: [category])]
        store.selectedDate = Date()

        store.setGoalTarget(categoryID: category.id, taskID: task.id, target: 0, unit: "pages")
        store.updateGoalProgress(categoryID: category.id, taskID: task.id, progress: -1)

        #expect(store.selectedWeek?.categories.first?.tasks.first?.goalTarget == nil)
        #expect(store.selectedWeek?.categories.first?.tasks.first?.goalProgress == nil)
    }

    @Test("A failed week load must not overwrite the unreadable file")
    func failedLoadPreservesFile() throws {
        let directory = makeTempDirectory()
        let fileURL = directory.appending(path: "checklist.json")
        let malformed = Data("not valid JSON".utf8)
        try malformed.write(to: fileURL, options: .atomic)

        let store = makeIsolatedStore(directory: directory)
        let nextWeek = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: Date())!
        store.navigateToDate(nextWeek)

        #expect(store.persistenceError != nil)
        #expect(try Data(contentsOf: fileURL) == malformed)
    }

    @Test("Retrying after a load failure finishes normal setup")
    func retryAfterLoadFailureRecovers() throws {
        let directory = makeTempDirectory()
        let settingsURL = directory.appending(path: "settings.json")
        try Data("not valid JSON".utf8).write(to: settingsURL, options: .atomic)

        let store = makeIsolatedStore(directory: directory)
        #expect(store.persistenceError != nil)
        #expect(store.savedCategories.isEmpty)

        try FileManager.default.removeItem(at: settingsURL)
        store.retryLoadingData()

        #expect(store.persistenceError == nil)
        #expect(!store.savedCategories.isEmpty, "Retry should seed starter templates like a normal launch")
        #expect(store.selectedWeek != nil, "Retry should create the current week")
    }
}

struct WeekPreviewTests {
    @Test("Previewing a week matches navigating to it, without creating it")
    func previewMatchesNavigation() {
        let store = makeIsolatedStore()
        var components = DateComponents()
        components.year = 2099; components.month = 3; components.day = 2  // a Monday
        let monday = Calendar.current.date(from: components)!
        let nextMonday = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: monday)!
        store.weeks = [Week(startDate: monday, categories: [
            Category(name: "Work", symbol: "briefcase", tasks: [
                ChecklistTask(title: "Report", isCompleted: false, mode: .carryOver),
                ChecklistTask(title: "Gym", isCompleted: true, mode: .repeating),
                ChecklistTask(title: "Once", isCompleted: false, mode: .oneTime),
            ])
        ])]

        let preview = store.previewWeek(for: nextMonday)
        #expect(store.weeks.count == 1, "previewing must not create the week")

        store.navigateToDate(nextMonday)
        let actual = store.selectedWeek
        #expect(preview.categories.map(\.name) == actual?.categories.map(\.name))
        #expect(preview.categories.map { $0.tasks.map(\.title).sorted() }
                == actual?.categories.map { $0.tasks.map(\.title).sorted() })
    }
}

struct ThisWeekOnlyCategoryTests {
    private func monday(weeksAfter offset: Int = 0) -> Date {
        var components = DateComponents()
        components.year = 2099; components.month = 6; components.day = 1  // a Monday
        let base = Calendar.current.date(from: components)!
        return Calendar.current.date(byAdding: .weekOfYear, value: offset, to: base)!
    }

    @Test("A this-week-only category doesn't roll forward; an every-week one does")
    func thisWeekOnlyDoesNotRoll() {
        let store = makeIsolatedStore()
        store.weeks = [Week(startDate: monday())]
        store.selectedDate = monday()
        store.addCategory(name: "Trip", symbol: "airplane", thisWeekOnly: true)
        store.addCategory(name: "Chores", symbol: "house")

        let next = store.ensureWeekExists(for: monday(weeksAfter: 1))
        #expect(!next.categories.contains { $0.name == "Trip" })
        #expect(next.categories.contains { $0.name == "Chores" && !$0.isThisWeekOnly })
    }

    @Test("Future-week previews and sync skip this-week-only categories")
    func futureSyncSkipsThisWeekOnly() {
        let store = makeIsolatedStore()
        store.weeks = [
            Week(startDate: monday()),
            Week(startDate: monday(weeksAfter: 1)),
        ]
        store.selectedDate = monday()
        store.addCategory(name: "Trip", symbol: "airplane", thisWeekOnly: true)

        #expect(!store.previewWeek(for: monday(weeksAfter: 1)).categories.contains { $0.name == "Trip" })
        store.navigateToDate(monday(weeksAfter: 1))
        #expect(!(store.selectedWeek?.categories.contains { $0.name == "Trip" } ?? true))
    }

    @Test("Categories saved before the flag existed load as every-week")
    func legacyCategoryDecodes() throws {
        let json = #"{"id":"A1B2C3D4-E5F6-7890-ABCD-EF1234567890","name":"Work","symbol":"briefcase","tasks":[]}"#
        let category = try JSONDecoder().decode(Category.self, from: Data(json.utf8))
        #expect(category.name == "Work")
        #expect(category.isThisWeekOnly == false)
    }
}

// MARK: - Calendar Integration

struct CalendarGroupingTests {
    private let calendar = Calendar.current
    private var monday: Date {
        var c = DateComponents(); c.year = 2099; c.month = 6; c.day = 1  // a Monday
        return calendar.date(from: c)!
    }
    private func at(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: calendar.date(byAdding: .day, value: day, to: monday)!)!
    }
    private func event(_ title: String, _ start: Date, _ end: Date, allDay: Bool = false) -> CalendarEvent {
        CalendarEvent(id: title, eventIdentifier: title, title: title, start: start, end: end, isAllDay: allDay, calendarID: "c", color: .blue)
    }
    private func days(_ events: [CalendarEvent]) -> [EventDay] {
        EventGrouping.days(for: events, weekStart: monday, calendar: calendar, timeFormatter: { date in
            let c = calendar.dateComponents([.hour, .minute], from: date)
            return String(format: "%02d:%02d", c.hour!, c.minute!)
        })
    }

    @Test("Timed events land on their start day; empty days are skipped; all-day sorts first")
    func timedAndAllDay() {
        let result = days([
            event("Lunch", at(1, 12), at(1, 13)),
            event("Standup", at(1, 9, 30), at(1, 10)),
            event("Holiday", at(1, 0), at(2, 0), allDay: true),
        ])
        #expect(result.count == 1)
        #expect(result.first?.date == at(1, 0))
        #expect(result.first?.events.map(\.event.title) == ["Holiday", "Standup", "Lunch"])
        #expect(result.first?.events.map(\.timeLabel) == ["All day", "09:30", "12:00"])
    }

    @Test("Multi-day events appear on each day they cover, only within the week")
    func multiDay() {
        let result = days([
            event("Trip", at(-2, 0), at(2, 0), allDay: true),       // started before Monday
            event("Night shift", at(5, 22), at(6, 6)),              // Saturday night into Sunday
            event("Conference", at(6, 9), at(9, 17)),               // runs past Sunday
        ])
        #expect(result.map { calendar.component(.weekday, from: $0.date) } == [2, 3, 7, 1])  // Mon, Tue, Sat, Sun
        #expect(result[0].events.first?.timeLabel == "All day")
        let sunday = result[3].events.map { "\($0.event.title): \($0.timeLabel)" }
        #expect(sunday.contains("Night shift: Until 06:00"))
        #expect(sunday.contains("Conference: 09:00"))
    }

    @Test("Events spanning a whole day in the middle show as continuing")
    func continuing() {
        let result = days([event("Retreat", at(2, 15), at(4, 11))])
        #expect(result.map(\.events.first!.timeLabel) == ["15:00", "Continues", "Until 11:00"])
    }

    @Test("The service loads a week from the provider and drops it when invalidated")
    func serviceCaching() async {
        let service = CalendarService(provider: FakeEventProvider())
        await service.loadCalendars()
        #expect(Set(service.defaultSelection) == ["home", "work"], "birthdays are not selected by default")
        let ids = Set(service.defaultSelection)
        #expect(service.days(forWeekStarting: monday, calendarIDs: ids) == nil)
        await service.load(weekStarting: monday, calendarIDs: ids)
        let loaded = service.days(forWeekStarting: monday, calendarIDs: ids)
        #expect(loaded?.flatMap(\.events).contains { $0.event.title == "Dentist" } == true)
        #expect(loaded?.flatMap(\.events).contains { $0.event.title == "Sam's Birthday" } == false)
        service.invalidate()
        #expect(service.days(forWeekStarting: monday, calendarIDs: ids) == nil)
    }

    @Test("Before the calendar list loads, the saved selection is used as-is")
    func selectionBeforeCalendarsLoad() async {
        let service = CalendarService(provider: FakeEventProvider())
        // Regression: at launch the list wasn't loaded, every saved calendar looked
        // deleted, and no events showed until Settings was opened.
        #expect(service.effectiveSelection(["work"]) == ["work"])
        await service.loadCalendars()
        #expect(service.effectiveSelection(["work"]) == ["work"])
    }

    @Test("Saved calendars that no longer exist are dropped; if none remain, the default is used")
    func staleCalendarSelection() async {
        let service = CalendarService(provider: FakeEventProvider())
        await service.loadCalendars()
        #expect(service.effectiveSelection(nil) == ["home", "work"])
        #expect(service.effectiveSelection(["work", "deleted"]) == ["work"])
        #expect(service.effectiveSelection(["deleted"]) == ["home", "work"])
    }

    @Test("Settings saved before calendar integration still load, with it turned off")
    func legacySettingsLoad() throws {
        let directory = makeTempDirectory()
        let legacy = #"{"savedCategories":[],"appearanceMode":"dark","hasSeenWelcome":true}"#
        try Data(legacy.utf8).write(to: directory.appending(path: "settings.json"))
        let store = makeIsolatedStore(directory: directory)
        #expect(store.persistenceError == nil)
        #expect(store.calendarEventsEnabled == false)
        #expect(store.selectedCalendarIDs == nil)
        #expect(store.weekStartsOnSunday == false, "weeks start on Monday by default")
        store.setCalendarEventsEnabled(true)
        store.setSelectedCalendarIDs(["a", "b"])
        let reloaded = makeIsolatedStore(directory: directory)
        #expect(reloaded.calendarEventsEnabled == true)
        #expect(reloaded.selectedCalendarIDs == ["a", "b"])
    }
}


// MARK: - Week Start Day

struct WeekStartTests {
    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: y, month: m, day: d))!
    }

    @Test("A week starts on the chosen day")
    func startOfWeek() {
        let wednesday = date(2099, 6, 3)
        #expect(Week.startOfWeek(containing: wednesday, firstWeekday: Week.monday) == date(2099, 6, 1))
        #expect(Week.startOfWeek(containing: wednesday, firstWeekday: Week.sunday) == date(2099, 5, 31))
        // Sunday itself: the last day of a Monday week, the first day of a Sunday week.
        let sunday = date(2099, 6, 7)
        #expect(Week.startOfWeek(containing: sunday, firstWeekday: Week.monday) == date(2099, 6, 1))
        #expect(Week.startOfWeek(containing: sunday, firstWeekday: Week.sunday) == date(2099, 6, 7))
    }

    @Test("Switching to Sunday moves every week back a day with its tasks, and switching back restores it")
    func switchingMovesWeeks() {
        let directory = makeTempDirectory()
        let store = makeIsolatedStore(directory: directory)
        let mondays = [date(2099, 6, 1), date(2099, 6, 8)]
        store.weeks = mondays.enumerated().map { index, monday in
            Week(startDate: monday, categories: [Category(name: "Work", symbol: "briefcase",
                                                          tasks: [ChecklistTask(title: "Task \(index)")])])
        }
        store.selectedDate = date(2099, 6, 10)  // Wednesday of the second week
        let selectedID = store.selectedWeek?.id

        store.setWeekStartsOnSunday(true)
        // The store keeps weeks newest first, and also ensures the real current week exists.
        let moved = store.weeks.filter { $0.startDate > date(2099, 1, 1) }.sorted { $0.startDate < $1.startDate }
        #expect(moved.map(\.startDate) == [date(2099, 5, 31), date(2099, 6, 7)])
        #expect(moved.map { $0.categories.first?.tasks.first?.title } == ["Task 0", "Task 1"])
        #expect(store.selectedWeek?.id == selectedID, "the same week stays selected")

        let reloaded = makeIsolatedStore(directory: directory)
        #expect(reloaded.weekStartsOnSunday)
        #expect(reloaded.weeks.contains { $0.startDate == date(2099, 5, 31) })

        store.setWeekStartsOnSunday(false)
        #expect(store.weeks.filter { $0.startDate > date(2099, 1, 1) }.map(\.startDate).sorted() == mondays)
        #expect(store.selectedWeek?.id == selectedID)
    }

    @Test("The current week is the one containing today, whatever day it starts on")
    func currentWeekAnyStart() {
        let today = Date()
        let sundayWeek = Week(startDate: Week.startOfWeek(containing: today, firstWeekday: Week.sunday))
        let mondayWeek = Week(startDate: Week.startOfWeek(containing: today, firstWeekday: Week.monday))
        #expect(sundayWeek.isCurrentWeek)
        #expect(mondayWeek.isCurrentWeek)
        let lastWeek = Week(startDate: Calendar.current.date(byAdding: .day, value: -7, to: sundayWeek.startDate)!)
        #expect(lastWeek.isPastWeek)
    }
}
