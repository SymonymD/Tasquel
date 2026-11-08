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
    /// Hides a decorative view from VoiceOver, even inside an open card. (An open card is
    /// marked `.accessibilityHidden(false)`, which brings back children hidden with
    /// `.accessibilityHidden(true)`; a representation of nothing stays hidden.)
    func hiddenFromVoiceOver() -> some View {
        accessibilityRepresentation { EmptyView() }
    }

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
    /// The goal editor's Step; empty means automatic.
    @State private var goalStepInput = GoalAmountInput()
    /// The goal editor's Days (`goalDays`, 1–7; blank for none). With a Step too, the target
    /// follows Step × Days; typing the target by hand clears it.
    @State private var goalDaysInput = ""
    @State private var isEditingGoal = false
    /// When the first + tap brought − in (see `goalSteps`).
    @State private var minusAppearedAt = Date.distantPast
    @FocusState private var focusedGoalField: GoalFocus?
    @State private var showOptions = false
    /// Another task is being dragged over this one (reordering in edit mode).
    @State private var isDropTarget = false
    /// Smart Add just added this task: lit like a drop target for a moment.
    private var isHighlighted: Bool { store.highlightedTaskID == task.id }
    /// The add-sub-task (or a list's add-item) field is open.
    @State private var isAddingSubtask = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isCardOpen) private var isCardOpen
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// The goal text fields, for moving the keyboard between them.
    nonisolated private enum GoalField: Hashable { case target, step, days, unitName }
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
                        .accessibilityActions { moveActions }
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
                    .accessibilityActions { moveActions }
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
                        // All the lines it needs: beside the icons, a row could otherwise get
                        // one line's height and cut the title off ("Plan Mom's birt…").
                        .fixedSize(horizontal: false, vertical: true)
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
                    // At the largest text sizes the icons stop growing, leaving the title
                    // room to wrap at word breaks ("Yog-a" otherwise).
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
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
                // Adding is off while the card is in edit mode. A list's row is a + until it's
                // tapped, like Add task; a sub-task's appears from the task's own +.
                if !isPastWeek && !isEditing && (task.taskType == .list || isAddingSubtask) {
                    HStack(spacing: 12) {
                        subtaskPlus
                        if isAddingSubtask {
                            // Multi-line for the same reason as Add task: Return keeps the keyboard.
                            TextField(subtaskPlaceholder, text: $newSubtaskTitle, axis: .vertical)
                                .lineLimit(1...4)
                                .accessibilityLabel(task.taskType == .list ? "Add item" : "Add sub-task")
                                .font(.expandedCard(.caption1, design: Theme.isRetro(theme) ? .monospaced : .default))
                                .cardField(theme, rc: rc, outset: true)
                                // Its fill (drawn 8pt past the text) ends at the type/mode
                                // button's right edge, above.
                                .padding(.trailing, 8)
                                // A list's field opens from its + (a sub-task's whole row does).
                                .transition(reduceMotion ? .identity : .revealFromLeading)
                                .focused($isSubtaskFieldFocused)
                                .submitLabel(.next)
                                .onChange(of: newSubtaskTitle) { _, text in submitTypedSubtask(text) }
                                // An empty field closes when the keyboard does.
                                .onChange(of: isSubtaskFieldFocused) { _, focused in
                                    guard !focused else { return }
                                    // However the keyboard went away, what was typed is added;
                                    // an empty field then closes.
                                    addSubtask(keepTyping: false)
                                    withAnimation(reduceMotion ? nil : .easeIn(duration: 0.2)) { isAddingSubtask = false }
                                }
                        } else {
                            // Holds the open row's height, so opening it moves nothing below,
                            // with the field's words where they'll be ("Add Item").
                            Text(" ")
                                .font(.expandedCard(.caption1))
                                .cardField(theme, rc: rc, outset: true)
                                .frame(maxWidth: .infinity)
                                .hidden()
                                .overlay(alignment: .leading) {
                                    PlusRowLabel(text: subtaskPlaceholder,
                                                 font: .expandedCard(.caption1, design: Theme.isRetro(theme) ? .monospaced : .default),
                                                 theme: theme, rc: rc, action: openSubtaskField)
                                }
                        }
                    }
                    .padding(.leading, 24 * expandedCardScale)
                    .padding(.vertical, 2)
                    .transition(task.taskType == .list || reduceMotion ? .identity : .revealFromLeading)
                }
            }
        }
        .task(id: store.taskAwaitingFirstInput) {
            guard store.taskAwaitingFirstInput == task.id else { return }
            store.taskAwaitingFirstInput = nil
            // Its card was closed meanwhile (Smart Add was still working): the field is
            // hidden, so the keyboard stays down.
            guard isCardOpen else { return }
            if task.taskType == .goal {
                focusedGoalField = GoalFocus(field: .target, part: goalKindSelection == .time ? .hours : .number)
            } else {
                openSubtaskField()
            }
        }
        .onChange(of: store.keyboardDoneRequests) { saveTypedOnDone() }
        // Edit mode removes the add-sub-task (or add-item) field before it loses focus, so
        // its save-on-close never runs: what was typed is added now.
        .onChange(of: isEditing) { _, editing in
            guard editing else { return }
            addSubtask(keepTyping: false)
            isAddingSubtask = false
        }
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
            if isDropTarget || isHighlighted {
                RoundedRectangle(cornerRadius: 8).fill(Theme.accent(theme, rc: rc).opacity(0.12)).padding(-4)
            }
        }
        // Smart Add's highlight fades after a moment. If the row goes meanwhile (Undo), it's
        // cleared at once.
        .task(id: isHighlighted) {
            guard isHighlighted else { return }
            try? await Task.sleep(for: .seconds(0.7))
            guard isHighlighted else { return }
            if Task.isCancelled {
                store.highlightedTaskID = nil
            } else {
                withAnimation(.easeOut(duration: 0.3)) { store.highlightedTaskID = nil }
            }
        }
        // A light tap for ticking off; a success for reaching a goal.
        .sensoryFeedback(trigger: task.isCompleted) { _, done in done && task.taskType != .goal ? .impact(weight: .light) : nil }
        .sensoryFeedback(.success, trigger: task.goalIsComplete) { wasDone, done in !wasDone && done }
    }

    /// In edit mode, VoiceOver's way to reorder (the drag handle is for touch): on the
    /// task's own checkbox or goal ring, not its sub-tasks, and only the moves there are.
    @ViewBuilder
    private var moveActions: some View {
        if isEditing && !isPastWeek,
           let tasks = store.selectedWeek?.categories.first(where: { $0.id == categoryID })?.tasks,
           let index = tasks.firstIndex(where: { $0.id == task.id }) {
            if index > 0 {
                Button("Move Up") { withAnimation { store.moveTask(categoryID: categoryID, taskID: task.id, by: -1) } }
            }
            if index < tasks.count - 1 {
                Button("Move Down") { withAnimation { store.moveTask(categoryID: categoryID, taskID: task.id, by: 1) } }
            }
        }
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
        Button {
            // On iPad the keyboard closes first (what's typed in Add task is added, as
            // whenever it closes): with it up, the picker went above the row and off the
            // screen. It opens once the keyboard is down; opening it as the keyboard went
            // cancelled it.
            if horizontalSizeClass == .regular,
               UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { showOptions = true }
            } else {
                showOptions = true
            }
        } label: {
            TaskOptionsLabel(type: task.taskType, mode: task.mode, theme: theme, rc: rc)
                .frame(minHeight: expandedCardControl(36))
                .contentShape(Rectangle())
                .touchTarget()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Task options: \(task.taskType.label), \(task.mode.label)")
        .accessibilityRemoveTraits(.isSelected)  // the checkbox type's checkmark icon isn't a state
        .popover(isPresented: $showOptions) {
            TaskOptionsPicker(
                type: task.taskType, mode: task.mode, theme: theme, rc: rc,
                confirmsLeavingGoal: task.goalTarget != nil || task.goalProgress != nil,
                onSelectType: { type in
                    withAnimation(.snappy(duration: 0.2)) {
                        store.updateTaskType(categoryID: categoryID, taskID: task.id, type: type)
                    }
                },
                onSelectMode: { store.updateTaskMode(categoryID: categoryID, taskID: task.id, mode: $0) },
                onDone: { showOptions = false },
                isThisWeekOnlyCategory: store.selectedWeek?.categories.first { $0.id == categoryID }?.isThisWeekOnly == true
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
        openSubtaskField()
    }

    /// The sub-task (or item) field opens from the left, then takes the keyboard. (As with
    /// Add task's: bringing the keyboard up during the opening froze it.)
    private func openSubtaskField() {
        guard !reduceMotion else {
            isAddingSubtask = true
            DispatchQueue.main.async { isSubtaskFieldFocused = true }
            return
        }
        withAnimation(.easeOut(duration: 0.2)) {
            isAddingSubtask = true
        } completion: {
            isSubtaskFieldFocused = true
        }
    }

    /// A list's add-item +: larger until it's tapped, like Add task's (and then it puts the
    /// keyboard back on the field). Beside a sub-task's field, just a small +.
    @ViewBuilder
    private var subtaskPlus: some View {
        let icon = Image(systemName: Theme.isRetro(theme) ? "greaterthan" : "plus.circle")
            .font(.expandedCard(.caption1))
        if task.taskType == .list {
            PlusOpener(icon: icon, isOpen: isAddingSubtask, scale: 1.45, theme: theme, rc: rc,
                       label: "Add item to \(task.title)", hint: "Opens a field to type a new item",
                       action: openSubtaskField)
        } else {
            icon
                .foregroundStyle(Theme.textTertiary(theme, rc: rc))
                .hiddenFromVoiceOver()
        }
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
            .hiddenFromVoiceOver()  // VoiceOver uses Move Up / Move Down on the task
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

    /// The goal's button, the bar and the amount on one line, and the − and + steps centered under
    /// the bar. At accessibility text sizes the amount goes under the bar, whole.
    private var goalProgressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let target = task.goalTarget, target > 0 {
                let stacksAmount = dynamicTypeSize.isAccessibilitySize
                HStack(alignment: .goalBar, spacing: 10) {
                    if !isPastWeek { editGoalButton(target: target) }
                    VStack(alignment: .leading, spacing: 8) {
                        ProgressView(value: min((task.goalProgress ?? 0) / target, 1.0))
                            .progressViewStyle(GoalBarStyle(
                                tint: task.goalIsComplete ? Theme.dotComplete(theme, rc: rc) : Theme.accent(theme, rc: rc),
                                track: Theme.textTertiary(theme, rc: rc).opacity(0.3),
                                isRetro: Theme.isRetro(theme)
                            ))
                            .alignmentGuide(.goalBar) { $0[VerticalAlignment.center] }
                        if stacksAmount { goalAmount }
                        if !isPastWeek && !isEditingGoal {
                            goalSteps.frame(maxWidth: .infinity)
                        }
                    }
                    if !stacksAmount { goalAmount }
                }
                .padding(.leading, 24 * expandedCardScale)

                if isEditingGoal && !isPastWeek {
                    editGoalForm
                }
            } else if !isPastWeek {
                setGoalForm
            }
        }
        .padding(.top, 2)
    }

    /// "2/3 bags", "45m / 2h".
    private var goalAmount: some View {
        HStack(spacing: 10) {
            Text(task.goalFraction)
                .font(Theme.isRetro(theme) ? .expandedCard(.caption1, weight: .bold, design: .monospaced) : .expandedCard(.caption1, weight: .bold).monospacedDigit())
                .foregroundStyle(task.goalIsComplete ? Theme.dotComplete(theme, rc: rc) : Theme.textPrimary(theme, rc: rc))
            if let unit = task.goalUnitLabel {
                Text(unit).font(.expandedCard(.caption1, design: Theme.isRetro(theme) ? .monospaced : .default)).foregroundStyle(Theme.textSecondary(theme, rc: rc))
            }
        }
    }

    /// The sliders left of the bar: open the goal's editor (Target and Step), or close it
    /// without saving while it's open. Not a pencil: that's Saved Categories' edit button,
    /// and the card's is a pencil on a square.
    private func editGoalButton(target: Double) -> some View {
        Button {
            if isEditingGoal { closeGoalEditing() } else { startEditingGoal(target: target) }
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.expandedCard(.subheadline, weight: .medium))
                .foregroundStyle(isEditingGoal ? Theme.accent(theme, rc: rc) : Theme.textSecondary(theme, rc: rc))
                .touchTarget()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Edit goal")
        .accessibilityAddTraits(isEditingGoal ? .isSelected : [])
    }

    // MARK: Goal Forms

    /// Shown until a goal has a target: unit and target on one line, wrapping
    /// onto two lines only when they don't fit.
    private var setGoalForm: some View {
        VStack(alignment: .leading, spacing: 4) {
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
        goalHint(goalTargetInput.problem(for: goalKindSelection))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 24 * expandedCardScale)
    }

    /// Why an amount can't be used, under its field (see `GoalAmountInput.problem`).
    @ViewBuilder
    private func goalHint(_ problem: String?) -> some View {
        if let problem {
            Text(problem)
                .font(.expandedCard(.caption1, design: Theme.isRetro(theme) ? .monospaced : .default))
                .foregroundStyle(Theme.destructive(theme))
        }
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
            goalHint(goalTargetInput.problem(for: goalKindSelection))
            // What + and − add or take away; empty picks one from the target.
            labeledGoalRow("Step") {
                goalAmountFields($goalStepInput, kind: goalKindSelection, field: .step, placeholder: "Auto")
            }
            goalHint(goalStepInput.problem(for: goalKindSelection))
            // A goal counted per day ("meditate 10 min daily"): the step is a day's amount,
            // and the target follows it.
            labeledGoalRow("Days") {
                goalNumberField("–", text: $goalDaysInput, focus: GoalFocus(field: .days, part: .number),
                                keyboard: .numberPad, width: 44)
                    .accessibilityLabel("Days")
                    .accessibilityHint("1 to 7. With a step, the target is the step times the days.")
            }
            goalHint(goalDaysProblem)
            if let days = goalDays, goalStepInput.positiveValue(for: goalKindSelection) != nil {
                Text("Step × \(days) \(days == 1 ? "day" : "days") = Target")
                    .font(.expandedCard(.caption1, design: Theme.isRetro(theme) ? .monospaced : .default))
                    .foregroundStyle(Theme.textTertiary(theme, rc: rc))
            }
            ViewThatFits(in: .horizontal) {
                editGoalButtons(stacked: false)
                editGoalButtons(stacked: true)
            }
        }
        .font(.expandedCard(.body, design: Theme.isRetro(theme) ? .monospaced : .default))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 24 * expandedCardScale)
        .onChange(of: goalStepInput) { followStepTimesDays() }
        .onChange(of: goalDaysInput) { _, text in
            // One digit at most (the number pad has no other keys).
            let digits = String(text.filter(\.isNumber).prefix(1))
            if digits != text { goalDaysInput = digits }
            followStepTimesDays()
        }
        .onChange(of: goalTargetInput) { _, _ in
            // Typed by hand: the target is the user's, and stops following.
            if focusedGoalField?.field == .target { goalDaysInput = "" }
        }
    }

    /// The editor's Days when it's 1–7; nil when blank or out of range.
    private var goalDays: Int? {
        Int(goalDaysInput).flatMap { (1...7).contains($0) ? $0 : nil }
    }

    private var goalDaysProblem: String? {
        !goalDaysInput.isEmpty && goalDays == nil ? "Days can be 1 to 7" : nil
    }

    /// With a Step and Days, the target is Step × Days.
    private func followStepTimesDays() {
        guard let days = goalDays,
              let target = GoalAmountInput.perDayTarget(step: goalStepInput, days: days, kind: goalKindSelection) else { return }
        goalTargetInput = target
    }

    /// Delete Task, Cancel and Save Goal: in a row, or one above another (Save on top)
    /// when a row doesn't fit.
    private func editGoalButtons(stacked: Bool) -> some View {
        let layout = stacked
            ? AnyLayout(VStackLayout(alignment: .trailing, spacing: 10))
            : AnyLayout(HStackLayout(spacing: 12))
        return layout {
                // Deleting removes the whole task, so it's small and kept apart from Save.
                Button(role: .destructive, action: deleteTask) {
                    Text("Delete Task")
                        .font(.expandedCard(.caption1, design: Theme.isRetro(theme) ? .monospaced : .default))
                        .foregroundStyle(Theme.destructive(theme))
                        .touchTarget()
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete task")
                if !stacked { Spacer(minLength: 0) }
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
                .accessibilityRemoveTraits(.isSelected)
            }
            .frame(maxWidth: stacked ? .infinity : nil, alignment: .trailing)
            .accessibilityElement(children: .contain)
    }

    /// Quantity, Time, or Custom. Switching carries a typed amount across (hours ↔ number).
    private var goalUnitMenu: some View {
        Menu {
            Picker("Unit", selection: Binding(
                get: { goalKindSelection },
                set: { newKind in
                    goalTargetInput = goalTargetInput.converted(from: goalKindSelection, to: newKind)
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
            .onSubmit { submitGoalField(.unitName) }
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
            // iPad and hardware keyboards have Return (the iPhone's number pad doesn't).
            .onSubmit { submitGoalField(focus.field) }
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

    /// A label column beside the fields; at accessibility text sizes the label goes above
    /// them and the fields stack, so the editor never grows wider than the screen.
    @ViewBuilder
    private func labeledGoalRow(_ label: String, @ViewBuilder content: () -> some View) -> some View {
        let title = Text(label)
            .font(.expandedCard(.caption1, design: Theme.isRetro(theme) ? .monospaced : .default))
            .foregroundStyle(Theme.textSecondary(theme, rc: rc))
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 6) {
                title
                VStack(alignment: .leading, spacing: 6) { content() }
            }
        } else {
            HStack(spacing: 8) {
                title.frame(width: 64 * expandedCardScale, alignment: .leading)
                content()
            }
        }
    }

    /// Set, 15% larger than caption text so it isn't missed beside the keyboard's Done.
    private func actionPill(_ title: String) -> some View {
        Text(title)
            .font(.expandedCard(.caption1, weight: .bold, scale: 1.15))
            // Never wraps ("+15 / m" in retro's wider monospaced font); the words beside it shrink instead.
            .lineLimit(1)
            .fixedSize()
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
        case (true, false): "Add Item"
        case (false, true): "sub_task>"
        case (false, false): "Add Sub-task"
        }
    }

    /// Return (a line break) adds the sub-task or item and keeps the keyboard for the next;
    /// Return in an empty field closes it. Pasted lines each become one.
    private func submitTypedSubtask(_ text: String) {
        guard let lineBreak = text.firstIndex(where: \.isNewline) else { return }
        let line = String(text[..<lineBreak])
        let rest = String(text[text.index(after: lineBreak)...])
        guard !line.trimmingCharacters(in: .whitespaces).isEmpty else {
            newSubtaskTitle = rest
            if rest.isEmpty { isSubtaskFieldFocused = false }
            return
        }
        addSubtask(line)
        newSubtaskTitle = rest  // one change to the field's text
    }

    /// `typed`: a line already taken out of the field (Return), instead of the field's text.
    private func addSubtask(_ typed: String? = nil, keepTyping: Bool = true) {
        let title = (typed ?? newSubtaskTitle).trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        withAnimation(.snappy(duration: 0.2)) {
            store.addSubtask(categoryID: categoryID, taskID: task.id, title: title)
        }
        if typed == nil { newSubtaskTitle = "" }
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
        goalUnitText = task.goalUnit ?? ""
        goalStepInput = task.goalStep.map { GoalAmountInput($0, kind: kind) } ?? GoalAmountInput()
        goalDaysInput = task.goalDays.map(String.init) ?? ""
        isEditingGoal = true
    }

    private func closeGoalEditing() {
        isEditingGoal = false
        goalTargetInput = GoalAmountInput()
        goalStepInput = GoalAmountInput()
        goalDaysInput = ""
        goalUnitText = ""
        focusedGoalField = nil
    }

    private var canSaveEditedGoal: Bool {
        goalTargetInput.positiveValue(for: goalKindSelection) != nil
            && (goalStepInput.isEmpty || goalStepInput.positiveValue(for: goalKindSelection) != nil)
            && goalDaysProblem == nil
    }

    private func saveEditedGoal() {
        guard let target = goalTargetInput.positiveValue(for: goalKindSelection) else { return }
        let oldKind = task.goalKind
        store.setGoalTarget(categoryID: categoryID, taskID: task.id, target: target, kind: goalKindSelection, unit: goalUnitText)
        // A switch to or from Time carries the progress over like the target's amount
        // (2 → 2h), so 2 of 3 doesn't become 2 minutes.
        if let progress = task.goalProgress, (oldKind == .time) != (goalKindSelection == .time),
           let carried = GoalAmountInput(progress, kind: oldKind).converted(from: oldKind, to: goalKindSelection).value(for: goalKindSelection) {
            store.updateGoalProgress(categoryID: categoryID, taskID: task.id, progress: carried)
        }
        store.setGoalStep(categoryID: categoryID, taskID: task.id, step: goalStepInput.positiveValue(for: goalKindSelection),
                          days: goalDays)
        closeGoalEditing()
    }

    /// One step forward (+) or back (−); never below zero.
    private func addQuickProgress(sign: Double) {
        let wasComplete = task.goalIsComplete
        if sign > 0 && (task.goalProgress ?? 0) == 0 { minusAppearedAt = Date() }
        let progress = max(0, (task.goalProgress ?? 0) + sign * quickStep)
        withAnimation(.snappy(duration: 0.2)) {
            store.updateGoalProgress(categoryID: categoryID, taskID: task.id, progress: progress)
        }
        // The goal ticks itself off: say so.
        if !wasComplete, let target = task.goalTarget, progress >= target {
            AccessibilityNotification.Announcement("\(task.title): goal reached").post()
        }
    }

    /// The most common update, in one tap, and its undo. With no progress yet, + is alone,
    /// centered; the first tap nudges it over to make room for −, which takes a step back
    /// (also after the goal is reached, to take back the last tap). + stays after the
    /// target too, so a goal can be beaten. − is only as wide as it needs, so + moves less
    /// than half its width and a quick second tap where it was still lands on it; − also
    /// ignores taps for a moment after it appears, so that tap can't undo the first.
    private var goalSteps: some View {
        let hasProgress = (task.goalProgress ?? 0) > 0
        let canAdd = (task.goalProgress ?? 0) < GoalUnitKind.maxValue
        return GoalStepsLayout(spacing: Self.goalStepSpacing) {
            if hasProgress {
                Button {
                    guard Date().timeIntervalSince(minusAppearedAt) > 0.4 else { return }
                    addQuickProgress(sign: -1)
                } label: {
                    stepTapArea(stepPill("−", filled: false).frame(minWidth: 28), toward: [.leading])
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale(scale: 0.6, anchor: .trailing)))
                .accessibilityLabel(task.goalKind == .time ? "Remove \(Int(quickStep)) minutes" : "Remove \(task.goalKind.format(quickStep))")
            }
            Button { addQuickProgress(sign: 1) } label: {
                stepTapArea(stepPill("+" + task.goalKind.format(quickStep), filled: true),
                            toward: hasProgress ? [.trailing] : [.leading, .trailing])
            }
            .buttonStyle(.plain)
            .opacity(canAdd ? 1 : 0)
            .disabled(!canAdd)
            .accessibilityHidden(!canAdd)
            .accessibilityLabel(task.goalKind == .time ? "Add \(Int(quickStep)) minutes" : "Add \(task.goalKind.format(quickStep))")
            // The + itself, as − comes and goes: it slides rather than being replaced.
            .layoutValue(key: IsPlusStep.self, value: true)
        }
    }

    private static let goalStepSpacing: CGFloat = 6

    /// − outlined, + filled, as wide as `GoalStepsLayout` makes them (− as wide as it needs).
    /// 
    private func stepPill(_ title: String, filled: Bool) -> some View {
        let accent = Theme.accent(theme, rc: rc)
        return Text(title)
            .font(.expandedCard(.caption1, weight: .bold, design: Theme.isRetro(theme) ? .monospaced : .default))
            // Never wraps ("+15 / m" in retro's wider monospaced font).
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 8).padding(.vertical, 5)
            .frame(maxWidth: .infinity)
            // Retro's accent is a bright phosphor color: dark text stays readable on it.
            .foregroundStyle(filled ? (Theme.isRetro(theme) ? Color.black : Color.white) : accent)
            .background(filled ? accent : Color.clear, in: Capsule())
            .overlay { if !filled { Capsule().stroke(accent.opacity(0.6), lineWidth: 1) } }
    }

    /// A step's tap area: 44pt tall, reaching out on its own side(s) and into half the gap,
    /// so neither step's area covers the other (44pt squares around two small pills did).
    /// The pill keeps its size in the layout.
    private func stepTapArea(_ pill: some View, toward edges: Set<HorizontalEdge>) -> some View {
        let vertical: CGFloat = 10, outward: CGFloat = 16, inward = Self.goalStepSpacing / 2
        let leading = edges.contains(.leading) ? outward : inward
        let trailing = edges.contains(.trailing) ? outward : inward
        return pill
            .padding(.vertical, vertical).padding(.leading, leading).padding(.trailing, trailing)
            .contentShape(Rectangle())
            .padding(.vertical, -vertical).padding(.leading, -leading).padding(.trailing, -trailing)
    }

    /// One tap's worth of progress: 1 for counts; for time, a step that suits the target
    /// (+5m toward 10 minutes, +30m toward 4 hours).
    private var quickStep: Double { task.goalStepOrAutomatic }

    /// The keyboard's Done saves a goal amount or sub-task typed in this row but not yet
    /// set or added; number pads have no Return key, so otherwise it would be lost.
    private func saveTypedOnDone() {
        if isSubtaskFieldFocused {
            addSubtask()
            return
        }
        guard let field = focusedGoalField?.field else { return }
        submitGoalField(field)
    }

    /// Saves what's typed in a goal field, as Set, Add or Save Goal would: from the
    /// keyboard's Done button, or Return.
    private func submitGoalField(_ field: GoalField) {
        switch field {
        case .target, .unitName, .step, .days:
            if isEditingGoal { saveEditedGoal() } else { setGoal() }
        }
    }
}

