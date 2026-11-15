// Data-level update check driver. Compiled twice for macOS:
//   old: old-project Models.swift + ChecklistStore.swift + this file
//   new: project Models.swift + ChecklistStore.swift + TypedDate.swift + stubs_new.swift + this file, with -D NEW
// It makes the same store calls the UI makes. The store's clock is the global `clock`.
//
//   driver seed <dir> <monday|sunday>     (old only) a long-time user's data, saved in <dir>
//   driver load <dir> <yyyy-MM-dd'T'HH:mm> [label]   launch at that moment, print a summary
//   driver edit <dir> <yyyy-MM-dd'T'HH:mm>  launch, then make one edit (first save rewrites the file)
import Foundation

var clock = Date()

func at(_ s: String) -> Date {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone.current
    f.dateFormat = "yyyy-MM-dd'T'HH:mm"
    return f.date(from: s)!
}

/// UserDefaults kept in a plist inside <dir> (a unique suite, removed after each run).
func withDefaults(_ dir: URL, _ body: (UserDefaults) -> Void) {
    let suite = "review.update.\(UUID().uuidString)"
    let d = UserDefaults(suiteName: suite)!
    d.removePersistentDomain(forName: suite)
    let plist = dir.appending(path: "defaults.plist")
    if let dict = NSDictionary(contentsOf: plist) as? [String: Any] { d.setPersistentDomain(dict, forName: suite) }
    body(d)
    let out = d.persistentDomain(forName: suite) ?? [:]
    (out as NSDictionary).write(to: plist, atomically: true)
    d.removePersistentDomain(forName: suite)
}

func makeStore(_ dir: URL, _ d: UserDefaults) -> ChecklistStore {
    #if NEW
    return ChecklistStore(directory: dir, defaults: d, now: { clock }, calendar: { .current }, appVersion: "1.1")
    #else
    return ChecklistStore(directory: dir, defaults: d, now: { clock }, calendar: { .current })
    #endif
}

func cat(_ s: ChecklistStore, _ name: String) -> Category {
    guard let c = s.selectedWeek?.categories.first(where: { $0.name == name }) else { fatalError("no card \(name)") }
    return c
}
func task(_ s: ChecklistStore, _ card: String, _ title: String) -> ChecklistTask {
    guard let t = cat(s, card).tasks.first(where: { $0.title == title }) else { fatalError("no task \(title) in \(card)") }
    return t
}

