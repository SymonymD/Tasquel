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
            ("calendar", "Navigate Weeks", "Swipe left or right, use the arrows, or tap the calendar icon to jump to any week. Future weeks can be filled in ahead of time. Past weeks are read-only. Tasquel opens on the current week."),
            ("calendar.badge.clock", "Calendar Events", "Turn on Show Calendar Events in Settings, then tap the calendar button next to Settings to see the week's events. Tap an event to open it in Calendar. Choose which calendars to include in Settings; events stay on your device."),
            ("square.grid.2x2", "Category Cards", "Tap a card to open it and see its tasks; tap the collapse icon to close it. The button at the top right opens or closes all cards. The ring shows how much of the card is done. Hold and drag a closed card to move it."),
        ]),
        ("Tasks", [
            ("slider.horizontal.3", "Type and Mode", "Every task has a type and a mode. Tap the icons at the end of a task to change either, or long-press the task."),
            ("checkmark.circle", "Checkbox", "A task to tick off. Tap + next to its icons to add sub-tasks."),
            ("target", "Goal", "Progress toward a target, like 50 push-ups or 2 hours. Use Add Progress as you go; it checks itself off when you reach the target."),
            ("list.bullet", "List", "A checklist like Groceries. Type an item and press Return to start the next one. The list checks itself off when every item is checked."),
            ("hand.draw", "Rename and Delete", "Double-tap a task title to rename it. Tap a card's edit button to show a trash can on each task."),
        ]),
        ("After This Week", [
            ("1.circle", "One-Time", "This week only. New tasks start as One-Time."),
            ("arrow.uturn.forward", "Carry Over", "If it isn't finished by the end of the week, it moves to next week. A list or sub-tasks bring only what's left; a goal keeps its progress."),
            ("repeat", "Repeating", "Comes back every week, unchecked, whether or not you finished it. A repeating goal starts from zero; a repeating list keeps its items, with checked ones still checked."),
        ]),
        ("Sub-Tasks", [
            ("plus", "Adding Sub-Tasks", "Tap + on a checkbox task, type a sub-task and press Return to add another. Press Return on an empty line to finish."),
            ("checkmark.circle", "Completing Sub-Tasks", "Tap a sub-task's circle to check it off. When every sub-task is checked, the task checks itself off."),
        ]),
        ("Managing Categories", [
            ("square.grid.2x2", "Edit Mode", "Tap the grid button in the bottom bar to add or delete categories. Cards stay closed while editing."),
            ("character.cursor.ibeam", "Rename a Category", "Open a card and tap its edit button, then edit the name, or tap the icon to change it. The new name applies to this week and future weeks."),
            ("trash", "Deleting Categories", "Deleting a category removes it from this week on. Past weeks keep their history, and you can add it back from Add Category."),
            ("square.stack", "Saved Categories", "Add Category offers your saved categories. Edit, reorder or delete them in Settings ▸ Saved Categories. A category you add for every week is saved automatically."),
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