// MARK: - Plus Opener

/// A + that opens a field: larger while the field is closed, shrinking to the field's
/// side as it opens. The image is always there (so it scales smoothly, no crossfade); the
/// 44pt button over it only while closed, so that's all VoiceOver hears of it.
private struct PlusOpener<Icon: View>: View {
    let icon: Icon
    let isOpen: Bool
    let scale: CGFloat
    let theme: AppearanceMode
    let rc: RetroColor
    let label: String
    let hint: String
    let action: () -> Void

    var body: some View {
        icon
            .foregroundStyle(isOpen ? Theme.textTertiary(theme, rc: rc) : Theme.textSecondary(theme, rc: rc))
            .scaleEffect(isOpen ? 1 : scale, anchor: .leading)
            .hiddenFromVoiceOver()
            .overlay {
                if !isOpen {
                    Button(action: action) {
                        Color.clear
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(label)
                    .accessibilityHint(hint)
                }
            }
    }
}

/// A closed + row's words ("Add Task", "Add Item"): light like the field's placeholder and
/// where it will be, so the field opens around them. A tap on them opens it too; VoiceOver
/// has the + button for that.
private struct PlusRowLabel: View {
    let text: String
    let font: Font
    let theme: AppearanceMode
    let rc: RetroColor
    let action: () -> Void

