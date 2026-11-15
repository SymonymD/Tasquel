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
    /// A task just added to another week than the one viewed (its day had gone by this
    /// week): the screen goes to that week (`ContentView`), and its card there shows the
    /// note, so the task is seen where it went instead of vanishing (2026-11-15). Not saved.
    var addedElsewhere: AddedElsewhere?
    struct AddedElsewhere: Equatable {
        let taskID: UUID
        let categoryName: String
        let weekStart: DayKey
        /// The words it was added from, and the note's message.
        let text: String
        let message: String
        let isSmartAdd: Bool
        /// Added there (Undo takes it away), or moved there (nothing to undo to).
        var canUndo = true
        /// Why it went there, for the pop-up as the screen follows (`ContentView`).
        var detail = ""
        let token = UUID()
    }
    /// A task is being moved by its handle (a card's edit mode): the week isn't swiped
    /// meanwhile. Read only by gestures, so changing it redraws nothing. Not saved.
    @ObservationIgnored var isReorderingTask = false
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
    /// Settings ▸ Expiration Reminders: a notification the day before a task's last day.
    var remindsBeforeExpiry = true
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
        case .system, .seasonal: nil  // Seasonal has light and dark palettes
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

    /// `directory` and `defaults` are injectable so tests never touch the app's real data;
    /// `appVersion` so they decide which version is launching (What's New).
    init(directory: URL = .documentsDirectory, defaults: UserDefaults = .standard,
         now: @escaping () -> Date = { Date() }, calendar: @escaping () -> Calendar = { .current },
         appVersion: String = AppInfo.version()) {
        fileURL = directory.appending(path: "checklist.json")
        settingsURL = directory.appending(path: "settings.json")
        self.defaults = defaults
        self.now = now
        calendarProvider = calendar
        selectedDate = now()
        if let stored = defaults.dictionary(forKey: Self.editTimesKey) as? [String: Double] {
            categoryEditTimes = stored.mapValues { Date(timeIntervalSince1970: $0) }
        }
        // Read before loading sets it: every launch since 1.0 left it, a new install hasn't.
        let launchedBefore = defaults.object(forKey: "didMigrateStarters_v1") != nil
        loadAndPrepare()
        noteLaunchForWhatsNew(appVersion: appVersion, launchedBefore: launchedBefore)
    }

    // MARK: - What's New

    /// The header's "What's New?" button shows (`WhatsNew`): for someone who updated from a
    /// version before `WhatsNew.version` (not a new install), until they've opened it from
    /// there `WhatsNew.buttonOpens` times. Settings always has What's New.
    private(set) var showsWhatsNewButton = false

    /// UserDefaults: the version last launched (none before 1.1), the What's New waiting to be
    /// seen from the button, and how many times the button has opened it.
    private static let lastLaunchedVersionKey = "lastLaunchedVersion"
    private static let whatsNewPendingKey = "whatsNewPending"
    private static let whatsNewOpensKey = "whatsNewButtonOpens"

    private func noteLaunchForWhatsNew(appVersion: String, launchedBefore: Bool) {
        #if DEBUG
        // `-demoWhatsNew`: as if just updated, the button not yet opened.
        if ProcessInfo.processInfo.arguments.contains("-demoWhatsNew") {
            defaults.set(WhatsNew.version, forKey: Self.whatsNewPendingKey)
            defaults.set(0, forKey: Self.whatsNewOpensKey)
            showsWhatsNewButton = true
            return
        }
        #endif
        // Before 1.1 nothing recorded the version: an earlier launch means 1.0.x.
        let previous = defaults.string(forKey: Self.lastLaunchedVersionKey) ?? (launchedBefore ? "1.0" : nil)
        if let previous, WhatsNew.isVersion(previous, olderThan: WhatsNew.version),
           !WhatsNew.isVersion(appVersion, olderThan: WhatsNew.version),
           defaults.string(forKey: Self.whatsNewPendingKey) != WhatsNew.version {
            defaults.set(WhatsNew.version, forKey: Self.whatsNewPendingKey)
            defaults.set(0, forKey: Self.whatsNewOpensKey)
        }
        defaults.set(appVersion, forKey: Self.lastLaunchedVersionKey)
        showsWhatsNewButton = defaults.string(forKey: Self.whatsNewPendingKey) == WhatsNew.version
            && defaults.integer(forKey: Self.whatsNewOpensKey) < WhatsNew.buttonOpens
    }

    /// The header's button opened What's New. True when that was its last time (the button
    /// goes once the sheet closes: `finishWhatsNewFromButton`).
    func whatsNewOpenedFromButton() -> Bool {
        let opens = defaults.integer(forKey: Self.whatsNewOpensKey) + 1
        defaults.set(opens, forKey: Self.whatsNewOpensKey)
        return opens >= WhatsNew.buttonOpens
    }

    /// The sheet the button opened has closed: the button goes if it's been opened enough.
    func finishWhatsNewFromButton() {
        guard defaults.integer(forKey: Self.whatsNewOpensKey) >= WhatsNew.buttonOpens else { return }
        defaults.removeObject(forKey: Self.whatsNewPendingKey)
        showsWhatsNewButton = false
    }

    /// Launched with throwaway data (UI tests, screenshots: `-isolatedData`, `-isolatedDataID`,
    /// `-demoData`; Debug builds only): no notification permission prompt, no reminders.
    static var launchesWithThrowawayData: Bool {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains("-isolatedData") || arguments.contains("-isolatedDataID") || launchesWithDemoData
        #else
        return false
        #endif
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
        let store = ChecklistStore(directory: directory, defaults: UserDefaults(suiteName: directory.lastPathComponent) ?? .standard,
                                   now: demo ? demoClock() : { Date() })
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
        inferWeekStartFromSavedWeeks()
        // The current week, in the middle (see `midweek`); also after Retry or Start Fresh
        // on another day than the app was opened on.
        selectedDate = midweek(weekStartDay(containing: now()))
        saveThisWeekOnlyCategories()
        makeThisWeekOnlyCardsOneTime()
        pruneEditTimes()
        let currentWeek = ensureWeekExists(for: now())
        migrateStartersIfNeeded(into: currentWeek)
        syncWithPreviousWeek(for: now())
        removeExpiredTasks()
    }

    /// The saved weeks say which day weeks start on: they always move with the setting, so
    /// when the two disagree the setting is the one that's wrong. That happens without
    /// settings.json (Start Fresh after it couldn't be read), or when a week-start change
    /// saved one file but not the other (a full device). Trusting the setting would hide
    /// every saved week and build a new current week. The most recent week's weekday says.
    private func inferWeekStartFromSavedWeeks() {
        guard let latest = weeks.first else { return }
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

    /// `keepsUndo`: a save of sync's own results, which doesn't end a delete's Undo (going
    /// to another week syncs it; the next sync makes again what undoing loses).
    func save(keepsUndo: Bool = false) {
        guard persistenceError == nil else { return }
        // Any other change ends the chance to undo the last delete: putting the old
        // weeks back would undo that change too.
        if !isSavingDelete && !keepsUndo { clearUndo() }
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
        var remindsBeforeExpiry: Bool?
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
            remindsBeforeExpiry = settings.remindsBeforeExpiry ?? true
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
                categorySort: categorySort.rawValue,
                remindsBeforeExpiry: remindsBeforeExpiry
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

    /// Noon in the middle of the week starting on `day`: the moment `selectedDate` holds.
    /// The week's first midnight could fall into the week before when the time zone moves
    /// west (Monday 00:00 in New York is Sunday 23:00 in Chicago); noon on its fourth day
    /// stays in the week through any time-zone change.
    private func midweek(_ day: DayKey) -> Date {
        let calendar = calendar
        let start = day.adding(days: 3).date(in: calendar)
        return calendar.date(byAdding: .hour, value: 12, to: start) ?? start
    }

    // MARK: - Week Status

    /// Today, in the current time zone.
    private var today: DayKey { DayKey(now(), in: calendar) }

    /// The store's current moment: `Date()`, or what tests (and `-demoToday`) set.
    /// Views use it for today so the day strip and the events list agree with the store.
    var currentDate: Date { now() }

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
        let selectedStart = selectedWeek.map { midweek($0.startDay.adding(days: shift)) }
        weeks = weeks.map { week in
            var moved = week
            moved.startDay = week.startDay.adding(days: shift)
            return moved
        }
        weekStartsOnSunday = sunday
        // Previews were for the old days: one kept could hand its ID to a saved week's day.
        previewCache.removeAll()
        lastPreviews.removeAll()
        if let selectedStart { selectedDate = selectedStart }
        save()
        saveSettings()
        ensureWeekExists(for: now())
        // A saved future week may have just become current.
        syncWithPreviousWeek(for: now())
    }

    func setRemindsBeforeExpiry(_ reminds: Bool) {
        remindsBeforeExpiry = reminds
        saveSettings()
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
            newWeek.categories = rollForwardCategories(from: previousWeek, cutoff: expiryCutoff(forWeekStarting: monday))
        } else if !isPastWeek(newWeek) {
            // First ever week: seed from saved category templates
            newWeek.categories = savedCategories.map {
                Category(name: $0.name, symbol: $0.symbol)
            }
        }
        // A past week with no week before it is from before Tasquel was used: it has no
        // cards ("Nothing was planned this week"). Seeded from the templates, it showed every
        // saved card, deleted starters and cards made today alike (2026-11-14).
        return newWeek
    }

    /// The week `navigateToDate(_:)` would show for `date`, without creating or
    /// saving anything. Used to draw neighboring weeks while paging.
    func previewWeek(for date: Date) -> Week {
        let monday = weekStartDay(containing: date)
        if let cached = previewCache[monday] { return cached }
        let stored = storedWeekIndex(startingOn: monday).map { weeks[$0] }
        var week = stored ?? makeWeek(startingOn: monday)
        if let source = mostRecentWeekBefore(monday) { week = caughtUp(week, from: source) }
        if let last = lastPreviews[monday] {
            if let stored {
                // What sync adds to a saved week (a card it doesn't have, a task copied from
                // the week before) is made anew each time: without the IDs it had, every
                // change to this week rebuilt those cards on the page beside it (2026-11-12).
                if last.id == stored.id { Self.reuseIDs(of: last, in: &week, saved: stored) }
            } else if !weeks.contains(where: { $0.id == last.id }) {
                Self.reuseIDs(of: last, in: &week)
            }
        }
        previewCache[monday] = week
        lastPreviews[monday] = week
        return week
    }

    /// `week` caught up with `source`, the week before it, as viewing it would: copies follow
    /// their sources, deletions reach on, expired tasks go. Changes nothing saved. A past
    /// week stays as it is.
    private func caughtUp(_ week: Week, from source: Week) -> Week {
        guard !isPastWeek(week) else { return week }
        var week = week
        if let dismissed = extendedDismissals(of: week, from: source) { week.dismissedCarryOvers = dismissed }
        let isFuture = isFutureWeek(week) && week.didFinalSync != true
        let cutoff = expiryCutoff(for: week)
        if isFuture { _ = Self.syncRecurringTasks(into: &week, from: source, addsCategories: true, cutoff: cutoff) }
        _ = Self.syncCarryOverTasks(into: &week, from: source, followsSource: isFuture, cutoff: cutoff)
        // As `removeExpiredTasks` does for saved weeks.
        for ci in week.categories.indices { week.categories[ci].tasks.removeAll { $0.isExpired(before: cutoff) } }
        return week
    }

    /// A week as it will be once the weeks before it have caught up in turn. A saved later
    /// week catches up with the week before it only when it's viewed, so an edit made this
    /// week (a check, a new date, a rename, a deleted copy) hasn't reached it yet; previews
    /// catch up from it as saved. This catches each saved later week up from the one before
    /// it as caught up, and builds an unsaved week from the latest of those. The current
    /// week and earlier ones are as saved. Read only: for reminders (2026-11-14).
    private func weekAsItWillBe(startingOn monday: DayKey, _ memo: inout [DayKey: Week]) -> Week {
        if let week = memo[monday] { return week }
        let stored = storedWeekIndex(startingOn: monday).map { weeks[$0] }
        let week: Week
        if let stored, !isFutureWeek(stored) {
            week = stored
        } else if let before = mostRecentWeekBefore(monday) {
            let source = weekAsItWillBe(startingOn: before.startDay, &memo)
            var built = stored ?? Week(startDay: monday)
            if stored == nil {
                built.categories = rollForwardCategories(from: source, cutoff: expiryCutoff(forWeekStarting: monday))
            }
            week = caughtUp(built, from: source)
        } else {
            week = stored ?? makeWeek(startingOn: monday)
        }
        memo[monday] = week
        return week
    }

    /// Gives a rebuilt preview the IDs of the previous preview of the same week: the week,
    /// its categories (by name), tasks (by the task they copy) and items (by title). For a
    /// saved week (`saved`), only what sync added: what's saved there keeps its own IDs, which
    /// edits find it by. Each earlier ID goes to one thing only (two cards with one name).
    private static func reuseIDs(of last: Week, in week: inout Week, saved: Week? = nil) {
        let savedCategories = Set(saved?.categories.map(\.id) ?? [])
        let savedTasks = Set(saved?.categories.flatMap { $0.tasks.map(\.id) } ?? [])
        let savedItems = Set(saved?.categories.flatMap { $0.tasks.flatMap { $0.subtasks.map(\.id) } } ?? [])
        if saved == nil { week.id = last.id }
        var usedCategories = Set<UUID>()
        for ci in week.categories.indices {
            let category = week.categories[ci]
            let lastCategory = savedCategories.contains(category.id)
                ? last.categories.first { $0.id == category.id }
                : last.categories.first {
                    $0.name == category.name && !savedCategories.contains($0.id) && !usedCategories.contains($0.id)
                }
            guard let lastCategory else { continue }
            usedCategories.insert(lastCategory.id)
            week.categories[ci].id = lastCategory.id
            var usedTasks = Set<UUID>()
            for ti in category.tasks.indices {
                let task = category.tasks[ti]
                let lastTask: ChecklistTask?
                if savedTasks.contains(task.id) {
                    lastTask = lastCategory.tasks.first { $0.id == task.id }
                } else if let source = task.carriedFrom ?? task.repeatsFrom {
                    lastTask = lastCategory.tasks.first {
                        ($0.carriedFrom ?? $0.repeatsFrom) == source && !savedTasks.contains($0.id) && !usedTasks.contains($0.id)
                    }
                } else {
                    lastTask = nil
                }
                guard let lastTask else { continue }
                usedTasks.insert(lastTask.id)
                week.categories[ci].tasks[ti].id = lastTask.id
                var usedItems = Set<UUID>()
                for si in task.subtasks.indices where !savedItems.contains(task.subtasks[si].id) {
                    guard let lastItem = lastTask.subtasks.first(where: {
                        $0.title == task.subtasks[si].title && !savedItems.contains($0.id) && !usedItems.contains($0.id)
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

    private func rollForwardCategories(from source: Week, cutoff: DayKey) -> [Category] {
        source.categories.filter { !$0.isThisWeekOnly }.map { category in
            var newCategory = Category(name: category.name, symbol: category.symbol)
            newCategory.isPinned = category.isPinned
            // In the same order as this week. Repeating tasks always come back (reset);
            // carry-over tasks only if unfinished; one-time tasks never; none past its last day.
            newCategory.tasks = category.tasks.filter { !$0.isExpired(before: cutoff) }.compactMap { task in
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
        selectedDate = midweek(weekStartDay(containing: date))
        if let week = selectedWeek, isCurrentWeek(week) { ensureWeekExists(for: date) }
        catchUpSavedWeeks(before: weekStartDay(containing: date))
        syncWithPreviousWeek(for: date)
        // (Also after midnight: ContentView comes back here on a new day.)
        removeExpiredTasks()
    }

    /// Brings the current or a future week up to date with the most recent week before
    /// it. Weeks are built from the week before only once, when first opened, so this
    /// picks up what changed since: unfinished carry-over tasks, and for a future week
    /// also its categories and recurring tasks.
    private func syncWithPreviousWeek(for date: Date) {
        finishSkippedWeeks()
        syncSavedWeek(startingOn: weekStartDay(containing: date))
    }

    /// Each saved later week before `monday` catches up with the week before it, in order,
    /// as paging through them would. A saved later week otherwise catches up only when it's
    /// viewed, so jumping ahead (Go to Week, the calendar) built the week from one still
    /// missing what changed since: "Meeting 1/27", added this week, wasn't in its week of
    /// January (the user, 2026-11-14). The week jumped to then catches up from them.
    private func catchUpSavedWeeks(before monday: DayKey) {
        let between = weeks.filter { isFutureWeek($0) && $0.startDay < monday }.map(\.startDay).sorted()
        for start in between { syncSavedWeek(startingOn: start) }
    }

    /// The saved week starting `monday` (current or later) brought up to date with the
    /// most recent week before it (see `syncWithPreviousWeek`).
    private func syncSavedWeek(startingOn monday: DayKey) {
        guard let wi = storedWeekIndex(startingOn: monday),
              !isPastWeek(weeks[wi]),
              let sourceWeek = mostRecentWeekBefore(monday) else { return }
        var changed = false
        if let dismissed = extendedDismissals(of: weeks[wi], from: sourceWeek) {
            weeks[wi].dismissedCarryOvers = dismissed
            changed = true
        }
        // A week that has had its final sync (it was current, then the week start day
        // changed and moved it into the future) is the user's own, like a current week.
        let isFuture = isFutureWeek(weeks[wi]) && weeks[wi].didFinalSync != true
        // A saved week that has just become current gets one last full sync, so changes
        // made last week after it was saved (a task finished, a repeating task renamed)
        // still reach it. Only once: after that the week is the user's own.
        let isFinalSync = !isFuture && weeks[wi].didFinalSync == false
        let follows = isFuture || isFinalSync
        let cutoff = expiryCutoff(for: weeks[wi])
        if follows {
            changed = Self.syncRecurringTasks(into: &weeks[wi], from: sourceWeek, addsCategories: isFuture, cutoff: cutoff)
        }
        if Self.syncCarryOverTasks(into: &weeks[wi], from: sourceWeek, followsSource: follows, cutoff: cutoff) { changed = true }
        if isFinalSync {
            weeks[wi].didFinalSync = true
            changed = true
        }
        // Sync's own saves keep a delete's Undo (it would only lose what sync makes again).
        if changed { save(keepsUndo: true) }
    }

    /// A task deleted from a week stays deleted there even as its source moves on: a week
    /// later the source is a copy of the task that was deleted (linked to it, or to a copy
    /// of it), and so on each week. Any task in `source` whose links lead back to a
    /// dismissed task is dismissed too. Returns the week's dismissals with those added, or
    /// nil when there's nothing to add. (Returned, not changed in place: it reads `weeks`.)
    private func extendedDismissals(of week: Week, from source: Week) -> [UUID]? {
        let dismissed = Set(week.dismissedCarryOvers ?? [])
        guard !dismissed.isEmpty else { return nil }
        var links: [UUID: [UUID]] = [:]
        for task in weeks.lazy.flatMap(\.categories).flatMap(\.tasks) {
            links[task.id] = [task.carriedFrom, task.repeatsFrom].compactMap { $0 }
        }
        func leadsToDismissed(_ id: UUID) -> Bool {
            var seen: Set<UUID> = [], queue = [id]
            while let next = queue.popLast() {
                guard seen.insert(next).inserted else { continue }
                if dismissed.contains(next) { return true }
                queue += links[next] ?? []
            }
            return false
        }
        var added: [UUID] = []
        for task in source.categories.flatMap(\.tasks) where !dismissed.contains(task.id) {
            if [task.carriedFrom, task.repeatsFrom].compactMap({ $0 }).contains(where: leadsToDismissed) {
                added.append(task.id)
            }
        }
        guard !added.isEmpty else { return nil }
        return (week.dismissedCarryOvers ?? []) + added
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
                if let dismissed = extendedDismissals(of: weeks[wi], from: source) { weeks[wi].dismissedCarryOvers = dismissed }
                let cutoff = expiryCutoff(for: weeks[wi])
                _ = Self.syncRecurringTasks(into: &weeks[wi], from: source, addsCategories: false, cutoff: cutoff)
                _ = Self.syncCarryOverTasks(into: &weeks[wi], from: source, followsSource: true, cutoff: cutoff)
            }
            weeks[wi].didFinalSync = true
        }
        save(keepsUndo: true)
    }

    // MARK: - Days

    /// Gives the task a day of the week (1 Sunday … 7 Saturday), or with nil takes it away.
    /// An edit, like a new mode; later weeks' untouched copies take it when they next sync.
    func setTaskDay(categoryID: UUID, taskID: UUID, day: Int?) {
        let day = day.flatMap { (1...7).contains($0) ? $0 : nil }
        guard viewedTask(categoryID, taskID)?.dayOfWeek != day,
              let wi = editableSelectedWeekIndex(),
              let ci = weeks[wi].categories.firstIndex(where: { $0.id == categoryID }),
              let ti = weeks[wi].categories[ci].tasks.firstIndex(where: { $0.id == taskID }) else { return }
        weeks[wi].categories[ci].tasks[ti].dayOfWeek = day
        // A day given after it had gone by this week isn't "late" (`ChecklistTask.isLate`).
        weeks[wi].categories[ci].tasks[ti].daySetOn = day == nil ? nil : today
        markEdited(wi, ci, ti)
        noteEdit(categoryID)
        save()
    }

    /// The weekday has already gone by in the viewed week, which is this week (Tuesday on a
    /// Saturday). A new task given such a day goes into next week (`addParsedTask`).
    func dayHasGoneBy(_ weekday: Int) -> Bool {
        guard let week = selectedWeek, isCurrentWeek(week) else { return false }
        return week.startDay.adding(days: Weekday.offset(weekday, firstWeekday: firstWeekday)) < today
    }

    /// Whether the week starting `start` has the task (one added to next week, say).
    func hasTask(_ taskID: UUID, inWeekStarting start: DayKey) -> Bool {
        guard let wi = storedWeekIndex(startingOn: start) else { return false }
        return weeks[wi].categories.contains { $0.tasks.contains { $0.id == taskID } }
    }

    /// Takes back a task just added to another week than the one viewed (a day gone by this
    /// week put it in next week): no Undo message, as for a Smart Add taken back.
    func removeAddedTask(_ taskID: UUID, inWeekStarting start: DayKey) {
        guard persistenceError == nil, let wi = storedWeekIndex(startingOn: start) else { return }
        for ci in weeks[wi].categories.indices {
            weeks[wi].categories[ci].tasks.removeAll { $0.id == taskID }
        }
        save()
    }

    // MARK: - Expiration

    /// Today, as the store's clock and calendar see it.
    var currentDay: DayKey { today }

    /// A task whose last day is before this is gone from `week`: the week's first day, or
    /// today in the current week (a task is there through its last day). A past week's is
    /// its own first day: they keep what they had (history).
    private func expiryCutoff(for week: Week) -> DayKey {
        isPastWeek(week) ? week.startDay : max(week.startDay, today)
    }

    private func expiryCutoff(forWeekStarting start: DayKey) -> DayKey {
        start.adding(days: 7) <= today ? start : max(start, today)
    }

    /// Takes tasks past their last day out of the current and later saved weeks (the day
    /// after their date they're gone; see `ChecklistTask.expiresOn`). Past weeks keep them.
    /// Like sync, it keeps a delete's Undo.
    func removeExpiredTasks() {
        var changed = false
        for wi in weeks.indices where !isPastWeek(weeks[wi]) {
            let cutoff = expiryCutoff(for: weeks[wi])
            for ci in weeks[wi].categories.indices where weeks[wi].categories[ci].tasks.contains(where: { $0.isExpired(before: cutoff) }) {
                weeks[wi].categories[ci].tasks.removeAll { $0.isExpired(before: cutoff) }
                changed = true
            }
        }
        if changed { save(keepsUndo: true) }
    }

    /// A task's date, from the type and mode popup or the edit mode's clock: its last day
    /// (`setTaskExpiry`), and what a date changes besides. A one-time task dated after its
    /// week goes into the week of its date (`moveToItsDatesWeek`); where it can't (no card of
    /// its name there), it carries over until then (`ChecklistTask.dateMode`). A date inside
    /// the week is its day (`dateWeekday`). Nil takes the date away and changes nothing else.
    func setTaskDate(categoryID: UUID, taskID: UUID, lastDay: DayKey?, wholeWeek: Bool = false) {
        if let lastDay, moveToItsDatesWeek(categoryID: categoryID, taskID: taskID, lastDay: lastDay, wholeWeek: wholeWeek) {
            return
        }
        if let lastDay, let week = selectedWeek, let task = viewedTask(categoryID, taskID) {
            let mode = ChecklistTask.dateMode(task.mode, lastDay: lastDay, weekStart: week.startDay)
            if mode != task.mode { updateTaskMode(categoryID: categoryID, taskID: taskID, mode: mode) }
            if let weekday = ChecklistTask.dateWeekday(lastDay, wholeWeek: wholeWeek, weekStart: week.startDay, calendar: calendar) {
                setTaskDay(categoryID: categoryID, taskID: taskID, day: weekday)
            } else if mode != .repeating {
                // A day and a date are one choice for a one-time or carry-over task: a later
                // week's date takes its day away (it read "Today" or "Thu · late" beside a
                // date weeks off). A repeating task keeps its day, every week until its date.
                setTaskDay(categoryID: categoryID, taskID: taskID, day: nil)
            }
        }
        setTaskExpiry(categoryID: categoryID, taskID: taskID, lastDay: lastDay, wholeWeek: wholeWeek)
    }

    /// The week a task dated `lastDay` belongs in: the one holding its date.
    func weekOfDate(_ lastDay: DayKey) -> DayKey { weekStartDay(containing: lastDay.date(in: calendar)) }

    /// A one-time task dated after the viewed week goes into the week of its date, on that day,
    /// and the screen follows it there (`addedElsewhere`, no Undo: it was moved, not added).
    /// The user's rule, 2026-11-15: as Carry Over until its date, a task months off sat in
    /// every week, and set back to One-Time it was gone before its date. Into that week's card
    /// of the same name; false, with nothing changed, when there's none (a This week only card).
    private func moveToItsDatesWeek(categoryID: UUID, taskID: UUID, lastDay: DayKey, wholeWeek: Bool) -> Bool {
        guard let week = selectedWeek, !isPastWeek(week), var task = viewedTask(categoryID, taskID),
              task.mode == .oneTime, lastDay > week.startDay.adding(days: 6),
              let name = week.categories.first(where: { $0.id == categoryID })?.name else { return false }
        let target = weekOfDate(lastDay)
        task.expiresOn = lastDay
        task.expirySetOn = today
        task.expiresWithWeek = wholeWeek
        task.dayOfWeek = ChecklistTask.dateWeekday(lastDay, wholeWeek: wholeWeek, weekStart: target, calendar: calendar)
        task.daySetOn = nil
        // Its own task there: not a copy, and not pinned (that card may have its two).
        task.carriedFrom = nil
        task.repeatsFrom = nil
        task.isPinned = false
        guard addTask(task, toWeekStarting: target, categoryNamed: name) != nil else { return false }
        deleteTask(categoryID: categoryID, taskID: taskID, undoable: false)
        let shown = lastDay.date(in: calendar).formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        addedElsewhere = AddedElsewhere(taskID: task.id, categoryName: name, weekStart: target, text: task.title,
                                        message: "“\(task.title)” moved here, to the week of its date, \(shown)",
                                        isSmartAdd: false, canUndo: false,
                                        detail: "A one-time task goes into the week of its date.")
        return true
    }

    /// Sets the task's last day (`expiresOn`; `wholeWeek` when a week was picked, its last
    /// day), or with nil takes the expiration away. The day it's set on is kept for the
    /// checkbox's ring. An edit, like a new mode; later weeks' untouched copies take it
    /// when they next sync, and leave once it has passed.
    func setTaskExpiry(categoryID: UUID, taskID: UUID, lastDay: DayKey?, wholeWeek: Bool = false) {
        let wholeWeek = lastDay != nil && wholeWeek
        guard let task = viewedTask(categoryID, taskID),
              task.expiresOn != lastDay || task.expiresWithWeek != wholeWeek,
              let wi = editableSelectedWeekIndex(),
              let ci = weeks[wi].categories.firstIndex(where: { $0.id == categoryID }),
              let ti = weeks[wi].categories[ci].tasks.firstIndex(where: { $0.id == taskID }) else { return }
        weeks[wi].categories[ci].tasks[ti].expiresOn = lastDay
        weeks[wi].categories[ci].tasks[ti].expirySetOn = lastDay == nil ? nil : today
        weeks[wi].categories[ci].tasks[ti].expiresWithWeek = wholeWeek
        markEdited(wi, ci, ti)
        noteEdit(categoryID)
        save()
        removeExpiredTasks()
    }

    /// The reminders due, the day before each expiring task's last day at 9 AM (none with
    /// Expiration Reminders off, none whose time has passed). One per task and date: a task
    /// and its copies (`carriedFrom`, `repeatsFrom`, back to the first) are one, whatever
    /// their names, and two tasks with one name are two. The week the reminder falls in
    /// decides, as it will be once caught up (`weekAsItWillBe`): there's one if a copy with
    /// that date is there unchecked. None when that copy was checked off (a repeating one
    /// comes back unchecked, so it gets one), deleted, finished as a carry-over, or left
    /// behind in a This week only card. A task that starts after that week (one added in
    /// its own later week) is decided by its date's week instead (2026-11-14).
    var expiryReminders: [ExpiryReminder] {
        guard remindsBeforeExpiry else { return [] }
        var parent: [UUID: UUID] = [:]
        func note(_ week: Week) {
            for category in week.categories {
                for task in category.tasks { if let source = task.carriedFrom ?? task.repeatsFrom { parent[task.id] = source } }
            }
        }
        func line(_ id: UUID) -> UUID {
            var id = id
            var seen: Set<UUID> = []
            while let source = parent[id], seen.insert(id).inserted { id = source }
            return id
        }
        weeks.forEach(note)
        // Each dated task's line and date, and the first week it's in.
        var order: [(line: UUID, last: DayKey)] = []
        var firstWeek: [String: DayKey] = [:]
        for week in weeks.sorted(by: { $0.startDay < $1.startDay }) where !isPastWeek(week) {
            let cutoff = expiryCutoff(for: week)
            for category in week.categories {
                for task in category.tasks where task.expiresOn != nil && !task.isExpired(before: cutoff) {
                    let key = "\(line(task.id))|\(task.expiresOn!)"
                    if firstWeek[key] == nil {
                        firstWeek[key] = week.startDay
                        order.append((line(task.id), task.expiresOn!))
                    }
                }
            }
        }
        let gregorian = Calendar.weekDates(in: calendar.timeZone)
        let now = now()
        var memo: [DayKey: Week] = [:]
        func copy(of taskLine: UUID, lastDay: DayKey, inWeekContaining day: DayKey) -> (task: ChecklistTask, category: String)? {
            let week = weekAsItWillBe(startingOn: weekStartDay(containing: day.date(in: calendar)), &memo)
            note(week)
            for category in week.categories {
                if let task = category.tasks.first(where: { $0.expiresOn == lastDay && line($0.id) == taskLine }) {
                    return (task, category.name)
                }
            }
            return nil
        }
        return order.compactMap { item in
            let day = item.last.adding(days: -1)
            guard let time = gregorian.date(bySettingHour: ExpiryReminder.hour, minute: 0, second: 0, of: day.date(in: calendar)),
                  time > now else { return nil }
            let key = "\(item.line)|\(item.last)"
            let reminderWeek = weekStartDay(containing: day.date(in: calendar))
            let startsLater = (firstWeek[key] ?? reminderWeek) > reminderWeek
            guard let found = copy(of: item.line, lastDay: item.last, inWeekContaining: startsLater ? item.last : day),
                  !found.task.isCompleted else { return nil }
            let date = item.last.date(in: calendar).formatted(.dateTime.weekday(.wide).month(.wide).day())
            return ExpiryReminder(id: key, title: "\(found.task.title) expires tomorrow",
                                  body: "\(date) is its last day in \(found.category).", day: day)
        }
    }

    /// What the week calendar marks in the week starting `monday` (the user, 2026-11-14):
    /// a task's date (`.date`), and a day some task in that week has (`.day`), a date winning
    /// on its own day. Later weeks as they will be (`weekAsItWillBe`); past weeks as saved
    /// (none for a past week never saved).
    func calendarMarks(weekStartingOn monday: DayKey) -> [DayKey: CalendarMark] {
        let currentStart = weekStartDay(containing: now())
        guard monday >= currentStart || storedWeekIndex(startingOn: monday) != nil else { return [:] }
        var memo: [DayKey: Week] = [:]
        let week = weekAsItWillBe(startingOn: monday, &memo)
        var marks: [DayKey: CalendarMark] = [:]
        let end = monday.adding(days: 6)
        for category in week.categories {
            for task in category.tasks {
                if let date = task.expiresOn, date >= monday, date <= end { marks[date] = .date }
                if let day = task.day(inWeekStarting: monday, firstWeekday: firstWeekday), marks[day] == nil { marks[day] = .day }
            }
        }
        return marks
    }

    /// The first day a task in the viewed week can be given as its last: today, or the
    /// week's first day in a later week.
    var earliestExpiry: DayKey {
        max(today, selectedWeek?.startDay ?? today)
    }

    /// Adds `source`'s unfinished carry-over tasks that `week` is missing, skipping ones
    /// the user deleted from `week`. With `followsSource` (a future week, or a week's
    /// final sync), copies the user hasn't touched (nothing checked) also follow their
    /// source: they pick up its new unchecked items, and go away once it's finished or
    /// no longer carries over. Copies the user changed in `week` are left alone.
    /// Returns whether anything changed.
    private static func syncCarryOverTasks(into week: inout Week, from source: Week, followsSource: Bool, cutoff: DayKey) -> Bool {
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
                    guard let sourceID = copy.carriedFrom, copy.syncMode == .carryOver, !copy.isUserEdited,
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
                && task.carriedFrom.map(dismissed.contains) != true && !task.isExpired(before: cutoff) {
                // Also present when this week's copy links to what the source itself was
                // carried from (it was made before the week in between existed).
                // Its copy may be in another card too: this one was renamed and a new card
                // took the old name. (Tasks never move between cards.)
                let isCopy = { (copy: ChecklistTask) in
                    copy.carriedFrom == task.id || (task.carriedFrom != nil && copy.carriedFrom == task.carriedFrom)
                }
                let present = week.categories[ci].tasks.contains { isCopy($0) || $0.title == task.title }
                    || week.categories.contains { $0.tasks.contains(where: isCopy) }
                guard !present else { continue }
                week.categories[ci].tasks.append(arriving(carriedCopy(of: task), in: week.categories[ci]))
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
        newTask.goalDays = task.goalDays
        newTask.isListFolded = task.isListFolded
        newTask.isPinned = task.isPinned
        newTask.takeExpiry(from: task)
        newTask.carriedFrom = task.id
        return newTask
    }

    /// An untouched future copy updated from its source: title (unless the copy was given its
    /// own, `hasOwnTitle`), type and goal from the source; items checked off in the source
    /// drop out and new unchecked ones are added. Items added only to the copy stay.
    private static func following(_ task: ChecklistTask, copy: ChecklistTask) -> ChecklistTask {
        var copy = copy
        if !copy.hasOwnTitle { copy.title = task.title }
        copy.taskType = task.taskType
        copy.goalTarget = task.goalTarget
        copy.goalProgress = task.goalProgress
        copy.goalUnit = task.goalUnit
        copy.goalUnitKind = task.goalUnitKind
        copy.goalStep = task.goalStep
        copy.goalDays = task.goalDays
        copy.takeExpiry(from: task)
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
    private static func syncRecurringTasks(into week: inout Week, from sourceWeek: Week, addsCategories: Bool, cutoff: DayKey) -> Bool {
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
                // Pinned only while the week has room: at most two pinned cards.
                newCat.isPinned = sourceCategory.isPinned && week.categories.filter(\.isPinned).count < Category.maxPins
                newCat.tasks = recurringTasks.filter { !isDismissed($0) && !$0.isExpired(before: cutoff) }.map { resetRecurringTask($0) }
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
                guard let sourceID = copy.repeatsFrom, copy.syncMode == .repeating, !copy.isUserEdited else { continue }
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
                } else if copy.taskType == .list || (!copy.isCompleted && (copy.goalProgress ?? 0) == 0
                                                       && !copy.subtasks.contains(where: \.isCompleted)) {
                    // (A list's checks came with it: repeating lists keep them, so they
                    // don't say the user started on this copy.)
                    week.categories[ci].tasks.remove(at: ti)
                    changed = true
                }
            }

            for task in recurringTasks where !isDismissed(task) && !task.isExpired(before: cutoff) {
                // A copy the user edited keeps its old link: it still counts as this task's
                // copy, in any card (this one may be a new card with a renamed one's old name).
                guard !week.categories.contains(where: { $0.tasks.contains {
                    $0.repeatsFrom == task.id || (task.repeatsFrom != nil && $0.repeatsFrom == task.repeatsFrom)
                } }) else { continue }
                week.categories[ci].tasks.append(arriving(resetRecurringTask(task), in: week.categories[ci]))
                changed = true
            }
            if !(week.userOrderedCategories ?? []).contains(sourceCategory.name),
               orderLikeSource(&week.categories[ci].tasks, source: sourceCategory.tasks) { changed = true }
        }
        return changed
    }

    /// A later week's copy of a repeating task updated from its source: name (unless it has
    /// its own, `hasOwnTitle`), type and goal setup follow; the copy's own progress and checks
    /// stay. A list gains the source's new items and drops unchecked items the source no
    /// longer has.
    private static func followingRepeating(_ task: ChecklistTask, copy original: ChecklistTask) -> ChecklistTask {
        var copy = original
        if !copy.hasOwnTitle { copy.title = task.title }
        copy.taskType = task.taskType
        copy.goalTarget = task.goalTarget
        copy.goalUnit = task.goalUnit
        copy.goalUnitKind = task.goalUnitKind
        copy.goalStep = task.goalStep
        copy.goalDays = task.goalDays
        copy.takeExpiry(from: task)
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
        // A changed target re-decides whether the goal is met, and so does a new type (as
        // `updateTaskType` decides it: a checkbox keeps its check).
        if task.taskType == .goal, copy.goalTarget != original.goalTarget || copy.taskType != original.taskType {
            copy.isCompleted = copy.goalIsComplete
        } else if task.taskType == .list, original.taskType != .list {
            copy.isCompleted = !copy.subtasks.isEmpty && copy.subtasks.allSatisfy(\.isCompleted)
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
        newTask.goalDays = task.goalDays
        newTask.isListFolded = task.isListFolded
        newTask.isPinned = task.isPinned
        newTask.takeExpiry(from: task)
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
    /// in it comes back (each remembers its mode), and later weeks lose it, keeping only
    /// tasks the user added or changed there. Off: its tasks get their modes back, and it
    /// comes back in later weeks like any category.
    func setCategoryThisWeekOnly(_ categoryID: UUID, _ thisWeekOnly: Bool) {
        guard let wi = editableSelectedWeekIndex(),
              let ci = weeks[wi].categories.firstIndex(where: { $0.id == categoryID }),
              weeks[wi].categories[ci].isThisWeekOnly != thisWeekOnly else { return }
        let category = weeks[wi].categories[ci]
        weeks[wi].categories[ci].isThisWeekOnly = thisWeekOnly
        if !thisWeekOnly { restoreModes(wi, ci) }
        if thisWeekOnly {
            for ti in category.tasks.indices where category.tasks[ti].mode != .oneTime {
                weeks[wi].categories[ci].tasks[ti] = Self.madeOneTime(category.tasks[ti])
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
    /// that off, and its other tasks get their modes back as when the switch is turned off.
    private func keepCategory(_ wi: Int, _ ci: Int, for mode: TaskMode) {
        guard mode != .oneTime, weeks[wi].categories[ci].isThisWeekOnly else { return }
        weeks[wi].categories[ci].isThisWeekOnly = false
        restoreModes(wi, ci)
        keepSavedCategory(for: weeks[wi].categories[ci])
    }

    /// A task made one-time for a "This week only" card, remembering its mode (and whether
    /// the user had changed it) for when the card stops being this week only.
    private static func madeOneTime(_ task: ChecklistTask) -> ChecklistTask {
        guard task.mode != .oneTime else { return task }
        var task = task
        task.modeBeforeThisWeekOnly = .init(mode: task.mode, wasUserEdited: task.isUserEdited)
        task.mode = .oneTime
        return task
    }

    /// A copy synced into `category`: one-time if the card is this week only, since
    /// nothing in it carries on (the copy remembers its mode, like the card's other tasks).
    /// A task copied into `category` by sync: one-time in a This week only card, and not
    /// pinned once the card has its two pinned tasks (a copy's pin could make a third).
    private static func arriving(_ task: ChecklistTask, in category: Category) -> ChecklistTask {
        var task = category.isThisWeekOnly ? madeOneTime(task) : task
        if task.isPinned && category.pinnedTaskCount >= Category.maxPins { task.isPinned = false }
        return task
    }

    /// Puts back the modes a card's tasks had before it was made this week only.
    private func restoreModes(_ wi: Int, _ ci: Int) {
        for ti in weeks[wi].categories[ci].tasks.indices {
            guard let saved = weeks[wi].categories[ci].tasks[ti].modeBeforeThisWeekOnly else { continue }
            weeks[wi].categories[ci].tasks[ti].mode = saved.mode
            weeks[wi].categories[ci].tasks[ti].isUserEdited = saved.wasUserEdited
            weeks[wi].categories[ci].tasks[ti].modeBeforeThisWeekOnly = nil
        }
    }

    /// A This week only card holds only one-time tasks, each remembering its mode (as when
    /// the switch is turned on, and as copies arrive there). Data saved by 1.0.2 can still
    /// have carry-over or repeating copies that sync put there before arrivals were made
    /// one-time; they're made one-time the same way (still following their source by the
    /// mode they had), so none says Carry Over and then doesn't carry. Past weeks stay as
    /// they were.
    private func makeThisWeekOnlyCardsOneTime() {
        var changed = false
        for wi in weeks.indices where !isPastWeek(weeks[wi]) {
            for ci in weeks[wi].categories.indices where weeks[wi].categories[ci].isThisWeekOnly {
                for ti in weeks[wi].categories[ci].tasks.indices where weeks[wi].categories[ci].tasks[ti].mode != .oneTime {
                    weeks[wi].categories[ci].tasks[ti] = Self.madeOneTime(weeks[wi].categories[ci].tasks[ti])
                    changed = true
                }
            }
        }
        if changed { save() }
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
              let to = weeks[wi].categories[ci].tasks.firstIndex(where: { $0.id == targetID }),
              // Among the tasks pinned like it with the same day (`reorderGroup`).
              weeks[wi].categories[ci].tasks[from].isPinned == weeks[wi].categories[ci].tasks[to].isPinned,
              weeks[wi].categories[ci].tasks[from].dayOfWeek == weeks[wi].categories[ci].tasks[to].dayOfWeek else { return }
        weeks[wi].categories[ci].tasks.move(fromOffsets: [from], toOffset: to > from ? to + 1 : to)
        // Syncing with the week before must not put the old order back.
        let name = weeks[wi].categories[ci].name
        if !(weeks[wi].userOrderedCategories ?? []).contains(name) {
            weeks[wi].userOrderedCategories = (weeks[wi].userOrderedCategories ?? []) + [name]
        }
        noteEdit(categoryID)
        save()
    }

    /// Moves a task one place up (-1) or down (+1) in its category, among the pinned tasks
    /// if it's pinned, else among the rest.
    func moveTask(categoryID: UUID, taskID: UUID, by offset: Int) {
        guard let tasks = selectedWeek?.categories.first(where: { $0.id == categoryID })?.reorderGroup(for: taskID),
              let index = tasks.firstIndex(where: { $0.id == taskID }),
              tasks.indices.contains(index + offset) else { return }
        moveTask(categoryID: categoryID, taskID: taskID, to: tasks[index + offset].id)
    }

    /// Adds a task to a later week than the one viewed (next week, for a day gone by this
    /// week), into its card named `name`, saving that week first if it's still a preview.
    /// Nil, with nothing changed, when that week has no such card.
    func addTask(_ task: ChecklistTask, toWeekStarting start: DayKey, categoryNamed name: String) -> UUID? {
        guard persistenceError == nil else { return nil }
        var wi = storedWeekIndex(startingOn: start)
        if wi == nil {
            var preview = previewWeek(for: midweek(start))
            guard isFutureWeek(preview), preview.categories.contains(where: { $0.name == name }) else { return nil }
            preview.didFinalSync = false
            weeks.append(preview)
            sortWeeks()
            wi = storedWeekIndex(startingOn: start)
        }
        guard let wi, let ci = weeks[wi].categories.firstIndex(where: { $0.name == name }) else { return nil }
        var task = task
        task.isUserEdited = true
        weeks[wi].categories[ci].tasks.append(task)
        keepCategory(wi, ci, for: task.mode)
        noteEdit(named: name)
        save()
        return task.id
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
            if task.syncMode == .repeating && isFutureWeek(weeks[wi]) {
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
    func viewedTask(_ categoryID: UUID, _ taskID: UUID) -> ChecklistTask? {
        selectedWeek?.categories.first { $0.id == categoryID }?.tasks.first { $0.id == taskID }
    }

    // Edits that change nothing are ignored: marking the task edited would stop a
    // carried or repeating copy from following its source.

    /// Picking a mode, even the one the task has, also brings it back into later weeks it was
    /// deleted from (`undismissCopies`; the user asked, 2026-11-12: a list carried into next
    /// week, its copy there renamed and then deleted, never came back however its mode was
    /// set). The same mode isn't an edit: only that changes.
    func updateTaskMode(categoryID: UUID, taskID: UUID, mode: TaskMode) {
        guard let task = viewedTask(categoryID, taskID), let week = selectedWeek, !isPastWeek(week) else { return }
        guard task.mode != mode else {
            if undismissCopies(of: taskID, after: week.startDay) { save() }
            return
        }
        guard let wi = editableSelectedWeekIndex(),
              let ci = weeks[wi].categories.firstIndex(where: { $0.id == categoryID }),
              let ti = weeks[wi].categories[ci].tasks.firstIndex(where: { $0.id == taskID }) else { return }
        weeks[wi].categories[ci].tasks[ti].mode = mode
        markEdited(wi, ci, ti)
        // The user picked this mode: it isn't put back to the one from before This week only.
        weeks[wi].categories[ci].tasks[ti].modeBeforeThisWeekOnly = nil
        keepCategory(wi, ci, for: mode)
        undismissCopies(of: taskID, after: weeks[wi].startDay)
        noteEdit(categoryID)
        save()
    }

    /// The saved weeks after `start` forget that the task, or a copy of it, was deleted from
    /// them, so syncing with the week before brings it back. Copies are found by their links
    /// (`carriedFrom`, `repeatsFrom`), in saved weeks and the previews shown (a copy deleted two
    /// weeks ahead is recorded by the copy in the week between). Returns whether any forgot.
    @discardableResult
    private func undismissCopies(of taskID: UUID, after start: DayKey) -> Bool {
        var links: [UUID: [UUID]] = [:]
        for week in weeks + Array(lastPreviews.values) where week.startDay > start {
            for task in week.categories.flatMap(\.tasks) {
                links[task.id] = [task.carriedFrom, task.repeatsFrom].compactMap { $0 }
            }
        }
        func isTaskOrCopy(_ id: UUID) -> Bool {
            var seen: Set<UUID> = [], queue = [id]
            while let next = queue.popLast() {
                guard seen.insert(next).inserted else { continue }
                if next == taskID { return true }
                queue += links[next] ?? []
            }
            return false
        }
        var changed = false
        for wi in weeks.indices where weeks[wi].startDay > start {
            guard let dismissed = weeks[wi].dismissedCarryOvers, dismissed.contains(where: isTaskOrCopy) else { continue }
            weeks[wi].dismissedCarryOvers = dismissed.filter { !isTaskOrCopy($0) }
            changed = true
        }
        return changed
    }

    /// Folds a list's items away, or opens it again. A view choice, not an edit: the task
    /// isn't made the user's own and the card's edit time stays. Untouched copies in later
    /// saved weeks fold with it (`fold(_:from:folded:in:)`), so the list is still folded next
    /// week. While a delete can be undone, the fold is made in the weeks Undo puts back too:
    /// it keeps the Undo, and Undo doesn't open the list again.
    func setListFolded(categoryID: UUID, taskID: UUID, folded: Bool) {
        guard let task = viewedTask(categoryID, taskID), task.taskType == .list, task.isListFolded != folded,
              let wi = editableSelectedWeekIndex() else { return }
        let start = weeks[wi].startDay
        Self.fold(taskID, from: start, folded: folded, in: &weeks)
        if weeksBeforeDelete != nil { Self.fold(taskID, from: start, folded: folded, in: &weeksBeforeDelete!) }
        save(keepsUndo: true)
    }

    /// Sets the fold of the list `taskID` in the week starting `start` and of its untouched
    /// copies in the saved weeks after it (`taskAndUntouchedCopies`).
    private static func fold(_ taskID: UUID, from start: DayKey, folded: Bool, in weeks: inout [Week]) {
        for (wi, ci, ti) in taskAndUntouchedCopies(of: taskID, from: start, in: weeks, following: { $0.taskType == .list }) {
            weeks[wi].categories[ci].tasks[ti].isListFolded = folded
        }
    }

    /// Pins a task to the top of its card, or unpins it, up to `Category.maxPins` a card.
    /// Like a fold: not an edit (no edited mark, no card edit time), a delete's Undo stays
    /// with the pin made in its snapshot too, and the task's untouched copies in later saved
    /// weeks take it (except in a card already holding two pins).
    func setTaskPinned(categoryID: UUID, taskID: UUID, pinned: Bool) {
        guard let task = viewedTask(categoryID, taskID), task.isPinned != pinned,
              let wi = editableSelectedWeekIndex(),
              let category = weeks[wi].categories.first(where: { $0.id == categoryID }),
              !pinned || category.pinnedTaskCount < Category.maxPins else { return }
        let start = weeks[wi].startDay
        Self.pin(taskID, from: start, pinned: pinned, in: &weeks)
        if weeksBeforeDelete != nil {
            // Undo's copy still holds a deleted pinned task: where its card has two pinned
            // already, Undo would bring back a third, so it ends instead.
            let full = weeksBeforeDelete!.first { $0.startDay == start }?.categories.first { $0.id == categoryID }
                .map { $0.pinnedTaskCount >= Category.maxPins } ?? false
            if pinned && full { clearUndo() } else { Self.pin(taskID, from: start, pinned: pinned, in: &weeksBeforeDelete!) }
        }
        save(keepsUndo: true)
    }

    private static func pin(_ taskID: UUID, from start: DayKey, pinned: Bool, in weeks: inout [Week]) {
        for (wi, ci, ti) in taskAndUntouchedCopies(of: taskID, from: start, in: weeks) {
            guard !pinned || weeks[wi].startDay == start
                    || weeks[wi].categories[ci].pinnedTaskCount < Category.maxPins else { continue }
            weeks[wi].categories[ci].tasks[ti].isPinned = pinned
        }
    }

    /// The task `taskID` in the week starting `start`, then its untouched copies in the saved
    /// weeks after it, found week by week along their links (a week skipped while unsaved
    /// links straight to the week before it). A copy the user changed is their own and is
    /// left out, and so are its copies; `following` leaves out others.
    private static func taskAndUntouchedCopies(of taskID: UUID, from start: DayKey, in weeks: [Week],
                                               following: (ChecklistTask) -> Bool = { _ in true }) -> [(Int, Int, Int)] {
        var sources: Set<UUID> = [taskID]
        var found: [(Int, Int, Int)] = []
        let order = weeks.indices.filter { weeks[$0].startDay >= start }.sorted { weeks[$0].startDay < weeks[$1].startDay }
        for wi in order {
            for ci in weeks[wi].categories.indices {
                for ti in weeks[wi].categories[ci].tasks.indices {
                    let task = weeks[wi].categories[ci].tasks[ti]
                    let isTheTask = weeks[wi].startDay == start && task.id == taskID
                    let isCopy = weeks[wi].startDay > start && !task.isUserEdited && following(task)
                        && [task.carriedFrom, task.repeatsFrom].contains { $0.map(sources.contains) == true }
                    guard isTheTask || isCopy else { continue }
                    found.append((wi, ci, ti))
                    if isCopy { sources.insert(task.id) }
                }
            }
        }
        return found
    }

    /// Pins a card to the start of the grid, or unpins it, from the viewed week on: the
    /// cards with its name in later weeks too (except in a week already holding two pins).
    /// Up to `Category.maxPins` a week. Not an edit (no card edit time, so the card sort
    /// doesn't change), and a delete's Undo stays, with the pin made in its snapshot too.
    func setCategoryPinned(categoryID: UUID, pinned: Bool) {
        guard let wi = editableSelectedWeekIndex(),
              let category = weeks[wi].categories.first(where: { $0.id == categoryID }),
              category.isPinned != pinned,
              !pinned || weeks[wi].categories.filter(\.isPinned).count < Category.maxPins else { return }
        let start = weeks[wi].startDay
        Self.pinCategory(categoryID, named: category.name, from: start, pinned: pinned, in: &weeks)
        if weeksBeforeDelete != nil {
            // As with tasks: a deleted pinned card in Undo's copy would make a third.
            let full = (weeksBeforeDelete!.first { $0.startDay == start }?.categories.filter(\.isPinned).count ?? 0) >= Category.maxPins
            if pinned && full { clearUndo() } else {
                Self.pinCategory(categoryID, named: category.name, from: start, pinned: pinned, in: &weeksBeforeDelete!)
            }
        }
        save(keepsUndo: true)
    }

    private static func pinCategory(_ categoryID: UUID, named name: String, from start: DayKey, pinned: Bool,
                                    in weeks: inout [Week]) {
        for wi in weeks.indices where weeks[wi].startDay >= start {
            let isViewed = weeks[wi].startDay == start
            for ci in weeks[wi].categories.indices {
                let category = weeks[wi].categories[ci]
                guard isViewed ? category.id == categoryID : category.name == name, category.isPinned != pinned,
                      !pinned || isViewed || weeks[wi].categories.filter(\.isPinned).count < Category.maxPins else { continue }
                weeks[wi].categories[ci].isPinned = pinned
            }
        }
    }

    func renameTask(categoryID: UUID, taskID: UUID, newTitle: String) {
        guard viewedTask(categoryID, taskID)?.title != newTitle,
              let wi = editableSelectedWeekIndex(),
              let ci = weeks[wi].categories.firstIndex(where: { $0.id == categoryID }),
              let ti = weeks[wi].categories[ci].tasks.firstIndex(where: { $0.id == taskID }) else { return }
        // A copy's rename changes only its name (`hasOwnTitle`); another task's makes it the
        // user's own as any change does.
        let source = viewedTask(categoryID, taskID).flatMap { $0.carriedFrom ?? $0.repeatsFrom }
        let sourceTitle = source.flatMap(anyTaskTitle)
        let rename = { (task: inout ChecklistTask) -> Bool in
            task.title = newTitle
            if task.carriedFrom != nil || task.repeatsFrom != nil {
                task.hasOwnTitle = newTitle != sourceTitle
            } else {
                Self.markEdited(&task)
            }
            return true
        }
        _ = rename(&weeks[wi].categories[ci].tasks[ti])
        noteEdit(categoryID)
        save(keepsUndo: changeInUndo(week: weeks[wi].startDay, taskID: taskID, rename))
    }

    /// The name of the task with this ID in any saved week or preview shown, if there is one.
    private func anyTaskTitle(_ id: UUID) -> String? {
        for week in weeks + Array(lastPreviews.values) {
            for category in week.categories {
                if let task = category.tasks.first(where: { $0.id == id }) { return task.title }
            }
        }
        return nil
    }

    /// While a delete can be undone, a rename is made in the weeks Undo puts back too, when
    /// the task is there, so it keeps the Undo: a rename finished after a delete (its field
    /// was still open) never costs the delete its Undo, and Undo doesn't take the rename
    /// back. `change` returns whether it found what it changes. Returns whether it was made.
    private func changeInUndo(week start: DayKey, taskID: UUID, _ change: (inout ChecklistTask) -> Bool) -> Bool {
        guard var saved = weeksBeforeDelete,
              let wi = saved.firstIndex(where: { $0.startDay == start }),
              let ci = saved[wi].categories.firstIndex(where: { $0.tasks.contains { $0.id == taskID } }),
              let ti = saved[wi].categories[ci].tasks.firstIndex(where: { $0.id == taskID }),
              change(&saved[wi].categories[ci].tasks[ti]) else { return false }
        weeksBeforeDelete = saved
        return true
    }

    /// The user changed this task in its own week: syncing leaves it alone from now on. In a
    /// This week only card the change is also kept in what the card remembers, so turning
    /// the switch off (which puts back the mode and this mark from before) keeps it theirs.
    private func markEdited(_ wi: Int, _ ci: Int, _ ti: Int) {
        Self.markEdited(&weeks[wi].categories[ci].tasks[ti])
    }

    private static func markEdited(_ task: inout ChecklistTask) {
        task.isUserEdited = true
        task.modeBeforeThisWeekOnly?.wasUserEdited = true
    }

    // MARK: - Goal Task CRUD

    func updateTaskType(categoryID: UUID, taskID: UUID, type: TaskType) {
        guard viewedTask(categoryID, taskID)?.taskType != type,
              let wi = editableSelectedWeekIndex(),
              let ci = weeks[wi].categories.firstIndex(where: { $0.id == categoryID }),
              let ti = weeks[wi].categories[ci].tasks.firstIndex(where: { $0.id == taskID }) else { return }
        weeks[wi].categories[ci].tasks[ti].taskType = type
        markEdited(wi, ci, ti)
        // A task that becomes a list starts open, so its first items can be added.
        weeks[wi].categories[ci].tasks[ti].isListFolded = false
        if type != .goal {
            weeks[wi].categories[ci].tasks[ti].goalTarget = nil
            weeks[wi].categories[ci].tasks[ti].goalProgress = nil
            weeks[wi].categories[ci].tasks[ti].goalUnit = nil
            weeks[wi].categories[ci].tasks[ti].goalUnitKind = nil
            weeks[wi].categories[ci].tasks[ti].goalStep = nil
            weeks[wi].categories[ci].tasks[ti].goalDays = nil
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
        let target = GoalUnitKind.cleaned(min(target, GoalUnitKind.maxValue))
        let unit = unit.trimmingCharacters(in: .whitespaces)
        let kind = kind ?? (unit.isEmpty ? .quantity : .custom)
        // Nothing changed (Save Goal tapped as it was): not an edit, so a copy keeps following.
        if let task = viewedTask(categoryID, taskID), task.goalTarget == target, task.goalKind == kind,
           (task.goalUnit ?? "") == (kind == .custom ? unit : "") { return }
        guard let wi = editableSelectedWeekIndex(),
              let ci = weeks[wi].categories.firstIndex(where: { $0.id == categoryID }),
              let ti = weeks[wi].categories[ci].tasks.firstIndex(where: { $0.id == taskID }) else { return }
        weeks[wi].categories[ci].tasks[ti].goalTarget = target
        markEdited(wi, ci, ti)
        weeks[wi].categories[ci].tasks[ti].goalUnitKind = kind
        weeks[wi].categories[ci].tasks[ti].goalUnit = kind == .custom ? unit : nil
        // Auto-update completion
        weeks[wi].categories[ci].tasks[ti].isCompleted = weeks[wi].categories[ci].tasks[ti].goalIsComplete
        noteEdit(categoryID)
        save()
    }

    /// Sets the step for a goal's + and − buttons; nil (or not above zero) means automatic.
    /// `days` is the goal's days a week (`goalDays`): with a step, the target follows step ×
    /// days in the editor; without one, + steps by the target ÷ days. nil is 7 days.
    func setGoalStep(categoryID: UUID, taskID: UUID, step: Double?, days: Int? = nil) {
        let step = step.flatMap { $0.isFinite && $0 > 0 ? GoalUnitKind.cleaned(min($0, GoalUnitKind.maxValue)) : nil }
        let days = days.flatMap { (1...7).contains($0) ? $0 : nil }
        // (No days and 7 are the same: the editor's toggle saves 7.)
        guard viewedTask(categoryID, taskID).map({ $0.goalStep != step || ($0.goalDays ?? 7) != (days ?? 7) }) == true,
              let wi = editableSelectedWeekIndex(),
              let ci = weeks[wi].categories.firstIndex(where: { $0.id == categoryID }),
              let ti = weeks[wi].categories[ci].tasks.firstIndex(where: { $0.id == taskID }) else { return }
        weeks[wi].categories[ci].tasks[ti].goalStep = step
        weeks[wi].categories[ci].tasks[ti].goalDays = days
        markEdited(wi, ci, ti)
        noteEdit(categoryID)
        save()
    }

    func updateGoalProgress(categoryID: UUID, taskID: UUID, progress: Double) {
        guard progress.isFinite, progress >= 0 else { return }
        let progress = GoalUnitKind.cleaned(min(progress, GoalUnitKind.maxValue))
        guard let wi = editableSelectedWeekIndex(),
              let ci = weeks[wi].categories.firstIndex(where: { $0.id == categoryID }),
              let ti = weeks[wi].categories[ci].tasks.firstIndex(where: { $0.id == taskID }) else { return }
        weeks[wi].categories[ci].tasks[ti].goalProgress = progress
        // A repeating copy keeps its own progress while following its source. A carried
        // copy's progress comes from its source, so entering some makes the copy the user's.
        if weeks[wi].categories[ci].tasks[ti].syncMode != .repeating {
            markEdited(wi, ci, ti)
        }
        weeks[wi].categories[ci].tasks[ti].isCompleted = weeks[wi].categories[ci].tasks[ti].goalIsComplete
        noteEdit(categoryID)
        save()
    }

    // MARK: - Sub-Task CRUD

    /// Returns whether it was added (not when the task isn't in the viewed week any more).
    @discardableResult
    func addSubtask(categoryID: UUID, taskID: UUID, title: String) -> Bool {
        guard let wi = editableSelectedWeekIndex(),
              let ci = weeks[wi].categories.firstIndex(where: { $0.id == categoryID }),
              let ti = weeks[wi].categories[ci].tasks.firstIndex(where: { $0.id == taskID }) else { return false }
        weeks[wi].categories[ci].tasks[ti].subtasks.append(SubTask(title: title))
        subtaskChecksBeforeCheck[taskID] = nil  // its items changed since the task was checked
        markEdited(wi, ci, ti)
        // A new unchecked item means the task isn't done yet.
        weeks[wi].categories[ci].tasks[ti].isCompleted = false
        noteEdit(categoryID)
        save()
        return true
    }

    func toggleSubtask(categoryID: UUID, taskID: UUID, subtaskID: UUID) {
        guard let wi = editableSelectedWeekIndex(),
              let ci = weeks[wi].categories.firstIndex(where: { $0.id == categoryID }),
              let ti = weeks[wi].categories[ci].tasks.firstIndex(where: { $0.id == taskID }),
              let si = weeks[wi].categories[ci].tasks[ti].subtasks.firstIndex(where: { $0.id == subtaskID }) else { return }
        weeks[wi].categories[ci].tasks[ti].subtasks[si].isCompleted.toggle()
        subtaskChecksBeforeCheck[taskID] = nil  // unchecking the task now clears, not restores
        // Auto-complete/uncomplete parent based on subtask state
        let task = weeks[wi].categories[ci].tasks[ti]
        if !task.subtasks.isEmpty {
            weeks[wi].categories[ci].tasks[ti].isCompleted = task.subtasks.allSatisfy(\.isCompleted)
        }
        noteEdit(categoryID)
        save()
    }

    /// With `undoable` false (taking back an item just added, from its Duplicate note)
    /// there's no Undo message of its own.
    func deleteSubtask(categoryID: UUID, taskID: UUID, subtaskID: UUID, undoable: Bool = true) {
        guard let wi = editableSelectedWeekIndex(),
              let ci = weeks[wi].categories.firstIndex(where: { $0.id == categoryID }),
              let ti = weeks[wi].categories[ci].tasks.firstIndex(where: { $0.id == taskID }) else { return }
        if undoable, let subtask = weeks[wi].categories[ci].tasks[ti].subtasks.first(where: { $0.id == subtaskID }) {
            rememberForUndo("“\(subtask.title)”")
        }
        weeks[wi].categories[ci].tasks[ti].subtasks.removeAll { $0.id == subtaskID }
        subtaskChecksBeforeCheck[taskID] = nil
        markEdited(wi, ci, ti)
        // Deleting the last unchecked item completes the task, as checking it would.
        let task = weeks[wi].categories[ci].tasks[ti]
        if !task.subtasks.isEmpty {
            weeks[wi].categories[ci].tasks[ti].isCompleted = task.subtasks.allSatisfy(\.isCompleted)
        }
        noteEdit(categoryID)
        if undoable { saveDelete() } else { save() }
    }

    func renameSubtask(categoryID: UUID, taskID: UUID, subtaskID: UUID, newTitle: String) {
        guard viewedTask(categoryID, taskID)?.subtasks.first(where: { $0.id == subtaskID })?.title != newTitle,
              let wi = editableSelectedWeekIndex(),
              let ci = weeks[wi].categories.firstIndex(where: { $0.id == categoryID }),
              let ti = weeks[wi].categories[ci].tasks.firstIndex(where: { $0.id == taskID }),
              weeks[wi].categories[ci].tasks[ti].subtasks.contains(where: { $0.id == subtaskID }) else { return }
        let rename = { (task: inout ChecklistTask) -> Bool in
            guard let si = task.subtasks.firstIndex(where: { $0.id == subtaskID }) else { return false }
            task.subtasks[si].title = newTitle
            Self.markEdited(&task)
            return true
        }
        _ = rename(&weeks[wi].categories[ci].tasks[ti])
        noteEdit(categoryID)
        save(keepsUndo: changeInUndo(week: weeks[wi].startDay, taskID: taskID, rename))
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
        // The copy put back is from before the delete: a task whose last day has passed
        // since (midnight came) goes again.
        removeExpiredTasks()
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
