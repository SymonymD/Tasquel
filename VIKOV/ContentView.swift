import SwiftUI

// MARK: - Root View

struct ContentView: View {
    @State var store = ChecklistStore()
    @State private var showDatePicker = false
    @State private var showSettings = false
    @State private var showAddCategory = false
    @State private var expandedCategories: Set<UUID> = []
    @State private var isEditing = false
    @State private var showOnboarding = false

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
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if isEditing {
                        Button("Done", systemImage: "checkmark.circle.fill") {
                            withAnimation(.snappy(duration: 0.25)) { isEditing.toggle() }
                        }
                        .tint(.green)
                    } else {
                        Button("Edit", systemImage: "pencil") {
                            withAnimation(.snappy(duration: 0.25)) { isEditing.toggle() }
                        }
                    }
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
            .sheet(isPresented: $showOnboarding) {
                OnboardingSheet(store: store, expandedCategories: $expandedCategories)
                    .interactiveDismissDisabled()
            }
        }
        .preferredColorScheme(store.colorScheme)
        .onAppear {
            if let week = store.selectedWeek {
                expandedCategories = Set(week.categories.map(\.id))
            }
            if store.shouldShowWelcome {
                showOnboarding = true
            }
        }
    }

    @ViewBuilder
    private func weekContent(_ week: Week) -> some View {
        List {
            if !week.isCurrentWeek {
                weekBanner(week)
            }

            if isEditing {
                Section {
                    Button {
                        showAddCategory = true
                    } label: {
                        Label("Add Category", systemImage: "plus.circle")
                    }
                }
            }

            ForEach(week.categories) { category in
                categorySection(category)
            }
        }
        .listStyle(.insetGrouped)
        .animation(.snappy(duration: 0.3), value: week)
        .environment(\.editMode, .constant(isEditing ? .active : .inactive))
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
                TaskRow(task: task, categoryID: category.id, store: store, isEditing: isEditing)
            }
            .onDelete { indexSet in
                for index in indexSet {
                    let task = category.tasks[index]
                    store.deleteTask(categoryID: category.id, taskID: task.id)
                }
            }

            AddTaskRow(categoryID: category.id, store: store)
        } header: {
            CategoryHeader(category: category, store: store, isEditing: isEditing)
        }
    }
}

// MARK: - Category Header

struct CategoryHeader: View {
    let category: Category
    let store: ChecklistStore
    let isEditing: Bool

    @State private var showDeleteOptions = false

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
            if isEditing {
                Button {
                    showDeleteOptions = true
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .contextMenu {
            Button("Save for Future Use", systemImage: "square.and.arrow.down") {
                store.saveCategoryAsTemplate(category.id)
            }
            Divider()
            Button("Remove from This Week", systemImage: "xmark.circle", role: .destructive) {
                withAnimation { store.deleteCategory(category.id) }
            }
            Button("Delete Entirely", systemImage: "trash", role: .destructive) {
                withAnimation {
                    // Remove saved template too
                    store.savedCategories.removeAll { $0.name == category.name }
                    store.saveSettings()
                    store.deleteCategory(category.id)
                }
            }
        }
        .sheet(isPresented: $showDeleteOptions) {
            RemoveCategorySheet(category: category, store: store)
                .presentationDetents([.height(260)])
        }
    }
}

// MARK: - Task Row

struct TaskRow: View {
    let task: ChecklistTask
    let categoryID: UUID
    let store: ChecklistStore
    let isEditing: Bool

