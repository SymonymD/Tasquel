import SwiftUI

// MARK: - Add Category Sheet

struct AddCategorySheet: View {
    let store: ChecklistStore
    /// Name, symbol, and whether the category is for this week only.
    var onAdd: ((String, String, Bool) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// At accessibility sizes Edit goes under the heading and Added / + under the name: beside
    /// them the words broke mid-word, "Cate- / gories", "Er- / rands" (the 2026-11-15 review).
    private var stacks: Bool { dynamicTypeSize.isAccessibilitySize }
    @State private var isCreatingNew = false
    @State private var newName = ""
    @State private var newSymbol = "folder"
    @State private var templateToRemove: CategoryTemplate?
    @State private var isEditingSaved = false
    /// The category being created is just this week's (off: it comes back every week).
    @State private var thisWeekOnly = false
    @FocusState private var isNameFocused: Bool
    /// The category added last: the sheet stays open to add several, and says so.
    @State private var lastAdded: String?
    /// A saved category just removed, shown for a moment where its row was ("Removed
    /// Errands"): with only the rows closing up, a tester read the Finish Editing row
    /// (then "✓ Done Editing") as what had happened (2026-11-15).
    @State private var removedNotice: RemovedNotice?
    private struct RemovedNotice: Equatable {
        let name: String
        let index: Int
        let token = UUID()
    }

    var body: some View {
        NavigationStack {
            List {
                createSection
                savedSection
            }
            // The keyboard opens with the row, so one tap is enough. Once, when the row
            // opens: an onAppear fired again whenever the List rebuilt the row (as when
            // Choose Emoji… opened its keyboard) and took the keyboard back.
            .onChange(of: isCreatingNew) { _, creating in
                if creating { isNameFocused = true }
            }
            .onChange(of: store.savedCategories.isEmpty) { _, isEmpty in
                if isEmpty { isEditingSaved = false }
            }
            // Room below the last row, so it isn't lost under the sheet's rounded bottom edge.
            .contentMargins(.bottom, 24, for: .scrollContent)
            // The app's own dark background in Dark and Retro (Retro was plain grey).
            .scrollContentBackground(Theme.hasOwnBackground(store.appearanceMode) ? .hidden : .automatic)
            .background(Theme.hasOwnBackground(store.appearanceMode) ? Theme.background(store.appearanceMode) : Color.clear)
            .navigationTitle("Add Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // A plain glass capsule rather than the blue confirm button (user's choice).
                ToolbarItem(placement: .topBarTrailing) {
                    SheetDoneButton(action: finish)
                }
            }
            .savedCategoryRemoval($templateToRemove, store: store) { removed, index in
                withAnimation(.snappy(duration: 0.25)) { removedNotice = RemovedNotice(name: removed.name, index: index) }
                AccessibilityNotification.Announcement("Removed \(removed.name)").post()
            }
            .task(id: removedNotice?.token) {
                guard removedNotice != nil else { return }
                try? await Task.sleep(for: .seconds(3))
                withAnimation(.snappy(duration: 0.25)) { removedNotice = nil }
            }
        }
        .emojiPickerHost()
        .fontDesign(Theme.isRetro(store.appearanceMode) ? .monospaced : nil)
        // Retro's and the season's own color, not system blue (Seasonal's Create New and Edit
        // stayed blue, the 2026-11-15 review).
        .tint(Theme.isRetro(store.appearanceMode) || Theme.isSeasonal(store.appearanceMode)
              ? Theme.accent(store.appearanceMode, rc: store.retroColor) : nil)
    }

    private var createSection: some View {
        Section {
            if isCreatingNew {
                HStack {
                    CategorySymbolMenu(symbol: $newSymbol) {
                        CategoryIcon(symbol: newSymbol)
                            .font(.title3)
                            .frame(width: 32, height: 32)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                            .touchTarget()
                    }
                    TextField("Category name", text: $newName)
                        .focused($isNameFocused)
                        .submitLabel(.done)
                        .onSubmit { createNew() }
                }
                if isNewNameTaken {
                    Text(nameTakenMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
                // For the category being created, just before Add Category (the user's flow,
                // 2026-11-15: name, icon, this, Add); off each time. At the sheet's top it was
                // the first thing new users met, and stayed on for every add after. A saved
                // category tapped below comes back every week; its card's edit mode can make
                // it just this week's.
                Toggle(isOn: $thisWeekOnly) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Just this week")
                        // Only when on (the user's wording, 2026-11-15).
                        if thisWeekOnly {
                            Text("It won't come back next week. Also saved for later use.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                HStack {
                    Button("Cancel") {
                        isCreatingNew = false
                        thisWeekOnly = false
                        newName = ""
                    }
                    .buttonStyle(.borderless)
                    Spacer()
                    Button("Add Category") {
                        createNew()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    // Retro's tint is a bright phosphor color; white text on it can't be read.
                    .foregroundStyle(Theme.isRetro(store.appearanceMode) ? Color.black : Color.white)
                    .disabled(ChecklistStore.cleanName(newName).isEmpty || isNewNameTaken)
                }
                .font(.subheadline)
            } else {
                Button {
                    isCreatingNew = true
                } label: {
                    Label("Create New Category", systemImage: "plus.circle")
                }
            }
        } header: {
            Text("Create New")
        } footer: {
            // What was just added, so it's clear it worked with the sheet still open.
            if let lastAdded {
                Label("Added \(lastAdded) · add another, or tap Done", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Theme.dotComplete(store.appearanceMode, rc: store.retroColor))
            }
        }
    }

    @ViewBuilder
    private var savedSection: some View {
        if !store.savedCategories.isEmpty {
            Section {
                ForEach(Array(store.savedCategories.enumerated()), id: \.element.id) { index, template in
                    if let removedNotice, removedNotice.index == index { removedRow(removedNotice) }
                    if isEditingSaved {
                        SavedCategoryRow(store: store, template: template) {
                            templateToRemove = template
                        }
                    } else {
                        savedCategoryButton(template)
                    }
                }
                if let removedNotice, removedNotice.index >= store.savedCategories.count { removedRow(removedNotice) }
            } header: {
                // Edit beside the heading, where it's seen: at the list's end, below every saved
                // category, it went unnoticed (the user, 2026-11-15).
                (stacks ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4)) : AnyLayout(HStackLayout())) {
                    Text("Saved Categories")
                    if !stacks { Spacer() }
                    Button(isEditingSaved ? "Done" : "Edit") {
                        withAnimation { isEditingSaved.toggle() }
                    }
                    .font(.subheadline.weight(.semibold))
                    .textCase(nil)
                    .accessibilityLabel(isEditingSaved ? "Done Editing Saved Categories" : "Edit Saved Categories")
                }
            } footer: {
                if isEditingSaved {
                    Text("A new name or icon also applies to the category's card this week and in later weeks. To reorder, go to Settings ▸ Saved Categories.")
                } else {
                    Text("Tap one to add it to this week.")
                }
            }
        }
    }

    /// "Removed Errands", in the removed row's place for a moment.
    private func removedRow(_ notice: RemovedNotice) -> some View {
        Label("Removed \(notice.name)", systemImage: "trash")
            .foregroundStyle(.secondary)
            .transition(.opacity)
    }

    /// Done adds a category being typed rather than dropping it, and closes; with nothing
    /// typed it just closes. A name that's taken keeps the sheet open, showing why. (After an
    /// add from Done the sheet stayed open, "Added Garden · add another, or tap Done", the
    /// 2026-11-15 review.)
    private func finish() {
        guard isCreatingNew, !ChecklistStore.cleanName(newName).isEmpty else {
            dismiss()
            return
        }
        if createNew() { dismiss() }
    }

    /// A saved category to add; swipe to remove it.
    private func savedCategoryButton(_ template: CategoryTemplate) -> some View {
        let alreadyAdded = store.selectedWeek?.categories.contains(where: { $0.name == template.name }) ?? false
        return Button {
            addFromTemplate(template)
        } label: {
            // Color.primary, not .primary: in a button that's its tint, and the ones that
            // could be added showed blue, which read as nothing in particular (the user,
            // 2026-11-15). A + says they can be added.
            (stacks ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4)) : AnyLayout(HStackLayout())) {
                Label { Text(template.name) } icon: { CategoryIcon(symbol: template.symbol) }
                    .foregroundStyle(alreadyAdded ? Color.secondary : Color.primary)
                if !stacks { Spacer() }
                if alreadyAdded {
                    Text("Added")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Theme.dotComplete(store.appearanceMode, rc: store.retroColor))
                        .accessibilityHidden(true)
                }
            }
        }
        .disabled(alreadyAdded)
        .accessibilityHint(alreadyAdded ? "" : "Adds it to this week")
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                templateToRemove = template
            } label: {
                Label("Remove", systemImage: "trash")
            }
        }
    }

    private func addFromTemplate(_ template: CategoryTemplate) {
        if let week = store.selectedWeek,
           week.categories.contains(where: { $0.name == template.name }) { return }
        add(name: template.name, symbol: template.symbol, isNew: false)
    }

    private var isNewNameTaken: Bool { store.isCategoryNameTaken(newName) }

    /// Says where the name is taken: this week's cards, or Saved Categories.
    private var nameTakenMessage: String {
        let name = ChecklistStore.cleanName(newName)
        let inSaved = store.savedCategories.contains { $0.name.caseInsensitiveCompare(name) == .orderedSame }
        return inSaved
            ? "A category named \(name) already exists. Pick it from Saved Categories, or choose another name."
            : "\(name) is already in this week. Choose another name."
    }

    /// False, with nothing added, when the name is empty or taken.
    @discardableResult
    private func createNew() -> Bool {
        let name = ChecklistStore.cleanName(newName)
        guard !name.isEmpty, !isNewNameTaken else { return false }
        add(name: name, symbol: newSymbol, isNew: true)
        return true
    }

    /// A new category is also kept in Saved Categories, also one added for this week
    /// only, so it can be added again another week.
    /// The sheet stays open for the next one (three testers went Edit ▸ Add Category ▸
    /// Create New once per card, 2026-11-14); Done closes it. A new one's field is cleared
    /// and keeps the keyboard.
    private func add(name: String, symbol: String, isNew: Bool) {
        if isNew {
            store.addSavedCategory(name: name, symbol: symbol)
        }
        onAdd?(name, symbol, isNew && thisWeekOnly)
        withAnimation(.snappy(duration: 0.2)) { lastAdded = name }
        if isNew {
            newName = ""
            newSymbol = "folder"
            thisWeekOnly = false
            isNameFocused = true
        }
        AccessibilityNotification.Announcement("Added \(name)").post()
    }
}
