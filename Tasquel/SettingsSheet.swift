import SwiftUI

// MARK: - Settings Sheet

struct SettingsSheet: View {
    let store: ChecklistStore
    @Environment(\.dismiss) private var dismiss
    @State private var showHelp = false
    @State private var editingName = ""
    @State private var isEditingName = false

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
                ToolbarItem(placement: .confirmationAction) {
                    Button(retro ? "[DONE]" : "Done") { dismiss() }
                        .font(retro ? .system(.subheadline, design: .monospaced).bold() : .body)
                        .foregroundStyle(retro ? Theme.accent(theme, rc: rc) : .blue)
                }
            }
            .sheet(isPresented: $showHelp) { HelpSheet(store: store) }
        }
        .preferredColorScheme(store.colorScheme)
    }

    // MARK: - Standard (System/Light/Dark) Settings

    private var darkCardBg: Color? { Theme.isDark(theme) ? Theme.cardFill(theme) : nil }

    private var standardSettings: some View {
        List {
            Section("Name") {
                nameRow
            }
            .listRowBackground(darkCardBg)
            Section("Appearance") {
                appearanceRows
            }
            .listRowBackground(darkCardBg)
            Section("Calendar") {
                calendarRow
            }
            .listRowBackground(darkCardBg)
            Section {
                Button { showHelp = true } label: {
                    Label("How to Use Tasquel", systemImage: "questionmark.circle")
                }
            } header: {
                Text("Help")
            }
            .listRowBackground(darkCardBg)
            Section("About") {
                LabeledContent("Version", value: "1.0")
                LabeledContent("Build", value: "1")
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
                retroSection("USER") {
                    nameRow
                }
                retroSection("APPEARANCE") {
                    appearanceRows
                }
                retroSection("TERMINAL_COLOR") {
                    retroColorPalette
                }
                retroSection("CALENDAR") {
                    calendarRow
                }
                retroSection("HELP") {
                    Button { showHelp = true } label: {
                        Text("> How to Use Tasquel")
                            .font(Theme.bodyFont(theme))
                            .foregroundStyle(Theme.accent(theme, rc: rc))
                    }
                    .buttonStyle(.plain)
                }
                retroSection("ABOUT") {
                    HStack {
                        Text("Version").font(Theme.bodyFont(theme)).foregroundStyle(Theme.textSecondary(theme, rc: rc))
                        Spacer()
                        Text("1.0").font(Theme.bodyFont(theme)).foregroundStyle(Theme.textPrimary(theme, rc: rc))
                    }
                    HStack {
                        Text("Build").font(Theme.bodyFont(theme)).foregroundStyle(Theme.textSecondary(theme, rc: rc))
                        Spacer()
                        Text("1").font(Theme.bodyFont(theme)).foregroundStyle(Theme.textPrimary(theme, rc: rc))
                    }
                }
            }
            .padding(16)
        }
        .background(Theme.background(theme))
        .foregroundStyle(Theme.textPrimary(theme, rc: rc))
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
    private var nameRow: some View {
        if isEditingName {
            HStack {
                TextField(retro ? "name>" : "Your name", text: $editingName)
                    .font(retro ? Theme.bodyFont(theme) : .body)
                    .onSubmit {
                        let name = editingName.trimmingCharacters(in: .whitespaces)
                        if !name.isEmpty && name.count <= 20 { store.setUserName(name) }
                        isEditingName = false
                    }
                Button(retro ? "[SAVE]" : "Save") {
                    let name = editingName.trimmingCharacters(in: .whitespaces)
                    if !name.isEmpty && name.count <= 20 { store.setUserName(name) }
                    isEditingName = false
                }
                .font(retro ? Theme.bodyFont(theme) : .body)
                .foregroundStyle(retro ? Theme.accent(theme, rc: rc) : .blue)
                .disabled(editingName.trimmingCharacters(in: .whitespaces).isEmpty || editingName.count > 20)
            }
        } else {
            HStack {
                Text(store.userName.isEmpty ? (retro ? "not_set" : "Not set") : store.userName)
                    .font(retro ? Theme.bodyFont(theme) : .body)
                    .foregroundStyle(store.userName.isEmpty ? Theme.textTertiary(theme, rc: rc) : (retro ? Theme.textPrimary(theme, rc: rc) : Color(.label)))
                Spacer()
                Button(retro ? "[EDIT]" : "Edit") {
                    editingName = store.userName
                    isEditingName = true
                }
                .font(retro ? Theme.bodyFont(theme) : .subheadline)
                .foregroundStyle(retro ? Theme.accent(theme, rc: rc) : .blue)
            }
        }
    }

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
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var calendarRow: some View {
        HStack {
            if retro {
                Text("> Calendar Integration")
                    .font(Theme.bodyFont(theme))
                    .foregroundStyle(Theme.textSecondary(theme, rc: rc))
            } else {
                Label("Calendar Integration", systemImage: "calendar.badge.plus")
            }
            Spacer()
            Text(retro ? "[SOON]" : "Coming Soon")
                .font(retro ? .system(.caption, design: .monospaced) : .caption)
                .foregroundStyle(retro ? Theme.textTertiary(theme, rc: rc) : .secondary)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(retro ? Theme.cardFill(theme) : Color(.quaternarySystemFill), in: retro ? AnyShape(RoundedRectangle(cornerRadius: 2)) : AnyShape(Capsule()))
        }
    }
}
