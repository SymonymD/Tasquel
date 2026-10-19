import SwiftUI
import UIKit

// MARK: - Expanded Card Sizing

/// Everything inside an expanded card is drawn 15% larger than its base size.
let expandedCardScale: CGFloat = 1.15

/// The user's text size (Settings ▸ Display & Brightness ▸ Text Size), for the
/// expanded-card sizes below. The root view keeps it current; views that read it while
/// drawing redraw when it changes.
@Observable
final class TextSizeSetting {
    static let shared = TextSizeSetting()
    var size: DynamicTypeSize = .large

    fileprivate var traits: UITraitCollection {
        UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(size))
    }
}

extension Font {
    /// A text style enlarged for expanded cards; follows the user's text size.
    static func expandedCard(_ style: UIFont.TextStyle, weight: Font.Weight = .regular, design: Font.Design = .default) -> Font {
        let size = UIFont.preferredFont(forTextStyle: style, compatibleWith: TextSizeSetting.shared.traits).pointSize
        return .system(size: size * expandedCardScale, weight: weight, design: design)
    }

    /// A point size (at the default text size) enlarged for expanded cards; grows and
    /// shrinks with the user's text size like body text.
    static func expandedCard(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> Font {
        .system(size: expandedCardScaled(size), weight: weight, design: design)
    }
}

/// A length enlarged for expanded cards that follows the user's text size, like body text.
func expandedCardScaled(_ length: CGFloat) -> CGFloat {
    UIFontMetrics(forTextStyle: .body).scaledValue(for: length * expandedCardScale, compatibleWith: TextSizeSetting.shared.traits)
}

/// Like `expandedCardScaled`, but stops growing at 1.6× so controls (checkboxes, icon
/// buttons) don't crowd out the text at the largest sizes.
func expandedCardControl(_ length: CGFloat) -> CGFloat {
    min(expandedCardScaled(length), length * expandedCardScale * 1.6)
}

extension View {
    func expandedCardFont(_ style: UIFont.TextStyle, weight: Font.Weight = .regular, design: Font.Design = .default) -> some View {
        font(.expandedCard(style, weight: weight, design: design))
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
    @FocusState private var isTitleFocused: Bool
    @State private var newSubtaskTitle = ""
    @FocusState private var isSubtaskFieldFocused: Bool
    @State private var goalKindSelection: GoalUnitKind = .quantity
    @State private var goalTargetInput = GoalAmountInput()
    @State private var goalUnitText = ""
    @State private var editedProgressInput = GoalAmountInput()
    @State private var addProgressInput = GoalAmountInput()
    @State private var isEditingGoal = false
    @State private var isAddingProgress = false
    @FocusState private var focusedGoalField: GoalFocus?
    @State private var showDeleteConfirmation = false
    @State private var showTypeChangeConfirmation = false
    /// The type waiting on the "Change type?" confirmation (long-press menu).
    @State private var pendingType: TaskType = .checkbox
    @State private var showOptions = false
    /// The add-sub-task field is open (a list's add-item field is always shown).
    @State private var isAddingSubtask = false

    /// The goal text fields, for moving the keyboard between them.
    nonisolated private enum GoalField: Hashable { case target, editProgress, addProgress, unitName }
    nonisolated private enum GoalFieldPart: Hashable { case number, hours, minutes }
    nonisolated private struct GoalFocus: Hashable {
        let field: GoalField
        let part: GoalFieldPart
    }

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
                                .frame(width: expandedCardControl(18), height: expandedCardControl(18))
                        }
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle().size(width: expandedCardControl(36), height: expandedCardControl(36)))
                    .accessibilityLabel("Check \(task.title)")
                    .accessibilityValue(task.isCompleted ? "Checked" : "Unchecked")
                }

                // Title
                if isEditingTitle {
                    TextField("Task name", text: $editedTitle)
                        .font(Theme.isRetro(theme) ? .expandedCard(size: 16, design: .monospaced) : .expandedCard(size: 16))
                        .focused($isTitleFocused)
                        // The keyboard opens with the field, so one tap is enough.
                        .onAppear { isTitleFocused = true }
                        .onSubmit(commitTitle)
                        // Closing the keyboard (Done, or scrolling) also saves the name.
                        .onChange(of: isTitleFocused) { _, focused in
                            if !focused && isEditingTitle { commitTitle() }
                        }
                } else {
                    // The whole width up to the icons is the target, not just the letters.
                    // In edit mode one tap edits; otherwise a double tap does.
                    Text(task.title)
                        .font(Theme.isRetro(theme) ? .expandedCard(size: 16, design: .monospaced) : .expandedCard(size: 16))
                        .foregroundStyle(Theme.textPrimary(theme, rc: rc))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture(count: isEditing ? 1 : 2) { startEditingTitle() }
                }

                if isEditingTitle { Spacer(minLength: 0) }

                // Inline icons: add sub-task (checkbox tasks), type and mode, and delete in edit mode
                if !isPastWeek {
                    HStack(spacing: 0) {
                        if task.taskType == .checkbox && !isEditing { addSubtaskButton }
                        taskOptionsButton
                        if isEditing { deleteButton }
                    }
                }
            }

            if task.taskType == .goal {
                goalProgressSection
            } else {
                // Checkbox: sub-tasks. List: its items.
                ForEach(task.subtasks) { subtask in
                    SubTaskRowCard(
                        subtask: subtask,
                        categoryID: categoryID,
                        taskID: task.id,
                        store: store,
                        isEditing: isEditing,
                        isPastWeek: isPastWeek,
                        isListItem: task.taskType == .list
                    )
                }
                // Adding is off while the card is in edit mode.
                if !isPastWeek && !isEditing && (task.taskType == .list || isAddingSubtask) {
                    HStack(spacing: 8) {
                        Image(systemName: Theme.isRetro(theme) ? "greaterthan" : "plus.circle")
                            .font(.expandedCard(.caption1)).foregroundStyle(Theme.textTertiary(theme, rc: rc))
                        TextField(subtaskPlaceholder, text: $newSubtaskTitle)
                            .font(.expandedCard(.caption1, design: Theme.isRetro(theme) ? .monospaced : .default))
                            .focused($isSubtaskFieldFocused)
                            .submitLabel(.next)
                            .onSubmit(addSubtask)
                            // An empty sub-task field closes when the keyboard does.
                            .onChange(of: isSubtaskFieldFocused) { _, focused in
                                if !focused && newSubtaskTitle.isEmpty { isAddingSubtask = false }
                            }
                    }
                    .padding(.leading, 24 * expandedCardScale)
                    .padding(.vertical, 2)
                }
            }
        }
        .task(id: store.listAwaitingFirstItem) {
            guard store.listAwaitingFirstItem == task.id else { return }
            store.listAwaitingFirstItem = nil
            isSubtaskFieldFocused = true
        }
        .contextMenu {
            if !isPastWeek {
            Section("Type") {
                ForEach(TaskType.allCases, id: \.self) { type in
                    Button {
                        selectTaskType(type)
                    } label: {
                        Label(type.label, systemImage: type.symbol)
                        if task.taskType == type { Image(systemName: "checkmark") }
                    }
                }
            }
            Section("After This Week") {
                ForEach(TaskMode.ordered, id: \.self) { mode in
                    Button {
                        store.updateTaskMode(categoryID: categoryID, taskID: task.id, mode: mode)
                    } label: {
                        Label(mode.label, systemImage: mode.symbol)
                        if task.mode == mode { Image(systemName: "checkmark") }
                    }
                }
            }
            Section {
                Button("Edit Title", systemImage: "pencil") { startEditingTitle() }
                if task.taskType == .list && !isPastWeek && !isEditing {
                    Button("Add Item", systemImage: "plus") {
                        isSubtaskFieldFocused = true
                    }
                } else if task.taskType == .checkbox && !isPastWeek && !isEditing {
                    Button("Add Sub-Task", systemImage: "list.bullet.indent") { startAddingSubtask() }
                }
                Button("Delete", systemImage: "trash", role: .destructive) {
                    showDeleteConfirmation = true
                }
            }
            }
        }
        .confirmationDialog("Delete \(task.title)?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete Task", role: .destructive) {
                store.deleteTask(categoryID: categoryID, taskID: task.id)
            }
        } message: {
            Text(deleteTaskMessage)
        }
        .confirmationDialog("Change to \(pendingType.label)?", isPresented: $showTypeChangeConfirmation, titleVisibility: .visible) {
            Button("Change Type", role: .destructive) {
                store.updateTaskType(categoryID: categoryID, taskID: task.id, type: pendingType)
            }
        } message: {
            Text("This clears the goal target and progress.")
        }
    }

    private var deleteTaskMessage: String {
        let count = task.subtasks.count
        let what = task.taskType == .list ? "list" : "task"
        guard count > 0 else { return "This removes the \(what) from this week." }
        let items = task.taskType == .list ? (count == 1 ? "item" : "items") : (count == 1 ? "sub-task" : "sub-tasks")
        return "This removes the whole \(what), including its \(count) \(items), from this week."
    }

    /// Row icons are 10% larger than the other expanded-card elements.
    private let rowIconSize: CGFloat = 16 * 1.1

    /// The task's type and mode icons; tap to change either.
    private var taskOptionsButton: some View {
        Button { showOptions = true } label: {
            TaskOptionsLabel(type: task.taskType, mode: task.mode, theme: theme, rc: rc)
                .frame(minHeight: expandedCardControl(36))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Task options: \(task.taskType.label), \(task.mode.label)")
        .popover(isPresented: $showOptions) {
            TaskOptionsPicker(
                type: task.taskType, mode: task.mode, theme: theme, rc: rc,
                confirmsLeavingGoal: task.goalTarget != nil || task.goalProgress != nil,
                onSelectType: { type in
                    withAnimation(.snappy(duration: 0.2)) {
                        store.updateTaskType(categoryID: categoryID, taskID: task.id, type: type)
                    }
                },
                onSelectMode: { store.updateTaskMode(categoryID: categoryID, taskID: task.id, mode: $0) }
            )
        }
    }

    private var addSubtaskButton: some View {
        Button(action: startAddingSubtask) {
            rowIcon("plus", color: Theme.textSecondary(theme, rc: rc))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add sub-task to \(task.title)")
    }

    private func startAddingSubtask() {
        isAddingSubtask = true
        isSubtaskFieldFocused = true
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
            .frame(width: expandedCardControl(36), height: expandedCardControl(36))
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
                Text("[\(task.goalFraction)]")
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
                    .frame(width: expandedCardControl(18), height: expandedCardControl(18))
            } else if let target = task.goalTarget, target > 0 {
                ZStack {
                    Circle().stroke(Theme.textTertiary(theme, rc: rc), lineWidth: 2.5)
                    Circle()
                        .trim(from: 0, to: min((task.goalProgress ?? 0) / target, 1.0))
                        .stroke(Theme.accent(theme, rc: rc), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: expandedCardControl(18), height: expandedCardControl(18))
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
                    if let unit = task.goalUnitLabel {
                        Text(unit).font(.expandedCard(.caption1, design: Theme.isRetro(theme) ? .monospaced : .default)).foregroundStyle(Theme.textSecondary(theme, rc: rc))
                    }
                }
                .padding(.leading, 24 * expandedCardScale)

                if !isPastWeek {
                    HStack(spacing: 20) {
                        Button(isEditingGoal ? "Cancel" : "Edit Goal") {
                            if isEditingGoal { closeGoalEditing() } else { startEditingGoal(target: target) }
                        }
                        .accessibilityLabel(isEditingGoal ? "Cancel editing goal" : "Edit goal")
                        if !task.goalIsComplete || isAddingProgress {
                            Button(isAddingProgress ? "Cancel" : "Add Progress") {
                                if isAddingProgress { closeAddProgress() } else { startAddingProgress() }
                            }
                            .accessibilityLabel(isAddingProgress ? "Cancel adding progress" : "Add progress")
                        }
                    }
                    .font(.expandedCard(.caption1, design: Theme.isRetro(theme) ? .monospaced : .default))
                    .padding(.leading, 24 * expandedCardScale)
                }

                if isEditingGoal && !isPastWeek {
                    editGoalForm
                }

                if isAddingProgress && !isPastWeek && !isEditingGoal {
                    addProgressRow
                }
            } else if !isPastWeek {
                setGoalForm
            }
        }
        .padding(.top, 2)
    }

    // MARK: Goal Forms

    /// Shown until a goal has a target: unit and target on one line, wrapping
    /// onto two lines only when they don't fit.
    private var setGoalForm: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                goalUnitMenu
                goalAmountFields($goalTargetInput, kind: goalKindSelection, field: .target, placeholder: "Target")
                if goalKindSelection == .custom { unitNameField }
                Spacer(minLength: 0)
                setGoalButton
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    goalUnitMenu
                    if goalKindSelection == .custom { unitNameField }
                }
                HStack(spacing: 8) {
                    goalAmountFields($goalTargetInput, kind: goalKindSelection, field: .target, placeholder: "Target")
                    Spacer(minLength: 0)
                    setGoalButton
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 24 * expandedCardScale)
    }

    private var setGoalButton: some View {
        Button(action: setGoal) { actionPill("Set") }
            .buttonStyle(.plain)
            .disabled(goalTargetInput.positiveValue(for: goalKindSelection) == nil)
    }

    private var editGoalForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            labeledGoalRow("Target") {
                goalUnitMenu
                goalAmountFields($goalTargetInput, kind: goalKindSelection, field: .target, placeholder: "Target")
                if goalKindSelection == .custom { unitNameField }
            }
            labeledGoalRow("Progress") {
                goalAmountFields($editedProgressInput, kind: goalKindSelection, field: .editProgress, placeholder: "Progress")
            }
            Button("Save Goal", action: saveEditedGoal)
                .disabled(!canSaveEditedGoal)
                .frame(maxWidth: .infinity)
        }
        .font(.expandedCard(.body, design: Theme.isRetro(theme) ? .monospaced : .default))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 24 * expandedCardScale)
    }

    /// Revealed by Add Progress; hides again after Add.
    private var addProgressRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus").font(.expandedCard(.subheadline)).foregroundStyle(Theme.textTertiary(theme, rc: rc))
            goalAmountFields($addProgressInput, kind: task.goalKind, field: .addProgress, placeholder: "Amount")
            if let unit = task.goalUnitLabel {
                Text(unit).font(goalFieldFont).foregroundStyle(Theme.textSecondary(theme, rc: rc))
            }
            Spacer(minLength: 0)
            Button(action: addGoalProgress) { actionPill("Add") }
                .buttonStyle(.plain)
                .disabled(addProgressInput.positiveValue(for: task.goalKind) == nil)
        }
        .padding(.leading, 24 * expandedCardScale)
        .onAppear {
            focusedGoalField = GoalFocus(field: .addProgress, part: task.goalKind == .time ? .hours : .number)
        }
    }

    /// Quantity, Time, or Custom. Switching carries a typed amount across (hours ↔ number).
    private var goalUnitMenu: some View {
        Menu {
            Picker("Unit", selection: Binding(
                get: { goalKindSelection },
                set: { newKind in
                    goalTargetInput = goalTargetInput.converted(from: goalKindSelection, to: newKind)
                    editedProgressInput = editedProgressInput.converted(from: goalKindSelection, to: newKind)
                    goalKindSelection = newKind
                }
            )) {
                ForEach(GoalUnitKind.allCases, id: \.self) { kind in
                    Text(kind.label).tag(kind)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(goalKindSelection.label)
                Image(systemName: "chevron.up.chevron.down").font(.expandedCard(.caption2))
            }
            .lineLimit(1)
            .fixedSize()
            .font(goalFieldFont)
            .foregroundStyle(Theme.textPrimary(theme, rc: rc))
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Theme.textTertiary(theme, rc: rc).opacity(0.3), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Goal unit: \(goalKindSelection.label)")
    }

    private var unitNameField: some View {
        TextField("Unit", text: $goalUnitText)
            .font(goalFieldFont)
            .foregroundStyle(Theme.textPrimary(theme, rc: rc))
            .textFieldStyle(.roundedBorder)
            .frame(minWidth: 64 * expandedCardScale)
            .focused($focusedGoalField, equals: GoalFocus(field: .unitName, part: .number))
            .accessibilityLabel("Unit name, for example pages")
    }

    /// A number field, or hours and minutes fields for time goals.
    @ViewBuilder
    private func goalAmountFields(_ input: Binding<GoalAmountInput>, kind: GoalUnitKind, field: GoalField, placeholder: String) -> some View {
        if kind == .time {
            HStack(spacing: 4) {
                goalNumberField("0", text: input.hours, focus: GoalFocus(field: field, part: .hours), keyboard: .numberPad, width: 44)
                    .accessibilityLabel("\(placeholder) hours")
                Text("h").font(goalFieldFont).foregroundStyle(Theme.textSecondary(theme, rc: rc))
                    .fixedSize()
                goalNumberField("0", text: input.minutes, focus: GoalFocus(field: field, part: .minutes), keyboard: .numberPad, width: 44)
                    .accessibilityLabel("\(placeholder) minutes")
                Text("m").font(goalFieldFont).foregroundStyle(Theme.textSecondary(theme, rc: rc))
                    .fixedSize()
            }
        } else {
            goalNumberField(placeholder, text: input.number, focus: GoalFocus(field: field, part: .number), keyboard: .decimalPad, width: 90)
        }
    }

    private func goalNumberField(_ placeholder: String, text: Binding<String>, focus: GoalFocus, keyboard: UIKeyboardType, width: CGFloat) -> some View {
        TextField(placeholder, text: text)
            .font(goalFieldFont)
            .foregroundStyle(Theme.textPrimary(theme, rc: rc))
            .keyboardType(keyboard)
            .textFieldStyle(.roundedBorder)
            .frame(width: width * expandedCardScale)
            .focused($focusedGoalField, equals: focus)
    }

    private func labeledGoalRow(_ label: String, @ViewBuilder content: () -> some View) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.expandedCard(.caption1, design: Theme.isRetro(theme) ? .monospaced : .default))
                .foregroundStyle(Theme.textSecondary(theme, rc: rc))
                .frame(width: 64 * expandedCardScale, alignment: .leading)
            content()
        }
    }

    private func actionPill(_ title: String) -> some View {
        Text(title)
            .font(.expandedCard(.caption1, weight: .bold))
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Theme.accent(theme, rc: rc), in: Capsule())
            .foregroundStyle(.white)
    }

    private var goalFieldFont: Font {
        Theme.isRetro(theme) ? .expandedCard(.subheadline, design: .monospaced) : .expandedCard(.subheadline)
    }

    private var subtaskPlaceholder: String {
        switch (task.taskType == .list, Theme.isRetro(theme)) {
        case (true, true): "add_item>"
        case (true, false): "Add item"
        case (false, true): "sub_task>"
        case (false, false): "Add sub-task"
        }
    }

    /// Return keeps the keyboard up for the next item; Return on an empty field closes it.
    private func addSubtask() {
        let title = newSubtaskTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        withAnimation(.snappy(duration: 0.2)) {
            store.addSubtask(categoryID: categoryID, taskID: task.id, title: title)
        }
        newSubtaskTitle = ""
        isSubtaskFieldFocused = true
    }

    private func startEditingTitle() {
        guard !isPastWeek else { return }
        editedTitle = task.title
        isEditingTitle = true
    }

    private func commitTitle() {
        let title = editedTitle.trimmingCharacters(in: .whitespaces)
        if !title.isEmpty {
            store.renameTask(categoryID: categoryID, taskID: task.id, newTitle: title)
        }
        isEditingTitle = false
    }

    // MARK: Goal Actions

    private func setGoal() {
        guard let target = goalTargetInput.positiveValue(for: goalKindSelection) else { return }
        store.setGoalTarget(categoryID: categoryID, taskID: task.id, target: target, kind: goalKindSelection, unit: goalUnitText)
        goalTargetInput = GoalAmountInput()
        goalUnitText = ""
        focusedGoalField = nil
    }

    private func startEditingGoal(target: Double) {
        let kind = task.goalKind
        goalKindSelection = kind
        goalTargetInput = GoalAmountInput(target, kind: kind)
        editedProgressInput = GoalAmountInput(task.goalProgress ?? 0, kind: kind)
        goalUnitText = task.goalUnit ?? ""
        closeAddProgress()
        isEditingGoal = true
    }

    private func closeGoalEditing() {
        isEditingGoal = false
        goalTargetInput = GoalAmountInput()
        goalUnitText = ""
        focusedGoalField = nil
    }

    private var canSaveEditedGoal: Bool {
        goalTargetInput.positiveValue(for: goalKindSelection) != nil
            && editedProgressInput.value(for: goalKindSelection) != nil
    }

    private func saveEditedGoal() {
        guard let target = goalTargetInput.positiveValue(for: goalKindSelection),
              let progress = editedProgressInput.value(for: goalKindSelection) else { return }
        store.setGoalTarget(categoryID: categoryID, taskID: task.id, target: target, kind: goalKindSelection, unit: goalUnitText)
        store.updateGoalProgress(categoryID: categoryID, taskID: task.id, progress: progress)
        closeGoalEditing()
    }

    private func startAddingProgress() {
        if isEditingGoal { closeGoalEditing() }
        addProgressInput = GoalAmountInput()
        isAddingProgress = true
    }

    private func closeAddProgress() {
        isAddingProgress = false
        addProgressInput = GoalAmountInput()
        focusedGoalField = nil
    }

    /// Leaving a goal that has a target or progress asks first, since it clears them.
    private func selectTaskType(_ type: TaskType) {
        guard !isPastWeek, task.taskType != type else { return }
        if task.taskType == .goal && (task.goalTarget != nil || task.goalProgress != nil) {
            pendingType = type
            showTypeChangeConfirmation = true
        } else {
            store.updateTaskType(categoryID: categoryID, taskID: task.id, type: type)
        }
    }

    /// Adds the typed amount, then hides the entry row and closes the keyboard.
    private func addGoalProgress() {
        guard let amount = addProgressInput.positiveValue(for: task.goalKind) else { return }
        let current = task.goalProgress ?? 0
        withAnimation(.snappy(duration: 0.2)) {
            store.updateGoalProgress(categoryID: categoryID, taskID: task.id, progress: current + amount)
            closeAddProgress()
        }
    }
}

