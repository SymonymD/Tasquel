import SwiftUI

// MARK: - App Info

/// Links and version shown in Settings, kept in one place.
enum AppInfo {
    static let privacyPolicyURL = URL(string: "https://jbfentner.com/tasquel/privacy")!
    static let supportURL = URL(string: "https://jbfentner.com/tasquel/support")!

    /// "1.0 (1)" style values from the app's Info.plist.
    static func version(from info: [String: Any]? = Bundle.main.infoDictionary) -> String {
        info?["CFBundleShortVersionString"] as? String ?? "—"
    }

    static func build(from info: [String: Any]? = Bundle.main.infoDictionary) -> String {
        info?["CFBundleVersion"] as? String ?? "—"
    }
}

// MARK: - Settings Sheet

struct SettingsSheet: View {
    let store: ChecklistStore
    let calendar: CalendarService
    @Environment(\.dismiss) private var dismiss
    @State private var showHelp = false
    @State private var showTour = false

    private var theme: AppearanceMode { store.appearanceMode }
    private var rc: RetroColor { store.retroColor }
    private var retro: Bool { Theme.isRetro(theme) }

    var body: some View {
        NavigationStack {
            Group {
                if retro {
                    retroSettings
                } else {
                    standardSettings
                }
            }
            .navigationTitle(retro ? "> SETTINGS_" : "Settings")
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
            .sheet(isPresented: $showHelp) { HelpSheet(store: store) }
            .sheet(isPresented: $showTour) { OnboardingSheet(store: store, calendar: calendar, isReplay: true) }
            .task {
                calendar.refreshAuthorization()
                await calendar.loadCalendars()
            }
        }
        .preferredColorScheme(store.colorScheme)
    }

    // MARK: - Standard (System/Light/Dark) Settings

    private var darkCardBg: Color? { Theme.isDark(theme) ? Theme.cardFill(theme) : nil }

