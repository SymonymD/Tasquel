import SwiftUI

// MARK: - Calendar Sheet

/// What the week selector's calendar button opens. With calendar events on, an Events |
/// Weeks toggle that opens on the viewed week's events (Weeks picks another week; a swipe
/// left or right on the events goes to the next or previous week); otherwise just the
/// week picker ("Go to Week").
struct CalendarSheet<Events: View>: View {
    let firstWeekday: Int
    let today: Date
    let theme: AppearanceMode
    let rc: RetroColor
    let showsEvents: Bool
    /// The viewed week, whose events show.
    let eventsWeek: DayKey?
    let onSelectWeek: (Date) -> Void
    /// +1 for the next week, -1 for the previous, and the swipe's speed (points per second),
    /// so the cards behind slide on at it.
    let onSwipeWeek: (Int, CGFloat) -> Void
    /// A week's events.
    @ViewBuilder let events: (DayKey) -> Events

    enum Side: Hashable { case events, weeks }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var side: Side
    @State private var weekStart: Date
    /// How far a sideways swipe on the events has moved them: with the finger, like the
    /// cards' pages, the week beside them coming in from that side.
    @State private var swipeOffset: CGFloat = 0
    /// The week in the middle. It stays put while a swipe's slide runs, then takes the week
    /// that slid in, so nothing jumps; otherwise it follows `eventsWeek`.
    @State private var shownWeek: DayKey?
    /// `eventsWeek` as it is now, for the end of a slide. (The slide's completion holds a
    /// copy of this view from when it started, with the week as it was then.)
    @State private var latestEventsWeek: DayKey?
    @State private var pageWidth: CGFloat = 0
    /// A swipe's slide to the next or previous week is running.
    @State private var isPaging = false
    /// The touch on the events is a sideways swipe: their buttons let go of it, so it
    /// can't open Calendar.
    @State private var isSwiping = false
    /// A finger is on the events. Resets itself if iOS cancels the drag (which doesn't
    /// call onEnded), so the events can't be left disabled or moved over.
    @GestureState private var isDragging = false

    init(selectedDate: Date, firstWeekday: Int, today: Date, theme: AppearanceMode, rc: RetroColor,
         showsEvents: Bool, eventsWeek: DayKey?, onSelectWeek: @escaping (Date) -> Void,
         onSwipeWeek: @escaping (Int, CGFloat) -> Void, @ViewBuilder events: @escaping (DayKey) -> Events) {
        self.firstWeekday = firstWeekday
        self.today = today
        self.theme = theme
        self.rc = rc
        self.showsEvents = showsEvents
        self.eventsWeek = eventsWeek
        self.onSelectWeek = onSelectWeek
        self.onSwipeWeek = onSwipeWeek
        self.events = events
        _shownWeek = State(initialValue: eventsWeek)
        _latestEventsWeek = State(initialValue: eventsWeek)
        _side = State(initialValue: showsEvents ? .events : .weeks)
        _weekStart = State(initialValue: Week.startOfWeek(containing: selectedDate, firstWeekday: firstWeekday))
    }

    private var isPickingWeek: Bool { side == .weeks || !showsEvents }