    var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(Theme.textTertiary(theme, rc: rc))
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
            .hiddenFromVoiceOver()
    }
}

// MARK: - Reveal

/// Uncovers a view from its leading edge outward, as the Add task field opens from its +.
/// The mask reaches a little past the view, so a field's fill drawn around its text (see
/// `cardField`) isn't cut off.
private struct RevealFromLeading: ViewModifier, Animatable {
    var fraction: CGFloat
    var animatableData: CGFloat {
        get { fraction }
        set { fraction = newValue }
    }

    func body(content: Content) -> some View {
        content.mask(alignment: .topLeading) {
            GeometryReader { proxy in
                let margin: CGFloat = 24
                Rectangle()
                    .frame(width: (proxy.size.width + margin * 2) * fraction, height: proxy.size.height + margin * 2)
                    .offset(x: -margin, y: -margin)
            }
        }
    }
}

extension AnyTransition {
    static var revealFromLeading: AnyTransition {
        .modifier(active: RevealFromLeading(fraction: 0), identity: RevealFromLeading(fraction: 1))
    }
}

// MARK: - Goal Bar

extension VerticalAlignment {
    private enum GoalBar: AlignmentID {
        static func defaultValue(in context: ViewDimensions) -> CGFloat { context[VerticalAlignment.center] }
    }

