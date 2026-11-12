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
    /// The device's appearance, used while the app follows it (System).
    var systemColorScheme: ColorScheme? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var showHelp = false
    /// Notifications are off for Tasquel in iOS Settings (Expiration Reminders says so).
    @State private var notificationsDenied = false
    @State private var showTour = false
    @AppStorage(AppIconSwitcher.matchesThemeKey) private var iconMatchesTheme = true

    private var theme: AppearanceMode { store.appearanceMode }
    private var rc: RetroColor { store.retroColor }
    private var retro: Bool { Theme.isRetro(theme) }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                Group {
                    if retro {
                        retroSettings
                    } else {
                        standardSettings
                    }
                }
                // A growing Feature Ideas comment stays above the keyboard, its newest line
                // (and the caret) included.
                .onChange(of: FeatureIdeasDraft.shared.comment) {
                    proxy.scrollTo(FeatureIdeasSurvey.commentID, anchor: .bottom)
                }
            }
            .navigationTitle(retro ? "> SETTINGS_" : "Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // A plain glass capsule rather than the blue confirm button (user's choice).
                ToolbarItem(placement: .topBarTrailing) {
                    if retro {
                        Button("[DONE]") { dismiss() }
                            .accessibilityLabel("Done")
                            .font(.system(.subheadline, design: .monospaced).bold())
                            .foregroundStyle(Theme.accent(theme, rc: rc))
                    } else {
                        SheetDoneButton { dismiss() }
                    }
                }
                // Retro: just the green word, no glass capsule behind it.
                .sharedBackgroundVisibility(retro ? .hidden : .automatic)
            }
            .sheet(isPresented: $showHelp) { HelpSheet(store: store) }
            .sheet(isPresented: $showTour) {
                // Sheets don't inherit the app's appearance.
                OnboardingSheet(store: store, calendar: calendar, isReplay: true)
                    .preferredColorScheme(store.colorScheme)
            }
            .task {
                calendar.refreshAuthorization()
                await calendar.loadCalendars()
            }
        }
        // Always a scheme, never nil: an open sheet keeps its earlier Dark or Light when
        // the preference goes back to nil, so choosing System here didn't show.
        .preferredColorScheme(store.colorScheme ?? systemColorScheme)
    }

    // MARK: - Standard (System/Light/Dark) Settings

    private var darkCardBg: Color? { Theme.hasOwnBackground(theme) && !Theme.isRetro(theme) ? Theme.cardFill(theme) : nil }

    private var standardSettings: some View {
        List {
            Section {
                appearanceRows
                appIconToggle
            } header: {
                Text("Appearance")
            } footer: {
                if AppIconSwitcher.isSupported {
                    Text("Uses the retro home-screen icon with the Retro theme. iOS confirms each icon change.")
                }
            }
            .listRowBackground(darkCardBg)
            Section("Week") {
                weekStartRow
            }
            .listRowBackground(darkCardBg)
            Section {
                expiryRemindersToggle
            } header: {
                Text("Reminders")
            } footer: {
                Text(expiryRemindersFooter)
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
                FeatureIdeasSurvey(store: store)
            } header: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Feature Ideas")
                    Text(Self.featureIdeasDescription)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }
            } footer: {
                Text("Optional and anonymous: only your picks, your comment and the app version are sent.")
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
        .scrollContentBackground(Theme.hasOwnBackground(theme) ? .hidden : .automatic)
        .background(Theme.hasOwnBackground(theme) ? Theme.background(theme) : Color.clear)
    }

    // MARK: - Retro Settings

    private var retroSettings: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                retroSection("APPEARANCE") {
                    appearanceRows
                    appIconToggle
                }
                retroSection("TERMINAL_COLOR") {
                    retroColorPalette
                }
                retroSection("WEEK") {
                    weekStartRow
                }
                retroSection("REMINDERS") {
                    expiryRemindersToggle
                    Text(expiryRemindersFooter)
                        .font(Theme.captionFont(theme))
                        .foregroundStyle(Theme.textSecondary(theme, rc: rc))
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
                retroSection("FEATURE_IDEAS") {
                    Text(Self.featureIdeasDescription)
                        .font(Theme.captionFont(theme))
                        .foregroundStyle(Theme.textSecondary(theme, rc: rc))
                    FeatureIdeasSurvey(store: store)
                    Text("anonymous // sends picks, comment, app version")
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
            .buttonStyle(.plain)  // no gray fill (iOS 26's default)
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
                AppIconSwitcher.update(for: mode, matchingTheme: iconMatchesTheme)
            } label: {
                HStack {
                    if retro {
                        Text("> \(mode.label.uppercased())")
                            .font(Theme.bodyFont(theme))
                            .foregroundStyle(store.appearanceMode == mode ? Theme.accent(theme, rc: rc) : Theme.textSecondary(theme, rc: rc))
                    } else {
                        // Color.primary, not .primary: that takes the button's blue tint.
                        Label(mode.label, systemImage: mode.symbol).foregroundStyle(Color.primary)
                        if mode == .seasonal {
                            // Which season it is now ("Fall"). Color.secondary: `.secondary` took
                            // the button's blue tint.
                            Text(Season.current.label).foregroundStyle(Color.secondary)
                        }
                    }
                    Spacer()
                    if store.appearanceMode == mode {
                        if retro {
                            Text("[*]")
                                .font(.system(.subheadline, design: .monospaced).bold())
                                .foregroundStyle(Theme.accent(theme, rc: rc))
                        } else {
                            Image(systemName: "checkmark").foregroundStyle(Theme.isSeasonal(theme) ? Theme.accent(theme, rc: rc) : .blue)
                        }
                    }
                }
                .padding(.vertical, 6)
                .frame(minHeight: retro ? 44 : nil)
                .contentShape(Rectangle())
            }
            // Retro's layout isn't a List: there the default button style gave each a gray fill.
            .modifier(PlainButtonInRetro(isRetro: retro))
            // In words, not "> RETRO, [*]"; the chosen one is selected in every theme.
            .accessibilityLabel(mode == .seasonal ? "Seasonal, now \(Season.current.label)" : mode.label)
            .accessibilityAddTraits(store.appearanceMode == mode ? .isSelected : [])
        }
    }

    /// A notification the day before an expiring task's last day.
    private var expiryRemindersToggle: some View {
        Toggle(isOn: Binding(get: { store.remindsBeforeExpiry }, set: { on in
            store.setRemindsBeforeExpiry(on)
            if on { ExpiryNotifications.shared.requestPermissionIfNeeded() }
        })) {
            if retro {
                Text("> Expiration Reminders").font(Theme.bodyFont(theme))
            } else {
                Label("Expiration Reminders", systemImage: "bell.badge")
            }
        }
        .tint(retro || Theme.isSeasonal(theme) ? Theme.accent(theme, rc: rc) : nil)
        .task { notificationsDenied = await ExpiryNotifications.shared.isDenied() }
    }

    private var expiryRemindersFooter: String {
        let what = "A notification at 9 AM the day before a task's last day (set with the clock in a card's edit mode)."
        return notificationsDenied && store.remindsBeforeExpiry
            ? what + " Notifications are off for Tasquel: turn them on in the Settings app." : what
    }

    /// Whether the home-screen icon turns retro with the Retro theme.
    @ViewBuilder
    private var appIconToggle: some View {
        if AppIconSwitcher.isSupported {
            Toggle(isOn: $iconMatchesTheme) {
                if retro {
                    Text("> Match App Icon to Theme").font(Theme.bodyFont(theme))
                } else {
                    Label("Match App Icon to Theme", systemImage: "app.badge")
                }
            }
            .tint(retro || Theme.isSeasonal(theme) ? Theme.accent(theme, rc: rc) : nil)
            .onChange(of: iconMatchesTheme) { _, matching in
                AppIconSwitcher.update(for: store.appearanceMode, matchingTheme: matching)
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

    /// What the Feature Ideas survey is for, under its heading.
    private static let featureIdeasDescription = "Ideas being considered. They aren't in Tasquel yet. Tick the ones you'd use to help decide what comes next."

    /// Manual (hold and drag) or by when each category was last edited.
    @ViewBuilder
    private var sortPicker: some View {
        if retro {
            // Outside a List a menu picker shows no label: it goes beside it.
            HStack {
                Text("> Sort Cards").font(Theme.bodyFont(theme))
                    .foregroundStyle(Theme.textPrimary(theme, rc: rc))
                    .accessibilityHidden(true)  // the menu says it
                Spacer()
                retroSortMenu
            }
            .frame(minHeight: 44)
        } else {
            sortMenu
        }
    }

    private var sortMenu: some View {
        Picker(selection: Binding(get: { store.categorySort }, set: { store.setCategorySort($0) })) {
            ForEach(CategorySortOrder.allCases, id: \.self) { order in
                Text(retro ? order.label.uppercased() : order.label).tag(order)
            }
        } label: {
            Label("Sort Cards", systemImage: "arrow.up.arrow.down")
        }
        .pickerStyle(.menu)
        .tint(retro || Theme.isSeasonal(theme) ? Theme.accent(theme, rc: rc) : nil)
    }

    /// Retro's: the chosen order in green with up/down arrows, no gray capsule (a menu
    /// picker's look); the same choices open from it.
    private var retroSortMenu: some View {
        Menu {
            Picker("Sort Cards", selection: Binding(get: { store.categorySort }, set: { store.setCategorySort($0) })) {
                ForEach(CategorySortOrder.allCases, id: \.self) { order in
                    Text(order.label).tag(order)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(store.categorySort.label.uppercased())
                Image(systemName: "chevron.up.chevron.down").font(.caption2.bold())
            }
            .font(.system(.subheadline, design: .monospaced).bold())
            .foregroundStyle(Theme.accent(theme, rc: rc))
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .accessibilityLabel("Sort Cards")
        .accessibilityValue(store.categorySort.label)
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
            if retro {
                // Not the segmented control, whose gray doesn't suit Retro: the chosen day
                // outlined in green.
                HStack(spacing: 6) {
                    retroWeekStartOption("SUN", sunday: true)
                    retroWeekStartOption("MON", sunday: false)
                }
            } else {
                Picker("Week Starts On", selection: Binding(
                    get: { store.weekStartsOnSunday },
                    set: { store.setWeekStartsOnSunday($0) }
                )) {
                    Text("Sunday").tag(true)
                    Text("Monday").tag(false)
                }
                .pickerStyle(.segmented)
                .fixedSize()
                .labelsHidden()
            }
        }
    }

    private func retroWeekStartOption(_ title: String, sunday: Bool) -> some View {
        let isChosen = store.weekStartsOnSunday == sunday
        return Button { store.setWeekStartsOnSunday(sunday) } label: {
            Text(title)
                .font(.system(.subheadline, design: .monospaced).bold())
                .foregroundStyle(isChosen ? Theme.accent(theme, rc: rc) : Theme.textSecondary(theme, rc: rc))
                .padding(.horizontal, 10)
                .frame(minHeight: 32)
                .overlay {
                    if isChosen { RoundedRectangle(cornerRadius: 2).stroke(Theme.accent(theme, rc: rc), lineWidth: 1.5) }
                }
                .contentShape(Rectangle())
                .touchTarget()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(sunday ? "Sunday" : "Monday")
        .accessibilityAddTraits(isChosen ? .isSelected : [])
    }
}

/// A plain button (or link) in Retro, whose Settings aren't a List (iOS 26's default style
/// gave its buttons a gray fill); the standard List keeps its rows' look.
struct PlainButtonInRetro: ViewModifier {
    let isRetro: Bool

    func body(content: Content) -> some View {
        if isRetro { content.buttonStyle(.plain) } else { content }
    }
}
