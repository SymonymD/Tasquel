import SwiftUI

// MARK: - Root View

struct ContentView: View {
    @State var store = ChecklistStore()
    @State private var showDatePicker = false
    @State private var showSettings = false
    @State private var showAddCategory = false
    @State private var expandedCategoryID: UUID? = nil
    @State private var isEditing = false
    @State private var showOnboarding = false

    private var isPastWeek: Bool {
        store.selectedWeek?.isPastWeek ?? false
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 12) {
                Text(store.selectedWeek?.displayTitle ?? "Tasquel")
                    .font(.title.bold())
                    .padding(.top, 8)

                weekNavigationBar

                if let week = store.selectedWeek {
                    weekContent(week)
                } else {
                    Spacer()
                    ContentUnavailableView("No Week Data", systemImage: "calendar.badge.exclamationmark")
                    Spacer()
                }
            }

            bottomBar
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
        }
        .preferredColorScheme(store.colorScheme)
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
            AddCategorySheet(store: store)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingSheet(store: store)
                .interactiveDismissDisabled()
        }
        .onAppear {
            if store.shouldShowWelcome {
                showOnboarding = true
            }
        }
        .onChange(of: store.selectedDate) {
            if isPastWeek { isEditing = false }
            expandedCategoryID = nil
        }
    }

    // MARK: - Navigation Capsule

    private var weekNavigationBar: some View {
        HStack(spacing: 20) {
            Button {
                withAnimation { store.navigateWeek(by: -1) }
            } label: {
                Image(systemName: "chevron.left").font(.body.bold())
            }
            Button { showDatePicker = true } label: {
                Image(systemName: "calendar").font(.body)
            }
            Button {
                withAnimation { store.navigateWeek(by: 1) }
            } label: {
                Image(systemName: "chevron.right").font(.body.bold())
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule())
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack {
            Button { showSettings = true } label: {
                Image(systemName: "gearshape.fill")
                    .font(.body)
                    .frame(width: 46, height: 46)
                    .background(.regularMaterial, in: Circle())
            }

            Spacer()

            if store.selectedWeek?.isCurrentWeek == true {
                Text(todayDateString)
                    .font(.subheadline.bold())
            } else {
                Button {
                    withAnimation { store.navigateToDate(Date()) }
                } label: {
                    VStack(spacing: 1) {
                        Text(todayDateString).font(.subheadline.bold())
                        Text("Go to Today").font(.caption2).foregroundStyle(.blue)
                    }
                }
                .buttonStyle(.plain)
            }

            Spacer()

            if !isPastWeek {
                Button {
                    withAnimation(.snappy(duration: 0.25)) { isEditing.toggle() }
                } label: {
                    if isEditing {
                        Image(systemName: "checkmark")
                            .font(.body).foregroundStyle(.green)
                            .frame(width: 46, height: 46)
                            .background(.green.opacity(0.15), in: Circle())
                            .overlay(Circle().stroke(.green, lineWidth: 1.5))
                    } else {
                        Image(systemName: "pencil")
                            .font(.body)
                            .frame(width: 46, height: 46)
                            .background(.regularMaterial, in: Circle())
                    }
                }
            } else {
                Color.clear.frame(width: 46, height: 46)
            }
        }
    }

    private var todayDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        let base = formatter.string(from: Date())
        let day = Calendar.current.component(.day, from: Date())
        let suffix: String
        switch day {
        case 1, 21, 31: suffix = "st"
        case 2, 22: suffix = "nd"
        case 3, 23: suffix = "rd"
        default: suffix = "th"
        }
        return "\(base)\(suffix)"
    }

    // MARK: - Week Content

    @ViewBuilder
    private func weekContent(_ week: Week) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                // Expanded card (if any)
                if let expandedID = expandedCategoryID,
                   let category = week.categories.first(where: { $0.id == expandedID }) {
                    ExpandedCategoryCard(
                        category: category,
                        store: store,
                        isEditing: isEditing,
                        isPastWeek: week.isPastWeek,
                        onToggleEdit: { withAnimation(.snappy(duration: 0.25)) { isEditing.toggle() } },
                        onCollapse: { withAnimation(.snappy(duration: 0.3)) { expandedCategoryID = nil } }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
                }

                // Collapsed cards grid
                let collapsed = week.categories.filter { $0.id != expandedCategoryID }
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)],
                    spacing: 16
                ) {
                    ForEach(collapsed) { category in
                        CategoryCard(category: category, store: store) {
                            withAnimation(.snappy(duration: 0.3)) {
                                expandedCategoryID = category.id
                            }
                        }
                    }

                    if isEditing && !week.isPastWeek {
                        Button { showAddCategory = true } label: {
                            VStack(spacing: 8) {
                                Image(systemName: "plus")
                                    .font(.title2).foregroundStyle(.secondary)
                                Text("Add Category")
                                    .font(.caption.bold()).foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 120)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
                                    .foregroundStyle(.tertiary)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                if week.categories.isEmpty && !isEditing {
                    ContentUnavailableView(
                        "No Categories",
                        systemImage: "folder.badge.plus",
                        description: Text("Tap the pencil to add categories.")
                    )
                    .padding(.top, 40)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 80)
        }
    }
}

