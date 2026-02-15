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

    var completedCount: Int { tasks.filter(\.isCompleted).count }
    var totalCount: Int { tasks.count }
}

struct Week: Codable, Identifiable, Equatable {
    var id = UUID()
    var startDate: Date
    var categories: [Category] = []

    var displayTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return "Week of \(formatter.string(from: startDate))"
    }

    var isCurrentWeek: Bool {
        Calendar.current.isDate(startDate, inSameDayAs: Week.mondayOfWeek(containing: Date()))
    }

    var isFutureWeek: Bool {
        startDate > Date()
    }

    var isPastWeek: Bool {
        !isCurrentWeek && !isFutureWeek
    }

    static func mondayOfWeek(containing date: Date) -> Date {
        var calendar = Calendar.current
        calendar.firstWeekday = 2  // Monday-based weeks
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        components.weekday = 2
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

    var label: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var symbol: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max"
        case .dark: "moon"
        }
    }
}
