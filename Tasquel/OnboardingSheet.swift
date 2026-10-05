import SwiftUI

// MARK: - Onboarding Sheet

struct OnboardingSheet: View {
    let store: ChecklistStore
    @Environment(\.dismiss) private var dismiss

    @State private var step: OnboardingStep = .overview
    @State private var userName = ""
    @State private var selectedCategories = CategoryTemplate.starters
    @State private var newName = ""
    @State private var newSymbol = "folder"
    @State private var isAddingCategory = false
    @State private var featurePage = 0

    enum OnboardingStep {
        case overview, features, name, categories
    }

    private let symbolOptions = [
        "folder", "star", "heart", "house", "cart",
        "briefcase", "figure.run", "book", "paintbrush",
        "music.note", "fork.knife", "airplane", "gift",
        "wrench.and.screwdriver", "leaf", "pawprint",
        "calendar.badge.clock", "lightbulb", "sparkles",
    ]

    private let gridColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .overview: overviewView
                case .features: featuresView
                case .name: nameView
                case .categories: categorySetupView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var overviewView: some View {
        VStack(spacing: 24) {
            Spacer()
            WeekCarryOverAnimation()
            Text("Welcome to Tasquel").font(.largeTitle.bold())
            VStack(spacing: 12) {
                Text("Your weekly task planner that keeps you on track.")
                    .font(.headline).multilineTextAlignment(.center)
                Text("Tasquel organizes your tasks into weekly checklists. If you don't finish something this week, it automatically carries over to the next — so nothing falls through the cracks.")
                    .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            Spacer()
            Button {
                withAnimation(.snappy(duration: 0.3)) { step = .features }
            } label: {
                Text("Next").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 32).padding(.bottom, 32)
        }
    }

    private let featurePages: [(title: String, icon: String, items: [(symbol: String, title: String, detail: String)])] = [
        ("Task Modes", "arrow.triangle.2.circlepath", [
            ("arrow.uturn.forward", "Carry Over",
             "Default mode. If not completed by end of the week, it rolls forward to the next — so nothing falls through the cracks."),
            ("repeat", "Repeating",
             "Appears every week automatically regardless of completion. Great for recurring habits. Resets each new week."),
            ("1.circle", "One-Time",
             "This week only. Will not carry forward or repeat, whether completed or not."),
        ]),
        ("Task Types", "checklist.checked", [
            ("checkmark.circle", "Checkbox",
             "Standard task — tap the circle to mark complete. Add sub-tasks to break it down further."),
            ("target", "Goal",
             "Track numeric progress toward a target (e.g. 30/50 push-ups). Auto-completes when the target is reached."),
        ]),
        ("Quick Tips", "lightbulb", [
            ("pencil", "Edit Mode",
             "Tap the pencil icon to add categories, change task modes, and manage tasks."),
            ("hand.draw", "Double-Tap to Edit",
             "Double-tap any task title to edit it inline."),
            ("hand.tap", "Long-Press Menus",
             "Long-press tasks or category cards for quick actions like save, remove, or change type."),
        ]),
    ]

    private var featuresView: some View {
        VStack(spacing: 0) {
            Text("How It Works").font(.title2.bold()).padding(.top, 24)

            TabView(selection: $featurePage) {
                ForEach(Array(featurePages.enumerated()), id: \.offset) { index, page in
                    VStack(spacing: 20) {
                        Image(systemName: page.icon)
                            .font(.system(size: 40))
                            .foregroundStyle(.blue)
                        Text(page.title)
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(page.items, id: \.title) { item in
                                OnboardingFeatureRow(symbol: item.symbol, title: item.title, detail: item.detail)
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    .padding(.bottom, 40)
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(spacing: 8) {
                ForEach(0..<featurePages.count, id: \.self) { index in
                    Circle()
                        .fill(index == featurePage ? Color.blue : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .scaleEffect(index == featurePage ? 1.2 : 1.0)
                        .animation(.snappy(duration: 0.2), value: featurePage)
                }
            }
            .padding(.bottom, 16)

            Button {
                if featurePage < featurePages.count - 1 {
                    withAnimation { featurePage += 1 }
                } else {
                    withAnimation(.snappy(duration: 0.3)) { step = .name }
                }
            } label: {
                Text(featurePage < featurePages.count - 1 ? "Next" : "Continue")
                    .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 32).padding(.bottom, 32)
        }
    }

    private var nameView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "person.circle")
                .font(.system(size: 60)).foregroundStyle(.blue)
            Text("What's your name?").font(.title2.bold())
            TextField("Your name", text: $userName)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 48).autocorrectionDisabled()
            Text("1-20 characters").font(.caption).foregroundStyle(.secondary)
            Spacer()
            VStack(spacing: 12) {
                Button {
                    let trimmed = userName.trimmingCharacters(in: .whitespaces)
                    store.setUserName(trimmed)
                    withAnimation(.snappy(duration: 0.3)) { step = .categories }
                } label: {
                    Text("Next").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .disabled(userName.trimmingCharacters(in: .whitespaces).isEmpty || userName.count > 20)

                Button {
                    withAnimation(.snappy(duration: 0.3)) { step = .categories }
                } label: {
                    Text("Skip").font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 32).padding(.bottom, 32)
        }
    }

    private var categorySetupView: some View {
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
                                Text(template.name).font(.caption.bold()).lineLimit(1)
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
                    }

                    if isAddingCategory {
                        VStack(spacing: 6) {
                            Menu {
                                ForEach(symbolOptions, id: \.self) { symbol in
                                    Button { newSymbol = symbol } label: {
                                        Label(symbol, systemImage: symbol)
                                    }
                                }
                            } label: {
                                Image(systemName: newSymbol).font(.title2)
                            }
                            TextField("Name", text: $newName)
                                .font(.caption).multilineTextAlignment(.center)
                                .onSubmit(addCustomCategory)
                            HStack(spacing: 8) {
                                Button("Cancel") {
                                    isAddingCategory = false; newName = ""
                                }
                                .font(.system(size: 10))
                                Button("Add") { addCustomCategory() }
                                    .font(.system(size: 10).bold())
                                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
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
                    }
                }
                .padding(.horizontal, 24)
            }

            Spacer()

            Button { finishOnboarding() } label: {
                Text("Let's Go!").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 32).padding(.bottom, 32)
        }
    }

    private func addCustomCategory() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        selectedCategories.append(CategoryTemplate(name: name, symbol: newSymbol))
        newName = ""
        newSymbol = "folder"
        isAddingCategory = false
    }

    private func finishOnboarding() {
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
