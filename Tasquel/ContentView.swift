import SwiftUI

// MARK: - Root View

struct ContentView: View {
    @State var store = ChecklistStore()
    @State private var showDatePicker = false
    @State private var showSettings = false
    @State private var showAddCategory = false
    @State private var expandedCategoryID: UUID? = nil
    @State private var isEditing = false
    @State private var showOnboarding = false

    private var theme: AppearanceMode { store.appearanceMode }
    private var rc: RetroColor { store.retroColor }

    private var isPastWeek: Bool {
        store.selectedWeek?.isPastWeek ?? false
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.background(theme).ignoresSafeArea()

            VStack(spacing: 12) {
                if Theme.isRetro(theme) {
                    Text("> \(store.selectedWeek?.displayTitle ?? "Tasquel")_")
                        .font(Theme.titleFont(theme))
                        .padding(.top, 8)
                } else {
                    Text(store.selectedWeek?.displayTitle ?? "Tasquel")
                        .font(Theme.titleFont(theme))
                        .padding(.top, 8)
                }

                weekNavigationBar

                if let week = store.selectedWeek {
                    weekContent(week)
                } else {
                    Spacer()
                    ContentUnavailableView("No Week Data", systemImage: "calendar.badge.exclamationmark")
                    Spacer()
                }
            }

            bottomBar
                .padding(.horizontal, 16)
                .padding(.bottom, 4)

            // Retro scanline overlay
            if Theme.isRetro(theme) {
                ScanlineOverlay()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .foregroundStyle(Theme.textPrimary(theme, rc: rc))
        .preferredColorScheme(store.colorScheme)
        .sheet(isPresented: $showDatePicker) {
            DatePickerSheet(selectedDate: store.selectedDate) { date in
                withAnimation { store.navigateToDate(date) }
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet(store: store)
        }
        .sheet(isPresented: $showAddCategory) {
            AddCategorySheet(store: store) { name, symbol in
                store.addCategory(name: name, symbol: symbol)
                isEditing = false
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingSheet(store: store)
                .interactiveDismissDisabled()
        }
        .onAppear {
            if store.shouldShowWelcome {
                showOnboarding = true
            }
        }
        .onChange(of: store.selectedDate) {
            if isPastWeek { isEditing = false }
            expandedCategoryID = nil
        }
    }

    // MARK: - Navigation Capsule

    private var weekNavigationBar: some View {
        HStack(spacing: 20) {
            Button {
                withAnimation { store.navigateWeek(by: -1) }
            } label: {
                Image(systemName: "chevron.left").font(.body.bold())
            }
            .buttonStyle(.plain)
            Button { showDatePicker = true } label: {
                Image(systemName: "calendar").font(.body)
            }
            .buttonStyle(.plain)
            Button {
                withAnimation { store.navigateWeek(by: 1) }
            } label: {
                Image(systemName: "chevron.right").font(.body.bold())
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(Theme.textPrimary(theme, rc: rc))
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background {
            if Theme.isRetro(theme) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Theme.navCapsule(theme))
                    .overlay(RoundedRectangle(cornerRadius: 2).stroke(Theme.cardBorder(theme, rc: rc), lineWidth: 1))
            } else {
                Capsule().fill(Theme.navCapsule(theme))
            }
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack {
            Button { showSettings = true } label: {
                Image(systemName: Theme.isRetro(theme) ? "terminal" : "gearshape.fill")
                    .font(.title3)
                    .foregroundStyle(Theme.textSecondary(theme, rc: rc))
                    .frame(width: 48, height: 48)
                    .background(Theme.cardFill(theme), in: Theme.isRetro(theme) ? AnyShape(RoundedRectangle(cornerRadius: 2)) : AnyShape(Circle()))
                    .overlay {
                        if Theme.isRetro(theme) {
                            RoundedRectangle(cornerRadius: 2).stroke(Theme.cardBorder(theme, rc: rc), lineWidth: 1)
                        }
                    }
            }
            .buttonStyle(.plain)

            Spacer()

            if store.selectedWeek?.isCurrentWeek == true {
                Text(Theme.isRetro(theme) ? "[\(todayDateString)]" : todayDateString)
                    .font(Theme.isRetro(theme) ? .system(.subheadline, design: .monospaced).bold() : .subheadline.bold())
            } else {
                Button {
                    withAnimation { store.navigateToDate(Date()) }
                } label: {
                    VStack(spacing: 1) {
                        Text(Theme.isRetro(theme) ? "[\(todayDateString)]" : todayDateString)
                            .font(Theme.isRetro(theme) ? .system(.subheadline, design: .monospaced).bold() : .subheadline.bold())
                        Text(Theme.isRetro(theme) ? "> GO_TO_TODAY" : "Go to Today")
                            .font(Theme.isRetro(theme) ? .system(.caption2, design: .monospaced) : .caption2)
                            .foregroundStyle(Theme.accent(theme, rc: rc))
                    }
                }
                .buttonStyle(.plain)
            }

            Spacer()

            if !isPastWeek {
                Button {
                    withAnimation(.snappy(duration: 0.25)) { isEditing.toggle() }
                } label: {
                    if isEditing {
                        Image(systemName: "checkmark")
                            .font(.title3).foregroundStyle(Theme.isRetro(theme) ? Theme.dotComplete(theme, rc: rc) : .green)
                            .frame(width: 48, height: 48)
                            .background(Theme.isRetro(theme) ? Theme.cardFill(theme) : .green.opacity(0.15), in: Theme.isRetro(theme) ? AnyShape(RoundedRectangle(cornerRadius: 2)) : AnyShape(Circle()))
                            .overlay {
                                if Theme.isRetro(theme) {
                                    RoundedRectangle(cornerRadius: 2).stroke(Theme.dotComplete(theme, rc: rc), lineWidth: 1.5)
                                } else {
                                    Circle().stroke(.green, lineWidth: 1.5)
                                }
                            }
                    } else {
                        Image(systemName: "pencil")
                            .font(.title3)
                            .foregroundStyle(Theme.textSecondary(theme, rc: rc))
                            .frame(width: 48, height: 48)
                            .background(Theme.cardFill(theme), in: Theme.isRetro(theme) ? AnyShape(RoundedRectangle(cornerRadius: 2)) : AnyShape(Circle()))
                            .overlay {
                                if Theme.isRetro(theme) {
                                    RoundedRectangle(cornerRadius: 2).stroke(Theme.cardBorder(theme, rc: rc), lineWidth: 1)
                                }
                            }
                    }
                }
                .buttonStyle(.plain)
            } else {
                Color.clear.frame(width: 48, height: 48)
            }
        }
    }

    private var todayDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        let base = formatter.string(from: Date())
        let day = Calendar.current.component(.day, from: Date())
        let suffix: String
        switch day {
        case 1, 21, 31: suffix = "st"
        case 2, 22: suffix = "nd"
        case 3, 23: suffix = "rd"
        default: suffix = "th"
        }
        return "\(base)\(suffix)"
    }

    // MARK: - Week Content

    @ViewBuilder
    private func weekContent(_ week: Week) -> some View {
        let categories = week.categories
        let showAdd = isEditing && !week.isPastWeek

        ScrollView {
            VStack(spacing: 8) {
                let rows = buildGridRows(categories: categories, showAddButton: showAdd)
                ForEach(rows) { row in
                    if row.isAddRow && row.left == nil {
                        // Standalone add button row (even category count)
                        HStack(spacing: 8) {
                            addCategoryButton
                            Color.clear.frame(maxWidth: .infinity)
                        }
                    } else if row.isAddRow && row.left != nil {
                        // Add button fills empty right slot (odd category count)
                        let leftExpanded = expandedCategoryID != nil && row.left?.id == expandedCategoryID
                        HStack(spacing: leftExpanded ? 0 : 8) {
                            if leftExpanded {
                                gridCardSlot(row.left, week: week)
                                Color.clear.frame(width: 0)
                            } else {
                                gridCardSlot(row.left, week: week)
                                addCategoryButton
                            }
                        }
                    } else {
                        let leftExpanded = expandedCategoryID != nil && row.left?.id == expandedCategoryID
                        let rightExpanded = expandedCategoryID != nil && row.right?.id == expandedCategoryID
                        let rowHasExpanded = leftExpanded || rightExpanded

                        HStack(spacing: rowHasExpanded ? 0 : 8) {
                            // Left slot
                            if rightExpanded {
                                Color.clear.frame(width: 0)
                            } else {
                                gridCardSlot(row.left, week: week)
                            }

                            // Right slot
                            if leftExpanded {
                                Color.clear.frame(width: 0)
                            } else {
                                gridCardSlot(row.right, week: week)
                            }
                        }
                    }
                }

                if categories.isEmpty && !isEditing {
                    ContentUnavailableView(
                        "No Categories",
                        systemImage: "folder.badge.plus",
                        description: Text("Tap the pencil to add categories.")
                    )
                    .padding(.top, 40)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 80)
        }
    }

    // MARK: - Grid Layout Helpers

    // Stable row IDs keyed by position — never changes between reflows
    private static let stableRowIDs: [UUID] = (0..<20).map {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", $0))!
    }

    private struct GridRow: Identifiable {
        let id: UUID
        let left: Category?
        let right: Category?
        var isAddRow: Bool = false
    }

    private func buildGridRows(categories: [Category], showAddButton: Bool) -> [GridRow] {
        let ids = ContentView.stableRowIDs
        var rows: [GridRow] = []
        var i = 0
        while i < categories.count {
            let left = categories[i]
            let right = (i + 1 < categories.count) ? categories[i + 1] : nil
            rows.append(GridRow(id: ids[rows.count], left: left, right: right))
            i += 2
        }
        if showAddButton {
            if let last = rows.last, last.right == nil, last.left != nil {
                rows[rows.count - 1] = GridRow(id: last.id, left: last.left, right: nil, isAddRow: true)
            } else {
                rows.append(GridRow(id: ids[rows.count], left: nil, right: nil, isAddRow: true))
            }
        }
        return rows
    }

    /// Renders a single grid slot — collapsed card, expanded card, or shrunk-to-zero neighbor
    @ViewBuilder
    private func gridCardSlot(_ category: Category?, week: Week) -> some View {
        if let category {
            let isExpanded = category.id == expandedCategoryID
            let neighborExpanded = !isExpanded && expandedCategoryID != nil

            if isExpanded {
                ExpandedCategoryCard(
                    category: category,
                    store: store,
                    isEditing: isEditing,
                    isPastWeek: week.isPastWeek,
                    onToggleEdit: { withAnimation(.snappy(duration: 0.25)) { isEditing.toggle() } },
                    onCollapse: {
                        withAnimation(.easeOut(duration: 0.7)) {
                            expandedCategoryID = nil
                        }
                    }
                )
                .id(category.id)
                .transition(.identity)
            } else {
                CategoryCard(category: category, store: store, dimmed: neighborExpanded, isEditing: isEditing) {
                    withAnimation(.easeOut(duration: 0.7)) {
                        expandedCategoryID = category.id
                    }
                }
                .id(category.id)
                .transition(.identity)
            }
        } else {
            Color.clear.frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var addCategoryButton: some View {
        Button { showAddCategory = true } label: {
            VStack(spacing: 8) {
                Image(systemName: Theme.isRetro(theme) ? "plus.square" : "plus")
                    .font(.title2).foregroundStyle(Theme.textSecondary(theme, rc: rc))
                Text(Theme.isRetro(theme) ? "+ NEW_CATEGORY" : "Add Category")
                    .font(Theme.captionFont(theme)).foregroundStyle(Theme.textSecondary(theme, rc: rc))
            }
            .frame(maxWidth: .infinity, minHeight: 140)
            .background(
                RoundedRectangle(cornerRadius: Theme.cardCornerRadius(theme))
                    .strokeBorder(style: StrokeStyle(lineWidth: Theme.isRetro(theme) ? 1 : 2, dash: Theme.isRetro(theme) ? [] : [8]))
                    .foregroundStyle(Theme.isRetro(theme) ? Theme.cardBorder(theme, rc: rc) : Theme.textTertiary(theme, rc: rc))
            )
        }
        .buttonStyle(.plain)
    }
}
