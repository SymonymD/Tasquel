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

    /// `-demoToday yyyy-MM-dd`: that day is today (at the real time of day), so screenshots
    /// taken on any day can show a midweek day strip. Without it, the real date.
    static func demoClock() -> () -> Date {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-demoToday"), arguments.indices.contains(index + 1) else { return { Date() } }
        let parts = arguments[index + 1].split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return { Date() } }
        let calendar = Calendar.current
        let day = DayKey(year: parts[0], month: parts[1], day: parts[2])
        let offset = day.date(in: calendar).timeIntervalSince(DayKey(Date(), in: calendar).date(in: calendar))
        return { Date().addingTimeInterval(offset) }
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
            // Mom's birthday is in four days, set two days ago: its checkbox's ring is 3 of 7 days in.
            for ti in weeks[wi].categories[ci].tasks.indices where weeks[wi].categories[ci].tasks[ti].title == "Plan Mom's birthday" {
                weeks[wi].categories[ci].tasks[ti].expiresOn = currentDay.adding(days: 4)
                weeks[wi].categories[ci].tasks[ti].expirySetOn = currentDay.adding(days: -2)
            }
        }
        // `-demoDaysAndPins` (the Seasonal screenshots): 1.1's days, a late task and pins.
        if arguments.contains("-demoDaysAndPins") { addDemoDaysAndPins(in: wi) }
        // `-demoFirstCard <name>` puts that card first, so it opens at the top.
        if let index = arguments.firstIndex(of: "-demoFirstCard"), arguments.indices.contains(index + 1),
           let ci = weeks[wi].categories.firstIndex(where: { $0.name == arguments[index + 1] }) {
            weeks[wi].categories.insert(weeks[wi].categories.remove(at: ci), at: 0)
        }
        save()
    }

    /// Days on a few tasks (one today, one late, one ahead, one done), Errands and Fitness
    /// pinned, and Groceries pinned in Errands.
    private func addDemoDaysAndPins(in wi: Int) {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = .current
        func weekday(_ day: DayKey) -> Int { gregorian.component(.weekday, from: day.date(in: gregorian)) }
        let yesterday = currentDay.adding(days: -1)
        let days: [String: Int?] = [
            "Call the vet": weekday(currentDay),
            "Car service": yesterday >= weeks[wi].startDay ? weekday(yesterday) : nil,
            "Drop off donations": 7,  // Saturday
            "Weekly 1:1 notes": 2,    // Monday
        ]
        for ci in weeks[wi].categories.indices {
            weeks[wi].categories[ci].isPinned = ["Errands", "Fitness"].contains(weeks[wi].categories[ci].name)
            for ti in weeks[wi].categories[ci].tasks.indices {
                let title = weeks[wi].categories[ci].tasks[ti].title
                if let day = days[title] { weeks[wi].categories[ci].tasks[ti].dayOfWeek = day }
                if title == "Groceries" { weeks[wi].categories[ci].tasks[ti].isPinned = true }
            }
        }
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
