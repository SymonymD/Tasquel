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

    /// Like `expandedCard`, but stops growing at 1.6× its default size, as the controls'
    /// frames do (`expandedCardControl`): for row icons and the type/mode button, so they
    /// don't crowd out the name at the largest text sizes. (These fonts read the app's
    /// text size, so a `.dynamicTypeSize` cap around them has no effect.)
    static func expandedCardControl(_ style: UIFont.TextStyle) -> Font {
        let standard = UIFont.preferredFont(forTextStyle: style, compatibleWith: UITraitCollection(preferredContentSizeCategory: .large)).pointSize
        let size = UIFont.preferredFont(forTextStyle: style, compatibleWith: TextSizeSetting.shared.traits).pointSize
        return .system(size: min(size, standard * 1.6) * expandedCardScale)
    }

    static func expandedCardControl(size: CGFloat) -> Font {
        .system(size: min(expandedCardScaled(size), size * expandedCardScale * 1.6))
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

/// Draws a task's name with its day label (the text marked `Pulses`) faded by `strength`:
/// animated back and forth, the label pulses on its day without the name being laid out
/// again. Everything else is drawn as it is.
struct DayPulseRenderer: TextRenderer, Animatable {
    /// Marks the day label's text; `isOn` on the task's day.
    struct Pulses: TextAttribute {
        let isOn: Bool
    }

    var strength: Double
    var animatableData: Double {
        get { strength }
        set { strength = newValue }
    }

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        for line in layout {
            for run in line {
                if run[Pulses.self]?.isOn == true {
                    var faded = context
                    faded.opacity = 1 - 0.65 * strength
                    faded.draw(run)
                } else {
                    context.draw(run)
                }
            }
        }
    }
}

/// An expiring task's checkbox: a gray ring, thicker than a plain outline, with the share
/// of its days gone by drawn over it in green, like a card's ring.
struct ExpiryCheckRing: View {
    let progress: Double
    let color: Color
    let track: Color

    var body: some View {
        GeometryReader { proxy in
            let lineWidth = max(2, proxy.size.width * 0.16)
            ZStack {
                Circle().stroke(track.opacity(0.45), lineWidth: lineWidth)
                Circle()
                    .trim(from: 0, to: min(max(progress, 0), 1))
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .padding(lineWidth / 2)
        }
    }
}

extension Text {
    /// "⧉ Duplicate" after a task's or item's name whose name another one in its card (or
    /// list) has; Retro "[DUP]". Caption-sized, in orange that keeps 4:1, never struck through.
    static func duplicateMark(_ theme: AppearanceMode) -> Text {
        let retro = Theme.isRetro(theme)
        let mark = retro ? Text(verbatim: "[DUP]") : Text("\(Image(systemName: "square.on.square"))\u{00A0}Duplicate")
        return mark
            .font(.expandedCard(.caption1, design: retro ? .monospaced : .default))
            .foregroundStyle(Theme.duplicate(theme))
    }

    /// How wide the mark is (it doesn't break), for a row deciding where its icons go.
    static func duplicateMarkWidth(retro: Bool) -> CGFloat {
        let size = UIFont.preferredFont(forTextStyle: .caption1, compatibleWith: TextSizeSetting.shared.traits).pointSize * expandedCardScale
        let font = retro ? UIFont.monospacedSystemFont(ofSize: size, weight: .regular) : UIFont.systemFont(ofSize: size)
        let word = ((retro ? "[DUP]" : "Duplicate") as NSString).size(withAttributes: [.font: font]).width
        return (word + (retro ? 0 : size * 1.6)).rounded(.up) + 2  // and the icon
    }
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
    /// Another task in its card has the same name: its name is marked Duplicate.
    var isDuplicate = false
    /// Moving the task by its handle (edit mode): how far the finger has gone up or down the
    /// screen from where it touched the handle and where it is now (window coordinates), and
    /// the handle let go. The card lifts, moves and drops the row (`TaskReorder`).
    var onHandleDrag: ((_ translation: CGFloat, _ fingerY: CGFloat) -> Void)? = nil
    var onHandleRelease: (() -> Void)? = nil

    private var theme: AppearanceMode { store.appearanceMode }
    private var rc: RetroColor { store.retroColor }

    @State private var isEditingTitle = false
    @State private var editedTitle = ""
    @FocusState private var isTitleFocused: Bool
    @State private var newSubtaskTitle = ""
    @FocusState private var isSubtaskFieldFocused: Bool
    /// An item or sub-task just added with the same name as another of this task's: a note
    /// above the field says so for a few seconds, with Undo.
    @State private var duplicateNote: DuplicateItemNote?
    /// The clock's calendar (the card's edit mode), for the task's expiration.
    @State private var showExpiry = false
    /// The options (or the date's calendar), opened from the marks after the name.
    @State private var showMarkOptions = false
    @Environment(\.freezesTaskOrder) private var freezesTaskOrder
    /// The clock, pin, trash and handle are in the row: from the card's edit mode starting
    /// until they've gathered back onto the handle after it ends (`rowIcons`).
    @State private var showsEditIcons = false
    /// The day label's pulse (0…1, animated back and forth) while it's the task's day.
    @State private var dayPulse = 0.0
    /// Which of them (clock 0 … handle 3) are out in their places; the others are stacked on
    /// the handle, hidden.
    @State private var spreadEditIcons: Set<Int> = []
    @State private var goalKindSelection: GoalUnitKind = .quantity
    @State private var goalTargetInput = GoalAmountInput()
    @State private var goalUnitText = ""
    /// The goal editor's Step; empty means automatic.
    @State private var goalStepInput = GoalAmountInput()
    /// The goal editor's Days, a 5 | 7 toggle (`goalDays`, nil saved as 7): the days a week
    /// the goal is spread over. With Step on Auto, + adds the target ÷ the days; a typed Step
    /// makes the target Step × Days.
    @State private var goalDaysSelection = 7
    @State private var isEditingGoal = false
    @FocusState private var focusedGoalField: GoalFocus?
    @State private var showOptions = false
    /// A finger is on the reorder handle.
    @GestureState private var isHoldingHandle = false
    /// The row's width, its checkbox's (or goal ring's) and its icons', for `stacksIcons`.
    @State private var rowWidth: CGFloat = 0
    @State private var leadingWidth: CGFloat = 0
    @State private var iconsWidth: CGFloat = 0
    /// The day and date marks' width: they sit beside the whole name, not in its last line.
    @State private var markWidth: CGFloat = 0
    /// The goal editor's width and its unit menu's, for `unitNameFitsBesideTarget`.
    @State private var goalFormWidth: CGFloat = 0
    @State private var unitMenuWidth: CGFloat = 0

