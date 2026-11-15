import SwiftUI

/// The clock's popover in a card's edit mode, and the type and mode popup's Date page: a
/// small month calendar for a task's last day, picked as a date or as a whole week (that
/// week's last day), from `earliest` on. Set saves it; Cancel, or a tap outside, leaves
/// things as they were; Remove (once one is set) takes it away. `title` heads it: "Expires"
/// at the clock, "Until" in the popup.
struct ExpiryPicker: View {
    let taskTitle: String
    /// The expiration the task has now, if any.
    let current: DayKey?
    let currentIsWeek: Bool
    /// The first day that can be picked: today, or a later week's first day.
    let earliest: DayKey
    let today: DayKey
    let firstWeekday: Int
    let theme: AppearanceMode
    let rc: RetroColor
    let onSet: (_ lastDay: DayKey, _ wholeWeek: Bool) -> Void
    let onRemove: () -> Void
    let onCancel: () -> Void
    let title: String
    /// Said under the summary for the day picked, if anything (a This week only card that
    /// a later date brings back every week).
    let noteFor: ((DayKey) -> String?)?

    @State private var picked: DayKey?
    @State private var wholeWeek: Bool
    /// The first day of the month shown.
    @State private var month: Date

    init(taskTitle: String, current: DayKey?, currentIsWeek: Bool, earliest: DayKey, today: DayKey,
         firstWeekday: Int, theme: AppearanceMode, rc: RetroColor,
         onSet: @escaping (_ lastDay: DayKey, _ wholeWeek: Bool) -> Void,
         onRemove: @escaping () -> Void, onCancel: @escaping () -> Void, title: String = "Expires",
         noteFor: ((DayKey) -> String?)? = nil) {
        self.title = title
        self.noteFor = noteFor
        self.taskTitle = taskTitle
        self.current = current
        self.currentIsWeek = currentIsWeek
        self.earliest = earliest
        self.today = today
        self.firstWeekday = firstWeekday
        self.theme = theme
        self.rc = rc
        self.onSet = onSet
        self.onRemove = onRemove
        self.onCancel = onCancel
        _picked = State(initialValue: current)
        _wholeWeek = State(initialValue: current != nil && currentIsWeek)
        let calendar = Self.calendar(firstWeekday)
        let shown = (current ?? earliest).date(in: calendar)
        _month = State(initialValue: calendar.dateInterval(of: .month, for: shown)?.start ?? shown)
    }

    private static func calendar(_ firstWeekday: Int) -> Calendar {
        var calendar = Calendar.weekDates()
        calendar.firstWeekday = firstWeekday
        calendar.locale = .current
        return calendar
    }

    private var calendar: Calendar { Self.calendar(firstWeekday) }
    private var accent: Color { Theme.accent(theme, rc: rc) }
    private var design: Font.Design { Theme.isRetro(theme) ? .monospaced : .default }

    var body: some View {
        // Compact: above a task in the middle of the screen it has about 400pt. The month
        // scrolls if even that's too tall (large text); the summary and buttons stay.
        VStack(alignment: .leading, spacing: 10) {
            header
            ViewThatFits(in: .vertical) {
                monthGrid
                ScrollView { monthGrid }
            }
            footer
        }
        .padding(14)
        .frame(minWidth: 300, maxWidth: 360)
        .presentationCompactAdaptation(.popover)
        .modifier(RetroPopoverBackground(theme: theme))
        .onChange(of: wholeWeek) { _, week in
            // A week is picked by its last day.
            if week, let picked { self.picked = lastDayOfWeek(containing: picked) }
        }
    }

