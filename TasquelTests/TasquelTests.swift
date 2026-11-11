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
private func makeIsolatedStore(directory: URL = makeTempDirectory(), clock: TestClock? = nil,
                               defaults: UserDefaults? = nil) -> ChecklistStore {
    let defaults = defaults ?? UserDefaults(suiteName: "TasquelTests-\(UUID().uuidString)")!
    guard let clock else { return ChecklistStore(directory: directory, defaults: defaults) }
    return ChecklistStore(directory: directory, defaults: defaults,
                          now: { clock.now }, calendar: { clock.calendar })
}

/// A "now" and calendar a test controls: move the time, or fly to another time zone.
final class TestClock {
    var now: Date
    var calendar: Calendar

    /// Noon on the given day, in `timeZone`.
    init(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12, timeZone: String = "America/New_York") {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZone)!
        self.calendar = calendar
        now = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    func weeks(_ count: Int, from date: Date) -> Date {
        calendar.date(byAdding: .weekOfYear, value: count, to: date)!
    }
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

@Test("Onboarding feature animations loop every 6 seconds and rest on their Reduce Motion frame")
func featureAnimationTimelines() {
    let types = KeyframeTimeline(initialValue: TaskTypesAnimation.Values()) { TaskTypesAnimation.timeline }
    #expect(abs(types.duration - 6) < 0.001)
    let typesRest = types.value(time: 5.0), typesDone = TaskTypesAnimation.Values.finished
    for path in [\TaskTypesAnimation.Values.check, \.goal, \.goalCheck, \.item1, \.item2, \.listCheck] {
        #expect(abs(typesRest[keyPath: path] - typesDone[keyPath: path]) < 0.05)
    }

    let modes = KeyframeTimeline(initialValue: TaskModesAnimation.Values()) { TaskModesAnimation.timeline }
    #expect(abs(modes.duration - 6) < 0.001)
    let modesRest = modes.value(time: 5.0), modesDone = TaskModesAnimation.Values.finished
    for path in [\TaskModesAnimation.Values.oneTimeCheck, \.repeatingCheck, \.pending, \.thisWeekFade,
                 \.nextWeekFade, \.carriedIn, \.repeatedIn, \.reset] {
        #expect(abs(modesRest[keyPath: path] - modesDone[keyPath: path]) < 0.05)
    }
    #expect(abs(modesRest.nextWeekX - modesDone.nextWeekX) < 0.5)

    let cards = KeyframeTimeline(initialValue: CategoryCardsAnimation.Values()) { CategoryCardsAnimation.timeline }
    #expect(abs(cards.duration - 6) < 0.001)
    let cardsRest = cards.value(time: 5.0), cardsDone = CategoryCardsAnimation.Values.finished
    for path in [\CategoryCardsAnimation.Values.tap, \.press, \.expand, \.check1, \.check2] {
        #expect(abs(cardsRest[keyPath: path] - cardsDone[keyPath: path]) < 0.05)
    }

    let events = KeyframeTimeline(initialValue: CalendarEventsAnimation.Values()) { CalendarEventsAnimation.timeline }
    #expect(abs(events.duration - 6) < 0.001)
    let eventsRest = events.value(time: 5.0), eventsDone = CalendarEventsAnimation.Values.finished
    for path in [\CalendarEventsAnimation.Values.tap, \.open, \.event1, \.event2, \.event3] {
        #expect(abs(eventsRest[keyPath: path] - eventsDone[keyPath: path]) < 0.05)
    }
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

    @Test("Deleting a category from a future week removes it from that week on; earlier weeks and its template keep it")
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
        #expect(names(thisMonday).contains("Gone"), "weeks before the viewed one keep it")
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

@MainActor
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

@MainActor
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
        let clock = TestClock(2099, 6, 10)  // a Wednesday
        let store = makeIsolatedStore(directory: directory, clock: clock)
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

        let reloaded = makeIsolatedStore(directory: directory, clock: clock)
        #expect(reloaded.weekStartsOnSunday)
        #expect(reloaded.weeks.contains { $0.startDate == date(2099, 5, 31) })

        store.setWeekStartsOnSunday(false)
        #expect(store.weeks.filter { $0.startDate > date(2099, 1, 1) }.map(\.startDate).sorted() == mondays)
        #expect(store.selectedWeek?.id == selectedID)
    }

    @Test("The current week is the one containing today, whatever day it starts on")
    func currentWeekAnyStart() {
        let clock = TestClock(2099, 3, 4)  // a Wednesday
        let store = makeIsolatedStore(clock: clock)
        let sundayWeek = Week(startDate: Week.startOfWeek(containing: clock.now, firstWeekday: Week.sunday, calendar: clock.calendar))
        let mondayWeek = Week(startDate: Week.startOfWeek(containing: clock.now, firstWeekday: Week.monday, calendar: clock.calendar))
        #expect(store.isCurrentWeek(sundayWeek))
        #expect(store.isCurrentWeek(mondayWeek))
        let lastWeek = Week(startDate: clock.calendar.date(byAdding: .day, value: -7, to: sundayWeek.startDate)!)
        #expect(store.isPastWeek(lastWeek))
    }
}

// MARK: - Goal Units

struct GoalUnitTests {
    @Test("Time goals show hours and minutes")
    func timeFormatting() {
        #expect(GoalUnitKind.time.format(90) == "1h 30m")
        #expect(GoalUnitKind.time.format(300) == "5h")
        #expect(GoalUnitKind.time.format(45) == "45m")
        #expect(GoalUnitKind.time.format(0) == "0m")

        var task = ChecklistTask(title: "Practice", taskType: .goal)
        task.goalUnitKind = .time
        task.goalTarget = 300
        task.goalProgress = 90
        #expect(task.goalFraction == "1h 30m / 5h")
        #expect(task.goalUnitLabel == nil)
    }

    @Test("Goals saved before unit kinds load as quantity, or custom when a unit was typed")
    func legacyGoalKind() throws {
        let json = #"{"id":"A1B2C3D4-E5F6-7890-ABCD-EF1234567890","title":"Read","isCompleted":false,"mode":"carryOver","subtasks":[],"taskType":"goal","goalTarget":20,"goalProgress":5,"goalUnit":"pages"}"#
        let task = try JSONDecoder().decode(ChecklistTask.self, from: Data(json.utf8))
        #expect(task.goalKind == .custom)
        #expect(task.goalUnitLabel == "pages")
        #expect(task.goalFraction == "5/20")
        #expect(ChecklistTask(title: "Push-ups", taskType: .goal).goalKind == .quantity)
    }

    @Test("Hours and minutes entry becomes minutes; switching units carries the amount")
    func amountInput() {
        var input = GoalAmountInput()
        input.hours = "1"
        input.minutes = "30"
        #expect(input.value(for: .time) == 90)
        #expect(input.converted(from: .time, to: .quantity).number == "1.5")
        #expect(GoalAmountInput().positiveValue(for: .time) == nil)
        #expect(GoalAmountInput(150, kind: .time).hours == "2")
        #expect(GoalAmountInput(150, kind: .time).minutes == "30")

        var count = GoalAmountInput()
        count.number = "3"
        #expect(count.converted(from: .quantity, to: .time).hours == "3")
        #expect(count.converted(from: .quantity, to: .custom) == count)
    }

    @Test("Setting a goal stores its unit kind, and it rolls into the next week")
    func setGoalStoresKind() {
        let store = makeIsolatedStore()
        let task = ChecklistTask(title: "Practice", mode: .repeating, taskType: .goal)
        let category = Category(name: "Music", symbol: "music.note", tasks: [task])
        store.weeks = [Week(startDate: Week.startOfWeek(containing: Date()), categories: [category])]
        store.selectedDate = Date()

        store.setGoalTarget(categoryID: category.id, taskID: task.id, target: 120, kind: .time, unit: "ignored")
        let saved = store.selectedWeek?.categories.first?.tasks.first
        #expect(saved?.goalUnitKind == .time)
        #expect(saved?.goalUnit == nil, "Only custom goals keep a unit name")

        let nextStart = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: store.weeks[0].startDate)!
        let rolled = store.ensureWeekExists(for: nextStart).categories.first?.tasks.first
        #expect(rolled?.goalUnitKind == .time)
        #expect(rolled?.goalTarget == 120)
    }
}

// MARK: - Task Type and Mode

struct TaskTypeAndModeTests {
    @Test("Type and mode change separately; leaving a goal clears it")
    func typeAndMode() {
        let store = makeIsolatedStore()
        let task = ChecklistTask(title: "Run", mode: .repeating)
        let category = Category(name: "Fitness", symbol: "figure.run", tasks: [task])
        store.weeks = [Week(startDate: Week.startOfWeek(containing: Date()), categories: [category])]
        store.selectedDate = Date()
        func saved() -> ChecklistTask? { store.selectedWeek?.categories.first?.tasks.first }

        store.updateTaskType(categoryID: category.id, taskID: task.id, type: .goal)
        #expect(saved()?.taskType == .goal)
        #expect(saved()?.mode == .repeating, "changing the type keeps the mode")

        store.setGoalTarget(categoryID: category.id, taskID: task.id, target: 5)
        store.updateTaskType(categoryID: category.id, taskID: task.id, type: .list)
        #expect(saved()?.goalTarget == nil)
        store.updateTaskMode(categoryID: category.id, taskID: task.id, mode: .oneTime)
        #expect(saved()?.taskType == .list, "changing the mode keeps the type")
        #expect(saved()?.mode == .oneTime)
    }

    @Test("A new task gets the type and mode it's added with")
    func addWithTypeAndMode() {
        let store = makeIsolatedStore()
        let category = Category(name: "Errands", symbol: "cart")
        store.weeks = [Week(startDate: Week.startOfWeek(containing: Date()), categories: [category])]
        store.selectedDate = Date()
        let id = store.addTask(categoryID: category.id, title: "Groceries", mode: .repeating, type: .list)
        let saved = store.selectedWeek?.categories.first?.tasks.first
        #expect(saved?.id == id)
        #expect(saved?.taskType == .list)
        #expect(saved?.mode == .repeating)
    }

    @Test("A repeating list comes back next week with its items as they were")
    func repeatingList() {
        let store = makeIsolatedStore()
        let list = ChecklistTask(title: "Groceries", mode: .repeating,
                                 subtasks: [SubTask(title: "Eggs", isCompleted: true), SubTask(title: "Milk")],
                                 taskType: .list)
        store.weeks = [Week(startDate: Week.startOfWeek(containing: Date()),
                            categories: [Category(name: "Errands", symbol: "cart", tasks: [list])])]
        let nextStart = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: store.weeks[0].startDate)!
        let rolled = store.ensureWeekExists(for: nextStart).categories.first?.tasks.first
        #expect(rolled?.taskType == .list)
        #expect(rolled?.subtasks.map(\.title) == ["Eggs", "Milk"])
        #expect(rolled?.subtasks.map(\.isCompleted) == [true, false], "checked items stay checked")
        #expect(rolled?.isCompleted == false)
    }
}

// MARK: - Categories

struct CategoryNameTests {
    private let thisMonday = Week.startOfWeek(containing: Date())
    private var nextMonday: Date { Calendar.current.date(byAdding: .weekOfYear, value: 1, to: thisMonday)! }
    private var lastMonday: Date { Calendar.current.date(byAdding: .weekOfYear, value: -1, to: thisMonday)! }

    private func makeStore() -> ChecklistStore {
        let store = makeIsolatedStore()
        store.weeks = [lastMonday, thisMonday, nextMonday].map {
            Week(startDate: $0, categories: [Category(name: "Work", symbol: "briefcase"), Category(name: "Home", symbol: "house")])
        }
        store.savedCategories = [CategoryTemplate(name: "Work", symbol: "briefcase"), CategoryTemplate(name: "Errands", symbol: "cart")]
        store.selectedDate = thisMonday
        return store
    }

    private func names(_ store: ChecklistStore, _ monday: Date) -> [String] {
        store.weeks.first { Calendar.current.isDate($0.startDate, inSameDayAs: monday) }!.categories.map(\.name)
    }

    @Test("Names are unique, ignoring case and spaces")
    func uniqueNames() {
        let store = makeStore()
        #expect(store.isCategoryNameTaken(" work "))
        #expect(store.isCategoryNameTaken("ERRANDS"), "a saved category counts")
        #expect(!store.isCategoryNameTaken("Garden"))
        store.addCategory(name: "home", symbol: "house")
        #expect(names(store, thisMonday) == ["Work", "Home"], "a duplicate isn't added")
    }

    @Test("Renaming applies to this and future weeks and the saved category, not past weeks")
    func rename() {
        let store = makeStore()
        let work = store.selectedWeek!.categories[0]
        #expect(store.renameCategory(work.id, newName: "Office"))
        #expect(names(store, thisMonday) == ["Office", "Home"])
        #expect(names(store, nextMonday) == ["Office", "Home"])
        #expect(names(store, lastMonday) == ["Work", "Home"])
        #expect(store.savedCategories.map(\.name) == ["Office", "Errands"])

        #expect(!store.renameCategory(work.id, newName: "home"), "taken by another category")
        #expect(!store.renameCategory(work.id, newName: "Errands"), "taken by a saved category")
        #expect(!store.renameCategory(work.id, newName: "  "))
        #expect(names(store, thisMonday) == ["Office", "Home"])
    }

    @Test("Setting the card order applies to this and future weeks, not past weeks")
    func setOrder() {
        let store = makeStore()
        store.weeks[2].categories.append(Category(name: "Garden", symbol: "leaf"))
        store.setCategoryOrder(["Home", "Work"])
        #expect(names(store, thisMonday) == ["Home", "Work"])
        #expect(names(store, nextMonday) == ["Home", "Work", "Garden"], "unlisted categories stay, after")
        #expect(names(store, lastMonday) == ["Work", "Home"])
    }

    @Test("Saved categories can be edited and reordered, with unique names")
    func editTemplates() {
        let store = makeStore()
        let errands = store.savedCategories[1]
        #expect(!store.updateSavedCategory(errands.id, name: "work", symbol: "cart"))
        #expect(store.updateSavedCategory(errands.id, name: "Shopping", symbol: "bag"))
        #expect(store.savedCategories[1].name == "Shopping")
        #expect(store.savedCategories[1].symbol == "bag")
        #expect(names(store, thisMonday) == ["Work", "Home"], "a category not in the weeks adds nothing")
        store.moveSavedCategories(fromOffsets: [1], toOffset: 0)
        #expect(store.savedCategories.map(\.name) == ["Shopping", "Work"])
        store.addSavedCategory(name: "SHOPPING", symbol: "cart")
        #expect(store.savedCategories.count == 2, "a duplicate isn't added")
    }

    @Test("Editing a saved category changes its category in this and future weeks, not past weeks")
    func editTemplateUpdatesWeeks() {
        let store = makeStore()
        let work = store.savedCategories[0]
        store.weeks[2].dismissedCategories = ["Work"]
        #expect(store.isSavedCategoryNameTaken("home", excluding: work.id), "taken by a category in the weeks")
        #expect(!store.updateSavedCategory(work.id, name: "Home", symbol: "briefcase"))
        #expect(store.updateSavedCategory(work.id, name: "Office", symbol: "🏢"))
        #expect(names(store, thisMonday) == ["Office", "Home"])
        #expect(store.selectedWeek!.categories[0].symbol == "🏢")
        #expect(names(store, lastMonday) == ["Work", "Home"])
        #expect(store.weeks[2].dismissedCategories == ["Office"], "a deleted category stays deleted after the rename")
    }

    @Test("A removed starter category isn't added back on the next launch")
    func removedStarterStaysRemoved() {
        let directory = FileManager.default.temporaryDirectory.appending(path: "starters-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let defaults = UserDefaults(suiteName: "starters-\(UUID().uuidString)")!
        let first = ChecklistStore(directory: directory, defaults: defaults)
        #expect(first.savedCategories.contains { $0.name == "Fitness" })
        let fitness = first.savedCategories.first { $0.name == "Fitness" }!
        first.removeSavedCategory(fitness.id)
        let work = first.savedCategories.first { $0.name == "Work" }!
        first.updateSavedCategory(work.id, name: "Office", symbol: work.symbol)

        let relaunched = ChecklistStore(directory: directory, defaults: defaults)
        #expect(!relaunched.savedCategories.contains { $0.name == "Fitness" })
        #expect(!relaunched.savedCategories.contains { $0.name == "Work" })
        #expect(relaunched.savedCategories.contains { $0.name == "Office" })
    }
}

// MARK: - List Tasks

struct ListTaskTests {
    private func makeStore(_ task: ChecklistTask) -> (ChecklistStore, Tasquel.Category) {
        let store = makeIsolatedStore()
        let category = Category(name: "Errands", symbol: "cart", tasks: [task])
        store.weeks = [Week(startDate: Week.startOfWeek(containing: Date()), categories: [category])]
        store.selectedDate = Date()
        return (store, category)
    }

    @Test("Choosing List keeps the task's mode")
    func chooseList() {
        let task = ChecklistTask(title: "Groceries", mode: .oneTime)
        let (store, category) = makeStore(task)
        store.updateTaskType(categoryID: category.id, taskID: task.id, type: .list)
        let saved = store.selectedWeek?.categories.first?.tasks.first
        #expect(saved?.taskType == .list)
        #expect(saved?.mode == .oneTime, "the mode is chosen separately")
    }

    @Test("A list checks itself off when every item is checked, and unchecks for a new item")
    func autoComplete() {
        let task = ChecklistTask(title: "Groceries", mode: .carryOver, taskType: .list)
        let (store, category) = makeStore(task)
        store.addSubtask(categoryID: category.id, taskID: task.id, title: "Eggs")
        store.addSubtask(categoryID: category.id, taskID: task.id, title: "Milk")
        func saved() -> ChecklistTask { store.selectedWeek!.categories[0].tasks[0] }

        for item in saved().subtasks {
            store.toggleSubtask(categoryID: category.id, taskID: task.id, subtaskID: item.id)
        }
        #expect(saved().isCompleted)

        store.addSubtask(categoryID: category.id, taskID: task.id, title: "Bread")
        #expect(!saved().isCompleted, "A new unchecked item reopens the list")

        store.deleteSubtask(categoryID: category.id, taskID: task.id, subtaskID: saved().subtasks[2].id)
        #expect(saved().isCompleted, "Deleting the only unchecked item completes the list")
    }

    @Test("An unfinished list carries over with only its unchecked items")
    func rollover() {
        let task = ChecklistTask(title: "Groceries", mode: .carryOver,
                                 subtasks: [SubTask(title: "Eggs", isCompleted: true), SubTask(title: "Milk")],
                                 taskType: .list)
        let (store, _) = makeStore(task)
        let nextStart = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: store.weeks[0].startDate)!
        let rolled = store.ensureWeekExists(for: nextStart).categories.first?.tasks.first
        #expect(rolled?.taskType == .list)
        #expect(rolled?.subtasks.map(\.title) == ["Milk"])
        #expect(rolled?.isCompleted == false)
    }

    @Test("Folding a list is saved, isn't an edit, and keeps a delete's Undo")
    func foldIsSavedNotAnEdit() throws {
        let directory = makeTempDirectory()
        let defaults = UserDefaults(suiteName: "TasquelTests-\(UUID().uuidString)")!
        let store = makeIsolatedStore(directory: directory, defaults: defaults)
        let list = ChecklistTask(title: "Bugs", subtasks: [SubTask(title: "Crash", isCompleted: true), SubTask(title: "Typo")],
                                 taskType: .list)
        let other = ChecklistTask(title: "Call Sam")
        let category = Category(name: "Tasquel", symbol: "hammer", tasks: [list, other])
        store.weeks = [Week(startDate: Week.startOfWeek(containing: Date()), categories: [category])]
        store.selectedDate = Date()
        store.deleteTask(categoryID: category.id, taskID: other.id)
        #expect(store.lastDelete != nil)

        store.setListFolded(categoryID: category.id, taskID: list.id, folded: true)
        let folded = try #require(store.selectedWeek?.categories[0].tasks.first)
        #expect(folded.isListFolded && folded.isFolded)
        #expect(!folded.isUserEdited, "folding doesn't stop a copy following its source")
        #expect(folded.subtasks.count == 2, "the items are only hidden")
        #expect(store.lastDelete != nil, "the Undo for the delete is still there")

        let relaunched = ChecklistStore(directory: directory, defaults: defaults)
        #expect(relaunched.weeks.first?.categories.first?.tasks.first?.isListFolded == true)

        store.setListFolded(categoryID: category.id, taskID: list.id, folded: false)
        #expect(store.selectedWeek?.categories[0].tasks.first?.isListFolded == false)
    }

