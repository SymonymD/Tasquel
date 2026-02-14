import SwiftUI

// MARK: - Root View

struct ContentView: View {
    @State var store = ChecklistStore()
    @State private var showDatePicker = false
    @State private var showSettings = false
    @State private var expandedCategories: Set<UUID> = []

    var body: some View {
        NavigationStack {
            Group {
                if let week = store.selectedWeek {
                    weekContent(week)
                } else {
                    ContentUnavailableView("No Week Data", systemImage: "calendar.badge.exclamationmark")
                }
            }
            .navigationTitle(store.selectedWeek?.displayTitle ?? "VIKOV")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Calendar", systemImage: "calendar") {
                        showDatePicker = true
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    weekNavigationButtons
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Settings", systemImage: "gearshape") {
                        showSettings = true
                    }
                }
            }
            .sheet(isPresented: $showDatePicker) {
                DatePickerSheet(selectedDate: store.selectedDate) { date in
                    withAnimation { store.navigateToDate(date) }
                }
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showSettings) {
                SettingsSheet()
                    .presentationDetents([.medium])
            }
        }
        .onAppear {
            if let week = store.selectedWeek {
                expandedCategories = Set(week.categories.map(\.id))
            }
        }
    }

    private var weekNavigationButtons: some View {
        HStack(spacing: 4) {
            Button("Previous Week", systemImage: "chevron.left") {
                withAnimation { store.navigateWeek(by: -1) }
            }
            Button("Next Week", systemImage: "chevron.right") {
                withAnimation { store.navigateWeek(by: 1) }
            }
        }
    }

    @ViewBuilder
    private func weekContent(_ week: Week) -> some View {
        List {
            if !week.isCurrentWeek {
                weekBanner(week)
            }

            ForEach(week.categories) { category in
                categorySection(category)
            }

            Section {
                AddCategoryRow(store: store, expandedCategories: $expandedCategories)
            }

            if store.isFirstLaunch {
                suggestionsSection
            }
        }
        .listStyle(.insetGrouped)
        .animation(.snappy(duration: 0.3), value: week)
    }

    @ViewBuilder
    private func weekBanner(_ week: Week) -> some View {
        Section {
            HStack {
                Image(systemName: week.isFutureWeek ? "calendar.badge.plus" : "clock.arrow.circlepath")
                    .foregroundStyle(week.isFutureWeek ? .blue : .orange)
                Text(week.isFutureWeek ? "Planning ahead" : "Reviewing past week")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Today") {
                    withAnimation { store.navigateToDate(Date()) }
                }
                .font(.subheadline.bold())
            }
        }
    }

    private func categorySection(_ category: Category) -> some View {
        Section(isExpanded: Binding(
            get: { expandedCategories.contains(category.id) },
            set: { isExpanded in
                withAnimation(.snappy(duration: 0.25)) {
                    if isExpanded {
                        expandedCategories.insert(category.id)
                    } else {
                        expandedCategories.remove(category.id)
                    }
                }
            }
        )) {
            ForEach(category.tasks) { task in
                TaskRow(task: task, categoryID: category.id, store: store)
            }
            .onDelete { indexSet in
                for index in indexSet {
                    let task = category.tasks[index]
                    store.deleteTask(categoryID: category.id, taskID: task.id)
                }
            }

            AddTaskRow(categoryID: category.id, store: store)
        } header: {
            CategoryHeader(category: category, store: store)
        }
    }

    private var suggestionsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {
                Label("Get Started", systemImage: "sparkles")
                    .font(.headline)

                Text("Tap a category above to expand it, then add your first tasks for the week.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 10) {
                    SuggestionRow(icon: "repeat", text: "Mark recurring tasks as Repeating — they'll appear every week automatically")
                    SuggestionRow(icon: "arrow.uturn.forward", text: "Carry Over tasks roll to next week if left incomplete")
                    SuggestionRow(icon: "calendar", text: "Use the calendar to plan future weeks or review past ones")
                    SuggestionRow(icon: "gearshape", text: "Calendar integration coming soon in Settings")
                }
            }
            .padding(.vertical, 8)
        } header: {
            Text("Tips")
        }
    }
}

// MARK: - Category Header

struct CategoryHeader: View {
    let category: Category
    let store: ChecklistStore

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: category.symbol)
            Text(category.name)
            Spacer()
            if category.totalCount > 0 {
                Text("\(category.completedCount)/\(category.totalCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .contextMenu {
            Button("Delete Category", systemImage: "trash", role: .destructive) {
                withAnimation { store.deleteCategory(category.id) }
            }
        }
    }
}

// MARK: - Task Row

struct TaskRow: View {
    let task: ChecklistTask
    let categoryID: UUID
    let store: ChecklistStore

