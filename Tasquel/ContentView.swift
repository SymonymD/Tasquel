import SwiftUI
import UniformTypeIdentifiers
// MARK: - Root View

struct ContentView: View {
    @State private var store = ChecklistStore.makeDefault()
    @State private var calendarService = CalendarService.makeDefault()
    @State private var showDatePicker = false
    @State private var showSettings = false
    @State private var showAddCategory = false
    @State private var expandedCategoryKeys: Set<CategoryLayoutKey> = []
    @State private var categoryDisplayOrder: [CategoryLayoutKey] = []
    @State private var lastToggledCategory: CategoryLayoutKey?
    @State private var isEditing = false
    /// The card being held and dragged to a new place (see Card Dragging).
    @State private var cardDrag: CardDrag?
    /// The order shown while a card is dragged; saved when it's dropped.
    @State private var liveCardOrder: [CategoryLayoutKey]?
    /// Each card's place in the grid of the week being viewed, for finding the card
    /// under the finger.
    @State private var cardFrames: [CategoryLayoutKey: CGRect] = [:]
    @State private var lastCardDrop = Date.distantPast
    /// Cards whose own edit button is on (only their tasks become editable).
    @State private var editingCategoryKeys: Set<CategoryLayoutKey> = []
    @State private var showOnboarding = false
    /// The bottom bar's calendar toggle: expands the bar to show the week's events.
    @State private var showEventsPanel = false
    /// While the keyboard is up, the bottom bar turns into a Done button.
    @State private var isKeyboardVisible = false
    @Namespace private var bottomBarGlass
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// When the app last went to the background, to decide whether reopening it
    /// should jump back to the current week.
    @State private var backgroundedAt: Date?

    // Week paging (swipe or arrows): last/this/next week sit side by side.
    // Read only by PagerTrack, so dragging moves the pages without rebuilding them.
    @State private var pager = WeekPagerState()
    @State private var pagerTarget: PagerTarget?
    @State private var arrivingWeekTitle: String?  // shown from release until the new week takes over
    @State private var weekSwipeAxis: Axis?
    @State private var weekDragOrigin: CGFloat = 0  // translation when the swipe was recognized
    @State private var isChangingWeek = false
    @State private var weekPageWidth: CGFloat = 400
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var theme: AppearanceMode { store.appearanceMode }
    private var rc: RetroColor { store.retroColor }

