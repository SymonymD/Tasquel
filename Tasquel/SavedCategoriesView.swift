import SwiftUI

// MARK: - Removing a Saved Category

extension View {
    /// The one confirmation for removing a saved category, used by Settings and Add Category.
    func savedCategoryRemoval(_ template: Binding<CategoryTemplate?>, store: ChecklistStore) -> some View {
        confirmationDialog(
            "Remove \(template.wrappedValue?.name ?? "")?",
            isPresented: Binding(get: { template.wrappedValue != nil }, set: { if !$0 { template.wrappedValue = nil } }),
            titleVisibility: .visible
        ) {
            Button("Remove Saved Category", role: .destructive) {
                if let removed = template.wrappedValue { store.removeSavedCategory(removed.id) }
                template.wrappedValue = nil
            }
        } message: {
            Text("It won't be offered in Add Category any more. Categories already in your weeks stay.")
        }
    }
}

// MARK: - Saved Categories (Settings)

/// Edit the saved categories offered in Add Category: rename and change icons in place,
/// reorder, add and delete. Renaming or re-iconing one also changes its card in this
/// week and later weeks.
struct SavedCategoriesView: View {
    let store: ChecklistStore
    @State private var editing: TemplateDraft?
    @State private var templateToRemove: CategoryTemplate?
    @State private var editMode: EditMode = .inactive

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
                // In edit mode each row leads with the same remove button as Add Category
                // (one tap, then the confirmation), and gets a reorder handle.
                ForEach(store.savedCategories) { template in
                    SavedCategoryRow(store: store, template: template,
                                     onRemove: editMode.isEditing ? { templateToRemove = template } : nil)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                templateToRemove = template
                            } label: {
                                Label("Remove", systemImage: "trash")
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
                Text("Tap a name to rename it, or an icon to change it. Tap the pencil to remove or reorder. These are offered in Add Category. A new name or icon also applies to the category's card this week and in later weeks.")
            }
        }
        .environment(\.editMode, $editMode)
        .scrollContentBackground(Theme.isCustomDark(theme) ? .hidden : .automatic)
        .background(Theme.isCustomDark(theme) ? Theme.background(theme) : Color.clear)
        .navigationTitle(retro ? "> SAVED_CATEGORIES" : "Saved Categories")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // An icon rather than EditButton's text, which iOS 26.6 squeezes into a small
            // circle when Button Shapes is on (see SheetDoneButton).
            if !store.savedCategories.isEmpty || editMode.isEditing {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(editMode.isEditing ? "Done" : "Edit",
                           systemImage: editMode.isEditing ? "checkmark" : "pencil") {
                        withAnimation { editMode = editMode.isEditing ? .inactive : .active }
                    }
                    .labelStyle(.iconOnly)
                }
            }
        }
        .sheet(item: $editing) { draft in
            TemplateEditor(store: store, draft: draft)
                .presentationDetents([.medium])
        }
        .savedCategoryRemoval($templateToRemove, store: store)
    }
}

// MARK: - Saved Category Row

/// A saved category's icon menu and name, both edited in place. The name is saved when
/// editing ends; an empty name, or one another saved category has, goes back to the old one.
/// With `onRemove`, a remove button leads the row.
struct SavedCategoryRow: View {
    let store: ChecklistStore
    let template: CategoryTemplate
    var onRemove: (() -> Void)? = nil
    @State private var name: String
    @FocusState private var isFocused: Bool

    init(store: ChecklistStore, template: CategoryTemplate, onRemove: (() -> Void)? = nil) {
        self.store = store
        self.template = template
        self.onRemove = onRemove
        _name = State(initialValue: template.name)
    }

    private var theme: AppearanceMode { store.appearanceMode }
    private var rc: RetroColor { store.retroColor }
    private var isTaken: Bool { store.isSavedCategoryNameTaken(name, excluding: template.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                if let onRemove {
                    Button(action: onRemove) {
                        Image(systemName: "minus.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .red)
                            .touchTarget()
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Remove \(template.name)")
                }
                CategorySymbolMenu(symbol: Binding(
                    get: { template.symbol },
                    set: { store.updateSavedCategory(template.id, name: template.name, symbol: $0) }
                )) {
                    CategoryIcon(symbol: template.symbol)
                        .foregroundStyle(Theme.accent(theme, rc: rc))
                        .frame(width: 28)
                        .touchTarget()
                }
                TextField("Category name", text: $name)
                    .font(Theme.isRetro(theme) ? Theme.bodyFont(theme) : .body)
                    .foregroundStyle(Theme.textPrimary(theme, rc: rc))
                    .focused($isFocused)
                    .submitLabel(.done)
                    .onSubmit(commit)
            }
            if isFocused && isTaken {
                Text("Another category is already named \(ChecklistStore.cleanName(name)).")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .onChange(of: isFocused) { _, focused in
            if !focused { commit() }
        }
        .onChange(of: template.name) { _, newName in
            if !isFocused { name = newName }
        }
        // Leaving editing (Add Category's Done Editing) removes the row while it may still
        // have focus, so focus never changes; save what was typed here instead.
        .onDisappear(perform: commit)
    }

    private func commit() {
        guard ChecklistStore.cleanName(name) != template.name else {
            name = template.name
            return
        }
        if store.updateSavedCategory(template.id, name: name, symbol: template.symbol) {
            name = ChecklistStore.cleanName(name)
        } else {
            name = template.name
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
                            CategoryIcon(symbol: draft.symbol)
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
                        Text("Another category is already named \(ChecklistStore.cleanName(draft.name)).")
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
        .fontDesign(Theme.isRetro(store.appearanceMode) ? .monospaced : nil)
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
