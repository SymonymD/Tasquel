//
//  PersonaDanTests.swift
//  TasquelTests
//
//  Dan, a parent running the household, plays several weeks through the store (not the
//  UI) to find where Tasquel 1.1's additions disagree with each other or with older
//  features. Weeks start on Monday: today is Wednesday, March 4, 2099 (the week of Mar 2–8;
//  next week Mar 9–15, then Mar 16–22, Mar 23–29, Mar 30–Apr 5).
//
//  The five `goal…` tests are Dan's weeks; the `repro…` tests are the smallest cases of
//  what those weeks turned up.
//

import Testing
import Foundation
@testable import Tasquel

// MARK: - Dan's home (store, clock, files)

/// Dan's phone: a store on a throwaway directory and defaults suite, with a clock the test moves.
@MainActor
private final class DanHome {
    let clock = TestClock(2099, 3, 4)  // Wednesday, noon, New York
    let directory: URL
    let defaults: UserDefaults
    let store: ChecklistStore

    init() {
        directory = FileManager.default.temporaryDirectory.appending(path: "TasquelDan-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defaults = UserDefaults(suiteName: "TasquelDan-\(UUID().uuidString)")!
        let clock = clock
        store = ChecklistStore(directory: directory, defaults: defaults, now: { clock.now }, calendar: { clock.calendar })
    }

    /// The app opened again on the same files.
    func relaunched() -> ChecklistStore {
        let clock = clock
        return ChecklistStore(directory: directory, defaults: defaults, now: { clock.now }, calendar: { clock.calendar })
    }

    /// Noon on a day of March 2099 (or another month).
    func date(_ day: Int, month: Int = 3, hour: Int = 12) -> Date {
        clock.calendar.date(from: DateComponents(year: 2099, month: month, day: day, hour: hour))!
    }

    /// Views the week holding that day of March.
    func go(_ day: Int) { store.navigateToDate(date(day)) }

    /// Time passes to noon on that day; the app comes back to today (ContentView does on a new day).
    func advance(to day: Int, hour: Int = 12) {
        clock.now = date(day, hour: hour)
        store.navigateToDate(clock.now)
    }

    func card(_ name: String) -> Tasquel.Category? { store.selectedWeek?.categories.first { $0.name == name } }
    func cardID(_ name: String) -> UUID { card(name)!.id }
    func task(_ card: String, id: UUID) -> ChecklistTask? { self.card(card)?.tasks.first { $0.id == id } }
    func task(_ card: String, _ title: String) -> ChecklistTask? { self.card(card)?.tasks.first { $0.title == title } }
    func week(_ start: DayKey) -> Week? { store.weeks.first { $0.startDay == start } }
    func previewCard(_ name: String, weekOf day: Int, month: Int = 3) -> Tasquel.Category? {
        store.previewWeek(for: date(day, month: month)).categories.first { $0.name == name }
    }
    func reminderTitles() -> [String] { store.expiryReminders.map(\.title) }

    @discardableResult
    func add(_ card: String, _ title: String, _ mode: TaskMode = .carryOver, _ type: TaskType = .checkbox) -> UUID {
        store.addTask(categoryID: cardID(card), title: title, mode: mode, type: type)!
    }
}

/// A day of March 2099 (or another month).
private func d(_ day: Int, _ month: Int = 3) -> DayKey { DayKey(year: 2099, month: month, day: day) }

/// What must hold after every step: no two tasks (cards, items) share an ID in a week; at most
/// two pinned cards a week and two pinned tasks a card; nothing past its last day in the current
/// or a later week; each reminder listed once.
@MainActor
private func checkInvariants(_ home: DanHome, _ step: String, sourceLocation: SourceLocation = #_sourceLocation) {
    let store = home.store
    let today = store.currentDay
    var weeks = store.weeks
    if let viewed = store.selectedWeek, !weeks.contains(where: { $0.id == viewed.id }) { weeks.append(viewed) }
    for week in weeks {
        let taskIDs = week.categories.flatMap { $0.tasks.map(\.id) }
        #expect(Set(taskIDs).count == taskIDs.count, "\(step): two tasks share an ID in the week of \(week.startDay)",
                sourceLocation: sourceLocation)
        let categoryIDs = week.categories.map(\.id)
        #expect(Set(categoryIDs).count == categoryIDs.count, "\(step): two cards share an ID in the week of \(week.startDay)",
                sourceLocation: sourceLocation)
        for task in week.categories.flatMap(\.tasks) {
            let itemIDs = task.subtasks.map(\.id)
            #expect(Set(itemIDs).count == itemIDs.count, "\(step): two items of \(task.title) share an ID",
                    sourceLocation: sourceLocation)
        }
        let pinnedCards = week.categories.filter(\.isPinned).map(\.name)
        #expect(pinnedCards.count <= Tasquel.Category.maxPins,
                "\(step): \(pinnedCards.count) pinned cards in the week of \(week.startDay): \(pinnedCards)",
                sourceLocation: sourceLocation)
        for category in week.categories {
            let pinned = category.tasks.filter(\.isPinned).map(\.title)
            #expect(pinned.count <= Tasquel.Category.maxPins,
                    "\(step): \(pinned.count) pinned tasks in \(category.name), week of \(week.startDay): \(pinned)",
                    sourceLocation: sourceLocation)
        }
        guard !store.isPastWeek(week) else { continue }
        let cutoff = store.isCurrentWeek(week) ? max(week.startDay, today) : week.startDay
        for task in week.categories.flatMap(\.tasks) where task.isExpired(before: cutoff) {
            Issue.record("\(step): \(task.title) is past its last day (\(task.expiresOn!)) but still in the week of \(week.startDay)",
                         sourceLocation: sourceLocation)
        }
    }
    let ids = store.expiryReminders.map(\.id)
    #expect(Set(ids).count == ids.count, "\(step): a reminder is listed twice", sourceLocation: sourceLocation)
}

