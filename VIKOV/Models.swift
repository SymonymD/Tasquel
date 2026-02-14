import Foundation

// MARK: - Task Mode

enum TaskMode: String, Codable, CaseIterable {
    case carryOver
    case repeating

    var label: String {
        switch self {
        case .carryOver: "Carry Over"
        case .repeating: "Repeating"
        }
    }

    var symbol: String {
        switch self {
        case .carryOver: "arrow.uturn.forward"
        case .repeating: "repeat"
        }
    }
}

// MARK: - Models

struct ChecklistTask: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var isCompleted: Bool = false
    var mode: TaskMode = .carryOver
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

    static func mondayOfWeek(containing date: Date) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        components.weekday = 2
        return calendar.date(from: components) ?? date
    }
}

// MARK: - Default Categories

extension Category {
    static let starters: [Category] = [
        Category(name: "Errands", symbol: "cart"),
        Category(name: "Work", symbol: "briefcase"),
        Category(name: "Fitness", symbol: "figure.run"),
        Category(name: "Study", symbol: "book"),
        Category(name: "Appointments", symbol: "calendar.badge.clock"),
    ]
}