    /// "Expires" and Date | Week.
    private var header: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(.headline, design: design))
                .foregroundStyle(Theme.textPrimary(theme, rc: rc))
                .accessibilityAddTraits(.isHeader)
                .accessibilityLabel(title == "Expires" ? "\(taskTitle) expires" : "\(taskTitle), until")
                .accessibilityIdentifier(title)
            Spacer(minLength: 0)
            Picker("Pick a", selection: $wholeWeek) {
                Text("Date").tag(false)
                Text("Week").tag(true)
            }
            .pickerStyle(.segmented)
            .fixedSize()
        }
    }

    private var monthGrid: some View {
        VStack(spacing: 2) {
            monthHeader
            weekdayHeader
            ForEach(weekStarts, id: \.self) { start in weekRow(start) }
        }
    }

    /// What's picked, and Remove (once one is set), Cancel and Set.
    private var footer: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(summary)
                .font(.system(.subheadline, design: design).weight(.semibold))
                .foregroundStyle(Theme.textPrimary(theme, rc: rc))
                .fixedSize(horizontal: false, vertical: true)
            if let picked, let note = noteFor?(picked) {
                Text(note)
                    .font(.system(.footnote, design: design))
                    .foregroundStyle(Theme.textSecondary(theme, rc: rc))
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 16) {
                if current != nil {
                    // "Remove" alone read as removing the task: an ✕ and the word Date.
                    Button(role: .destructive, action: onRemove) {
                        Label("Date", systemImage: "xmark")
                            .labelStyle(.titleAndIcon)
                    }
                    .foregroundStyle(Theme.destructive(theme))
                    .accessibilityLabel("Remove date")
                }
                Spacer(minLength: 0)
                Button("Cancel", action: onCancel)
                Button("Set") {
                    if let picked { onSet(picked, wholeWeek) }
                }
                .fontWeight(.semibold)
                .foregroundStyle(canSet ? accent : Theme.textTertiary(theme, rc: rc))
                .disabled(!canSet)
            }
            .font(.system(.body, design: design))
            .foregroundStyle(accent)
        }
    }

    /// Something is picked, and it isn't what's already set.
    private var canSet: Bool {
        picked != nil && !(picked == current && wholeWeek == currentIsWeek)
    }

    // MARK: Month

    private var monthHeader: some View {
        let first = calendar.dateInterval(of: .month, for: earliest.date(in: calendar))?.start ?? month
        let last = calendar.date(byAdding: .month, value: 24, to: first) ?? month
        return HStack {
            Button { moveMonth(-1) } label: {
                Image(systemName: "chevron.left").touchTarget()
            }
            .disabled(month <= first)
            .accessibilityLabel("Previous month")
            Spacer()
            Text(month.formatted(.dateTime.month(.wide).year()))
                .font(.system(.subheadline, design: design).weight(.semibold))
                .foregroundStyle(Theme.textPrimary(theme, rc: rc))
            Spacer()
            Button { moveMonth(1) } label: {
                Image(systemName: "chevron.right").touchTarget()
            }
            .disabled(month >= last)
            .accessibilityLabel("Next month")
        }
        .buttonStyle(.plain)
        .foregroundStyle(accent)
    }

    private func moveMonth(_ by: Int) {
        if let moved = calendar.date(byAdding: .month, value: by, to: month) { month = moved }
    }

    /// "M T W …", starting on the user's week start day.
    private var weekdayHeader: some View {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { index in
                Text(symbols[(first + index) % 7])
                    .font(.system(.caption2, design: design).weight(.semibold))
                    .foregroundStyle(Theme.textSecondary(theme, rc: rc))
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }

    /// The first days of the weeks with a day in the month shown.
    private var weekStarts: [Date] {
        guard let interval = calendar.dateInterval(of: .month, for: month) else { return [] }
        var start = Week.startOfWeek(containing: interval.start, firstWeekday: firstWeekday)
        var starts: [Date] = []
        while start < interval.end {
            starts.append(start)
            guard let next = calendar.date(byAdding: .day, value: 7, to: start) else { break }
            start = next
        }
        return starts
    }

    private func lastDayOfWeek(containing day: DayKey) -> DayKey {
        let start = Week.startOfWeek(containing: day.date(in: calendar), firstWeekday: firstWeekday)
        return DayKey(start, in: calendar).adding(days: 6)
    }

    // MARK: Weeks and days

    /// A week: one button for the whole week (Week), or a button for each day (Date).
    @ViewBuilder
    private func weekRow(_ start: Date) -> some View {
        let days = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
        let lastDay = DayKey(start, in: calendar).adding(days: 6)
        if wholeWeek {
            let isPicked = picked == lastDay
            let shape = RoundedRectangle(cornerRadius: Theme.isRetro(theme) ? 2 : 10)
            Button { picked = lastDay } label: {
                HStack(spacing: 0) {
                    ForEach(days, id: \.self) { dayLabel($0, isPicked: false) }
                }
                .background {
                    if isPicked {
                        shape.fill(accent.opacity(0.18))
                        shape.stroke(accent, lineWidth: 1.5)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(lastDay < earliest)
            .accessibilityLabel("Week of \(start.formatted(.dateTime.month(.wide).day()))")
            .accessibilityAddTraits(isPicked ? .isSelected : [])
        } else {
            HStack(spacing: 0) {
                ForEach(days, id: \.self) { day in
                    let key = DayKey(day, in: calendar)
                    Button { picked = key } label: { dayLabel(day, isPicked: picked == key) }
                        .buttonStyle(.plain)
                        .disabled(key < earliest)
                        .accessibilityLabel(day.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                        .accessibilityAddTraits(picked == key ? .isSelected : [])
                }
            }
        }
    }

    private func dayLabel(_ day: Date, isPicked: Bool) -> some View {
        let key = DayKey(day, in: calendar)
        let isInMonth = calendar.isDate(day, equalTo: month, toGranularity: .month)
        let isToday = key == today
        let color: Color = isPicked ? Theme.onAccent(theme)
            : key < earliest ? Theme.textTertiary(theme, rc: rc).opacity(0.5)
            : isToday ? accent
            : isInMonth ? Theme.textPrimary(theme, rc: rc) : Theme.textTertiary(theme, rc: rc)
        return Text(day.formatted(.dateTime.day()))
            .font(.system(.body, design: design).weight(isToday || isPicked ? .bold : .regular))
            .monospacedDigit()
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, minHeight: 32)
            .background {
                if isPicked { Circle().fill(accent).frame(width: 30, height: 30) }
            }
            .contentShape(Rectangle())
    }

    /// "Until Thu, Dec 25, then it's gone", for a week "Until Sun, Dec 28 (week of Dec 22)".
    private var summary: String {
        guard let picked else { return wholeWeek ? "Pick the task's last week" : "Pick the task's last day" }
        let last = picked.date(in: calendar).formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        guard wholeWeek else { return "Until \(last), then it's gone" }
        let start = picked.adding(days: -6).date(in: calendar).formatted(.dateTime.month(.abbreviated).day())
        return "Until \(last) (week of \(start)), then it's gone"
    }
}
