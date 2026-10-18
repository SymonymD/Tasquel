import Foundation

// MARK: - Task Mode

enum TaskMode: String, Codable, CaseIterable {
    case carryOver
    case repeating
    /// This week only. Shown in menus as "Checkbox" (see `TaskKind`).
    case oneTime

    var label: String {
        switch self {
        case .carryOver: "Carry Over"
        case .repeating: "Repeating"
        case .oneTime: "One-Time"
        }
    }

    var symbol: String {
        switch self {
        case .carryOver: "arrow.uturn.forward"
        case .repeating: "repeat"
        case .oneTime: "1.circle"
        }
    }

    var hint: String {
        switch self {
        case .carryOver: "Rolls to next week if incomplete"
        case .repeating: "Appears every week automatically"
        case .oneTime: "This week only, does not carry forward"
        }
    }
}

// MARK: - Task Type

enum TaskType: String, Codable, CaseIterable {
    case checkbox
    case goal
    /// A checklist of items (stored as sub-tasks) that checks itself off when every item is checked.
    case list

    var label: String {
        switch self {
        case .checkbox: "Checkbox"
        case .goal: "Goal"
        case .list: "List"
        }
    }

    var symbol: String {
        switch self {
        case .checkbox: "checkmark.circle"
        case .goal: "target"
        case .list: "list.bullet"
        }
    }
}

// MARK: - Task Kind

/// The one choice offered in task menus, covering both mode and type: a checkbox for
/// this week only, a carry-over or repeating checkbox, a goal, or a list. A goal keeps
/// its mode; a list always carries over, with only its unchecked items.
enum TaskKind: CaseIterable {
    case checkbox
    case carryOver
    case repeating
    case goal
    case list

    init(_ task: ChecklistTask) {
        switch task.taskType {
        case .goal: self = .goal; return
        case .list: self = .list; return
        case .checkbox: break
        }
        switch task.mode {
        case .oneTime: self = .checkbox
        case .carryOver: self = .carryOver
        case .repeating: self = .repeating
        }
    }

    /// The mode this choice sets, or `nil` for a goal.
    var mode: TaskMode? {
        switch self {
        case .checkbox: .oneTime
        case .carryOver: .carryOver
        case .repeating: .repeating
        case .goal: nil
        case .list: .carryOver
        }
    }

    var type: TaskType {
        switch self {
        case .checkbox, .carryOver, .repeating: .checkbox
        case .goal: .goal
        case .list: .list
        }
    }

    var label: String {
        switch self {
        case .checkbox: "Checkbox"
        case .carryOver: "Carry Over"
        case .repeating: "Repeating"
        case .goal: "Goal"
        case .list: "List"
        }
    }

    var symbol: String {
        switch self {
        case .checkbox: TaskType.checkbox.symbol
        case .carryOver: TaskMode.carryOver.symbol
        case .repeating: TaskMode.repeating.symbol
        case .goal: TaskType.goal.symbol
        case .list: TaskType.list.symbol
        }
    }
}

// MARK: - Goal Unit

/// What a goal counts. Time goals store their target and progress in minutes.
enum GoalUnitKind: String, Codable, CaseIterable {
    case quantity
    case time
    case custom

    var label: String {
        switch self {
        case .quantity: "Quantity"
        case .time: "Time"
        case .custom: "Custom"
        }
    }

    /// A goal value for display: "1h 30m" for time, otherwise the number.
    func format(_ value: Double) -> String {
        guard self == .time else {
            return value.formatted(.number.precision(.fractionLength(0...2)))
        }
        let minutes = Int(value.rounded())
        let hours = minutes / 60, remainder = minutes % 60
        if hours == 0 { return "\(remainder)m" }
        return remainder == 0 ? "\(hours)h" : "\(hours)h \(remainder)m"
    }
}

// MARK: - Sub-Task

struct SubTask: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var isCompleted: Bool = false
}

// MARK: - Models

