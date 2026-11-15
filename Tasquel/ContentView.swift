import SwiftUI
import UniformTypeIdentifiers
// MARK: - Root View

struct ContentView: View {
    let store: ChecklistStore
    let calendarService: CalendarService
    @State private var showDatePicker = false
    @State private var showSettings = false
    @State private var showAddCategory = false
    /// A category was added in the open Add Category sheet (Edit ends when it closes).
    @State private var addedCategoryInSheet = false
    @State private var expandedCategoryKeys: Set<CategoryLayoutKey> = []
    @State private var categoryDisplayOrder: [CategoryLayoutKey] = []
    @State private var lastToggledCategory: CategoryLayoutKey?
    @State private var isEditing = false
    /// The day picked in the day strip (1 Sunday … 7 Saturday): cards show that day's tasks
    /// and the ones without a day. Tapped again, every task shows. Kept across weeks.
    @State private var dayFilter: Int?
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
    /// While the keyboard is up, the bottom bar turns into a Done button.
    @State private var isKeyboardVisible = false
    private var isSheetPresented: Bool {
        showSettings || showAddCategory || showDatePicker || showOnboarding || whatsNewFromButton != nil
    }
    /// What's New, opened from the header's button (`whatsNewButton`), and whether that was
    /// the button's last time.
    @State private var whatsNewFromButton: WhatsNewSheet.FromButton?
    /// The header's What's New pill's width, for the room the title gives it, and where it is.
    @State private var whatsNewButtonWidth: CGFloat = 0
    @State private var isWhatsNewOut = false
    /// The week title's width at full size and the header row's, so the title moves over for
    /// What's New only if the pill wouldn't fit beside it (`weekTitleLeadingInset`).
    @State private var weekTitleNaturalWidth: CGFloat = 0
    @State private var weekTitleRowWidth: CGFloat = 0
    /// The bottom bar's height above the home indicator; the grid scrolls clear of it.
    @State private var bottomBarHeight: CGFloat = 68
    /// The screen's bottom safe area (home indicator), which the flush bar covers.
    @State private var homeIndicatorInset: CGFloat = 34
    /// How far in from the leading edge the header's Tasquel mark has to sit to clear an
    /// iPadOS window's controls (close, minimize, full screen) in the top-leading corner;
    /// 0 without them (iPhone, or an iPad app in full screen). See `WindowControlsInsetReader`.
    @State private var windowControlsInset: CGFloat = 0
    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    /// When the app last went to the background, to decide whether reopening it
    /// should jump back to the current week.
    @State private var backgroundedAt: Date?
    /// Bumped to wiggle a card (by category ID): a card with a task for today, as the app opens.
    @State private var wiggleTicks: [UUID: Int] = [:]
    @State private var wiggleSequence: Task<Void, Never>?
    /// Today (the store's clock), for the day strip and the calendar. Updated when the day
    /// changes while the app is open.
    @State private var today = Date()
    /// The week today was in at the last check, kept as a day (not a moment, which reads
    /// differently once the time zone changes), to tell whether the viewed week was the
    /// current one when the day or time zone changes.
    @State private var currentWeekStart: DayKey?
    /// "Moved to the week of Dec 14": the screen just went to another week with a task.
    @State private var movedNotice: MovedNotice?
    /// A week to go to without animation (Reduce Motion), set from a dispatched block and
    /// gone to in `onChange`: store changes from async code inside an animation could be
    /// drawn from the week as it was (see CLAUDE.md, "Store changes from async code").
    @State private var pendingWeekDate: Date?
    /// The bottom bar's Edit side (the wider of Edit and Done), which the Settings side
    /// matches so the week selector stays centered.
    @State private var editSideWidth: CGFloat = 80
    /// The bottom row's width and the week selector's, for the bar's house (`barHouse`).
    @State private var barContentWidth: CGFloat = 0
    /// The selector's three buttons, without the capsule's padding.
    @State private var weekButtonsWidth: CGFloat = 0
    /// The selector's and the house's glass, so the house can grow out of the selector.
    @Namespace private var barGlass
    /// The house's glass still blends with the selector's: while it comes out, until it
    /// lets go (`houseBlend`), and while it goes back in.
    @State private var houseAttached = true
    /// Where the bar's house is in its moves (`moveBarHouse`), and on which side.
    @State private var houseStage: BarHouseStage = .inside
    @State private var houseStageSide: BarHouseSide = .left
    /// Counts moves, so the steps of one left over aren't played after the next.
    @State private var houseMoveGeneration = 0
    /// The week's title: 5% under .title2's 22pt, and growing with Dynamic Type like it.
    @ScaledMetric(relativeTo: .title2) private var weekTitleSize: CGFloat = 20.9

    // Week paging (swipe or arrows): last/this/next week sit side by side.
    // Read only by PagerTrack, so dragging moves the pages without rebuilding them.
    @State private var pager = WeekPagerState()
    @State private var pagerTarget: PagerTarget?
    @State private var arrivingWeek: Week?  // its title and days show from release until it takes over
    /// Which way the drag on the grid is going, decided once per drag. Not watched by the
    /// screen: every drag (an ordinary scroll too) set it and cleared it, and as state each
    /// change redrew the whole screen, every card and task row on all three pages, twice a
    /// scroll (2026-11-12). The pages only need to know about a sideways one (`isSwipingWeeks`).
    @State private var weekSwipe = WeekSwipeTracker()
    /// A sideways drag is moving the weeks: the pages are disabled until it ends.
    @State private var isSwipingWeeks = false
    /// The grid of cards' width (the same on every page), for open cards' contents.
    @State private var cardGridWidth: CGFloat?
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
            if Theme.isSeasonal(theme) {
                SeasonalBackdrop(season: Season.current)
            } else {
                Theme.background(theme).ignoresSafeArea()
            }