    private var isPastWeek: Bool {
        store.selectedWeek?.isPastWeek ?? false
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.background(theme).ignoresSafeArea()

            VStack(spacing: 12) {
                // Today's date; the viewed week is shown in the bottom bar.
                Text(Theme.isRetro(theme) ? "> \(todayDateString)_" : todayDateString)
                    .font(Theme.titleFont(theme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 56)  // clear of the Expand All button
                    .frame(maxWidth: .infinity)
                .overlay(alignment: .trailing) { expandAllButton }
                .padding(.top, 8)

                if let error = store.persistenceError {
                    Spacer()
                    ContentUnavailableView {
                        Label("Planner Unavailable", systemImage: "externaldrive.badge.exclamationmark")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Retry Loading") {
                            store.retryLoadingData()
                            if store.persistenceError == nil && store.shouldShowWelcome {
                                showOnboarding = true
                            }
                        }
                    }
                    Spacer()
                } else if let week = store.selectedWeek {
                    weekNavigationBar
                    PagerTrack(pager: pager) {
                        // Keyed by week, so the page that slides in keeps its identity when
                        // it becomes current; only the new off-screen neighbor is built.
                        ForEach(pagerPages(current: week)) { page in
                            weekContent(page.week)
                                .offset(x: CGFloat(page.slot) * weekPageWidth)
                                // Neighbor pages are only for show while paging.
                                .allowsHitTesting(page.slot == 0)
                                .accessibilityHidden(page.slot != 0)
                                // A swipe that starts on a card or checkbox must not tap it: the
                                // content moves with the finger, so the touch never leaves the button.
                                // (allowsHitTesting doesn't cancel a touch already in progress.)
                                .disabled(page.slot != 0 || weekSwipeAxis == .horizontal || isChangingWeek)
                        }
                    }
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { weekPageWidth = $0 }
                    .simultaneousGesture(weekSwipeGesture)
                } else {
                    Spacer()
                    ContentUnavailableView("No Week Data", systemImage: "calendar.badge.exclamationmark")
                    Spacer()
                }
            }

            if store.persistenceError == nil {
                bottomBar
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }

            // Retro scanline overlay
            if Theme.isRetro(theme) {
                ScanlineOverlay()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .foregroundStyle(Theme.textPrimary(theme, rc: rc))
        .preferredColorScheme(store.colorScheme)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation(.snappy(duration: 0.3)) { isKeyboardVisible = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.snappy(duration: 0.3)) { isKeyboardVisible = false }
        }
        .sheet(isPresented: $showDatePicker) {
            DatePickerSheet(selectedDate: store.selectedDate, firstWeekday: store.firstWeekday) { date in
                changeWeek(to: date)
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet(store: store, calendar: calendarService)
        }
        .sheet(isPresented: $showAddCategory) {
            AddCategorySheet(store: store) { name, symbol, thisWeekOnly in
                store.addCategory(name: name, symbol: symbol, thisWeekOnly: thisWeekOnly)
                isEditing = false
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingSheet(store: store)
                .interactiveDismissDisabled()
        }
        .onAppear {
            if store.persistenceError == nil && store.shouldShowWelcome {
                showOnboarding = true
            }
        }
        .task {
            // The calendar list is needed to resolve the saved selection; without it no
            // events load until Settings is opened.
            await calendarService.loadCalendars()
        }
        .onChange(of: dynamicTypeSize, initial: true) {
            TextSizeSetting.shared.size = dynamicTypeSize
        }
        .onChange(of: scenePhase) {
            if scenePhase == .background { backgroundedAt = Date() }
            guard scenePhase == .active else { return }
            returnToCurrentWeekIfAway()
            // Calendars may have changed (or access revoked) while away.
            calendarService.refreshAuthorization()
            calendarService.invalidate()
            Task { await calendarService.loadCalendars() }
        }
        .onChange(of: isEditing) {
            // Edit mode is for managing categories: collapse everything.
            guard isEditing else { return }
            withAnimation(Self.cardSpring) {
                expandedCategoryKeys.removeAll()
                editingCategoryKeys.removeAll()
                categoryDisplayOrder.removeAll()
                lastToggledCategory = nil
            }
        }
        .onChange(of: store.selectedDate) {
            if isPastWeek { isEditing = false }
        }
    }

    /// Reopening the app shows the current week (creating it if a new week has started)
    /// after 15 minutes away, or whenever a new week has started since. A quick trip to
    /// another app keeps the week being viewed.
    private func returnToCurrentWeekIfAway() {
        guard let backgroundedAt, store.persistenceError == nil else { return }
        self.backgroundedAt = nil
        let newWeekStarted = store.startOfWeek(containing: backgroundedAt) != store.startOfWeek(containing: Date())
        guard newWeekStarted || Date().timeIntervalSince(backgroundedAt) > 15 * 60 else { return }
        isEditing = false
        store.navigateToDate(Date())
    }

    // MARK: - Week Paging

    /// Horizontal drags move the week grid with the finger; releasing past a
    /// quarter of the width (or flicking) pages to the adjacent week. Vertical
    /// drags are left to the scroll view.
    private var weekSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                if weekSwipeAxis == nil {
                    // A lifted card owns the touch: treating it as a week swipe would disable
                    // the page (below), cancelling the card's drag.
                    weekSwipeAxis = cardDrag == nil && abs(value.translation.width) > abs(value.translation.height) ? .horizontal : .vertical
                    // Track from here so the grid doesn't jump by the recognition distance.
                    weekDragOrigin = value.translation.width
                }
                guard weekSwipeAxis == .horizontal, !isChangingWeek, cardDrag == nil else { return }
                pager.offset = value.translation.width - weekDragOrigin
            }
            .onEnded { value in
                defer { weekSwipeAxis = nil }
                guard weekSwipeAxis == .horizontal, !isChangingWeek, cardDrag == nil else {
                    if cardDrag == nil { withAnimation(.snappy(duration: 0.25)) { pager.offset = 0 } }
                    return
                }
                let distance = value.translation.width - weekDragOrigin
                let predicted = value.predictedEndTranslation.width - weekDragOrigin
                let velocity = value.velocity.width
                if abs(distance) > weekPageWidth * 0.25 || abs(predicted) > weekPageWidth * 0.5 {
                    let weeks = (abs(distance) > weekPageWidth * 0.25 ? distance : predicted) < 0 ? 1 : -1
                    changeWeek(by: weeks, velocity: velocity)
                } else {
                    withAnimation(pagingSpring(to: 0, velocity: velocity)) { pager.offset = 0 }
                }
            }
    }

    /// A spring from the current drag offset to `target` that starts at the finger's
    /// speed, so releasing a flick continues it instead of braking and re-easing.
    private func pagingSpring(to target: CGFloat, velocity: CGFloat) -> Animation {
        let remaining = target - pager.offset
        // interpolatingSpring's velocity is in "fractions of the change per second".
        // Capped below the point where a critically damped spring would overshoot,
        // since an overshoot would show as a jump when the new week takes over.
        let relative = abs(remaining) > 1 ? max(0, min(12, velocity / remaining)) : 0
        return .interpolatingSpring(duration: 0.4, bounce: 0, initialVelocity: relative)
    }

    private func changeWeek(by weeks: Int, velocity: CGFloat = 0) {
        guard let date = Calendar.current.date(byAdding: .weekOfYear, value: weeks, to: store.selectedDate) else { return }
        changeWeek(to: date, velocity: velocity)
    }

