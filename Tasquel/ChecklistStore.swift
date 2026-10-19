import Foundation
import Observation
import SwiftUI

@Observable
final class ChecklistStore {

    var weeks: [Week] = [] { didSet { previewCache.removeAll() } }
    var selectedDate: Date
    /// Starter categories already added to Saved Categories, so removed ones stay removed.
    private var offeredStarterNames: [String]?
    /// A list task just created from the add-task row, whose item field should take the
    /// keyboard when it appears. Not saved.
    var listAwaitingFirstItem: UUID?
    var savedCategories: [CategoryTemplate] = [] { didSet { previewCache.removeAll() } }
    /// Previewed weeks, so repeated previews (every render while paging) return identical
    /// values instead of new IDs. Cleared whenever the data they're built from changes.
    @ObservationIgnored private var previewCache: [DayKey: Week] = [:]
    var appearanceMode: AppearanceMode = .system
    var retroColor: RetroColor = .green
    var hasSeenWelcome: Bool = false
    /// Calendar integration: show events in the bottom bar, and which calendars to include
    /// (nil until the first time it's turned on, when a default selection is made).
    var calendarEventsEnabled = false
    /// Weeks start on Monday unless the user chooses Sunday.
    var weekStartsOnSunday = false
    var selectedCalendarIDs: [String]?
    var userName: String = ""
    private(set) var weekLoadError: String?
    private(set) var settingsLoadError: String?

    var persistenceError: String? { weekLoadError ?? settingsLoadError }

    /// The viewed week: the saved one, or, for a week that hasn't been saved (a future
    /// week nobody has edited yet), its preview. Editing a preview saves it.
    var selectedWeek: Week? {
        if let wi = storedWeekIndex(startingOn: weekStartDay(containing: selectedDate)) { return weeks[wi] }
        guard persistenceError == nil else { return nil }
        return previewWeek(for: selectedDate)
    }

    var shouldShowWelcome: Bool {
        !hasSeenWelcome
    }

    var colorScheme: ColorScheme? {
        switch appearanceMode {
        case .system: nil
        case .light: .light
        case .dark, .retro: .dark
        }
    }

    private let fileURL: URL
    private let settingsURL: URL
    private let defaults: UserDefaults
    /// The current moment and calendar (with its time zone). Injectable so tests decide
    /// what "today" is instead of depending on the real date.
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let calendarProvider: () -> Calendar

    /// The calendar for week dates: Gregorian, in the provided calendar's time zone, so
    /// a device set to the Japanese, Buddhist, Hebrew or another calendar still finds
    /// the same weeks.
    var calendar: Calendar { .weekDates(in: calendarProvider().timeZone) }

    /// `directory` and `defaults` are injectable so tests never touch the app's real data.
    init(directory: URL = .documentsDirectory, defaults: UserDefaults = .standard,
         now: @escaping () -> Date = { Date() }, calendar: @escaping () -> Calendar = { .current }) {
        fileURL = directory.appending(path: "checklist.json")
        settingsURL = directory.appending(path: "settings.json")
        self.defaults = defaults
        self.now = now
        calendarProvider = calendar
        selectedDate = now()
        userName = defaults.string(forKey: "userName") ?? ""
        loadAndPrepare()
    }

