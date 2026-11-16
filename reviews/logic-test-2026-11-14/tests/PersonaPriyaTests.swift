//
//  PersonaPriyaTests.swift
//  TasquelTests
//
//  Priya, a freelancer training for a race, plays several weeks through the store:
//  training goals, a client card, planning ahead, reminders and day boundaries. Each step
//  checks the invariants that matter (IDs, copies, expirations, reminders, the ring, reload).
//  The `repro…` tests at the end are minimal repros of what the persona runs found.
//

import Testing
import Foundation
@testable import Tasquel

// MARK: - Harness

private func priyaTempDirectory() -> URL {
    let url = FileManager.default.temporaryDirectory.appending(path: "TasquelPriya-\(UUID().uuidString)")
    try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

/// One persona's phone: a data folder, a defaults suite and a clock, so a second store on the
/// same folder is the app relaunched.
@MainActor
private final class Priya {
    let directory = priyaTempDirectory()
    let defaults = UserDefaults(suiteName: "TasquelPriya-\(UUID().uuidString)")!
    let clock: TestClock
    var store: ChecklistStore!

    init(_ clock: TestClock) {
        self.clock = clock
        store = make()
    }

    func make() -> ChecklistStore {
        let clock = clock
        return ChecklistStore(directory: directory, defaults: defaults, now: { clock.now }, calendar: { clock.calendar })
    }

    /// The days go by (ContentView calls `navigateToDate` on a new day).
    func advance(days: Int) {
        clock.now = clock.calendar.date(byAdding: .day, value: days, to: clock.now)!
        store.navigateToDate(clock.now)
    }

    func view(weeksAhead count: Int) { store.navigateToDate(clock.weeks(count, from: clock.now)) }
    func viewThisWeek() { store.navigateToDate(clock.now) }

    var week: Week { store.selectedWeek! }
    func card(_ name: String) -> Tasquel.Category? { store.selectedWeek?.categories.first { $0.name == name } }
    func cardID(_ name: String) -> UUID { card(name)!.id }
    func task(_ card: String, _ title: String) -> ChecklistTask? { self.card(card)?.tasks.first { $0.title == title } }
    func task(_ card: String, id: UUID) -> ChecklistTask? { self.card(card)?.tasks.first { $0.id == id } }
    func titles(_ card: String) -> [String] { self.card(card)?.tasks.map(\.title) ?? [] }

    @discardableResult
    func addCard(_ name: String, thisWeekOnly: Bool = false) -> UUID {
        store.addCategory(name: name, symbol: "folder", thisWeekOnly: thisWeekOnly)
        return cardID(name)
    }

    @discardableResult
    func add(_ title: String, to card: String, mode: TaskMode = .carryOver, type: TaskType = .checkbox) -> UUID {
        store.addTask(categoryID: cardID(card), title: title, mode: mode, type: type)!
    }

    /// A saved week starting on `start`, if any.
    func saved(_ start: DayKey) -> Week? { store.weeks.first { $0.startDay == start } }

    /// The reminders' titles, in order.
    var reminderTitles: [String] { store.expiryReminders.map(\.title) }
}

private func day(_ month: Int, _ number: Int, _ year: Int = 2099) -> DayKey { DayKey(year: year, month: month, day: number) }

/// What must hold after every step: no two tasks (or cards) share an ID in a week, the viewed
/// one included (a preview); no task past its last day in the current or a later saved week;
/// each reminder once; at most two pins; and the data reloads as it is.
@MainActor
private func checkInvariants(_ p: Priya, _ step: String, reload: Bool = true,
                             sourceLocation: SourceLocation = #_sourceLocation) {
    let store = p.store!
    var weeks = store.weeks
    if let viewed = store.selectedWeek { weeks.append(viewed) }
    for week in weeks {
        let taskIDs = week.categories.flatMap { $0.tasks.map(\.id) }
        #expect(Set(taskIDs).count == taskIDs.count, "\(step): two tasks share an ID in \(week.startDay)", sourceLocation: sourceLocation)
        let cardIDs = week.categories.map(\.id)
        #expect(Set(cardIDs).count == cardIDs.count, "\(step): two cards share an ID in \(week.startDay)", sourceLocation: sourceLocation)
        #expect(week.categories.filter(\.isPinned).count <= Tasquel.Category.maxPins, "\(step): too many pinned cards", sourceLocation: sourceLocation)
        for card in week.categories {
            #expect(card.pinnedTaskCount <= Tasquel.Category.maxPins, "\(step): too many pins in \(card.name)", sourceLocation: sourceLocation)
        }
    }
    let today = store.currentDay
    for week in store.weeks where !store.isPastWeek(week) {
        let cutoff = store.isCurrentWeek(week) ? max(week.startDay, today) : week.startDay
        let expired = week.categories.flatMap(\.tasks).filter { $0.isExpired(before: cutoff) }.map(\.title)
        #expect(expired.isEmpty, "\(step): expired tasks still in \(week.startDay): \(expired)", sourceLocation: sourceLocation)
    }
    let reminders = store.expiryReminders
    #expect(Set(reminders.map(\.id)).count == reminders.count, "\(step): a reminder twice", sourceLocation: sourceLocation)
    if reload {
        let relaunched = p.make()
        #expect(relaunched.weeks == store.weeks, "\(step): data changed across a relaunch", sourceLocation: sourceLocation)
        #expect(relaunched.expiryReminders == reminders, "\(step): reminders changed across a relaunch", sourceLocation: sourceLocation)
    }
}

private func near(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 1e-9 }

// MARK: - Persona

@MainActor
struct PersonaPriyaTests {

    // MARK: 1. Training goals

    @Test("Training: Run and Yoga goals through progress, target changes, a race date and a type round trip")
    func trainingGoals() throws {
        let p = Priya(TestClock(2099, 3, 4))  // Wednesday; the week is Mon 3/2 – Sun 3/8
        let training = p.addCard("Training")
        let run = p.add("Run", to: "Training", mode: .repeating, type: .goal)
        p.store.setGoalTarget(categoryID: training, taskID: run, target: 3)
        let yoga = p.add("Yoga", to: "Training", mode: .repeating, type: .goal)
        p.store.setGoalTarget(categoryID: training, taskID: yoga, target: 90, kind: .time)
        p.store.setGoalStep(categoryID: training, taskID: yoga, step: nil, days: 5)
        #expect(p.task("Training", id: run)?.goalStepOrAutomatic == 1, "3 ÷ 7 rounds up to 1")
        #expect(p.task("Training", id: yoga)?.goalStepOrAutomatic == 18, "90 min over 5 days")
        checkInvariants(p, "goals set up")

        // She logs a run and a yoga session.
        p.store.updateGoalProgress(categoryID: training, taskID: run, progress: 1)
        p.store.updateGoalProgress(categoryID: training, taskID: yoga, progress: 18)
        #expect(near(p.card("Training")!.doneFraction, (1.0 / 3 + 0.2) / 2), "ring: a third of Run, a fifth of Yoga")
        #expect(p.card("Training")!.completedCount == 0)

        // Mid-week she raises both targets.
        p.store.setGoalTarget(categoryID: training, taskID: run, target: 4)
        p.store.setGoalTarget(categoryID: training, taskID: yoga, target: 120, kind: .time)
        let yogaNow = try #require(p.task("Training", id: yoga))
        #expect(yogaNow.goalDays == 5 && yogaNow.goalStepOrAutomatic == 24, "the days stay: 120 ÷ 5")
        #expect(p.task("Training", id: run)?.goalProgress == 1)
        #expect(near(p.card("Training")!.doneFraction, (0.25 + 0.15) / 2))
        checkInvariants(p, "targets raised")

        // Next week (a preview): the new targets, progress back to zero, the days kept.
        p.view(weeksAhead: 1)
        let nextRun = try #require(p.task("Training", "Run"))
        #expect(nextRun.repeatsFrom == run && nextRun.goalTarget == 4 && nextRun.goalProgress == 0)
        #expect(p.task("Training", "Yoga")?.goalDays == 5 && p.task("Training", "Yoga")?.goalTarget == 120)
        // She logs a run there ahead of time; a step on a repeating copy isn't an edit.
        p.store.updateGoalProgress(categoryID: p.cardID("Training"), taskID: nextRun.id, progress: 1)
        #expect(p.task("Training", id: nextRun.id)?.isUserEdited == false)
        #expect(p.saved(day(3, 9)) != nil, "next week saved by the edit")
        checkInvariants(p, "next week saved", reload: false)
        p.viewThisWeek()

        // Race day: Sunday 3/29, four weeks out.
        let race = day(3, 29)
        p.store.setTaskDate(categoryID: training, taskID: run, lastDay: race)
        let dated = try #require(p.task("Training", id: run))
        #expect(dated.mode == .repeating && dated.expiresOn == race && dated.dayOfWeek == nil)
        #expect(dated.goalTarget == 4 && dated.goalProgress == 1, "dating leaves the goal's numbers")
        #expect(p.store.expiryReminders.filter { $0.title == "Run expires tomorrow" }.map(\.day) == [day(3, 28)],
                "one reminder for Run, the day before race day")
        checkInvariants(p, "race date")

        p.view(weeksAhead: 3)  // Mar 23 – 29: the race week still has Run
        #expect(p.task("Training", "Run")?.expiresOn == race)
        p.view(weeksAhead: 4)  // Mar 30: after the race
        #expect(p.task("Training", "Run") == nil, "no Run after race day")
        #expect(p.task("Training", "Yoga") != nil)
        p.view(weeksAhead: 1)  // the saved week's copy follows the date and keeps its own progress
        #expect(p.task("Training", "Run")?.expiresOn == race)
        #expect(p.task("Training", "Run")?.goalProgress == 1)
        p.viewThisWeek()

        // Goal → checkbox and back (the user confirms the first).
        p.store.updateTaskType(categoryID: training, taskID: run, type: .checkbox)
        #expect(p.task("Training", id: run)?.taskType == .checkbox && p.task("Training", id: run)?.goalTarget == nil)
        #expect(p.task("Training", id: run)?.expiresOn == race, "the date stays")
        p.store.updateTaskType(categoryID: training, taskID: run, type: .goal)
        p.store.setGoalTarget(categoryID: training, taskID: run, target: 3)
        let back = try #require(p.task("Training", id: run))
        #expect(back.taskType == .goal && back.goalTarget == 3 && back.expiresOn == race && back.mode == .repeating)
        #expect(p.store.expiryReminders.filter { $0.title == "Run expires tomorrow" }.count == 1)
        checkInvariants(p, "type round trip")

        // Next week's copy: type and target follow; the run she logged there (her own
        // progress, which a repeating copy keeps) is gone after the round trip.
        p.view(weeksAhead: 1)
        let copy = try #require(p.task("Training", "Run"))
        #expect(copy.taskType == .goal && copy.goalTarget == 3 && copy.expiresOn == race)
        #expect(copy.goalProgress == 1, "the copy's own progress stays (CLAUDE.md: followingRepeating)")
        p.viewThisWeek()
        checkInvariants(p, "end")
    }

    @Test("Training words through Smart Add: a date only when it's a date, the goal's numbers left alone")
    func trainingWords() async throws {
        let calendar = Calendar.weekDates()
        let today = DayKey(Date(), in: calendar)
        let us = Locale(identifier: "en_US")
        /// What Smart Add does with the words (TaskRowCard `smartAdd` / `finishSmartAdd`): the
        /// date is found first, the rest is parsed by the rules, and the task is named.
        func smartAdd(_ text: String) async throws -> (date: TypedDate?, parsed: ParsedTask, name: String) {
            let date = TypedDate.find(in: text, earliest: today, calendar: calendar, locale: us)
            let words = date?.titleWithoutDate ?? text
            let parsed = try await AppleIntelligenceTaskParser.parse(words) { ParsedTask(title: $0) }
            let name = date.map { parsed.title == $0.titleWithoutDate ? text : "\(parsed.title) \($0.phrase)" } ?? parsed.title
            return (date, parsed, name)
        }

        let until = try await smartAdd("Run 3x per week until 12/15")
        #expect(until.date?.day.month == 12 && until.date?.day.day == 15 && until.date?.phrase == "12/15",
                "found: \(String(describing: until.date))")
        #expect(until.date?.titleWithoutDate == "Run 3x per week", "“until” goes with the date")
        #expect(until.parsed.type == .goal && until.parsed.goalTarget == 3 && until.parsed.mode == .repeating)
        #expect(until.parsed.title == "Run")

        let fiveK = try await smartAdd("Run 5k 3/4")
        #expect(fiveK.date?.day.month == 3 && fiveK.date?.day.day == 4, "3/4 after the words reads as March 4")
        #expect(fiveK.parsed.goalTarget == nil || fiveK.parsed.goalTarget == 5, "3/4 isn't a goal amount")
        #expect(fiveK.name.contains("3/4"), "the name keeps the date until Set Date")

        let swim = try await smartAdd("Swim 2.5 miles")
        #expect(swim.date == nil, "a decimal isn't a date")
        #expect(swim.name.contains("2.5"), "the distance isn't lost")

        let squats = try await smartAdd("Squats 3-5 sets")
        #expect(squats.date == nil, "a range isn't a date")
        #expect(squats.name.contains("3-5"))

        let long = try await smartAdd("Long run Dec 3")
        #expect(long.date?.day.month == 12 && long.date?.day.day == 3)
        #expect(long.date?.titleWithoutDate == "Long run" && long.name == "Long run Dec 3")
        #expect(long.parsed.type == .checkbox)

        // Fractions of a distance, which runners type.
        let quarter = try await smartAdd("Run 3/4 mile")
        #expect(quarter.date == nil, "“3/4 mile” is a distance, not March 4")
        let half = try await smartAdd("Swim 1/2 mile 3x per week")
        #expect(half.date == nil, "“1/2 mile” is a distance, not January 2")
        #expect(half.parsed.goalTarget == 3)
        #expect(half.name.contains("1/2 mile"), "the distance stays where it was typed: \(half.name)")
    }

    // MARK: 2. Client projects

    @Test("Client X: a This week only card with carry-overs, dates and a pin, switched off and on")
    func clientProjects() throws {
        let p = Priya(TestClock(2099, 3, 4))  // Wednesday
        // Made as an every-week card first, so it has carry-over tasks.
        let clientX = p.addCard("Client X")
        let proposal = p.add("Draft proposal", to: "Client X", type: .list)
        for item in ["Scope", "Budget", "Timeline", "Team"] {
            p.store.addSubtask(categoryID: clientX, taskID: proposal, title: item)
        }
        for item in p.task("Client X", id: proposal)!.subtasks.prefix(2) {
            p.store.toggleSubtask(categoryID: clientX, taskID: proposal, subtaskID: item.id)
        }
        let hours = p.add("Billable hours", to: "Client X", type: .goal)
        p.store.setGoalTarget(categoryID: clientX, taskID: hours, target: 40, unit: "hours")
        p.store.updateGoalProgress(categoryID: clientX, taskID: hours, progress: 10)
        let kickoff = p.add("Kickoff call", to: "Client X", mode: .oneTime)
        p.store.toggleTask(categoryID: clientX, taskID: kickoff)
        let invoice = p.add("Send invoice", to: "Client X", mode: .oneTime)
        p.store.setTaskDate(categoryID: clientX, taskID: invoice, lastDay: day(3, 6))  // Friday
        p.store.setTaskPinned(categoryID: clientX, taskID: proposal, pinned: true)

        #expect(p.task("Client X", id: invoice)?.dayOfWeek == 6 && p.task("Client X", id: invoice)?.mode == .oneTime)
        #expect(p.card("Client X")!.orderedTasks(firstWeekday: p.store.firstWeekday).first?.id == proposal, "pinned first")
        #expect(near(p.card("Client X")!.doneFraction, (0.5 + 0.25 + 1 + 0) / 4), "ring: half the list, a quarter of the hours, the call")
        #expect(p.card("Client X")!.completedCount == 1)
        #expect(p.reminderTitles == ["Send invoice expires tomorrow"])
        checkInvariants(p, "Client X set up")

        // This week only on.
        p.store.setCategoryThisWeekOnly(clientX, true)
        let on = try #require(p.card("Client X"))
        #expect(on.isThisWeekOnly && on.tasks.allSatisfy { $0.mode == .oneTime })
        #expect(p.task("Client X", id: proposal)?.modeBeforeThisWeekOnly?.mode == .carryOver)
        #expect(p.task("Client X", id: proposal)?.isPinned == true, "the pin stays")
        #expect(p.task("Client X", id: invoice)?.expiresOn == day(3, 6) && p.task("Client X", id: invoice)?.dayOfWeek == 6)
        #expect(near(on.doneFraction, 1.75 / 4), "the ring doesn't change")
        p.view(weeksAhead: 1)
        #expect(p.card("Client X") == nil, "not next week")
        p.viewThisWeek()
        checkInvariants(p, "This week only on")

        // She adds the final delivery and dates it two weeks out.
        let delivery = p.add("Final delivery", to: "Client X", mode: .oneTime)
        #expect(p.card("Client X")?.isThisWeekOnly == true)
        p.store.setTaskDate(categoryID: clientX, taskID: delivery, lastDay: day(3, 18))
        #expect(p.card("Client X")?.isThisWeekOnly == true,
                "dating a task leaves the card's This week only switch as she set it")
        #expect(p.task("Client X", id: delivery)?.expiresOn == day(3, 18))
        checkInvariants(p, "delivery dated")

        // Off and on again, by hand (if dating already turned it off, it's turned on first).
        if p.card("Client X")?.isThisWeekOnly == false { p.store.setCategoryThisWeekOnly(clientX, true) }
        p.store.setCategoryThisWeekOnly(clientX, false)
        let off = try #require(p.card("Client X"))
        #expect(!off.isThisWeekOnly)
        #expect(p.task("Client X", id: proposal)?.mode == .carryOver && p.task("Client X", id: hours)?.mode == .carryOver)
        #expect(p.task("Client X", id: kickoff)?.mode == .oneTime && p.task("Client X", id: invoice)?.mode == .oneTime)
        #expect(p.task("Client X", id: delivery)?.mode == .carryOver, "dated past its week: carries over until then")
        #expect(p.task("Client X", id: invoice)?.expiresOn == day(3, 6) && p.task("Client X", id: invoice)?.dayOfWeek == 6)
        p.view(weeksAhead: 1)
        #expect(p.titles("Client X") == ["Draft proposal", "Billable hours", "Final delivery"])
        #expect(p.task("Client X", "Draft proposal")?.subtasks.map(\.title) == ["Timeline", "Team"])
        #expect(p.task("Client X", "Draft proposal")?.isPinned == true)
        #expect(p.task("Client X", "Billable hours")?.goalProgress == 10)
        #expect(p.task("Client X", "Final delivery")?.expiresOn == day(3, 18))
        p.view(weeksAhead: 3)  // Mar 23: after the delivery date
        #expect(p.task("Client X", "Final delivery") == nil)
        p.viewThisWeek()
        p.store.setCategoryThisWeekOnly(clientX, true)
        #expect(p.card("Client X")!.tasks.allSatisfy { $0.mode == .oneTime })
        p.store.setCategoryThisWeekOnly(clientX, false)
        #expect(p.task("Client X", id: delivery)?.mode == .carryOver && p.task("Client X", id: proposal)?.mode == .carryOver)
        checkInvariants(p, "off and on and off")

        // A second "send invoice" is a duplicate.
        let second = p.add("send  invoice ", to: "Client X", mode: .oneTime)
        #expect(p.card("Client X")!.duplicateTaskIDs == [invoice, second])
        p.store.deleteTask(categoryID: clientX, taskID: second, undoable: false)

        // Friday: still there (its last day). Saturday: gone, and the ring counts what's left.
        p.advance(days: 2)
        #expect(p.task("Client X", "Send invoice") != nil)
        #expect(p.task("Client X", "Send invoice")?.isLate(inWeekStarting: p.week.startDay, firstWeekday: p.store.firstWeekday,
                                                           today: p.store.currentDay) == false)
        p.advance(days: 1)
        #expect(p.task("Client X", "Send invoice") == nil, "gone the day after its date")
        let left = try #require(p.card("Client X"))
        #expect(left.tasks.count == 4)
        #expect(near(left.doneFraction, (0.5 + 0.25 + 1 + 0) / 4))
        checkInvariants(p, "Saturday")
    }

    // MARK: 3. Planning ahead

    @Test("Planning ahead: a preview five weeks out, a task added there, renames and a date from this week")
    func planningAhead() throws {
        let p = Priya(TestClock(2099, 3, 4))
        let training = p.addCard("Training")
        let longRun = p.add("Long run", to: "Training", mode: .repeating)
        let plan = p.add("Plan season", to: "Training")
        checkInvariants(p, "set up")

        // Five weeks ahead (Apr 6): a preview, its IDs stable while she looks.
        p.view(weeksAhead: 5)
        #expect(p.saved(day(4, 6)) == nil, "still a preview")
        let previewIDs = p.card("Training")!.tasks.map(\.id)
        #expect(p.card("Training")!.tasks.map(\.repeatsFrom).contains(longRun))
        #expect(p.card("Training")!.tasks.map(\.carriedFrom).contains(plan))
        p.view(weeksAhead: 4)
        p.view(weeksAhead: 5)
        #expect(p.card("Training")!.tasks.map(\.id) == previewIDs, "the same IDs on a second look")
        checkInvariants(p, "preview", reload: false)

        // She adds a task there: the week is saved with the preview's IDs.
        p.add("Book race hotel", to: "Training", mode: .oneTime)
        #expect(p.saved(day(4, 6)) != nil)
        #expect(Array(p.card("Training")!.tasks.map(\.id).prefix(2)) == previewIDs)
        checkInvariants(p, "week +5 saved", reload: false)

        // Back to this week; next week's preview keeps its IDs when this week changes.
        p.viewThisWeek()
        let nextIDs = p.store.previewWeek(for: p.clock.weeks(1, from: p.clock.now)).categories.first { $0.name == "Training" }!.tasks.map(\.id)
        p.add("Foam roll", to: "Training", mode: .oneTime)
        let nextAfter = p.store.previewWeek(for: p.clock.weeks(1, from: p.clock.now)).categories.first { $0.name == "Training" }!.tasks.map(\.id)
        #expect(nextAfter == nextIDs)

        // She renames the source: it reaches week +5's copy (and the previews in between).
        p.store.renameTask(categoryID: training, taskID: longRun, newTitle: "Long run (easy)")
        p.view(weeksAhead: 2)
        #expect(p.task("Training", "Long run (easy)") != nil)
        p.view(weeksAhead: 5)
        let copy = try #require(p.card("Training")?.tasks.first { $0.repeatsFrom == longRun })
        #expect(copy.title == "Long run (easy)")
        // Renaming week +5's copy changes only it, only its name.
        p.store.renameTask(categoryID: p.cardID("Training"), taskID: copy.id, newTitle: "Race-pace run")
        let renamed = try #require(p.task("Training", id: copy.id))
        #expect(renamed.hasOwnTitle && !renamed.isUserEdited)
        p.viewThisWeek()
        #expect(p.task("Training", id: longRun)?.title == "Long run (easy)", "the rename doesn't flow backward")
        p.view(weeksAhead: 4)
        #expect(p.task("Training", "Long run (easy)") != nil, "nor into the previews before it")
        p.viewThisWeek()
        p.store.renameTask(categoryID: training, taskID: longRun, newTitle: "Long run (Z2)")
        p.view(weeksAhead: 5)
        #expect(p.task("Training", id: copy.id)?.title == "Race-pace run", "the copy keeps its own name")
        p.viewThisWeek()
        checkInvariants(p, "renames")

        // She dates the repeating task for Sunday 3/22 (week +2).
        p.store.setTaskDate(categoryID: training, taskID: longRun, lastDay: day(3, 22))
        #expect(p.task("Training", id: longRun)?.mode == .repeating && p.task("Training", id: longRun)?.dayOfWeek == nil)
        p.view(weeksAhead: 2)
        #expect(p.task("Training", "Long run (Z2)")?.expiresOn == day(3, 22))
        p.view(weeksAhead: 3)
        #expect(p.card("Training")!.tasks.allSatisfy { $0.repeatsFrom == nil }, "no Long run after its date")
        p.view(weeksAhead: 5)
        #expect(p.task("Training", id: copy.id) == nil, "the renamed copy leaves with its source")
        #expect(p.task("Training", "Book race hotel") != nil)
        p.viewThisWeek()
        #expect(p.store.expiryReminders.map(\.day) == [day(3, 21)])
        checkInvariants(p, "dated")

        // A week later, last week is view only: dating, a mode pick, a rename do nothing.
        p.advance(days: 7)
        p.store.navigateToDate(p.clock.weeks(-1, from: p.clock.now))
        #expect(p.store.isPastWeek(p.week))
        let before = p.store.weeks
        let pastPlan = try #require(p.task("Training", "Plan season"))
        p.store.setTaskDate(categoryID: p.cardID("Training"), taskID: pastPlan.id, lastDay: day(3, 30))
        p.store.updateTaskMode(categoryID: p.cardID("Training"), taskID: pastPlan.id, mode: .carryOver)
        p.store.setTaskDate(categoryID: p.cardID("Training"), taskID: longRun, lastDay: nil)
        #expect(p.store.weeks == before, "a past week can't be changed")
        p.viewThisWeek()
        checkInvariants(p, "past week")
    }

    // MARK: 4. Reminders

    @Test("Reminders: one per task and date through renames, a removed date, completion, a deleted copy")
    func reminders() throws {
        let p = Priya(TestClock(2099, 3, 4))  // Wednesday noon
        let admin = p.addCard("Admin")
        let taxes = p.add("Tax forms", to: "Admin")
        p.store.setTaskDate(categoryID: admin, taskID: taxes, lastDay: day(3, 11))  // next Wednesday
        let bag = p.add("Gym bag", to: "Admin", mode: .repeating)
        p.store.setTaskDate(categoryID: admin, taskID: bag, lastDay: day(3, 13))
        let call = p.add("Call accountant", to: "Admin", mode: .oneTime)
        p.store.setTaskDate(categoryID: admin, taskID: call, lastDay: day(3, 6))
        #expect(p.task("Admin", id: call)?.mode == .oneTime && p.task("Admin", id: call)?.dayOfWeek == 6)
        // Next week is saved (she adds a note there), with copies of Tax forms and Gym bag.
        p.view(weeksAhead: 1)
        p.add("Next week note", to: "Admin", mode: .oneTime)
        #expect(p.titles("Admin") == ["Tax forms", "Gym bag", "Next week note"])
        p.viewThisWeek()
        #expect(Set(p.reminderTitles) == ["Tax forms expires tomorrow", "Gym bag expires tomorrow", "Call accountant expires tomorrow"])
        #expect(p.reminderTitles.count == 3)
        checkInvariants(p, "set up")

        // A rename this week: one reminder, under the new name.
        p.store.renameTask(categoryID: admin, taskID: taxes, newTitle: "Taxes")
        #expect(p.reminderTitles.filter { $0.hasPrefix("Tax") } == ["Taxes expires tomorrow"],
                "one reminder for the renamed task (next week not opened since)")
        p.view(weeksAhead: 1)
        p.viewThisWeek()
        #expect(p.reminderTitles.filter { $0.hasPrefix("Tax") } == ["Taxes expires tomorrow"])

        // Next week's copy renamed: still one reminder for that task and date.
        p.view(weeksAhead: 1)
        let copy = try #require(p.task("Admin", "Taxes"))
        p.store.renameTask(categoryID: p.cardID("Admin"), taskID: copy.id, newTitle: "Taxes (final)")
        #expect(p.store.expiryReminders.filter { $0.day == day(3, 10) }.count == 1,
                "one reminder for Tax forms' date: \(p.reminderTitles)")
        p.store.renameTask(categoryID: p.cardID("Admin"), taskID: copy.id, newTitle: "Taxes")
        #expect(p.task("Admin", id: copy.id)?.hasOwnTitle == false)
        p.viewThisWeek()
        checkInvariants(p, "renames")

        // The date removed this week: no reminder.
        p.store.setTaskDate(categoryID: admin, taskID: taxes, lastDay: nil)
        #expect(!p.reminderTitles.contains("Taxes expires tomorrow"), "no date, no reminder")
        p.view(weeksAhead: 1)
        p.viewThisWeek()
        #expect(!p.reminderTitles.contains("Taxes expires tomorrow"))
        p.store.setTaskDate(categoryID: admin, taskID: taxes, lastDay: day(3, 11))
        p.view(weeksAhead: 1)
        p.viewThisWeek()
        #expect(p.reminderTitles.filter { $0 == "Taxes expires tomorrow" }.count == 1)

        // Finished this week: a carry-over that's done doesn't come along, so no reminder.
        p.store.toggleTask(categoryID: admin, taskID: taxes)
        #expect(!p.reminderTitles.contains("Taxes expires tomorrow"), "done: no reminder")
        p.view(weeksAhead: 1)
        #expect(p.task("Admin", "Taxes") == nil, "next week's copy left with it")
        p.viewThisWeek()
        #expect(!p.reminderTitles.contains("Taxes expires tomorrow"))
        p.store.toggleTask(categoryID: admin, taskID: taxes)
        p.view(weeksAhead: 1)
        #expect(p.task("Admin", "Taxes") != nil, "unchecked, it carries again")
        checkInvariants(p, "completed and back", reload: false)

        // She deletes next week's copy: no reminder for a task that won't be there.
        p.store.deleteTask(categoryID: p.cardID("Admin"), taskID: p.task("Admin", "Taxes")!.id)
        #expect(!p.reminderTitles.contains("Taxes expires tomorrow"), "deleted from the week its last day is in")
        p.viewThisWeek()
        // Picking its mode brings it back, and the reminder with it.
        p.store.updateTaskMode(categoryID: admin, taskID: taxes, mode: .carryOver)
        p.view(weeksAhead: 1)
        #expect(p.task("Admin", "Taxes") != nil, "brought back")
        p.viewThisWeek()
        #expect(p.reminderTitles.filter { $0 == "Taxes expires tomorrow" }.count == 1)
        checkInvariants(p, "deleted and back")

        // The repeating Gym bag: checked this week it still comes back; checked in the week
        // its reminder falls in, none.
        p.store.toggleTask(categoryID: admin, taskID: bag)
        #expect(p.reminderTitles.contains("Gym bag expires tomorrow"))
        p.view(weeksAhead: 1)
        p.store.toggleTask(categoryID: p.cardID("Admin"), taskID: p.task("Admin", "Gym bag")!.id)
        #expect(!p.reminderTitles.contains("Gym bag expires tomorrow"))
        p.viewThisWeek()

        // Two "Call accountant" tasks with the same date (a duplicate): one checked, the other
        // still needs its reminder.
        let call2 = p.add("Call accountant", to: "Admin", mode: .oneTime)
        p.store.setTaskDate(categoryID: admin, taskID: call2, lastDay: day(3, 6))
        #expect(p.card("Admin")!.duplicateTaskIDs == [call, call2])
        #expect(p.reminderTitles.filter { $0 == "Call accountant expires tomorrow" }.count == 1)
        p.store.toggleTask(categoryID: admin, taskID: call)
        #expect(p.reminderTitles.contains("Call accountant expires tomorrow"), "the unchecked one still has its reminder")
        checkInvariants(p, "duplicates")
    }

    // MARK: 5. Day boundaries

    @Test("Day boundaries: dated today, the day passes; a whole week; the ring")
    func dayBoundaries() throws {
        let p = Priya(TestClock(2099, 3, 4))  // Wednesday noon, New York
        let today = p.addCard("Today")
        let timesheet = p.add("Submit timesheet", to: "Today", mode: .oneTime)
        p.store.setTaskDate(categoryID: today, taskID: timesheet, lastDay: day(3, 4))
        let bib = p.add("Pick up bib", to: "Today")
        p.store.setTaskDate(categoryID: today, taskID: bib, lastDay: day(3, 6))
        let stretch = p.add("Stretch", to: "Today", mode: .repeating)
        p.store.toggleTask(categoryID: today, taskID: stretch)
        let prep = p.add("Race week prep", to: "Today")
        p.store.setTaskDate(categoryID: today, taskID: prep, lastDay: day(3, 8), wholeWeek: true)

        let sheet = try #require(p.task("Today", id: timesheet))
        #expect(sheet.dayOfWeek == 4 && sheet.mode == .oneTime, "today's date is its day")
        #expect(sheet.expiryProgress(on: p.store.currentDay) == 1, "set on its last day: full")
        #expect(p.task("Today", id: bib)?.expiryProgress(on: p.store.currentDay) == 1.0 / 3)
        #expect(p.task("Today", id: prep)?.dayOfWeek == nil && p.task("Today", id: prep)?.expiresWithWeek == true)
        #expect(near(p.card("Today")!.doneFraction, 1.0 / 4))
        #expect(!p.reminderTitles.contains("Submit timesheet expires tomorrow"), "its reminder time has passed")
        #expect(p.reminderTitles == ["Pick up bib expires tomorrow", "Race week prep expires tomorrow"])
        p.view(weeksAhead: 1)
        #expect(p.titles("Today") == ["Stretch"], "nothing dated this week comes along")
        p.viewThisWeek()
        checkInvariants(p, "Wednesday")

        // Thursday: the timesheet is gone; the bib's ring fills.
        p.store.toggleTask(categoryID: today, taskID: timesheet)
        p.advance(days: 1)
        #expect(p.titles("Today") == ["Pick up bib", "Stretch", "Race week prep"])
        #expect(p.task("Today", id: bib)?.expiryProgress(on: p.store.currentDay) == 2.0 / 3)
        #expect(near(p.card("Today")!.doneFraction, 1.0 / 3))
        checkInvariants(p, "Thursday")

        // Sunday, the week's last day: prep is still there; Monday it's gone, last week keeps it.
        p.advance(days: 3)
        #expect(p.task("Today", "Race week prep") != nil)
        p.advance(days: 1)
        #expect(p.titles("Today") == ["Stretch"])
        #expect(p.task("Today", "Stretch")?.isCompleted == false)
        let lastWeek = try #require(p.saved(day(3, 2)))
        #expect(lastWeek.categories.first { $0.name == "Today" }!.tasks.map(\.title)
                == ["Submit timesheet", "Pick up bib", "Stretch", "Race week prep"], "history")
        checkInvariants(p, "next Monday")
    }

    @Test("Day boundaries in another time zone: a date for today, then flying east past midnight")
    func timeZones() throws {
        let p = Priya(TestClock(2099, 3, 4, hour: 20, timeZone: "America/Los_Angeles"))  // Wed 8 PM
        let card = p.addCard("Today")
        let sheet = p.add("Submit timesheet", to: "Today", mode: .oneTime)
        p.store.setTaskDate(categoryID: card, taskID: sheet, lastDay: p.store.currentDay)
        #expect(p.store.currentDay == day(3, 4))
        let gift = p.add("Mail race medal", to: "Today")
        p.store.setTaskDate(categoryID: card, taskID: gift, lastDay: day(3, 6))
        #expect(p.store.expiryReminders.map(\.day) == [day(3, 5)])
        let reminderBefore = p.store.expiryReminders.first!
        checkInvariants(p, "Los Angeles")

        // To Tokyo: the same moment is Thursday 1 PM there; the timesheet's day is over.
        p.clock.calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        p.store.navigateToDate(p.clock.now)
        #expect(p.store.currentDay == day(3, 5))
        #expect(p.titles("Today") == ["Mail race medal"])
        // 9 AM Thursday has passed in Tokyo: the reminder 13 hours away in Los Angeles is gone.
        #expect(p.store.expiryReminders.isEmpty, "\(p.store.expiryReminders) (was \(reminderBefore))")
        checkInvariants(p, "Tokyo")
    }

    // MARK: - Minimal repros

    /// Next week saved with an untouched copy of a dated carry-over task.
    private func adminWithSavedNextWeek() -> (Priya, UUID, UUID) {
        let p = Priya(TestClock(2099, 3, 4))
        let admin = p.addCard("Admin")
        let taxes = p.add("Tax forms", to: "Admin")
        p.store.setTaskDate(categoryID: admin, taskID: taxes, lastDay: day(3, 11))
        p.view(weeksAhead: 1)
        p.add("Note", to: "Admin", mode: .oneTime)
        p.viewThisWeek()
        return (p, admin, taxes)
    }

    @Test("Repro: renaming a dated task this week leaves a second reminder under the old name")
    func reproReminderAfterRename() {
        let (p, admin, taxes) = adminWithSavedNextWeek()
        p.store.renameTask(categoryID: admin, taskID: taxes, newTitle: "Taxes")
        #expect(p.reminderTitles == ["Taxes expires tomorrow"])
    }

    @Test("Repro: a later week's renamed copy gets its own reminder: two for one task")
    func reproReminderForRenamedCopy() {
        let (p, _, _) = adminWithSavedNextWeek()
        p.view(weeksAhead: 1)
        p.store.renameTask(categoryID: p.cardID("Admin"), taskID: p.task("Admin", "Tax forms")!.id, newTitle: "Tax forms (final)")
        #expect(p.reminderTitles.count == 1, "\(p.reminderTitles)")
    }

    @Test("Repro: removing a task's date this week keeps its reminder")
    func reproReminderAfterDateRemoved() {
        let (p, admin, taxes) = adminWithSavedNextWeek()
        p.store.setTaskDate(categoryID: admin, taskID: taxes, lastDay: nil)
        #expect(p.reminderTitles.isEmpty)
    }

    @Test("Repro: finishing a dated carry-over task this week keeps its reminder")
    func reproReminderAfterCompleted() {
        let (p, admin, taxes) = adminWithSavedNextWeek()
        p.store.toggleTask(categoryID: admin, taskID: taxes)
        #expect(p.reminderTitles.isEmpty)
    }

    @Test("Repro: deleting the copy from the week its last day is in keeps the reminder")
    func reproReminderAfterCopyDeleted() {
        let (p, _, _) = adminWithSavedNextWeek()
        p.view(weeksAhead: 1)
        p.store.deleteTask(categoryID: p.cardID("Admin"), taskID: p.task("Admin", "Tax forms")!.id)
        #expect(p.reminderTitles.isEmpty)
    }

    @Test("Repro: two same-named tasks with one date: checking the first takes the other's reminder")
    func reproReminderLostForDuplicate() {
        let p = Priya(TestClock(2099, 3, 4))
        let admin = p.addCard("Admin")
        let first = p.add("Call accountant", to: "Admin", mode: .oneTime)
        let second = p.add("Call accountant", to: "Admin", mode: .oneTime)
        p.store.setTaskDate(categoryID: admin, taskID: first, lastDay: day(3, 6))
        p.store.setTaskDate(categoryID: admin, taskID: second, lastDay: day(3, 6))
        p.store.toggleTask(categoryID: admin, taskID: first)
        #expect(p.reminderTitles == ["Call accountant expires tomorrow"])
    }

    @Test("Repro: dating a task past its week in a This week only card turns the card's switch off")
    func reproDatingTurnsThisWeekOnlyOff() {
        let p = Priya(TestClock(2099, 3, 4))
        let client = p.addCard("Client X", thisWeekOnly: true)
        let delivery = p.add("Final delivery", to: "Client X", mode: .oneTime)
        p.store.setTaskDate(categoryID: client, taskID: delivery, lastDay: day(3, 18))
        #expect(p.card("Client X")?.isThisWeekOnly == true)
        p.view(weeksAhead: 1)
        #expect(p.card("Client X") == nil, "a This week only card isn't in next week")
    }

    @Test("Repro: a day set by a date stays when the date moves to a later week, and shows late")
    func reproDayFromDateStays() {
        let p = Priya(TestClock(2099, 3, 4))
        let client = p.addCard("Client X")
        let invoice = p.add("Send invoice", to: "Client X", mode: .oneTime)
        p.store.setTaskDate(categoryID: client, taskID: invoice, lastDay: day(3, 5))  // Thursday: its day
        p.store.setTaskDate(categoryID: client, taskID: invoice, lastDay: day(3, 11))  // moved to next Wednesday
        #expect(p.task("Client X", id: invoice)?.dayOfWeek == nil, "Thursday was only the old date's day")
        p.advance(days: 1)  // Thursday
        p.advance(days: 1)  // Friday
        let task = p.task("Client X", id: invoice)
        #expect(task?.isLate(inWeekStarting: p.week.startDay, firstWeekday: p.store.firstWeekday, today: p.store.currentDay) == false,
                "not late for a day it no longer has")
        p.view(weeksAhead: 1)
        #expect(p.task("Client X", "Send invoice")?.dayOfWeek == nil, "next week's copy shows under Thursday, after its last day")
    }

    @Test("Repro: a whole-week date runs a day into the next week after the week start changes")
    func reproWholeWeekAfterWeekStartChange() {
        let p = Priya(TestClock(2099, 3, 4))  // Wednesday, Monday weeks
        let card = p.addCard("Today")
        let prep = p.add("Race week prep", to: "Today")
        p.store.setTaskDate(categoryID: card, taskID: prep, lastDay: day(3, 8), wholeWeek: true)  // this week
        p.store.setWeekStartsOnSunday(true)  // this week is now Sun 3/1 – Sat 3/7
        p.view(weeksAhead: 1)                // Sun 3/8 – Sat 3/14
        #expect(p.task("Today", "Race week prep") == nil, "picked as this week: not in next week")
    }

    @Test("Repro: in a later week, a typed date before that week is taken as next year's")
    func reproTypedDateInLaterWeek() throws {
        let calendar = Calendar.weekDates()
        let today = DayKey(Date(), in: calendar)
        // Looking at a week three weeks ahead: Smart Add's earliest is that week's first day.
        let weekStart = today.adding(days: 21)
        let written = calendar.date(byAdding: .day, value: 14, to: Date())!  // a date before that week, this year
        let parts = calendar.dateComponents([.month, .day], from: written)
        let found = TypedDate.find(in: "Long run \(parts.month!)/\(parts.day!)", earliest: weekStart, calendar: calendar,
                                   locale: Locale(identifier: "en_US"))
        #expect(found == nil || found!.day.adding(days: 0).year == DayKey(written, in: calendar).year,
                "a date two weeks from now isn't a year away: \(String(describing: found?.day))")
    }

    @Test("Repro: a dated task checked and gone the next day is missing from that week's history")
    func reproHistoryLostDayByDay() {
        func lastWeekTitles(openedThursday: Bool) -> [String] {
            let p = Priya(TestClock(2099, 3, 4))  // Wednesday
            let card = p.addCard("Today")
            let sheet = p.add("Submit timesheet", to: "Today", mode: .oneTime)
            p.store.setTaskDate(categoryID: card, taskID: sheet, lastDay: day(3, 4))
            p.store.toggleTask(categoryID: card, taskID: sheet)
            if openedThursday { p.advance(days: 1) }
            p.clock.now = p.clock.calendar.date(byAdding: .day, value: openedThursday ? 4 : 5, to: p.clock.now)!  // Monday
            p.store.navigateToDate(p.clock.weeks(-1, from: p.clock.now))  // last week, view only
            return p.titles("Today")
        }
        #expect(lastWeekTitles(openedThursday: false) == ["Submit timesheet"], "the app not opened Thursday")
        #expect(lastWeekTitles(openedThursday: true) == ["Submit timesheet"], "the app opened Thursday: the same week's history")
    }

    @Test("Repro: a date set this week doesn't reach the weeks after a saved next week until it's opened")
    func reproStalePreviewPastSavedWeek() {
        let p = Priya(TestClock(2099, 3, 4))
        let training = p.addCard("Training")
        let run = p.add("Run", to: "Training", mode: .repeating)
        p.view(weeksAhead: 1)
        p.add("Stretch", to: "Training", mode: .oneTime)  // next week saved
        p.viewThisWeek()
        p.store.setTaskDate(categoryID: training, taskID: run, lastDay: day(3, 15))  // Sunday of next week
        p.store.navigateToDate(p.clock.weeks(3, from: p.clock.now))  // Go to Week, three weeks ahead
        #expect(p.task("Training", "Run") == nil, "Run never repeats past its last day")
    }

    @Test("Repro: Undo of a delete just before midnight brings back a task that expired at midnight")
    func reproUndoAfterMidnight() {
        let p = Priya(TestClock(2099, 3, 4, hour: 23))  // Wednesday 11 PM
        let card = p.addCard("Today")
        let sheet = p.add("Submit timesheet", to: "Today", mode: .oneTime)
        p.store.setTaskDate(categoryID: card, taskID: sheet, lastDay: day(3, 4))
        let note = p.add("Old note", to: "Today", mode: .oneTime)
        p.clock.now = p.clock.calendar.date(byAdding: .minute, value: 59, to: p.clock.now)!  // 11:59 PM
        p.store.deleteTask(categoryID: card, taskID: note)
        p.clock.now = p.clock.calendar.date(byAdding: .minute, value: 2, to: p.clock.now)!  // 12:01 AM Thursday
        p.store.navigateToDate(p.clock.now)
        #expect(p.titles("Today").isEmpty && p.store.lastDelete != nil)
        p.store.undoLastDelete()
        #expect(p.titles("Today") == ["Old note"], "the expired timesheet stays gone")
        checkInvariants(p, "after Undo", reload: false)
    }

    @Test("Smart Add's Set Date on a real-date week: the date's rules, the name without the date, one reminder")
    func smartAddSetDate() async throws {
        let calendar = Calendar.weekDates(in: TimeZone(identifier: "America/New_York")!)
        let parts = calendar.dateComponents([.year, .month, .day], from: Date())
        let p = Priya(TestClock(parts.year!, parts.month!, parts.day!))
        let training = p.addCard("Training")
        // What finishSmartAdd adds for "Long run Dec 3": the words' task, the date still in its name.
        let text = "Long run Dec 3"
        let found = try #require(TypedDate.find(in: text, earliest: p.store.earliestExpiry, calendar: p.store.calendar,
                                                 locale: Locale(identifier: "en_US")))
        let parsed = try await AppleIntelligenceTaskParser.parse(found.titleWithoutDate) { ParsedTask(title: $0) }
        var added = parsed
        added.title = parsed.title == found.titleWithoutDate ? text : "\(parsed.title) \(found.phrase)"
        let id = try #require(p.store.addParsedTask(added, categoryID: training))
        #expect(p.task("Training", id: id)?.title == "Long run Dec 3" && p.task("Training", id: id)?.mode == .oneTime)
        // Set Date: setTaskDate, then the name without the date (TaskRowCard setTypedDate).
        p.store.setTaskDate(categoryID: training, taskID: id, lastDay: found.day)
        p.store.renameTask(categoryID: training, taskID: id, newTitle: found.titleWithoutDate)
        let task = try #require(p.task("Training", id: id))
        #expect(task.title == "Long run" && task.expiresOn == found.day)
        let laterWeek = found.day > p.week.startDay.adding(days: 6)
        #expect(task.mode == (laterWeek ? .carryOver : .oneTime))
        #expect(p.reminderTitles.filter { $0.hasPrefix("Long run") }.count <= 1)
        checkInvariants(p, "Set Date")
    }

    @Test("Repro: “until 12/15” is offered as today, not December 15", arguments: [
        "Run 3x per week until 12/15", "Run until Dec 15", "Taper until December 15th", "Invoice due 12/15", "Taxes by 12/15",
    ])
    func reproUntilDateIsToday(_ text: String) {
        let calendar = Calendar.weekDates()
        let today = DayKey(Date(), in: calendar)
        let found = TypedDate.find(in: text, earliest: today, calendar: calendar, locale: Locale(identifier: "en_US"))
        #expect(found?.day.month == 12 && found?.day.day == 15, "\(text): \(String(describing: found))")
    }

    @Test("Repro: a fraction of a mile is taken as a date")
    func reproFractionAsDate() {
        let calendar = Calendar.weekDates()
        let found = TypedDate.find(in: "Run 3/4 mile", earliest: DayKey(Date(), in: calendar), calendar: calendar,
                                   locale: Locale(identifier: "en_US"))
        #expect(found == nil, "offered: \(String(describing: found))")
    }
}
