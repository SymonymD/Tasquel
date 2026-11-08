import Foundation
import FoundationModels
import UIKit

// MARK: - Apple Intelligence Task Parser

/// Works out a task from plain words with the on-device Apple Intelligence model: free,
/// private and offline, on devices that have Apple Intelligence turned on. The only file
/// that uses Foundation Models; everything else sees a `TaskTextParser` and a `ParsedTask`.
final class AppleIntelligenceTaskParser: TaskTextParser {
    static let shared = AppleIntelligenceTaskParser()

    /// A session made ahead of time (see `prepare`). Each parse uses a fresh one, so the
    /// transcript never grows.
    private var preparedSession: LanguageModelSession?

    var isAvailable: Bool {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else { return false }
        let language = Locale.current.language.languageCode
        return model.supportedLanguages.contains { $0.languageCode == language }
    }

    func prepare() {
        guard isAvailable, preparedSession == nil else { return }
        let session = Self.makeSession()
        session.prewarm()
        preparedSession = session
    }

    func parse(_ text: String) async throws -> ParsedTask? {
        guard isAvailable else { return nil }
        return try await Self.parse(text) { text in
            let session = preparedSession ?? Self.makeSession()
            preparedSession = nil
            // Greedy sampling: the same words give the same task.
            let response = try await session.respond(
                to: "Note: \(text)",
                generating: TaskDraft.self,
                options: GenerationOptions(sampling: .greedy)
            )
            return response.content.parsedTask(fallbackTitle: text)
        }
    }

    /// What `model` makes of the words, checked by the rules. Words with no real word and no
    /// digit ("asldkjlkd") don't go to the model, which gave them a made-up schedule: it
    /// throws `TaskTextParserError.noRealWords`, and they're added as typed.
    static func parse(_ text: String, model: (String) async throws -> ParsedTask) async throws -> ParsedTask {
        guard hasRealWords(text) else { throw TaskTextParserError.noRealWords }
        let parsed = TaskTextHints.dropInvented(try await model(text), from: text)
        return fixingTypos(TaskTextHints.refine(parsed, from: text), typed: text)
    }

    /// A digit, or a word the system spell checker knows.
    static func hasRealWords(_ text: String) -> Bool {
        if text.contains(where: \.isNumber) { return true }
        let checker = UITextChecker()
        let language = spellingLanguage
        let words = text as NSString
        var found = false
        words.enumerateSubstrings(in: NSRange(location: 0, length: words.length), options: .byWords) { _, range, _, stop in
            let miss = checker.rangeOfMisspelledWord(in: text, range: range, startingAt: range.location, wrap: false, language: language)
            if miss.location == NSNotFound {
                found = true
                stop.pointee = true
            }
        }
        return found
    }

    // MARK: Spelling

    /// A backstop for the model: the system spell checker corrects a word in the title or
    /// unit when its first suggestion is a close match ("pishups" → "pushups"). Words the
    /// user capitalised (names) and short words are left alone.
    static func fixingTypos(_ parsed: ParsedTask, typed: String) -> ParsedTask {
        var task = parsed
        // Words typed with a capital (names, or the first word) are kept as typed.
        let capitalised = Set(typed.split(separator: " ").filter { $0.first?.isUppercase == true }
            .map { $0.trimmingCharacters(in: .punctuationCharacters).lowercased() })
        let fix = { (text: String) in
            text.split(separator: " ", omittingEmptySubsequences: false).map { word -> String in
                let word = String(word)
                let key = word.trimmingCharacters(in: .punctuationCharacters).lowercased()
                return capitalised.contains(key) ? word : corrected(word)
            }.joined(separator: " ")
        }
        task.title = fix(task.title)
        task.goalUnit = fix(task.goalUnit)
        return task
    }

    private static func corrected(_ word: String) -> String {
        let letters = word.trimmingCharacters(in: .punctuationCharacters)
        guard letters.count >= 4, letters.allSatisfy(\.isLetter) else { return word }
        let checker = UITextChecker()
        let language = spellingLanguage
        let range = NSRange(location: 0, length: (letters as NSString).length)
        let miss = checker.rangeOfMisspelledWord(in: letters, range: range, startingAt: 0, wrap: false, language: language)
        guard miss.location != NSNotFound,
              let guess = checker.guesses(forWordRange: miss, in: letters, language: language)?.first,
              !guess.contains(" "), guess.lowercased().first == letters.lowercased().first,
              editDistance(guess.lowercased(), letters.lowercased()) <= 2 else { return word }
        // Keep the typed capitalisation of the first letter.
        let fixed = letters.first?.isUppercase == true ? guess.prefix(1).uppercased() + guess.dropFirst() : guess
        return word.replacingOccurrences(of: letters, with: fixed)
    }

    /// The spell checker's language for the user's.
    private static var spellingLanguage: String {
        UITextChecker.availableLanguages.first { $0.hasPrefix(Locale.current.language.languageCode?.identifier ?? "en") } ?? "en_US"
    }

    private static func editDistance(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        var row = Array(0...b.count)
        for i in 1...max(a.count, 1) where !a.isEmpty {
            var previous = row[0]
            row[0] = i
            for j in 1...max(b.count, 1) where !b.isEmpty {
                let current = row[j]
                row[j] = min(row[j] + 1, row[j - 1] + 1, previous + (a[i - 1] == b[j - 1] ? 0 : 1))
                previous = current
            }
        }
        return row[b.count]
    }

