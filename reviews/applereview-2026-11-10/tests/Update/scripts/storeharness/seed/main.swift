import Foundation
// Seeds a Documents folder with the LIVE 1.0.2 store code (old copy's ChecklistStore.swift),
// through the same store calls the UI makes, so the files are exactly what 1.0.2 writes.
//   seed-old <empty folder>
let dir = URL(fileURLWithPath: CommandLine.arguments[1])
let defaults = UserDefaults(suiteName: "seed-\(UUID().uuidString)")!
let today = Date()
let store = ChecklistStore(directory: dir, defaults: defaults, now: { today })
store.dismissWelcome()

func cat(_ name: String) -> UUID { store.selectedWeek!.categories.first { $0.name == name }!.id }
func task(_ c: String, _ t: String) -> UUID { store.selectedWeek!.categories.first { $0.name == c }!.tasks.first { $0.title == t }!.id }
func sub(_ c: String, _ t: String, _ s: String) -> UUID {
    store.selectedWeek!.categories.first { $0.name == c }!.tasks.first { $0.title == t }!.subtasks.first { $0.title == s }!.id
}

// Errands
let e = cat("Errands")
_ = store.addTask(categoryID: e, title: "Groceries", mode: .carryOver, type: .list)
for i in ["Eggs", "Milk", "Bread"] { _ = store.addSubtask(categoryID: e, taskID: task("Errands", "Groceries"), title: i) }
store.toggleSubtask(categoryID: e, taskID: task("Errands", "Groceries"), subtaskID: sub("Errands", "Groceries", "Eggs"))
_ = store.addTask(categoryID: e, title: "Laundry", mode: .repeating, type: .checkbox)
for i in ["Wash", "Fold"] { _ = store.addSubtask(categoryID: e, taskID: task("Errands", "Laundry"), title: i) }
store.toggleSubtask(categoryID: e, taskID: task("Errands", "Laundry"), subtaskID: sub("Errands", "Laundry", "Wash"))
_ = store.addTask(categoryID: e, title: "Pay rent", mode: .oneTime, type: .checkbox)
store.toggleTask(categoryID: e, taskID: task("Errands", "Pay rent"))
_ = store.addTask(categoryID: e, title: "Buy", mode: .carryOver, type: .checkbox)
store.renameTask(categoryID: e, taskID: task("Errands", "Buy"), newTitle: "Buy stamps")
_ = store.addTask(categoryID: e, title: "Old note", mode: .oneTime, type: .checkbox)
store.deleteTask(categoryID: e, taskID: task("Errands", "Old note"))
store.clearUndo()
_ = store.addTask(categoryID: e, title: "Weekly list", mode: .repeating, type: .list)
for i in ["Soap", "Rice"] { _ = store.addSubtask(categoryID: e, taskID: task("Errands", "Weekly list"), title: i) }
store.toggleSubtask(categoryID: e, taskID: task("Errands", "Weekly list"), subtaskID: sub("Errands", "Weekly list", "Soap"))
store.moveTask(categoryID: e, taskID: task("Errands", "Buy stamps"), by: -1)

// Fitness
let f = cat("Fitness")
_ = store.addTask(categoryID: f, title: "Run", mode: .repeating, type: .goal)
store.setGoalTarget(categoryID: f, taskID: task("Fitness", "Run"), target: 10)
store.updateGoalProgress(categoryID: f, taskID: task("Fitness", "Run"), progress: 4)
_ = store.addTask(categoryID: f, title: "Stretch", mode: .carryOver, type: .goal)
store.setGoalTarget(categoryID: f, taskID: task("Fitness", "Stretch"), target: 60, kind: .time)
store.updateGoalProgress(categoryID: f, taskID: task("Fitness", "Stretch"), progress: 9)
_ = store.addTask(categoryID: f, title: "Read", mode: .repeating, type: .goal)
store.setGoalTarget(categoryID: f, taskID: task("Fitness", "Read"), target: 50, kind: .custom, unit: "pages")
store.setGoalStep(categoryID: f, taskID: task("Fitness", "Read"), step: 10, days: 5)
_ = store.addTask(categoryID: f, title: "Gym bag", mode: .repeating, type: .list)
for i in ["Shoes", "Towel"] { _ = store.addSubtask(categoryID: f, taskID: task("Fitness", "Gym bag"), title: i) }
store.toggleSubtask(categoryID: f, taskID: task("Fitness", "Gym bag"), subtaskID: sub("Fitness", "Gym bag", "Shoes"))

// Work, then This week only on (1.0.2 makes its tasks one-time for good)
let w = cat("Work")
_ = store.addTask(categoryID: w, title: "Report", mode: .carryOver, type: .checkbox)
_ = store.addTask(categoryID: w, title: "Standup", mode: .repeating, type: .checkbox)
_ = store.addTask(categoryID: w, title: "Inbox", mode: .repeating, type: .list)
_ = store.addSubtask(categoryID: w, taskID: task("Work", "Inbox"), title: "Reply")
store.setCategoryThisWeekOnly(w, true)

// Trip, for this week only
store.addCategory(name: "Trip", symbol: "airplane", thisWeekOnly: true)
_ = store.addTask(categoryID: cat("Trip"), title: "Pack", mode: .oneTime, type: .checkbox)

// Next week: saved by an edit; Study there made this week only, then a carry-over task added
// to this week's Study arrives in it (1.0.2 leaves such a copy carry-over).
let next = today.addingTimeInterval(7 * 86_400)
store.navigateToDate(next)
_ = store.addTask(categoryID: cat("Errands"), title: "Next week task", mode: .oneTime, type: .checkbox)
store.navigateToDate(today)
let s = cat("Study")
_ = store.addTask(categoryID: s, title: "Essay", mode: .carryOver, type: .checkbox)
store.navigateToDate(next)
store.setCategoryThisWeekOnly(cat("Study"), true)
store.navigateToDate(today)
_ = store.addTask(categoryID: cat("Study"), title: "Flashcards", mode: .carryOver, type: .list)
_ = store.addSubtask(categoryID: cat("Study"), taskID: task("Study", "Flashcards"), title: "Deck 1")
store.navigateToDate(next)
store.navigateToDate(today)

// Settings
store.setAppearance(.dark)
store.setCategorySort(.recentFirst)
print("seeded", store.weeks.map { "\($0.startDay)" })
