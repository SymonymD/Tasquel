import SwiftUI

private extension View {
    func categoryDeletionConfirmation(
        isPresented: Binding<Bool>,
        category: Category,
        store: ChecklistStore
    ) -> some View {
        confirmationDialog("Delete \(category.name)?", isPresented: isPresented, titleVisibility: .visible) {
            Button("Delete Category", role: .destructive) {
                withAnimation { store.deleteCategory(category.id) }
            }
        } message: {
            Text(category.isThisWeekOnly
                 ? "This removes the category and its tasks from this week."
                 : "This removes the category and its tasks from this week and later weeks. Past weeks keep their history. You can add the category back from Add Category, but its tasks won't return.")
        }
    }
}

// MARK: - Category Grid Card

/// One card for a category, collapsed or expanded.
///
/// The header (icon, name, progress ring) and completion line are shared by both
/// states, so they move and resize with the card instead of being swapped out.
/// Only the content below them changes, and it cross-fades.
struct CategoryGridCard: View {
    let category: Category
    let store: ChecklistStore
    let isExpanded: Bool
    /// Global edit mode (bottom bar): category removal plus every card's tasks.
    let isEditing: Bool
    /// Whether this card's tasks are editable: global edit mode, or this card's own edit button.
    let isEditingTasks: Bool
    let isPastWeek: Bool
    let onToggleEdit: () -> Void
    let onExpand: () -> Void
    let onCollapse: () -> Void
    /// Called with the new name after a rename, so the grid can keep the card open.
    let onRenamed: (String) -> Void

    @State private var showDeleteConfirmation = false
    @State private var editedName = ""
    @State private var nameError: String?
    @FocusState private var isNameFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    // Collapsed → expanded sizes; scaled with Dynamic Type. Expanded sizes include
    // the 15% enlargement applied to everything inside an expanded card.
    @ScaledMetric(relativeTo: .subheadline) private var collapsedTitleSize: CGFloat = 15
    @ScaledMetric(relativeTo: .title3) private var expandedTitleSize: CGFloat = 20 * expandedCardScale
    @ScaledMetric(relativeTo: .body) private var collapsedPieSize: CGFloat = 17
    @ScaledMetric(relativeTo: .title3) private var expandedPieSize: CGFloat = 20 * expandedCardScale
    @ScaledMetric(relativeTo: .caption) private var collapsedCaptionSize: CGFloat = 12
    @ScaledMetric(relativeTo: .subheadline) private var expandedCaptionSize: CGFloat = 15 * expandedCardScale

    @Environment(\.cardGridWidth) private var gridWidth

    private var theme: AppearanceMode { store.appearanceMode }
    private var rc: RetroColor { store.retroColor }
    private var cornerRadius: CGFloat { Theme.cardCornerRadius(theme) }
    /// An open card's padding (everything in it is 15% larger), and its contents' width: an
    /// open card takes the grid's whole width.
    private static let openPadding = 14 * expandedCardScale
    private var openContentWidth: CGFloat? { gridWidth.map { max(0, $0 - 2 * Self.openPadding) } }
    private var design: Font.Design { Theme.isRetro(theme) ? .monospaced : .default }