#if !NEW
func seed(_ dir: URL, sunday: Bool) {
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    withDefaults(dir) { d in
        // Week 1 (Tuesday Nov 3): first launch, onboarding done, cards and tasks of every kind.
        clock = at("2026-11-03T10:00")
        var s = makeStore(dir, d)
        s.dismissWelcome()
        if sunday { s.setWeekStartsOnSunday(true) }
        s.addCategory(name: "Home", symbol: "house")
        s.addCategory(name: "Fitness", symbol: "figure.run")
        s.addCategory(name: "Errands", symbol: "cart")
        var c = cat(s, "Home").id
        let laundry = s.addTask(categoryID: c, title: "Laundry", mode: .carryOver)!
        _ = s.addSubtask(categoryID: c, taskID: laundry, title: "Wash")
        _ = s.addSubtask(categoryID: c, taskID: laundry, title: "Dry")
        _ = s.addSubtask(categoryID: c, taskID: laundry, title: "Fold")
        let wash = task(s, "Home", "Laundry").subtasks[0].id
        s.toggleSubtask(categoryID: c, taskID: laundry, subtaskID: wash)
        let plants = s.addTask(categoryID: c, title: "Water plants", mode: .repeating)!
        s.toggleTask(categoryID: c, taskID: plants)
        s.addTask(categoryID: c, title: "Call plumber", mode: .oneTime)
        s.addTask(categoryID: c, title: "Call mom", mode: .carryOver)
        s.addTask(categoryID: c, title: "Call mom", mode: .carryOver)
        let books = s.addTask(categoryID: c, title: "Return library books", mode: .carryOver)!
        s.toggleTask(categoryID: c, taskID: books)
        s.addTask(categoryID: c, title: "Take out trash", mode: .repeating)
        c = cat(s, "Fitness").id
        let run = s.addTask(categoryID: c, title: "Run", mode: .repeating, type: .goal)!
        s.setGoalTarget(categoryID: c, taskID: run, target: 20, kind: .custom, unit: "km")
        s.updateGoalProgress(categoryID: c, taskID: run, progress: 6)
        let read = s.addTask(categoryID: c, title: "Read", mode: .carryOver, type: .goal)!
        s.setGoalTarget(categoryID: c, taskID: read, target: 120, kind: .time)
        s.setGoalStep(categoryID: c, taskID: read, step: 30)
        s.updateGoalProgress(categoryID: c, taskID: read, progress: 30)
        let pushups = s.addTask(categoryID: c, title: "Pushups", mode: .oneTime, type: .goal)!
        s.setGoalTarget(categoryID: c, taskID: pushups, target: 100, kind: .quantity)
        s.updateGoalProgress(categoryID: c, taskID: pushups, progress: 100)
        c = cat(s, "Errands").id
        let groceries = s.addTask(categoryID: c, title: "Groceries", mode: .carryOver, type: .list)!
        for item in ["Milk", "Eggs", "Bread"] { _ = s.addSubtask(categoryID: c, taskID: groceries, title: item) }
        s.toggleSubtask(categoryID: c, taskID: groceries, subtaskID: task(s, "Errands", "Groceries").subtasks[0].id)
        s.setListFolded(categoryID: c, taskID: groceries, folded: true)
        let packing = s.addTask(categoryID: c, title: "Weekly shop", mode: .repeating, type: .list)!
        for item in ["Coffee", "Fruit"] { _ = s.addSubtask(categoryID: c, taskID: packing, title: item) }
        s.toggleSubtask(categoryID: c, taskID: packing, subtaskID: task(s, "Errands", "Weekly shop").subtasks[1].id)
        let pharmacy = s.addTask(categoryID: c, title: "Pharmacy", mode: .oneTime, type: .list)!
        _ = s.addSubtask(categoryID: c, taskID: pharmacy, title: "Vitamins")

        // Week 2 (Tuesday Nov 10): relaunch; a This week only card, a reordered card, a deleted card,
        // a deleted task (Undo gone), a rename, next week's edits, Retro amber.
        clock = at("2026-11-10T09:00")
        s = makeStore(dir, d)
        s.addCategory(name: "Trip", symbol: "airplane")
        c = cat(s, "Trip").id
        s.addTask(categoryID: c, title: "Pack bag", mode: .carryOver)
        s.addTask(categoryID: c, title: "Book hotel", mode: .repeating)
        s.addTask(categoryID: c, title: "Print tickets", mode: .oneTime)
        s.setCategoryThisWeekOnly(c, true)
        s.addCategory(name: "Old stuff", symbol: "archivebox")
        s.addTask(categoryID: cat(s, "Old stuff").id, title: "Junk", mode: .carryOver)
        s.deleteCategory(cat(s, "Old stuff").id)
        s.clearUndo()
        c = cat(s, "Home").id
        let temp = s.addTask(categoryID: c, title: "Temp task", mode: .carryOver)!
        s.deleteTask(categoryID: c, taskID: temp)
        s.clearUndo()
        s.renameTask(categoryID: c, taskID: task(s, "Home", "Water plants").id, newTitle: "Water the plants")
        s.moveTask(categoryID: c, taskID: task(s, "Home", "Take out trash").id, by: -1)
        s.setCategoryOrder(["Errands", "Home", "Trip", "Fitness"])
        s.setAppearance(.retro)
        s.setRetroColor(.amber)
        // Next week: rename a copy, delete a repeating copy.
        clock = at("2026-11-12T20:00")
        s = makeStore(dir, d)
        let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: clock)!
        s.navigateToDate(nextWeek)
        s.renameTask(categoryID: cat(s, "Home").id, taskID: task(s, "Home", "Laundry").id, newTitle: "Laundry (big load)")
        s.deleteTask(categoryID: cat(s, "Home").id, taskID: task(s, "Home", "Take out trash").id)
        s.clearUndo()
        s.navigateToDate(clock)

        // Today (Sunday Nov 15): one more launch, a sub-task checked, a goal step.
        clock = at("2026-11-15T12:00")
        s = makeStore(dir, d)
        c = cat(s, "Home").id
        let l = cat(s, "Home").tasks.first { $0.title.hasPrefix("Laundry") }!
        s.toggleSubtask(categoryID: c, taskID: l.id, subtaskID: l.subtasks[1].id)
        c = cat(s, "Fitness").id
        s.updateGoalProgress(categoryID: c, taskID: task(s, "Fitness", "Run").id, progress: 9)
        summarize(s, "seeded (1.0.3)")
    }
}
#endif


