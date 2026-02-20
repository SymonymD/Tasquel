import SwiftUI

// MARK: - Design System

/// Mode-aware theme resolved per-render from the store's appearanceMode.
/// Pass the mode explicitly to each property so SwiftUI re-evaluates when the
/// observable `store.appearanceMode` changes — no stale static var.
enum Theme {
    // Retro color palettes (bright, dim, faint)
    private static func retroPalette(_ c: RetroColor) -> (Color, Color, Color) {
        switch c {
        case .green:
            (Color(red: 0.2, green: 1.0, blue: 0.2),
             Color(red: 0.15, green: 0.7, blue: 0.15),
             Color(red: 0.1, green: 0.4, blue: 0.1))
        case .amber:
            (Color(red: 1.0, green: 0.75, blue: 0.0),
             Color(red: 0.7, green: 0.5, blue: 0.0),
             Color(red: 0.4, green: 0.3, blue: 0.0))
        case .blue:
            (Color(red: 0.3, green: 0.7, blue: 1.0),
             Color(red: 0.2, green: 0.5, blue: 0.7),
             Color(red: 0.1, green: 0.3, blue: 0.4))
        case .white:
            (Color(white: 0.95),
             Color(white: 0.65),
             Color(white: 0.35))
        case .red:
            (Color(red: 1.0, green: 0.3, blue: 0.3),
             Color(red: 0.7, green: 0.2, blue: 0.2),
             Color(red: 0.4, green: 0.1, blue: 0.1))
        case .purple:
            (Color(red: 0.75, green: 0.4, blue: 1.0),
             Color(red: 0.5, green: 0.25, blue: 0.7),
             Color(red: 0.3, green: 0.15, blue: 0.4))
        }
    }

    /// Convenience to get the color for a swatch preview
    static func retroBright(_ c: RetroColor) -> Color { retroPalette(c).0 }

    // Helpers
    static func isRetro(_ m: AppearanceMode) -> Bool { m == .retro }
    static func isDark(_ m: AppearanceMode) -> Bool { m == .dark }
    static func isCustomDark(_ m: AppearanceMode) -> Bool { m == .dark || m == .retro }

    // Core backgrounds
    static func background(_ m: AppearanceMode) -> Color {
        switch m {
        case .retro: .black
        case .dark: Color(red: 0, green: 0, blue: 20.0/255)
        case .system, .light: Color(.systemBackground)
        }
    }
    static func cardFill(_ m: AppearanceMode) -> Color {
        switch m {
        case .retro: Color(white: 0.06)
        case .dark: Color(red: 55.0/255, green: 55.0/255, blue: 84.0/255)
        case .system, .light: Color(.secondarySystemGroupedBackground)
        }
    }
    static func navCapsule(_ m: AppearanceMode) -> Color {
        switch m {
        case .retro: Color(white: 0.1)
        case .dark: Color(white: 33.0/255, opacity: 0.2)
        case .system, .light: Color(.systemGray5)
        }
    }

    // Task dot colors — retro uses the phosphor bright color
    static func dotComplete(_ m: AppearanceMode, rc: RetroColor = .green) -> Color {
        isRetro(m) ? retroPalette(rc).0 : .green
    }
    static func dotIncomplete(_ m: AppearanceMode) -> Color {
        isRetro(m) ? .red.opacity(0.8) : .red
    }

    // Completion icon colors
    static func completionAll(_ m: AppearanceMode, rc: RetroColor = .green) -> Color { isRetro(m) ? retroPalette(rc).0 : .green }
    static func completionPartial(_ m: AppearanceMode) -> Color { isRetro(m) ? .yellow : .orange }
    static func completionNone(_ m: AppearanceMode) -> Color { isRetro(m) ? .red.opacity(0.8) : .red }

    // Accent
    static func accent(_ m: AppearanceMode, rc: RetroColor = .green) -> Color { isRetro(m) ? retroPalette(rc).0 : .blue }
    static func destructive(_ m: AppearanceMode) -> Color { isRetro(m) ? .red.opacity(0.8) : .red }

    // Text
    static func textPrimary(_ m: AppearanceMode, rc: RetroColor = .green) -> Color {
        switch m {
        case .retro: retroPalette(rc).0
        case .dark: .white
        case .system, .light: Color(.label)
        }
    }
    static func textSecondary(_ m: AppearanceMode, rc: RetroColor = .green) -> Color {
        switch m {
        case .retro: retroPalette(rc).1
        case .dark: .white.opacity(0.6)
        case .system, .light: Color(.secondaryLabel)
        }
    }
    static func textTertiary(_ m: AppearanceMode, rc: RetroColor = .green) -> Color {
        switch m {
        case .retro: retroPalette(rc).2
        case .dark: .white.opacity(0.35)
        case .system, .light: Color(.tertiaryLabel)
        }
    }

    // Card
    static func cardCornerRadius(_ m: AppearanceMode) -> CGFloat { isRetro(m) ? 2 : 12 }
    static func cardShadow(_ m: AppearanceMode, rc: RetroColor = .green) -> Color {
        switch m {
        case .retro: retroPalette(rc).2.opacity(0.3)
        case .dark: .black.opacity(0.3)
        case .system, .light: .black.opacity(0.08)
        }
    }
    static func cardBorder(_ m: AppearanceMode, rc: RetroColor = .green) -> Color { isRetro(m) ? retroPalette(rc).1 : .clear }
    static func cardBorderWidth(_ m: AppearanceMode) -> CGFloat { isRetro(m) ? 1 : 0 }

    // Font
    static func primaryFont(_ m: AppearanceMode) -> Font { isRetro(m) ? .system(.subheadline, design: .monospaced).bold() : .subheadline.bold() }
    static func bodyFont(_ m: AppearanceMode) -> Font { isRetro(m) ? .system(.subheadline, design: .monospaced) : .subheadline }
    static func captionFont(_ m: AppearanceMode) -> Font { isRetro(m) ? .system(.caption, design: .monospaced) : .caption }
    static func titleFont(_ m: AppearanceMode) -> Font { isRetro(m) ? .system(.title, design: .monospaced).bold() : .title.bold() }
}

