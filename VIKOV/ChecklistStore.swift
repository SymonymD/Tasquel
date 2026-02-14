import Foundation
import Observation
import SwiftUI

@Observable
final class ChecklistStore {

    var weeks: [Week] = []
    var selectedDate: Date = Date()
    var savedCategories: [CategoryTemplate] = []
    var appearanceMode: AppearanceMode = .system
    var hasSeenWelcome: Bool = false

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
        case .dark: .dark
        }
    }

    private let fileURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appending(path: "checklist.json")
    }()

    private let settingsURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appending(path: "settings.json")
    }()

    init() {
        loadSettings()
        if savedCategories.isEmpty {
            savedCategories = CategoryTemplate.starters
            saveSettings()
        }
        load()
        ensureWeekExists(for: Date())
    }

    // MARK: - Persistence

    func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path()) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            weeks = try decoder.decode([Week].self, from: data)
            sortWeeks()
        } catch {
            print("Failed to load: \(error)")
        }
    }

    func save() {
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
        var hasSeenWelcome: Bool
    }

    func loadSettings() {
        guard FileManager.default.fileExists(atPath: settingsURL.path()) else { return }
        do {
            let data = try Data(contentsOf: settingsURL)
            let settings = try JSONDecoder().decode(Settings.self, from: data)
            savedCategories = settings.savedCategories
            appearanceMode = settings.appearanceMode
            hasSeenWelcome = settings.hasSeenWelcome
        } catch {
            print("Failed to load settings: \(error)")
        }
    }

    func saveSettings() {
        do {
            let settings = Settings(
                savedCategories: savedCategories,
                appearanceMode: appearanceMode,
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

            let repeatingTasks = category.tasks
                .filter { $0.mode == .repeating }
                .map { ChecklistTask(title: $0.title, mode: .repeating) }

            let carryOverTasks = category.tasks
                .filter { $0.mode == .carryOver && !$0.isCompleted }
                .map { ChecklistTask(title: $0.title, mode: .carryOver) }

            newCategory.tasks = repeatingTasks + carryOverTasks
            return newCategory
        }
    }

    func navigateToDate(_ date: Date) {
        selectedDate = date
        ensureWeekExists(for: date)
    }

    func navigateWeek(by offset: Int) {
        guard let newDate = Calendar.current.date(byAdding: .weekOfYear, value: offset, to: selectedDate) else { return }
        navigateToDate(newDate)
    }

    // MARK: - Category CRUD

    func addCategory(name: String, symbol: String) {
        guard let week = selectedWeek,
              let wi = weeks.firstIndex(where: { $0.id == week.id }) else { return }
        weeks[wi].categories.append(Category(name: name, symbol: symbol))
        save()
    }

    func deleteCategory(_ categoryID: UUID) {
        guard let week = selectedWeek,
              let wi = weeks.firstIndex(where: { $0.id == week.id }) else { return }
        weeks[wi].categories.removeAll { $0.id == categoryID }
        save()
    }

    func saveCategoryAsTemplate(_ categoryID: UUID) {
        guard let week = selectedWeek,
              let category = week.categories.first(where: { $0.id == categoryID }) else { return }
        // Don't duplicate
        if !savedCategories.contains(where: { $0.name == category.name }) {
            addSavedCategory(name: category.name, symbol: category.symbol)
        }
    }

    func renameCategory(_ categoryID: UUID, newName: String) {
        guard let week = selectedWeek,
              let wi = weeks.firstIndex(where: { $0.id == week.id }),
              let ci = weeks[wi].categories.firstIndex(where: { $0.id == categoryID }) else { return }
        weeks[wi].categories[ci].name = newName
        save()
    }

    // MARK: - Task CRUD

    func addTask(categoryID: UUID, title: String, mode: TaskMode = .carryOver) {
        guard let week = selectedWeek,
              let wi = weeks.firstIndex(where: { $0.id == week.id }),
              let ci = weeks[wi].categories.firstIndex(where: { $0.id == categoryID }) else { return }
        weeks[wi].categories[ci].tasks.append(ChecklistTask(title: title, mode: mode))
        save()
    }

    func toggleTask(categoryID: UUID, taskID: UUID) {
        guard let week = selectedWeek,
              let wi = weeks.firstIndex(where: { $0.id == week.id }),
              let ci = weeks[wi].categories.firstIndex(where: { $0.id == categoryID }),
              let ti = weeks[wi].categories[ci].tasks.firstIndex(where: { $0.id == taskID }) else { return }
        weeks[wi].categories[ci].tasks[ti].isCompleted.toggle()
        save()
    }

    func deleteTask(categoryID: UUID, taskID: UUID) {
        guard let week = selectedWeek,
              let wi = weeks.firstIndex(where: { $0.id == week.id }),
              let ci = weeks[wi].categories.firstIndex(where: { $0.id == categoryID }) else { return }
        weeks[wi].categories[ci].tasks.removeAll { $0.id == taskID }
        save()
    }

    func updateTaskMode(categoryID: UUID, taskID: UUID, mode: TaskMode) {
        guard let week = selectedWeek,
              let wi = weeks.firstIndex(where: { $0.id == week.id }),
              let ci = weeks[wi].categories.firstIndex(where: { $0.id == categoryID }),
              let ti = weeks[wi].categories[ci].tasks.firstIndex(where: { $0.id == taskID }) else { return }
        weeks[wi].categories[ci].tasks[ti].mode = mode
        save()
    }

    func renameTask(categoryID: UUID, taskID: UUID, newTitle: String) {
        guard let week = selectedWeek,
              let wi = weeks.firstIndex(where: { $0.id == week.id }),
              let ci = weeks[wi].categories.firstIndex(where: { $0.id == categoryID }),
              let ti = weeks[wi].categories[ci].tasks.firstIndex(where: { $0.id == taskID }) else { return }
        weeks[wi].categories[ci].tasks[ti].title = newTitle
        save()
    }

    // MARK: - Helpers

    private func sortWeeks() {
        weeks.sort { $0.startDate > $1.startDate }
    }
}
