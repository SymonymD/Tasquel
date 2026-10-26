import SwiftUI
import UniformTypeIdentifiers
// MARK: - Root View

struct ContentView: View {
    let store: ChecklistStore
    let calendarService: CalendarService
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
    /// Each card's place in its week's grid, for finding the card under the finger.
    /// Kept for every page, so a week that slides in already has its cards' places.
    /// Not observed (a plain class): frames change on every frame of a card opening or
    /// closing, and redrawing the whole screen for each made scrolling and expanding janky.
    /// They're only read while a card is dragged, which redraws anyway.
    @State private var cardFrameStore = CardFrameStore()
    /// Category names in the chosen sort order (empty for manual). Refreshed only at calm
    /// moments (opening, changing week or the setting, all cards closed), never while
    /// tasks are ticked, so a card doesn't jump from under the finger.
    @State private var sortedNames: [String] = []

    private final class CardFrameStore {
        var frames: [DayKey: [CategoryLayoutKey: CGRect]] = [:]
    }
    /// The order when the card was lifted, to tell whether dropping it changed anything.
    @State private var liftedCardOrder: [CategoryLayoutKey]?
    @State private var lastCardDrop = Date.distantPast
    /// Cards whose own edit button is on (only their tasks become editable).
    @State private var editingCategoryKeys: Set<CategoryLayoutKey> = []
    /// The cards that were open when edit mode closed them, reopened when it ends.
    @State private var expandedBeforeEditing: Set<CategoryLayoutKey> = []
    @State private var showOnboarding = false
    @State private var showStartFreshConfirmation = false
    /// The bottom bar's calendar toggle: expands the bar to show the week's events.
    @State private var showEventsPanel = false
    /// The events panel is in the bar: from opening until its closing animation ends.
    /// (SwiftUI doesn't clip or move a view while removing it, so the panel used to sit
    /// in place over the grid while the bar shrank away from it.)
    @State private var isEventsPanelMounted = false
    /// The events panel is being dragged down; the grid ignores the bar's height meanwhile.
    @State private var isEventsPanelDragged = false
    /// While the keyboard is up, the bottom bar turns into a Done button.
    @State private var isKeyboardVisible = false
    private var isSheetPresented: Bool {
        showSettings || showAddCategory || showDatePicker || showOnboarding
    }
    /// The bottom bar's height above the home indicator; the grid scrolls clear of it.
    @State private var bottomBarHeight: CGFloat = 68
    /// The screen's bottom safe area (home indicator), which the flush bar covers.
    @State private var homeIndicatorInset: CGFloat = 34
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    /// When the app last went to the background, to decide whether reopening it
    /// should jump back to the current week.
    @State private var backgroundedAt: Date?
    /// Today, for the bottom bar's date. Updated when the day changes while the app is open.
    @State private var today = Date()

    // Week paging (swipe or arrows): last/this/next week sit side by side.
    // Read only by PagerTrack, so dragging moves the pages without rebuilding them.
    @State private var pager = WeekPagerState()
    @State private var pagerTarget: PagerTarget?
    @State private var arrivingWeekTitle: String?  // shown from release until the new week takes over
    @State private var weekSwipeAxis: Axis?
    /// Resets on its own when iOS cancels the touch (onEnded isn't called then), so a
    /// cancelled swipe can't leave the page disabled and the grid unable to scroll.
    @GestureState private var isWeekSwiping = false
    @State private var weekDragOrigin: CGFloat = 0  // translation when the swipe was recognized
    @State private var isChangingWeek = false
    @State private var weekPageWidth: CGFloat = 400
    /// Whether the window is wider than tall (an iPad in landscape, or a wide window).
    @State private var isLandscape = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    private var theme: AppearanceMode { store.appearanceMode }
    private var rc: RetroColor { store.retroColor }