// MARK: - Scanline Overlay (Retro)

struct ScanlineOverlay: View {
    var body: some View {
        Canvas { context, size in
            for y in stride(from: 0, to: size.height, by: 3) {
                let rect = CGRect(x: 0, y: y, width: size.width, height: 1)
                context.fill(Path(rect), with: .color(.black.opacity(0.15)))
            }
        }
    }
}

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

        // Build a flat list of grid slots: each category + optional "Add" placeholder
        // Expanded card stays in its row, neighbor bumps down, rest re-pairs
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
                                // Right card is expanding — hide left
                                Color.clear.frame(width: 0)
                            } else {
                                gridCardSlot(row.left, week: week)
                            }

                            // Right slot
                            if leftExpanded {
                                // Left card is expanding — hide right
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
            // If last row has an empty right slot, put add button there
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

// MARK: - Category Card (Collapsed)

struct CategoryCard: View {
    let category: Category
    let store: ChecklistStore
    var dimmed: Bool = false
    var isEditing: Bool = false
    let onExpand: () -> Void

    private var theme: AppearanceMode { store.appearanceMode }
    private var rc: RetroColor { store.retroColor }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                if !Theme.isRetro(theme) {
                    Image(systemName: category.symbol).font(.subheadline)
                }
                Text(Theme.isRetro(theme) ? "[\(category.name.uppercased())]" : category.name)
                    .font(Theme.primaryFont(theme)).lineLimit(1)
                Spacer()
                completionIcon(for: category)
            }

            Text(Theme.isRetro(theme) ? "done: \(category.completedCount)/\(category.totalCount)" : "Completed: \(category.completedCount)/\(category.totalCount)")
                .font(Theme.captionFont(theme)).foregroundStyle(Theme.textSecondary(theme, rc: rc))

            VStack(alignment: .leading, spacing: 3) {
                ForEach(category.tasks.prefix(5)) { task in
                    HStack(spacing: 6) {
                        if Theme.isRetro(theme) {
                            Text(task.isCompleted ? "[x]" : "[ ]")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(task.isCompleted ? Theme.dotComplete(theme, rc: rc) : Theme.dotIncomplete(theme))
                        } else {
                            Circle()
                                .fill(task.isCompleted ? Theme.dotComplete(theme, rc: rc) : Theme.dotIncomplete(theme))
                                .frame(width: 7, height: 7)
                        }
                        Text(task.title)
                            .font(Theme.isRetro(theme) ? .system(.caption2, design: .monospaced) : .caption2)
                            .foregroundStyle(Theme.textSecondary(theme, rc: rc)).lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 0)

            HStack {
                Spacer()
                if Theme.isRetro(theme) {
                    Text("[OPEN]").font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Theme.textTertiary(theme, rc: rc))
                } else {
                    Image(systemName: "arrow.up.forward")
                        .font(.caption).foregroundStyle(Theme.textTertiary(theme, rc: rc))
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius(theme))
                .fill(Theme.cardFill(theme))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cardCornerRadius(theme))
                        .stroke(Theme.cardBorder(theme, rc: rc), lineWidth: Theme.cardBorderWidth(theme))
                )
                .shadow(color: Theme.cardShadow(theme, rc: rc), radius: Theme.isRetro(theme) ? 8 : (dimmed ? 2 : 6), x: 0, y: Theme.isRetro(theme) ? 0 : (dimmed ? 1 : 3))
        }
        .overlay {
            if dimmed {
                RoundedRectangle(cornerRadius: Theme.cardCornerRadius(theme))
                    .fill(Color.black.opacity(0.08))
            }
        }
        .overlay(alignment: .topTrailing) {
            if isEditing {
                Button {
                    withAnimation { store.deleteCategory(category.id) }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white, .red)
                }
                .buttonStyle(.plain)
                .offset(x: 8, y: -8)
            }
        }
        .onTapGesture { onExpand() }
        .contextMenu {
            Button("Save for Future Use", systemImage: "square.and.arrow.down") {
                store.saveCategoryAsTemplate(category.id)
            }
            Divider()
            Button("Remove from This Week", systemImage: "xmark.circle", role: .destructive) {
                withAnimation { store.deleteCategory(category.id) }
            }
            Button("Delete Entirely", systemImage: "trash", role: .destructive) {
                withAnimation {
                    store.savedCategories.removeAll { $0.name == category.name }
                    store.saveSettings()
                    store.deleteCategory(category.id)
                }
            }
        }
    }

    private func completionIcon(for category: Category) -> some View {
        let total = category.totalCount
        let completed = category.completedCount
        let color: Color = total == 0 ? .gray : completed == 0 ? Theme.completionNone(theme) : completed == total ? Theme.completionAll(theme, rc: rc) : Theme.completionPartial(theme)
        if Theme.isRetro(theme) {
            return AnyView(
                Text(completed == total && total > 0 ? "[OK]" : "[\(completed)/\(total)]")
                    .font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(color)
            )
        } else {
            return AnyView(
                Image(systemName: "chart.pie.fill")
                    .font(.body)
                    .foregroundStyle(color)
            )
        }
    }
}

// MARK: - Expanded Category Card

struct ExpandedCategoryCard: View {
    let category: Category
    let store: ChecklistStore
    let isEditing: Bool
    let isPastWeek: Bool
    let onToggleEdit: () -> Void
    let onCollapse: () -> Void

    private var theme: AppearanceMode { store.appearanceMode }
    private var rc: RetroColor { store.retroColor }

    @State private var showDeleteOptions = false

    private let expandedScale: CGFloat = 1.1

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(alignment: .bottom) {
                if !Theme.isRetro(theme) {
                    Image(systemName: category.symbol).font(.body)
                        .scaleEffect(expandedScale)
                }
                Text(Theme.isRetro(theme) ? "[\(category.name.uppercased())]" : category.name)
                    .font(Theme.isRetro(theme) ? .system(.title3, design: .monospaced) : .title3)
                Spacer()
                if !isPastWeek {
                    Button { onToggleEdit() } label: {
                        Image(systemName: isEditing ? "checkmark.circle.fill" : "square.and.pencil")
                            .font(.system(size: 20))
                            .foregroundStyle(isEditing ? .green : Theme.textSecondary(theme, rc: rc))
                    }
                    .buttonStyle(.plain)
                }
                completionIcon(for: category)
            }

