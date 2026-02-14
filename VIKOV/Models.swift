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