    private var isPastWeek: Bool {
        store.selectedWeek.map(store.isPastWeek) ?? false
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.background(theme).ignoresSafeArea()

            VStack(spacing: 12) {
                // The viewed week; today's date is shown in the bottom bar.
                weekTitleText
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
                        Button("Start Fresh", role: .destructive) { showStartFreshConfirmation = true }
                        Link("Contact Support", destination: AppInfo.supportURL)
                    }
                    .confirmationDialog("Start Fresh?", isPresented: $showStartFreshConfirmation, titleVisibility: .visible) {
                        Button("Start Fresh", role: .destructive) {
                            store.setAsideUnreadableData()
                            if store.persistenceError == nil && store.shouldShowWelcome {
                                showOnboarding = true
                            }
                        }
                    } message: {
                        Text(startFreshMessage)
                    }
                    Spacer()
                } else if let week = store.selectedWeek {
                    weekNavigationBar
                    if isPastWeek {
                        // Past weeks can't be changed; say so before a tap does nothing.
                        Label(Theme.isRetro(theme) ? "PAST_WEEK // READ_ONLY" : "Past week · view only", systemImage: "lock")
                            .font(Theme.isRetro(theme) ? .system(.caption, design: .monospaced) : .caption)
                            .foregroundStyle(Theme.textSecondary(theme, rc: rc))
                            .padding(.bottom, -4)
                    } else if isEditing {
                        Text(editModeHint)
                            .font(Theme.isRetro(theme) ? .system(.caption, design: .monospaced) : .caption)
                            .foregroundStyle(Theme.textSecondary(theme, rc: rc))
                            .padding(.bottom, -4)
                            .transition(.opacity)
                    }
                    if store.isSaveFailing && store.saveError == nil {
                        saveFailingNotice
                    }
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
                    .onGeometryChange(for: Bool.self) { $0.size.width > $0.size.height } action: { isLandscape = $0 }
                    .simultaneousGesture(weekSwipeGesture)
                    .onChange(of: isWeekSwiping) { _, swiping in
                        // Cancelled rather than ended: put the page back.
                        guard !swiping, weekSwipeAxis != nil else { return }
                        weekSwipeAxis = nil
                        if !isChangingWeek { withAnimation(.snappy(duration: 0.25)) { pager.offset = 0 } }
                    }
                } else {
                    Spacer()
                    ContentUnavailableView("No Week Data", systemImage: "calendar.badge.exclamationmark")
                    Spacer()
                }
            }

            if store.persistenceError == nil {
                // Pinned to the very bottom of the screen; the bar pads itself above the
                // home indicator. When the keyboard opens the bar goes at once: fading it out
                // let it ride up the screen on top of the rising keyboard.
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    if !isKeyboardVisible {
                        bottomBar
                            // Not while the events panel follows a finger: the grid would re-pad
                            // itself on every frame of the drag.
                            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                                if !isEventsPanelDragged { bottomBarHeight = height }
                            }
                            .transition(.asymmetric(insertion: .opacity, removal: .identity))
                    }
                }
                .ignoresSafeArea(.container, edges: .bottom)

                // Just above the keyboard while it's up.
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    if isKeyboardVisible {
                        keyboardDoneLayer
                            .transition(.opacity)
                    }
                }
            }

            // "Deleted … · Undo", just above the bottom bar (or the keyboard).
            if store.persistenceError == nil, let deletion = store.lastDelete {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    undoDeleteMessage(deletion)
                        .padding(.horizontal, 16)
                        .padding(.bottom, isKeyboardVisible
                                 ? Self.keyboardDoneClearance + 8
                                 : max(8, bottomBarHeight - homeIndicatorInset + 8))
                }
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom)))
            }

            // Retro scanline overlay
            if Theme.isRetro(theme) {
                ScanlineOverlay()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        // Ignoring the keyboard, the bottom inset is the home indicator's alone.
        .background {
            Color.clear
                .ignoresSafeArea(.keyboard)
                .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.bottom } action: { homeIndicatorInset = $0 }
        }
        .foregroundStyle(Theme.textPrimary(theme, rc: rc))
        .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: store.lastDelete)
        .preferredColorScheme(store.colorScheme)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            // A keyboard for a field in a sheet isn't this screen's: on iPad the bar would
            // change around the form sheet.
            guard !isSheetPresented else { return }
            withAnimation(.snappy(duration: 0.3)) { isKeyboardVisible = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.snappy(duration: 0.3)) { isKeyboardVisible = false }
        }
        .sheet(isPresented: $showDatePicker) {
            DatePickerSheet(selectedDate: store.selectedDate, firstWeekday: store.firstWeekday,
                            theme: theme, rc: rc) { date in
                changeWeek(to: date)
            }
            .presentationDetents([.medium, .large])
            .preferredColorScheme(store.colorScheme)
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
            .preferredColorScheme(store.colorScheme)
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingSheet(store: store, calendar: calendarService)
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
            if scenePhase == .background {
                backgroundedAt = Date()
                // Saves a title being typed: iOS may end the app while it's away.
                dismissKeyboard()
            }
            guard scenePhase == .active else { return }
            // Only after a real trip away: Notification Center or Control Center (inactive)
            // mustn't re-sort cards that are in use.
            if backgroundedAt != nil { refreshSortOrder() }
            today = Date()
            returnToCurrentWeekIfAway()
            // Calendars may have changed (or access revoked) while away.
            calendarService.refreshAuthorization()
            calendarService.invalidate()
            Task { await calendarService.loadCalendars() }
        }
        .onChange(of: isEditing) {
            // Edit mode is for managing categories: collapse everything, and reopen the
            // same cards afterwards.
            withAnimation(cardAnimation) {
                if isEditing {
                    expandedBeforeEditing = expandedCategoryKeys
                    expandedCategoryKeys.removeAll()
                    editingCategoryKeys.removeAll()
                } else {
                    expandedCategoryKeys = expandedBeforeEditing
                    expandedBeforeEditing.removeAll()
                }
                categoryDisplayOrder.removeAll()
                lastToggledCategory = nil
            }
        }
        .onChange(of: store.selectedDate) {
            if isPastWeek { isEditing = false }
        }
        .background { sortOrderWatcher }
        // Midnight (or a time zone change) while the app is open.
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            handleDayChange()
        }
        .alert("Couldn't Save", isPresented: Binding(
            get: { store.saveError != nil },
            set: { if !$0 { store.dismissSaveError() } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.saveError ?? "")
        }
    }

    /// A new day while the app stays open. If the week being viewed was the current week
    /// and a new week has started, the new current week is shown (the old one is now
    /// read-only); otherwise the viewed week is brought up to date.
    private func handleDayChange() {
        let previousToday = today
        today = Date()
        guard store.persistenceError == nil, let week = store.selectedWeek else { return }
        let wasCurrentWeek = week.startDay == store.weekStartDay(containing: previousToday)
        if wasCurrentWeek && store.isPastWeek(week) {
            dismissKeyboard()
            isEditing = false
            store.navigateToDate(today)
        } else if !store.isPastWeek(week) {
            store.navigateToDate(store.selectedDate)
        }
    }

    /// Ends text editing, which commits whatever is being typed.
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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
        store.navigateToDate(today)
    }

    // MARK: - Week Paging

    /// Horizontal drags move the week grid with the finger; releasing past a
    /// quarter of the width (or flicking) pages to the adjacent week. Vertical
    /// drags are left to the scroll view.
    private var weekSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .updating($isWeekSwiping) { _, swiping, _ in swiping = true }
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
        guard let date = store.calendar.date(byAdding: .weekOfYear, value: weeks, to: store.selectedDate) else { return }
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
            let date = store.calendar.date(byAdding: .weekOfYear, value: slot, to: current.startDate) ?? current.startDate
            return PagerPage(slot: slot, week: store.previewWeek(for: date))
        }
    }

    /// Pages to the week containing `date`: the neighbor slot slides in (with the
    /// current week sliding out) in one motion, then becomes the current week in place.
    private func changeWeek(to date: Date, velocity: CGFloat = 0) {
        guard !isChangingWeek, let current = store.selectedWeek else { return }
        let target = store.startOfWeek(containing: date)
        guard !store.calendar.isDate(target, inSameDayAs: current.startDate) else {
            withAnimation(.snappy(duration: 0.25)) { pager.offset = 0 }
            return
        }
        // A title being typed is saved to the week it belongs to, before the week changes.
        let wasTyping = isKeyboardVisible
        dismissKeyboard()
        guard !reduceMotion else {
            pager.offset = 0
            isChangingWeek = true
            // Gives the field's commit (on losing focus) a moment to run first.
            DispatchQueue.main.asyncAfter(deadline: .now() + (wasTyping ? 0.1 : 0)) {
                withAnimation(.easeInOut(duration: 0.2)) { store.navigateToDate(date) }
                isChangingWeek = false
            }
            return
        }

        let slot = target > current.startDate ? 1 : -1
        if let adjacent = store.calendar.date(byAdding: .weekOfYear, value: slot, to: current.startDate),
           !store.calendar.isDate(store.startOfWeek(containing: adjacent), inSameDayAs: target) {
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

    // MARK: - Undo

    /// Shown for five seconds after a delete; deleting no longer asks first, so this is
    /// how a mistaken delete is taken back.
    private func undoDeleteMessage(_ deletion: ChecklistStore.UndoableDelete) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "trash")
                .foregroundStyle(Theme.textSecondary(theme, rc: rc))
            Text(Theme.isRetro(theme) ? "deleted \(deletion.description)" : "Deleted \(deletion.description)")
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 8)
            Button(Theme.isRetro(theme) ? "[UNDO]" : "Undo") {
                withAnimation(cardAnimation) { store.undoLastDelete() }
            }
            .buttonStyle(.plain)
            .fontWeight(.semibold)
            .foregroundStyle(Theme.accent(theme, rc: rc))
            .touchTarget()
            .accessibilityLabel("Undo delete")
        }
        .font(Theme.isRetro(theme) ? .system(.subheadline, design: .monospaced) : .subheadline)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background {
            if Theme.isRetro(theme) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Theme.navCapsule(theme))
                    .overlay(RoundedRectangle(cornerRadius: 2).stroke(Theme.cardBorder(theme, rc: rc), lineWidth: 1))
            } else {
                Capsule().fill(.clear).glassEffect(.regular, in: Capsule())
            }
        }
        .task(id: deletion.token) {
            // With VoiceOver it stays until the next change: five seconds isn't enough to
            // move to it, and deleting no longer asks first.
            guard !voiceOverEnabled else { return }
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled, store.lastDelete?.token == deletion.token else { return }
            store.clearUndo()
        }
    }

    // MARK: - Problems Saving or Loading

    /// What Start Fresh leaves behind, named for the file that couldn't be read.
    private var startFreshMessage: String {
        var lost: [String] = []
        if store.weekLoadError != nil { lost.append("your tasks and weeks") }
        if store.settingsLoadError != nil { lost.append("your settings and saved categories") }
        return "Tasquel will start over without \(lost.joined(separator: " or ")). The file it can't open is set aside on this device, not deleted. If you need it back, contact Support before starting fresh."
    }

    /// Stays while saves keep failing, after the one-time alert is dismissed.
    private var saveFailingNotice: some View {
        Label(Theme.isRetro(theme) ? "ERR: CHANGES_NOT_SAVED" : "Changes aren't being saved", systemImage: "exclamationmark.triangle.fill")
            .font(Theme.isRetro(theme) ? .system(.caption, design: .monospaced).bold() : .caption.bold())
            .foregroundStyle(Theme.destructive(theme))
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Theme.destructive(theme).opacity(0.12), in: Capsule())
            .accessibilityHint("Free up storage on your device; everything is saved again with your next change.")
    }

    // MARK: - Expand / Collapse All

    /// Collapses every card when any is open; otherwise opens them all.
    @ViewBuilder
    private var expandAllButton: some View {
        if store.persistenceError == nil, !isEditing, let week = store.selectedWeek, !gridEntries(for: week).isEmpty {
            let anyExpanded = gridEntries(for: week).contains { expandedCategoryKeys.contains($0.id) }
            Button {
                if anyExpanded {
                    collapseAllCards()
                } else {
                    withAnimation(cardAnimation) {
                        expandedCategoryKeys = Set(gridEntries(for: week).map(\.id))
                        categoryDisplayOrder.removeAll()
                        lastToggledCategory = nil
                    }
                }
            } label: {
                Group {
                    if Theme.isRetro(theme) {
                        Text(anyExpanded ? "[-]" : "[+]")
                            .font(.system(.body, design: .monospaced).bold())
                    } else {
                        Image(systemName: anyExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
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
            .accessibilityLabel(anyExpanded ? "Close all cards" : "Open all cards")
        }
    }

    private func collapseAllCards() {
        dismissKeyboard()  // see collapseCategory
        withAnimation(cardAnimation) {
            expandedCategoryKeys.removeAll()
            editingCategoryKeys.removeAll()
            categoryDisplayOrder.removeAll()
            lastToggledCategory = nil
        }
    }

    // MARK: - Navigation Capsule

    private var weekNavigationBar: some View {
        HStack(spacing: 20) {
            Button {
                changeWeek(by: -1)
            } label: {
                Image(systemName: "chevron.left").font(.body.bold())
                    .touchTarget()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Previous week")
            Button { showDatePicker = true } label: {
                Image(systemName: "calendar").font(.body)
                    .touchTarget()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Go to week")
            Button {
                changeWeek(by: 1)
            } label: {
                Image(systemName: "chevron.right").font(.body.bold())
                    .touchTarget()
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
            retroBottomBar
        } else {
            // Flush with the bottom of the screen, like a tab bar: a flat translucent
            // bar with only a top border, running down behind the home indicator
            // while the buttons stay above it.
            // The content shape makes the whole bar a touch target. Without it, taps on
            // Settings/Edit fell through to the scrolling grid behind the see-through
            // bar and the buttons never fired.
            bottomBarStack
                .padding(.horizontal, 28)
                .padding(.top, 8)
                .padding(.bottom, homeIndicatorInset)
                .contentShape(Rectangle())
                .background {
                    Rectangle().fill(.bar)
                        .overlay(alignment: .top) { Divider() }
                }
        }
    }

    /// The keyboard's Done, at the right just above the keyboard.
    private var keyboardDoneLayer: some View {
        Group {
            if Theme.isRetro(theme) {
                keyboardDoneButton
                    .background(
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Theme.navCapsule(theme))
                            .overlay(RoundedRectangle(cornerRadius: 2).stroke(Theme.cardBorder(theme, rc: rc), lineWidth: 1))
                    )
            } else {
                keyboardDoneButton
                    .glassEffect(.regular.interactive(), in: Circle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    /// Closes the keyboard; also closes it when swiped down. Tapping it first saves what's
    /// typed in an add-task or goal field (rows watch `keyboardDoneRequests` while their
    /// field still has focus), then closes the keyboard.
    private var keyboardDoneButton: some View {
        Button {
            store.keyboardDoneRequests += 1
            DispatchQueue.main.async {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        } label: {
            // A small icon at the right rather than a full-width bar (user's choice).
            Image(systemName: "keyboard.chevron.compact.down")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Theme.isRetro(theme) ? Theme.accent(theme, rc: rc) : Theme.textPrimary(theme, rc: rc))
                .frame(width: 48, height: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Done")
        .accessibilityHint("Saves what you typed and closes the keyboard")
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
            .padding(.horizontal, 28)
            .padding(.top, 8)
            .padding(.bottom, homeIndicatorInset)
            .contentShape(Rectangle())
            .background {
                Theme.navCapsule(theme)
                    .overlay(alignment: .top) { Theme.cardBorder(theme, rc: rc).frame(height: 1) }
            }
    }

    /// The bar's row, with the events panel expanding above it when toggled on.
    private var bottomBarStack: some View {
        VStack(spacing: 0) {
            if isEventsPanelMounted && showsEventsToggle {
                VStack(spacing: 8) {
                    eventsPanel
                    Divider()
                }
                .padding(.bottom, 8)
                .modifier(EventsPanelCollapse(isCollapsed: !showEventsPanel))
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

            // Today's date / Go to Today
            if store.selectedWeek.map(store.isCurrentWeek) == true {
                todayText
            } else {
                Button {
                    changeWeek(to: today)
                } label: {
                    VStack(spacing: 1) {
                        todayText
                        Text(Theme.isRetro(theme) ? "> GO_TO_TODAY" : "Go to Today")
                            .font(Theme.isRetro(theme) ? .system(.caption2, design: .monospaced) : .caption2)
                            .foregroundStyle(Theme.accent(theme, rc: rc))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
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
                    // Words, not an icon: "Edit" says what it does, and a pencil is each
                    // card's own edit button.
                    let color: Color = isEditing
                        ? (Theme.isRetro(theme) ? Theme.dotComplete(theme, rc: rc) : .green)
                        : Theme.textSecondary(theme, rc: rc)
                    Text(Theme.isRetro(theme) ? (isEditing ? "[DONE]" : "[EDIT]") : (isEditing ? "Done" : "Edit"))
                        .font(Theme.isRetro(theme) ? .system(.subheadline, design: .monospaced).bold() : .headline)
                        .foregroundStyle(color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 12)
                        .frame(minWidth: Self.barButtonSize, minHeight: Self.barButtonSize * 0.75)
                        .background {
                            if Theme.isRetro(theme) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Theme.cardFill(theme))
                                    .overlay(RoundedRectangle(cornerRadius: 2).stroke(color, lineWidth: isEditing ? 1.5 : 1))
                            } else if isEditing {
                                Capsule().fill(.green.opacity(0.15))
                                    .overlay(Capsule().stroke(.green, lineWidth: 1.5))
                            }
                        }
                        .frame(height: Self.barButtonSize)
                        .contentShape(Rectangle())
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
        return Text(Theme.isRetro(theme) ? "> \(title)_" : title)
    }

    /// Today's date, in the bottom bar: shorter forms on narrow screens or at large text
    /// sizes instead of cutting it off ("Wednesday, Oct 21st", "Wed, Oct 21st", "Oct 21st",
    /// then the numeric "10/21"). VoiceOver always hears the full date.
    private var todayText: some View {
        ViewThatFits(in: .horizontal) {
            todayLabel(weekday: .wide)
            todayLabel(weekday: .abbreviated)
            todayLabel(weekday: nil)
            todayLabel(Self.numericDateString(today))
                .minimumScaleFactor(0.6)
        }
        .font(Theme.isRetro(theme) ? .system(.subheadline, design: .monospaced).bold() : .subheadline.bold())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(today.formatted(date: .complete, time: .omitted))
    }

    private func todayLabel(weekday: Date.FormatStyle.Symbol.Weekday?) -> some View {
        todayLabel(Self.dateString(today, weekday: weekday))
    }

    private func todayLabel(_ date: String) -> some View {
        Text(Theme.isRetro(theme) ? "[\(date)]" : date)
            .lineLimit(1)
    }

    /// The shortest form, month and day in digits in the user's order ("10/21", "21.10.").
    static func numericDateString(_ date: Date, locale: Locale = .current) -> String {
        date.formatted(Date.FormatStyle(locale: locale).month(.defaultDigits).day())
    }

    /// The date in the user's language and region. English adds the day's ordinal
    /// suffix where the day comes last ("Oct 21st"); other languages use their own form.
    static func dateString(_ date: Date, weekday: Date.FormatStyle.Symbol.Weekday?, locale: Locale = .current) -> String {
        var style = Date.FormatStyle(locale: locale).month(.abbreviated).day()
        if let weekday { style = style.weekday(weekday) }
        let text = date.formatted(style)
        let day = Calendar(identifier: .gregorian).component(.day, from: date)
        guard locale.language.languageCode == .english, text.hasSuffix(" \(day)") else { return text }
        let suffix = switch day {
        case 1, 21, 31: "st"
        case 2, 22: "nd"
        case 3, 23: "rd"
        default: "th"
        }
        return text + suffix
    }

    // MARK: - Week Content

    /// Bottom bar icons: 20% larger than the original .title3 (20pt), with matching tap areas.
    private static let barIconSize: CGFloat = 24
    private static let barButtonSize: CGFloat = 52
    /// Room below the grid for the Undo message while it shows.
    private static let undoMessageClearance: CGFloat = 64
    /// Room above the keyboard taken by the Done button.
    private static let keyboardDoneClearance: CGFloat = 56

    /// One spring for expand, collapse, and the reflow of neighboring cards.
    private static let cardSpring = Animation.spring(duration: 0.45, bounce: 0.12)

    /// With Reduce Motion on, cards open and close without sliding or resizing.
    private var cardAnimation: Animation? { reduceMotion ? nil : Self.cardSpring }

    /// At accessibility text sizes every card takes a full row, so names and tasks fit.
    private var usesSingleColumn: Bool { dynamicTypeSize.isAccessibilitySize }

    /// Three columns of closed cards on iPad (a full-width window), two on iPhone.
    /// Columns of closed cards: 2 on iPhone (portrait only), 3 on iPad in portrait and 4 in
    /// landscape. A narrow iPad window (compact width) gets 2 like an iPhone.
    private var gridColumns: Int {
        guard horizontalSizeClass == .regular else { return 2 }
        return isLandscape ? 4 : 3
    }

    @ViewBuilder
    private func weekContent(_ week: Week) -> some View {
        let categories = week.categories
        let showAdd = isEditing && !store.isPastWeek(week)

        ScrollView {
            VStack(spacing: 8) {
                // Expanded cards take a full row; other open cards remain open.
                CategoryGridLayout(spacing: 8, columns: gridColumns) {
                    ForEach(gridEntries(for: week)) { entry in
                        let isExpanded = expandedCategoryKeys.contains(entry.id)
                        CategoryGridCard(
                            category: entry.category,
                            store: store,
                            isExpanded: isExpanded,
                            isEditing: isEditing,
                            isEditingTasks: isEditing || editingCategoryKeys.contains(entry.id),
                            isPastWeek: store.isPastWeek(week),
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
                                withAnimation(cardAnimation) { collapseCategory(entry.id) }
                            },
                            onRenamed: { renameCardKey(entry.id, to: $0) }
                        )
                        // Deleting a card's last task while editing it ends its edit mode, so
                        // the Add task row is back (empty, as a checkbox and one-time) without
                        // tapping the checkmark first.
                        .onChange(of: entry.category.tasks.isEmpty) { _, isEmpty in
                            guard isEmpty, editingCategoryKeys.contains(entry.id) else { return }
                            withAnimation(.snappy(duration: 0.25)) { _ = editingCategoryKeys.remove(entry.id) }
                        }
                        // The dragged card leaves a gap where it will land; a lifted copy
                        // follows the finger (see the overlay below).
                        .opacity(cardDrag?.key == entry.id ? 0 : 1)
                        .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.cardGridSpace)) } action: { frame in
                            cardFrameStore.frames[week.startDay, default: [:]][entry.id] = frame
                        }
                        // Closed cards can be held and dragged to a new place. (Holding inside an
                        // open card is for its tasks.)
                        .modifier(CardDragGesture(
                            isCollapsed: !isExpanded,
                            // Sorted by last edit, cards stay where the sort puts them.
                            canDrag: !store.isPastWeek(week) && store.categorySort == .manual,
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
                            if !store.isPastWeek(week) && !isExpanded && store.categorySort == .manual { cardMoveActions(entry.id, in: week) }
                        }
                        // Outside the modifiers above, where the grid layout can read it.
                        .categoryGridFullWidth(isExpanded || usesSingleColumn)
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
                        systemImage: store.isPastWeek(week) ? "folder" : "folder.badge.plus",
                        description: Text(store.isPastWeek(week) ? "Nothing was planned this week." : "Tap Edit below to add categories.")
                    )
                    .padding(.top, 40)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            // Clear of the bottom bar, which grows when the events panel is open.
            // (The bar is hidden while the keyboard is up; the Done button is covered by
            // keyboardDoneClearance below.)
            .padding(.bottom, (isKeyboardVisible ? 80 : max(80, bottomBarHeight - homeIndicatorInset + 16))
                     // Room for the Undo message, so it never sits over the last row.
                     + (store.lastDelete != nil ? Self.undoMessageClearance : 0))
        }
        // Dragging down into the keyboard closes it; scrolling up keeps it open.
        .scrollDismissesKeyboard(.interactively)
        // Pull down past the top and let go to close every card (like pull to refresh).
        // Off while typing: dragging down to put the keyboard away mustn't also close cards.
        .modifier(PullToCloseAll(isEnabled: !expandedCategoryKeys.isEmpty && !isEditing && !isKeyboardVisible,
                                 theme: theme, rc: rc, onClose: collapseAllCards))
        .scrollDisabled(cardDrag != nil)
        .accessibilityActions {
            if store.lastDelete != nil {
                Button("Undo delete") { withAnimation(cardAnimation) { store.undoLastDelete() } }
            }
        }
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
        var entries = week.categories.compactMap { category in
            keysByID[category.id].map { CategoryGridEntry(id: $0, category: category) }
        }
        if !sortedNames.isEmpty {
            // Names not in the snapshot (added since) go last, in their arranged order.
            let rank = Dictionary(sortedNames.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
            entries = entries.enumerated()
                .sorted { (rank[$0.element.id.name] ?? Int.max, $0.offset) < (rank[$1.element.id.name] ?? Int.max, $1.offset) }
                .map(\.element)
        }
        let entriesByKey = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
        let order = week.id == store.selectedWeek?.id ? (liveCardOrder ?? categoryDisplayOrder) : categoryDisplayOrder
        let ordered = order.compactMap { entriesByKey[$0] }
        let orderedKeys = Set(ordered.map(\.id))
        return ordered + entries.filter { !orderedKeys.contains($0.id) }
    }

    /// Re-sorts at the calm moments `sortedNames` describes.
    private var sortOrderWatcher: some View {
        Color.clear
            // Categories added or deleted while editing take their sorted places.
            .onChange(of: isEditing) { _, editing in
                if !editing { refreshSortOrder() }
            }
            .onChange(of: store.lastDelete) { _, deletion in
                if let deletion {
                    AccessibilityNotification.Announcement("Deleted \(deletion.description). Undo is available.").post()
                }
            }
            .onChange(of: store.selectedWeek?.startDay, initial: true) { refreshSortOrder() }
            .onChange(of: store.categorySort) { withAnimation(cardAnimation) { refreshSortOrder() } }
            .onChange(of: expandedCategoryKeys.isEmpty) { _, allClosed in
                if allClosed { withAnimation(cardAnimation) { refreshSortOrder() } }
            }
    }

    private var editModeHint: String {
        switch (store.categorySort == .manual, Theme.isRetro(theme)) {
        case (true, true): "> hold + drag a card to move it"
        case (true, false): "Hold and drag a card to move it"
        case (false, true): "> sorted by last edit // manual in settings to move"
        case (false, false): "Sorted by last edit · Choose Manual in Settings to move cards"
        }
    }

    /// Takes the current sort order (see `sortedNames`).
    private func refreshSortOrder() {
        guard store.categorySort != .manual, let week = store.selectedWeek else {
            sortedNames = []
            return
        }
        sortedNames = store.sortedCategories(week.categories).map(\.name)
    }

    /// Expanding a card that isn't first in its row moves it into the row's first
    /// slot, so it opens in place instead of dropping below an already-open card.
    private func expandCard(_ key: CategoryLayoutKey, in week: Week) {
        guard !isEditing else { return }  // edit mode keeps cards collapsed
        withAnimation(cardAnimation) { expandCategory(key, in: week) }
    }

    private func expandCategory(_ key: CategoryLayoutKey, in week: Week) {
        var order = gridEntries(for: week).map(\.id)
        let rows = CategoryGridLayout.rows(fullWidth: order.map { usesSingleColumn || expandedCategoryKeys.contains($0) },
                                           columns: gridColumns)
        if let row = rows.first(where: { $0.dropFirst().contains { order[$0] == key } }),
           let index = row.first(where: { order[$0] == key }) {
            order.remove(at: index)
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

    /// Card places in the week being viewed.
    private var cardFrames: [CategoryLayoutKey: CGRect] {
        store.selectedWeek.flatMap { cardFrameStore.frames[$0.startDay] } ?? [:]
    }

    private func liftCard(_ key: CategoryLayoutKey, in week: Week) {
        guard cardDrag == nil, let frame = cardFrames[key] else { return }
        liveCardOrder = gridEntries(for: week).map(\.id)
        liftedCardOrder = liveCardOrder
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
        // Only cards in this week's order: places of deleted or renamed cards may linger.
        let target = liveCardOrder?.first { $0 != drag.key && cardFrames[$0]?.contains(location) == true }
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
        // A card held and let go where it was changes nothing (and saves nothing).
        if let order = liveCardOrder, order != liftedCardOrder {
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
            liftedCardOrder = nil
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
                onToggleEdit: {}, onExpand: {}, onCollapse: {}, onRenamed: { _ in }
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

    /// A renamed category gets a new layout key (keys follow names), so its open, editing
    /// and order state moves to the new key; otherwise the card would close.
    private func renameCardKey(_ old: CategoryLayoutKey, to name: String) {
        let new = CategoryLayoutKey(name: name, occurrence: old.occurrence)
        let move = { (key: CategoryLayoutKey) in key == old ? new : key }
        if expandedCategoryKeys.remove(old) != nil { expandedCategoryKeys.insert(new) }
        if editingCategoryKeys.remove(old) != nil { editingCategoryKeys.insert(new) }
        categoryDisplayOrder = categoryDisplayOrder.map(move)
        lastToggledCategory = lastToggledCategory.map(move)
        // A renamed card keeps its place in a sorted order.
        sortedNames = sortedNames.map { $0 == old.name ? name : $0 }
    }

    private func collapseCategory(_ key: CategoryLayoutKey) {
        // A field in the closing card would otherwise keep the keyboard, typing into a
        // card that's no longer shown. (What was typed is saved as the field closes.)
        dismissKeyboard()
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
            setEventsPanel(open: !showEventsPanel)
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

    /// Opens or closes the events panel. It's added to the bar collapsed and then opened,
    /// and closed before it's taken out, so the bar and the panel shrink together.
    /// `velocity` (panel heights per second) continues a swipe down at the finger's speed.
    private func setEventsPanel(open: Bool, velocity: Double = 0) {
        if open {
            isEventsPanelMounted = true
            DispatchQueue.main.async {
                withAnimation(.spring(duration: 0.4, bounce: 0.12)) { showEventsPanel = true }
            }
        } else {
            // No bounce: overshooting a height of zero makes the bar dip and spring back.
            let animation = Animation.interpolatingSpring(duration: 0.35, bounce: 0, initialVelocity: velocity)
            withAnimation(animation, completionCriteria: .removed) {
                showEventsPanel = false
            } completion: {
                if !showEventsPanel { isEventsPanelMounted = false }
            }
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
                onDismiss: { velocity in
                    isEventsPanelDragged = false
                    setEventsPanel(open: false, velocity: velocity)
                },
                onDragChanged: { isEventsPanelDragged = $0 }
            )
            .task(id: EventsLoadKey(weekStart: week.startDate, calendarIDs: calendarIDs, generation: calendarService.generation)) {
                await calendarService.load(weekStarting: week.startDate, calendarIDs: calendarIDs)
            }
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
    ContentView(store: .makeDefault(), calendarService: .makeDefault())
}

// MARK: - Events Panel Collapse

/// The events panel opening and closing in the bottom bar: it fades while its height
/// grows from, or shrinks to, nothing, clipped so it never covers the bar's buttons.
private struct EventsPanelCollapse: ViewModifier {
    let isCollapsed: Bool

    func body(content: Content) -> some View {
        content
            .modifier(CardContentCrossFade(isHidden: isCollapsed))
            .clipped()
    }
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

    // The gestures are always attached and switched on or off (mask, isEnabled):
    // different view branches for open and closed cards would rebuild the card (losing
    // its state and its resize animation) every time it opened or closed.
    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .gesture(TapGesture().onEnded(onTap), including: isCollapsed ? .all : .subviews)
            // UIKit's long press, not a SwiftUI LongPress-then-Drag: that drag claimed every
            // touch on a card, so a screen full of cards couldn't be scrolled. This one gives
            // up when the finger moves before the hold, leaving the touch to the scroll view.
            .gesture(CardHoldRecognizer(isEnabled: isCollapsed && canDrag,
                                        onLift: onLift, onMove: onMove, onDrop: onDrop))
            // A card that goes away mid-drag must not leave the grid locked.
            .onDisappear(perform: onDrop)
    }
}

/// Hold a closed card half a second (like iOS's own hold-to-move), then drag it.
private struct CardHoldRecognizer: UIGestureRecognizerRepresentable {
    let isEnabled: Bool
    let onLift: () -> Void
    let onMove: (_ start: CGPoint, _ location: CGPoint) -> Void
    let onDrop: () -> Void

    final class Coordinator {
        /// Where the finger was when the hold began, in the grid's coordinates.
        var start: CGPoint?
    }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

    func makeUIGestureRecognizer(context: Context) -> UILongPressGestureRecognizer {
        let recognizer = UILongPressGestureRecognizer()
        recognizer.minimumPressDuration = 0.5
        recognizer.isEnabled = isEnabled
        return recognizer
    }

    func updateUIGestureRecognizer(_ recognizer: UILongPressGestureRecognizer, context: Context) {
        recognizer.isEnabled = isEnabled
    }

    func handleUIGestureRecognizerAction(_ recognizer: UILongPressGestureRecognizer, context: Context) {
        let location = context.converter.location(in: .named(ContentView.cardGridSpace))
        switch recognizer.state {
        case .began:
            context.coordinator.start = location
            onLift()
            onMove(location, location)
        case .changed:
            onMove(context.coordinator.start ?? location, location)
        case .ended, .cancelled, .failed:
            guard context.coordinator.start != nil else { return }
            context.coordinator.start = nil
            onDrop()
        default:
            break
        }
    }
}

// MARK: - Pull to Close All

/// Pulling the grid down past its top and letting go closes every open card. Only a pull
/// the finger is holding counts, never the bounce of a fast scroll to the top, and it acts
/// on release. Its state lives here, not in ContentView: scrolling then redraws only this
/// (and only while pulled past the top), not the whole screen on every frame.
private struct PullToCloseAll: ViewModifier {
    let isEnabled: Bool
    let theme: AppearanceMode
    let rc: RetroColor
    let onClose: () -> Void

    static let distance: CGFloat = 90
    @State private var pull: CGFloat = 0
    @State private var isTouching = false

    private var isArmed: Bool { isEnabled && isTouching && pull >= Self.distance }

    func body(content: Content) -> some View {
        content
            // Zero whenever the grid isn't pulled past its top, so ordinary scrolling
            // changes nothing here; whole points, capped, while it is.
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                min(max(0, -(geometry.contentOffset.y + geometry.contentInsets.top)), Self.distance * 1.5).rounded()
            } action: { _, overscroll in
                pull = overscroll
            }
            .onScrollPhaseChange { _, phase in
                let wasArmed = isArmed
                isTouching = phase == .interacting
                if wasArmed && phase != .interacting { onClose() }
            }
            .overlay(alignment: .top) { hint }
            .sensoryFeedback(.impact(weight: .light), trigger: isArmed) { _, armed in armed }
    }

    /// In the gap a pull opens above the cards: what letting go will do.
    @ViewBuilder
    private var hint: some View {
        if isEnabled && isTouching && pull > 12 {
            Label(isArmed ? "Release to close all" : "Pull to close all",
                  systemImage: "arrow.down.right.and.arrow.up.left")
                .font(Theme.isRetro(theme) ? .system(.caption, design: .monospaced) : .caption.weight(.medium))
                .foregroundStyle(isArmed ? Theme.accent(theme, rc: rc) : Theme.textSecondary(theme, rc: rc))
                .opacity(min(1, pull / Self.distance))
                .padding(.top, 6)
                .allowsHitTesting(false)
                .accessibilityHidden(true)  // VoiceOver uses the Collapse All button
        }
    }
}
