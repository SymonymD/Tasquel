import Foundation
// Runs the app's own ChecklistStore (this copy's ChecklistStore.swift + Models.swift, built
// for macOS) on a copy of a Documents folder, with "today" moved by N days, and prints the
// current week and the two after it the way a user sees them. Used to compare what 1.0.2 and
// the new build do with the same 1.0.2 data, including a rollover a week later.
//   harness <Documents copy> <days from today> [actions...]
// Actions (new build only, see actions.swift): fold:<task>, unfold:<task>, twoOff:<card>, twoOn:<card>
let args = CommandLine.arguments
let dir = URL(fileURLWithPath: args[1])
let days = Double(args[2]) ?? 0
let start = Date().addingTimeInterval(days * 86_400)
let defaults = UserDefaults(suiteName: "harness-\(UUID().uuidString)")!
defaults.set(true, forKey: "didMigrateStarters_v1")  // set by 1.0.2 at its first launch
let store = ChecklistStore(directory: dir, defaults: defaults, now: { start })
runActions(store, Array(args.dropFirst(3)))

func describe(_ week: Week?, _ label: String) {
    guard let week else { print("\(label): none"); return }
    print("== \(label) \(week.startDay) \(store.isPastWeek(week) ? "past" : store.isFutureWeek(week) ? "future" : "current")")
    for c in week.categories {
        print("  [\(c.name)]\(c.isThisWeekOnly ? " this-week-only" : "")")
        for t in c.tasks {
            var s = "    - \(t.title) | \(t.taskType) \(t.mode) | \(t.isCompleted ? "done" : "open")"
            if t.taskType == .goal { s += " | \(t.goalProgress ?? 0)/\(t.goalTarget ?? 0) \(t.goalKind) step \(t.goalStep.map { "\($0)" } ?? "auto") days \(t.goalDays.map { "\($0)" } ?? "-")" }
            if !t.subtasks.isEmpty { s += " | " + t.subtasks.map { ($0.isCompleted ? "[x]" : "[ ]") + $0.title }.joined(separator: " ") }
            s += " | edited=\(t.isUserEdited) carried=\(t.carriedFrom != nil) repeats=\(t.repeatsFrom != nil)"
            s += extra(t)
            print(s)
        }
    }
}
for k in 0..<3 {
    store.navigateToDate(start.addingTimeInterval(Double(k) * 7 * 86_400))
    describe(store.selectedWeek, "week+\(k)")
}
print("saved weeks:", store.weeks.map { "\($0.startDay)" }.joined(separator: ", "))
