import Foundation
import Observation
import OSLog
import SwiftUI

@Observable
final class ChecklistStore {

    var weeks: [Week] = [] { didSet { previewCache.removeAll() } }
    var selectedDate: Date
    /// Starter categories already added to Saved Categories, so removed ones stay removed.
    private var offeredStarterNames: [String]?
    /// Saved categories the user removed. Deleting a card with one of these names doesn't
    /// save it again (otherwise deleting a card keeps its template for re-adding).
    private var removedSavedCategoryNames: [String] = []
    /// Whether settings.json existed at the last load; without it, the week start is
    /// worked out from the saved weeks.
    @ObservationIgnored private var didFindSettingsFile = false
    /// Sub-task checks from before a task was checked (which checks them all), so
    /// unchecking it right away puts them back instead of clearing them. Not saved.
    @ObservationIgnored private var subtaskChecksBeforeCheck: [UUID: [UUID: Bool]] = [:]
    /// A list or goal just created from the add-task row, whose first field (a list's item,
    /// a goal's target) should take the keyboard when it appears. Not saved.
    var taskAwaitingFirstInput: UUID?
    /// A task Smart Add just added, its row lit for a moment so it's seen (not with Reduce
    /// Motion). Not saved.
    var highlightedTaskID: UUID?
    /// How category cards are ordered (Settings ▸ Categories).
    var categorySort: CategorySortOrder = .manual
    /// When each category (by name) last had a task added, changed or removed, for the
    /// recently-edited sort. Kept on the device (UserDefaults), not in the task data.
    private(set) var categoryEditTimes: [String: Date] = [:]

    /// The last delete, offered as "Deleted … · Undo" for a few seconds. Not saved.
    struct UndoableDelete: Equatable {
        let description: String
        /// The week it was deleted from, so Undo can show it coming back there.
        var week: DayKey? = nil
        let token = UUID()
    }
    private(set) var lastDelete: UndoableDelete?
    /// Everything as it was just before `lastDelete`, which Undo puts back.
    @ObservationIgnored private var weeksBeforeDelete: [Week]?
    @ObservationIgnored private var savedCategoriesBeforeDelete: [CategoryTemplate]?
    /// Set while a delete saves, so that save doesn't end the chance to undo it.
    @ObservationIgnored private var isSavingDelete = false
    /// Counts taps on the keyboard's Done button. Rows with something typed but not yet
    /// added (a task, a goal amount) watch it and save what's typed. Not saved.
    var keyboardDoneRequests = 0
    var savedCategories: [CategoryTemplate] = [] { didSet { previewCache.removeAll() } }
    /// Previewed weeks, so repeated previews (every render while paging) return identical
    /// values instead of new IDs. Cleared whenever the data they're built from changes.
    @ObservationIgnored private var previewCache: [DayKey: Week] = [:]
    /// The last preview built for each week (kept when the cache is cleared), whose IDs a
    /// rebuilt preview takes over so its cards and rows keep their identity.
    @ObservationIgnored private var lastPreviews: [DayKey: Week] = [:]
    /// A preview added to `weeks` for an edit that was then refused (a duplicate name,
    /// say), so nothing was saved. Dropped when the user moves to another week.
    @ObservationIgnored private var unsavedPreviewID: UUID?
    private static let log = Logger(subsystem: "com.symonym.Tasquel", category: "Persistence")
    var appearanceMode: AppearanceMode = .system
    var retroColor: RetroColor = .green
    var hasSeenWelcome: Bool = false
    /// Calendar integration: show events in the bottom bar, and which calendars to include
    /// (nil until the first time it's turned on, when a default selection is made).
    var calendarEventsEnabled = false
    /// Weeks start on Monday unless the user chooses Sunday.
    var weekStartsOnSunday = false
    var selectedCalendarIDs: [String]?
    private(set) var weekLoadError: String?
    private(set) var settingsLoadError: String?