    var body: some View {
        NavigationStack {
            Group {
                if isPickingWeek {
                    WeekPickerCalendar(weekStart: $weekStart, firstWeekday: firstWeekday, today: today, theme: theme, rc: rc)
                } else {
                    ScrollView {
                        ZStack(alignment: .top) {
                            if let week = shownWeek {
                                eventsPage(week)
                                    .offset(x: swipeOffset)
                                // The week beside it, on the side the finger is pulling from.
                                if swipeOffset < 0 {
                                    eventsPage(week.adding(days: 7))
                                        .offset(x: swipeOffset + pageWidth)
                                } else if swipeOffset > 0 {
                                    eventsPage(week.adding(days: -7))
                                        .offset(x: swipeOffset - pageWidth)
                                }
                            }
                        }
                        .disabled(isSwiping && isDragging)
                    }
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { pageWidth = $0 }
                    .onChange(of: eventsWeek) { _, week in
                        latestEventsWeek = week
                        if !isPaging { shownWeek = week }
                    }
                    .simultaneousGesture(weekSwipe)
                    // A drag iOS cancelled puts the events back; not one that went on to slide
                    // to another week (that slide ends in place by itself).
                    .onChange(of: isDragging) { _, dragging in
                        guard !dragging, !isPaging else { return }
                        isSwiping = false
                        withAnimation(.snappy(duration: 0.25)) { swipeOffset = 0 }
                    }
                    .accessibilityAction(named: "Next week") { swipeWeek(by: 1) }
                    .accessibilityAction(named: "Previous week") { swipeWeek(by: -1) }
                }
            }
            .fontDesign(Theme.isRetro(theme) ? .monospaced : nil)
            .navigationTitle(showsEvents ? "Calendar" : "Go to Week")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if showsEvents {
                    ToolbarItem(placement: .principal) {
                        Picker("Show", selection: $side) {
                            Text("Events").tag(Side.events)
                            Text("Weeks").tag(Side.weeks)
                        }
                        .pickerStyle(.segmented)
                        .fixedSize()
                    }
                }
                if isPickingWeek {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Go") {
                            onSelectWeek(weekStart)
                            dismiss()
                        }
                    }
                } else {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
            }
        }
        .tint(Theme.isRetro(theme) ? Theme.accent(theme, rc: rc) : nil)
        // The week picker follows a week changed by swiping the events.
        .onChange(of: eventsWeek) { _, week in
            if let week { weekStart = week.date(in: .weekDates()) }
        }
    }

    /// Left for the next week, right for the previous, as on the main screen. Only a drag
    /// that's clearly sideways counts; a vertical one scrolls the events.
    private var weekSwipe: some Gesture {
        DragGesture(minimumDistance: 12)
            .updating($isDragging) { _, dragging, _ in dragging = true }
            .onChanged { value in
                guard !isPaging else { return }
                let dx = value.translation.width, dy = value.translation.height
                if !isSwiping {
                    guard abs(dx) > 16, abs(dx) > abs(dy) * 1.5 else { return }
                    isSwiping = true
                }
                if !reduceMotion { swipeOffset = dx }
            }
            .onEnded { value in
                defer { isSwiping = false }
                guard isSwiping, !isPaging else { return }
                let dx = value.predictedEndTranslation.width
                let weeks = dx < -80 ? 1 : dx > 80 ? -1 : 0
                guard weeks != 0 else {
                    withAnimation(.snappy(duration: 0.25)) { swipeOffset = 0 }
                    return
                }
                page(by: weeks, velocity: value.velocity.width)
            }
    }

    /// The events slide on to the next or previous week as the cards behind do (same
    /// spring, carrying on at the finger's speed); then that week takes the middle.
    private func page(by weeks: Int, velocity: CGFloat) {
        onSwipeWeek(weeks, velocity)
        guard !reduceMotion, pageWidth > 0 else { return }  // `shownWeek` follows `eventsWeek`
        isPaging = true
        let target = weeks > 0 ? -pageWidth : pageWidth
        let remaining = target - swipeOffset
        let relative = abs(remaining) > 1 ? max(0, min(12, velocity / remaining)) : 0
        withAnimation(.interpolatingSpring(duration: 0.4, bounce: 0, initialVelocity: relative), completionCriteria: .removed) {
            swipeOffset = target
        } completion: {
            var settle = Transaction()
            settle.disablesAnimations = true
            withTransaction(settle) {
                shownWeek = latestEventsWeek ?? shownWeek?.adding(days: 7 * weeks)
                swipeOffset = 0
            }
            isPaging = false
        }
    }

    /// A week's events, as wide as the sheet. (Not a width measured from the sheet: one
    /// measured while it slid in was too narrow, and the sheet then kept to it.)
    private func eventsPage(_ week: DayKey) -> some View {
        events(week)
            .padding()
            .frame(maxWidth: .infinity, alignment: .top)
    }

    /// Next or previous week without a swipe (VoiceOver).
    private func swipeWeek(by weeks: Int) {
        DispatchQueue.main.async { onSwipeWeek(weeks, 0) }
    }
}

// MARK: - Week Picker

/// Months to pick a week from. Tapping any day picks its whole week, which is highlighted
/// (in both months when it spans two), with "Week of …" under the months. The list starts
/// at the picked week's month, so it opens there with the next month below, and goes two
/// years ahead; Earlier, at the top, adds the month before. (Scrolling to a month in the
/// middle of the list landed it under the sheet's toolbar, or past it.)
struct WeekPickerCalendar: View {
    @Binding var weekStart: Date
    let firstWeekday: Int
    let today: Date
    let theme: AppearanceMode
    let rc: RetroColor