    @Test("Only lists fold; a task that becomes a list starts open, and old files load lists open")
    func onlyListsFold() throws {
        let task = ChecklistTask(title: "Groceries", subtasks: [SubTask(title: "Milk")], taskType: .list)
        let (store, category) = makeStore(task)
        store.setListFolded(categoryID: category.id, taskID: task.id, folded: true)
        func saved() -> ChecklistTask { store.selectedWeek!.categories[0].tasks[0] }

        store.updateTaskType(categoryID: category.id, taskID: task.id, type: .checkbox)
        #expect(!saved().isFolded, "a checkbox always shows its sub-tasks")
        store.setListFolded(categoryID: category.id, taskID: task.id, folded: true)
        #expect(!saved().isListFolded, "a checkbox can't be folded")
        store.updateTaskType(categoryID: category.id, taskID: task.id, type: .list)
        #expect(!saved().isFolded, "a new list is open, so items can be added")

        // A file saved before lists could fold.
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(task)) as? [String: Any])
        json["isListFolded"] = nil
        let old = try JSONDecoder().decode(ChecklistTask.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(!old.isListFolded)
    }

    @Test("A folded list is still folded next week, carried over or repeating")
    func foldRollsOver() {
        let carried = ChecklistTask(title: "Bugs", mode: .carryOver, subtasks: [SubTask(title: "Typo")], taskType: .list)
        let repeating = ChecklistTask(title: "Shopping", mode: .repeating, subtasks: [SubTask(title: "Milk")], taskType: .list)
        let open = ChecklistTask(title: "Features", mode: .carryOver, subtasks: [SubTask(title: "Fold lists")], taskType: .list)
        let store = makeIsolatedStore()
        let category = Category(name: "Tasquel", symbol: "hammer", tasks: [carried, repeating, open])
        store.weeks = [Week(startDate: Week.startOfWeek(containing: Date()), categories: [category])]
        store.selectedDate = Date()
        store.setListFolded(categoryID: category.id, taskID: carried.id, folded: true)
        store.setListFolded(categoryID: category.id, taskID: repeating.id, folded: true)

        let nextStart = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: store.weeks[0].startDate)!
        let rolled = store.ensureWeekExists(for: nextStart).categories.first?.tasks ?? []
        #expect(rolled.first { $0.title == "Bugs" }?.isListFolded == true)
        #expect(rolled.first { $0.title == "Shopping" }?.isListFolded == true)
        #expect(rolled.first { $0.title == "Features" }?.isListFolded == false)
    }
}

// MARK: - Carry-Over Sync

struct CarryOverSyncTests {
    private let thisMonday = Week.startOfWeek(containing: Date())
    private var nextMonday: Date { Calendar.current.date(byAdding: .weekOfYear, value: 1, to: thisMonday)! }
    private var lastMonday: Date { Calendar.current.date(byAdding: .weekOfYear, value: -1, to: thisMonday)! }

    private func tasks(_ store: ChecklistStore, _ monday: Date) -> [ChecklistTask] {
        store.weeks.first { Calendar.current.isDate($0.startDate, inSameDayAs: monday) }!.categories[0].tasks
    }

    @Test("A task added after next week exists still carries into it, and follows its source")
    func futureWeekFollows() {
        let store = makeIsolatedStore()
        store.weeks = [thisMonday, nextMonday].map { Week(startDate: $0, categories: [Category(name: "Errands", symbol: "cart")]) }
        store.selectedDate = thisMonday
        let categoryID = store.selectedWeek!.categories[0].id
        store.addTask(categoryID: categoryID, title: "Groceries")
        let list = tasks(store, thisMonday)[0]
        store.updateTaskType(categoryID: categoryID, taskID: list.id, type: .list)
        store.addSubtask(categoryID: categoryID, taskID: list.id, title: "Eggs")
        store.addSubtask(categoryID: categoryID, taskID: list.id, title: "Milk")

        store.navigateToDate(nextMonday)
        #expect(tasks(store, nextMonday).map(\.title) == ["Groceries"])
        #expect(tasks(store, nextMonday)[0].subtasks.map(\.title) == ["Eggs", "Milk"])

        // Back in this week: check off eggs, add bread. Next week follows.
        store.navigateToDate(thisMonday)
        let eggs = tasks(store, thisMonday)[0].subtasks[0]
        store.toggleSubtask(categoryID: categoryID, taskID: list.id, subtaskID: eggs.id)
        store.addSubtask(categoryID: categoryID, taskID: list.id, title: "Bread")
        store.navigateToDate(nextMonday)
        #expect(tasks(store, nextMonday).count == 1, "no duplicate")
        #expect(tasks(store, nextMonday)[0].subtasks.map(\.title) == ["Milk", "Bread"])

        // Finishing the list this week removes next week's untouched copy.
        store.navigateToDate(thisMonday)
        for item in tasks(store, thisMonday)[0].subtasks where !item.isCompleted {
            store.toggleSubtask(categoryID: categoryID, taskID: list.id, subtaskID: item.id)
        }
        store.navigateToDate(nextMonday)
        #expect(tasks(store, nextMonday).isEmpty)
    }

    @Test("Folding a list folds next week's saved copy; a fold changed there stays")
    func foldReachesSavedCopies() {
        let store = makeIsolatedStore()
        store.weeks = [thisMonday, nextMonday].map { Week(startDate: $0, categories: [Category(name: "Tasquel", symbol: "hammer")]) }
        store.selectedDate = thisMonday
        let categoryID = store.selectedWeek!.categories[0].id
        store.addTask(categoryID: categoryID, title: "Bugs")
        let list = tasks(store, thisMonday)[0]
        store.updateTaskType(categoryID: categoryID, taskID: list.id, type: .list)
        store.addSubtask(categoryID: categoryID, taskID: list.id, title: "Typo")
        store.navigateToDate(nextMonday)
        #expect(tasks(store, nextMonday).map(\.title) == ["Bugs"], "next week has its copy")
        #expect(!tasks(store, nextMonday)[0].isListFolded)

        store.navigateToDate(thisMonday)
        store.setListFolded(categoryID: categoryID, taskID: list.id, folded: true)
        #expect(tasks(store, nextMonday)[0].isListFolded, "next week was saved before: its copy folds too")

        // Opened in next week, it stays open there, whatever this week's does.
        store.navigateToDate(nextMonday)
        let nextCategoryID = store.selectedWeek!.categories[0].id
        store.setListFolded(categoryID: nextCategoryID, taskID: tasks(store, nextMonday)[0].id, folded: false)
        store.navigateToDate(thisMonday)
        store.navigateToDate(nextMonday)
        #expect(!tasks(store, nextMonday)[0].isListFolded, "syncing doesn't fold it again")
        #expect(!tasks(store, nextMonday)[0].isUserEdited, "and the copy still follows its source")
        #expect(tasks(store, thisMonday)[0].isListFolded)
    }

    @Test("An older copy without a source link is adopted and follows its source")
    func adoptsUnlinkedCopy() {
        let store = makeIsolatedStore()
        let list = ChecklistTask(title: "Grocery", mode: .carryOver,
                                 subtasks: [SubTask(title: "Eggs", isCompleted: true), SubTask(title: "Milk")],
                                 taskType: .list)
        let stale = ChecklistTask(title: "Grocery", mode: .carryOver, subtasks: [SubTask(title: "Eggs")])
        store.weeks = [
            Week(startDate: thisMonday, categories: [Category(name: "Errands", symbol: "cart", tasks: [list])]),
            Week(startDate: nextMonday, categories: [Category(name: "Errands", symbol: "cart", tasks: [stale])]),
        ]
        store.navigateToDate(nextMonday)
        let copy = tasks(store, nextMonday)
        #expect(copy.count == 1)
        #expect(copy.first?.carriedFrom == list.id)
        #expect(copy.first?.taskType == .list)
        #expect(copy.first?.subtasks.map(\.title) == ["Milk"])
    }

    @Test("A deleted carry-over stays deleted")
    func deletedCopyStaysDeleted() {
        let store = makeIsolatedStore()
        store.weeks = [thisMonday, nextMonday].map { Week(startDate: $0, categories: [Category(name: "Errands", symbol: "cart")]) }
        store.selectedDate = thisMonday
        let categoryID = store.selectedWeek!.categories[0].id
        store.addTask(categoryID: categoryID, title: "Return books")

        store.navigateToDate(nextMonday)
        let copy = tasks(store, nextMonday)[0]
        store.deleteTask(categoryID: store.selectedWeek!.categories[0].id, taskID: copy.id)
        store.navigateToDate(thisMonday)
        store.navigateToDate(nextMonday)
        #expect(tasks(store, nextMonday).isEmpty)
    }

    @Test("This week picks up what was left unfinished last week, even if it already existed")
    func currentWeekCatchesUp() {
        let store = makeIsolatedStore()
        let leftover = ChecklistTask(title: "Call bank", mode: .carryOver)
        let done = ChecklistTask(title: "Mail", isCompleted: true, mode: .carryOver)
        store.weeks = [
            Week(startDate: lastMonday, categories: [Category(name: "Errands", symbol: "cart", tasks: [leftover, done])]),
            Week(startDate: thisMonday, categories: [Category(name: "Errands", symbol: "cart")]),
        ]
        store.navigateToDate(thisMonday)
        #expect(tasks(store, thisMonday).map(\.title) == ["Call bank"])

        // A checked-off copy is the user's: it stays even though its source is unfinished.
        store.toggleTask(categoryID: store.selectedWeek!.categories[0].id, taskID: tasks(store, thisMonday)[0].id)
        store.navigateToDate(thisMonday)
        #expect(tasks(store, thisMonday).count == 1)
    }
}

// MARK: - Future Weeks Are Previews

/// Looking at a future week doesn't save it; it keeps following this week until edited.
struct FutureWeekPreviewTests {
    private let clock = TestClock(2099, 3, 4)  // a Wednesday
    private var nextWeek: Date { clock.weeks(1, from: clock.now) }

    private func titles(_ store: ChecklistStore) -> [String] {
        store.selectedWeek!.categories[0].tasks.map(\.title)
    }

    @Test("Peeking at next week doesn't save it")
    func peekDoesNotSave() {
        let store = makeIsolatedStore(clock: clock)
        let count = store.weeks.count
        store.navigateToDate(nextWeek)
        #expect(store.weeks.count == count)
        #expect(store.selectedWeek != nil)
    }

    @Test("An edit that's refused in a preview doesn't leave the week saved")
    func refusedEditKeepsPreview() throws {
        let store = makeIsolatedStore(clock: clock)
        let count = store.weeks.count
        store.navigateToDate(nextWeek)
        let category = store.selectedWeek!.categories[0]
        let taken = try #require(store.savedCategories.first { $0.name != category.name }).name
        #expect(!store.renameCategory(category.id, newName: taken))
        store.navigateToDate(clock.now)
        #expect(store.weeks.count == count)
        store.navigateToDate(nextWeek)
        #expect(store.selectedWeek!.categories[0].id == category.id, "the preview keeps its IDs")
    }

    @Test("A carry-over finished after peeking doesn't appear next week")
    func finishedAfterPeek() {
        let store = makeIsolatedStore(clock: clock)
        let categoryID = store.selectedWeek!.categories[0].id
        let taskID = store.addTask(categoryID: categoryID, title: "Call bank", mode: .carryOver)!
        store.navigateToDate(nextWeek)
        #expect(titles(store) == ["Call bank"])

        store.navigateToDate(clock.now)
        store.toggleTask(categoryID: categoryID, taskID: taskID)
        store.navigateToDate(nextWeek)
        #expect(titles(store).isEmpty)
    }

    @Test("A carry-over added after peeking appears next week")
    func addedAfterPeek() {
        let store = makeIsolatedStore(clock: clock)
        store.navigateToDate(nextWeek)
        #expect(titles(store).isEmpty)

        store.navigateToDate(clock.now)
        store.addTask(categoryID: store.selectedWeek!.categories[0].id, title: "Return books", mode: .carryOver)
        store.navigateToDate(nextWeek)
        #expect(titles(store) == ["Return books"])
    }

    @Test("Mode changes this week reach next week")
    func modeChangeAfterPeek() {
        let store = makeIsolatedStore(clock: clock)
        let categoryID = store.selectedWeek!.categories[0].id
        let taskID = store.addTask(categoryID: categoryID, title: "Taxes", mode: .carryOver)!
        store.navigateToDate(nextWeek)
        store.navigateToDate(clock.now)
        store.updateTaskMode(categoryID: categoryID, taskID: taskID, mode: .oneTime)
        store.navigateToDate(nextWeek)
        #expect(titles(store).isEmpty)
    }

    @Test("Editing next week saves it, and it still follows this week's carry-overs")
    func editedWeekFollows() {
        let store = makeIsolatedStore(clock: clock)
        let categoryID = store.selectedWeek!.categories[0].id
        let taskID = store.addTask(categoryID: categoryID, title: "Call bank", mode: .carryOver)!
        let count = store.weeks.count

        store.navigateToDate(nextWeek)
        store.addTask(categoryID: store.selectedWeek!.categories[0].id, title: "Dentist", mode: .oneTime)
        #expect(store.weeks.count == count + 1, "the first edit saves the week")
        #expect(titles(store) == ["Call bank", "Dentist"])

        store.navigateToDate(clock.now)
        store.toggleTask(categoryID: categoryID, taskID: taskID)
        store.navigateToDate(nextWeek)
        #expect(titles(store) == ["Dentist"], "the finished carry-over leaves; the user's task stays")
    }

    @Test("A repeating task deleted from a future week stays deleted")
    func deletedRepeatingStaysDeleted() {
        let directory = makeTempDirectory()
        let store = makeIsolatedStore(directory: directory, clock: clock)
        store.addTask(categoryID: store.selectedWeek!.categories[0].id, title: "Gym", mode: .repeating)

        store.navigateToDate(nextWeek)
        let gym = store.selectedWeek!.categories[0].tasks.first { $0.title == "Gym" }!
        store.deleteTask(categoryID: store.selectedWeek!.categories[0].id, taskID: gym.id)
        store.navigateToDate(clock.now)
        store.navigateToDate(nextWeek)
        #expect(titles(store).isEmpty)

        let reloaded = makeIsolatedStore(directory: directory, clock: clock)
        reloaded.navigateToDate(nextWeek)
        #expect(titles(reloaded).isEmpty, "still deleted after relaunch")
    }

    @Test("A new repeating task with a deleted one's name still repeats into that week")
    func sameNameAfterDeleteRepeats() {
        let store = makeIsolatedStore(clock: clock)
        let categoryID = store.selectedWeek!.categories[0].id
        let oldGym = store.addTask(categoryID: categoryID, title: "Gym", mode: .repeating)!

        store.navigateToDate(nextWeek)
        let copy = store.selectedWeek!.categories[0].tasks.first { $0.title == "Gym" }!
        store.deleteTask(categoryID: store.selectedWeek!.categories[0].id, taskID: copy.id)

        store.navigateToDate(clock.now)
        store.deleteTask(categoryID: categoryID, taskID: oldGym)
        store.addTask(categoryID: categoryID, title: "Gym", mode: .repeating)
        store.navigateToDate(nextWeek)
        #expect(titles(store) == ["Gym"])
    }
}

// MARK: - Weeks Are Calendar Dates

/// A week is identified by the day it starts, not by a moment, so changing time zones
/// finds the same week instead of creating a duplicate.
struct WeekDayIdentityTests {
    @Test("Flying west finds the same week and creates no duplicate")
    func timeZoneChangeKeepsWeek() {
        let directory = makeTempDirectory()
        let clock = TestClock(2099, 3, 4)  // Wednesday, New York
        let store = makeIsolatedStore(directory: directory, clock: clock)
        store.addTask(categoryID: store.selectedWeek!.categories[0].id, title: "Pack", mode: .oneTime)
        let next = clock.weeks(1, from: clock.now)
        store.navigateToDate(next)
        store.addTask(categoryID: store.selectedWeek!.categories[0].id, title: "Unpack")
        let ids = store.weeks.map(\.id)

        // Same moment, now in Los Angeles: New York's Monday midnight is Sunday evening there.
        clock.calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        store.navigateToDate(clock.now)
        #expect(store.selectedWeek?.categories[0].tasks.map(\.title) == ["Pack"])
        store.ensureWeekExists(for: clock.now)
        store.navigateToDate(next)
        #expect(store.selectedWeek?.categories[0].tasks.map(\.title) == ["Unpack"])
        #expect(store.weeks.map(\.id) == ids, "no week was added")

        // Relaunching in Los Angeles finds them too.
        let reloaded = makeIsolatedStore(directory: directory, clock: clock)
        #expect(reloaded.weeks.map(\.id) == ids)
        #expect(reloaded.selectedWeek?.categories[0].tasks.map(\.title) == ["Pack"])
    }

    @Test("Monday just after midnight in New York is still that week after flying west")
    func earlyMondayInNewYork() {
        let clock = TestClock(2099, 3, 2, hour: 0)  // Monday 00:00, New York
        clock.now = clock.now.addingTimeInterval(30 * 60)
        let store = makeIsolatedStore(clock: clock)
        let weekID = store.selectedWeek!.id
        clock.calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        // It's Sunday evening in Los Angeles: the week before. Hours later it's Monday there.
        clock.now = clock.now.addingTimeInterval(4 * 3600)
        store.navigateToDate(clock.now)
        store.ensureWeekExists(for: clock.now)
        #expect(store.selectedWeek?.id == weekID)
        #expect(store.weeks.count == 1)
    }

    @Test("Weeks saved as a moment get their day from it on first load")
    func migratesLegacyStartDate() throws {
        let directory = makeTempDirectory()
        // Monday 2 March 2099, local midnight in New York, as older versions saved it.
        let legacy = """
        [{"id":"A1B2C3D4-E5F6-7890-ABCD-EF1234567890","startDate":"2099-03-02T05:00:00Z",
          "categories":[{"id":"B1B2C3D4-E5F6-7890-ABCD-EF1234567890","name":"Work","symbol":"briefcase",
          "tasks":[{"id":"C1B2C3D4-E5F6-7890-ABCD-EF1234567890","title":"Report","isCompleted":false,
          "mode":"carryOver","subtasks":[],"taskType":"checkbox"}]}]}]
        """
        try Data(legacy.utf8).write(to: directory.appending(path: "checklist.json"))
        let clock = TestClock(2099, 3, 4)
        let store = makeIsolatedStore(directory: directory, clock: clock)
        let week = try #require(store.weeks.first { $0.id.uuidString == "A1B2C3D4-E5F6-7890-ABCD-EF1234567890" })
        #expect(week.startDay == DayKey(year: 2099, month: 3, day: 2))
        #expect(week.categories[0].tasks.map(\.title) == ["Report"], "nothing lost")
        let saved = try String(contentsOf: directory.appending(path: "checklist.json"), encoding: .utf8)
        #expect(saved.contains("\"startDay\" : \"2099-03-02\""), "the day is saved right away")
    }

    @Test("Switching to Sunday starts moves each week back one calendar day")
    func weekStartShiftByDay() {
        let clock = TestClock(2099, 3, 4)
        let store = makeIsolatedStore(clock: clock)
        #expect(store.selectedWeek?.startDay == DayKey(year: 2099, month: 3, day: 2))
        store.setWeekStartsOnSunday(true)
        #expect(store.selectedWeek?.startDay == DayKey(year: 2099, month: 3, day: 1))
        #expect(DayKey(year: 2099, month: 3, day: 1).adding(days: -1) == DayKey(year: 2099, month: 2, day: 28))
    }
}

// MARK: - Goal Numbers

struct GoalNumberTests {
    private let english = Locale(identifier: "en_US")
    private let german = Locale(identifier: "de_DE")