#if NEW
/// New features on 1.0.3's items: a day, a date, pins, Just this week off; then a relaunch.
func features(_ dir: URL, _ when: String) {
    clock = at(when)
    withDefaults(dir) { d in
        var s = makeStore(dir, d)
        print("REVIEW: reminders before any date: \(s.expiryReminders.count)")
        let late = s.selectedWeek!.categories.flatMap(\.tasks).filter { $0.isLate(inWeekStarting: s.selectedWeek!.startDay, firstWeekday: s.firstWeekday, today: s.currentDay) }
        print("REVIEW: late on old data: \(late.map(\.title))")
        var c = cat(s, "Home").id
        // A day on an old repeating task, a pin on an old task and an old card.
        s.setTaskDay(categoryID: c, taskID: task(s, "Home", "Water the plants").id, day: 6)  // Friday
        s.setTaskPinned(categoryID: c, taskID: task(s, "Home", "Take out trash").id, pinned: true)
        s.setCategoryPinned(categoryID: cat(s, "Fitness").id, pinned: true)
        // A date three weeks off on an old carry-over goal: it carries until then.
        let due = s.currentDay.adding(days: 21)
        s.setTaskDate(categoryID: cat(s, "Fitness").id, taskID: task(s, "Fitness", "Read").id, lastDay: due)
        print("REVIEW: reminders after a date: \(s.expiryReminders.map { "\($0.title) on \($0.day)" })")
        // Just this week off on 1.0.3's This week only card.
        s.setCategoryThisWeekOnly(cat(s, "Trip").id, false)
        print("REVIEW: Trip after Just this week off: \(cat(s, "Trip").tasks.map { "\($0.title)=\($0.mode.rawValue)" })")
        // Relaunch twice.
        s = makeStore(dir, d)
        s = makeStore(dir, d)
        c = cat(s, "Home").id
        let w = task(s, "Home", "Water the plants"), t = task(s, "Home", "Take out trash"), r = task(s, "Fitness", "Read")
        print("REVIEW: after relaunch: day=\(w.dayOfWeek.map(String.init) ?? "nil") pinTask=\(t.isPinned) pinCard=\(cat(s, "Fitness").isPinned) readDate=\(r.expiresOn.map(\.description) ?? "nil") readMode=\(r.mode.rawValue) trip=\(cat(s, "Trip").isThisWeekOnly)")
        print("REVIEW: Home shown order: \(cat(s, "Home").orderedTasks(firstWeekday: s.firstWeekday).map(\.title))")
        summarize(s, "after new features + 2 relaunches")
    }
}
#endif