            Text(Theme.isRetro(theme) ? "done: \(category.completedCount)/\(category.totalCount)" : "Completed: \(category.completedCount)/\(category.totalCount)")
                .font(Theme.isRetro(theme) ? .system(.subheadline, design: .monospaced) : .subheadline)
                .foregroundStyle(Theme.textSecondary(theme, rc: rc))

            Divider().padding(.vertical, 2)

            // Tasks
            ForEach(category.tasks) { task in
                TaskRowCard(
                    task: task,
                    categoryID: category.id,
                    store: store,
                    isEditing: isEditing,
                    isPastWeek: isPastWeek
                )
            }

            // Add task
            if !isPastWeek {
                AddTaskRowCard(categoryID: category.id, store: store)
            }

            // Collapse arrow
            HStack {
                Spacer()
                Button { onCollapse() } label: {
                    if Theme.isRetro(theme) {
                        Text("[CLOSE]").font(.system(.caption, design: .monospaced))
                            .foregroundStyle(Theme.textTertiary(theme, rc: rc))
                    } else {
                        Image(systemName: "rectangle.compress.vertical")
                            .font(.system(size: 20)).foregroundStyle(Theme.isCustomDark(theme) ? .white : Color(.secondaryLabel))
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius(theme))
                .fill(Theme.cardFill(theme))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cardCornerRadius(theme))
                        .stroke(Theme.cardBorder(theme, rc: rc), lineWidth: Theme.cardBorderWidth(theme))
                )
                .shadow(color: Theme.cardShadow(theme, rc: rc), radius: Theme.isRetro(theme) ? 8 : 10, x: Theme.isRetro(theme) ? 0 : 2, y: Theme.isRetro(theme) ? 0 : 2)
        }
        .contextMenu {
            Button("Save for Future Use", systemImage: "square.and.arrow.down") {
                store.saveCategoryAsTemplate(category.id)
            }
            Divider()
            Button("Remove from This Week", systemImage: "xmark.circle", role: .destructive) {
                withAnimation { store.deleteCategory(category.id) }
            }
            Button("Delete Entirely", systemImage: "trash", role: .destructive) {
                withAnimation {
                    store.savedCategories.removeAll { $0.name == category.name }
                    store.saveSettings()
                    store.deleteCategory(category.id)
                }
            }
        }
        .sheet(isPresented: $showDeleteOptions) {
            RemoveCategorySheet(category: category, store: store)
                .presentationDetents([.height(260)])
        }
    }

    private func completionIcon(for category: Category) -> some View {
        let total = category.totalCount
        let completed = category.completedCount
        let color: Color = total == 0 ? .gray : completed == 0 ? Theme.completionNone(theme) : completed == total ? Theme.completionAll(theme, rc: rc) : Theme.completionPartial(theme)
        if Theme.isRetro(theme) {
            return AnyView(
                Text(completed == total && total > 0 ? "[OK]" : "[\(completed)/\(total)]")
                    .font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(color)
            )
        } else {
            return AnyView(
                Image(systemName: "chart.pie.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(color)
            )
        }
    }
}

// MARK: - Task Row (Card)

struct TaskRowCard: View {
    let task: ChecklistTask
    let categoryID: UUID
    let store: ChecklistStore
    let isEditing: Bool
    var isPastWeek: Bool = false

    private var theme: AppearanceMode { store.appearanceMode }
    private var rc: RetroColor { store.retroColor }

    @State private var isEditingTitle = false
    @State private var editedTitle = ""
    @State private var newSubtaskTitle = ""
    @State private var addProgressText = ""
    @State private var goalTargetText = ""
    @State private var goalUnitText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                // Completion indicator
                if task.taskType == .goal {
                    goalIndicator
                } else {
                    Button {
                        guard !isPastWeek else { return }
                        withAnimation(.snappy(duration: 0.2)) {
                            store.toggleTask(categoryID: categoryID, taskID: task.id)
                        }
                    } label: {
                        if Theme.isRetro(theme) {
                            Text(task.isCompleted ? "[x]" : "[ ]")
                                .font(.system(.subheadline, design: .monospaced).bold())
                                .foregroundStyle(task.isCompleted ? Theme.dotComplete(theme, rc: rc) : Theme.textSecondary(theme, rc: rc))
                        } else {
                            Circle()
                                .fill(task.isCompleted ? Theme.dotComplete(theme, rc: rc) : Color.clear)
                                .overlay(Circle().stroke(task.isCompleted ? Theme.dotComplete(theme, rc: rc) : Theme.textSecondary(theme, rc: rc), lineWidth: 1.5))
                                .frame(width: 18, height: 18)
                        }
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle().size(width: 36, height: 36))
                }

                // Title
                if isEditingTitle {
                    TextField("Task name", text: $editedTitle)
                        .font(Theme.isRetro(theme) ? .system(size: 16, design: .monospaced) : .system(size: 16))
                        .onSubmit {
                            let title = editedTitle.trimmingCharacters(in: .whitespaces)
                            if !title.isEmpty {
                                store.renameTask(categoryID: categoryID, taskID: task.id, newTitle: title)
                            }
                            isEditingTitle = false
                        }
                } else {
                    Text(task.title)
                        .font(Theme.isRetro(theme) ? .system(size: 16, design: .monospaced) : .system(size: 16))
                        .foregroundStyle(task.isCompleted ? Theme.textSecondary(theme, rc: rc) : Theme.textPrimary(theme, rc: rc))
                        .onTapGesture(count: 2) {
                            editedTitle = task.title
                            isEditingTitle = true
                        }
                        .onTapGesture {
                            if isEditing {
                                editedTitle = task.title
                                isEditingTitle = true
                            }
                        }
                }

                Spacer()