// MARK: - Goal Amount Input

/// Text typed for one goal amount: a number, or hours and minutes for time goals.
struct GoalAmountInput: Equatable {
    var number = ""
    var hours = ""
    var minutes = ""

    init() {}

    /// Prefilled with a saved value (minutes for time goals).
    init(_ value: Double, kind: GoalUnitKind) {
        if kind == .time {
            let total = Int(value.rounded())
            hours = String(total / 60)
            minutes = String(total % 60)
        } else {
            number = value.formatted(.number.precision(.fractionLength(0...2)).grouping(.never))
        }
    }

    /// The typed value (minutes for time goals), or nil if it isn't a valid amount.
    func value(for kind: GoalUnitKind) -> Double? {
        if kind == .time {
            guard !(hours.isEmpty && minutes.isEmpty),
                  let h = hours.isEmpty ? 0 : Double(hours),
                  let m = minutes.isEmpty ? 0 : Double(minutes),
                  h.isFinite, m.isFinite, h >= 0, m >= 0 else { return nil }
            return h * 60 + m
        }
        guard let n = Double(number), n.isFinite, n >= 0 else { return nil }
        return n
    }

    /// The typed value if it's greater than zero.
    func positiveValue(for kind: GoalUnitKind) -> Double? {
        value(for: kind).flatMap { $0 > 0 ? $0 : nil }
    }