    @Test("An amount that can't be used says why: over the maximum, or zero where it must be more")
    func goalAmountProblems() {
        var input = GoalAmountInput()
        #expect(input.problem(for: .quantity, locale: english) == nil, "nothing typed")
        input.number = "1000000"
        #expect(input.problem(for: .quantity, locale: english) == "Up to 999,999")
        input.number = "0"
        #expect(input.problem(for: .quantity, locale: english) == "More than 0")
        #expect(input.problem(for: .quantity, allowsZero: true, locale: english) == nil, "progress can be 0")
        input.number = "12"
        #expect(input.problem(for: .quantity, locale: english) == nil)
        var time = GoalAmountInput()
        time.hours = "16667"
        #expect(time.problem(for: .time, locale: english) == "Up to 16,666 hours")
    }

    @Test("A huge target is rejected in the field and capped in the store, without crashing")
    func hugeValues() {
        var input = GoalAmountInput()
        input.number = String(repeating: "9", count: 20)
        #expect(input.positiveValue(for: .quantity, locale: english) == nil, "Set stays disabled")

        let store = makeIsolatedStore(clock: TestClock(2099, 3, 4))
        let categoryID = store.selectedWeek!.categories[0].id
        let taskID = store.addTask(categoryID: categoryID, title: "Read", type: .goal)!
        store.setGoalTarget(categoryID: categoryID, taskID: taskID, target: 1e20)
        store.updateGoalProgress(categoryID: categoryID, taskID: taskID, progress: 1e21)
        let task = store.selectedWeek!.categories[0].tasks[0]
        #expect(task.goalTarget == GoalUnitKind.maxValue)
        #expect(task.goalProgress == GoalUnitKind.maxValue)
        _ = task.goalFraction
        _ = GoalUnitKind.time.format(1e20)
        _ = GoalAmountInput(1e20, kind: .time)
    }

    @Test("Amounts show up to two decimals with no trailing .0")
    func formatting() {
        #expect(GoalNumber.fieldText(2.5, locale: english) == "2.5")
        #expect(GoalNumber.fieldText(5, locale: english) == "5")
        #expect(GoalNumber.fieldText(2.5, locale: german) == "2,5")
        #expect(GoalAmountInput(5, kind: .quantity, locale: english).number == "5")
    }

    @Test("Amounts are read in the user's locale")
    func localeParsing() {
        #expect(GoalNumber.parse("2.5", locale: english) == 2.5)
        #expect(GoalNumber.parse("1,000", locale: english) == 1000)
        #expect(GoalNumber.parse("2,5", locale: german) == 2.5)
        #expect(GoalNumber.parse("1.000,5", locale: german) == 1000.5)
        #expect(GoalNumber.parse("abc", locale: german) == nil)
        var input = GoalAmountInput()
        input.number = "2,5"
        #expect(input.positiveValue(for: .quantity, locale: german) == 2.5, "Set is enabled for 2,5 in German")
        var time = GoalAmountInput()
        time.hours = "1,5"
        #expect(time.value(for: .time, locale: german) == 90)
    }
}

// MARK: - App Info

struct AppInfoTests {
    @Test("Settings shows the version and build from Info.plist")
    func versionFromBundle() {
        let info: [String: Any] = ["CFBundleShortVersionString": "1.2", "CFBundleVersion": "34"]
        #expect(AppInfo.version(from: info) == "1.2")
        #expect(AppInfo.build(from: info) == "34")
        #expect(AppInfo.version(from: nil) == "—")
        #expect(AppInfo.privacyPolicyURL.scheme == "https")
        #expect(AppInfo.supportURL.scheme == "https")
    }
}

// MARK: - Accessibility

struct TaskAccessibilityTests {
    @Test("Today's pill in the week's strip says the day as an ordinal, in the user's language")
    func todayOrdinal() {
        let us = Locale(identifier: "en_US")
        #expect([1, 2, 3, 4, 11, 12, 13, 21, 22, 23, 31].map { WeekDayStrip.ordinal($0, locale: us) }
                == ["1st", "2nd", "3rd", "4th", "11th", "12th", "13th", "21st", "22nd", "23rd", "31st"])
        #expect(WeekDayStrip.ordinal(7, locale: Locale(identifier: "de_DE")) == "7.")
    }

    @Test("Checkboxes say what tapping them does")
    func checkboxLabels() {
        #expect(TaskAccessibility.checkboxLabel("Eggs", isCompleted: false) == "Complete Eggs")
        #expect(TaskAccessibility.checkboxLabel("Eggs", isCompleted: true) == "Mark Eggs incomplete")
    }

    @Test("A goal reads its progress")
    func goalValue() {
        var task = ChecklistTask(title: "Read", taskType: .goal)
        #expect(TaskAccessibility.goalValue(task) == "No target yet")
        task.goalTarget = 5
        task.goalProgress = 3
        #expect(TaskAccessibility.goalValue(task) == "3 of 5")
        task.goalUnitKind = .custom
        task.goalUnit = "pages"
        #expect(TaskAccessibility.goalValue(task) == "3 of 5 pages")
        task.goalProgress = 5
        #expect(TaskAccessibility.goalValue(task) == "Done, 5 of 5 pages")
    }
}

// MARK: - Privacy Manifest

struct PrivacyManifestTests {
    @Test("The app ships a privacy manifest declaring its UserDefaults and keyboard use")
    func manifestIsBundled() throws {
        let url = try #require(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        let plist = try #require(NSDictionary(contentsOf: url))
        #expect(plist["NSPrivacyTracking"] as? Bool == false)
        let apis = plist["NSPrivacyAccessedAPITypes"] as? [[String: Any]] ?? []
        #expect(apis.contains { $0["NSPrivacyAccessedAPIType"] as? String == "NSPrivacyAccessedAPICategoryUserDefaults" })
        // The emoji field reads the active keyboards (UITextInputMode.activeInputModes).
        #expect(apis.contains {
            $0["NSPrivacyAccessedAPIType"] as? String == "NSPrivacyAccessedAPICategoryActiveKeyboards"
                && ($0["NSPrivacyAccessedAPITypeReasons"] as? [String]) == ["54BD.1"]
        })
        // The Feature Ideas survey is the only data that leaves the device, anonymously:
        // the picks and app version (Other Data) and the optional comment (Other User Content).
        let collected = plist["NSPrivacyCollectedDataTypes"] as? [[String: Any]] ?? []
        #expect(Set(collected.compactMap { $0["NSPrivacyCollectedDataType"] as? String })
                == ["NSPrivacyCollectedDataTypeOtherDataTypes", "NSPrivacyCollectedDataTypeOtherUserContent"])
        #expect(collected.allSatisfy { $0["NSPrivacyCollectedDataTypeLinked"] as? Bool == false && $0["NSPrivacyCollectedDataTypeTracking"] as? Bool == false })
        // Matches the App Store Connect privacy answer: Analytics.
        #expect(collected.allSatisfy { ($0["NSPrivacyCollectedDataTypePurposes"] as? [String]) == ["NSPrivacyCollectedDataTypePurposeAnalytics"] })
    }
}

// MARK: - Repeating Tasks Follow Their Source

struct RepeatingFollowTests {
    private let clock = TestClock(2099, 3, 4)
    private var nextWeek: Date { clock.weeks(1, from: clock.now) }

    private func titles(_ store: ChecklistStore) -> [String] {
        store.selectedWeek!.categories[0].tasks.map(\.title)
    }

    /// This week: Hands (repeating), Books (carry-over), Articles (repeating).
    private func makeStore() -> (ChecklistStore, UUID) {
        let store = makeIsolatedStore(clock: clock)
        let categoryID = store.selectedWeek!.categories[0].id
        store.addTask(categoryID: categoryID, title: "Hands", mode: .repeating, type: .goal)
        store.addTask(categoryID: categoryID, title: "Books", mode: .carryOver, type: .goal)
        store.addTask(categoryID: categoryID, title: "Articles", mode: .repeating, type: .goal)
        return (store, categoryID)
    }

    @Test("Next week lists tasks in this week's order")
    func keepsOrder() {
        let (store, _) = makeStore()
        store.navigateToDate(nextWeek)
        #expect(titles(store) == ["Hands", "Books", "Articles"], "preview")
        store.addTask(categoryID: store.selectedWeek!.categories[0].id, title: "Mine", mode: .oneTime)
        store.navigateToDate(clock.now)
        store.navigateToDate(nextWeek)
        #expect(titles(store) == ["Hands", "Books", "Articles", "Mine"], "saved week")
    }

    @Test("Renaming a repeating task renames next week's copy instead of adding one")
    func renameFollows() {
        let (store, categoryID) = makeStore()
        store.navigateToDate(nextWeek)
        store.addTask(categoryID: store.selectedWeek!.categories[0].id, title: "Mine", mode: .oneTime)  // saves next week

        store.navigateToDate(clock.now)
        let hands = store.selectedWeek!.categories[0].tasks[0]
        store.renameTask(categoryID: categoryID, taskID: hands.id, newTitle: "Essays")
        store.navigateToDate(nextWeek)
        #expect(titles(store) == ["Essays", "Books", "Articles", "Mine"])
    }

    @Test("A copy keeps its own progress while following its source's target")
    func copyKeepsProgress() {
        let (store, categoryID) = makeStore()
        store.navigateToDate(nextWeek)
        let copy = store.selectedWeek!.categories[0].tasks[0]
        store.updateGoalProgress(categoryID: store.selectedWeek!.categories[0].id, taskID: copy.id, progress: 3)

        store.navigateToDate(clock.now)
        let hands = store.selectedWeek!.categories[0].tasks[0]
        store.setGoalTarget(categoryID: categoryID, taskID: hands.id, target: 10)
        store.navigateToDate(nextWeek)
        let followed = store.selectedWeek!.categories[0].tasks[0]
        #expect(followed.goalTarget == 10)
        #expect(followed.goalProgress == 3)
    }

    @Test("A deleted repeating copy stays deleted even after its source is renamed")
    func deletedStaysDeletedAfterRename() {
        let (store, categoryID) = makeStore()
        store.navigateToDate(nextWeek)
        let copy = store.selectedWeek!.categories[0].tasks[0]
        store.deleteTask(categoryID: store.selectedWeek!.categories[0].id, taskID: copy.id)

        store.navigateToDate(clock.now)
        let hands = store.selectedWeek!.categories[0].tasks[0]
        store.renameTask(categoryID: categoryID, taskID: hands.id, newTitle: "Essays")
        store.navigateToDate(nextWeek)
        #expect(titles(store) == ["Books", "Articles"])
    }
}

// MARK: - Final Sync When a Week Becomes Current

struct FinalSyncTests {
    private func titles(_ store: ChecklistStore) -> [String] {
        store.selectedWeek!.categories[0].tasks.map(\.title)
    }

    /// This week has "Call bank" (carry-over) and "Hands" (repeating); next week is
    /// saved because the user added "Dentist" to it.
    private let defaults = UserDefaults(suiteName: "TasquelTests-\(UUID().uuidString)")!

    private func setUp() -> (URL, TestClock, ChecklistStore, UUID) {
        let directory = makeTempDirectory()
        let clock = TestClock(2099, 3, 4)
        let store = makeIsolatedStore(directory: directory, clock: clock, defaults: defaults)
        let categoryID = store.selectedWeek!.categories[0].id
        store.addTask(categoryID: categoryID, title: "Call bank", mode: .carryOver)
        store.addTask(categoryID: categoryID, title: "Hands", mode: .repeating)
        store.navigateToDate(clock.weeks(1, from: clock.now))
        store.addTask(categoryID: store.selectedWeek!.categories[0].id, title: "Dentist", mode: .oneTime)
        store.navigateToDate(clock.now)
        return (directory, clock, store, categoryID)
    }

    @Test("Changes made after next week was saved reach it when it becomes current")
    func finalSyncOnLaunch() {
        let (directory, clock, store, categoryID) = setUp()
        let tasks = store.selectedWeek!.categories[0].tasks
        store.toggleTask(categoryID: categoryID, taskID: tasks[0].id)  // finish Call bank
        store.renameTask(categoryID: categoryID, taskID: tasks[1].id, newTitle: "Essays")

        // A week later, without ever opening next week again.
        clock.now = clock.weeks(1, from: clock.now)
        let relaunched = makeIsolatedStore(directory: directory, clock: clock, defaults: defaults)
        #expect(titles(relaunched) == ["Essays", "Dentist"])
    }

    @Test("The final sync happens once, so later edits to the current week stay")
    func finalSyncOnlyOnce() {
        let (directory, clock, _, _) = setUp()
        clock.now = clock.weeks(1, from: clock.now)
        let store = makeIsolatedStore(directory: directory, clock: clock, defaults: defaults)
        #expect(titles(store) == ["Call bank", "Hands", "Dentist"])

        // The user renames the carried copy and deletes a category in the current week.
        let category = store.selectedWeek!.categories[0]
        store.renameTask(categoryID: category.id, taskID: category.tasks[0].id, newTitle: "Call the bank")
        let removed = store.selectedWeek!.categories[1]
        store.deleteCategory(removed.id)

        let relaunched = makeIsolatedStore(directory: directory, clock: clock, defaults: defaults)
        #expect(titles(relaunched) == ["Call the bank", "Hands", "Dentist"])
        #expect(!relaunched.selectedWeek!.categories.contains { $0.name == removed.name })
    }
}

extension FinalSyncTests {
    @Test("Weeks saved before the flag: current ones are left alone, future ones still get their final sync")
    func legacyWeeks() throws {
        let directory = makeTempDirectory()
        let clock = TestClock(2099, 3, 4)
        let lastWeek = Week.startOfWeek(containing: clock.weeks(-1, from: clock.now), calendar: clock.calendar)
        let thisWeek = Week.startOfWeek(containing: clock.now, calendar: clock.calendar)
        let nextWeek = Week.startOfWeek(containing: clock.weeks(1, from: clock.now), calendar: clock.calendar)
        let hands = ChecklistTask(title: "Hands", mode: .repeating, taskType: .goal)
        let books = ChecklistTask(title: "Books", mode: .carryOver, taskType: .goal)
        // Like the phone's data: "Hands" was renamed "Articles" this week; next week was
        // saved by peeking, with a copy of "Books"; no week has the flag.
        func week(_ start: Date, _ tasks: [ChecklistTask]) -> Week {
            Week(startDay: DayKey(start, in: clock.calendar), categories: [Tasquel.Category(name: "Study", symbol: "book", tasks: tasks)])
        }
        var articles = hands; articles.id = UUID(); articles.title = "Articles"
        var booksNow = books; booksNow.id = UUID()
        var booksCopy = books; booksCopy.id = UUID(); booksCopy.carriedFrom = booksNow.id
        let weeks = [week(nextWeek, [booksCopy]), week(thisWeek, [booksNow, articles]), week(lastWeek, [hands])]
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var json = try #require(String(data: encoder.encode(weeks), encoding: .utf8))
        json = json.replacingOccurrences(of: ",\"didFinalSync\":true", with: "")
        try Data(json.utf8).write(to: directory.appending(path: "checklist.json"))

        let defaults = UserDefaults(suiteName: "TasquelTests-\(UUID().uuidString)")!
        let store = makeIsolatedStore(directory: directory, clock: clock, defaults: defaults)
        let study = { (store: ChecklistStore) in
            store.selectedWeek!.categories.first { $0.name == "Study" }!.tasks.map(\.title)
        }
        #expect(study(store) == ["Books", "Articles"], "the current week isn't re-synced")

        // Finish Books this week; when next week becomes current, its copy leaves.
        let category = store.selectedWeek!.categories.first { $0.name == "Study" }!
        store.toggleTask(categoryID: category.id, taskID: category.tasks[0].id)
        clock.now = clock.weeks(1, from: clock.now)
        let later = makeIsolatedStore(directory: directory, clock: clock, defaults: defaults)
        #expect(!study(later).contains("Books"), "the old future week got its final sync")
    }

    @Test("A saved week the app never opens while it's current still passes on this week's changes")
    func skippedWeekIsBuiltFrom() {
        let (directory, clock, store, categoryID) = setUp()
        let tasks = store.selectedWeek!.categories[0].tasks
        store.toggleTask(categoryID: categoryID, taskID: tasks[0].id)  // finish Call bank
        store.renameTask(categoryID: categoryID, taskID: tasks[1].id, newTitle: "Essays")

        // Two weeks later: next week came and went without the app being opened.
        let start = clock.now
        clock.now = clock.weeks(2, from: start)
        let relaunched = makeIsolatedStore(directory: directory, clock: clock, defaults: defaults)
        #expect(titles(relaunched) == ["Essays"])

        // The skipped week itself got the sync it missed.
        relaunched.navigateToDate(clock.weeks(1, from: start))
        #expect(titles(relaunched) == ["Essays", "Dentist"])
    }

    @Test("A saved week that becomes current after a skipped week follows this week's changes")
    func savedWeekAfterSkippedWeek() {
        let (directory, clock, store, categoryID) = setUp()
        let start = clock.now
        store.navigateToDate(clock.weeks(2, from: start))
        store.addTask(categoryID: store.selectedWeek!.categories[0].id, title: "Taxes", mode: .oneTime)
        store.navigateToDate(start)
        let tasks = store.selectedWeek!.categories[0].tasks
        store.toggleTask(categoryID: categoryID, taskID: tasks[0].id)  // finish Call bank
        store.renameTask(categoryID: categoryID, taskID: tasks[1].id, newTitle: "Essays")

        clock.now = clock.weeks(2, from: start)
        let relaunched = makeIsolatedStore(directory: directory, clock: clock, defaults: defaults)
        #expect(titles(relaunched) == ["Essays", "Taxes"])
    }
}

// MARK: - Week Dates Are Gregorian

struct GregorianWeekTests {
    @Test("Japanese, Buddhist and Hebrew device calendars find the same weeks", arguments: [
        Calendar.Identifier.japanese, .buddhist, .hebrew, .islamicUmmAlQura,
    ])
    func sameWeeks(identifier: Calendar.Identifier) {
        let directory = makeTempDirectory()
        let clock = TestClock(2099, 3, 4)
        let store = makeIsolatedStore(directory: directory, clock: clock)
        store.addTask(categoryID: store.selectedWeek!.categories[0].id, title: "Pack", mode: .oneTime)
        let weeks = store.weeks.map { ($0.id, $0.startDay) }
        #expect(store.selectedWeek?.startDay == DayKey(year: 2099, month: 3, day: 2))

        var other = Calendar(identifier: identifier)
        other.timeZone = clock.calendar.timeZone
        clock.calendar = other
        let reopened = makeIsolatedStore(directory: directory, clock: clock)
        #expect(reopened.weeks.map(\.id) == weeks.map(\.0))
        #expect(reopened.weeks.map(\.startDay) == weeks.map(\.1))
        #expect(reopened.selectedWeek?.categories[0].tasks.map(\.title) == ["Pack"])
        #expect(reopened.isCurrentWeek(reopened.selectedWeek!))
        #expect(Week.startOfWeek(containing: clock.now, calendar: other)
                == Week.startOfWeek(containing: clock.now, calendar: .weekDates(in: other.timeZone)))
        #expect(DayKey(clock.now, in: other) == DayKey(year: 2099, month: 3, day: 4))
    }
}

// MARK: - Copies Edited in a Future Week

struct EditedCopyTests {
    private let clock = TestClock(2099, 3, 4)
    private var nextWeek: Date { clock.weeks(1, from: clock.now) }

    private func titles(_ store: ChecklistStore) -> [String] {
        store.selectedWeek!.categories[0].tasks.map(\.title)
    }

    @Test("Renaming next week's repeating copy sticks, also through its final sync")
    func renamedRepeatingCopyStays() {
        let directory = makeTempDirectory()
        let defaults = UserDefaults(suiteName: "TasquelTests-\(UUID().uuidString)")!
        let store = makeIsolatedStore(directory: directory, clock: clock, defaults: defaults)
        store.addTask(categoryID: store.selectedWeek!.categories[0].id, title: "Hands", mode: .repeating)
        let next = nextWeek
        store.navigateToDate(next)
        let category = store.selectedWeek!.categories[0]
        store.renameTask(categoryID: category.id, taskID: category.tasks[0].id, newTitle: "Hands x2")
        store.navigateToDate(clock.now)
        store.navigateToDate(next)
        #expect(titles(store) == ["Hands x2"])

        clock.now = next
        let relaunched = makeIsolatedStore(directory: directory, clock: clock, defaults: defaults)
        #expect(titles(relaunched) == ["Hands x2"])
    }

