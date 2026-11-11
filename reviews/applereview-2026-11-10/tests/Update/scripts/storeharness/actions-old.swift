import Foundation
// 1.0.2's actions (no folding there).
func runActions(_ store: ChecklistStore, _ actions: [String]) {
    for action in actions {
        let parts = action.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2, let week = store.selectedWeek else { continue }
        switch parts[0] {
        case "twoOff", "twoOn":
            for c in week.categories where c.name == parts[1] { store.setCategoryThisWeekOnly(c.id, parts[0] == "twoOn") }
        case "goto": store.navigateToDate(store.currentDate.addingTimeInterval((Double(parts[1]) ?? 0) * 7 * 86_400))
        default: print("unknown action \(action)")
        }
        print("did \(action)")
    }
}
func extra(_ t: ChecklistTask) -> String { "" }
