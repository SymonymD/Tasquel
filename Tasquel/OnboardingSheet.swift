import SwiftUI

// MARK: - Onboarding Sheet

struct OnboardingSheet: View {
    let store: ChecklistStore
    @Environment(\.dismiss) private var dismiss

    @State private var page: Page = .welcome

    /// Every step is a page: swipe between them, or use Next and Back.
    private enum Page: Int, CaseIterable {
        case welcome, types, modes, categories, calendar
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TabView(selection: $page) {
                    illustratedPage(.welcome)
                    illustratedPage(.types)
                    illustratedPage(.modes)
                    illustratedPage(.categories)
                    illustratedPage(.calendar)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                pageDots.padding(.vertical, 12)
                bottomButton
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

    private var bottomButton: some View {
        let isLast = page == Page.allCases.last
        return Button {
            if isLast { finishOnboarding() } else { go(by: 1) }
        } label: {
            Text(isLast ? "Let's Go!" : "Next")
                .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 4)
        }
        .buttonStyle(.borderedProminent)
    }

    // MARK: Pages

    /// Scrolls only when the page is taller than the screen (large text sizes).
    private func illustratedPage(_ page: Page) -> some View {
        ViewThatFits(in: .vertical) {
            pageContent(page)
            ScrollView { pageContent(page) }
        }
        .tag(page)
    }

    private func pageContent(_ page: Page) -> some View {
        VStack(spacing: 24) {
            illustration(for: page)
            switch page {
            case .welcome:
                Text("Welcome to Tasquel").font(.largeTitle.bold()).multilineTextAlignment(.center)
                VStack(spacing: 12) {
                    Text("Your weekly task planner that keeps you on track.")
                        .font(.headline).multilineTextAlignment(.center)
                    Text("Tasquel organizes your tasks into weekly checklists. For each task, you choose what happens when the week ends: it's done, it carries over if it's unfinished, or it comes back every week.")
                        .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)
            case .types:
                featureText("Three Kinds of Task",
                            "Tick off a checkbox, work toward a goal like 50 push-ups, or fill a list like Groceries. Goals and lists check themselves off when they're done.")
            case .modes:
                featureText("You Decide What Happens Next",
                            "When the week ends, one-time tasks stay behind, carry-over tasks move on if they're unfinished, and repeating tasks come back unchecked. Tap the icons at the end of a task to choose.")
            case .categories:
                featureText("Organized by Category",
                            "Your tasks live in category cards. Tap a card to open it, or tap the grid button to add, remove and rearrange categories.")
            case .calendar:
                featureText("Your Calendar, Alongside",
                            "See the week's events next to your tasks. Turn on Show Calendar Events in Settings, then tap the calendar button at the bottom.")
            }
        }
        .padding(.vertical, 24)
        .frame(maxHeight: .infinity)
    }

    @ViewBuilder
    private func illustration(for page: Page) -> some View {
        switch page {
        case .welcome: WeekCarryOverAnimation()
        case .types: TaskTypesAnimation()
        case .modes: TaskModesAnimation()
        case .categories: CategoryCardsAnimation()
        case .calendar: CalendarEventsAnimation()
        }
    }

    private func featureText(_ title: LocalizedStringKey, _ detail: LocalizedStringKey) -> some View {
        VStack(spacing: 12) {
            Text(title).font(.title.bold()).multilineTextAlignment(.center)
            Text(detail).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
    }

    private func finishOnboarding() {
        store.dismissWelcome()
        dismiss()
    }
}

#Preview("Onboarding") {
    // Temporary storage so the preview never reads or writes the app's real data.
    OnboardingSheet(store: ChecklistStore(directory: .temporaryDirectory))
}