                // Inline icons
                if !isPastWeek {
                    if isEditing {
                        taskModeIcons
                    } else {
                        taskTypeIcons
                    }
                }
            }

            if task.taskType == .goal {
                // Goal: always show setup or progress inline
                goalProgressSection
            } else {
                // Checkbox: subtasks
                ForEach(task.subtasks) { subtask in
                    SubTaskRowCard(
                        subtask: subtask,
                        categoryID: categoryID,
                        taskID: task.id,
                        store: store,
                        isEditing: isEditing,
                        isPastWeek: isPastWeek
                    )
                }
                if !isPastWeek {
                    HStack(spacing: 8) {
                        Image(systemName: Theme.isRetro(theme) ? "greaterthan" : "plus.circle")
                            .font(.caption).foregroundStyle(Theme.textTertiary(theme, rc: rc))
                        TextField(Theme.isRetro(theme) ? "sub_task>" : "Add sub-task", text: $newSubtaskTitle)
                            .font(Theme.captionFont(theme))
                            .onSubmit(addSubtask)
                    }
                    .padding(.leading, 24)
                    .padding(.vertical, 2)
                }
            }
        }
        .contextMenu {
            Section("Task Mode") {
                ForEach(TaskMode.allCases, id: \.self) { mode in
                    Button {
                        store.updateTaskMode(categoryID: categoryID, taskID: task.id, mode: mode)
                    } label: {
                        Label(mode.label, systemImage: mode.symbol)
                        if task.mode == mode { Image(systemName: "checkmark") }
                    }
                }
            }
            Section("Task Type") {
                ForEach(TaskType.allCases, id: \.self) { type in
                    Button {
                        store.updateTaskType(categoryID: categoryID, taskID: task.id, type: type)
                    } label: {
                        Label(type.label, systemImage: type.symbol)
                        if task.taskType == type { Image(systemName: "checkmark") }
                    }
                }
            }
            Section {
                Button("Edit Title", systemImage: "pencil") {
                    editedTitle = task.title
                    isEditingTitle = true
                }
                if task.subtasks.isEmpty && !isPastWeek {
                    Button("Add Sub-Task", systemImage: "list.bullet.indent") {
                        store.addSubtask(categoryID: categoryID, taskID: task.id, title: "New sub-task")
                    }
                }
                Button("Delete", systemImage: "trash", role: .destructive) {
                    store.deleteTask(categoryID: categoryID, taskID: task.id)
                }
            }
        }
    }

    // Mode icons: carry-over, repeating, one-time + delete (shown when NOT editing title)
    private var taskModeIcons: some View {
        HStack(spacing: 0) {
            ForEach(TaskMode.allCases, id: \.self) { mode in
                Button {
                    store.updateTaskMode(categoryID: categoryID, taskID: task.id, mode: mode)
                } label: {
                    Image(systemName: mode.symbol)
                        .font(.system(size: 16))
                        .foregroundStyle(task.mode == mode ? Theme.accent(theme, rc: rc) : Theme.textSecondary(theme, rc: rc))
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Button {
                withAnimation(.snappy(duration: 0.2)) {
                    store.deleteTask(categoryID: categoryID, taskID: task.id)
                }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 16)).foregroundStyle(Theme.destructive(theme))
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // Type icons: checkbox + goal (shown when NOT in edit mode)
    private var taskTypeIcons: some View {
        HStack(spacing: 0) {
            ForEach(TaskType.allCases, id: \.self) { type in
                Button {
                    store.updateTaskType(categoryID: categoryID, taskID: task.id, type: type)
                } label: {
                    Image(systemName: type.symbol)
                        .font(.system(size: 16))
                        .foregroundStyle(task.taskType == type ? Theme.accent(theme, rc: rc) : Theme.textSecondary(theme, rc: rc))
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var goalIndicator: some View {
        if Theme.isRetro(theme) {
            if task.goalIsComplete {
                Text("[OK]")
                    .font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(Theme.dotComplete(theme, rc: rc))
            } else if let target = task.goalTarget, target > 0 {
                Text("[\(Int(task.goalProgress ?? 0))/\(Int(target))]")
                    .font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(Theme.accent(theme, rc: rc))
            } else {
                Text("[??]")
                    .font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(Theme.completionPartial(theme))
            }
        } else {
            if task.goalIsComplete {
                Circle()
                    .fill(Theme.dotComplete(theme, rc: rc))
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 12).bold())
                            .foregroundStyle(.white)
                    )
                    .frame(width: 18, height: 18)
            } else if let target = task.goalTarget, target > 0 {
                ZStack {
                    Circle().stroke(Theme.textTertiary(theme, rc: rc), lineWidth: 2.5)
                    Circle()
                        .trim(from: 0, to: min((task.goalProgress ?? 0) / target, 1.0))
                        .stroke(Theme.accent(theme, rc: rc), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 18, height: 18)
            } else {
                Image(systemName: "target")
                    .font(.system(size: 12)).foregroundStyle(Theme.completionPartial(theme))
            }
        }
    }

    private var goalProgressSection: some View {
        VStack(spacing: 6) {
            if let target = task.goalTarget, target > 0 {
                // Progress bar + fraction
                HStack(spacing: 10) {
                    ProgressView(value: min((task.goalProgress ?? 0) / target, 1.0))
                        .tint(task.goalIsComplete ? Theme.dotComplete(theme, rc: rc) : Theme.accent(theme, rc: rc))
                    Text(task.goalFraction)
                        .font(Theme.isRetro(theme) ? .system(.caption, design: .monospaced).bold() : .caption.bold().monospacedDigit())
                        .foregroundStyle(task.goalIsComplete ? Theme.dotComplete(theme, rc: rc) : Theme.textPrimary(theme, rc: rc))
                    if let unit = task.goalUnit, !unit.isEmpty {
                        Text(unit).font(Theme.captionFont(theme)).foregroundStyle(Theme.textSecondary(theme, rc: rc))
                    }
                }
                .padding(.leading, 24)

                // Add progress input
                if !isPastWeek && !task.goalIsComplete {
                    HStack(spacing: 8) {
                        Image(systemName: "plus").font(.subheadline).foregroundStyle(Theme.textTertiary(theme, rc: rc))
                        TextField("Add progress", text: $addProgressText)
                            .font(.subheadline)
                            .foregroundStyle(Theme.textPrimary(theme, rc: rc))
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.plain)
                            .padding(.bottom, 4)
                            .overlay(alignment: .bottom) {
                                Rectangle().fill(Theme.textTertiary(theme, rc: rc)).frame(height: 1)
                            }
                            .onSubmit(addGoalProgress)
                        Button { addGoalProgress() } label: {
                            Text("Add")
                                .font(.caption.bold())
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(Theme.accent(theme, rc: rc), in: Capsule())
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                        .disabled(Double(addProgressText) == nil)
                    }
                    .padding(.leading, 24)
                }
            } else if !isPastWeek {
                // Goal setup: [target] - [unit] Set
                HStack(spacing: 8) {
                    TextField("Target", text: $goalTargetText)
                        .font(Theme.isRetro(theme) ? .system(.subheadline, design: .monospaced) : .subheadline)
                        .foregroundStyle(Theme.textPrimary(theme, rc: rc))
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 70)
                    Text("—").font(.caption).foregroundStyle(Theme.textTertiary(theme, rc: rc))
                    TextField("Unit", text: $goalUnitText)
                        .font(Theme.isRetro(theme) ? .system(.subheadline, design: .monospaced) : .subheadline)
                        .foregroundStyle(Theme.textPrimary(theme, rc: rc))
                        .textFieldStyle(.roundedBorder)
                    Button {
                        if let target = Double(goalTargetText), target > 0 {
                            store.setGoalTarget(categoryID: categoryID, taskID: task.id, target: target, unit: goalUnitText)
                        }
                        goalTargetText = ""
                        goalUnitText = ""
                    } label: {
                        Text("Set")
                            .font(.caption.bold())
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Theme.accent(theme, rc: rc), in: Capsule())
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .disabled(Double(goalTargetText) == nil)
                }
                .padding(.leading, 24)
            }
        }
        .padding(.top, 2)
    }

    private func addSubtask() {
        let title = newSubtaskTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        withAnimation(.snappy(duration: 0.2)) {
            store.addSubtask(categoryID: categoryID, taskID: task.id, title: title)
        }
        newSubtaskTitle = ""
    }

    private func addGoalProgress() {
        guard let amount = Double(addProgressText), amount > 0 else { return }
        let current = task.goalProgress ?? 0
        withAnimation(.snappy(duration: 0.2)) {
            store.updateGoalProgress(categoryID: categoryID, taskID: task.id, progress: current + amount)
        }
        addProgressText = ""
    }
}

// MARK: - Sub-Task Row (Card)

struct SubTaskRowCard: View {
    let subtask: SubTask
    let categoryID: UUID
    let taskID: UUID
    let store: ChecklistStore
    let isEditing: Bool
    let isPastWeek: Bool

    private var theme: AppearanceMode { store.appearanceMode }
    private var rc: RetroColor { store.retroColor }

    @State private var isEditingTitle = false
    @State private var editedTitle = ""

    var body: some View {
        HStack(spacing: 8) {
            Button {
                guard !isPastWeek else { return }
                withAnimation(.snappy(duration: 0.2)) {
                    store.toggleSubtask(categoryID: categoryID, taskID: taskID, subtaskID: subtask.id)
                }
            } label: {
                if Theme.isRetro(theme) {
                    Text(subtask.isCompleted ? "[x]" : "[ ]")
                        .font(.system(.caption, design: .monospaced).bold())
                        .foregroundStyle(subtask.isCompleted ? Theme.dotComplete(theme, rc: rc) : Theme.textSecondary(theme, rc: rc))
                } else {
                    Circle()
                        .fill(subtask.isCompleted ? Theme.dotComplete(theme, rc: rc) : Color.clear)
                        .overlay(Circle().stroke(subtask.isCompleted ? Theme.dotComplete(theme, rc: rc) : Theme.textSecondary(theme, rc: rc), lineWidth: 1.5))
                        .frame(width: 14, height: 14)
                }
            }
            .buttonStyle(.plain)

            if isEditing && isEditingTitle {
                TextField("Sub-task", text: $editedTitle)
                    .font(Theme.isRetro(theme) ? .system(size: 14, design: .monospaced) : .system(size: 14))
                    .onSubmit {
                        let title = editedTitle.trimmingCharacters(in: .whitespaces)
                        if !title.isEmpty {
                            store.renameSubtask(categoryID: categoryID, taskID: taskID, subtaskID: subtask.id, newTitle: title)
                        }
                        isEditingTitle = false
                    }
            } else {
                Text(subtask.title)
                    .font(Theme.isRetro(theme) ? .system(size: 14, design: .monospaced) : .system(size: 14))
                    .foregroundStyle(subtask.isCompleted ? Theme.textTertiary(theme, rc: rc) : Theme.textSecondary(theme, rc: rc))
                    .strikethrough(subtask.isCompleted && !Theme.isRetro(theme), color: Theme.textSecondary(theme, rc: rc))
                    .onTapGesture {
                        if isEditing {
                            editedTitle = subtask.title
                            isEditingTitle = true
                        }
                    }
            }

            Spacer()

            if isEditing {
                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        store.deleteSubtask(categoryID: categoryID, taskID: taskID, subtaskID: subtask.id)
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.subheadline).foregroundStyle(Theme.destructive(theme))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.leading, 24)
    }
}

// MARK: - Add Task Row (Card)

struct AddTaskRowCard: View {
    let categoryID: UUID
    let store: ChecklistStore

    private var theme: AppearanceMode { store.appearanceMode }
    private var rc: RetroColor { store.retroColor }

    @State private var newTitle = ""
    @State private var newMode: TaskMode = .carryOver
    @State private var newType: TaskType = .checkbox
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: Theme.isRetro(theme) ? "greaterthan" : "plus.circle")
                .font(.subheadline).foregroundStyle(Theme.textTertiary(theme, rc: rc))
            TextField(Theme.isRetro(theme) ? "new_task>" : "Add task", text: $newTitle)
                .font(Theme.bodyFont(theme)).focused($isFocused).onSubmit(addTask)
            if isFocused {
                Menu {
                    Section("Task Type") {
                        ForEach(TaskType.allCases, id: \.self) { type in
                            Button {
                                newType = type
                            } label: {
                                Label(type.label, systemImage: type.symbol)
                                if newType == type { Image(systemName: "checkmark") }
                            }
                        }
                    }
                    Section("Task Mode") {
                        ForEach(TaskMode.allCases, id: \.self) { mode in
                            Button {
                                newMode = mode
                            } label: {
                                Label(mode.label, systemImage: mode.symbol)
                                if newMode == mode { Image(systemName: "checkmark") }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: newType.symbol)
                        Image(systemName: newMode.symbol)
                    }
                    .font(.caption2).foregroundStyle(Theme.textSecondary(theme, rc: rc))
                    .padding(4).background(Theme.textTertiary(theme, rc: rc).opacity(0.3), in: Capsule())
                }
            }
        }
    }

    private func addTask() {
        let title = newTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        withAnimation(.snappy(duration: 0.2)) {
            store.addTask(categoryID: categoryID, title: title, mode: newMode)
            if newType == .goal, let week = store.selectedWeek,
               let cat = week.categories.first(where: { $0.id == categoryID }),
               let task = cat.tasks.last {
                store.updateTaskType(categoryID: categoryID, taskID: task.id, type: .goal)
            }
        }
        newTitle = ""
    }
}

// MARK: - Add Category Sheet

struct AddCategorySheet: View {
    let store: ChecklistStore
    var onAdd: ((String, String) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var isCreatingNew = false
    @State private var newName = ""
    @State private var newSymbol = "folder"

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
                                    store.removeSavedCategory(template.id)
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
        }
    }

    private func addFromTemplate(_ template: CategoryTemplate) {
        // Don't add duplicate category to the same week
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

// MARK: - Settings Sheet

struct SettingsSheet: View {
    let store: ChecklistStore
    @Environment(\.dismiss) private var dismiss
    @State private var showHelp = false
    @State private var editingName = ""
    @State private var isEditingName = false

    private var theme: AppearanceMode { store.appearanceMode }
    private var rc: RetroColor { store.retroColor }
    private var retro: Bool { Theme.isRetro(theme) }

    var body: some View {
        NavigationStack {
            Group {
                if retro {
                    retroSettings
                } else {
                    standardSettings
                }
            }
            .navigationTitle(retro ? "> SETTINGS_" : "Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(retro ? "[DONE]" : "Done") { dismiss() }
                        .font(retro ? .system(.subheadline, design: .monospaced).bold() : .body)
                        .foregroundStyle(retro ? Theme.accent(theme, rc: rc) : .blue)
                }
            }
            .sheet(isPresented: $showHelp) { HelpSheet(store: store) }
        }
        .preferredColorScheme(store.colorScheme)
    }

    // MARK: - Standard (System/Light/Dark) Settings

    private var darkCardBg: Color? { Theme.isDark(theme) ? Theme.cardFill(theme) : nil }

    private var standardSettings: some View {
        List {
            Section("Name") {
                nameRow
            }
            .listRowBackground(darkCardBg)
            Section("Appearance") {
                appearanceRows
            }
            .listRowBackground(darkCardBg)
            Section("Calendar") {
                calendarRow
            }
            .listRowBackground(darkCardBg)
            Section {
                Button { showHelp = true } label: {
                    Label("How to Use Tasquel", systemImage: "questionmark.circle")
                }
            } header: {
                Text("Help")
            }
            .listRowBackground(darkCardBg)
            Section("About") {
                LabeledContent("Version", value: "1.0")
                LabeledContent("Build", value: "1")
            }
            .listRowBackground(darkCardBg)
        }
        .scrollContentBackground(Theme.isDark(theme) ? .hidden : .automatic)
        .background(Theme.isDark(theme) ? Theme.background(theme) : Color.clear)
    }

    // MARK: - Retro Settings

    private var retroSettings: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                retroSection("USER") {
                    nameRow
                }
                retroSection("APPEARANCE") {
                    appearanceRows
                }
                retroSection("TERMINAL_COLOR") {
                    retroColorPalette
                }
                retroSection("CALENDAR") {
                    calendarRow
                }
                retroSection("HELP") {
                    Button { showHelp = true } label: {
                        Text("> How to Use Tasquel")
                            .font(Theme.bodyFont(theme))
                            .foregroundStyle(Theme.accent(theme, rc: rc))
                    }
                    .buttonStyle(.plain)
                }
                retroSection("ABOUT") {
                    HStack {
                        Text("Version").font(Theme.bodyFont(theme)).foregroundStyle(Theme.textSecondary(theme, rc: rc))
                        Spacer()
                        Text("1.0").font(Theme.bodyFont(theme)).foregroundStyle(Theme.textPrimary(theme, rc: rc))
                    }
                    HStack {
                        Text("Build").font(Theme.bodyFont(theme)).foregroundStyle(Theme.textSecondary(theme, rc: rc))
                        Spacer()
                        Text("1").font(Theme.bodyFont(theme)).foregroundStyle(Theme.textPrimary(theme, rc: rc))
                    }
                }
            }
            .padding(16)
        }
        .background(Theme.background(theme))
        .foregroundStyle(Theme.textPrimary(theme, rc: rc))
    }

    @ViewBuilder
    private func retroSection(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("[\(title)]")
                .font(.system(.caption, design: .monospaced).bold())
                .foregroundStyle(Theme.textTertiary(theme, rc: rc))
            VStack(alignment: .leading, spacing: 6) {
                content()
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 2)
                    .fill(Theme.cardFill(theme))
                    .overlay(RoundedRectangle(cornerRadius: 2).stroke(Theme.cardBorder(theme, rc: rc), lineWidth: 1))
            )
        }
    }

    // MARK: - Shared Rows

    @ViewBuilder
    private var nameRow: some View {
        if isEditingName {
            HStack {
                TextField(retro ? "name>" : "Your name", text: $editingName)
                    .font(retro ? Theme.bodyFont(theme) : .body)
                    .onSubmit {
                        let name = editingName.trimmingCharacters(in: .whitespaces)
                        if !name.isEmpty && name.count <= 20 { store.setUserName(name) }
                        isEditingName = false
                    }
                Button(retro ? "[SAVE]" : "Save") {
                    let name = editingName.trimmingCharacters(in: .whitespaces)
                    if !name.isEmpty && name.count <= 20 { store.setUserName(name) }
                    isEditingName = false
                }
                .font(retro ? Theme.bodyFont(theme) : .body)
                .foregroundStyle(retro ? Theme.accent(theme, rc: rc) : .blue)
                .disabled(editingName.trimmingCharacters(in: .whitespaces).isEmpty || editingName.count > 20)
            }
        } else {
            HStack {
                Text(store.userName.isEmpty ? (retro ? "not_set" : "Not set") : store.userName)
                    .font(retro ? Theme.bodyFont(theme) : .body)
                    .foregroundStyle(store.userName.isEmpty ? Theme.textTertiary(theme, rc: rc) : (retro ? Theme.textPrimary(theme, rc: rc) : Color(.label)))
                Spacer()
                Button(retro ? "[EDIT]" : "Edit") {
                    editingName = store.userName
                    isEditingName = true
                }
                .font(retro ? Theme.bodyFont(theme) : .subheadline)
                .foregroundStyle(retro ? Theme.accent(theme, rc: rc) : .blue)
            }
        }
    }

    @ViewBuilder
    private var appearanceRows: some View {
        ForEach(AppearanceMode.allCases, id: \.self) { mode in
            Button {
                store.setAppearance(mode)
            } label: {
                HStack {
                    if retro {
                        Text("> \(mode.label.uppercased())")
                            .font(Theme.bodyFont(theme))
                            .foregroundStyle(store.appearanceMode == mode ? Theme.accent(theme, rc: rc) : Theme.textSecondary(theme, rc: rc))
                    } else {
                        Label(mode.label, systemImage: mode.symbol).foregroundStyle(.primary)
                    }
                    Spacer()
                    if store.appearanceMode == mode {
                        if retro {
                            Text("[*]")
                                .font(.system(.subheadline, design: .monospaced).bold())
                                .foregroundStyle(Theme.accent(theme, rc: rc))
                        } else {
                            Image(systemName: "checkmark").foregroundStyle(.blue)
                        }
                    }
                }
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
        }
    }

    private var retroColorPalette: some View {
        HStack(spacing: 10) {
            ForEach(RetroColor.allCases, id: \.self) { color in
                Button {
                    store.setRetroColor(color)
                } label: {
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Theme.retroBright(color))
                            .frame(width: 36, height: 36)
                            .overlay(
                                RoundedRectangle(cornerRadius: 2)
                                    .stroke(store.retroColor == color ? .white : .clear, lineWidth: 2)
                            )
                        Text(color.label.prefix(3).uppercased())
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(store.retroColor == color ? Theme.retroBright(color) : Theme.textTertiary(theme, rc: rc))
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var calendarRow: some View {
        HStack {
            if retro {
                Text("> Calendar Integration")
                    .font(Theme.bodyFont(theme))
                    .foregroundStyle(Theme.textSecondary(theme, rc: rc))
            } else {
                Label("Calendar Integration", systemImage: "calendar.badge.plus")
            }
            Spacer()
            Text(retro ? "[SOON]" : "Coming Soon")
                .font(retro ? .system(.caption, design: .monospaced) : .caption)
                .foregroundStyle(retro ? Theme.textTertiary(theme, rc: rc) : .secondary)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(retro ? Theme.cardFill(theme) : Color(.quaternarySystemFill), in: retro ? AnyShape(RoundedRectangle(cornerRadius: 2)) : AnyShape(Capsule()))
        }
    }
}

// MARK: - Help Sheet

struct HelpSheet: View {
    var store: ChecklistStore? = nil
    @Environment(\.dismiss) private var dismiss

    private var theme: AppearanceMode { store?.appearanceMode ?? .system }
    private var rc: RetroColor { store?.retroColor ?? .green }
    private var retro: Bool { Theme.isRetro(theme) }

    private let helpSections: [(title: String, items: [(symbol: String, title: String, detail: String)])] = [
        ("Weekly Checklist", [
            ("calendar", "Navigate Weeks", "Use the arrows or tap the calendar icon to jump to any week. Future weeks can be pre-populated. Past weeks can be reviewed."),
            ("square.grid.2x2", "Category Cards", "Tap a card to expand and view all tasks. Tap the collapse arrow to return to grid view. Long-press for options: save, remove, or delete."),
            ("pencil", "Edit Mode", "Tap the pencil icon to enter edit mode. From here you can add categories, change task modes, and delete tasks using the inline icons."),
        ]),
        ("Task Modes", [
            ("arrow.uturn.forward", "Carry Over", "Default mode. If not completed by end of the week, it rolls forward to the next week. Completed tasks do not carry over."),
            ("repeat", "Repeating", "Appears every week automatically regardless of completion. Great for recurring habits. Resets to unchecked each new week."),
            ("1.circle", "One-Time", "This week only. Will not carry forward or repeat, whether completed or not."),
            ("hand.draw", "Changing Modes", "In edit mode, use the inline mode icons on each task. Or long-press a task for the context menu. Double-tap a task title to edit it inline."),
        ]),
        ("Task Types", [
            ("checkmark.circle", "Checkbox", "Standard task — tap the circle to mark complete. This is the default type for all new tasks."),
            ("target", "Goal", "Track progress toward a numeric target (e.g. 50 push-ups). Tap the progress ring to update. Auto-completes when the target is reached."),
            ("arrow.left.arrow.right", "Switching Types", "Long-press a task and choose a type from the context menu."),
        ]),
        ("Sub-Tasks", [
            ("list.bullet.indent", "Adding Sub-Tasks", "Tasks with sub-tasks show them inline when expanded. Type in the field below to add more. Long-press a task to add the first sub-task."),
            ("checkmark.circle", "Completing Sub-Tasks", "Tap any sub-task's circle to check it off. Sub-task progress shows as a count on the parent task."),
        ]),
        ("Managing Categories", [
            ("square.and.arrow.down", "Save for Future", "Long-press a category card and choose \"Save for Future Use\" to add it to your template library."),
            ("trash", "Removing Categories", "Long-press a category card to remove from this week only or delete entirely including from saved categories."),
        ]),
        ("Upcoming Features", [
            ("calendar.badge.plus", "Calendar Integration", "A future paid upgrade will allow importing your personal calendar events directly into Tasquel as tasks."),
        ]),
    ]

    var body: some View {
        NavigationStack {
            Group {
                if retro {
                    retroHelp
                } else {
                    standardHelp
                }
            }
            .navigationTitle(retro ? "> HELP_" : "How to Use Tasquel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(retro ? "[DONE]" : "Done") { dismiss() }
                        .font(retro ? .system(.subheadline, design: .monospaced).bold() : .body)
                        .foregroundStyle(retro ? Theme.accent(theme, rc: rc) : .blue)
                }
            }
        }
    }

    private var darkHelpBg: Color? { Theme.isDark(theme) ? Theme.cardFill(theme) : nil }

    @ViewBuilder
    private func helpSection(_ index: Int) -> some View {
        let section = helpSections[index]
        Section(section.title) {
            ForEach(section.items, id: \.title) { item in
                HelpRow(symbol: item.symbol, title: item.title, detail: item.detail)
            }
        }
    }

    private var standardHelp: some View {
        List {
            helpSection(0)
            helpSection(1)
            helpSection(2)
            helpSection(3)
            helpSection(4)
            helpSection(5)
        }
    }

    private var retroHelp: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(helpSections, id: \.title) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text("[\(section.title.uppercased())]")
                            .font(.system(.caption, design: .monospaced).bold())
                            .foregroundStyle(Theme.textTertiary(theme, rc: rc))
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(section.items, id: \.title) { item in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("> \(item.title)")
                                        .font(.system(.subheadline, design: .monospaced).bold())
                                        .foregroundStyle(Theme.accent(theme, rc: rc))
                                    Text(item.detail)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(Theme.textSecondary(theme, rc: rc))
                                }
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Theme.cardFill(theme))
                                .overlay(RoundedRectangle(cornerRadius: 2).stroke(Theme.cardBorder(theme, rc: rc), lineWidth: 1))
                        )
                    }
                }
            }
            .padding(16)
        }
        .background(Theme.background(theme))
    }
}