    @Test("A goal set up on next week's repeating copy stays")
    func goalOnCopyStays() {
        let store = makeIsolatedStore(clock: clock)
        store.addTask(categoryID: store.selectedWeek!.categories[0].id, title: "Run", mode: .repeating)
        store.navigateToDate(nextWeek)
        let category = store.selectedWeek!.categories[0]
        store.updateTaskType(categoryID: category.id, taskID: category.tasks[0].id, type: .goal)
        store.setGoalTarget(categoryID: category.id, taskID: category.tasks[0].id, target: 5)
        store.navigateToDate(clock.now)
        store.navigateToDate(nextWeek)
        let copy = store.selectedWeek!.categories[0].tasks[0]
        #expect(copy.taskType == .goal)
        #expect(copy.goalTarget == 5)
    }

    @Test("Progress entered on next week's carried copy stays when this week's task is finished")
    func carriedProgressStays() {
        let store = makeIsolatedStore(clock: clock)
        let categoryID = store.selectedWeek!.categories[0].id
        let books = store.addTask(categoryID: categoryID, title: "Books", mode: .carryOver, type: .goal)!
        store.setGoalTarget(categoryID: categoryID, taskID: books, target: 10)
        store.updateGoalProgress(categoryID: categoryID, taskID: books, progress: 2)
        store.navigateToDate(nextWeek)
        let category = store.selectedWeek!.categories[0]
        store.updateGoalProgress(categoryID: category.id, taskID: category.tasks[0].id, progress: 5)

        store.navigateToDate(clock.now)
        store.updateGoalProgress(categoryID: categoryID, taskID: books, progress: 10)
        store.navigateToDate(nextWeek)
        let copy = store.selectedWeek!.categories[0].tasks.first { $0.title == "Books" }
        #expect(copy?.goalProgress == 5)
    }

    @Test("A task typed into next week isn't taken over by this week's task with the same name")
    func typedTaskIsNotAdopted() {
        let store = makeIsolatedStore(clock: clock)
        let categoryID = store.selectedWeek!.categories[0].id
        store.navigateToDate(nextWeek)
        store.addTask(categoryID: store.selectedWeek!.categories[0].id, title: "Pay rent", mode: .carryOver)
        store.navigateToDate(clock.now)
        let rent = store.addTask(categoryID: categoryID, title: "Pay rent", mode: .carryOver)!
        store.navigateToDate(nextWeek)
        store.navigateToDate(clock.now)
        store.toggleTask(categoryID: categoryID, taskID: rent)
        store.navigateToDate(nextWeek)
        #expect(titles(store) == ["Pay rent"])
    }

    @Test("A repeating copy that follows a new target is checked again only if it meets it")
    func followedTargetRedecidesCompletion() {
        let store = makeIsolatedStore(clock: clock)
        let categoryID = store.selectedWeek!.categories[0].id
        let hands = store.addTask(categoryID: categoryID, title: "Hands", mode: .repeating, type: .goal)!
        store.setGoalTarget(categoryID: categoryID, taskID: hands, target: 5)
        store.navigateToDate(nextWeek)
        let category = store.selectedWeek!.categories[0]
        store.updateGoalProgress(categoryID: category.id, taskID: category.tasks[0].id, progress: 5)
        #expect(store.selectedWeek!.categories[0].tasks[0].isCompleted)

        store.navigateToDate(clock.now)
        store.setGoalTarget(categoryID: categoryID, taskID: hands, target: 10)
        store.navigateToDate(nextWeek)
        let copy = store.selectedWeek!.categories[0].tasks[0]
        #expect(copy.goalTarget == 10)
        #expect(!copy.isCompleted)
    }
}

// MARK: - Deleting a Category From a Future Week

struct FutureCategoryDeletionTests {
    private let clock = TestClock(2099, 3, 4)
    private var nextWeek: Date { clock.weeks(1, from: clock.now) }

    private func names(_ store: ChecklistStore) -> [String] {
        store.selectedWeek!.categories.map(\.name)
    }

    @Test("Deleting a category from next week keeps it this week, and syncing doesn't add it back")
    func keepsCurrentWeek() {
        let store = makeIsolatedStore(clock: clock)
        let name = store.selectedWeek!.categories[0].name
        store.addTask(categoryID: store.selectedWeek!.categories[0].id, title: "Keep me", mode: .oneTime)
        store.navigateToDate(nextWeek)
        store.deleteCategory(store.selectedWeek!.categories[0].id)

        store.navigateToDate(clock.now)
        #expect(names(store).contains(name))
        #expect(store.selectedWeek!.categories[0].tasks.map(\.title) == ["Keep me"])
        store.navigateToDate(nextWeek)
        #expect(!names(store).contains(name))

        // Adding it back to next week works.
        store.addCategory(name: name, symbol: "star")
        store.navigateToDate(clock.now)
        store.navigateToDate(nextWeek)
        #expect(names(store).contains(name))
    }

    @Test("A this-week-only category is deleted from its own week only")
    func thisWeekOnly() {
        let store = makeIsolatedStore(clock: clock)
        store.addCategory(name: "Trip", symbol: "airplane", thisWeekOnly: true)
        let trip = store.selectedWeek!.categories.first { $0.name == "Trip" }!
        store.deleteCategory(trip.id)
        #expect(!names(store).contains("Trip"))
        #expect(store.savedCategories.contains { $0.name == "Trip" }, "kept so it can be added again")
    }
}

// MARK: - A Week Becoming Current While the App Is Open

@Test("A saved week that becomes current on screen gets its final sync before the first edit")
func finalSyncBeforeFirstEdit() {
    let directory = makeTempDirectory()
    let defaults = UserDefaults(suiteName: "TasquelTests-\(UUID().uuidString)")!
    let clock = TestClock(2099, 3, 4)
    let store = makeIsolatedStore(directory: directory, clock: clock, defaults: defaults)
    store.addTask(categoryID: store.selectedWeek!.categories[0].id, title: "Hands", mode: .repeating)
    let next = clock.weeks(1, from: clock.now)
    store.navigateToDate(next)
    store.addTask(categoryID: store.selectedWeek!.categories[0].id, title: "Dentist", mode: .oneTime)

    // Midnight passes with next week on screen; then the user deletes its "Hands".
    clock.now = next
    let category = store.selectedWeek!.categories[0]
    store.deleteTask(categoryID: category.id, taskID: category.tasks.first { $0.title == "Hands" }!.id)

    let relaunched = makeIsolatedStore(directory: directory, clock: clock, defaults: defaults)
    #expect(relaunched.selectedWeek!.categories[0].tasks.map(\.title) == ["Dentist"])
}

@Test("Switching to Monday weeks on a Sunday doesn't bring back categories deleted that week")
func weekStartSwitchOnSunday() {
    let clock = TestClock(2099, 3, 1)  // a Sunday
    let store = makeIsolatedStore(clock: clock)
    store.setWeekStartsOnSunday(true)
    clock.now = clock.weeks(1, from: clock.now)  // the next Sunday
    store.navigateToDate(clock.now)
    let removed = store.selectedWeek!.categories[0].name
    store.deleteCategory(store.selectedWeek!.categories[0].id)

    // Today's week stays the current week, and next week rolls from it.
    store.setWeekStartsOnSunday(false)
    #expect(store.isCurrentWeek(store.selectedWeek!))
    #expect(!store.selectedWeek!.categories.contains { $0.name == removed })
    store.navigateToDate(clock.weeks(1, from: clock.now))
    #expect(!store.selectedWeek!.categories.contains { $0.name == removed })
}

@Test("Changing the week start on a Sunday keeps this week's tasks in the current, editable week",
      arguments: [false, true])
func weekStartSwitchOnSundayKeepsCurrentWeek(startOnSunday: Bool) {
    let clock = TestClock(2099, 3, 8)  // a Sunday
    let store = makeIsolatedStore(clock: clock)
    if startOnSunday { store.setWeekStartsOnSunday(true) }
    let categoryID = store.selectedWeek!.categories[0].id
    store.addTask(categoryID: categoryID, title: "Dentist", mode: .oneTime)

    store.setWeekStartsOnSunday(!startOnSunday)
    let week = store.selectedWeek!
    #expect(store.isCurrentWeek(week), "today's week stays the current week")
    #expect(!store.isPastWeek(week))
    #expect(week.startDay == (startOnSunday ? DayKey(year: 2099, month: 3, day: 2) : DayKey(year: 2099, month: 3, day: 8)))
    #expect(week.categories[0].tasks.contains { $0.title == "Dentist" })
    #expect(store.weeks.filter { store.isCurrentWeek($0) }.count == 1, "no second current week")
}

// MARK: - Unreadable or Odd Data

struct DataRecoveryTests {
    private let clock = TestClock(2099, 3, 4)

    @Test("A settings save doesn't clear a failed task save; it retries it")
    func saveErrorsPerFile() throws {
        let directory = makeTempDirectory()
        let store = makeIsolatedStore(directory: directory)
        // A folder where checklist.json should be: saving tasks fails, settings still save.
        let weeksFile = directory.appending(path: "checklist.json")
        try? FileManager.default.removeItem(at: weeksFile)
        try FileManager.default.createDirectory(at: weeksFile.appending(path: "blocker"), withIntermediateDirectories: true)

        store.addTask(categoryID: store.selectedWeek!.categories[0].id, title: "Unsaved")
        #expect(store.saveError != nil)
        store.setRetroColor(.amber)
        #expect(store.saveError != nil, "tasks still aren't saved")

        try FileManager.default.removeItem(at: weeksFile)
        store.setRetroColor(.blue)
        #expect(store.saveError == nil, "the settings save retried the tasks save")
        let saved = try String(contentsOf: weeksFile, encoding: .utf8)
        #expect(saved.contains("Unsaved"))
    }

    @Test("A failing save alerts once; the lasting notice stays until a save works")
    func saveFailureAlertsOnce() throws {
        let directory = makeTempDirectory()
        let store = makeIsolatedStore(directory: directory)
        let weeksFile = directory.appending(path: "checklist.json")
        try? FileManager.default.removeItem(at: weeksFile)
        try FileManager.default.createDirectory(at: weeksFile.appending(path: "blocker"), withIntermediateDirectories: true)
        let categoryID = store.selectedWeek!.categories[0].id

        store.addTask(categoryID: categoryID, title: "First")
        #expect(store.saveError != nil)
        store.dismissSaveError()
        store.addTask(categoryID: categoryID, title: "Second")
        #expect(store.saveError == nil, "no second alert while saves keep failing")
        #expect(store.isSaveFailing)

        try FileManager.default.removeItem(at: weeksFile)
        store.addTask(categoryID: categoryID, title: "Third")
        #expect(!store.isSaveFailing)
    }

    @Test("A task with missing fields or an unknown mode still loads")
    func lenientTaskDecoding() throws {
        let directory = makeTempDirectory()
        let json = """
        [{"id":"\(UUID())","startDay":"2099-03-02","categories":[{"id":"\(UUID())","name":"Home","symbol":"house",
          "tasks":[{"id":"\(UUID())","title":"Odd","mode":"fortnightly"},{"title":"Bare"}]}]}]
        """
        try Data(json.utf8).write(to: directory.appending(path: "checklist.json"))
        let store = makeIsolatedStore(directory: directory, clock: clock)
        #expect(store.persistenceError == nil)
        let tasks = store.selectedWeek?.categories.first { $0.name == "Home" }?.tasks ?? []
        #expect(tasks.map(\.title) == ["Odd", "Bare"])
        #expect(tasks.first?.mode == .carryOver)
    }

    @Test("Start Fresh keeps the unreadable file and continues without it")
    func setAsideUnreadableFile() throws {
        let directory = makeTempDirectory()
        try Data("not json".utf8).write(to: directory.appending(path: "checklist.json"))
        let store = makeIsolatedStore(directory: directory, clock: clock)
        #expect(store.persistenceError != nil)

        store.setAsideUnreadableData()
        #expect(store.persistenceError == nil)
        #expect(store.selectedWeek != nil)
        let kept = try FileManager.default.contentsOfDirectory(atPath: directory.path())
            .filter { $0.hasPrefix("checklist-unreadable-") }
        #expect(kept.count == 1)
        #expect(try String(contentsOf: directory.appending(path: kept[0]), encoding: .utf8) == "not json")
    }
}

@Test("Next week's preview keeps its IDs when this week changes")
func previewKeepsIDs() {
    let clock = TestClock(2099, 3, 4)
    let store = makeIsolatedStore(clock: clock)
    let categoryID = store.selectedWeek!.categories[0].id
    store.addTask(categoryID: categoryID, title: "Books", mode: .carryOver)
    let next = clock.weeks(1, from: clock.now)
    let before = store.previewWeek(for: next)
    store.addTask(categoryID: categoryID, title: "Today only", mode: .oneTime)
    let after = store.previewWeek(for: next)
    #expect(after.id == before.id)
    #expect(after.categories.map(\.id) == before.categories.map(\.id))
    #expect(after.categories[0].tasks.map(\.id) == before.categories[0].tasks.map(\.id))
}

/// A category icon is an emoji only when it's one emoji; SF Symbol names never are.
@Test func categoryIconEmojiDetection() {
    for emoji in ["😀", "❤️", "👍🏽", "🇺🇸", "👨‍👩‍👧", "1️⃣"] {
        #expect(CategorySymbols.isEmoji(emoji), "\(emoji)")
    }
    for other in ["folder", "figure.run", "calendar.badge.clock", "a", "1", "#", "", "😀😀"] {
        #expect(!CategorySymbols.isEmoji(other), "\(other)")
    }
    #expect(CategorySymbols.name(for: "🎸") == "🎸")
    #expect(CategorySymbols.name(for: "cart") == "Shopping")
}

/// Checking a task with sub-tasks checks them all; unchecking clears them. Checking a
/// sub-task afterwards then can't uncheck the task by surprise.
@Test func checkingParentChecksSubtasks() {
    let store = makeIsolatedStore()
    let categoryID = store.selectedWeek!.categories[0].id
    let taskID = store.addTask(categoryID: categoryID, title: "Pack")!
    store.addSubtask(categoryID: categoryID, taskID: taskID, title: "Socks")
    store.addSubtask(categoryID: categoryID, taskID: taskID, title: "Charger")
    func task() -> ChecklistTask { store.selectedWeek!.categories[0].tasks.first { $0.id == taskID }! }

    store.toggleTask(categoryID: categoryID, taskID: taskID)
    #expect(task().isCompleted)
    let allChecked = task().subtasks.allSatisfy(\.isCompleted)
    #expect(allChecked)

    store.toggleSubtask(categoryID: categoryID, taskID: taskID, subtaskID: task().subtasks[0].id)
    #expect(!task().isCompleted, "unchecking a sub-task unchecks the task")
    store.toggleSubtask(categoryID: categoryID, taskID: taskID, subtaskID: task().subtasks[0].id)
    #expect(task().isCompleted)

    store.toggleTask(categoryID: categoryID, taskID: taskID)
    #expect(!task().isCompleted)
    let anyChecked = task().subtasks.contains(where: \.isCompleted)
    #expect(!anyChecked)
}

/// Smart Add's result becomes a task with its goal target or list items; a goal with no
/// amount is left for the user to set.
@Test func addingParsedTasks() {
    let store = makeIsolatedStore()
    let categoryID = store.selectedWeek!.categories[0].id
    func task(_ id: UUID?) -> ChecklistTask? { store.selectedWeek!.categories[0].tasks.first { $0.id == id } }

    let run = store.addParsedTask(ParsedTask(title: "Run", type: .goal, mode: .repeating, goalTarget: 3), categoryID: categoryID)
    #expect(task(run)?.mode == .repeating)
    #expect(task(run)?.goalTarget == 3)

    let read = store.addParsedTask(ParsedTask(title: "Read", type: .goal, goalTarget: 20, goalKind: .custom, goalUnit: "pages"), categoryID: categoryID)
    #expect(task(read)?.goalUnit == "pages")

    let groceries = store.addParsedTask(ParsedTask(title: "Groceries", type: .list, items: ["milk", " ", "eggs"]), categoryID: categoryID)
    #expect(task(groceries)?.taskType == .list)
    #expect(task(groceries)?.subtasks.map(\.title) == ["milk", "eggs"], "blank items are skipped")

    let vague = store.addParsedTask(ParsedTask(title: "Stretch", type: .goal), categoryID: categoryID)
    #expect(task(vague)?.goalTarget == nil)
    #expect(store.addParsedTask(ParsedTask(title: "  "), categoryID: categoryID) == nil)
}

/// Smart Add's rules fix what the model can miss, even when it returns the words as a
/// plain one-time checkbox.
@Test(arguments: [
    ("run 3x per week", "Run", TaskType.goal, TaskMode.repeating, 3.0),
    ("Run 3x a week", "Run", .goal, .repeating, 3),
    ("gym twice a week", "Gym", .goal, .repeating, 2),
    ("yoga 3x/week", "Yoga", .goal, .repeating, 3),
    ("swim three times a week", "Swim", .goal, .repeating, 3),
    ("Water plants weekly", "Water plants", .checkbox, .repeating, nil),
    ("call mom every Sunday", "Call mom", .checkbox, .repeating, nil),
    ("Call the bank until it's sorted", "Call the bank", .checkbox, .carryOver, nil),
    ("Weekly report this week only", "Weekly report", .checkbox, .oneTime, nil),
    ("Plan a week of meals", "Plan a week of meals", .checkbox, .oneTime, nil),
    ("run 3x", "Run", .goal, .oneTime, 3),
    ("Take pill twice a day", "Take pill", .goal, .repeating, 14),
    ("Meditate daily", "Meditate", .goal, .repeating, 7),
    ("stretch every weekday", "Stretch", .goal, .repeating, 5),
    ("walk the dog every morning", "Walk the dog", .goal, .repeating, 7),
    // Ordinary words that only look like schedules are left alone.
    ("Measure twice, cut once", "Measure twice, cut once", .checkbox, .oneTime, nil),
    ("Print 4 x 6 photos", "Print 4 x 6 photos", .checkbox, .oneTime, nil),
    ("Buy 1x HDMI cable", "Buy 1x HDMI cable", .checkbox, .oneTime, nil),
    ("Carry over boxes to garage", "Carry over boxes to garage", .checkbox, .oneTime, nil),
    ("Dentist every other Tuesday", "Dentist every other Tuesday", .checkbox, .oneTime, nil),
    ("Pay one-time fee", "Pay one-time fee", .checkbox, .oneTime, nil),
    ("Daily standup notes", "Daily standup notes", .goal, .repeating, 7),
    ("Study C# daily", "Study C#", .goal, .repeating, 7),
] as [(String, String, TaskType, TaskMode, Double?)])
func smartAddHints(text: String, title: String, type: TaskType, mode: TaskMode, target: Double?) {
    let refined = TaskTextHints.refine(ParsedTask(title: text), from: text)
    #expect(refined.title == title)
    #expect(refined.type == type)
    #expect(refined.mode == mode)
    #expect(refined.goalTarget == target)
}

/// Words with no schedule or count are added exactly as typed.
@Test func smartAddHintsLeavePlainWords() {
    let refined = TaskTextHints.refine(ParsedTask(title: "buy milk."), from: "buy milk.")
    #expect(refined == ParsedTask(title: "buy milk."))
    #expect(TaskTextHints.refine(ParsedTask(title: "read a book every week"), from: "read a book every week").mode == .repeating)
    let groceries = TaskTextHints.refine(ParsedTask(title: "groceries: milk, eggs, bread"), from: "groceries: milk, eggs, bread")
    #expect(groceries.type == .list)
    #expect(groceries.title == "Groceries")
    #expect(groceries.items == ["milk", "eggs", "bread"])
    for text in ["Dentist 10:30, bring forms", "Read: Pride and Prejudice"] {
        #expect(TaskTextHints.refine(ParsedTask(title: text), from: text) == ParsedTask(title: text), "\(text)")
    }
    #expect(TaskTextHints.refine(ParsedTask(title: "Note: call mom"), from: "Note: call mom").type == .checkbox, "one item isn't a list")
}


// MARK: - Second Audit Fixes

