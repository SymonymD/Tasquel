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
            ("calendar", "Navigate Weeks", "Swipe left or right, use the arrows, or tap the calendar icon to jump to any week. Future weeks can be pre-populated. Past weeks can be reviewed."),
            ("calendar.badge.clock", "Calendar Events", "Turn on Show Calendar Events in Settings, then tap the calendar button next to Settings to see the week's events. Tap an event to open it in Calendar. Choose which calendars to include in Settings; events stay on your device."),
            ("square.grid.2x2", "Category Cards", "Tap a card to open it and see its tasks; tap the collapse icon to close it. The button at the top right opens or closes all cards. Long-press a card to save it for future use or delete it."),
            ("pencil", "Edit Mode", "Tap the pencil in the bottom bar to add or delete categories; cards stay closed while editing. Deleting a category removes it from this week on, and you can add it back from Add Category. To edit one card's tasks, tap the edit icon inside that open card."),
        ]),
        ("Task Types", [
            ("checkmark.circle", "Checkbox", "Default for new tasks. Tap the circle to mark it complete. It stays in this week only."),
            ("arrow.uturn.forward", "Carry Over", "If not completed by end of the week, it rolls forward to the next week. Completed tasks do not carry over."),
            ("repeat", "Repeating", "Appears every week automatically regardless of completion. Great for recurring habits. Resets to unchecked each new week."),
            ("target", "Goal", "Track progress toward a target, like 50 push-ups or 2 hours. Auto-completes when the target is reached."),
            ("list.bullet", "List", "A checklist like Groceries. Type an item and press Return to start the next one. The list checks itself off when every item is checked; otherwise it carries over with only the unchecked items."),
            ("hand.draw", "Changing Types", "Tap a task's type icon, or long-press the task, to choose Checkbox, Carry Over, Repeating, Goal or List. In edit mode, a trash can deletes the task. Double-tap a task title to rename it."),
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
            ForEach(helpSections.indices, id: \.self) { helpSection($0) }
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
