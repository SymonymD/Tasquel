import SwiftUI

// MARK: - Task Options Button

/// A task's type and mode icons side by side, in their colors. Opens `TaskOptionsPicker`.
struct TaskOptionsLabel: View {
    let type: TaskType
    let mode: TaskMode
    let theme: AppearanceMode
    let rc: RetroColor

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: type.symbol)
                .foregroundStyle(Theme.taskType(type, theme, rc: rc))
            Image(systemName: mode.symbol)
                .foregroundStyle(Theme.taskMode(mode, theme, rc: rc))
        }
        // Stops growing at the largest text sizes, like the row's other icons.
        .font(.expandedCardControl(.subheadline))
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(Theme.textTertiary(theme, rc: rc).opacity(0.2), in: Capsule())
    }
}

// MARK: - Task Options Picker

/// Two columns: what the task is (type) and what happens to it after this week (mode).
/// Each tap applies right away. For a new task, `onAdd` shows an Add Task button;
/// otherwise `onDone` shows Done, which closes the picker.
struct TaskOptionsPicker: View {
    let type: TaskType
    let mode: TaskMode
    let theme: AppearanceMode
    let rc: RetroColor
    /// Leaving a goal that has a target or progress asks first, since it clears them.
    var confirmsLeavingGoal = false
    let onSelectType: (TaskType) -> Void
    let onSelectMode: (TaskMode) -> Void
    var onAdd: (() -> Void)? = nil
    var onDone: (() -> Void)? = nil
    /// The task's card is for this week only: a mode that comes back next week turns that off.
    var isThisWeekOnlyCategory = false
    /// The day it's for (1 Sunday … 7 Saturday, nil any day); `onSelectDay` shows the Day row.
    var day: Int? = nil
    var onSelectDay: ((Int?) -> Void)? = nil
    /// The weekday weeks start on, for the row's order.
    var firstWeekday = 2
    /// The task's date (its last day, `expiresOn`; `dateIsWeek` when a whole week was
    /// picked); `onSelectDate` shows the Date row, whose calendar (`ExpiryPicker`, on a page
    /// of its own) starts at `earliestDate`. Nil from `onSelectDate`: no date.
    var date: DayKey? = nil
    var dateIsWeek = false
    var earliestDate: DayKey? = nil
    var today: DayKey? = nil
    var taskTitle = ""
    /// The first day of the task's week, for what a date after it means.
    var weekStart: DayKey? = nil
    var onSelectDate: ((DayKey?, Bool) -> Void)? = nil

    /// Opened from the date's mark next to the task's name: the calendar first, and Set,
    /// Cancel or Remove close it all (`onDateDone`) rather than going back to the options.
    var startsOnDate = false
    var onDateDone: (() -> Void)? = nil

    @State private var pendingType: TaskType?
    @State private var isPickingDate = false
    @State private var leftStartingDate = false

    private var picksDate: Bool { isPickingDate || (startsOnDate && !leftStartingDate) }

