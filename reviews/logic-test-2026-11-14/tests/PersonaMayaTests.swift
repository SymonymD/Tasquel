//
//  PersonaMayaTests.swift
//  TasquelTests
//
//  Maya, a grad student, plays her semester through the store (not the UI): exams typed
//  with dates, a repeating reading goal, a carry-over thesis with sub-tasks, a This week
//  only finals card, and a switch to Sunday weeks. Each step checks the invariants that
//  hold across features (IDs, copies, expirations, reminders, pins, duplicates, reload).
//

import Testing
import Foundation
@testable import Tasquel

// (Copies of TasquelTests.swift's private helpers.)
private func mayaTempDirectory() -> URL {
    let url = FileManager.default.temporaryDirectory.appending(path: "MayaTests-\(UUID().uuidString)")
    try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

@MainActor
private func mayaStore(directory: URL, clock: TestClock, defaults: UserDefaults) -> ChecklistStore {
    ChecklistStore(directory: directory, defaults: defaults, now: { clock.now }, calendar: { clock.calendar })
}

private let enUS = Locale(identifier: "en_US")
private let monthAbbreviations = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

/// Noon on the Wednesday of the real current week (Monday start, New York): Smart Add's date
/// finder reads typed dates against the real today, so its test can't use a 2099 clock.
private func clockOnThisRealWednesday() -> TestClock {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/New_York")!
    let monday = Week.startOfWeek(containing: Date(), firstWeekday: Week.monday, calendar: calendar)
    let wednesday = calendar.date(byAdding: .day, value: 2, to: monday)!
    let parts = calendar.dateComponents([.year, .month, .day], from: wednesday)
    return TestClock(parts.year!, parts.month!, parts.day!)
}

/// Maya's phone: one store on one directory and defaults suite, with a clock she lives by.
@MainActor
private final class Maya {
    let directory = mayaTempDirectory()
    let defaults = UserDefaults(suiteName: "MayaTests-\(UUID().uuidString)")!
    let clock: TestClock
    let store: ChecklistStore

    init(clock: TestClock = TestClock(2099, 3, 4)) {  // a Wednesday; its week starts Mon 2099-03-02
        self.clock = clock
        store = mayaStore(directory: directory, clock: clock, defaults: defaults)
    }

    var week: Week { store.selectedWeek! }
    func card(_ name: String = "Study") -> Tasquel.Category { week.categories.first { $0.name == name }! }
    func hasCard(_ name: String = "Study") -> Bool { week.categories.contains { $0.name == name } }
    func cardID(_ name: String = "Study") -> UUID { card(name).id }
    func tasks(_ name: String = "Study") -> [ChecklistTask] { week.categories.first { $0.name == name }?.tasks ?? [] }
    func titles(_ name: String = "Study") -> [String] { tasks(name).map(\.title) }
    func task(_ title: String, in name: String = "Study") -> ChecklistTask? { tasks(name).first { $0.title == title } }
    func tasks(expiringOn day: DayKey) -> [ChecklistTask] {
        week.categories.flatMap(\.tasks).filter { $0.expiresOn == day }
    }

    /// Looks at the week `offset` weeks from today's.
    func view(weeksAhead offset: Int) { store.navigateToDate(clock.weeks(offset, from: clock.now)) }
    func viewToday() { store.navigateToDate(clock.now) }
    /// Days go by (the app comes back to today, as ContentView does on a new day).
    func pass(days: Int) {
        clock.now = clock.calendar.date(byAdding: .day, value: days, to: clock.now)!
        store.navigateToDate(clock.now)
    }

    // MARK: Adding as the app does

    /// Smart Add with a written-out date: found by `TypedDate.find`, the rest parsed by the
    /// plain rules, and added with the date still in the name (as `finishSmartAdd` does).
    func smartAdd(_ text: String, in name: String = "Study") throws -> (id: UUID, typed: TypedDate) {
        let start = week.startDay
        let typed = try #require(TypedDate.find(in: text, earliest: store.earliestExpiry, calendar: store.calendar, locale: enUS))
        let words = typed.titleWithoutDate
        var parsed = TaskTextHints.refine(ParsedTask(title: words), from: words)
        parsed.title = parsed.title == typed.titleWithoutDate ? text : "\(parsed.title) \(typed.phrase)"
        let id = try #require(store.addParsedTask(parsed, categoryID: cardID(name), weekStart: start))
        return (id, typed)
    }

    /// The add note's Set Date button (`setTypedDate`).
    func tapSetDate(_ typed: TypedDate, on id: UUID, in name: String = "Study") {
        store.setTaskDate(categoryID: cardID(name), taskID: id, lastDay: typed.day)
        store.renameTask(categoryID: cardID(name), taskID: id, newTitle: typed.titleWithoutDate)
    }

    /// A new task with a date picked in the type/mode popup: the add row applies the date's
    /// rules to its picks (`pickDate`) and the date goes on as it's added (`ParsedTask.lastDay`).
    @discardableResult
    func addWithPickedDate(_ title: String, _ lastDay: DayKey, wholeWeek: Bool = false, mode: TaskMode = .oneTime,
                           type: TaskType = .checkbox, in name: String = "Study") -> UUID? {
        let start = week.startDay
        var parsed = ParsedTask(title: title, type: type, mode: ChecklistTask.dateMode(mode, lastDay: lastDay, weekStart: start))
        parsed.day = ChecklistTask.dateWeekday(lastDay, wholeWeek: wholeWeek, weekStart: start, calendar: store.calendar)
        parsed.lastDay = lastDay
        parsed.lastDayIsWeek = wholeWeek
        return store.addParsedTask(parsed, categoryID: cardID(name), weekStart: start)
    }

    // MARK: Invariants

    /// What must hold after every step: in each saved week and the viewed one (and previews
    /// of the next weeks), no two tasks or cards share an ID; at most two pinned cards a week
    /// and two pinned tasks a card; nothing past its last day; reminders once each.
    func check(_ step: String, sourceLocation: SourceLocation = #_sourceLocation) {
        var shown = store.weeks
        if let viewed = store.selectedWeek, !shown.contains(where: { $0.id == viewed.id }) { shown.append(viewed) }
        // The page beside it, as the week pager builds it.
        let preview = store.previewWeek(for: clock.weeks(1, from: store.selectedDate))
        if !shown.contains(where: { $0.id == preview.id }) { shown.append(preview) }
        let savedIDs = Dictionary(store.weeks.map { ($0.id, $0.startDay) }, uniquingKeysWith: { a, _ in a })
        for week in shown {
            if let day = savedIDs[week.id] {
                #expect(day == week.startDay, "\(step): a preview of \(week.startDay) took the ID of the saved week \(day)",
                        sourceLocation: sourceLocation)
            }
            let taskIDs = week.categories.flatMap { $0.tasks.map(\.id) }
            #expect(Set(taskIDs).count == taskIDs.count, "\(step): two tasks share an ID in the week of \(week.startDay)",
                    sourceLocation: sourceLocation)
            let categoryIDs = week.categories.map(\.id)
            #expect(Set(categoryIDs).count == categoryIDs.count, "\(step): two cards share an ID in the week of \(week.startDay)",
                    sourceLocation: sourceLocation)
            guard !store.isPastWeek(week) else { continue }
            let pinnedCards = week.categories.filter(\.isPinned).map(\.name)
            #expect(pinnedCards.count <= Tasquel.Category.maxPins,
                    "\(step): \(pinnedCards.count) pinned cards (\(pinnedCards)) in the week of \(week.startDay)",
                    sourceLocation: sourceLocation)
            let cutoff = store.isCurrentWeek(week) ? max(week.startDay, store.currentDay) : week.startDay
            for category in week.categories {
                #expect(category.pinnedTaskCount <= Tasquel.Category.maxPins,
                        "\(step): \(category.pinnedTaskCount) pinned tasks in \(category.name), week of \(week.startDay)",
                        sourceLocation: sourceLocation)
                for task in category.tasks {
                    #expect(!task.isExpired(before: cutoff),
                            "\(step): \(task.title) (last day \(task.expiresOn!)) is still in the week of \(week.startDay)",
                            sourceLocation: sourceLocation)
                }
                // Duplicates: exactly the tasks whose cleaned names repeat.
                let keys = category.tasks.map { DuplicateNames.key($0.title) }
                let expected = Set(category.tasks.filter { t in
                    let key = DuplicateNames.key(t.title)
                    return !key.isEmpty && keys.filter { $0 == key }.count > 1
                }.map(\.id))
                #expect(category.duplicateTaskIDs == expected, "\(step): duplicate marks in \(category.name)",
                        sourceLocation: sourceLocation)
            }
        }
        let reminders = store.expiryReminders
        #expect(Set(reminders.map(\.id)).count == reminders.count, "\(step): a reminder listed twice", sourceLocation: sourceLocation)
        #expect(store.selectedWeek == store.selectedWeek, "\(step): the viewed week changes between reads",
                sourceLocation: sourceLocation)
    }

    /// Reminders that come on `day` (the day before a last day).
    func reminders(on day: DayKey) -> [ExpiryReminder] { store.expiryReminders.filter { $0.day == day } }

    /// The app opened again on the same data: the same weeks and reminders.
    func checkSurvivesRelaunch(_ step: String, sourceLocation: SourceLocation = #_sourceLocation) {
        let again = mayaStore(directory: directory, clock: clock, defaults: defaults)
        #expect(again.persistenceError == nil, "\(step): data didn't load", sourceLocation: sourceLocation)
        #expect(again.weekStartsOnSunday == store.weekStartsOnSunday, "\(step): week start after relaunch",
                sourceLocation: sourceLocation)
        #expect(again.weeks == store.weeks, "\(step): saved weeks differ after relaunch", sourceLocation: sourceLocation)
        #expect(again.expiryReminders == store.expiryReminders, "\(step): reminders differ after relaunch",
                sourceLocation: sourceLocation)
    }
}

