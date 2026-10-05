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

@Test("Welcome illustration starts with both clock hands at noon")
func welcomeClockHandsStartAtNoon() {
    let points = handPoints(for: ClockHandsShape())
    #expect(points.count == 3)
    if points.count == 3 {
        #expect(points[0].x == 50 && points[0].y < 50)
        #expect(points[1] == CGPoint(x: 50, y: 50))
        #expect(points[2].x == 50 && points[2].y < 50)
    }
}

@Test("Clock hands reach 10:10 before becoming a checkmark")
func welcomeClockHandsReachTenTen() {
    let points = handPoints(for: ClockHandsShape(hourAngle: 305, minuteAngle: 420))
    #expect(points.count == 3)
    if points.count == 3 {
        #expect(abs(points[0].x - 32) < 0.5 && abs(points[0].y - 37.4) < 0.5)
        #expect(points[1] == CGPoint(x: 50, y: 50))
        #expect(abs(points[2].x - 78.6) < 0.5 && abs(points[2].y - 33.5) < 0.5)
    }
}

@Test("The same hands become the two strokes of a checkmark")
func welcomeClockHandsFormCheckmark() {
    let points = handPoints(for: ClockHandsShape(
        hourAngle: ClockHandsShape.checkedHourAngle,
        minuteAngle: ClockHandsShape.checkedMinuteAngle
    ))
    #expect(points.count == 3)
    if points.count == 3 {
        #expect(points[0].x < 40 && points[0].y < 40)
        #expect(points[1] == CGPoint(x: 50, y: 50))
        #expect(points[2].x > 50 && points[2].y < 30)
        #expect(hypot(points[0].x - 50, points[0].y - 50)
                < hypot(points[2].x - 50, points[2].y - 50))
    }
}

private func handPoints(for shape: ClockHandsShape) -> [CGPoint] {
    let path = shape.path(in: CGRect(x: 0, y: 0, width: 100, height: 100))
    var points: [CGPoint] = []
    path.forEach { element in
        switch element {
        case .move(to: let point), .line(to: let point): points.append(point)
        default: break
        }
    }
    return points
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

    // MARK: - deleteCategoryEntirely

    @Test("deleteCategoryEntirely removes template from savedCategories")
    func deleteCategoryEntirelyCleansTemplate() {
        let store = makeIsolatedStore()
        let monday = futureMonday(weeksFromBase: 90)

        // Seed a week with a category that also has a saved template
        store.weeks = [Week(startDate: monday)]
        let category = Category(name: "TestCat", symbol: "star")
        store.weeks[0].categories = [category]
        store.savedCategories.append(CategoryTemplate(name: "TestCat", symbol: "star"))
        store.selectedDate = monday

        store.deleteCategoryEntirely(category.id)

        #expect(!store.savedCategories.contains(where: { $0.name == "TestCat" }),
                "deleteCategoryEntirely should remove the matching saved template")
        #expect(store.selectedWeek?.categories.contains(where: { $0.name == "TestCat" }) != true,
                "deleteCategoryEntirely should remove category from current week")
    }
}

struct JourneySafetyTests {
    @Test("Past weeks reject task and category changes")
    func pastWeekIsReadOnly() {
        let store = makeIsolatedStore()
        let pastDate = Calendar.current.date(byAdding: .weekOfYear, value: -2, to: Date())!
        let task = ChecklistTask(title: "Original")
        let category = Category(name: "History", symbol: "clock", tasks: [task])
        store.weeks = [Week(startDate: Week.mondayOfWeek(containing: pastDate), categories: [category])]
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
        store.weeks = [Week(startDate: Week.mondayOfWeek(containing: Date()), categories: [category])]
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