    /// A week shown in a neighbor slot instead of the adjacent week, for jumps
    /// of more than one week (date picker, Go to Today).
    private struct PagerTarget {
        let slot: Int
        let date: Date
    }

    private struct PagerPage: Identifiable {
        let slot: Int  // -1 = left of the current week, 0 = current, 1 = right
        let week: Week
        var id: Date { week.startDate }
    }

    /// The current week with a neighbor on each side.
    private func pagerPages(current: Week) -> [PagerPage] {
        [-1, 0, 1].map { slot in
            guard slot != 0 else { return PagerPage(slot: 0, week: current) }
            if let pagerTarget, pagerTarget.slot == slot {
                return PagerPage(slot: slot, week: store.previewWeek(for: pagerTarget.date))
            }
            let date = Calendar.current.date(byAdding: .weekOfYear, value: slot, to: current.startDate) ?? current.startDate
            return PagerPage(slot: slot, week: store.previewWeek(for: date))
        }
    }

    /// Pages to the week containing `date`: the neighbor slot slides in (with the
    /// current week sliding out) in one motion, then becomes the current week in place.
    private func changeWeek(to date: Date, velocity: CGFloat = 0) {
        guard !isChangingWeek, let current = store.selectedWeek else { return }
        let target = store.startOfWeek(containing: date)
        guard !Calendar.current.isDate(target, inSameDayAs: current.startDate) else {
            withAnimation(.snappy(duration: 0.25)) { pager.offset = 0 }
            return
        }
        guard !reduceMotion else {
            pager.offset = 0
            withAnimation(.easeInOut(duration: 0.2)) { store.navigateToDate(date) }
            return
        }

        let slot = target > current.startDate ? 1 : -1
        if let adjacent = Calendar.current.date(byAdding: .weekOfYear, value: slot, to: current.startDate),
           !Calendar.current.isDate(store.startOfWeek(containing: adjacent), inSameDayAs: target) {
            pagerTarget = PagerTarget(slot: slot, date: date)  // off-screen, so no visible swap
        }
        isChangingWeek = true
        // The title switches now; the page hands over only once the slide has fully
        // settled, so the cards never snap the last few points into place.
        arrivingWeekTitle = store.previewWeek(for: date).displayTitle
        let endOffset = -CGFloat(slot) * weekPageWidth
        withAnimation(pagingSpring(to: endOffset, velocity: velocity), completionCriteria: .removed) {
            pager.offset = endOffset
        } completion: {
            // The neighbor page now fills the screen. Make it the current week in
            // place, without animation: it moves to slot 0 as the offset returns to 0.
            var settle = Transaction()
            settle.disablesAnimations = true
            withTransaction(settle) {
                store.navigateToDate(date)
                pagerTarget = nil
                arrivingWeekTitle = nil
                pager.offset = 0
            }
            isChangingWeek = false
        }
    }

    // MARK: - Expand / Collapse All

    /// Collapses every card when any is open; otherwise opens them all.
    @ViewBuilder
    private var expandAllButton: some View {
        if store.persistenceError == nil, !isEditing, let week = store.selectedWeek, !gridEntries(for: week).isEmpty {
            let anyExpanded = gridEntries(for: week).contains { expandedCategoryKeys.contains($0.id) }
            Button {
                withAnimation(Self.cardSpring) {
                    if anyExpanded {
                        expandedCategoryKeys.removeAll()
                        editingCategoryKeys.removeAll()
                    } else {
                        expandedCategoryKeys = Set(gridEntries(for: week).map(\.id))
                    }
                    categoryDisplayOrder.removeAll()
                    lastToggledCategory = nil
                }
            } label: {
                Group {
                    if Theme.isRetro(theme) {
                        Text(anyExpanded ? "[-]" : "[+]")
                            .font(.system(.body, design: .monospaced).bold())
                    } else {
                        Image(systemName: anyExpanded ? "rectangle.compress.vertical" : "rectangle.expand.vertical")
                            .font(.title3)
                            .contentTransition(.symbolEffect(.replace))
                    }
                }
                .foregroundStyle(Theme.textSecondary(theme, rc: rc))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, 12)
            .accessibilityLabel(anyExpanded ? "Collapse all categories" : "Expand all categories")
        }
    }

    // MARK: - Navigation Capsule