    /// A custom unit's name fits on the Target row: the label, the unit menu, the number
    /// and the name's least width, 8pt apart. Fixed widths only, so typing a longer name
    /// never moves the field (and its keyboard) to another row.
    private var unitNameFitsBesideTarget: Bool {
        if dynamicTypeSize.isAccessibilitySize || goalFormWidth == 0 { return true }
        let needed = 64 * expandedCardScale + 8 + unitMenuWidth + 8 + 90 * expandedCardScale + 8 + 64 * expandedCardScale
        return needed <= goalFormWidth
    }
    /// Smart Add just added this task: lit like a drop target for a moment.
    private var isHighlighted: Bool { store.highlightedTaskID == task.id }
    /// The add-sub-task (or a list's add-item) field is open.
    @State private var isAddingSubtask = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isCardOpen) private var isCardOpen
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.cardGridScroll) private var gridScroll
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.cardWeekStart) private var weekStart
    /// A list with its items folded away. Past weeks show everything: they're view only,
    /// and a folded list there couldn't be opened to see what was in it.
    private var isFolded: Bool { task.isFolded && !isPastWeek }

    /// The goal text fields, for moving the keyboard between them.
    nonisolated private enum GoalField: Hashable { case target, step, unitName }
    nonisolated private enum GoalFieldPart: Hashable { case number, hours, minutes }
    nonisolated private struct GoalFocus: Hashable {
        let field: GoalField
        let part: GoalFieldPart
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // The name, and its icons beside it or on their own line under it (`stacksIcons`).
            // One layout that switches, so the icons stay the same views either way: rebuilt
            // under the name as edit mode started, they skipped their transitions and just
            // appeared.
            nameAndIconsLayout {
                HStack(spacing: 10) {
                    // Completion indicator
                    Group {
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
                                        if !task.isCompleted, let progress = task.expiryProgress(on: store.currentDay) {
                                            // An expiring task's outline is a ring, like a card's: gray, filling
                                            // green as its days go by (the day it was set is day 1).
                                            ExpiryCheckRing(progress: progress, color: Theme.expirySet(theme, rc: rc),
                                                            track: Theme.textSecondary(theme, rc: rc))
                                                .frame(width: expandedCardControl(18), height: expandedCardControl(18))
                                        } else {
                                            Circle()
                                                .fill(task.isCompleted ? Theme.dotComplete(theme, rc: rc) : Color.clear)
                                                .overlay(Circle().stroke(task.isCompleted ? Theme.dotComplete(theme, rc: rc) : Theme.textSecondary(theme, rc: rc), lineWidth: 1.5))
                                                .frame(width: expandedCardControl(18), height: expandedCardControl(18))
                                        }
                                    }
                                }
                                .modifier(PastWeekDimming(isPastWeek: isPastWeek, theme: theme))
                                .touchTarget()
                            }
                            .buttonStyle(CheckboxButtonStyle())
                            .disabled(isPastWeek)
                            .accessibilityLabel(TaskAccessibility.checkboxLabel(task.title, isCompleted: task.isCompleted))
                            .accessibilityValue(expiryDescription)
                            .accessibilityAddTraits(task.isCompleted ? .isSelected : [])
                            .accessibilityActions { moveActions }
                        }
                    }
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { leadingWidth = $0 }

                    // Title
                    if isEditingTitle {
                        // Wraps like the name it replaces, so every part of a long name can be
                        // reached (on one line the start scrolled out of view). Return saves.
                        TextField("Task name", text: $editedTitle, axis: .vertical)
                            .lineLimit(1...8)
                            .fixedSize(horizontal: false, vertical: true)
                            // (A wrapping field is a text view: it doesn't take its name from the title.)
                            .accessibilityIdentifier("Task name")
                            .accessibilityLabel("Task name")
                            // Growing a line can take it under the keyboard: it scrolls back.
                            .id(renameFieldID)
                            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { _ in keepRenameFieldInView() }
                            .font(Theme.isRetro(theme) ? .expandedCard(size: 16, design: .monospaced) : .expandedCard(size: 16))
                            .cardField(theme, rc: rc, outset: true)
                            .focused($isTitleFocused)
                            // The keyboard opens with the field, so one tap is enough.
                            .onAppear { isTitleFocused = true }
                            // Escape (a hardware keyboard) puts the old name back.
                            .onReceive(NotificationCenter.default.publisher(for: EscapeKey.pressed)) { _ in
                                if isTitleFocused { isEditingTitle = false }
                            }
                            // Rotating, or another keyboard, can leave it under the keyboard.
                            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidChangeFrameNotification)) { _ in
                                keepRenameFieldInView()
                            }
                            .onSubmit { commitTitle(returnPressed: true) }
                            .onChange(of: editedTitle) { old, text in
                                if let name = RenameField.submitted(text, was: old) { editedTitle = name; commitTitle(returnPressed: true) }
                            }
                            // Closing the keyboard (Done, or scrolling) also saves the name.
                            .onChange(of: isTitleFocused) { _, focused in
                                if !focused && isEditingTitle { commitTitle() }
                            }
                    } else {
                        // One tap renames. The whole width up to the icons is the target, not just
                        // the letters; the day and date marks after the name are their own button.
                        HStack(alignment: .lastTextBaseline, spacing: 8) {
                            titleText
                                .font(Theme.isRetro(theme) ? .expandedCard(size: 16, design: .monospaced) : .expandedCard(size: 16))
                                // All the lines it needs: beside the icons, a row could otherwise get
                                // one line's height and cut the title off ("Plan Mom's birt…").
                                .fixedSize(horizontal: false, vertical: true)
                                // The name stays the label (Voice Control's "tap Groceries"); a folded
                                // list's count is the value, so VoiceOver hears both.
                                .accessibilityLabel(task.title)
                                .accessibilityValue(titleValue)
                                .modifier(RenamableName(isRenamable: !isPastWeek, hint: "Renames the task", rename: startEditingTitle))
                            if let markText { markButton(markText) }
                        }
                        // Fades only the day's letters on its day (`DayPulseRenderer`).
                        .onChange(of: isDueToday, initial: true) { _, due in pulseDay(due) }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture { startEditingTitle() }
                    }

                    if isEditingTitle { Spacer(minLength: 0) }
                }

                if !isPastWeek { rowIcons }
            }
            .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: stacksIcons)

            if task.taskType == .goal {
                goalProgressSection
            } else if !isFolded {
                // Checkbox: sub-tasks. List: its items, unless folded away.
                let duplicates = task.duplicateSubtaskIDs
                ForEach(task.subtasks) { subtask in
                    SubTaskRowCard(
                        subtask: subtask,
                        categoryID: categoryID,
                        taskID: task.id,
                        store: store,
                        isEditing: isEditing,
                        isPastWeek: isPastWeek,
                        isListItem: task.taskType == .list,
                        isDuplicate: duplicates.contains(subtask.id)
                    )
                }
                if let note = duplicateNote, !isPastWeek, !isEditing {
                    duplicateItemMessage(note)
                        .opacity(note.isFaded ? 0 : 1)
                        .disabled(note.isFaded)
                        .transition(.opacity)
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
        // The full row, whichever way its icons go (the name fills what they leave).
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { rowWidth = $0 }
        // The card keeps its order while this task's options or calendar are open.
        .onChange(of: showOptions || showMarkOptions || showExpiry) { _, open in freezesTaskOrder(open) }
        // Gone with its options open (a date moved it to another week): the card's order is
        // let go, as closing them would.
        .onDisappear { if showOptions || showMarkOptions || showExpiry { freezesTaskOrder(false) } }
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
        // A field in a closed card never keeps the keyboard (its + may finish opening it
        // after the card closed).
        .onChange(of: isSubtaskFieldFocused) { _, focused in
            if focused && !isCardOpen { isSubtaskFieldFocused = false }
        }
        // The Duplicate note goes after 4 seconds (with VoiceOver it stays until the next
        // add, so Undo can be reached). While the field has the keyboard it fades but keeps
        // its place until the keyboard goes, so the field doesn't move up under the typing.
        .task(id: duplicateNote?.token) {
            guard duplicateNote != nil, !voiceOverEnabled else { return }
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            withAnimation(.snappy(duration: 0.25)) {
                if isSubtaskFieldFocused { duplicateNote?.isFaded = true } else { duplicateNote = nil }
            }
        }
        .onChange(of: isSubtaskFieldFocused) { _, focused in
            guard !focused, duplicateNote?.isFaded == true else { return }
            withAnimation(.snappy(duration: 0.25)) { duplicateNote = nil }
        }
        // Its item was deleted or renamed: the note goes too.
        .onChange(of: duplicateNoteIsStale) { _, stale in
            if stale { withAnimation(.snappy(duration: 0.25)) { duplicateNote = nil } }
        }
        .background {
            if isHighlighted {
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
           let tasks = store.selectedWeek?.categories.first(where: { $0.id == categoryID })?.reorderGroup(for: task.id),
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
        Button { Self.afterEndingTyping { showOptions = true } } label: {
            TaskOptionsLabel(type: task.taskType, mode: task.mode, theme: theme, rc: rc)
                .frame(minHeight: expandedCardControl(36))
                .contentShape(Rectangle())
                .touchTarget()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Task options: \(task.taskType.label), \(task.mode.label)")
        .accessibilityRemoveTraits(.isSelected)  // the checkbox type's checkmark icon isn't a state
        .popover(isPresented: $showOptions) {
            taskOptionsPicker(onDone: { showOptions = false })
        }
    }

    /// The task's type, mode, day and date: from its options button, or from the mark after
    /// its name (`startsOnDate` for a date's calendar, which then closes it all).
    private func taskOptionsPicker(startsOnDate: Bool = false, onDone: @escaping () -> Void) -> TaskOptionsPicker {
            TaskOptionsPicker(
                type: task.taskType, mode: task.mode, theme: theme, rc: rc,
                confirmsLeavingGoal: task.goalTarget != nil || task.goalProgress != nil,
                onSelectType: { type in
                    withAnimation(.snappy(duration: 0.2)) {
                        store.updateTaskType(categoryID: categoryID, taskID: task.id, type: type)
                    }
                },
                onSelectMode: { store.updateTaskMode(categoryID: categoryID, taskID: task.id, mode: $0) },
                onDone: onDone,
                isThisWeekOnlyCategory: store.selectedWeek?.categories.first { $0.id == categoryID }?.isThisWeekOnly == true,
                day: task.dayOfWeek,
                onSelectDay: { day in
                    withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) {
                        store.setTaskDay(categoryID: categoryID, taskID: task.id, day: day)
                    }
                },
                firstWeekday: store.firstWeekday,
                date: task.expiresOn, dateIsWeek: task.expiresWithWeek,
                earliestDate: store.earliestExpiry, today: store.currentDay, taskTitle: task.title,
                weekStart: store.selectedWeek?.startDay,
                onSelectDate: { day, week in
                    // The first date asks whether Tasquel may remind (never at launch).
                    if day != nil && store.remindsBeforeExpiry { ExpiryNotifications.shared.requestPermissionIfNeeded() }
                    withAnimation(reduceMotion ? nil : .snappy(duration: 0.2)) {
                        store.setTaskDate(categoryID: categoryID, taskID: task.id, lastDay: day, wholeWeek: week)
                    }
                },
                startsOnDate: startsOnDate,
                onDateDone: startsOnDate ? onDone : nil
            )
    }

    /// Any typing ends first, so a name being edited in another row saves and the keyboard
    /// closes (it stayed up, that row's field still editable, under a popover opened from
    /// here; the user, 2026-11-14), and so does what's typed in Add task, as whenever the
    /// keyboard closes. Then `open` runs once the keyboard is down: a popover opened as the
    /// keyboard went was cancelled, and on iPad one opened with it up went off the screen.
    static func afterEndingTyping(_ open: @escaping () -> Void) {
        if UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { open() }
        } else {
            open()
        }
    }

    /// The day and date marks after the name: a button that opens what they show, the date's
    /// calendar or the options with the Day row (the user kept tapping them, 2026-11-14).
    /// Plain in a past week and in the card's edit mode.
    @ViewBuilder
    private func markButton(_ mark: Text) -> some View {
        let shown = mark
            .font(Theme.isRetro(theme) ? .expandedCard(size: 16, design: .monospaced) : .expandedCard(size: 16))
            .textRenderer(DayPulseRenderer(strength: dayPulse))
            .fixedSize()
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { markWidth = $0 }
        if isPastWeek || showsEditIcons {
            shown.accessibilityHidden(true)
        } else {
            let dated = task.expiresOn != nil
            Button { Self.afterEndingTyping { showMarkOptions = true } } label: {
                shown.contentShape(Rectangle()).touchTarget()
            }
            .buttonStyle(.plain)
            .accessibilityLabel(dated ? "Change date of \(task.title)" : "Change day of \(task.title)")
            .popover(isPresented: $showMarkOptions) {
                taskOptionsPicker(startsOnDate: dated, onDone: { showMarkOptions = false })
            }
        }
    }

    /// The day and date marks, if any (see `dayMark`, `dateMark`).
    private var markText: Text? {
        // Not in the card's edit mode: the name has the row (the clock shows a date there),
        // where the marks pushed the edit icons onto a line of their own (2026-11-15).
        guard !showsEditIcons else { return nil }
        return switch (dayMark, dateMark) {
        case let (day?, date?): Text("\(day)  \(date)")
        case let (day?, nil): day
        case let (nil, date?): date
        case (nil, nil): nil
        }
    }

    /// The row's icons: add sub-task (checkbox tasks) or fold (lists), type and mode, and in
    /// the card's edit mode the clock (instead of type and mode), pin, delete and the
    /// reorder handle.
    private var rowIcons: some View {
        HStack(spacing: 0) {
            if task.taskType == .checkbox && !showsEditIcons { addSubtaskButton.transition(outsideEditIconTransition) }
            if task.taskType == .list { foldButton }
            // In the card's edit mode the clock (the task's expiration) takes the type and
            // mode's place; those change outside it.
            if !showsEditIcons { taskOptionsButton.transition(outsideEditIconTransition) }
            if showsEditIcons {
                HStack(spacing: 0) {
                    editIcon(0, expiryButton)
                    editIcon(1, pinButton)
                    editIcon(2, deleteButton)
                    editIcon(3, reorderHandle)
                }
                // Added stacked and hidden: they run out to their places.
                .onAppear { runOutEditIcons() }
                .onDisappear { spreadEditIcons = [] }
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { iconsWidth = $0 }
        .onChange(of: isEditing, initial: true) { _, editing in
            if editing {
                // Back into edit mode while they were gathering: out they go again.
                if showsEditIcons { runOutEditIcons() } else { showsEditIcons = true }
            } else if showsEditIcons {
                // They gather back onto the handle and go; then type and mode grow back.
                withAnimation(iconsGather) { spreadEditIcons = [] } completion: {
                    if !isEditing { showsEditIcons = false }
                }
            }
        }
    }

    /// As the card's edit mode starts, type and mode (and a checkbox's +) shrink away first;
    /// meanwhile the clock, pin, trash and handle are added stacked on the handle and hidden,
    /// and once type and mode are gone they run out to their places (`iconRunOut`). Leaving
    /// edit mode they gather back onto the handle and fade (`iconsGather`), and only then go,
    /// with type and mode growing back. Reduce Motion: they fade. (Moved by state, not by a
    /// transition: an offset transition here only faded, the icons appearing in their places.)
    private static let iconSwapOut = 0.14

    /// Once type and mode are gone, each on a quick spring with two bounces (0.5: 0.25 was
    /// too little, 0.4 bounced once, 0.55 on shorter periods was jittery), so it runs past its place and settles back, as if they ran in and skidded to a stop (the
    /// user's words): the clock first, the one with the farthest to go, then the pin and the
    /// trash 0.04s apart, each a little quicker, and the handle last. (All together on one
    /// curve looked mechanical; a 0.25s ease-out was too even; a curve with nearly all its
    /// movement in the first 50ms looked like no animation.)
    private func iconRunOut(_ index: Int) -> Animation {
        guard !reduceMotion else { return .easeInOut(duration: 0.2) }
        // A bouncier spring settles later, so the periods are shorter: each still settles when
        // it did at bounce 0.4 with 0.27…0.2s (about 0.64 × period ÷ (1 − bounce)).
        let periods = [0.23, 0.21, 0.19, 0.17]
        return .spring(duration: periods[index], bounce: 0.5).delay(Self.iconSwapOut + 0.02 + Double(index) * 0.04)
    }

    private func runOutEditIcons() {
        for index in 0..<4 {
            withAnimation(iconRunOut(index)) { _ = spreadEditIcons.insert(index) }
        }
    }

    /// The `index`th edit icon (clock 0 … handle 3): stacked on the handle and hidden until
    /// it has run out to its place.
    private func editIcon(_ index: Int, _ icon: some View) -> some View {
        icon
            .offset(x: stackedOffset(index))
            .opacity(spreadEditIcons.contains(index) ? 1 : 0)
    }

    private var iconsGather: Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .easeIn(duration: Self.iconSwapOut)
    }

    private var outsideEditIconTransition: AnyTransition {
        guard !reduceMotion else { return .opacity.animation(.easeInOut(duration: 0.2)) }
        let shrunk = AnyTransition.scale(scale: 0.01).combined(with: .opacity)
        return .asymmetric(insertion: shrunk.animation(.easeOut(duration: 0.2)),
                           removal: shrunk.animation(.easeIn(duration: Self.iconSwapOut)))
    }

    /// How far the `index`th edit icon (clock 0 … handle 3) is from its place while they're
    /// stacked on the handle.
    private func stackedOffset(_ index: Int) -> CGFloat {
        guard !spreadEditIcons.contains(index), !reduceMotion else { return 0 }
        return CGFloat(3 - index) * expandedCardControl(36) * (layoutDirection == .rightToLeft ? -1 : 1)
    }

    /// Where beside the icons the name's widest word wouldn't fit (and at accessibility text
    /// sizes) they get their own line under it, at its trailing end, which keeps the name the
    /// whole width: beside them it had a column too narrow for one word ("Gr / oc / eri / es").
    private var nameAndIconsLayout: AnyLayout {
        stacksIcons ? AnyLayout(VStackLayout(alignment: .trailing, spacing: 6)) : AnyLayout(HStackLayout(spacing: 10))
    }

    /// The row's icons get their own line under the name (`rowIcons`) where beside it they'd
    /// leave it too little room: at accessibility text sizes, and wherever the name's widest
    /// word wouldn't fit beside them, so a name never breaks mid-word. (In the card's edit
    /// mode a list has five icons, with the pin: "Grocerie / s" at the default size; at XXXL
    /// with four it had a 48pt column, "Gro / ceri / es".) The widths it compares don't
    /// depend on where the icons go, so it can't flip back and forth.
    private var stacksIcons: Bool {
        if dynamicTypeSize.isAccessibilitySize { return true }
        guard rowWidth > 0, iconsWidth > 0 else { return false }
        let besideIcons = rowWidth - leadingWidth - 10 - 10 - iconsWidth  // the row's two gaps
        // The day and date marks sit beside the name (8pt apart), so every line of the name
        // has that much less room: counted as one more word, "Send invoice" next to
        // "Fri · late" and edit mode's four icons broke as "invoic / e" (2026-11-14).
        let besideMark = besideIcons - (markText == nil ? 0 : markWidth + 8)
        let widest = max(TaskRowCard.widestWord(of: titleWords, retro: Theme.isRetro(theme)),
                         showsDuplicate ? Text.duplicateMarkWidth(retro: Theme.isRetro(theme)) : 0)
        return besideMark < widest
    }

    /// The name's pieces that can't break: its words, and a folded list's count ("2 of 5").
    private var titleWords: [String] {
        var words = task.title.split(whereSeparator: { $0.isWhitespace && $0 != "\u{00A0}" }).map(String.init)
        if isFolded, !task.subtasks.isEmpty {
            words.append("\(task.subtasks.filter(\.isCompleted).count)\u{00A0}of\u{00A0}\(task.subtasks.count)")
        }
        return words
    }

    /// How wide the widest of `words` is in a task name's font, plus a little for rounding.
    static func widestWord(of words: [String], retro: Bool) -> CGFloat {
        let size = expandedCardScaled(16)
        let font = retro ? UIFont.monospacedSystemFont(ofSize: size, weight: .regular) : UIFont.systemFont(ofSize: size)
        let widest = words.map { ($0 as NSString).size(withAttributes: [.font: font]).width }.max() ?? 0
        return widest.rounded(.up) + 2
    }

    /// The task's name; done tasks are struck through, like done sub-tasks. A folded list
    /// adds how many of its items are checked ("Groceries  2 of 5"), in the same text, so
    /// the count wraps with the name instead of taking width from it.
    private var titleText: Text {
        var text = Text(task.title)
            .foregroundStyle(task.isCompleted ? Theme.textSecondary(theme, rc: rc) : Theme.textPrimary(theme, rc: rc))
            .strikethrough(task.isCompleted && !Theme.isRetro(theme), color: Theme.textSecondary(theme, rc: rc))
        if isFolded, !task.subtasks.isEmpty {
            // Non-breaking spaces: "2 of 5" wraps as one piece.
            let count = Text("\(task.subtasks.filter(\.isCompleted).count)\u{00A0}of\u{00A0}\(task.subtasks.count)")
                .font(.expandedCard(.caption1, design: Theme.isRetro(theme) ? .monospaced : .default))
                .monospacedDigit()
                .foregroundStyle(Theme.textSecondary(theme, rc: rc))
            text = Text("\(text)  \(count)")
        }
        if showsDuplicate { text = Text("\(text)  \(Text.duplicateMark(theme))") }
        if showsPinMark {
            // A pinned task says so outside edit mode too; it only sat at the top, which
            // two testers took for nothing having happened (2026-11-14).
            let pin = Theme.isRetro(theme) ? Text(verbatim: "[PIN]") : Text(Image(systemName: "pin.fill"))
            text = Text("\(text)  \(pin.font(.expandedCard(.caption1, design: Theme.isRetro(theme) ? .monospaced : .default)).foregroundStyle(Theme.pinned(theme, rc: rc)))")
        }
        return text
    }

    /// Edit mode's own pin button shows it there.
    private var showsPinMark: Bool { task.isPinned && !showsEditIcons }

    /// Today is its day (only in the current week): its label says Today.
    private var isTaskDay: Bool {
        guard let weekStart, !isPastWeek else { return false }
        return task.day(inWeekStarting: weekStart, firstWeekday: store.firstWeekday) == store.currentDay
    }

    /// Today is its day and it isn't done: the label is green and pulses.
    private var isDueToday: Bool { isTaskDay && !task.isCompleted }

    /// On its day the day label pulses, gently and slowly, until it's done or the day is
    /// over (the user asked, 2026-11-12). Reduce Motion: it doesn't; nor in UI tests and demo
    /// data, where an animation that never ends keeps XCUITest waiting for the app to settle.
    private func pulseDay(_ due: Bool) {
        if due && !reduceMotion && !ChecklistStore.launchesWithThrowawayData {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { dayPulse = 1 }
        } else {
            var still = Transaction()
            still.disablesAnimations = true
            withTransaction(still) { dayPulse = 0 }
        }
    }

    /// Its day's gone by and it isn't done (only in the current week).
    private var isLate: Bool {
        guard let weekStart, !isPastWeek else { return false }
        return task.isLate(inWeekStarting: weekStart, firstWeekday: store.firstWeekday, today: store.currentDay)
    }

    /// "Thu" after the name, for a task with a day; on its day "Today", green and pulsing
    /// until it's done (the user's choice, 2026-11-12); "Tue · late" in orange once that day
    /// has gone by unfinished. Caption-sized, never struck through.
    private var dayMark: Text? {
        guard let day = task.dayOfWeek else { return nil }
        let retro = Theme.isRetro(theme)
        let name = isTaskDay ? "Today" : Weekday.name(day)
        let shown = retro ? name.uppercased() : name
        let color = isLate ? Theme.late(theme) : isDueToday ? Theme.expirySet(theme, rc: rc) : Theme.textSecondary(theme, rc: rc)
        let label = Text(verbatim: isLate ? (retro ? "[\(shown) LATE]" : "\(shown)\u{00A0}·\u{00A0}late") : (retro ? "[\(shown)]" : shown))
        // A calendar for a repeating task's day, a timer for this week's or until done (as
        // closed cards' marks); none with a date, whose calendar follows.
        let icon = task.expiresOn != nil ? nil : Text(Image(systemName: task.mode == .repeating ? "calendar" : "timer"))
        return (icon.map { Text("\($0)\u{00A0}\(label)") } ?? label)
            .font(.expandedCard(.caption1, weight: isDueToday ? .semibold : .regular, design: retro ? .monospaced : .default))
            .foregroundStyle(color)
            .customAttribute(DayPulseRenderer.Pulses(isOn: isDueToday))
    }

    /// A task with a date (its last day): a small calendar after its name, green until it's
    /// done (the user asked, 2026-11-14). The checkbox's ring and VoiceOver say how long.
    private var dateMark: Text? {
        guard let lastDay = task.expiresOn else { return nil }
        // The date itself too ("Nov 28"): an icon alone left new users unsure what the date
        // was, or that there was one (four of six testers, 2026-11-14).
        let shown = lastDay.date(in: store.calendar).formatted(.dateTime.month(.abbreviated).day())
        let retro = Theme.isRetro(theme)
        return Text("\(Image(systemName: "calendar"))\u{00A0}\(retro ? shown.uppercased() : shown)")
            .font(.expandedCard(.caption1, weight: .semibold, design: retro ? .monospaced : .default))
            .foregroundStyle(task.isCompleted ? Theme.textSecondary(theme, rc: rc) : Theme.expirySet(theme, rc: rc))
    }

    /// Past weeks are view only: nothing there can be fixed, so nothing is marked.
    private var showsDuplicate: Bool { isDuplicate && !isPastWeek }

    /// What VoiceOver hears after the name: a folded list's count, and "duplicate".
    private var titleValue: String {
        let day = task.dayOfWeek.map { isTaskDay ? "today" : Weekday.name($0, short: false) + (isLate ? ", late" : "") } ?? ""
        return [day, foldedCountDescription, showsDuplicate ? "duplicate" : "", showsPinMark ? "pinned" : ""]
            .filter { !$0.isEmpty }.joined(separator: ", ")
    }

    /// A folded list's count in words ("2 of 5 items checked"); empty otherwise.
    private var foldedCountDescription: String {
        guard isFolded, !task.subtasks.isEmpty else { return "" }
        let total = task.subtasks.count
        return "\(task.subtasks.filter(\.isCompleted).count) of \(total) \(total == 1 ? "item" : "items") checked"
    }

    /// A list's chevron, just before its type and mode: pointing down while the items show,
    /// forward while they're folded away (`chevron.forward` turns with the reading direction).
    private var foldButton: some View {
        Button(action: toggleFold) {
            rowIcon(task.isListFolded ? "chevron.forward" : "chevron.down", color: Theme.textSecondary(theme, rc: rc))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(task.isListFolded ? "Expand list" : "Collapse list")
        .accessibilityValue(task.title)
        .accessibilityIdentifier("Fold \(task.title)")
    }

    /// Folding takes the Add Item field with the items: what was typed is added first (as
    /// when the card's edit mode starts), and an item being renamed saves as its row goes.
    private func toggleFold() {
        let folding = !task.isListFolded
        if folding {
            addSubtask(keepTyping: false)
            isAddingSubtask = false
        }
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) {
            store.setListFolded(categoryID: categoryID, taskID: task.id, folded: folding)
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
            // Not if the card closed meanwhile: a hidden field never takes the keyboard.
            if isCardOpen { isSubtaskFieldFocused = true }
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

    /// In edit mode: touch and drag to move the task within its card. It lifts at the
    /// touch and follows the finger (the card moves it; see `TaskReorder`). Not the system's
    /// drag and drop: its task lifted only after a hold, showed only a small copy under the
    /// finger, and a sideways wobble meanwhile swiped the week.
    private var reorderHandle: some View {
        rowIcon("line.3.horizontal", color: Theme.textTertiary(theme, rc: rc))
            .gesture(
                // On the screen: the handle's own space moves with the lifted row, and the
                // task list's with the grid as it scrolls (the card adds that in).
                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                    .updating($isHoldingHandle) { _, holding, _ in holding = true }
                    .onChanged { onHandleDrag?($0.translation.height, $0.location.y) }
                    // Where the finger let go, which the last change may not have reached.
                    .onEnded {
                        onHandleDrag?($0.translation.height, $0.location.y)
                        onHandleRelease?()
                    }
            )
            // Cancelled (the system took the touch): the task still lands where it is.
            .onChange(of: isHoldingHandle) { _, holding in
                if !holding { onHandleRelease?() }
            }
            .hiddenFromVoiceOver()  // VoiceOver uses Move Up / Move Down on the task
    }

    /// In the card's edit mode: the task's expiration. Gray without one, green with one; it
    /// opens a small calendar to pick a date or a week, or to remove it.
    private var expiryButton: some View {
        let hasExpiry = task.expiresOn != nil
        return Button { Self.afterEndingTyping { showExpiry = true } } label: {
            rowIcon(hasExpiry ? "clock.fill" : "clock",
                    color: hasExpiry ? Theme.expirySet(theme, rc: rc) : Theme.textSecondary(theme, rc: rc))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(hasExpiry ? "Change expiration of \(task.title)" : "Set expiration for \(task.title)")
        .accessibilityValue(expiryDescription)
        .accessibilityIdentifier("Expiration \(task.title)")
        .popover(isPresented: $showExpiry) {
            ExpiryPicker(
                taskTitle: task.title, current: task.expiresOn, currentIsWeek: task.expiresWithWeek,
                earliest: store.earliestExpiry, today: store.currentDay,
                firstWeekday: store.weekStartsOnSunday ? 1 : 2, theme: theme, rc: rc,
                onSet: { day, week in
                    showExpiry = false
                    // The first expiration asks whether Tasquel may remind (never at launch).
                    if store.remindsBeforeExpiry { ExpiryNotifications.shared.requestPermissionIfNeeded() }
                    withAnimation(.snappy(duration: 0.2)) {
                        store.setTaskDate(categoryID: categoryID, taskID: task.id, lastDay: day, wholeWeek: week)
                    }
                },
                onRemove: {
                    showExpiry = false
                    withAnimation(.snappy(duration: 0.2)) {
                        store.setTaskExpiry(categoryID: categoryID, taskID: task.id, lastDay: nil)
                    }
                },
                onCancel: { showExpiry = false },
                noteFor: { day in
                    TaskOptionsPicker.thisWeekOnlyNote(
                        for: day, weekStart: store.selectedWeek?.startDay,
                        isThisWeekOnly: store.selectedWeek?.categories.first { $0.id == categoryID }?.isThisWeekOnly == true)
                        ?? TaskOptionsPicker.datesWeekNote(for: day, weekStart: store.selectedWeek?.startDay, mode: task.mode)
                }
            )
        }
    }

    /// "expires today", "expires tomorrow", "expires in 3 days, on Thursday, December 25";
    /// empty without an expiration.
    private var expiryDescription: String {
        guard let end = task.expiresOn else { return "" }
        let days = store.currentDay.days(to: end)
        let date = end.date(in: Calendar.weekDates()).formatted(.dateTime.weekday(.wide).month(.wide).day())
        switch days {
        case ..<1: return "expires today"
        case 1: return "expires tomorrow"
        default: return "expires in \(days) days, on \(date)"
        }
    }

    /// In the card's edit mode: pins the task to the top of the card, or unpins it. With two
    /// pinned, the other tasks' pins are dimmed.
    private var pinButton: some View {
        let canPin = task.isPinned
            || (store.selectedWeek?.categories.first { $0.id == categoryID }?.pinnedTaskCount ?? 0) < Category.maxPins
        return Button {
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) {
                store.setTaskPinned(categoryID: categoryID, taskID: task.id, pinned: !task.isPinned)
            }
        } label: {
            rowIcon(task.isPinned ? "pin.fill" : "pin",
                    color: task.isPinned ? Theme.pinned(theme, rc: rc) : Theme.textSecondary(theme, rc: rc))
                .opacity(canPin ? 1 : 0.35)
        }
        .buttonStyle(.plain)
        .disabled(!canPin)
        .accessibilityLabel(task.isPinned ? "Unpin \(task.title)" : "Pin \(task.title) to the top")
        .accessibilityHint(canPin ? "" : "Two tasks are pinned. Unpin one to pin this one.")
        .accessibilityIdentifier("Pin \(task.title)")
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
            .font(.expandedCardControl(size: rowIconSize))
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
        // Starts on the goal's own unit (Smart Add may know it's time or pages without an
        // amount), unless something's typed already.
        .onAppear {
            guard goalTargetInput.isEmpty else { return }
            goalKindSelection = task.goalKind
            goalUnitText = task.goalUnit ?? ""
        }
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
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { unitMenuWidth = $0 }
                // Typed by hand, the target leads: a typed Step goes back to Auto, a day's
                // share of it. (Only typing: a Unit switch converting it keeps the Step.)
                goalAmountFields(Binding(get: { goalTargetInput }, set: {
                                     goalTargetInput = $0
                                     if !goalStepInput.isEmpty { goalStepInput = GoalAmountInput() }
                                 }),
                                 kind: goalKindSelection, field: .target, placeholder: "Target")
                if goalKindSelection == .custom && unitNameFitsBesideTarget { unitNameField }
            }
            goalHint(goalTargetInput.problem(for: goalKindSelection))
            // Where it doesn't fit beside the target, the unit's name has a row of its own:
            // on a 402pt iPhone the Target row ran ~20pt past the card, cutting off the name
            // and Save Goal (2026-11-14).
            if goalKindSelection == .custom && !unitNameFitsBesideTarget {
                labeledGoalRow("Unit") { unitNameField }
            }
            // What + and − add or take away; empty (Auto) is the target ÷ the days.
            labeledGoalRow("Step") {
                goalAmountFields($goalStepInput, kind: goalKindSelection, field: .step, placeholder: "Auto")
            }
            goalHint(goalStepInput.problem(for: goalKindSelection))
            labeledGoalRow("Days") {
                Picker("Days", selection: $goalDaysSelection) {
                    ForEach(goalDayOptions, id: \.self) { days in
                        Text(verbatim: "\(days)").accessibilityLabel("\(days) days").tag(days)
                    }
                }
                .pickerStyle(.segmented)
                .fixedSize()
                .labelsHidden()
                .accessibilityHint("With a step, the target is the step times the days; without one, each step is the target divided by the days.")
            }
            // Kept clear of Step's box: the toggle took a tap just below it (meant for the
            // field, whose tap area reaches 6pt past the box).
            .padding(.top, 6)
            let days = goalDaysSelection, dayWord = goalDaysSelection == 1 ? "day" : "days"
            if goalStepInput.positiveValue(for: goalKindSelection) != nil {
                goalLinkHint("Step × \(days) \(dayWord) = Target")
            } else if goalStepInput.isEmpty, let target = goalTargetInput.positiveValue(for: goalKindSelection) {
                // What Auto means: a day's share of the target.
                let step = ChecklistTask.automaticStep(forTarget: target, days: days)
                goalLinkHint("Target ÷ \(days) \(dayWord) = \(goalKindSelection.format(step)) a step")
            }
            // Saving would make the goal met at once: said before, not found struck through
            // after ("Done, 8 of 7" when a tester set a step of 1, 2026-11-14).
            if let metBySaving = goalMetBySaving {
                Text(metBySaving)
                    .font(.expandedCard(.caption1, design: Theme.isRetro(theme) ? .monospaced : .default))
                    .foregroundStyle(Theme.late(theme))
            }
            ViewThatFits(in: .horizontal) {
                editGoalButtons(stacked: false)
                editGoalButtons(stacked: true)
            }
        }
        .font(.expandedCard(.body, design: Theme.isRetro(theme) ? .monospaced : .default))
        .frame(maxWidth: .infinity, alignment: .leading)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { goalFormWidth = $0 }
        .padding(.leading, 24 * expandedCardScale)
        .onChange(of: goalStepInput) { followStepTimesDays() }
        .onChange(of: goalDaysSelection) { followStepTimesDays() }
    }

    /// "Already 8 of 7: saving marks it done", when the target as edited is one the progress
    /// already meets but the saved target isn't.
    private var goalMetBySaving: String? {
        guard let progress = task.goalProgress, progress > 0,
              (task.goalUnitKind ?? .quantity) == goalKindSelection,
              let target = goalTargetInput.positiveValue(for: goalKindSelection), progress >= target,
              task.goalTarget.map({ progress < $0 }) ?? true else { return nil }
        return "Already \(goalKindSelection.format(progress)) of \(goalKindSelection.format(target)): saving marks it done"
    }

    /// How Target, Step and Days go together, under the fields.
    private func goalLinkHint(_ text: String) -> some View {
        Text(text)
            .font(.expandedCard(.caption1, design: Theme.isRetro(theme) ? .monospaced : .default))
            .foregroundStyle(Theme.textTertiary(theme, rc: rc))
    }

    /// 5 and 7, plus the goal's own days when Smart Add gave it others ("yoga 30 min on
    /// Mon, Wed, Fri" is 3), so opening the editor doesn't turn them into 7.
    private var goalDayOptions: [Int] {
        Set([5, 7] + [task.goalDays].compactMap { $0 }).sorted()
    }

    /// With a Step, the target is Step × Days.
    private func followStepTimesDays() {
        guard let target = GoalAmountInput.perDayTarget(step: goalStepInput, days: goalDaysSelection,
                                                        kind: goalKindSelection) else { return }
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
                    OptionButtonLabel(title: "Save Goal", symbol: "checkmark", color: Theme.dotComplete(theme, rc: rc), isHighlighted: true,
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
            .foregroundStyle(Theme.onAccent(theme))
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
        guard let typed = TypedLines(text) else { return }
        // Every finished line at once (pasted lines too): the field's change isn't reported
        // again for each line it's left with. One change to the field's text.
        let kept = typed.lines.filter { !addSubtask($0) }
        newSubtaskTitle = typed.leftover(keeping: kept)
        if typed.lines.isEmpty && typed.rest.isEmpty { isSubtaskFieldFocused = false }
    }

    /// `typed`: a line already taken out of the field (Return), instead of the field's text.
    /// Returns whether it was added. Refused (the week changed before the words landed:
    /// another iPad window, say), the words stay in the field.
    @discardableResult
    private func addSubtask(_ typed: String? = nil, keepTyping: Bool = true) -> Bool {
        let title = (typed ?? newSubtaskTitle).trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return false }
        var added = false
        withAnimation(.snappy(duration: 0.2)) {
            added = store.addSubtask(categoryID: categoryID, taskID: task.id, title: title)
            // Its name is already one of this task's: a note says so, with Undo.
            let saved = store.viewedTask(categoryID, task.id)
            if added, let new = saved?.subtasks.last, saved?.duplicateSubtaskIDs.contains(new.id) == true {
                duplicateNote = DuplicateItemNote(subtaskID: new.id, title: new.title)
            } else if added {
                duplicateNote = nil
            }
        }
        guard added else { return false }
        if let note = duplicateNote, note.subtaskID == store.viewedTask(categoryID, task.id)?.subtasks.last?.id {
            AccessibilityNotification.Announcement("\(note.title) is already in \(task.title). Undo is above.").post()
        }
        if typed == nil { newSubtaskTitle = "" }
        if keepTyping { isSubtaskFieldFocused = true }
        return true
    }

    private var duplicateNoteIsStale: Bool {
        guard let note = duplicateNote else { return false }
        return !task.duplicateSubtaskIDs.contains(note.subtaskID)
    }

    struct DuplicateItemNote: Equatable {
        let subtaskID: UUID
        let title: String
        /// Its time is up while the field has the keyboard: invisible but in its place, so the
        /// field being typed in doesn't move up.
        var isFaded = false
        let token = UUID()
    }

    /// "⧉ “Milk” is already in Groceries   Undo", above the Add Item field.
    private func duplicateItemMessage(_ note: DuplicateItemNote) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "square.on.square").foregroundStyle(Theme.duplicate(theme))
            Text("“\(note.title)” is already in \(task.title)")
                .foregroundStyle(Theme.textSecondary(theme, rc: rc))
                .lineLimit(2)
                // Both lines: beside the Undo it was laid out one line tall ("is already i…").
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            Button("Undo") {
                withAnimation(.snappy(duration: 0.2)) {
                    store.deleteSubtask(categoryID: categoryID, taskID: task.id, subtaskID: note.subtaskID, undoable: false)
                    duplicateNote = nil
                }
            }
            .buttonStyle(.plain)
            .fontWeight(.semibold)
            .foregroundStyle(Theme.accent(theme, rc: rc))
            .touchTarget()
            .accessibilityLabel("Undo adding \(note.title)")
        }
        .font(.expandedCard(.caption1, design: Theme.isRetro(theme) ? .monospaced : .default))
        .padding(.leading, 24 * expandedCardScale)
    }

    private var renameFieldID: String { "rename-\(task.id)" }

    /// A rename field that wraps onto another line while it has the keyboard is scrolled
    /// back into view, clear of the keyboard and its Done button, as Add task is after an
    /// add: iOS keeps only the caret in view, and the field grew down under the keyboard.
    private func keepRenameFieldInView() {
        guard isTitleFocused, let gridScroll else { return }
        DispatchQueue.main.async {
            withAnimation(.snappy(duration: 0.2)) { gridScroll.scrollTo(renameFieldID) }
        }
    }

    private func startEditingTitle() {
        guard !isPastWeek else { return }
        editedTitle = task.title
        isEditingTitle = true
    }

    /// Saves the typed name. Return (or Tab) in a field that was emptied deletes the task,
    /// with the usual Undo message; ending any other way (the keyboard's Done, a tap
    /// elsewhere) keeps the name it had.
    private func commitTitle(returnPressed: Bool = false) {
        let title = editedTitle.trimmingCharacters(in: .whitespaces)
        isEditingTitle = false
        if !title.isEmpty {
            store.renameTask(categoryID: categoryID, taskID: task.id, newTitle: title)
        } else if returnPressed {
            withAnimation(.snappy(duration: 0.2)) { store.deleteTask(categoryID: categoryID, taskID: task.id) }
        }
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
        goalDaysSelection = task.goalDays ?? 7
        isEditingGoal = true
    }

    private func closeGoalEditing() {
        isEditingGoal = false
        goalTargetInput = GoalAmountInput()
        goalStepInput = GoalAmountInput()
        goalDaysSelection = 7
        goalUnitText = ""
        focusedGoalField = nil
    }

    private var canSaveEditedGoal: Bool {
        goalTargetInput.positiveValue(for: goalKindSelection) != nil
            && (goalStepInput.isEmpty || goalStepInput.positiveValue(for: goalKindSelection) != nil)
    }

    private func saveEditedGoal() {
        guard let target = goalTargetInput.positiveValue(for: goalKindSelection) else { return }
        let oldKind = task.goalKind
        let wasMet = task.goalIsComplete
        store.setGoalTarget(categoryID: categoryID, taskID: task.id, target: target, kind: goalKindSelection, unit: goalUnitText)
        // A switch to or from Time carries the progress over like the target's amount
        // (2 → 2h), so 2 of 3 doesn't become 2 minutes. A goal that was met stays met: the
        // carried amounts are rounded (70 min is 1.17 hours, its step 0.17 × 7 days 1.19).
        if let progress = task.goalProgress, (oldKind == .time) != (goalKindSelection == .time),
           var carried = GoalAmountInput(progress, kind: oldKind).converted(from: oldKind, to: goalKindSelection).value(for: goalKindSelection) {
            if wasMet, let oldTarget = task.goalTarget, progress >= oldTarget - 1e-9 { carried = max(carried, target) }
            store.updateGoalProgress(categoryID: categoryID, taskID: task.id, progress: carried)
        }
        store.setGoalStep(categoryID: categoryID, taskID: task.id, step: goalStepInput.positiveValue(for: goalKindSelection),
                          days: goalDaysSelection)
        closeGoalEditing()
    }

    /// One step forward (+) or back (−); never below zero.
    private func addQuickProgress(sign: Double) {
        let wasComplete = task.goalIsComplete
        let progress = max(0, (task.goalProgress ?? 0) + sign * quickStep)
        withAnimation(.snappy(duration: 0.2)) {
            store.updateGoalProgress(categoryID: categoryID, taskID: task.id, progress: progress)
        }
        // The goal ticks itself off: say so.
        if !wasComplete, let target = task.goalTarget, progress >= target {
            AccessibilityNotification.Announcement("\(task.title): goal reached").post()
        }
    }

    /// The most common update, in one tap, and its undo: − takes a step back (also after
    /// the goal is reached, to take back the last tap), dimmed until there's progress; +
    /// stays after the target too, so a goal can be beaten. Both are always there, so
    /// neither moves under a finger: − used to come in with the first tap and push + over,
    /// and at −'s size now (56pt, so a tap meant for it doesn't land on +) a second tap where
    /// + had been would have taken the first back.
    private var goalSteps: some View {
        let hasProgress = (task.goalProgress ?? 0) > 0
        let canAdd = (task.goalProgress ?? 0) < GoalUnitKind.maxValue
        return HStack(spacing: Self.goalStepSpacing) {
            Button { addQuickProgress(sign: -1) } label: {
                stepTapArea(stepPill("−", filled: false), toward: [.leading])
            }
            .buttonStyle(.plain)
            .opacity(hasProgress ? 1 : 0.35)
            .disabled(!hasProgress)
            .accessibilityLabel(task.goalKind == .time ? "Remove \(Int(quickStep)) minutes" : "Remove \(task.goalKind.format(quickStep))")
            Button { addQuickProgress(sign: 1) } label: {
                stepTapArea(stepPill("+" + task.goalKind.format(quickStep), filled: true), toward: [.trailing])
            }
            .buttonStyle(.plain)
            // Hidden at the maximum but keeping its place.
            .opacity(canAdd ? 1 : 0)
            .disabled(!canAdd)
            .accessibilityHidden(!canAdd)
            .accessibilityLabel(task.goalKind == .time ? "Add \(Int(quickStep)) minutes" : "Add \(task.goalKind.format(quickStep))")
        }
    }

    /// The gap between − and +, and each one's least width: − twice its old 28pt, + as wide
    /// or wider for its label ("+999,999").
    private static let goalStepSpacing: CGFloat = 12
    private static let goalStepMinWidth: CGFloat = 56

    /// − outlined, + filled, at least `goalStepMinWidth` wide.
    private func stepPill(_ title: String, filled: Bool) -> some View {
        let accent = Theme.accent(theme, rc: rc)
        return Text(title)
            .font(.expandedCard(.caption1, weight: .bold, design: Theme.isRetro(theme) ? .monospaced : .default))
            // Never wraps ("+15 / m" in retro's wider monospaced font).
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 8).padding(.vertical, 5)
            .frame(minWidth: Self.goalStepMinWidth)
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

    /// One tap's worth of progress: the Step, or a day's share of the target (+10m toward
    /// 70 minutes, +14 toward 100 pages).
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
        case .target, .unitName, .step:
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
/// A name that one tap renames tells VoiceOver so: a hint, and Rename in its actions
/// (double-tapping already taps it). It stays text: a default action, or the button
/// trait, would make it a button, and the UI tests find names as text.
private struct RenamableName: ViewModifier {
    let isRenamable: Bool
    let hint: String
    let rename: () -> Void

