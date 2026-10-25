import Foundation

// MARK: - Parsed Task

/// A task worked out from plain words ("Run 3 times every week", "Groceries: milk, eggs").
/// Plain Swift with no AI framework in it: a parser fills it in, and the store adds it.
/// Only `AppleIntelligenceTaskParser` knows about Apple Intelligence, so another platform
/// (or no parser at all) can replace it without touching anything else.
struct ParsedTask: Equatable {
    var title: String
    var type: TaskType = .checkbox
    var mode: TaskMode = .oneTime
    /// A goal's target: minutes for time goals. Nil leaves the goal for the user to set.
    var goalTarget: Double?
    var goalKind: GoalUnitKind = .quantity
    /// A custom goal's unit ("pages").
    var goalUnit = ""
    /// A list's items.
    var items: [String] = []
}

/// Turns typed words into a task. Nil when the words can't be worked out, in which case
/// the text is added as a plain task.
protocol TaskTextParser {
    var isAvailable: Bool { get }
    /// Called when the user starts typing, so the first parse is quicker.
    func prepare()
    func parse(_ text: String) async throws -> ParsedTask?
}

extension ChecklistStore {
    /// Adds a parsed task, with its goal or list items, to a category of the viewed week
    /// in one save. With `weekStart`, only while that week is still the one viewed (the
    /// user may have moved on while the parser worked). Returns its ID.
    @discardableResult
    func addParsedTask(_ parsed: ParsedTask, categoryID: UUID, weekStart: DayKey? = nil) -> UUID? {
        let title = parsed.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, weekStart == nil || selectedWeek?.startDay == weekStart else { return nil }
        var task = ChecklistTask(title: title, mode: parsed.mode, taskType: parsed.type)
        switch parsed.type {
        case .goal:
            // The unit is kept even without an amount, ready for the target to be typed.
            task.goalUnitKind = parsed.goalKind
            task.goalUnit = parsed.goalKind == .custom && !parsed.goalUnit.isEmpty ? parsed.goalUnit : nil
            if let target = parsed.goalTarget, target.isFinite, target > 0 {
                task.goalTarget = min(target, GoalUnitKind.maxValue)
            }
        case .list:
            task.subtasks = parsed.items
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .map { SubTask(title: $0) }
        case .checkbox:
            break
        }
        return addTask(task, categoryID: categoryID)
    }
}

// MARK: - Text Hints

/// Plain rules for schedule phrases people type ("3x per week", "twice a week", "weekly",
/// "every Monday", "until it's done"). Smart Add checks them after the model and they win
/// when they match, since a small model can miss them. They only catch clear phrases;
/// anything else is left exactly as typed. No AI framework, so they work anywhere.
enum TaskTextHints {
    /// Corrects a parsed task from the words it came from. When a rule matched, the title
    /// loses the schedule and count; otherwise it's left as it was.
    static func refine(_ parsed: ParsedTask, from text: String) -> ParsedTask {
        var task = parsed
        let lower = text.lowercased()
        var matched = true
        if matchesAny(lower, oneTimePatterns) {
            task.mode = .oneTime
        } else if matchesAny(lower, repeatingPatterns) {
            task.mode = .repeating
        } else if matchesAny(lower, carryOverPatterns) {
            task.mode = .carryOver
        } else {
            matched = false
        }
        // "3x per week": a goal of 3, unless the parser already found a goal amount.
        if let count = weeklyCount(lower), task.type != .list,
           task.type != .goal || task.goalTarget == nil {
            task.type = .goal
            task.goalTarget = Double(count)
            task.goalKind = .quantity
            task.goalUnit = ""
            matched = true
        }
        if matched { task.title = cleanTitle(task.title, fallback: text) }
        // "Groceries: milk, eggs, bread": a list, unless the parser already found its items.
        if task.type != .goal, task.items.isEmpty, let list = colonList(text) {
            task.type = .list
            task.title = matched ? cleanTitle(list.title, fallback: list.title) : list.title
            task.items = list.items
        }
        return task
    }

    // MARK: Patterns

    private static let days = "day|morning|night|evening|weekday|weekend|monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|tues|wed|thu|thur|thurs|fri|sat|sun"
    private static let counts = #"(\d{1,3}\s*(x|times)|twice|once|(one|two|three|four|five|six|seven|eight|nine|ten)\s+times)"#
    private static let frequency = #"\s*(a|an|per|each|every|/)\s*(week|wk|day)\b"#

