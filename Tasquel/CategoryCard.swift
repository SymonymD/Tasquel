import SwiftUI

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
                withAnimation { store.deleteCategoryEntirely(category.id) }
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

            // Collapse button
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
                withAnimation { store.deleteCategoryEntirely(category.id) }
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
