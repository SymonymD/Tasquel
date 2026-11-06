import SwiftUI

// MARK: - Task Options Button

/// A task's type and mode icons side by side, in their colors. Opens `TaskOptionsPicker`.
struct TaskOptionsLabel: View {
    let type: TaskType
    let mode: TaskMode
    let theme: AppearanceMode
    let rc: RetroColor

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: type.symbol)
                .foregroundStyle(Theme.taskType(type, theme, rc: rc))
            Image(systemName: mode.symbol)
                .foregroundStyle(Theme.taskMode(mode, theme, rc: rc))
        }
        .expandedCardFont(.subheadline)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(Theme.textTertiary(theme, rc: rc).opacity(0.2), in: Capsule())
    }
}

// MARK: - Task Options Picker

/// Two columns: what the task is (type) and what happens to it after this week (mode).
/// Each tap applies right away. For a new task, `onAdd` shows an Add Task button;
/// otherwise `onDone` shows Done, which closes the picker.
struct TaskOptionsPicker: View {
    let type: TaskType
    let mode: TaskMode
    let theme: AppearanceMode
    let rc: RetroColor
    /// Leaving a goal that has a target or progress asks first, since it clears them.
    var confirmsLeavingGoal = false
    let onSelectType: (TaskType) -> Void
    let onSelectMode: (TaskMode) -> Void
    var onAdd: (() -> Void)? = nil
    var onDone: (() -> Void)? = nil
    /// The task's card is for this week only: a mode that comes back next week turns that off.
    var isThisWeekOnlyCategory = false

    @State private var pendingType: TaskType?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // Scrolls when it's taller than the screen (accessibility text sizes).
        ViewThatFits(in: .vertical) {
            content
            ScrollView { content }
        }
        .padding(16)
        .frame(minWidth: 300)
        // A keyboard that's up (typing a new task) mustn't push the options out of the
        // popover: in landscape on iPad it pushed the first rows off the top.
        .ignoresSafeArea(.keyboard)
        .presentationCompactAdaptation(.popover)
        .confirmationDialog("Change to \(pendingType?.label ?? "")?", isPresented: Binding(
            get: { pendingType != nil },
            set: { if !$0 { pendingType = nil } }
        ), titleVisibility: .visible) {
            Button("Change Type", role: .destructive) {
                if let pendingType { onSelectType(pendingType) }
                pendingType = nil
            }
        } message: {
            Text("This clears the goal target and progress.")
        }
    }

    /// Two columns side by side; one above the other at accessibility text sizes.
    private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            let columns = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 14))
                : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
            columns {
                column("Type") {
                    ForEach(TaskType.allCases, id: \.self) { option in
                        optionButton(option.label, symbol: option.symbol,
                                     color: Theme.taskType(option, theme, rc: rc),
                                     isSelected: option == type) {
                            selectType(option)
                        }
                    }
                }
                column("After This Week") {
                    ForEach(TaskMode.ordered, id: \.self) { option in
                        optionButton(option.label, symbol: option.symbol,
                                     color: Theme.taskMode(option, theme, rc: rc),
                                     isSelected: option == mode) {
                            onSelectMode(option)
                        }
                    }
                }
            }
            Text(hint)
                .font(Theme.isRetro(theme) ? .system(.footnote, design: .monospaced) : .footnote)
                .foregroundStyle(Theme.textSecondary(theme, rc: rc))
                .fixedSize(horizontal: false, vertical: true)
            if let action = onAdd ?? onDone {
                Button(action: action) {
                    Text(onAdd != nil ? "Add Task" : "Done")
                        .font(Theme.isRetro(theme) ? .system(.headline, design: .monospaced) : .headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent(theme, rc: rc))
            }
        }
    }

    /// What the mode does. In a "This week only" card, a mode that comes back next week
    /// says the card will too, in one line like the others: with the keyboard up, even one
    /// more line pushed Add Task out of the popover.
    private var hint: String {
        guard isThisWeekOnlyCategory else { return mode.hint }
        return switch mode {
        case .carryOver: "Carries over, and this card comes back next week"
        case .repeating: "Comes back every week, and so does this card"
        case .oneTime: mode.hint
        }
    }

    private func selectType(_ option: TaskType) {
        guard option != type else { return }
        if confirmsLeavingGoal && type == .goal {
            pendingType = option
        } else {
            onSelectType(option)
        }
    }

    private func column<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Theme.isRetro(theme) ? "[\(title.uppercased())]" : title.uppercased())
                .font(Theme.isRetro(theme) ? .system(.caption, design: .monospaced).bold() : .caption.bold())
                .foregroundStyle(Theme.textSecondary(theme, rc: rc))
                .accessibilityAddTraits(.isHeader)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func optionButton(_ label: String, symbol: String, color: Color, isSelected: Bool,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            OptionButtonLabel(title: label, symbol: symbol, color: color, isHighlighted: isSelected,
                              theme: theme, rc: rc, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        // Checkbox's checkmark icon would make it read "selected" when it isn't.
        .accessibilityRemoveTraits(isSelected ? [] : .isSelected)
    }
}

// MARK: - Option Button Label

/// The look of the picker's option buttons: a colored icon and label in a rounded box,
/// tinted and outlined in the color when highlighted. Also used for the goal editor's
/// Delete and Save Goal so they match.
struct OptionButtonLabel: View {
    let title: String
    let symbol: String
    let color: Color
    let isHighlighted: Bool
    let theme: AppearanceMode
    let rc: RetroColor
    var alignment: HorizontalAlignment = .center
    var isEnabled = true
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(spacing: 8) {
            if alignment == .center { Spacer(minLength: 0) }
            Image(systemName: symbol)
                .foregroundStyle(isEnabled ? color : Theme.textTertiary(theme, rc: rc))
                .frame(width: 22)
            Text(title)
                .foregroundStyle(isEnabled ? Theme.textPrimary(theme, rc: rc) : Theme.textTertiary(theme, rc: rc))
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
        }
        .font(Theme.isRetro(theme) ? .system(.subheadline, design: .monospaced) : .subheadline)
        .padding(.horizontal, 10)
        .frame(minHeight: 44)
        .background {
            let shape = RoundedRectangle(cornerRadius: Theme.isRetro(theme) ? 2 : 10)
            let highlighted = isHighlighted && isEnabled
            shape.fill(highlighted ? color.opacity(0.18) : Color.clear)
            shape.stroke(highlighted ? color : Theme.textTertiary(theme, rc: rc).opacity(0.4), lineWidth: highlighted ? 1.5 : 1)
        }
        .contentShape(Rectangle())
    }
}
