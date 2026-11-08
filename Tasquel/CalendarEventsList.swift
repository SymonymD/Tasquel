import SwiftUI

// MARK: - Calendar Events List

/// The viewed week's calendar events, the Events side of the calendar sheet. Read-only;
/// tapping an event opens the Calendar app at that event's date.
struct CalendarEventsList: View {
    let store: ChecklistStore
    /// "This Week's Events", or which week they're for.
    let title: String
    /// The week's events by day, or nil while loading.
    let days: [EventDay]?
    let onOpen: (CalendarEvent) -> Void

    private var theme: AppearanceMode { store.appearanceMode }
    private var rc: RetroColor { store.retroColor }
    private var retro: Bool { Theme.isRetro(theme) }
    private var design: Font.Design { retro ? .monospaced : .default }

    /// Each event once (multi-day events appear under several days).
    private var eventCount: Int {
        Set((days ?? []).flatMap(\.events).map(\.event.id)).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(retro ? "[\(title.uppercased())]" : title)
                    .font(.system(.subheadline, design: design).weight(.semibold))
                    .foregroundStyle(Theme.textPrimary(theme, rc: rc))
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if days != nil {
                    Text(eventCount == 1 ? "1 event" : "\(eventCount) events")
                        .font(.system(.caption, design: design))
                        .foregroundStyle(Theme.textSecondary(theme, rc: rc))
                }
            }
            eventList
        }
    }

    @ViewBuilder
    private var eventList: some View {
        VStack(alignment: .leading, spacing: 10) {
            if days == nil {
                ProgressView().frame(maxWidth: .infinity)
            } else if eventCount == 0 {
                Text(retro ? "> nothing scheduled" : "Nothing scheduled this week.")
                    .font(.system(.subheadline, design: design))
                    .foregroundStyle(Theme.textTertiary(theme, rc: rc))
            }
            ForEach(days ?? []) { day in
                VStack(alignment: .leading, spacing: 4) {
                    Text(dayTitle(day.date))
                        .font(.system(.caption, design: design).weight(.semibold))
                        .foregroundStyle(Calendar.current.isDate(day.date, inSameDayAs: store.currentDate) ? Theme.accent(theme, rc: rc) : Theme.textSecondary(theme, rc: rc))
                    ForEach(day.events) { dayEvent in
                        Button {
                            onOpen(dayEvent.event)
                        } label: {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Circle().fill(dayEvent.event.color).frame(width: 8, height: 8)
                                Text(dayEvent.timeLabel)
                                    .font(.system(.caption, design: design).monospacedDigit())
                                    .foregroundStyle(Theme.textSecondary(theme, rc: rc))
                                    .frame(width: 66, alignment: .leading)
                                Text(dayEvent.event.title)
                                    .font(.system(.subheadline, design: design))
                                    .foregroundStyle(Theme.textPrimary(theme, rc: rc))
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                                Image(systemName: "arrow.up.forward.app")
                                    .font(.caption)
                                    .foregroundStyle(Theme.textTertiary(theme, rc: rc))
                            }
                            .contentShape(Rectangle())
                        }
                        // No long-press gesture here: in a scrolling list it claimed every
                        // touch, so the list couldn't scroll (and a swipe up opened the event).
                        .buttonStyle(EventButtonStyle())
                        .accessibilityLabel("\(dayEvent.event.title), \(dayEvent.timeLabel)")
                        .accessibilityHint("Opens Calendar")
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func dayTitle(_ date: Date) -> String {
        let title = date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
        return retro ? title.uppercased() : title
    }
}

/// Like `.plain`, dimmed while pressed.
private struct EventButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.6 : 1)
    }
}