    var body: some View {
        VStack(alignment: .leading, spacing: isExpanded ? 8 : 6) {
            header
            if isRenaming, let nameError {
                Text(nameError)
                    .font(.footnote)
                    .foregroundStyle(Theme.destructive(theme))
            }

            // At accessibility sizes the chip goes under the line: beside it, it ran off the
            // card and squeezed the line to nothing (the 2026-11-15 review).
            let chipUnder = isRenaming && dynamicTypeSize.isAccessibilitySize
            let completedLine = chipUnder ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
                : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
            completedLine {
                completionLine
                    .accessibilityLabel("\(category.completedCount) of \(category.totalCount) complete\(category.isThisWeekOnly ? ", just this week" : "")\(category.isPinned ? ", pinned" : "")")
                    .modifier(AnimatableFont(size: isExpanded ? expandedCaptionSize : collapsedCaptionSize, design: design))
                    .foregroundStyle(Theme.textSecondary(theme, rc: rc))
                    // Two lines at accessibility sizes in the card's edit mode, where "· Just this
                    // week" made it "Completed: 1/4 · J…".
                    .lineLimit(chipUnder ? 2 : 1)
                    .minimumScaleFactor(0.8)
                // In the card's own edit mode, up by the checkmark and the same size as this
                // line, so no row below moves as editing starts (the user, 2026-11-15: the
                // switch at the card's bottom, "This week only", wasn't clear).
                if isRenaming {
                    if !chipUnder { Spacer(minLength: 0) }
                    justThisWeekChip
                        .modifier(AnimatableFont(size: expandedCaptionSize, design: design))
                }
            }

            // Both contents stay in place so they move with the card; only the
            // visible one takes up space.
            ZStack(alignment: .topLeading) {
                // Never read by VoiceOver: a collapsed card is announced by its Open button.
                CollapsedCategoryContent(category: category, store: store, isPastWeek: isPastWeek, isEditing: isEditing)
                    .hiddenFromVoiceOver()
                    .modifier(CardContentCrossFade(isHidden: isExpanded))
                ExpandedCategoryContent(
                    category: category, store: store, isEditing: isEditingTasks,
                    isPastWeek: isPastWeek, onCollapse: onCollapse
                )
                .environment(\.isCardOpen, isExpanded)
                .modifier(CardContentCrossFade(isHidden: !isExpanded, width: openContentWidth))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(isExpanded ? Self.openPadding : 12)
        .frame(maxWidth: .infinity, minHeight: isExpanded ? 0 : 120, maxHeight: .infinity, alignment: .topLeading)
        // Contents animate inside the card's moving frame instead of each child
        // interpolating its own position (which let text run ahead of the card).
        .geometryGroup()
        .accessibilityHidden(!isExpanded)  // the Open button below speaks for a collapsed card
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .background { GridCardBackground(theme: theme, rc: rc, isExpanded: isExpanded) }
        .overlay {
            if !isExpanded {
                // Touches go to the grid's tap-or-hold gesture (tap opens, hold drags);
                // this button opens the card for VoiceOver.
                Button(action: onExpand) {
                    Color.clear.contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .allowsHitTesting(false)
                .accessibilityLabel(collapsedCardLabel)
                // In Edit cards don't open; VoiceOver moves them with Move Earlier / Later.
                .accessibilityRemoveTraits(isEditing ? .isButton : [])
                .accessibilityHint(isEditing && !isPastWeek ? "Use the Move Earlier and Move Later actions to move it." : "")
            }
        }
        .overlay(alignment: .topTrailing) {
            if isEditing && !isPastWeek && !isExpanded {
                Button {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white, .red)
                        .touchTarget()
                }
                .buttonStyle(.plain)
                .offset(x: 8, y: -8)
                .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
                .accessibilityLabel("Delete \(category.name)")
            }
        }
        // The pin inside the bottom-left corner, across from the open arrow: outside the top
        // left, it met the delete badge of the card beside it in the gap between them. (Not in
        // the card's contents, which VoiceOver doesn't see while it's closed.)
        .overlay(alignment: .bottomLeading) {
            if isEditing && !isPastWeek && !isExpanded {
                CardPinBadge(category: category, store: store)
                    .padding(.leading, 8)
                    .padding(.bottom, 6)
                    .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
            }
        }

        // No long-press menu: in edit mode holding a card starts a drag, and deleting
        // goes through the remove badge.
        .categoryDeletionConfirmation(isPresented: $showDeleteConfirmation, category: category, store: store)
        // A success when the card's last task is done. Keyed by the category's ID: paging
        // to a finished week shows the same card with another week's category, silently.
        // Only for checking off the last task: not for deleting the last unfinished one.
        .sensoryFeedback(trigger: completion, CardCompletion.finishedFeedback)
        .onChange(of: isRenaming, initial: true) { wasRenaming, renaming in
            // Finishing with the card's checkmark removes the field before it loses
            // focus, so the typed name is saved here.
            if wasRenaming && !renaming { commitName() }
            editedName = category.name
            nameError = nil
        }
    }

    // MARK: Header

    /// A card in its own edit mode (or global edit mode, while open) can be renamed and
    /// given another icon.
    private var isRenaming: Bool { isExpanded && isEditingTasks && !isPastWeek }

    private var header: some View {
        HStack(alignment: .center) {
            headerTitle
                // An open card also closes from a tap on its icon or name, not just
                // the button at its bottom. (Off while renaming, and on a closed card,
                // whose taps go to the grid's tap-or-hold gesture.)
                .contentShape(Rectangle())
                .gesture(TapGesture().onEnded { onCollapse() },
                         including: isExpanded && !isRenaming && !isEditing ? .all : .subviews)
            Spacer(minLength: 4)
            // The edit button lives beside the pie chart in space that opens up as
            // the card expands, so it travels with the pie instead of being inserted.
            completionIcon
                .padding(.leading, showsEditButton ? expandedPieSize + 10 : 0)
                .overlay(alignment: .leading) {
                    if !isPastWeek {
                        Button { onToggleEdit() } label: {
                            Image(systemName: isEditingTasks ? "checkmark.circle.fill" : "square.and.pencil")
                                .font(.system(size: expandedPieSize))
                                .foregroundStyle(isEditingTasks ? Theme.dotComplete(theme, rc: rc) : Theme.textSecondary(theme, rc: rc))
                                .touchTarget()
                        }
                        .buttonStyle(.plain)
                        .opacity(showsEditButton ? 1 : 0)
                        .scaleEffect(showsEditButton ? 1 : 0.5)
                        .allowsHitTesting(showsEditButton)
                        .accessibilityLabel(isEditingTasks ? "Done editing \(category.name)" : "Edit \(category.name)")
                        .accessibilityRemoveTraits(.isSelected)  // the Done checkmark isn't a state
                    }
                }
        }
    }

    /// The card's icon and name, or their editors while renaming.
    private var headerTitle: some View {
        HStack(alignment: .center) {
            if isRenaming {
                CategorySymbolMenu(symbol: Binding(
                    get: { category.symbol },
                    set: { store.setCategorySymbol(category.id, symbol: $0) }
                )) {
                    CategoryIcon(symbol: category.symbol)
                        .modifier(AnimatableFont(size: expandedTitleSize * 0.95))
                        .padding(6)
                        .background(Theme.textTertiary(theme, rc: rc).opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            } else if !Theme.isRetro(theme) {
                CategoryIcon(symbol: category.symbol)
                    .modifier(AnimatableFont(size: isExpanded ? expandedTitleSize * 0.95 : collapsedTitleSize))
                    .hiddenFromVoiceOver()  // the name follows
            }
            if isRenaming {
                TextField("Category name", text: $editedName)
                    .modifier(AnimatableFont(size: expandedTitleSize, weight: .semibold, design: design))
                    .focused($isNameFocused)
                    .submitLabel(.done)
                    .onSubmit(commitName)
                    // Escape (a hardware keyboard) puts the old name back.
                    .onReceive(NotificationCenter.default.publisher(for: EscapeKey.pressed)) { _ in
                        guard isNameFocused else { return }
                        editedName = category.name
                        nameError = nil
                        isNameFocused = false
                    }
                    .onChange(of: isNameFocused) { _, focused in
                        // Back in the field to try again: the last "why not" goes.
                        if focused { nameError = nil } else { commitName() }
                    }
                    .cardField(theme, rc: rc)
                    .accessibilityLabel("Category name")
            } else {
                Text(Theme.isRetro(theme) ? "[\(category.name.uppercased())]" : category.name)
                    .modifier(AnimatableFont(
                        size: isExpanded ? expandedTitleSize : collapsedTitleSize,
                        weight: .semibold, design: design
                    ))
                    // Long names wrap rather than being cut off at large text sizes; a
                    // single long word ("Appointments" on a small phone) shrinks instead
                    // of breaking mid-word.
                    .lineLimit(isSingleWordName ? 1 : 2)
                    .minimumScaleFactor(isSingleWordName ? 0.6 : 1)
                    .accessibilityLabel(category.name)
                    .accessibilityAddTraits(.isHeader)
            }
        }
    }

    private var isSingleWordName: Bool { !category.name.contains(" ") }

    /// "Completed: 2/4", then "· This week" for a card that's only this week's, and a pin for
    /// a pinned one (Retro: "done: 2/4 [1WK] [PIN]").
    private var completionLine: Text {
        let counts = "\(category.completedCount)/\(category.totalCount)"
        if Theme.isRetro(theme) {
            return Text(verbatim: "done: \(counts)\(category.isThisWeekOnly ? " [1WK]" : "")\(category.isPinned ? " [PIN]" : "")")
        }
        let line = "Completed: \(counts)\(category.isThisWeekOnly ? " · Just this week" : "")"
        return category.isPinned ? Text("\(line)  \(Image(systemName: "pin.fill"))") : Text(verbatim: line)
    }

    /// What VoiceOver says for a closed card: "Open Work, 2 of 4 tasks complete" (in Edit,
    /// where cards don't open, without "Open").
    private var collapsedCardLabel: String {
        let scope = (category.isPinned ? "pinned, " : "") + (category.isThisWeekOnly ? "just this week, " : "")
        let tasks = category.totalCount == 0 ? "no tasks yet" : "\(category.completedCount) of \(category.totalCount) tasks complete"
        return (isEditing ? "" : "Open ") + "\(category.name), \(scope)\(tasks)"
    }

    private var completion: CardCompletion {
        CardCompletion(id: category.id, total: category.totalCount,
                       isDone: category.totalCount > 0 && category.completedCount == category.totalCount)
    }

    /// "◯ Just this week" / "✓ Just this week": the card won't come back next week.
    private var justThisWeekChip: some View {
        let on = category.isThisWeekOnly
        let retro = Theme.isRetro(theme)
        return Button {
            withAnimation(.snappy(duration: 0.2)) { store.setCategoryThisWeekOnly(category.id, !on) }
        } label: {
            HStack(spacing: 4) {
                if retro {
                    Text(on ? "[x]" : "[ ]")
                } else {
                    Image(systemName: on ? "checkmark.circle.fill" : "circle")
                }
                Text(retro ? "just_this_week" : "Just this week")
            }
            .foregroundStyle(on ? Theme.accent(theme, rc: rc) : Theme.textSecondary(theme, rc: rc))
            // On its own line at accessibility sizes, where it may wrap to stay on the card.
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
            .fixedSize(horizontal: !dynamicTypeSize.isAccessibilitySize, vertical: true)
            .contentShape(Rectangle())
            .touchTarget()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Just this week")
        .accessibilityIdentifier("Just this week chip")
        .accessibilityValue(on ? "On" : "Off")
        .accessibilityAddTraits(.isToggle)
        .accessibilityHint(on ? "It won't come back next week." : "Makes this card this week's only.")
    }

    /// Hidden during global edit mode, which already covers every card.
    private var showsEditButton: Bool { isExpanded && !isPastWeek && !isEditing }

    /// Saves the typed name; a name that's empty or already used is rejected and the
    /// field goes back to the current name.
    private func commitName() {
        let name = ChecklistStore.cleanName(editedName)
        // Unchanged, including after a refused name was put back: leave its message up
        // (Return commits, then the field losing focus commits again).
        guard name != category.name else { return }
        if name.isEmpty {
            nameError = "A category needs a name."
        } else if store.renameCategory(category.id, newName: name) {
            nameError = nil
            onRenamed(name)
            return
        } else {
            nameError = "Another category is already named \(name)."
        }
        editedName = category.name
    }

    private var completionIcon: some View {
        let total = category.totalCount
        let completed = category.completedCount
        // A goal's progress, or a list's checked items, fill part of the ring before the task is done.
        let fraction = category.doneFraction
        // Nothing done yet is neutral, not red: every week starts there. The retro count
        // shows whole tasks, so its color goes by them.
        let started = Theme.isRetro(theme) ? completed > 0 : fraction > 0
        let color: Color = total == 0 || !started ? (Theme.isRetro(theme) ? Theme.textSecondary(theme, rc: rc) : .gray)
            : completed == total ? Theme.completionAll(theme, rc: rc)
            : Theme.completionPartial(theme)
        return Group {
            if Theme.isRetro(theme) {
                Text(completed == total && total > 0 ? "[OK]" : "[\(completed)/\(total)]")
                    .font(.system(.caption, design: .monospaced).bold())
                    .hiddenFromVoiceOver()  // the card's label and completion line give the count
            } else {
                CompletionRing(fraction: fraction, color: color)
                    .frame(width: isExpanded ? expandedPieSize : collapsedPieSize,
                           height: isExpanded ? expandedPieSize : collapsedPieSize)
                    .hiddenFromVoiceOver()  // the card's label and completion line give the count
            }
        }
        .foregroundStyle(color)
    }
}

// MARK: - Pin Badge

/// In Edit, at a closed card's bottom-leading corner: pins the card to the start of the grid,
/// or unpins it. With two pinned, the other cards' pins are dimmed.
private struct CardPinBadge: View {
    let category: Category
    let store: ChecklistStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let canPin = category.isPinned
            || (store.selectedWeek?.categories.filter(\.isPinned).count ?? 0) < Category.maxPins
        Button {
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.3)) {
                store.setCategoryPinned(categoryID: category.id, pinned: !category.isPinned)
            }
        } label: {
            Image(systemName: "pin.circle.fill")
                .font(.title3)
                .foregroundStyle(.white, category.isPinned ? Theme.pinned(store.appearanceMode, rc: store.retroColor) : Color.gray)
                .opacity(canPin ? 1 : 0.35)
                .touchTarget()
        }
        .buttonStyle(.plain)
        .disabled(!canPin)
        .accessibilityLabel(category.isPinned ? "Unpin \(category.name)" : "Pin \(category.name) to the top")
        .accessibilityHint(canPin ? "" : "Two cards are pinned. Unpin one to pin this one.")
        .accessibilityIdentifier("Pin \(category.name)")
    }
}

// MARK: - Completion Ring

/// A circular progress bar: a faint track with the completed share drawn over it.
struct CompletionRing: View {
    var fraction: Double
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            let lineWidth = max(2, proxy.size.width * 0.17)
            ZStack {
                Circle().stroke(color.opacity(0.25), lineWidth: lineWidth)
                Circle()
                    .trim(from: 0, to: min(max(fraction, 0), 1))
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .padding(lineWidth / 2)
        }
        .animation(.snappy(duration: 0.3), value: fraction)
    }
}

// MARK: - Card Background

/// The rounded card shape, border, and shadow shared by every grid card.
struct GridCardBackground: View {
    let theme: AppearanceMode
    let rc: RetroColor
    let isExpanded: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: Theme.cardCornerRadius(theme))
            .fill(Theme.cardFill(theme))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardCornerRadius(theme))
                    .stroke(Theme.cardBorder(theme, rc: rc), lineWidth: Theme.cardBorderWidth(theme))
            )
            .shadow(
                color: Theme.cardShadow(theme, rc: rc),
                radius: Theme.isRetro(theme) ? 8 : (isExpanded ? 10 : 6),
                x: Theme.isRetro(theme) ? 0 : (isExpanded ? 2 : 0),
                y: Theme.isRetro(theme) ? 0 : (isExpanded ? 2 : 3)
            )
    }
}

