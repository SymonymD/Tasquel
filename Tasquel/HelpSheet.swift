import SwiftUI

// MARK: - Help Sheet

struct HelpSheet: View {
    var store: ChecklistStore? = nil
    @Environment(\.dismiss) private var dismiss

    private var theme: AppearanceMode { store?.appearanceMode ?? .system }
    private var rc: RetroColor { store?.retroColor ?? .green }
    private var retro: Bool { Theme.isRetro(theme) }

    /// The guide in tabs, so an answer is a tap away rather than a long scroll (the user
    /// asked, 2026-11-14): a short tab name, the section's title, and its entries.
    private let helpSections: [(tab: String, title: String, items: [(symbol: String, title: String, detail: String)])] = [
        // The questions six new users came with (2026-11-14), answered first.
        ("Q&A", "Questions", [
            ("lightbulb", "Is there a Someday list?", "Make a card for it, like Ideas or Someday, and add each idea as Carry Over: it comes along every week until you check it off or delete it."),
            ("calendar.badge.plus", "How do I plan next week?", "Tap the › arrow at the bottom, or swipe, to go to next week and add tasks there. Or give a new task a day that has already gone by this week: it goes into next week, on that day."),
            ("arrow.uturn.forward", "Will an unfinished task disappear?", "A One-Time task stays behind in its week when the week ends. Make it Carry Over to bring it along until it's done, or Repeating to have it every week: tap the icons at the end of the task."),
            ("calendar", "Is a date a deadline?", "A date is a task's last day, shown after its name. A One-Time task goes into the week of its date. A Carry Over task comes along every week until then: in Smart Add, \"by Dec 12\" or \"due 12/12\" makes one. A reminder comes at 9 AM the day before, and the day after, it's gone."),
            ("checkmark.circle", "Where do finished tasks go?", "They stay checked in their week. Tap the ‹ arrow to look back at past weeks, which are view only."),
            ("character.cursor.ibeam", "How do I rename a card?", "Open the card and tap its edit button, the pencil, then edit its name or tap its icon."),
            ("sparkles", "Can I type a task in my own words?", "With Apple Intelligence on, type it and tap the sparkles button (Smart Add): \"Gym Mon, Wed, Fri\" or \"Call Mom tomorrow\". Return adds exactly what you typed. Pasting several lines adds a task for each."),
            ("repeat", "Can a task repeat every month?", "Not yet: Repeating means every week. For a monthly bill, add it in the week it's due, with its date."),
            ("person.2", "Can I share a list, or see it on my iPad?", "Your tasks stay on this device: Tasquel doesn't share or sync them. If you'd use that, say so in Settings ▸ Feature Ideas."),
        ]),
        ("Weeks", "Weekly Checklist", [
            ("calendar", "Navigate Weeks", "Swipe left or right on your cards, or use the arrows at the bottom. To jump to any week, tap the calendar button between the arrows, then Weeks, and pick a week. Days with a task's date have a purple ring, and days with a day task a green one. To come back to this week, tap the Tasquel logo at the top left, the green house that comes out of the arrows on another week (to their left on a later week, where Edit is on an earlier one), or This Week in the calendar. (In late December the logo wears string lights for two weeks, then confetti for New Year's week.) Future weeks can be filled in ahead of time. Past weeks are view only: their checkboxes are dimmed and there's no Edit. Tasquel opens on the current week."),
            ("capsule", "Days of the Week", "The pills under the week's name are its days. Days gone by are blue, and today is green. Tap one to see that day's tasks; tap it again, or Show All, to see every task. Today's also shows tasks whose day has gone by unfinished."),
            ("calendar.day.timeline.left", "Week Start", "Weeks start on Monday. Choose Sunday in Settings ▸ Week."),
            ("calendar.badge.clock", "Calendar Events", "Turn on Show Calendar Events in Settings. The calendar button between the week arrows turns green; tap it to see the week's events. Swipe the events left or right to change week, and your cards move with them. Tap an event to see that day in Calendar. Choose which calendars to include in Settings; events stay on your device."),
            ("leaf", "Seasonal Look", "Settings ▸ Appearance ▸ Seasonal dresses Tasquel for spring, summer, fall or winter, and changes with the season (south of the equator, the other way round). Each season has a light and a dark look that follows your phone's setting."),
        ]),
        ("Cards", "Category Cards", [
            ("square.grid.2x2", "Category Cards", "Tap a card to open it; tap its name or the close button to close it. The ring shows how much of the card is done: goals, lists and sub-tasks fill their part as you go. Hold and drag a closed card to move it."),
            ("arrow.down.right.and.arrow.up.left", "Close All Cards", "Pull the cards down from the top, like refreshing a page, and let go to close every open card. The button at the top right also opens or closes them all."),
            ("arrow.up.arrow.down", "Sort Cards", "In Settings ▸ Categories, Sort Cards can put recently or least recently edited cards first. Sorted cards rearrange only when you open Tasquel, change week or close every card, and can't be dragged. Choose Manual to move them yourself."),
            ("square.grid.2x2", "Edit Mode", "Tap Edit at the bottom right to add or delete categories: Add Category is the first tile. Open cards close while editing and reopen when you tap Done. In Add Category, add as many as you like, then tap Done. Creating one you won't need next week, turn on Just this week before Add Category."),
            ("pin.circle", "Pin a Card", "Tap Edit, then the pin at a card's top left to keep it first, whatever Sort Cards says. Up to two cards can be pinned; a pinned card shows a pin under its name. Tap the pin again to unpin it, and it goes back to its place."),
            ("calendar", "Just This Week", "A Just this week category doesn't come back next week. Turn it on as you create the category, or open its card, tap its edit button, and tap Just this week beside Completed. Turning it on makes its carry-over and repeating tasks one-time; adding a carry-over or repeating task to it turns it off."),
            ("character.cursor.ibeam", "Rename a Category", "Open a card and tap its edit button, then edit the name, or tap the icon to change it. The new name applies to this week and later weeks. The icon can also be any emoji: pick Choose Emoji… from the icon menu."),
            ("trash", "Deleting Categories", "Tap Edit, then the red − on a card. Once you confirm, it's deleted with its tasks from this week on (a This week only category, from this week alone). Past weeks keep their history. Tap Undo in the message to bring it back. The category stays in Saved Categories (unless you removed it there), so you can add it again, but its tasks won't return."),
            ("square.stack", "Saved Categories", "Add Category offers your saved categories; tap Edit beside Saved Categories there to rename, re-icon or remove them. Reorder them in Settings ▸ Saved Categories. A new name or icon also applies to the category's card this week and in later weeks. A category you add, also one for this week only, is saved automatically."),
        ]),
        ("Tasks", "Tasks", [
            ("plus.circle", "Adding Tasks", "Tap Add Task at the bottom of an open card and type. Press Return to add the task and start the next one; press Return on an empty line to finish. The button at the end of the field picks the new task's type and mode."),
            ("sparkles", "Smart Add", "With Apple Intelligence on, type a task in your own words and tap the sparkles button: \"Run 3x per week\" becomes a repeating goal of 3, \"Swim Mon, Wed, Fri\" a goal of 3, \"Meditate 10 min daily\" a goal of 70 minutes that counts 10 a tap, \"Call the bank on Friday\" a task for this week only, \"Fix the bike when I can\" a carry-over task, and \"Groceries: milk, eggs\" a list with those items. Any type or mode you picked is kept; with List picked, words in parts make its name and items (\"Go to the zoo and buy a panda shirt\"). A note under the new task says what was added, with Undo. It works on your device; nothing is sent anywhere. Return adds exactly what you typed. A date in your words, like \"Exam 12/15\", isn't counted as numbers: the task is added as typed, and the message under it asks whether to make it the task's date. Tap Set Date and it is, and the date leaves the name."),
            ("hand.draw", "Rename, Reorder and Delete", "Tap a task's or sub-task's name to rename it; clear the name and press Return to delete it. On a keyboard, Escape puts the old name back. Renaming a carried-over or repeating task in a later week changes only its name there: it still gets what changes in the week before, like items checked off or added. Tap a card's edit button to show a trash can and a handle on each task (drag a task by its handle to move it), and a red − on each sub-task or list item. Deleting doesn't ask: tap Undo in the message that appears. A carry-over or repeating task deleted from a later week stays out of it; to bring it back, pick its mode again (tap its type and mode button) in the week it comes from. A goal's editor also has Delete Task. Tap the green checkmark when you're done to add tasks again."),
            ("keyboard.chevron.compact.down", "Closing the Keyboard", "Tap the round keyboard button at the bottom right, or swipe down on your cards. Anything you've typed is kept: a new task or sub-task is added, and the keyboard button also sets a goal amount you've typed."),
            ("square.on.square", "Duplicates", "A task with the same name as another in its card, or an item with the same name as another in its list, is marked Duplicate (capitals and extra spaces don't count; the same name on different days isn't a duplicate). When you add one, a note under it says so: tap Undo to take it back."),
            ("pin", "Pin a Task", "Tap a card's edit button, then the pin on a task to keep it at the top of the card. Up to two tasks a card can be pinned; tap a pin again to unpin the task, and it goes back to its place. A pinned task shows a pin after its name, and stays pinned next week too."),
        ]),
        ("Types", "Task Types", [
            ("slider.horizontal.3", "Type and Mode", "Every task has a type and a mode. Tap the icons at the end of a task to change either (in a card's edit mode the clock takes their place)."),
            ("checkmark.circle", "Checkbox", "A task to tick off. Tap the + at the end of a task to add sub-tasks."),
            ("target", "Goal", "Progress toward a target, like 50 push-ups or 2 hours. Tap + under the bar to count one step (a day's share of the target: 70 minutes goes by 10, 100 push-ups by 15) or − to take one back. To change the target or the step, tap the sliders beside the bar. Days, 5 or 7, is how many days the goal is spread over: with no step set, a step is the target divided by the days, so 70 minutes over 5 days goes by 14. Type a step and the target becomes the step times the days (a 20-minute step over 7 days makes 140 minutes); type the target and the step goes back to automatic. Smart Add fills Days in for \"10 min daily\". It checks itself off when you reach the target, and + keeps counting past it."),
            ("list.bullet", "List", "A checklist like Groceries. Tap Add Item under it, type an item and press Return to start the next one. The list checks itself off when every item is checked. Tap the arrow beside its type button to fold the items away (it shows how many are checked), and again to open it. A folded list stays folded next week too."),
            ("plus", "Adding Sub-Tasks", "Tap the + at the end of a checkbox task, type a sub-task and press Return to add another. Press Return on an empty line to finish."),
            ("checkmark.circle", "Completing Sub-Tasks", "Tap a sub-task's circle to check it off. When every sub-task is checked, the task checks itself off, and checking the task checks all its sub-tasks. Unchecking the task right away puts back the checks it had."),
        ]),
        ("Modes", "After This Week", [
            ("1.circle", "One-Time", "This week only. New tasks start as One-Time; a type or mode you pick stays picked for the next task you add to that card, and the field says which (like Add Repeating Goal)."),
            ("arrow.uturn.forward", "Carry Over", "If it isn't finished by the end of the week, it moves to next week. A list or sub-tasks bring only what's left; a goal keeps its progress."),
            ("repeat", "Repeating", "Comes back every week, unchecked, whether or not you finished it. A repeating goal starts from zero; a repeating list keeps its items, with checked ones still checked."),
        ]),
        ("Dates", "Days and Dates", [
            ("calendar", "A Task's Day", "Tap the icons at the end of a task and pick a day under Day. It shows after the task's name (\"Fri\"), tasks with a day come first in their card, in the week's order, and one whose day has gone by unfinished says late. A new task given a day that has already gone by this week goes into next week, on that day (the field says \"for Next Thu\"); given to a task you already have, it isn't late this week. Tap a day at the top to see only its tasks, and the ones with no day, in every card; tasks you add then get that day. Smart Add picks up \"on Friday\", \"by Thursday\", \"tomorrow\" or \"every Monday\". A task that carries over or repeats keeps its day."),
            ("clock", "Dates and Expiration", "For a task you only need until a certain day, like a birthday or a holiday gift list: in its type and mode options (the button beside the task, or beside Add Task while you type), tap the calendar at the end of the days and pick its last day, or a whole week. In a card's edit mode, the clock on the task does the same. A one-time task dated after this week goes into the week of its date, on that day, and the screen goes there with it; a carry-over task carries over until then. A date this week is also its day. A day and a date are one choice: picking a day takes the date away (a repeating task can have both: every Monday until its date). The calendar and date after a task's name (\"Nov 28\") open its date; a day's timer or calendar opens its options. Its circle becomes a ring that fills green as its days go by. The day after, it's gone, and it doesn't carry over or repeat after that (earlier weeks keep it). The clock turns green; tap it to change the date or remove it. At 9 AM the day before its last day, a notification reminds you (Settings ▸ Expiration Reminders)."),
        ]),
    ]

