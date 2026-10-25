import SwiftUI
import UIKit

// MARK: - Calendar Settings Rows

/// The Calendar section of Settings: on/off, permission state, and which calendars to show.
/// Used in both the standard and retro Settings layouts.
struct CalendarSettingsRows: View {
    let store: ChecklistStore
    let calendar: CalendarService

    private var theme: AppearanceMode { store.appearanceMode }
    private var rc: RetroColor { store.retroColor }
    private var retro: Bool { Theme.isRetro(theme) }

    var body: some View {
        Toggle(isOn: Binding(
            get: { store.calendarEventsEnabled && calendar.isAuthorized },
            set: { setEnabled($0) }
        )) {
            if retro {
                Text("> Show Calendar Events").font(Theme.bodyFont(theme))
            } else {
                Label("Show Calendar Events", systemImage: "calendar")
            }
        }
        .tint(retro ? Theme.accent(theme, rc: rc) : nil)
        // Without access a tap can't turn it on; the note below says how to allow it.
        .disabled(calendar.authorization == .denied || calendar.authorization == .restricted)

        switch calendar.authorization {
        case .denied, .restricted, .writeOnly:
            VStack(alignment: .leading, spacing: 6) {
                Text(calendar.authorization == .restricted
                     ? "Calendar access is restricted on this device."
                     : "Tasquel doesn't have access to your calendars. Turn on Full Access in Settings to show your events.")
                    .font(retro ? Theme.captionFont(theme) : .footnote)
                    .foregroundStyle(Theme.textSecondary(theme, rc: rc))
                if calendar.authorization != .restricted {
                    Button(retro ? "> Open Settings" : "Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .font(retro ? Theme.bodyFont(theme) : .body)
                }
            }
        case .authorized where store.calendarEventsEnabled:
            NavigationLink {
                CalendarPicker(store: store, calendar: calendar)
            } label: {
                HStack {
                    if retro {
                        Text("> Calendars").font(Theme.bodyFont(theme))
                    } else {
                        Label("Calendars", systemImage: "checklist")
                    }
                    Spacer()
                    Text("\(calendar.effectiveSelection(store.selectedCalendarIDs).count) selected")
                        .font(retro ? Theme.captionFont(theme) : .body)
                        .foregroundStyle(Theme.textSecondary(theme, rc: rc))
                }
            }
        default:
            EmptyView()
        }
    }

    private func setEnabled(_ enabled: Bool) {
        guard enabled else {
            store.setCalendarEventsEnabled(false)
            return
        }
        Task { await Self.turnOn(store: store, calendar: calendar) }
    }

    /// Asks for access if needed and turns events on. The choice is kept even when access
    /// is refused, so allowing it later in the Settings app shows events straight away
    /// (events only show while access is allowed).
    static func turnOn(store: ChecklistStore, calendar: CalendarService) async {
        await calendar.requestAccess()
        store.setCalendarEventsEnabled(true)
        guard calendar.isAuthorized else { return }
        // First time (or every saved calendar is gone): select the user's own calendars.
        store.setSelectedCalendarIDs(calendar.effectiveSelection(store.selectedCalendarIDs))
    }
}

// MARK: - Calendar Picker

/// Which calendars feed the bottom bar's events, grouped by account.
struct CalendarPicker: View {
    let store: ChecklistStore
    let calendar: CalendarService

    private var theme: AppearanceMode { store.appearanceMode }
    private var rc: RetroColor { store.retroColor }
    private var retro: Bool { Theme.isRetro(theme) }
    private var selected: Set<String> { Set(calendar.effectiveSelection(store.selectedCalendarIDs)) }

    var body: some View {
        List {
            ForEach(groupedSources, id: \.self) { source in
                Section(retro ? "[\(source.uppercased())]" : source) {
                    ForEach(calendar.availableCalendars.filter { $0.sourceTitle == source }) { info in
                        Button { toggle(info.id) } label: {
                            HStack(spacing: 12) {
                                Circle().fill(info.color).frame(width: 12, height: 12)
                                Text(info.title)
                                    .font(retro ? Theme.bodyFont(theme) : .body)
                                    .foregroundStyle(Theme.textPrimary(theme, rc: rc))
                                Spacer()
                                if selected.contains(info.id) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Theme.accent(theme, rc: rc))
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selected.contains(info.id) ? .isSelected : [])
                    }
                }
                .listRowBackground(Theme.isDark(theme) ? Theme.cardFill(theme) : nil)
            }
            Section {} footer: {
                Text("At least one calendar stays selected. To hide events, turn off Show Calendar Events.")
            }
        }
        .scrollContentBackground(Theme.isDark(theme) ? .hidden : .automatic)
        .background(Theme.isDark(theme) ? Theme.background(theme) : Color.clear)
        .navigationTitle(retro ? "> CALENDARS_" : "Calendars")
        .navigationBarTitleDisplayMode(.inline)
        .task { await calendar.loadCalendars() }
    }

    private var groupedSources: [String] {
        var seen = Set<String>()
        return calendar.availableCalendars.map(\.sourceTitle).filter { seen.insert($0).inserted }
    }

    private func toggle(_ id: String) {
        var ids = selected
        if ids.contains(id) {
            // An empty selection means "the defaults", so unticking the last one would
            // tick others back on; it stays instead.
            guard ids.count > 1 else { return }
            ids.remove(id)
        } else {
            ids.insert(id)
        }
        // Keep the account/title order stable in the saved list.
        store.setSelectedCalendarIDs(calendar.availableCalendars.map(\.id).filter { ids.contains($0) })
    }
}