    /// The app's store, or one backed by throwaway storage when UI tests pass
    /// `-isolatedData`, so they never touch the simulator's real data.
    /// `-isolatedDataID <name>` reuses the same throwaway storage across launches.
    static func makeDefault() -> ChecklistStore {
        let arguments = ProcessInfo.processInfo.arguments
        let reusableID = arguments.firstIndex(of: "-isolatedDataID").flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil }
        guard arguments.contains("-isolatedData") || reusableID != nil else { return ChecklistStore() }
        let directory = FileManager.default.temporaryDirectory.appending(path: "isolated-\(reusableID ?? UUID().uuidString)")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return ChecklistStore(directory: directory, defaults: UserDefaults(suiteName: directory.lastPathComponent) ?? .standard)
    }

    /// Init order matters: settings → seed starter templates → weeks → current week.
    /// Stops at the first unreadable file so defaults never overwrite it.
    private func loadAndPrepare() {
        loadSettings()
        guard settingsLoadError == nil else { return }
        seedStarterTemplates()
        load()
        guard weekLoadError == nil else { return }
        let currentWeek = ensureWeekExists(for: now())
        migrateStartersIfNeeded(into: currentWeek)
        syncWithPreviousWeek(for: now())
    }

    /// Adds each starter category to Saved Categories once. A starter the user later
    /// removes or renames isn't added back; one added in an app update is offered once.
    private func seedStarterTemplates() {
        guard let offered = offeredStarterNames else {
            // First launch, or settings from before this was tracked (every starter was
            // added then, so any that are missing were removed by the user).
            if savedCategories.isEmpty { savedCategories = CategoryTemplate.starters }
            offeredStarterNames = CategoryTemplate.starters.map(\.name)
            saveSettings()
            return
        }
        let newStarters = CategoryTemplate.starters.filter { !offered.contains($0.name) }
        guard !newStarters.isEmpty else { return }
        for starter in newStarters where !Self.containsName(starter.name, in: savedCategories.map(\.name)) {
            savedCategories.append(CategoryTemplate(name: starter.name, symbol: starter.symbol))
        }
        offeredStarterNames = offered + newStarters.map(\.name)
        saveSettings()
    }

    /// One-time migration: add missing starters to current week
    private func migrateStartersIfNeeded(into currentWeek: Week) {
        if !defaults.bool(forKey: "didMigrateStarters_v1") {
            if let wi = weeks.firstIndex(where: { $0.id == currentWeek.id }) {
                var didAddToWeek = false
                for starter in CategoryTemplate.starters {
                    if !weeks[wi].categories.contains(where: { $0.name == starter.name }) {
                        weeks[wi].categories.append(Category(name: starter.name, symbol: starter.symbol))
                        didAddToWeek = true
                    }
                }
                if didAddToWeek { save() }
            }
            defaults.set(true, forKey: "didMigrateStarters_v1")
        }
    }

    // MARK: - Persistence

    func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path()) else {
            weekLoadError = nil
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            decoder.userInfo[.weekCalendar] = calendar
            weeks = try decoder.decode([Week].self, from: data)
            sortWeeks()
            weekLoadError = nil
            // Weeks saved before they had a start day just got one, worked out in this
            // time zone. Save it now so a later time-zone change can't shift them.
            if !weeks.isEmpty, data.range(of: Data("\"startDay\"".utf8)) == nil { save() }
        } catch {
            weekLoadError = "Your saved weeks could not be opened. The file has not been changed."
            print("Failed to load: \(error)")
        }
    }

    func retryLoadingData() {
        loadAndPrepare()
    }

    func save() {
        guard persistenceError == nil else { return }
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(weeks)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Failed to save: \(error)")
        }
    }

    // MARK: - Settings Persistence

    private struct Settings: Codable {
        var savedCategories: [CategoryTemplate]
        var appearanceMode: AppearanceMode
        var retroColor: RetroColor?
        var hasSeenWelcome: Bool
        // Optional so settings saved before calendar integration still load.
        var calendarEventsEnabled: Bool?
        var selectedCalendarIDs: [String]?
        var weekStartsOnSunday: Bool?
        var offeredStarterNames: [String]?
    }

    func loadSettings() {
        guard FileManager.default.fileExists(atPath: settingsURL.path()) else {
            settingsLoadError = nil
            return
        }
        do {
            let data = try Data(contentsOf: settingsURL)
            let settings = try JSONDecoder().decode(Settings.self, from: data)
            savedCategories = settings.savedCategories
            appearanceMode = settings.appearanceMode
            retroColor = settings.retroColor ?? .green
            hasSeenWelcome = settings.hasSeenWelcome
            calendarEventsEnabled = settings.calendarEventsEnabled ?? false
            selectedCalendarIDs = settings.selectedCalendarIDs
            weekStartsOnSunday = settings.weekStartsOnSunday ?? false
            offeredStarterNames = settings.offeredStarterNames
            settingsLoadError = nil
        } catch {
            settingsLoadError = "Your settings could not be opened. The file has not been changed."
            print("Failed to load settings: \(error)")
        }
    }

    func saveSettings() {
        guard persistenceError == nil else { return }
        do {
            let settings = Settings(
                savedCategories: savedCategories,
                appearanceMode: appearanceMode,
                retroColor: retroColor,
                hasSeenWelcome: hasSeenWelcome,
                calendarEventsEnabled: calendarEventsEnabled,
                selectedCalendarIDs: selectedCalendarIDs,
                weekStartsOnSunday: weekStartsOnSunday,
                offeredStarterNames: offeredStarterNames
            )
            let data = try JSONEncoder().encode(settings)
            try data.write(to: settingsURL, options: .atomic)
        } catch {
            print("Failed to save settings: \(error)")
        }
    }

    func dismissWelcome() {
        hasSeenWelcome = true
        saveSettings()
    }

    func setAppearance(_ mode: AppearanceMode) {
        appearanceMode = mode
        saveSettings()
    }

    func setRetroColor(_ color: RetroColor) {
        retroColor = color
        saveSettings()
    }

    var firstWeekday: Int { weekStartsOnSunday ? Week.sunday : Week.monday }

    /// Start of the week containing `date`, honoring the week-start setting.
    func startOfWeek(containing date: Date) -> Date {
        Week.startOfWeek(containing: date, firstWeekday: firstWeekday, calendar: calendar)
    }

    /// The day the week containing `date` starts on, in the current time zone.
    func weekStartDay(containing date: Date) -> DayKey {
        DayKey(startOfWeek(containing: date), in: calendar)
    }

    // MARK: - Week Status

    /// Today, in the current time zone.
    private var today: DayKey { DayKey(now(), in: calendar) }

    /// Whether today falls within the week (any week start day).
    func isCurrentWeek(_ week: Week) -> Bool {
        let today = today
        return week.startDay <= today && today < week.startDay.adding(days: 7)
    }

    func isFutureWeek(_ week: Week) -> Bool { week.startDay > today }

    /// Past weeks are read-only.
    func isPastWeek(_ week: Week) -> Bool { !isCurrentWeek(week) && !isFutureWeek(week) }

    /// The saved week starting on `day`, if any.
    private func storedWeekIndex(startingOn day: DayKey) -> Int? {
        weeks.firstIndex { $0.startDay == day }
    }

    /// Where the viewed week is in `weeks`, ready to change. A week that's only a preview
    /// is saved first (the first edit is what makes a future week real). Nil for past
    /// weeks, which are read-only, and when data couldn't be loaded.
    private func editableSelectedWeekIndex() -> Int? {
        guard persistenceError == nil, let week = selectedWeek, !isPastWeek(week) else { return nil }
        if let wi = weeks.firstIndex(where: { $0.id == week.id }) { return wi }
        weeks.append(week)
        sortWeeks()
        return weeks.firstIndex { $0.id == week.id }
    }

    /// Changes the week start day. Every saved week moves by one day (Monday ↔ the
    /// Sunday before it) so its tasks stay with it, and the selected week stays selected.
    func setWeekStartsOnSunday(_ sunday: Bool) {
        guard sunday != weekStartsOnSunday, persistenceError == nil else { return }
        let shift = sunday ? -1 : 1
        let selectedStart = selectedWeek.map { $0.startDay.adding(days: shift).date(in: calendar) }
        weeks = weeks.map { week in
            var moved = week
            moved.startDay = week.startDay.adding(days: shift)
            return moved
        }
        weekStartsOnSunday = sunday
        if let selectedStart { selectedDate = selectedStart }
        save()
        saveSettings()
        ensureWeekExists(for: now())
    }

    func setCalendarEventsEnabled(_ enabled: Bool) {
        calendarEventsEnabled = enabled
        saveSettings()
    }

    func setSelectedCalendarIDs(_ ids: [String]) {
        selectedCalendarIDs = ids
        saveSettings()
    }

    func setUserName(_ name: String) {
        userName = name
        defaults.set(name, forKey: "userName")
    }

    // MARK: - Saved Category Templates

    func addSavedCategory(name: String, symbol: String) {
        let name = Self.cleanName(name)
        guard !name.isEmpty, !Self.containsName(name, in: savedCategories.map(\.name)) else { return }
        let template = CategoryTemplate(name: name, symbol: symbol)
        savedCategories.append(template)
        saveSettings()
    }

    func removeSavedCategory(_ templateID: UUID) {
        savedCategories.removeAll { $0.id == templateID }
        saveSettings()
    }

    /// Renames a saved category and changes its icon. Only the template changes, not
    /// categories already in weeks. Fails if another saved category has the name.
    @discardableResult
    func updateSavedCategory(_ templateID: UUID, name: String, symbol: String) -> Bool {
        let name = Self.cleanName(name)
        guard !name.isEmpty,
              let index = savedCategories.firstIndex(where: { $0.id == templateID }),
              !Self.containsName(name, in: savedCategories.filter { $0.id != templateID }.map(\.name)) else { return false }
        savedCategories[index].name = name
        savedCategories[index].symbol = symbol
        saveSettings()
        return true
    }

    func moveSavedCategories(fromOffsets source: IndexSet, toOffset destination: Int) {
        savedCategories.move(fromOffsets: source, toOffset: destination)
        saveSettings()
    }

    // MARK: - Category Names

    /// Category names are unique, ignoring case and surrounding spaces: weeks and saved
    /// categories match categories by name.
    static func cleanName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func containsName(_ name: String, in names: [String]) -> Bool {
        let name = cleanName(name)
        return names.contains { cleanName($0).caseInsensitiveCompare(name) == .orderedSame }
    }

    /// Whether a new category can't use `name`: a category in the viewed week or a saved
    /// category already has it.
    func isCategoryNameTaken(_ name: String) -> Bool {
        Self.containsName(name, in: (selectedWeek?.categories.map(\.name) ?? []) + savedCategories.map(\.name))
    }

    /// Whether a saved category other than `templateID` has `name`.
    func isSavedCategoryNameTaken(_ name: String, excluding templateID: UUID?) -> Bool {
        Self.containsName(name, in: savedCategories.filter { $0.id != templateID }.map(\.name))
    }

    // MARK: - Week Management

    @discardableResult
    func ensureWeekExists(for date: Date) -> Week {
        let monday = weekStartDay(containing: date)
        if let wi = storedWeekIndex(startingOn: monday) {
            return weeks[wi]
        }

        var newWeek = makeWeek(startingOn: monday)
        // Built from the week before just now, so already fully synced.
        if !isFutureWeek(newWeek) { newWeek.didFinalSync = true }
        weeks.append(newWeek)
        sortWeeks()
        save()
        return newWeek
    }

    /// Builds (but doesn't store) a new week: rolled forward from the most recent
    /// prior week, or seeded from saved templates if there is none.
    private func makeWeek(startingOn monday: DayKey) -> Week {
        var newWeek = Week(startDay: monday)
        if let previousWeek = mostRecentWeekBefore(monday) {
            newWeek.categories = rollForwardCategories(from: previousWeek)
        } else {
            // First ever week: seed from saved category templates
            newWeek.categories = savedCategories.map {
                Category(name: $0.name, symbol: $0.symbol)
            }
        }
        return newWeek
    }

    /// The week `navigateToDate(_:)` would show for `date`, without creating or
    /// saving anything. Used to draw neighboring weeks while paging.
    func previewWeek(for date: Date) -> Week {
        let monday = weekStartDay(containing: date)
        if let cached = previewCache[monday] { return cached }
        var week = storedWeekIndex(startingOn: monday).map { weeks[$0] } ?? makeWeek(startingOn: monday)
        if !isPastWeek(week), let source = mostRecentWeekBefore(monday) {
            let isFuture = isFutureWeek(week)
            if isFuture { _ = Self.syncRecurringTasks(into: &week, from: source, addsCategories: true) }
            _ = Self.syncCarryOverTasks(into: &week, from: source, followsSource: isFuture)
        }
        previewCache[monday] = week
        return week
    }

    private func mostRecentWeekBefore(_ day: DayKey) -> Week? {
        weeks
            .filter { $0.startDay < day }
            .max { $0.startDay < $1.startDay }
    }

    private func rollForwardCategories(from source: Week) -> [Category] {
        source.categories.filter { !$0.isThisWeekOnly }.map { category in
            var newCategory = Category(name: category.name, symbol: category.symbol)
            // In the same order as this week. Repeating tasks always come back (reset);
            // carry-over tasks only if unfinished; one-time tasks never.
            newCategory.tasks = category.tasks.compactMap { task in
                switch task.mode {
                case .repeating: Self.resetRecurringTask(task)
                case .carryOver: task.isCompleted ? nil : Self.carriedCopy(of: task)
                case .oneTime: nil
                }
            }
            return newCategory
        }
    }

    /// Shows the week containing `date`. Only the current week is created and saved by
    /// looking at it; any other week that hasn't been saved stays a preview until edited,
    /// so it keeps following the weeks before it.
    func navigateToDate(_ date: Date) {
        guard persistenceError == nil else { return }
        selectedDate = date
        if let week = selectedWeek, isCurrentWeek(week) { ensureWeekExists(for: date) }
        syncWithPreviousWeek(for: date)
    }

    /// Brings the current or a future week up to date with the most recent week before
    /// it. Weeks are built from the week before only once, when first opened, so this
    /// picks up what changed since: unfinished carry-over tasks, and for a future week
    /// also its categories and recurring tasks.
    private func syncWithPreviousWeek(for date: Date) {
        let monday = weekStartDay(containing: date)
        guard let wi = storedWeekIndex(startingOn: monday),
              !isPastWeek(weeks[wi]),
              let sourceWeek = mostRecentWeekBefore(monday) else { return }
        var changed = false
        let isFuture = isFutureWeek(weeks[wi])
        // A saved week that has just become current gets one last full sync, so changes
        // made last week after it was saved (a task finished, a repeating task renamed)
        // still reach it. Only once: after that the week is the user's own.
        let isFinalSync = !isFuture && weeks[wi].didFinalSync != true
        let follows = isFuture || isFinalSync
        if follows {
            changed = Self.syncRecurringTasks(into: &weeks[wi], from: sourceWeek, addsCategories: isFuture)
        }
        if Self.syncCarryOverTasks(into: &weeks[wi], from: sourceWeek, followsSource: follows) { changed = true }
        if isFinalSync {
            weeks[wi].didFinalSync = true
            changed = true
        }
        if changed { save() }
    }

    /// Adds `source`'s unfinished carry-over tasks that `week` is missing, skipping ones
    /// the user deleted from `week`. With `followsSource` (a future week, or a week's
    /// final sync), copies the user hasn't touched (nothing checked) also follow their
    /// source: they pick up its new unchecked items, and go away once it's finished or
    /// no longer carries over. Returns whether anything changed.
    private static func syncCarryOverTasks(into week: inout Week, from source: Week, followsSource: Bool) -> Bool {
        var changed = false
        let dismissed = Set(week.dismissedCarryOvers ?? [])
        for sourceCategory in source.categories where !sourceCategory.isThisWeekOnly {
            guard let ci = week.categories.firstIndex(where: { $0.name == sourceCategory.name }) else { continue }
            let sources = Dictionary(sourceCategory.tasks.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

            if followsSource {
                // Copies made before copies remembered their source (same title, never
                // touched) are adopted, so they follow too instead of going stale.
                for task in sourceCategory.tasks where task.mode == .carryOver && !task.isCompleted {
                    let tasks = week.categories[ci].tasks
                    guard !tasks.contains(where: { $0.carriedFrom == task.id }),
                          let ti = tasks.firstIndex(where: {
                              $0.carriedFrom == nil && $0.title == task.title && $0.mode == .carryOver &&
                                  !$0.isCompleted && !$0.subtasks.contains(where: \.isCompleted)
                          }) else { continue }
                    week.categories[ci].tasks[ti].carriedFrom = task.id
                    changed = true
                }

                for ti in week.categories[ci].tasks.indices.reversed() {
                    let copy = week.categories[ci].tasks[ti]
                    guard let sourceID = copy.carriedFrom, copy.mode == .carryOver,
                          !copy.isCompleted, !copy.subtasks.contains(where: \.isCompleted) else { continue }
                    if let task = sources[sourceID], task.mode == .carryOver, !task.isCompleted {
                        let followed = following(task, copy: copy)
                        if followed != copy {
                            week.categories[ci].tasks[ti] = followed
                            changed = true
                        }
                    } else {
                        week.categories[ci].tasks.remove(at: ti)
                        changed = true
                    }
                }
            }

            for task in sourceCategory.tasks
            where task.mode == .carryOver && !task.isCompleted && !dismissed.contains(task.id) {
                let present = week.categories[ci].tasks.contains {
                    $0.carriedFrom == task.id || $0.title == task.title
                }
                guard !present else { continue }
                week.categories[ci].tasks.append(carriedCopy(of: task))
                changed = true
            }
            if followsSource, orderLikeSource(&week.categories[ci].tasks, source: sourceCategory.tasks) { changed = true }
        }
        return changed
    }

    /// Puts copies of `source`'s tasks in `source`'s order, so next week lists them the
    /// way this week does. Tasks added only to this week keep their places.
    /// Returns whether the order changed.
    private static func orderLikeSource(_ tasks: inout [ChecklistTask], source: [ChecklistTask]) -> Bool {
        let rank = Dictionary(source.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { first, _ in first })
        let sourceRank = { (task: ChecklistTask) in (task.repeatsFrom ?? task.carriedFrom).flatMap { rank[$0] } }
        let slots = tasks.indices.filter { sourceRank(tasks[$0]) != nil }
        let sorted = slots.map { tasks[$0] }.sorted { sourceRank($0)! < sourceRank($1)! }
        guard sorted.map(\.id) != slots.map({ tasks[$0].id }) else { return false }
        for (slot, task) in zip(slots, sorted) { tasks[slot] = task }
        return true
    }

    /// A copy of a carry-over task for the next week: its unchecked sub-tasks and its
    /// goal progress so far.
    private static func carriedCopy(of task: ChecklistTask) -> ChecklistTask {
        var newTask = ChecklistTask(title: task.title, mode: .carryOver, subtasks: task.subtasks.filter { !$0.isCompleted }.map { SubTask(title: $0.title) })
        newTask.taskType = task.taskType
        newTask.goalTarget = task.goalTarget
        newTask.goalProgress = task.goalProgress
        newTask.goalUnit = task.goalUnit
        newTask.goalUnitKind = task.goalUnitKind
        newTask.carriedFrom = task.id
        return newTask
    }

    /// An untouched future copy updated from its source: title, type and goal from the
    /// source; items checked off in the source drop out and new unchecked ones are added.
    /// Items added only to the copy stay.
    private static func following(_ task: ChecklistTask, copy: ChecklistTask) -> ChecklistTask {
        var copy = copy
        copy.title = task.title
        copy.taskType = task.taskType
        copy.goalTarget = task.goalTarget
        copy.goalProgress = task.goalProgress
        copy.goalUnit = task.goalUnit
        copy.goalUnitKind = task.goalUnitKind
        let checked = Set(task.subtasks.filter(\.isCompleted).map(\.title))
        copy.subtasks.removeAll { checked.contains($0.title) }
        let present = Set(copy.subtasks.map(\.title))
        copy.subtasks += task.subtasks
            .filter { !$0.isCompleted && !present.contains($0.title) }
            .map { SubTask(title: $0.title) }
        return copy
    }

    /// Brings `week`'s repeating tasks in line with the source week's: copies follow
    /// their source (a renamed task is renamed, not added again), untouched copies of
    /// tasks that stopped repeating or were deleted go away, and missing ones are added,
    /// skipping ones the user deleted from `week`. With `addsCategories`, missing
    /// categories are added too (not in a current week, whose deletions are the user's).
    /// Returns whether anything changed.
    private static func syncRecurringTasks(into week: inout Week, from sourceWeek: Week, addsCategories: Bool) -> Bool {
        var changed = false
        let dismissedTitles = Set(week.dismissedRepeating ?? [])
        let dismissedIDs = Set(week.dismissedCarryOvers ?? [])
        let isDismissed = { (task: ChecklistTask) in dismissedIDs.contains(task.id) || dismissedTitles.contains(task.title) }

        for sourceCategory in sourceWeek.categories where !sourceCategory.isThisWeekOnly {
            let recurringTasks = sourceCategory.tasks.filter { $0.mode == .repeating }
            guard let ci = week.categories.firstIndex(where: { $0.name == sourceCategory.name }) else {
                guard addsCategories else { continue }
                // Category missing from future week — add it (with any recurring tasks)
                var newCat = Category(name: sourceCategory.name, symbol: sourceCategory.symbol)
                newCat.tasks = recurringTasks.filter { !isDismissed($0) }.map { resetRecurringTask($0) }
                week.categories.append(newCat)
                changed = true
                continue
            }
            let sources = Dictionary(sourceCategory.tasks.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

            // Copies made before they remembered their source are adopted by title.
            for task in recurringTasks {
                let tasks = week.categories[ci].tasks
                guard !tasks.contains(where: { $0.repeatsFrom == task.id }),
                      let ti = tasks.firstIndex(where: { $0.repeatsFrom == nil && $0.carriedFrom == nil && $0.mode == .repeating && $0.title == task.title })
                else { continue }
                week.categories[ci].tasks[ti].repeatsFrom = task.id
                changed = true
            }

            for ti in week.categories[ci].tasks.indices.reversed() {
                let copy = week.categories[ci].tasks[ti]
                guard let sourceID = copy.repeatsFrom, copy.mode == .repeating else { continue }
                // Linked to the source, or to the task the source itself repeats (a week
                // in between was saved after this one).
                let source = sources[sourceID] ?? sourceCategory.tasks.first { $0.repeatsFrom == sourceID }
                if let task = source, task.mode == .repeating {
                    var followed = followingRepeating(task, copy: copy)
                    followed.repeatsFrom = task.id
                    if followed != copy {
                        week.categories[ci].tasks[ti] = followed
                        changed = true
                    }
                } else if !copy.isCompleted && (copy.goalProgress ?? 0) == 0 && !copy.subtasks.contains(where: \.isCompleted) {
                    week.categories[ci].tasks.remove(at: ti)
                    changed = true
                }
            }

            for task in recurringTasks where !isDismissed(task) {
                guard !week.categories[ci].tasks.contains(where: { $0.repeatsFrom == task.id }) else { continue }
                week.categories[ci].tasks.append(resetRecurringTask(task))
                changed = true
            }
            if orderLikeSource(&week.categories[ci].tasks, source: sourceCategory.tasks) { changed = true }
        }
        return changed
    }

    /// A later week's copy of a repeating task updated from its source: name, type and
    /// goal setup follow; the copy's own progress and checks stay. A list gains the
    /// source's new items and drops unchecked items the source no longer has.
    private static func followingRepeating(_ task: ChecklistTask, copy: ChecklistTask) -> ChecklistTask {
        var copy = copy
        copy.title = task.title
        copy.taskType = task.taskType
        copy.goalTarget = task.goalTarget
        copy.goalUnit = task.goalUnit
        copy.goalUnitKind = task.goalUnitKind
        if task.taskType != .goal { copy.goalProgress = nil }
        if task.taskType == .list {
            let sourceTitles = Set(task.subtasks.map(\.title))
            copy.subtasks.removeAll { !$0.isCompleted && !sourceTitles.contains($0.title) }
            let present = Set(copy.subtasks.map(\.title))
            copy.subtasks += task.subtasks.filter { !present.contains($0.title) }.map { SubTask(title: $0.title) }
        }
        return copy
    }

    /// Next week's copy of a repeating task: unchecked, with goal progress back to zero.
    /// A repeating list keeps its items as they were, checked ones included (like a
    /// standing shopping list), and is done only if every item is still checked.
    private static func resetRecurringTask(_ task: ChecklistTask) -> ChecklistTask {
        let keepsItems = task.taskType == .list
        let subtasks = task.subtasks.map { SubTask(title: $0.title, isCompleted: keepsItems && $0.isCompleted) }
        var newTask = ChecklistTask(title: task.title, mode: .repeating, subtasks: subtasks)
        newTask.isCompleted = keepsItems && !subtasks.isEmpty && subtasks.allSatisfy(\.isCompleted)
        newTask.taskType = task.taskType
        newTask.goalTarget = task.goalTarget
        newTask.goalProgress = 0
        newTask.goalUnit = task.goalUnit
        newTask.goalUnitKind = task.goalUnitKind
        newTask.repeatsFrom = task.id
        return newTask
    }

    func replaceCurrentWeekCategories(with categories: [Category]) {
        guard let wi = editableSelectedWeekIndex() else { return }
        weeks[wi].categories = categories
        save()
    }

    // MARK: - Category CRUD

    /// Adds a category to the selected week. Unless `thisWeekOnly`, it rolls forward
    /// into later weeks like every other category.
    func addCategory(name: String, symbol: String, thisWeekOnly: Bool = false) {
        let name = Self.cleanName(name)
        guard !name.isEmpty,
              !Self.containsName(name, in: selectedWeek?.categories.map(\.name) ?? []),
              let wi = editableSelectedWeekIndex() else { return }
        var category = Category(name: name, symbol: symbol)
        category.isThisWeekOnly = thisWeekOnly
        weeks[wi].categories.append(category)
        save()
    }

    /// Deletes the category (matched by name) from the current week and every future
    /// week, so future-week syncing can't bring it back. Past weeks keep their history.
    /// Its saved template is kept (or created) so it can be re-added from Add Category.
    func deleteCategory(_ categoryID: UUID) {
        guard let wi = editableSelectedWeekIndex(),
              let category = weeks[wi].categories.first(where: { $0.id == categoryID }) else { return }
        for wi in weeks.indices where !isPastWeek(weeks[wi]) {
            weeks[wi].categories.removeAll { $0.name == category.name }
        }
        save()
        if !category.isThisWeekOnly && !savedCategories.contains(where: { $0.name == category.name }) {
            addSavedCategory(name: category.name, symbol: category.symbol)
        }
    }

    /// Renames a category in this week and every future week, and its saved category,
    /// so they stay linked (weeks match categories by name). Past weeks keep the old
    /// name. Fails if another category in this week, or another saved category, has it.
    @discardableResult
    func renameCategory(_ categoryID: UUID, newName: String) -> Bool {
        let newName = Self.cleanName(newName)
        guard !newName.isEmpty,
              let wi = editableSelectedWeekIndex(),
              let oldName = weeks[wi].categories.first(where: { $0.id == categoryID })?.name else { return false }
        let week = weeks[wi]
        guard newName != oldName else { return true }
        let otherNames = week.categories.filter { $0.id != categoryID }.map(\.name)
            + savedCategories.filter { $0.name != oldName }.map(\.name)
        guard !Self.containsName(newName, in: otherNames) else { return false }
        updateCategories(named: oldName) { $0.name = newName }
        if let ti = savedCategories.firstIndex(where: { $0.name == oldName }) {
            savedCategories[ti].name = newName
            saveSettings()
        }
        return true
    }

    /// Changes a category's icon in this week, every future week, and its saved category.
    func setCategorySymbol(_ categoryID: UUID, symbol: String) {
        guard let wi = editableSelectedWeekIndex(),
              let name = weeks[wi].categories.first(where: { $0.id == categoryID })?.name else { return }
        updateCategories(named: name) { $0.symbol = symbol }
        if let ti = savedCategories.firstIndex(where: { $0.name == name }) {
            savedCategories[ti].symbol = symbol
            saveSettings()
        }
    }

    /// Puts categories in the order of `names` in this week and every future week.
    /// Categories not named keep their relative order, after the named ones.
    func setCategoryOrder(_ names: [String]) {
        guard editableSelectedWeekIndex() != nil else { return }
        let rank = Dictionary(names.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        var changed = false
        for wi in weeks.indices where !isPastWeek(weeks[wi]) {
            let sorted = weeks[wi].categories.enumerated()
                .sorted { (rank[$0.element.name] ?? names.count, $0.offset) < (rank[$1.element.name] ?? names.count, $1.offset) }
                .map(\.element)
            if sorted.map(\.id) != weeks[wi].categories.map(\.id) {
                weeks[wi].categories = sorted
                changed = true
            }
        }
        if changed { save() }
    }

    /// Applies `change` to the category named `name` in the current and future weeks.
    private func updateCategories(named name: String, _ change: (inout Category) -> Void) {
        for wi in weeks.indices where !isPastWeek(weeks[wi]) {
            for ci in weeks[wi].categories.indices where weeks[wi].categories[ci].name == name {
                change(&weeks[wi].categories[ci])
            }
        }
        save()
    }

    // MARK: - Task CRUD

    /// Returns the new task's ID.
    @discardableResult
    func addTask(categoryID: UUID, title: String, mode: TaskMode = .carryOver, type: TaskType = .checkbox) -> UUID? {
        guard let wi = editableSelectedWeekIndex(),
              let ci = weeks[wi].categories.firstIndex(where: { $0.id == categoryID }) else { return nil }
        let task = ChecklistTask(title: title, mode: mode, taskType: type)
        weeks[wi].categories[ci].tasks.append(task)
        save()
        return task.id
    }

    func toggleTask(categoryID: UUID, taskID: UUID) {
        guard let wi = editableSelectedWeekIndex(),
              let ci = weeks[wi].categories.firstIndex(where: { $0.id == categoryID }),
              let ti = weeks[wi].categories[ci].tasks.firstIndex(where: { $0.id == taskID }) else { return }
        weeks[wi].categories[ci].tasks[ti].isCompleted.toggle()
        save()
    }

    func deleteTask(categoryID: UUID, taskID: UUID) {
        guard let wi = editableSelectedWeekIndex(),
              let ci = weeks[wi].categories.firstIndex(where: { $0.id == categoryID }) else { return }
        if let task = weeks[wi].categories[ci].tasks.first(where: { $0.id == taskID }) {
            if let sourceID = task.carriedFrom {
                weeks[wi].dismissedCarryOvers = (weeks[wi].dismissedCarryOvers ?? []) + [sourceID]
            }
            // In a future week, a deleted repeating task must not be synced back in.
            if task.mode == .repeating && isFutureWeek(weeks[wi]) {
                weeks[wi].dismissedRepeating = (weeks[wi].dismissedRepeating ?? []) + [task.title]
                if let sourceID = task.repeatsFrom {
                    weeks[wi].dismissedCarryOvers = (weeks[wi].dismissedCarryOvers ?? []) + [sourceID]
                }
            }
        }
        weeks[wi].categories[ci].tasks.removeAll { $0.id == taskID }
        save()
    }

    func updateTaskMode(categoryID: UUID, taskID: UUID, mode: TaskMode) {
        guard let wi = editableSelectedWeekIndex(),
              let ci = weeks[wi].categories.firstIndex(where: { $0.id == categoryID }),
              let ti = weeks[wi].categories[ci].tasks.firstIndex(where: { $0.id == taskID }) else { return }
        weeks[wi].categories[ci].tasks[ti].mode = mode
        save()
    }

    func renameTask(categoryID: UUID, taskID: UUID, newTitle: String) {
        guard let wi = editableSelectedWeekIndex(),
              let ci = weeks[wi].categories.firstIndex(where: { $0.id == categoryID }),
              let ti = weeks[wi].categories[ci].tasks.firstIndex(where: { $0.id == taskID }) else { return }
        weeks[wi].categories[ci].tasks[ti].title = newTitle
        save()
    }

    // MARK: - Goal Task CRUD

    func updateTaskType(categoryID: UUID, taskID: UUID, type: TaskType) {
        guard let wi = editableSelectedWeekIndex(),
              let ci = weeks[wi].categories.firstIndex(where: { $0.id == categoryID }),
              let ti = weeks[wi].categories[ci].tasks.firstIndex(where: { $0.id == taskID }) else { return }
        weeks[wi].categories[ci].tasks[ti].taskType = type
        if type != .goal {
            weeks[wi].categories[ci].tasks[ti].goalTarget = nil
            weeks[wi].categories[ci].tasks[ti].goalProgress = nil
            weeks[wi].categories[ci].tasks[ti].goalUnit = nil
            weeks[wi].categories[ci].tasks[ti].goalUnitKind = nil
        }
        save()
    }

    /// Sets a goal's target and unit. Time targets are in minutes. `unit` names a
    /// custom unit; without a `kind`, a non-empty unit means a custom goal.
    func setGoalTarget(categoryID: UUID, taskID: UUID, target: Double, kind: GoalUnitKind? = nil, unit: String = "") {
        guard target.isFinite, target > 0 else { return }
        let target = min(target, GoalUnitKind.maxValue)
        let unit = unit.trimmingCharacters(in: .whitespaces)
        let kind = kind ?? (unit.isEmpty ? .quantity : .custom)
        guard let wi = editableSelectedWeekIndex(),
              let ci = weeks[wi].categories.firstIndex(where: { $0.id == categoryID }),
              let ti = weeks[wi].categories[ci].tasks.firstIndex(where: { $0.id == taskID }) else { return }
        weeks[wi].categories[ci].tasks[ti].goalTarget = target
        weeks[wi].categories[ci].tasks[ti].goalUnitKind = kind
        weeks[wi].categories[ci].tasks[ti].goalUnit = kind == .custom ? unit : nil
        // Auto-update completion
        let progress = weeks[wi].categories[ci].tasks[ti].goalProgress ?? 0
        weeks[wi].categories[ci].tasks[ti].isCompleted = progress >= target
        save()
    }

    func updateGoalProgress(categoryID: UUID, taskID: UUID, progress: Double) {
        guard progress.isFinite, progress >= 0 else { return }
        let progress = min(progress, GoalUnitKind.maxValue)
        guard let wi = editableSelectedWeekIndex(),
              let ci = weeks[wi].categories.firstIndex(where: { $0.id == categoryID }),
              let ti = weeks[wi].categories[ci].tasks.firstIndex(where: { $0.id == taskID }) else { return }
        weeks[wi].categories[ci].tasks[ti].goalProgress = progress
        let target = weeks[wi].categories[ci].tasks[ti].goalTarget ?? 0
        weeks[wi].categories[ci].tasks[ti].isCompleted = target > 0 && progress >= target
        save()
    }

    // MARK: - Sub-Task CRUD

    func addSubtask(categoryID: UUID, taskID: UUID, title: String) {
        guard let wi = editableSelectedWeekIndex(),
              let ci = weeks[wi].categories.firstIndex(where: { $0.id == categoryID }),
              let ti = weeks[wi].categories[ci].tasks.firstIndex(where: { $0.id == taskID }) else { return }
        weeks[wi].categories[ci].tasks[ti].subtasks.append(SubTask(title: title))
        // A new unchecked item means the task isn't done yet.
        weeks[wi].categories[ci].tasks[ti].isCompleted = false
        save()
    }

    func toggleSubtask(categoryID: UUID, taskID: UUID, subtaskID: UUID) {
        guard let wi = editableSelectedWeekIndex(),
              let ci = weeks[wi].categories.firstIndex(where: { $0.id == categoryID }),
              let ti = weeks[wi].categories[ci].tasks.firstIndex(where: { $0.id == taskID }),
              let si = weeks[wi].categories[ci].tasks[ti].subtasks.firstIndex(where: { $0.id == subtaskID }) else { return }
        weeks[wi].categories[ci].tasks[ti].subtasks[si].isCompleted.toggle()
        // Auto-complete/uncomplete parent based on subtask state
        let task = weeks[wi].categories[ci].tasks[ti]
        if !task.subtasks.isEmpty {
            weeks[wi].categories[ci].tasks[ti].isCompleted = task.subtasks.allSatisfy(\.isCompleted)
        }
        save()
    }

    func deleteSubtask(categoryID: UUID, taskID: UUID, subtaskID: UUID) {
        guard let wi = editableSelectedWeekIndex(),
              let ci = weeks[wi].categories.firstIndex(where: { $0.id == categoryID }),
              let ti = weeks[wi].categories[ci].tasks.firstIndex(where: { $0.id == taskID }) else { return }
        weeks[wi].categories[ci].tasks[ti].subtasks.removeAll { $0.id == subtaskID }
        // Deleting the last unchecked item completes the task, as checking it would.
        let task = weeks[wi].categories[ci].tasks[ti]
        if !task.subtasks.isEmpty {
            weeks[wi].categories[ci].tasks[ti].isCompleted = task.subtasks.allSatisfy(\.isCompleted)
        }
        save()
    }

    func renameSubtask(categoryID: UUID, taskID: UUID, subtaskID: UUID, newTitle: String) {
        guard let wi = editableSelectedWeekIndex(),
              let ci = weeks[wi].categories.firstIndex(where: { $0.id == categoryID }),
              let ti = weeks[wi].categories[ci].tasks.firstIndex(where: { $0.id == taskID }),
              let si = weeks[wi].categories[ci].tasks[ti].subtasks.firstIndex(where: { $0.id == subtaskID }) else { return }
        weeks[wi].categories[ci].tasks[ti].subtasks[si].title = newTitle
        save()
    }

    // MARK: - Helpers

    private func sortWeeks() {
        weeks.sort { $0.startDay > $1.startDay }
    }
}
