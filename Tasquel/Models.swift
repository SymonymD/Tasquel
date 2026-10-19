import Foundation

// MARK: - Task Mode

enum TaskMode: String, Codable, CaseIterable {
    case carryOver
    case repeating
    /// This week only.
    case oneTime

    /// Menu order: this week only, then the two that reach into later weeks.
    static let ordered: [TaskMode] = [.oneTime, .carryOver, .repeating]

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
        case .oneTime: "This week only, doesn't come back"
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

// MARK: - Day

/// A calendar date with no time of day or time zone, saved as "2026-10-19". Weeks are
/// identified by the day they start, so changing time zones can't move a week onto
/// another day (an exact midnight in New York is still Sunday evening in California).
struct DayKey: Hashable, Comparable, Codable, CustomStringConvertible {
    let year: Int
    let month: Int
    let day: Int

    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// The day `date` falls on in `calendar`'s time zone.
    init(_ date: Date, in calendar: Calendar) {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: parts.year ?? 1, month: parts.month ?? 1, day: parts.day ?? 1)
    }

    /// Midnight at the start of this day in `calendar`'s time zone.
    func date(in calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
    }

    /// The day `days` later (or earlier), by the calendar, not by 24-hour steps.
    func adding(days: Int) -> DayKey {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let moved = calendar.date(byAdding: .day, value: days, to: date(in: calendar)) ?? date(in: calendar)
        return DayKey(moved, in: calendar)
    }

    static func < (lhs: DayKey, rhs: DayKey) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    var description: String { String(format: "%04d-%02d-%02d", year, month, day) }

    init(from decoder: Decoder) throws {
        let text = try decoder.singleValueContainer().decode(String.self)
        let parts = text.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Expected yyyy-MM-dd, got \(text)"))
        }
        self.init(year: parts[0], month: parts[1], day: parts[2])
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}

extension CodingUserInfoKey {
    /// The calendar a decoder uses to turn a saved week's old `startDate` into its day.
    static let weekCalendar = CodingUserInfoKey(rawValue: "weekCalendar")!
}

struct Week: Codable, Identifiable, Equatable {
    var id = UUID()
    /// The day the week starts on. This, not a moment in time, identifies the week.
    var startDay: DayKey
    var categories: [Category] = []
    /// Carry-over tasks (by their source's ID) the user deleted from this week, so
    /// syncing with the week before doesn't bring them back.
    var dismissedCarryOvers: [UUID]? = nil
    /// Repeating tasks (by title) the user deleted from this week, so syncing with the
    /// week before doesn't bring them back.
    var dismissedRepeating: [String]? = nil

    init(id: UUID = UUID(), startDay: DayKey, categories: [Category] = []) {
        self.id = id
        self.startDay = startDay
        self.categories = categories
    }

    /// A week starting on the day `startDate` falls on in the current time zone.
    init(id: UUID = UUID(), startDate: Date, categories: [Category] = []) {
        self.init(id: id, startDay: DayKey(startDate, in: .current), categories: categories)
    }

    /// Midnight at the start of the week, in the current time zone.
    var startDate: Date { startDay.date(in: .current) }

    var displayTitle: String {
        "Week of \(startDay.month)/\(startDay.day)/\(String(format: "%02d", startDay.year % 100))"
    }

    private enum CodingKeys: String, CodingKey {
        case id, startDay, startDate, categories, dismissedCarryOvers, dismissedRepeating
    }

    /// Weeks saved before `startDay` existed only have `startDate`, a moment; their day
    /// is worked out in the decoder's calendar (the current time zone) on first load.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        if let day = try container.decodeIfPresent(DayKey.self, forKey: .startDay) {
            startDay = day
        } else {
            let calendar = decoder.userInfo[.weekCalendar] as? Calendar ?? .current
            startDay = DayKey(try container.decode(Date.self, forKey: .startDate), in: calendar)
        }
        categories = try container.decode([Category].self, forKey: .categories)
        dismissedCarryOvers = try container.decodeIfPresent([UUID].self, forKey: .dismissedCarryOvers)
        dismissedRepeating = try container.decodeIfPresent([String].self, forKey: .dismissedRepeating)
    }

    /// Also writes `startDate`, so an older build of the app can still open the file.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(startDay, forKey: .startDay)
        try container.encode(startDate, forKey: .startDate)
        try container.encode(categories, forKey: .categories)
        try container.encodeIfPresent(dismissedCarryOvers, forKey: .dismissedCarryOvers)
        try container.encodeIfPresent(dismissedRepeating, forKey: .dismissedRepeating)
    }

    // Whether a week is past, current or future depends on today, so the store answers
    // it (`isPastWeek(_:)` etc.), using a clock tests can control.

    /// Calendar weekday numbers for the supported week start days.
    static let sunday = 1
    static let monday = 2

    /// Start (midnight) of the week containing `date`. `firstWeekday` is 1 for
    /// Sunday or 2 for Monday; the store passes the user's setting.
    static func startOfWeek(containing date: Date, firstWeekday: Int = monday, calendar: Calendar = .current) -> Date {
        var calendar = calendar
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