/// A carry-over deleted two weeks ahead stays deleted once the week in between is saved.
@Test func carryOverDeletedTwoWeeksAheadStaysDeleted() {
    let clock = TestClock(2099, 3, 4)
    let store = makeIsolatedStore(clock: clock)
    let name = store.selectedWeek!.categories[0].name
    func category() -> Tasquel.Category { store.selectedWeek!.categories.first { $0.name == name }! }
    store.addTask(categoryID: category().id, title: "Taxes", mode: .carryOver)

    store.navigateToDate(clock.weeks(2, from: clock.now))
    let copy = category().tasks.first { $0.title == "Taxes" }!
    store.deleteTask(categoryID: category().id, taskID: copy.id)

    store.navigateToDate(clock.weeks(1, from: clock.now))
    store.addTask(categoryID: category().id, title: "Other")  // saves the week in between
    store.navigateToDate(clock.weeks(2, from: clock.now))
    #expect(!category().tasks.contains { $0.title == "Taxes" })
}

/// Tapping a name and leaving it unchanged doesn't make a copy stop following its source.
@Test func unchangedRenameKeepsCopyFollowing() {
    let clock = TestClock(2099, 3, 4)
    let store = makeIsolatedStore(clock: clock)
    let name = store.selectedWeek!.categories[0].name
    func category() -> Tasquel.Category { store.selectedWeek!.categories.first { $0.name == name }! }
    store.addTask(categoryID: category().id, title: "Taxes", mode: .carryOver)
    store.navigateToDate(clock.weeks(1, from: clock.now))
    let copy = category().tasks.first { $0.title == "Taxes" }!
    store.renameTask(categoryID: category().id, taskID: copy.id, newTitle: "Taxes")
    store.updateTaskMode(categoryID: category().id, taskID: copy.id, mode: .carryOver)
    #expect(category().tasks.first { $0.title == "Taxes" }?.isUserEdited == false)
}

/// Unchecking a task right after checking it puts its sub-tasks' checks back.
@Test func uncheckingRestoresSubtaskChecks() {
    let store = makeIsolatedStore()
    let categoryID = store.selectedWeek!.categories[0].id
    let taskID = store.addTask(categoryID: categoryID, title: "Pack")!
    for item in ["Socks", "Charger", "Tickets"] { store.addSubtask(categoryID: categoryID, taskID: taskID, title: item) }
    func task() -> ChecklistTask { store.selectedWeek!.categories[0].tasks.first { $0.id == taskID }! }
    store.toggleSubtask(categoryID: categoryID, taskID: taskID, subtaskID: task().subtasks[0].id)

    store.toggleTask(categoryID: categoryID, taskID: taskID)
    store.toggleTask(categoryID: categoryID, taskID: taskID)
    #expect(task().subtasks.map(\.isCompleted) == [true, false, false])
}

/// A rename can't give a category the name another category has in a later week.
@Test func renameChecksLaterWeeks() {
    let thisMonday = Week.startOfWeek(containing: Date())
    let nextMonday = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: thisMonday)!
    let store = makeIsolatedStore()
    var trip = Category(name: "Trip", symbol: "airplane")
    trip.isThisWeekOnly = true
    store.weeks = [
        Week(startDate: nextMonday, categories: [Category(name: "Work", symbol: "briefcase"), trip]),
        Week(startDate: thisMonday, categories: [Category(name: "Work", symbol: "briefcase")]),
    ]
    store.selectedDate = thisMonday
    #expect(!store.renameCategory(store.selectedWeek!.categories[0].id, newName: "trip"))
}

/// Adding a deleted category back starts it empty: its carried tasks stay deleted.
@Test func readdedCategoryStartsEmpty() {
    let clock = TestClock(2099, 3, 4)
    let store = makeIsolatedStore(clock: clock)
    let name = store.selectedWeek!.categories[0].name
    let symbol = store.selectedWeek!.categories[0].symbol
    store.addTask(categoryID: store.selectedWeek!.categories[0].id, title: "Taxes", mode: .carryOver)
    store.navigateToDate(clock.weeks(1, from: clock.now))
    let category = store.selectedWeek!.categories.first { $0.name == name }!
    #expect(category.tasks.contains { $0.title == "Taxes" })
    store.deleteCategory(category.id)
    store.addCategory(name: name, symbol: symbol)
    store.navigateToDate(clock.now)
    store.navigateToDate(clock.weeks(1, from: clock.now))
    #expect(store.selectedWeek!.categories.first { $0.name == name }?.tasks.isEmpty == true)
}

/// A saved category the user removed isn't saved again when its card is deleted.
@Test func removedSavedCategoryStaysRemoved() {
    let store = makeIsolatedStore()
    let category = store.selectedWeek!.categories[0]
    let template = store.savedCategories.first { $0.name == category.name }!
    store.removeSavedCategory(template.id)
    store.deleteCategory(category.id)
    #expect(!store.savedCategories.contains { $0.name == category.name })
}

/// Without settings.json, the week start comes from the saved weeks, so they stay reachable.
@Test func weekStartInferredWithoutSettings() throws {
    let directory = makeTempDirectory()
    let first = makeIsolatedStore(directory: directory)
    first.addTask(categoryID: first.selectedWeek!.categories[0].id, title: "Keep me")
    first.setWeekStartsOnSunday(true)
    try FileManager.default.removeItem(at: directory.appending(path: "settings.json"))

    let reopened = makeIsolatedStore(directory: directory)
    #expect(reopened.weekStartsOnSunday)
    #expect(reopened.selectedWeek!.categories[0].tasks.contains { $0.title == "Keep me" })
}

/// One category missing a field doesn't stop the file from loading.
@Test func categoryDecodesLeniently() throws {
    let category = try JSONDecoder().decode(Tasquel.Category.self, from: Data(#"{"name":"Work"}"#.utf8))
    #expect(category.name == "Work")
    #expect(category.symbol == "folder")
}

/// Smart Add only adds to the week it was typed in, and keeps a goal's unit without an amount.
@Test func parsedTaskWeekAndUnit() {
    let store = makeIsolatedStore()
    let categoryID = store.selectedWeek!.categories[0].id
    let otherWeek = store.selectedWeek!.startDay.adding(days: 7)
    #expect(store.addParsedTask(ParsedTask(title: "Late"), categoryID: categoryID, weekStart: otherWeek) == nil)
    let id = store.addParsedTask(ParsedTask(title: "Read", type: .goal, goalKind: .custom, goalUnit: "pages"), categoryID: categoryID)
    let task = store.selectedWeek!.categories[0].tasks.first { $0.id == id }
    #expect(task?.goalTarget == nil)
    #expect(task?.goalUnitLabel == "pages")
}

/// On iPad cards sit three to a row; an open card still takes its own row.
@Test func threeColumnRows() {
    #expect(CategoryGridLayout.rows(fullWidth: [false, false, false, false, false], columns: 3) == [[0, 1, 2], [3, 4]])
    #expect(CategoryGridLayout.rows(fullWidth: [false, true, false, false, false, false], columns: 3) == [[0], [1], [2, 3, 4], [5]])
}

// MARK: - Polish Batch

/// Deleting a category whose saved category was removed (and renamed since) saves it
/// again as a template, and can still be undone; Undo takes the template back out.
@Test func deleteCategoryWithoutTemplateCanBeUndone() {
    let store = makeIsolatedStore()
    let category = store.selectedWeek!.categories[0]
    let template = store.savedCategories.first { $0.name == category.name }!
    store.removeSavedCategory(template.id)
    #expect(store.renameCategory(category.id, newName: "Chores"))
    #expect(!store.savedCategories.contains { $0.name == "Chores" })

    store.deleteCategory(category.id)
    #expect(store.lastDelete != nil, "the delete can be undone")
    #expect(store.savedCategories.contains { $0.name == "Chores" }, "a deleted category keeps a template")
    store.undoLastDelete()
    #expect(store.selectedWeek!.categories.contains { $0.name == "Chores" })
    #expect(!store.savedCategories.contains { $0.name == "Chores" }, "Undo takes the template back out")
}

/// Changing a task's type re-decides whether it's done: a finished checkbox becomes an
/// unfinished goal (no target yet), and a list is done only when all its items are.
@Test func changingTypeRedecidesDone() {
    let store = makeIsolatedStore()
    let categoryID = store.selectedWeek!.categories[0].id
    let taskID = store.addTask(categoryID: categoryID, title: "Stretch")!
    store.toggleTask(categoryID: categoryID, taskID: taskID)
    func task() -> ChecklistTask { store.selectedWeek!.categories[0].tasks.first { $0.id == taskID }! }
    #expect(task().isCompleted)

    store.updateTaskType(categoryID: categoryID, taskID: taskID, type: .goal)
    #expect(!task().isCompleted, "a goal with no target isn't done")

    store.updateTaskType(categoryID: categoryID, taskID: taskID, type: .checkbox)
    store.toggleTask(categoryID: categoryID, taskID: taskID)
    #expect(task().isCompleted)
    store.updateTaskType(categoryID: categoryID, taskID: taskID, type: .list)
    #expect(!task().isCompleted, "a list with no items isn't done")
}

/// Deleting can be undone; any other change ends the chance.
@Test func undoDeletes() {
    let store = makeIsolatedStore()
    let categoryID = store.selectedWeek!.categories[0].id
    let taskID = store.addTask(categoryID: categoryID, title: "Milk")!
    store.addTask(categoryID: categoryID, title: "Eggs")
    store.deleteTask(categoryID: categoryID, taskID: taskID)
    #expect(store.lastDelete?.description == "“Milk”")
    store.undoLastDelete()
    #expect(store.selectedWeek!.categories[0].tasks.map(\.title) == ["Milk", "Eggs"])
    #expect(store.lastDelete == nil)

    store.deleteTask(categoryID: categoryID, taskID: taskID)
    store.addTask(categoryID: categoryID, title: "Bread")
    #expect(store.lastDelete == nil, "another change ends the undo")

    let category = store.selectedWeek!.categories[0]
    store.deleteCategory(category.id)
    store.undoLastDelete()
    #expect(store.selectedWeek!.categories.contains { $0.name == category.name })
}

/// Tasks move within their card.
@Test func movingTasks() {
    let store = makeIsolatedStore()
    let categoryID = store.selectedWeek!.categories[0].id
    let a = store.addTask(categoryID: categoryID, title: "A")!
    store.addTask(categoryID: categoryID, title: "B")
    let c = store.addTask(categoryID: categoryID, title: "C")!
    func titles() -> [String] { store.selectedWeek!.categories[0].tasks.map(\.title) }
    store.moveTask(categoryID: categoryID, taskID: a, to: c)
    #expect(titles() == ["B", "C", "A"])
    store.moveTask(categoryID: categoryID, taskID: a, by: -1)
    #expect(titles() == ["B", "A", "C"])
    store.moveTask(categoryID: categoryID, taskID: c, to: store.selectedWeek!.categories[0].tasks[0].id)
    #expect(titles() == ["C", "B", "A"])
}

/// The header reads "Week of Oct 5" in the user's region, with the year only when needed.
@Test func weekTitleFollowsRegion() {
    let week = Week(startDate: Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 10, day: 5))!, categories: [])
    let now = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 10, day: 7))!
    let gregorian = Calendar(identifier: .gregorian)
    #expect(week.displayTitle(now: now, locale: Locale(identifier: "en_US"), calendar: gregorian) == "Week of Oct 5")
    #expect(week.displayTitle(now: now, locale: Locale(identifier: "en_GB"), calendar: gregorian) == "Week of 5 Oct")
    let nextYear = gregorian.date(from: DateComponents(year: 2027, month: 1, day: 4))!
    #expect(week.displayTitle(now: nextYear, locale: Locale(identifier: "en_US"), calendar: gregorian) == "Week of Oct 5, 2026")
}

/// Cards can be sorted by when each category was last edited, either way round. Ones never
/// edited count as the oldest (in their arranged order): last with recent first, first with
/// least recent first. The choice is saved.
@Test func sortingCardsByLastEdit() {
    let clock = TestClock(2099, 3, 4)
    let directory = makeTempDirectory()
    let defaults = UserDefaults(suiteName: "TasquelTests-\(UUID().uuidString)")!
    let store = makeIsolatedStore(directory: directory, clock: clock, defaults: defaults)
    let names = store.selectedWeek!.categories.map(\.name)
    #expect(names.count >= 3)
    func id(_ name: String) -> UUID { store.selectedWeek!.categories.first { $0.name == name }!.id }

    store.addTask(categoryID: id(names[2]), title: "First")
    clock.now = clock.now.addingTimeInterval(60)
    store.addTask(categoryID: id(names[0]), title: "Second")

    #expect(store.sortedCategories(store.selectedWeek!.categories).map(\.name) == names, "manual keeps the arranged order")
    store.setCategorySort(.recentFirst)
    #expect(store.sortedCategories(store.selectedWeek!.categories).map(\.name).prefix(2) == [names[0], names[2]])
    #expect(store.sortedCategories(store.selectedWeek!.categories).map(\.name)[2] == names[1], "never-edited ones follow, in their arranged order")
    store.setCategorySort(.oldestFirst)
    let oldest = store.sortedCategories(store.selectedWeek!.categories).map(\.name)
    #expect(oldest.first == names[1], "never-edited ones lead, in their arranged order")
    #expect(oldest.suffix(2) == [names[2], names[0]], "and the one edited last comes last")

    let reopened = makeIsolatedStore(directory: directory, clock: clock, defaults: defaults)
    #expect(reopened.categorySort == .oldestFirst)
    #expect(reopened.sortedCategories(reopened.selectedWeek!.categories).map(\.name) == oldest, "edit times are kept")
}

/// A model's made-up amounts and items are dropped; ones in the words stay.
@Test func inventedAmountsAreDropped() {
    let rhythm = TaskTextHints.dropInvented(ParsedTask(title: "Rhythm", type: .goal, goalTarget: 10, goalKind: .time), from: "Rhythm")
    #expect(rhythm.type == .checkbox)
    #expect(rhythm.goalTarget == nil)
    let piano = ParsedTask(title: "Practice piano", type: .goal, goalTarget: 120, goalKind: .time)
    #expect(TaskTextHints.dropInvented(piano, from: "Practice piano 2 hours") == piano)
    let daily = ParsedTask(title: "Meditate", type: .goal, mode: .repeating, goalTarget: 7)
    #expect(TaskTextHints.dropInvented(daily, from: "Meditate daily") == daily)
    let list = ParsedTask(title: "Groceries", type: .list, items: ["milk", "eggs", "butter"])
    #expect(TaskTextHints.dropInvented(list, from: "Groceries: milk, eggs").items == ["milk", "eggs"])
}


// MARK: - Third Audit Fixes

/// Tasks reordered in a future week keep that order when the week syncs again.
@Test func futureWeekReorderSticks() {
    let clock = TestClock(2099, 3, 4)
    let store = makeIsolatedStore(clock: clock)
    let name = store.selectedWeek!.categories[0].name
    func category() -> Tasquel.Category { store.selectedWeek!.categories.first { $0.name == name }! }
    store.addTask(categoryID: category().id, title: "A", mode: .repeating)
    store.addTask(categoryID: category().id, title: "B", mode: .repeating)
    store.navigateToDate(clock.weeks(1, from: clock.now))
    let tasks = category().tasks
    store.moveTask(categoryID: category().id, taskID: tasks[1].id, to: tasks[0].id)
    #expect(category().tasks.map(\.title) == ["B", "A"])
    store.navigateToDate(clock.now)
    store.navigateToDate(clock.weeks(1, from: clock.now))
    #expect(category().tasks.map(\.title) == ["B", "A"], "the sync doesn't put the old order back")
}

/// Taking back a Smart Add removes the task without offering an Undo of its own.
@Test func quietDeleteHasNoUndo() {
    let store = makeIsolatedStore()
    let categoryID = store.selectedWeek!.categories[0].id
    let id = store.addTask(categoryID: categoryID, title: "Gym")!
    store.deleteTask(categoryID: categoryID, taskID: id, undoable: false)
    #expect(store.lastDelete == nil)
    #expect(store.selectedWeek!.categories[0].tasks.isEmpty)
}

/// "Twice daily" counts per day; a "Name: a, b" list beats "daily".
@Test func dailyPhrasesAndLists() {
    func refine(_ text: String) -> ParsedTask { TaskTextHints.refine(ParsedTask(title: text), from: text) }
    #expect(refine("Brush teeth twice daily").goalTarget == 14)
    #expect(refine("Brush teeth twice daily").title == "Brush teeth")
    #expect(refine("Take meds 3 times daily").goalTarget == 21)
    #expect(refine("Stretch daily 2x").goalTarget == 14)
    let habits = refine("Daily habits: water, walk, read")
    #expect(habits.type == .list)
    #expect(habits.items == ["water", "walk", "read"])
}

/// Amounts written in words count as amounts; loose matching keeps the model's items.
@Test func amountsInWordsAreKept() {
    for (text, target) in [("Meditate fifteen minutes", 15.0), ("Twenty pushups", 20), ("Run a mile", 1), ("Read a dozen pages", 12)] {
        #expect(TaskTextHints.dropInvented(ParsedTask(title: text, type: .goal, goalTarget: target), from: text).goalTarget == target, "\(text)")
    }
    let pack = TaskTextHints.dropInvented(ParsedTask(title: "Pack", type: .list, items: ["Mom's charger", "sock", "butter"]),
                                          from: "Pack: Mom’s charger, socks")
    #expect(pack.items == ["Mom's charger", "sock"])
    // "Groceries" with made-up items: the items go, but it stays a list to fill in.
    let groceries = TaskTextHints.dropInvented(ParsedTask(title: "Groceries", type: .list, items: ["milk", "eggs"]), from: "groceries")
    #expect(groceries.type == .list)
    #expect(groceries.items.isEmpty)
}

/// A sort value this version doesn't know reads as Manual instead of breaking settings.
@Test func unknownSortReadsAsManual() throws {
    let directory = makeTempDirectory()
    let first = makeIsolatedStore(directory: directory)
    first.setCategorySort(.recentFirst)
    let url = directory.appending(path: "settings.json")
    let text = try String(contentsOf: url, encoding: .utf8).replacingOccurrences(of: "recentFirst", with: "someFutureOrder")
    try text.write(to: url, atomically: true, encoding: .utf8)
    let reopened = makeIsolatedStore(directory: directory)
    #expect(reopened.settingsLoadError == nil)
    #expect(reopened.categorySort == .manual)
}

/// Smart Add's spelling backstop fixes a close typo but leaves names and real words.
@Test func smartAddFixesTypos() {
    let fixed = AppleIntelligenceTaskParser.fixingTypos(
        ParsedTask(title: "Do pishups", type: .goal, goalTarget: 50, goalKind: .custom, goalUnit: "pishups"),
        typed: "Do 50 pishups")
    #expect(fixed.title.lowercased().hasPrefix("do p"))
    #expect(fixed.title != "Do pishups", "the typo is corrected")
    #expect(fixed.goalUnit != "pishups")
    let name = AppleIntelligenceTaskParser.fixingTypos(ParsedTask(title: "Call Siobhan"), typed: "Call Siobhan")
    #expect(name.title == "Call Siobhan", "names typed with a capital stay")
    let fine = AppleIntelligenceTaskParser.fixingTypos(ParsedTask(title: "Water plants"), typed: "water plants")
    #expect(fine.title == "Water plants")
}

/// A goal's step, when set, is what + and − use; it carries into the next week.
@Test func goalStepIsKept() {
    let clock = TestClock(2099, 3, 4)
    let store = makeIsolatedStore(clock: clock)
    let name = store.selectedWeek!.categories[0].name
    func category() -> Tasquel.Category { store.selectedWeek!.categories.first { $0.name == name }! }
    let id = store.addParsedTask(ParsedTask(title: "Push-ups", type: .goal, mode: .repeating, goalTarget: 500), categoryID: category().id)!
    store.setGoalStep(categoryID: category().id, taskID: id, step: 20)
    #expect(category().tasks[0].goalStep == 20)
    store.navigateToDate(clock.weeks(1, from: clock.now))
    #expect(category().tasks.first { $0.title == "Push-ups" }?.goalStep == 20, "the repeating copy keeps the step")
    store.navigateToDate(clock.now)
    store.setGoalStep(categoryID: category().id, taskID: id, step: nil)
    #expect(category().tasks[0].goalStep == nil, "cleared back to automatic")
}

