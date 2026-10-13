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
        Task {
            await calendar.requestAccess()
            guard calendar.isAuthorized else {
                store.setCalendarEventsEnabled(false)
                return
            }
            // First time (or every saved calendar is gone): select the user's own calendars.
            store.setSelectedCalendarIDs(calendar.effectiveSelection(store.selectedCalendarIDs))
            store.setCalendarEventsEnabled(true)
        }
    }
}

// MARK: - Calendar Picker

/// Which calendars feed the Events card, grouped by account.
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
        if ids.contains(id) { ids.remove(id) } else { ids.insert(id) }
        // Keep the account/title order stable in the saved list.
        store.setSelectedCalendarIDs(calendar.availableCalendars.map(\.id).filter { ids.contains($0) })
    }
}