@MainActor
struct PersonaMayaTests {

    // MARK: - 1. Exams with dates

    @Test("Maya types exams with dates (Smart Add's Set Date and the popup's date) and lives through them")
    func examsWithDates() throws {
        let maya = Maya(clock: clockOnThisRealWednesday())
        let store = maya.store
        let start = maya.week.startDay
        let today = store.currentDay

        // The two ways she writes dates, as typed (any year: they're whatever comes next).
        let literalExam = try #require(TypedDate.find(in: "Exam 2/3", earliest: today, calendar: store.calendar, locale: enUS))
        #expect(literalExam.day.month == 2 && literalExam.day.day == 3 && literalExam.titleWithoutDate == "Exam")
        let literalMidterm = try #require(TypedDate.find(in: "Midterm Dec 15", earliest: today, calendar: store.calendar, locale: enUS))
        #expect(literalMidterm.day.month == 12 && literalMidterm.day.day == 15 && literalMidterm.titleWithoutDate == "Midterm")

        // This semester's: the exam on a Tuesday five weeks on, the midterm on Friday in two.
        let examDay = start.adding(days: 7 * 5 + 1)
        let midtermDay = start.adding(days: 7 * 2 + 4)
        let litReviewWeekEnd = start.adding(days: 7 * 3 + 6)
        let problemSetDay = start.adding(days: 4)

        let exam = try maya.smartAdd("Exam \(examDay.month)/\(examDay.day)")
        #expect(exam.typed.day == examDay)
        #expect(maya.task("Exam \(examDay.month)/\(examDay.day)")?.mode == .oneTime, "added as typed, one-time")
        maya.tapSetDate(exam.typed, on: exam.id)
        let midterm = try maya.smartAdd("Midterm \(monthAbbreviations[midtermDay.month - 1]) \(midtermDay.day)")
        #expect(midterm.typed.day == midtermDay)
        maya.tapSetDate(midterm.typed, on: midterm.id)

        for (title, day) in [("Exam", examDay), ("Midterm", midtermDay)] {
            let task = try #require(maya.task(title), "\(title) renamed to the words without the date")
            #expect(task.expiresOn == day)
            #expect(task.expirySetOn == today)
            #expect(task.mode == .carryOver, "\(title): one-time dated after its week carries over")
            #expect(task.dayOfWeek == nil, "\(title): a later week's date isn't a day this week")
        }

        // Dates picked in the popup: this Friday's problem set, and a lit review due by the end of week 3.
        let problemSet = try #require(maya.addWithPickedDate("Problem set 5", problemSetDay))
        let litReview = try #require(maya.addWithPickedDate("Lit review", litReviewWeekEnd, wholeWeek: true))
        #expect(maya.task("Problem set 5")?.mode == .oneTime)
        #expect(maya.task("Problem set 5")?.dayOfWeek == 6, "Friday")
        #expect(maya.task("Lit review")?.mode == .carryOver)
        #expect(maya.task("Lit review")?.expiresWithWeek == true)
        #expect(maya.task("Lit review")?.dayOfWeek == nil)
        _ = (problemSet, litReview)
        #expect(store.expiryReminders.count == 4, "one reminder each")
        #expect(maya.reminders(on: problemSetDay.adding(days: -1)).map(\.title) == ["Problem set 5 expires tomorrow"])
        #expect(maya.card().duplicateTaskIDs.isEmpty)
        maya.check("added")
        maya.checkSurvivesRelaunch("added")

        // Next week: the carried copies keep their dates; the problem set doesn't come.
        maya.view(weeksAhead: 1)
        #expect(Set(maya.titles()) == ["Exam", "Midterm", "Lit review"])
        #expect(maya.task("Exam")?.expiresOn == examDay)
        #expect(maya.task("Midterm")?.expiresOn == midtermDay)
        #expect(maya.task("Lit review")?.expiresWithWeek == true)
        // She notes the room on next week's midterm copy (that saves next week).
        let midtermCopy = try #require(maya.task("Midterm"))
        store.renameTask(categoryID: maya.cardID(), taskID: midtermCopy.id, newTitle: "Midterm (room 204)")
        #expect(maya.task("Midterm (room 204)")?.hasOwnTitle == true)
        #expect(maya.task("Midterm (room 204)")?.isUserEdited == false)
        maya.check("renamed next week's midterm")

        // Back this week, she renames both sources.
        maya.viewToday()
        store.renameTask(categoryID: maya.cardID(), taskID: exam.id, newTitle: "Stats exam")
        store.renameTask(categoryID: maya.cardID(), taskID: midterm.id, newTitle: "Stats midterm")
        maya.check("renamed the sources")
        #expect(maya.reminders(on: examDay.adding(days: -1)).count == 1,
                "one exam reminder, not one per name: \(maya.reminders(on: examDay.adding(days: -1)).map(\.title))")
        #expect(maya.reminders(on: midtermDay.adding(days: -1)).count == 1,
                "one midterm reminder, not one per name: \(maya.reminders(on: midtermDay.adding(days: -1)).map(\.title))")

        maya.view(weeksAhead: 1)
        #expect(maya.task("Stats exam")?.expiresOn == examDay, "the exam copy follows the rename and keeps the date")
        #expect(maya.task("Midterm (room 204)")?.expiresOn == midtermDay, "the renamed copy keeps its name and date")
        #expect(maya.task("Stats midterm") == nil)
        maya.viewToday()
        #expect(maya.reminders(on: midtermDay.adding(days: -1)).count == 1,
                "one midterm reminder: \(maya.reminders(on: midtermDay.adding(days: -1)).map(\.title))")
        maya.checkSurvivesRelaunch("renames")

        // Day by day through the semester.
        let lastDays = [problemSetDay, midtermDay, litReviewWeekEnd, examDay]
        for _ in 1...42 {
            maya.pass(days: 1)
            let day = store.currentDay
            for last in lastDays {
                let inFirstWeekOnly = last == problemSetDay
                let shouldBeThere = day <= last && (!inFirstWeekOnly || day < start.adding(days: 7))
                #expect(maya.tasks(expiringOn: last).count == (shouldBeThere ? 1 : 0),
                        "on \(day): the task with last day \(last) should \(shouldBeThere ? "" : "not ")be there")
                let reminderDay = last.adding(days: -1)
                let reminderTime = store.calendar.date(bySettingHour: 9, minute: 0, second: 0, of: reminderDay.date(in: store.calendar))!
                #expect(maya.reminders(on: reminderDay).count == (shouldBeThere && maya.clock.now < reminderTime ? 1 : 0),
                        "on \(day): reminders for \(last): \(maya.reminders(on: reminderDay).map(\.title))")
            }
            maya.check("on \(day)")
            if day == midtermDay || day == examDay.adding(days: 1) { maya.checkSurvivesRelaunch("on \(day)") }
        }
        #expect(maya.week.categories.flatMap(\.tasks).allSatisfy { $0.expiresOn == nil })
        maya.view(weeksAhead: 1)
        #expect(maya.tasks().isEmpty, "nothing dated comes back after its date")
    }

    // MARK: - 2. A repeating reading goal

    @Test("Maya's repeating Read goal: target changes, a day, a renamed copy, a copy deleted and brought back, then a date")
    func repeatingReadGoal() throws {
        let maya = Maya()
        let store = maya.store
        let start = maya.week.startDay  // Monday 2099-03-02; today is Wednesday
        let read = try #require(store.addTask(categoryID: maya.cardID(), title: "Read", mode: .repeating, type: .goal))
        store.setGoalTarget(categoryID: maya.cardID(), taskID: read, target: 100, kind: .custom, unit: "pages")
        store.setGoalStep(categoryID: maya.cardID(), taskID: read, step: nil, days: 5)
        #expect(maya.task("Read")?.goalStepOrAutomatic == 20, "100 pages over 5 days")
        store.updateGoalProgress(categoryID: maya.cardID(), taskID: read, progress: 40)
        #expect(abs(maya.card().doneFraction - 0.4) < 1e-9, "the ring counts the goal's progress")

        // Mid-week she raises the target, and puts it on Mondays.
        store.setGoalTarget(categoryID: maya.cardID(), taskID: read, target: 120, kind: .custom, unit: "pages")
        #expect(maya.task("Read")?.goalStepOrAutomatic == 24)
        #expect(abs(maya.card().doneFraction - 40.0 / 120) < 1e-9)
        store.setTaskDay(categoryID: maya.cardID(), taskID: read, day: Week.monday)
        #expect(maya.task("Read")?.isLate(inWeekStarting: start, firstWeekday: store.firstWeekday, today: store.currentDay) == true,
                "Monday has gone by unfinished")
        #expect(maya.card().shownTasks(firstWeekday: store.firstWeekday, day: 3).isEmpty, "Tuesday's filter hides a Monday task")
        maya.check("set up")

        // Next week's copy: renamed for the chapter.
        maya.view(weeksAhead: 1)
        var copy = try #require(maya.task("Read"))
        #expect(copy.repeatsFrom == read && copy.goalTarget == 120 && copy.goalProgress == 0 && copy.dayOfWeek == Week.monday)
        store.renameTask(categoryID: maya.cardID(), taskID: copy.id, newTitle: "Read ch. 4")
        copy = try #require(maya.task("Read ch. 4"))
        #expect(copy.hasOwnTitle && !copy.isUserEdited)
        maya.check("renamed next week's copy")

        // She changes the source's target: the copy follows it and keeps its name.
        maya.viewToday()
        store.setGoalTarget(categoryID: maya.cardID(), taskID: read, target: 150, kind: .custom, unit: "pages")
        maya.view(weeksAhead: 1)
        #expect(maya.titles() == ["Read ch. 4"])
        #expect(maya.task("Read ch. 4")?.goalTarget == 150)
        #expect(maya.task("Read ch. 4")?.dayOfWeek == Week.monday)
        maya.check("target followed")

        // Two weeks ahead, she deletes it; then picks its mode again to bring it back.
        maya.view(weeksAhead: 2)
        let twoAhead = try #require(maya.tasks().first, "the copy two weeks ahead")
        #expect(twoAhead.title == "Read ch. 4", "it follows the renamed copy before it")
        store.deleteTask(categoryID: maya.cardID(), taskID: twoAhead.id)
        #expect(maya.tasks().isEmpty)
        #expect(store.lastDelete != nil)
        maya.view(weeksAhead: 3)
        #expect(maya.tasks().isEmpty, "the week after is built from the one she deleted it from")
        maya.check("deleted two weeks ahead")
        maya.viewToday()
        store.updateTaskMode(categoryID: maya.cardID(), taskID: read, mode: .repeating)
        #expect(maya.task("Read")?.isUserEdited == true, "picking the same mode isn't another edit (it was already edited)")
        maya.view(weeksAhead: 2)
        #expect(maya.titles() == ["Read ch. 4"], "brought back")
        #expect(maya.tasks().first?.goalTarget == 150)
        maya.view(weeksAhead: 3)
        #expect(maya.titles() == ["Read ch. 4"])
        maya.check("brought back")
        maya.checkSurvivesRelaunch("brought back")

        // Then she gives the source a date three weeks out (that week's Wednesday).
        let lastDay = start.adding(days: 7 * 3 + 2)
        maya.viewToday()
        store.setTaskDate(categoryID: maya.cardID(), taskID: read, lastDay: lastDay)
        #expect(maya.task("Read")?.mode == .repeating, "repeating stays repeating")
        #expect(maya.task("Read")?.dayOfWeek == Week.monday, "a date in a later week leaves its day")
        maya.check("dated")
        for ahead in 1...3 {
            maya.view(weeksAhead: ahead)
            let copy = try #require(maya.tasks().first, "week +\(ahead) has its copy")
            #expect(copy.title == "Read ch. 4", "week +\(ahead) keeps the copy's name")
            #expect(copy.expiresOn == lastDay, "week +\(ahead)'s copy takes the date")
            #expect(copy.goalTarget == 150 && copy.dayOfWeek == Week.monday)
        }
        maya.view(weeksAhead: 4)
        #expect(maya.tasks().isEmpty, "never repeats past its last day")
        maya.viewToday()
        let reminderDay = lastDay.adding(days: -1)
        #expect(maya.reminders(on: reminderDay).count == 1,
                "one reminder for the reading goal: \(maya.reminders(on: reminderDay).map(\.title))")
        maya.check("copies dated")
        maya.checkSurvivesRelaunch("copies dated")

        // Weeks go by.
        for _ in 1...3 {
            maya.pass(days: 7)
            #expect(maya.tasks().count == 1 && maya.tasks()[0].expiresOn == lastDay, "on \(store.currentDay)")
            // (Until 9 AM the day before; on its last day the reminder has come and gone.)
            let expected = store.currentDay < reminderDay ? 1 : 0
            #expect(maya.reminders(on: reminderDay).count == expected,
                    "on \(store.currentDay): \(maya.reminders(on: reminderDay).map(\.title))")
            maya.check("on \(store.currentDay)")
        }
        #expect(store.currentDay == lastDay)
        #expect(maya.tasks().first?.isLate(inWeekStarting: maya.week.startDay, firstWeekday: store.firstWeekday,
                                          today: store.currentDay) == true)
        maya.pass(days: 1)
        #expect(maya.tasks().isEmpty, "gone the day after its last day")
        #expect(store.expiryReminders.isEmpty)
        maya.view(weeksAhead: 1)
        #expect(maya.tasks().isEmpty)
        maya.check("after the date")
        maya.checkSurvivesRelaunch("after the date")
    }

    // MARK: - 3. A carry-over thesis with sub-tasks

    @Test("Maya's carry-over Thesis: sub-tasks, a pin, a duplicate, a date, finished the next week")
    func thesisCarryOver() throws {
        let maya = Maya()
        let store = maya.store
        let start = maya.week.startDay
        let thesis = try #require(store.addTask(categoryID: maya.cardID(), title: "Thesis"))
        for item in ["Lit review", "Methods", "Results", "Discussion"] {
            store.addSubtask(categoryID: maya.cardID(), taskID: thesis, title: item)
        }
        for item in ["Lit review", "Methods"] {
            let id = maya.task("Thesis")!.subtasks.first { $0.title == item }!.id
            store.toggleSubtask(categoryID: maya.cardID(), taskID: thesis, subtaskID: id)
        }
        #expect(maya.task("Thesis")?.isCompleted == false)
        #expect(abs(maya.card().doneFraction - 0.5) < 1e-9, "ring: half its items")

        // She plans ahead, which saves the next two weeks.
        maya.view(weeksAhead: 1)
        store.addTask(categoryID: maya.cardID(), title: "Advisor meeting", mode: .oneTime)
        maya.view(weeksAhead: 2)
        store.addTask(categoryID: maya.cardID(), title: "Conference abstract", mode: .oneTime)
        #expect(maya.task("Thesis")?.subtasks.map(\.title) == ["Results", "Discussion"])
        maya.viewToday()

        // Pin it; it's pinned in the saved weeks' copies too.
        store.setTaskPinned(categoryID: maya.cardID(), taskID: thesis, pinned: true)
        for ahead in 1...2 {
            maya.view(weeksAhead: ahead)
            #expect(maya.task("Thesis")?.isPinned == true, "week +\(ahead)'s copy is pinned")
            #expect(maya.card().orderedTasks(firstWeekday: store.firstWeekday).first?.title == "Thesis")
        }
        maya.viewToday()

        // She adds "thesis" again: both are marked.
        let again = try #require(store.addTask(categoryID: maya.cardID(), title: "thesis"))
        #expect(maya.card().duplicateTaskIDs == [thesis, again])
        // Deletes it, unpins Thesis meanwhile (keeps the Undo), and undoes the delete.
        store.deleteTask(categoryID: maya.cardID(), taskID: again)
        #expect(maya.card().duplicateTaskIDs.isEmpty)
        store.setTaskPinned(categoryID: maya.cardID(), taskID: thesis, pinned: false)
        #expect(store.lastDelete != nil, "a pin keeps the Undo")
        store.undoLastDelete()
        #expect(maya.card().duplicateTaskIDs == [thesis, again], "back, and marked")
        #expect(maya.task("Thesis")?.isPinned == false, "Undo doesn't take the pin change back")
        store.setTaskPinned(categoryID: maya.cardID(), taskID: thesis, pinned: true)
        maya.check("duplicate")

        maya.view(weeksAhead: 1)
        #expect(maya.card().duplicateTaskIDs.count == 2, "both copies arrive marked: \(maya.titles())")
        #expect(maya.card().pinnedTaskCount == 1)
        maya.check("next week with the duplicate")

        // She dates the thesis: Friday in two weeks.
        let due = start.adding(days: 7 * 2 + 4)
        maya.viewToday()
        store.setTaskDate(categoryID: maya.cardID(), taskID: thesis, lastDay: due)
        #expect(maya.task("Thesis")?.mode == .carryOver)
        #expect(maya.task("Thesis")?.dayOfWeek == nil)
        for ahead in 1...2 {
            maya.view(weeksAhead: ahead)
            let copy = try #require(maya.task("Thesis"), "week +\(ahead)")
            #expect(copy.expiresOn == due && copy.isPinned && copy.subtasks.map(\.title) == ["Results", "Discussion"])
        }
        maya.view(weeksAhead: 3)
        #expect(maya.task("Thesis") == nil, "never carried past its date")
        #expect(maya.task("thesis") != nil, "the undated one carries on")
        maya.viewToday()
        #expect(maya.reminders(on: due.adding(days: -1)).map(\.title) == ["Thesis expires tomorrow"])
        maya.check("dated")
        maya.checkSurvivesRelaunch("dated")

        // Next week she finishes it.
        maya.pass(days: 7)
        let copy = try #require(maya.task("Thesis"))
        #expect(copy.isPinned && copy.expiresOn == due)
        #expect(maya.card().duplicateTaskIDs.count == 2)
        store.toggleTask(categoryID: maya.cardID(), taskID: copy.id)
        #expect(maya.task("Thesis")?.isCompleted == true)
        #expect(maya.task("Thesis")?.subtasks.allSatisfy(\.isCompleted) == true)
        #expect(maya.card().duplicateTaskIDs.count == 2, "both still there, both marked")
        // Past weeks are view only: last week's Thesis can't be re-dated.
        maya.view(weeksAhead: -1)
        store.setTaskDate(categoryID: maya.cardID(), taskID: thesis, lastDay: nil)
        #expect(maya.task("Thesis")?.expiresOn == due)
        maya.viewToday()
        // Finished, so no reminder (she hasn't looked at the week after yet).
        #expect(maya.reminders(on: due.adding(days: -1)).isEmpty,
                "a finished carry-over gets no reminder: \(maya.reminders(on: due.adding(days: -1)).map(\.title))")
        maya.check("finished")

        maya.view(weeksAhead: 1)
        #expect(maya.task("Thesis") == nil, "a finished carry-over leaves the week after")
        #expect(maya.task("thesis") != nil)
        #expect(maya.card().duplicateTaskIDs.isEmpty, "alone, no longer marked")
        #expect(maya.titles().contains("Conference abstract"))
        #expect(maya.reminders(on: due.adding(days: -1)).isEmpty)
        maya.check("week after finishing")
        maya.checkSurvivesRelaunch("week after finishing")
    }

    // MARK: - 4. Finals week

    @Test("Maya's Study card is This week only for finals, with dated and pinned tasks, then every week again")
    func finalsWeek() throws {
        let maya = Maya()
        let store = maya.store
        let start = maya.week.startDay
        store.addTask(categoryID: maya.cardID(), title: "Read", mode: .repeating)
        store.addTask(categoryID: maya.cardID(), title: "Thesis", mode: .carryOver)
        store.setCategoryPinned(categoryID: maya.cardID(), pinned: true)
        store.setCategoryPinned(categoryID: maya.cardID("Errands"), pinned: true)

        // Finals: Study this week only.
        store.setCategoryThisWeekOnly(maya.cardID(), true)
        #expect(maya.tasks().allSatisfy { $0.mode == .oneTime })
        #expect(maya.task("Read")?.modeBeforeThisWeekOnly?.mode == .repeating)
        maya.view(weeksAhead: 1)
        #expect(!maya.hasCard(), "next week has no Study")
        // Next week she pins Work (Errands is pinned there already).
        store.setCategoryPinned(categoryID: maya.cardID("Work"), pinned: true)
        #expect(maya.week.categories.filter(\.isPinned).map(\.name).sorted() == ["Errands", "Work"])
        maya.check("next week's pins")
        maya.viewToday()

        // Dated finals: the stats final this Friday (popup), and a paper due next Tuesday.
        let statsDay = start.adding(days: 4)
        let paperDay = start.adding(days: 8)
        let stats = try #require(maya.addWithPickedDate("Stats final", statsDay))
        #expect(maya.task("Stats final")?.mode == .oneTime && maya.task("Stats final")?.dayOfWeek == 6)
        #expect(maya.card().isThisWeekOnly)
        store.setTaskPinned(categoryID: maya.cardID(), taskID: stats, pinned: true)
        let paper = try #require(maya.addWithPickedDate("Final paper", paperDay))
        #expect(maya.card().isThisWeekOnly,
                "dating a task in a This week only card past the week shouldn't silently make the card every week")
        if !maya.card().isThisWeekOnly {
            // What the app did: Final paper became Carry Over, which turned This week only off
            // and gave Read and Thesis their modes back.
            #expect(maya.task("Read")?.mode == .repeating)
            #expect(maya.task("Final paper")?.mode == .carryOver)
            // She turns it back on.
            store.setCategoryThisWeekOnly(maya.cardID(), true)
        }
        #expect(maya.task("Final paper")?.mode == .oneTime, "in a This week only card")
        #expect(maya.task("Final paper")?.modeBeforeThisWeekOnly?.mode == .carryOver)
        #expect(maya.reminders(on: paperDay.adding(days: -1)).isEmpty, "it won't be there on Monday, so no reminder")
        store.setTaskPinned(categoryID: maya.cardID(), taskID: paper, pinned: true)
        store.setTaskPinned(categoryID: maya.cardID(), taskID: maya.task("Read")!.id, pinned: true)
        #expect(maya.card().pinnedTaskCount == 2, "a third pin is refused")
        #expect(maya.task("Read")?.isPinned == false)
        #expect(maya.reminders(on: statsDay.adding(days: -1)).map(\.title) == ["Stats final expires tomorrow"])
        maya.check("finals set up")
        maya.checkSurvivesRelaunch("finals set up")

        // Plans change: every week again.
        store.setCategoryThisWeekOnly(maya.cardID(), false)
        #expect(maya.task("Read")?.mode == .repeating)
        #expect(maya.task("Thesis")?.mode == .carryOver)
        #expect(maya.task("Final paper")?.mode == .carryOver, "the date's carry-over comes back")
        #expect(maya.task("Stats final")?.mode == .oneTime)
        #expect(maya.task("Final paper")?.expiresOn == paperDay && maya.task("Stats final")?.expiresOn == statsDay)
        #expect(maya.reminders(on: paperDay.adding(days: -1)).count == 1)
        maya.check("every week again")

        maya.view(weeksAhead: 1)
        #expect(maya.hasCard(), "Study comes back next week")
        #expect(Set(maya.titles()) == ["Read", "Thesis", "Final paper"])
        #expect(maya.task("Final paper")?.expiresOn == paperDay)
        #expect(maya.task("Final paper")?.isPinned == true)
        maya.check("next week after finals")  // pins: Errands, Work, and the returning Study?
        maya.checkSurvivesRelaunch("next week after finals")

        // The paper's day passes.
        maya.pass(days: 7)  // next Wednesday
        #expect(maya.task("Final paper") == nil, "gone the day after Tuesday")
        #expect(maya.task("Stats final") == nil)
        #expect(maya.task("Read") != nil && maya.task("Thesis") != nil)
        maya.check("after the paper")
    }

    // MARK: - 5. Week start

    @Test("Maya switches from Monday to Sunday weeks mid-semester with dated tasks, day tasks and reminders")
    func weekStartSwitch() throws {
        let maya = Maya()  // Wednesday 2099-03-04; Monday weeks: Mon 03-02 … Sun 03-08
        let store = maya.store
        let start = maya.week.startDay
        let seminar = try #require(store.addTask(categoryID: maya.cardID(), title: "Seminar reading", mode: .repeating))
        store.setTaskDay(categoryID: maya.cardID(), taskID: seminar, day: Week.monday)
        let lab = try #require(store.addTask(categoryID: maya.cardID(), title: "Lab report", mode: .oneTime))
        let sunday = start.adding(days: 6)
        store.setTaskDate(categoryID: maya.cardID(), taskID: lab, lastDay: sunday)
        let grant = try #require(store.addTask(categoryID: maya.cardID(), title: "Grant draft", mode: .oneTime))
        let grantDay = start.adding(days: 9)  // next Wednesday
        store.setTaskDate(categoryID: maya.cardID(), taskID: grant, lastDay: grantDay)
        let office = try #require(store.addTask(categoryID: maya.cardID(), title: "Office hours", mode: .oneTime))
        store.setTaskDay(categoryID: maya.cardID(), taskID: office, day: 5)
        maya.view(weeksAhead: 1)
        store.addTask(categoryID: maya.cardID(), title: "Committee email", mode: .oneTime)
        maya.viewToday()

        #expect(maya.task("Lab report")?.mode == .oneTime && maya.task("Lab report")?.dayOfWeek == 1, "Sunday, its last day")
        #expect(maya.task("Grant draft")?.mode == .carryOver)
        func late(_ title: String) -> Bool {
            maya.task(title)!.isLate(inWeekStarting: maya.week.startDay, firstWeekday: store.firstWeekday, today: store.currentDay)
        }
        #expect(late("Seminar reading") && !late("Lab report") && !late("Office hours"))
        let remindersBefore = store.expiryReminders
        #expect(remindersBefore.map(\.day) == [sunday.adding(days: -1), grantDay.adding(days: -1)]
                || Set(remindersBefore.map(\.day)) == [sunday.adding(days: -1), grantDay.adding(days: -1)])
        maya.check("Monday weeks")

        // Sunday weeks now.
        store.setWeekStartsOnSunday(true)
        #expect(maya.week.startDay == start.adding(days: -1))
        #expect(Set(maya.titles()) == ["Seminar reading", "Lab report", "Grant draft", "Office hours"])
        #expect(store.expiryReminders == remindersBefore, "reminders keep their days")
        #expect(late("Seminar reading"), "Monday still went by")
        #expect(!late("Office hours"), "Thursday is still to come")
        let labTask = try #require(maya.task("Lab report"))
        #expect(labTask.day(inWeekStarting: maya.week.startDay, firstWeekday: store.firstWeekday) == labTask.expiresOn,
                "the day shown for the lab report should be its date, Sunday the 8th")
        #expect(!late("Lab report"), "its date (Sunday the 8th) is still to come")
        maya.check("Sunday weeks")
        maya.checkSurvivesRelaunch("Sunday weeks")

        maya.view(weeksAhead: 1)  // now Sun 03-08 … Sat 03-14
        #expect(maya.week.startDay == sunday)
        #expect(maya.task("Grant draft")?.expiresOn == grantDay)
        #expect(maya.task("Committee email") != nil, "the saved week moved with its tasks")
        #expect(maya.task("Seminar reading")?.dayOfWeek == Week.monday)
        #expect(maya.task("Lab report") != nil, "Sunday the 8th is the lab report's last day, so it should be there")
        maya.check("next Sunday week")
        maya.viewToday()

        // Sunday comes.
        maya.pass(days: 4)
        #expect(store.currentDay == sunday)
        #expect(maya.task("Lab report") != nil, "on its last day")
        #expect(maya.task("Grant draft") != nil)
        maya.check("Sunday")
        maya.pass(days: 4)  // Thursday 03-12
        #expect(maya.task("Grant draft") == nil, "gone after Wednesday")
        #expect(maya.task("Seminar reading") != nil)
        maya.check("Thursday")
        maya.checkSurvivesRelaunch("Thursday")
    }

    @Test("On a Sunday the switch moves weeks six days: a task dated today stays today's, a Saturday task isn't late")
    func weekStartSwitchOnASunday() throws {
        let maya = Maya(clock: TestClock(2099, 3, 8))  // Sunday, the last day of the Monday week 03-02
        let store = maya.store
        let lab = try #require(store.addTask(categoryID: maya.cardID(), title: "Lab report", mode: .oneTime))
        store.setTaskDate(categoryID: maya.cardID(), taskID: lab, lastDay: store.currentDay)
        let quiz = try #require(store.addTask(categoryID: maya.cardID(), title: "Quiz prep", mode: .carryOver))
        store.setTaskDay(categoryID: maya.cardID(), taskID: quiz, day: 7)
        func late(_ title: String) -> Bool {
            maya.task(title)!.isLate(inWeekStarting: maya.week.startDay, firstWeekday: store.firstWeekday, today: store.currentDay)
        }
        #expect(late("Quiz prep"))
        store.setWeekStartsOnSunday(true)
        #expect(maya.week.startDay == store.currentDay)
        #expect(maya.task("Lab report")?.expiresOn == store.currentDay)
        #expect(!late("Lab report") && !late("Quiz prep"))
        maya.check("switched on a Sunday")
        maya.checkSurvivesRelaunch("switched on a Sunday")
        maya.pass(days: 1)
        #expect(maya.task("Lab report") == nil)
        #expect(maya.task("Quiz prep") != nil)
        maya.check("Monday after")
    }

    // MARK: - Minimal repros

    @Test("Repro: a renamed later copy of a dated task gets a second reminder")
    func reproRenamedCopySecondReminder() throws {
        let maya = Maya()
        let store = maya.store
        let lastDay = maya.week.startDay.adding(days: 16)  // Wednesday in two weeks
        let paper = try #require(store.addTask(categoryID: maya.cardID(), title: "Paper", mode: .carryOver))
        store.setTaskDate(categoryID: maya.cardID(), taskID: paper, lastDay: lastDay)
        maya.view(weeksAhead: 1)
        store.renameTask(categoryID: maya.cardID(), taskID: maya.task("Paper")!.id, newTitle: "Paper v2")
        maya.viewToday()
        let titles = maya.reminders(on: lastDay.adding(days: -1)).map(\.title)
        #expect(titles.count == 1, "one task, one reminder: \(titles)")
    }

    @Test("Repro: renaming a dated task before a saved later week syncs gives two reminders")
    func reproRenameBeforeSyncSecondReminder() throws {
        let maya = Maya()
        let store = maya.store
        let lastDay = maya.week.startDay.adding(days: 9)  // next Wednesday
        let paper = try #require(store.addTask(categoryID: maya.cardID(), title: "Paper", mode: .carryOver))
        store.setTaskDate(categoryID: maya.cardID(), taskID: paper, lastDay: lastDay)
        maya.view(weeksAhead: 1)
        store.addTask(categoryID: maya.cardID(), title: "Other", mode: .oneTime)  // saves next week
        maya.viewToday()
        store.renameTask(categoryID: maya.cardID(), taskID: paper, newTitle: "Stats paper")
        let titles = maya.reminders(on: lastDay.adding(days: -1)).map(\.title)
        #expect(titles.count == 1, "one task, one reminder: \(titles)")
    }

    @Test("Repro: a carry-over finished this week still gets its reminder from next week's saved copy")
    func reproFinishedCarryOverStillReminds() throws {
        let maya = Maya()
        let store = maya.store
        let lastDay = maya.week.startDay.adding(days: 9)  // next Wednesday
        let paper = try #require(store.addTask(categoryID: maya.cardID(), title: "Paper", mode: .carryOver))
        store.setTaskDate(categoryID: maya.cardID(), taskID: paper, lastDay: lastDay)
        maya.view(weeksAhead: 1)
        store.addTask(categoryID: maya.cardID(), title: "Other", mode: .oneTime)  // saves next week
        maya.viewToday()
        store.toggleTask(categoryID: maya.cardID(), taskID: paper)
        #expect(maya.reminders(on: lastDay.adding(days: -1)).isEmpty,
                "finished, so it won't be there next week: \(maya.reminders(on: lastDay.adding(days: -1)).map(\.title))")
        maya.view(weeksAhead: 1)
        #expect(maya.task("Paper") == nil)
        #expect(maya.reminders(on: lastDay.adding(days: -1)).isEmpty, "after looking at next week")
    }

    @Test("Repro: a dated task deleted from next week still gets its reminder")
    func reproDeletedCopyStillReminds() throws {
        let maya = Maya()
        let store = maya.store
        let lastDay = maya.week.startDay.adding(days: 16)  // Wednesday in two weeks
        let read = try #require(store.addTask(categoryID: maya.cardID(), title: "Read", mode: .repeating))
        store.setTaskDate(categoryID: maya.cardID(), taskID: read, lastDay: lastDay)
        maya.view(weeksAhead: 1)
        store.deleteTask(categoryID: maya.cardID(), taskID: maya.task("Read")!.id)
        maya.view(weeksAhead: 2)
        #expect(maya.task("Read") == nil, "not in its last week")
        maya.viewToday()
        #expect(maya.reminders(on: lastDay.adding(days: -1)).isEmpty,
                "it won't be there: \(maya.reminders(on: lastDay.adding(days: -1)).map(\.title))")
    }

    @Test("Repro: a pinned carry-over arriving in a later week's card with two pins makes three")
    func reproSyncedCopyExceedsTaskPins() throws {
        let maya = Maya()
        let store = maya.store
        maya.view(weeksAhead: 1)
        for title in ["Advisor meeting", "TA grading"] {
            let id = try #require(store.addTask(categoryID: maya.cardID(), title: title, mode: .oneTime))
            store.setTaskPinned(categoryID: maya.cardID(), taskID: id, pinned: true)
        }
        #expect(maya.card().pinnedTaskCount == 2)
        maya.viewToday()
        let thesis = try #require(store.addTask(categoryID: maya.cardID(), title: "Thesis", mode: .carryOver))
        store.setTaskPinned(categoryID: maya.cardID(), taskID: thesis, pinned: true)
        maya.view(weeksAhead: 1)
        #expect(maya.task("Thesis") != nil)
        #expect(maya.card().pinnedTaskCount <= Tasquel.Category.maxPins,
                "pinned: \(maya.tasks().filter(\.isPinned).map(\.title))")
    }

    @Test("Repro: a pinned card coming back to a later week that has two pins makes three")
    func reproReturningCardExceedsCardPins() throws {
        let maya = Maya()
        let store = maya.store
        store.setCategoryPinned(categoryID: maya.cardID(), pinned: true)
        store.setCategoryThisWeekOnly(maya.cardID(), true)
        maya.view(weeksAhead: 1)
        store.setCategoryPinned(categoryID: maya.cardID("Errands"), pinned: true)
        store.setCategoryPinned(categoryID: maya.cardID("Work"), pinned: true)
        maya.viewToday()
        store.setCategoryThisWeekOnly(maya.cardID(), false)
        maya.view(weeksAhead: 1)
        #expect(maya.hasCard())
        let pinned = maya.week.categories.filter(\.isPinned).map(\.name)
        #expect(pinned.count <= Tasquel.Category.maxPins, "pinned cards: \(pinned)")
    }

    @Test("Repro: dating a task in a This week only card past the week turns This week only off")
    func reproDatingTurnsThisWeekOnlyOff() throws {
        let maya = Maya()
        let store = maya.store
        store.addTask(categoryID: maya.cardID(), title: "Read", mode: .repeating)
        store.setCategoryThisWeekOnly(maya.cardID(), true)
        let paper = try #require(store.addTask(categoryID: maya.cardID(), title: "Final paper", mode: .oneTime))
        #expect(maya.card().isThisWeekOnly)
        store.setTaskDate(categoryID: maya.cardID(), taskID: paper, lastDay: maya.week.startDay.adding(days: 8))
        #expect(maya.card().isThisWeekOnly, "only a date was set")
        #expect(maya.task("Read")?.mode == .oneTime, "\(maya.task("Read")!.mode)")
    }

    @Test("Repro: after switching to Sunday weeks, a one-time task dated on the old week's Sunday is late and gone a day early")
    func reproSundayDateAfterWeekStartSwitch() throws {
        let maya = Maya()  // Wednesday 2099-03-04, Monday weeks
        let store = maya.store
        let sunday = maya.week.startDay.adding(days: 6)  // 03-08, the week's last day
        let lab = try #require(store.addTask(categoryID: maya.cardID(), title: "Lab report", mode: .oneTime))
        store.setTaskDate(categoryID: maya.cardID(), taskID: lab, lastDay: sunday)
        #expect(maya.task("Lab report")?.mode == .oneTime, "dated inside its week")
        store.setWeekStartsOnSunday(true)  // the week is now Sun 03-01 … Sat 03-07
        let task = try #require(maya.task("Lab report"))
        #expect(!task.isLate(inWeekStarting: maya.week.startDay, firstWeekday: store.firstWeekday, today: store.currentDay),
                "shown as late on Wednesday though it's due Sunday the 8th")
        maya.pass(days: 4)  // Sunday 03-08, its last day
        #expect(maya.task("Lab report") != nil, "gone on its last day")
    }

    @Test("Repro: two carry-overs with one name both carry into a new week, but only one into a saved one")
    func reproExactDuplicateDroppedFromSavedWeek() throws {
        // Next week not saved: both copies arrive.
        let fresh = Maya()
        for _ in 0..<2 { fresh.store.addTask(categoryID: fresh.cardID(), title: "Thesis", mode: .carryOver) }
        #expect(fresh.card().duplicateTaskIDs.count == 2)
        fresh.view(weeksAhead: 1)
        #expect(fresh.titles() == ["Thesis", "Thesis"])

        // Next week saved first: only one arrives.
        let maya = Maya()
        maya.view(weeksAhead: 1)
        maya.store.addTask(categoryID: maya.cardID(), title: "Advisor meeting", mode: .oneTime)
        maya.viewToday()
        for _ in 0..<2 { maya.store.addTask(categoryID: maya.cardID(), title: "Thesis", mode: .carryOver) }
        maya.view(weeksAhead: 1)
        #expect(maya.titles().filter { $0 == "Thesis" }.count == 2, "\(maya.titles())")
    }

    @Test("Repro: a date moved from this week to a later one keeps the day the first date gave it")
    func reproRedatedTaskKeepsOldDay() throws {
        let maya = Maya()
        let store = maya.store
        let start = maya.week.startDay
        let draft = try #require(store.addTask(categoryID: maya.cardID(), title: "Chapter draft", mode: .oneTime))
        store.setTaskDate(categoryID: maya.cardID(), taskID: draft, lastDay: start.adding(days: 4))  // this Friday
        #expect(maya.task("Chapter draft")?.dayOfWeek == 6)
        store.setTaskDate(categoryID: maya.cardID(), taskID: draft, lastDay: start.adding(days: 18))  // Friday in two weeks
        #expect(maya.task("Chapter draft")?.mode == .carryOver)
        #expect(maya.task("Chapter draft")?.dayOfWeek == nil, "the Friday came from the old date")
        maya.pass(days: 8)  // next Thursday: the copy says Fri
        maya.pass(days: 2)  // Saturday
        let copy = try #require(maya.task("Chapter draft"))
        #expect(!copy.isLate(inWeekStarting: maya.week.startDay, firstWeekday: store.firstWeekday, today: store.currentDay),
                "shown late a week before it's due")
    }

    @Test("Repro: a dated task in a This week only card gets a reminder for a day it won't be there")
    func reproThisWeekOnlyReminder() throws {
        let maya = Maya()
        let store = maya.store
        let lastDay = maya.week.startDay.adding(days: 9)  // next Wednesday
        let paper = try #require(store.addTask(categoryID: maya.cardID(), title: "Final paper", mode: .carryOver))
        store.setTaskDate(categoryID: maya.cardID(), taskID: paper, lastDay: lastDay)
        store.setCategoryThisWeekOnly(maya.cardID(), true)
        #expect(maya.task("Final paper")?.mode == .oneTime)
        maya.view(weeksAhead: 1)
        #expect(!maya.hasCard(), "next week has no Study, so no Final paper")
        maya.viewToday()
        #expect(maya.reminders(on: lastDay.adding(days: -1)).isEmpty,
                "reminded the day before a last day it won't reach: \(maya.reminders(on: lastDay.adding(days: -1)).map(\.title))")
    }

    @Test("Repro: typed dates are read against the real today, not the store's clock")
    func reproTypedDateIgnoresStoreClock() {
        let maya = Maya()  // the store's today is 2099-03-04
        let found = TypedDate.find(in: "Exam 2/3", earliest: maya.store.earliestExpiry, calendar: maya.store.calendar, locale: enUS)
        #expect(found?.day == DayKey(year: 2100, month: 2, day: 3), "\(String(describing: found))")
    }
}