/// The data survives saving and opening the app again: the same weeks, reminders and sort.
@MainActor
private func checkSurvivesRelaunch(_ home: DanHome, _ step: String, sourceLocation: SourceLocation = #_sourceLocation) {
    let relaunched = home.relaunched()
    #expect(relaunched.persistenceError == nil, "\(step): couldn't load", sourceLocation: sourceLocation)
    let before = home.store.weeks, after = relaunched.weeks
    #expect(after.map(\.startDay) == before.map(\.startDay), "\(step): other weeks after relaunch", sourceLocation: sourceLocation)
    for (old, new) in zip(before, after) where old != new {
        Issue.record("\(step): the week of \(old.startDay) changed on relaunch", sourceLocation: sourceLocation)
    }
    #expect(relaunched.expiryReminders == home.store.expiryReminders, "\(step): other reminders after relaunch",
            sourceLocation: sourceLocation)
    #expect(relaunched.categorySort == home.store.categorySort, sourceLocation: sourceLocation)
}

// MARK: - Dan's weeks

@MainActor
struct PersonaDanTests {

    // MARK: Goal 1

    @Test("Goal 1: a repeating Groceries list: checks kept, Milk twice, folded, next week's copy renamed, items deleted, then a date")
    func goal1Groceries() throws {
        let home = DanHome()
        let store = home.store
        let errands = { home.cardID("Errands") }
        let list = home.add("Errands", "Groceries", .repeating, .list)
        for item in ["Milk", "Eggs", "Bread", "Apples"] { store.addSubtask(categoryID: errands(), taskID: list, title: item) }
        func source() -> ChecklistTask { home.task("Errands", id: list)! }
        func item(_ title: String) -> UUID { source().subtasks.first { $0.title == title }!.id }
        store.toggleSubtask(categoryID: errands(), taskID: list, subtaskID: item("Milk"))
        store.toggleSubtask(categoryID: errands(), taskID: list, subtaskID: item("Eggs"))
        #expect(home.card("Errands")!.doneFraction == 0.5, "the ring counts the list's 2 of 4 items")

        // "Milk" again: both are marked.
        store.addSubtask(categoryID: errands(), taskID: list, title: "Milk")
        let milks = source().subtasks.filter { $0.title == "Milk" }.map(\.id)
        #expect(milks.count == 2 && source().duplicateSubtaskIDs == Set(milks))
        store.setListFolded(categoryID: errands(), taskID: list, folded: true)
        #expect(source().isFolded)
        checkInvariants(home, "Groceries set up")
        checkSurvivesRelaunch(home, "Groceries set up")

        // Paging shows next week (the UI builds its preview), then he goes there.
        _ = store.previewWeek(for: home.date(11))
        home.go(11)
        let copy = try #require(home.card("Errands")?.tasks.first { $0.repeatsFrom == list })
        #expect(copy.subtasks.map(\.title) == ["Milk", "Eggs", "Bread", "Apples", "Milk"])
        #expect(copy.subtasks.map(\.isCompleted) == [true, true, false, false, false], "a repeating list keeps its checks")
        #expect(copy.isListFolded, "and its fold")
        #expect(copy.duplicateSubtaskIDs.count == 2, "its two Milks are marked too")
        store.renameTask(categoryID: errands(), taskID: copy.id, newTitle: "Groceries (Costco)")
        let renamed = try #require(home.task("Errands", id: copy.id))
        #expect(renamed.hasOwnTitle && !renamed.isUserEdited, "a rename changes only the name")
        checkInvariants(home, "next week's copy renamed")

        // This week: Bread and the extra Milk deleted from the list, Butter added.
        home.go(4)
        store.deleteSubtask(categoryID: errands(), taskID: list, subtaskID: item("Bread"))
        store.deleteSubtask(categoryID: errands(), taskID: list, subtaskID: source().subtasks.last { $0.title == "Milk" }!.id)
        store.addSubtask(categoryID: errands(), taskID: list, title: "Butter")
        #expect(source().subtasks.map(\.title) == ["Milk", "Eggs", "Apples", "Butter"])
        #expect(source().duplicateSubtaskIDs.isEmpty)

        home.go(11)
        let followed = try #require(home.task("Errands", id: copy.id))
        #expect(followed.title == "Groceries (Costco)", "keeps its own name")
        #expect(followed.subtasks.map(\.title) == ["Milk", "Eggs", "Apples", "Butter"],
                "follows everything else: Bread and the extra Milk gone, Butter added")
        #expect(followed.duplicateSubtaskIDs.isEmpty, "no Duplicate mark once the list has one Milk")
        #expect(followed.isListFolded)
        checkInvariants(home, "next week followed the list")

