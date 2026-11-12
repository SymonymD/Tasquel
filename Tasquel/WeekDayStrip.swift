import SwiftUI

// MARK: - Week Day Strip

/// The viewed week's seven days, as pills under its title, so it's clear where today
/// falls: days gone by are green (like Save Goal), today shows its date ("7th"), days to
/// come are empty. In a past week every day is green; in a future week none is. Tapping
/// a day shows only its tasks (and the ones without a day) in every card: that pill fills
/// in with the day's name, a line under the strip says so with Show All, and tapping it
/// again shows every task. Its text size is capped where it's placed (`.dynamicTypeSize`,
/// outside, so the `@ScaledMetric` pill sizes see the cap too).
struct WeekDayStrip: View {
    let weekStart: DayKey
    let today: DayKey
    /// Today, for VoiceOver.
    let todayDate: Date
    let theme: AppearanceMode
    let rc: RetroColor
    /// The day whose tasks are shown (1 Sunday … 7 Saturday), if one is picked.
    var selectedWeekday: Int? = nil
    var firstWeekday = 2
    var onSelect: ((Int) -> Void)? = nil

    /// About half the size the days first had (26pt-tall boxes), then 5% larger.
    @ScaledMetric(relativeTo: .caption2) private var height: CGFloat = 13.65
    @ScaledMetric(relativeTo: .caption2) private var width: CGFloat = 24.15

    private var days: [DayKey] { (0..<7).map { weekStart.adding(days: $0) } }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                ForEach(Array(days.enumerated()), id: \.element) { index, day in
                    let weekday = Weekday.ordered(firstWeekday: firstWeekday)[index]
                    if let onSelect {
                        Button { onSelect(weekday) } label: {
                            // 44pt tall and as wide as the space each day has (the pills are
                            // tiny), inside the label: a plain button takes taps only there.
                            pill(day, weekday: weekday).touchTarget(width: width + 8, height: 44)
                        }
                            .buttonStyle(.plain)
                            .accessibilityLabel(dayLabel(day, weekday: weekday))
                            .accessibilityHint(selectedWeekday == weekday ? "Shows every task again" : "Shows only this day's tasks")
                            .accessibilityAddTraits(selectedWeekday == weekday ? .isSelected : [])
                            .accessibilityIdentifier("Day \(Weekday.name(weekday, short: false))")
                    } else {
                        pill(day, weekday: weekday)
                    }
                }
            }
            .accessibilityElement(children: onSelect == nil ? .ignore : .contain)
            .accessibilityLabel(onSelect == nil ? accessibilityText : "")
            .accessibilityIdentifier("Week days")
            if let selectedWeekday, let onSelect {
                HStack(spacing: 6) {
                    Text(Theme.isRetro(theme) ? "> \(Weekday.name(selectedWeekday, short: false).uppercased()) + NO_DAY"
                                              : "\(Weekday.name(selectedWeekday, short: false)) and tasks with no day")
                        .foregroundStyle(Theme.textSecondary(theme, rc: rc))
                    Button(Theme.isRetro(theme) ? "[SHOW_ALL]" : "Show All") { onSelect(selectedWeekday) }
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.accent(theme, rc: rc))
                        .touchTarget()
                }
                .font(Theme.isRetro(theme) ? .system(.caption, design: .monospaced) : .caption)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .transition(.opacity)
            }
        }
    }

    /// "Thursday, November 12", with "today" on today.
    private func dayLabel(_ day: DayKey, weekday: Int) -> String {
        let date = day.date(in: Calendar.weekDates()).formatted(.dateTime.weekday(.wide).month(.wide).day())
        return day == today ? "Today, \(date)" : date
    }

    private func pill(_ day: DayKey, weekday: Int) -> some View {
        let shape = Theme.isRetro(theme) ? AnyShape(RoundedRectangle(cornerRadius: 2)) : AnyShape(Capsule())
        let isToday = day == today
        let isPast = day < today
        let isSelected = selectedWeekday == weekday
        let accent = Theme.accent(theme, rc: rc)
        // Save Goal's green: a soft fill inside a full-color border.
        let done = Theme.isRetro(theme) ? Theme.dotComplete(theme, rc: rc) : Color.green
        return Group {
            if isSelected {
                // The picked day: filled in, with its name ("Thu", today's date on today).
                Text(isToday ? Self.ordinal(day.day) : Weekday.name(weekday))
                    .font(Theme.isRetro(theme) ? .system(.caption2, design: .monospaced).bold() : .caption2.bold())
                    .foregroundStyle(Theme.isRetro(theme) ? .black : .white)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, 7)
                    .padding(.vertical, 1)
                    .frame(minWidth: width, minHeight: height)
                    .fixedSize()
                    .background { shape.fill(accent) }
            } else if isToday {
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