    private var standardSettings: some View {
        List {
            Section("Appearance") {
                appearanceRows
            }
            .listRowBackground(darkCardBg)
            Section("Week") {
                weekStartRow
            }
            .listRowBackground(darkCardBg)
            Section {
                NavigationLink {
                    SavedCategoriesView(store: store)
                } label: {
                    Label("Saved Categories", systemImage: "square.stack")
                }
                sortPicker
            } header: {
                Text("Categories")
            } footer: {
                Text("Manual: hold and drag cards to move them. Sorted cards rearrange only when you open the app, change week, or close every card, never while you're using them.")
            }
            .listRowBackground(darkCardBg)
            // Hidden entirely while calendar integration is turned off.
            if FeatureAccess.isCalendarUnlocked {
                Section {
                    CalendarSettingsRows(store: store, calendar: calendar)
                } header: {
                    Text("Calendar")
                } footer: {
                    Text("Shows the week's events from the calendar button in the bottom bar. Events stay on your device and are never changed.")
                }
                .listRowBackground(darkCardBg)
            }
            Section {
                Button { showHelp = true } label: {
                    Label("How to Use Tasquel", systemImage: "questionmark.circle")
                }
                Button { showTour = true } label: {
                    Label("Show Welcome Tour", systemImage: "sparkles")
                }
            } header: {
                Text("Help")
            }
            .listRowBackground(darkCardBg)
            Section {
                ComingSoonSurvey(store: store)
            } header: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Coming Soon")
                    Text(Self.comingSoonDescription)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }
            } footer: {
                Text("Tick what you'd use. It's anonymous: only your picks and comment are sent.")
            }
            .listRowBackground(darkCardBg)
            Section("Support") {
                Link(destination: AppInfo.supportURL) {
                    Label("Support", systemImage: "lifepreserver")
                }
                Link(destination: AppInfo.privacyPolicyURL) {
                    Label("Privacy Policy", systemImage: "hand.raised")
                }
            }
            .listRowBackground(darkCardBg)
            Section("About") {
                LabeledContent("Version", value: AppInfo.version())
                LabeledContent("Build", value: AppInfo.build())
            }
            .listRowBackground(darkCardBg)
        }
        .scrollContentBackground(Theme.isDark(theme) ? .hidden : .automatic)
        .background(Theme.isDark(theme) ? Theme.background(theme) : Color.clear)
    }

    // MARK: - Retro Settings

    private var retroSettings: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                retroSection("APPEARANCE") {
                    appearanceRows
                }
                retroSection("TERMINAL_COLOR") {
                    retroColorPalette
                }
                retroSection("WEEK") {
                    weekStartRow
                }
                retroSection("CATEGORIES") {
                    NavigationLink {
                        SavedCategoriesView(store: store)
                    } label: {
                        retroLinkLabel("> Saved Categories")
                    }
                    .buttonStyle(.plain)
                    sortPicker
                }
                if FeatureAccess.isCalendarUnlocked {
                    retroSection("CALENDAR") {
                        CalendarSettingsRows(store: store, calendar: calendar)
                    }
                }
                retroSection("HELP") {
                    Button { showHelp = true } label: {
                        retroLinkLabel("> How to Use Tasquel")
                    }
                    .buttonStyle(.plain)
                    Button { showTour = true } label: {
                        retroLinkLabel("> Show Welcome Tour")
                    }
                    .buttonStyle(.plain)
                }
                retroSection("COMING_SOON") {
                    Text(Self.comingSoonDescription)
                        .font(Theme.captionFont(theme))
                        .foregroundStyle(Theme.textSecondary(theme, rc: rc))
                    ComingSoonSurvey(store: store)
                    Text("anonymous // only your picks and comment are sent")
                        .font(Theme.captionFont(theme))
                        .foregroundStyle(Theme.textTertiary(theme, rc: rc))
                }
                retroSection("SUPPORT") {
                    retroLink("> Support", to: AppInfo.supportURL)
                    retroLink("> Privacy Policy", to: AppInfo.privacyPolicyURL)
                }
                retroSection("ABOUT") {
                    HStack {
                        Text("Version").font(Theme.bodyFont(theme)).foregroundStyle(Theme.textSecondary(theme, rc: rc))
                        Spacer()
                        Text(AppInfo.version()).font(Theme.bodyFont(theme)).foregroundStyle(Theme.textPrimary(theme, rc: rc))
                    }
                    HStack {
                        Text("Build").font(Theme.bodyFont(theme)).foregroundStyle(Theme.textSecondary(theme, rc: rc))
                        Spacer()
                        Text(AppInfo.build()).font(Theme.bodyFont(theme)).foregroundStyle(Theme.textPrimary(theme, rc: rc))
                    }
                }
            }
            .padding(16)
        }
        .background(Theme.background(theme))
        .foregroundStyle(Theme.textPrimary(theme, rc: rc))
    }

    /// Opens in Safari.
    private func retroLink(_ title: String, to url: URL) -> some View {
        Link(destination: url) { retroLinkLabel(title) }
    }

    /// A retro link's text, a full 44pt tall and tappable across the row.
    private func retroLinkLabel(_ title: String) -> some View {
        Text(title)
            .font(Theme.bodyFont(theme))
            .foregroundStyle(Theme.accent(theme, rc: rc))
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
    }

    @ViewBuilder
    private func retroSection(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("[\(title)]")
                .font(.system(.caption, design: .monospaced).bold())
                .foregroundStyle(Theme.textTertiary(theme, rc: rc))
            VStack(alignment: .leading, spacing: 6) {
                content()
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

    // MARK: - Shared Rows

    @ViewBuilder
    private var appearanceRows: some View {
        ForEach(AppearanceMode.allCases, id: \.self) { mode in
            Button {
                store.setAppearance(mode)
            } label: {
                HStack {
                    if retro {
                        Text("> \(mode.label.uppercased())")
                            .font(Theme.bodyFont(theme))
                            .foregroundStyle(store.appearanceMode == mode ? Theme.accent(theme, rc: rc) : Theme.textSecondary(theme, rc: rc))
                    } else {
                        Label(mode.label, systemImage: mode.symbol).foregroundStyle(.primary)
                    }
                    Spacer()
                    if store.appearanceMode == mode {
                        if retro {
                            Text("[*]")
                                .font(.system(.subheadline, design: .monospaced).bold())
                                .foregroundStyle(Theme.accent(theme, rc: rc))
                        } else {
                            Image(systemName: "checkmark").foregroundStyle(.blue)
                        }
                    }
                }
                .padding(.vertical, 6)
                .frame(minHeight: retro ? 44 : nil)
                .contentShape(Rectangle())
            }
        }
    }

    private var retroColorPalette: some View {
        HStack(spacing: 10) {
            ForEach(RetroColor.allCases, id: \.self) { color in
                Button {
                    store.setRetroColor(color)
                } label: {
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Theme.retroBright(color))
                            .frame(width: 36, height: 36)
                            .overlay(
                                RoundedRectangle(cornerRadius: 2)
                                    .stroke(store.retroColor == color ? .white : .clear, lineWidth: 2)
                            )
                        Text(color.label.prefix(3).uppercased())
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(store.retroColor == color ? Theme.retroBright(color) : Theme.textTertiary(theme, rc: rc))
                    }
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(color.label)
                .accessibilityAddTraits(store.retroColor == color ? .isSelected : [])
            }
        }
    }

    /// What the Coming Soon survey is for, under its heading.
    private static let comingSoonDescription = "Features being considered for Tasquel. Tick the ones you'd use to help decide what comes next."

    /// Manual (hold and drag) or by when each category was last edited.
    private var sortPicker: some View {
        Picker(selection: Binding(get: { store.categorySort }, set: { store.setCategorySort($0) })) {
            ForEach(CategorySortOrder.allCases, id: \.self) { order in
                Text(retro ? order.label.uppercased() : order.label).tag(order)
            }
        } label: {
            if retro {
                Text("> Sort Cards").font(Theme.bodyFont(theme))
            } else {
                Label("Sort Cards", systemImage: "arrow.up.arrow.down")
            }
        }
        .pickerStyle(.menu)
        .tint(retro ? Theme.accent(theme, rc: rc) : nil)
        .frame(minHeight: retro ? 44 : nil)
    }

    /// Sunday or Monday. Changing it moves saved weeks by a day so tasks stay with their week.
    private var weekStartRow: some View {
        HStack {
            if retro {
                Text("> Week Starts On").font(Theme.bodyFont(theme))
            } else {
                Label("Week Starts On", systemImage: "calendar.day.timeline.left")
            }
            Spacer()
            Picker("Week Starts On", selection: Binding(
                get: { store.weekStartsOnSunday },
                set: { store.setWeekStartsOnSunday($0) }
            )) {
                Text(retro ? "SUN" : "Sunday").tag(true)
                Text(retro ? "MON" : "Monday").tag(false)
            }
            .pickerStyle(.segmented)
            .fixedSize()
            .labelsHidden()
        }
    }
}
