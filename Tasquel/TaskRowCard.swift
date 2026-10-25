import SwiftUI
import OSLog
import UniformTypeIdentifiers
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
    /// A text style enlarged for expanded cards (and by `scale`); follows the user's text size.
    static func expandedCard(_ style: UIFont.TextStyle, weight: Font.Weight = .regular, design: Font.Design = .default,
                             scale: CGFloat = 1) -> Font {
        let size = UIFont.preferredFont(forTextStyle: style, compatibleWith: TextSizeSetting.shared.traits).pointSize
        return .system(size: size * expandedCardScale * scale, weight: weight, design: design)
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
    /// Makes a small control tappable across at least 44×44 points (or the given size)
    /// around its center, without changing its layout. Apply it inside a button's label.
    func touchTarget(width: CGFloat = 44, height: CGFloat = 44) -> some View {
        background {
            Color.clear
                .frame(width: width, height: height)
                .contentShape(Rectangle())
        }
    }

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
    /// The goal editor's Step; empty means automatic.
    @State private var goalStepInput = GoalAmountInput()
    @State private var addProgressInput = GoalAmountInput()
    @State private var isEditingGoal = false
    @State private var isAddingProgress = false
    @FocusState private var focusedGoalField: GoalFocus?
    @State private var showOptions = false
    /// Another task is being dragged over this one (reordering in edit mode).
    @State private var isDropTarget = false
    /// The add-sub-task field is open (a list's add-item field is always shown).
    @State private var isAddingSubtask = false

    /// The goal text fields, for moving the keyboard between them.
    nonisolated private enum GoalField: Hashable { case target, editProgress, step, addProgress, unitName }
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
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(task.title) progress")
                        .accessibilityValue(TaskAccessibility.goalValue(task))
                } else {
                    Button {
                        guard !isPastWeek else { return }
                        withAnimation(.snappy(duration: 0.2)) {
                            store.toggleTask(categoryID: categoryID, taskID: task.id)
                        }
                    } label: {
                        Group {
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
                        .modifier(PastWeekDimming(isPastWeek: isPastWeek, theme: theme))
                        .touchTarget()
                    }
                    .buttonStyle(CheckboxButtonStyle())
                    .disabled(isPastWeek)
                    .accessibilityLabel(TaskAccessibility.checkboxLabel(task.title, isCompleted: task.isCompleted))
                    .accessibilityAddTraits(task.isCompleted ? .isSelected : [])
                }

                // Title
                if isEditingTitle {
                    TextField("Task name", text: $editedTitle)
                        .font(Theme.isRetro(theme) ? .expandedCard(size: 16, design: .monospaced) : .expandedCard(size: 16))
                        .cardField(theme, rc: rc, outset: true)
                        .focused($isTitleFocused)
                        // The keyboard opens with the field, so one tap is enough.
                        .onAppear { isTitleFocused = true }
                        .onSubmit(commitTitle)
                        // Closing the keyboard (Done, or scrolling) also saves the name.
                        .onChange(of: isTitleFocused) { _, focused in
                            if !focused && isEditingTitle { commitTitle() }
                        }
                } else {
                    // One tap renames. The whole width up to the icons is the target, not just the letters.
                    // Done tasks are struck through, like done sub-tasks.
                    Text(task.title)
                        .font(Theme.isRetro(theme) ? .expandedCard(size: 16, design: .monospaced) : .expandedCard(size: 16))
                        .foregroundStyle(task.isCompleted ? Theme.textSecondary(theme, rc: rc) : Theme.textPrimary(theme, rc: rc))
                        .strikethrough(task.isCompleted && !Theme.isRetro(theme), color: Theme.textSecondary(theme, rc: rc))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture { startEditingTitle() }
                }

                if isEditingTitle { Spacer(minLength: 0) }

                // Inline icons: add sub-task (checkbox tasks), type and mode, and delete in edit mode
                if !isPastWeek {
                    HStack(spacing: 0) {
                        if task.taskType == .checkbox && !isEditing { addSubtaskButton }
                        taskOptionsButton
                        if isEditing {
                            deleteButton
                            reorderHandle
                        }
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
                            .cardField(theme, rc: rc, outset: true)
                            .focused($isSubtaskFieldFocused)
                            .submitLabel(.next)
                            .onSubmit { addSubtask() }
                            // An empty sub-task field closes when the keyboard does.
                            .onChange(of: isSubtaskFieldFocused) { _, focused in
                                guard !focused else { return }
                                // However the keyboard went away, what was typed is added;
                                // an empty field then closes.
                                addSubtask(keepTyping: false)
                                isAddingSubtask = false
                            }
                    }
                    .padding(.leading, 24 * expandedCardScale)
                    .padding(.vertical, 2)
                }
            }
        }
        .task(id: store.taskAwaitingFirstInput) {
            guard store.taskAwaitingFirstInput == task.id else { return }
            store.taskAwaitingFirstInput = nil
            if task.taskType == .goal {
                focusedGoalField = GoalFocus(field: .target, part: goalKindSelection == .time ? .hours : .number)
            } else {
                isSubtaskFieldFocused = true
            }
        }
        .onChange(of: store.keyboardDoneRequests) { saveTypedOnDone() }
        // A task dragged by its handle (edit mode) and dropped here takes this place.
        .dropDestination(for: TaskDragItem.self) { items, _ in
            // Only within this card, and only while it's being edited.
            guard isEditing, !isPastWeek, let item = items.first, item.categoryID == categoryID else { return false }
            withAnimation(.snappy(duration: 0.25)) {
                store.moveTask(categoryID: categoryID, taskID: item.taskID, to: task.id)
            }
            return true
        } isTargeted: { isDropTarget = $0 && isEditing }
        .background {
            if isDropTarget {
                RoundedRectangle(cornerRadius: 8).fill(Theme.accent(theme, rc: rc).opacity(0.12)).padding(-4)
            }
        }
        .accessibilityActions {
            if isEditing && !isPastWeek {
                Button("Move Up") { withAnimation { store.moveTask(categoryID: categoryID, taskID: task.id, by: -1) } }
                Button("Move Down") { withAnimation { store.moveTask(categoryID: categoryID, taskID: task.id, by: 1) } }
            }
        }
        // A light tap for ticking off; a success for reaching a goal.
        .sensoryFeedback(trigger: task.isCompleted) { _, done in done && task.taskType != .goal ? .impact(weight: .light) : nil }
        .sensoryFeedback(.success, trigger: task.goalIsComplete) { wasDone, done in !wasDone && done }
    }

    /// No confirmation: the delete can be undone from the message that follows.
    private func deleteTask() {
        withAnimation(.snappy(duration: 0.2)) {
            store.deleteTask(categoryID: categoryID, taskID: task.id)
        }
    }

    /// Row icons are 10% larger than the other expanded-card elements.
    private let rowIconSize: CGFloat = 16 * 1.1

    /// The task's type and mode icons; tap to change either.
    private var taskOptionsButton: some View {
        Button { showOptions = true } label: {
            TaskOptionsLabel(type: task.taskType, mode: task.mode, theme: theme, rc: rc)
                .frame(minHeight: expandedCardControl(36))
                .contentShape(Rectangle())
                .touchTarget()
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

    /// In edit mode: hold and drag to move the task within its card.
    private var reorderHandle: some View {
        rowIcon("line.3.horizontal", color: Theme.textTertiary(theme, rc: rc))
            .draggable(TaskDragItem(taskID: task.id, categoryID: categoryID)) {
                Text(task.title)
                    .font(.expandedCard(size: 16))
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Theme.cardFill(theme), in: RoundedRectangle(cornerRadius: 8))
            }
            .accessibilityHidden(true)  // VoiceOver uses Move Up / Move Down on the task
    }

    private var deleteButton: some View {
        Button(action: deleteTask) {
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
            .touchTarget()
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

                if !isPastWeek && !isEditingGoal {
                    HStack(spacing: 20) {
                        Button("Edit Goal") { startEditingGoal(target: target) }
                            .accessibilityLabel("Edit goal")
                        if !task.goalIsComplete || isAddingProgress {
                            Button(isAddingProgress ? "Cancel" : "Add Progress") {
                                if isAddingProgress { closeAddProgress() } else { startAddingProgress() }
                            }
                            .accessibilityLabel(isAddingProgress ? "Cancel adding progress" : "Add progress")
                        }
                        // The most common update, in one tap, and its undo: − takes a step
                        // back (also after the goal is reached, to take back the last tap).
                        HStack(spacing: 6) {
                            if (task.goalProgress ?? 0) > 0 && !isAddingProgress {
                                Button { addQuickProgress(sign: -1) } label: {
                                    Text("−")
                                        .font(.expandedCard(.caption1, weight: .bold, scale: 1.15))
                                        .frame(minWidth: 14)
                                        .padding(.horizontal, 10).padding(.vertical, 6)
                                        .foregroundStyle(Theme.accent(theme, rc: rc))
                                        .overlay(Capsule().stroke(Theme.accent(theme, rc: rc).opacity(0.6), lineWidth: 1))
                                        .contentShape(Capsule())
                                        .touchTarget()
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(task.goalKind == .time ? "Remove \(Int(quickStep)) minutes" : "Remove \(task.goalKind.format(quickStep))")
                            }
                            if !task.goalIsComplete && !isAddingProgress {
                                Button { addQuickProgress(sign: 1) } label: {
                                    actionPill("+" + task.goalKind.format(quickStep))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(task.goalKind == .time ? "Add \(Int(quickStep)) minutes" : "Add \(task.goalKind.format(quickStep))")
                            }
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
            // What + and − add or take away; empty picks one from the target.
            labeledGoalRow("Step") {
                goalAmountFields($goalStepInput, kind: goalKindSelection, field: .step, placeholder: "Auto")
            }
            HStack(spacing: 12) {
                // Deleting removes the whole task, so it's small and kept apart from Save.
                Button(role: .destructive, action: deleteTask) {
                    Text("Delete Task")
                        .font(.expandedCard(.caption1, design: Theme.isRetro(theme) ? .monospaced : .default))
                        .foregroundStyle(Theme.destructive(theme))
                        .touchTarget()
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete task")
                Spacer(minLength: 0)
                Button("Cancel", action: closeGoalEditing)
                    .font(.expandedCard(.caption1, design: Theme.isRetro(theme) ? .monospaced : .default))
                    .accessibilityLabel("Cancel editing goal")
                Button(action: saveEditedGoal) {
                    OptionButtonLabel(title: "Save Goal", symbol: "checkmark", color: .green, isHighlighted: true,
                                      theme: theme, rc: rc, isEnabled: canSaveEditedGoal)
                }
                .buttonStyle(.plain)
                .disabled(!canSaveEditedGoal)
                .accessibilityLabel("Save Goal")
            }
            .accessibilityElement(children: .contain)
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
                    goalStepInput = goalStepInput.converted(from: goalKindSelection, to: newKind)
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
            .cardField(theme, rc: rc)
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
            .cardField(theme, rc: rc)
            .frame(width: width * expandedCardScale)
            .focused($focusedGoalField, equals: focus)
            // A tap just outside the small box still lands in it.
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .onTapGesture { focusedGoalField = focus }
            .padding(.vertical, -6)
            // The current amount is selected, so typing replaces it.
            .onChange(of: focusedGoalField) { _, new in
                guard new == focus else { return }
                DispatchQueue.main.async {
                    UIApplication.shared.sendAction(#selector(UIResponder.selectAll(_:)), to: nil, from: nil, for: nil)
                }
            }
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

    /// Set and Add, 15% larger than caption text so they aren't missed beside the keyboard's Done.
    private func actionPill(_ title: String) -> some View {
        Text(title)
            .font(.expandedCard(.caption1, weight: .bold, scale: 1.15))
            .padding(.horizontal, 14).padding(.vertical, 7)
            .background(Theme.accent(theme, rc: rc), in: Capsule())
            // Retro's accent is a bright phosphor color: dark text stays readable on it.
            .foregroundStyle(Theme.isRetro(theme) ? .black : .white)
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
    private func addSubtask(keepTyping: Bool = true) {
        let title = newSubtaskTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        withAnimation(.snappy(duration: 0.2)) {
            store.addSubtask(categoryID: categoryID, taskID: task.id, title: title)
        }
        newSubtaskTitle = ""
        if keepTyping { isSubtaskFieldFocused = true }
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
        goalStepInput = task.goalStep.map { GoalAmountInput($0, kind: kind) } ?? GoalAmountInput()
        closeAddProgress()
        isEditingGoal = true
    }

    private func closeGoalEditing() {
        isEditingGoal = false
        goalTargetInput = GoalAmountInput()
        goalStepInput = GoalAmountInput()
        goalUnitText = ""
        focusedGoalField = nil
    }

    private var canSaveEditedGoal: Bool {
        goalTargetInput.positiveValue(for: goalKindSelection) != nil
            && editedProgressInput.value(for: goalKindSelection) != nil
            && (goalStepInput.isEmpty || goalStepInput.positiveValue(for: goalKindSelection) != nil)
    }

    private func saveEditedGoal() {
        guard let target = goalTargetInput.positiveValue(for: goalKindSelection),
              let progress = editedProgressInput.value(for: goalKindSelection) else { return }
        store.setGoalTarget(categoryID: categoryID, taskID: task.id, target: target, kind: goalKindSelection, unit: goalUnitText)
        store.updateGoalProgress(categoryID: categoryID, taskID: task.id, progress: progress)
        store.setGoalStep(categoryID: categoryID, taskID: task.id, step: goalStepInput.positiveValue(for: goalKindSelection))
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

    /// One step forward (+) or back (−); never below zero.
    private func addQuickProgress(sign: Double) {
        let progress = max(0, (task.goalProgress ?? 0) + sign * quickStep)
        withAnimation(.snappy(duration: 0.2)) {
            store.updateGoalProgress(categoryID: categoryID, taskID: task.id, progress: progress)
        }
    }

    /// One tap's worth of progress: 1 for counts; for time, a step that suits the target
    /// (+5m toward 10 minutes, +30m toward 4 hours).
    private var quickStep: Double {
        if let step = task.goalStep, step > 0 { return step }  // set in the goal editor
        guard task.goalKind == .time else { return 1 }
        switch task.goalTarget ?? 0 {
        case ...20: return 5
        case ...60: return 10
        case ...180: return 15
        default: return 30
        }
    }

    /// The keyboard's Done saves a goal amount or sub-task typed in this row but not yet
    /// set or added; number pads have no Return key, so otherwise it would be lost.
    private func saveTypedOnDone() {
        if isSubtaskFieldFocused {
            addSubtask()
            return
        }
        guard let field = focusedGoalField?.field else { return }
        switch field {
        case .addProgress:
            addGoalProgress()
        case .target, .unitName, .editProgress, .step:
            if isEditingGoal { saveEditedGoal() } else { setGoal() }
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

// MARK: - Dragging Tasks

/// What a task's reorder handle drags. Raw data rather than text, so a text field (or
/// another app) doesn't take it as something to paste.
struct TaskDragItem: Codable, Transferable {
    let taskID: UUID
    let categoryID: UUID

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .data)
    }
}

// MARK: - Checkboxes

/// A checkbox's button style: no press or disabled dimming of its own, so a past week's
/// checkbox can be disabled (VoiceOver says so) while `PastWeekDimming` sets the look.
private struct CheckboxButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}

/// Past weeks are view only: their checkboxes are dimmed. Not in retro, whose text
/// colors are tuned to keep 4.5:1 and would fall below it.
private struct PastWeekDimming: ViewModifier {
    let isPastWeek: Bool
    let theme: AppearanceMode

    func body(content: Content) -> some View {
        content.opacity(isPastWeek && !Theme.isRetro(theme) ? 0.5 : 1)
    }
}

// MARK: - Accessibility

enum TaskAccessibility {
    /// What tapping a checkbox does: "Complete Eggs" or "Mark Eggs incomplete".
    static func checkboxLabel(_ title: String, isCompleted: Bool) -> String {
        isCompleted ? "Mark \(title) incomplete" : "Complete \(title)"
    }

    /// A goal's progress read aloud: "3 of 5", "3 of 5 pages", "1h of 2h", or that it
    /// has no target yet.
    static func goalValue(_ task: ChecklistTask) -> String {
        guard let target = task.goalTarget, target > 0 else { return "No target yet" }
        let kind = task.goalKind
        var value = "\(kind.format(task.goalProgress ?? 0)) of \(kind.format(target))"
        if let unit = task.goalUnitLabel { value += " \(unit)" }
        return task.goalIsComplete ? "Done, \(value)" : value
    }
}

// MARK: - Goal Amount Input

/// Text typed for one goal amount: a number, or hours and minutes for time goals.
struct GoalAmountInput: Equatable {
    var number = ""
    var hours = ""
    var minutes = ""

    init() {}

    /// Prefilled with a saved value (minutes for time goals), without a trailing ".0".
    init(_ value: Double, kind: GoalUnitKind, locale: Locale = .current) {
        let value = value.isFinite ? min(max(value, 0), GoalUnitKind.maxValue) : 0
        if kind == .time {
            let total = Int(value.rounded())
            hours = String(total / 60)
            minutes = String(total % 60)
        } else {
            number = GoalNumber.fieldText(value, locale: locale)
        }
    }

    /// The typed value (minutes for time goals), or nil if it isn't a valid amount or is
    /// over the maximum.
    func value(for kind: GoalUnitKind, locale: Locale = .current) -> Double? {
        let result: Double
        if kind == .time {
            guard !(hours.isEmpty && minutes.isEmpty),
                  let h = hours.isEmpty ? 0 : GoalNumber.parse(hours, locale: locale),
                  let m = minutes.isEmpty ? 0 : GoalNumber.parse(minutes, locale: locale),
                  h >= 0, m >= 0 else { return nil }
            result = h * 60 + m
        } else {
            guard let n = GoalNumber.parse(number, locale: locale), n >= 0 else { return nil }
            result = n
        }
        return result <= GoalUnitKind.maxValue ? result : nil
    }

    /// Nothing typed.
    var isEmpty: Bool { number.isEmpty && hours.isEmpty && minutes.isEmpty }

    /// The typed value if it's greater than zero.
    func positiveValue(for kind: GoalUnitKind, locale: Locale = .current) -> Double? {
        value(for: kind, locale: locale).flatMap { $0 > 0 ? $0 : nil }
    }

    /// The same amount after switching units: a number becomes hours, and time becomes hours.
    func converted(from old: GoalUnitKind, to new: GoalUnitKind) -> GoalAmountInput {
        guard (old == .time) != (new == .time) else { return self }
        var result = GoalAmountInput()
        if new == .time {
            result.hours = number
        } else if let minutes = value(for: .time) {
            result.number = GoalNumber.fieldText(minutes / 60)
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

    /// Full width, but no taller than a sub-task row, so a tap can't reach the next row's checkbox.
    private static let touchHeight: CGFloat = 32

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
                    // No confirmation: it can be undone from the message that follows.
                    withAnimation(.snappy(duration: 0.2)) {
                        store.deleteSubtask(categoryID: categoryID, taskID: taskID, subtaskID: subtask.id)
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.expandedCard(.subheadline))
                        .foregroundStyle(.white, Theme.destructive(theme))
                        .frame(width: expandedCardControl(14), height: expandedCardControl(14))
                        .touchTarget(height: Self.touchHeight)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isListItem ? "Delete item \(subtask.title)" : "Delete sub-task \(subtask.title)")
            } else {
                checkbox
            }

            if !isPastWeek && isEditingTitle {
                TextField(isListItem ? "Item" : "Sub-task", text: $editedTitle)
                    .font(Theme.isRetro(theme) ? .expandedCard(size: 14, design: .monospaced) : .expandedCard(size: 14))
                    .cardField(theme, rc: rc, outset: true)
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
                    // One tap renames, like a task's name.
                    .onTapGesture {
                        if !isPastWeek {
                            editedTitle = subtask.title
                            isEditingTitle = true
                        }
                    }
            }
        }
        .padding(.leading, 24 * expandedCardScale)
        .padding(.vertical, 4)
        // Leaving edit mode removes the field before it loses focus: save the name now.
        .onChange(of: isEditing) { _, editing in
            if !editing && isEditingTitle { commitTitle() }
        }
    }

    private var checkbox: some View {
        Button {
            guard !isPastWeek else { return }
            withAnimation(.snappy(duration: 0.2)) {
                store.toggleSubtask(categoryID: categoryID, taskID: taskID, subtaskID: subtask.id)
            }
        } label: {
            Group {
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
            .modifier(PastWeekDimming(isPastWeek: isPastWeek, theme: theme))
            .touchTarget(height: Self.touchHeight)
        }
        .buttonStyle(CheckboxButtonStyle())
        .disabled(isPastWeek)
        .sensoryFeedback(.selection, trigger: subtask.isCompleted)
        .accessibilityLabel(TaskAccessibility.checkboxLabel(subtask.title, isCompleted: subtask.isCompleted))
        .accessibilityAddTraits(subtask.isCompleted ? .isSelected : [])
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
    /// Working out a task from the typed words (Smart Add).
    @State private var isParsing = false
    /// The type or mode was chosen in the picker for the task being typed; Smart Add keeps
    /// them. Reset after each add, so a pick for one task doesn't force the next ones.
    @State private var pickedType = false
    @State private var pickedMode = false
    /// Bumped when Smart Add adds a task, for its haptic.
    @State private var smartAddCount = 0
    /// What Smart Add just added, shown under the row for a few seconds with Undo.
    @State private var smartAddResult: SmartAddResult?

    private struct SmartAddResult: Equatable {
        let taskID: UUID
        let text: String
        let summary: String
        let token = UUID()
    }
    /// Optional: Smart Add only shows when the parser can run on this device.
    private let parser: TaskTextParser = AppleIntelligenceTaskParser.shared
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    private var hasText: Bool { !newTitle.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            addRow
            if let result = smartAddResult {
                smartAddMessage(result)
                    .transition(.opacity)
            }
        }
        .task(id: smartAddResult?.token) {
            // With VoiceOver it stays (until the next Smart Add), so Undo can be reached.
            guard smartAddResult != nil, !voiceOverEnabled else { return }
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            withAnimation(.snappy(duration: 0.25)) { smartAddResult = nil }
        }
    }

    private var addRow: some View {
        // Wider than other rows: the field's fill reaches past its text (see cardField).
        HStack(spacing: 14) {
            Image(systemName: Theme.isRetro(theme) ? "greaterthan" : "plus.circle")
                .font(.expandedCard(.subheadline)).foregroundStyle(Theme.textTertiary(theme, rc: rc))
            TextField(Theme.isRetro(theme) ? "new_task>" : "Add task", text: $newTitle)
                .font(.expandedCard(.subheadline, design: Theme.isRetro(theme) ? .monospaced : .default))
                .cardField(theme, rc: rc, outset: true)
                .focused($isFocused)
                .submitLabel(.next)
                .onSubmit { addTask(keepTyping: true) }
                .onChange(of: isFocused) { _, focused in
                    if focused {
                        parser.prepare()
                    } else if !showOptions, newTitle.trimmingCharacters(in: .whitespaces).count > 1 {
                        // However the keyboard went away (swiped down, another field
                        // tapped), what was typed is added, like a renamed task's name.
                        // (A single stray letter isn't.)
                        addTask(keepTyping: false)
                    }
                }
            HStack(spacing: 6) {
                if isParsing {
                    ProgressView()
                        .controlSize(.small)
                        .frame(minWidth: expandedCardControl(36), minHeight: expandedCardControl(36))
                        .accessibilityLabel("Working out the task")
                } else if hasText && parser.isAvailable {
                    smartAddButton
                }
                // Kept while the picker is open, which can take the keyboard away.
                if !isParsing && (isFocused || showOptions || !newTitle.isEmpty) {
                    Button { showOptions = true } label: {
                        TaskOptionsLabel(type: newType, mode: newMode, theme: theme, rc: rc)
                            .contentShape(Rectangle())
                            .touchTarget()
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("New task options: \(newType.label), \(newMode.label)")
                    .popover(isPresented: $showOptions) {
                        TaskOptionsPicker(
                            type: newType, mode: newMode, theme: theme, rc: rc,
                            onSelectType: { newType = $0; pickedType = true },
                            onSelectMode: { newMode = $0; pickedMode = true },
                            onAdd: newTitle.trimmingCharacters(in: .whitespaces).isEmpty ? nil : {
                                showOptions = false
                                addTask(keepTyping: true)
                            }
                        )
                    }
                }
            }
        }
        // The keyboard's Done adds a typed task rather than leaving it in the field.
        .onChange(of: store.keyboardDoneRequests) {
            if isFocused { addTask(keepTyping: false) }
        }
        .sensoryFeedback(.success, trigger: smartAddCount)
    }

    /// "✨ Added Gym · repeating goal of 3   Undo": what Smart Add worked out, so a wrong
    /// guess is seen and can be taken back (the task is removed and the words return).
    private func smartAddMessage(_ result: SmartAddResult) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles").foregroundStyle(Theme.accent(theme, rc: rc))
            Text("Added \(result.summary)")
                .foregroundStyle(Theme.textSecondary(theme, rc: rc))
                .lineLimit(2)
            Spacer(minLength: 4)
            Button("Undo") { undoSmartAdd(result) }
                .buttonStyle(.plain)
                .fontWeight(.semibold)
                .foregroundStyle(Theme.accent(theme, rc: rc))
                .touchTarget()
                .accessibilityLabel("Undo Smart Add")
        }
        .font(.expandedCard(.caption1, design: Theme.isRetro(theme) ? .monospaced : .default))
        .padding(.leading, 24 * expandedCardScale)
    }

    /// Takes the task back entirely: no "Deleted … · Undo" of its own, and nothing left
    /// in the field to be added again when the keyboard closes.
    private func undoSmartAdd(_ result: SmartAddResult) {
        withAnimation(.snappy(duration: 0.2)) {
            store.deleteTask(categoryID: categoryID, taskID: result.taskID, undoable: false)
            smartAddResult = nil
        }
    }

    /// Smart Add: the typed words become a task with its type, mode, goal or list items
    /// worked out ("Run 3 times every week" → a repeating goal of 3). Styled like the
    /// type and mode capsule beside it, so it reads as a button.
    private var smartAddButton: some View {
        Button(action: smartAdd) {
            Image(systemName: "sparkles")
                .expandedCardFont(.subheadline)
                .foregroundStyle(Theme.accent(theme, rc: rc))
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Theme.accent(theme, rc: rc).opacity(0.15), in: Capsule())
                .overlay(Capsule().stroke(Theme.accent(theme, rc: rc).opacity(0.35), lineWidth: 1))
                .contentShape(Rectangle())
                .touchTarget()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Smart Add")
        .accessibilityHint("Works out the task's type, schedule, goal or list items from what you typed")
    }

    /// The model reads the words, then the plain rules correct what it can miss. If the
    /// model can't run or fails, the rules alone decide. Picks made in the type and mode
    /// picker are kept. The task goes into the week it was typed in; if the user moved to
    /// another week meanwhile, nothing is added and the text stays.
    private func smartAdd() {
        let text = newTitle.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, !isParsing else { return }
        let weekStart = store.selectedWeek?.startDay
        isParsing = true
        Task {
            var parsed: ParsedTask
            var usedModel = false
            do {
                if let result = try await parser.parse(text) {
                    parsed = result
                    usedModel = true
                } else {
                    parsed = TaskTextHints.refine(ParsedTask(title: text), from: text)
                }
            } catch {
                Self.log.error("Smart Add couldn't parse: \(error)")
                parsed = TaskTextHints.refine(ParsedTask(title: text), from: text)
            }
            isParsing = false
            if pickedMode { parsed.mode = newMode }
            if pickedType && parsed.type != newType {
                parsed.type = newType
                parsed.items = []
                parsed.goalTarget = nil
            }
            // A goal without an amount takes the keyboard for its target; a list without
            // items, for its first item.
            let awaitsTarget = (parsed.type == .goal && parsed.goalTarget == nil) || (parsed.type == .list && parsed.items.isEmpty)
            var added: UUID?
            withAnimation(.snappy(duration: 0.2)) {
                added = store.addParsedTask(parsed, categoryID: categoryID, weekStart: weekStart)
                // A goal it couldn't find an amount for takes the keyboard for its target.
                if awaitsTarget, let added { store.taskAwaitingFirstInput = added }
            }
            guard let added else { return }
            smartAddCount += 1
            pickedType = false
            pickedMode = false
            // Says when Apple Intelligence couldn't be used and only the plain rules applied.
            let summary = Self.describe(parsed, separator: " · ") + (usedModel ? "" : " · without Apple Intelligence")
            withAnimation(.snappy(duration: 0.25)) {
                smartAddResult = SmartAddResult(taskID: added, text: text, summary: summary)
            }
            AccessibilityNotification.Announcement("Added \(Self.describe(parsed)). Undo is below.").post()
            // Anything typed meanwhile stays.
            if newTitle.trimmingCharacters(in: .whitespaces) == text { newTitle = "" }
        }
    }

    /// "Run, repeating goal of 3" (VoiceOver), or with " · " for the message under the row.
    private static func describe(_ task: ParsedTask, separator: String = ", ") -> String {
        let mode = task.mode.label.lowercased()
        switch task.type {
        case .goal:
            let amount = task.goalTarget.map { " of \(task.goalKind.format($0))\(task.goalUnit.isEmpty ? "" : " \(task.goalUnit)")" } ?? ""
            return "\(task.title)\(separator)\(mode) goal\(amount)"
        case .list:
            return "\(task.title)\(separator)\(mode) list of \(task.items.count)"
        case .checkbox:
            return "\(task.title)\(separator)\(mode)"
        }
    }

    private static let log = Logger(subsystem: "com.symonym.Tasquel", category: "SmartAdd")

    /// Adds exactly what was typed, with the type and mode last picked (Smart Add is the
    /// only thing that reads the words). Return keeps the keyboard up for the next task;
    /// a new list or goal takes the keyboard for its first item or target instead.
    private func addTask(keepTyping: Bool) {
        let title = newTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty, !isParsing else { return }
        let task = ParsedTask(title: title, type: newType, mode: newMode)
        let awaitsInput = task.type != .checkbox
        withAnimation(.snappy(duration: 0.2)) {
            let id = store.addParsedTask(task, categoryID: categoryID)
            if keepTyping && awaitsInput { store.taskAwaitingFirstInput = id }
        }
        newTitle = ""
        pickedType = false
        pickedMode = false
        if keepTyping && !awaitsInput { isFocused = true }
    }
}