    /// The same amount after switching units: a number becomes hours, and time becomes hours.
    func converted(from old: GoalUnitKind, to new: GoalUnitKind) -> GoalAmountInput {
        guard (old == .time) != (new == .time) else { return self }
        var result = GoalAmountInput()
        if new == .time {
            result.hours = number
        } else if let minutes = value(for: .time) {
            result.number = (minutes / 60).formatted(.number.precision(.fractionLength(0...2)).grouping(.never))
        }
        return result
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
    /// An item in a list task rather than a sub-task; only changes the wording.
    var isListItem = false

    private var theme: AppearanceMode { store.appearanceMode }
    private var rc: RetroColor { store.retroColor }

    @State private var isEditingTitle = false
    @State private var editedTitle = ""
    @FocusState private var isTitleFocused: Bool
    @State private var showDeleteConfirmation = false

    private func commitTitle() {
        let title = editedTitle.trimmingCharacters(in: .whitespaces)
        if !title.isEmpty {
            store.renameSubtask(categoryID: categoryID, taskID: taskID, subtaskID: subtask.id, newTitle: title)
        }
        isEditingTitle = false
    }

    var body: some View {
        HStack(spacing: 8) {
            // In edit mode the checkbox becomes a delete button on the left, well away
            // from the task's own trash can on the right.
            if isEditing && !isPastWeek {
                Button {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.expandedCard(.subheadline))
                        .foregroundStyle(.white, Theme.destructive(theme))
                        .frame(width: expandedCardControl(14), height: expandedCardControl(14))
                }
                .buttonStyle(.plain)
                .padding(8)
                .contentShape(Rectangle())
                .padding(-8)
                .accessibilityLabel(isListItem ? "Delete item \(subtask.title)" : "Delete sub-task \(subtask.title)")
            } else {
                checkbox
            }

            if isEditing && !isPastWeek && isEditingTitle {
                TextField(isListItem ? "Item" : "Sub-task", text: $editedTitle)
                    .font(Theme.isRetro(theme) ? .expandedCard(size: 14, design: .monospaced) : .expandedCard(size: 14))
                    .focused($isTitleFocused)
                    .onAppear { isTitleFocused = true }
                    .onSubmit(commitTitle)
                    // Closing the keyboard (Done, or scrolling) also saves the name.
                    .onChange(of: isTitleFocused) { _, focused in
                        if !focused && isEditingTitle { commitTitle() }
                    }
            } else {
                Text(subtask.title)
                    .font(Theme.isRetro(theme) ? .expandedCard(size: 14, design: .monospaced) : .expandedCard(size: 14))
                    .foregroundStyle(subtask.isCompleted ? Theme.textTertiary(theme, rc: rc) : Theme.textSecondary(theme, rc: rc))
                    .strikethrough(subtask.isCompleted && !Theme.isRetro(theme), color: Theme.textSecondary(theme, rc: rc))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if isEditing && !isPastWeek {
                            editedTitle = subtask.title
                            isEditingTitle = true
                        }
                    }
            }
        }
        .padding(.leading, 24 * expandedCardScale)
        .padding(.vertical, 2)
        .confirmationDialog("Delete \(subtask.title)?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button(isListItem ? "Delete Item" : "Delete Sub-Task", role: .destructive) {
                store.deleteSubtask(categoryID: categoryID, taskID: taskID, subtaskID: subtask.id)
            }
        }
    }

    private var checkbox: some View {
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
                    .frame(width: expandedCardControl(14), height: expandedCardControl(14))
            }
        }
        .buttonStyle(.plain)
        // A bigger touch target than the small circle, without changing the layout.
        .padding(8)
        .contentShape(Rectangle())
        .padding(-8)
        .accessibilityLabel("Check \(subtask.title)")
        .accessibilityValue(subtask.isCompleted ? "Checked" : "Unchecked")
    }
}

