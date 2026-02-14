import Foundation

struct ChecklistTask: Codable, Identifiable {
    var id = UUID()
    var title: String
    var isCompleted: Bool = false
}

struct Category: Codable, Identifiable {
    var id = UUID()
    var name: String
    var tasks: [ChecklistTask] = []
}

struct Week: Codable, Identifiable {
    var id = UUID()
    var startDate: Date
    var categories: [Category] = []

    var displayTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d/yy"
        return "Week of \(formatter.string(from: startDate))"
    }

    static func mondayOfWeek(containing date: Date) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        components.weekday = 2 // Monday
        return calendar.date(from: components) ?? date
    }
}