/// Launch, optionally turn Trip's This week only off, then look at next week.
func nextWeek(_ dir: URL, _ when: String, tripOff: Bool) {
    clock = at(when)
    withDefaults(dir) { d in
        let s = makeStore(dir, d)
        if tripOff { s.setCategoryThisWeekOnly(cat(s, "Trip").id, false) }
        s.navigateToDate(Calendar.current.date(byAdding: .day, value: 7, to: clock)!)
        print("REVIEW: next week \(s.selectedWeek!.startDay):")
        for c in s.selectedWeek!.categories {
            print("    \(c.name): " + c.tasks.map { t -> String in
                var x = "\(t.title)[\(t.mode.rawValue)"
                #if NEW
                if let day = t.dayOfWeek { x += ",day \(day)" }
                if t.isPinned { x += ",pinned" }
                if let e = t.expiresOn { x += ",until \(e)" }
                #endif
                return x + "]"
            }.joined(separator: " "))
        }
    }
}

func summarize(_ s: ChecklistStore, _ label: String) {
    print("== \(label): \(s.weeks.count) weeks, appearance \(s.appearanceMode.rawValue) \(s.retroColor.rawValue), sundayStart \(s.weekStartsOnSunday), welcomeSeen \(s.hasSeenWelcome)")
    for w in s.weeks.sorted(by: { $0.startDay < $1.startDay }) {
        print("  week \(w.startDay)" + (s.isCurrentWeek(w) ? " (current)" : ""))
        for c in w.categories {
            #if NEW
            let dup = c.duplicateTaskIDs
            #endif
            let tasks = c.tasks.map { t -> String in
                var x = "\(t.title)[\(t.mode.rawValue),\(t.taskType.rawValue)\(t.isCompleted ? ",done" : "")"
                if t.taskType == .goal { x += ",\(t.goalProgress ?? 0)/\(t.goalTarget ?? 0)\(t.goalUnit.map { " " + $0 } ?? "")" }
                if !t.subtasks.isEmpty { x += ",{" + t.subtasks.map { ($0.isCompleted ? "x " : "") + $0.title }.joined(separator: ";") + "}" }
                if t.isListFolded { x += ",folded" }
                if let m = t.modeBeforeThisWeekOnly { x += ",before:\(m.mode.rawValue)" }
                #if NEW
                if t.dayOfWeek != nil || t.expiresOn != nil || t.isPinned || t.hasOwnTitle { x += ",NEWFIELDS" }
                if dup.contains(t.id) { x += ",DUP" }
                #endif
                return x + "]"
            }
            print("    \(c.name)\(c.isThisWeekOnly ? " (this week only)" : ""): " + tasks.joined(separator: " "))
        }
    }
}

@main struct Driver {
    static func main() {
        let a = CommandLine.arguments
        let dir = URL(fileURLWithPath: a[2])
        switch a[1] {
        #if !NEW
        case "seed": seed(dir, sunday: a[3] == "sunday")
        #endif
        case "load", "edit":
            clock = at(a[3])
            withDefaults(dir) { d in
                let s = makeStore(dir, d)
                if let e = s.persistenceError { print("PERSISTENCE ERROR: \(e)") }
                #if NEW
                print("REVIEW: whatsNewButton=\(s.showsWhatsNewButton) lastLaunched=\(d.string(forKey: "lastLaunchedVersion") ?? "nil") pending=\(d.string(forKey: "whatsNewPending") ?? "nil") opens=\(d.integer(forKey: "whatsNewButtonOpens")) remindsBeforeExpiry=\(s.remindsBeforeExpiry)")
                #endif
                if a[1] == "edit" {
                    let c = cat(s, "Home").id
                    s.toggleTask(categoryID: c, taskID: task(s, "Home", "Call mom").id)
                    s.toggleTask(categoryID: c, taskID: task(s, "Home", "Call mom").id)
                }
                summarize(s, a.count > 4 ? a[4] : "\(a[1]) at \(a[3])")
            }
        #if NEW
        case "features": features(dir, a[3])
        #endif
        case "nextweek": nextWeek(dir, a[3], tripOff: a.count > 4 && a[4] == "tripoff")
        default: fatalError("usage")
        }
    }
}