    @State private var tab = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                tabBar
                // Swipe between tabs too.
                TabView(selection: $tab) {
                    ForEach(helpSections.indices, id: \.self) { index in
                        Group {
                            if retro { retroPage(index) } else { standardPage(index) }
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .background((Theme.hasOwnBackground(theme) || retro ? Theme.background(theme) : Color(.systemGroupedBackground)).ignoresSafeArea())
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

    /// The tabs: a row of pills (scrolling sideways at large text sizes), the picked one
    /// filled; Retro's in brackets.
    private var tabBar: some View {
        ScrollViewReader { scroll in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(helpSections.indices, id: \.self) { index in
                        tabButton(index).id(index)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .onChange(of: tab) { _, index in
                withAnimation(.snappy(duration: 0.25)) { scroll.scrollTo(index, anchor: .center) }
            }
        }
    }

    private func tabButton(_ index: Int) -> some View {
        let picked = index == tab
        let name = helpSections[index].tab
        return Button {
            withAnimation(.snappy(duration: 0.25)) { tab = index }
        } label: {
            Group {
                if retro {
                    Text(picked ? "[\(name.uppercased())]" : " \(name.uppercased()) ")
                        .font(.system(.subheadline, design: .monospaced).bold())
                        .foregroundStyle(picked ? Theme.accent(theme, rc: rc) : Theme.textTertiary(theme, rc: rc))
                } else {
                    Text(name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(picked ? Theme.onAccent(theme) : Theme.textPrimary(theme, rc: rc))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background {
                            Capsule().fill(picked ? AnyShapeStyle(Theme.accent(theme, rc: rc)) : AnyShapeStyle(.quaternary))
                        }
                }
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // Named as shown ("Cards"), so Voice Control's "tap Cards" finds it; the section's
        // full title is the hint. Named "Category Cards", the pill's own word didn't work.
        .accessibilityLabel(name)
        .accessibilityHint(helpSections[index].title)
        .accessibilityAddTraits(picked ? .isSelected : [])
    }

    private var darkHelpBg: Color? { Theme.hasOwnBackground(theme) && !Theme.isRetro(theme) ? Theme.cardFill(theme) : nil }

    private func standardPage(_ index: Int) -> some View {
        let section = helpSections[index]
        return List {
            Section(section.title) {
                ForEach(section.items, id: \.title) { item in
                    HelpRow(symbol: item.symbol, title: item.title, detail: item.detail)
                }
            }
            .listRowBackground(darkHelpBg)
        }
        .scrollContentBackground(Theme.hasOwnBackground(theme) ? .hidden : .automatic)
        .contentMargins(.top, 0, for: .scrollContent)
        // The season's color for the icons, not system blue (the 2026-11-15 review).
        .tint(Theme.isSeasonal(theme) ? Theme.accent(theme, rc: rc) : nil)
    }

    private func retroPage(_ index: Int) -> some View {
        let section = helpSections[index]
        return ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("[\(section.title.uppercased())]")
                    .font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(Theme.textTertiary(theme, rc: rc))
                    .accessibilityLabel(section.title)
                    .accessibilityAddTraits(.isHeader)
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(section.items, id: \.title) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("> \(item.title)")
                                .accessibilityLabel(item.title)
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
            .padding(16)
        }
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
