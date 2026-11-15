import Foundation

/// A calendar date in typed words ("Exam 12/15", "Dentist on Dec 3", "Party December 15th"),
/// which Smart Add offers as the task's date (its last day) and asks before setting. Only
/// written-out dates count: numbers with / - or . between, or a month's name with a number.
/// Not "today" or "Friday": a weekday is already the task's day. Found by Foundation's date
/// detector (Apple-only, like Smart Add; elsewhere the words stay as typed).
struct TypedDate: Equatable {
    let day: DayKey
    /// The date as typed: "12/15".
    let phrase: String
    /// The words without it (and without an "on", "by", "due", "until" or "for" just before
    /// it): "Exam". Words that are only a date aren't offered one.
    let titleWithoutDate: String

    /// The first written-out date in `text` from `earliest` on (the viewed week's first day,
    /// or today), at most a year after `today`. A date typed without a year is this year's,
    /// as the store's clock has it, or next year's once it has gone by (judged against
    /// today, not the viewed week). Foundation's detector passes over short slash dates
    /// ("2/3", "1/5": fractions to it, unless "on" comes first), so those are read here,
    /// the month first or the day first as `locale` writes dates. Dots and dashes aren't:
    /// "2.5 miles", "3-5 times". A range ("until 12/15", "due 12/15": from now) counts by
    /// its end.
    static func find(in text: String, earliest: DayKey, today: DayKey, calendar: Calendar,
                     locale: Locale = .current) -> TypedDate? {
        var found: [(range: Range<String.Index>, day: DayKey, hasYear: Bool)] = []
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) {
            for match in detector.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                // Slash dates are all read below, one way: the detector rolls "2/30" over to March 2.
                guard let start = match.date, let range = Range(match.range, in: text),
                      isWrittenOutDate(String(text[range])),
                      String(text[range]).range(of: #"^\s*\d{1,2}/\d{1,2}(/\d{2,4})?\s*$"#, options: .regularExpression) == nil
                else { continue }
                // "until 12/15" is read as from now until then: the date is its end.
                let date = match.duration > 0 ? start.addingTimeInterval(match.duration) : start
                found.append((range, DayKey(date, in: calendar), hasYear(String(text[range]))))
            }
        }
        for slash in slashDates(in: text, year: today.year, calendar: calendar, locale: locale)
        where !found.contains(where: { $0.range.overlaps(slash.range) }) {
            found.append(slash)
        }
        for candidate in found.sorted(by: { $0.range.lowerBound < $1.range.lowerBound }) {
            var day = candidate.day
            if !candidate.hasYear {
                // This year's by the store's clock, or next year's once gone by.
                day = DayKey(year: today.year, month: day.month, day: day.day)
                if day < today { day = DayKey(year: today.year + 1, month: day.month, day: day.day) }
                // Feb 29 only in a year that has one.
                guard DayKey(day.date(in: calendar), in: calendar) == day else { continue }
            }
            let phrase = String(text[candidate.range]).trimmingCharacters(in: .whitespaces)
            guard day >= earliest, today.days(to: day) <= 366,
                  let title = title(text, without: candidate.range) else { continue }
            return TypedDate(day: day, phrase: phrase, titleWithoutDate: title)
        }
        return nil
    }

    /// "2/3", "12/15", "2/3/27", "2/3/2027": a real date, read month first or day first as
    /// `locale` does. Without a year, this year's (moved to next year by `find` if gone by).
    /// Not a fraction of something: "3/4 mile", "1/2 cup", "2/3 of the book".
    private static let units = "of|mi|mile|miles|km|k|m|cup|cups|tsp|tbsp|teaspoons?|tablespoons?|oz|ounces?|lbs?|pounds?|g|kg|ml|l|liters?|litres?|gallons?|inch|inches|in|ft|feet|hrs?|hours?|mins?|minutes?|laps?|pages?|servings?|slices?|scoops?|glass(es)?|reps?|sets?"

    private static func slashDates(in text: String, year thisYear: Int, calendar: Calendar, locale: Locale)
        -> [(range: Range<String.Index>, day: DayKey, hasYear: Bool)] {
        let pattern = #"(?<![\d/])(\d{1,2})/(\d{1,2})(?:/(\d{4}|\d{2}))?(?![\d/])(?!\s*(?i:"# + units + #")\b)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let order = DateFormatter.dateFormat(fromTemplate: "Md", options: 0, locale: locale) ?? "M/d"
        let monthFirst = (order.firstIndex(of: "M") ?? order.startIndex) < (order.firstIndex(of: "d") ?? order.endIndex)
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { match in
            guard let range = Range(match.range, in: text),
                  let first = Range(match.range(at: 1), in: text).flatMap({ Int(text[$0]) }),
                  let second = Range(match.range(at: 2), in: text).flatMap({ Int(text[$0]) }) else { return nil }
            let (month, day) = monthFirst ? (first, second) : (second, first)
            var year = thisYear
            let yearRange = Range(match.range(at: 3), in: text)
            if let yearRange, let typed = Int(text[yearRange]) { year = typed < 100 ? 2000 + typed : typed }
            // Only a day the calendar has (not 2/30).
            guard (1...12).contains(month), let date = calendar.date(from: DateComponents(year: year, month: month, day: day)),
                  calendar.component(.month, from: date) == month else { return nil }
            return (range, DayKey(date, in: calendar), yearRange != nil)
        }
    }

    /// "12/15", "12-15-2026", "15.12.", "Dec 3", "December 15th": not a time, a weekday or
    /// a word like "tomorrow".
    static func isWrittenOutDate(_ phrase: String) -> Bool {
        if phrase.range(of: #"\d{1,4}\s*[/.\-]\s*\d{1,2}"#, options: .regularExpression) != nil { return true }
        let month = #"(?i)\b(jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)[a-z]*\.?"#
        return phrase.range(of: month, options: .regularExpression) != nil
            && phrase.range(of: #"\d"#, options: .regularExpression) != nil
    }

    private static func hasYear(_ phrase: String) -> Bool {
        phrase.range(of: #"\d{4}|[/.\-]\s*\d{1,2}\s*[/.\-]\s*\d{2}\b"#, options: .regularExpression) != nil
    }

    /// The words around the date, the date and a joining word before it taken out.
    private static func title(_ text: String, without range: Range<String.Index>) -> String? {
        var before = String(text[..<range.lowerBound])
        let after = String(text[range.upperBound...])
        before = before.replacingOccurrences(of: #"(?i)\s*\b(on|by|due|until|for)\s*$"#, with: "", options: .regularExpression)
        let joined = (before + " " + after)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: "-–—,:")))
        return joined.isEmpty ? nil : joined
    }
}
