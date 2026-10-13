import SwiftUI
import UIKit

// MARK: - Expanded Card Sizing

/// Everything inside an expanded card is drawn 15% larger than its base size.
let expandedCardScale: CGFloat = 1.15

extension Font {
    /// A text style enlarged for expanded cards; follows the user's Dynamic Type size.
    static func expandedCard(_ style: UIFont.TextStyle, weight: Font.Weight = .regular, design: Font.Design = .default) -> Font {
        .system(size: UIFont.preferredFont(forTextStyle: style).pointSize * expandedCardScale, weight: weight, design: design)
    }

    /// A fixed point size enlarged for expanded cards.
    static func expandedCard(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> Font {
        .system(size: size * expandedCardScale, weight: weight, design: design)
    }
}

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
                                .font(.expandedCard(.subheadline, weight: .bold, design: .monospaced))
                                .foregroundStyle(task.isCompleted ? Theme.dotComplete(theme, rc: rc) : Theme.textSecondary(theme, rc: rc))
                        } else {
                            Circle()
                                .fill(task.isCompleted ? Theme.dotComplete(theme, rc: rc) : Color.clear)
                                .overlay(Circle().stroke(task.isCompleted ? Theme.dotComplete(theme, rc: rc) : Theme.textSecondary(theme, rc: rc), lineWidth: 1.5))
                                .frame(width: 18 * expandedCardScale, height: 18 * expandedCardScale)
                        }
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle().size(width: 36 * expandedCardScale, height: 36 * expandedCardScale))
                }

                // Title
                if isEditingTitle {
                    TextField("Task name", text: $editedTitle)
                        .font(Theme.isRetro(theme) ? .expandedCard(size: 16, design: .monospaced) : .expandedCard(size: 16))
                        .onSubmit {
                            let title = editedTitle.trimmingCharacters(in: .whitespaces)
                            if !title.isEmpty {
                                store.renameTask(categoryID: categoryID, taskID: task.id, newTitle: title)
                            }
                            isEditingTitle = false
                        }
                } else {
                    Text(task.title)
                        .font(Theme.isRetro(theme) ? .expandedCard(size: 16, design: .monospaced) : .expandedCard(size: 16))
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

                // Inline icons: mode (also the checkbox type), goal, and delete in edit mode
                if !isPastWeek {
                    HStack(spacing: 0) {
                        taskModeMenu
                        goalTypeButton
                        if isEditing { deleteButton }
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
                            .font(.expandedCard(.caption1)).foregroundStyle(Theme.textTertiary(theme, rc: rc))
                        TextField(Theme.isRetro(theme) ? "sub_task>" : "Add sub-task", text: $newSubtaskTitle)
                            .font(.expandedCard(.caption1, design: Theme.isRetro(theme) ? .monospaced : .default))
                            .onSubmit(addSubtask)
                    }
                    .padding(.leading, 24 * expandedCardScale)
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

    /// Row icons are 10% larger than the other expanded-card elements.
    private let rowIconSize: CGFloat = 16 * 1.1

    // Mode (and checkbox type): shows the task's mode; tap to change it. Highlighted
    // when the task is a checkbox task.
    private var taskModeMenu: some View {
        Menu {
            Picker("Task Mode", selection: Binding(
                get: { task.mode },
                set: { store.updateTaskMode(categoryID: categoryID, taskID: task.id, mode: $0) }
            )) {
                ForEach(TaskMode.allCases, id: \.self) { mode in
                    Label(mode.label, systemImage: mode.symbol).tag(mode)
                }
            }
        } label: {
            rowIcon(task.mode.symbol, color: task.taskType == .checkbox ? Theme.accent(theme, rc: rc) : Theme.textSecondary(theme, rc: rc))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Task mode: \(task.mode.label)")
    }

    /// Toggles between goal and checkbox.
    private var goalTypeButton: some View {
        Button {
            selectTaskType(task.taskType == .goal ? .checkbox : .goal)
        } label: {
            rowIcon(TaskType.goal.symbol, color: task.taskType == .goal ? Theme.accent(theme, rc: rc) : Theme.textSecondary(theme, rc: rc))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(task.taskType == .goal ? "Switch to checkbox task" : "Make goal task")
    }

    private var deleteButton: some View {
        Button {
            showDeleteConfirmation = true
        } label: {
            rowIcon("trash", color: Theme.destructive(theme))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Delete \(task.title)")
    }

    private func rowIcon(_ systemName: String, color: Color) -> some View {
        Image(systemName: systemName)
            .font(.expandedCard(size: rowIconSize))
            .foregroundStyle(color)
            .frame(width: 36 * expandedCardScale, height: 36 * expandedCardScale)
            .contentShape(Rectangle())
    }

    @ViewBuilder
    private var goalIndicator: some View {
        if Theme.isRetro(theme) {
            if task.goalIsComplete {
                Text("[OK]")
                    .font(.expandedCard(.caption1, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.dotComplete(theme, rc: rc))
            } else if let target = task.goalTarget, target > 0 {
                Text("[\(Int(task.goalProgress ?? 0))/\(Int(target))]")
                    .font(.expandedCard(.caption1, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.accent(theme, rc: rc))
            } else {
                Text("[??]")
                    .font(.expandedCard(.caption1, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.completionPartial(theme))
            }
        } else {
            if task.goalIsComplete {
                Circle()
                    .fill(Theme.dotComplete(theme, rc: rc))
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.expandedCard(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    )
                    .frame(width: 18 * expandedCardScale, height: 18 * expandedCardScale)
            } else if let target = task.goalTarget, target > 0 {
                ZStack {
                    Circle().stroke(Theme.textTertiary(theme, rc: rc), lineWidth: 2.5)
                    Circle()
                        .trim(from: 0, to: min((task.goalProgress ?? 0) / target, 1.0))
                        .stroke(Theme.accent(theme, rc: rc), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 18 * expandedCardScale, height: 18 * expandedCardScale)
            } else {
                Image(systemName: "target")
                    .font(.expandedCard(size: 12)).foregroundStyle(Theme.completionPartial(theme))
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
                        .font(Theme.isRetro(theme) ? .expandedCard(.caption1, weight: .bold, design: .monospaced) : .expandedCard(.caption1, weight: .bold).monospacedDigit())
                        .foregroundStyle(task.goalIsComplete ? Theme.dotComplete(theme, rc: rc) : Theme.textPrimary(theme, rc: rc))
                    if let unit = task.goalUnit, !unit.isEmpty {
                        Text(unit).font(.expandedCard(.caption1, design: Theme.isRetro(theme) ? .monospaced : .default)).foregroundStyle(Theme.textSecondary(theme, rc: rc))
                    }
                }
                .padding(.leading, 24 * expandedCardScale)

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
                    .font(.expandedCard(.caption1))
                    .padding(.leading, 24 * expandedCardScale)
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
                    .font(.expandedCard(.body))
                    .padding(.leading, 24 * expandedCardScale)
                }

                if !isPastWeek && !task.goalIsComplete && !isEditingGoal {
                    HStack(spacing: 8) {
                        Image(systemName: "plus").font(.expandedCard(.subheadline)).foregroundStyle(Theme.textTertiary(theme, rc: rc))
                        TextField("Add progress", text: $addProgressText)
                            .font(.expandedCard(.subheadline))
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
                                .font(.expandedCard(.caption1, weight: .bold))
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(Theme.accent(theme, rc: rc), in: Capsule())
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                        .disabled(!(Double(addProgressText).map { $0.isFinite && $0 > 0 } ?? false))
                    }
                    .padding(.leading, 24 * expandedCardScale)
                }
            } else if !isPastWeek {
                HStack(spacing: 8) {
                    TextField("Target", text: $goalTargetText)
                        .font(Theme.isRetro(theme) ? .expandedCard(.subheadline, design: .monospaced) : .expandedCard(.subheadline))
                        .foregroundStyle(Theme.textPrimary(theme, rc: rc))
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 70 * expandedCardScale)
                    Text("—").font(.expandedCard(.caption1)).foregroundStyle(Theme.textTertiary(theme, rc: rc))
                    TextField("Unit", text: $goalUnitText)
                        .font(Theme.isRetro(theme) ? .expandedCard(.subheadline, design: .monospaced) : .expandedCard(.subheadline))
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
                            .font(.expandedCard(.caption1, weight: .bold))
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Theme.accent(theme, rc: rc), in: Capsule())
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .disabled(!(Double(goalTargetText).map { $0.isFinite && $0 > 0 } ?? false))
                }
                .padding(.leading, 24 * expandedCardScale)
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
                        .font(.expandedCard(.caption1, weight: .bold, design: .monospaced))
                        .foregroundStyle(subtask.isCompleted ? Theme.dotComplete(theme, rc: rc) : Theme.textSecondary(theme, rc: rc))
                } else {
                    Circle()
                        .fill(subtask.isCompleted ? Theme.dotComplete(theme, rc: rc) : Color.clear)
                        .overlay(Circle().stroke(subtask.isCompleted ? Theme.dotComplete(theme, rc: rc) : Theme.textSecondary(theme, rc: rc), lineWidth: 1.5))
                        .frame(width: 14 * expandedCardScale, height: 14 * expandedCardScale)
                }
            }
            .buttonStyle(.plain)

            if isEditing && !isPastWeek && isEditingTitle {
                TextField("Sub-task", text: $editedTitle)
                    .font(Theme.isRetro(theme) ? .expandedCard(size: 14, design: .monospaced) : .expandedCard(size: 14))
                    .onSubmit {
                        let title = editedTitle.trimmingCharacters(in: .whitespaces)
                        if !title.isEmpty {
                            store.renameSubtask(categoryID: categoryID, taskID: taskID, subtaskID: subtask.id, newTitle: title)
                        }
                        isEditingTitle = false
                    }
            } else {
                Text(subtask.title)
                    .font(Theme.isRetro(theme) ? .expandedCard(size: 14, design: .monospaced) : .expandedCard(size: 14))
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
                        .font(.expandedCard(.caption1)).foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.leading, 24 * expandedCardScale)
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
                .font(.expandedCard(.subheadline)).foregroundStyle(Theme.textTertiary(theme, rc: rc))
            TextField(Theme.isRetro(theme) ? "new_task>" : "Add task", text: $newTitle)
                .font(.expandedCard(.subheadline, design: Theme.isRetro(theme) ? .monospaced : .default)).focused($isFocused).onSubmit(addTask)
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
                    .font(.expandedCard(.caption2)).foregroundStyle(Theme.textSecondary(theme, rc: rc))
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