    var body: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.snappy(duration: 0.2)) {
                    store.toggleTask(categoryID: categoryID, taskID: task.id)
                }
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.isCompleted ? .green : .secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .strikethrough(task.isCompleted, color: .secondary)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)

                Label(task.mode.label, systemImage: task.mode.symbol)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                store.deleteTask(categoryID: categoryID, taskID: task.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                let newMode: TaskMode = task.mode == .carryOver ? .repeating : .carryOver
                store.updateTaskMode(categoryID: categoryID, taskID: task.id, mode: newMode)
            } label: {
                let target: TaskMode = task.mode == .carryOver ? .repeating : .carryOver
                Label(target.label, systemImage: target.symbol)
            }
            .tint(.indigo)
        }
        .contextMenu {
            Section("Task Mode") {
                ForEach(TaskMode.allCases, id: \.self) { mode in
                    Button {
                        store.updateTaskMode(categoryID: categoryID, taskID: task.id, mode: mode)
                    } label: {
                        Label(mode.label, systemImage: mode.symbol)
                        if task.mode == mode {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
            Section {
                Button("Delete", systemImage: "trash", role: .destructive) {
                    store.deleteTask(categoryID: categoryID, taskID: task.id)
                }
            }
        }
    }
}

// MARK: - Add Task Row

struct AddTaskRow: View {
    let categoryID: UUID
    let store: ChecklistStore
    @State private var newTitle = ""
    @State private var newMode: TaskMode = .carryOver
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus.circle")
                .font(.title3)
                .foregroundStyle(.tertiary)

            TextField("Add task", text: $newTitle)
                .focused($isFocused)
                .onSubmit(addTask)

            if isFocused {
                Menu {
                    ForEach(TaskMode.allCases, id: \.self) { mode in
                        Button {
                            newMode = mode
                        } label: {
                            Label(mode.label, systemImage: mode.symbol)
                            if newMode == mode {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                } label: {
                    Image(systemName: newMode.symbol)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(6)
                        .background(.quaternary, in: Circle())
                }
            }
        }
    }

    private func addTask() {
        let title = newTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        withAnimation(.snappy(duration: 0.2)) {
            store.addTask(categoryID: categoryID, title: title, mode: newMode)
        }
        newTitle = ""
    }
}

// MARK: - Add Category Row

struct AddCategoryRow: View {
    let store: ChecklistStore
    @Binding var expandedCategories: Set<UUID>
    @State private var isAdding = false
    @State private var categoryName = ""
    @State private var categorySymbol = "folder"

    private let symbolOptions = [
        "folder", "star", "heart", "house", "cart",
        "briefcase", "figure.run", "book", "paintbrush",
        "music.note", "fork.knife", "airplane", "gift",
        "wrench.and.screwdriver", "leaf", "pawprint",
    ]

    var body: some View {
        if isAdding {
            VStack(spacing: 12) {
                HStack {
                    Menu {
                        ForEach(symbolOptions, id: \.self) { symbol in
                            Button {
                                categorySymbol = symbol
                            } label: {
                                Label(symbol, systemImage: symbol)
                            }
                        }
                    } label: {
                        Image(systemName: categorySymbol)
                            .font(.title3)
                            .frame(width: 32, height: 32)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                    }

                    TextField("Category name", text: $categoryName)
                        .onSubmit(addCategory)
                }

                HStack {
                    Button("Cancel") {
                        isAdding = false
                        categoryName = ""
                    }
                    Spacer()
                    Button("Add", action: addCategory)
                        .disabled(categoryName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .font(.subheadline)
            }
        } else {
            Button {
                isAdding = true
            } label: {
                Label("Add Category", systemImage: "plus.circle")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func addCategory() {
        let name = categoryName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        store.addCategory(name: name, symbol: categorySymbol)
        if let newCat = store.selectedWeek?.categories.last {
            expandedCategories.insert(newCat.id)
        }
        categoryName = ""
        categorySymbol = "folder"
        isAdding = false
    }
}

// MARK: - Suggestion Row

struct SuggestionRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.blue)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Date Picker Sheet

struct DatePickerSheet: View {
    let selectedDate: Date
    let onSelect: (Date) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var pickerDate: Date

    init(selectedDate: Date, onSelect: @escaping (Date) -> Void) {
        self.selectedDate = selectedDate
        self.onSelect = onSelect
        self._pickerDate = State(initialValue: selectedDate)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                DatePicker(
                    "Select a week",
                    selection: $pickerDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)

                Text("Selected: Week of \(formattedMonday)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .navigationTitle("Go to Week")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Go") {
                        onSelect(pickerDate)
                        dismiss()
                    }
                }
            }
        }
    }

    private var formattedMonday: String {
        let monday = Week.mondayOfWeek(containing: pickerDate)
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: monday)
    }
}

// MARK: - Settings Sheet

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var calendarIntegration = false

    var body: some View {
        NavigationStack {
            List {
                Section("Calendar") {
                    HStack {
                        Label("Calendar Integration", systemImage: "calendar.badge.plus")
                        Spacer()
                        Text("Coming Soon")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.quaternary, in: Capsule())
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: "1.0")
                    LabeledContent("Build", value: "1")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