    private var weekNavigationBar: some View {
        HStack(spacing: 20) {
            Button {
                changeWeek(by: -1)
            } label: {
                Image(systemName: "chevron.left").font(.body.bold())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Previous week")
            Button { showDatePicker = true } label: {
                Image(systemName: "calendar").font(.body)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Go to week")
            Button {
                changeWeek(by: 1)
            } label: {
                Image(systemName: "chevron.right").font(.body.bold())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Next week")
        }
        .foregroundStyle(Theme.textPrimary(theme, rc: rc))
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background {
            if Theme.isRetro(theme) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Theme.navCapsule(theme))
                    .overlay(RoundedRectangle(cornerRadius: 2).stroke(Theme.cardBorder(theme, rc: rc), lineWidth: 1))
            } else {
                Capsule().fill(Theme.navCapsule(theme))
            }
        }
    }

    // MARK: - Bottom Bar

    @ViewBuilder
    private var bottomBar: some View {
        if Theme.isRetro(theme) {
            if isKeyboardVisible {
                keyboardDoneButton
                    .background(
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Theme.navCapsule(theme))
                            .overlay(RoundedRectangle(cornerRadius: 2).stroke(Theme.cardBorder(theme, rc: rc), lineWidth: 1))
                    )
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .transition(.opacity)
            } else {
                retroBottomBar
                    .transition(.opacity)
            }
        } else {
            // The bar and the Done button share a glass ID, so the bar's glass morphs
            // into the button when the keyboard opens.
            GlassEffectContainer {
                if isKeyboardVisible {
                    keyboardDoneButton
                        .glassEffect(.regular.interactive(), in: Capsule())
                        .glassEffectID("bottomBar", in: bottomBarGlass)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                } else {
                    // The content shape makes the whole bar a touch target. Without it, taps on
                    // Settings/Edit fell through to the scrolling grid behind the see-through
                    // bar and the buttons never fired.
                    bottomBarStack
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .glassEffect(in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .glassEffectID("bottomBar", in: bottomBarGlass)
                }
            }
        }
    }

    /// Closes the keyboard; also closes it when swiped down.
    private var keyboardDoneButton: some View {
        Button {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        } label: {
            Label("Done", systemImage: "keyboard.chevron.compact.down")
                .font(Theme.isRetro(theme) ? .system(.headline, design: .monospaced) : .headline)
                .foregroundStyle(Theme.isRetro(theme) ? Theme.accent(theme, rc: rc) : Theme.textPrimary(theme, rc: rc))
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 10).onEnded { value in
                if value.translation.height > 20 {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
        )
    }

    private var retroBottomBar: some View {
        bottomBarStack
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 2)
                    .fill(Theme.navCapsule(theme))
                    .overlay(RoundedRectangle(cornerRadius: 2).stroke(Theme.cardBorder(theme, rc: rc), lineWidth: 1))
            )
            .contentShape(RoundedRectangle(cornerRadius: 2))
    }

    /// The bar's row, with the events panel expanding above it when toggled on.
    private var bottomBarStack: some View {
        VStack(spacing: 8) {
            if showEventsPanel && showsEventsToggle {
                eventsPanel
                Divider()
            }
            bottomBarContent
        }
    }