// MARK: - Add Task Row (Card)

struct AddTaskRowCard: View {
    let categoryID: UUID
    let store: ChecklistStore

    private var theme: AppearanceMode { store.appearanceMode }
    private var rc: RetroColor { store.retroColor }

    @State private var newTitle = ""
    @State private var newType: TaskType = .checkbox
    @State private var newMode: TaskMode = .oneTime
    @State private var showOptions = false
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: Theme.isRetro(theme) ? "greaterthan" : "plus.circle")
                .font(.expandedCard(.subheadline)).foregroundStyle(Theme.textTertiary(theme, rc: rc))
            TextField(Theme.isRetro(theme) ? "new_task>" : "Add task", text: $newTitle)
                .font(.expandedCard(.subheadline, design: Theme.isRetro(theme) ? .monospaced : .default)).focused($isFocused).onSubmit(addTask)
            // Kept while the picker is open, which can take the keyboard away.
            if isFocused || showOptions || !newTitle.isEmpty {
                Button { showOptions = true } label: {
                    TaskOptionsLabel(type: newType, mode: newMode, theme: theme, rc: rc)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("New task options: \(newType.label), \(newMode.label)")
                .popover(isPresented: $showOptions) {
                    TaskOptionsPicker(
                        type: newType, mode: newMode, theme: theme, rc: rc,
                        onSelectType: { newType = $0 },
                        onSelectMode: { newMode = $0 },
                        onAdd: newTitle.trimmingCharacters(in: .whitespaces).isEmpty ? nil : {
                            showOptions = false
                            addTask()
                        }
                    )
                }
            }
        }
    }

    /// Return uses the type and mode last picked.
    private func addTask() {
        let title = newTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        withAnimation(.snappy(duration: 0.2)) {
            let id = store.addTask(categoryID: categoryID, title: title, mode: newMode, type: newType)
            // A new list goes straight to typing its first item.
            if newType == .list { store.listAwaitingFirstItem = id }
        }
        newTitle = ""
    }
}