/// With no step set, any goal steps by a day's share of its target, whatever its mode: the
/// target ÷ its Days (7 when blank), rounded up to a whole minute or number, so that many
/// taps reach it. "Meditate 70 minutes" counts 10 a tap (not the 15 an old table by size
/// gave); 67 minutes over 5 days, 14 (5 taps; rounded to 5 minutes, 67 over 6 days was 7 taps).
@Test(arguments: [(70.0, nil, 10.0), (67, nil, 10), (67, 5, 14), (67, 6, 12), (67, 1, 67), (140, nil, 20),
                  (120, nil, 18), (10, nil, 2), (100, nil, 15), (3, nil, 1), (56, nil, 8), (8, nil, 2),
                  (0.5, nil, 1), (0, nil, 1), (70, 9, 10)] as [(Double, Int?, Double)])
func automaticStep(target: Double, days: Int?, step: Double) {
    #expect(ChecklistTask.automaticStep(forTarget: target, days: days) == step)
    if target > 0, (1...7).contains(days ?? 7) {
        #expect((target / step).rounded(.up) <= Double(days ?? 7), "a tap a day reaches the target within the days")
    }
}

@Test(arguments: TaskMode.allCases)
func goalStepOrAutomatic(mode: TaskMode) {
    var meditate = ChecklistTask(title: "Meditate", mode: mode, taskType: .goal, goalTarget: 70, goalUnitKind: .time)
    #expect(meditate.goalStepOrAutomatic == 10, "a day's share in every mode")
    meditate.goalDays = 5
    #expect(meditate.goalStepOrAutomatic == 14, "over its Days")
    meditate.goalStep = 20
    #expect(meditate.goalStepOrAutomatic == 20, "a step set in the editor wins")
    let pushups = ChecklistTask(title: "Push-ups", mode: mode, taskType: .goal, goalTarget: 70, goalUnitKind: .quantity)
    #expect(pushups.goalStepOrAutomatic == 10)
}

/// An amount per day steps the goal a day at a time: "meditate 10 min daily" is 70 min
/// with a 10 min step, counting 7 days.
@Test(arguments: [
    ("meditate 10 min daily", 10.0, 7),
    ("read 20 pages on weekdays", 20, 5),
    ("Drink 8 glasses of water a day", 8, 7),
    ("practice piano 30 min Mon, Wed, Fri", 30, 3),
] as [(String, Double, Int)])
func smartAddPerDayGoals(text: String, step: Double, days: Int) {
    let task = smartAddRules(text)
    #expect(task.goalStep == step)
    #expect(task.goalDays == days)
    #expect(task.goalTarget == step * Double(days))
}

/// Other goals have no day's amount: their step is left to pick itself.
@Test func smartAddOtherGoalsHaveNoDays() {
    for text in ["read 90 pages", "Run 3x per week", "Meditate daily", "Run 5 km in a day"] {
        let task = smartAddRules(text)
        #expect(task.goalStep == nil, "\(text)")
        #expect(task.goalDays == nil, "\(text)")
    }
}

/// A per-day goal keeps its step and days when added, in next week's copy, and in the
/// store's step setter; without a step the days stay, for the automatic step to divide by.
@Test func perDayGoalIsKept() {
    let clock = TestClock(2099, 3, 4)
    let store = makeIsolatedStore(clock: clock)
    let name = store.selectedWeek!.categories[0].name
    func category() -> Tasquel.Category { store.selectedWeek!.categories.first { $0.name == name }! }
    func task() -> ChecklistTask { category().tasks.first { $0.title == "Meditate" }! }
    let parsed = ParsedTask(title: "Meditate", type: .goal, mode: .repeating, goalTarget: 70, goalKind: .time,
                            goalStep: 10, goalDays: 7)
    let id = store.addParsedTask(parsed, categoryID: category().id)!
    #expect(task().goalStep == 10)
    #expect(task().goalDays == 7)
    store.navigateToDate(clock.weeks(1, from: clock.now))
    #expect(task().goalDays == 7, "the repeating copy keeps its days")
    store.navigateToDate(clock.now)
    store.setGoalStep(categoryID: category().id, taskID: id, step: 20, days: 7)
    #expect(task().goalStep == 20)
    #expect(task().goalDays == 7)
    store.setGoalStep(categoryID: category().id, taskID: id, step: 20, days: nil)
    #expect(task().goalDays == 7, "no days is 7 days: nothing changed")
    store.setGoalStep(categoryID: category().id, taskID: id, step: 20, days: 5)
    #expect(task().goalDays == 5)
    store.setGoalStep(categoryID: category().id, taskID: id, step: nil, days: 5)
    #expect(task().goalStep == nil)
    #expect(task().goalDays == 5, "days without a step: + steps by the target ÷ days")
    #expect(task().goalStepOrAutomatic == 14, "70 minutes over 5 days")
    store.setGoalStep(categoryID: category().id, taskID: id, step: nil, days: 9)
    #expect(task().goalDays == nil, "out of range is blank")
}

/// The editor's target for a per-day goal's step: step × days, capped like any goal.
@Test func perDayTargetFollowsTheStep() {
    #expect(GoalAmountInput.perDayTarget(step: GoalAmountInput(20, kind: .time), days: 7, kind: .time) == GoalAmountInput(140, kind: .time))
    #expect(GoalAmountInput.perDayTarget(step: GoalAmountInput(8, kind: .custom), days: 5, kind: .custom) == GoalAmountInput(40, kind: .custom))
    #expect(GoalAmountInput.perDayTarget(step: GoalAmountInput(), days: 7, kind: .time) == nil, "no step typed")
    #expect(GoalAmountInput.perDayTarget(step: GoalAmountInput(500_000, kind: .quantity), days: 7, kind: .quantity)
            == GoalAmountInput(GoalUnitKind.maxValue, kind: .quantity))
}

/// `goalDays` decodes leniently: missing or out of range is no days.
@Test func goalDaysDecodesLeniently() throws {
    func decode(_ days: String) throws -> Int? {
        let json = #"{"title":"Meditate","taskType":"goal","goalTarget":70,"goalStep":10"# + days + "}"
        return try JSONDecoder().decode(ChecklistTask.self, from: Data(json.utf8)).goalDays
    }
    #expect(try decode(#","goalDays":5"#) == 5)
    #expect(try decode("") == nil)
    #expect(try decode(#","goalDays":9"#) == nil)
    #expect(try decode(#","goalDays":"x""#) == nil)
}

/// Smart Add's rules read an amount with its unit, for when the model can't run; dates,
/// sizes and labels aren't amounts.
@Test(arguments: [
    ("read 90 pages", "Read", 90.0, GoalUnitKind.custom, "pages"),
    ("Practice piano 2 hours", "Practice piano", 120, .time, ""),
    ("meditate 15 min", "Meditate", 15, .time, ""),
    ("Do 50 pushups", "Pushups", 50, .custom, "pushups"),
    ("Drink 8 glasses of water", "Drink water", 8, .custom, "glasses"),
    ("run 5 km", "Run", 5, .custom, "km"),
] as [(String, String, Double, GoalUnitKind, String)])
func smartAddReadsAmounts(text: String, title: String, target: Double, kind: GoalUnitKind, unit: String) {
    let refined = TaskTextHints.refine(ParsedTask(title: text), from: text)
    #expect(refined.type == .goal)
    #expect(refined.title == title)
    #expect(refined.goalTarget == target)
    #expect(refined.goalKind == kind)
    #expect(refined.goalUnit == unit)
}

@Test func smartAddIgnoresNonAmounts() {
    for text in ["Dentist at 3 today", "Renew passport in 2 days", "Read chapter 3", "Print 4 x 6 photos", "Room 101 cleanup"] {
        #expect(TaskTextHints.refine(ParsedTask(title: text), from: text).type == .checkbox, "\(text)")
    }
}

// MARK: - Smart Add Rules, 1.0.2

/// What Smart Add's rules make of the model's answer: `model` is the mode it gave, with
/// the words as its title.
private func smartAddRules(_ text: String, model mode: TaskMode = .oneTime) -> ParsedTask {
    TaskTextHints.refine(TaskTextHints.dropInvented(ParsedTask(title: text, mode: mode), from: text), from: text)
}

/// Days a week, day lists, weekends, days of this week, "sometime" and daily amounts.
@Test(arguments: [
    ("gym 3 days a week", TaskMode.oneTime, "Gym", TaskType.goal, TaskMode.repeating, 3.0, GoalUnitKind.quantity, ""),
    ("run 5 days per week", .oneTime, "Run", .goal, .repeating, 5, .quantity, ""),
    ("yoga 3 days/week", .oneTime, "Yoga", .goal, .repeating, 3, .quantity, ""),
    ("gym three days a week", .oneTime, "Gym", .goal, .repeating, 3, .quantity, ""),
    ("yoga each Monday", .oneTime, "Yoga", .checkbox, .repeating, nil, .quantity, ""),
    ("swim Mondays and Thursdays", .oneTime, "Swim", .goal, .repeating, 2, .quantity, ""),
    ("lift Mon, Wed, Fri", .oneTime, "Lift", .goal, .repeating, 3, .quantity, ""),
    ("tennis Tuesdays & Saturdays", .oneTime, "Tennis", .goal, .repeating, 2, .quantity, ""),
    ("run every Monday and Thursday", .oneTime, "Run", .goal, .repeating, 2, .quantity, ""),
    ("clean the garage on weekends", .oneTime, "Clean the garage", .goal, .repeating, 2, .quantity, ""),
    ("hike every weekend", .oneTime, "Hike", .goal, .repeating, 2, .quantity, ""),
    ("call the dentist tomorrow", .carryOver, "Call the dentist", .checkbox, .oneTime, nil, .quantity, ""),
    ("dinner with Sam on Friday", .repeating, "Dinner with Sam", .checkbox, .oneTime, nil, .quantity, ""),
    ("pack for this weekend", .carryOver, "Pack", .checkbox, .oneTime, nil, .quantity, ""),
    ("fix the bike sometime", .oneTime, "Fix the bike", .checkbox, .carryOver, nil, .quantity, ""),
    ("Fix the bike, no rush", .oneTime, "Fix the bike", .checkbox, .carryOver, nil, .quantity, ""),
    ("call mom when I get a chance", .oneTime, "Call mom", .checkbox, .carryOver, nil, .quantity, ""),
    ("meditate 10 min daily", .oneTime, "Meditate", .goal, .repeating, 70, .time, ""),
    ("read 20 pages daily", .oneTime, "Read", .goal, .repeating, 140, .custom, "pages"),
    ("Drink 8 glasses of water a day", .oneTime, "Drink water", .goal, .repeating, 56, .custom, "glasses"),
    ("practice piano 30 min Mon, Wed, Fri", .oneTime, "Practice piano", .goal, .repeating, 90, .time, ""),
    ("water plants", .repeating, "water plants", .checkbox, .oneTime, nil, .quantity, ""),
    ("water plants every week", .repeating, "Water plants", .checkbox, .repeating, nil, .quantity, ""),
] as [(String, TaskMode, String, TaskType, TaskMode, Double?, GoalUnitKind, String)])
func smartAddNewRules(text: String, model: TaskMode, title: String, type: TaskType, mode: TaskMode,
                      target: Double?, kind: GoalUnitKind, unit: String) {
    let task = smartAddRules(text, model: model)
    #expect(task.title == title)
    #expect(task.type == type)
    #expect(task.mode == mode)
    #expect(task.goalTarget == target)
    #expect(task.goalKind == kind)
    #expect(task.goalUnit == unit)
}

/// Words that only look like the new rules are read as before.
@Test func smartAddNewRulesLeaveLookalikes() {
    for text in ["Move Monday's meeting to Friday", "Friday team lunch", "Measure twice, cut once", "Print 4 x 6 photos",
                 "Room 101 cleanup", "Renew passport in 3 days", "Dentist every other Tuesday", "Plan 3 days in Rome"] {
        #expect(smartAddRules(text) == ParsedTask(title: text), "\(text)")
    }
    #expect(smartAddRules("Dentist every other Tuesday", model: .repeating).mode == .oneTime, "every other week isn't repeating")
    #expect(smartAddRules("Daily standup") == ParsedTask(title: "Daily standup", type: .goal, mode: .repeating, goalTarget: 7))
    #expect(smartAddRules("Weekly report") == ParsedTask(title: "Weekly report", mode: .repeating))
    // An amount "in a day" isn't each day's.
    #expect(smartAddRules("Run 5 km in a day") == ParsedTask(title: "Run in a day", type: .goal, goalTarget: 5, goalKind: .custom, goalUnit: "km"))
    // A count per day stays a count.
    #expect(smartAddRules("Take 2 pills twice a day").goalTarget == 14)
    // "Monday's" isn't a day in a list; the day's name stays in the title mid-sentence.
    #expect(smartAddRules("Lunch on Friday with Sam").title == "Lunch on Friday with Sam")
    #expect(smartAddRules("Lunch on Friday with Sam", model: .repeating).mode == .oneTime)
}

/// The model's amount for one day becomes the week's.
@Test func smartAddDailyAmountOverridesModel() {
    let model = ParsedTask(title: "Meditate", type: .goal, mode: .repeating, goalTarget: 10, goalKind: .time)
    let task = TaskTextHints.refine(TaskTextHints.dropInvented(model, from: "meditate 10 min daily"), from: "meditate 10 min daily")
    #expect(task == ParsedTask(title: "Meditate", type: .goal, mode: .repeating, goalTarget: 70, goalKind: .time,
                               goalStep: 10, goalDays: 7))
}

/// A mode the model gave stays when the words give a reason for it, and goes when they don't.
@Test func smartAddModeNeedsAReason() {
    for text in ["Water plants again", "Stretch regularly", "Morning routine", "Reading habit", "Ongoing cleanup",
                 "Keep the plants alive", "Pay rent monthly"] {
        #expect(TaskTextHints.dropInvented(ParsedTask(title: text, mode: .repeating), from: text).mode == .repeating, "\(text)")
    }
    #expect(TaskTextHints.dropInvented(ParsedTask(title: "Finish the report", mode: .carryOver), from: "Finish the report").mode == .oneTime)
    #expect(TaskTextHints.dropInvented(ParsedTask(title: "Paint the fence", mode: .carryOver), from: "Paint the fence until done").mode == .carryOver)
}

/// Words with no real word and no digit skip the model and are added as typed; others
/// go to it, and the rules check what it says.
@MainActor @Test func smartAddSkipsTheModelForNoRealWords() async throws {
    var asked = false
    do {
        _ = try await AppleIntelligenceTaskParser.parse("asldkjlkd") { _ in
            asked = true
            return ParsedTask(title: "Asldkjlkd", mode: .repeating)
        }
        Issue.record("the model's answer was used")
    } catch {
        #expect(error as? TaskTextParserError == .noRealWords)
    }
    #expect(!asked, "the model isn't asked")
    // What Smart Add then adds: the words as typed, a one-time checkbox.
    #expect(TaskTextHints.refine(ParsedTask(title: "asldkjlkd"), from: "asldkjlkd") == ParsedTask(title: "asldkjlkd"))
    #expect(!AppleIntelligenceTaskParser.hasRealWords("asldkjlkd qwpoeiru"))
    for text in ["water plants", "zxqv 3x", "Siobhan's party", "a"] {
        #expect(AppleIntelligenceTaskParser.hasRealWords(text), "\(text)")
    }

    let dentist = try await AppleIntelligenceTaskParser.parse("call the dentist tomorrow") { _ in
        ParsedTask(title: "Call the dentist", mode: .carryOver)
    }
    #expect(dentist == ParsedTask(title: "Call the dentist"), "a one-time checkbox")
}

/// The Welcome Tour's extra animations loop in 6 seconds and come to rest on their
/// Reduce Motion frames.
@Test func tourAnimationTimelines() {
    let smart = KeyframeTimeline(initialValue: SmartAddAnimation.Values()) { SmartAddAnimation.timeline }
    #expect(abs(smart.duration - 6) < 0.001)
    let smartRest = smart.value(time: 5.0), smartDone = SmartAddAnimation.Values.finished
    for path in [\SmartAddAnimation.Values.typed, \.tap, \.added, \.note] {
        #expect(abs(smartRest[keyPath: path] - smartDone[keyPath: path]) < 0.05)
    }
    let tidy = KeyframeTimeline(initialValue: TidyUpAnimation.Values()) { TidyUpAnimation.timeline }
    #expect(abs(tidy.duration - 6) < 0.001)
    let tidyRest = tidy.value(time: 5.0), tidyDone = TidyUpAnimation.Values.finished
    for path in [\TidyUpAnimation.Values.trashTap, \.deleted, \.toast, \.undoTap, \.pull, \.closed] {
        #expect(abs(tidyRest[keyPath: path] - tidyDone[keyPath: path]) < 0.05)
    }
    let goal = KeyframeTimeline(initialValue: GoalStepsAnimation.Values()) { GoalStepsAnimation.timeline }
    #expect(abs(goal.duration - 6) < 0.001)
    let goalRest = goal.value(time: 5.0), goalDone = GoalStepsAnimation.Values.finished
    for path in [\GoalStepsAnimation.Values.progress, \.plusTap, \.minusTap, \.check] {
        #expect(abs(goalRest[keyPath: path] - goalDone[keyPath: path]) < 0.05)
    }
}

// MARK: - This Week Only, Turned On and Off

struct ThisWeekOnlyTests {
    private let clock = TestClock(2099, 3, 4)
    private var nextWeek: Date { clock.weeks(1, from: clock.now) }

    private func trip(_ store: ChecklistStore) -> Tasquel.Category? {
        store.selectedWeek?.categories.first { $0.name == "Trip" }
    }

    private func makeStoreWithTrip() -> ChecklistStore {
        let store = makeIsolatedStore(clock: clock)
        store.addCategory(name: "Trip", symbol: "airplane", thisWeekOnly: true)
        return store
    }

    @Test("Adding a carry-over or repeating task turns This week only off; a one-time task doesn't", arguments: [
        TaskMode.carryOver, .repeating, .oneTime,
    ])
    func addingLastingTask(mode: TaskMode) {
        let store = makeStoreWithTrip()
        store.addParsedTask(ParsedTask(title: "Pack", mode: mode), categoryID: trip(store)!.id)
        #expect(trip(store)!.isThisWeekOnly == (mode == .oneTime))
        store.navigateToDate(nextWeek)
        #expect((trip(store) != nil) == (mode != .oneTime), "it comes back next week only if it stopped being this week only")
        #expect(store.savedCategories.contains { $0.name == "Trip" } == (mode != .oneTime))
    }

    @Test("Changing a task to carry over turns This week only off")
    func changingModeKeepsCategory() {
        let store = makeStoreWithTrip()
        let category = trip(store)!
        let id = store.addTask(categoryID: category.id, title: "Pack", mode: .oneTime)!
        store.updateTaskMode(categoryID: category.id, taskID: id, mode: .carryOver)
        #expect(trip(store)!.isThisWeekOnly == false)
        store.navigateToDate(nextWeek)
        #expect(trip(store)?.tasks.map(\.title) == ["Pack"])
    }

    @Test("Turning This week only on makes its tasks one-time and takes it out of next week")
    func turningOn() {
        let store = makeIsolatedStore(clock: clock)
        store.addCategory(name: "Trip", symbol: "airplane")
        let category = trip(store)!
        store.addTask(categoryID: category.id, title: "Pack", mode: .carryOver)
        store.addTask(categoryID: category.id, title: "Stretch", mode: .repeating)
        store.setCategoryThisWeekOnly(category.id, true)
        #expect(trip(store)!.isThisWeekOnly)
        #expect(trip(store)!.tasks.map(\.mode) == [.oneTime, .oneTime])
        store.navigateToDate(nextWeek)
        #expect(trip(store) == nil)
    }

