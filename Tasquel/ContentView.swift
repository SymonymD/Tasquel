import SwiftUI
// MARK: - Root View

struct ContentView: View {
    @State private var store = ChecklistStore()
    @State private var showDatePicker = false
    @State private var showSettings = false
    @State private var showAddCategory = false
    @State private var expandedCategoryKeys: Set<CategoryLayoutKey> = []
    @State private var categoryDisplayOrder: [CategoryLayoutKey] = []
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

                if let error = store.persistenceError {
                    Spacer()
                    ContentUnavailableView {
                        Label("Planner Unavailable", systemImage: "externaldrive.badge.exclamationmark")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Retry Loading") {
                            store.retryLoadingData()
                            if store.persistenceError == nil && store.shouldShowWelcome {
                                showOnboarding = true
                            }
                        }
                    }
                    Spacer()
                } else if let week = store.selectedWeek {
                    weekNavigationBar
                    weekContent(week)
                } else {
                    Spacer()
                    ContentUnavailableView("No Week Data", systemImage: "calendar.badge.exclamationmark")
                    Spacer()
                }
            }

            if store.persistenceError == nil {
                bottomBar
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }

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
            if store.persistenceError == nil && store.shouldShowWelcome {
                showOnboarding = true
            }
        }
        .onChange(of: store.selectedDate) {
            if isPastWeek { isEditing = false }
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
            .accessibilityLabel("Previous week")
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
            .accessibilityLabel("Next week")
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

    @ViewBuilder
    private var bottomBar: some View {
        if Theme.isRetro(theme) {
            bottomBarContent
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Theme.navCapsule(theme))
                        .overlay(RoundedRectangle(cornerRadius: 2).stroke(Theme.cardBorder(theme, rc: rc), lineWidth: 1))
                )
        } else {
            bottomBarContent
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .glassEffect(in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
    }

    private var bottomBarContent: some View {
        HStack {
            // Settings
            Button { showSettings = true } label: {
                Image(systemName: Theme.isRetro(theme) ? "terminal" : "gearshape.fill")
                    .font(.title3)
                    .foregroundStyle(Theme.textSecondary(theme, rc: rc))
                    .frame(width: 44, height: 44)
                    .background {
                        if Theme.isRetro(theme) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Theme.cardFill(theme))
                                .overlay(RoundedRectangle(cornerRadius: 2).stroke(Theme.cardBorder(theme, rc: rc), lineWidth: 1))
                        }
                    }
            }
            .buttonStyle(.plain)

            Spacer()

            // Date / Go to Today
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

            // Edit / Done
            if !isPastWeek {
                Button {
                    withAnimation(.snappy(duration: 0.25)) { isEditing.toggle() }
                } label: {
                    if isEditing {
                        Image(systemName: "checkmark")
                            .font(.title3)
                            .foregroundStyle(Theme.isRetro(theme) ? Theme.dotComplete(theme, rc: rc) : .green)
                            .frame(width: 44, height: 44)
                            .background {
                                if Theme.isRetro(theme) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Theme.cardFill(theme))
                                        .overlay(RoundedRectangle(cornerRadius: 2).stroke(Theme.dotComplete(theme, rc: rc), lineWidth: 1.5))
                                } else {
                                    Circle().fill(.green.opacity(0.15))
                                        .overlay(Circle().stroke(.green, lineWidth: 1.5))
                                }
                            }
                    } else {
                        Image(systemName: "pencil")
                            .font(.title3)
                            .foregroundStyle(Theme.textSecondary(theme, rc: rc))
                            .frame(width: 44, height: 44)
                            .background {
                                if Theme.isRetro(theme) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Theme.cardFill(theme))
                                        .overlay(RoundedRectangle(cornerRadius: 2).stroke(Theme.cardBorder(theme, rc: rc), lineWidth: 1))
                                }
                            }
                    }
                }
                .buttonStyle(.plain)
            } else {
                Color.clear.frame(width: 44, height: 44)
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

        // An expanded card takes a full row; other open cards remain open.
        ScrollView {
            VStack(spacing: 8) {
                let rows = buildGridRows(categories: categories, showAddButton: showAdd)
                ForEach(rows) { row in
                    if row.isExpandedRow {
                        // Expanded card takes full width
                        gridCardSlot(row.left, week: week)
                    } else if row.isAddRow && row.left == nil {
                        // Standalone add button (even category count)
                        HStack(spacing: 8) {
                            addCategoryButton
                            Color.clear.frame(maxWidth: .infinity)
                        }
                    } else if row.isAddRow {
                        // Add button fills empty right slot
                        HStack(spacing: 8) {
                            gridCardSlot(row.left, week: week)
                            addCategoryButton
                        }
                    } else if row.right == nil {
                        // Last odd card — half width
                        HStack(spacing: 8) {
                            gridCardSlot(row.left, week: week)
                            Color.clear.frame(maxWidth: .infinity)
                        }
                    } else {
                        // Normal 2-column row
                        HStack(spacing: 8) {
                            gridCardSlot(row.left, week: week)
                            gridCardSlot(row.right, week: week)
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

    private struct GridRow: Identifiable {
        let id: Int
        let left: Category?
        let right: Category?
        var isAddRow: Bool = false
        var isExpandedRow: Bool = false  // left is the expanded card; renders full-width
    }

    /// Weeks create new category IDs, so layout state follows a category's name.
    /// The occurrence distinguishes categories with the same name in one week.
    private struct CategoryLayoutKey: Hashable {
        let name: String
        let occurrence: Int
    }

    private func categoryKeys(for categories: [Category]) -> [UUID: CategoryLayoutKey] {
        var occurrences: [String: Int] = [:]
        var keys: [UUID: CategoryLayoutKey] = [:]
        for category in categories {
            let occurrence = occurrences[category.name, default: 0]
            keys[category.id] = CategoryLayoutKey(name: category.name, occurrence: occurrence)
            occurrences[category.name] = occurrence + 1
        }
        return keys
    }

    private func buildGridRows(categories: [Category], showAddButton: Bool) -> [GridRow] {
        let keysByID = categoryKeys(for: categories)
        let categoriesByKey = Dictionary(uniqueKeysWithValues: categories.compactMap { category in
            keysByID[category.id].map { ($0, category) }
        })
        let orderedKeys = categoryDisplayOrder.filter { categoriesByKey[$0] != nil }
        let orderedKeySet = Set(orderedKeys)
        let orderedCategories = orderedKeys.compactMap { categoriesByKey[$0] }
            + categories.filter { category in
                keysByID[category.id].map { !orderedKeySet.contains($0) } ?? true
            }
        var rows: [GridRow] = []
        var index = 0
        while index < orderedCategories.count {
            let left = orderedCategories[index]
            if keysByID[left.id].map({ expandedCategoryKeys.contains($0) }) ?? false {
                rows.append(GridRow(id: rows.count, left: left, right: nil, isExpandedRow: true))
                index += 1
            } else {
                let nextIndex = index + 1
                let right = nextIndex < orderedCategories.count
                    && !(keysByID[orderedCategories[nextIndex].id].map { expandedCategoryKeys.contains($0) } ?? false)
                    ? orderedCategories[nextIndex] : nil
                rows.append(GridRow(id: rows.count, left: left, right: right))
                index += right == nil ? 1 : 2
            }
        }

        if showAddButton {
            // Put add button in the empty right slot of the last non-expanded row if available
            if let last = rows.last, last.right == nil, !last.isAddRow, !last.isExpandedRow {
                rows[rows.count - 1] = GridRow(id: last.id, left: last.left, right: nil, isAddRow: true)
            } else {
                rows.append(GridRow(id: rows.count, left: nil, right: nil, isAddRow: true))
            }
        }
        return rows
    }

    private func expandCategory(_ categoryID: UUID, in categories: [Category]) {
        let keysByID = categoryKeys(for: categories)
        guard let categoryKey = keysByID[categoryID] else { return }
        let rows = buildGridRows(categories: categories, showAddButton: false)
        if let row = rows.first(where: { $0.right?.id == categoryID }),
           let leftID = row.left?.id,
           let leftKey = keysByID[leftID] {
            let visualOrder = rows.flatMap { [$0.left?.id, $0.right?.id] }
                .compactMap { $0.flatMap { keysByID[$0] } }
            if let leftIndex = visualOrder.firstIndex(of: leftKey) {
                categoryDisplayOrder = visualOrder.filter { $0 != categoryKey }
                categoryDisplayOrder.insert(categoryKey, at: leftIndex)
            }
        }
        expandedCategoryKeys.insert(categoryKey)
    }

    private func collapseCategory(_ categoryID: UUID, in categories: [Category]) {
        guard let categoryKey = categoryKeys(for: categories)[categoryID] else { return }
        expandedCategoryKeys.remove(categoryKey)
        if expandedCategoryKeys.isEmpty { categoryDisplayOrder.removeAll() }
    }

    /// Renders a single grid slot — collapsed card, expanded card, or shrunk-to-zero neighbor
    @ViewBuilder
    private func gridCardSlot(_ category: Category?, week: Week) -> some View {
        if let category {
            let categoryKey = categoryKeys(for: week.categories)[category.id]
            let isExpanded = categoryKey.map { expandedCategoryKeys.contains($0) } ?? false

            if isExpanded {
                ExpandedCategoryCard(
                    category: category,
                    store: store,
                    isEditing: isEditing,
                    isPastWeek: week.isPastWeek,
                    onToggleEdit: { withAnimation(.snappy(duration: 0.25)) { isEditing.toggle() } },
                    onCollapse: {
                        withAnimation(.easeOut(duration: 0.7)) {
                            collapseCategory(category.id, in: week.categories)
                        }
                    }
                )
                .id(category.id)
                .transition(.identity)
            } else {
                CategoryCard(category: category, store: store, isEditing: isEditing, isPastWeek: week.isPastWeek) {
                    withAnimation(.easeOut(duration: 0.7)) {
                        expandCategory(category.id, in: week.categories)
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
struct BookingCalendarAnimation: View {
    @State private var tileScales: [CGFloat] = Array(repeating: 0, count: 8)
    @State private var checkScale: CGFloat = 0
    @State private var sparkleOpacity: Double = 0
    @State private var sparkleScales: [CGFloat] = Array(repeating: 0, count: 5)

    // 8 day tiles in a 4x2 grid — staggered pop-in timing (seconds)
    private let tileDelays: [Double] = [0.0, 0.2, 0.4, 0.73, 0.93, 1.13, 1.33, 1.53]
    // Sparkle timing
    private let sparkleDelays: [Double] = [0.13, 0.17, 0.53, 0.9, 0.83]

    private let lineColor = Color(white: 0.28)
    private let tileColor = Color(red: 0.15, green: 0.53, blue: 0.96)
    private let headerFill = Color(white: 0.91)

    var body: some View {
        Canvas { context, size in
            let s = min(size.width / 210, size.height / 156)
            let ox = (size.width - 210 * s) / 2
            let oy = (size.height - 156 * s) / 2

            // Helper to scale points
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(x: ox + x * s, y: oy + y * s)
            }
            func v(_ val: CGFloat) -> CGFloat { val * s }

            // --- Calendar body (rounded rect) ---
            let bodyRect = CGRect(x: ox, y: oy + 22 * s, width: 210 * s, height: 134 * s)
            let bodyPath = Path(roundedRect: bodyRect, cornerRadius: v(11))
            context.fill(bodyPath, with: .color(.white))
            context.stroke(bodyPath, with: .color(lineColor), style: StrokeStyle(lineWidth: v(1.7)))

            // --- Header bar ---
            var headerPath = Path()
            headerPath.addRoundedRect(in: CGRect(x: ox, y: oy + 22 * s, width: 210 * s, height: 30 * s),
                                       cornerSize: CGSize(width: v(11), height: v(11)))
            // Clip bottom corners of header
            let headerClip = CGRect(x: ox, y: oy + 22 * s, width: 210 * s, height: 30 * s)
            let headerVisual = Path(roundedRect: headerClip, cornerRadii: .init(topLeading: v(11), bottomLeading: 0, bottomTrailing: 0, topTrailing: v(11)))
            context.fill(headerVisual, with: .color(headerFill))
            context.stroke(headerVisual, with: .color(lineColor), style: StrokeStyle(lineWidth: v(1.7)))

            // --- Horizontal divider below header ---
            var divider = Path()
            divider.move(to: p(0, 52))
            divider.addLine(to: p(210, 52))
            context.stroke(divider, with: .color(lineColor), style: StrokeStyle(lineWidth: v(1.7)))

            // --- Vertical divider ---
            var vDiv = Path()
            vDiv.move(to: p(105, 52))
            vDiv.addLine(to: p(105, 156))
            context.stroke(vDiv, with: .color(lineColor), style: StrokeStyle(lineWidth: v(1.7)))

            // --- Horizontal mid divider ---
            var hDiv = Path()
            hDiv.move(to: p(0, 104))
            hDiv.addLine(to: p(210, 104))
            context.stroke(hDiv, with: .color(lineColor), style: StrokeStyle(lineWidth: v(1.7)))

            // --- Ring pegs (6 circles on top) ---
            let pegXs: [CGFloat] = [31.4, 59, 86.5, 114.1, 141.7, 169.3]
            for px in pegXs {
                // Peg stem
                var stem = Path()
                stem.move(to: p(px, 8))
                stem.addLine(to: p(px, 30))
                context.stroke(stem, with: .color(lineColor), style: StrokeStyle(lineWidth: v(3), lineCap: .round))
                // Peg circle
                let pegCircle = Path(ellipseIn: CGRect(x: ox + (px - 6.4) * s, y: oy, width: v(12.8), height: v(12.8)))
                context.fill(pegCircle, with: .color(.white))
                context.stroke(pegCircle, with: .color(lineColor), style: StrokeStyle(lineWidth: v(1.7)))
            }

            // --- Day tiles (4 columns x 2 rows) ---
            let tilePositions: [(x: CGFloat, y: CGFloat)] = [
                (30, 68), (76.5, 68), (123, 68), (170, 68),   // row 1
                (170, 114), (123, 114), (76, 114), (30, 114),  // row 2
            ]
            let tileSize: CGFloat = 35

            for (i, pos) in tilePositions.enumerated() {
                let sc = tileScales[i]
                guard sc > 0.01 else { continue }
                let cx = ox + pos.x * s
                let cy = oy + pos.y * s
                let half = tileSize * s * sc / 2
                let tileRect = CGRect(x: cx - half, y: cy - half, width: half * 2, height: half * 2)
                let tilePath = Path(roundedRect: tileRect, cornerRadius: half * 0.35)
                context.fill(tilePath, with: .color(tileColor.opacity(Double(sc.clamped(to: 0...1)))))
            }

            // --- Checkmark on tile at (123, 68) ---
            if checkScale > 0.01 {
                let cx = ox + 123 * s
                let cy = oy + 68 * s
                let cs = checkScale.clamped(to: 0...1.5)
                var check = Path()
                check.move(to: CGPoint(x: cx - 6 * s * cs, y: cy + 1 * s * cs))
                check.addLine(to: CGPoint(x: cx - 1.5 * s * cs, y: cy + 6 * s * cs))
                check.addLine(to: CGPoint(x: cx + 7 * s * cs, y: cy - 6 * s * cs))
                context.stroke(check, with: .color(.white),
                               style: StrokeStyle(lineWidth: v(2.5) * cs, lineCap: .round, lineJoin: .round))
            }

            // --- Sparkles ---
            let sparklePositions: [(x: CGFloat, y: CGFloat)] = [
                (190, -8), (206, 14), (122, -2), (-24, -12), (-38, 8)
            ]
            for (i, sp) in sparklePositions.enumerated() {
                let sc = sparkleScales[i]
                guard sc > 0.01 else { continue }
                let cx = ox + sp.x * s
                let cy = oy + sp.y * s
                let arm = 4 * s * sc
                let starColor = Color(red: 0.22, green: 0.22, blue: 0.86)
                var star = Path()
                star.move(to: CGPoint(x: cx - arm, y: cy))
                star.addLine(to: CGPoint(x: cx + arm, y: cy))
                star.move(to: CGPoint(x: cx, y: cy - arm))
                star.addLine(to: CGPoint(x: cx, y: cy + arm))
                context.stroke(star, with: .color(starColor.opacity(sparkleOpacity)),
                               style: StrokeStyle(lineWidth: v(0.7), lineCap: .round))
            }
        }
        .onAppear { runLoop() }
    }

    private func runLoop() {
        // Reset
        tileScales = Array(repeating: 0, count: 8)
        checkScale = 0
        sparkleOpacity = 0
        sparkleScales = Array(repeating: 0, count: 5)

        // Pop in tiles sequentially
        for i in 0..<8 {
            DispatchQueue.main.asyncAfter(deadline: .now() + tileDelays[i]) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                    tileScales[i] = 1.1
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + tileDelays[i] + 0.2) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                    tileScales[i] = 1.0
                }
            }
        }

        // Checkmark appears at ~0.87s, bounces
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.87) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                checkScale = 1.3
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.07) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.65)) {
                checkScale = 1.0
            }
        }

        // Sparkles fade in and twinkle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.0) {
            withAnimation(.easeIn(duration: 1.3)) {
                sparkleOpacity = 1.0
            }
        }
        for i in 0..<5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + sparkleDelays[i]) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    sparkleScales[i] = 1.0
                }
            }
            // Twinkle out and back
            DispatchQueue.main.asyncAfter(deadline: .now() + sparkleDelays[i] + 0.8) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    sparkleScales[i] = 0
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + sparkleDelays[i] + 1.3) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    sparkleScales[i] = 0.8
                }
            }
        }

        // Pop out tiles (reverse order, staggered from ~2.4s)
        for i in 0..<8 {
            let outDelay = 2.4 + Double(i) * 0.06
            DispatchQueue.main.asyncAfter(deadline: .now() + outDelay) {
                withAnimation(.spring(response: 0.15, dampingFraction: 0.7)) {
                    tileScales[7 - i] = 1.1
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + outDelay + 0.1) {
                withAnimation(.easeIn(duration: 0.15)) {
                    tileScales[7 - i] = 0
                }
            }
        }

        // Fade out checkmark and sparkles
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeIn(duration: 0.2)) {
                checkScale = 0
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeIn(duration: 0.3)) {
                sparkleOpacity = 0
                for i in 0..<5 { sparkleScales[i] = 0 }
            }
        }

        // Loop after full cycle (3s = 90 frames @ 30fps)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
            runLoop()
        }
    }
}

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

#Preview {
    ContentView()
}