        // He dates the list: its last day Wednesday, Mar 25 (three weeks out). Still repeating.
        home.go(4)
        store.setTaskDate(categoryID: errands(), taskID: list, lastDay: d(25))
        #expect(source().mode == .repeating && source().dayOfWeek == nil && source().expiresOn == d(25))
        home.go(11)
        let dated = try #require(home.task("Errands", id: copy.id))
        #expect(dated.expiresOn == d(25), "the renamed copy takes the date")
        #expect(dated.title == "Groceries (Costco)")
        #expect(home.previewCard("Errands", weekOf: 25)?.tasks.contains { $0.expiresOn == d(25) } == true, "the week of its last day has it")
        #expect(home.previewCard("Errands", weekOf: 30)?.tasks.isEmpty == true, "the week after doesn't")
        // One list, one reminder: the day before its last day.
        #expect(store.expiryReminders.count == 1, "one reminder for one list, got \(home.reminderTitles())")
        #expect(store.expiryReminders.first?.day == d(24))
        checkInvariants(home, "list dated")
        checkSurvivesRelaunch(home, "list dated")
    }

    // MARK: Goal 2

    @Test("Goal 2: birthdays: a date three weeks out, one this week, the clock changing and removing them, a whole week")
    func goal2Birthdays() throws {
        let home = DanHome()
        let store = home.store
        store.addCategory(name: "Family", symbol: "person.2")
        let family = { home.cardID("Family") }
        let mom = home.add("Family", "Mom's birthday", .oneTime)
        let bakery = home.add("Family", "Call the bakery", .oneTime)
        func t(_ id: UUID) -> ChecklistTask? { home.task("Family", id: id) }
        func momReminders() -> [ExpiryReminder] { store.expiryReminders.filter { $0.title.hasPrefix("Mom") } }

        // Mom's birthday is Wednesday, Mar 25; the bakery is to be called this Friday.
        store.setTaskDate(categoryID: family(), taskID: mom, lastDay: d(25))
        #expect(t(mom)?.mode == .carryOver, "a one-time task dated after its week carries over")
        #expect(t(mom)?.dayOfWeek == nil && t(mom)?.expiresOn == d(25) && t(mom)?.expirySetOn == d(4))
        store.setTaskDate(categoryID: family(), taskID: bakery, lastDay: d(6))
        #expect(t(bakery)?.mode == .oneTime)
        #expect(t(bakery)?.dayOfWeek == 6, "a date in its week is its day: Friday")
        #expect(Set(home.reminderTitles()) == ["Mom's birthday expires tomorrow", "Call the bakery expires tomorrow"])
        #expect(Set(store.expiryReminders.map(\.day)) == [d(24), d(5)])
        checkInvariants(home, "dates set")
        checkSurvivesRelaunch(home, "dates set")

        // Next week is saved (he adds Wrap the gift there): the birthday is in it, the bakery isn't.
        home.go(11)
        home.add("Family", "Wrap the gift", .oneTime)
        let momCopy = try #require(home.card("Family")?.tasks.first { $0.carriedFrom == mom })
        #expect(momCopy.expiresOn == d(25) && momCopy.dayOfWeek == nil)
        #expect(home.task("Family", "Call the bakery") == nil)
        #expect(home.previewCard("Family", weekOf: 23)?.tasks.contains { $0.title == "Mom's birthday" } == true)
        #expect(home.previewCard("Family", weekOf: 30)?.tasks.contains { $0.title == "Mom's birthday" } == false)
        #expect(momReminders().count == 1, "one reminder however many weeks have a copy")
        checkInvariants(home, "next week saved")

        // The edit-mode clock: the bakery moves to Thursday, then to next Wednesday, Mar 11.
        home.go(4)
        store.setTaskDate(categoryID: family(), taskID: bakery, lastDay: d(5))
        #expect(t(bakery)?.dayOfWeek == 5, "Thursday now")
        store.setTaskDate(categoryID: family(), taskID: bakery, lastDay: d(11))
        #expect(t(bakery)?.mode == .carryOver, "dated after its week: carries over until then")
        home.go(11)
        let bakeryCopy = try #require(home.card("Family")?.tasks.first { $0.carriedFrom == bakery })
        #expect(bakeryCopy.expiresOn == d(11))
        let wednesday = home.card("Family")!.shownTasks(firstWeekday: store.firstWeekday, day: 4).map(\.title)
        #expect(wednesday.contains("Call the bakery"), "on its last day, Wednesday's filter shows it; got \(wednesday)")
        if let day = bakeryCopy.day(inWeekStarting: d(9), firstWeekday: store.firstWeekday) {
            #expect(day <= d(11), "its day (\(day)) comes after its last day (Mar 11)")
        }
        checkInvariants(home, "bakery moved to next week")

        // Mom's birthday moves to Thursday the 26th: one reminder, on the 25th.
        home.go(4)
        store.setTaskDate(categoryID: family(), taskID: mom, lastDay: d(26))
        #expect(momReminders().map(\.day) == [d(25)], "only the new date is reminded; got \(momReminders().map(\.day))")

        // Removing the bakery's date takes only the date (the spec): it stays Carry Over and Thursday.
        store.setTaskDate(categoryID: family(), taskID: bakery, lastDay: nil)
        #expect(t(bakery)?.expiresOn == nil && t(bakery)?.expirySetOn == nil && t(bakery)?.expiresWithWeek == false)
        #expect(t(bakery)?.mode == .carryOver, "no date changes only the date")
        #expect(t(bakery)?.dayOfWeek == 5)

        // A whole week for Mom: the week of Mar 16 (its last day Sunday the 22nd).
        store.setTaskDate(categoryID: family(), taskID: mom, lastDay: d(22), wholeWeek: true)
        #expect(t(mom)?.expiresWithWeek == true && t(mom)?.dayOfWeek == nil && t(mom)?.mode == .carryOver)
        home.go(11)
        #expect(home.card("Family")?.tasks.first { $0.carriedFrom == mom }?.expiresOn == d(22))
        #expect(home.card("Family")?.tasks.first { $0.carriedFrom == mom }?.expiresWithWeek == true)
        #expect(home.previewCard("Family", weekOf: 16)?.tasks.contains { $0.title == "Mom's birthday" && $0.expiresWithWeek } == true)
        #expect(home.previewCard("Family", weekOf: 23)?.tasks.contains { $0.title == "Mom's birthday" } == false)
        home.go(4)
        #expect(momReminders().map(\.day) == [d(21)])
        checkInvariants(home, "whole-week date")
        checkSurvivesRelaunch(home, "whole-week date")

        // He calls Mom early and checks it off: nothing is left to remind him of.
        store.toggleTask(categoryID: family(), taskID: mom)
        #expect(momReminders().isEmpty, "a finished carry-over isn't reminded; got \(momReminders().map(\.title))")
        store.toggleTask(categoryID: family(), taskID: mom)  // a mis-tap: unchecked again

        // The weeks go by: it's there through Sunday the 22nd and gone on Monday the 23rd.
        home.advance(to: 9)
        #expect(home.task("Family", "Mom's birthday") != nil)
        home.advance(to: 22)
        #expect(home.task("Family", "Mom's birthday") != nil, "there on its last day")
        #expect(momReminders().isEmpty, "the reminder's time has passed")
        home.advance(to: 23)
        #expect(home.task("Family", "Mom's birthday") == nil, "gone the day after its last day")
        checkInvariants(home, "weeks gone by")
        checkSurvivesRelaunch(home, "weeks gone by")
    }

    // MARK: Goal 3

    @Test("Goal 3: pins on Errands with the card sort on recently edited: a third refused, a date, an expiry, a delete and Undo")
    func goal3Pins() throws {
        let home = DanHome()
        let store = home.store
        store.setCategorySort(.recentFirst)
        let errands = { home.cardID("Errands") }
        store.setCategoryPinned(categoryID: errands(), pinned: true)
        let groceries = home.add("Errands", "Groceries", .repeating, .list)
        let dry = home.add("Errands", "Dry cleaning")
        let library = home.add("Errands", "Return library books")
        let gifts = home.add("Errands", "Gifts")
        func t(_ id: UUID) -> ChecklistTask? { home.task("Errands", id: id) }
        func pinned() -> [String] { home.card("Errands")?.tasks.filter(\.isPinned).map(\.title) ?? [] }

        let times = store.categoryEditTimes
        store.setTaskPinned(categoryID: errands(), taskID: groceries, pinned: true)
        store.setTaskPinned(categoryID: errands(), taskID: gifts, pinned: true)
        store.setTaskPinned(categoryID: errands(), taskID: dry, pinned: true)
        #expect(pinned() == ["Groceries", "Gifts"], "a third pin is refused")
        #expect(store.categoryEditTimes == times, "pins aren't edits: the card sort doesn't move")
        #expect(home.card("Errands")!.orderedTasks(firstWeekday: store.firstWeekday).map(\.title)
                == ["Groceries", "Gifts", "Dry cleaning", "Return library books"])
        home.clock.now = home.clock.now.addingTimeInterval(60)  // a minute later (same timestamps tie)
        home.add("Work", "Expense report", .oneTime)
        #expect(store.sortedCategories(store.selectedWeek!.categories).first?.name == "Work", "Work was edited last")
        #expect(home.card("Errands")!.isPinned, "Errands stays pinned (the grid puts it first whatever the sort)")
        checkInvariants(home, "pins set")
        checkSurvivesRelaunch(home, "pins set")

        // Gifts gets a date this Friday: still pinned, Friday its day; it's an edit for the sort.
        home.clock.now = home.clock.now.addingTimeInterval(60)
        store.setTaskDate(categoryID: errands(), taskID: gifts, lastDay: d(6))
        #expect(t(gifts)?.isPinned == true && t(gifts)?.dayOfWeek == 6)
        #expect(store.sortedCategories(store.selectedWeek!.categories).first?.name == "Errands")

        // Next week: Errands and Groceries pinned, no Gifts (its last day is this week). He pins
        // Dry cleaning there, and the Work card.
        home.go(11)
        #expect(home.card("Errands")?.isPinned == true)
        #expect(pinned() == ["Groceries"])
        let dryCopy = try #require(home.card("Errands")?.tasks.first { $0.carriedFrom == dry })
        store.setTaskPinned(categoryID: errands(), taskID: dryCopy.id, pinned: true)
        store.setCategoryPinned(categoryID: home.cardID("Work"), pinned: true)
        #expect(pinned() == ["Groceries", "Dry cleaning"])
        checkInvariants(home, "next week's pins")

        // This week he adds a School card and pins it (Errands and School).
        home.go(4)
        store.addCategory(name: "School", symbol: "book")
        store.setCategoryPinned(categoryID: home.cardID("School"), pinned: true)
        home.go(11)
        checkInvariants(home, "School pinned this week, next week synced")

        // Saturday: Gifts is gone, a pin is free; he pins a new repeating Pharmacy run.
        home.advance(to: 7)
        #expect(t(gifts) == nil, "gone the day after its last day")
        #expect(pinned() == ["Groceries"])
        let pharmacy = home.add("Errands", "Pharmacy", .repeating)
        store.setTaskPinned(categoryID: errands(), taskID: pharmacy, pinned: true)
        #expect(pinned() == ["Groceries", "Pharmacy"])
        home.go(11)
        checkInvariants(home, "Pharmacy pinned this week, next week synced")

        // He deletes the pinned Groceries and, while Undo is up, pins Return library books; then Undo.
        home.go(7)
        store.deleteTask(categoryID: errands(), taskID: groceries)
        #expect(pinned() == ["Pharmacy"])
        store.setTaskPinned(categoryID: errands(), taskID: library, pinned: true)
        #expect(store.lastDelete != nil, "a pin keeps the Undo")
        store.undoLastDelete()
        #expect(t(groceries)?.isPinned == true, "Groceries is back, pinned")
        #expect(pinned().count <= 2, "Undo leaves at most two pins; got \(pinned())")
        checkInvariants(home, "after Undo")
        checkSurvivesRelaunch(home, "after Undo")
    }

    // MARK: Goal 4

    @Test("Goal 4: chores: Mow the lawn on Saturday goes late, is filtered, checked late, changes mode, a copy deleted and brought back, dated")
    func goal4Chores() throws {
        let home = DanHome()
        let store = home.store
        store.addCategory(name: "Chores", symbol: "house")
        let chores = { home.cardID("Chores") }
        let mow = home.add("Chores", "Mow the lawn")
        home.add("Chores", "Fix the gate", .oneTime)
        store.setTaskDay(categoryID: chores(), taskID: mow, day: 7)  // Saturday
        func t(_ id: UUID) -> ChecklistTask? { home.task("Chores", id: id) }
        func late(_ task: ChecklistTask) -> Bool {
            task.isLate(inWeekStarting: store.selectedWeek!.startDay, firstWeekday: store.firstWeekday, today: store.currentDay)
        }
        func shown(_ day: Int) -> [String] { home.card("Chores")!.shownTasks(firstWeekday: store.firstWeekday, day: day).map(\.title) }
        func copy() -> ChecklistTask? { home.card("Chores")?.tasks.first { $0.repeatsFrom == mow || $0.carriedFrom == mow } }

        #expect(!late(t(mow)!))
        #expect(shown(7) == ["Mow the lawn", "Fix the gate"], "Saturday: its tasks first, then those with no day")
        #expect(shown(4) == ["Fix the gate"])
        #expect(home.previewCard("Chores", weekOf: 11)?.tasks.first { $0.carriedFrom == mow }?.dayOfWeek == 7, "the copy keeps Saturday")

        // Sunday: Saturday went by unfinished.
        home.advance(to: 8)
        #expect(late(t(mow)!), "late")
        store.toggleTask(categoryID: chores(), taskID: mow)
        #expect(!late(t(mow)!), "checked off late: not late any more")
        #expect(home.previewCard("Chores", weekOf: 11)?.tasks.contains { $0.carriedFrom == mow } == false, "a finished carry-over doesn't carry")

        // Carry-over → repeating: next week gets it back, unchecked, still Saturday, not late.
        store.updateTaskMode(categoryID: chores(), taskID: mow, mode: .repeating)
        home.go(11)
        let repeating = try #require(copy())
        #expect(repeating.repeatsFrom == mow && repeating.dayOfWeek == 7 && !repeating.isCompleted && !late(repeating))
        home.add("Chores", "Clean the gutters", .oneTime)  // next week is saved
        checkInvariants(home, "repeating")

        // → one-time: next week's untouched copy leaves. → repeating again: it's back.
        home.go(8)
        store.updateTaskMode(categoryID: chores(), taskID: mow, mode: .oneTime)
        home.go(11)
        #expect(copy() == nil, "one-time: the copy leaves")
        home.go(8)
        store.updateTaskMode(categoryID: chores(), taskID: mow, mode: .repeating)
        home.go(11)
        let back = try #require(copy())
        #expect(back.dayOfWeek == 7)

        // He deletes next week's copy; it stays deleted...
        store.deleteTask(categoryID: chores(), taskID: back.id)
        #expect(home.week(d(9))?.dismissedCarryOvers?.contains(mow) == true)
        home.go(8)
        home.go(11)
        #expect(copy() == nil, "deleted stays deleted")
        // ...until he picks Repeating again (the mode it has).
        home.go(8)
        store.updateTaskMode(categoryID: chores(), taskID: mow, mode: .repeating)
        home.go(11)
        let returned = try #require(copy(), "picking the mode brings the copy back")
        #expect(returned.dayOfWeek == 7 && returned.expiresOn == nil && !returned.isUserEdited)
        checkInvariants(home, "copy brought back")
        checkSurvivesRelaunch(home, "copy brought back")

        // A date two weeks on, Saturday the 21st: still repeating, still Saturday; copies take it.
        home.go(8)
        store.setTaskDate(categoryID: chores(), taskID: mow, lastDay: d(21))
        #expect(t(mow)?.mode == .repeating && t(mow)?.dayOfWeek == 7)
        home.go(11)
        #expect(copy()?.expiresOn == d(21))
        #expect(home.previewCard("Chores", weekOf: 16)?.tasks.contains { $0.title == "Mow the lawn" } == true)
        #expect(home.previewCard("Chores", weekOf: 23)?.tasks.contains { $0.title == "Mow the lawn" } == false)
        #expect(store.expiryReminders.map(\.title) == ["Mow the lawn expires tomorrow"])
        #expect(store.expiryReminders.map(\.day) == [d(20)])

        // Then today, Sunday the 8th: its day becomes Sunday; next week's copy leaves.
        home.go(8)
        store.setTaskDate(categoryID: chores(), taskID: mow, lastDay: d(8))
        #expect(t(mow)?.dayOfWeek == 1, "a date in its week is its day")
        home.go(11)
        #expect(copy() == nil, "nothing repeats past its last day")
        #expect(store.expiryReminders.isEmpty)
        checkInvariants(home, "dated today")

        // Monday: next week is this week, after its final sync; no lawn.
        home.advance(to: 9)
        #expect(copy() == nil)
        #expect(home.task("Chores", "Clean the gutters") != nil)
        checkInvariants(home, "a new week")
        checkSurvivesRelaunch(home, "a new week")
    }

    // MARK: Goal 5

    @Test("Goal 5: Undo under pressure: a dated task deleted, a fold, a rename, a pin, a date change; a card deleted and undone")
    func goal5Undo() throws {
        let home = DanHome()
        let store = home.store
        store.addCategory(name: "Family", symbol: "person.2")
        let family = { home.cardID("Family") }
        let errands = { home.cardID("Errands") }
        let mom = home.add("Family", "Mom's birthday", .oneTime)
        let bakery = home.add("Family", "Call the bakery", .oneTime)
        store.setTaskDate(categoryID: family(), taskID: mom, lastDay: d(25))   // carries over until then
        store.setTaskDate(categoryID: family(), taskID: bakery, lastDay: d(6))  // Friday, its day
        let groceries = home.add("Errands", "Groceries", .repeating, .list)
        for item in ["Milk", "Eggs"] { store.addSubtask(categoryID: errands(), taskID: groceries, title: item) }
        home.go(11)
        home.add("Family", "Wrap the gift", .oneTime)  // next week is saved
        home.go(4)
        func t(_ id: UUID) -> ChecklistTask? { home.task("Family", id: id) }
        let momBefore = try #require(t(mom))

        // He deletes the birthday; while "Deleted … · Undo" is up he folds Groceries, renames the
        // bakery call and pins it. Then Undo.
        store.deleteTask(categoryID: family(), taskID: mom)
        #expect(store.lastDelete != nil)
        store.setListFolded(categoryID: errands(), taskID: groceries, folded: true)
        store.renameTask(categoryID: family(), taskID: bakery, newTitle: "Call the bakery about the cake")
        store.setTaskPinned(categoryID: family(), taskID: bakery, pinned: true)
        #expect(store.lastDelete != nil, "a fold, a rename and a pin keep the Undo")
        store.undoLastDelete()
        #expect(t(mom) == momBefore, "the birthday is back as it was: date, day set, mode, no day")
        #expect(t(mom)?.mode == .carryOver && t(mom)?.expiresOn == d(25) && t(mom)?.dayOfWeek == nil)
        let cake = try #require(t(bakery))
        #expect(cake.title == "Call the bakery about the cake" && cake.isPinned, "the rename and the pin stay")
        #expect(cake.dayOfWeek == 6 && cake.expiresOn == d(6) && cake.mode == .oneTime)
        #expect(home.task("Errands", id: groceries)?.isListFolded == true, "the fold stays")
        #expect(Set(home.reminderTitles()) == ["Mom's birthday expires tomorrow", "Call the bakery about the cake expires tomorrow"])
        home.go(11)
        #expect(home.card("Family")?.tasks.first { $0.carriedFrom == mom }?.expiresOn == d(25), "next week's copy is there")
        #expect(home.card("Errands")?.tasks.first { $0.repeatsFrom == groceries }?.isListFolded == true)
        home.go(4)
        checkInvariants(home, "after the first Undo")
        checkSurvivesRelaunch(home, "after the first Undo")

        // Deleted again, then the bakery's date changes: a date isn't one of the changes that
        // keep a delete's Undo (rename, fold, pin), so the Undo ends (the spec).
        store.deleteTask(categoryID: family(), taskID: mom)
        store.setTaskDate(categoryID: family(), taskID: bakery, lastDay: d(5))
        #expect(store.lastDelete == nil, "any other save ends the Undo")
        #expect(t(bakery)?.dayOfWeek == 5)
        store.undoLastDelete()
        #expect(t(mom) == nil, "nothing to undo")

        // The Family card deleted with Errands and Family pinned; Work pinned while Undo is up.
        store.setCategoryPinned(categoryID: errands(), pinned: true)
        store.setCategoryPinned(categoryID: family(), pinned: true)
        store.deleteCategory(family())
        #expect(home.card("Family") == nil)
        store.setCategoryPinned(categoryID: home.cardID("Work"), pinned: true)
        #expect(store.lastDelete != nil)
        store.undoLastDelete()
        let restored = try #require(home.card("Family"))
        #expect(restored.isPinned)
        #expect(restored.tasks.first { $0.id == bakery }?.expiresOn == d(5) && restored.tasks.first { $0.id == bakery }?.dayOfWeek == 5)
        let pinnedCards = store.selectedWeek!.categories.filter(\.isPinned).map(\.name)
        #expect(pinnedCards.count <= 2, "at most two pinned cards after Undo; got \(pinnedCards)")
        home.go(11)
        #expect(home.task("Family", "Wrap the gift") != nil, "next week's Family is back too")
        checkInvariants(home, "card delete undone")
        checkSurvivesRelaunch(home, "card delete undone")

        // A fold made in a later week while the Undo is up stays after Undo.
        home.go(4)
        let dry = home.add("Errands", "Dry cleaning", .oneTime)
        store.deleteTask(categoryID: errands(), taskID: dry)
        home.go(16)  // the week of Mar 16, not saved yet
        let later = try #require(home.card("Errands")?.tasks.first { $0.title == "Groceries" })
        #expect(later.isListFolded)
        store.setListFolded(categoryID: errands(), taskID: later.id, folded: false)
        #expect(store.lastDelete != nil)
        store.undoLastDelete()
        #expect(home.card("Errands")?.tasks.first { $0.title == "Groceries" }?.isListFolded == false,
                "the list he opened in that week stays open")
        checkInvariants(home, "later fold and Undo")
    }

    // MARK: - Repros

    /// Mom's birthday carries over to Mar 25; next week is saved; he checks it off this week.
    @Test("Repro: a reminder stays for a task checked off this week while a later saved week still has its copy")
    func reproReminderAfterCheckingOff() {
        let home = DanHome(), store = home.store
        store.addCategory(name: "Family", symbol: "person.2")
        let mom = home.add("Family", "Mom's birthday")
        store.setTaskDate(categoryID: home.cardID("Family"), taskID: mom, lastDay: d(25))
        home.go(11); home.add("Family", "Wrap the gift", .oneTime); home.go(4)
        store.toggleTask(categoryID: home.cardID("Family"), taskID: mom)
        #expect(store.expiryReminders.isEmpty, "finished: no reminder; got \(home.reminderTitles())")
        home.go(11)  // only visiting next week syncs it
        #expect(store.expiryReminders.isEmpty)
    }

    @Test("Repro: after a date change this week, a later saved week's copy is still reminded on the old date")
    func reproReminderOldDate() {
        let home = DanHome(), store = home.store
        store.addCategory(name: "Family", symbol: "person.2")
        let mom = home.add("Family", "Mom's birthday")
        store.setTaskDate(categoryID: home.cardID("Family"), taskID: mom, lastDay: d(25))
        home.go(11); home.add("Family", "Wrap the gift", .oneTime); home.go(4)
        store.setTaskDate(categoryID: home.cardID("Family"), taskID: mom, lastDay: d(26))
        #expect(store.expiryReminders.map(\.day) == [d(25)], "one reminder, for the new date; got \(store.expiryReminders.map(\.day))")
    }

    @Test("Repro: after renaming a task this week, a later saved week's copy is reminded under the old name too")
    func reproReminderOldName() {
        let home = DanHome(), store = home.store
        store.addCategory(name: "Family", symbol: "person.2")
        let mom = home.add("Family", "Mom's birthday")
        store.setTaskDate(categoryID: home.cardID("Family"), taskID: mom, lastDay: d(25))
        home.go(11); home.add("Family", "Wrap the gift", .oneTime); home.go(4)
        store.renameTask(categoryID: home.cardID("Family"), taskID: mom, newTitle: "Mom's 60th birthday")
        #expect(home.reminderTitles() == ["Mom's 60th birthday expires tomorrow"], "got \(home.reminderTitles())")
    }

    @Test("Repro: a later week's copy renamed (its own name) gets a second reminder for the same task")
    func reproRenamedCopyOwnReminder() throws {
        let home = DanHome(), store = home.store
        store.addCategory(name: "Family", symbol: "person.2")
        let mom = home.add("Family", "Mom's birthday")
        store.setTaskDate(categoryID: home.cardID("Family"), taskID: mom, lastDay: d(25))
        home.go(11)
        let copy = try #require(home.card("Family")?.tasks.first { $0.carriedFrom == mom })
        store.renameTask(categoryID: home.cardID("Family"), taskID: copy.id, newTitle: "Mom's birthday dinner")
        #expect(store.expiryReminders.count == 1, "one task, one reminder; got \(home.reminderTitles())")
    }

    @Test("Repro: two tasks with the same name and date share one reminder, and the first one checked silences the other")
    func reproDuplicatesShareReminder() {
        let home = DanHome(), store = home.store
        let first = home.add("Errands", "Gifts")
        let second = home.add("Errands", "Gifts")
        for id in [first, second] { store.setTaskDate(categoryID: home.cardID("Errands"), taskID: id, lastDay: d(6)) }
        #expect(home.card("Errands")!.duplicateTaskIDs == [first, second])
        store.toggleTask(categoryID: home.cardID("Errands"), taskID: first)
        #expect(home.reminderTitles() == ["Gifts expires tomorrow"], "the second Gifts is still to do; got \(home.reminderTitles())")
    }

    @Test("Repro: pinned repeating tasks arriving by sync give a saved later week's card more than two pins")
    func reproSyncedTaskPinsOverTwo() {
        let home = DanHome(), store = home.store
        home.go(11)
        for title in ["Bank", "Post office"] {
            let id = home.add("Errands", title, .oneTime)
            store.setTaskPinned(categoryID: home.cardID("Errands"), taskID: id, pinned: true)
        }
        home.go(4)
        for title in ["Groceries", "Pharmacy"] {
            let id = home.add("Errands", title, .repeating)
            store.setTaskPinned(categoryID: home.cardID("Errands"), taskID: id, pinned: true)
        }
        home.go(11)
        let pinned = home.card("Errands")!.tasks.filter(\.isPinned).map(\.title)
        #expect(pinned.count <= 2, "got \(pinned)")
    }

    @Test("Repro: a pinned card added by sync gives a saved later week more than two pinned cards")
    func reproSyncedCardPinsOverTwo() {
        let home = DanHome(), store = home.store
        home.go(11)
        store.setCategoryPinned(categoryID: home.cardID("Work"), pinned: true)
        store.setCategoryPinned(categoryID: home.cardID("Fitness"), pinned: true)
        home.go(4)
        store.addCategory(name: "School", symbol: "book")
        store.setCategoryPinned(categoryID: home.cardID("School"), pinned: true)
        home.go(11)
        let pinned = store.selectedWeek!.categories.filter(\.isPinned).map(\.name)
        #expect(pinned.count <= 2, "got \(pinned)")
    }

    @Test("Repro: a task pinned while a delete's Undo is up leaves three pinned tasks after Undo")
    func reproUndoThreeTaskPins() {
        let home = DanHome(), store = home.store
        let a = home.add("Errands", "Groceries"), b = home.add("Errands", "Pharmacy"), c = home.add("Errands", "Bank")
        store.setTaskPinned(categoryID: home.cardID("Errands"), taskID: a, pinned: true)
        store.setTaskPinned(categoryID: home.cardID("Errands"), taskID: b, pinned: true)
        store.deleteTask(categoryID: home.cardID("Errands"), taskID: a)
        store.setTaskPinned(categoryID: home.cardID("Errands"), taskID: c, pinned: true)
        store.undoLastDelete()
        let pinned = home.card("Errands")!.tasks.filter(\.isPinned).map(\.title)
        #expect(pinned.count <= 2, "got \(pinned)")
    }

    @Test("Repro: a card pinned while a card delete's Undo is up leaves three pinned cards after Undo")
    func reproUndoThreeCardPins() {
        let home = DanHome(), store = home.store
        store.setCategoryPinned(categoryID: home.cardID("Errands"), pinned: true)
        store.setCategoryPinned(categoryID: home.cardID("Work"), pinned: true)
        store.deleteCategory(home.cardID("Errands"))
        store.setCategoryPinned(categoryID: home.cardID("Fitness"), pinned: true)
        store.undoLastDelete()
        let pinned = store.selectedWeek!.categories.filter(\.isPinned).map(\.name)
        #expect(pinned.count <= 2, "got \(pinned)")
    }

    @Test("Repro: a fold made in a not-yet-saved later week while a delete's Undo is up is lost by Undo")
    func reproUndoLosesLaterWeekFold() throws {
        let home = DanHome(), store = home.store
        let list = home.add("Errands", "Groceries", .repeating, .list)
        store.addSubtask(categoryID: home.cardID("Errands"), taskID: list, title: "Milk")
        let dry = home.add("Errands", "Dry cleaning", .oneTime)
        store.deleteTask(categoryID: home.cardID("Errands"), taskID: dry)
        home.go(11)  // a preview
        let copy = try #require(home.card("Errands")?.tasks.first { $0.repeatsFrom == list })
        store.setListFolded(categoryID: home.cardID("Errands"), taskID: copy.id, folded: true)
        #expect(store.lastDelete != nil)
        store.undoLastDelete()
        #expect(home.card("Errands")?.tasks.first { $0.title == "Groceries" }?.isListFolded == true,
                "a fold keeps the Undo and isn't undone by it")
    }

    @Test("Repro: moving a date from this week to a later week keeps the old date's day, after its last day")
    func reproRedatedTaskKeepsOldDay() throws {
        let home = DanHome(), store = home.store
        store.addCategory(name: "Family", symbol: "person.2")
        let bakery = home.add("Family", "Call the bakery", .oneTime)
        store.setTaskDate(categoryID: home.cardID("Family"), taskID: bakery, lastDay: d(5))   // Thursday
        store.setTaskDate(categoryID: home.cardID("Family"), taskID: bakery, lastDay: d(11))  // next Wednesday
        home.go(11)
        let copy = try #require(home.card("Family")?.tasks.first { $0.carriedFrom == bakery })
        let wednesday = home.card("Family")!.shownTasks(firstWeekday: store.firstWeekday, day: 4).map(\.title)
        #expect(wednesday.contains("Call the bakery"), "its last day's filter shows it; got \(wednesday)")
        #expect(copy.dayOfWeek == nil || copy.dayOfWeek == 4, "day \(String(describing: copy.dayOfWeek)) is after its last day")
    }

    @Test("Repro: after switching weeks to Sunday, a one-time task dated its week's Sunday is late and gone before its last day")
    func reproWeekStartMovesDatedTask() throws {
        let home = DanHome(), store = home.store
        store.addCategory(name: "Family", symbol: "person.2")
        let bakery = home.add("Family", "Call the bakery", .oneTime)
        store.setTaskDate(categoryID: home.cardID("Family"), taskID: bakery, lastDay: d(8))  // Sunday: its week's last day
        #expect(home.task("Family", id: bakery)?.dayOfWeek == 1 && home.task("Family", id: bakery)?.mode == .oneTime)
        store.setWeekStartsOnSunday(true)  // this week is now Sun Mar 1 – Sat Mar 7
        let task = try #require(home.task("Family", id: bakery))
        #expect(!task.isLate(inWeekStarting: store.selectedWeek!.startDay, firstWeekday: store.firstWeekday, today: store.currentDay),
                "its last day (Sunday the 8th) is still to come: not late")
        #expect(home.previewCard("Family", weekOf: 8)?.tasks.contains { $0.title == "Call the bakery" } == true,
                "there on its last day, Sunday the 8th")
    }

    @Test("Repro: with today's day picked in the strip, a late task (its day gone by) is hidden")
    func reproLateHiddenByTodayFilter() throws {
        let home = DanHome(), store = home.store
        store.addCategory(name: "Chores", symbol: "house")
        let mow = home.add("Chores", "Mow the lawn")
        store.setTaskDay(categoryID: home.cardID("Chores"), taskID: mow, day: 7)
        home.advance(to: 8)  // Sunday
        let task = try #require(home.task("Chores", id: mow))
        #expect(task.isLate(inWeekStarting: store.selectedWeek!.startDay, firstWeekday: store.firstWeekday, today: store.currentDay))
        let today = home.card("Chores")!.shownTasks(firstWeekday: store.firstWeekday, day: 1).map(\.title)
        #expect(today.contains("Mow the lawn"), "late and still to do, but Sunday's filter hides it; got \(today)")
    }

    @Test("Repro: a new one-time task given a later date as it's added (Smart Add with a picked date) doesn't carry to it")
    func reproNewTaskLaterDateStaysOneTime() throws {
        let home = DanHome(), store = home.store
        store.addCategory(name: "Family", symbol: "person.2")
        var parsed = ParsedTask(title: "Mom's birthday", mode: .oneTime)  // Smart Add's mode; the add row's wasn't picked
        parsed.lastDay = d(25)
        let id = try #require(store.addParsedTask(parsed, categoryID: home.cardID("Family")))
        #expect(home.task("Family", id: id)?.mode == .carryOver, "dated after its week: carries over, as setTaskDate makes it")
        #expect(home.previewCard("Family", weekOf: 11)?.tasks.contains { $0.title == "Mom's birthday" } == true,
                "still there next week, before its date")
    }

    @Test("Repro: picking One-Time for a task dated three weeks out makes it vanish this Sunday, unreminded")
    func reproOneTimeAfterDate() throws {
        let home = DanHome(), store = home.store
        store.addCategory(name: "Family", symbol: "person.2")
        let mom = home.add("Family", "Mom's birthday", .oneTime)
        store.setTaskDate(categoryID: home.cardID("Family"), taskID: mom, lastDay: d(25))
        store.updateTaskMode(categoryID: home.cardID("Family"), taskID: mom, mode: .oneTime)
        #expect(home.previewCard("Family", weekOf: 11)?.tasks.contains { $0.title == "Mom's birthday" } == true,
                "its date is Mar 25 but it's gone after this week")
        #expect(!store.expiryReminders.isEmpty, "and no reminder comes")
    }

    @Test("Repro: an item deleted from a repeating list stays in next week's saved copy when it was checked")
    func reproDeletedCheckedItemStays() throws {
        let home = DanHome(), store = home.store
        let list = home.add("Errands", "Groceries", .repeating, .list)
        for item in ["Milk", "Eggs"] { store.addSubtask(categoryID: home.cardID("Errands"), taskID: list, title: item) }
        let eggs = home.task("Errands", id: list)!.subtasks[1].id
        store.toggleSubtask(categoryID: home.cardID("Errands"), taskID: list, subtaskID: eggs)
        home.go(11); home.add("Errands", "Bank", .oneTime); home.go(4)  // next week saved, its copy untouched
        store.deleteSubtask(categoryID: home.cardID("Errands"), taskID: list, subtaskID: eggs)
        home.go(11)
        let copy = try #require(home.card("Errands")?.tasks.first { $0.repeatsFrom == list })
        #expect(copy.subtasks.map(\.title) == ["Milk"], "Eggs was deleted from the list; got \(copy.subtasks.map(\.title))")
    }

    @Test("Repro: a later week's list copy follows items by name, so duplicate items aren't followed one by one")
    func reproDuplicateItemsFollowedByName() throws {
        let home = DanHome(), store = home.store
        let list = home.add("Errands", "Groceries", .repeating, .list)
        for item in ["Milk", "Eggs", "Milk"] { store.addSubtask(categoryID: home.cardID("Errands"), taskID: list, title: item) }
        home.go(11); home.add("Errands", "Bank", .oneTime); home.go(4)
        // The extra Milk deleted, and a second Eggs added.
        let extraMilk = home.task("Errands", id: list)!.subtasks[2].id
        store.deleteSubtask(categoryID: home.cardID("Errands"), taskID: list, subtaskID: extraMilk)
        store.addSubtask(categoryID: home.cardID("Errands"), taskID: list, title: "Eggs")
        #expect(home.task("Errands", id: list)!.subtasks.map(\.title) == ["Milk", "Eggs", "Eggs"])
        home.go(11)
        let copy = try #require(home.card("Errands")?.tasks.first { $0.repeatsFrom == list })
        #expect(copy.subtasks.map(\.title) == ["Milk", "Eggs", "Eggs"], "got \(copy.subtasks.map(\.title))")
    }

    @Test("Repro: a second carry-over task with the same name doesn't reach a saved later week")
    func reproDuplicateCarryOverNotSynced() {
        let home = DanHome(), store = home.store
        home.add("Errands", "Pick up prescription")
        home.go(11); home.add("Errands", "Bank", .oneTime); home.go(4)
        home.add("Errands", "Pick up prescription")  // the other child's
        #expect(home.card("Errands")!.duplicateTaskIDs.count == 2)
        home.go(11)
        let copies = home.card("Errands")!.tasks.filter { $0.title == "Pick up prescription" }
        #expect(copies.count == 2, "both carry over (an unsaved week gets both); got \(copies.count)")
        _ = store
    }

    @Test("Repro: next week's card ring starts part-filled from a repeating list's kept checks, before anything is done")
    func reproRingStartsFilled() throws {
        let home = DanHome(), store = home.store
        let list = home.add("Errands", "Groceries", .repeating, .list)
        for item in ["Milk", "Eggs"] { store.addSubtask(categoryID: home.cardID("Errands"), taskID: list, title: item) }
        store.toggleSubtask(categoryID: home.cardID("Errands"), taskID: list,
                            subtaskID: home.task("Errands", id: list)!.subtasks[0].id)
        let next = try #require(home.previewCard("Errands", weekOf: 11))
        #expect(next.doneFraction == 0, "nothing done next week yet; the ring shows \(next.doneFraction)")
    }

    @Test("Repro: Undo right after midnight brings back a task past its last day")
    func reproUndoBringsBackExpired() {
        let home = DanHome(), store = home.store
        store.addCategory(name: "Family", symbol: "person.2")
        let bakery = home.add("Family", "Call the bakery", .oneTime)
        store.setTaskDate(categoryID: home.cardID("Family"), taskID: bakery, lastDay: d(6))  // Friday
        let dry = home.add("Errands", "Dry cleaning", .oneTime)
        home.advance(to: 6, hour: 23)  // Friday, 11 PM
        store.deleteTask(categoryID: home.cardID("Errands"), taskID: dry)
        home.clock.now = home.clock.calendar.date(byAdding: .minute, value: 61, to: home.clock.now)!  // 12:01 AM Saturday
        store.navigateToDate(home.clock.now)  // the app on a new day
        #expect(home.task("Family", id: bakery) == nil, "gone the day after its last day")
        store.undoLastDelete()
        #expect(home.task("Errands", id: dry) != nil)
        #expect(home.task("Family", id: bakery) == nil, "Undo brings back the bakery, past its last day")
    }
}
