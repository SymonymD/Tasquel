import SwiftUI

// MARK: - Week Day Strip

/// The viewed week's seven days, as pills under its title, so it's clear where today
/// falls: days gone by are green (like Save Goal), today shows its date ("7th"), days to
/// come are empty. In a past week every day is green; in a future week none is. Only to
/// look at, not to tap. Its text size is capped where it's placed (`.dynamicTypeSize`,
/// outside, so the `@ScaledMetric` pill sizes see the cap too).
struct WeekDayStrip: View {
    let weekStart: DayKey
    let today: DayKey
    /// Today, for VoiceOver.
    let todayDate: Date
    let theme: AppearanceMode
    let rc: RetroColor

    /// About half the size the days first had (26pt-tall boxes), then 5% larger.
    @ScaledMetric(relativeTo: .caption2) private var height: CGFloat = 13.65
    @ScaledMetric(relativeTo: .caption2) private var width: CGFloat = 24.15

    private var days: [DayKey] { (0..<7).map { weekStart.adding(days: $0) } }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(days, id: \.self) { day in
                pill(day)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityIdentifier("Week days")
    }

    private func pill(_ day: DayKey) -> some View {
        let shape = Theme.isRetro(theme) ? AnyShape(RoundedRectangle(cornerRadius: 2)) : AnyShape(Capsule())
        let isToday = day == today
        let isPast = day < today
        let accent = Theme.accent(theme, rc: rc)
        // Save Goal's green: a soft fill inside a full-color border.
        let done = Theme.isRetro(theme) ? Theme.dotComplete(theme, rc: rc) : Color.green
        return Group {
            if isToday {
                // As wide as its date needs ("22nd").
                Text(Self.ordinal(day.day))
                    .font(Theme.isRetro(theme) ? .system(.caption2, design: .monospaced).bold() : .caption2.bold())
                    .foregroundStyle(accent)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, 7)
                    .padding(.vertical, 1)
                    .frame(minWidth: width, minHeight: height)
                    .fixedSize()
            } else {
                Color.clear.frame(width: width, height: height)
            }
        }
        .background {
            shape.fill(isPast ? done.opacity(0.18) : Color.clear)
            shape.stroke(isToday ? accent : isPast ? done : Theme.textTertiary(theme, rc: rc).opacity(0.8),
                         lineWidth: isToday ? 1.5 : 1)
        }
    }

    /// "7th", "2nd", "22nd" in English; each language's own form elsewhere ("7.").
    static func ordinal(_ number: Int, locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .ordinal
        return formatter.string(from: number as NSNumber) ?? "\(number)"
    }

    /// Today's full date in this week, or whether the week is over or still to come.
    private var accessibilityText: String {
        if let index = days.firstIndex(of: today) {
            return "Today, \(todayDate.formatted(date: .complete, time: .omitted)), day \(index + 1) of 7"
        }
        return today < weekStart ? "This week hasn't started" : "This week is over"
    }
}
