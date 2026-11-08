#if DEBUG
import Foundation

// MARK: - Demo Data (App Store screenshots)

/// `-demoData` (debug builds only): throwaway storage, no onboarding, and a current week
/// filled with sample tasks across the starter categories, for App Store screenshots.
/// `-demoAppearance <system|light|dark|retro>` picks the theme and `-demoFirstCard <name>`
/// puts one card first. Calendar events come from `-fakeCalendar`.
extension ChecklistStore {
    static var launchesWithDemoData: Bool {
        ProcessInfo.processInfo.arguments.contains("-demoData")
    }

    func fillWithDemoData() {
        dismissWelcome()
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-demoAppearance"), arguments.indices.contains(index + 1),
           let mode = AppearanceMode(rawValue: arguments[index + 1]) {
            setAppearance(mode)
        }
        setCalendarEventsEnabled(true)

        let current = ensureWeekExists(for: selectedDate)  // today, at launch
        guard let wi = weeks.firstIndex(where: { $0.id == current.id }) else { return }
        for ci in weeks[wi].categories.indices {
            weeks[wi].categories[ci].tasks = Self.demoTasks(for: weeks[wi].categories[ci].name)
        }
        // `-demoFirstCard <name>` puts that card first, so it opens at the top.
        if let index = arguments.firstIndex(of: "-demoFirstCard"), arguments.indices.contains(index + 1),
           let ci = weeks[wi].categories.firstIndex(where: { $0.name == arguments[index + 1] }) {
            weeks[wi].categories.insert(weeks[wi].categories.remove(at: ci), at: 0)
        }
        save()
    }

    private static func demoTasks(for category: String) -> [ChecklistTask] {
        switch category {
        case "Errands":
            [
                ChecklistTask(title: "Groceries", mode: .repeating, subtasks: [
                    SubTask(title: "Eggs", isCompleted: true),
                    SubTask(title: "Spinach", isCompleted: true),
                    SubTask(title: "Coffee beans"),
                    SubTask(title: "Oat milk"),
                    SubTask(title: "Lemons"),
                ], taskType: .list),
                ChecklistTask(title: "Plan Mom's birthday", mode: .carryOver, subtasks: [
                    SubTask(title: "Order the cake", isCompleted: true),
                    SubTask(title: "Book dinner"),
                    SubTask(title: "Wrap the gift"),
                ]),
                ChecklistTask(title: "Drop off donations", mode: .oneTime, taskType: .goal,
                              goalTarget: 3, goalProgress: 2, goalUnit: "bags", goalUnitKind: .custom),
                ChecklistTask(title: "Pick up dry cleaning", isCompleted: true, mode: .oneTime),
            ]
        case "Work":
            [
                ChecklistTask(title: "Q4 planning deck", mode: .carryOver, subtasks: [
                    SubTask(title: "Outline", isCompleted: true),
                    SubTask(title: "Draft slides", isCompleted: true),
                    SubTask(title: "Review with team"),
                ]),
                ChecklistTask(title: "Expense report", isCompleted: true, mode: .oneTime),
                ChecklistTask(title: "Weekly 1:1 notes", isCompleted: true, mode: .repeating),
                ChecklistTask(title: "Inbox zero", mode: .repeating),
            ]
        case "Fitness":
            [
                ChecklistTask(title: "Run", mode: .repeating, taskType: .goal,
                              goalTarget: 3, goalProgress: 2, goalUnitKind: .quantity),
                ChecklistTask(title: "Yoga", mode: .repeating, taskType: .goal,
                              goalTarget: 90, goalProgress: 60, goalUnitKind: .time),
                ChecklistTask(title: "Meal prep", isCompleted: true, mode: .repeating),
            ]
        case "Study":
            [
                ChecklistTask(title: "Read", mode: .repeating, taskType: .goal,
                              goalTarget: 100, goalProgress: 70, goalUnit: "pages", goalUnitKind: .custom),
                ChecklistTask(title: "Spanish lessons", isCompleted: true, mode: .repeating, taskType: .goal,
                              goalTarget: 5, goalProgress: 5, goalUnitKind: .quantity),
                ChecklistTask(title: "Finish module 3", mode: .carryOver, subtasks: [
                    SubTask(title: "Watch lectures", isCompleted: true),
                    SubTask(title: "Take the quiz"),
                ]),
            ]
        case "Appointments":
            [
                ChecklistTask(title: "Book a dentist cleaning", isCompleted: true, mode: .oneTime),
                ChecklistTask(title: "Car service", mode: .carryOver),
                ChecklistTask(title: "Call the vet", mode: .oneTime),
            ]
        default:
            []
        }
    }
}
#endif
