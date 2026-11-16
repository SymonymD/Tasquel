import SwiftUI

/// What's New: the features a version brings, shown in a sheet from the header's "What's New?"
/// button (for someone who updated, `ChecklistStore.showsWhatsNewButton`) and from Settings
/// (the user asked, 2026-11-14). Write each in plain words: what it is and where to find it.
enum WhatsNew {
    /// The version these items are for. A later version with its own items changes it, and
    /// those who update to it get the button again.
    static let version = "1.1"
    /// Opened this many times from the header's button, the button goes; Settings keeps it.
    static let buttonOpens = 2

    struct Item: Identifiable {
        let symbol: String
        let title: String
        let detail: String
        let color: Color
        var id: String { title }
    }

    static let items: [Item] = [
        Item(symbol: "calendar", title: "Days for Tasks",
             detail: "Give a task a day of the week in its options, or type “on Friday” in Smart Add. On its day it reads Today, and its card gives a little wiggle when you open the app. A new task for a day that's already gone by this week goes into next week.",
             color: .blue),
        Item(symbol: "clock", title: "Dates and Reminders",
             detail: "Give a task a date: a one-time task goes into that week, and a carry-over one comes along until then. The date shows after its name, and a notification reminds you the day before. Smart Add spots dates you type.",
             color: .green),
        Item(symbol: "pin.fill", title: "Pins",
             detail: "Keep up to two cards first in the grid, and up to two tasks at the top of a card. Pin them in edit mode; a pinned task shows a pin.",
             color: .orange),
        Item(symbol: "circle.dashed", title: "Progress Rings",
             detail: "A card's ring fills as you go, counting each step of a goal and each item of a list.",
             color: .pink),
        Item(symbol: "square.on.square", title: "Duplicates Flagged",
             detail: "Tasks or list items with the same name in one card are marked, so nothing gets done twice.",
             color: .red),
        Item(symbol: "delete.left", title: "Clear to Delete",
             detail: "Clear a task's, sub-task's or list item's name and press Return to delete it. Undo brings it back.",
             color: .purple),
        Item(symbol: "leaf.fill", title: "Seasonal Look",
             detail: "Settings ▸ Appearance ▸ Seasonal changes Tasquel's colors with the season. In every look, the logo dresses up for the holidays, and Retro's text fields now look like DOS.",
             color: .mint),
        Item(symbol: "house.fill", title: "Back to This Week",
             detail: "On another week, tap the green house in the bottom bar. Go to Week now rings the days your tasks are dated or set for.",
             color: .teal),
        Item(symbol: "bolt.fill", title: "Faster",
             detail: "Scrolling, opening cards and checking off tasks are much quicker, even with lots of tasks.",
             color: .yellow),
        Item(symbol: "questionmark.circle", title: "Help in Tabs",
             detail: "Help is now in tabs, starting with answers to common questions, so you can go straight to an answer. Swipe between them.",
             color: .cyan),
        Item(symbol: "sparkles", title: "And More",
             detail: "Add several categories in one go. Escape on a keyboard cancels a rename, and past weeks no longer push the cards down with a banner. Fixes for VoiceOver, iPad and smaller iPhones.",
             color: .indigo),
    ]

    /// Whether version `a` is older than `b`, comparing numbers ("1.0.3" < "1.1" < "1.10").
    static func isVersion(_ a: String, olderThan b: String) -> Bool {
        let x = a.split(separator: ".").map { Int($0) ?? 0 }, y = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(x.count, y.count) {
            let l = i < x.count ? x[i] : 0, r = i < y.count ? y[i] : 0
            if l != r { return l < r }
        }
        return false
    }
}

/// The What's New sheet. From the header's button it adds a note that Settings has it too
/// (`lastFromButton`: the button won't show again).
struct WhatsNewSheet: View {
    let store: ChecklistStore
    /// Opened from the header's button, and how: nil from Settings.
    var fromButton: FromButton? = nil
    @Environment(\.dismiss) private var dismiss

    enum FromButton: Identifiable {
        case again, lastTime
        var id: Self { self }
    }

    private var theme: AppearanceMode { store.appearanceMode }
    private var rc: RetroColor { store.retroColor }
    private var retro: Bool { Theme.isRetro(theme) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: retro ? .leading : .center, spacing: 6) {
                    Text(retro ? "> WHAT'S_NEW" : "What's New")
                        .font(retro ? .system(.title2, design: .monospaced).bold() : .largeTitle.bold())
                        .foregroundStyle(Theme.textPrimary(theme, rc: rc))
                        .accessibilityAddTraits(.isHeader)
                    Text(retro ? "// TASQUEL \(WhatsNew.version)" : "in Tasquel \(WhatsNew.version)")
                        .font(retro ? .system(.subheadline, design: .monospaced) : .title3)
                        .foregroundStyle(Theme.textSecondary(theme, rc: rc))
                }
                .frame(maxWidth: .infinity, alignment: retro ? .leading : .center)
                .padding(.top, 36)
                VStack(alignment: .leading, spacing: 22) {
                    ForEach(WhatsNew.items) { item in row(item) }
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 24)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { footer }
        .background((Theme.hasOwnBackground(theme) ? Theme.background(theme) : Color(.systemBackground)).ignoresSafeArea())
        // A sheet doesn't inherit the app's appearance setting.
        .preferredColorScheme(store.colorScheme)
    }

    private func row(_ item: WhatsNew.Item) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: item.symbol)
                .font(.title2)
                .foregroundStyle(retro || Theme.isSeasonal(theme) ? Theme.accent(theme, rc: rc) : item.color)
                .frame(width: 36)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(retro ? .system(.subheadline, design: .monospaced).bold() : .headline)
                    .foregroundStyle(Theme.textPrimary(theme, rc: rc))
                Text(item.detail)
                    .font(retro ? .system(.caption, design: .monospaced) : .subheadline)
                    .foregroundStyle(Theme.textSecondary(theme, rc: rc))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var footer: some View {
        VStack(spacing: 12) {
            if let fromButton {
                Text(fromButton == .lastTime
                     ? "That's the last time the What's New button shows. You can always find this in Settings ▸ Help ▸ What's New."
                     : "You can also find this anytime in Settings ▸ Help ▸ What's New.")
                    .font(retro ? .system(.caption, design: .monospaced) : .footnote)
                    .foregroundStyle(Theme.textSecondary(theme, rc: rc))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if retro {
                Button { dismiss() } label: {
                    Text("[CONTINUE]")
                        .font(.system(.headline, design: .monospaced))
                        .foregroundStyle(Theme.accent(theme, rc: rc))
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .overlay(RoundedRectangle(cornerRadius: 2).stroke(Theme.accent(theme, rc: rc), lineWidth: 1))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Continue")
            } else {
                Button { dismiss() } label: {
                    Text("Continue").font(.headline).frame(maxWidth: .infinity, minHeight: 34)
                        .foregroundStyle(Theme.onAccent(theme))  // dark on Seasonal's light accent at night
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent(theme, rc: rc))
                .controlSize(.large)
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background((Theme.hasOwnBackground(theme) ? Theme.background(theme) : Color(.systemBackground)).ignoresSafeArea())
    }
}
