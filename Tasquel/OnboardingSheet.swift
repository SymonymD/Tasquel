import SwiftUI

// MARK: - Onboarding Sheet

struct OnboardingSheet: View {
    let store: ChecklistStore
    let calendar: CalendarService
    /// Opened from Settings ▸ Show Welcome Tour: adds pages on features newer than the
    /// first-launch tour, and the buttons say Close and Done.
    var isReplay = false
    @Environment(\.dismiss) private var dismiss

    @State private var page: Page = .welcome

    /// Every step is a page: swipe between them, or use Next and Back.
    private enum Page: Int, CaseIterable {
        case welcome, types, modes, categories, calendar
        // Welcome Tour only.
        case smartAdd, tidyUp, goalSteps
    }

    /// The Smart Add page shows only where Smart Add can run (Apple Intelligence), and the
    /// calendar page only while calendar events are offered (`FeatureAccess`).
    private var pages: [Page] {
        let calendar = FeatureAccess.isCalendarUnlocked
        guard isReplay else {
            return [.welcome, .types, .modes, .categories, .calendar].filter { $0 != .calendar || calendar }
        }
        let smartAdd = SmartAddParser.current.isAvailable
        return Page.allCases.filter { ($0 != .smartAdd || smartAdd) && ($0 != .calendar || calendar) }
    }

    private var pageIndex: Int { pages.firstIndex(of: page) ?? 0 }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TabView(selection: $page) {
                    ForEach(pages, id: \.self) { illustratedPage($0) }
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
                if page != pages.last {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(isReplay ? "Close" : "Skip", action: finishOnboarding)
                    }
                }
            }
        }
    }

    private func go(by offset: Int) {
        let index = pageIndex + offset
        guard pages.indices.contains(index) else { return }
        withAnimation(.snappy(duration: 0.3)) { page = pages[index] }
    }

    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(pages, id: \.self) { dot in
                Circle()
                    .fill(dot == page ? Color.blue : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .scaleEffect(dot == page ? 1.2 : 1.0)
                    .animation(.snappy(duration: 0.2), value: page)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Page \(pageIndex + 1) of \(pages.count)")
    }

    private var bottomButton: some View {
        let isLast = page == pages.last
        return Button {
            if isLast { finishOnboarding() } else { go(by: 1) }
        } label: {
            Text(isLast ? (isReplay ? "Done" : "Let's Go!") : "Next")
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
                    Text("Tasquel organizes your tasks into weekly checklists. For each task, you choose what happens when the week ends: it stays behind, it carries over if it's unfinished, or it comes back every week.")
                        .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)
            case .types:
                featureText("Three Kinds of Task",
                            "Tick off a checkbox, work toward a goal like 50 push-ups, or fill a list like Groceries. Goals and lists check themselves off when they're done.")
                // Smart Add, only where it can run (Apple Intelligence on).
                if SmartAddParser.current.isAvailable {
                    Text("\(Image(systemName: "sparkles")) Or type it in your own words, like “Gym 3x per week”, and tap the sparkles to set it up for you.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            case .modes:
                featureText("You Decide What Happens Next",
                            "When the week ends, one-time tasks stay behind, carry-over tasks move on if they're unfinished, and repeating tasks come back unchecked. New tasks start as one-time; tap the icons at the end of a task to choose.")
            case .categories:
                featureText("Organized by Category",
                            "Your tasks live in category cards. Tap a card to open it, and Add Task to add one. Hold and drag a closed card to move it. Tap Edit at the bottom to add or delete categories. Deleted something by mistake? Tap Undo.")
            case .calendar:
                featureText("Your Calendar, Alongside",
                            "Tap the calendar button between the week arrows to see the week's events. Swipe them to change week, and your cards come along; This Week brings you back. You can turn this on now, or later in Settings.")
                calendarButton
            case .smartAdd:
                featureText("Smart Add",
                            "Type a task in your own words, like “Gym 3x per week”, and tap the sparkles: it becomes a repeating goal of 3. “Meditate 10 min daily” becomes 70 minutes for the week, 10 a tap. If it guessed wrong, tap Undo in the note under the new task.")
            case .tidyUp:
                featureText("Tidy Up",
                            "Deleting doesn't ask first: tap Undo in the message to bring it back. Pull the cards down from the top and let go to close them all.")
            case .goalSteps:
                featureText("Goals, Step by Step",
                            "Tap + to count progress and − to take it back. Each tap adds a step that suits the goal; set your own with the sliders beside the bar, like 20 for 100 push-ups. + keeps counting past the target.")
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
        case .smartAdd: SmartAddAnimation()
        case .tidyUp: TidyUpAnimation()
        case .goalSteps: GoalStepsAnimation()
        }
    }

    /// Turns on calendar events here, where the reason for asking was just shown, before
    /// iOS asks for access.
    @ViewBuilder
    private var calendarButton: some View {
        if store.calendarEventsEnabled && calendar.isAuthorized {
            Label("Calendar Events On", systemImage: "checkmark.circle.fill")
                .font(.subheadline.bold())
                .foregroundStyle(.green)
        } else if calendar.authorization == .denied || calendar.authorization == .restricted {
            Text(calendar.authorization == .restricted
                 ? "Calendar access is restricted on this device."
                 : "Tasquel doesn't have access to your calendars. Turn on Full Access for Tasquel in the Settings app.")
                .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        } else {
            Button("Turn On Calendar Events", systemImage: "calendar") {
                Task { await CalendarSettingsRows.turnOn(store: store, calendar: calendar) }
            }
            .buttonStyle(.bordered)
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
    OnboardingSheet(store: ChecklistStore(directory: .temporaryDirectory), calendar: CalendarService(provider: FakeEventProvider()))
}