nonisolated private struct CardCompletion: Equatable {
    let id: UUID
    let total: Int
    let isDone: Bool

    /// Success when the same card's last task was just checked off (same total, so not
    /// a delete of its last unfinished task).
    static func finishedFeedback(_ old: CardCompletion, _ new: CardCompletion) -> SensoryFeedback? {
        old.id == new.id && old.total == new.total && !old.isDone && new.isDone ? .success : nil
    }
}

// MARK: - This Week Only

/// In a card's own edit mode: whether the category is for the viewed week only.
private struct ThisWeekOnlyNote: View {
    let category: Category
    let store: ChecklistStore

    private var theme: AppearanceMode { store.appearanceMode }
    private var rc: RetroColor { store.retroColor }
    private var design: Font.Design { Theme.isRetro(theme) ? .monospaced : .default }

    /// What Just this week does beyond its name, when there's something to say.
    private var note: String? {
        if category.isThisWeekOnly {
            return "Just this week: it won't come back next week. Adding a carry-over or repeating task turns this off."
        }
        return category.tasks.contains { $0.mode != .oneTime }
            ? "Just this week would make its carry-over and repeating tasks one-time."
            : nil
    }

    var body: some View {
        if let note {
            Text(note)
                .font(.expandedCard(.caption1, design: design))
                .foregroundStyle(Theme.textSecondary(theme, rc: rc))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Collapsed Content

/// Task preview dots and the open arrow, shown below the header when collapsed.
private struct CollapsedCategoryContent: View {
    let category: Category
    let store: ChecklistStore
    let isPastWeek: Bool
    /// Edit mode: cards don't open, so the empty hint doesn't say "Tap to add".
    let isEditing: Bool

    private var theme: AppearanceMode { store.appearanceMode }
    private var rc: RetroColor { store.retroColor }
    /// Tasks listed on a closed card; any more are counted below them.
    private static let previewCount = 5
    @Environment(\.taskDayFilter) private var dayFilter
    @Environment(\.cardWeekStart) private var weekStart

    /// In the card's order; with a day picked in the day strip, that day's and those with no day.
    private var shownTasks: [ChecklistTask] {
        category.shownTasks(firstWeekday: store.firstWeekday, day: dayFilter, weekStart: weekStart, today: store.currentDay)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 3) {
                if let dayFilter, !category.tasks.isEmpty, shownTasks.isEmpty {
                    Text(Theme.isRetro(theme) ? "nothing_on_\(Weekday.name(dayFilter).lowercased())"
                                              : "Nothing for \(Weekday.name(dayFilter, short: false))")
                        .font(Theme.isRetro(theme) ? .system(.caption2, design: .monospaced) : .caption2)
                        .foregroundStyle(Theme.textSecondary(theme, rc: rc))
                }
                // An empty card says what to do rather than looking blank.
                if category.tasks.isEmpty {
                    let quiet = isPastWeek || isEditing
                    Text(Theme.isRetro(theme)
                         ? (quiet ? "no_tasks" : "no_tasks // tap_to_add")
                         : (isPastWeek ? "No tasks" : isEditing ? "No tasks yet" : "No tasks yet · Tap to add"))
                        .font(Theme.isRetro(theme) ? .system(.caption2, design: .monospaced) : .caption2)
                        .foregroundStyle(Theme.textSecondary(theme, rc: rc))
                }
                ForEach(shownTasks.prefix(Self.previewCount)) { task in
                    HStack(spacing: 6) {
                        if Theme.isRetro(theme) {
                            Text(task.isCompleted ? "[x]" : "[ ]")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(task.isCompleted ? Theme.dotComplete(theme, rc: rc) : Theme.dotIncomplete(theme))
                        } else {
                            // Filled when done, an outline when not, so it doesn't rely on color alone.
                            Circle()
                                .fill(task.isCompleted ? Theme.dotComplete(theme, rc: rc) : .clear)
                                .strokeBorder(task.isCompleted ? .clear : Theme.dotIncomplete(theme), lineWidth: 1.5)
                                .frame(width: 7, height: 7)
                        }
                        Text(task.title)
                            .font(Theme.isRetro(theme) ? .system(.caption2, design: .monospaced) : .caption2)
                            .foregroundStyle(Theme.textSecondary(theme, rc: rc)).lineLimit(1)
                        if task.dayOfWeek != nil || task.expiresOn != nil {
                            // A task with a day or a date: a small mark after its name (a
                            // long name gives way first), colored like the open card's.
                            TaskTimeMark(task: task, color: dayColor(task))
                        }
                    }
                }
                if shownTasks.count > Self.previewCount {
                    Text(Theme.isRetro(theme) ? "+\(shownTasks.count - Self.previewCount)_more" : "+\(shownTasks.count - Self.previewCount) more")
                        .font(Theme.isRetro(theme) ? .system(.caption2, design: .monospaced) : .caption2)
                        .foregroundStyle(Theme.textTertiary(theme, rc: rc))
                }
            }

            Spacer(minLength: 0)

            HStack {
                Spacer()
                if Theme.isRetro(theme) {
                    Text("[OPEN]").font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Theme.textTertiary(theme, rc: rc))
                } else {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.caption).foregroundStyle(Theme.textTertiary(theme, rc: rc))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// The small mark after a task's name in a closed card (the user's picks, 2026-11-14): a
/// calendar for a task with a date, a calendar with its day's letters for a repeating task
/// with a day, and a timer for any other task with a day (this week's, or until done).
struct TaskTimeMark: View {
    let task: ChecklistTask
    let color: Color

    var body: some View {
        Group {
            if task.expiresOn != nil {
                Image(systemName: "calendar")
            } else if task.mode == .repeating, let day = task.dayOfWeek {
                DayCalendarGlyph(day: day)
            } else {
                Image(systemName: "timer")
            }
        }
        .font(.caption2.weight(.semibold))
        .imageScale(.small)
        .foregroundStyle(color)
        .fixedSize()
        .accessibilityHidden(true)
    }
}

/// A tiny calendar page with a day's first two letters ("Tu") for a repeating task's day.
struct DayCalendarGlyph: View {
    let day: Int

    var body: some View {
        Text(String(Weekday.name(day).prefix(2)))
            .font(.system(size: 6.5, weight: .heavy))
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .frame(width: 12, height: 8)
            .padding(.top, 3)
            .overlay(alignment: .top) { Rectangle().frame(height: 2.5) }
            .overlay { RoundedRectangle(cornerRadius: 2, style: .continuous).strokeBorder(lineWidth: 1) }
    }
}

extension CollapsedCategoryContent {
    /// A day task's clock: green on its day until it's done, orange once its day has gone by
    /// unfinished, gray otherwise (as the open card's "Today" / "Tue · late" / "Fri").
    fileprivate func dayColor(_ task: ChecklistTask) -> Color {
        guard let weekStart, !isPastWeek else { return Theme.textSecondary(theme, rc: rc) }
        // A date without a day: green until it's done, like the open card's clock.
        if task.dayOfWeek == nil { return task.isCompleted ? Theme.textSecondary(theme, rc: rc) : Theme.expirySet(theme, rc: rc) }
        if task.isLate(inWeekStarting: weekStart, firstWeekday: store.firstWeekday, today: store.currentDay) {
            return Theme.late(theme)
        }
        if !task.isCompleted, task.day(inWeekStarting: weekStart, firstWeekday: store.firstWeekday) == store.currentDay {
            return Theme.expirySet(theme, rc: rc)
        }
        return Theme.textSecondary(theme, rc: rc)
    }
}

// MARK: - Expanded Content

/// Full task list, add-task field, and collapse button, shown below the header when expanded.
private struct ExpandedCategoryContent: View {
    let category: Category
    let store: ChecklistStore
    let isEditing: Bool
    let isPastWeek: Bool
    let onCollapse: () -> Void

    private var theme: AppearanceMode { store.appearanceMode }
    private var rc: RetroColor { store.retroColor }

    /// The task being moved by its handle (the card's edit mode), if any.
    @State private var reorder: TaskReorder?
    @Environment(\.taskDayFilter) private var dayFilter
    @Environment(\.cardWeekStart) private var weekStart
    /// Each task row's frame in the task list (laid out, without a reorder's offsets).
    @State private var rowFrames: [UUID: CGRect] = [:]
    /// Scrolls the grid while a lifted task is held near the top or bottom.
    @State private var autoScroller = TaskAutoScroller()
    @Environment(\.cardGridBottomBar) private var bottomBar

    /// Wider than the gaps inside a task (sub-tasks, a goal's bar and buttons), so each
    /// task reads as one group.
    private var taskSpacing: CGFloat { 14 * expandedCardScale }

    /// The order the tasks had when one's options or date calendar opened, kept until it
    /// closes: a new day or date moved the task to the top or the end while it was being
    /// chosen (the user, 2026-11-14). Then they move into place.
    @State private var frozenOrder: [UUID]?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Holds the order (or lets it go, the tasks moving into place) for a row whose options
    /// are open, or for the Add task row while it's in use; tasks added meanwhile go last.
    private func freezeOrder(_ hold: Bool) {
        withAnimation(hold || reduceMotion ? nil : .snappy(duration: 0.25)) {
            frozenOrder = hold ? listedTasks.map(\.id) : nil
        }
    }

    /// Pinned first, then by day (`shownTasks`), unless a task's options are open.
    private var listedTasks: [ChecklistTask] {
        let live = category.shownTasks(firstWeekday: store.firstWeekday, day: dayFilter, weekStart: weekStart, today: store.currentDay)
        guard let frozenOrder else { return live }
        let byID = Dictionary(category.tasks.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        // Tasks added meanwhile go last in the order they were added, not sorted (a new task
        // with a day went ahead of the others typed with it, away from its note, 2026-11-15).
        let shown = Set(live.map(\.id))
        return frozenOrder.compactMap { byID[$0] } + category.tasks.filter { shown.contains($0.id) && !frozenOrder.contains($0.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: taskSpacing) {
            // Pinned first, then by day (`orderedTasks`); with a day picked in the day strip,
            // that day's and those with no day.
            let duplicates = category.duplicateTaskIDs
            ForEach(listedTasks) { task in
                let isLifted = reorder?.taskID == task.id
                TaskRowCard(
                    task: task,
                    categoryID: category.id,
                    store: store,
                    isEditing: isEditing,
                    isPastWeek: isPastWeek,
                    isDuplicate: duplicates.contains(task.id),
                    onHandleDrag: { moveLifted(task.id, by: $0, at: $1) },
                    onHandleRelease: { drop(task.id) }
                )
                // A lifted task sits over the others on its own card, a little larger.
                .background {
                    if isLifted { LiftedTaskBackground(theme: theme, rc: rc) }
                }
                .scaleEffect(isLifted ? 1.03 : 1)
                .offset(y: reorder?.offset(for: task.id, spacing: taskSpacing) ?? 0)
                // Measured outside the offset, so it's where the row is laid out.
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(TaskReorder.space)) } action: {
                    rowFrames[task.id] = $0
                }
                // Last, so the stack sees it: before the measuring, the rows it passed while the
                // grid scrolled were drawn over it.
                .zIndex(isLifted ? 1 : 0)
                .environment(\.freezesTaskOrder, freezeOrder)
            }

            // Adding is off while the card is in edit mode. Just this week's note takes the
            // add row's place then (its switch is beside Completed), so no row above it moves as
            // editing starts (a tap
            // meant for a task's delete button landed on the row below instead). The add row
            // stays, showing nothing, so a Smart Add still working isn't lost.
            if !isPastWeek {
                VStack(alignment: .leading, spacing: 0) {
                    AddTaskRowCard(categoryID: category.id, store: store, isEditing: isEditing)
                        // New tasks stay just above the field, by their note, while it's in use
                        // ("Call mom Sunday" went to the top, its note left by the field, 2026-11-15).
                        .environment(\.freezesTaskOrder, freezeOrder)
                    if isEditing {
                        // What Just this week (beside Completed, up top) does, where it says more.
                        ThisWeekOnlyNote(category: category, store: store)
                    }
                }
                // Clear of the sub-task or item rows above: the field's fill reaches past
                // its text (see cardField), which crowded the last row.
                .padding(.top, 8 * expandedCardScale)
            }

            HStack {
                Spacer()
                Button { onCollapse() } label: {
                    Group {
                        if Theme.isRetro(theme) {
                            Text("[CLOSE]").font(.expandedCard(.caption1, design: .monospaced))
                                .foregroundStyle(Theme.textTertiary(theme, rc: rc))
                        } else {
                            Image(systemName: "arrow.down.right.and.arrow.up.left")
                                .font(.expandedCard(size: 20))
                                .foregroundStyle(Theme.isCustomDark(theme) ? .white : Theme.isSeasonal(theme) ? Theme.textSecondary(theme, rc: rc) : Color(.secondaryLabel))
                        }
                    }
                    .touchTarget()
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close \(category.name)")
            }
        }
        .coordinateSpace(.named(TaskReorder.space))
        .background { TaskAutoScrollAnchor(scroller: autoScroller).hiddenFromVoiceOver() }
        // A firm tap as a task lifts, a lighter one as it drops, a tick for each place it passes.
        .sensoryFeedback(trigger: reorder?.taskID) { _, lifted in
            lifted != nil ? .impact(weight: .medium) : .impact(weight: .light)
        }
        .sensoryFeedback(.selection, trigger: reorder?.target) { old, new in old != nil && new != nil }
        // Leaving edit mode takes the handle away mid-drag: the task goes back to its place.
        .onChange(of: isEditing) { _, editing in
            if !editing && reorder != nil { endReorder() }
        }
        .onDisappear { if reorder != nil { endReorder() } }
    }

    /// The handle of `taskID` moved `translation` on the screen from where it was touched,
    /// the finger now at `fingerY` (window coordinates): the first move lifts the task, then
    /// it follows the finger and the tasks it passes slide over to make room.
    private func moveLifted(_ taskID: UUID, by translation: CGFloat, at fingerY: CGFloat) {
        guard isEditing, !isPastWeek else { return }
        if reorder == nil {
            // A pinned task moves among the pinned ones, another among the rest.
            let order = category.reorderGroup(for: taskID).map(\.id)
            guard let from = order.firstIndex(of: taskID), order.allSatisfy({ rowFrames[$0] != nil }) else { return }
            // The week can't be swiped meanwhile: a sideways wobble changed the week.
            store.isReorderingTask = true
            autoScroller.begin()
            withAnimation(.snappy(duration: 0.15)) {
                reorder = TaskReorder(taskID: taskID, order: order, frames: rowFrames, from: from)
            }
        }
        guard reorder?.taskID == taskID else { return }
        reorder?.fingerTranslation = translation
        reorder?.fingerY = fingerY
        followFinger()
    }

    /// Puts the lifted task under the finger: its move on the screen plus however far the
    /// grid has scrolled under it. Near the top or bottom the grid scrolls (once the finger
    /// has moved a little, so a task lifted near the bottom bar doesn't set it off), until the
    /// task reaches that end of its card; each step comes back here.
    private func followFinger() {
        guard let moving = reorder else { return }
        let bounds = moving.distanceBounds
        let distance = moving.clamped(moving.fingerTranslation + autoScroller.scrolled)
        reorder?.distance = distance
        if let landing = reorder?.landing, landing != reorder?.target {
            withAnimation(.snappy(duration: 0.2)) { reorder?.target = landing }
        }
        let hasMoved = abs(moving.fingerTranslation) > 8
        autoScroller.update(fingerY: moving.fingerY,
                            canScrollUp: hasMoved && distance > bounds.lowerBound + 0.5,
                            canScrollDown: hasMoved && distance < bounds.upperBound - 0.5,
                            bottomBar: bottomBar,
                            onScroll: { followFinger() })
    }

    /// The handle let go: the task takes the place it was dragged to.
    private func drop(_ taskID: UUID) {
        guard let moving = reorder, moving.taskID == taskID else { return }
        withAnimation(.snappy(duration: 0.25)) {
            // (Not if the card's tasks changed meanwhile: the places no longer match.)
            if moving.target != moving.from, moving.order.indices.contains(moving.target),
               category.reorderGroup(for: taskID).map(\.id) == moving.order {
                store.moveTask(categoryID: category.id, taskID: taskID, to: moving.order[moving.target])
            }
            endReorder()
        }
    }

    private func endReorder() {
        autoScroller.end()
        reorder = nil
        store.isReorderingTask = false
    }
}

/// A task being moved by its handle in a card's edit mode: it follows the finger, and the
/// tasks it passes slide over to make room. The frames are the rows' as it was lifted.
struct TaskReorder {
    /// The task list's coordinate space, which doesn't move during a drag (the handle's
    /// own space moves with the lifted row).
    static let space = "taskList"

    let taskID: UUID
    let order: [UUID]
    let frames: [UUID: CGRect]
    let from: Int
    /// How far the task has moved in the list, up (negative) or down: the finger's move
    /// plus the grid's scrolling.
    var distance: CGFloat = 0
    /// The place it would take if let go now.
    var target: Int
    /// The finger's move on the screen since it touched the handle, and where it is now
    /// (window coordinates).
    var fingerTranslation: CGFloat = 0
    var fingerY: CGFloat = 0

    init(taskID: UUID, order: [UUID], frames: [UUID: CGRect], from: Int) {
        self.taskID = taskID
        self.order = order
        self.frames = frames
        self.from = from
        target = from
    }

    /// `distance` kept within the list, so the task can't be dragged past either end, but
    /// always far enough for its middle to reach the end tasks' (a tall task held at the
    /// end of the list stopped short of a short last task's middle, and couldn't pass it).
    func clamped(_ distance: CGFloat) -> CGFloat {
        min(max(distance, distanceBounds.lowerBound), distanceBounds.upperBound)
    }

    /// How far up (negative) and down the task can go: to either end of the list.
    var distanceBounds: ClosedRange<CGFloat> {
        guard let frame = frames[taskID], let first = order.first.flatMap({ frames[$0] }),
              let last = order.last.flatMap({ frames[$0] }) else { return -CGFloat.infinity...CGFloat.infinity }
        let top = min(first.minY - frame.minY, first.midY - frame.midY, 0)
        let bottom = max(last.maxY - frame.maxY, last.midY - frame.midY, 0)
        return top...bottom
    }

    /// Where the task would land: past every task whose middle its own middle has reached,
    /// to within a point (held at the end of the list, the two middles meet exactly, and a
    /// rounding error decided it).
    var landing: Int {
        guard let frame = frames[taskID] else { return from }
        let middle = frame.midY + distance
        var index = 0
        for (i, id) in order.enumerated() where id != taskID {
            guard let other = frames[id] else { continue }
            // Reaching a task's middle takes its place, going up or down.
            if i < from ? other.midY < middle - 1 : other.midY <= middle + 1 { index += 1 }
        }
        return index
    }

    /// How far a row is drawn from its place: the lifted one with the finger, the ones it
    /// has passed by its height, toward the place it left.
    func offset(for id: UUID, spacing: CGFloat) -> CGFloat {
        if id == taskID { return distance }
        guard let i = order.firstIndex(of: id), let height = frames[taskID]?.height else { return 0 }
        if from < i && i <= target { return -(height + spacing) }
        if target <= i && i < from { return height + spacing }
        return 0
    }
}

/// Behind a lifted task: its own card, outlined, with a shadow (Retro: a bright outline).
private struct LiftedTaskBackground: View {
    let theme: AppearanceMode
    let rc: RetroColor

    var body: some View {
        let isRetro = Theme.isRetro(theme)
        let shape = RoundedRectangle(cornerRadius: isRetro ? 2 : 10)
        shape.fill(Theme.cardFill(theme))
            .overlay { shape.stroke(Theme.accent(theme, rc: rc).opacity(isRetro ? 1 : 0.35), lineWidth: 1) }
            .shadow(color: .black.opacity(isRetro ? 0 : 0.22), radius: 8, y: 3)
            .padding(.horizontal, -8)
            .padding(.vertical, -6)
            .hiddenFromVoiceOver()
    }
}

// MARK: - Animation Helpers

/// A system font whose point size animates smoothly. Named text styles
/// (`.subheadline` → `.title3`) can't be interpolated and would jump.
struct AnimatableFont: ViewModifier, Animatable {
    var size: CGFloat
    var weight: Font.Weight = .regular
    var design: Font.Design = .default

    var animatableData: CGFloat {
        get { size }
        set { size = newValue }
    }

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: weight, design: design))
    }
}

/// Hidden content stops taking up space immediately (so the card can shrink)
/// but fades out in place, cross-fading with the content being shown.
/// (Toggling `accessibilityHidden` here would corrupt the accessibility frames
/// of the buttons inside, so VoiceOver visibility is handled by the card.)
struct CardContentCrossFade: ViewModifier {
    let isHidden: Bool
    /// The width to lay the content out at, whatever the card's width on the way there (an
    /// open card's contents: `openContentWidth`); nil, the card's width as it is.
    var width: CGFloat? = nil

    func body(content: Content) -> some View {
        HiddenContentLayout(isHidden: isHidden, width: width) { content }
            .opacity(isHidden ? 0 : 1)
            .allowsHitTesting(!isHidden)
    }
}

/// While hidden, takes up no space and never widens the card: it reports only the
/// width it's offered, but still lays its content out at that width. (Hidden task
/// rows have a minimum width wider than a grid column, which squeezed out the gap
/// between collapsed cards.)
///
/// With a `width`, the content is laid out at that width (and its own height) however wide
/// the card is: an open card's task rows, laid out at the card's width on every frame of it
/// growing or shrinking, made each frame take ~35ms and the animation stutter (2026-11-12).
/// At its own width they're laid out once and the card's edge reveals them as it grows.
/// (Its height doesn't depend on the height offered: nothing in it stretches.)
private struct HiddenContentLayout: Layout {
    var isHidden: Bool
    var width: CGFloat?

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let content = subviews.first else { return .zero }
        if isHidden { return CGSize(width: proposal.width ?? 0, height: 0) }
        guard let width else { return content.sizeThatFits(proposal) }
        let size = content.sizeThatFits(ProposedViewSize(width: width, height: nil))
        return CGSize(width: proposal.width ?? size.width, height: size.height)
    }

    // No alignment guides come out of a card's contents. Left to the default, which merges
    // the guides of everything inside, every layout pass measured each card's whole contents
    // (every task row) again just to find there were none; with a card opening that was
    // every frame (2026-11-12, the lag the user felt on the phone).
    func explicitAlignment(of guide: HorizontalAlignment, in bounds: CGRect, proposal: ProposedViewSize,
                           subviews: Subviews, cache: inout ()) -> CGFloat? { nil }
    func explicitAlignment(of guide: VerticalAlignment, in bounds: CGRect, proposal: ProposedViewSize,
                           subviews: Subviews, cache: inout ()) -> CGFloat? { nil }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(
            at: bounds.origin,
            anchor: .topLeading,
            proposal: ProposedViewSize(width: width ?? bounds.width, height: isHidden || width != nil ? nil : bounds.height)
        )
    }
}