    private static let repeatingPatterns = [
        #"\b(every|each|per)\s+(week|wk)\b"#,
        #"\bweekly\b"#,
        #"\b"# + counts + frequency,
        #"\d\s*x?\s*/\s*(week|wk)\b"#,
        // Not "every other Tuesday": that's every second week.
        "\\bevery\\s+(\(days))s?\\b",
        "\\bon\\s+(\(days))s\\b",
        #"\b(daily|nightly|each day|every day)\b"#,
    ]

    private static let carryOverPatterns = [
        #"\b(until|till|til)\s+(it'?s\s+|it\s+is\s+)?(done|finished|sorted|complete|completed|fixed)\b"#,
    ]

    private static let oneTimePatterns = [
        #"\b(this|just this)\s+week\s+only\b"#,
        #"\bjust\s+this\s+week\b"#,
    ]

    /// How many times a week: "3x per week", "3 times a week", "twice a week", "3x/week",
    /// or a bare "3x"/"3 times" ending the text. Not per day ("twice a day" is a daily
    /// habit, not a weekly goal of 2) and not sizes like "4 x 6".
    private static func weeklyCount(_ text: String) -> Int? {
        let words = ["once": 1, "twice": 2, "one": 1, "two": 2, "three": 3, "four": 4, "five": 5,
                     "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10]
        guard let match = text.firstMatch(of: #/\b(\d{1,3}|once|twice|one|two|three|four|five|six|seven|eight|nine|ten)\s*(x|times)?(\s*(a|an|per|each|every|/)\s*(week|wk)\b|\s*$)/#)
        else { return nil }
        let word = String(match.1)
        let hasMultiplier = match.2 != nil   // "x" or "times"
        let hasFrequency = match.4 != nil    // "a week", "per week", "/week"
        // Digits and number words need "x"/"times"; once and twice don't.
        guard hasMultiplier || word == "once" || word == "twice" else { return nil }
        // Without "a week", only "3x"/"3 times" ending the text counts ("run 3x"), not a
        // bare "once" or "twice" ("measure twice, cut once").
        if !hasFrequency && (!hasMultiplier || word == "once" || word == "twice") { return nil }
        let count = Int(word) ?? words[word] ?? 0
        return count > 0 ? count : nil
    }

    private static func matchesAny(_ text: String, _ patterns: [String]) -> Bool {
        patterns.contains { text.range(of: $0, options: [.regularExpression, .caseInsensitive]) != nil }
    }

    /// Without the schedule and count ("run 3x per week" → "Run"), starting with a capital.
    static func cleanTitle(_ title: String, fallback: String) -> String {
        var result = title
        // Counts with their frequency first ("three times a week" leaves no "three").
        // Words that start a name ("Weekly report", "Daily standup") stay; they're only
        // removed at the end.
        let removals = [
            #"\b"# + counts + #"(\s*(a|an|per|each|every|/)\s*(week|wk|day))"#,
            #"\b\d{1,3}\s*(x|times)\s*$"#,
            #"\b(every|each|per)\s+(week|wk)\b"#,
            #"\d\s*x?\s*/\s*(week|wk)\b"#,
            "\\bevery\\s+(\(days))s?\\b",
            "\\bon\\s+(\(days))s\\b",
            #"\b(weekly|daily|nightly|each day|every day)\s*$"#,
        ] + carryOverPatterns + oneTimePatterns
        for pattern in removals {
            result = result.replacingOccurrences(of: pattern, with: " ", options: [.regularExpression, .caseInsensitive])
        }
        // Only spaces and stray separators are trimmed, so "C#" or "Q&A" keep their marks.
        result = result
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: " ,;:-–—"))
        if result.isEmpty {
            result = fallback.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return result.prefix(1).uppercased() + result.dropFirst()
    }

    /// A name, a colon, then two or more items split by commas: "Groceries: milk, eggs".
    /// Not a time ("Dentist 10:30, bring forms"), and not "and" lists ("Read: Pride and Prejudice").
    private static func colonList(_ text: String) -> (title: String, items: [String])? {
        guard let colon = text.firstIndex(of: ":") else { return nil }
        let before = text[..<colon].last, after = text[text.index(after: colon)...].first
        if before?.isNumber == true, after?.isNumber == true { return nil }
        let title = text[..<colon].trimmingCharacters(in: .whitespaces)
        let items = text[text.index(after: colon)...]
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !title.isEmpty, items.count >= 2 else { return nil }
        return (title.prefix(1).uppercased() + title.dropFirst(), items)
    }
}
