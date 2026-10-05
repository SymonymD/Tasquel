import Foundation
import Observation
import SwiftUI

@Observable
final class ChecklistStore {

    var weeks: [Week] = []
    var selectedDate: Date = Date()
    var savedCategories: [CategoryTemplate] = []
    var appearanceMode: AppearanceMode = .system
    var retroColor: RetroColor = .green
    var hasSeenWelcome: Bool = false
    var userName: String = ""
    private(set) var weekLoadError: String?
    private(set) var settingsLoadError: String?

    var persistenceError: String? { weekLoadError ?? settingsLoadError }

    var hasSetName: Bool { !userName.isEmpty }

    var selectedWeek: Week? {
        let monday = Week.mondayOfWeek(containing: selectedDate)
        return weeks.first { Calendar.current.isDate($0.startDate, inSameDayAs: monday) }
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

    /// `directory` and `defaults` are injectable so tests never touch the app's real data.
    init(directory: URL = .documentsDirectory, defaults: UserDefaults = .standard) {
        fileURL = directory.appending(path: "checklist.json")
        settingsURL = directory.appending(path: "settings.json")
        self.defaults = defaults
        userName = defaults.string(forKey: "userName") ?? ""
        loadAndPrepare()
    }

    /// Init order matters: settings → seed starter templates → weeks → current week.
    /// Stops at the first unreadable file so defaults never overwrite it.
    private func loadAndPrepare() {
        loadSettings()
        guard settingsLoadError == nil else { return }
        seedStarterTemplates()
        load()
        guard weekLoadError == nil else { return }
        let currentWeek = ensureWeekExists(for: Date())
        migrateStartersIfNeeded(into: currentWeek)
    }

    private func seedStarterTemplates() {
        if savedCategories.isEmpty {
            savedCategories = CategoryTemplate.starters
            saveSettings()
        } else {
            // Ensure any new starters added in updates are present
            var addedStarters: [CategoryTemplate] = []
            for starter in CategoryTemplate.starters {
                if !savedCategories.contains(where: { $0.name == starter.name }) {
                    savedCategories.append(CategoryTemplate(name: starter.name, symbol: starter.symbol))
                    addedStarters.append(starter)
                }
            }
            if !addedStarters.isEmpty { saveSettings() }
        }
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
            weeks = try decoder.decode([Week].self, from: data)
            sortWeeks()
            weekLoadError = nil
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
                hasSeenWelcome: hasSeenWelcome
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

    func setUserName(_ name: String) {
        userName = name
        defaults.set(name, forKey: "userName")
    }

    // MARK: - Saved Category Templates

    func addSavedCategory(name: String, symbol: String) {
        let template = CategoryTemplate(name: name, symbol: symbol)
        savedCategories.append(template)
        saveSettings()
    }

    func removeSavedCategory(_ templateID: UUID) {
        savedCategories.removeAll { $0.id == templateID }
        saveSettings()
    }

    // MARK: - Week Management

    @discardableResult
    func ensureWeekExists(for date: Date) -> Week {
        let monday = Week.mondayOfWeek(containing: date)
        if let existing = weeks.first(where: { Calendar.current.isDate($0.startDate, inSameDayAs: monday) }) {
            return existing
        }

        var newWeek = Week(startDate: monday)

        if let previousWeek = mostRecentWeekBefore(monday) {
            newWeek.categories = rollForwardCategories(from: previousWeek)
        } else {
            // First ever week: seed from saved category templates
            newWeek.categories = savedCategories.map {
                Category(name: $0.name, symbol: $0.symbol)
            }
        }

        weeks.append(newWeek)
        sortWeeks()
        save()
        return newWeek
    }

    private func mostRecentWeekBefore(_ date: Date) -> Week? {
        weeks
            .filter { $0.startDate < date }
            .sorted { $0.startDate > $1.startDate }
            .first
    }

    private func rollForwardCategories(from source: Week) -> [Category] {
        source.categories.map { category in
            var newCategory = Category(name: category.name, symbol: category.symbol)

            // Repeating tasks always carry forward (reset to incomplete)
            let repeatingTasks = category.tasks
                .filter { $0.mode == .repeating }
                .map { task in
                    var newTask = ChecklistTask(title: task.title, mode: .repeating, subtasks: task.subtasks.map { SubTask(title: $0.title) })
                    newTask.taskType = task.taskType
                    newTask.goalTarget = task.goalTarget
                    newTask.goalProgress = 0  // Reset progress for repeating
                    newTask.goalUnit = task.goalUnit
                    return newTask
                }

            // Carry-over tasks only if incomplete
            let carryOverTasks = category.tasks
                .filter { $0.mode == .carryOver && !$0.isCompleted }
                .map { task in
                    var newTask = ChecklistTask(title: task.title, mode: .carryOver, subtasks: task.subtasks.filter { !$0.isCompleted }.map { SubTask(title: $0.title) })
                    newTask.taskType = task.taskType
                    newTask.goalTarget = task.goalTarget
                    newTask.goalProgress = task.goalProgress  // Carry existing progress
                    newTask.goalUnit = task.goalUnit
                    return newTask
                }

            // oneTime tasks never carry forward
            newCategory.tasks = repeatingTasks + carryOverTasks
            return newCategory
        }
    }

    func navigateToDate(_ date: Date) {
        guard persistenceError == nil else { return }
        selectedDate = date
        let week = ensureWeekExists(for: date)
        if week.isFutureWeek {
            syncFutureWeek(for: date)
        }
    }

    /// Sync categories and recurring tasks from the most recent prior week into a future week.
    /// Ensures future weeks always have the same category structure plus any recurring tasks.
    private func syncFutureWeek(for date: Date) {
        let monday = Week.mondayOfWeek(containing: date)
        guard let wi = weeks.firstIndex(where: { Calendar.current.isDate($0.startDate, inSameDayAs: monday) }),
              let sourceWeek = mostRecentWeekBefore(monday) else { return }

        var changed = false

        for sourceCategory in sourceWeek.categories {
            let recurringTasks = sourceCategory.tasks.filter { $0.mode == .repeating }

            if let ci = weeks[wi].categories.firstIndex(where: { $0.name == sourceCategory.name }) {
                // Category exists — add any missing recurring tasks
                let existingTitles = Set(weeks[wi].categories[ci].tasks.filter { $0.mode == .repeating }.map(\.title))
                for task in recurringTasks where !existingTitles.contains(task.title) {
                    var newTask = ChecklistTask(title: task.title, mode: .repeating, subtasks: task.subtasks.map { SubTask(title: $0.title) })
                    newTask.taskType = task.taskType
                    newTask.goalTarget = task.goalTarget
                    newTask.goalProgress = 0
                    newTask.goalUnit = task.goalUnit
                    weeks[wi].categories[ci].tasks.append(newTask)
                    changed = true
                }
            } else {
                // Category missing from future week — add it (with any recurring tasks)
                var newCat = Category(name: sourceCategory.name, symbol: sourceCategory.symbol)
                newCat.tasks = recurringTasks.map { task in
                    var newTask = ChecklistTask(title: task.title, mode: .repeating, subtasks: task.subtasks.map { SubTask(title: $0.title) })
                    newTask.taskType = task.taskType
                    newTask.goalTarget = task.goalTarget
                    newTask.goalProgress = 0
                    newTask.goalUnit = task.goalUnit
                    return newTask
                }
                weeks[wi].categories.append(newCat)
                changed = true
            }
        }

        if changed { save() }
    }

    func navigateWeek(by offset: Int) {
        guard let newDate = Calendar.current.date(byAdding: .weekOfYear, value: offset, to: selectedDate) else { return }
        navigateToDate(newDate)
    }

    func replaceCurrentWeekCategories(with categories: [Category]) {
        guard let week = selectedWeek,
              let wi = weeks.firstIndex(where: { $0.id == week.id }) else { return }
        weeks[wi].categories = categories
        save()
    }

    // MARK: - Category CRUD

    func addCategory(name: String, symbol: String) {
        guard let week = selectedWeek,
              !week.isPastWeek,
              let wi = weeks.firstIndex(where: { $0.id == week.id }) else { return }
        weeks[wi].categories.append(Category(name: name, symbol: symbol))
        save()
    }

    func deleteCategory(_ categoryID: UUID) {
        guard let week = selectedWeek,
              !week.isPastWeek,
              let wi = weeks.firstIndex(where: { $0.id == week.id }) else { return }
        weeks[wi].categories.removeAll { $0.id == categoryID }
        save()
    }

    func saveCategoryAsTemplate(_ categoryID: UUID) {
        guard let week = selectedWeek,
              !week.isPastWeek,
              let category = week.categories.first(where: { $0.id == categoryID }) else { return }
        // Don't duplicate
        if !savedCategories.contains(where: { $0.name == category.name }) {
            addSavedCategory(name: category.name, symbol: category.symbol)
        }
    }

    func renameCategory(_ categoryID: UUID, newName: String) {
        guard let week = selectedWeek,
              !week.isPastWeek,
              let wi = weeks.firstIndex(where: { $0.id == week.id }),
              let ci = weeks[wi].categories.firstIndex(where: { $0.id == categoryID }) else { return }
        weeks[wi].categories[ci].name = newName
        save()
    }

    // MARK: - Task CRUD

    func addTask(categoryID: UUID, title: String, mode: TaskMode = .carryOver) {
        guard let week = selectedWeek,
              !week.isPastWeek,
              let wi = weeks.firstIndex(where: { $0.id == week.id }),
              let ci = weeks[wi].categories.firstIndex(where: { $0.id == categoryID }) else { return }
        weeks[wi].categories[ci].tasks.append(ChecklistTask(title: title, mode: mode))
        save()
    }

    func toggleTask(categoryID: UUID, taskID: UUID) {
        guard let week = selectedWeek,
              !week.isPastWeek,
              let wi = weeks.firstIndex(where: { $0.id == week.id }),
              let ci = weeks[wi].categories.firstIndex(where: { $0.id == categoryID }),
              let ti = weeks[wi].categories[ci].tasks.firstIndex(where: { $0.id == taskID }) else { return }
        weeks[wi].categories[ci].tasks[ti].isCompleted.toggle()
        save()
    }

    func deleteTask(categoryID: UUID, taskID: UUID) {
        guard let week = selectedWeek,
              !week.isPastWeek,
              let wi = weeks.firstIndex(where: { $0.id == week.id }),
              let ci = weeks[wi].categories.firstIndex(where: { $0.id == categoryID }) else { return }
        weeks[wi].categories[ci].tasks.removeAll { $0.id == taskID }
        save()
    }

    func updateTaskMode(categoryID: UUID, taskID: UUID, mode: TaskMode) {
        guard let week = selectedWeek,
              !week.isPastWeek,
              let wi = weeks.firstIndex(where: { $0.id == week.id }),
              let ci = weeks[wi].categories.firstIndex(where: { $0.id == categoryID }),
              let ti = weeks[wi].categories[ci].tasks.firstIndex(where: { $0.id == taskID }) else { return }
        weeks[wi].categories[ci].tasks[ti].mode = mode
        save()
    }

    func renameTask(categoryID: UUID, taskID: UUID, newTitle: String) {
        guard let week = selectedWeek,
              !week.isPastWeek,
              let wi = weeks.firstIndex(where: { $0.id == week.id }),
              let ci = weeks[wi].categories.firstIndex(where: { $0.id == categoryID }),
              let ti = weeks[wi].categories[ci].tasks.firstIndex(where: { $0.id == taskID }) else { return }
        weeks[wi].categories[ci].tasks[ti].title = newTitle
        save()
    }

    // MARK: - Goal Task CRUD

    func updateTaskType(categoryID: UUID, taskID: UUID, type: TaskType) {
        guard let week = selectedWeek,
              !week.isPastWeek,
              let wi = weeks.firstIndex(where: { $0.id == week.id }),
              let ci = weeks[wi].categories.firstIndex(where: { $0.id == categoryID }),
              let ti = weeks[wi].categories[ci].tasks.firstIndex(where: { $0.id == taskID }) else { return }
        weeks[wi].categories[ci].tasks[ti].taskType = type
        if type == .checkbox {
            weeks[wi].categories[ci].tasks[ti].goalTarget = nil
            weeks[wi].categories[ci].tasks[ti].goalProgress = nil
            weeks[wi].categories[ci].tasks[ti].goalUnit = nil
        }
        save()
    }

    func setGoalTarget(categoryID: UUID, taskID: UUID, target: Double, unit: String) {
        guard target.isFinite, target > 0 else { return }
        guard let week = selectedWeek,
              !week.isPastWeek,
              let wi = weeks.firstIndex(where: { $0.id == week.id }),
              let ci = weeks[wi].categories.firstIndex(where: { $0.id == categoryID }),
              let ti = weeks[wi].categories[ci].tasks.firstIndex(where: { $0.id == taskID }) else { return }
        weeks[wi].categories[ci].tasks[ti].goalTarget = target
        weeks[wi].categories[ci].tasks[ti].goalUnit = unit
        // Auto-update completion
        let progress = weeks[wi].categories[ci].tasks[ti].goalProgress ?? 0
        weeks[wi].categories[ci].tasks[ti].isCompleted = progress >= target
        save()
    }

    func updateGoalProgress(categoryID: UUID, taskID: UUID, progress: Double) {
        guard progress.isFinite, progress >= 0 else { return }
        guard let week = selectedWeek,
              !week.isPastWeek,
              let wi = weeks.firstIndex(where: { $0.id == week.id }),
              let ci = weeks[wi].categories.firstIndex(where: { $0.id == categoryID }),
              let ti = weeks[wi].categories[ci].tasks.firstIndex(where: { $0.id == taskID }) else { return }
        weeks[wi].categories[ci].tasks[ti].goalProgress = progress
        let target = weeks[wi].categories[ci].tasks[ti].goalTarget ?? 0
        weeks[wi].categories[ci].tasks[ti].isCompleted = target > 0 && progress >= target
        save()
    }

    // MARK: - Category Deletion Options

    func deleteCategoryEntirely(_ categoryID: UUID) {
        guard selectedWeek?.isPastWeek == false else { return }
        // Capture the name before deletion — deleteCategory removes it from the week,
        // so looking it up afterward would always fail.
        let categoryName = selectedWeek?.categories.first(where: { $0.id == categoryID })?.name

        // Remove from current week
        deleteCategory(categoryID)

        // Remove matching saved template
        if let name = categoryName {
            savedCategories.removeAll { $0.name == name }
            saveSettings()
        }
    }

    // MARK: - Sub-Task CRUD

    func addSubtask(categoryID: UUID, taskID: UUID, title: String) {
        guard let week = selectedWeek,
              !week.isPastWeek,
              let wi = weeks.firstIndex(where: { $0.id == week.id }),
              let ci = weeks[wi].categories.firstIndex(where: { $0.id == categoryID }),
              let ti = weeks[wi].categories[ci].tasks.firstIndex(where: { $0.id == taskID }) else { return }
        weeks[wi].categories[ci].tasks[ti].subtasks.append(SubTask(title: title))
        save()
    }

    func toggleSubtask(categoryID: UUID, taskID: UUID, subtaskID: UUID) {
        guard let week = selectedWeek,
              !week.isPastWeek,
              let wi = weeks.firstIndex(where: { $0.id == week.id }),
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
        guard let week = selectedWeek,
              !week.isPastWeek,
              let wi = weeks.firstIndex(where: { $0.id == week.id }),
              let ci = weeks[wi].categories.firstIndex(where: { $0.id == categoryID }),
              let ti = weeks[wi].categories[ci].tasks.firstIndex(where: { $0.id == taskID }) else { return }
        weeks[wi].categories[ci].tasks[ti].subtasks.removeAll { $0.id == subtaskID }
        save()
    }

    func renameSubtask(categoryID: UUID, taskID: UUID, subtaskID: UUID, newTitle: String) {
        guard let week = selectedWeek,
              !week.isPastWeek,
              let wi = weeks.firstIndex(where: { $0.id == week.id }),
              let ci = weeks[wi].categories.firstIndex(where: { $0.id == categoryID }),
              let ti = weeks[wi].categories[ci].tasks.firstIndex(where: { $0.id == taskID }),
              let si = weeks[wi].categories[ci].tasks[ti].subtasks.firstIndex(where: { $0.id == subtaskID }) else { return }
        weeks[wi].categories[ci].tasks[ti].subtasks[si].title = newTitle
        save()
    }

    // MARK: - Helpers

    private func sortWeeks() {
        weeks.sort { $0.startDate > $1.startDate }
    }
}
