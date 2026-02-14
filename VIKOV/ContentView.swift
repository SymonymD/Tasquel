import SwiftUI

// MARK: - Root View

struct ContentView: View {
    @State var store = ChecklistStore()
    @State private var showDatePicker = false
    @State private var showSettings = false
    @State private var showAddCategory = false
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
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button("Previous Week", systemImage: "chevron.left") {
                        withAnimation { store.navigateWeek(by: -1) }
                    }
                    Button("Calendar", systemImage: "calendar") {
                        showDatePicker = true
                    }
                    Button("Next Week", systemImage: "chevron.right") {
                        withAnimation { store.navigateWeek(by: 1) }
                    }
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
                SettingsSheet(store: store)
            }
            .sheet(isPresented: $showAddCategory) {
                AddCategorySheet(store: store, expandedCategories: $expandedCategories)
                    .presentationDetents([.medium, .large])
            }
            .alert("Welcome to VIKOV", isPresented: Binding(
                get: { store.shouldShowWelcome },
                set: { if !$0 { store.dismissWelcome() } }
            )) {
                Button("Got It") { store.dismissWelcome() }
            } message: {
                Text("Your weekly checklist. Tap a category to expand it and add tasks.\n\nSwipe right on a task to toggle between Carry Over and Repeating modes.\n\nCarry Over tasks roll to next week if incomplete. Repeating tasks appear every week automatically.\n\nUse the calendar to plan ahead or review past weeks.")
            }
        }
        .preferredColorScheme(store.colorScheme)
        .onAppear {
            if let week = store.selectedWeek {
                expandedCategories = Set(week.categories.map(\.id))
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
                Button {
                    showAddCategory = true
                } label: {
                    Label("Add Category", systemImage: "plus.circle")
                        .foregroundStyle(.secondary)
                }
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
            Button("Save for Future Use", systemImage: "square.and.arrow.down") {
                store.saveCategoryAsTemplate(category.id)
            }
            Divider()
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

// MARK: - Add Category Sheet

struct AddCategorySheet: View {
    let store: ChecklistStore
    @Binding var expandedCategories: Set<UUID>
    @Environment(\.dismiss) private var dismiss
    @State private var isCreatingNew = false
    @State private var newName = ""
    @State private var newSymbol = "folder"

    private let symbolOptions = [
        "folder", "star", "heart", "house", "cart",
        "briefcase", "figure.run", "book", "paintbrush",
        "music.note", "fork.knife", "airplane", "gift",
        "wrench.and.screwdriver", "leaf", "pawprint",
        "calendar.badge.clock", "lightbulb", "sparkles",
    ]

    var body: some View {
        NavigationStack {
            List {
                if !store.savedCategories.isEmpty {
                    Section("Saved Categories") {
                        ForEach(store.savedCategories) { template in
                            Button {
                                addFromTemplate(template)
                            } label: {
                                Label(template.name, systemImage: template.symbol)
                                    .foregroundStyle(.primary)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    store.removeSavedCategory(template.id)
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                        }
                    }
                }

                Section("Create New") {
                    if isCreatingNew {
                        HStack {
                            Menu {
                                ForEach(symbolOptions, id: \.self) { symbol in
                                    Button {
                                        newSymbol = symbol
                                    } label: {
                                        Label(symbol, systemImage: symbol)
                                    }
                                }
                            } label: {
                                Image(systemName: newSymbol)
                                    .font(.title3)
                                    .frame(width: 32, height: 32)
                                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                            }

                            TextField("Category name", text: $newName)
                                .onSubmit(createNew)
                        }

                        HStack {
                            Toggle("Save for future", isOn: .constant(true))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .disabled(true)
                        }

                        HStack {
                            Button("Cancel") {
                                isCreatingNew = false
                                newName = ""
                            }
                            Spacer()
                            Button("Add to Week & Save") {
                                createNew()
                            }
                            .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                        .font(.subheadline)
                    } else {
                        Button {
                            isCreatingNew = true
                        } label: {
                            Label("Create New Category", systemImage: "plus.circle")
                        }
                    }
                }
            }
            .navigationTitle("Add Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func addFromTemplate(_ template: CategoryTemplate) {
        store.addCategory(name: template.name, symbol: template.symbol)
        if let newCat = store.selectedWeek?.categories.last {
            expandedCategories.insert(newCat.id)
        }
        dismiss()
    }

    private func createNew() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        // Save as template and add to current week
        store.addSavedCategory(name: name, symbol: newSymbol)
        store.addCategory(name: name, symbol: newSymbol)
        if let newCat = store.selectedWeek?.categories.last {
            expandedCategories.insert(newCat.id)
        }
        newName = ""
        newSymbol = "folder"
        isCreatingNew = false
        dismiss()
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
    let store: ChecklistStore
    @Environment(\.dismiss) private var dismiss
    @State private var showHelp = false

    var body: some View {
        NavigationStack {
            List {
                Section("Appearance") {
                    ForEach(AppearanceMode.allCases, id: \.self) { mode in
                        Button {
                            withAnimation { store.setAppearance(mode) }
                        } label: {
                            HStack {
                                Label(mode.label, systemImage: mode.symbol)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if store.appearanceMode == mode {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                }

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

                Section {
                    Button {
                        showHelp = true
                    } label: {
                        Label("How to Use VIKOV", systemImage: "questionmark.circle")
                    }
                } header: {
                    Text("Help")
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
            .sheet(isPresented: $showHelp) {
                HelpSheet()
            }
        }
    }
}

// MARK: - Help Sheet

struct HelpSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Weekly Checklist") {
                    HelpRow(
                        symbol: "calendar",
                        title: "Navigate Weeks",
                        detail: "Use the arrows or tap the calendar icon to jump to any week. Past weeks are read-only for review. Future weeks can be pre-populated."
                    )
                    HelpRow(
                        symbol: "chevron.up.chevron.down",
                        title: "Categories",
                        detail: "Tap a category header to expand or collapse it. Long-press to delete or save it as a template for future use."
                    )
                    HelpRow(
                        symbol: "plus.circle",
                        title: "Add Tasks",
                        detail: "Tap the \"Add task\" field inside any category. Press Return to add. Use the mode picker to choose Carry Over or Repeating before adding."
                    )
                }

                Section("Task Modes") {
                    HelpRow(
                        symbol: "arrow.uturn.forward",
                        title: "Carry Over",
                        detail: "Default mode. If a Carry Over task is not completed by end of the week, it automatically rolls forward to the next week. Completed tasks do not carry over."
                    )
                    HelpRow(
                        symbol: "repeat",
                        title: "Repeating",
                        detail: "Repeating tasks appear every week regardless of completion. Great for recurring habits like \"Gym\" or \"Review budget\". They reset to unchecked each new week."
                    )
                    HelpRow(
                        symbol: "hand.draw",
                        title: "Changing Modes",
                        detail: "Swipe right on any task to toggle between modes. Or long-press a task to choose from the context menu."
                    )
                }

                Section("Managing Categories") {
                    HelpRow(
                        symbol: "square.and.arrow.down",
                        title: "Save for Future",
                        detail: "Long-press a category header and choose \"Save for Future Use\" to add it to your template library. Saved categories appear when you tap Add Category."
                    )
                    HelpRow(
                        symbol: "trash",
                        title: "Delete",
                        detail: "Long-press a category header to delete it and all its tasks from the current week. Swipe left on a saved category template to remove it from the library."
                    )
                }

                Section("Upcoming Features") {
                    HelpRow(
                        symbol: "calendar.badge.plus",
                        title: "Calendar Integration",
                        detail: "A future paid upgrade will allow importing your personal calendar events directly into VIKOV as tasks, toggled in Settings."
                    )
                }
            }
            .navigationTitle("How to Use VIKOV")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct HelpRow: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbol)
                .font(.subheadline.bold())
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ContentView()
}