// MARK: - Category Card (Collapsed)

struct CategoryCard: View {
    let category: Category
    let store: ChecklistStore
    let onExpand: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Image(systemName: category.symbol).font(.caption)
                Text(category.name).font(.subheadline.bold()).lineLimit(1)
                Spacer()
                completionIcon(for: category)
            }

            Text("Completed: \(category.completedCount)/\(category.totalCount)")
                .font(.caption2).foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 3) {
                ForEach(category.tasks.prefix(5)) { task in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(task.isCompleted ? Color.green : Color.red)
                            .frame(width: 7, height: 7)
                        Text(task.title)
                            .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 0)

            HStack {
                Spacer()
                Image(systemName: "arrow.up.forward")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        }
        .onTapGesture { onExpand() }
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
                    store.savedCategories.removeAll { $0.name == category.name }
                    store.saveSettings()
                    store.deleteCategory(category.id)
                }
            }
        }
    }

    private func completionIcon(for category: Category) -> some View {
        let total = category.totalCount
        let completed = category.completedCount
        let color: Color = total == 0 ? .gray : completed == 0 ? .red : completed == total ? .green : .orange
        return Image(systemName: "chart.pie.fill")
            .font(.subheadline)
            .foregroundStyle(color)
    }
}

// MARK: - Expanded Category Card

struct ExpandedCategoryCard: View {
    let category: Category
    let store: ChecklistStore
    let isEditing: Bool
    let isPastWeek: Bool
    let onToggleEdit: () -> Void
    let onCollapse: () -> Void

    @State private var showDeleteOptions = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(alignment: .top) {
                Image(systemName: category.symbol).font(.caption)
                Text(category.name).font(.subheadline.bold())
                Spacer()
                if !isPastWeek {
                    Button { onToggleEdit() } label: {
                        Image(systemName: isEditing ? "checkmark.circle.fill" : "square.and.pencil")
                            .font(.subheadline)
                            .foregroundStyle(isEditing ? .green : .secondary)
                    }
                    .buttonStyle(.plain)
                }
                completionIcon(for: category)
            }

            Text("Completed: \(category.completedCount)/\(category.totalCount)")
                .font(.caption2).foregroundStyle(.secondary)

            Divider().padding(.vertical, 2)

            // Tasks
            ForEach(category.tasks) { task in
                TaskRowCard(
                    task: task,
                    categoryID: category.id,
                    store: store,
                    isEditing: isEditing,
                    isPastWeek: isPastWeek
                )
            }

            // Add task
            if !isPastWeek {
                AddTaskRowCard(categoryID: category.id, store: store)
            }

