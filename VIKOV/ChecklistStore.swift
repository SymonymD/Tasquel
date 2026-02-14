import Foundation
import Observation

@Observable
final class ChecklistStore {

    var weeks: [Week] = []

    private let fileURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appending(path: "checklist.json")
    }()

    init() {
        load()
        ensureCurrentWeekExists()
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

    // MARK: - Week Management

    func ensureCurrentWeekExists() {
        let currentMonday = Week.mondayOfWeek(containing: Date())
        if !weeks.contains(where: { Calendar.current.isDate($0.startDate, inSameDayAs: currentMonday) }) {
            var newWeek = Week(startDate: currentMonday)
            // Carry forward incomplete tasks from the most recent week
            if let lastWeek = weeks.first {
                newWeek.categories = carryForwardCategories(from: lastWeek)
            }
            weeks.insert(newWeek, at: 0)
            save()
        }
    }

    private func carryForwardCategories(from sourceWeek: Week) -> [Category] {
        sourceWeek.categories.compactMap { category in
            let incompleteTasks = category.tasks
                .filter { !$0.isCompleted }
                .map { ChecklistTask(title: $0.title) }
            // Keep the category even if empty, so structure carries forward
            return Category(name: category.name, tasks: incompleteTasks)
        }
    }

    func createNewWeek() {
        let currentMonday = Week.mondayOfWeek(containing: Date())
        // Find the most recent Monday that doesn't already exist
        var candidate = currentMonday
        while weeks.contains(where: { Calendar.current.isDate($0.startDate, inSameDayAs: candidate) }) {
            candidate = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: candidate)!
        }
        // Actually, the user probably wants the current week. If it exists, do nothing.
        // For manual carry-forward, we just ensure current week exists.
        ensureCurrentWeekExists()
    }

    func deleteWeek(_ week: Week) {
        weeks.removeAll { $0.id == week.id }
        save()
    }

    // MARK: - Category CRUD

    func addCategory(to weekID: UUID, name: String) {
        guard let wi = weeks.firstIndex(where: { $0.id == weekID }) else { return }
        weeks[wi].categories.append(Category(name: name))
        save()
    }

    func renameCategory(weekID: UUID, categoryID: UUID, newName: String) {
        guard let wi = weeks.firstIndex(where: { $0.id == weekID }),
              let ci = weeks[wi].categories.firstIndex(where: { $0.id == categoryID }) else { return }
        weeks[wi].categories[ci].name = newName
        save()
    }

    func deleteCategory(weekID: UUID, categoryID: UUID) {
        guard let wi = weeks.firstIndex(where: { $0.id == weekID }) else { return }
        weeks[wi].categories.removeAll { $0.id == categoryID }
        save()
    }

    // MARK: - Task CRUD

    func addTask(weekID: UUID, categoryID: UUID, title: String) {
        guard let wi = weeks.firstIndex(where: { $0.id == weekID }),
              let ci = weeks[wi].categories.firstIndex(where: { $0.id == categoryID }) else { return }
        weeks[wi].categories[ci].tasks.append(ChecklistTask(title: title))
        save()
    }

    func toggleTask(weekID: UUID, categoryID: UUID, taskID: UUID) {
        guard let wi = weeks.firstIndex(where: { $0.id == weekID }),
              let ci = weeks[wi].categories.firstIndex(where: { $0.id == categoryID }),
              let ti = weeks[wi].categories[ci].tasks.firstIndex(where: { $0.id == taskID }) else { return }
        weeks[wi].categories[ci].tasks[ti].isCompleted.toggle()
        save()
    }

    func renameTask(weekID: UUID, categoryID: UUID, taskID: UUID, newTitle: String) {
        guard let wi = weeks.firstIndex(where: { $0.id == weekID }),
              let ci = weeks[wi].categories.firstIndex(where: { $0.id == categoryID }),
              let ti = weeks[wi].categories[ci].tasks.firstIndex(where: { $0.id == taskID }) else { return }
        weeks[wi].categories[ci].tasks[ti].title = newTitle
        save()
    }

    func deleteTask(weekID: UUID, categoryID: UUID, taskID: UUID) {
        guard let wi = weeks.firstIndex(where: { $0.id == weekID }),
              let ci = weeks[wi].categories.firstIndex(where: { $0.id == categoryID }) else { return }
        weeks[wi].categories[ci].tasks.removeAll { $0.id == taskID }
        save()
    }

    // MARK: - Carry Forward

    func carryForwardTask(weekID: UUID, categoryID: UUID, taskID: UUID) {
        guard let wi = weeks.firstIndex(where: { $0.id == weekID }),
              let ci = weeks[wi].categories.firstIndex(where: { $0.id == categoryID }),
              let ti = weeks[wi].categories[ci].tasks.firstIndex(where: { $0.id == taskID }) else { return }

        let task = weeks[wi].categories[ci].tasks[ti]
        guard !task.isCompleted else { return }

        // Find or create current week
        ensureCurrentWeekExists()
        guard let currentWI = weeks.firstIndex(where: {
            Calendar.current.isDate($0.startDate, inSameDayAs: Week.mondayOfWeek(containing: Date()))
        }) else { return }

        // Find matching category or create one
        let categoryName = weeks[wi].categories[ci].name
        if let existingCI = weeks[currentWI].categories.firstIndex(where: { $0.name == categoryName }) {
            weeks[currentWI].categories[existingCI].tasks.append(ChecklistTask(title: task.title))
        } else {
            weeks[currentWI].categories.append(Category(name: categoryName, tasks: [ChecklistTask(title: task.title)]))
        }

        // Remove from old week
        weeks[wi].categories[ci].tasks.remove(at: ti)
        save()
    }

    // MARK: - Helpers

    private func sortWeeks() {
        weeks.sort { $0.startDate > $1.startDate }
    }
}
