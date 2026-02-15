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
            .navigationTitle(store.selectedWeek?.displayTitle ?? "Tasquel")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if !isPastWeek {
                        if isEditing {
                            Button {
                                withAnimation(.snappy(duration: 0.25)) { isEditing.toggle() }
                            } label: {
                                Image(systemName: "checkmark")
                                    .font(.subheadline.bold())
                                    .padding(6)
                                    .background(.green.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.green, lineWidth: 1.5))
                            }
                            .tint(.green)
                        } else {
                            Button {
                                withAnimation(.snappy(duration: 0.25)) { isEditing.toggle() }
                            } label: {
                                Image(systemName: "pencil")
                                    .font(.subheadline.bold())
                            }
                        }
                    }
                }
            }
            .overlay(alignment: .bottomLeading) {
                weekNavigationBar
                    .padding(.leading, 16)
                    .padding(.bottom, 12)
            }
            .overlay(alignment: .bottomTrailing) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.body)
                        .padding(12)
                        .background(.regularMaterial, in: Circle())
                        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                }
                .padding(.trailing, 16)
                .padding(.bottom, 12)
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

    private var isPastWeek: Bool {
        store.selectedWeek?.isPastWeek ?? false
    }

    private var weekNavigationBar: some View {
        HStack(spacing: 20) {
            Button {
                withAnimation { store.navigateWeek(by: -1) }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.bold())
            }

            Button {
                showDatePicker = true
            } label: {
                Image(systemName: "calendar")
                    .font(.body)
            }

            Button {
                withAnimation { store.navigateWeek(by: 1) }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.body.bold())
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
        .scaleEffect(1.1)
    }

    @ViewBuilder
    private func weekContent(_ week: Week) -> some View {
        List {
            dateBanner(week)

            if isEditing && !week.isPastWeek {
                Section {
                    Button {
                        showAddCategory = true
                    } label: {
                        Label("Add Category", systemImage: "plus.circle")
                    }
                }
            }

            ForEach(week.categories) { category in
                categorySection(category, isPast: week.isPastWeek)
            }
        }
        .listStyle(.insetGrouped)
        .animation(.snappy(duration: 0.3), value: week)
        .environment(\.editMode, .constant(isEditing ? .active : .inactive))
        .onChange(of: store.selectedDate) {
            if store.selectedWeek?.isPastWeek == true {
                isEditing = false
            }
            // Auto-expand all categories when navigating to a new week
            if let week = store.selectedWeek {
                expandedCategories = Set(week.categories.map(\.id))
            }
        }
    }

    @ViewBuilder
    private func dateBanner(_ week: Week) -> some View {
        Section {
            HStack {
                Image(systemName: "calendar")
                    .foregroundStyle(.blue)
                Text(todayDateString)
                    .font(.subheadline.bold())
                Spacer()
                if week.isCurrentWeek {
                    Text("Today")
                        .font(.subheadline.bold())
                        .foregroundStyle(.blue)
                } else {
                    Button("Today") {
                        withAnimation { store.navigateToDate(Date()) }
                    }
                    .font(.subheadline.bold())
                }
            }
        }
    }

    private var todayDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d"
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

    private func categorySection(_ category: Category, isPast: Bool) -> some View {
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
                TaskRow(task: task, categoryID: category.id, store: store, isEditing: isEditing, isPastWeek: isPast)
            }
            .onDelete { indexSet in
                guard !isPast else { return }
                for index in indexSet {
                    let task = category.tasks[index]
                    store.deleteTask(categoryID: category.id, taskID: task.id)
                }
            }

            if !isPast {
                AddTaskRow(categoryID: category.id, store: store)
            }
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
    var isPastWeek: Bool = false

    @State private var isEditingTitle = false
    @State private var editedTitle: String = ""
    @State private var showSubtasks = false
    @State private var newSubtaskTitle = ""
    @State private var addProgressText = ""
    @State private var isSettingGoal = false
    @State private var goalTargetText = ""
    @State private var goalUnitText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main task row
            HStack(spacing: 12) {
                if !isEditing {
                    if task.taskType == .goal {
                        goalIndicator
                    } else {
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
                            .onTapGesture(count: 2) {
                                editedTitle = task.title
                                isEditingTitle = true
                                withAnimation(.snappy(duration: 0.2)) { showSubtasks = true }
                            }
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
                            typePicker
                        } else {
                            Label(task.mode.label, systemImage: task.mode.symbol)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            if task.taskType == .goal, let unit = task.goalUnit, !unit.isEmpty {
                                Text("\(task.goalFraction) \(unit)")
                                    .font(.caption2)
                                    .foregroundStyle(task.goalIsComplete ? .green : .secondary)
                            }
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
                        Image(systemName: task.taskType == .goal ? "chart.bar" : "list.bullet.indent")
                            .font(.subheadline)
                            .foregroundStyle(showSubtasks ? .blue : .secondary)
                    }
                    .buttonStyle(.plain)
                } else if task.taskType == .goal && task.goalTarget != nil {
                    Button {
                        withAnimation(.snappy(duration: 0.2)) { showSubtasks.toggle() }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .rotationEffect(.degrees(showSubtasks ? 90 : 0))
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

            // Expanded content: subtasks for checkbox, progress for goal
            if showSubtasks {
                if task.taskType == .goal {
                    goalProgressSection
                } else {
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

                        if !isPastWeek {
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
                    }
                    .padding(.top, 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
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
            ForEach(TaskMode.allCases, id: \.self) { mode in
                Button {
                    store.updateTaskMode(categoryID: categoryID, taskID: task.id, mode: mode)
                } label: {
                    Label(mode.label, systemImage: mode.symbol)
                }
                .tint(task.mode == mode ? .blue : .indigo)
            }
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
            Section("Task Type") {
                ForEach(TaskType.allCases, id: \.self) { type in
                    Button {
                        store.updateTaskType(categoryID: categoryID, taskID: task.id, type: type)
                    } label: {
                        Label(type.label, systemImage: type.symbol)
                        if task.taskType == type {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
            Section {
                Button("Edit Title", systemImage: "pencil") {
                    editedTitle = task.title
                    isEditingTitle = true
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

    private func addGoalProgress() {
        guard let amount = Double(addProgressText), amount > 0 else { return }
        let current = task.goalProgress ?? 0
        withAnimation(.snappy(duration: 0.2)) {
            store.updateGoalProgress(categoryID: categoryID, taskID: task.id, progress: current + amount)
        }
        addProgressText = ""
    }

    @ViewBuilder
    private var goalIndicator: some View {
        Button {
            withAnimation(.snappy(duration: 0.2)) {
                showSubtasks.toggle()
                if task.goalTarget == nil {
                    isSettingGoal = true
                }
            }
        } label: {
            if task.goalIsComplete {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.green)
            } else if let target = task.goalTarget, target > 0 {
                ZStack {
                    Circle()
                        .stroke(.secondary.opacity(0.3), lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: min((task.goalProgress ?? 0) / target, 1.0))
                        .stroke(.blue, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(Int(task.goalProgress ?? 0))")
                        .font(.system(size: 9).bold())
                        .foregroundStyle(.primary)
                }
                .frame(width: 26, height: 26)
            } else {
                Image(systemName: "target")
                    .font(.title3)
                    .foregroundStyle(.orange)
            }
        }
        .buttonStyle(.plain)
    }

    private var goalProgressSection: some View {
        VStack(spacing: 6) {
            // Progress bar
            if let target = task.goalTarget, target > 0 {
                HStack(spacing: 10) {
                    ProgressView(value: min((task.goalProgress ?? 0) / target, 1.0))
                        .tint(task.goalIsComplete ? .green : .blue)

                    Text("\(task.goalFraction)")
                        .font(.caption.bold().monospacedDigit())
                        .foregroundStyle(task.goalIsComplete ? .green : .primary)

                    if let unit = task.goalUnit, !unit.isEmpty {
                        Text(unit)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.leading, 28)

                // Add progress input
                if !isPastWeek && !task.goalIsComplete {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        TextField("Add progress", text: $addProgressText)
                            .font(.subheadline)
                            .keyboardType(.decimalPad)
                            .onSubmit(addGoalProgress)
                        Button {
                            addGoalProgress()
                        } label: {
                            Text("Add")
                                .font(.caption.bold())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(.blue, in: Capsule())
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                        .disabled(Double(addProgressText) == nil)
                    }
                    .padding(.leading, 28)
                }
            } else {
                // Inline goal setup
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Text("Target:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("e.g. 50", text: $goalTargetText)
                            .font(.subheadline)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                    }
                    HStack(spacing: 8) {
                        Text("Unit:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("e.g. push-ups", text: $goalUnitText)
                            .font(.subheadline)
                            .textFieldStyle(.roundedBorder)
                    }
                    HStack {
                        Spacer()
                        Button("Save Goal") {
                            if let target = Double(goalTargetText), target > 0 {
                                store.setGoalTarget(categoryID: categoryID, taskID: task.id, target: target, unit: goalUnitText)
                            }
                            isSettingGoal = false
                            goalTargetText = ""
                            goalUnitText = ""
                        }
                        .font(.caption.bold())
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(Double(goalTargetText) == nil)
                    }
                }
                .padding(.leading, 28)
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 2)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private var typePicker: some View {
        Menu {
            ForEach(TaskType.allCases, id: \.self) { type in
                Button {
                    store.updateTaskType(categoryID: categoryID, taskID: task.id, type: type)
                    if type == .goal && task.goalTarget == nil {
                        isSettingGoal = true
                    }
                } label: {
                    Label(type.label, systemImage: type.symbol)
                    if task.taskType == type {
                        Image(systemName: "checkmark")
                    }
                }
            }
        } label: {
            Label(task.taskType.label, systemImage: task.taskType.symbol)
                .font(.caption2)
                .foregroundStyle(.orange)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.orange.opacity(0.1), in: Capsule())
        }
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
    @State private var newType: TaskType = .checkbox
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
                    Section("Task Type") {
                        ForEach(TaskType.allCases, id: \.self) { type in
                            Button {
                                newType = type
                            } label: {
                                Label(type.label, systemImage: type.symbol)
                                if newType == type {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                    Section("Task Mode") {
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
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: newType.symbol)
                        Image(systemName: newMode.symbol)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(6)
                    .background(.quaternary, in: Capsule())
                }
            }
        }
    }

    private func addTask() {
        let title = newTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        withAnimation(.snappy(duration: 0.2)) {
            store.addTask(categoryID: categoryID, title: title, mode: newMode)
            // If goal type, update the task type after creation
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
                .tint(.blue)

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
                                    if !name.isEmpty && name.count <= 20 {
                                        store.setUserName(name)
                                    }
                                    isEditingName = false
                                }
                            Button("Save") {
                                let name = editingName.trimmingCharacters(in: .whitespaces)
                                if !name.isEmpty && name.count <= 20 {
                                    store.setUserName(name)
                                }
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
                        detail: "Swipe right on any task to see mode buttons. Swipe left to delete. In edit mode, tap the mode badge to pick. Or long-press a task for the context menu. Double-tap a task title to edit it inline."
                    )
                }

                Section("Task Types") {
                    HelpRow(
                        symbol: "checkmark.circle",
                        title: "Checkbox",
                        detail: "Standard task — tap the circle to mark complete. This is the default type for all new tasks."
                    )
                    HelpRow(
                        symbol: "target",
                        title: "Goal",
                        detail: "Track progress toward a numeric target (e.g. 50 push-ups). Tap the progress ring to update. Auto-completes when the target is reached."
                    )
                    HelpRow(
                        symbol: "arrow.left.arrow.right",
                        title: "Switching Types",
                        detail: "Long-press a task and choose a type from the context menu, or use the type picker in edit mode."
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
                        detail: "A future paid upgrade will allow importing your personal calendar events directly into Tasquel as tasks, toggled in Settings."
                    )
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

    @State private var step: OnboardingStep = .overview
    @State private var userName = ""
    @State private var selectedCategories: [CategoryTemplate]
    @State private var newName = ""
    @State private var newSymbol = "folder"
    @State private var isAddingCategory = false

    enum OnboardingStep {
        case overview
        case features
        case name
        case categories
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

    init(store: ChecklistStore, expandedCategories: Binding<Set<UUID>>) {
        self.store = store
        self._expandedCategories = expandedCategories
        self._selectedCategories = State(initialValue: CategoryTemplate.starters)
    }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .overview:
                    overviewView
                case .features:
                    featuresView
                case .name:
                    nameView
                case .categories:
                    categorySetupView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: Screen 1 — Overview

    private var overviewView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle")
                .font(.system(size: 60))
                .foregroundStyle(.green)

            Text("Welcome to Tasquel")
                .font(.largeTitle.bold())

            VStack(spacing: 12) {
                Text("Your weekly task planner that keeps you on track.")
                    .font(.headline)
                    .multilineTextAlignment(.center)

                Text("Tasquel organizes your tasks into weekly checklists. If you don't finish something this week, it automatically carries over to the next — so nothing falls through the cracks.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)

            Spacer()

            Button {
                withAnimation(.snappy(duration: 0.3)) { step = .features }
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

    // MARK: Screen 2 — Features

    private var featuresView: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("How It Works")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 16) {
                OnboardingFeatureRow(
                    symbol: "arrow.uturn.forward",
                    title: "Carry Over",
                    detail: "Default mode — incomplete tasks automatically move to next week."
                )
                OnboardingFeatureRow(
                    symbol: "repeat",
                    title: "Repeating",
                    detail: "Appears every week regardless of completion. Great for habits."
                )
                OnboardingFeatureRow(
                    symbol: "1.circle",
                    title: "One-Time",
                    detail: "This week only — won't carry forward or repeat."
                )
                OnboardingFeatureRow(
                    symbol: "checkmark.circle",
                    title: "Checkbox Tasks",
                    detail: "Simple check-off tasks with optional sub-tasks."
                )
                OnboardingFeatureRow(
                    symbol: "target",
                    title: "Goal Tasks",
                    detail: "Track numeric progress (e.g. 30/50 push-ups). Auto-completes when target is reached."
                )
            }
            .padding(.horizontal, 24)

            Spacer()

            Button {
                withAnimation(.snappy(duration: 0.3)) { step = .name }
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

    // MARK: Screen 3 — Name

    private var nameView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "person.circle")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            Text("What's your name?")
                .font(.title2.bold())

            TextField("Your name", text: $userName)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 48)
                .autocorrectionDisabled()

            Text("1-20 characters")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                let trimmed = userName.trimmingCharacters(in: .whitespaces)
                store.setUserName(trimmed)
                withAnimation(.snappy(duration: 0.3)) { step = .categories }
            } label: {
                Text("Next")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .disabled(userName.trimmingCharacters(in: .whitespaces).isEmpty || userName.count > 20)
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
    }

    // MARK: Screen 4 — Category Setup

    private var categorySetupView: some View {
        VStack(spacing: 16) {
            Text("Set Up Your Categories")
                .font(.title2.bold())
                .padding(.top, 24)

            Text("Tap a category to remove it, or add your own.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            ScrollView {
                LazyVGrid(columns: gridColumns, spacing: 12) {
                    ForEach(selectedCategories) { template in
                        Button {
                            withAnimation(.snappy(duration: 0.2)) {
                                selectedCategories.removeAll { $0.id == template.id }
                            }
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: template.symbol)
                                    .font(.title2)
                                Text(template.name)
                                    .font(.caption.bold())
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(4),
                                alignment: .topTrailing
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    // Add category tile
                    if isAddingCategory {
                        VStack(spacing: 6) {
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
                                    .font(.title2)
                            }
                            TextField("Name", text: $newName)
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .onSubmit(addCustomCategory)
                            HStack(spacing: 8) {
                                Button("Cancel") {
                                    isAddingCategory = false
                                    newName = ""
                                }
                                .font(.system(size: 10))
                                Button("Add") { addCustomCategory() }
                                    .font(.system(size: 10).bold())
                                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                    } else {
                        Button {
                            isAddingCategory = true
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: "plus.circle")
                                    .font(.title2)
                                Text("Add")
                                    .font(.caption.bold())
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
            }

            Spacer()

            Button {
                finishOnboarding()
            } label: {
                Text("Let's Go!")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
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
        // Use whatever categories the user has selected/added
        store.savedCategories = selectedCategories
        store.saveSettings()

        // Replace current week's categories
        store.replaceCurrentWeekCategories(with: selectedCategories.map {
            Category(name: $0.name, symbol: $0.symbol)
        })

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
