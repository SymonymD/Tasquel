import SwiftUI

// MARK: - Add Category Sheet

struct AddCategorySheet: View {
    let store: ChecklistStore
    var onAdd: ((String, String) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var isCreatingNew = false
    @State private var newName = ""
    @State private var newSymbol = "folder"
    @State private var templateToRemove: CategoryTemplate?

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
                            Button("Add to Week & Save") {
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
        onAdd?(template.name, template.symbol)
        dismiss()
    }

    private func createNew() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        store.addSavedCategory(name: name, symbol: newSymbol)
        onAdd?(name, newSymbol)
        dismiss()
    }
}

// MARK: - Date Picker Sheet

struct DatePickerSheet: View {
    let selectedDate: Date
    let onSelect: (Date) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var pickerDate: Date

    init(selectedDate: Date, onSelect: @escaping (Date) -> Void) {
        self.selectedDate = selectedDate
        self.onSelect = onSelect
        self._pickerDate = State(initialValue: selectedDate)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                DatePicker("Select a week", selection: $pickerDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .tint(.blue)
                Text("Selected: Week of \(formattedMonday)")
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

    private var formattedMonday: String {
        let monday = Week.mondayOfWeek(containing: pickerDate)
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: monday)
    }
}