    private func finishDate() {
        if let onDateDone { onDateDone() } else {
            isPickingDate = false
            leftStartingDate = true
        }
    }
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if picksDate, let onSelectDate, let earliestDate, let today {
                // The date's calendar, in place of the options until Set or Cancel.
                ExpiryPicker(
                    taskTitle: taskTitle.isEmpty ? "New task" : taskTitle, current: date, currentIsWeek: dateIsWeek,
                    earliest: earliestDate, today: today, firstWeekday: firstWeekday, theme: theme, rc: rc,
                    onSet: { day, week in
                        onSelectDate(day, week)
                        finishDate()
                    },
                    onRemove: {
                        onSelectDate(nil, false)
                        finishDate()
                    },
                    onCancel: finishDate,
                    title: "Until",
                    noteFor: {
                        Self.thisWeekOnlyNote(for: $0, weekStart: weekStart, isThisWeekOnly: isThisWeekOnlyCategory)
                            ?? Self.datesWeekNote(for: $0, weekStart: weekStart, mode: mode)
                    }
                )
            } else {
                // Scrolls when it's taller than the screen (accessibility text sizes).
                ViewThatFits(in: .vertical) {
                    content
                    ScrollView { content }
                }
                .padding(16)
            }
        }
        .frame(minWidth: 300)
        // A keyboard that's up (typing a new task) mustn't push the options out of the
        // popover: in landscape on iPad it pushed the first rows off the top.
        .ignoresSafeArea(.keyboard)
        .presentationCompactAdaptation(.popover)
        .modifier(RetroPopoverBackground(theme: theme))
        .confirmationDialog("Change to \(pendingType?.label ?? "")?", isPresented: Binding(
            get: { pendingType != nil },
            set: { if !$0 { pendingType = nil } }
        ), titleVisibility: .visible) {
            Button("Change Type", role: .destructive) {
                if let pendingType { onSelectType(pendingType) }
                pendingType = nil
            }
        } message: {
            Text("This clears the goal target and progress.")
        }
    }

    /// Two columns side by side; one above the other at accessibility text sizes.
    private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            let columns = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 14))
                : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
            columns {
                column("Type") {
                    ForEach(TaskType.allCases, id: \.self) { option in
                        optionButton(option.label, symbol: option.symbol,
                                     color: Theme.taskType(option, theme, rc: rc),
                                     isSelected: option == type) {
                            selectType(option)
                        }
                    }
                }
                column("After This Week") {
                    ForEach(TaskMode.ordered, id: \.self) { option in
                        optionButton(option.label, symbol: option.symbol,
                                     color: Theme.taskMode(option, theme, rc: rc),
                                     isSelected: option == mode) {
                            onSelectMode(option)
                        }
                    }
                }
            }
            if let onSelectDay { dayRow(onSelectDay) }
            Text(hint).foregroundStyle(Theme.textSecondary(theme, rc: rc))
            .font(Theme.isRetro(theme) ? .system(.footnote, design: .monospaced) : .footnote)
            .fixedSize(horizontal: false, vertical: true)
            if let action = onAdd ?? onDone {
                if Theme.isRetro(theme) {
                    // No fill in Retro: on the bright accent, the filled button's words vanished.
                    Button(action: action) {
                        Text(onAdd != nil ? "[ADD_TASK]" : "[DONE]")
                            .font(.system(.headline, design: .monospaced))
                            .foregroundStyle(Theme.accent(theme, rc: rc))
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .overlay { RoundedRectangle(cornerRadius: 2).stroke(Theme.accent(theme, rc: rc), lineWidth: 1.5) }
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(onAdd != nil ? "Add Task" : "Done")
                } else {
                    Button(action: action) {
                        Text(onAdd != nil ? "Add Task" : "Done")
                            .font(.headline)
                            .foregroundStyle(Theme.onAccent(theme))  // dark on a light accent (Seasonal at night)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent(theme, rc: rc))
                }
            }
        }
    }

    /// What the mode does. In a "This week only" card, a mode that comes back next week
    /// says the card will too, in one line like the others: with the keyboard up, even one
    /// more line pushed Add Task out of the popover.
    private var hint: String {
        // One line, like the others: with the keyboard up, a second pushed Add Task out.
        if let date, onSelectDate != nil {
            let until = Self.dateText(date)
            let afterThisWeek = weekStart.map { date > $0.adding(days: 6) } ?? false
            let cardComesBack = isThisWeekOnlyCategory && mode != .oneTime ? ", and this card comes back" : ""
            return switch mode {
            case .carryOver: "Carries over until \(until)\(cardComesBack)"
            case .repeating: "Comes back every week until \(until)\(cardComesBack)"
            // After this week: it goes into its date's week (`ChecklistStore.setTaskDate`), but
            // a This week only card isn't there, so it carries over until then instead.
            case .oneTime: !afterThisWeek ? "Until \(until), then it's gone"
                : isThisWeekOnlyCategory ? "Carries over until \(until), and this card comes back"
                : "Moves to the week of \(until)"
            }
        }
        guard isThisWeekOnlyCategory else { return modeHint }
        return switch mode {
        case .carryOver: "Carries over, and this card comes back next week"
        case .repeating: "Comes back every week, and so does this card"
        case .oneTime: mode.hint
        }
    }

    /// The mode's hint for this type. A repeating list keeps its checks (d4016f8) and a goal
    /// starts from zero, so "unchecked" is only a checkbox's: a tester's grocery list came
    /// back with milk and bread still checked under that line (2026-11-14).
    private var modeHint: String {
        guard mode == .repeating else { return mode.hint }
        return switch type {
        case .checkbox: mode.hint
        case .goal: "Comes back every week, from zero"
        case .list: "Comes back every week, checks kept"
        }
    }

    /// In a This week only card, a date after this week makes the task carry over until
    /// then, which brings the card back every week: the calendar says so before Set.
    static func thisWeekOnlyNote(for day: DayKey, weekStart: DayKey?, isThisWeekOnly: Bool) -> String? {
        guard isThisWeekOnly, let weekStart, day > weekStart.adding(days: 6) else { return nil }
        return "It carries over until then, so this card will come back every week."
    }

    /// A one-time task dated after its week moves into its date's week: the calendar says so
    /// before Set (2026-11-15).
    static func datesWeekNote(for day: DayKey, weekStart: DayKey?, mode: TaskMode) -> String? {
        guard mode == .oneTime, let weekStart, day > weekStart.adding(days: 6) else { return nil }
        return "As a One-Time task, it moves to that week."
    }


    /// A one-time or carry-over task's day and date are one choice: with a date, no day is
    /// picked, and picking a day (or Any) takes the date away. A repeating task's day and
    /// date go together (every Monday, until its date).
    private var dateIsTheDay: Bool { date != nil && mode != .repeating && onSelectDate != nil }

    /// "Thu, Dec 3".
    private static func dateText(_ day: DayKey) -> String {
        day.date(in: Calendar.weekDates()).formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().locale(.gregorian))
    }

    /// Any, then the days in the week's order, one letter each (two rows at accessibility
    /// sizes), and with `onSelectDate` a calendar: the task's date (its last day), which the
    /// hint then says. VoiceOver hears each day's full name. The calendar is in this row,
    /// not a row of its own: with the keyboard up, a taller popover pushed Add Task out.
    private func dayRow(_ select: @escaping (Int?) -> Void) -> some View {
        column("Day") {
            let count = (dynamicTypeSize.isAccessibilitySize ? 4 : 8) + (onSelectDate != nil && !dynamicTypeSize.isAccessibilitySize ? 1 : 0)
            let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: count)
            LazyVGrid(columns: columns, spacing: 4) {
                dayButton(Theme.isRetro(theme) ? "ANY" : "Any", label: "Any day", isSelected: day == nil && !dateIsTheDay) {
                    pickDay(nil, select)
                }
                ForEach(Weekday.ordered(firstWeekday: firstWeekday), id: \.self) { weekday in
                    dayButton(Weekday.letter(weekday), label: Weekday.name(weekday, short: false),
                              isSelected: day == weekday && !dateIsTheDay) { pickDay(weekday, select) }
                }
                if onSelectDate != nil {
                    dayButton("", icon: date == nil ? "calendar" : "calendar.badge.checkmark",
                              label: date.map { "Date: \((dateIsWeek ? "week until " : "") + Self.dateText($0))" } ?? "Add a date",
                              isSelected: date != nil) { isPickingDate = true }
                        .accessibilityHint("Opens a calendar for the task's last day")
                }
            }
        }
    }

    /// A day picked; for a one-time or carry-over task with a date, the date goes.
    private func pickDay(_ day: Int?, _ select: (Int?) -> Void) {
        let clearsDate = dateIsTheDay
        select(day)
        if clearsDate { onSelectDate?(nil, false) }
    }

    private func dayButton(_ text: String, icon: String? = nil, label: String, isSelected: Bool,
                           action: @escaping () -> Void) -> some View {
        let accent = Theme.accent(theme, rc: rc)
        let shape = RoundedRectangle(cornerRadius: Theme.isRetro(theme) ? 2 : 8)
        return Button(action: action) {
            Group {
                if let icon {
                    Image(systemName: icon)
                } else {
                    Text(text)
                }
            }
                .font(Theme.isRetro(theme) ? .system(.subheadline, design: .monospaced) : .subheadline)
                .foregroundStyle(Theme.textPrimary(theme, rc: rc))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, minHeight: 36)
                .background {
                    shape.fill(isSelected ? accent.opacity(0.18) : Color.clear)
                    shape.stroke(isSelected ? accent : Theme.textTertiary(theme, rc: rc).opacity(0.4), lineWidth: isSelected ? 1.5 : 1)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func selectType(_ option: TaskType) {
        guard option != type else { return }
        if confirmsLeavingGoal && type == .goal {
            pendingType = option
        } else {
            onSelectType(option)
        }
    }

    private func column<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Theme.isRetro(theme) ? "[\(title.uppercased())]" : title.uppercased())
                .font(Theme.isRetro(theme) ? .system(.caption, design: .monospaced).bold() : .caption.bold())
                .foregroundStyle(Theme.textSecondary(theme, rc: rc))
                .accessibilityAddTraits(.isHeader)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func optionButton(_ label: String, symbol: String, color: Color, isSelected: Bool,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            OptionButtonLabel(title: label, symbol: symbol, color: color, isHighlighted: isSelected,
                              theme: theme, rc: rc, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        // Checkbox's checkmark icon would make it read "selected" when it isn't.
        .accessibilityRemoveTraits(isSelected ? [] : .isSelected)
    }
}

// MARK: - Option Button Label

/// The look of the picker's option buttons: a colored icon and label in a rounded box,
/// tinted and outlined in the color when highlighted. Also used for the goal editor's
/// Delete and Save Goal so they match.
struct OptionButtonLabel: View {
    let title: String
    let symbol: String
    let color: Color
    let isHighlighted: Bool
    let theme: AppearanceMode
    let rc: RetroColor
    var alignment: HorizontalAlignment = .center
    var isEnabled = true
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// The icon's column grows with the text: a fixed 22pt let the symbols spill over their
    /// rows' borders at the largest sizes (the 2026-11-15 review).
    @ScaledMetric(relativeTo: .body) private var iconWidth: CGFloat = 22

    var body: some View {
        HStack(spacing: 8) {
            if alignment == .center { Spacer(minLength: 0) }
            Image(systemName: symbol)
                .foregroundStyle(isEnabled ? color : Theme.textTertiary(theme, rc: rc))
                .frame(width: iconWidth)
            Text(title)
                .foregroundStyle(isEnabled ? Theme.textPrimary(theme, rc: rc) : Theme.textTertiary(theme, rc: rc))
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
        }
        .font(Theme.isRetro(theme) ? .system(.subheadline, design: .monospaced) : .subheadline)
        .padding(.horizontal, 10)
        .frame(minHeight: 44)
        .background {
            let shape = RoundedRectangle(cornerRadius: Theme.isRetro(theme) ? 2 : 10)
            let highlighted = isHighlighted && isEnabled
            shape.fill(highlighted ? color.opacity(0.18) : Color.clear)
            shape.stroke(highlighted ? color : Theme.textTertiary(theme, rc: rc).opacity(0.4), lineWidth: highlighted ? 1.5 : 1)
        }
        .contentShape(Rectangle())
    }
}
