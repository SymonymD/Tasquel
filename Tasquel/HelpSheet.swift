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
            ("calendar", "Navigate Weeks", "Swipe left or right on your cards, or use the arrows at the bottom. To jump to any week, tap the calendar button between the arrows, then Weeks, and pick a week. To come back to this week, tap the Tasquel logo at the top left, or This Week in the calendar. Future weeks can be filled in ahead of time. Past weeks are view only, as the line under the week says. Tasquel opens on the current week."),
            ("capsule", "Days of the Week", "The pills under the week's name are its days. Days gone by are green, and today shows its date."),
            ("calendar.day.timeline.left", "Week Start", "Weeks start on Monday. Choose Sunday in Settings ▸ Week."),
            ("calendar.badge.clock", "Calendar Events", "Turn on Show Calendar Events in Settings. The calendar button between the week arrows turns green; tap it to see the week's events. Swipe the events left or right to change week, and your cards move with them. Tap an event to see that day in Calendar. Choose which calendars to include in Settings; events stay on your device."),
            ("square.grid.2x2", "Category Cards", "Tap a card to open it; tap its name or the close button to close it. The ring shows how much of the card is done. Hold and drag a closed card to move it."),
            ("arrow.down.right.and.arrow.up.left", "Close All Cards", "Pull the cards down from the top, like refreshing a page, and let go to close every open card. The button at the top right also opens or closes them all."),
            ("arrow.up.arrow.down", "Sort Cards", "In Settings ▸ Categories, Sort Cards can put recently or least recently edited cards first. Sorted cards rearrange only when you open Tasquel, change week or close every card, and can't be dragged. Choose Manual to move them yourself."),
        ]),
        ("Tasks", [
            ("plus.circle", "Adding Tasks", "Tap Add Task at the bottom of an open card and type. Press Return to add the task and start the next one; press Return on an empty line to finish. The button at the end of the field picks the new task's type and mode."),
            ("sparkles", "Smart Add", "With Apple Intelligence on, type a task in your own words and tap the sparkles button: \"Run 3x per week\" becomes a repeating goal of 3, \"Swim Mon, Wed, Fri\" a goal of 3, \"Meditate 10 min daily\" a goal of 70 minutes that counts 10 a tap, \"Call the bank on Friday\" a task for this week only, \"Fix the bike when I can\" a carry-over task, and \"Groceries: milk, eggs\" a list with those items. Any type or mode you picked is kept. A note under the new task says what was added, with Undo. It works on your device; nothing is sent anywhere. Return adds exactly what you typed."),
            ("slider.horizontal.3", "Type and Mode", "Every task has a type and a mode. Tap the icons at the end of a task to change either."),
            ("checkmark.circle", "Checkbox", "A task to tick off. Tap the + at the end of a task to add sub-tasks."),
            ("target", "Goal", "Progress toward a target, like 50 push-ups or 2 hours. Tap + under the bar to count one step (a day's share of the target: 70 minutes goes by 10, 100 push-ups by 15) or − to take one back. To change the target or the step, tap the sliders beside the bar. Days, 5 or 7, is how many days the goal is spread over: with no step set, a step is the target divided by the days, so 70 minutes over 5 days goes by 14. Type a step and the target becomes the step times the days (a 20-minute step over 7 days makes 140 minutes); type the target and the step goes back to automatic. Smart Add fills Days in for \"10 min daily\". It checks itself off when you reach the target, and + keeps counting past it."),
            ("list.bullet", "List", "A checklist like Groceries. Tap Add Item under it, type an item and press Return to start the next one. The list checks itself off when every item is checked. Tap the arrow beside its type button to fold the items away (it shows how many are checked), and again to open it. A folded list stays folded next week too."),
            ("keyboard.chevron.compact.down", "Closing the Keyboard", "Tap the round keyboard button at the bottom right, or swipe down on your cards. Anything you've typed is kept: a new task or sub-task is added, and the keyboard button also sets a goal amount you've typed."),
            ("hand.draw", "Rename, Reorder and Delete", "Tap a task's or sub-task's name to rename it. Tap a card's edit button to show a trash can and a handle on each task (drag a task by its handle to move it), and a red − on each sub-task or list item. Deleting doesn't ask: tap Undo in the message that appears. A goal's editor also has Delete Task. Tap the green checkmark when you're done to add tasks again."),
        ]),
        ("After This Week", [
            ("1.circle", "One-Time", "This week only. New tasks start as One-Time; a type or mode you pick stays picked for the next task you add to that card, and the field says which (like Add Repeating Goal)."),
            ("arrow.uturn.forward", "Carry Over", "If it isn't finished by the end of the week, it moves to next week. A list or sub-tasks bring only what's left; a goal keeps its progress."),
            ("repeat", "Repeating", "Comes back every week, unchecked, whether or not you finished it. A repeating goal starts from zero; a repeating list keeps its items, with checked ones still checked."),
        ]),
        ("Sub-Tasks", [
            ("plus", "Adding Sub-Tasks", "Tap the + at the end of a checkbox task, type a sub-task and press Return to add another. Press Return on an empty line to finish."),
            ("checkmark.circle", "Completing Sub-Tasks", "Tap a sub-task's circle to check it off. When every sub-task is checked, the task checks itself off, and checking the task checks all its sub-tasks. Unchecking the task right away puts back the checks it had."),
        ]),
        ("Managing Categories", [
            ("square.grid.2x2", "Edit Mode", "Tap Edit at the bottom right to add or delete categories. Open cards close while editing and reopen when you tap Done. In Add Category, turn on This week only for a category you won't need next week."),
            ("calendar", "This Week Only", "A This week only category doesn't come back next week. Open its card and tap its edit button to turn This week only on or off. Turning it on makes its carry-over and repeating tasks one-time; adding a carry-over or repeating task to it turns it off."),
            ("character.cursor.ibeam", "Rename a Category", "Open a card and tap its edit button, then edit the name, or tap the icon to change it. The new name applies to this week and later weeks. The icon can also be any emoji: pick Choose Emoji… from the icon menu."),
            ("trash", "Deleting Categories", "Tap Edit, then the red − on a card. Once you confirm, it's deleted with its tasks from this week on (a This week only category, from this week alone). Past weeks keep their history. Tap Undo in the message to bring it back. The category stays in Saved Categories (unless you removed it there), so you can add it again, but its tasks won't return."),
            ("square.stack", "Saved Categories", "Add Category offers your saved categories; tap Edit Saved Categories there to rename, re-icon or remove them. Reorder them in Settings ▸ Saved Categories. A new name or icon also applies to the category's card this week and in later weeks. A category you add, also one for this week only, is saved automatically."),
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
                // A plain glass capsule rather than the blue confirm button (user's choice).
                ToolbarItem(placement: .topBarTrailing) {
                    if retro {
                        Button("[DONE]") { dismiss() }
                            .font(.system(.subheadline, design: .monospaced).bold())
                            .foregroundStyle(Theme.accent(theme, rc: rc))
                    } else {
                        SheetDoneButton { dismiss() }
                    }
                }
            }
        }
        // A sheet doesn't inherit the app's appearance setting.
        .preferredColorScheme(store?.colorScheme)
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
        .listRowBackground(darkHelpBg)
    }

    private var standardHelp: some View {
        List {
            ForEach(helpSections.indices, id: \.self) { helpSection($0) }
        }
        .scrollContentBackground(Theme.isDark(theme) ? .hidden : .automatic)
        .background(Theme.isDark(theme) ? Theme.background(theme) : Color.clear)
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
