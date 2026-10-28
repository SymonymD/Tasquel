import SwiftUI

// MARK: - Add Category Sheet

struct AddCategorySheet: View {
    let store: ChecklistStore
    /// Name, symbol, and whether the category is for this week only.
    var onAdd: ((String, String, Bool) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var isCreatingNew = false
    @State private var newName = ""
    @State private var newSymbol = "folder"
    @State private var templateToRemove: CategoryTemplate?
    @State private var isEditingSaved = false
    /// Off: the category carries into future weeks. On: it's for the viewed week only.
    @State private var thisWeekOnly = false
    @FocusState private var isNameFocused: Bool
    /// Set once a category is added, while the sheet closes: the name just added would
    /// otherwise count as taken and flash the warning below the field.
    @State private var didAdd = false

    var body: some View {
        NavigationStack {
            List {
                // Set before choosing, so a category is added in one tap (no second
                // "every week or this week?" question).
                Section {
                    Toggle("This week only", isOn: $thisWeekOnly)
                } footer: {
                    Text(thisWeekOnly
                         ? "The category is added to this week only and won't come back next week."
                         : "The category is added to this week and later weeks.")
                }
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
            .scrollContentBackground(Theme.isCustomDark(store.appearanceMode) ? .hidden : .automatic)
            .background(Theme.isCustomDark(store.appearanceMode) ? Theme.background(store.appearanceMode) : Color.clear)
            .navigationTitle("Add Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // A plain glass capsule rather than the blue confirm button (user's choice).
                ToolbarItem(placement: .topBarTrailing) {
                    SheetDoneButton(action: finish)
                }
            }
            .savedCategoryRemoval($templateToRemove, store: store)
        }
        .fontDesign(Theme.isRetro(store.appearanceMode) ? .monospaced : nil)
        .tint(Theme.isRetro(store.appearanceMode) ? Theme.accent(store.appearanceMode, rc: store.retroColor) : nil)
    }

    private var createSection: some View {
        Section("Create New") {
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
                        .onSubmit(createNew)
                }
                if isNewNameTaken {
                    Text(nameTakenMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
                HStack {
                    Button("Cancel") {
                        isCreatingNew = false
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
        }
    }

    @ViewBuilder
    private var savedSection: some View {
        if !store.savedCategories.isEmpty {
            Section {
                ForEach(store.savedCategories) { template in
                    if isEditingSaved {
                        SavedCategoryRow(store: store, template: template) {
                            templateToRemove = template
                        }
                    } else {
                        savedCategoryButton(template)
                    }
                }
                Button {
                    withAnimation { isEditingSaved.toggle() }
                } label: {
                    Label(isEditingSaved ? "Done Editing" : "Edit Saved Categories",
                          systemImage: isEditingSaved ? "checkmark" : "pencil")
                }
                .accessibilityRemoveTraits(.isSelected)  // a checkmark icon reads as "selected"
            } header: {
                Text("Saved Categories")
            } footer: {
                if isEditingSaved {
                    Text("A new name or icon also applies to the category's card this week and in later weeks. To reorder, go to Settings ▸ Saved Categories.")
                }
            }
        }
    }

    /// Done adds a category being typed rather than dropping it; with nothing typed it
    /// just closes. A name that's taken keeps the sheet open, showing why.
    private func finish() {
        guard isCreatingNew, !ChecklistStore.cleanName(newName).isEmpty else {
            dismiss()
            return
        }
        createNew()
    }

    /// A saved category to add; swipe to remove it.
    private func savedCategoryButton(_ template: CategoryTemplate) -> some View {
        let alreadyAdded = store.selectedWeek?.categories.contains(where: { $0.name == template.name }) ?? false
        return Button {
            addFromTemplate(template)
        } label: {
            HStack {
                Label { Text(template.name) } icon: { CategoryIcon(symbol: template.symbol) }
                    .foregroundStyle(alreadyAdded ? .secondary : .primary)
                Spacer()
                if alreadyAdded {
                    Text("Added")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .disabled(alreadyAdded)
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
           week.categories.contains(where: { $0.name == template.name }) {
            dismiss()
            return
        }
        add(name: template.name, symbol: template.symbol, isNew: false)
    }

    private var isNewNameTaken: Bool { !didAdd && store.isCategoryNameTaken(newName) }

    /// Says where the name is taken: this week's cards, or Saved Categories.
    private var nameTakenMessage: String {
        let name = ChecklistStore.cleanName(newName)
        let inSaved = store.savedCategories.contains { $0.name.caseInsensitiveCompare(name) == .orderedSame }
        return inSaved
            ? "A category named \(name) already exists. Pick it from Saved Categories, or choose another name."
            : "\(name) is already in this week. Choose another name."
    }

    private func createNew() {
        let name = ChecklistStore.cleanName(newName)
        guard !name.isEmpty, !isNewNameTaken else { return }
        add(name: name, symbol: newSymbol, isNew: true)
    }

    /// A new category added for every week is also kept in Saved Categories;
    /// one added for this week only isn't, since it's meant to be temporary.
    private func add(name: String, symbol: String, isNew: Bool) {
        didAdd = true
        if isNew && !thisWeekOnly {
            store.addSavedCategory(name: name, symbol: symbol)
        }
        onAdd?(name, symbol, thisWeekOnly)
        dismiss()
    }
}

// MARK: - Date Picker Sheet

struct DatePickerSheet: View {
    let selectedDate: Date
    let firstWeekday: Int
    var theme: AppearanceMode = .system
    var rc: RetroColor = .green
    let onSelect: (Date) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var pickerDate: Date

    init(selectedDate: Date, firstWeekday: Int, theme: AppearanceMode = .system, rc: RetroColor = .green,
         onSelect: @escaping (Date) -> Void) {
        self.selectedDate = selectedDate
        self.firstWeekday = firstWeekday
        self.theme = theme
        self.rc = rc
        self.onSelect = onSelect
        self._pickerDate = State(initialValue: selectedDate)
    }

    var body: some View {
        NavigationStack {
            // Scrolls rather than pushing the selected week off the bottom at the
            // half-height detent or with large text.
            ScrollView {
                VStack(spacing: 20) {
                    DatePicker("Select a week", selection: $pickerDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .tint(Theme.isRetro(theme) ? Theme.accent(theme, rc: rc) : .blue)
                        .environment(\.calendar, pickerCalendar)
                    Text("Selected: Week of \(formattedWeekStart)")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .padding()
            }
            .fontDesign(Theme.isRetro(theme) ? .monospaced : nil)
            .navigationTitle("Go to Week")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Go") {
                        onSelect(pickerDate)
                        dismiss()
                    }
                }
            }
        }
    }

    /// The month grid starts on the user's chosen week start day.
    private var pickerCalendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = firstWeekday
        return calendar
    }

    /// In the user's language and region ("Oct 19, 2026", "19 Oct 2026").
    private var formattedWeekStart: String {
        Week.startOfWeek(containing: pickerDate, firstWeekday: firstWeekday)
            .formatted(.dateTime.month(.abbreviated).day().year())
    }
}