            // Collapse arrow
            HStack {
                Spacer()
                Button { onCollapse() } label: {
                    Image(systemName: "arrow.down.backward")
                        .font(.caption).foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
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

    private func completionIcon(for category: Category) -> some View {
        let total = category.totalCount
        let completed = category.completedCount
        let color: Color = total == 0 ? .gray : completed == 0 ? .red : completed == total ? .green : .orange
        return Image(systemName: "chart.pie.fill")
            .font(.subheadline)
            .foregroundStyle(color)
    }
}

// MARK: - Task Row (Card)

struct TaskRowCard: View {
    let task: ChecklistTask
    let categoryID: UUID
    let store: ChecklistStore
    let isEditing: Bool
    var isPastWeek: Bool = false

    @State private var isEditingTitle = false
    @State private var editedTitle = ""
    @State private var newSubtaskTitle = ""
    @State private var addProgressText = ""
    @State private var goalTargetText = ""
    @State private var goalUnitText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                // Completion indicator
                if task.taskType == .goal {
                    goalIndicator
                } else {
                    Button {
                        guard !isPastWeek else { return }
                        withAnimation(.snappy(duration: 0.2)) {
                            store.toggleTask(categoryID: categoryID, taskID: task.id)
                        }
                    } label: {
                        Circle()
                            .fill(task.isCompleted ? Color.green : Color.clear)
                            .overlay(Circle().stroke(task.isCompleted ? Color.green : Color.secondary, lineWidth: 1.5))
                            .frame(width: 14, height: 14)
                    }
                    .buttonStyle(.plain)
                }

                // Title
                if isEditingTitle {
                    TextField("Task name", text: $editedTitle)
                        .font(.subheadline)
                        .onSubmit {
                            let title = editedTitle.trimmingCharacters(in: .whitespaces)
                            if !title.isEmpty {
                                store.renameTask(categoryID: categoryID, taskID: task.id, newTitle: title)
                            }
                            isEditingTitle = false
                        }
                } else {
                    Text(task.title)
                        .font(.subheadline)
                        .foregroundStyle(task.isCompleted ? .secondary : .primary)
                        .onTapGesture(count: 2) {
                            editedTitle = task.title
                            isEditingTitle = true
                        }
                        .onTapGesture {
                            if isEditing {
                                editedTitle = task.title
                                isEditingTitle = true
                            }
                        }
                }

                Spacer()

                // Inline icons
                if !isPastWeek {
                    if isEditing {
                        taskModeIcons
                    } else {
                        taskTypeIcons
                    }
                }
            }

            if task.taskType == .goal {
                // Goal: always show setup or progress inline
                goalProgressSection
            } else {
                // Checkbox: subtasks
                ForEach(task.subtasks) { subtask in
                    SubTaskRowCard(
                        subtask: subtask,
                        categoryID: categoryID,
                        taskID: task.id,
                        store: store,
                        isEditing: isEditing,
                        isPastWeek: isPastWeek
                    )
                }
                if !isPastWeek {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle")
                            .font(.caption2).foregroundStyle(.tertiary)
                        TextField("Add sub-task", text: $newSubtaskTitle)
                            .font(.caption)
                            .onSubmit(addSubtask)
                    }
                    .padding(.leading, 24)
                }
            }
        }
        .contextMenu {
            Section("Task Mode") {
                ForEach(TaskMode.allCases, id: \.self) { mode in
                    Button {
                        store.updateTaskMode(categoryID: categoryID, taskID: task.id, mode: mode)
                    } label: {
                        Label(mode.label, systemImage: mode.symbol)
                        if task.mode == mode { Image(systemName: "checkmark") }
                    }
                }
            }
            Section("Task Type") {
                ForEach(TaskType.allCases, id: \.self) { type in
                    Button {
                        store.updateTaskType(categoryID: categoryID, taskID: task.id, type: type)
                    } label: {
                        Label(type.label, systemImage: type.symbol)
                        if task.taskType == type { Image(systemName: "checkmark") }
                    }
                }
            }
            Section {
                Button("Edit Title", systemImage: "pencil") {
                    editedTitle = task.title
                    isEditingTitle = true
                }
                if task.subtasks.isEmpty && !isPastWeek {
                    Button("Add Sub-Task", systemImage: "list.bullet.indent") {
                        store.addSubtask(categoryID: categoryID, taskID: task.id, title: "New sub-task")
                    }
                }
                Button("Delete", systemImage: "trash", role: .destructive) {
                    store.deleteTask(categoryID: categoryID, taskID: task.id)
                }
            }
        }
    }

    // Mode icons: carry-over, repeating, one-time + delete (shown when NOT editing title)
    private var taskModeIcons: some View {
        HStack(spacing: 6) {
            ForEach(TaskMode.allCases, id: \.self) { mode in
                Button {
                    store.updateTaskMode(categoryID: categoryID, taskID: task.id, mode: mode)
                } label: {
                    Image(systemName: mode.symbol)
                        .font(.caption2)
                        .foregroundStyle(task.mode == mode ? .blue : .secondary)
                }
                .buttonStyle(.plain)
            }
            Button {
                withAnimation(.snappy(duration: 0.2)) {
                    store.deleteTask(categoryID: categoryID, taskID: task.id)
                }
            } label: {
                Image(systemName: "trash")
                    .font(.caption2).foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
    }

    // Type icons: checkbox + goal (shown when editing title)
    private var taskTypeIcons: some View {
        HStack(spacing: 6) {
            ForEach(TaskType.allCases, id: \.self) { type in
                Button {
                    store.updateTaskType(categoryID: categoryID, taskID: task.id, type: type)
                } label: {
                    Image(systemName: type.symbol)
                        .font(.caption2)
                        .foregroundStyle(task.taskType == type ? .blue : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var goalIndicator: some View {
        if task.goalIsComplete {
            Circle()
                .fill(Color.green)
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: 8).bold())
                        .foregroundStyle(.white)
                )
                .frame(width: 14, height: 14)
        } else if let target = task.goalTarget, target > 0 {
            ZStack {
                Circle().stroke(Color.secondary.opacity(0.3), lineWidth: 2)
                Circle()
                    .trim(from: 0, to: min((task.goalProgress ?? 0) / target, 1.0))
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 14, height: 14)
        } else {
            Image(systemName: "target")
                .font(.caption).foregroundStyle(.orange)
        }
    }

    private var goalProgressSection: some View {
        VStack(spacing: 6) {
            if let target = task.goalTarget, target > 0 {
                // Progress bar + fraction
                HStack(spacing: 10) {
                    ProgressView(value: min((task.goalProgress ?? 0) / target, 1.0))
                        .tint(task.goalIsComplete ? .green : .blue)
                    Text(task.goalFraction)
                        .font(.caption.bold().monospacedDigit())
                        .foregroundStyle(task.goalIsComplete ? .green : .primary)
                    if let unit = task.goalUnit, !unit.isEmpty {
                        Text(unit).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.leading, 24)

                // Add progress input
                if !isPastWeek && !task.goalIsComplete {
                    HStack(spacing: 8) {
                        Image(systemName: "plus").font(.caption).foregroundStyle(.tertiary)
                        TextField("Add progress", text: $addProgressText)
                            .font(.caption).keyboardType(.decimalPad).onSubmit(addGoalProgress)
                        Button { addGoalProgress() } label: {
                            Text("Add")
                                .font(.caption2.bold())
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(.blue, in: Capsule())
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                        .disabled(Double(addProgressText) == nil)
                    }
                    .padding(.leading, 24)
                }
            } else if !isPastWeek {
                // Goal setup: [target] - [unit] Set
                HStack(spacing: 6) {
                    TextField("Target", text: $goalTargetText)
                        .font(.caption).keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                    Text("—").font(.caption).foregroundStyle(.tertiary)
                    TextField("Unit", text: $goalUnitText)
                        .font(.caption)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        if let target = Double(goalTargetText), target > 0 {
                            store.setGoalTarget(categoryID: categoryID, taskID: task.id, target: target, unit: goalUnitText)
                        }
                        goalTargetText = ""
                        goalUnitText = ""
                    } label: {
                        Text("Set")
                            .font(.caption.bold())
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(.blue, in: Capsule())
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .disabled(Double(goalTargetText) == nil)
                }
                .padding(.leading, 24)
            }
        }
        .padding(.top, 2)
    }

    private func addSubtask() {
        let title = newSubtaskTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        withAnimation(.snappy(duration: 0.2)) {
            store.addSubtask(categoryID: categoryID, taskID: task.id, title: title)
        }
        newSubtaskTitle = ""
    }

    private func addGoalProgress() {
        guard let amount = Double(addProgressText), amount > 0 else { return }
        let current = task.goalProgress ?? 0
        withAnimation(.snappy(duration: 0.2)) {
            store.updateGoalProgress(categoryID: categoryID, taskID: task.id, progress: current + amount)
        }
        addProgressText = ""
    }
}

// MARK: - Sub-Task Row (Card)

struct SubTaskRowCard: View {
    let subtask: SubTask
    let categoryID: UUID
    let taskID: UUID
    let store: ChecklistStore
    let isEditing: Bool
    let isPastWeek: Bool

    @State private var isEditingTitle = false
    @State private var editedTitle = ""

    var body: some View {
        HStack(spacing: 6) {
            Button {
                guard !isPastWeek else { return }
                withAnimation(.snappy(duration: 0.2)) {
                    store.toggleSubtask(categoryID: categoryID, taskID: taskID, subtaskID: subtask.id)
                }
            } label: {
                Circle()
                    .fill(subtask.isCompleted ? Color.green : Color.clear)
                    .overlay(Circle().stroke(subtask.isCompleted ? Color.green : Color.secondary, lineWidth: 1))
                    .frame(width: 10, height: 10)
            }
            .buttonStyle(.plain)

            if isEditing && isEditingTitle {
                TextField("Sub-task", text: $editedTitle)
                    .font(.caption)
                    .onSubmit {
                        let title = editedTitle.trimmingCharacters(in: .whitespaces)
                        if !title.isEmpty {
                            store.renameSubtask(categoryID: categoryID, taskID: taskID, subtaskID: subtask.id, newTitle: title)
                        }
                        isEditingTitle = false
                    }
            } else {
                Text(subtask.title)
                    .font(.caption)
                    .foregroundStyle(subtask.isCompleted ? .tertiary : .secondary)
                    .strikethrough(subtask.isCompleted, color: .secondary)
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
                        .font(.caption2).foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.leading, 24)
    }
}

// MARK: - Add Task Row (Card)

struct AddTaskRowCard: View {
    let categoryID: UUID
    let store: ChecklistStore
    @State private var newTitle = ""
    @State private var newMode: TaskMode = .carryOver
    @State private var newType: TaskType = .checkbox
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle")
                .font(.subheadline).foregroundStyle(.tertiary)
            TextField("Add task", text: $newTitle)
                .font(.subheadline).focused($isFocused).onSubmit(addTask)
            if isFocused {
                Menu {
                    Section("Task Type") {
                        ForEach(TaskType.allCases, id: \.self) { type in
                            Button {
                                newType = type
                            } label: {
                                Label(type.label, systemImage: type.symbol)
                                if newType == type { Image(systemName: "checkmark") }
                            }
                        }
                    }
                    Section("Task Mode") {
                        ForEach(TaskMode.allCases, id: \.self) { mode in
                            Button {
                                newMode = mode
                            } label: {
                                Label(mode.label, systemImage: mode.symbol)
                                if newMode == mode { Image(systemName: "checkmark") }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: newType.symbol)
                        Image(systemName: newMode.symbol)
                    }
                    .font(.caption2).foregroundStyle(.secondary)
                    .padding(4).background(.quaternary, in: Capsule())
                }
            }
        }
    }

    private func addTask() {
        let title = newTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        withAnimation(.snappy(duration: 0.2)) {
            store.addTask(categoryID: categoryID, title: title, mode: newMode)
            if newType == .goal, let week = store.selectedWeek,
               let cat = week.categories.first(where: { $0.id == categoryID }),
               let task = cat.tasks.last {
                store.updateTaskType(categoryID: categoryID, taskID: task.id, type: .goal)
            }
        }
        newTitle = ""
    }
}

// MARK: - Add Category Sheet

struct AddCategorySheet: View {
    let store: ChecklistStore
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
                            Button("Add to Week & Save") { createNew() }
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
        dismiss()
    }

    private func createNew() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        store.addSavedCategory(name: name, symbol: newSymbol)
        store.addCategory(name: name, symbol: newSymbol)
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
                DatePicker("Select a week", selection: $pickerDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .tint(.blue)
                Text("Selected: Week of \(formattedMonday)")
                    .font(.subheadline).foregroundStyle(.secondary)
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
    @State private var editingName = ""
    @State private var isEditingName = false

    var body: some View {
        NavigationStack {
            List {
                Section("Name") {
                    if isEditingName {
                        HStack {
                            TextField("Your name", text: $editingName)
                                .onSubmit {
                                    let name = editingName.trimmingCharacters(in: .whitespaces)
                                    if !name.isEmpty && name.count <= 20 { store.setUserName(name) }
                                    isEditingName = false
                                }
                            Button("Save") {
                                let name = editingName.trimmingCharacters(in: .whitespaces)
                                if !name.isEmpty && name.count <= 20 { store.setUserName(name) }
                                isEditingName = false
                            }
                            .disabled(editingName.trimmingCharacters(in: .whitespaces).isEmpty || editingName.count > 20)
                        }
                    } else {
                        HStack {
                            Text(store.userName.isEmpty ? "Not set" : store.userName)
                                .foregroundStyle(store.userName.isEmpty ? .secondary : .primary)
                            Spacer()
                            Button("Edit") {
                                editingName = store.userName
                                isEditingName = true
                            }
                            .font(.subheadline)
                        }
                    }
                }

                Section("Appearance") {
                    ForEach(AppearanceMode.allCases, id: \.self) { mode in
                        Button {
                            withAnimation { store.setAppearance(mode) }
                        } label: {
                            HStack {
                                Label(mode.label, systemImage: mode.symbol).foregroundStyle(.primary)
                                Spacer()
                                if store.appearanceMode == mode {
                                    Image(systemName: "checkmark").foregroundStyle(.blue)
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
                            .font(.caption).foregroundStyle(.secondary)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(.quaternary, in: Capsule())
                    }
                }

                Section {
                    Button { showHelp = true } label: {
                        Label("How to Use Tasquel", systemImage: "questionmark.circle")
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
            .sheet(isPresented: $showHelp) { HelpSheet() }
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
                    HelpRow(symbol: "calendar", title: "Navigate Weeks",
                            detail: "Use the arrows or tap the calendar icon to jump to any week. Future weeks can be pre-populated. Past weeks can be reviewed.")
                    HelpRow(symbol: "square.grid.2x2", title: "Category Cards",
                            detail: "Tap a card to expand and view all tasks. Tap the collapse arrow to return to grid view. Long-press for options: save, remove, or delete.")
                    HelpRow(symbol: "pencil", title: "Edit Mode",
                            detail: "Tap the pencil icon to enter edit mode. From here you can add categories, change task modes, and delete tasks using the inline icons.")
                }

                Section("Task Modes") {
                    HelpRow(symbol: "arrow.uturn.forward", title: "Carry Over",
                            detail: "Default mode. If not completed by end of the week, it rolls forward to the next week. Completed tasks do not carry over.")
                    HelpRow(symbol: "repeat", title: "Repeating",
                            detail: "Appears every week automatically regardless of completion. Great for recurring habits. Resets to unchecked each new week.")
                    HelpRow(symbol: "1.circle", title: "One-Time",
                            detail: "This week only. Will not carry forward or repeat, whether completed or not.")
                    HelpRow(symbol: "hand.draw", title: "Changing Modes",
                            detail: "In edit mode, use the inline mode icons on each task. Or long-press a task for the context menu. Double-tap a task title to edit it inline.")
                }

                Section("Task Types") {
                    HelpRow(symbol: "checkmark.circle", title: "Checkbox",
                            detail: "Standard task — tap the circle to mark complete. This is the default type for all new tasks.")
                    HelpRow(symbol: "target", title: "Goal",
                            detail: "Track progress toward a numeric target (e.g. 50 push-ups). Tap the progress ring to update. Auto-completes when the target is reached.")
                    HelpRow(symbol: "arrow.left.arrow.right", title: "Switching Types",
                            detail: "Long-press a task and choose a type from the context menu.")
                }

                Section("Sub-Tasks") {
                    HelpRow(symbol: "list.bullet.indent", title: "Adding Sub-Tasks",
                            detail: "Tasks with sub-tasks show them inline when expanded. Type in the field below to add more. Long-press a task to add the first sub-task.")
                    HelpRow(symbol: "checkmark.circle", title: "Completing Sub-Tasks",
                            detail: "Tap any sub-task's circle to check it off. Sub-task progress shows as a count on the parent task.")
                }

                Section("Managing Categories") {
                    HelpRow(symbol: "square.and.arrow.down", title: "Save for Future",
                            detail: "Long-press a category card and choose \"Save for Future Use\" to add it to your template library.")
                    HelpRow(symbol: "trash", title: "Removing Categories",
                            detail: "Long-press a category card to remove from this week only or delete entirely including from saved categories.")
                }

                Section("Upcoming Features") {
                    HelpRow(symbol: "calendar.badge.plus", title: "Calendar Integration",
                            detail: "A future paid upgrade will allow importing your personal calendar events directly into Tasquel as tasks.")
                }
            }
            .navigationTitle("How to Use Tasquel")
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
            Label(title, systemImage: symbol).font(.subheadline.bold())
            Text(detail).font(.subheadline).foregroundStyle(.secondary)
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
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2).foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 16).padding(.trailing, 20)

            Text("Remove \"\(category.name)\"")
                .font(.headline).padding(.top, 4)

            Text("Remove from this week only, or delete entirely including from saved categories?")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32).padding(.top, 8)

            VStack(spacing: 12) {
                Button {
                    withAnimation { store.deleteCategory(category.id) }
                    dismiss()
                } label: {
                    Text("Remove from This Week").frame(maxWidth: .infinity)
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
                    Text("Delete Entirely").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 32).padding(.top, 20)

            Spacer()
        }
    }
}

// MARK: - Onboarding Sheet

struct OnboardingSheet: View {
    let store: ChecklistStore
    @Environment(\.dismiss) private var dismiss

    @State private var step: OnboardingStep = .overview
    @State private var userName = ""
    @State private var selectedCategories = CategoryTemplate.starters
    @State private var newName = ""
    @State private var newSymbol = "folder"
    @State private var isAddingCategory = false

    enum OnboardingStep {
        case overview, features, name, categories
    }

    private let symbolOptions = [
        "folder", "star", "heart", "house", "cart",
        "briefcase", "figure.run", "book", "paintbrush",
        "music.note", "fork.knife", "airplane", "gift",
        "wrench.and.screwdriver", "leaf", "pawprint",
        "calendar.badge.clock", "lightbulb", "sparkles",
    ]

    private let gridColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .overview: overviewView
                case .features: featuresView
                case .name: nameView
                case .categories: categorySetupView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var overviewView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.circle")
                .font(.system(size: 60)).foregroundStyle(.green)
            Text("Welcome to Tasquel").font(.largeTitle.bold())
            VStack(spacing: 12) {
                Text("Your weekly task planner that keeps you on track.")
                    .font(.headline).multilineTextAlignment(.center)
                Text("Tasquel organizes your tasks into weekly checklists. If you don't finish something this week, it automatically carries over to the next — so nothing falls through the cracks.")
                    .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            Spacer()
            Button {
                withAnimation(.snappy(duration: 0.3)) { step = .features }
            } label: {
                Text("Next").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 32).padding(.bottom, 32)
        }
    }

    private var featuresView: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("How It Works").font(.title2.bold())
            VStack(alignment: .leading, spacing: 16) {
                OnboardingFeatureRow(symbol: "arrow.uturn.forward", title: "Carry Over",
                                     detail: "Default mode — incomplete tasks automatically move to next week.")
                OnboardingFeatureRow(symbol: "repeat", title: "Repeating",
                                     detail: "Appears every week regardless of completion. Great for habits.")
                OnboardingFeatureRow(symbol: "1.circle", title: "One-Time",
                                     detail: "This week only — won't carry forward or repeat.")
                OnboardingFeatureRow(symbol: "checkmark.circle", title: "Checkbox Tasks",
                                     detail: "Simple check-off tasks with optional sub-tasks.")
                OnboardingFeatureRow(symbol: "target", title: "Goal Tasks",
                                     detail: "Track numeric progress (e.g. 30/50 push-ups). Auto-completes when target is reached.")
            }
            .padding(.horizontal, 24)
            Spacer()
            Button {
                withAnimation(.snappy(duration: 0.3)) { step = .name }
            } label: {
                Text("Next").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 32).padding(.bottom, 32)
        }
    }

    private var nameView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "person.circle")
                .font(.system(size: 60)).foregroundStyle(.blue)
            Text("What's your name?").font(.title2.bold())
            TextField("Your name", text: $userName)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 48).autocorrectionDisabled()
            Text("1-20 characters").font(.caption).foregroundStyle(.secondary)
            Spacer()
            Button {
                let trimmed = userName.trimmingCharacters(in: .whitespaces)
                store.setUserName(trimmed)
                withAnimation(.snappy(duration: 0.3)) { step = .categories }
            } label: {
                Text("Next").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .disabled(userName.trimmingCharacters(in: .whitespaces).isEmpty || userName.count > 20)
            .padding(.horizontal, 32).padding(.bottom, 32)
        }
    }

    private var categorySetupView: some View {
        VStack(spacing: 16) {
            Text("Set Up Your Categories").font(.title2.bold()).padding(.top, 24)
            Text("Tap a category to remove it, or add your own.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, 24)

            ScrollView {
                LazyVGrid(columns: gridColumns, spacing: 12) {
                    ForEach(selectedCategories) { template in
                        Button {
                            withAnimation(.snappy(duration: 0.2)) {
                                selectedCategories.removeAll { $0.id == template.id }
                            }
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: template.symbol).font(.title2)
                                Text(template.name).font(.caption.bold()).lineLimit(1)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption).foregroundStyle(.secondary).padding(4),
                                alignment: .topTrailing
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    if isAddingCategory {
                        VStack(spacing: 6) {
                            Menu {
                                ForEach(symbolOptions, id: \.self) { symbol in
                                    Button { newSymbol = symbol } label: {
                                        Label(symbol, systemImage: symbol)
                                    }
                                }
                            } label: {
                                Image(systemName: newSymbol).font(.title2)
                            }
                            TextField("Name", text: $newName)
                                .font(.caption).multilineTextAlignment(.center)
                                .onSubmit(addCustomCategory)
                            HStack(spacing: 8) {
                                Button("Cancel") {
                                    isAddingCategory = false; newName = ""
                                }
                                .font(.system(size: 10))
                                Button("Add") { addCustomCategory() }
                                    .font(.system(size: 10).bold())
                                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                            }
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                    } else {
                        Button { isAddingCategory = true } label: {
                            VStack(spacing: 8) {
                                Image(systemName: "plus.circle").font(.title2)
                                Text("Add").font(.caption.bold())
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
            }

            Spacer()

            Button { finishOnboarding() } label: {
                Text("Let's Go!").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 32).padding(.bottom, 32)
        }
    }

    private func addCustomCategory() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        selectedCategories.append(CategoryTemplate(name: name, symbol: newSymbol))
        newName = ""
        newSymbol = "folder"
        isAddingCategory = false
    }

    private func finishOnboarding() {
        store.savedCategories = selectedCategories
        store.saveSettings()
        store.replaceCurrentWeekCategories(with: selectedCategories.map {
            Category(name: $0.name, symbol: $0.symbol)
        })
        store.dismissWelcome()
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
                .font(.title2).foregroundStyle(.blue).frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.bold())
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    ContentView()
}
