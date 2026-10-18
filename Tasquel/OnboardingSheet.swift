import SwiftUI

// MARK: - Onboarding Sheet

struct OnboardingSheet: View {
    let store: ChecklistStore
    @Environment(\.dismiss) private var dismiss

    @State private var page: Page = .welcome
    @State private var userName = ""
    @State private var selectedCategories = CategoryTemplate.starters
    @State private var newName = ""
    @State private var newSymbol = "folder"
    @State private var isAddingCategory = false

    /// Every step is a page: swipe between them, or use Next and Back.
    private enum Page: Int, CaseIterable {
        case welcome, types, modes, tips, name, categories
    }

    private let gridColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    private typealias FeatureItem = (symbol: String, title: String, detail: String)

    private let typeItems: [FeatureItem] = [
        ("checkmark.circle", "Checkbox",
         "A task to tick off. Tap + to break it into sub-tasks."),
        ("target", "Goal",
         "Progress toward a target, like 50 push-ups or 2 hours. Checks itself off when you reach it."),
        ("list.bullet", "List",
         "A checklist like Groceries: type an item, press Return, type the next. Checks itself off when every item is done."),
    ]

    private let modeItems: [FeatureItem] = [
        ("1.circle", "One-Time",
         "This week only. New tasks start here."),
        ("arrow.uturn.forward", "Carry Over",
         "Not done by the end of the week? It moves to next week, with only what's left."),
        ("repeat", "Repeating",
         "Back every week, unchecked, whether or not you finished it."),
    ]