extension EnvironmentValues {
    /// Whether the card holding a view is open. An open card's contents stay in place
    /// (hidden) while it's closed, so a field there mustn't take the keyboard then.
    @Entry var isCardOpen = true
    /// The width of the week's grid of cards (an open card's width), once measured.
    @Entry var cardGridWidth: CGFloat? = nil
    /// Told when a task's options or date calendar open (true) and close (false): its card
    /// keeps its order meanwhile (see `ExpandedCategoryContent.frozenOrder`).
    @Entry var freezesTaskOrder: (Bool) -> Void = { _ in }
    /// The day picked in the week's day strip (1 Sunday … 7 Saturday): cards show that day's
    /// tasks and the ones with no day, and tasks added get that day. Nil: every task.
    @Entry var taskDayFilter: Int? = nil
    /// The first day of the week a card's page shows (neighbor pages are drawn while paging).
    @Entry var cardWeekStart: DayKey? = nil
    /// Scrolls the week's grid of cards, so a field can bring itself wholly into view.
    @Entry var cardGridScroll: ScrollViewProxy? = nil
    /// The bottom bar's height from the window's bottom (0 while the keyboard is up), so a
    /// task moved by its handle scrolls the grid before reaching it.
    @Entry var cardGridBottomBar: CGFloat = 0
}
