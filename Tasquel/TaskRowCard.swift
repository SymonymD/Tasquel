import SwiftUI

// MARK: - Task Row (Card)

struct TaskRowCard: View {
    let task: ChecklistTask
    let categoryID: UUID
    let store: ChecklistStore
    let isEditing: Bool
    var isPastWeek: Bool = false

    private var theme: AppearanceMode { store.appearanceMode }
    private var rc: RetroColor { store.retroColor }

    @State private var isEditingTitle = false
    @State private var editedTitle = ""
    @State private var newSubtaskTitle = ""
    @State private var addProgressText = ""
    @State private var goalTargetText = ""
    @State private var goalUnitText = ""
    @State private var editedGoalProgressText = ""
    @State private var isEditingGoal = false
    @State private var showDeleteConfirmation = false
    @State private var showTypeChangeConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
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
                        if Theme.isRetro(theme) {
                            Text(task.isCompleted ? "[x]" : "[ ]")
                                .font(.system(.subheadline, design: .monospaced).bold())
                                .foregroundStyle(task.isCompleted ? Theme.dotComplete(theme, rc: rc) : Theme.textSecondary(theme, rc: rc))
                        } else {
                            Circle()
                                .fill(task.isCompleted ? Theme.dotComplete(theme, rc: rc) : Color.clear)
                                .overlay(Circle().stroke(task.isCompleted ? Theme.dotComplete(theme, rc: rc) : Theme.textSecondary(theme, rc: rc), lineWidth: 1.5))
                                .frame(width: 18, height: 18)
                        }
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle().size(width: 36, height: 36))
                }

                // Title
                if isEditingTitle {
                    TextField("Task name", text: $editedTitle)
                        .font(Theme.isRetro(theme) ? .system(size: 16, design: .monospaced) : .system(size: 16))
                        .onSubmit {
                            let title = editedTitle.trimmingCharacters(in: .whitespaces)
                            if !title.isEmpty {
                                store.renameTask(categoryID: categoryID, taskID: task.id, newTitle: title)
                            }
                            isEditingTitle = false
                        }
                } else {
                    Text(task.title)
                        .font(Theme.isRetro(theme) ? .system(size: 16, design: .monospaced) : .system(size: 16))
                        .foregroundStyle(Theme.textPrimary(theme, rc: rc))
                        .onTapGesture(count: 2) {
                            guard !isPastWeek else { return }
                            editedTitle = task.title
                            isEditingTitle = true
                        }
                        .onTapGesture {
                            if isEditing && !isPastWeek {
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
                    HStack(spacing: 8) {
                        Image(systemName: Theme.isRetro(theme) ? "greaterthan" : "plus.circle")
                            .font(.caption).foregroundStyle(Theme.textTertiary(theme, rc: rc))
                        TextField(Theme.isRetro(theme) ? "sub_task>" : "Add sub-task", text: $newSubtaskTitle)
                            .font(Theme.captionFont(theme))
                            .onSubmit(addSubtask)
                    }
                    .padding(.leading, 24)
                    .padding(.vertical, 2)
                }
            }
        }
        .contextMenu {
            if !isPastWeek {
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
                        selectTaskType(type)
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
                    showDeleteConfirmation = true
                }
            }
            }
        }
        .confirmationDialog("Delete \(task.title)?", isPresented: $showDeleteConfirmation) {
            Button("Delete Task", role: .destructive) {
                store.deleteTask(categoryID: categoryID, taskID: task.id)
            }
        } message: {
            Text("This removes the task and its sub-tasks from this week.")
        }
        .confirmationDialog("Change to checkbox?", isPresented: $showTypeChangeConfirmation) {
            Button("Change Type", role: .destructive) {
                store.updateTaskType(categoryID: categoryID, taskID: task.id, type: .checkbox)
            }
        } message: {
            Text("This clears the goal target and progress.")
        }
    }

    // Mode icons: carry-over, repeating, one-time + delete (shown IN edit mode)
    private var taskModeIcons: some View {
        HStack(spacing: 0) {
            ForEach(TaskMode.allCases, id: \.self) { mode in
                Button {
                    store.updateTaskMode(categoryID: categoryID, taskID: task.id, mode: mode)
                } label: {
                    Image(systemName: mode.symbol)
                        .font(.system(size: 16))
                        .foregroundStyle(task.mode == mode ? Theme.accent(theme, rc: rc) : Theme.textSecondary(theme, rc: rc))
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Button {
                withAnimation(.snappy(duration: 0.2)) {
                    showDeleteConfirmation = true
                }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 16)).foregroundStyle(Theme.destructive(theme))
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // Type icons: checkbox + goal (shown when NOT in edit mode)
    private var taskTypeIcons: some View {
        HStack(spacing: 0) {
            ForEach(TaskType.allCases, id: \.self) { type in
                Button {
                    selectTaskType(type)
                } label: {
                    Image(systemName: type.symbol)
                        .font(.system(size: 16))
                        .foregroundStyle(task.taskType == type ? Theme.accent(theme, rc: rc) : Theme.textSecondary(theme, rc: rc))
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var goalIndicator: some View {
        if Theme.isRetro(theme) {
            if task.goalIsComplete {
                Text("[OK]")
                    .font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(Theme.dotComplete(theme, rc: rc))
            } else if let target = task.goalTarget, target > 0 {
                Text("[\(Int(task.goalProgress ?? 0))/\(Int(target))]")
                    .font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(Theme.accent(theme, rc: rc))
            } else {
                Text("[??]")
                    .font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(Theme.completionPartial(theme))
            }
        } else {
            if task.goalIsComplete {
                Circle()
                    .fill(Theme.dotComplete(theme, rc: rc))
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 12).bold())
                            .foregroundStyle(.white)
                    )
                    .frame(width: 18, height: 18)
            } else if let target = task.goalTarget, target > 0 {
                ZStack {
                    Circle().stroke(Theme.textTertiary(theme, rc: rc), lineWidth: 2.5)
                    Circle()
                        .trim(from: 0, to: min((task.goalProgress ?? 0) / target, 1.0))
                        .stroke(Theme.accent(theme, rc: rc), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 18, height: 18)
            } else {
                Image(systemName: "target")
                    .font(.system(size: 12)).foregroundStyle(Theme.completionPartial(theme))
            }
        }
    }

    private var goalProgressSection: some View {
        VStack(spacing: 6) {
            if let target = task.goalTarget, target > 0 {
                HStack(spacing: 10) {
                    ProgressView(value: min((task.goalProgress ?? 0) / target, 1.0))
                        .tint(task.goalIsComplete ? Theme.dotComplete(theme, rc: rc) : Theme.accent(theme, rc: rc))
                    Text(task.goalFraction)
                        .font(Theme.isRetro(theme) ? .system(.caption, design: .monospaced).bold() : .caption.bold().monospacedDigit())
                        .foregroundStyle(task.goalIsComplete ? Theme.dotComplete(theme, rc: rc) : Theme.textPrimary(theme, rc: rc))
                    if let unit = task.goalUnit, !unit.isEmpty {
                        Text(unit).font(Theme.captionFont(theme)).foregroundStyle(Theme.textSecondary(theme, rc: rc))
                    }
                }
                .padding(.leading, 24)

                if !isPastWeek {
                    Button(isEditingGoal ? "Cancel editing goal" : "Edit goal") {
                        if isEditingGoal {
                            isEditingGoal = false
                        } else {
                            goalTargetText = String(target)
                            editedGoalProgressText = String(task.goalProgress ?? 0)
                            goalUnitText = task.goalUnit ?? ""
                            isEditingGoal = true
                        }
                    }
                    .font(.caption)
                    .padding(.leading, 24)
                }

                if isEditingGoal && !isPastWeek {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Target", text: $goalTargetText)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                        TextField("Progress", text: $editedGoalProgressText)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                        TextField("Unit", text: $goalUnitText)
                            .textFieldStyle(.roundedBorder)
                        Button("Save Goal") {
                            guard let target = Double(goalTargetText), target.isFinite, target > 0,
                                  let progress = Double(editedGoalProgressText), progress.isFinite, progress >= 0 else { return }
                            store.setGoalTarget(categoryID: categoryID, taskID: task.id, target: target, unit: goalUnitText)
                            store.updateGoalProgress(categoryID: categoryID, taskID: task.id, progress: progress)
                            isEditingGoal = false
                        }
                        .disabled(!canSaveEditedGoal)
                    }
                    .padding(.leading, 24)
                }

                if !isPastWeek && !task.goalIsComplete && !isEditingGoal {
                    HStack(spacing: 8) {
                        Image(systemName: "plus").font(.subheadline).foregroundStyle(Theme.textTertiary(theme, rc: rc))
                        TextField("Add progress", text: $addProgressText)
                            .font(.subheadline)
                            .foregroundStyle(Theme.textPrimary(theme, rc: rc))
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.plain)
                            .padding(.bottom, 4)
                            .overlay(alignment: .bottom) {
                                Rectangle().fill(Theme.textTertiary(theme, rc: rc)).frame(height: 1)
                            }
                            .onSubmit(addGoalProgress)
                        Button { addGoalProgress() } label: {
                            Text("Add")
                                .font(.caption.bold())
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(Theme.accent(theme, rc: rc), in: Capsule())
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                        .disabled(!(Double(addProgressText).map { $0.isFinite && $0 > 0 } ?? false))
                    }
                    .padding(.leading, 24)
                }
            } else if !isPastWeek {
                HStack(spacing: 8) {
                    TextField("Target", text: $goalTargetText)
                        .font(Theme.isRetro(theme) ? .system(.subheadline, design: .monospaced) : .subheadline)
                        .foregroundStyle(Theme.textPrimary(theme, rc: rc))
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 70)
                    Text("—").font(.caption).foregroundStyle(Theme.textTertiary(theme, rc: rc))
                    TextField("Unit", text: $goalUnitText)
                        .font(Theme.isRetro(theme) ? .system(.subheadline, design: .monospaced) : .subheadline)
                        .foregroundStyle(Theme.textPrimary(theme, rc: rc))
                        .textFieldStyle(.roundedBorder)
                    Button {
                        if let target = Double(goalTargetText), target > 0 {
                            store.setGoalTarget(categoryID: categoryID, taskID: task.id, target: target, unit: goalUnitText)
                        }
                        if Double(goalTargetText).map({ $0.isFinite && $0 > 0 }) == true {
                            goalTargetText = ""
                            goalUnitText = ""
                        }
                    } label: {
                        Text("Set")
                            .font(.caption.bold())
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Theme.accent(theme, rc: rc), in: Capsule())
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .disabled(!(Double(goalTargetText).map { $0.isFinite && $0 > 0 } ?? false))
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

    private var canSaveEditedGoal: Bool {
        guard let target = Double(goalTargetText), target.isFinite, target > 0,
              let progress = Double(editedGoalProgressText), progress.isFinite, progress >= 0 else { return false }
        return true
    }

    private func selectTaskType(_ type: TaskType) {
        guard !isPastWeek, task.taskType != type else { return }
        if task.taskType == .goal && type == .checkbox &&
            (task.goalTarget != nil || task.goalProgress != nil) {
            showTypeChangeConfirmation = true
        } else {
            store.updateTaskType(categoryID: categoryID, taskID: task.id, type: type)
        }
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

    private var theme: AppearanceMode { store.appearanceMode }
    private var rc: RetroColor { store.retroColor }

    @State private var isEditingTitle = false
    @State private var editedTitle = ""
    @State private var showDeleteConfirmation = false

    var body: some View {
        HStack(spacing: 8) {
            Button {
                guard !isPastWeek else { return }
                withAnimation(.snappy(duration: 0.2)) {
                    store.toggleSubtask(categoryID: categoryID, taskID: taskID, subtaskID: subtask.id)
                }
            } label: {
                if Theme.isRetro(theme) {
                    Text(subtask.isCompleted ? "[x]" : "[ ]")
                        .font(.system(.caption, design: .monospaced).bold())
                        .foregroundStyle(subtask.isCompleted ? Theme.dotComplete(theme, rc: rc) : Theme.textSecondary(theme, rc: rc))
                } else {
                    Circle()
                        .fill(subtask.isCompleted ? Theme.dotComplete(theme, rc: rc) : Color.clear)
                        .overlay(Circle().stroke(subtask.isCompleted ? Theme.dotComplete(theme, rc: rc) : Theme.textSecondary(theme, rc: rc), lineWidth: 1.5))
                        .frame(width: 14, height: 14)
                }
            }
            .buttonStyle(.plain)

            if isEditing && !isPastWeek && isEditingTitle {
                TextField("Sub-task", text: $editedTitle)
                    .font(Theme.isRetro(theme) ? .system(size: 14, design: .monospaced) : .system(size: 14))
                    .onSubmit {
                        let title = editedTitle.trimmingCharacters(in: .whitespaces)
                        if !title.isEmpty {
                            store.renameSubtask(categoryID: categoryID, taskID: taskID, subtaskID: subtask.id, newTitle: title)
                        }
                        isEditingTitle = false
                    }
            } else {
                Text(subtask.title)
                    .font(Theme.isRetro(theme) ? .system(size: 14, design: .monospaced) : .system(size: 14))
                    .foregroundStyle(subtask.isCompleted ? Theme.textTertiary(theme, rc: rc) : Theme.textSecondary(theme, rc: rc))
                    .strikethrough(subtask.isCompleted && !Theme.isRetro(theme), color: Theme.textSecondary(theme, rc: rc))
                    .onTapGesture {
                        if isEditing && !isPastWeek {
                            editedTitle = subtask.title
                            isEditingTitle = true
                        }
                    }
            }

            Spacer()

            if isEditing && !isPastWeek {
                Button {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.caption).foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.leading, 24)
        .padding(.vertical, 2)
        .confirmationDialog("Delete \(subtask.title)?", isPresented: $showDeleteConfirmation) {
            Button("Delete Sub-Task", role: .destructive) {
                store.deleteSubtask(categoryID: categoryID, taskID: taskID, subtaskID: subtask.id)
            }
        }
    }
}

// MARK: - Add Task Row (Card)

struct AddTaskRowCard: View {
    let categoryID: UUID
    let store: ChecklistStore

    private var theme: AppearanceMode { store.appearanceMode }
    private var rc: RetroColor { store.retroColor }

    @State private var newTitle = ""
    @State private var newMode: TaskMode = .carryOver
    @State private var newType: TaskType = .checkbox
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: Theme.isRetro(theme) ? "greaterthan" : "plus.circle")
                .font(.subheadline).foregroundStyle(Theme.textTertiary(theme, rc: rc))
            TextField(Theme.isRetro(theme) ? "new_task>" : "Add task", text: $newTitle)
                .font(Theme.bodyFont(theme)).focused($isFocused).onSubmit(addTask)
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
                    .font(.caption2).foregroundStyle(Theme.textSecondary(theme, rc: rc))
                    .padding(4).background(Theme.textTertiary(theme, rc: rc).opacity(0.3), in: Capsule())
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