            VStack(spacing: 12) {
                if let error = store.persistenceError {
                    weekTitleRow
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
                            // Settings set aside start over on System: the icon follows,
                            // or the Retro icon would stay on the home screen.
                            AppIconSwitcher.update(for: store.appearanceMode,
                                                   matchingTheme: UserDefaults.standard.object(forKey: AppIconSwitcher.matchesThemeKey) as? Bool ?? true)
                            if store.persistenceError == nil && store.shouldShowWelcome {
                                showOnboarding = true
                            }
                        }
                    } message: {
                        Text(startFreshMessage)
                    }
                    Spacer()
                } else if let week = store.selectedWeek {
                    PagerTrack(pager: pager) {
                        // Keyed by week, so the page that slides in keeps its identity when
                        // it becomes current; only the new off-screen neighbor is built.
                        ForEach(pagerPages(current: week)) { page in
                            weekContent(page.week)
                                .environment(\.cardWeekStart, page.week.startDay)
                                .environment(\.taskDayFilter, dayFilter)
                                .offset(x: CGFloat(page.slot) * weekPageWidth)
                                // Neighbor pages are only for show while paging.
                                .allowsHitTesting(page.slot == 0)
                                .accessibilityHidden(page.slot != 0)
                                // A swipe that starts on a card or checkbox must not tap it: the
                                // content moves with the finger, so the touch never leaves the button.
                                // (allowsHitTesting doesn't cancel a touch already in progress.)
                                .disabled(page.slot != 0 || isSwipingWeeks || isChangingWeek)
                        }
                    }
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { weekPageWidth = $0 }
                    .modifier(WeekSwipeGesture(onChanged: weekSwipeChanged, onEnded: weekSwipeEnded) {
                        // Cancelled rather than ended: put the page back.
                        guard weekSwipe.axis != nil else { return }
                        endWeekSwipe()
                        if !isChangingWeek { withAnimation(.snappy(duration: 0.25)) { pager.offset = 0 } }
                    })
                    // The cards scroll up under the header's frosted glass.
                    .safeAreaInset(edge: .top, spacing: 0) { weekHeader(week) }
                } else {
                    weekTitleRow
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
                            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                                bottomBarHeight = height
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

            // "Deleted … · Undo", just above the bottom bar. Hidden while the keyboard is up:
            // above it, it sat over the field being typed in. (Not ended: a keyboard notice
            // as a goal editor's Delete Task took its field away ended it at once.)
            if store.persistenceError == nil, let deletion = store.lastDelete, !isKeyboardVisible {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    undoDeleteMessage(deletion)
                        .frame(maxWidth: 560)  // not the width of an iPad
                        .padding(.horizontal, 16)
                        .padding(.bottom, max(8, bottomBarHeight - homeIndicatorInset + 8))
                }
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom)))
            }

            movedNoticeLayer

            // Retro scanline overlay
            if Theme.isRetro(theme) {
                ScanlineOverlay()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .background { windowMeasurements }
        .foregroundStyle(Theme.textPrimary(theme, rc: rc))
        .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: store.lastDelete)
        .preferredColorScheme(store.colorScheme)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { keyboardWillShow($0) }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.snappy(duration: 0.3)) { isKeyboardVisible = false }
        }
        .sheet(isPresented: $showDatePicker) {
            CalendarSheet(selectedDate: store.selectedDate, firstWeekday: store.firstWeekday, today: today,
                          theme: theme, rc: rc, showsEvents: showsEventsToggle,
                          eventsWeek: (arrivingWeek ?? store.selectedWeek)?.startDay,
                          onSelectWeek: { changeWeek(to: $0) },
                          onSwipeWeek: { changeWeek(by: $0, velocity: $1) },
                          marks: { store.calendarMarks(weekStartingOn: $0) }) { week in
                eventsList(for: week)
            }
            // Full height on iPad, where half a form sheet cut the content off.
            .presentationDetents(horizontalSizeClass == .regular ? [.large] : [.medium, .large])
            .preferredColorScheme(store.colorScheme)
        }
        .sheet(isPresented: $showSettings) {
            // The phone's own light or dark, for a look that follows it (System, Seasonal). Not
            // the main screen's: just after leaving Light it was still light, and Settings
            // kept light sections under Seasonal's night text (2026-11-14).
            SettingsSheet(store: store, calendar: calendarService, systemColorScheme: deviceColorScheme)
        }
        // The sheet stays open to add several; once it closes after an add, Edit ends, as it
        // did after each add before.
        .sheet(isPresented: $showAddCategory, onDismiss: {
            if addedCategoryInSheet { isEditing = false }
            addedCategoryInSheet = false
        }) {
            AddCategorySheet(store: store) { name, symbol, thisWeekOnly in
                store.addCategory(name: name, symbol: symbol, thisWeekOnly: thisWeekOnly)
                addedCategoryInSheet = true
            }
            // Full height on iPad, where half a form sheet cut the content off.
            .presentationDetents(horizontalSizeClass == .regular ? [.large] : [.medium, .large])
            .preferredColorScheme(store.colorScheme)
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingSheet(store: store, calendar: calendarService)
                .interactiveDismissDisabled()
        }
        .sheet(item: $whatsNewFromButton, onDismiss: {
            withAnimation(whatsNewAnimation) { store.finishWhatsNewFromButton() }
        }) { fromButton in
            WhatsNewSheet(store: store, fromButton: fromButton)
        }
        .onAppear {
            today = store.currentDate
            currentWeekStart = store.weekStartDay(containing: today)
            if store.persistenceError == nil && store.shouldShowWelcome {
                showOnboarding = true
            } else {
                wiggleCardsWithTodaysTasks()
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
                backgroundedAt = store.currentDate
                // Saves a title being typed: iOS may end the app while it's away.
                dismissKeyboard()
            }
            guard scenePhase == .active else { return }
            // Only after a real trip away: Notification Center or Control Center (inactive)
            // mustn't re-sort cards that are in use.
            let wasAway = backgroundedAt != nil
            if wasAway { refreshSortOrder() }
            today = store.currentDate
            returnToCurrentWeekIfAway()
            currentWeekStart = store.weekStartDay(containing: today)
            if wasAway { wiggleCardsWithTodaysTasks() }
            // Calendars may have changed (or access revoked) while away. Not after Control
            // Center or the icon-change alert: reloading made an open events panel flash.
            // (Changes while the app is open arrive through EventKit's notification.)
            calendarService.refreshAuthorization()
            if wasAway {
                calendarService.invalidate()
                Task { await calendarService.loadCalendars() }
            }
        }
        .onChange(of: isEditing) {
            // Closing cards lets go of the keyboard first, saving what's typed (with a
            // hardware keyboard the bar, and Edit, stay up while typing).
            if isEditing && isKeyboardVisible {
                store.keyboardDoneRequests += 1
                dismissKeyboard()
            }
            // Edit mode is for managing categories: collapse everything, and reopen the
            // same cards afterwards, each where it was (at the start of its row).
            withAnimation(cardAnimation) {
                categoryDisplayOrder.removeAll()
                if isEditing {
                    expandedBeforeEditing = expandedCategoryKeys
                    expandedCategoryKeys.removeAll()
                    editingCategoryKeys.removeAll()
                } else {
                    reopenCards(expandedBeforeEditing)
                    expandedBeforeEditing.removeAll()
                }
                lastToggledCategory = nil
            }
        }
        .onChange(of: store.selectedDate) {
            if isPastWeek { isEditing = false }
        }
        .onChange(of: pendingWeekDate) { _, date in
            guard let date else { return }
            pendingWeekDate = nil
            withAnimation(.easeInOut(duration: 0.2)) {
                store.navigateToDate(date)
                refreshSortOrder()  // in its own order at once (see `changeWeek`)
            }
            isChangingWeek = false
        }
        .background {
            sortOrderWatcher
            addedElsewhereFollower
        }
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
        let previousWeek = currentWeekStart ?? store.weekStartDay(containing: today)
        today = store.currentDate
        currentWeekStart = store.weekStartDay(containing: today)
        guard store.persistenceError == nil, let week = store.selectedWeek else { return }
        let wasCurrentWeek = week.startDay == previousWeek
        if wasCurrentWeek && store.isPastWeek(week) {
            dismissKeyboard()
            isEditing = false
            store.navigateToDate(today)
        } else if !store.isPastWeek(week) {
            store.navigateToDate(store.selectedDate)
        }
    }

    /// Opening the app (at launch, or back from a real trip away) on a day some tasks are
    /// for: each card in this week holding one that isn't done wiggles once, 0.5s, one after
    /// another in the grid's order, top to bottom (the user asked, 2026-11-12). Not in Edit,
    /// with Reduce Motion, or with throwaway data (UI tests, demo).
    private func wiggleCardsWithTodaysTasks() {
        wiggleSequence?.cancel()
        guard !reduceMotion, !isEditing, !ChecklistStore.launchesWithThrowawayData,
              let week = store.selectedWeek, store.isCurrentWeek(week) else { return }
        let day = store.currentDay
        let ids = gridEntries(for: week).map(\.category).filter { category in
            category.tasks.contains { !$0.isCompleted && $0.day(inWeekStarting: week.startDay, firstWeekday: store.firstWeekday) == day }
        }.map(\.id)
        guard !ids.isEmpty else { return }
        wiggleSequence = Task {
            try? await Task.sleep(for: .seconds(0.6))  // once the screen has settled
            for id in ids {
                guard !Task.isCancelled else { return }
                wiggleTicks[id, default: 0] += 1
                try? await Task.sleep(for: .seconds(0.55))  // its 0.5s wiggle, then the next
            }
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
        let now = store.currentDate
        let newWeekStarted = store.startOfWeek(containing: backgroundedAt) != store.startOfWeek(containing: now)
        guard newWeekStarted || now.timeIntervalSince(backgroundedAt) > 15 * 60 else { return }
        isEditing = false
        store.navigateToDate(today)
    }

    // MARK: - Week Paging

    /// Horizontal drags move the week grid with the finger; releasing past a
    /// quarter of the width (or flicking) pages to the adjacent week. Vertical
    /// drags are left to the scroll view (`WeekSwipeGesture`).
    private func weekSwipeChanged(_ value: DragGesture.Value) {
        if weekSwipe.axis == nil {
            // A lifted card owns the touch: treating it as a week swipe would disable
            // the page (below), cancelling the card's drag. So does a task moved by
            // its handle, which a sideways wobble turned into a week swipe.
            let axis: Axis = cardDrag == nil && !store.isReorderingTask
                && abs(value.translation.width) > abs(value.translation.height) ? .horizontal : .vertical
            weekSwipe.axis = axis
            // Track from here so the grid doesn't jump by the recognition distance.
            weekSwipe.origin = value.translation.width
            if axis == .horizontal {
                isSwipingWeeks = true
                // The page is disabled for the swipe from now on, which took its field's
                // focus but left the keyboard up. What's typed is saved to this week.
                if isKeyboardVisible {
                    store.keyboardDoneRequests += 1
                    dismissKeyboard()
                }
            }
        }
        guard weekSwipe.axis == .horizontal, !isChangingWeek, cardDrag == nil else { return }
        pager.offset = value.translation.width - weekSwipe.origin
    }

    private func weekSwipeEnded(_ value: DragGesture.Value) {
        defer { endWeekSwipe() }
        guard weekSwipe.axis == .horizontal, !isChangingWeek, cardDrag == nil else {
            // (Not while a page slides in: that would pull it back.)
            if cardDrag == nil && !isChangingWeek { withAnimation(.snappy(duration: 0.25)) { pager.offset = 0 } }
            return
        }
        let distance = value.translation.width - weekSwipe.origin
        let predicted = value.predictedEndTranslation.width - weekSwipe.origin
        let velocity = value.velocity.width
        if abs(distance) > weekPageWidth * 0.25 || abs(predicted) > weekPageWidth * 0.5 {
            let weeks = (abs(distance) > weekPageWidth * 0.25 ? distance : predicted) < 0 ? 1 : -1
            changeWeek(by: weeks, velocity: velocity)
        } else {
            withAnimation(pagingSpring(to: 0, velocity: velocity)) { pager.offset = 0 }
        }
    }

    /// The drag is over (ended or cancelled): the next one decides its direction afresh.
    private func endWeekSwipe() {
        weekSwipe.axis = nil
        if isSwipingWeeks { isSwipingWeeks = false }
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

    /// Returns whether the week is changing (not while the last change still slides).
    @discardableResult
    private func changeWeek(by weeks: Int, velocity: CGFloat = 0) -> Bool {
        guard let date = store.calendar.date(byAdding: .weekOfYear, value: weeks, to: store.selectedDate) else { return false }
        return changeWeek(to: date, velocity: velocity)
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
    @discardableResult
    private func changeWeek(to date: Date, velocity: CGFloat = 0) -> Bool {
        guard !isChangingWeek, let current = store.selectedWeek else { return false }
        let target = store.startOfWeek(containing: date)
        guard !store.calendar.isDate(target, inSameDayAs: current.startDate) else {
            withAnimation(.snappy(duration: 0.25)) { pager.offset = 0 }
            return false
        }
        // A title being typed is saved to the week it belongs to, before the week changes.
        dismissKeyboard()
        guard !reduceMotion else {
            pager.offset = 0
            isChangingWeek = true
            // Gives the field's commit (on losing focus) a moment to run first; always, as a
            // hardware keyboard isn't counted as `isKeyboardVisible`. See `pendingWeekDate`.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { pendingWeekDate = date }
            return true
        }

        let slot = target > current.startDate ? 1 : -1
        if let adjacent = store.calendar.date(byAdding: .weekOfYear, value: slot, to: current.startDate),
           !store.calendar.isDate(store.startOfWeek(containing: adjacent), inSameDayAs: target) {
            pagerTarget = PagerTarget(slot: slot, date: date)  // off-screen, so no visible swap
        }
        isChangingWeek = true
        // The title switches now; the page hands over only once the slide has fully
        // settled, so the cards never snap the last few points into place.
        arrivingWeek = store.previewWeek(for: date)
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
                // Its order at once, as it slid in (`gridEntries`): left to `onChange`, a
                // frame could show it in the old week's order.
                refreshSortOrder()
                pagerTarget = nil
                arrivingWeek = nil
                pager.offset = 0
            }
            isChangingWeek = false
        }
        return true
    }

    // MARK: - Undo

    /// The window's measurements, behind everything (see the comments for why each is
    /// measured as it is).
    private var windowMeasurements: some View {
        ZStack {
            // Ignoring the keyboard, the bottom inset is the home indicator's alone. Not
            // measured while a sheet covers the screen: a keyboard in a sheet over a sheet
            // (Choose Emoji… in Add Category or Saved Categories) lifts this screen's inset to
            // ~380pt, and the bar, padded by it, then chased it in a layout loop that froze
            // the app. (The home indicator's real inset doesn't change while a sheet is up.)
            Color.clear
                .ignoresSafeArea(.keyboard)
                .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.bottom } action: { inset in
                    if !isSheetPresented { homeIndicatorInset = inset }
                }
            // Landscape from the window itself, which keyboards don't change: measured in
            // SwiftUI, the space above an iPad's keyboard made portrait "landscape" (4 columns).
            WindowSizeReader { size in isLandscape = size.width > size.height }
        }
    }

    /// The bottom bar makes way for this screen's keyboard. A keyboard for a field in a
    /// sheet isn't this screen's (on iPad the bar would change around the form sheet); with
    /// a hardware keyboard, iPadOS shows only a short shortcuts bar, so the bar stays.
    private func keyboardWillShow(_ note: Notification) {
        guard !isSheetPresented else { return }
        let height = (note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)?.height ?? .infinity
        withAnimation(.snappy(duration: 0.3)) { isKeyboardVisible = height > 100 }
    }

    /// Undoes the last delete. From another week, it goes back to the week of the delete
    /// first, so what returns is seen returning.
    private func undoDelete() {
        let week = store.lastDelete?.week
        withAnimation(cardAnimation) { store.undoLastDelete() }
        if let week, week != store.selectedWeek?.startDay {
            changeWeek(to: week.date(in: store.calendar))
        }
    }

    /// Shown for five seconds after a delete; deleting no longer asks first, so this is
    /// how a mistaken delete is taken back. Only as wide as its words (screen-wide, it
    /// covered rows below it), and only Undo takes taps: a tap on the rest reaches what's
    /// under it, like a card's Add Task.
    private func undoDeleteMessage(_ deletion: ChecklistStore.UndoableDelete) -> some View {
        HStack(spacing: 12) {
            Group {
                Image(systemName: "trash")
                    .foregroundStyle(Theme.textSecondary(theme, rc: rc))
                    .hiddenFromVoiceOver()
                Text(Theme.isRetro(theme) ? "deleted \(deletion.description)" : "Deleted \(deletion.description)")
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .allowsHitTesting(false)
            Button(Theme.isRetro(theme) ? "[UNDO]" : "Undo") {
                undoDelete()
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
            Group {
                if Theme.isRetro(theme) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Theme.navCapsule(theme))
                        .overlay(RoundedRectangle(cornerRadius: 2).stroke(Theme.cardBorder(theme, rc: rc), lineWidth: 1))
                } else {
                    Capsule().fill(.clear).glassEffect(.regular, in: Capsule())
                }
            }
            .allowsHitTesting(false)
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
                            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                    } else {
                        Image(systemName: anyExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                            .font(.title3)
                            .contentTransition(.symbolEffect(.replace))
                            // Grows no further at the largest text sizes, so it stays clear of
                            // the week title.
                            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
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

    /// The Tasquel mark (the app icon's ring and t), in one color, at the top left: back to
    /// this week (what Go to Today in the bottom bar used to do). In late December it wears
    /// the holiday's layers (`HolidayMark`).
    @ViewBuilder
    private var homeButton: some View {
        if store.persistenceError == nil {
            let retro = Theme.isRetro(theme)
            // Retro's brackets are wide; the ring is 5% larger.
            let markHeight: CGFloat = retro ? 28.6 : 30
            let layers = HolidayMark.of(DayKey(today, in: store.calendar), firstWeekday: store.firstWeekday,
                                        calendar: store.calendar)?.layers(retro: retro)
            let layerSize = HolidayMark.layerSize(forMarkHeight: markHeight, retro: retro)
            Button { changeWeek(to: today) } label: {
                // Retro's is its icon's: the t in brackets.
                Image(retro ? "TasquelMarkRetro" : "TasquelMark")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(height: markHeight)
                    .foregroundStyle(Theme.textSecondary(theme, rc: rc))
                    .background { holidayMarkLayer(layers?.behind, size: layerSize) }
                    // Retro's are one color: its bright one.
                    .overlay { holidayMarkLayer(layers?.front, size: layerSize).foregroundStyle(Theme.textPrimary(theme, rc: rc)) }
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.leading, markLeadingInset)
            .accessibilityLabel("This Week")
            .accessibilityHint("Goes back to the current week")
        }
    }

    /// Thanksgiving week's turkey (`TurkeyCameo`), in a strip from the screen's edge past the
    /// mark: it hides behind the mark's middle and comes out 36pt right of it. Only in that
    /// week (Debug `-demoTurkey`: any week).
    @ViewBuilder
    private var turkeyCameo: some View {
        #if DEBUG
        let demo = ProcessInfo.processInfo.arguments.contains("-demoTurkey")
        #else
        let demo = false
        #endif
        let isWeek = demo || Thanksgiving.isWeek(of: DayKey(today, in: store.calendar), firstWeekday: store.firstWeekday,
                                                 calendar: store.calendar, region: Locale.current.region?.identifier)
        // Not while What's New is out beside the mark: they'd share the spot.
        if isWeek && !reduceMotion && store.persistenceError == nil && !store.showsWhatsNewButton
            && (demo || !ChecklistStore.launchesWithThrowawayData) {
            let markMiddle = markLeadingInset + 22
            TurkeyCameo(retro: Theme.isRetro(theme), tint: Theme.textPrimary(theme, rc: rc),
                        markEdge: markMiddle + (Theme.isRetro(theme) ? 16.5 : 15.5),
                        // Retro's title starts sooner ("> Week…"): less far out there.
                        hideX: markMiddle, outX: markMiddle + (Theme.isRetro(theme) ? 30 : 36))
                .frame(width: markMiddle + 80, height: 44)
        }
    }

    /// The header's "What's New?" (the user asked, 2026-11-14): after an update with a What's
    /// New, a small pill slides out from behind the mark a moment after the app opens, in one
    /// springy move that grows and fades it in, as the header's house did (`isWhatsNewOut`;
    /// it first peeked out a third and paused, which the user found less smooth). The title
    /// moves over with it only if it must (`weekTitleLeadingInset`). It
    /// opens What's New, and once it's been opened twice (`ChecklistStore.showsWhatsNewButton`)
    /// it slides back behind the mark for good; Settings keeps What's New. Shown only right of
    /// the mark's ring, under the mark, so it comes from behind it. Half the size it was at
    /// first (the user's ask); its tap area is still 44pt tall. The deeper blue of today's date
    /// (white words 5.6:1); Seasonal's accent; Retro's words in brackets.
    @ViewBuilder
    private var whatsNewButton: some View {
        if store.persistenceError == nil && (store.showsWhatsNewButton || isWhatsNewOut) {
            let retro = Theme.isRetro(theme)
            let fill: Color = Theme.isSeasonal(theme) ? Theme.accent(theme, rc: rc) : Color(Theme.pastDayDateLight)
            let markMiddle = markLeadingInset + 22
            let markEdge = markMiddle + (retro ? 16.5 : 15.5)
            let out = markLeadingInset + 44 - 2
            // Well behind until it's been measured, so it never shows at a guess.
            let hidden = markEdge - (whatsNewButtonWidth > 0 ? whatsNewButtonWidth : 200) - 2
            // With Reduce Motion it only fades, in place.
            let x = isWhatsNewOut || reduceMotion ? out : hidden
            Button {
                let last = store.whatsNewOpenedFromButton()
                whatsNewFromButton = last ? .lastTime : .again
            } label: {
                Text(retro ? "[WHAT'S NEW?]" : "What's New?")
                    .font(.system(size: 9, weight: .bold, design: retro ? .monospaced : .default))
                    .lineLimit(1)
                    .fixedSize()
                    .foregroundStyle(retro ? Theme.textPrimary(theme, rc: rc) : Theme.onAccent(theme))
                    .padding(.horizontal, retro ? 1 : 6)
                    .padding(.vertical, 3)
                    .background { if !retro { Capsule().fill(fill) } }
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { whatsNewButtonWidth = $0 }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("What's New?")
            .accessibilityHint("Shows what's new in this version")
            .scaleEffect(isWhatsNewOut || reduceMotion ? 1 : 0.5, anchor: .leading)
            .opacity(isWhatsNewOut ? 1 : 0)
            .offset(x: x)
            .frame(width: out + max(whatsNewButtonWidth, 1) + 4, alignment: .leading)
            .mask(alignment: .leading) {
                HStack(spacing: 0) {
                    Color.clear.frame(width: markEdge)
                    Rectangle()
                }
            }
            .allowsHitTesting(isWhatsNewOut && store.showsWhatsNewButton)
            .accessibilityHidden(!store.showsWhatsNewButton)
            .task(id: store.showsWhatsNewButton) {
                if store.showsWhatsNewButton {
                    guard !isWhatsNewOut else { return }
                    // A moment after opening, so it's seen.
                    try? await Task.sleep(for: .seconds(0.9))
                    guard !Task.isCancelled else { return }
                    withAnimation(whatsNewAnimation) { isWhatsNewOut = true }
                } else {
                    withAnimation(whatsNewAnimation) { isWhatsNewOut = false }
                }
            }
        }
    }

    /// The week title's leading inset: clear of the mark, and of What's New while it's out.
    /// The title stays centered while the pill fits beside it (most weeks on a Pro Max at
    /// the default size; the user asked, 2026-11-14), moves over only as far as it must,
    /// and shrinks once there's no more room (6.3" phones, the SE, larger text, Retro, a
    /// title with a year).
    private var weekTitleLeadingInset: CGFloat {
        let base = markLeadingInset + 44
        guard isWhatsNewOut, whatsNewButtonWidth > 0, weekTitleRowWidth > 0 else { return base }
        // The pill's trailing edge (it's out at the mark's edge less 2pt), plus a gap.
        let clear = markLeadingInset + 44 - 2 + whatsNewButtonWidth + 6
        // The title is centered between the inset and 56pt from the trailing edge; this
        // inset puts its leading edge at `clear`.
        let needed = 2 * clear + weekTitleNaturalWidth - weekTitleRowWidth + 56
        return min(clear, max(base, needed))
    }
    /// The header house's spring (a little overshoot), a touch longer as the pill goes about
    /// twice as far; a fade with Reduce Motion.
    private var whatsNewAnimation: Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.5, bounce: 0.3)
    }

    /// One of the holiday mark's layers, centered on the mark (Retro's are templates, tinted
    /// by the caller; the others keep their own colors).
    @ViewBuilder
    private func holidayMarkLayer(_ name: String?, size: CGSize) -> some View {
        if let name {
            Image(name)
                .resizable()
                .scaledToFit()
                .frame(width: size.width, height: size.height)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    /// Light or dark as the phone is set, whatever this screen was told: the screen's traits
    /// aren't overridden as a window's are. The environment's scheme while the screen
    /// follows the phone, otherwise.
    private var deviceColorScheme: ColorScheme {
        let screen = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen
        guard let style = screen?.traitCollection.userInterfaceStyle, style != .unspecified else { return colorScheme }
        return style == .dark ? .dark : .light
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

    // MARK: - Week Selector

    /// Previous week, a week picked from a calendar, next week: in the bottom bar, as
    /// narrow as the bar needs. Each button's tap area is its own slice of the capsule.
    private var weekNavigationBar: some View {
        HStack(spacing: 0) {
            weekNavButton("chevron.left", label: "Previous week") { changeWeek(by: -1) }
            // The calendar sheet: weeks, and with calendar events on your events too (a green
            // calendar with a person then).
            weekNavButton(showsEventsToggle ? "calendar.and.person" : "calendar",
                          label: showsEventsToggle ? "Calendar and events" : "Go to week",
                          color: showsEventsToggle ? eventsGreen : nil) { showDatePicker = true }
                // The viewed week's events load ahead, so the sheet opens with them.
                .task(id: showsEventsToggle ? eventsLoadKey : nil) {
                    guard showsEventsToggle, let key = eventsLoadKey else { return }
                    await calendarService.load(weekStarting: key.weekStart, calendarIDs: key.calendarIDs)
                }
            weekNavButton("chevron.right", label: "Next week") { changeWeek(by: 1) }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { weekButtonsWidth = $0 }
        .foregroundStyle(Theme.textPrimary(theme, rc: rc))
        // A little wider while the house is in it; once the house has let go, the edge it
        // left through draws in, slowly, the buttons and the other edge staying where they
        // are. Only its glass's shape changes, never its layout: as padding, the row
        // re-centering it hitched (and both edges at once on a quick spring read as a
        // twitch, 2026-11-14).
        .padding(.horizontal, 6 + Self.selectorSpare)
        .modifier(SelectorBackground(inset: (leading: selectorDrawnIn == .left ? Self.selectorSpare : 0,
                                             trailing: selectorDrawnIn == .right ? Self.selectorSpare : 0),
                                     theme: theme, rc: rc, glassNamespace: barGlass))
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .smooth(duration: 0.45), value: selectorDrawnIn)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    /// How much wider the selector is on this week, given up once the house is out.
    private static let selectorSpare: CGFloat = 6

    /// The selector's edge drawn in once the house has let go through it; it widens again
    /// as the house rejoins.
    private var selectorDrawnIn: BarHouseSide? { barHouseSide == nil || houseAttached ? nil : houseStageSide }

    private func weekNavButton(_ symbol: String, label: String, color: Color? = nil,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(symbol.hasPrefix("chevron") ? .body.bold() : .body)
                .foregroundStyle(color ?? Theme.textPrimary(theme, rc: rc))
                .frame(minWidth: 28, maxWidth: 44, minHeight: Self.barButtonSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: - Bottom Bar

    /// The bottom row of buttons, each with its own background (Liquid Glass, or Retro's
    /// boxes) and no bar behind them, so taps between them reach the cards. They sit
    /// above the home indicator, or 8pt above the screen's edge on a phone with a Home
    /// button (no indicator), as far as the space above them.
    private var bottomBar: some View {
        bottomBarContent
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, max(homeIndicatorInset, 8))
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
                    store.keyboardDoneRequests += 1
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
        )
    }

    private var bottomBarContent: some View {
        // No spacing of its own: the spacers keep the selector clear, and on a 375pt-wide
        // phone it needs all the rest.
        HStack(spacing: 0) {
            // Settings, in a side as wide as Edit's, so the week selector stays centered.
            Button { showSettings = true } label: {
                Image(systemName: Theme.isRetro(theme) ? "terminal" : "gearshape.fill")
                    .font(.system(size: Self.barIconSize))
                    .foregroundStyle(Theme.textSecondary(theme, rc: rc))
                    .frame(width: Self.barButtonSize, height: Self.barButtonSize)
                    .modifier(BarBackground(shape: Self.barButtonShape(theme), theme: theme, rc: rc))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
            .frame(width: max(Self.barButtonSize, editSideWidth), alignment: .leading)

            Spacer(minLength: 4)

            // The week selector (the Tasquel mark at the top goes back to this week, as Go
            // to Today here did; today's date is in the day strip). It takes the room it can.
            // The house grows out of the selector's glass, a drop of it pulling away
            // (`GlassEffectContainer` blends glass this close; `glassEffectID` morphs it).
            GlassEffectContainer(spacing: houseAttached && !reduceMotion ? Self.houseBlend : 0) {
                weekNavigationBar
                    .background { barHouse }
            }
            .layoutPriority(1)
            .onChange(of: barHouseSide) { _, side in moveBarHouse(to: side) }
            // The bar is gone while the keyboard is up, and missed a week change then (a task
            // that went into next week, a swipe while typing): the house catches up as the bar
            // comes back (it stayed in, 2026-11-15).
            .onAppear { reconcileBarHouse() }

            Spacer(minLength: 4)

            // Edit / Done. The side is as wide as the wider of the two words (both laid out,
            // hidden), so the selector doesn't move when editing starts; the Settings side
            // copies its width. (Sized for two buttons, the sides left the arrows ~30pt on
            // an SE.)
            ZStack(alignment: .trailing) {
                editLabel(editing: false).hidden()
                editLabel(editing: true).hidden()
                if !shownWeekIsPast {
                    Button {
                        withAnimation(.snappy(duration: 0.25)) { isEditing.toggle() }
                    } label: {
                        let color: Color = isEditing ? Theme.dotComplete(theme, rc: rc) : Theme.textSecondary(theme, rc: rc)
                        editLabel(editing: isEditing)
                            .foregroundStyle(color)
                            .background {
                                if Theme.isRetro(theme) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Theme.cardFill(theme))
                                        .overlay(RoundedRectangle(cornerRadius: 2).stroke(color, lineWidth: isEditing ? 1.5 : 1))
                                }
                            }
                            .modifier(BarBackground(shape: Capsule(), theme: theme, rc: rc,
                                                    tint: isEditing ? Theme.dotComplete(theme, rc: rc).opacity(0.25) : nil, isRetroBoxed: false))
                            .overlay { if isEditing && !Theme.isRetro(theme) { Capsule().stroke(Theme.dotComplete(theme, rc: rc), lineWidth: 1.5) } }
                            .frame(height: Self.barButtonSize)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isEditing ? "Done Editing" : "Edit")
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: shownWeekIsPast)
            .frame(minWidth: Self.barButtonSize, minHeight: Self.barButtonSize, alignment: .trailing)
            .fixedSize()
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { editSideWidth = $0 }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { barContentWidth = $0 }
    }

    /// The week on screen: the one arriving while paging, else the selected one.
    private var shownWeek: Week? { arrivingWeek ?? store.selectedWeek }
    private var shownWeekIsPast: Bool { shownWeek.map(store.isPastWeek) ?? false }

    /// Where the bar's house is: left of the selector on a later week, at Edit's place on an
    /// earlier one (Edit isn't there then), none on this week.
    private enum BarHouseSide { case left, right }
    /// Inside the selector's middle, just inside its edge, at its place.
    private enum BarHouseStage { case inside, atEdge, out }
    private var barHouseSide: BarHouseSide? {
        guard store.persistenceError == nil, let week = shownWeek else { return nil }
        return store.isFutureWeek(week) ? .left : store.isPastWeek(week) ? .right : nil
    }

    /// How near the house's glass blends with the selector's while attached: a neck of
    /// glass between them that stretches and then lets go.
    private static let houseBlend: CGFloat = 20

    /// Between Settings and the selector (drawn in), ~44pt on an SE, ~58 on a 17 Pro.
    private var barHouseRoom: CGFloat {
        barContentWidth / 2 - weekButtonsWidth / 2 - 6 - Self.barButtonSize
    }

    /// The bar's other buttons' size at Edit's place. On the left, that size where it fits,
    /// smaller where it doesn't.
    private func barHouseSize(_ side: BarHouseSide) -> CGFloat {
        guard side == .left else { return Self.barButtonSize }
        return min(Self.barButtonSize, max(36, barHouseRoom - 2 * 6))
    }

    /// From the selector's middle to the house's middle: left, beside the selector, centered
    /// in the room to Settings where that's narrow (an iPhone) but no more than 10pt from the
    /// selector (on an iPad the room's middle left it far off, the user, 2026-11-15); right,
    /// at the row's end where Edit is on an iPhone, 10pt from the selector on an iPad.
    private func barHouseOffset(_ side: BarHouseSide) -> CGFloat {
        switch side {
        case .left: return -(weekButtonsWidth / 2 + 6 + min(barHouseRoom / 2, 10 + barHouseSize(.left) / 2))
        case .right:
            // At Edit's place (no Edit on a past week); on an iPad, as on the left, 10pt from
            // the selector rather than the far end of a wide bar (the user, 2026-11-15).
            let editsPlace = barContentWidth / 2 - Self.barButtonSize / 2
            guard horizontalSizeClass == .regular else { return editsPlace }
            return min(editsPlace, weekButtonsWidth / 2 + 6 + 10 + barHouseSize(.right) / 2)
        }
    }

    /// The bar's house's moves (the user's design, 2026-11-14). Out: from the selector's
    /// middle it zips inside to the selector's edge on its side, then pushes out through it,
    /// growing, joined by a neck of glass; once out the neck lets go and the selector draws
    /// in. Back: it rejoins the selector at that edge and slips into the middle. To the
    /// other side: into the middle, then out the other way. Reduce Motion: it fades in
    /// and out in place.
    /// Moves the house to where the week on screen needs it, if it isn't there.
    private func reconcileBarHouse() {
        let side = barHouseSide
        let isOut = houseStage != .inside
        let needsMove: Bool
        if let side { needsMove = !isOut || houseStageSide != side } else { needsMove = isOut }
        if needsMove { moveBarHouse(to: side) }
    }

    private func moveBarHouse(to side: BarHouseSide?) {
        houseMoveGeneration += 1
        let generation = houseMoveGeneration
        func later(_ delay: Double, _ step: @escaping () -> Void) {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard generation == houseMoveGeneration else { return }
                step()
            }
        }
        if reduceMotion {
            if let side { houseStageSide = side }
            houseAttached = side == nil
            withAnimation(.easeInOut(duration: 0.2)) { houseStage = side == nil ? .inside : .out }
            return
        }
        withAnimation(.easeIn(duration: 0.15)) { houseAttached = true }
        func comeOut(_ side: BarHouseSide) {
            houseStageSide = side  // in the middle, so nothing moves
            withAnimation(.easeIn(duration: 0.12)) { houseStage = .atEdge }
            switch side {
            case .left:
                later(0.12) { withAnimation(.spring(duration: 0.45, bounce: 0.15)) { houseStage = .out } }
                // Lets go as it pulls away, as on the right, so the selector draws in with the
                // house's move: at 0.45s, the house nearly settled, the neck letting go and then
                // the edge drawing in came as steps of their own (the user, 2026-11-15).
                later(0.12 + 0.12) { withAnimation(.easeOut(duration: 0.2)) { houseAttached = false } }
            case .right:
                // Out of the selector slowly, then quickly over to Edit's place, easing out
                // (the user's ask, 2026-11-14: one spring went too fast). One curve, slow at
                // first: as two steps, the second starting on a timer, it hitched between them.
                later(0.12) { withAnimation(.timingCurve(0.6, 0, 0.2, 1, duration: 0.6)) { houseStage = .out } }
                // As it pulls away (~0.15s into the curve), as on the left: the selector drawing
                // in once the house had settled, half a second after it let go, looked like a
                // twitch of its own (the user, 2026-11-14).
                later(0.12 + 0.16) { withAnimation(.easeOut(duration: 0.2)) { houseAttached = false } }
            }
        }
        switch (side, houseStage) {
        case (nil, .inside):
            break
        case (nil, _):
            withAnimation(.spring(duration: 0.3, bounce: 0)) { houseStage = .atEdge }
            later(0.22) { withAnimation(.easeOut(duration: 0.12)) { houseStage = .inside } }
        case (let side?, .inside):
            comeOut(side)
        case (let side?, _):
            withAnimation(.easeInOut(duration: 0.2)) { houseStage = .inside }
            later(0.2) { comeOut(side) }
        }
    }

    /// The house's size at a stage: 70% inside the selector, growing to full as it comes out.
    private func barHouseDrawnSize(_ stage: BarHouseStage, _ side: BarHouseSide) -> CGFloat {
        stage == .inside || stage == .atEdge ? barHouseSize(side) * 0.7 : barHouseSize(side)
    }

    /// From the selector's middle to the house's middle at a stage.
    private func barHouseX(_ stage: BarHouseStage, _ side: BarHouseSide) -> CGFloat {
        let direction: CGFloat = side == .left ? -1 : 1
        // The selector's half width while the house is in it.
        let wideHalf = weekButtonsWidth / 2 + 6 + Self.selectorSpare
        let size = barHouseDrawnSize(stage, side)
        switch stage {
        case .inside: return 0
        case .atEdge: return direction * (wideHalf - size / 2 - 3)
        case .out: return barHouseOffset(side)
        }
    }

    /// Back to this week, in the bottom bar (the user asked, 2026-11-14): on a later week it
    /// comes out of the selector to its left, on an earlier week to the right, all the way
    /// to where Edit is, and on this week it's back inside the selector (`moveBarHouse`).
    /// Green like the header's house; Retro's box like Settings, hidden behind the selector.
    /// Always there, hidden inside the selector on this week (to VoiceOver and taps too): a
    /// glass container drops a glass view the moment it's removed, so the house couldn't go
    /// back in if it were removed. Placed by layout (`position`), not `offset`: VoiceOver's
    /// stand-in button takes the layout's place.
    private var barHouse: some View {
        let side = houseStageSide
        let stage = reduceMotion ? .out : houseStage
        let size = barHouseDrawnSize(stage, side)
        let x = barHouseX(stage, side)
        return GeometryReader { selector in
            ZStack {
                // VoiceOver's and UI tests' button, where the house is once out (the glass
                // house has none of its own: always there, it couldn't be taken out of the
                // tree, and a stand-in for it stayed in the selector's middle).
                if barHouseSide != nil {
                    Button { changeWeek(to: today) } label: {
                        Color.clear
                            .frame(width: max(barHouseSize(side), 44), height: max(barHouseSize(side), 44))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Back to This Week")
                    .accessibilityIdentifier("Bar Back to This Week")
                    .position(x: selector.size.width / 2 + barHouseOffset(side), y: selector.size.height / 2)
                }
                Button { changeWeek(to: today) } label: {
                    // Drawn at its full size and scaled, so it grows smoothly (a font size jumps).
                    BarHouseIcon(size: Self.barIconSize * barHouseSize(side) / Self.barButtonSize, color: Theme.expirySet(theme, rc: rc),
                                 isOut: houseStage == .out)
                        .scaleEffect(size / barHouseSize(side))
                        .frame(width: size, height: size)
                        .modifier(BarBackground(shape: Self.barButtonShape(theme), theme: theme, rc: rc,
                                                glassID: "house", glassNamespace: barGlass))
                        // A full 44pt to tap, also where it's drawn smaller.
                        .frame(width: max(size, 44), height: max(size, 44))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .hiddenFromVoiceOver()
                .position(x: selector.size.width / 2 + x, y: selector.size.height / 2)
            }
        }
        .opacity(reduceMotion && houseStage != .out ? 0 : 1)
        .allowsHitTesting(barHouseSide != nil)
    }

    /// Edit or Done in words, not an icon: "Edit" says what it does, and a pencil is each
    /// card's own edit button.
    private func editLabel(editing: Bool) -> some View {
        Text(Theme.isRetro(theme) ? (editing ? "[DONE]" : "[EDIT]") : (editing ? "Done" : "Edit"))
            .font(Theme.isRetro(theme) ? .system(.subheadline, design: .monospaced).bold() : .headline)
            // Capped: at accessibility sizes the word widened both sides (`editSideWidth`)
            // and squeezed the week arrows between them.
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .lineLimit(1)
            .padding(.horizontal, Theme.isRetro(theme) ? 12 : 18)
            .frame(minWidth: Self.barButtonSize, minHeight: Theme.isRetro(theme) ? Self.barButtonSize * 0.75 : Self.barButtonSize)
    }

    /// The Tasquel mark's distance from the leading edge: 12pt, or more in an iPad window
    /// whose controls sit in that corner (they covered it, and a tap there opened the window
    /// menu instead of going back to this week).
    private var markLeadingInset: CGFloat { max(12, windowControlsInset) }

    /// The viewed week, between the Tasquel mark (back to this week) and Open/Close All.
    private var weekTitleRow: some View {
        let font = Font.system(size: weekTitleSize, weight: .bold, design: Theme.isRetro(theme) ? .monospaced : .default)
        // Measured without animating, so a new week's title or a rotation doesn't slide it.
        var instant = Transaction()
        instant.disablesAnimations = true
        return weekTitleText
            .font(font)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            // Clear of the buttons on either side (the mark is 44pt wide), and of What's New
            // while it's out.
            .animation(whatsNewAnimation) { title in
                title.padding(.leading, weekTitleLeadingInset)
            }
            .padding(.trailing, 56)
            .frame(maxWidth: .infinity)
            .background(alignment: .leading) {
                weekTitleText
                    .font(font)
                    .fixedSize()
                    .hidden()
                    .accessibilityHidden(true)
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
                        withTransaction(instant) { weekTitleNaturalWidth = width }
                    }
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
                withTransaction(instant) { weekTitleRowWidth = width }
            }
            .overlay(alignment: .leading) {
                // The turkey and What's New first, so the mark is drawn over them.
                ZStack(alignment: .leading) {
                    turkeyCameo
                    whatsNewButton
                    homeButton
                }
            }
            .overlay(alignment: .trailing) { expandAllButton }
            .background { WindowControlsInsetReader { windowControlsInset = $0 } }
            .padding(.top, 8)
    }

    /// The bar at the top: the week's title, its days (today's date among them), and what
    /// applies to the week now (past, being edited, not saving). Frosted glass, reaching up
    /// behind the status bar, with the cards scrolling under it; in Retro a solid bar with
    /// a rule under it.
    private func weekHeader(_ week: Week) -> some View {
        VStack(spacing: 12) {
            weekTitleRow
            WeekDayStrip(weekStart: (arrivingWeek ?? week).startDay, today: DayKey(today, in: store.calendar),
                         todayDate: today, theme: theme, rc: rc,
                         selectedWeekday: dayFilter, firstWeekday: store.firstWeekday,
                         onSelect: { weekday in
                             withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) {
                                 dayFilter = dayFilter == weekday ? nil : weekday
                             }
                         })
                // Capped: at the largest accessibility sizes the seven pills came to ~675pt
                // and stretched the whole screen past both edges, the bar's Settings and
                // Edit off it. (Here, not inside: its @ScaledMetric sizes read this
                // environment. VoiceOver reads the day aloud.)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .padding(.horizontal, 16)
            // No "Past week · view only" line (the user's call, 2026-11-14: it pushed the cards
            // down); the house at Edit's place, the dimmed checkboxes and VoiceOver's title
            // say it.
            if isEditing && !isPastWeek {
                editModeHintText
                    .padding(.bottom, -4)
                    .transition(.opacity)
            }
            if store.isSaveFailing && store.saveError == nil {
                saveFailingNotice
            }
        }
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity)
        .background {
            if Theme.isRetro(theme) {
                Theme.background(theme)
                    .overlay(alignment: .bottom) { Theme.cardBorder(theme, rc: rc).frame(height: 1) }
                    .ignoresSafeArea(edges: .top)
            } else {
                Rectangle().fill(.thinMaterial)
                    .ignoresSafeArea(edges: .top)
            }
        }
    }

    /// "Week of 10/5/26" for the viewed week (or the one arriving while paging).
    private var weekTitleText: some View {
        let title = arrivingWeek?.displayTitle ?? store.selectedWeek?.displayTitle ?? "Tasquel"
        return Text(Theme.isRetro(theme) ? "> \(title)_" : title)
            .accessibilityLabel(title)
            .accessibilityValue(shownWeekIsPast ? "Past week, view only" : "")
            .accessibilityAddTraits(.isHeader)
            .accessibilityActions {
                if store.lastDelete != nil { Button("Undo delete") { undoDelete() } }
            }
    }

    // MARK: - Week Content

    /// Bottom bar icons: 20% larger than the original .title3 (20pt), with matching tap areas.
    private static let barIconSize: CGFloat = 24
    private static let barButtonSize: CGFloat = 52
    /// Between Settings and the calendar toggle, so their glass stays apart.
    /// The groups either side of the week selector, the same width so it stays centered.

    private static func barButtonShape(_ theme: AppearanceMode) -> AnyShape {
        Theme.isRetro(theme) ? AnyShape(RoundedRectangle(cornerRadius: 2)) : AnyShape(Circle())
    }
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

    /// In four columns (iPad landscape) an open card takes two, half the width, and the closed
    /// cards go two across beside it (`CategoryGridLayout.halfWidthOpen`), so the rest of the
    /// week stays in view (the user, 2026-11-15; prototyped 2026-11-13/14). Portrait keeps
    /// three columns and full-width open cards; at accessibility sizes every card has a row.
    private var halfWidthOpen: Bool { gridColumns >= 4 && !usesSingleColumn }

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

        // The reader lets a field keep itself in view (see `cardGridScroll`).
        ScrollViewReader { scroll in
            ScrollView {
                VStack(spacing: 8) {
                    // Expanded cards take a full row; other open cards remain open.
                    CategoryGridLayout(spacing: 8, columns: gridColumns, halfWidthOpen: halfWidthOpen) {
                        // First, in the top-left slot: at the grid's end it was below the screen
                        // with ten cards (the user, 2026-11-15). Card drags go by the cards'
                        // measured frames, so the tile ahead of them changes nothing there.
                        if showAdd {
                            addCategoryButton
                                .transition(.opacity)
                        }
                        // By category ID, not by the entry's name key: a renamed card stays the
                        // same view, so a menu, sheet or field open in it survives the rename.
                        ForEach(gridEntries(for: week), id: \.category.id) { entry in
                            let isExpanded = expandedCategoryKeys.contains(entry.id)
                            let weekStart = week.startDay
                            GridCard(
                                key: entry.id,
                                layout: GridCard.Layout(columns: gridColumns, singleColumn: usesSingleColumn,
                                                        reduceMotion: reduceMotion),
                                category: entry.category,
                                store: store,
                                isExpanded: isExpanded,
                                isEditing: isEditing,
                                // Only a card's own edit mode: in Edit every card is closed, and
                                // putting all their hidden task rows into editing too (every row's
                                // icons running out, on three weeks of pages) held up Edit for about
                                // half a second before its tile showed (the user, 2026-11-15).
                                isEditingTasks: editingCategoryKeys.contains(entry.id),
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
                                // The week as it is when tapped: a card that didn't change keeps
                                // these closures while other cards in its week do (`GridCard`).
                                onExpand: { expandCard(entry.id, in: liveWeek(startingOn: weekStart) ?? week) },
                                onCollapse: {
                                    withAnimation(cardAnimation) { collapseCategory(entry.id) }
                                },
                                onRenamed: { renameCardKey(entry.id, to: $0) }
                            )
                            .equatable()
                            // Deleting a card's last task while editing it ends its edit mode, so
                            // the Add task row is back (empty, as a checkbox and one-time) without
                            // tapping the checkmark first.
                            .onChange(of: entry.category.tasks.isEmpty) { _, isEmpty in
                                // (Neighbor pages share the key: next week's copy emptying
                                // mustn't end this week's card's edit mode.)
                                guard isEmpty, week.startDay == store.selectedWeek?.startDay,
                                      editingCategoryKeys.contains(entry.id) else { return }
                                withAnimation(.snappy(duration: 0.25)) { _ = editingCategoryKeys.remove(entry.id) }
                            }
                            // The dragged card leaves a gap where it will land; a lifted copy
                            // follows the finger (see the overlay below).
                            .opacity(cardDrag?.key == entry.id ? 0 : 1)
                            // As the app opens, a card with a task for today wiggles once. (By its own
                            // count only: other weeks' cards have other IDs. Zeroed while its page was
                            // off to the side, the count changed twice on a swipe there and back, and
                            // each change wiggled it again.)
                            .modifier(CardWiggle(trigger: wiggleTicks[entry.category.id] ?? 0, isExpanded: isExpanded))
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
                                // Also on the week title; the Undo button itself stays while VoiceOver is on.
                                if store.lastDelete != nil { Button("Undo delete") { undoDelete() } }
                            }
                            // Outside the modifiers above, where the grid layout can read it.
                            .categoryGridFullWidth(isExpanded || usesSingleColumn)
                            // The card being opened or closed stays above neighbors sliding past it.
                            .zIndex(entry.id == lastToggledCategory ? 2 : isExpanded ? 1 : 0)
                        }
                    }
                    .coordinateSpace(.named(Self.cardGridSpace))
                    // An open card is this wide: its contents are laid out at that width
                    // while it opens and closes (`CardContentCrossFade`).
                    // Two columns' width when open cards take half the grid.
                    .environment(\.cardGridWidth, cardGridWidth.map { width in
                        guard halfWidthOpen else { return width }
                        let column = (width - 8 * CGFloat(gridColumns - 1)) / CGFloat(gridColumns)
                        return column * 2 + 8
                    })
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { cardGridWidth = $0 }
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
            .modifier(PullToCloseAll(isEnabled: viewedWeekHasOpenCard && !isEditing && !isKeyboardVisible,
                                     theme: theme, rc: rc, onClose: collapseAllCards))
            .scrollDisabled(cardDrag != nil)
            .sensoryFeedback(.impact(weight: .medium), trigger: cardDrag?.key) { _, new in new != nil }
            .sensoryFeedback(.selection, trigger: liveCardOrder)
            // Keeps the field being edited (and its options) clear of the Done button.
            .safeAreaPadding(.bottom, isKeyboardVisible ? Self.keyboardDoneClearance : 0)
            .environment(\.cardGridScroll, scroll)
            .environment(\.cardGridBottomBar, isKeyboardVisible ? 0 : bottomBarHeight)
        }
    }

    // MARK: - Grid Order & Expansion

    /// Weeks create new category IDs, so layout state follows a category's name.
    /// The occurrence distinguishes categories with the same name in one week.
    fileprivate struct CategoryLayoutKey: Hashable {
        let name: String
        let occurrence: Int

    }

    /// `id` (name and occurrence) carries a card's open and editing state and its place
    /// across weeks, where category IDs change. Within a week the grid keys cards by
    /// category ID (see `weekContent`).
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

    /// A card of the viewed week is open. (`expandedCategoryKeys` also holds cards open in
    /// other weeks, so they reopen there; "every card is closed" means this week's.)
    private var viewedWeekHasOpenCard: Bool {
        guard let week = store.selectedWeek, !expandedCategoryKeys.isEmpty else { return false }
        return categoryKeys(for: week.categories).values.contains(where: expandedCategoryKeys.contains)
    }

    /// Cards in display order: any reordering from expansion first, then the rest. The
    /// viewed week keeps its snapshot (`sortedNames`), so cards don't move while it's used; a
    /// week beside it is laid out as it will be once it's the viewed week (its own sort,
    /// open cards reopened on it as `refreshSortOrder` will), so nothing moves when it lands.
    /// (With the viewed week's snapshot, cards it doesn't have went last on the page sliding
    /// in, then jumped to their places once it stopped; the user saw it, 2026-11-14.)
    private func gridEntries(for week: Week) -> [CategoryGridEntry] {
        let isViewed = week.id == store.selectedWeek?.id
        let names = isViewed ? sortedNames : sortNames(for: week)
        let entries = baseGridEntries(for: week, sortedBy: names)
        let order: [CategoryLayoutKey]
        if isViewed {
            order = liveCardOrder ?? categoryDisplayOrder
        } else if categoryDisplayOrder.isEmpty || names == sortedNames {
            order = categoryDisplayOrder
        } else {
            order = reopenedOrder(entries, open: expandedCategoryKeys)
        }
        let entriesByKey = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
        let ordered = order.compactMap { entriesByKey[$0] }
        let orderedKeys = Set(ordered.map(\.id))
        return ordered + entries.filter { !orderedKeys.contains($0.id) }
    }

    /// A week's cards sorted by `names` (empty: the week's own order), pinned cards first.
    private func baseGridEntries(for week: Week, sortedBy names: [String]) -> [CategoryGridEntry] {
        let keysByID = categoryKeys(for: week.categories)
        var entries = week.categories.compactMap { category in
            keysByID[category.id].map { CategoryGridEntry(id: $0, category: category) }
        }
        // Pinned cards come first, in the week's own order whatever the sort.
        let pinned = entries.filter(\.category.isPinned)
        entries.removeAll(where: \.category.isPinned)
        if !names.isEmpty {
            // Names not in the snapshot (added since) go last, in their arranged order.
            let rank = Dictionary(names.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
            entries = entries.enumerated()
                .sorted { (rank[$0.element.id.name] ?? Int.max, $0.offset) < (rank[$1.element.id.name] ?? Int.max, $1.offset) }
                .map(\.element)
        }
        return pinned + entries
    }

    /// The names in sort order a week gets when it becomes the viewed one (empty: manual).
    private func sortNames(for week: Week) -> [String] {
        store.categorySort == .manual ? [] : store.sortedCategories(week.categories).map(\.name)
    }

    /// The display order `reopenCards` would give these entries: each open card opened in
    /// turn, moved to the start of its row.
    private func reopenedOrder(_ entries: [CategoryGridEntry], open keys: Set<CategoryLayoutKey>) -> [CategoryLayoutKey] {
        var order = entries.map(\.id)
        let pinned = Set(entries.filter(\.category.isPinned).map(\.id))
        var opened: Set<CategoryLayoutKey> = []
        for key in entries.map(\.id) where keys.contains(key) {
            if let moved = orderOpening(key, in: order, pinned: pinned, open: opened) { order = moved }
            opened.insert(key)
        }
        return order
    }

    /// Re-sorts at the calm moments `sortedNames` describes.
    /// A task just added to next week (its day had gone by this week): the screen goes there,
    /// as › would, and its card there shows the note (`AddTaskRowCard.handedOver`).
    private var addedElsewhereFollower: some View {
        Color.clear.onChange(of: store.addedElsewhere?.token) {
            guard let note = store.addedElsewhere, note.weekStart != store.selectedWeek?.startDay else { return }
            let title = "\(note.canUndo ? "Added" : "Moved") to \(weekPhrase(note.weekStart))"
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) {
                movedNotice = MovedNotice(title: title, detail: note.detail)
            }
            changeWeek(to: note.weekStart.adding(days: 3).date(in: store.calendar))
        }
    }

    /// The screen just went to another week with a task: a pop-up says so, where it can't be
    /// missed (the user, 2026-11-15: right after Set Date, the slide alone was a blink, and
    /// they might not notice they'd been taken to the future). OK, or Back to This Week.
    private struct MovedNotice: Equatable {
        let title: String
        let detail: String
        let token = UUID()
    }

    /// "next week", or "the week of Dec 14".
    private func weekPhrase(_ start: DayKey) -> String {
        if let currentWeekStart, start == currentWeekStart.adding(days: 7) { return "next week" }
        return "the week of " + start.date(in: store.calendar).formatted(.dateTime.month(.abbreviated).day())
    }

    @ViewBuilder
    private var movedNoticeLayer: some View {
        if let notice = movedNotice {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                movedNoticeCard(notice)
                Spacer(minLength: 0)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.94)))
            .task(id: notice.token) {
                try? await Task.sleep(for: .seconds(6))
                guard !Task.isCancelled else { return }
                withAnimation(.snappy(duration: 0.25)) { movedNotice = nil }
            }
        }
    }

    private func movedNoticeCard(_ notice: MovedNotice) -> some View {
        let retro = Theme.isRetro(theme)
        return VStack(spacing: 10) {
            Image(systemName: "calendar.badge.clock")
                .font(.title2)
                .foregroundStyle(Theme.expirySet(theme, rc: rc))
                .hiddenFromVoiceOver()
            Text(retro ? notice.title.uppercased() : notice.title)
                .font(retro ? .system(.headline, design: .monospaced) : .headline)
                .foregroundStyle(Theme.textPrimary(theme, rc: rc))
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            if !notice.detail.isEmpty {
                Text(notice.detail)
                    .font(retro ? .system(.subheadline, design: .monospaced) : .subheadline)
                    .foregroundStyle(Theme.textSecondary(theme, rc: rc))
                    .multilineTextAlignment(.center)
            }
            HStack(spacing: 12) {
                Button(retro ? "[OK]" : "OK") {
                    withAnimation(.snappy(duration: 0.25)) { movedNotice = nil }
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("Moved OK")
                Button(retro ? "[BACK]" : "Back to This Week") {
                    withAnimation(.snappy(duration: 0.25)) { movedNotice = nil }
                    changeWeek(to: today)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("Moved Back to This Week")
            }
            .tint(Theme.accent(theme, rc: rc))
            .padding(.top, 4)
        }
        .padding(20)
        .frame(maxWidth: 340)
        .background {
            if retro {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Theme.navCapsule(theme))
                    .overlay(RoundedRectangle(cornerRadius: 2).stroke(Theme.cardBorder(theme, rc: rc), lineWidth: 1))
            } else {
                RoundedRectangle(cornerRadius: 24).fill(.clear).glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24))
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var sortOrderWatcher: some View {
        Color.clear
            .onChange(of: viewedCategories) { old, new in reconcileCardKeys(from: old, to: new) }
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
            // A card's own edit mode is for that week's card, not its copies in other weeks.
            .onChange(of: store.selectedWeek?.startDay) {
                editingCategoryKeys.removeAll()
                if let title = store.selectedWeek?.displayTitle {
                    AccessibilityNotification.Announcement(title).post()
                }
            }
            .onChange(of: store.categorySort) { withAnimation(cardAnimation) { refreshSortOrder() } }
            .onChange(of: viewedWeekHasOpenCard) { _, anyOpen in
                if !anyOpen { withAnimation(cardAnimation) { refreshSortOrder() } }
            }
    }

    private var editModeHintText: some View {
        Text(editModeHint)
            .font(Theme.isRetro(theme) ? .system(.caption, design: .monospaced) : .caption)
            .foregroundStyle(Theme.textSecondary(theme, rc: rc))
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
        let names = store.selectedWeek.map(sortNames) ?? []
        guard names != sortedNames else { return }
        sortedNames = names
        // Open cards moved to the start of their rows go where the new order puts them
        // (their places would otherwise hold the old order until every card is closed).
        if !categoryDisplayOrder.isEmpty { reopenCards(expandedCategoryKeys) }
    }

    /// Opens `keys` again on top of the week's current order, as if opened one by one: each
    /// at the start of its row. Keys of cards not in this week stay open for other weeks.
    private func reopenCards(_ keys: Set<CategoryLayoutKey>) {
        guard let week = store.selectedWeek else {
            expandedCategoryKeys = keys
            return
        }
        let toggled = lastToggledCategory
        categoryDisplayOrder.removeAll()
        expandedCategoryKeys.removeAll()
        for key in gridEntries(for: week).map(\.id) where keys.contains(key) {
            expandCategory(key, in: week)
        }
        expandedCategoryKeys.formUnion(keys)
        lastToggledCategory = toggled
    }

    /// Expanding a card that isn't first in its row moves it into the row's first
    /// slot, so it opens in place instead of dropping below an already-open card.
    /// The week a page shows, as it is now: the viewed week, or a neighbor's preview.
    private func liveWeek(startingOn start: DayKey) -> Week? {
        if let viewed = store.selectedWeek, viewed.startDay == start { return viewed }
        return store.previewWeek(for: start.date(in: store.calendar))
    }

    private func expandCard(_ key: CategoryLayoutKey, in week: Week) {
        guard !isEditing else { return }  // edit mode keeps cards collapsed
        withAnimation(cardAnimation) { expandCategory(key, in: week) }
    }

    private func expandCategory(_ key: CategoryLayoutKey, in week: Week) {
        let entries = gridEntries(for: week)
        let pinned = Set(entries.filter(\.category.isPinned).map(\.id))
        if let moved = orderOpening(key, in: entries.map(\.id), pinned: pinned, open: expandedCategoryKeys) {
            categoryDisplayOrder = moved
        }
        expandedCategoryKeys.insert(key)
        lastToggledCategory = key
    }

    /// The order with `key` opened: moved to the start of its row (never ahead of a pinned
    /// card: they keep the start of the grid), or nil where it stays. `open`: the cards
    /// already open, each taking a full row.
    private func orderOpening(_ key: CategoryLayoutKey, in order: [CategoryLayoutKey],
                              pinned: Set<CategoryLayoutKey>, open: Set<CategoryLayoutKey>) -> [CategoryLayoutKey]? {
        // Open cards half the width: an opened card keeps its place (its lane takes it).
        guard !halfWidthOpen else { return nil }
        let rows = CategoryGridLayout.rows(fullWidth: order.map { usesSingleColumn || open.contains($0) }, columns: gridColumns)
        guard let row = rows.first(where: { $0.dropFirst().contains { order[$0] == key } }),
              let index = row.first(where: { order[$0] == key }) else { return nil }
        let slot = pinned.contains(key) ? row[0] : (row.first { !pinned.contains(order[$0]) } ?? index)
        guard slot < index else { return nil }
        var moved = order
        moved.remove(at: index)
        moved.insert(key, at: slot)
        return moved
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
        /// The cards it can swap with: the pinned ones if it's pinned, else the rest.
        var group: Set<CategoryLayoutKey> = []
    }

    /// Card places in the week being viewed.
    private var cardFrames: [CategoryLayoutKey: CGRect] {
        store.selectedWeek.flatMap { cardFrameStore.frames[$0.startDay] } ?? [:]
    }

    private func liftCard(_ key: CategoryLayoutKey, in week: Week) {
        guard cardDrag == nil, let frame = cardFrames[key] else { return }
        let entries = gridEntries(for: week)
        liveCardOrder = entries.map(\.id)
        liftedCardOrder = liveCardOrder
        let isPinned = entries.first { $0.id == key }?.category.isPinned ?? false
        let group = Set(entries.filter { $0.category.isPinned == isPinned }.map(\.id))
        withAnimation(.snappy(duration: 0.2)) {
            cardDrag = CardDrag(key: key, grab: nil, location: frame.origin, group: group)
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
        // Pinned cards swap only with each other, so none of them leaves the start.
        let target = liveCardOrder?.first { $0 != drag.key && drag.group.contains($0) && cardFrames[$0]?.contains(location) == true }
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
            store.setCategoryOrder(savedOrder(moving: drag.key, shownAs: order, in: week).map(\.name))
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
        let entries = gridEntries(for: week)
        let order = entries.map(\.id)
        let isPinned = entries.map(\.category.isPinned)
        // Only within the pinned cards, or the rest.
        if let index = order.firstIndex(of: key) {
            if index > 0, isPinned[index - 1] == isPinned[index] {
                Button("Move Earlier") { moveCard(key, by: -1, in: order, week: week) }
            }
            if index < order.count - 1, isPinned[index + 1] == isPinned[index] {
                Button("Move Later") { moveCard(key, by: 1, in: order, week: week) }
            }
        }
    }

    private func moveCard(_ key: CategoryLayoutKey, by offset: Int, in order: [CategoryLayoutKey], week: Week) {
        guard let from = order.firstIndex(of: key), order.indices.contains(from + offset) else { return }
        var order = order
        order.swapAt(from, from + offset)
        withAnimation(.snappy(duration: 0.25)) {
            store.setCategoryOrder(savedOrder(moving: key, shownAs: order, in: week).map(\.name))
            if !categoryDisplayOrder.isEmpty { categoryDisplayOrder = order }
        }
    }

    /// The order to save after moving one card: the week's own order with `key` moved to
    /// just before the card that follows it on screen. (On screen, an open card may sit at
    /// the start of its row only while it's open; that mustn't be saved.)
    private func savedOrder(moving key: CategoryLayoutKey, shownAs shown: [CategoryLayoutKey], in week: Week) -> [CategoryLayoutKey] {
        let keysByID = categoryKeys(for: week.categories)
        var order = week.categories.compactMap { keysByID[$0.id] }.filter { $0 != key }
        let after = shown.drop { $0 != key }.dropFirst()
        if let next = after.first(where: { order.contains($0) }), let index = order.firstIndex(of: next) {
            order.insert(key, at: index)
        } else {
            order.append(key)
        }
        return order
    }

    /// A renamed category gets a new layout key (keys follow names), so its open, editing
    /// and order state moves to the new key; otherwise the card would close.
    private func renameCardKey(_ old: CategoryLayoutKey, to name: String) {
        moveCardKey(old, to: CategoryLayoutKey(name: name, occurrence: old.occurrence))
    }

    /// A card's open and editing state, place and sort rank follow it to its new key.
    private func moveCardKey(_ old: CategoryLayoutKey, to new: CategoryLayoutKey) {
        guard old != new else { return }
        remapCardKeys([old: new])
    }

    /// Moves cards' state to new keys, and forgets deleted cards (a nil key), all at once
    /// from the state as it was. (One at a time, in a dictionary's order, forgetting a
    /// deleted "Work" could take the state just moved to its key by the second "Work",
    /// closing it.) A forgotten card can't reopen when Edit ends or come back open when a
    /// category with its name is added again. Keys not in `changes` stay as they are.
    private func remapCardKeys(_ changes: [CategoryLayoutKey: CategoryLayoutKey?]) {
        guard !changes.isEmpty else { return }
        func remap(_ key: CategoryLayoutKey) -> CategoryLayoutKey? {
            if let change = changes[key] { return change }
            return key
        }
        expandedCategoryKeys = Set(expandedCategoryKeys.compactMap(remap))
        editingCategoryKeys = Set(editingCategoryKeys.compactMap(remap))
        expandedBeforeEditing = Set(expandedBeforeEditing.compactMap(remap))
        categoryDisplayOrder = categoryDisplayOrder.compactMap(remap)
        lastToggledCategory = lastToggledCategory.flatMap(remap)
        // The card isn't rebuilt by a rename, so its place for dragging moves with it (a
        // moved card's frame wins over a stale one left at its new key).
        for day in Array(cardFrameStore.frames.keys) {
            guard let frames = cardFrameStore.frames[day] else { continue }
            var remapped = frames.filter { changes[$0.key] == nil }
            for (key, frame) in frames {
                if let change = changes[key], let new = change { remapped[new] = frame }
            }
            cardFrameStore.frames[day] = remapped
        }
        // A renamed card keeps its place in a sorted order.
        var renamed: [String: String] = [:]
        for (old, change) in changes {
            if let new = change, new.name != old.name { renamed[old.name] = new.name }
        }
        if !renamed.isEmpty { sortedNames = sortedNames.map { renamed[$0] ?? $0 } }
    }

    /// The viewed week's categories by ID, to notice renames made outside the card (Saved
    /// Categories, Edit Saved Categories) and deletes.
    private struct ViewedCategories: Equatable {
        let week: DayKey?
        let categories: [Entry]
        struct Entry: Equatable { let id: UUID; let name: String }
    }

    private var viewedCategories: ViewedCategories {
        ViewedCategories(week: store.selectedWeek?.startDay,
                         categories: (store.selectedWeek?.categories ?? []).map { .init(id: $0.id, name: $0.name) })
    }

    /// Keys follow renamed categories and deleted ones are forgotten. Only within one week:
    /// in another week the same cards have other IDs, and keys carry over by name.
    private func reconcileCardKeys(from old: ViewedCategories, to new: ViewedCategories) {
        guard old.week == new.week else { return }
        let keys = { (entries: [ViewedCategories.Entry]) -> [UUID: CategoryLayoutKey] in
            var occurrences: [String: Int] = [:]
            var keys: [UUID: CategoryLayoutKey] = [:]
            for entry in entries {
                let occurrence = occurrences[entry.name, default: 0]
                keys[entry.id] = CategoryLayoutKey(name: entry.name, occurrence: occurrence)
                occurrences[entry.name] = occurrence + 1
            }
            return keys
        }
        let before = keys(old.categories), after = keys(new.categories)
        var changes: [CategoryLayoutKey: CategoryLayoutKey?] = [:]
        for (id, key) in before where after[id] != key {
            changes[key] = .some(after[id])  // nil: deleted
        }
        remapCardKeys(changes)
    }

    private func collapseCategory(_ key: CategoryLayoutKey) {
        // A field in the closing card would otherwise keep the keyboard, typing into a
        // card that's no longer shown. (What was typed is saved as the field closes.)
        dismissKeyboard()
        editingCategoryKeys.remove(key)
        expandedCategoryKeys.remove(key)
        lastToggledCategory = key
        if !viewedWeekHasOpenCard { categoryDisplayOrder.removeAll() }
    }

    // MARK: - Calendar Events (bottom bar)

    /// Calendar events are on (in Settings, and allowed): the calendar sheet has an Events side.
    private var showsEventsToggle: Bool {
        FeatureAccess.isCalendarUnlocked && store.calendarEventsEnabled && calendarService.isAuthorized
    }

    private var eventsGreen: Color {
        Theme.dotComplete(theme, rc: rc)  // green, or the season's
    }

    private var eventsLoadKey: EventsLoadKey? {
        guard let week = store.selectedWeek else { return nil }
        return EventsLoadKey(
            weekStart: week.startDate,
            calendarIDs: Set(calendarService.effectiveSelection(store.selectedCalendarIDs)),
            generation: calendarService.generation
        )
    }

    /// A week's events, for the calendar sheet's Events side (the viewed week, and while a
    /// swipe drags it, the one beside it).
    private func eventsList(for day: DayKey) -> some View {
        let week = Week(startDay: day)
        let calendarIDs = Set(calendarService.effectiveSelection(store.selectedCalendarIDs))
        return CalendarEventsList(
            store: store,
            title: store.isCurrentWeek(week) ? "This Week's Events" : "Events, \(week.displayTitle)",
            days: calendarService.days(forWeekStarting: week.startDate, calendarIDs: calendarIDs),
            onOpen: openInCalendar
        )
        .task(id: EventsLoadKey(weekStart: week.startDate, calendarIDs: calendarIDs, generation: calendarService.generation)) {
            await calendarService.load(weekStarting: week.startDate, calendarIDs: calendarIDs)
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

/// A card in the grid, redrawn only when what it shows (or how the grid is laid out) changes.
/// The screen redraws for many reasons, a card opening, a task checked in another card, and
/// redrawing every card with it (each with every task row, also on the pages beside it) is
/// what made opening cards, checking tasks and scrolling lag (2026-11-12). Its closures act
/// through the screen's state, which they read when called, so the ones it was drawn with
/// stay right; the grid's layout is compared because they read it.
private struct GridCard: View, Equatable {
    /// What the closures read besides state: the grid's columns, text size and Reduce Motion.
    struct Layout: Equatable {
        let columns: Int
        let singleColumn: Bool
        let reduceMotion: Bool
    }

    let key: ContentView.CategoryLayoutKey
    let layout: Layout
    let category: Category
    let store: ChecklistStore
    let isExpanded: Bool
    let isEditing: Bool
    let isEditingTasks: Bool
    let isPastWeek: Bool
    let onToggleEdit: () -> Void
    let onExpand: () -> Void
    let onCollapse: () -> Void
    let onRenamed: (String) -> Void

    static func == (a: GridCard, b: GridCard) -> Bool {
        a.key == b.key && a.layout == b.layout && a.category == b.category && a.store === b.store
            && a.isExpanded == b.isExpanded && a.isEditing == b.isEditing
            && a.isEditingTasks == b.isEditingTasks && a.isPastWeek == b.isPastWeek
    }

    var body: some View {
        CategoryGridCard(category: category, store: store, isExpanded: isExpanded, isEditing: isEditing,
                         isEditingTasks: isEditingTasks, isPastWeek: isPastWeek, onToggleEdit: onToggleEdit,
                         onExpand: onExpand, onCollapse: onCollapse, onRenamed: onRenamed)
    }
}

/// The week swipe's direction and where it was recognized. A plain class, so setting them
/// redraws nothing (see `ContentView.weekSwipe`).
private final class WeekSwipeTracker {
    var axis: Axis?
    /// The drag's translation when its direction was decided.
    var origin: CGFloat = 0
}

/// The week swipe's drag, in its own view with the state that notices iOS cancelling it
/// (`onEnded` isn't called then), so a cancelled swipe can't leave the page disabled and the
/// grid unable to scroll. That state flips at every drag, scrolls too; here it redraws only
/// this, not the screen and every card on it.
private struct WeekSwipeGesture: ViewModifier {
    let onChanged: (DragGesture.Value) -> Void
    let onEnded: (DragGesture.Value) -> Void
    let onCancelled: () -> Void
    @GestureState private var isDragging = false

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: 20)
                    .updating($isDragging) { _, dragging, _ in dragging = true }
                    .onChanged(onChanged)
                    .onEnded(onEnded)
            )
            .onChange(of: isDragging) { _, dragging in
                if !dragging { onCancelled() }
            }
    }
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
/// The bar's green house, faded while it's inside the selector: in once it's past the
/// selector's icons, out before it reaches them going back.
private struct BarHouseIcon: View {
    let size: CGFloat
    let color: Color
    let isOut: Bool

    var body: some View {
        Image(systemName: "house.fill")
            .font(.system(size: size))
            .foregroundStyle(color)
            .opacity(isOut ? 1 : 0)
            .animation(isOut ? .easeIn(duration: 0.14).delay(0.16) : .easeOut(duration: 0.14), value: isOut)
    }
}

/// A capsule (or Retro's box, `cornerRadius`) inset from its frame's sides, so it can draw
/// in on one side, animated, without the view's layout changing.
struct SideInsetCapsule: Shape {
    var leading: CGFloat
    var trailing: CGFloat
    var cornerRadius: CGFloat?

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(leading, trailing) }
        set { leading = newValue.first; trailing = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        let inner = CGRect(x: rect.minX + leading, y: rect.minY, width: max(rect.width - leading - trailing, rect.height),
                           height: rect.height)
        if let cornerRadius { return Path(roundedRect: inner, cornerRadius: cornerRadius) }
        return Capsule().path(in: inner)
    }
}

/// The week selector's background: `BarBackground`'s, drawn in by `inset` on either side.
private struct SelectorBackground: ViewModifier {
    let inset: (leading: CGFloat, trailing: CGFloat)
    let theme: AppearanceMode
    let rc: RetroColor
    let glassNamespace: Namespace.ID

    func body(content: Content) -> some View {
        let shape = SideInsetCapsule(leading: inset.leading, trailing: inset.trailing,
                                     cornerRadius: Theme.isRetro(theme) ? 2 : nil)
        if Theme.isRetro(theme) {
            content
                .background {
                    shape.fill(Theme.cardFill(theme))
                        .overlay(shape.stroke(Theme.cardBorder(theme, rc: rc), lineWidth: 1))
                }
                .contentShape(shape)
        } else {
            content
                .glassEffect(.regular.interactive(), in: shape)
                .glassEffectID("selector", in: glassNamespace)
                .contentShape(shape)
        }
    }
}

/// A bottom bar button's own background: Liquid Glass, tinted when it's on, or in Retro a
/// bordered box.
private struct BarBackground: ViewModifier {
    let shape: AnyShape
    let theme: AppearanceMode
    let rc: RetroColor
    var tint: Color? = nil
    /// False where the view draws its own Retro box (Edit).
    var isRetroBoxed = true
    /// For glass that morphs with other glass in a `GlassEffectContainer`.
    var glassID: String? = nil
    var glassNamespace: Namespace.ID? = nil

    init<S: Shape>(shape: S, theme: AppearanceMode, rc: RetroColor, tint: Color? = nil,
                   isRetroBoxed: Bool = true, glassID: String? = nil, glassNamespace: Namespace.ID? = nil) {
        self.shape = AnyShape(shape)
        self.theme = theme
        self.rc = rc
        self.tint = tint
        self.isRetroBoxed = isRetroBoxed
        self.glassID = glassID
        self.glassNamespace = glassNamespace
    }

    func body(content: Content) -> some View {
        if Theme.isRetro(theme) {
            if isRetroBoxed {
                content
                    .background {
                        shape.fill(Theme.cardFill(theme))
                            .overlay(shape.stroke(Theme.cardBorder(theme, rc: rc), lineWidth: 1))
                    }
                    .contentShape(shape)
            } else {
                content
            }
        } else {
            let glass = tint.map { Glass.regular.tint($0) } ?? .regular
            if let glassID, let glassNamespace {
                content
                    .glassEffect(glass.interactive(), in: shape)
                    .glassEffectID(glassID, in: glassNamespace)
                    .contentShape(shape)
            } else {
                content
                    .glassEffect(glass.interactive(), in: shape)
                    .contentShape(shape)
            }
        }
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

// MARK: - Window Controls

/// Reports how far in from the leading edge content in this view must start to stay clear of
/// an iPadOS window's controls in the top-leading corner (UIKit's safe area adapted to the
/// window's corners, less the plain safe area): 0 when there are none. Read from a plain
/// view behind the header's title row, so it's in that row's own space.
private struct WindowControlsInsetReader: UIViewRepresentable {
    let onChange: (CGFloat) -> Void

    func makeUIView(context: Context) -> ProbeView { ProbeView(onChange: onChange) }

    func updateUIView(_ view: ProbeView, context: Context) { view.onChange = onChange }

    final class ProbeView: UIView {
        var onChange: (CGFloat) -> Void
        private var reported: CGFloat?

        init(onChange: @escaping (CGFloat) -> Void) {
            self.onChange = onChange
            super.init(frame: .zero)
            isUserInteractionEnabled = false
        }

        required init?(coder: NSCoder) { nil }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            report()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            report()
        }

        override func safeAreaInsetsDidChange() {
            super.safeAreaInsetsDidChange()
            report()
        }

        private func report() {
            guard window != nil else { return }
            let adapted = directionalEdgeInsets(for: .safeArea(cornerAdaptation: .horizontal)).leading
            let plain = directionalEdgeInsets(for: .safeArea()).leading
            let inset = max(0, (adapted - plain).rounded())
            guard inset != reported else { return }
            reported = inset
            let onChange = onChange
            // Not during the layout pass that noticed it.
            DispatchQueue.main.async { onChange(inset) }
        }
    }
}

// MARK: - Window Size

/// Reports the size of the window it's in, when it changes: rotation or an iPad window
/// being resized, but not a keyboard (unlike sizes measured in SwiftUI).
private struct WindowSizeReader: UIViewRepresentable {
    let onChange: (CGSize) -> Void

    func makeUIView(context: Context) -> ReaderView { ReaderView(onChange: onChange) }

    func updateUIView(_ view: ReaderView, context: Context) { view.onChange = onChange }

    final class ReaderView: UIView {
        var onChange: (CGSize) -> Void
        private var reported: CGSize?

        init(onChange: @escaping (CGSize) -> Void) {
            self.onChange = onChange
            super.init(frame: .zero)
            isUserInteractionEnabled = false
        }

        required init?(coder: NSCoder) { nil }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            report()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            report()
        }

        private func report() {
            guard let size = window?.bounds.size, size != reported else { return }
            reported = size
            let onChange = onChange
            // Not during the layout pass that noticed it.
            DispatchQueue.main.async { onChange(size) }
        }
    }
}

/// One slight wiggle, 0.5s, each time `trigger` goes up while the card is on screen (a card
/// with a task for today, as the app opens; `wiggleCardsWithTodaysTasks`). An open card,
/// being bigger, turns less. It plays its own count (`plays`), which starts at zero in every
/// card built: a card built again with a count above zero (this week's page, coming back to
/// it from later weeks) wiggled again on the user's phone, iOS 27 (2026-11-12; a 26.3
/// simulator doesn't).
private struct CardWiggle: ViewModifier {
    let trigger: Int
    let isExpanded: Bool
    @State private var plays = 0

    func body(content: Content) -> some View {
        let angle = isExpanded ? 0.6 : 2.0
        content.keyframeAnimator(initialValue: 0.0, trigger: plays) { view, degrees in
            view.rotationEffect(.degrees(degrees))
        } keyframes: { _ in
            KeyframeTrack {
                CubicKeyframe(angle, duration: 0.08)
                CubicKeyframe(-angle, duration: 0.12)
                CubicKeyframe(angle * 0.6, duration: 0.1)
                CubicKeyframe(-angle * 0.3, duration: 0.1)
                CubicKeyframe(0, duration: 0.1)
            }
        }
        .onChange(of: trigger) { plays += 1 }
    }
}