    /// The first day of each month shown. Set when the picker opens (and by Earlier), so
    /// picking a week in another month doesn't shift the list under the finger.
    @State private var months: [Date]

    init(weekStart: Binding<Date>, firstWeekday: Int, today: Date, theme: AppearanceMode, rc: RetroColor) {
        _weekStart = weekStart
        self.firstWeekday = firstWeekday
        self.today = today
        self.theme = theme
        self.rc = rc
        let calendar = Self.calendar(firstWeekday)
        let month = calendar.dateInterval(of: .month, for: weekStart.wrappedValue)?.start
        _months = State(initialValue: month.map { month in
            (0...24).compactMap { calendar.date(byAdding: .month, value: $0, to: month) }
        } ?? [])
    }

    private static func calendar(_ firstWeekday: Int) -> Calendar {
        var calendar = Calendar.weekDates()
        calendar.firstWeekday = firstWeekday
        calendar.locale = .current
        return calendar
    }

    private var calendar: Calendar { Self.calendar(firstWeekday) }
    private var accent: Color { Theme.accent(theme, rc: rc) }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                Button(action: addEarlierMonth) {
                    Label("Earlier", systemImage: "chevron.up")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(accent)
                .accessibilityLabel("Show earlier month")
                ForEach(months, id: \.self) { month in
                    monthView(month)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .safeAreaInset(edge: .bottom) {
            Text("Week of \(weekStart.formatted(.dateTime.month(.abbreviated).day().year()))")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary(theme, rc: rc))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(.bar)
                .accessibilityLabel("Picked: week of \(weekStart.formatted(.dateTime.month(.wide).day().year()))")
        }
    }

    private func monthView(_ month: Date) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(month.formatted(.dateTime.month(.wide).year()))
                .font(.headline)
                .foregroundStyle(Theme.textPrimary(theme, rc: rc))
                .padding(.horizontal, 6)
                .padding(.bottom, 4)
                .accessibilityAddTraits(.isHeader)
            weekdayHeader
            ForEach(weekStarts(in: month), id: \.self) { start in
                weekRow(start, month: month)
            }
        }
    }

    /// "M T W …", starting on the user's week start day.
    private func addEarlierMonth() {
        guard let first = months.first, let earlier = calendar.date(byAdding: .month, value: -1, to: first) else { return }
        months.insert(earlier, at: 0)
    }

    private var weekdayHeader: some View {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { index in
                Text(symbols[(first + index) % 7])
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary(theme, rc: rc))
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }

    /// The starts of the weeks that have a day in the month.
    private func weekStarts(in month: Date) -> [Date] {
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

    /// One button for the whole week.
    private func weekRow(_ start: Date, month: Date) -> some View {
        let isPicked = calendar.isDate(start, inSameDayAs: weekStart)
        let shape = RoundedRectangle(cornerRadius: Theme.isRetro(theme) ? 2 : 12)
        return Button { weekStart = start } label: {
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { offset in
                    if let day = calendar.date(byAdding: .day, value: offset, to: start) {
                        dayCell(day, isInMonth: calendar.isDate(day, equalTo: month, toGranularity: .month))
                    }
                }
            }
            .padding(.vertical, 2)
            .background {
                if isPicked {
                    shape.fill(accent.opacity(0.18))
                    shape.stroke(accent, lineWidth: 1.5)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Week of \(start.formatted(.dateTime.month(.wide).day().year()))")
        .accessibilityAddTraits(isPicked ? .isSelected : [])
    }

    private func dayCell(_ day: Date, isInMonth: Bool) -> some View {
        let isToday = calendar.isDate(day, inSameDayAs: today)
        return Text(day.formatted(.dateTime.day()))
            .font(isToday ? .body.weight(.bold) : .body)
            .monospacedDigit()
            .foregroundStyle(isToday ? accent : isInMonth ? Theme.textPrimary(theme, rc: rc) : Theme.textTertiary(theme, rc: rc))
            .frame(maxWidth: .infinity, minHeight: 40)
            .overlay {
                if isToday { Circle().stroke(accent, lineWidth: 1.5).frame(width: 34, height: 34) }
            }
    }
}