    private let tipItems: [FeatureItem] = [
        ("slider.horizontal.3", "Type and Mode",
         "Tap the icons at the end of a task to choose both."),
        ("square.grid.2x2", "Edit Mode",
         "Tap the grid button to add or remove categories. Hold and drag a closed card to move it. A card's own edit button lets you rename it and delete tasks."),
        ("hand.tap", "Double-Tap and Long-Press",
         "Double-tap a task to rename it. Long-press a task for more options."),
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TabView(selection: $page) {
                    welcomePage.tag(Page.welcome)
                    featurePage("What a Task Is", icon: "checklist.checked", items: typeItems).tag(Page.types)
                    featurePage("After This Week", icon: "calendar", items: modeItems).tag(Page.modes)
                    featurePage("Quick Tips", icon: "lightbulb", items: tipItems).tag(Page.tips)
                    namePage.tag(Page.name)
                    categoriesPage.tag(Page.categories)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                pageDots.padding(.vertical, 12)
                bottomButtons
                    .padding(.horizontal, 32).padding(.bottom, 24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if page != .welcome {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { go(by: -1) } label: {
                            Label("Back", systemImage: "chevron.left").labelStyle(.titleAndIcon)
                        }
                    }
                }
            }
            // A name typed and then swiped past still counts.
            .onChange(of: page) { old, _ in
                if old == .name { saveName() }
            }
        }
    }

    private func go(by offset: Int) {
        guard let next = Page(rawValue: page.rawValue + offset) else { return }
        withAnimation(.snappy(duration: 0.3)) { page = next }
    }

    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(Page.allCases, id: \.self) { dot in
                Circle()
                    .fill(dot == page ? Color.blue : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .scaleEffect(dot == page ? 1.2 : 1.0)
                    .animation(.snappy(duration: 0.2), value: page)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Page \(page.rawValue + 1) of \(Page.allCases.count)")
    }

    @ViewBuilder
    private var bottomButtons: some View {
        VStack(spacing: 12) {
            switch page {
            case .name:
                primaryButton("Next") { go(by: 1) }
                    .disabled(!isNameValid)
                Button { go(by: 1) } label: {
                    Text("Skip").font(.subheadline).foregroundStyle(.secondary)
                }
            case .categories:
                primaryButton("Let's Go!", action: finishOnboarding)
            case .tips:
                primaryButton("Continue") { go(by: 1) }
            default:
                primaryButton("Next") { go(by: 1) }
            }
        }
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.headline).frame(maxWidth: .infinity).padding(.vertical, 4)
        }
        .buttonStyle(.borderedProminent)
    }

    // MARK: Pages

    private var welcomePage: some View {
        ViewThatFits(in: .vertical) {
            welcomeContent
            ScrollView { welcomeContent }
        }
    }

    private var welcomeContent: some View {
        VStack(spacing: 24) {
            WeekCarryOverAnimation()
            Text("Welcome to Tasquel").font(.largeTitle.bold()).multilineTextAlignment(.center)
            VStack(spacing: 12) {
                Text("Your weekly task planner that keeps you on track.")
                    .font(.headline).multilineTextAlignment(.center)
                Text("Tasquel organizes your tasks into weekly checklists. For each task, you choose what happens when the week ends: it's done, it carries over if it's unfinished, or it comes back every week.")
                    .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
        }
        .frame(maxHeight: .infinity)
    }

    /// Scrolls only when the page is taller than the screen (large text sizes).
    private func featurePage(_ title: String, icon: String, items: [FeatureItem]) -> some View {
        ViewThatFits(in: .vertical) {
            featureContent(title, icon: icon, items: items)
            ScrollView { featureContent(title, icon: icon, items: items) }
        }
    }

    private func featureContent(_ title: String, icon: String, items: [FeatureItem]) -> some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundStyle(.blue)
            Text(title)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            VStack(alignment: .leading, spacing: 14) {
                ForEach(items, id: \.title) { item in
                    OnboardingFeatureRow(symbol: item.symbol, title: item.title, detail: item.detail)
                }
            }
            .padding(.horizontal, 24)
        }
        .padding(.vertical, 24)
        .frame(maxHeight: .infinity)
    }

    private var isNameValid: Bool {
        let trimmed = userName.trimmingCharacters(in: .whitespaces)
        return !trimmed.isEmpty && trimmed.count <= 20
    }

    private func saveName() {
        if isNameValid { store.setUserName(userName.trimmingCharacters(in: .whitespaces)) }
    }

    private var namePage: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "person.circle")
                    .font(.system(.largeTitle)).imageScale(.large).foregroundStyle(.blue)
                Text("What's your name?").font(.title2.bold())
                TextField("Your name", text: $userName)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, 48).autocorrectionDisabled()
                    .submitLabel(.next)
                    .onSubmit { if isNameValid { go(by: 1) } }
                Text("1-20 characters").font(.caption).foregroundStyle(.secondary)
            }
            .padding(.top, 60)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private var isNewNameTaken: Bool {
        let name = ChecklistStore.cleanName(newName)
        return selectedCategories.contains { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

    private var categoriesPage: some View {
        VStack(spacing: 16) {
            Text("Set Up Your Categories").font(.title2.bold()).padding(.top, 24)
            Text("Tap a category to remove it, or add your own.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, 24)

            ScrollView {
                LazyVGrid(columns: gridColumns, spacing: 12) {
                    ForEach(selectedCategories) { template in
                        Button {
                            withAnimation(.snappy(duration: 0.2)) {
                                selectedCategories.removeAll { $0.id == template.id }
                            }
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: template.symbol).font(.title2)
                                Text(template.name).font(.caption.bold()).lineLimit(2)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption).foregroundStyle(.secondary).padding(4),
                                alignment: .topTrailing
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove \(template.name)")
                    }

                    if isAddingCategory {
                        VStack(spacing: 6) {
                            Menu {
                                ForEach(CategorySymbols.options.map(\.symbol), id: \.self) { symbol in
                                    Button { newSymbol = symbol } label: {
                                        Label(CategorySymbols.name(for: symbol), systemImage: symbol)
                                    }
                                }
                            } label: {
                                Image(systemName: newSymbol).font(.title2)
                            }
                            .accessibilityLabel("Icon: \(CategorySymbols.name(for: newSymbol))")
                            TextField("Name", text: $newName)
                                .font(.caption).multilineTextAlignment(.center)
                                .onSubmit(addCustomCategory)
                            if isNewNameTaken {
                                Text("Already added").font(.caption2).foregroundStyle(.red)
                            }
                            HStack(spacing: 12) {
                                Button("Cancel") {
                                    isAddingCategory = false; newName = ""
                                }
                                .font(.subheadline)
                                Button("Add") { addCustomCategory() }
                                    .font(.subheadline.bold())
                                    .disabled(ChecklistStore.cleanName(newName).isEmpty || isNewNameTaken)
                            }
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                    } else {
                        Button { isAddingCategory = true } label: {
                            VStack(spacing: 8) {
                                Image(systemName: "plus.circle").font(.title2)
                                Text("Add").font(.caption.bold())
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Add a category")
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }

    private func addCustomCategory() {
        let name = ChecklistStore.cleanName(newName)
        guard !name.isEmpty, !isNewNameTaken else { return }
        selectedCategories.append(CategoryTemplate(name: name, symbol: newSymbol))
        newName = ""
        newSymbol = "folder"
        isAddingCategory = false
    }

    private func finishOnboarding() {
        saveName()
        store.savedCategories = selectedCategories
        store.saveSettings()
        store.replaceCurrentWeekCategories(with: selectedCategories.map {
            Category(name: $0.name, symbol: $0.symbol)
        })
        store.dismissWelcome()
        dismiss()
    }
}

// MARK: - Onboarding Feature Row

struct OnboardingFeatureRow: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: symbol)
                .font(.title2).foregroundStyle(.blue).frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.bold())
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}

#Preview("Onboarding") {
    // Temporary storage so the preview never reads or writes the app's real data.
    OnboardingSheet(store: ChecklistStore(directory: .temporaryDirectory))
}
