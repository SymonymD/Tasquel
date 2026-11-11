import Foundation
func runActions(_ store: ChecklistStore, _ actions: [String]) {
    for action in actions {
        let parts = action.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2, let week = store.selectedWeek else { continue }
        switch parts[0] {
        case "fold", "unfold":
            for c in week.categories { for t in c.tasks where t.title == parts[1] {
                store.setListFolded(categoryID: c.id, taskID: t.id, folded: parts[0] == "fold")
            } }
        case "twoOff", "twoOn":
            for c in week.categories where c.name == parts[1] { store.setCategoryThisWeekOnly(c.id, parts[0] == "twoOn") }
        case "goto": store.navigateToDate(store.currentDate.addingTimeInterval((Double(parts[1]) ?? 0) * 7 * 86_400))
        case "mode":  // mode:<task>=carryOver|repeating|oneTime
            let kv = parts[1].split(separator: "=").map(String.init)
            for c in week.categories { for t in c.tasks where t.title == kv[0] { store.updateTaskMode(categoryID: c.id, taskID: t.id, mode: TaskMode(rawValue: kv[1])!) } }
        default: print("unknown action \(action)")
        }
        print("did \(action)")
    }
}
func extra(_ t: ChecklistTask) -> String {
    " | folded=\(t.isListFolded) before=\(t.modeBeforeThisWeekOnly.map { "\($0.mode)/\($0.wasUserEdited)" } ?? "-")"
}