struct HelpRow: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbol).font(.subheadline.bold())
            Text(detail).font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Remove Category Sheet

struct RemoveCategorySheet: View {
    let category: Category
    let store: ChecklistStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2).foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 16).padding(.trailing, 20)

            Text("Remove \"\(category.name)\"")
                .font(.headline).padding(.top, 4)

            Text("Remove from this week only, or delete entirely including from saved categories?")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32).padding(.top, 8)

            VStack(spacing: 12) {
                Button {
                    withAnimation { store.deleteCategory(category.id) }
                    dismiss()
                } label: {
                    Text("Remove from This Week").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button(role: .destructive) {
                    withAnimation {
                        store.savedCategories.removeAll { $0.name == category.name }
                        store.saveSettings()
                        store.deleteCategory(category.id)
                    }
                    dismiss()
                } label: {
                    Text("Delete Entirely").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 32).padding(.top, 20)

            Spacer()
        }
    }
}

// MARK: - Carry Over Animation

struct CarryOverAnimation: View {
    @State private var phase: Int = 0
    @State private var checkTrim: CGFloat = 0
    @State private var ringTrim: CGFloat = 0
    @State private var ringRotation: Double = -90
    @State private var handAngle: Double = -90
    @State private var crossfade: Double = 0 // 0 = checkmark, 1 = clock
    @State private var hue: Double = 0.35 // green

