import Foundation

// MARK: - Task Mode

enum TaskMode: String, Codable, CaseIterable {
    case carryOver
    case repeating
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

    var label: String {
        switch self {
        case .checkbox: "Checkbox"
        case .goal: "Goal"
        }
    }

    var symbol: String {
        switch self {
        case .checkbox: "checkmark.circle"
        case .goal: "target"
        }
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

    var allSubtasksCompleted: Bool {
        subtasks.allSatisfy(\.isCompleted)
    }

    var completedSubtaskCount: Int {
        subtasks.filter(\.isCompleted).count
    }

    var goalFraction: String {
        let progress = goalProgress ?? 0
        let target = goalTarget ?? 0
        return "\(Int(progress))/\(Int(target))"
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
