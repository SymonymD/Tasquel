import SwiftUI

// MARK: - Help Sheet

struct HelpSheet: View {
    var store: ChecklistStore? = nil
    @Environment(\.dismiss) private var dismiss

    private var theme: AppearanceMode { store?.appearanceMode ?? .system }
    private var rc: RetroColor { store?.retroColor ?? .green }
    private var retro: Bool { Theme.isRetro(theme) }

    private let helpSections: [(title: String, items: [(symbol: String, title: String, detail: String)])] = [
        ("Weekly Checklist", [
            ("calendar", "Navigate Weeks", "Use the arrows or tap the calendar icon to jump to any week. Future weeks can be pre-populated. Past weeks can be reviewed."),
            ("square.grid.2x2", "Category Cards", "Tap a card to expand and view all tasks. Tap the collapse arrow to return to grid view. Long-press for options: save, remove, or delete."),
            ("pencil", "Edit Mode", "Tap the pencil icon to enter edit mode. From here you can add categories, change task modes, and delete tasks using the inline icons."),
        ]),
        ("Task Modes", [
            ("arrow.uturn.forward", "Carry Over", "Default mode. If not completed by end of the week, it rolls forward to the next week. Completed tasks do not carry over."),
            ("repeat", "Repeating", "Appears every week automatically regardless of completion. Great for recurring habits. Resets to unchecked each new week."),
            ("1.circle", "One-Time", "This week only. Will not carry forward or repeat, whether completed or not."),
            ("hand.draw", "Changing Modes", "In edit mode, use the inline mode icons on each task. Or long-press a task for the context menu. Double-tap a task title to edit it inline."),
        ]),
        ("Task Types", [
            ("checkmark.circle", "Checkbox", "Standard task — tap the circle to mark complete. This is the default type for all new tasks."),
            ("target", "Goal", "Track progress toward a numeric target (e.g. 50 push-ups). Tap the progress ring to update. Auto-completes when the target is reached."),
            ("arrow.left.arrow.right", "Switching Types", "Long-press a task and choose a type from the context menu."),
        ]),
        ("Sub-Tasks", [
            ("list.bullet.indent", "Adding Sub-Tasks", "Tasks with sub-tasks show them inline when expanded. Type in the field below to add more. Long-press a task to add the first sub-task."),
            ("checkmark.circle", "Completing Sub-Tasks", "Tap any sub-task's circle to check it off. Sub-task progress shows as a count on the parent task."),
        ]),
        ("Managing Categories", [
            ("square.and.arrow.down", "Save for Future", "Long-press a category card and choose \"Save for Future Use\" to add it to your template library."),
            ("trash", "Removing Categories", "Long-press a category card to remove from this week only or delete entirely including from saved categories."),
        ]),
        ("Upcoming Features", [
            ("calendar.badge.plus", "Calendar Integration", "A future paid upgrade will allow importing your personal calendar events directly into Tasquel as tasks."),
        ]),
    ]

    var body: some View {
        NavigationStack {
            Group {
                if retro {
                    retroHelp
                } else {
                    standardHelp
                }
            }
            .navigationTitle(retro ? "> HELP_" : "How to Use Tasquel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(retro ? "[DONE]" : "Done") { dismiss() }
                        .font(retro ? .system(.subheadline, design: .monospaced).bold() : .body)
                        .foregroundStyle(retro ? Theme.accent(theme, rc: rc) : .blue)
                }
            }
        }
    }

    private var darkHelpBg: Color? { Theme.isDark(theme) ? Theme.cardFill(theme) : nil }

    @ViewBuilder
    private func helpSection(_ index: Int) -> some View {
        let section = helpSections[index]
        Section(section.title) {
            ForEach(section.items, id: \.title) { item in
                HelpRow(symbol: item.symbol, title: item.title, detail: item.detail)
            }
        }
    }

    private var standardHelp: some View {
        List {
            helpSection(0)
            helpSection(1)
            helpSection(2)
            helpSection(3)
            helpSection(4)
            helpSection(5)
        }
    }

    private var retroHelp: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(helpSections, id: \.title) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text("[\(section.title.uppercased())]")
                            .font(.system(.caption, design: .monospaced).bold())
                            .foregroundStyle(Theme.textTertiary(theme, rc: rc))
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(section.items, id: \.title) { item in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("> \(item.title)")
                                        .font(.system(.subheadline, design: .monospaced).bold())
                                        .foregroundStyle(Theme.accent(theme, rc: rc))
                                    Text(item.detail)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(Theme.textSecondary(theme, rc: rc))
                                }
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Theme.cardFill(theme))
                                .overlay(RoundedRectangle(cornerRadius: 2).stroke(Theme.cardBorder(theme, rc: rc), lineWidth: 1))
                        )
                    }
                }
            }
            .padding(16)
        }
        .background(Theme.background(theme))
    }
}

// MARK: - Help Row

struct HelpRow: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbol).font(.subheadline.bold())
            Text(detail).font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