    /// A goal's bar: the goal's button and the amount beside it line up with the bar, not with
    /// the bar and the steps under it.
    static let goalBar = VerticalAlignment(GoalBar.self)
}

/// A goal's bar: twice the system bar's height (8pt), with round ends (square in Retro).
/// Still a ProgressView, so VoiceOver reads it as one.
private struct GoalBarStyle: ProgressViewStyle {
    let tint: Color
    let track: Color
    let isRetro: Bool

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: isRetro ? 1 : 4)
        let fraction = min(max(configuration.fractionCompleted ?? 0, 0), 1)
        return shape.fill(track)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    shape.fill(tint).frame(width: proxy.size.width * fraction)
                }
            }
            .frame(height: 8)
    }
}

/// Marks the + among the steps.
nonisolated private struct IsPlusStep: LayoutValueKey {
    static let defaultValue = false
}

/// A goal's − and + steps. + takes half of about a third of the width offered (the bar's),
/// or what its label needs ("+15m"), alone or with −; − takes only what it needs. The
/// parent centers them, so + is centered alone and moves over when − comes in.
private struct GoalStepsLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = itemSizes(proposal, subviews)
        let width = sizes.map(\.width).reduce(0, +) + spacing * CGFloat(max(subviews.count - 1, 0))
        return CGSize(width: width, height: sizes.map(\.height).max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        for (subview, size) in zip(subviews, itemSizes(proposal, subviews)) {
            subview.place(at: CGPoint(x: x, y: bounds.midY), anchor: .leading, proposal: ProposedViewSize(size))
            x += size.width + spacing
        }
    }

    private func itemSizes(_ proposal: ProposedViewSize, _ subviews: Subviews) -> [CGSize] {
        let offered = proposal.width.flatMap { $0.isFinite ? $0 : nil } ?? 0
        let share = (offered / 3 - spacing) / 2
        return subviews.map { subview in
            let natural = subview.sizeThatFits(.unspecified)
            return CGSize(width: subview[IsPlusStep.self] ? max(natural.width, share) : natural.width, height: natural.height)
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

    /// A per-day goal's target for a step: the step × its days (20 min × 7 is 2h 20m),
    /// capped like any goal. Nil while the step isn't a valid amount.
    static func perDayTarget(step: GoalAmountInput, days: Int, kind: GoalUnitKind) -> GoalAmountInput? {
        guard let value = step.positiveValue(for: kind) else { return nil }
        return GoalAmountInput(min(value * Double(days), GoalUnitKind.maxValue), kind: kind)
    }

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

    /// Why what's typed can't be used, said under the field (Set and Save stay off
    /// otherwise, with no reason given): over the maximum, or zero where an amount has to
    /// be more. Nil when it's fine, or when nothing (or no number) is typed.
    func problem(for kind: GoalUnitKind, allowsZero: Bool = false, locale: Locale = .current) -> String? {
        guard !isEmpty else { return nil }
        let typed: Double
        if kind == .time {
            guard let h = hours.isEmpty ? 0 : GoalNumber.parse(hours, locale: locale),
                  let m = minutes.isEmpty ? 0 : GoalNumber.parse(minutes, locale: locale) else { return nil }
            typed = h * 60 + m
        } else {
            guard let n = GoalNumber.parse(number, locale: locale) else { return nil }
            typed = n
        }
        if typed > GoalUnitKind.maxValue {
            let limit = kind == .time ? Int(GoalUnitKind.maxValue / 60) : Int(GoalUnitKind.maxValue)
            return "Up to " + limit.formatted(.number.locale(locale)) + (kind == .time ? " hours" : "")
        }
        if typed <= 0 && !allowsZero { return "More than 0" }
        return nil
    }

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
                    // Done ones are struck through in the secondary color, like done tasks (the
                    // tertiary color was too faint to read); Retro's faint color reads fine.
                    .foregroundStyle(subtask.isCompleted && Theme.isRetro(theme) ? Theme.textTertiary(theme, rc: rc) : Theme.textSecondary(theme, rc: rc))
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
    /// The card is in its own edit mode. The row shows nothing then (the This week only
    /// switch takes its place) but stays, so a Smart Add still working adds its task when
    /// it's done, and what's typed is added as editing starts. (Removed, it lost both.)
    var isEditing = false

    private var theme: AppearanceMode { store.appearanceMode }
    private var rc: RetroColor { store.retroColor }

    @State private var newTitle = ""
    @State private var newType: TaskType = .checkbox
    @State private var newMode: TaskMode = .oneTime
    @State private var showOptions = false
    /// The options are about to open on iPad, after the keyboard closes: the field losing
    /// focus meanwhile mustn't add the words (they're what the options are for).
    @State private var isOpeningOptions = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @FocusState private var isFocused: Bool
    /// Working out a task from the typed words (Smart Add).
    @State private var isParsing = false
    /// The type or mode was chosen in the picker for the task being typed; Smart Add keeps
    /// them. Reset after each add, so a pick for one task doesn't force the next ones.
    @State private var pickedType = false
    @State private var pickedMode = false
    /// Bumped when Smart Add adds a task, for its haptic.
    @State private var smartAddCount = 0
    /// The field is open: + was tapped. Until then only a larger + shows (see `addRow`).
    @State private var isFieldOpen = false
    /// What Smart Add just added, shown above the row (so right under the new task, which
    /// goes at the end) for a few seconds with Undo.
    @State private var smartAddResult: SmartAddResult?
    /// What Smart Add worked out, waiting to be added (see `finishSmartAdd`).
    @State private var smartAddOutcome: SmartAddOutcome?
    #if DEBUG
    private static let keepsSmartAddMessage = ChecklistStore.launchesWithDemoData
    #else
    private static let keepsSmartAddMessage = false
    #endif

    private struct SmartAddResult: Equatable {
        let taskID: UUID
        let text: String
        let summary: String
        /// Its time is up while the field has the keyboard: it's invisible but keeps its
        /// place, so the field being typed in doesn't move up (see `body`).
        var isFaded = false
        let token = UUID()
    }

    private struct SmartAddOutcome: Equatable {
        let parsed: ParsedTask
        /// The words it was worked out from.
        let text: String
        /// Said after the summary when only the plain rules applied.
        let note: String
        /// The week it was typed in.
        let weekStart: DayKey?
        let token = UUID()
    }
    /// Optional: Smart Add only shows when the parser can run on this device.
    private let parser: TaskTextParser = SmartAddParser.current
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isCardOpen) private var isCardOpen
    @Environment(\.cardGridScroll) private var gridScroll

    private var hasText: Bool { !newTitle.trimmingCharacters(in: .whitespaces).isEmpty }

    /// Says what Return will add when it isn't a plain one-time task ("Add repeating goal"):
    /// a type or mode picked in the options stays picked for the card's next task.
    private var addPlaceholder: String {
        let kind = switch newType {
        case .checkbox: "task"
        case .goal: "goal"
        case .list: "list"
        }
        let mode: String? = switch newMode {
        case .oneTime: nil
        case .carryOver: "carry-over"
        case .repeating: "repeating"
        }
        if Theme.isRetro(theme) {
            return "new_" + (mode.map { $0.replacingOccurrences(of: "-", with: "_") + "_" } ?? "") + kind + ">"
        }
        return addPlaceholderSpoken.capitalized  // "Add Task", "Add Repeating Goal"
    }

    /// The placeholder in words, for VoiceOver (also in Retro).
    private var addPlaceholderSpoken: String {
        let kind = switch newType {
        case .checkbox: "task"
        case .goal: "goal"
        case .list: "list"
        }
        let mode: String? = switch newMode {
        case .oneTime: nil
        case .carryOver: "carry-over"
        case .repeating: "repeating"
        }
        return "Add " + (mode.map { $0 + " " } ?? "") + kind
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if isEditing {
                Color.clear.frame(height: 0)
            } else {
                // Above the row, under the task it describes. (Below, it read as describing
                // the empty field.)
                if let result = smartAddResult {
                    smartAddMessage(result)
                        // (Never faded with VoiceOver: see the timer.)
                        .opacity(result.isFaded ? 0 : 1)
                        .disabled(result.isFaded)
                        .transition(.opacity)
                }
                addRow
                    .id(rowID)
                    // The keyboard's Done adds a typed task rather than leaving it in the field.
                    .onChange(of: store.keyboardDoneRequests) {
                        if isFocused { addTask(keepTyping: false) }
                    }
                    // Closing the options with nothing typed, and no keyboard, closes the field.
                    .onChange(of: showOptions) { _, shown in
                        if !shown { closeFieldIfIdle() }
                    }
            }
        }
        .sensoryFeedback(.success, trigger: smartAddCount)
        // Editing starts: what's typed is added as it is (a sub-task's is too), as when the
        // keyboard goes. A Smart Add still working adds its own task when it's done.
        .onChange(of: isEditing) { _, editing in
            guard editing else { return }
            showOptions = false
            if !isParsing, newTitle.trimmingCharacters(in: .whitespaces).count > 1 {
                addTask(keepTyping: false)
            }
            isFocused = false
            isFieldOpen = false
        }
        .task(id: smartAddResult?.token) {
            // With VoiceOver it stays (until the next task is added), so Undo can be reached.
            // So it does with demo data, for the App Store screenshot.
            guard smartAddResult != nil, !voiceOverEnabled, !Self.keepsSmartAddMessage else { return }
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            withAnimation(.snappy(duration: 0.25)) {
                // Taking its place away would move the field up under the next task being
                // typed: it fades and its place goes with the keyboard or the next add.
                if isFocused { smartAddResult?.isFaded = true } else { smartAddResult = nil }
            }
        }
        .onChange(of: isFocused) { _, focused in
            guard !focused, smartAddResult?.isFaded == true else { return }
            withAnimation(.snappy(duration: 0.25)) { smartAddResult = nil }
        }
        .onChange(of: smartAddOutcome) { _, outcome in
            guard let outcome else { return }
            smartAddOutcome = nil
            finishSmartAdd(outcome)
        }
    }

    /// The field shows once + is tapped, and stays while there's something in it, Smart Add
    /// is working on it, or its options are open.
    private var showsField: Bool {
        isFieldOpen || !newTitle.isEmpty || isParsing || showOptions || isOpeningOptions
    }

    /// The +: larger and alone until it's tapped, then small beside the field it opened.
    /// One image throughout, scaled, so it shrinks smoothly as the field opens; the button
    /// over it is there only while the field is closed, so VoiceOver hears "Add task" then
    /// and the field itself after. (Not accessibilityHidden, which an open card undoes, nor
    /// accessibilityRepresentation, whose stand-in reported the wrong place to tap.)
    private var plusButton: some View {
        PlusOpener(icon: plusIcon, isOpen: showsField, scale: Self.closedPlusScale, theme: theme, rc: rc,
                   label: "Add task", hint: "Opens a field to type a new task", action: openField)
    }

    private var plusIcon: some View {
        Image(systemName: Theme.isRetro(theme) ? "greaterthan" : "plus.circle")
            .font(.expandedCard(.subheadline))
    }

    /// About .title2 over .subheadline.
    private static let closedPlusScale: CGFloat = 1.45

    /// + opens the field quickly from where it is, then gives it the keyboard, so typing can
    /// start within about half a second. The keyboard waits for the field: bringing it up
    /// holds the main thread for a moment, and an opening that overlapped it froze, then
    /// jumped to its end.
    private func openField() {
        guard !reduceMotion else {
            isFieldOpen = true
            // Next turn of the run loop: the field exists by then.
            DispatchQueue.main.async { isFocused = true }
            return
        }
        withAnimation(.easeOut(duration: 0.2)) {
            isFieldOpen = true
        } completion: {
            isFocused = true
        }
    }

    /// Back to the + when the field is empty and has let go of the keyboard.
    private func closeFieldIfIdle() {
        guard isFieldOpen, !isFocused, !showOptions, !isOpeningOptions, !isParsing,
              newTitle.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        withAnimation(reduceMotion ? nil : .easeIn(duration: 0.2)) { isFieldOpen = false }
    }

    private var addRow: some View {
        // Wider than other rows: the field's fill reaches past its text (see cardField).
        HStack(spacing: 14) {
            plusButton
            if showsField {
                // Multi-line, so Return types a line break instead of ending editing: ending and
                // re-focusing dropped the keyboard and brought it back (the bottom bar flashed
                // between them). The line break adds the task; see `submitTyped`.
                TextField(addPlaceholder, text: $newTitle, axis: .vertical)
                    .lineLimit(1...4)
                    .accessibilityIdentifier("Add task")
                    .accessibilityLabel(addPlaceholderSpoken)
                    .font(.expandedCard(.subheadline, design: Theme.isRetro(theme) ? .monospaced : .default))
                    .cardField(theme, rc: rc, outset: true)
                    // Opens from the + outward.
                    .transition(reduceMotion ? .identity : .revealFromLeading)
                    .focused($isFocused)
                    .submitLabel(.next)
                    .onChange(of: newTitle) { _, text in submitTyped(text) }
                    .onChange(of: isFocused) { _, focused in
                        if focused {
                            parser.prepare()
                        } else if !showOptions, !isOpeningOptions, newTitle.trimmingCharacters(in: .whitespaces).count > 1 {
                            // However the keyboard went away (swiped down, another field
                            // tapped), what was typed is added, like a renamed task's name.
                            // (A single stray letter isn't.)
                            addTask(keepTyping: false)
                        }
                        if !focused { closeFieldIfIdle() }
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
                        Button {
                            // On iPad the keyboard closes first: with it up, the picker opened
                            // above the row and partly off the screen. It opens once the
                            // keyboard is down (opening as it went cancelled it).
                            if horizontalSizeClass == .regular && isFocused {
                                isOpeningOptions = true
                                isFocused = false
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                    showOptions = true
                                    isOpeningOptions = false
                                }
                            } else {
                                showOptions = true
                            }
                        } label: {
                            TaskOptionsLabel(type: newType, mode: newMode, theme: theme, rc: rc)
                                .contentShape(Rectangle())
                                .touchTarget()
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("New task options: \(newType.label), \(newMode.label)")
                        .accessibilityRemoveTraits(.isSelected)
                        .popover(isPresented: $showOptions) {
                            TaskOptionsPicker(
                                type: newType, mode: newMode, theme: theme, rc: rc,
                                onSelectType: { newType = $0; pickedType = true },
                                onSelectMode: { newMode = $0; pickedMode = true },
                                onAdd: newTitle.trimmingCharacters(in: .whitespaces).isEmpty ? nil : {
                                    showOptions = false
                                    addTask(keepTyping: true)
                                },
                                onDone: { showOptions = false },
                                isThisWeekOnlyCategory: store.selectedWeek?.categories.first { $0.id == categoryID }?.isThisWeekOnly == true
                            )
                        }
                    }
                }
                .transition(.opacity)
            } else {
                // Holds the open row's height, so opening it moves nothing below, with the
                // field's words where they'll be ("Add Task").
                Text(" ")
                    .font(.expandedCard(.subheadline))
                    .cardField(theme, rc: rc, outset: true)
                    .frame(maxWidth: .infinity)
                    .hidden()
                    .overlay(alignment: .leading) {
                        PlusRowLabel(text: addPlaceholder,
                                     font: .expandedCard(.subheadline, design: Theme.isRetro(theme) ? .monospaced : .default),
                                     theme: theme, rc: rc, action: openField)
                    }
            }
        }
    }

    /// "✨ Added Gym · repeating goal of 3   Undo": what Smart Add worked out, so a wrong
    /// guess is seen and can be taken back (the task is removed; see `undoSmartAdd`).
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
            // Said after the summary when only the plain rules applied.
            var rulesOnlyNote = ""
            do {
                if let result = try await parser.parse(text) {
                    parsed = result
                } else {
                    parsed = TaskTextHints.refine(ParsedTask(title: text), from: text)
                    rulesOnlyNote = " · without Apple Intelligence"
                }
            } catch {
                // Apple Intelligence is on but turned these words down (or failed), or they
                // hold no real word for it to read.
                if (error as? TaskTextParserError) != .noRealWords { Self.log.error("Smart Add couldn't parse: \(error)") }
                parsed = TaskTextHints.refine(ParsedTask(title: text), from: text)
                rulesOnlyNote = " · set up from your words"
            }
            // Added from `onChange`, during SwiftUI's own update like a tap, not from this
            // task: changing the store here (inside withAnimation) made SwiftUI first redraw
            // pending views from the week as it was before the change, and a screen redrawn
            // that way missed the change, so the card showed no task under "Added …".
            smartAddOutcome = SmartAddOutcome(parsed: parsed, text: text, note: rulesOnlyNote, weekStart: weekStart)
        }
    }

    /// Adds what Smart Add worked out (see `smartAdd`). Still parsing until now, so the
    /// words can't also be added as typed meanwhile.
    private func finishSmartAdd(_ outcome: SmartAddOutcome) {
        var parsed = outcome.parsed
        if pickedMode { parsed.mode = newMode }
        if pickedType && parsed.type != newType {
            parsed.type = newType
            parsed.items = []
            parsed.goalTarget = nil
            parsed.goalStep = nil
            parsed.goalDays = nil
        }
        // A goal without an amount takes the keyboard for its target; a list without
        // items, for its first item.
        let awaitsTarget = (parsed.type == .goal && parsed.goalTarget == nil) || (parsed.type == .list && parsed.items.isEmpty)
        let summary = Self.describe(parsed, separator: " · ") + outcome.note
        // One animation for the spinner going, the new row, the message under it and the
        // row's highlight, so the Add task field moves down once. (The spinner going on its
        // own shrank the row for a frame first.)
        var added: UUID?
        withAnimation(.snappy(duration: 0.2)) {
            isParsing = false
            added = store.addParsedTask(parsed, categoryID: categoryID, weekStart: outcome.weekStart)
            guard let added else { return }
            // A goal it couldn't find an amount for takes the keyboard for its target.
            if awaitsTarget { store.taskAwaitingFirstInput = added }
            smartAddResult = SmartAddResult(taskID: added, text: outcome.text, summary: summary)
            if isCardOpen && !reduceMotion { store.highlightedTaskID = added }
            // Anything typed meanwhile stays.
            if newTitle.trimmingCharacters(in: .whitespaces) == outcome.text { newTitle = "" }
        }
        // Smart Add may have finished after the keyboard went (Done while it worked).
        closeFieldIfIdle()
        guard added != nil else { return }
        if !awaitsTarget { keepFieldInView() }
        smartAddCount += 1
        pickedType = false
        pickedMode = false
        AccessibilityNotification.Announcement("Added \(Self.describe(parsed)). Undo is above.").post()
    }

    /// "Run, repeating goal of 3" (VoiceOver), or with " · " for the message above the row.
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

    /// Return in the field (a line break): what's before it is added and the keyboard stays
    /// for the next task; Return in an empty field closes the keyboard. Pasted lines each
    /// become a task. While Smart Add is still working, nothing is added and the words stay.
    private func submitTyped(_ text: String) {
        guard let lineBreak = text.firstIndex(where: \.isNewline) else { return }
        let line = String(text[..<lineBreak])
        let rest = String(text[text.index(after: lineBreak)...])
        guard !line.trimmingCharacters(in: .whitespaces).isEmpty else {
            newTitle = rest
            if rest.isEmpty { isFocused = false }
            return
        }
        // One change to the field's text, so keys typed right after Return aren't lost.
        newTitle = addTask(line, keepTyping: true) ? rest : line + rest
    }

    /// Adds exactly what was typed, with the type and mode last picked (Smart Add is the
    /// only thing that reads the words). Return keeps the keyboard up for the next task;
    /// a new list or goal takes the keyboard for its first item or target instead.
    /// `typed`: a line already taken out of the field (Return), instead of the field's text.
    /// Returns whether a task was added.
    @discardableResult
    private func addTask(_ typed: String? = nil, keepTyping: Bool) -> Bool {
        let title = (typed ?? newTitle).trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty, !isParsing else { return false }
        let task = ParsedTask(title: title, type: newType, mode: newMode)
        let awaitsInput = task.type != .checkbox
        withAnimation(.snappy(duration: 0.2)) {
            let id = store.addParsedTask(task, categoryID: categoryID)
            if keepTyping && awaitsInput { store.taskAwaitingFirstInput = id }
            // A Smart Add message would now sit under this task instead of its own.
            if id != nil { smartAddResult = nil }
        }
        if typed == nil { newTitle = "" }
        pickedType = false
        pickedMode = false
        if keepTyping && !awaitsInput {
            isFocused = true
            keepFieldInView()
        }
        return true
    }

    private var rowID: String { "add-task-\(categoryID)" }

    /// A task was just added above the field: if it still has the keyboard, the whole row
    /// scrolls into view, as little as it takes. (iOS keeps only the caret in view, which
    /// after a tall task, such as a goal, left the field half under the keyboard.)
    private func keepFieldInView() {
        guard let gridScroll else { return }
        // Once the new row is laid out.
        DispatchQueue.main.async {
            guard isFocused else { return }
            withAnimation(.snappy(duration: 0.25)) { gridScroll.scrollTo(rowID) }
        }
    }
}