    @Test("Turning it on takes it out of a saved later week, keeping only the user's own tasks there", arguments: [
        false, true,
    ])
    func turningOnWithSavedNextWeek(userAddedNextWeek: Bool) {
        let store = makeIsolatedStore(clock: clock)
        store.addCategory(name: "Trip", symbol: "airplane")
        store.addTask(categoryID: trip(store)!.id, title: "Pack", mode: .carryOver)
        store.navigateToDate(nextWeek)
        if userAddedNextWeek {
            store.addTask(categoryID: trip(store)!.id, title: "Unpack", mode: .oneTime)
        } else {
            // Saves next week through another card, leaving Trip's copy untouched.
            store.addTask(categoryID: store.selectedWeek!.categories[0].id, title: "Other", mode: .oneTime)
        }
        #expect(trip(store)?.tasks.map(\.title).contains("Pack") == true)
        store.navigateToDate(clock.now)
        store.setCategoryThisWeekOnly(trip(store)!.id, true)
        store.navigateToDate(nextWeek)
        #expect(trip(store)?.tasks.map(\.title) == (userAddedNextWeek ? ["Unpack"] : nil))
    }

    @Test("Turning it off brings it into next week and saves it")
    func turningOff() {
        let store = makeStoreWithTrip()
        store.addTask(categoryID: trip(store)!.id, title: "Pack", mode: .oneTime)
        store.setCategoryThisWeekOnly(trip(store)!.id, false)
        #expect(trip(store)!.isThisWeekOnly == false)
        #expect(store.savedCategories.contains { $0.name == "Trip" })
        store.navigateToDate(nextWeek)
        #expect(trip(store) != nil)
    }

    @Test("This-week-only categories from before get a saved category at launch, unless it was removed")
    func savedAtLaunch() {
        let directory = makeTempDirectory()
        let defaults = UserDefaults(suiteName: "TasquelTests-\(UUID().uuidString)")!
        let store = makeIsolatedStore(directory: directory, clock: clock, defaults: defaults)
        store.addCategory(name: "Trip", symbol: "airplane", thisWeekOnly: true)
        store.addCategory(name: "Party", symbol: "gift", thisWeekOnly: true)
        // Removed from Saved Categories by the user: stays removed.
        store.addSavedCategory(name: "Party", symbol: "gift")
        store.removeSavedCategory(store.savedCategories.first { $0.name == "Party" }!.id)
        #expect(!store.savedCategories.contains { $0.name == "Trip" })

        let relaunched = makeIsolatedStore(directory: directory, clock: clock, defaults: defaults)
        #expect(relaunched.savedCategories.contains { $0.name == "Trip" && $0.symbol == "airplane" })
        #expect(!relaunched.savedCategories.contains { $0.name == "Party" })
        #expect(trip(relaunched)!.isThisWeekOnly, "still this week only")
    }
}

// MARK: - Audit 2026-11-08

/// A repeating task deleted from a week three weeks ahead stays deleted there as the weeks
/// between come and go: each week its source is a copy of a copy, linked down the chain.
@Test func deletedRepeatingTaskStaysDeletedAsWeeksPass() {
    let clock = TestClock(2099, 3, 4)
    let store = makeIsolatedStore(clock: clock)
    let name = store.selectedWeek!.categories[0].name
    func category() -> Tasquel.Category { store.selectedWeek!.categories.first { $0.name == name }! }
    store.addParsedTask(ParsedTask(title: "Gym", mode: .repeating), categoryID: category().id)
    store.navigateToDate(clock.weeks(3, from: clock.now))
    let gym = try! #require(category().tasks.first { $0.title == "Gym" })
    store.deleteTask(categoryID: category().id, taskID: gym.id)
    store.clearUndo()
    for week in 1...3 {
        clock.now = clock.weeks(1, from: clock.now)
        store.navigateToDate(clock.now)
        #expect(category().tasks.contains { $0.title == "Gym" } == (week < 3), "week \(week)")
    }
}

/// A carry-over task isn't copied again into a new card that took a renamed card's old name.
@Test func renamedCardsOldNameDoesntDuplicateCarryOvers() {
    let clock = TestClock(2099, 3, 4)
    let store = makeIsolatedStore(clock: clock)
    let name = store.selectedWeek!.categories[0].name
    store.addParsedTask(ParsedTask(title: "Send report", mode: .carryOver), categoryID: store.selectedWeek!.categories[0].id)
    clock.now = clock.weeks(1, from: clock.now)
    store.navigateToDate(clock.now)
    let renamed = store.selectedWeek!.categories.first { $0.name == name }!
    #expect(store.renameCategory(renamed.id, newName: "Job"))
    store.addCategory(name: name, symbol: "star")
    store.navigateToDate(clock.now)
    let copies = store.selectedWeek!.categories.flatMap(\.tasks).filter { $0.title == "Send report" }
    #expect(copies.count == 1)
}

/// A repeating list with checked items goes from a saved later week when it's deleted
/// here: its checks came with it, they aren't the user's work on that copy.
@Test func deletedRepeatingListLeavesLaterWeeks() {
    let clock = TestClock(2099, 3, 4)
    let store = makeIsolatedStore(clock: clock)
    let name = store.selectedWeek!.categories[0].name
    func category() -> Tasquel.Category { store.selectedWeek!.categories.first { $0.name == name }! }
    let id = store.addParsedTask(ParsedTask(title: "Groceries", type: .list, mode: .repeating, items: ["Milk", "Eggs"]),
                                 categoryID: category().id)!
    let milk = category().tasks.first { $0.id == id }!.subtasks[0]
    store.toggleSubtask(categoryID: category().id, taskID: id, subtaskID: milk.id)
    let thisWeek = clock.now
    store.navigateToDate(clock.weeks(1, from: thisWeek))
    store.addParsedTask(ParsedTask(title: "Next week's own"), categoryID: category().id)  // saves next week
    #expect(category().tasks.contains { $0.title == "Groceries" })
    store.navigateToDate(thisWeek)
    store.deleteTask(categoryID: category().id, taskID: id)
    store.navigateToDate(clock.weeks(1, from: thisWeek))
    #expect(!category().tasks.contains { $0.title == "Groceries" })
}

/// Save Goal with nothing changed isn't an edit: next week's copy keeps following.
@Test func unchangedGoalSaveIsNotAnEdit() {
    let clock = TestClock(2099, 3, 4)
    let store = makeIsolatedStore(clock: clock)
    let name = store.selectedWeek!.categories[0].name
    func category() -> Tasquel.Category { store.selectedWeek!.categories.first { $0.name == name }! }
    store.addParsedTask(ParsedTask(title: "Swim", type: .goal, mode: .repeating, goalTarget: 3), categoryID: category().id)
    store.navigateToDate(clock.weeks(1, from: clock.now))
    let copy = try! #require(category().tasks.first { $0.title == "Swim" })
    store.setGoalTarget(categoryID: category().id, taskID: copy.id, target: 3, kind: .quantity)
    #expect(category().tasks.first { $0.title == "Swim" }?.isUserEdited == false)
}

/// Going to another week (which syncs it) doesn't end a delete's Undo.
@Test func changingWeekKeepsUndo() {
    let clock = TestClock(2099, 3, 4)
    let store = makeIsolatedStore(clock: clock)
    let name = store.selectedWeek!.categories[0].name
    func category() -> Tasquel.Category { store.selectedWeek!.categories.first { $0.name == name }! }
    let gym = store.addParsedTask(ParsedTask(title: "Gym", mode: .repeating), categoryID: category().id)!
    store.navigateToDate(clock.weeks(1, from: clock.now))
    store.addParsedTask(ParsedTask(title: "Saves next week"), categoryID: category().id)
    store.navigateToDate(clock.now)
    store.deleteTask(categoryID: category().id, taskID: gym)
    store.navigateToDate(clock.weeks(1, from: clock.now))
    #expect(store.lastDelete != nil, "Undo is still there")
    store.undoLastDelete()
    store.navigateToDate(clock.now)
    #expect(category().tasks.contains { $0.title == "Gym" })
}

/// The week moving west across midnight stays the viewed week (picked weeks were kept at
/// their first midnight, which a westward move put in the week before).
@Test func pickedWeekSurvivesTimeZoneMovingWest() {
    let clock = TestClock(2099, 3, 4)
    let store = makeIsolatedStore(clock: clock)
    let next = store.weekStartDay(containing: clock.weeks(1, from: clock.now))
    store.navigateToDate(next.date(in: clock.calendar))  // midnight, as the calendar sheet passes it
    clock.calendar.timeZone = TimeZone(identifier: "America/Chicago")!
    #expect(store.selectedWeek?.startDay == next)
    clock.calendar.timeZone = TimeZone(identifier: "Pacific/Honolulu")!
    #expect(store.selectedWeek?.startDay == next)
}

/// Settings that disagree with the saved weeks (a week-start change saved one file but
/// not the other) give way to the weeks, so the current week isn't hidden.
@Test func weekStartFollowsSavedWeeks() throws {
    let directory = makeTempDirectory()
    let defaults = UserDefaults(suiteName: "TasquelTests-\(UUID().uuidString)")!
    let clock = TestClock(2099, 3, 4)
    let first = makeIsolatedStore(directory: directory, clock: clock, defaults: defaults)
    let week = first.selectedWeek!.startDay
    first.addParsedTask(ParsedTask(title: "Kept"), categoryID: first.selectedWeek!.categories[0].id)
    // settings.json says Sunday; the weeks are Monday weeks.
    let url = directory.appending(path: "settings.json")
    var settings = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
    settings["weekStartsOnSunday"] = true
    try JSONSerialization.data(withJSONObject: settings).write(to: url)
    let second = makeIsolatedStore(directory: directory, clock: clock, defaults: defaults)
    #expect(!second.weekStartsOnSunday)
    #expect(second.selectedWeek?.startDay == week)
    #expect(second.selectedWeek?.categories.flatMap(\.tasks).contains { $0.title == "Kept" } == true)
}

/// A theme or color from a newer version reads as the default, not as unreadable settings.
@Test func unknownThemeInSettingsReadsAsDefault() throws {
    let directory = makeTempDirectory()
    let defaults = UserDefaults(suiteName: "TasquelTests-\(UUID().uuidString)")!
    _ = makeIsolatedStore(directory: directory, defaults: defaults)
    let url = directory.appending(path: "settings.json")
    var settings = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
    settings["appearanceMode"] = "neon"
    settings["retroColor"] = "teal"
    try JSONSerialization.data(withJSONObject: settings).write(to: url)
    let store = makeIsolatedStore(directory: directory, defaults: defaults)
    #expect(store.persistenceError == nil)
    #expect(store.appearanceMode == .system)
    #expect(store.retroColor == .green)
}

/// Decimal steps reach their target exactly and come back to zero.
@Test func decimalStepsMeetTheGoal() {
    let store = makeIsolatedStore()
    let category = store.selectedWeek!.categories[0]
    let id = store.addParsedTask(ParsedTask(title: "Run", type: .goal, goalTarget: 1, goalKind: .custom, goalUnit: "km"),
                                 categoryID: category.id)!
    func task() -> ChecklistTask { store.selectedWeek!.categories[0].tasks.first { $0.id == id }! }
    for _ in 0..<10 { store.updateGoalProgress(categoryID: category.id, taskID: id, progress: (task().goalProgress ?? 0) + 0.1) }
    #expect(task().isCompleted)
    #expect(task().goalProgress == 1)
    for _ in 0..<10 { store.updateGoalProgress(categoryID: category.id, taskID: id, progress: task().goalProgress! - 0.1) }
    #expect(task().goalProgress == 0)
}

/// Time is whole minutes: hours switched over from a number ("1.17") don't make 70.2.
@Test func timeAmountsAreWholeMinutes() {
    var input = GoalAmountInput()
    input.hours = "1.17"
    #expect(input.value(for: .time) == 70)
}

/// Unchecking a parent after its items changed clears them, instead of restoring checks
/// from before.
@Test func uncheckingParentAfterItemChangesClears() {
    let store = makeIsolatedStore()
    let category = store.selectedWeek!.categories[0]
    let id = store.addParsedTask(ParsedTask(title: "Packing", type: .list, items: ["A", "B"]), categoryID: category.id)!
    func task() -> ChecklistTask { store.selectedWeek!.categories[0].tasks.first { $0.id == id }! }
    store.toggleSubtask(categoryID: category.id, taskID: id, subtaskID: task().subtasks[0].id)  // A checked
    store.toggleTask(categoryID: category.id, taskID: id)                                         // all checked
    store.toggleSubtask(categoryID: category.id, taskID: id, subtaskID: task().subtasks[1].id)  // B unchecked
    store.toggleSubtask(categoryID: category.id, taskID: id, subtaskID: task().subtasks[1].id)  // B checked: done
    store.toggleTask(categoryID: category.id, taskID: id)                                         // unchecked
    #expect(task().subtasks.allSatisfy { !$0.isCompleted }, "cleared, not A back from before")
}

/// Smart Add's rules on phrases that used to go wrong.
@Test(arguments: [
    ("Call back in 2 hours", "Call back in 2 hours", TaskType.checkbox, TaskMode.oneTime, nil as Double?, nil as Double?, nil as Int?),
    ("Leave in 10 min", "Leave in 10 min", .checkbox, .oneTime, nil, nil, nil),
    ("Gym Mon, Wed, Fri 1 hour", "Gym", .goal, .repeating, 180, 60, 3),
    ("Hike weekends 2 hours", "Hike", .goal, .repeating, 240, 120, 2),
    ("Run Mon/Wed/Fri 5 km", "Run", .goal, .repeating, 15, 5, 3),
    ("Sleep in on days off", "Sleep in on days off", .checkbox, .oneTime, nil, nil, nil),
    ("Gym 3x weekly", "Gym", .goal, .repeating, 3, nil, nil),
    ("Swim twice weekly", "Swim", .goal, .repeating, 2, nil, nil),
    ("Sleep 8 hours a night", "Sleep", .goal, .repeating, 3360, 480, 7),
    ("Read for 30 minutes at night", "Read at night", .goal, .oneTime, 30, nil, nil),
] as [(String, String, TaskType, TaskMode, Double?, Double?, Int?)])
func smartAddAuditPhrases(text: String, title: String, type: TaskType, mode: TaskMode, target: Double?, step: Double?, days: Int?) {
    let task = smartAddRules(text)
    #expect(task.title == title)
    #expect(task.type == type)
    #expect(task.mode == mode)
    #expect(task.goalTarget == target)
    #expect(task.goalStep == step)
    #expect(task.goalDays == days)
}

/// "Every 3 days" is a reason for the model's repeating.
@Test func everyFewDaysKeepsRepeating() {
    let model = ParsedTask(title: "Water plants", mode: .repeating)
    #expect(TaskTextHints.dropInvented(model, from: "water plants every 3 days").mode == .repeating)
}

// MARK: - 1.0.3

extension ThisWeekOnlyTests {
    private func makeStoreWithTripTasks(_ modes: [(String, TaskMode)]) -> ChecklistStore {
        let store = makeIsolatedStore(clock: clock)
        store.addCategory(name: "Trip", symbol: "airplane")
        for (title, mode) in modes { store.addTask(categoryID: trip(store)!.id, title: title, mode: mode) }
        return store
    }

    @Test("Turning it off puts back each task's mode")
    func turningOffRestoresModes() {
        let store = makeStoreWithTripTasks([("Pack", .carryOver), ("Stretch", .repeating), ("Note", .oneTime)])
        store.setCategoryThisWeekOnly(trip(store)!.id, true)
        #expect(trip(store)!.tasks.map(\.mode) == [.oneTime, .oneTime, .oneTime])
        store.setCategoryThisWeekOnly(trip(store)!.id, false)
        #expect(trip(store)!.tasks.map(\.mode) == [.carryOver, .repeating, .oneTime])
        #expect(trip(store)!.tasks.allSatisfy { $0.modeBeforeThisWeekOnly == nil })
        store.navigateToDate(nextWeek)
        #expect(trip(store)?.tasks.map(\.title) == ["Pack", "Stretch"], "they carry on into next week again")
    }

    @Test("The modes are remembered across a relaunch")
    func modesRememberedAcrossRelaunch() {
        let directory = makeTempDirectory()
        let defaults = UserDefaults(suiteName: "TasquelTests-\(UUID().uuidString)")!
        let store = makeIsolatedStore(directory: directory, clock: clock, defaults: defaults)
        store.addCategory(name: "Trip", symbol: "airplane")
        store.addTask(categoryID: trip(store)!.id, title: "Stretch", mode: .repeating)
        store.setCategoryThisWeekOnly(trip(store)!.id, true)

        let relaunched = makeIsolatedStore(directory: directory, clock: clock, defaults: defaults)
        relaunched.setCategoryThisWeekOnly(trip(relaunched)!.id, false)
        #expect(trip(relaunched)!.tasks.map(\.mode) == [.repeating])
    }

    @Test("A copy turned on and off again in a later week still follows its task")
    func copyFollowsAfterOnAndOff() {
        let store = makeStoreWithTripTasks([("Stretch", .repeating)])
        store.navigateToDate(nextWeek)
        store.setCategoryThisWeekOnly(trip(store)!.id, true)
        store.setCategoryThisWeekOnly(trip(store)!.id, false)
        #expect(trip(store)!.tasks.first?.isUserEdited == false, "untouched, as before")

        store.navigateToDate(clock.now)
        store.renameTask(categoryID: trip(store)!.id, taskID: trip(store)!.tasks[0].id, newTitle: "Yoga")
        store.navigateToDate(nextWeek)
        #expect(trip(store)?.tasks.map(\.title) == ["Yoga"])
    }

    @Test("Adding a repeating task turns it off and puts the other tasks' modes back")
    func addingLastingTaskRestoresModes() {
        let store = makeStoreWithTripTasks([("Pack", .carryOver)])
        store.setCategoryThisWeekOnly(trip(store)!.id, true)
        store.addTask(categoryID: trip(store)!.id, title: "Stretch", mode: .repeating)
        #expect(trip(store)!.isThisWeekOnly == false)
        #expect(trip(store)!.tasks.map(\.mode) == [.carryOver, .repeating])
    }

    @Test("A mode the user picks isn't replaced by the one from before")
    func pickedModeStays() {
        let store = makeStoreWithTripTasks([("Pack", .carryOver), ("Stretch", .repeating)])
        store.setCategoryThisWeekOnly(trip(store)!.id, true)
        store.updateTaskMode(categoryID: trip(store)!.id, taskID: trip(store)!.tasks[1].id, mode: .carryOver)
        #expect(trip(store)!.isThisWeekOnly == false)
        #expect(trip(store)!.tasks.map(\.mode) == [.carryOver, .carryOver])
    }

    @Test("A task synced into a later week's This week only card is one-time there until it's off")
    func syncedCopyIsOneTime() throws {
        let store = makeStoreWithTripTasks([("Note", .oneTime)])
        store.navigateToDate(nextWeek)
        store.setCategoryThisWeekOnly(trip(store)!.id, true)
        store.navigateToDate(clock.now)
        store.addTask(categoryID: trip(store)!.id, title: "Stretch", mode: .repeating)
        store.addTask(categoryID: trip(store)!.id, title: "Taxes", mode: .carryOver)

        store.navigateToDate(nextWeek)
        let modes = Dictionary(uniqueKeysWithValues: (trip(store)?.tasks ?? []).map { ($0.title, $0.mode) })
        #expect(modes == ["Stretch": .oneTime, "Taxes": .oneTime])
        store.setCategoryThisWeekOnly(trip(store)!.id, false)
        #expect(trip(store)?.tasks.map(\.mode) == [.repeating, .carryOver])
    }

    @Test("A synced one-time copy still leaves with its task, and stays deleted")
    func syncedCopyFollowsItsTask() throws {
        let store = makeStoreWithTripTasks([("Note", .oneTime)])
        store.navigateToDate(nextWeek)
        store.setCategoryThisWeekOnly(trip(store)!.id, true)
        store.navigateToDate(clock.now)
        let taxes = store.addTask(categoryID: trip(store)!.id, title: "Taxes", mode: .carryOver)!
        store.addTask(categoryID: trip(store)!.id, title: "Stretch", mode: .repeating)

        store.navigateToDate(nextWeek)
        let stretch = try #require(trip(store)?.tasks.first { $0.title == "Stretch" })
        store.deleteTask(categoryID: trip(store)!.id, taskID: stretch.id)
        store.navigateToDate(clock.now)
        store.toggleTask(categoryID: trip(store)!.id, taskID: taxes)  // done: its copy goes
        store.navigateToDate(nextWeek)
        #expect(trip(store)?.tasks.map(\.title) == [], "Taxes left with its task; Stretch stayed deleted")
    }
}