    private var bottomBarContent: some View {
        HStack {
            // Settings and the calendar toggle (fixed width so the date stays centered)
            HStack(spacing: 4) {
            Button { showSettings = true } label: {
                Image(systemName: Theme.isRetro(theme) ? "terminal" : "gearshape.fill")
                    .font(.system(size: Self.barIconSize))
                    .foregroundStyle(Theme.textSecondary(theme, rc: rc))
                    .frame(width: Self.barButtonSize, height: Self.barButtonSize)
                    .background {
                        if Theme.isRetro(theme) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Theme.cardFill(theme))
                                .overlay(RoundedRectangle(cornerRadius: 2).stroke(Theme.cardBorder(theme, rc: rc), lineWidth: 1))
                        }
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
            if showsEventsToggle {
                eventsToggle
            }
            }
            .frame(width: Self.barButtonSize * 2 + 4, alignment: .leading)

            Spacer()

            // Viewed week / Go to Today
            if store.selectedWeek?.isCurrentWeek == true {
                weekTitleText
            } else {
                Button {
                    changeWeek(to: Date())
                } label: {
                    VStack(spacing: 1) {
                        weekTitleText
                        Text(Theme.isRetro(theme) ? "> GO_TO_TODAY" : "Go to Today")
                            .font(Theme.isRetro(theme) ? .system(.caption2, design: .monospaced) : .caption2)
                            .foregroundStyle(Theme.accent(theme, rc: rc))
                    }
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Edit / Done
            if !isPastWeek {
                Button {
                    withAnimation(.snappy(duration: 0.25)) { isEditing.toggle() }
                } label: {
                    if isEditing {
                        Image(systemName: "checkmark")
                            .font(.system(size: Self.barIconSize))
                            .foregroundStyle(Theme.isRetro(theme) ? Theme.dotComplete(theme, rc: rc) : .green)
                            .frame(width: Self.barButtonSize, height: Self.barButtonSize)
                            .background {
                                if Theme.isRetro(theme) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Theme.cardFill(theme))
                                        .overlay(RoundedRectangle(cornerRadius: 2).stroke(Theme.dotComplete(theme, rc: rc), lineWidth: 1.5))
                                } else {
                                    Circle().fill(.green.opacity(0.15))
                                        .overlay(Circle().stroke(.green, lineWidth: 1.5))
                                }
                            }
                    } else {
                        // Not a pencil: that's each card's own edit button.
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: Self.barIconSize))
                            .foregroundStyle(Theme.textSecondary(theme, rc: rc))
                            .frame(width: Self.barButtonSize, height: Self.barButtonSize)
                            .background {
                                if Theme.isRetro(theme) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Theme.cardFill(theme))
                                        .overlay(RoundedRectangle(cornerRadius: 2).stroke(Theme.cardBorder(theme, rc: rc), lineWidth: 1))
                                }
                            }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isEditing ? "Done Editing" : "Edit")
                .frame(width: Self.barButtonSize * 2 + 4, alignment: .trailing)
            } else {
                Color.clear.frame(width: Self.barButtonSize * 2 + 4, height: Self.barButtonSize)
            }
        }
    }

    /// "Week of 10/5/26" for the viewed week (or the one arriving while paging).
    private var weekTitleText: some View {
        let title = arrivingWeekTitle ?? store.selectedWeek?.displayTitle ?? "Tasquel"
        return Text(Theme.isRetro(theme) ? "[\(title)]" : title)
            .font(Theme.isRetro(theme) ? .system(.subheadline, design: .monospaced).bold() : .subheadline.bold())
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }

    private var todayDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        let base = formatter.string(from: Date())
        let day = Calendar.current.component(.day, from: Date())
        let suffix: String
        switch day {
        case 1, 21, 31: suffix = "st"
        case 2, 22: suffix = "nd"
        case 3, 23: suffix = "rd"
        default: suffix = "th"
        }
        return "\(base)\(suffix)"
    }

    // MARK: - Week Content

    /// Bottom bar icons: 20% larger than the original .title3 (20pt), with matching tap areas.
    private static let barIconSize: CGFloat = 24
    private static let barButtonSize: CGFloat = 52
    /// Room above the keyboard taken by the Done button.
    private static let keyboardDoneClearance: CGFloat = 64

    /// One spring for expand, collapse, and the reflow of neighboring cards.
    private static let cardSpring = Animation.spring(duration: 0.45, bounce: 0.12)

    @ViewBuilder
    private func weekContent(_ week: Week) -> some View {
        let categories = week.categories
        let showAdd = isEditing && !week.isPastWeek

        ScrollView {
            VStack(spacing: 8) {
                // Expanded cards take a full row; other open cards remain open.
                CategoryGridLayout(spacing: 8) {
                    ForEach(gridEntries(for: week)) { entry in
                        let isExpanded = expandedCategoryKeys.contains(entry.id)
                        CategoryGridCard(
                            category: entry.category,
                            store: store,
                            isExpanded: isExpanded,
                            isEditing: isEditing,
                            isEditingTasks: isEditing || editingCategoryKeys.contains(entry.id),
                            isPastWeek: week.isPastWeek,
                            onToggleEdit: {
                                withAnimation(.snappy(duration: 0.25)) {
                                    if editingCategoryKeys.contains(entry.id) {
                                        editingCategoryKeys.remove(entry.id)
                                    } else {
                                        editingCategoryKeys.insert(entry.id)
                                    }
                                }
                            },
                            onExpand: { expandCard(entry.id, in: week) },
                            onCollapse: {
                                withAnimation(Self.cardSpring) { collapseCategory(entry.id) }
                            }
                        )
                        // The dragged card leaves a gap where it will land; a lifted copy
                        // follows the finger (see the overlay below).
                        .opacity(cardDrag?.key == entry.id ? 0 : 1)
                        .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.cardGridSpace)) } action: { frame in
                            if week.id == store.selectedWeek?.id { cardFrames[entry.id] = frame }
                        }
                        // Closed cards can be held and dragged to a new place. (Holding inside an
                        // open card is for its tasks.)
                        .modifier(CardDragGesture(
                            isCollapsed: !isExpanded,
                            canDrag: !week.isPastWeek,
                            onTap: {
                                // A hold that's released without moving isn't a tap.
                                guard cardDrag == nil, Date().timeIntervalSince(lastCardDrop) > 0.5 else { return }
                                expandCard(entry.id, in: week)
                            },
                            onLift: { liftCard(entry.id, in: week) },
                            onMove: { start, location in moveDraggedCard(start: start, to: location) },
                            onDrop: { dropCard(in: week) }
                        ))
                        .accessibilityActions {
                            if !week.isPastWeek && !isExpanded { cardMoveActions(entry.id, in: week) }
                        }
                        // Outside the modifiers above, where the grid layout can read it.
                        .categoryGridFullWidth(isExpanded)
                        // The card being opened or closed stays above neighbors sliding past it.
                        .zIndex(entry.id == lastToggledCategory ? 2 : isExpanded ? 1 : 0)
                    }
                    if showAdd {
                        addCategoryButton
                            .transition(.opacity)
                    }
                }
                .coordinateSpace(.named(Self.cardGridSpace))
                .overlay(alignment: .topLeading) { liftedCard(in: week) }

                if categories.isEmpty && !isEditing {
                    ContentUnavailableView(
                        "No Categories",
                        systemImage: "folder.badge.plus",
                        description: Text("Tap the grid button below to add categories.")
                    )
                    .padding(.top, 40)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 80)
        }
        // Dragging down into the keyboard closes it; scrolling up keeps it open.
        .scrollDismissesKeyboard(.interactively)
        .scrollDisabled(cardDrag != nil)
        .sensoryFeedback(.impact(weight: .medium), trigger: cardDrag?.key) { _, new in new != nil }
        .sensoryFeedback(.selection, trigger: liveCardOrder)
        // Keeps the field being edited (and its options) clear of the Done button.
        .safeAreaPadding(.bottom, isKeyboardVisible ? Self.keyboardDoneClearance : 0)
    }

    // MARK: - Grid Order & Expansion

    /// Weeks create new category IDs, so layout state follows a category's name.
    /// The occurrence distinguishes categories with the same name in one week.
    private struct CategoryLayoutKey: Hashable {
        let name: String
        let occurrence: Int

    }

    /// Keyed by `CategoryLayoutKey` so a card keeps its identity across weeks.
    private struct CategoryGridEntry: Identifiable {
        let id: CategoryLayoutKey
        let category: Category
    }

    private func categoryKeys(for categories: [Category]) -> [UUID: CategoryLayoutKey] {
        var occurrences: [String: Int] = [:]
        var keys: [UUID: CategoryLayoutKey] = [:]
        for category in categories {
            let occurrence = occurrences[category.name, default: 0]
            keys[category.id] = CategoryLayoutKey(name: category.name, occurrence: occurrence)
            occurrences[category.name] = occurrence + 1
        }
        return keys
    }

    /// Cards in display order: any reordering from expansion first, then the rest.
    private func gridEntries(for week: Week) -> [CategoryGridEntry] {
        let keysByID = categoryKeys(for: week.categories)
        let entries = week.categories.compactMap { category in
            keysByID[category.id].map { CategoryGridEntry(id: $0, category: category) }
        }
        let entriesByKey = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
        let order = week.id == store.selectedWeek?.id ? (liveCardOrder ?? categoryDisplayOrder) : categoryDisplayOrder
        let ordered = order.compactMap { entriesByKey[$0] }
        let orderedKeys = Set(ordered.map(\.id))
        return ordered + entries.filter { !orderedKeys.contains($0.id) }
    }

    /// Expanding the right-hand card of a row moves it into its left neighbor's
    /// slot, so it opens in place instead of dropping below an already-open card.
    private func expandCard(_ key: CategoryLayoutKey, in week: Week) {
        guard !isEditing else { return }  // edit mode keeps cards collapsed
        withAnimation(Self.cardSpring) { expandCategory(key, in: week) }
    }

    private func expandCategory(_ key: CategoryLayoutKey, in week: Week) {
        var order = gridEntries(for: week).map(\.id)
        let rows = CategoryGridLayout.rows(fullWidth: order.map { expandedCategoryKeys.contains($0) })
        if let row = rows.first(where: { $0.count == 2 && order[$0[1]] == key }) {
            order.remove(at: row[1])
            order.insert(key, at: row[0])
            categoryDisplayOrder = order
        }
        expandedCategoryKeys.insert(key)
        lastToggledCategory = key
    }

    // MARK: - Card Dragging

    static let cardGridSpace = "cardGrid"

    /// A card lifted for dragging: where it was grabbed (relative to its top-left
    /// corner) and where the finger is now, in the grid's coordinates.
    private struct CardDrag {
        let key: CategoryLayoutKey
        var grab: CGSize?
        var location: CGPoint
        /// The card last swapped with, so hovering over it doesn't swap back and forth.
        var lastTarget: CategoryLayoutKey?
    }

    private func liftCard(_ key: CategoryLayoutKey, in week: Week) {
        guard cardDrag == nil, let frame = cardFrames[key] else { return }
        liveCardOrder = gridEntries(for: week).map(\.id)
        withAnimation(.snappy(duration: 0.2)) {
            cardDrag = CardDrag(key: key, grab: nil, location: frame.origin)
        }
    }

    /// The lifted card follows the finger; when the finger is over another card, the
    /// dragged card takes its place and the cards in between slide along.
    private func moveDraggedCard(start: CGPoint, to location: CGPoint) {
        guard var drag = cardDrag, let frame = cardFrames[drag.key] else { return }
        if drag.grab == nil {
            drag.grab = CGSize(width: start.x - frame.minX, height: start.y - frame.minY)
        }
        drag.location = location
        let target = cardFrames.first { $0.key != drag.key && $0.value.contains(location) }?.key
        if let target, target != drag.lastTarget, var order = liveCardOrder,
           let from = order.firstIndex(of: drag.key), let to = order.firstIndex(of: target) {
            order.move(fromOffsets: [from], toOffset: to > from ? to + 1 : to)
            withAnimation(.snappy(duration: 0.25)) { liveCardOrder = order }
        }
        drag.lastTarget = target
        cardDrag = drag
    }

    /// Saves the new order (this week and future weeks), then settles the lifted card
    /// into its place.
    private func dropCard(in week: Week) {
        guard let drag = cardDrag else { return }
        lastCardDrop = Date()
        if let order = liveCardOrder {
            store.setCategoryOrder(order.map(\.name))
            if !categoryDisplayOrder.isEmpty { categoryDisplayOrder = order }
        }
        let grab = drag.grab ?? .zero
        let slot = cardFrames[drag.key]?.origin ?? drag.location
        withAnimation(.snappy(duration: 0.25)) {
            cardDrag?.location = CGPoint(x: slot.x + grab.width, y: slot.y + grab.height)
        } completion: {
            cardDrag = nil
            liveCardOrder = nil
        }
    }

    /// A copy of the dragged card, lifted above the grid under the finger.
    @ViewBuilder
    private func liftedCard(in week: Week) -> some View {
        if let drag = cardDrag, week.id == store.selectedWeek?.id,
           let entry = gridEntries(for: week).first(where: { $0.id == drag.key }),
           let frame = cardFrames[drag.key] {
            let grab = drag.grab ?? .zero
            CategoryGridCard(
                category: entry.category, store: store, isExpanded: false,
                isEditing: isEditing, isEditingTasks: false, isPastWeek: false,
                onToggleEdit: {}, onExpand: {}, onCollapse: {}
            )
            .frame(width: frame.width, height: frame.height)
            .scaleEffect(1.05)
            .shadow(color: .black.opacity(0.3), radius: 16, y: 8)
            .offset(x: drag.location.x - grab.width, y: drag.location.y - grab.height)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    /// VoiceOver: move a closed card one place earlier or later.
    @ViewBuilder
    private func cardMoveActions(_ key: CategoryLayoutKey, in week: Week) -> some View {
        let order = gridEntries(for: week).map(\.id)
        if let index = order.firstIndex(of: key) {
            if index > 0 {
                Button("Move Earlier") { moveCard(key, by: -1, in: order) }
            }
            if index < order.count - 1 {
                Button("Move Later") { moveCard(key, by: 1, in: order) }
            }
        }
    }

    private func moveCard(_ key: CategoryLayoutKey, by offset: Int, in order: [CategoryLayoutKey]) {
        guard let from = order.firstIndex(of: key), order.indices.contains(from + offset) else { return }
        var order = order
        order.swapAt(from, from + offset)
        withAnimation(.snappy(duration: 0.25)) {
            store.setCategoryOrder(order.map(\.name))
            if !categoryDisplayOrder.isEmpty { categoryDisplayOrder = order }
        }
    }

    private func collapseCategory(_ key: CategoryLayoutKey) {
        editingCategoryKeys.remove(key)
        expandedCategoryKeys.remove(key)
        lastToggledCategory = key
        if expandedCategoryKeys.isEmpty { categoryDisplayOrder.removeAll() }
    }

    // MARK: - Calendar Events (bottom bar)

    /// The calendar toggle appears once events are turned on in Settings.
    private var showsEventsToggle: Bool {
        FeatureAccess.isCalendarUnlocked && store.calendarEventsEnabled && calendarService.isAuthorized
    }

    private var eventsToggle: some View {
        Button {
            withAnimation(.spring(duration: 0.4, bounce: 0.12)) { showEventsPanel.toggle() }
        } label: {
            Image(systemName: Theme.isRetro(theme) ? "calendar" : (showEventsPanel ? "calendar.circle.fill" : "calendar"))
                .font(.system(size: Self.barIconSize))
                .foregroundStyle(weekHasEvents ? eventsGreen : (showEventsPanel ? Theme.accent(theme, rc: rc) : Theme.textSecondary(theme, rc: rc)))
                .frame(width: Self.barButtonSize, height: Self.barButtonSize)
                .background {
                    if Theme.isRetro(theme) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Theme.cardFill(theme))
                            .overlay(RoundedRectangle(cornerRadius: 2).stroke(
                                showEventsPanel ? Theme.accent(theme, rc: rc) : Theme.cardBorder(theme, rc: rc), lineWidth: 1))
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(showEventsPanel ? "Hide events" : "Show events")
        .accessibilityValue(weekHasEvents ? "Has events this week" : "")
        // Load the viewed week's events even while the panel is closed, to color the icon.
        .task(id: eventsLoadKey) {
            guard let key = eventsLoadKey else { return }
            await calendarService.load(weekStarting: key.weekStart, calendarIDs: key.calendarIDs)
        }
    }

    private var eventsGreen: Color {
        Theme.isRetro(theme) ? Theme.dotComplete(theme, rc: rc) : .green
    }

    /// Whether the viewed week has any events from the chosen calendars.
    private var weekHasEvents: Bool {
        guard let key = eventsLoadKey else { return false }
        return !(calendarService.days(forWeekStarting: key.weekStart, calendarIDs: key.calendarIDs) ?? []).isEmpty
    }

    private var eventsLoadKey: EventsLoadKey? {
        guard let week = store.selectedWeek else { return nil }
        return EventsLoadKey(
            weekStart: week.startDate,
            calendarIDs: Set(calendarService.effectiveSelection(store.selectedCalendarIDs)),
            generation: calendarService.generation
        )
    }

    @ViewBuilder
    private var eventsPanel: some View {
        if let week = store.selectedWeek {
            let calendarIDs = Set(calendarService.effectiveSelection(store.selectedCalendarIDs))
            CalendarEventsPanel(
                store: store,
                days: calendarService.days(forWeekStarting: week.startDate, calendarIDs: calendarIDs),
                onOpen: openInCalendar,
                onDismiss: {
                    withAnimation(.spring(duration: 0.4, bounce: 0.12)) { showEventsPanel = false }
                }
            )
            .task(id: EventsLoadKey(weekStart: week.startDate, calendarIDs: calendarIDs, generation: calendarService.generation)) {
                await calendarService.load(weekStarting: week.startDate, calendarIDs: calendarIDs)
            }
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }

    /// Opens the Calendar app at the event's date (iOS can't open a specific event).
    private func openInCalendar(_ event: CalendarEvent) {
        if let url = URL(string: "calshow:\(event.start.timeIntervalSinceReferenceDate)") {
            openURL(url)
        }
    }

    private struct EventsLoadKey: Hashable {
        let weekStart: Date
        let calendarIDs: Set<String>
        let generation: Int
    }

    @ViewBuilder
    private var addCategoryButton: some View {
        Button { showAddCategory = true } label: {
            VStack(spacing: 8) {
                Image(systemName: Theme.isRetro(theme) ? "plus.square" : "plus")
                    .font(.title2).foregroundStyle(Theme.textSecondary(theme, rc: rc))
                Text(Theme.isRetro(theme) ? "+ NEW_CATEGORY" : "Add Category")
                    .font(Theme.captionFont(theme)).foregroundStyle(Theme.textSecondary(theme, rc: rc))
            }
            .frame(maxWidth: .infinity, minHeight: 140)
            .background(
                RoundedRectangle(cornerRadius: Theme.cardCornerRadius(theme))
                    .strokeBorder(style: StrokeStyle(lineWidth: Theme.isRetro(theme) ? 1 : 2, dash: Theme.isRetro(theme) ? [] : [8]))
                    .foregroundStyle(Theme.isRetro(theme) ? Theme.cardBorder(theme, rc: rc) : Theme.textTertiary(theme, rc: rc))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Week Pager Support

/// Horizontal offset of the week pages. Kept out of ContentView's own state so a
/// drag only re-renders `PagerTrack`, not the three pages of cards.
@Observable
private final class WeekPagerState {
    var offset: CGFloat = 0
}

/// Lays the pages out in a ZStack and shifts them by the pager offset.
private struct PagerTrack<Content: View>: View {
    let pager: WeekPagerState
    @ViewBuilder let content: Content

    var body: some View {
        ZStack { content }
            .offset(x: pager.offset)
    }
}

#Preview {
    ContentView()
}

// MARK: - Card Drag Gesture

/// A closed card's touches: tap to open it, or hold and then drag to move it. A swipe
/// that starts before the hold completes still scrolls or changes week.
///
/// The hold-and-drag runs alongside the scroll view's own gesture, so the scroll view
/// can't take the finger away once the card is lifted. It may still be cancelled (a
/// call, a system gesture); `isHolding` resets then too, which drops the card.
private struct CardDragGesture: ViewModifier {
    let isCollapsed: Bool
    let canDrag: Bool
    let onTap: () -> Void
    let onLift: () -> Void
    let onMove: (_ start: CGPoint, _ location: CGPoint) -> Void
    let onDrop: () -> Void

    @GestureState private var isHolding = false

    func body(content: Content) -> some View {
        if !isCollapsed {
            content
        } else if !canDrag {
            content.contentShape(Rectangle()).onTapGesture(perform: onTap)
        } else {
            content
                .contentShape(Rectangle())
                .onTapGesture(perform: onTap)
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.35)
                        .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named(ContentView.cardGridSpace)))
                        .updating($isHolding) { value, state, _ in
                            if case .second(true, _) = value { state = true }
                        }
                        .onChanged { value in
                            guard case .second(true, let drag) = value else { return }
                            onLift()
                            if let drag { onMove(drag.startLocation, drag.location) }
                        }
                )
                // Ends, or is cancelled: either way the card drops.
                .onChange(of: isHolding) { _, holding in
                    if !holding { onDrop() }
                }
        }
    }
}