    private let size: CGFloat = 80
    private let stroke: CGFloat = 3.5

    private var accentColor: Color { Color(hue: hue, saturation: 0.65, brightness: 0.75) }

    var body: some View {
        ZStack {
            // Ring
            Circle()
                .trim(from: 0, to: ringTrim)
                .stroke(accentColor, style: StrokeStyle(lineWidth: stroke, lineCap: .round))
                .frame(width: size, height: size)
                .rotationEffect(.degrees(ringRotation))

            // Checkmark (fades out as clock fades in)
            CheckmarkPath()
                .trim(from: 0, to: checkTrim)
                .stroke(accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                .frame(width: size * 0.38, height: size * 0.38)
                .opacity(1 - crossfade)

            // Abstract clock — single hand sweeping
            RoundedRectangle(cornerRadius: 1.5)
                .fill(accentColor)
                .frame(width: 2.5, height: size * 0.3)
                .offset(y: -size * 0.15)
                .rotationEffect(.degrees(handAngle))
                .opacity(crossfade)
        }
        .onAppear { runLoop() }
    }

    private func runLoop() {
        // Reset
        checkTrim = 0
        ringTrim = 0
        ringRotation = -90
        handAngle = -90
        crossfade = 0
        hue = 0.35

        // Phase 1 (0s): Ring draws in + checkmark draws — "task complete"
        withAnimation(.easeOut(duration: 0.45)) {
            ringTrim = 1
            checkTrim = 1
        }

        // Phase 2 (0.65s): Crossfade check→hand, shift hue green→orange, hand starts at 12
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
            withAnimation(.easeInOut(duration: 0.35)) {
                crossfade = 1
                hue = 0.08 // orange
            }
        }

        // Phase 3 (1.0s): Hand sweeps full circle — "time passing"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeInOut(duration: 1.0)) {
                handAngle = 270 // full sweep from 12 o'clock
            }
        }

        // Phase 4 (2.1s): Crossfade hand→check, hue back to green, redraw check
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.1) {
            checkTrim = 0
            withAnimation(.easeInOut(duration: 0.35)) {
                crossfade = 0
                hue = 0.35
            }
            withAnimation(.easeOut(duration: 0.35).delay(0.1)) {
                checkTrim = 1
            }
        }

        // Loop
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            runLoop()
        }
    }
}

struct CheckmarkPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.width * 0.35, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}

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
            CarryOverAnimation()
                .frame(width: 240, height: 160)
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

#Preview {
    ContentView()
}