struct ChecklistTask: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var isCompleted: Bool = false
    var mode: TaskMode = .carryOver
    var subtasks: [SubTask] = []
    var taskType: TaskType = .checkbox
    var goalTarget: Double? = nil
    var goalProgress: Double? = nil
    var goalUnit: String? = nil
    /// What the goal counts. `nil` for goals saved before units had a kind; see `goalKind`.
    var goalUnitKind: GoalUnitKind? = nil
    /// For a task carried over from the week before: the task it was copied from.
    var carriedFrom: UUID? = nil

    var allSubtasksCompleted: Bool {
        subtasks.allSatisfy(\.isCompleted)
    }

    var completedSubtaskCount: Int {
        subtasks.filter(\.isCompleted).count
    }

    /// The goal's unit kind. Older goals count a quantity, or a custom unit if one was typed.
    var goalKind: GoalUnitKind {
        goalUnitKind ?? ((goalUnit ?? "").isEmpty ? .quantity : .custom)
    }

    /// The unit name shown after the numbers (custom goals only).
    var goalUnitLabel: String? {
        guard goalKind == .custom, let unit = goalUnit, !unit.isEmpty else { return nil }
        return unit
    }

    var goalFraction: String {
        let progress = goalKind.format(goalProgress ?? 0)
        let target = goalKind.format(goalTarget ?? 0)
        return goalKind == .time ? "\(progress) / \(target)" : "\(progress)/\(target)"
    }

    var goalIsComplete: Bool {
        guard let target = goalTarget, target > 0 else { return false }
        return (goalProgress ?? 0) >= target
    }
}

struct Category: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var symbol: String
    var tasks: [ChecklistTask] = []
    /// Added "for this week only": not rolled forward into later weeks.
    var isThisWeekOnly = false

    var completedCount: Int { tasks.filter(\.isCompleted).count }
    var totalCount: Int { tasks.count }
}

extension Category {
    /// Decodes `isThisWeekOnly` leniently so data saved before it existed still loads.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        symbol = try container.decode(String.self, forKey: .symbol)
        tasks = try container.decode([ChecklistTask].self, forKey: .tasks)
        isThisWeekOnly = try container.decodeIfPresent(Bool.self, forKey: .isThisWeekOnly) ?? false
    }
}

struct Week: Codable, Identifiable, Equatable {
    var id = UUID()
    var startDate: Date
    var categories: [Category] = []
    /// Carry-over tasks (by their source's ID) the user deleted from this week, so
    /// syncing with the week before doesn't bring them back.
    var dismissedCarryOvers: [UUID]? = nil

    var displayTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d/yy"
        return "Week of \(formatter.string(from: startDate))"
    }

    /// The day after the week's last day.
    var endDate: Date {
        Calendar.current.date(byAdding: .day, value: 7, to: startDate) ?? startDate
    }

    /// Whether today falls within this week (works for any week start day).
    var isCurrentWeek: Bool {
        let now = Date()
        return startDate <= now && now < endDate
    }

    var isFutureWeek: Bool {
        startDate > Date()
    }

    var isPastWeek: Bool {
        !isCurrentWeek && !isFutureWeek
    }

    /// Calendar weekday numbers for the supported week start days.
    static let sunday = 1
    static let monday = 2

    /// Start (midnight) of the week containing `date`. `firstWeekday` is 1 for
    /// Sunday or 2 for Monday; the store passes the user's setting.
    static func startOfWeek(containing date: Date, firstWeekday: Int = monday) -> Date {
        var calendar = Calendar.current
        calendar.firstWeekday = firstWeekday  // must be set, or US locales default to Sunday
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        components.weekday = firstWeekday
        return calendar.date(from: components) ?? date
    }
}

// MARK: - Saved Category Template

struct CategoryTemplate: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var symbol: String
}

// MARK: - Default Categories

extension CategoryTemplate {
    static let starters: [CategoryTemplate] = [
        CategoryTemplate(name: "Errands", symbol: "cart"),
        CategoryTemplate(name: "Work", symbol: "briefcase"),
        CategoryTemplate(name: "Fitness", symbol: "figure.run"),
        CategoryTemplate(name: "Study", symbol: "book"),
        CategoryTemplate(name: "Appointments", symbol: "calendar.badge.clock"),
    ]
}

// MARK: - Appearance

enum AppearanceMode: String, Codable, CaseIterable {
    case system
    case light
    case dark
    case retro

    var label: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        case .retro: "Retro"
        }
    }

    var symbol: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max"
        case .dark: "moon"
        case .retro: "terminal"
        }
    }
}

// MARK: - Retro Color

enum RetroColor: String, Codable, CaseIterable {
    case green
    case amber
    case blue
    case white
    case red
    case purple

    var label: String {
        switch self {
        case .green: "Green"
        case .amber: "Amber"
        case .blue: "Blue"
        case .white: "White"
        case .red: "Red"
        case .purple: "Purple"
        }
    }
}
