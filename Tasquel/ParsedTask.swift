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
    /// For an amount per day ("meditate 10 min daily"): the day's amount, as the goal's
    /// step, and the days a week it counts (`ChecklistTask.goalDays`).
    var goalStep: Double?
    var goalDays: Int?
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

/// Thrown by a parser that leaves the words alone: with no real word and no digit in
/// them ("asldkjlkd") there's nothing to read, so they're added as typed.
enum TaskTextParserError: Error {
    case noRealWords
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
                // A day's amount steps the goal a day at a time ("8 glasses a day" is
                // 56 by 8, which the automatic ÷ 7 would also get; "on weekdays", by 5 days,
                // wouldn't).
                if let step = parsed.goalStep, step.isFinite, step > 0 {
                    task.goalStep = min(step, GoalUnitKind.maxValue)
                    task.goalDays = parsed.goalDays.flatMap { (1...7).contains($0) ? $0 : nil }
                }
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

/// Plain rules for schedule phrases people type ("3x per week", "3 days a week", "weekly",
/// "every Monday", "Mon, Wed, Fri", "on weekends", "tomorrow", "until it's done",
/// "sometime"). Smart Add checks them after the model and they win when they match, since a
/// small model can miss them. They only catch clear phrases; anything else is left exactly
/// as typed. No AI framework, so they work anywhere.
enum TaskTextHints {
    /// Corrects a parsed task from the words it came from. When a rule matched, the title
    /// loses the schedule and count; otherwise it's left as it was.
    static func refine(_ parsed: ParsedTask, from text: String) -> ParsedTask {
        var task = parsed
        let lower = text.lowercased()
        var matched = true
        if let mode = scheduleMode(lower) ?? scheduleMode(withoutAmount(lower)) {
            task.mode = mode
        } else {
            matched = false
        }
        // A "Name: a, b" list wins over counts ("Daily habits: water, walk" is a list).
        let list = colonList(text)
        // "Meditate 10 min daily": the week's total, 70 minutes, even if the parser found
        // the day's amount.
        if list == nil, task.type != .list, let daily = dailyAmount(lower) {
            task.type = .goal
            task.goalTarget = daily.value
            task.goalKind = daily.kind
            task.goalUnit = daily.unit
            task.goalStep = daily.perDay
            task.goalDays = daily.days
            // "10 min a day" is a schedule too.
            if !matched { task.mode = .repeating }
            task.title = title(task.title, without: daily.phrase, unit: daily.unit)
            matched = true
        }
        // "3x per week": a goal of 3, "daily" one of 7, unless the parser already found an amount.
        if list == nil, let count = goalCount(lower), task.type != .list,
           task.type != .goal || task.goalTarget == nil {
            task.type = .goal
            task.goalTarget = Double(count)
            task.goalKind = .quantity
            task.goalUnit = ""
            matched = true
        }
        if matched { task.title = cleanTitle(task.title, fallback: text) }
        // "Read 90 pages", "Practice piano 2 hours": a goal of that amount, unless one was found.
        if list == nil, task.type != .list, task.type != .goal || task.goalTarget == nil,
           let amount = unitAmount(lower) {
            task.type = .goal
            task.goalTarget = amount.value
            task.goalKind = amount.kind
            task.goalUnit = amount.unit
            let phrase = (amount.kind == .time ? #"(\bfor\s+)?"# : "") + NSRegularExpression.escapedPattern(for: amount.phrase)
            task.title = title(task.title, without: phrase, unit: amount.unit)
        }
        // "Groceries: milk, eggs, bread": a list, unless the parser already found its items.
        if task.type != .goal || task.goalTarget == nil, task.items.isEmpty, let list {
            task.type = .list
            task.title = matched ? cleanTitle(list.title, fallback: list.title) : list.title
            task.items = list.items
        }
        return task
    }

    /// The words without their amount, so a schedule just before it still reads as ending
    /// the words ("gym mon, wed, fri 1 hour" → "gym mon, wed, fri").
    private static func withoutAmount(_ text: String) -> String {
        guard let amount = unitAmount(text), let at = text.range(of: amount.phrase) else { return text }
        return text.replacingCharacters(in: at, with: " ")
    }

    /// The title without an amount (a pattern), and what's left cleaned up. "Do 50 pushups"
    /// is better titled "Pushups" than "Do".
    private static func title(_ title: String, without phrase: String, unit: String) -> String {
        let stripped = title.replacingOccurrences(of: phrase, with: " ", options: [.regularExpression, .caseInsensitive])
        let cleaned = cleanTitle(stripped, fallback: title)
        let filler: Set<String> = ["do", "make", "get", "go", "have", "complete", "finish", "hit"]
        guard !unit.isEmpty, filler.contains(cleaned.lowercased()) else { return cleaned }
        return unit.prefix(1).uppercased() + unit.dropFirst()
    }

    /// An amount for each day of a schedule, as the week's total: "meditate 10 min daily" is
    /// 70 minutes, "read 20 pages on weekdays" 100 pages, "drink 8 glasses of water a day"
    /// 56 glasses. `phrase` is a pattern for the amount (and "a day") in the title. Not
    /// with a count ("take 2 pills twice a day" is left to the count).
    static func dailyAmount(_ text: String) -> (value: Double, kind: GoalUnitKind, unit: String, phrase: String, perDay: Double, days: Int)? {
        guard let amount = unitAmount(text), weeklyCount(text) == nil, dailyCount(text) == nil,
              let at = text.range(of: amount.phrase) else { return nil }
        // "For 30 minutes" goes with its amount ("Read for 30 minutes daily" is "Read").
        var phrase = (amount.kind == .time ? #"(\bfor\s+)?"# : "") + NSRegularExpression.escapedPattern(for: amount.phrase)
        // The days around the amount: "Gym Mon, Wed, Fri 1 hour" too.
        var days = daysPerWeek(text.replacingCharacters(in: at, with: " "))
        // "10 min a day", "8 glasses of water a day", "8 hours a night": "a day" right after
        // the amount (and what it's of), not "run 5 km in a day".
        let gap = amount.phrase.hasSuffix(" of") ? #"([a-z'’-]+\s+)?"# : ""
        if text[at.upperBound...].range(of: #"^\s+"# + gap + #"(a|per)\s+(day|night)\b"#, options: .regularExpression) != nil {
            days = days ?? 7
            phrase += #"|\b(a|per)\s+(day|night)\b"#
        }
        guard let days else { return nil }
        return (min(amount.value * Double(days), GoalUnitKind.maxValue), amount.kind, amount.unit, phrase, amount.value, days)
    }

    /// An amount with its unit: "90 pages" (a goal of 90 pages), "2 hours" or "45 min"
    /// (a time goal, in minutes). Not dates or times ("at 3 today", "in 2 days").
    static func unitAmount(_ text: String) -> (value: Double, kind: GoalUnitKind, unit: String, phrase: String)? {
        for match in text.matches(of: #/\b(\d+(?:[.,]\d+)?)\s*(hours|hour|hrs|hr|h|minutes|minute|mins|min)\b/#) {
            // When, not how long: "call back in 2 hours", "leave in 10 min".
            let before = text[..<match.range.lowerBound]
            guard before.range(of: #"\b(in|at|by|before|after|until|till|from|within)\s*$"#, options: .regularExpression) == nil,
                  let number = Double(match.1.replacingOccurrences(of: ",", with: ".")), number > 0 else { continue }
            let minutes = match.2.hasPrefix("h") ? number * 60 : number
            return (min(minutes, GoalUnitKind.maxValue), .time, "", String(match.0))
        }
        let skip: Set<String> = ["am", "pm", "times", "time", "today", "tomorrow", "tonight", "day", "days",
                                 "week", "weeks", "month", "months", "year", "years", "oclock", "and", "or", "to"]
        let units: Set<String> = ["km", "kg", "lb", "lbs", "mi", "k", "ml", "oz"]
        for match in text.matches(of: #/(?:^|\s)(?:(at|on|in|by|before|after|until|from)\s+)?(\d{1,6})\s+([a-z][a-z'’-]{1,})/#) {
            guard match.1 == nil, let number = Double(match.2), number > 0 else { continue }
            // Not a size ("4 x 6 photos").
            let before = text[..<match.range.lowerBound].trimmingCharacters(in: .whitespaces)
            guard !before.hasSuffix("x"), !before.hasSuffix("×") else { continue }
            let unit = String(match.3)
            guard !skip.contains(unit.replacingOccurrences(of: "'", with: "")) else { continue }
            // Something counted: a plural ("90 pages"), one of something ("1 chapter"), or a
            // unit ("5 km"); not a label ("Room 101 cleanup").
            guard unit.count > 2 && unit.hasSuffix("s") || number == 1 || units.contains(unit) else { continue }
            // "8 glasses of water": the title keeps "water" ("Drink water").
            let after = text[match.range.upperBound...]
            let phrase = after.hasPrefix(" of ") ? "\(match.2) \(unit) of" : "\(match.2) \(unit)"
            return (min(number, GoalUnitKind.maxValue), .custom, unit, phrase)
        }
        return nil
    }

    /// Takes out what a model made up: a goal amount when the words hold no number at all,
    /// in digits or words, and no frequency ("Rhythm" isn't a 10-minute goal; it's a plain
    /// task), a mode when nothing in the words gives one (gibberish came back repeating),
    /// and list items that aren't in the words. A list stays a list even with no items left
    /// ("Groceries" is a list to fill in).
    static func dropInvented(_ parsed: ParsedTask, from text: String) -> ParsedTask {
        var task = parsed
        let lower = text.lowercased()
        if task.type == .goal, !hasAmount(lower), goalCount(lower) == nil {
            task.goalTarget = nil
            task.goalStep = nil
            task.goalDays = nil
            task.type = .checkbox
        }
        // `refine` runs after, so a schedule it reads still wins.
        if task.mode != .oneTime, !hasScheduleCue(lower) {
            task.mode = .oneTime
        }
        let words = loose(lower)
        task.items = task.items.filter { item in
            let wanted = loose(item.lowercased()).trimmingCharacters(in: .whitespaces)
            // "eggs" for "egg" and the other way round.
            let singular = wanted.replacingOccurrences(of: #"(es|s)$"#, with: "", options: .regularExpression)
            return !wanted.isEmpty && (words.contains(wanted) || (singular.count > 2 && words.contains(singular)))
        }
        return task
    }

    /// Something in the words that gives a mode: a phrase the rules read ("weekly", "Mon,
    /// Wed, Fri", "tomorrow", "sometime"), or a word like "again" or "habit" that the
    /// model can go by.
    private static func hasScheduleCue(_ text: String) -> Bool {
        scheduleMode(text) != nil || dailyAmount(text) != nil
            || text.contains(#/\b(again|regularly|routines?|habits?|ongoing|keep|keeps|keeping|monthly)\b/#)
            || text.contains(#/\bevery\s+([2-6]|two|three|four|five|six|other)\s+days\b/#)
    }

    /// Digits, or an amount in words: "fifteen minutes", "a dozen", "half an hour", "a mile".
    private static func hasAmount(_ text: String) -> Bool {
        if text.contains(where: \.isNumber) { return true }
        let numberWords = #/\b(once|twice|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|twenty|thirty|forty|fifty|sixty|seventy|eighty|ninety|hundred|thousand|dozen|couple|few|several|half|quarter)\b/#
        let oneUnit = #/\b(a|an)\s+(minute|hour|mile|kilometer|km|page|chapter|lap|set|rep|glass|cup|day)\b/#
        return text.contains(numberWords) || text.contains(oneUnit)
    }

    /// Lowercased text with accents and curly quotes folded, for loose matching.
    private static func loose(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "‘", with: "'")
    }

    // MARK: Patterns

    private static let days = "day|morning|night|evening|weekday|weekend|monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|tues|wed|thu|thur|thurs|fri|sat|sun"
    /// `days` without plain "day", for "on …s": "on Mondays", "on weekends", not "on days off".
    private static let namedDays = "morning|night|evening|weekday|weekend|monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|tues|wed|thu|thur|thurs|fri|sat|sun"
    private static let counts = #"(\d{1,3}\s*(x|times)|twice|once|(one|two|three|four|five|six|seven|eight|nine|ten)\s+times)"#
    private static let frequency = #"\s*(a|an|per|each|every|/)\s*(week|wk|day)\b"#

    /// A weekday's name, full or short, one or many ("Monday", "Mondays", "Mon"); not a
    /// possessive ("Monday's meeting").
    private static let weekday = #"(?:(?:monday|tuesday|wednesday|thursday|friday|saturday|sunday)s?|mon|tue|tues|wed|thu|thur|thurs|fri|sat|sun)(?![a-z'’])"#
    /// One weekday, in full ("on Friday"; not "on Fridays" or "on Fri").
    private static let oneWeekday = #"(?:monday|tuesday|wednesday|thursday|friday|saturday|sunday)(?![a-z'’])"#
    /// Two or more weekdays: "Mondays and Thursdays", "Mon, Wed, Fri", "Tue/Thu".
    private static let weekdayList = weekday + #"(?:(?:\s*,\s*(?:(?:and|&)\s+)?|\s+and\s+|\s*&\s*|\s*/\s*)"# + weekday + ")+"
    /// A list of days after "on", "every" or "each", or ending the words.
    private static let weekdayListPatterns = [
        #"\b(?:on|every|each)\s+"# + weekdayList,
        #"\b"# + weekdayList + #"\s*$"#,
    ]
    /// "3 days a week", "5 days per week", "3 days/week".
    private static let daysAWeek = #"\b([1-7]|one|two|three|four|five|six|seven)\s+days?(?:\s+(?:a|per|each|every)\s+|\s*/\s*)(?:week|wk)\b"#
    /// "On weekends", "every weekend", or "weekends" ending the words.
    private static let weekends = #"\b(?:on\s+weekends\b|(?:every|each)\s+weekend\b|weekends\s*$)"#
    /// "Every day", "each morning": a day of the week, every week.
    private static let daily = #"\b(daily|nightly|each day|every day|(every|each) (night|morning|evening))\b"#

    private static let repeatingPatterns = [
        #"\b(every|each|per)\s+(week|wk)\b"#,
        #"\bweekly\b"#,
        #"\b"# + counts + frequency,
        #"\d\s*x?\s*/\s*(week|wk)\b"#,
        daysAWeek,
        // Not "every other Tuesday": that's every second week.
        "\\b(every|each)\\s+(\(days))s?\\b",
        "\\bon\\s+(\(namedDays))s\\b",
        #"\b(daily|nightly|each day|every day|weekdays)\b"#,
        weekends,
    ] + weekdayListPatterns

    /// "Until it's done", anywhere in the words.
    private static let untilDone = #"\b(until|till|til)\s+(it'?s\s+|it\s+is\s+)?(done|finished|sorted|complete|completed|fixed)\b"#
    /// "No rush", "sometime", "when I get a chance": no set week, so it stays until done.
    private static let noSetTime = #"\b(no\s+rush|sometime|someday|whenever|eventually|when(ever)?\s+i\s+(can|get\s+a\s+chance))\b"#
    private static let carryOverPatterns = [untilDone, noSetTime]

    private static let oneTimePatterns = [
        #"\b(this|just this)\s+week\s+only\b"#,
        #"\bjust\s+this\s+week\b"#,
    ]

    /// A day of this week: "today", "tonight", "tomorrow", "this weekend", "this Friday",
    /// "on Friday" (but "on Fridays" repeats). Weaker than the other rules: "run daily
    /// starting tomorrow" repeats.
    private static let oneTimeDayPatterns = [
        #"\b(today|tonight|tomorrow)\b"#,
        #"\bthis\s+(?:weekend\b|"# + oneWeekday + ")",
        #"\bon\s+"# + oneWeekday,
    ]

    /// The mode the words give, if a rule reads one. "This week only" wins, then a
    /// repeating schedule, then carry-over, then a day of this week.
    private static func scheduleMode(_ text: String) -> TaskMode? {
        if matchesAny(text, oneTimePatterns) { return .oneTime }
        if matchesAny(text, repeatingPatterns) { return .repeating }
        if matchesAny(text, carryOverPatterns) { return .carryOver }
        if matchesAny(text, oneTimeDayPatterns) { return .oneTime }
        return nil
    }

    /// How many times a week, as a goal: a weekly count ("3x per week"), a daily one
    /// ("twice a day" is 14), days a week ("3 days a week"), a daily habit ("meditate
    /// daily" is 7, so it's ticked off each day, not once a week), a list of days ("Mon,
    /// Wed, Fri" is 3), weekdays (5) or weekends (2). Nil when the words give no count.
    static func goalCount(_ text: String) -> Int? {
        let weekly = weeklyCount(text)
        if let weekly, weekly.hasFrequency { return weekly.count }
        if let perDay = dailyCount(text) { return perDay * 7 }
        if let days = daysAWeekCount(text) { return days }
        if matchesAny(text, [daily]) {
            return (weekly?.count ?? 1) * 7  // "stretch daily 2x" is 14
        }
        if let weekly { return weekly.count }  // a bare "3x" ending the text
        if let days = weekdayListCount(text) { return days }
        if text.contains(#/\b(weekdays|every weekday|each weekday)\b/#) { return 5 }
        if matchesAny(text, [weekends]) { return 2 }
        return nil
    }

    /// How many days a week the words name: "3 days a week", a list of days, daily (7),
    /// weekdays (5), weekends (2) or one day ("every Monday", "on Mondays"). Nil otherwise.
    static func daysPerWeek(_ text: String) -> Int? {
        if let days = daysAWeekCount(text) ?? weekdayListCount(text) { return days }
        if matchesAny(text, [daily]) { return 7 }
        if text.contains(#/\b(weekdays|every weekday|each weekday)\b/#) { return 5 }
        if matchesAny(text, [weekends]) { return 2 }
        if matchesAny(text, [#"\b(?:every|each)\s+"# + weekday, #"\bon\s+(?:monday|tuesday|wednesday|thursday|friday|saturday|sunday)s\b"#]) { return 1 }
        return nil
    }

    /// "3 days a week" is 3.
    private static func daysAWeekCount(_ text: String) -> Int? {
        guard let range = text.range(of: daysAWeek, options: [.regularExpression, .caseInsensitive]),
              let number = text[range].split(separator: " ").first else { return nil }
        let words = ["one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7]
        return Int(number) ?? words[String(number).lowercased()]
    }

    /// "Mondays and Thursdays" is 2, "Mon, Wed, Fri" 3.
    private static func weekdayListCount(_ text: String) -> Int? {
        let list = weekdayListPatterns.lazy
            .compactMap { text.range(of: $0, options: [.regularExpression, .caseInsensitive]) }
            .first.map { String(text[$0]).lowercased() }
        guard let list, let names = try? NSRegularExpression(pattern: #"\b"# + weekday) else { return nil }
        let found = names.matches(in: list, range: NSRange(list.startIndex..., in: list))
            .compactMap { Range($0.range, in: list).map { list[$0].prefix(3) } }
        let count = Set(found).count
        return count >= 2 ? count : nil
    }

    /// "Twice a day", "3x a day", "3 times per day", "twice daily", "2x nightly".
    private static func dailyCount(_ text: String) -> Int? {
        let words = ["once": 1, "twice": 2, "one": 1, "two": 2, "three": 3, "four": 4, "five": 5]
        guard let match = text.firstMatch(of: #/\b(\d{1,2}|once|twice|one|two|three|four|five)\s*(x|times)?\s*((a|per|each|every|/)\s*day|daily|nightly)\b/#)
        else { return nil }
        let word = String(match.1)
        guard match.2 != nil || word == "once" || word == "twice" else { return nil }
        let count = Int(word) ?? words[word] ?? 0
        return count > 0 ? count : nil
    }

    /// How many times a week: "3x per week", "3 times a week", "twice a week", "3x/week"
    /// (`hasFrequency`), or a bare "3x"/"3 times" ending the text. Not sizes like "4 x 6".
    private static func weeklyCount(_ text: String) -> (count: Int, hasFrequency: Bool)? {
        let words = ["once": 1, "twice": 2, "one": 1, "two": 2, "three": 3, "four": 4, "five": 5,
                     "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10]
        guard let match = text.firstMatch(of: #/\b(\d{1,3}|once|twice|one|two|three|four|five|six|seven|eight|nine|ten)\s*(x|times)?(\s*(a|an|per|each|every|/)\s*(week|wk)\b|\s+weekly\b|\s*$)/#)
        else { return nil }
        let word = String(match.1)
        let hasMultiplier = match.2 != nil   // "x" or "times"
        // "a week", "per week", "/week", "weekly"
        let hasFrequency = !match.3.trimmingCharacters(in: .whitespaces).isEmpty
        // Digits and number words need "x"/"times"; once and twice don't.
        guard hasMultiplier || word == "once" || word == "twice" else { return nil }
        // Without "a week", only "3x"/"3 times" ending the text counts ("run 3x"), not a
        // bare "once" or "twice" ("measure twice, cut once").
        if !hasFrequency && (!hasMultiplier || word == "once" || word == "twice") { return nil }
        let count = Int(word) ?? words[word] ?? 0
        return count > 0 ? (count, hasFrequency) : nil
    }

    private static func matchesAny(_ text: String, _ patterns: [String]) -> Bool {
        patterns.contains { text.range(of: $0, options: [.regularExpression, .caseInsensitive]) != nil }
    }

    /// Without the schedule and count ("run 3x per week" → "Run"), starting with a capital.
    static func cleanTitle(_ title: String, fallback: String) -> String {
        var result = title
        // Counts with their frequency first ("three times a week" leaves no "three").
        // Words that start a name ("Weekly report", "Daily standup") stay; they're only
        // removed at the end. So are days of this week and "sometime" ("Friday team lunch"
        // keeps its name).
        let removals = [
            #"\b"# + counts + #"(\s*(a|an|per|each|every|/)\s*(week|wk|day)|\s+(daily|nightly|weekly))"#,
            daysAWeek,
            #"\b\d{1,3}\s*(x|times)\s*$"#,
            #"\b(every|each|per)\s+(week|wk)\b"#,
            #"\d\s*x?\s*/\s*(week|wk)\b"#,
        ] + weekdayListPatterns + [
            "\\b(every|each)\\s+(\(days))s?\\b",
            "\\bon\\s+(\(namedDays))s\\b",
            #"\b(weekly|daily|nightly|each day|every day)\s*$"#,
            #"\b(on\s+)?weekdays\s*$"#,
            #"\bweekends\s*$"#,
            #"\b(no\s+rush|sometime|someday|eventually|when(ever)?\s+i\s+(can|get\s+a\s+chance)|whenever)\s*$"#,
            #"\b((by|before|until|till|til|for)\s+)?(today|tonight|tomorrow|this\s+weekend|(this|on)\s+"# + oneWeekday + #")\s*$"#,
            untilDone,
        ] + oneTimePatterns
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