    @State private var isEditingTitle = false
    @State private var editedTitle: String = ""
    @State private var showSubtasks = false
    @State private var newSubtaskTitle = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main task row
            HStack(spacing: 12) {
                if !isEditing {
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
                }

                VStack(alignment: .leading, spacing: 2) {
                    if isEditing && isEditingTitle {
                        TextField("Task name", text: $editedTitle)
                            .font(.body)
                            .onSubmit {
                                let title = editedTitle.trimmingCharacters(in: .whitespaces)
                                if !title.isEmpty {
                                    store.renameTask(categoryID: categoryID, taskID: task.id, newTitle: title)
                                }
                                isEditingTitle = false
                            }
                    } else {
                        Text(task.title)
                            .strikethrough(task.isCompleted, color: .secondary)
                            .foregroundStyle(task.isCompleted ? .secondary : .primary)
                            .onTapGesture {
                                if isEditing {
                                    editedTitle = task.title
                                    isEditingTitle = true
                                }
                            }
                    }

                    HStack(spacing: 8) {
                        if isEditing {
                            modePicker
                        } else {
                            Label(task.mode.label, systemImage: task.mode.symbol)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }

                        if !task.subtasks.isEmpty {
                            Text("\(task.completedSubtaskCount)/\(task.subtasks.count) sub-tasks")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                Spacer()

                if isEditing {
                    Button {
                        withAnimation(.snappy(duration: 0.2)) { showSubtasks.toggle() }
                    } label: {
                        Image(systemName: "list.bullet.indent")
                            .font(.subheadline)
                            .foregroundStyle(showSubtasks ? .blue : .secondary)
                    }
                    .buttonStyle(.plain)
                } else if !task.subtasks.isEmpty {
                    Button {
                        withAnimation(.snappy(duration: 0.2)) { showSubtasks.toggle() }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .rotationEffect(.degrees(showSubtasks ? 90 : 0))
                    }
                    .buttonStyle(.plain)
                }
            }

            // Subtasks (expanded)
            if showSubtasks {
                VStack(spacing: 0) {
                    ForEach(task.subtasks) { subtask in
                        SubTaskRow(
                            subtask: subtask,
                            categoryID: categoryID,
                            taskID: task.id,
                            store: store,
                            isEditing: isEditing
                        )
                    }

                    // Add subtask
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        TextField("Add sub-task", text: $newSubtaskTitle)
                            .font(.subheadline)
                            .onSubmit(addSubtask)
                    }
                    .padding(.leading, 28)
                    .padding(.vertical, 4)
                }
                .padding(.top, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
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
                let modes = TaskMode.allCases
                let currentIndex = modes.firstIndex(of: task.mode) ?? 0
                let nextMode = modes[(currentIndex + 1) % modes.count]
                store.updateTaskMode(categoryID: categoryID, taskID: task.id, mode: nextMode)
            } label: {
                let modes = TaskMode.allCases
                let currentIndex = modes.firstIndex(of: task.mode) ?? 0
                let nextMode = modes[(currentIndex + 1) % modes.count]
                Label(nextMode.label, systemImage: nextMode.symbol)
            }
            .tint(.indigo)
        }
        .contextMenu {
            Section("Task Mode") {
                ForEach(TaskMode.allCases, id: \.self) { mode in
                    Button {
                        store.updateTaskMode(categoryID: categoryID, taskID: task.id, mode: mode)
                    } label: {
                        Label {
                            Text(mode.label)
                        } icon: {
                            Image(systemName: mode.symbol)
                        }
                        if task.mode == mode {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
            Section {
                Button("Edit Title", systemImage: "pencil") {
                    editedTitle = task.title
                    isEditingTitle = true
                    // inline editing handled by isEditingTitle
                }
                Button(showSubtasks ? "Hide Sub-Tasks" : "Show Sub-Tasks", systemImage: "list.bullet.indent") {
                    withAnimation { showSubtasks.toggle() }
                }
            }
            Section {
                Button("Delete", systemImage: "trash", role: .destructive) {
                    store.deleteTask(categoryID: categoryID, taskID: task.id)
                }
            }
        }
    }

    private var modePicker: some View {
        Menu {
            ForEach(TaskMode.allCases, id: \.self) { mode in
                Button {
                    store.updateTaskMode(categoryID: categoryID, taskID: task.id, mode: mode)
                } label: {
                    Label {
                        VStack(alignment: .leading) {
                            Text(mode.label)
                            Text(mode.hint)
                        }
                    } icon: {
                        Image(systemName: mode.symbol)
                    }
                    if task.mode == mode {
                        Image(systemName: "checkmark")
                    }
                }
            }
        } label: {
            Label(task.mode.label, systemImage: task.mode.symbol)
                .font(.caption2)
                .foregroundStyle(.blue)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.blue.opacity(0.1), in: Capsule())
        }
    }

    private func addSubtask() {
        let title = newSubtaskTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        withAnimation(.snappy(duration: 0.2)) {
            store.addSubtask(categoryID: categoryID, taskID: task.id, title: title)
        }
        newSubtaskTitle = ""
    }
}

// MARK: - Sub-Task Row

struct SubTaskRow: View {
    let subtask: SubTask
    let categoryID: UUID
    let taskID: UUID
    let store: ChecklistStore
    let isEditing: Bool

    @State private var isEditingTitle = false
    @State private var editedTitle = ""

    var body: some View {
        HStack(spacing: 8) {
            Button {
                withAnimation(.snappy(duration: 0.2)) {
                    store.toggleSubtask(categoryID: categoryID, taskID: taskID, subtaskID: subtask.id)
                }
            } label: {
                Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.subheadline)
                    .foregroundStyle(subtask.isCompleted ? Color.green : Color.secondary)
            }
            .buttonStyle(.plain)

            if isEditing && isEditingTitle {
                TextField("Sub-task", text: $editedTitle)
                    .font(.subheadline)
                    .onSubmit {
                        let title = editedTitle.trimmingCharacters(in: .whitespaces)
                        if !title.isEmpty {
                            store.renameSubtask(categoryID: categoryID, taskID: taskID, subtaskID: subtask.id, newTitle: title)
                        }
                        isEditingTitle = false
                    }
            } else {
                Text(subtask.title)
                    .font(.subheadline)
                    .strikethrough(subtask.isCompleted, color: .secondary)
                    .foregroundStyle(subtask.isCompleted ? .tertiary : .secondary)
                    .onTapGesture {
                        if isEditing {
                            editedTitle = subtask.title
                            isEditingTitle = true
                        }
                    }
            }

            Spacer()

            if isEditing {
                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        store.deleteSubtask(categoryID: categoryID, taskID: taskID, subtaskID: subtask.id)
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.leading, 28)
        .padding(.vertical, 2)
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
                            Label {
                                Text(mode.label)
                                Text(mode.hint)
                            } icon: {
                                Image(systemName: mode.symbol)
                            }
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
                        detail: "Use the arrows or tap the calendar icon to jump to any week. Future weeks can be pre-populated. Past weeks can be reviewed."
                    )
                    HelpRow(
                        symbol: "chevron.up.chevron.down",
                        title: "Categories",
                        detail: "Tap a category header to expand or collapse. Long-press for options: save for future use, remove from this week, or delete entirely."
                    )
                    HelpRow(
                        symbol: "pencil",
                        title: "Edit Mode",
                        detail: "Tap the edit button to enter edit mode. From here you can add/remove categories, edit task titles and modes, and manage sub-tasks."
                    )
                }

                Section("Task Modes") {
                    HelpRow(
                        symbol: "arrow.uturn.forward",
                        title: "Carry Over",
                        detail: "Default mode. If not completed by end of the week, it rolls forward to the next week. Completed tasks do not carry over."
                    )
                    HelpRow(
                        symbol: "repeat",
                        title: "Repeating",
                        detail: "Appears every week automatically regardless of completion. Great for recurring habits. Resets to unchecked each new week."
                    )
                    HelpRow(
                        symbol: "1.circle",
                        title: "One-Time",
                        detail: "This week only. Will not carry forward or repeat, whether completed or not."
                    )
                    HelpRow(
                        symbol: "hand.draw",
                        title: "Changing Modes",
                        detail: "Swipe right on any task to cycle through modes. In edit mode, tap the mode badge to pick. Or long-press a task for the context menu."
                    )
                }

                Section("Sub-Tasks") {
                    HelpRow(
                        symbol: "list.bullet.indent",
                        title: "Adding Sub-Tasks",
                        detail: "In edit mode, tap the list icon on any task to expand its sub-tasks. Type in the field to add. Sub-tasks have their own checkboxes."
                    )
                    HelpRow(
                        symbol: "checkmark.circle",
                        title: "Completing Sub-Tasks",
                        detail: "Tap any sub-task's circle to check it off. Sub-task progress shows as a count on the parent task."
                    )
                }

                Section("Managing Categories") {
                    HelpRow(
                        symbol: "square.and.arrow.down",
                        title: "Save for Future",
                        detail: "Long-press a category header and choose \"Save for Future Use\" to add it to your template library."
                    )
                    HelpRow(
                        symbol: "trash",
                        title: "Removing Categories",
                        detail: "In edit mode, tap the red minus on a category header. Choose to remove from this week only or delete entirely (removes saved template too)."
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

// MARK: - Remove Category Sheet

struct RemoveCategorySheet: View {
    let category: Category
    let store: ChecklistStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Close button
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 16)
            .padding(.trailing, 20)

            Text("Remove \"\(category.name)\"")
                .font(.headline)
                .padding(.top, 4)

            Text("Remove from this week only, or delete entirely including from saved categories?")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.top, 8)

            VStack(spacing: 12) {
                Button {
                    withAnimation { store.deleteCategory(category.id) }
                    dismiss()
                } label: {
                    Text("Remove from This Week")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button(role: .destructive) {
                    withAnimation {
                        store.savedCategories.removeAll { $0.name == category.name }
                        store.saveSettings()
                        store.deleteCategory(category.id)
                    }
                    dismiss()
                } label: {
                    Text("Delete Entirely")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 32)
            .padding(.top, 20)

            Spacer()
        }
    }
}

// MARK: - Onboarding Sheet

struct OnboardingSheet: View {
    let store: ChecklistStore
    @Binding var expandedCategories: Set<UUID>
    @Environment(\.dismiss) private var dismiss

    @State private var step: OnboardingStep = .welcome
    @State private var customCategories: [(name: String, symbol: String)] = []
    @State private var newName = ""
    @State private var newSymbol = "folder"
    @State private var isAddingCategory = false

    enum OnboardingStep {
        case welcome
        case categories
    }

    private let symbolOptions = [
        "folder", "star", "heart", "house", "cart",
        "briefcase", "figure.run", "book", "paintbrush",
        "music.note", "fork.knife", "airplane", "gift",
        "wrench.and.screwdriver", "leaf", "pawprint",
        "calendar.badge.clock", "lightbulb", "sparkles",
    ]

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .welcome:
                    welcomeView
                case .categories:
                    categorySetupView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var welcomeView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle")
                .font(.system(size: 60))
                .foregroundStyle(.green)

            Text("Welcome to VIKOV")
                .font(.largeTitle.bold())

            VStack(alignment: .leading, spacing: 16) {
                OnboardingFeatureRow(
                    symbol: "rectangle.stack",
                    title: "Weekly Checklist",
                    detail: "Tap a category to expand it and add tasks."
                )
                OnboardingFeatureRow(
                    symbol: "arrow.uturn.forward",
                    title: "Smart Task Modes",
                    detail: "Tasks can carry over, repeat weekly, or be one-time. Swipe right to change."
                )
                OnboardingFeatureRow(
                    symbol: "pencil",
                    title: "Edit Mode",
                    detail: "Manage categories, edit tasks, and add sub-tasks."
                )
            }
            .padding(.horizontal, 24)

            Spacer()

            Button {
                withAnimation(.snappy(duration: 0.3)) { step = .categories }
            } label: {
                Text("Next")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
    }

    private var categorySetupView: some View {
        VStack(spacing: 16) {
            Text("Set Up Your Categories")
                .font(.title2.bold())
                .padding(.top, 24)

            Text("Create your own categories, or skip to start with defaults (Errands, Work, Fitness, Study, Appointments).")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            List {
                if !customCategories.isEmpty {
                    Section("Your Categories") {
                        ForEach(Array(customCategories.enumerated()), id: \.offset) { index, cat in
                            Label(cat.name, systemImage: cat.symbol)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        customCategories.remove(at: index)
                                    } label: {
                                        Label("Remove", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }

                Section {
                    if isAddingCategory {
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
                                .onSubmit(addCustomCategory)
                        }

                        HStack {
                            Button("Cancel") {
                                isAddingCategory = false
                                newName = ""
                            }
                            Spacer()
                            Button("Add") { addCustomCategory() }
                                .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                        .font(.subheadline)
                    } else {
                        Button {
                            isAddingCategory = true
                        } label: {
                            Label("Add Category", systemImage: "plus.circle")
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)

            HStack(spacing: 16) {
                Button {
                    finishOnboarding(useDefaults: true)
                } label: {
                    Text("Skip (Use Defaults)")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.bordered)

                if !customCategories.isEmpty {
                    Button {
                        finishOnboarding(useDefaults: false)
                    } label: {
                        Text("Done")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    private func addCustomCategory() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        customCategories.append((name: name, symbol: newSymbol))
        newName = ""
        newSymbol = "folder"
        isAddingCategory = false
    }

    private func finishOnboarding(useDefaults: Bool) {
        if !useDefaults && !customCategories.isEmpty {
            // Replace default categories with user's custom ones
            store.savedCategories = customCategories.map {
                CategoryTemplate(name: $0.name, symbol: $0.symbol)
            }
            store.saveSettings()

            // Replace current week's categories
            store.replaceCurrentWeekCategories(with: customCategories.map {
                Category(name: $0.name, symbol: $0.symbol)
            })
        }

        store.dismissWelcome()

        // Expand all categories
        if let week = store.selectedWeek {
            expandedCategories = Set(week.categories.map(\.id))
        }
        dismiss()
    }
}

struct OnboardingFeatureRow: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    ContentView()
}
