import SwiftUI

// MARK: - Saved Categories (Settings)

/// Edit the saved categories offered in Add Category: rename, change icons, reorder,
/// add and delete. Changes here don't touch categories already in your weeks.
struct SavedCategoriesView: View {
    let store: ChecklistStore
    @State private var editing: TemplateDraft?
    @State private var templateToDelete: CategoryTemplate?

    private var theme: AppearanceMode { store.appearanceMode }
    private var rc: RetroColor { store.retroColor }
    private var retro: Bool { Theme.isRetro(theme) }

    /// A template being edited, or a new one when `id` is nil.
    struct TemplateDraft: Identifiable {
        var id: UUID?
        var name: String
        var symbol: String
    }

    var body: some View {
        List {
            Section {
                ForEach(store.savedCategories) { template in
                    Button {
                        editing = TemplateDraft(id: template.id, name: template.name, symbol: template.symbol)
                    } label: {
                        HStack {
                            Label(template.name, systemImage: template.symbol)
                                .font(retro ? Theme.bodyFont(theme) : .body)
                                .foregroundStyle(Theme.textPrimary(theme, rc: rc))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.footnote.bold())
                                .foregroundStyle(Theme.textTertiary(theme, rc: rc))
                        }
                    }
                    .accessibilityHint("Edit name and icon")
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            templateToDelete = template
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                .onMove { store.moveSavedCategories(fromOffsets: $0, toOffset: $1) }
                .listRowBackground(Theme.isCustomDark(theme) ? Theme.cardFill(theme) : nil)

                Button {
                    editing = TemplateDraft(id: nil, name: "", symbol: "folder")
                } label: {
                    Label("New Saved Category", systemImage: "plus.circle")
                        .font(retro ? Theme.bodyFont(theme) : .body)
                        .foregroundStyle(Theme.accent(theme, rc: rc))
                }
                .listRowBackground(Theme.isCustomDark(theme) ? Theme.cardFill(theme) : nil)
            } footer: {
                Text("These are offered in Add Category. Editing one here doesn't change categories already in your weeks. To rename a category in your weeks, open its card and tap its edit button.")
            }
        }
        .scrollContentBackground(Theme.isCustomDark(theme) ? .hidden : .automatic)
        .background(Theme.isCustomDark(theme) ? Theme.background(theme) : Color.clear)
        .navigationTitle(retro ? "> SAVED_CATEGORIES" : "Saved Categories")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !store.savedCategories.isEmpty {
                ToolbarItem(placement: .topBarTrailing) { EditButton() }
            }
        }
        .sheet(item: $editing) { draft in
            TemplateEditor(store: store, draft: draft)
                .presentationDetents([.medium])
        }
        .confirmationDialog(
            "Delete \(templateToDelete?.name ?? "")?",
            isPresented: Binding(get: { templateToDelete != nil }, set: { if !$0 { templateToDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete Saved Category", role: .destructive) {
                if let templateToDelete { store.removeSavedCategory(templateToDelete.id) }
                templateToDelete = nil
            }
        } message: {
            Text("It won't be offered in Add Category any more. Categories already in your weeks stay.")
        }
    }
}

// MARK: - Template Editor

private struct TemplateEditor: View {
    let store: ChecklistStore
    @State var draft: SavedCategoriesView.TemplateDraft
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isNameFocused: Bool

    private var isTaken: Bool { store.isSavedCategoryNameTaken(draft.name, excluding: draft.id) }
    private var canSave: Bool { !ChecklistStore.cleanName(draft.name).isEmpty && !isTaken }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        CategorySymbolMenu(symbol: $draft.symbol) {
                            Image(systemName: draft.symbol)
                                .font(.title2)
                                .frame(width: 44, height: 44)
                                .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
                        }
                        TextField("Category name", text: $draft.name)
                            .focused($isNameFocused)
                            .submitLabel(.done)
                            .onSubmit(save)
                    }
                } footer: {
                    if isTaken {
                        Text("Another saved category is already named \(ChecklistStore.cleanName(draft.name)).")
                            .foregroundStyle(.red)
                    } else {
                        Text("Tap the icon to change it.")
                    }
                }
            }
            .navigationTitle(draft.id == nil ? "New Saved Category" : "Edit Saved Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(!canSave)
                }
            }
            .onAppear { if draft.id == nil { isNameFocused = true } }
        }
        .preferredColorScheme(store.colorScheme)
    }

    private func save() {
        guard canSave else { return }
        if let id = draft.id {
            store.updateSavedCategory(id, name: draft.name, symbol: draft.symbol)
        } else {
            store.addSavedCategory(name: draft.name, symbol: draft.symbol)
        }
        dismiss()
    }
}
