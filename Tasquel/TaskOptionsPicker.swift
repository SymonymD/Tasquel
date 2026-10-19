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
/// Each tap applies right away. For a new task, `onAdd` shows an Add button.
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

    @State private var pendingType: TaskType?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
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
            Text(mode.hint)
                .font(Theme.isRetro(theme) ? .system(.footnote, design: .monospaced) : .footnote)
                .foregroundStyle(Theme.textSecondary(theme, rc: rc))
                .fixedSize(horizontal: false, vertical: true)
            if let onAdd {
                Button(action: onAdd) {
                    Text("Add Task")
                        .font(Theme.isRetro(theme) ? .system(.headline, design: .monospaced) : .headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent(theme, rc: rc))
            }
        }
        .padding(16)
        .frame(minWidth: 300)
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

    var body: some View {
        HStack(spacing: 8) {
            if alignment == .center { Spacer(minLength: 0) }
            Image(systemName: symbol)
                .foregroundStyle(isEnabled ? color : Theme.textTertiary(theme, rc: rc))
                .frame(width: 22)
            Text(title)
                .foregroundStyle(isEnabled ? Theme.textPrimary(theme, rc: rc) : Theme.textTertiary(theme, rc: rc))
                .lineLimit(1)
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