    var persistenceError: String? { weekLoadError ?? settingsLoadError }
    /// Set when saving starts failing (the device is full, say), so the user is told once.
    /// The next successful save, which writes everything, clears it.
    private(set) var saveError: String?
    /// Whether saves are failing, for a lasting notice after the alert is dismissed.
    private(set) var isSaveFailing = false

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
        if let stored = defaults.dictionary(forKey: Self.editTimesKey) as? [String: Double] {
            categoryEditTimes = stored.mapValues { Date(timeIntervalSince1970: $0) }
        }
        loadAndPrepare()
    }

    /// The app's store, or one backed by throwaway storage when UI tests pass
    /// `-isolatedData`, so they never touch the simulator's real data.
    /// `-isolatedDataID <name>` reuses the same throwaway storage across launches.
    /// `-demoData` also uses throwaway storage, filled with sample tasks.
    /// Debug builds only.
    static func makeDefault() -> ChecklistStore {
        #if !DEBUG
        return ChecklistStore()
        #else
        let arguments = ProcessInfo.processInfo.arguments
        let reusableID = arguments.firstIndex(of: "-isolatedDataID").flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil }
        let demo = launchesWithDemoData
        guard arguments.contains("-isolatedData") || reusableID != nil || demo else { return ChecklistStore() }
        let directory = FileManager.default.temporaryDirectory.appending(path: "isolated-\(reusableID ?? UUID().uuidString)")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = ChecklistStore(directory: directory, defaults: UserDefaults(suiteName: directory.lastPathComponent) ?? .standard)
        // App Store screenshots: sample tasks, no onboarding (DemoData.swift).
        if demo { store.fillWithDemoData() }
        return store
        #endif
    }

    /// Init order matters: settings → seed starter templates → weeks → current week.
    /// Stops at the first unreadable file so defaults never overwrite it.
    private func loadAndPrepare() {
        loadSettings()
        guard settingsLoadError == nil else { return }
        seedStarterTemplates()
        load()
        guard weekLoadError == nil else { return }
        inferWeekStartIfSettingsMissing()
        saveThisWeekOnlyCategories()
        pruneEditTimes()
        let currentWeek = ensureWeekExists(for: now())
        migrateStartersIfNeeded(into: currentWeek)
        syncWithPreviousWeek(for: now())
    }

    /// Without settings.json (Start Fresh after it couldn't be read, say), the week start
    /// would default to Monday while saved weeks may start on Sunday, hiding them all and
    /// building a new current week. The most recent saved week's weekday says which.
    private func inferWeekStartIfSettingsMissing() {
        guard !didFindSettingsFile, let latest = weeks.first else { return }
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        let sunday = gregorian.component(.weekday, from: latest.startDay.date(in: calendar)) == 1
        guard sunday != weekStartsOnSunday else { return }
        weekStartsOnSunday = sunday
        saveSettings()
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
            var needsSave = !weeks.isEmpty && data.range(of: Data("\"startDay\"".utf8)) == nil
            // Weeks saved before the final-sync flag: only future ones still need their
            // final sync. Current and past weeks are the user's as they are.
            for wi in weeks.indices where weeks[wi].didFinalSync == nil {
                weeks[wi].didFinalSync = !isFutureWeek(weeks[wi])
                needsSave = true
            }
            // Weeks saved before they had a start day just got one, worked out in this
            // time zone. Saving now means a later time-zone change can't shift them.
            if needsSave { save() }
        } catch {
            weekLoadError = "Your saved weeks could not be opened. The file has not been changed."
            Self.log.error("Failed to load weeks: \(error)")
        }
    }

    func retryLoadingData() {
        loadAndPrepare()
    }

    /// Starts over when a data file can't be read: the unreadable file is renamed (kept
    /// beside the others, never deleted) and the app continues without it.
    func setAsideUnreadableData() {
        let stamp = Int(now().timeIntervalSince1970)
        for (error, url) in [(weekLoadError, fileURL), (settingsLoadError, settingsURL)] where error != nil {
            let name = url.deletingPathExtension().lastPathComponent
            let kept = url.deletingLastPathComponent().appending(path: "\(name)-unreadable-\(stamp).json")
            try? FileManager.default.moveItem(at: url, to: kept)
        }
        loadAndPrepare()
    }

    func dismissSaveError() {
        saveError = nil
    }

    private enum DataFile { case weeks, settings }

    /// Files whose last save failed. The warning clears only when both have saved, so a
    /// small settings save succeeding can't hide that tasks weren't saved.
    @ObservationIgnored private var failedSaves: Set<DataFile> = []

    private func reportSave(_ error: Error?, for file: DataFile) {
        if let error {
            Self.log.error("Failed to save \(file == .weeks ? "weeks" : "settings"): \(error)")
            // Only the first failure alerts; later ones (every tap, while the device is
            // full) leave the lasting notice to say it.
            if failedSaves.isEmpty {
                saveError = "Your latest changes couldn't be saved. If your device is low on storage, free up some space; everything is saved again with your next change."
            }
            failedSaves.insert(file)
            isSaveFailing = true
            return
        }
        guard failedSaves.remove(file) != nil || !failedSaves.isEmpty else { return }
        // This file saved, so there may be room again: retry the other one.
        if failedSaves.contains(.weeks) { save() } else if failedSaves.contains(.settings) { saveSettings() }
        if failedSaves.isEmpty {
            saveError = nil
            isSaveFailing = false
        }
    }

    func save() {
        guard persistenceError == nil else { return }
        // Any other change ends the chance to undo the last delete: putting the old
        // weeks back would undo that change too.
        if !isSavingDelete { clearUndo() }
        unsavedPreviewID = nil
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(weeks)
            try data.write(to: fileURL, options: .atomic)
            reportSave(nil, for: .weeks)
        } catch {
            reportSave(error, for: .weeks)
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
        var removedSavedCategoryNames: [String]?
        /// A raw string, so a value from a newer version reads as Manual instead of
        /// making the whole settings file unreadable.
        var categorySort: String?
    }

    func loadSettings() {
        didFindSettingsFile = FileManager.default.fileExists(atPath: settingsURL.path())
        guard didFindSettingsFile else {
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
            removedSavedCategoryNames = settings.removedSavedCategoryNames ?? []
            categorySort = settings.categorySort.flatMap(CategorySortOrder.init(rawValue:)) ?? .manual
            settingsLoadError = nil
        } catch {
            settingsLoadError = "Your settings could not be opened. The file has not been changed."
            Self.log.error("Failed to load settings: \(error)")
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
                offeredStarterNames: offeredStarterNames,
                removedSavedCategoryNames: removedSavedCategoryNames,
                categorySort: categorySort.rawValue
            )
            let data = try JSONEncoder().encode(settings)
            try data.write(to: settingsURL, options: .atomic)
            reportSave(nil, for: .settings)
        } catch {
            reportSave(error, for: .settings)
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
        if let wi = weeks.firstIndex(where: { $0.id == week.id }) {
            // A saved week that became current while it was on screen (the app stayed
            // open into a new week) gets its final sync before the user's first edit,
            // so the sync can't undo that edit later.
            if weeks[wi].didFinalSync == false && !isFutureWeek(weeks[wi]) { syncWithPreviousWeek(for: selectedDate) }
            return wi
        }
        var saved = week
        saved.didFinalSync = !isFutureWeek(week)
        weeks.append(saved)
        unsavedPreviewID = saved.id
        sortWeeks()
        return weeks.firstIndex { $0.id == week.id }
    }

    /// Changes the week start day. Every saved week moves by the same number of days, so
    /// its tasks stay with it, the selected week stays selected, and the week containing
    /// today stays the current week: usually one day (Monday ↔ the Sunday before it), but
    /// six on a Sunday, which ends a Monday week and starts a Sunday one.
    func setWeekStartsOnSunday(_ sunday: Bool) {
        guard sunday != weekStartsOnSunday, persistenceError == nil else { return }
        let oldStart = startOfWeek(containing: now())
        let newStart = Week.startOfWeek(containing: now(), firstWeekday: sunday ? Week.sunday : Week.monday,
                                        calendar: calendar)
        let shift = Calendar.weekDates(in: calendar.timeZone)
            .dateComponents([.day], from: oldStart, to: newStart).day ?? (sunday ? -1 : 1)
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
        // A saved future week may have just become current.
        syncWithPreviousWeek(for: now())
    }

    func setCalendarEventsEnabled(_ enabled: Bool) {
        calendarEventsEnabled = enabled
        saveSettings()
    }

    func setSelectedCalendarIDs(_ ids: [String]) {
        selectedCalendarIDs = ids
        saveSettings()
    }

    // MARK: - Saved Category Templates

    func addSavedCategory(name: String, symbol: String) {
        let name = Self.cleanName(name)
        guard !name.isEmpty, !Self.containsName(name, in: savedCategories.map(\.name)) else { return }
        clearUndo()  // Undo puts saved categories back too; it mustn't undo this
        appendSavedCategory(name: name, symbol: symbol)
    }

    /// Adds a saved category whose name is clean and free, without ending a delete's Undo:
    /// a deleted category keeps its template this way, and undoing the delete takes the
    /// template back out with everything else.
    private func appendSavedCategory(name: String, symbol: String) {
        savedCategories.append(CategoryTemplate(name: name, symbol: symbol))
        removedSavedCategoryNames.removeAll { Self.cleanName($0).caseInsensitiveCompare(name) == .orderedSame }
        saveSettings()
    }

    func removeSavedCategory(_ templateID: UUID) {
        clearUndo()
        if let name = savedCategories.first(where: { $0.id == templateID })?.name,
           !Self.containsName(name, in: removedSavedCategoryNames) {
            removedSavedCategoryNames.append(name)
        }
        savedCategories.removeAll { $0.id == templateID }
        saveSettings()
    }

    /// Renames a saved category and changes its icon, and its category in this week and
    /// every future week, so they stay linked like renaming a card does. Past weeks keep
    /// the old name. Fails if another saved category, or another category in those weeks,
    /// has the name.
    @discardableResult
    func updateSavedCategory(_ templateID: UUID, name: String, symbol: String) -> Bool {
        let name = Self.cleanName(name)
        guard !name.isEmpty,
              let index = savedCategories.firstIndex(where: { $0.id == templateID }),
              !isSavedCategoryNameTaken(name, excluding: templateID) else { return false }
        let old = savedCategories[index]
        clearUndo()
        savedCategories[index].name = name
        savedCategories[index].symbol = symbol
        saveSettings()
        if old.name != name || old.symbol != symbol,
           weeks.contains(where: { !isPastWeek($0) && $0.categories.contains { $0.name == old.name } }) {
            updateCategories(named: old.name) {
                $0.name = name
                $0.symbol = symbol
            }
        }
        renameDismissedCategory(old.name, to: name)
        moveEditTime(from: old.name, to: name)
        return true
    }

    func moveSavedCategories(fromOffsets source: IndexSet, toOffset destination: Int) {
        clearUndo()
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

    /// Whether a saved category other than `templateID` has `name`. Renaming one also
    /// renames its category in this and future weeks, so their other categories count too.
    func isSavedCategoryNameTaken(_ name: String, excluding templateID: UUID?) -> Bool {
        var names = savedCategories.filter { $0.id != templateID }.map(\.name)
        if let oldName = savedCategories.first(where: { $0.id == templateID })?.name {
            for week in weeks where !isPastWeek(week) && week.categories.contains(where: { $0.name == oldName }) {
                names += week.categories.map(\.name).filter { $0 != oldName }
            }
        }
        return Self.containsName(name, in: names)
    }

    // MARK: - Week Management

    @discardableResult
    func ensureWeekExists(for date: Date) -> Week {
        finishSkippedWeeks()
        let monday = weekStartDay(containing: date)
        if let wi = storedWeekIndex(startingOn: monday) {
            return weeks[wi]
        }

        var newWeek = makeWeek(startingOn: monday)
        // A week built as the current week is already in sync; a future one isn't yet.
        newWeek.didFinalSync = !isFutureWeek(newWeek)
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
        let stored = storedWeekIndex(startingOn: monday).map { weeks[$0] }
        var week = stored ?? makeWeek(startingOn: monday)
        if !isPastWeek(week), let source = mostRecentWeekBefore(monday) {
            let isFuture = isFutureWeek(week) && week.didFinalSync != true
            if isFuture { _ = Self.syncRecurringTasks(into: &week, from: source, addsCategories: true) }
            _ = Self.syncCarryOverTasks(into: &week, from: source, followsSource: isFuture)
        }
        if stored == nil, let last = lastPreviews[monday] { Self.reuseIDs(of: last, in: &week) }
        previewCache[monday] = week
        lastPreviews[monday] = week
        return week
    }

    /// Gives a rebuilt preview the IDs of the previous preview of the same week: the week,
    /// its categories (by name), tasks (by the task they copy) and items (by title).
    private static func reuseIDs(of last: Week, in week: inout Week) {
        week.id = last.id
        for ci in week.categories.indices {
            guard let lastCategory = last.categories.first(where: { $0.name == week.categories[ci].name }) else { continue }
            week.categories[ci].id = lastCategory.id
            var usedTasks = Set<UUID>()
            for ti in week.categories[ci].tasks.indices {
                let task = week.categories[ci].tasks[ti]
                guard let source = task.carriedFrom ?? task.repeatsFrom,
                      let lastTask = lastCategory.tasks.first(where: {
                          ($0.carriedFrom ?? $0.repeatsFrom) == source && !usedTasks.contains($0.id)
                      }) else { continue }
                usedTasks.insert(lastTask.id)
                week.categories[ci].tasks[ti].id = lastTask.id
                var usedItems = Set<UUID>()
                for si in task.subtasks.indices {
                    guard let lastItem = lastTask.subtasks.first(where: {
                        $0.title == task.subtasks[si].title && !usedItems.contains($0.id)
                    }) else { continue }
                    usedItems.insert(lastItem.id)
                    week.categories[ci].tasks[ti].subtasks[si].id = lastItem.id
                }
            }
        }
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
        if let id = unsavedPreviewID {
            weeks.removeAll { $0.id == id }
            unsavedPreviewID = nil
        }
        selectedDate = date
        if let week = selectedWeek, isCurrentWeek(week) { ensureWeekExists(for: date) }
        syncWithPreviousWeek(for: date)
    }

    /// Brings the current or a future week up to date with the most recent week before
    /// it. Weeks are built from the week before only once, when first opened, so this
    /// picks up what changed since: unfinished carry-over tasks, and for a future week
    /// also its categories and recurring tasks.
    private func syncWithPreviousWeek(for date: Date) {
        finishSkippedWeeks()
        let monday = weekStartDay(containing: date)
        guard let wi = storedWeekIndex(startingOn: monday),
              !isPastWeek(weeks[wi]),
              let sourceWeek = mostRecentWeekBefore(monday) else { return }
        var changed = false
        // A week that has had its final sync (it was current, then the week start day
        // changed and moved it into the future) is the user's own, like a current week.
        let isFuture = isFutureWeek(weeks[wi]) && weeks[wi].didFinalSync != true
        // A saved week that has just become current gets one last full sync, so changes
        // made last week after it was saved (a task finished, a repeating task renamed)
        // still reach it. Only once: after that the week is the user's own.
        let isFinalSync = !isFuture && weeks[wi].didFinalSync == false
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

    /// A saved future week the app was never opened in while it was current never got
    /// its final sync, so it still shows the week before as it was when it was saved
    /// (a task since finished, a repeating task since renamed). Gives each such week,
    /// oldest first, the final sync it missed, so weeks built or synced from it don't
    /// bring those back.
    private func finishSkippedWeeks() {
        let skipped = weeks.indices
            .filter { weeks[$0].didFinalSync == false && isPastWeek(weeks[$0]) }
            .sorted { weeks[$0].startDay < weeks[$1].startDay }
        guard !skipped.isEmpty else { return }
        for wi in skipped {
            if let source = mostRecentWeekBefore(weeks[wi].startDay) {
                _ = Self.syncRecurringTasks(into: &weeks[wi], from: source, addsCategories: false)
                _ = Self.syncCarryOverTasks(into: &weeks[wi], from: source, followsSource: true)
            }
            weeks[wi].didFinalSync = true
        }
        save()
    }

    /// Adds `source`'s unfinished carry-over tasks that `week` is missing, skipping ones
    /// the user deleted from `week`. With `followsSource` (a future week, or a week's
    /// final sync), copies the user hasn't touched (nothing checked) also follow their
    /// source: they pick up its new unchecked items, and go away once it's finished or
    /// no longer carries over. Copies the user changed in `week` are left alone.
    /// Returns whether anything changed.
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
                              $0.carriedFrom == nil && !$0.isUserEdited && $0.title == task.title && $0.mode == .carryOver &&
                                  !$0.isCompleted && !$0.subtasks.contains(where: \.isCompleted)
                          }) else { continue }
                    week.categories[ci].tasks[ti].carriedFrom = task.id
                    changed = true
                }

                for ti in week.categories[ci].tasks.indices.reversed() {
                    let copy = week.categories[ci].tasks[ti]
                    guard let sourceID = copy.carriedFrom, copy.mode == .carryOver, !copy.isUserEdited,
                          !copy.isCompleted, !copy.subtasks.contains(where: \.isCompleted) else { continue }
                    // Linked to the source, or to the copy the source week has of it (a
                    // week in between was saved after this one).
                    let source = sources[sourceID] ?? sourceCategory.tasks.first { $0.carriedFrom == sourceID }
                    if let task = source, task.mode == .carryOver, !task.isCompleted {
                        var followed = following(task, copy: copy)
                        followed.carriedFrom = task.id
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
            where task.mode == .carryOver && !task.isCompleted && !dismissed.contains(task.id)
                && task.carriedFrom.map(dismissed.contains) != true {
                // Also present when this week's copy links to what the source itself was
                // carried from (it was made before the week in between existed).
                let present = week.categories[ci].tasks.contains {
                    $0.carriedFrom == task.id || $0.title == task.title
                        || (task.carriedFrom != nil && $0.carriedFrom == task.carriedFrom)
                }
                guard !present else { continue }
                week.categories[ci].tasks.append(carriedCopy(of: task))
                changed = true
            }
            if followsSource, !(week.userOrderedCategories ?? []).contains(sourceCategory.name),
               orderLikeSource(&week.categories[ci].tasks, source: sourceCategory.tasks) { changed = true }
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
        newTask.goalStep = task.goalStep
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
        copy.goalStep = task.goalStep
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
        // A source the user deleted a copy of, or a task repeating that source (a week in
        // between was saved later). Titles only come from copies that never knew their source.
        let isDismissed = { (task: ChecklistTask) in
            dismissedIDs.contains(task.id) || task.repeatsFrom.map(dismissedIDs.contains) == true
                || dismissedTitles.contains(task.title)
        }
        let dismissedCategories = Set(week.dismissedCategories ?? [])

        for sourceCategory in sourceWeek.categories where !sourceCategory.isThisWeekOnly {
            let recurringTasks = sourceCategory.tasks.filter { $0.mode == .repeating }
            guard let ci = week.categories.firstIndex(where: { $0.name == sourceCategory.name }) else {
                guard addsCategories, !dismissedCategories.contains(sourceCategory.name) else { continue }
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
                      let ti = tasks.firstIndex(where: { $0.repeatsFrom == nil && $0.carriedFrom == nil && !$0.isUserEdited && $0.mode == .repeating && $0.title == task.title })
                else { continue }
                week.categories[ci].tasks[ti].repeatsFrom = task.id
                changed = true
            }

            for ti in week.categories[ci].tasks.indices.reversed() {
                let copy = week.categories[ci].tasks[ti]
                // A copy the user changed in this week is theirs: it neither follows nor goes away.
                guard let sourceID = copy.repeatsFrom, copy.mode == .repeating, !copy.isUserEdited else { continue }
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
                // A copy the user edited keeps its old link: it still counts as this task's copy.
                guard !week.categories[ci].tasks.contains(where: {
                    $0.repeatsFrom == task.id || (task.repeatsFrom != nil && $0.repeatsFrom == task.repeatsFrom)
                }) else { continue }
                week.categories[ci].tasks.append(resetRecurringTask(task))
                changed = true
            }
            if !(week.userOrderedCategories ?? []).contains(sourceCategory.name),
               orderLikeSource(&week.categories[ci].tasks, source: sourceCategory.tasks) { changed = true }
        }
        return changed
    }

    /// A later week's copy of a repeating task updated from its source: name, type and
    /// goal setup follow; the copy's own progress and checks stay. A list gains the
    /// source's new items and drops unchecked items the source no longer has.
    private static func followingRepeating(_ task: ChecklistTask, copy original: ChecklistTask) -> ChecklistTask {
        var copy = original
        copy.title = task.title
        copy.taskType = task.taskType
        copy.goalTarget = task.goalTarget
        copy.goalUnit = task.goalUnit
        copy.goalUnitKind = task.goalUnitKind
        copy.goalStep = task.goalStep
        if task.taskType != .goal { copy.goalProgress = nil }
        if task.taskType == .list {
            let sourceTitles = Set(task.subtasks.map(\.title))
            copy.subtasks.removeAll { !$0.isCompleted && !sourceTitles.contains($0.title) }
            let present = Set(copy.subtasks.map(\.title))
            copy.subtasks += task.subtasks.filter { !present.contains($0.title) }.map { SubTask(title: $0.title) }
            if copy.subtasks != original.subtasks, !copy.subtasks.isEmpty {
                copy.isCompleted = copy.subtasks.allSatisfy(\.isCompleted)
            }
        }
        // A changed target re-decides whether the goal is met.
        if task.taskType == .goal, copy.goalTarget != original.goalTarget {
            copy.isCompleted = copy.goalIsComplete
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
        newTask.goalStep = task.goalStep
        newTask.repeatsFrom = task.id
        return newTask
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
        weeks[wi].dismissedCategories?.removeAll { $0 == name }
        noteEdit(named: name)
        save()
    }

    /// Deletes the category (matched by name) from the viewed week and every later week,
    /// so future-week syncing can't bring it back. Earlier weeks keep it. A "this week
    /// only" category is deleted from the viewed week alone. Its saved template is kept
    /// (or created) so it can be re-added from Add Category.
    func deleteCategory(_ categoryID: UUID) {
        guard let wi = editableSelectedWeekIndex(),
              let category = weeks[wi].categories.first(where: { $0.id == categoryID }) else { return }
        rememberForUndo("“\(category.name)”")
        let fromDay = weeks[wi].startDay
        if category.isThisWeekOnly {
            weeks[wi].categories.removeAll { $0.id == categoryID }
        } else {
            for index in weeks.indices where weeks[index].startDay >= fromDay {
                // Its carried and repeating copies stay deleted too, so adding the category
                // back later starts it empty, as the delete message says.
                for task in weeks[index].categories.filter({ $0.name == category.name }).flatMap(\.tasks) {
                    for link in [task.carriedFrom, task.repeatsFrom].compactMap({ $0 }) {
                        weeks[index].dismissCarryOver(link)
                    }
                }
                weeks[index].categories.removeAll { $0.name == category.name }
            }
            // The week before may still have it; a future week's sync would add it back.
            if isFutureWeek(weeks[wi]), !(weeks[wi].dismissedCategories ?? []).contains(category.name) {
                weeks[wi].dismissedCategories = (weeks[wi].dismissedCategories ?? []) + [category.name]
            }
        }
        saveDelete()
        keepSavedCategory(for: category)
    }

    /// Makes sure `category` has a saved category, unless the user removed that saved
    /// category (deleting or keeping the card mustn't bring it back).
    private func keepSavedCategory(for category: Category) {
        let name = Self.cleanName(category.name)
        if !name.isEmpty && !Self.containsName(name, in: savedCategories.map(\.name))
            && !Self.containsName(name, in: removedSavedCategoryNames) {
            appendSavedCategory(name: name, symbol: category.symbol)
        }
    }

    /// Turns "This week only" on or off for a category in the viewed week (its card's
    /// edit mode). On: its carry-over and repeating tasks become one-time, since nothing
    /// in it comes back, and later weeks lose it, keeping only tasks the user added or
    /// changed there. Off: it comes back in later weeks like any category.
    func setCategoryThisWeekOnly(_ categoryID: UUID, _ thisWeekOnly: Bool) {
        guard let wi = editableSelectedWeekIndex(),
              let ci = weeks[wi].categories.firstIndex(where: { $0.id == categoryID }),
              weeks[wi].categories[ci].isThisWeekOnly != thisWeekOnly else { return }
        let category = weeks[wi].categories[ci]
        weeks[wi].categories[ci].isThisWeekOnly = thisWeekOnly
        if thisWeekOnly {
            for ti in category.tasks.indices where category.tasks[ti].mode != .oneTime {
                weeks[wi].categories[ci].tasks[ti].mode = .oneTime
                weeks[wi].categories[ci].tasks[ti].isUserEdited = true
            }
            // Later weeks lose the copies of its tasks the user hasn't touched there, and the
            // category itself once nothing of theirs is left in it.
            let fromDay = weeks[wi].startDay
            for index in weeks.indices where weeks[index].startDay > fromDay {
                guard let li = weeks[index].categories.firstIndex(where: { $0.name == category.name }) else { continue }
                weeks[index].categories[li].tasks.removeAll {
                    !$0.isUserEdited && !$0.isCompleted && !$0.subtasks.contains(where: \.isCompleted)
                }
                if weeks[index].categories[li].tasks.isEmpty { weeks[index].categories.remove(at: li) }
            }
        }
        noteEdit(categoryID)
        save()
        if !thisWeekOnly { keepSavedCategory(for: category) }
    }

    /// A carry-over or repeating task comes back next week, so its category has to as
    /// well: adding one to a "This week only" category (or changing a task to one) turns
    /// that off.
    private func keepCategory(_ wi: Int, _ ci: Int, for mode: TaskMode) {
        guard mode != .oneTime, weeks[wi].categories[ci].isThisWeekOnly else { return }
        weeks[wi].categories[ci].isThisWeekOnly = false
        keepSavedCategory(for: weeks[wi].categories[ci])
    }

    /// Categories added for this week only before they were kept in Saved Categories
    /// get a saved category too (unless the user removed one with that name).
    private func saveThisWeekOnlyCategories() {
        for week in weeks where !isPastWeek(week) {
            for category in week.categories where category.isThisWeekOnly { keepSavedCategory(for: category) }
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
        // The rename reaches every later week with this category, so their other
        // categories count too (a this-week-only "Trip" there, say).
        var otherNames = week.categories.filter { $0.id != categoryID }.map(\.name)
            + savedCategories.filter { $0.name != oldName }.map(\.name)
        for other in weeks where !isPastWeek(other) && other.categories.contains(where: { $0.name == oldName }) {
            otherNames += other.categories.map(\.name).filter { $0 != oldName }
        }
        guard !Self.containsName(newName, in: otherNames) else { return false }
        updateCategories(named: oldName) { $0.name = newName }
        renameDismissedCategory(oldName, to: newName)
        moveEditTime(from: oldName, to: newName)
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

    /// A future week remembers categories deleted from it by name; after a rename it must
    /// remember the new name, or syncing would add the category back under it.
    private func renameDismissedCategory(_ oldName: String, to newName: String) {
        guard oldName != newName else { return }
        var changed = false
        for wi in weeks.indices where !isPastWeek(weeks[wi]) {
            if let ordered = weeks[wi].userOrderedCategories, ordered.contains(oldName) {
                weeks[wi].userOrderedCategories = ordered.map { $0 == oldName ? newName : $0 }
                changed = true
            }
            guard let dismissed = weeks[wi].dismissedCategories, dismissed.contains(oldName) else { continue }
            weeks[wi].dismissedCategories = dismissed.map { $0 == oldName ? newName : $0 }
            changed = true
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
        let task = ChecklistTask(title: title, mode: mode, taskType: type, isUserEdited: true)
        weeks[wi].categories[ci].tasks.append(task)
        keepCategory(wi, ci, for: mode)
        noteEdit(categoryID)
        save()
        return task.id
    }

    /// Moves a task within its category to where `targetID` is. Later weeks' copies take
    /// the new order when they next sync with this week.
    func moveTask(categoryID: UUID, taskID: UUID, to targetID: UUID) {
        guard taskID != targetID,
              let wi = editableSelectedWeekIndex(),
              let ci = weeks[wi].categories.firstIndex(where: { $0.id == categoryID }),
              let from = weeks[wi].categories[ci].tasks.firstIndex(where: { $0.id == taskID }),
              let to = weeks[wi].categories[ci].tasks.firstIndex(where: { $0.id == targetID }) else { return }
        weeks[wi].categories[ci].tasks.move(fromOffsets: [from], toOffset: to > from ? to + 1 : to)
        // Syncing with the week before must not put the old order back.
        let name = weeks[wi].categories[ci].name
        if !(weeks[wi].userOrderedCategories ?? []).contains(name) {
            weeks[wi].userOrderedCategories = (weeks[wi].userOrderedCategories ?? []) + [name]
        }
        noteEdit(categoryID)
        save()
    }

    /// Moves a task one place up (-1) or down (+1) in its category.
    func moveTask(categoryID: UUID, taskID: UUID, by offset: Int) {
        guard let tasks = selectedWeek?.categories.first(where: { $0.id == categoryID })?.tasks,
              let index = tasks.firstIndex(where: { $0.id == taskID }),
              tasks.indices.contains(index + offset) else { return }
        moveTask(categoryID: categoryID, taskID: taskID, to: tasks[index + offset].id)
    }

    /// Adds a fully built task (a parsed one, with its goal or items) in one save.
    @discardableResult
    func addTask(_ task: ChecklistTask, categoryID: UUID) -> UUID? {
        guard let wi = editableSelectedWeekIndex(),
              let ci = weeks[wi].categories.firstIndex(where: { $0.id == categoryID }) else { return nil }
        var task = task
        task.isUserEdited = true
        weeks[wi].categories[ci].tasks.append(task)
        keepCategory(wi, ci, for: task.mode)
        noteEdit(categoryID)
        save()
        return task.id
    }

    func toggleTask(categoryID: UUID, taskID: UUID) {
        guard let wi = editableSelectedWeekIndex(),
              let ci = weeks[wi].categories.firstIndex(where: { $0.id == categoryID }),
              let ti = weeks[wi].categories[ci].tasks.firstIndex(where: { $0.id == taskID }) else { return }
        weeks[wi].categories[ci].tasks[ti].isCompleted.toggle()
        // Checking a task with sub-tasks (or a list) checks them all, so the task and its
        // sub-tasks never disagree (see toggleSubtask). Unchecking it straight after puts
        // back the checks it had (a mis-tap loses nothing); otherwise it clears them.
        let isCompleted = weeks[wi].categories[ci].tasks[ti].isCompleted
        let subtasks = weeks[wi].categories[ci].tasks[ti].subtasks
        if isCompleted {
            subtaskChecksBeforeCheck[taskID] = Dictionary(uniqueKeysWithValues: subtasks.map { ($0.id, $0.isCompleted) })
        }
        let before = isCompleted ? nil : subtaskChecksBeforeCheck.removeValue(forKey: taskID)
        for si in subtasks.indices {
            weeks[wi].categories[ci].tasks[ti].subtasks[si].isCompleted = isCompleted || (before?[subtasks[si].id] ?? false)
        }
        noteEdit(categoryID)
        save()
    }

    /// With `undoable` false (taking back a Smart Add) there's no Undo message and the
    /// category's edit time isn't touched.
    func deleteTask(categoryID: UUID, taskID: UUID, undoable: Bool = true) {
        guard let wi = editableSelectedWeekIndex(),
              let ci = weeks[wi].categories.firstIndex(where: { $0.id == categoryID }) else { return }
        if let task = weeks[wi].categories[ci].tasks.first(where: { $0.id == taskID }) {
            if undoable { rememberForUndo("“\(task.title)”") }
            if let sourceID = task.carriedFrom {
                weeks[wi].dismissCarryOver(sourceID)
            }
            // In a future week, a deleted repeating task must not be synced back in.
            // Remembered by its source, so a different task given the same name still
            // repeats into this week; by title only if the copy never knew its source.
            if task.mode == .repeating && isFutureWeek(weeks[wi]) {
                if let sourceID = task.repeatsFrom {
                    weeks[wi].dismissCarryOver(sourceID)
                } else if !task.isUserEdited, !(weeks[wi].dismissedRepeating ?? []).contains(task.title) {
                    // (A task the user made in this week isn't a copy: deleting it mustn't
                    // block a repeating task of the same name.)
                    weeks[wi].dismissedRepeating = (weeks[wi].dismissedRepeating ?? []) + [task.title]
                }
            }
        }
        weeks[wi].categories[ci].tasks.removeAll { $0.id == taskID }
        guard undoable else { return save() }
        noteEdit(categoryID)
        saveDelete()
    }

    /// A task in the viewed week, read without saving a preview week.
    private func viewedTask(_ categoryID: UUID, _ taskID: UUID) -> ChecklistTask? {
        selectedWeek?.categories.first { $0.id == categoryID }?.tasks.first { $0.id == taskID }
    }

    // Edits that change nothing are ignored: marking the task edited would stop a
    // carried or repeating copy from following its source.

    func updateTaskMode(categoryID: UUID, taskID: UUID, mode: TaskMode) {
        guard viewedTask(categoryID, taskID)?.mode != mode,
              let wi = editableSelectedWeekIndex(),
              let ci = weeks[wi].categories.firstIndex(where: { $0.id == categoryID }),
              let ti = weeks[wi].categories[ci].tasks.firstIndex(where: { $0.id == taskID }) else { return }
        weeks[wi].categories[ci].tasks[ti].mode = mode
        weeks[wi].categories[ci].tasks[ti].isUserEdited = true
        keepCategory(wi, ci, for: mode)
        noteEdit(categoryID)
        save()
    }

    func renameTask(categoryID: UUID, taskID: UUID, newTitle: String) {
        guard viewedTask(categoryID, taskID)?.title != newTitle,
              let wi = editableSelectedWeekIndex(),
              let ci = weeks[wi].categories.firstIndex(where: { $0.id == categoryID }),
              let ti = weeks[wi].categories[ci].tasks.firstIndex(where: { $0.id == taskID }) else { return }
        weeks[wi].categories[ci].tasks[ti].title = newTitle
        weeks[wi].categories[ci].tasks[ti].isUserEdited = true
        noteEdit(categoryID)
        save()
    }

    // MARK: - Goal Task CRUD

    func updateTaskType(categoryID: UUID, taskID: UUID, type: TaskType) {
        guard viewedTask(categoryID, taskID)?.taskType != type,
              let wi = editableSelectedWeekIndex(),
              let ci = weeks[wi].categories.firstIndex(where: { $0.id == categoryID }),
              let ti = weeks[wi].categories[ci].tasks.firstIndex(where: { $0.id == taskID }) else { return }
        weeks[wi].categories[ci].tasks[ti].taskType = type
        weeks[wi].categories[ci].tasks[ti].isUserEdited = true
        if type != .goal {
            weeks[wi].categories[ci].tasks[ti].goalTarget = nil
            weeks[wi].categories[ci].tasks[ti].goalProgress = nil
            weeks[wi].categories[ci].tasks[ti].goalUnit = nil
            weeks[wi].categories[ci].tasks[ti].goalUnitKind = nil
            weeks[wi].categories[ci].tasks[ti].goalStep = nil
        }
        // Done or not as its new type counts it: a goal when its target is met (a new one
        // has none yet), a list when it has items and all are checked. A checkbox keeps it.
        let task = weeks[wi].categories[ci].tasks[ti]
        switch type {
        case .goal: weeks[wi].categories[ci].tasks[ti].isCompleted = task.goalIsComplete
        case .list: weeks[wi].categories[ci].tasks[ti].isCompleted = !task.subtasks.isEmpty && task.subtasks.allSatisfy(\.isCompleted)
        case .checkbox: break
        }
        noteEdit(categoryID)
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
        weeks[wi].categories[ci].tasks[ti].isUserEdited = true
        weeks[wi].categories[ci].tasks[ti].goalUnitKind = kind
        weeks[wi].categories[ci].tasks[ti].goalUnit = kind == .custom ? unit : nil
        // Auto-update completion
        let progress = weeks[wi].categories[ci].tasks[ti].goalProgress ?? 0
        weeks[wi].categories[ci].tasks[ti].isCompleted = progress >= target
        noteEdit(categoryID)
        save()
    }

    /// Sets the step for a goal's + and − buttons; nil (or not above zero) means automatic.
    func setGoalStep(categoryID: UUID, taskID: UUID, step: Double?) {
        let step = step.flatMap { $0.isFinite && $0 > 0 ? min($0, GoalUnitKind.maxValue) : nil }
        guard viewedTask(categoryID, taskID).map({ $0.goalStep != step }) == true,
              let wi = editableSelectedWeekIndex(),
              let ci = weeks[wi].categories.firstIndex(where: { $0.id == categoryID }),
              let ti = weeks[wi].categories[ci].tasks.firstIndex(where: { $0.id == taskID }) else { return }
        weeks[wi].categories[ci].tasks[ti].goalStep = step
        weeks[wi].categories[ci].tasks[ti].isUserEdited = true
        noteEdit(categoryID)
        save()
    }

    func updateGoalProgress(categoryID: UUID, taskID: UUID, progress: Double) {
        guard progress.isFinite, progress >= 0 else { return }
        let progress = min(progress, GoalUnitKind.maxValue)
        guard let wi = editableSelectedWeekIndex(),
              let ci = weeks[wi].categories.firstIndex(where: { $0.id == categoryID }),
              let ti = weeks[wi].categories[ci].tasks.firstIndex(where: { $0.id == taskID }) else { return }
        weeks[wi].categories[ci].tasks[ti].goalProgress = progress
        // A repeating copy keeps its own progress while following its source. A carried
        // copy's progress comes from its source, so entering some makes the copy the user's.
        if weeks[wi].categories[ci].tasks[ti].mode != .repeating {
            weeks[wi].categories[ci].tasks[ti].isUserEdited = true
        }
        let target = weeks[wi].categories[ci].tasks[ti].goalTarget ?? 0
        weeks[wi].categories[ci].tasks[ti].isCompleted = target > 0 && progress >= target
        noteEdit(categoryID)
        save()
    }

    // MARK: - Sub-Task CRUD

    func addSubtask(categoryID: UUID, taskID: UUID, title: String) {
        guard let wi = editableSelectedWeekIndex(),
              let ci = weeks[wi].categories.firstIndex(where: { $0.id == categoryID }),
              let ti = weeks[wi].categories[ci].tasks.firstIndex(where: { $0.id == taskID }) else { return }
        weeks[wi].categories[ci].tasks[ti].subtasks.append(SubTask(title: title))
        weeks[wi].categories[ci].tasks[ti].isUserEdited = true
        // A new unchecked item means the task isn't done yet.
        weeks[wi].categories[ci].tasks[ti].isCompleted = false
        noteEdit(categoryID)
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
        noteEdit(categoryID)
        save()
    }

    func deleteSubtask(categoryID: UUID, taskID: UUID, subtaskID: UUID) {
        guard let wi = editableSelectedWeekIndex(),
              let ci = weeks[wi].categories.firstIndex(where: { $0.id == categoryID }),
              let ti = weeks[wi].categories[ci].tasks.firstIndex(where: { $0.id == taskID }) else { return }
        if let subtask = weeks[wi].categories[ci].tasks[ti].subtasks.first(where: { $0.id == subtaskID }) {
            rememberForUndo("“\(subtask.title)”")
        }
        weeks[wi].categories[ci].tasks[ti].subtasks.removeAll { $0.id == subtaskID }
        weeks[wi].categories[ci].tasks[ti].isUserEdited = true
        // Deleting the last unchecked item completes the task, as checking it would.
        let task = weeks[wi].categories[ci].tasks[ti]
        if !task.subtasks.isEmpty {
            weeks[wi].categories[ci].tasks[ti].isCompleted = task.subtasks.allSatisfy(\.isCompleted)
        }
        noteEdit(categoryID)
        saveDelete()
    }

    func renameSubtask(categoryID: UUID, taskID: UUID, subtaskID: UUID, newTitle: String) {
        guard viewedTask(categoryID, taskID)?.subtasks.first(where: { $0.id == subtaskID })?.title != newTitle,
              let wi = editableSelectedWeekIndex(),
              let ci = weeks[wi].categories.firstIndex(where: { $0.id == categoryID }),
              let ti = weeks[wi].categories[ci].tasks.firstIndex(where: { $0.id == taskID }),
              let si = weeks[wi].categories[ci].tasks[ti].subtasks.firstIndex(where: { $0.id == subtaskID }) else { return }
        weeks[wi].categories[ci].tasks[ti].subtasks[si].title = newTitle
        weeks[wi].categories[ci].tasks[ti].isUserEdited = true
        noteEdit(categoryID)
        save()
    }

    // MARK: - Category Order

    private static let editTimesKey = "categoryEditTimes"

    func setCategorySort(_ order: CategorySortOrder) {
        guard order != categorySort else { return }
        categorySort = order
        saveSettings()
    }

    /// Drops edit times of names no week or saved category has any more, so a deleted
    /// category's time can't attach to a new one with its name.
    private func pruneEditTimes() {
        let names = Set(weeks.flatMap { $0.categories.map(\.name) } + savedCategories.map(\.name))
        let kept = categoryEditTimes.filter { names.contains($0.key) }
        guard kept.count != categoryEditTimes.count else { return }
        categoryEditTimes = kept
        defaults.set(categoryEditTimes.mapValues(\.timeIntervalSince1970), forKey: Self.editTimesKey)
    }

    /// Records that a category in the viewed week was just edited.
    private func noteEdit(_ categoryID: UUID) {
        guard let name = selectedWeek?.categories.first(where: { $0.id == categoryID })?.name else { return }
        noteEdit(named: name)
    }

    private func noteEdit(named name: String) {
        categoryEditTimes[name] = now()
        defaults.set(categoryEditTimes.mapValues(\.timeIntervalSince1970), forKey: Self.editTimesKey)
    }

    /// A renamed category keeps its place in the recently-edited order.
    private func moveEditTime(from oldName: String, to newName: String) {
        guard oldName != newName else { return }
        // The new name takes the old one's time, or none (not a deleted category's old time).
        categoryEditTimes[newName] = categoryEditTimes.removeValue(forKey: oldName)
        defaults.set(categoryEditTimes.mapValues(\.timeIntervalSince1970), forKey: Self.editTimesKey)
    }

    /// `categories` in the chosen order: as arranged (manual), or by when they were last
    /// edited. Ones never edited keep their arranged order, after the edited ones.
    func sortedCategories(_ categories: [Category]) -> [Category] {
        guard categorySort != .manual else { return categories }
        let newestFirst = categorySort == .recentFirst
        return categories.enumerated().sorted { a, b in
            switch (categoryEditTimes[a.element.name], categoryEditTimes[b.element.name]) {
            case let (x?, y?) where x != y: return newestFirst ? x > y : x < y
            // Never edited counts as oldest: last when recent comes first, first when the
            // least recent does (the card just edited mustn't lead "least recent").
            case (_?, nil): return newestFirst
            case (nil, _?): return !newestFirst
            default: return a.offset < b.offset
            }
        }.map(\.element)
    }

    // MARK: - Undo

    /// Called by a delete just before it changes anything.
    private func rememberForUndo(_ description: String) {
        weeksBeforeDelete = weeks
        savedCategoriesBeforeDelete = savedCategories
        lastDelete = UndoableDelete(description: description, week: selectedWeek?.startDay)
    }

    /// Saves a delete without ending its undo.
    private func saveDelete() {
        isSavingDelete = true
        save()
        isSavingDelete = false
    }

    /// Puts back everything as it was before the last delete.
    func undoLastDelete() {
        guard let weeksBeforeDelete else { return }
        weeks = weeksBeforeDelete
        if let savedCategoriesBeforeDelete, savedCategoriesBeforeDelete != savedCategories {
            savedCategories = savedCategoriesBeforeDelete
            saveSettings()
        }
        clearUndo()
        save()
    }

    /// Ends the chance to undo (the message timed out, or something else changed).
    func clearUndo() {
        guard lastDelete != nil || weeksBeforeDelete != nil else { return }
        lastDelete = nil
        weeksBeforeDelete = nil
        savedCategoriesBeforeDelete = nil
    }

    // MARK: - Helpers

    private func sortWeeks() {
        weeks.sort { $0.startDay > $1.startDay }
    }
}