/// Smart Add reads an amount for each of a few sessions as the week's total.
@Test(arguments: [
    ("Gym 3 times 45 min", "Gym", TaskMode.oneTime, 135.0, 45.0, 3, GoalUnitKind.time, ""),
    ("gym 3x 45 min", "Gym", .oneTime, 135, 45, 3, .time, ""),
    ("Gym 3x a week 45 min", "Gym", .repeating, 135, 45, 3, .time, ""),
    ("gym 45 min 3 times a week", "Gym", .repeating, 135, 45, 3, .time, ""),
    ("Gym 3 times a week for 45 minutes", "Gym", .repeating, 135, 45, 3, .time, ""),
    ("gym 3 times for 45 minutes", "Gym", .oneTime, 135, 45, 3, .time, ""),
    ("swim twice a week 30 min", "Swim", .repeating, 60, 30, 2, .time, ""),
    ("Gym 3 sessions of 45 min", "Gym", .oneTime, 135, 45, 3, .time, ""),
    ("Yoga three 45-minute sessions", "Yoga", .oneTime, 135, 45, 3, .time, ""),
    ("Run 3 times 5 km", "Run", .oneTime, 15, 5, 3, .custom, "km"),
    ("Run 3x weekly 1 hour", "Run", .repeating, 180, 60, 3, .time, ""),
] as [(String, String, TaskMode, Double, Double, Int, GoalUnitKind, String)])
func smartAddSessions(text: String, title: String, mode: TaskMode, target: Double, step: Double, days: Int,
                      kind: GoalUnitKind, unit: String) {
    let task = smartAddRules(text)
    #expect(task.title == title)
    #expect(task.type == .goal)
    #expect(task.mode == mode)
    #expect(task.goalTarget == target)
    #expect(task.goalStep == step)
    #expect(task.goalDays == days)
    #expect(task.goalKind == kind)
    #expect(task.goalUnit == unit)
}

/// Words that only look like sessions are read as before.
@Test func smartAddSessionLookalikes() {
    #expect(smartAddRules("Meeting at 3 for 45 min") == ParsedTask(title: "Meeting at 3", type: .goal, goalTarget: 45, goalKind: .time))
    #expect(smartAddRules("Call 2 clients 30 min").goalStep == nil)
    #expect(smartAddRules("Take 2 pills twice a day").goalTarget == 14, "a count per day stays a count")
    #expect(smartAddRules("Gym Mon, Wed, Fri 1 hour").goalTarget == 180, "days are still days")
    #expect(smartAddRules("Run 3x") == ParsedTask(title: "Run", type: .goal, goalTarget: 3))
}

/// A list's title isn't one of its items ("Bugs" came back as a list holding "Bugs").
@Test func listTitleIsntAnItem() {
    for text in ["Bugs", "v1.2", "Packing list"] {
        let list = TaskTextHints.dropInvented(ParsedTask(title: text, type: .list, items: [text]), from: text)
        #expect(list.type == .list, "\(text)")
        #expect(list.items.isEmpty, "\(text)")
    }
    let groceries = TaskTextHints.dropInvented(ParsedTask(title: "Groceries", type: .list, items: ["Groceries", "milk", "eggs"]),
                                               from: "Groceries: milk, eggs")
    #expect(groceries.items == ["milk", "eggs"])
}

/// Return in a wrapping rename field saves the name, without the line break.
@Test func renameFieldReturnSaves() {
    #expect(RenameField.submitted("Plan the trip", was: "Plan the tri") == nil)
    #expect(RenameField.submitted("Plan the trip\n", was: "Plan the trip") == "Plan the trip")
    // Return typed with the cursor inside a word saves the name as it was, with no space.
    #expect(RenameField.submitted("Groe\ncries", was: "Groecries") == "Groecries")
    // Tab on a hardware keyboard saves too, and never ends up in the name.
    #expect(RenameField.submitted("Pick up\t", was: "Pick up") == "Pick up")
    // Pasted lines (and tabs) are joined with spaces.
    #expect(RenameField.submitted("Plan the\ntrip", was: "") == "Plan the trip")
    #expect(RenameField.submitted("Plan\tthe trip", was: "P") == "Plan the trip")
    #expect(RenameField.submitted("\n", was: "") == "")
}

/// An add field's text, once it has a line break: every finished line (pasted ones too)
/// and what's still being typed after the last break.
@Test func typedLinesSplitsEveryLine() {
    #expect(TypedLines("Milk") == nil)
    let pasted = TypedLines("Line 1\nLine 2\n\nLine 3\nLine 4")
    #expect(pasted?.lines == ["Line 1", "Line 2", "Line 3"], "blank lines are dropped")
    #expect(pasted?.rest == "Line 4", "the last line is still being typed")
    #expect(TypedLines("Eggs\n")?.lines == ["Eggs"])
    #expect(TypedLines("Eggs\n")?.rest == "")
    #expect(TypedLines("\n")?.lines == [], "Return in an empty field")
    #expect(TypedLines("a\nb")?.leftover(keeping: ["a"]) == "a b", "a line that couldn't be added stays")
    #expect(TypedLines("a\n")?.leftover(keeping: []) == "")
}

/// A task moved by its handle lands past each task whose middle it reaches, going up or
/// down, and can't go past either end of the list.
@Test func taskReorderLanding() {
    let ids = (0..<3).map { _ in UUID() }
    let frames = Dictionary(uniqueKeysWithValues: ids.enumerated().map {
        ($1, CGRect(x: 0, y: CGFloat($0) * 60, width: 300, height: 40))
    })
    var down = TaskReorder(taskID: ids[0], order: ids, frames: frames, from: 0)
    down.distance = 50
    #expect(down.landing == 0, "not yet at the next task's middle")
    down.distance = 60
    #expect(down.landing == 1)
    down.distance = 120
    #expect(down.landing == 2)
    #expect(down.clamped(500) == 120)
    down.target = 2
    #expect(down.offset(for: ids[1], spacing: 20) == -60)
    #expect(down.offset(for: ids[2], spacing: 20) == -60)
    #expect(down.offset(for: ids[0], spacing: 20) == 120)

    var up = TaskReorder(taskID: ids[2], order: ids, frames: frames, from: 2)
    up.distance = -60
    #expect(up.landing == 1)
    up.distance = -120
    #expect(up.landing == 0)
    #expect(up.clamped(-500) == -120)
    up.target = 1
    #expect(up.offset(for: ids[0], spacing: 20) == 0)
    #expect(up.offset(for: ids[1], spacing: 20) == 60)
}

/// Held at either end of the list, a task takes the end task's place: a tall task (one
/// with sub-tasks) past a short last one, and rows whose sizes don't add up exactly.
@Test func taskReorderReachesTheEnds() {
    let ids = (0..<2).map { _ in UUID() }
    let frames = [ids[0]: CGRect(x: 0, y: 0, width: 300, height: 120), ids[1]: CGRect(x: 0, y: 134, width: 300, height: 40)]
    var tall = TaskReorder(taskID: ids[0], order: ids, frames: frames, from: 0)
    tall.distance = tall.clamped(1000)
    #expect(tall.landing == 1, "the tall task passes the short last one")
    var short = TaskReorder(taskID: ids[1], order: ids, frames: frames, from: 1)
    short.distance = short.clamped(-1000)
    #expect(short.landing == 0)

    let thirds = (0..<3).map { _ in UUID() }
    let height = 100.0 / 3, gap = 14.0 + 1.0 / 3
    let rows = Dictionary(uniqueKeysWithValues: thirds.enumerated().map {
        ($1, CGRect(x: 0, y: CGFloat($0) * (height + gap), width: 300, height: height))
    })
    var down = TaskReorder(taskID: thirds[0], order: thirds, frames: rows, from: 0)
    down.distance = down.clamped(1000)
    #expect(down.landing == 2)
    var up = TaskReorder(taskID: thirds[2], order: thirds, frames: rows, from: 2)
    up.distance = up.clamped(-1000)
    #expect(up.landing == 0)
}

/// A lifted task scrolls the grid only near the top or bottom of what's visible, faster
/// closer to the edge.
@Test func autoScrollSpeed() {
    let zone = TaskAutoScroller.zone, top: CGFloat = 100, bottom: CGFloat = 800
    #expect(TaskAutoScroller.velocity(fingerY: 450, top: top, bottom: bottom) == 0)
    #expect(TaskAutoScroller.velocity(fingerY: top + zone, top: top, bottom: bottom) == 0)
    #expect(TaskAutoScroller.velocity(fingerY: top + zone / 2, top: top, bottom: bottom) == -TaskAutoScroller.maxSpeed / 2)
    #expect(TaskAutoScroller.velocity(fingerY: top - 40, top: top, bottom: bottom) == -TaskAutoScroller.maxSpeed, "capped past the edge")
    #expect(TaskAutoScroller.velocity(fingerY: bottom - zone / 2, top: top, bottom: bottom) == TaskAutoScroller.maxSpeed / 2)
    #expect(TaskAutoScroller.velocity(fingerY: bottom + 10, top: top, bottom: bottom) == TaskAutoScroller.maxSpeed)
    #expect(TaskAutoScroller.velocity(fingerY: 120, top: 100, bottom: 200) == 0, "no room for both edges: no scrolling")
}

// MARK: - Review 2026-11-10 fixes (store)

/// From the 1.0.3 review (reviews/applereview-2026-11-10): edits made while a card is This
/// week only, Undo against folds and renames, and This week only cards in 1.0.2 data.
struct ReviewFixStoreTests {
    private let clock = TestClock(2099, 3, 4)  // a Wednesday, New York
    private var nextWeek: Date { clock.weeks(1, from: clock.now) }

    private func card(_ store: ChecklistStore, _ name: String) -> Tasquel.Category? {
        store.selectedWeek?.categories.first { $0.name == name }
    }

    @Test("A copy renamed while This week only is on keeps its name after it's turned off")
    func renameWhileThisWeekOnlySurvivesTurningItOff() throws {
        let store = makeIsolatedStore(clock: clock)
        store.addCategory(name: "Trip", symbol: "airplane")
        _ = store.addTask(categoryID: card(store, "Trip")!.id, title: "Stretch", mode: .repeating)
        store.navigateToDate(nextWeek)
        let tripID = try #require(card(store, "Trip")?.id)
        store.setCategoryThisWeekOnly(tripID, true)
        let copy = try #require(card(store, "Trip")?.tasks.first)
        store.renameTask(categoryID: tripID, taskID: copy.id, newTitle: "Yoga")
        store.setCategoryThisWeekOnly(tripID, false)
        store.navigateToDate(clock.now)
        store.navigateToDate(nextWeek)
        #expect(card(store, "Trip")?.tasks.map(\.title) == ["Yoga"], "the user's rename is kept")
        #expect(card(store, "Trip")?.tasks.first?.mode == .repeating, "and the mode came back")
    }

    @Test("Items added to a repeating list while This week only is on survive adding a repeating task")
    func listItemsSurviveTurningOffByAddingTask() throws {
        let store = makeIsolatedStore(clock: clock)
        store.addCategory(name: "Trip", symbol: "airplane")
        let tripNow = card(store, "Trip")!.id
        let packing = try #require(store.addTask(categoryID: tripNow, title: "Packing", mode: .repeating, type: .list))
        _ = store.addSubtask(categoryID: tripNow, taskID: packing, title: "Passport")
        store.navigateToDate(nextWeek)
        let tripID = try #require(card(store, "Trip")?.id)
        store.setCategoryThisWeekOnly(tripID, true)
        let copy = try #require(card(store, "Trip")?.tasks.first)
        _ = store.addSubtask(categoryID: tripID, taskID: copy.id, title: "Sunscreen")
        _ = store.addTask(categoryID: tripID, title: "Stretch", mode: .repeating)  // turns it off
        #expect(card(store, "Trip")?.isThisWeekOnly == false)
        store.navigateToDate(clock.now)
        store.navigateToDate(nextWeek)
        let items = card(store, "Trip")?.tasks.first { $0.title == "Packing" }?.subtasks.map(\.title)
        #expect(items == ["Passport", "Sunscreen"], "the item the user added is kept")
    }

    @Test("Progress on a carried goal while This week only is on survives turning it off")
    func goalProgressSurvivesTurningOff() throws {
        let store = makeIsolatedStore(clock: clock)
        store.addCategory(name: "Trip", symbol: "airplane")
        let tripNow = card(store, "Trip")!.id
        let run = try #require(store.addTask(categoryID: tripNow, title: "Run", mode: .carryOver, type: .goal))
        store.setGoalTarget(categoryID: tripNow, taskID: run, target: 10, kind: .custom, unit: "km")
        store.navigateToDate(nextWeek)
        let tripID = try #require(card(store, "Trip")?.id)
        store.setCategoryThisWeekOnly(tripID, true)
        let copy = try #require(card(store, "Trip")?.tasks.first)
        store.updateGoalProgress(categoryID: tripID, taskID: copy.id, progress: 6)
        store.setCategoryThisWeekOnly(tripID, false)
        store.navigateToDate(clock.now)
        store.navigateToDate(nextWeek)
        #expect(card(store, "Trip")?.tasks.first?.goalProgress == 6, "the progress the user counted is kept")
    }

    @Test("An untouched copy still follows its task after This week only goes on and off")
    func untouchedCopyStillFollows() throws {
        let store = makeIsolatedStore(clock: clock)
        store.addCategory(name: "Trip", symbol: "airplane")
        let stretch = try #require(store.addTask(categoryID: card(store, "Trip")!.id, title: "Stretch", mode: .repeating))
        store.navigateToDate(nextWeek)
        let tripID = try #require(card(store, "Trip")?.id)
        store.setCategoryThisWeekOnly(tripID, true)
        store.setCategoryThisWeekOnly(tripID, false)
        #expect(card(store, "Trip")?.tasks.first?.isUserEdited == false, "turning it on and off isn't an edit")
        store.navigateToDate(clock.now)
        store.renameTask(categoryID: card(store, "Trip")!.id, taskID: stretch, newTitle: "Yoga")
        store.navigateToDate(nextWeek)
        #expect(card(store, "Trip")?.tasks.map(\.title) == ["Yoga"], "it follows the rename")
    }

    @Test("A step counted on a repeating goal while This week only is on isn't an edit: the copy still follows")
    func repeatingGoalStepWhileThisWeekOnlyStillFollows() throws {
        let store = makeIsolatedStore(clock: clock)
        store.addCategory(name: "Fitness", symbol: "figure.run")
        let fitnessNow = card(store, "Fitness")!.id
        let run = try #require(store.addTask(categoryID: fitnessNow, title: "Run", mode: .repeating, type: .goal))
        store.setGoalTarget(categoryID: fitnessNow, taskID: run, target: 3)
        store.navigateToDate(nextWeek)
        let fitnessID = try #require(card(store, "Fitness")?.id)
        store.setCategoryThisWeekOnly(fitnessID, true)
        let copy = try #require(card(store, "Fitness")?.tasks.first)
        store.updateGoalProgress(categoryID: fitnessID, taskID: copy.id, progress: 1)
        store.setCategoryThisWeekOnly(fitnessID, false)
        #expect(card(store, "Fitness")?.tasks.first?.isUserEdited == false,
                "a repeating copy keeps its own progress while following its task")
        store.navigateToDate(clock.now)
        store.renameTask(categoryID: fitnessNow, taskID: run, newTitle: "Run club")
        store.navigateToDate(nextWeek)
        #expect(card(store, "Fitness")?.tasks.map(\.title) == ["Run club"], "it follows the rename")
        #expect(card(store, "Fitness")?.tasks.first?.goalProgress == 1, "and keeps its own progress")
    }

    @Test("Undoing a delete keeps a list folded after the delete, in later weeks too")
    func undoKeepsLaterFold() throws {
        let store = makeIsolatedStore(clock: clock)
        store.addCategory(name: "Home", symbol: "house")
        let home = card(store, "Home")!.id
        let list = try #require(store.addTask(categoryID: home, title: "Groceries", mode: .repeating, type: .list))
        _ = store.addSubtask(categoryID: home, taskID: list, title: "Milk")
        let other = try #require(store.addTask(categoryID: home, title: "Call Sam", mode: .oneTime))
        store.navigateToDate(nextWeek)
        _ = store.addTask(categoryID: card(store, "Home")!.id, title: "Plan", mode: .oneTime)  // saves next week
        store.navigateToDate(clock.now)

        store.deleteTask(categoryID: home, taskID: other)
        store.setListFolded(categoryID: home, taskID: list, folded: true)
        #expect(store.lastDelete != nil, "folding keeps the Undo")
        store.undoLastDelete()
        #expect(card(store, "Home")?.tasks.map(\.title) == ["Groceries", "Call Sam"], "the task is back")
        #expect(card(store, "Home")?.tasks.first?.isListFolded == true, "and the list stays folded")
        store.navigateToDate(nextWeek)
        #expect(card(store, "Home")?.tasks.first { $0.title == "Groceries" }?.isListFolded == true,
                "next week's copy too")
    }

    @Test("A rename finished after a delete keeps the delete's Undo, and Undo keeps the rename")
    func renameAfterDeleteKeepsUndo() throws {
        let store = makeIsolatedStore(clock: clock)
        store.addCategory(name: "Home", symbol: "house")
        let home = card(store, "Home")!.id
        let list = try #require(store.addTask(categoryID: home, title: "Groceries", mode: .oneTime, type: .list))
        for item in ["Milk", "Eggs"] { _ = store.addSubtask(categoryID: home, taskID: list, title: item) }
        let items = try #require(card(store, "Home")?.tasks.first?.subtasks)
        store.deleteSubtask(categoryID: home, taskID: list, subtaskID: items[1].id)
        // The Milk rename field was open: it saves as the keyboard goes, after the delete.
        store.renameSubtask(categoryID: home, taskID: list, subtaskID: items[0].id, newTitle: "Oat milk")
        store.renameTask(categoryID: home, taskID: list, newTitle: "Shopping")
        #expect(store.lastDelete != nil, "the delete can still be undone")
        store.undoLastDelete()
        let task = try #require(card(store, "Home")?.tasks.first)
        #expect(task.subtasks.map(\.title) == ["Oat milk", "Eggs"], "Eggs is back and the rename stays")
        #expect(task.title == "Shopping")
    }

    @Test("Other changes after a delete still end its Undo")
    func otherChangesStillEndUndo() throws {
        let store = makeIsolatedStore(clock: clock)
        store.addCategory(name: "Home", symbol: "house")
        let home = card(store, "Home")!.id
        let a = try #require(store.addTask(categoryID: home, title: "A", mode: .oneTime))
        store.deleteTask(categoryID: home, taskID: a)
        _ = store.addTask(categoryID: home, title: "B", mode: .oneTime)
        #expect(store.lastDelete == nil, "adding a task isn't in the weeks Undo would put back")
    }

    @Test("Carry-over and repeating tasks left in a This week only card by 1.0.2 load one-time")
    func oldThisWeekOnlyCardLoadsOneTime() throws {
        let directory = makeTempDirectory()
        let defaults = UserDefaults(suiteName: "TasquelTests-\(UUID().uuidString)")!
        let store = makeIsolatedStore(directory: directory, clock: clock, defaults: defaults)
        store.addCategory(name: "Study", symbol: "book")
        let study = card(store, "Study")!.id
        _ = store.addTask(categoryID: study, title: "Essay", mode: .oneTime)
        // What 1.0.2 could leave: the card this week only, a carry-over copy in it.
        let wi = try #require(store.weeks.firstIndex { $0.categories.contains { $0.id == study } })
        let ci = try #require(store.weeks[wi].categories.firstIndex { $0.id == study })
        store.weeks[wi].categories[ci].isThisWeekOnly = true
        store.weeks[wi].categories[ci].tasks.append(ChecklistTask(title: "Flashcards", mode: .carryOver, taskType: .list,
                                                                  carriedFrom: UUID()))
        store.save()

        let relaunched = makeIsolatedStore(directory: directory, clock: clock, defaults: defaults)
        let flashcards = try #require(card(relaunched, "Study")?.tasks.first { $0.title == "Flashcards" })
        #expect(flashcards.mode == .oneTime, "a This week only card holds only one-time tasks")
        #expect(flashcards.modeBeforeThisWeekOnly?.mode == .carryOver, "remembering the mode it had")
        #expect(card(relaunched, "Study")?.tasks.first { $0.title == "Essay" }?.mode == .oneTime)
    }
}
