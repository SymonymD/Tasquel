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
    @State private var pendingAdd: PendingCategory?

    /// A category waiting for the user to choose "every week" or "this week only".
    private struct PendingCategory {
        let name: String
        let symbol: String
        let isNew: Bool  // created here, rather than picked from Saved Categories
    }

    private let symbolOptions = [
        "folder", "star", "heart", "house", "cart",
        "briefcase", "figure.run", "book", "paintbrush",
        "music.note", "fork.knife", "airplane", "gift",
        "wrench.and.screwdriver", "leaf", "pawprint",
        "calendar.badge.clock", "lightbulb", "sparkles",
    ]

    var body: some View {
        NavigationStack {
            List {
                Section("Create New") {
                    if isCreatingNew {
                        HStack {
                            Menu {
                                ForEach(symbolOptions, id: \.self) { symbol in
                                    Button {
                                        newSymbol = symbol
                                    } label: {
                                        Label(symbol, systemImage: symbol)
                                    }
                                }
                            } label: {
                                Image(systemName: newSymbol)
                                    .font(.title3)
                                    .frame(width: 32, height: 32)
                                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                            }
                            TextField("Category name", text: $newName)
                                .onSubmit(createNew)
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
                            .buttonStyle(.borderless)
                            .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
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

                if !store.savedCategories.isEmpty {
                    Section("Saved Categories") {
                        ForEach(store.savedCategories) { template in
                            let alreadyAdded = store.selectedWeek?.categories.contains(where: { $0.name == template.name }) ?? false
                            Button {
                                addFromTemplate(template)
                            } label: {
                                HStack {
                                    Label(template.name, systemImage: template.symbol)
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
                    }
                }
            }
            .scrollContentBackground(Theme.isDark(store.appearanceMode) ? .hidden : .automatic)
            .background(Theme.isDark(store.appearanceMode) ? Theme.background(store.appearanceMode) : Color.clear)
            .confirmationDialog(
                pendingAdd.map { "Add \($0.name)" } ?? "",
                isPresented: Binding(
                    get: { pendingAdd != nil },
                    set: { if !$0 { pendingAdd = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Every Week") { confirmAdd(thisWeekOnly: false) }
                Button("This Week Only") { confirmAdd(thisWeekOnly: true) }
            } message: {
                Text("Every week: it carries into future weeks. This week only: it won't come back next week.")
            }
            .navigationTitle("Add Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Remove saved category?", isPresented: Binding(
                get: { templateToRemove != nil },
                set: { if !$0 { templateToRemove = nil } }
            )) {
                Button("Remove Saved Category", role: .destructive) {
                    if let templateToRemove {
                        store.removeSavedCategory(templateToRemove.id)
                    }
                    templateToRemove = nil
                }
            } message: {
                Text("You can create this category again later.")
            }
        }
    }

    private func addFromTemplate(_ template: CategoryTemplate) {
        if let week = store.selectedWeek,
           week.categories.contains(where: { $0.name == template.name }) {
            dismiss()
            return
        }
        pendingAdd = PendingCategory(name: template.name, symbol: template.symbol, isNew: false)
    }

    private func createNew() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        pendingAdd = PendingCategory(name: name, symbol: newSymbol, isNew: true)
    }

    /// A new category added for every week is also kept in Saved Categories;
    /// one added for this week only isn't, since it's meant to be temporary.
    private func confirmAdd(thisWeekOnly: Bool) {
        guard let pendingAdd else { return }
        if pendingAdd.isNew && !thisWeekOnly {
            store.addSavedCategory(name: pendingAdd.name, symbol: pendingAdd.symbol)
        }
        onAdd?(pendingAdd.name, pendingAdd.symbol, thisWeekOnly)
        self.pendingAdd = nil
        dismiss()
    }
}

// MARK: - Date Picker Sheet

struct DatePickerSheet: View {
    let selectedDate: Date
    let firstWeekday: Int
    let onSelect: (Date) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var pickerDate: Date

    init(selectedDate: Date, firstWeekday: Int, onSelect: @escaping (Date) -> Void) {
        self.selectedDate = selectedDate
        self.firstWeekday = firstWeekday
        self.onSelect = onSelect
        self._pickerDate = State(initialValue: selectedDate)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                DatePicker("Select a week", selection: $pickerDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .tint(.blue)
                    .environment(\.calendar, pickerCalendar)
                Text("Selected: Week of \(formattedWeekStart)")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            .padding()
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

    private var formattedWeekStart: String {
        let start = Week.startOfWeek(containing: pickerDate, firstWeekday: firstWeekday)
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: start)
    }
}