    func body(content: Content) -> some View {
        if isRenamable {
            content
                .accessibilityHint(hint)
                .accessibilityAction(named: "Rename") { rename() }
        } else {
            content
        }
    }
}

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

// MARK: - Rename Fields

/// The rename fields wrap (`axis: .vertical`), so Return types a line break instead of
/// submitting: a line break means Return, and the name is saved without it.
enum RenameField {
    /// The name to save when `text` (the field's text; `old`, what it held just before)
    /// has a line break or a tab, which in a rename field mean Return (Tab on a hardware
    /// keyboard: done too). One typed wherever the cursor was saves the name without it, so
    /// a Return in the middle of a word adds no space. Pasted lines are joined with
    /// spaces. Nil while there's neither.
    static func submitted(_ text: String, was old: String) -> String? {
        let ends = { (character: Character) in character.isNewline || character == "\t" }
        guard text.contains(where: ends) else { return nil }
        if text.count == old.count + 1, let typed = text.firstIndex(where: ends) {
            var without = text
            without.remove(at: typed)
            if without == old { return old }
        }
        return text.split(whereSeparator: ends)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

/// What an add field (Add task, sub-task, item) holds once it has a line break: the
/// finished lines to add (blank ones dropped) and what's after the last break, still being
/// typed. Nil without a line break.
struct TypedLines: Equatable {
    let lines: [String]
    let rest: String

    init?(_ text: String) {
        guard text.contains(where: \.isNewline) else { return nil }
        var pieces = text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).map(String.init)
        rest = pieces.removeLast()
        lines = pieces.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    /// The field's new text: lines that couldn't be added (the week changed under them)
    /// stay, joined with spaces so they aren't tried again at once, before the rest.
    func leftover(keeping kept: [String]) -> String {
        (kept + [rest]).filter { !$0.isEmpty }.joined(separator: " ")
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
        return GoalAmountInput(GoalUnitKind.cleaned(min(value * Double(days), GoalUnitKind.maxValue)), kind: kind)
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
            // Whole minutes: hours switched over from a number ("1.17") don't leave 70.2.
            result = (h * 60 + m).rounded()
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
    /// Another of its task's items or sub-tasks has the same name: marked Duplicate.
    var isDuplicate = false

    private var theme: AppearanceMode { store.appearanceMode }
    private var rc: RetroColor { store.retroColor }

    @State private var isEditingTitle = false
    @State private var editedTitle = ""
    @FocusState private var isTitleFocused: Bool
    @Environment(\.cardGridScroll) private var gridScroll

    /// Full width, but no taller than a sub-task row, so a tap can't reach the next row's checkbox.
    private static let touchHeight: CGFloat = 32

    /// Saves the typed name; Return (or Tab) in a field that was emptied deletes the item,
    /// with the usual Undo message. Ending any other way keeps the name it had.
    private func commitTitle(returnPressed: Bool = false) {
        let title = editedTitle.trimmingCharacters(in: .whitespaces)
        isEditingTitle = false
        if !title.isEmpty {
            store.renameSubtask(categoryID: categoryID, taskID: taskID, subtaskID: subtask.id, newTitle: title)
        } else if returnPressed {
            withAnimation(.snappy(duration: 0.2)) {
                store.deleteSubtask(categoryID: categoryID, taskID: taskID, subtaskID: subtask.id)
            }
        }
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
                // Wraps, like a task's rename field, so all of a long name can be reached.
                TextField(isListItem ? "Item" : "Sub-task", text: $editedTitle, axis: .vertical)
                    .lineLimit(1...8)
                    // All its lines, like the name it replaces (one line tall, it showed only
                    // the end of a long name).
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(isListItem ? "Item" : "Sub-task")
                    .accessibilityLabel(isListItem ? "Item" : "Sub-task")
                    // Growing a line can take it under the keyboard: it scrolls back.
                    .id("rename-\(subtask.id)")
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { _ in
                        guard isTitleFocused, let gridScroll else { return }
                        DispatchQueue.main.async {
                            withAnimation(.snappy(duration: 0.2)) { gridScroll.scrollTo("rename-\(subtask.id)") }
                        }
                    }
                    .font(Theme.isRetro(theme) ? .expandedCard(size: 14, design: .monospaced) : .expandedCard(size: 14))
                    .cardField(theme, rc: rc, outset: true)
                    .focused($isTitleFocused)
                    .onAppear { isTitleFocused = true }
                    // Escape (a hardware keyboard) puts the old name back.
                    .onReceive(NotificationCenter.default.publisher(for: EscapeKey.pressed)) { _ in
                        if isTitleFocused { isEditingTitle = false }
                    }
                    // Rotating, or another keyboard, can leave it under the keyboard.
                    .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidChangeFrameNotification)) { _ in
                        guard isTitleFocused, let gridScroll else { return }
                        withAnimation(.snappy(duration: 0.2)) { gridScroll.scrollTo("rename-\(subtask.id)") }
                    }
                    .onSubmit { commitTitle(returnPressed: true) }
                    .onChange(of: editedTitle) { old, text in
                        if let name = RenameField.submitted(text, was: old) { editedTitle = name; commitTitle(returnPressed: true) }
                    }
                    // Closing the keyboard (Done, or scrolling) also saves the name.
                    .onChange(of: isTitleFocused) { _, focused in
                        if !focused && isEditingTitle { commitTitle() }
                    }
            } else {
                nameText
                    .font(Theme.isRetro(theme) ? .expandedCard(size: 14, design: .monospaced) : .expandedCard(size: 14))
                    // All the lines it needs, like a task's name: under a folded list a long
                    // item was laid out one line tall and cut off ("…passwor…").
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    // One tap renames, like a task's name.
                    .onTapGesture {
                        if !isPastWeek {
                            editedTitle = subtask.title
                            isEditingTitle = true
                        }
                    }
                    // The name stays the label (Voice Control's "tap Milk"); the mark is the value.
                    .accessibilityLabel(subtask.title)
                    .accessibilityValue(isDuplicate && !isPastWeek ? "duplicate" : "")
                    .modifier(RenamableName(isRenamable: !isPastWeek, hint: isListItem ? "Renames the item" : "Renames the sub-task") {
                        editedTitle = subtask.title
                        isEditingTitle = true
                    })
            }
        }
        .padding(.leading, 24 * expandedCardScale)
        .padding(.vertical, 4)
        // Leaving edit mode removes the field before it loses focus: save the name now.
        .onChange(of: isEditing) { _, editing in
            if !editing && isEditingTitle { commitTitle() }
        }
        // So does folding its list away: the row goes, field and all.
        .onDisappear {
            if isEditingTitle { commitTitle() }
        }
    }

    /// The name: done ones are struck through in the secondary color, like done tasks (the
    /// tertiary color was too faint to read); Retro's faint color reads fine. Then the
    /// Duplicate mark, if another item has its name (not in past weeks, which are view only).
    private var nameText: Text {
        let name = Text(subtask.title)
            .foregroundStyle(subtask.isCompleted && Theme.isRetro(theme) ? Theme.textTertiary(theme, rc: rc) : Theme.textSecondary(theme, rc: rc))
            .strikethrough(subtask.isCompleted && !Theme.isRetro(theme), color: Theme.textSecondary(theme, rc: rc))
        return isDuplicate && !isPastWeek ? Text("\(name)  \(Text.duplicateMark(theme))") : name
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
    /// A day picked in the picker for the card's new tasks (it stays picked, like type and
    /// mode); `didPickDay` once one (or Any) was. Until then they get the day picked in the
    /// day strip, if any.
    @State private var newDay: Int?
    @State private var didPickDay = false
    /// A date picked for the task being typed (its last day): for that task only.
    @State private var newDate: DayKey?
    @State private var newDateIsWeek = false
    @Environment(\.taskDayFilter) private var dayFilter
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
    /// What Smart Add just added, or that a task just added has the name of one already in
    /// the card: shown above the row (so right under the new task, which goes at the end)
    /// for a few seconds with Undo.
    /// Holds the card's order while the field is in use (`ExpandedCategoryContent.freezeOrder`).
    @Environment(\.freezesTaskOrder) private var freezesTaskOrder
    @State private var addNote: AddNote?
    /// What Smart Add worked out, waiting to be added (see `finishSmartAdd`).
    @State private var smartAddOutcome: SmartAddOutcome?
    #if DEBUG
    private static let keepsSmartAddMessage = ChecklistStore.launchesWithDemoData
    #else
    private static let keepsSmartAddMessage = false
    #endif

    private struct AddNote: Equatable {
        let taskID: UUID
        /// The words it was added from.
        let text: String
        /// "Added Gym · repeating goal of 3" (Smart Add), or "“Groceries” is already in this card".
        let message: String
        /// Smart Add's note (sparkles), else a duplicate's (⧉).
        var isSmartAdd = true
        /// The card was This week only before: a repeating or carry-over task turned that
        /// off, and Undo turns it back on.
        var wasThisWeekOnly = false
        /// Its time is up while the field has the keyboard: it's invisible but keeps its
        /// place, so the field being typed in doesn't move up (see `body`).
        var isFaded = false
        /// A date Smart Add found in the words ("Exam 12/15"), offered as the task's date:
        /// Set Date sets it and renames the task to `titleWithoutDate` ("Exam").
        var typedDate: TypedDate? = nil
        /// The week the task went into when it isn't the one viewed: a day that had gone by
        /// this week put it in next week (`ChecklistStore.placeParsedTask`).
        var nextWeek: DayKey? = nil
        /// Undo for a task added; none for one moved to its date's week (nothing to undo to).
        var canUndo = true
        let token = UUID()
    }

    private struct AddNoteTimer: Hashable {
        let token: UUID?
        let isEditing: Bool
    }

    private struct SmartAddOutcome: Equatable {
        let parsed: ParsedTask
        /// The words it was worked out from.
        let text: String
        /// Said after the summary when only the plain rules applied.
        let note: String
        /// The week it was typed in.
        let weekStart: DayKey?
        /// A written-out date in the words, kept out of what was worked out.
        var typedDate: TypedDate? = nil
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
            return "new_" + (mode.map { $0.replacingOccurrences(of: "-", with: "_") + "_" } ?? "") + kind
                + (addDay.map { (store.dayHasGoneBy($0) ? "_next_" : "_") + Weekday.name($0).lowercased() } ?? "") + ">"
        }
        // "Add Task", "Add Repeating Goal", "Add Task for Thu"; "Add Task for Next Thu" once
        // Thursday has gone by this week, since that's where it will go (`placeParsedTask`).
        return ("Add " + (mode.map { $0 + " " } ?? "") + kind).capitalized
            + (addDay.map { " for " + (store.dayHasGoneBy($0) ? "Next " : "") + Weekday.name($0) } ?? "")
    }

    /// The day the next task added gets: one picked in the picker, else the day strip's.
    private var addDay: Int? { didPickDay ? newDay : dayFilter }

    /// A date picked for the task being typed, and what it changes, shown in the picker as
    /// they'll be (`ChecklistTask.dateMode`, `dateWeekday`): a one-time task dated after this
    /// week carries over; a date in this week is its day.
    private func pickDate(_ day: DayKey?, wholeWeek: Bool) {
        newDate = day
        newDateIsWeek = day != nil && wholeWeek
        guard let day, let weekStart = store.selectedWeek?.startDay else { return }
        if store.remindsBeforeExpiry { ExpiryNotifications.shared.requestPermissionIfNeeded() }
        // Shown in the picker; adding applies the rule itself (`addParsedTask`), so it isn't
        // a picked mode: Smart Add keeps the mode it works out ("3x per week" repeats).
        // A one-time task stays one: dated after this week it goes into its date's week
        // (`placeParsedTask`); other modes don't change.
        if let weekday = ChecklistTask.dateWeekday(day, wholeWeek: wholeWeek, weekStart: weekStart, calendar: store.calendar) {
            newDay = weekday
            didPickDay = true
        } else if newMode != .repeating {
            // A later week's date is the task's day; none this week (as `setTaskDate`).
            newDay = nil
            didPickDay = false
        }
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
            + (addDay.map { " for " + (store.dayHasGoneBy($0) ? "next " : "") + Weekday.name($0, short: false) } ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if isEditing {
                Color.clear.frame(height: 0)
            } else {
                // Above the row, under the task it describes. (Below, it read as describing
                // the empty field.)
                if let result = addNote {
                    addNoteMessage(result)
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
        .task(id: AddNoteTimer(token: addNote?.token, isEditing: isEditing)) {
            // With VoiceOver it stays (until the next task is added), so Undo can be reached.
            // So it does with demo data, for the App Store screenshot. In the card's edit
            // mode it's hidden: its time starts when editing ends.
            guard addNote != nil, !isEditing, !voiceOverEnabled, !Self.keepsSmartAddMessage else { return }
            // One asking about a date stays until it's answered, the next task is added or
            // this one goes: two testers and the user missed Set Date before it faded
            // (2026-11-15; it had 10 seconds).
            guard addNote?.typedDate == nil else { return }
            // 8 seconds: at 4, Undo was gone before the user saw what Smart Add had made
            // (2026-11-15).
            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled else { return }
            withAnimation(.snappy(duration: 0.25)) {
                // Taking its place away would move the field up under the next task being
                // typed: it fades and its place goes with the keyboard or the next add.
                if isFocused { addNote?.isFaded = true } else { addNote = nil }
            }
        }
        // A field in a closed card never keeps the keyboard (the + opening it may finish
        // after the card closed).
        .onChange(of: isFocused) { _, focused in
            if focused && !isCardOpen { isFocused = false }
        }
        .onChange(of: isFocused) { _, focused in
            guard !focused, addNote?.isFaded == true else { return }
            withAnimation(.snappy(duration: 0.25)) { addNote = nil }
        }
        .onChange(of: smartAddOutcome) { _, outcome in
            guard let outcome else { return }
            smartAddOutcome = nil
            finishSmartAdd(outcome)
        }
        .onChange(of: handedOver?.token, initial: true) { showHandedOverNote() }
        // While typing, and while a new task's note shows, new tasks stay just above the
        // field, under which the note is; then they move into place.
        .onChange(of: holdsCardOrder) { _, hold in freezesTaskOrder(hold) }
        .onChange(of: noteTaskIsGone) { _, gone in
            if gone { withAnimation(.snappy(duration: 0.25)) { addNote = nil } }
        }
    }

    /// The task Smart Add's note is about was deleted (in the card's edit mode, say, where
    /// the note waits to show again): the note goes with it.
    private var noteTaskIsGone: Bool {
        guard let note = addNote else { return false }
        if let week = note.nextWeek { return !store.hasTask(note.taskID, inWeekStarting: week) }
        return store.viewedTask(categoryID, note.taskID) == nil
    }

    /// The field shows once + is tapped, and stays while there's something in it, Smart Add
    /// is working on it, or its options are open.
    private var showsField: Bool {
        isFieldOpen || !newTitle.trimmingCharacters(in: .whitespaces).isEmpty || isParsing || showOptions || isOpeningOptions
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
            // Not if the card closed meanwhile: a hidden field never takes the keyboard.
            if isCardOpen { isFocused = true }
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
                    // Rotating, or another keyboard, can leave it under the keyboard.
                    .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidChangeFrameNotification)) { _ in
                        keepFieldInView()
                    }
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
                                isThisWeekOnlyCategory: store.selectedWeek?.categories.first { $0.id == categoryID }?.isThisWeekOnly == true,
                                day: addDay,
                                onSelectDay: { newDay = $0; didPickDay = true },
                                firstWeekday: store.firstWeekday,
                                date: newDate, dateIsWeek: newDateIsWeek,
                                earliestDate: store.earliestExpiry, today: store.currentDay, taskTitle: newTitle,
                                weekStart: store.selectedWeek?.startDay,
                                onSelectDate: pickDate
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
    /// guess is seen and can be taken back (the task is removed; see `undoAdd`). Or
    /// "⧉ “Groceries” is already in this card   Undo", for a task added with a name the
    /// card already had.
    private func addNoteMessage(_ result: AddNote) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            addNoteLine(result)
            if let typedDate = result.typedDate { dateQuestion(typedDate, for: result) }
        }
        .font(.expandedCard(.caption1, design: Theme.isRetro(theme) ? .monospaced : .default))
        .padding(.leading, 24 * expandedCardScale)
    }

    /// "Until Mon, Dec 15?  [Set Date]": a date Smart Add found in the words, set only if
    /// asked. Setting it also takes it out of the name. The button sits right after the
    /// question, a pill, not at the right edge under Undo: the two were easy to mix up.
    private func dateQuestion(_ typedDate: TypedDate, for result: AddNote) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar")
                .foregroundStyle(Theme.expirySet(theme, rc: rc))
            Text("Until \(typedDate.day.date(in: Calendar.weekDates()).formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))?")
                .foregroundStyle(Theme.textSecondary(theme, rc: rc))
            Button { setTypedDate(typedDate, for: result) } label: {
                Text(Theme.isRetro(theme) ? "[SET_DATE]" : "Set Date")
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.accent(theme, rc: rc))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background {
                        if !Theme.isRetro(theme) { Capsule().fill(Theme.accent(theme, rc: rc).opacity(0.15)) }
                    }
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Set date to \(Self.spokenDate(typedDate.day))")
            Spacer(minLength: 0)
        }
    }

    private func setTypedDate(_ typedDate: TypedDate, for result: AddNote) {
        if store.remindsBeforeExpiry { ExpiryNotifications.shared.requestPermissionIfNeeded() }
        withAnimation(.snappy(duration: 0.2)) {
            // Renamed first: a one-time task then goes into its date's week (`setTaskDate`).
            store.renameTask(categoryID: categoryID, taskID: result.taskID, newTitle: typedDate.titleWithoutDate)
            // "By Dec 12", "due 12/12": a deadline, so it stays in front of you, carrying over
            // until then; "on Dec 14", or the date alone, is when to do it (2026-11-15).
            // The word is before the date, or in it: Foundation's detector reads "due 12/15"
            // or "until 12/15" as one phrase.
            let word = #"\b(by|due|until|till|before)(\s+on)?\s+"#
            let deadline = typedDate.phrase.range(of: "^" + word, options: [.regularExpression, .caseInsensitive]) != nil
                || result.text.range(of: word + NSRegularExpression.escapedPattern(for: typedDate.phrase),
                                     options: [.regularExpression, .caseInsensitive]) != nil
            if deadline, store.viewedTask(categoryID, result.taskID)?.mode == .oneTime {
                store.updateTaskMode(categoryID: categoryID, taskID: result.taskID, mode: .carryOver)
            }
            store.setTaskDate(categoryID: categoryID, taskID: result.taskID, lastDay: typedDate.day)
            addNote = nil
        }
    }

    /// "Monday, December 15".
    private static func spokenDate(_ day: DayKey) -> String {
        day.date(in: Calendar.weekDates()).formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    private func addNoteLine(_ result: AddNote) -> some View {
        HStack(spacing: 8) {
            Image(systemName: result.nextWeek != nil ? "calendar" : result.isSmartAdd ? "sparkles" : "square.on.square")
                .foregroundStyle(result.isSmartAdd || result.nextWeek != nil ? Theme.accent(theme, rc: rc) : Theme.duplicate(theme))
            Text(result.message)
                .foregroundStyle(Theme.textSecondary(theme, rc: rc))
                .lineLimit(2)
                // Both lines: beside the Undo it was laid out one line tall ("is already i…").
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            if result.canUndo {
                Button("Undo") { undoAdd(result) }
                    .buttonStyle(.plain)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.accent(theme, rc: rc))
                    .touchTarget()
                    .accessibilityLabel(result.isSmartAdd ? "Undo Smart Add" : "Undo adding \(result.text)")
            }
        }
    }

    /// Takes the task back entirely: no "Deleted … · Undo" of its own, and nothing left
    /// in the field to be added again when the keyboard closes.
    private func undoAdd(_ result: AddNote) {
        withAnimation(.snappy(duration: 0.2)) {
            if let week = result.nextWeek {
                store.removeAddedTask(result.taskID, inWeekStarting: week)
            } else {
                store.deleteTask(categoryID: categoryID, taskID: result.taskID, undoable: false)
            }
            if result.wasThisWeekOnly { store.setCategoryThisWeekOnly(categoryID, true) }
            addNote = nil
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
        // A written-out date ("Exam 12/15") is kept out of what's worked out, so its numbers
        // aren't a goal's; it's offered as the task's date once added (unless one was picked).
        let typedDate = newDate == nil
            ? TypedDate.find(in: text, earliest: store.earliestExpiry, today: store.currentDay, calendar: store.calendar)
            : nil
        let words = typedDate?.titleWithoutDate ?? text
        isParsing = true
        Task {
            var parsed: ParsedTask
            // Said after the summary when only the plain rules applied.
            var rulesOnlyNote = ""
            do {
                if let result = try await parser.parse(words) {
                    parsed = result
                } else {
                    parsed = TaskTextHints.refine(ParsedTask(title: words), from: words)
                    rulesOnlyNote = " · without Apple Intelligence"
                }
            } catch {
                // Apple Intelligence is on but turned these words down (or failed), or they
                // hold no real word for it to read.
                if (error as? TaskTextParserError) != .noRealWords { Self.log.error("Smart Add couldn't parse: \(error)") }
                parsed = TaskTextHints.refine(ParsedTask(title: words), from: words)
                rulesOnlyNote = " · set up from your words"
            }
            // Added from `onChange`, during SwiftUI's own update like a tap, not from this
            // task: changing the store here (inside withAnimation) made SwiftUI first redraw
            // pending views from the week as it was before the change, and a screen redrawn
            // that way missed the change, so the card showed no task under "Added …".
            smartAddOutcome = SmartAddOutcome(parsed: parsed, text: text, note: rulesOnlyNote, weekStart: weekStart,
                                              typedDate: typedDate)
        }
    }

    /// Adds what Smart Add worked out (see `smartAdd`). Still parsing until now, so the
    /// words can't also be added as typed meanwhile.
    private func finishSmartAdd(_ outcome: SmartAddOutcome) {
        var parsed = outcome.parsed
        if pickedMode {
            parsed.mode = newMode
            parsed.keepsMode = true
        }
        // A day picked in the picker wins; then the words' ("on Friday", "tomorrow"); then
        // the strip's. ("Tomorrow" needs today, so it's read here; not for a repeating task:
        // "run daily starting tomorrow" is every day.)
        if parsed.day == nil, parsed.mode != .repeating {
            parsed.day = TaskTextHints.relativeDay(outcome.text, today: store.currentDay, calendar: store.calendar)
        }
        if didPickDay { parsed.day = newDay } else if parsed.day == nil { parsed.day = dayFilter }
        if let newDate {
            parsed.lastDay = newDate
            parsed.lastDayIsWeek = newDateIsWeek
        }
        if pickedType && parsed.type != newType {
            parsed.type = newType
            parsed.items = []
            parsed.goalTarget = nil
            parsed.goalStep = nil
            parsed.goalDays = nil
            // The parse took its amount or items out of the title, for a type that wasn't
            // picked: "Call 3 clients today" as a checkbox is "Call 3 clients".
            let words = outcome.typedDate?.titleWithoutDate ?? outcome.text
            parsed.title = TaskTextHints.cleanTitle(words, fallback: words)
        }
        // List picked: words in parts are its name and items, whatever the model made
        // ("Go to the zoo and harass penguins" is "Go to the zoo", "harass penguins"), the sure
        // way to a list (2026-11-15: the model made one only sometimes). Not "Name: a, b",
        // which the rules already read.
        if pickedType, newType == .list {
            let words = outcome.typedDate?.titleWithoutDate ?? outcome.text
            let parts = TaskTextHints.clauses(words)
            if parts.count >= 2, !words.contains(":") {
                parsed.type = .list
                parsed.title = parts[0].prefix(1).uppercased() + parts[0].dropFirst()
                parsed.items = Array(parts.dropFirst())
            }
        }
        // A goal without an amount takes the keyboard for its target; a list without
        // items, for its first item.
        let awaitsTarget = (parsed.type == .goal && parsed.goalTarget == nil) || (parsed.type == .list && parsed.items.isEmpty)
        // Until Set Date, the name keeps the date as typed, so nothing typed is lost: the
        // words themselves when Smart Add kept the rest as typed, else its name and the date.
        let typedDate = outcome.typedDate.map {
            TypedDate(day: $0.day, phrase: $0.phrase, titleWithoutDate: parsed.title.isEmpty ? $0.titleWithoutDate : parsed.title)
        }
        if let found = outcome.typedDate {
            parsed.title = parsed.title == found.titleWithoutDate ? outcome.text : "\(parsed.title) \(found.phrase)"
        }
        let summary = Self.describe(parsed, separator: " · ") + outcome.note
        // One animation for the spinner going, the new row, the message under it and the
        // row's highlight, so the Add task field moves down once. (The spinner going on its
        // own shrank the row for a frame first.)
        var added: UUID?
        var nextWeek: DayKey?
        var isDuplicate = false
        let wasThisWeekOnly = store.selectedWeek?.categories.first { $0.id == categoryID }?.isThisWeekOnly == true
        withAnimation(.snappy(duration: 0.2)) {
            isParsing = false
            let placed = store.placeParsedTask(parsed, categoryID: categoryID, weekStart: outcome.weekStart)
            added = placed?.id
            guard let added else { return }
            // A day that had gone by this week put it in next week (`placeParsedTask`).
            nextWeek = placed.flatMap { $0.weekStart != store.selectedWeek?.startDay ? $0.weekStart : nil }
            // A goal it couldn't find an amount for takes the keyboard for its target.
            if awaitsTarget && nextWeek == nil { store.taskAwaitingFirstInput = added }
            isDuplicate = nextWeek == nil && isDuplicateInCard(added)
            if let nextWeek {
                // The screen goes there, and the note with it (`handOver`).
                addNote = nil
                let why = parsed.lastDay != nil ? "the week of its date"
                    : parsed.day.map { "as \(Weekday.name($0, short: false)) had gone by" } ?? "another week"
                handOver(added, to: nextWeek, text: outcome.text, message: "Added \(summary) · here, \(why)", isSmartAdd: true,
                         detail: Self.handOverDetail(lastDay: parsed.lastDay, day: parsed.day))
            } else {
                addNote = AddNote(taskID: added, text: outcome.text,
                                  message: "Added \(summary)" + (isDuplicate ? " · already in this card" : ""),
                                  wasThisWeekOnly: wasThisWeekOnly, typedDate: typedDate)
                if isCardOpen && !reduceMotion { store.highlightedTaskID = added }
            }
            // Anything typed meanwhile stays.
            if newTitle.trimmingCharacters(in: .whitespaces) == outcome.text { newTitle = "" }
        }
        // Smart Add may have finished after the keyboard went (Done while it worked).
        closeFieldIfIdle()
        guard added != nil else { return }
        if !awaitsTarget && nextWeek == nil { keepFieldInView() }
        smartAddCount += 1
        pickedType = false
        pickedMode = false
        newDate = nil
        newDateIsWeek = false
        let dateQuestion = typedDate.map { " Set its date to \(Self.spokenDate($0.day))? Set Date is above." } ?? ""
        let nextWeekSaid = nextWeek != nil ? ", in next week: its day has gone by this week" : ""
        AccessibilityNotification.Announcement("Added \(Self.describe(parsed))\(nextWeekSaid)\(isDuplicate ? ", already in this card" : ""). Undo is above.\(nextWeek == nil ? dateQuestion : "")").post()
    }

    /// "Thursday had already gone by, so “Call dentist” is here, in next week", said in next
    /// week's card, where the screen has gone with it.
    private static func nextWeekMessage(_ title: String, day: Int) -> String {
        "\(Weekday.name(day, short: false)) had already gone by, so “\(title)” is here, in next week"
    }

    /// "“Zoo trip” is here, in the week of its date, Mon, Dec 14", said in that week's card.
    private static func datesWeekMessage(_ title: String, lastDay: DayKey, calendar: Calendar) -> String {
        let shown = lastDay.date(in: calendar).formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        return "“\(title)” is here, in the week of its date, \(shown)"
    }

    /// A task that went into next week (its day had gone by): the screen goes there
    /// (`ContentView`), and this card there shows its note (`handedOver`), so the task is seen
    /// where it went instead of vanishing from this week (2026-11-15).
    private func handOver(_ taskID: UUID, to week: DayKey, text: String, message: String, isSmartAdd: Bool, detail: String) {
        guard let name = store.selectedWeek?.categories.first(where: { $0.id == categoryID })?.name else { return }
        store.addedElsewhere = .init(taskID: taskID, categoryName: name, weekStart: week, text: text,
                                     message: message, isSmartAdd: isSmartAdd, detail: detail)
    }

    /// Why a new task went into another week, for the pop-up as the screen follows it.
    private static func handOverDetail(lastDay: DayKey?, day: Int?) -> String {
        if lastDay != nil { return "A one-time task goes into the week of its date." }
        return day.map { "\(Weekday.name($0, short: false)) had already gone by this week." } ?? ""
    }

    private var holdsCardOrder: Bool { isFocused || isParsing || (addNote != nil && addNote?.nextWeek == nil) }

    /// The note handed over for this card, once its week is the one viewed.
    private var handedOver: ChecklistStore.AddedElsewhere? {
        guard let note = store.addedElsewhere, let week = store.selectedWeek, week.startDay == note.weekStart,
              week.categories.first(where: { $0.id == categoryID })?.name == note.categoryName else { return nil }
        return note
    }

    private func showHandedOverNote() {
        guard let note = handedOver else { return }
        store.addedElsewhere = nil
        withAnimation(.snappy(duration: 0.25)) {
            addNote = AddNote(taskID: note.taskID, text: note.text, message: note.message,
                              isSmartAdd: note.isSmartAdd, nextWeek: note.weekStart, canUndo: note.canUndo)
        }
        if !reduceMotion { store.highlightedTaskID = note.taskID }
        AccessibilityNotification.Announcement("\(note.message).\(note.canUndo ? " Undo is in the card." : "")").post()
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
        guard let typed = TypedLines(text) else { return }
        // Every finished line at once (pasted lines too). One change to the field's text, so
        // keys typed right after Return aren't lost.
        let kept = typed.lines.filter { !addTask($0, keepTyping: true) }
        newTitle = typed.leftover(keeping: kept)
        if typed.lines.isEmpty && typed.rest.isEmpty { isFocused = false }
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
        var task = ParsedTask(title: title, type: newType, mode: newMode)
        task.day = addDay
        task.lastDay = newDate
        task.lastDayIsWeek = newDateIsWeek
        task.keepsMode = pickedMode
        let awaitsInput = task.type != .checkbox
        let wasThisWeekOnly = store.selectedWeek?.categories.first { $0.id == categoryID }?.isThisWeekOnly == true
        var added: UUID?
        var nextWeek: DayKey?
        withAnimation(.snappy(duration: 0.2)) {
            let placed = store.placeParsedTask(task, categoryID: categoryID)
            added = placed?.id
            nextWeek = placed.flatMap { $0.weekStart != store.selectedWeek?.startDay ? $0.weekStart : nil }
            if keepTyping && awaitsInput && nextWeek == nil { store.taskAwaitingFirstInput = added }
            // A task with its name is already in the card: a note says so, with Undo. (Any
            // other note would now sit under this task instead of its own.) One that went
            // into next week says so instead.
            if let added {
                if let nextWeek {
                    // The screen goes there, and the note with it (`handOver`).
                    addNote = nil
                    let message = task.lastDay.map { Self.datesWeekMessage(title, lastDay: $0, calendar: store.calendar) }
                        ?? task.day.map { Self.nextWeekMessage(title, day: $0) } ?? "“\(title)” is here"
                    handOver(added, to: nextWeek, text: title, message: message, isSmartAdd: false,
                             detail: Self.handOverDetail(lastDay: task.lastDay, day: task.day))
                } else {
                    addNote = isDuplicateInCard(added)
                        ? AddNote(taskID: added, text: title, message: "“\(title)” is already in this card",
                                  isSmartAdd: false, wasThisWeekOnly: wasThisWeekOnly)
                        : nil
                }
            }
        }
        // Refused (the week changed before the words landed: another iPad window, say):
        // the words stay in the field.
        guard let added else { return false }
        if addNote?.taskID == added {
            AccessibilityNotification.Announcement("\(addNote?.message ?? title). Undo is above.").post()
        }
        if typed == nil { newTitle = "" }
        pickedType = false
        pickedMode = false
        newDate = nil
        newDateIsWeek = false
        // Not when it went into next week: the screen goes there, closing the keyboard.
        if keepTyping && !awaitsInput && nextWeek == nil {
            isFocused = true
            keepFieldInView()
        }
        return true
    }

    private var rowID: String { "add-task-\(categoryID)" }

    /// Another task in the card has the name of the task just added.
    private func isDuplicateInCard(_ taskID: UUID) -> Bool {
        store.selectedWeek?.categories.first { $0.id == categoryID }?.duplicateTaskIDs.contains(taskID) == true
    }

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