    private static func makeSession() -> LanguageModelSession {
        // Kept plain and everyday: the system safety check reads these too, and an
        // example like "call the bank" got every request refused as regulated content.
        LanguageModelSession(instructions: """
            Turn a short note into one task for a weekly checklist.
            Title: short, in the note's own words, without the schedule, amount or items.
            Kind: checkbox for one thing to do; goal for an amount to reach; list when several items are named.
            Recurrence: repeating when the note says how often, like "3x per week", "weekly", "every Monday" or "on weekends"; \
            carryOver when it should stay until done or has no set time, like "sometime" or "no rush"; \
            otherwise oneTime, as for one day, like "tomorrow" or "on Friday".
            Never add amounts or items that aren't in the note.
            Fix obvious spelling mistakes in the title and unit, but keep names as written.
            Examples:
            "gym 3x per week" -> Gym, goal, repeating, amount 3, unit count.
            "Read 20 pages" -> Read, goal, oneTime, amount 20, unit named, unitName pages.
            "Practice piano 2 hours" -> Practice piano, goal, oneTime, amount 120, unit minutes.
            "Groceries: milk, eggs" -> Groceries, list, oneTime, items milk and eggs.
            "Water plants weekly" -> Water plants, checkbox, repeating.
            "Meditate daily" -> Meditate, goal, repeating, amount 7, unit count.
            "Meditate 10 min daily" -> Meditate, goal, repeating, amount 70, unit minutes.
            "Stretch every weekday" -> Stretch, goal, repeating, amount 5, unit count.
            "Yoga 3 days a week" -> Yoga, goal, repeating, amount 3, unit count.
            "Swim Mondays and Thursdays" -> Swim, goal, repeating, amount 2, unit count.
            "Hike on weekends" -> Hike, goal, repeating, amount 2, unit count.
            "Yoga each Monday" -> Yoga, checkbox, repeating.
            "Dinner with Sam on Friday" -> Dinner with Sam, checkbox, oneTime.
            "Paint the fence until done" -> Paint the fence, checkbox, carryOver.
            "Fix the bike sometime" -> Fix the bike, checkbox, carryOver.
            """)
    }
}

// MARK: - Generated Draft

/// What the model fills in; turned into a `ParsedTask` and checked before use.
@Generable
struct TaskDraft {
    @Guide(description: "The task's short name, without the schedule, amount or items")
    var title: String
    @Guide(description: "checkbox: one thing to do. goal: an amount to reach. list: several named items.")
    var kind: Kind
    @Guide(description: "repeating: every week. carryOver: until it's done. oneTime: otherwise.")
    var recurrence: Recurrence
    @Guide(description: "For a goal, the amount to reach; minutes for time. 0 when it isn't a goal.")
    var amount: Double
    @Guide(description: "For a goal: count for a plain number, minutes for time, named for a named unit.")
    var unit: Unit
    @Guide(description: "For a goal with a named unit, like pages or push-ups, that word. Otherwise empty.")
    var unitName: String
    @Guide(description: "For a list, each item named in the note. Otherwise empty.", .maximumCount(30))
    var items: [String]

    @Generable
    enum Kind { case checkbox, goal, list }

    @Generable
    enum Recurrence { case oneTime, carryOver, repeating }

    @Generable
    enum Unit { case count, minutes, named }

    func parsedTask(fallbackTitle: String) -> ParsedTask {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        var task = ParsedTask(title: cleanTitle.isEmpty ? fallbackTitle : cleanTitle)
        task.mode = switch recurrence {
        case .oneTime: .oneTime
        case .carryOver: .carryOver
        case .repeating: .repeating
        }
        switch kind {
        case .checkbox:
            task.type = .checkbox
        case .list:
            task.type = .list
            task.items = items
        case .goal:
            task.type = .goal
            if amount.isFinite, amount > 0 { task.goalTarget = min(amount, GoalUnitKind.maxValue) }
            let name = unitName.trimmingCharacters(in: .whitespacesAndNewlines)
            switch unit {
            case .minutes: task.goalKind = .time
            case .named where !name.isEmpty:
                task.goalKind = .custom
                task.goalUnit = name
            default: task.goalKind = .quantity
            }
        }
        return task
    }
}

// MARK: - Parser Choice

/// The parser Smart Add uses: Apple Intelligence or, in debug builds launched with
/// `-smartAddRules`, the plain rules after a 2-second pause like the model's, so Smart Add
/// can be tested in a simulator (which has no model). `-smartAddDelay 6` makes the pause
/// longer, for a test that does something else meanwhile.
enum SmartAddParser {
    static let current: TaskTextParser = {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-smartAddRules") {
            let delay = arguments.firstIndex(of: "-smartAddDelay")
                .flatMap { arguments.indices.contains($0 + 1) ? Double(arguments[$0 + 1]) : nil }
            return RulesOnlyTaskParser(delay: delay ?? 2)
        }
        #endif
        return AppleIntelligenceTaskParser.shared
    }()
}

#if DEBUG
/// Smart Add without a model, for simulators: the rules Smart Add applies after the model.
struct RulesOnlyTaskParser: TaskTextParser {
    /// Seconds, like the model's pause.
    var delay: Double = 2
    var isAvailable: Bool { true }
    func prepare() {}
    func parse(_ text: String) async throws -> ParsedTask? {
        try await Task.sleep(for: .seconds(delay))
        return try await AppleIntelligenceTaskParser.parse(text) { ParsedTask(title: $0) }
    }
}
#endif
