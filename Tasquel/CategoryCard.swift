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
                 : "This removes the category and its tasks from this week and all upcoming weeks. Past weeks keep their history. You can add it back from Add Category.")
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

    @State private var showDeleteConfirmation = false
    @State private var editedName = ""
    @State private var nameError: String?
    @FocusState private var isNameFocused: Bool

    // Collapsed → expanded sizes; scaled with Dynamic Type. Expanded sizes include
    // the 15% enlargement applied to everything inside an expanded card.
    @ScaledMetric(relativeTo: .subheadline) private var collapsedTitleSize: CGFloat = 15
    @ScaledMetric(relativeTo: .title3) private var expandedTitleSize: CGFloat = 20 * expandedCardScale
    @ScaledMetric(relativeTo: .body) private var collapsedPieSize: CGFloat = 17
    @ScaledMetric(relativeTo: .title3) private var expandedPieSize: CGFloat = 20 * expandedCardScale
    @ScaledMetric(relativeTo: .caption) private var collapsedCaptionSize: CGFloat = 12
    @ScaledMetric(relativeTo: .subheadline) private var expandedCaptionSize: CGFloat = 15 * expandedCardScale

    private var theme: AppearanceMode { store.appearanceMode }
    private var rc: RetroColor { store.retroColor }
    private var cornerRadius: CGFloat { Theme.cardCornerRadius(theme) }
    private var design: Font.Design { Theme.isRetro(theme) ? .monospaced : .default }

    var body: some View {
        VStack(alignment: .leading, spacing: isExpanded ? 8 : 6) {
            header
            if isRenaming, let nameError {
                Text(nameError)
                    .font(.footnote)
                    .foregroundStyle(Theme.destructive(theme))
            }

            Text(Theme.isRetro(theme)
                 ? "done: \(category.completedCount)/\(category.totalCount)\(category.isThisWeekOnly ? " [1WK]" : "")"
                 : "Completed: \(category.completedCount)/\(category.totalCount)\(category.isThisWeekOnly ? " · This week" : "")")
                .modifier(AnimatableFont(size: isExpanded ? expandedCaptionSize : collapsedCaptionSize, design: design))
                .foregroundStyle(Theme.textSecondary(theme, rc: rc))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            // Both contents stay in place so they move with the card; only the
            // visible one takes up space.
            ZStack(alignment: .topLeading) {
                // Never read by VoiceOver: a collapsed card is announced by its Open button.
                CollapsedCategoryContent(category: category, store: store)
                    .accessibilityHidden(true)
                    .modifier(CardContentCrossFade(isHidden: isExpanded))
                ExpandedCategoryContent(
                    category: category, store: store, isEditing: isEditingTasks,
                    isPastWeek: isPastWeek, onCollapse: onCollapse
                )
                .modifier(CardContentCrossFade(isHidden: !isExpanded))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(isExpanded ? 14 * expandedCardScale : 12)
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
                .accessibilityLabel("Open \(category.name), \(category.isThisWeekOnly ? "this week only, " : "")\(category.completedCount) of \(category.totalCount) tasks complete")
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
                }
                .buttonStyle(.plain)
                .offset(x: 8, y: -8)
                .transition(.scale.combined(with: .opacity))
                .accessibilityLabel("Remove \(category.name)")
            }
        }
        // No long-press menu: in edit mode holding a card starts a drag, and deleting
        // goes through the remove badge.
        .categoryDeletionConfirmation(isPresented: $showDeleteConfirmation, category: category, store: store)
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
            if isRenaming {
                CategorySymbolMenu(symbol: Binding(
                    get: { category.symbol },
                    set: { store.setCategorySymbol(category.id, symbol: $0) }
                )) {
                    Image(systemName: category.symbol)
                        .modifier(AnimatableFont(size: expandedTitleSize * 0.95))
                        .padding(6)
                        .background(Theme.textTertiary(theme, rc: rc).opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            } else if !Theme.isRetro(theme) {
                Image(systemName: category.symbol)
                    .modifier(AnimatableFont(size: isExpanded ? expandedTitleSize * 0.95 : collapsedTitleSize))
            }
            if isRenaming {
                TextField("Category name", text: $editedName)
                    .modifier(AnimatableFont(size: expandedTitleSize, weight: .semibold, design: design))
                    .focused($isNameFocused)
                    .submitLabel(.done)
                    .onSubmit(commitName)
                    .onChange(of: isNameFocused) { _, focused in
                        if !focused { commitName() }
                    }
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Theme.textTertiary(theme, rc: rc).opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
                    .accessibilityLabel("Category name")
            } else {
                Text(Theme.isRetro(theme) ? "[\(category.name.uppercased())]" : category.name)
                    .modifier(AnimatableFont(
                        size: isExpanded ? expandedTitleSize : collapsedTitleSize,
                        weight: .semibold, design: design
                    ))
                    .lineLimit(1)
            }
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
                                .foregroundStyle(isEditingTasks ? .green : Theme.textSecondary(theme, rc: rc))
                        }
                        .buttonStyle(.plain)
                        .opacity(showsEditButton ? 1 : 0)
                        .scaleEffect(showsEditButton ? 1 : 0.5)
                        .allowsHitTesting(showsEditButton)
                        .accessibilityLabel(isEditingTasks ? "Done editing \(category.name)" : "Edit \(category.name)")
                    }
                }
        }
    }

    /// Hidden during global edit mode, which already covers every card.
    private var showsEditButton: Bool { isExpanded && !isPastWeek && !isEditing }

    /// Saves the typed name; a name that's empty or already used is rejected and the
    /// field goes back to the current name.
    private func commitName() {
        let name = ChecklistStore.cleanName(editedName)
        guard name != category.name else { nameError = nil; return }
        if name.isEmpty {
            nameError = "A category needs a name."
        } else if store.renameCategory(category.id, newName: name) {
            nameError = nil
            return
        } else {
            nameError = "Another category is already named \(name)."
        }
        editedName = category.name
    }

    private var completionIcon: some View {
        let total = category.totalCount
        let completed = category.completedCount
        let color: Color = total == 0 ? .gray
            : completed == 0 ? Theme.completionNone(theme)
            : completed == total ? Theme.completionAll(theme, rc: rc)
            : Theme.completionPartial(theme)
        return Group {
            if Theme.isRetro(theme) {
                Text(completed == total && total > 0 ? "[OK]" : "[\(completed)/\(total)]")
                    .font(.system(.caption, design: .monospaced).bold())
            } else {
                CompletionRing(fraction: total == 0 ? 0 : Double(completed) / Double(total), color: color)
                    .frame(width: isExpanded ? expandedPieSize : collapsedPieSize,
                           height: isExpanded ? expandedPieSize : collapsedPieSize)
                    .accessibilityHidden(true)  // the card's label and completion line give the count
            }
        }
        .foregroundStyle(color)
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

// MARK: - Collapsed Content

/// Task preview dots and the open arrow, shown below the header when collapsed.
private struct CollapsedCategoryContent: View {
    let category: Category
    let store: ChecklistStore

    private var theme: AppearanceMode { store.appearanceMode }
    private var rc: RetroColor { store.retroColor }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 3) {
                ForEach(category.tasks.prefix(5)) { task in
                    HStack(spacing: 6) {
                        if Theme.isRetro(theme) {
                            Text(task.isCompleted ? "[x]" : "[ ]")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(task.isCompleted ? Theme.dotComplete(theme, rc: rc) : Theme.dotIncomplete(theme))
                        } else {
                            Circle()
                                .fill(task.isCompleted ? Theme.dotComplete(theme, rc: rc) : Theme.dotIncomplete(theme))
                                .frame(width: 7, height: 7)
                        }
                        Text(task.title)
                            .font(Theme.isRetro(theme) ? .system(.caption2, design: .monospaced) : .caption2)
                            .foregroundStyle(Theme.textSecondary(theme, rc: rc)).lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 0)

            HStack {
                Spacer()
                if Theme.isRetro(theme) {
                    Text("[OPEN]").font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Theme.textTertiary(theme, rc: rc))
                } else {
                    Image(systemName: "arrow.up.forward")
                        .font(.caption).foregroundStyle(Theme.textTertiary(theme, rc: rc))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 8 * expandedCardScale) {
            ForEach(category.tasks) { task in
                TaskRowCard(
                    task: task,
                    categoryID: category.id,
                    store: store,
                    isEditing: isEditing,
                    isPastWeek: isPastWeek
                )
            }

            // Adding is off while the card is in edit mode.
            if !isPastWeek && !isEditing {
                AddTaskRowCard(categoryID: category.id, store: store)
            }

            HStack {
                Spacer()
                Button { onCollapse() } label: {
                    if Theme.isRetro(theme) {
                        Text("[CLOSE]").font(.expandedCard(.caption1, design: .monospaced))
                            .foregroundStyle(Theme.textTertiary(theme, rc: rc))
                    } else {
                        Image(systemName: "rectangle.compress.vertical")
                            .font(.expandedCard(size: 20))
                            .foregroundStyle(Theme.isCustomDark(theme) ? .white : Color(.secondaryLabel))
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Collapse \(category.name)")
            }
        }
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

    func body(content: Content) -> some View {
        HiddenContentLayout(isHidden: isHidden) { content }
            .opacity(isHidden ? 0 : 1)
            .allowsHitTesting(!isHidden)
    }
}

/// While hidden, takes up no space and never widens the card: it reports only the
/// width it's offered, but still lays its content out at that width. (Hidden task
/// rows have a minimum width wider than a grid column, which squeezed out the gap
/// between collapsed cards.)
private struct HiddenContentLayout: Layout {
    var isHidden: Bool

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let content = subviews.first else { return .zero }
        return isHidden ? CGSize(width: proposal.width ?? 0, height: 0) : content.sizeThatFits(proposal)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(
            at: bounds.origin,
            anchor: .topLeading,
            proposal: ProposedViewSize(width: bounds.width, height: isHidden ? nil : bounds.height)
        )
    }
}
