import SwiftUI

// MARK: - Root View

struct ContentView: View {
    @State var store = ChecklistStore()
    @State private var expandedWeekIDs: Set<UUID> = []
    @State private var expandedCategoryIDs: Set<UUID> = []

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header bar
                headerBar

                // Week cards
                ForEach(store.weeks) { week in
                    WeekCard(
                        week: week,
                        store: store,
                        isExpanded: expandedWeekIDs.contains(week.id),
                        expandedCategoryIDs: $expandedCategoryIDs,
                        onToggleExpand: {
                            withAnimation(.snappy(duration: 0.3)) {
                                if expandedWeekIDs.contains(week.id) {
                                    expandedWeekIDs.remove(week.id)
                                } else {
                                    expandedWeekIDs.insert(week.id)
                                }
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 40)
        }
        .background(Color(red: 0.08, green: 0.08, blue: 0.14))
        .onAppear {
            // Auto-expand the current week
            if let currentWeek = store.weeks.first {
                expandedWeekIDs.insert(currentWeek.id)
                // Auto-expand its first category
                if let firstCat = currentWeek.categories.first {
                    expandedCategoryIDs.insert(firstCat.id)
                }
            }
        }
    }

    private var headerBar: some View {
        HStack {
            Image(systemName: "calendar")
                .font(.title2)
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
            Image(systemName: "slider.horizontal.3")
                .font(.title2)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.horizontal, 6)
        .padding(.top, 8)
    }
}

// MARK: - Week Card

struct WeekCard: View {
    let week: Week
    let store: ChecklistStore
    let isExpanded: Bool
    @Binding var expandedCategoryIDs: Set<UUID>
    let onToggleExpand: () -> Void

    @State private var showAddCategory = false
    @State private var newCategoryName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Week header
            Button(action: onToggleExpand) {
                HStack {
                    Text(week.displayTitle)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.6))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    // Add Category button
                    addCategoryButton

                    // Categories
                    ForEach(week.categories) { category in
                        CategorySection(
                            week: week,
                            category: category,
                            store: store,
                            isExpanded: expandedCategoryIDs.contains(category.id),
                            onToggleExpand: {
                                withAnimation(.snappy(duration: 0.25)) {
                                    if expandedCategoryIDs.contains(category.id) {
                                        expandedCategoryIDs.remove(category.id)
                                    } else {
                                        expandedCategoryIDs.insert(category.id)
                                    }
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color(red: 0.14, green: 0.14, blue: 0.22), in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var addCategoryButton: some View {
        if showAddCategory {
            HStack(spacing: 8) {
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                TextField("Category name", text: $newCategoryName)
                    .textFieldStyle(.plain)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .onSubmit {
                        let name = newCategoryName.trimmingCharacters(in: .whitespaces)
                        if !name.isEmpty {
                            store.addCategory(to: week.id, name: name)
                            // Auto-expand the new category
                            if let newCat = store.weeks.first(where: { $0.id == week.id })?.categories.last {
                                expandedCategoryIDs.insert(newCat.id)
                            }
                        }
                        newCategoryName = ""
                        showAddCategory = false
                    }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.08), in: Capsule())
            .padding(.bottom, 8)
        } else {
            Button {
                showAddCategory = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.down")
                        .font(.caption)
                    Text("Add Category")
                        .font(.subheadline)
                }
                .foregroundStyle(.white.opacity(0.8))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.08), in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.bottom, 8)
        }
    }
}

// MARK: - Category Section

struct CategorySection: View {
    let week: Week
    let category: Category
    let store: ChecklistStore
    let isExpanded: Bool
    let onToggleExpand: () -> Void

    @State private var newTaskTitle = ""
    @State private var editingTaskID: UUID?
    @State private var editingTaskTitle = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Category header
            HStack {
                Button(action: onToggleExpand) {
                    HStack {
                        Text(category.name)
                            .font(.headline)
                            .foregroundStyle(.white)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                // Delete category
                Button {
                    withAnimation(.snappy(duration: 0.25)) {
                        store.deleteCategory(weekID: week.id, categoryID: category.id)
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.3))
                }
                .buttonStyle(.plain)

                Image(systemName: "arrowtriangle.up.fill")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
                    .rotationEffect(.degrees(isExpanded ? 0 : 180))
                    .onTapGesture(perform: onToggleExpand)
            }
            .padding(.top, 12)

            if isExpanded {
                VStack(spacing: 4) {
                    // Task rows
                    ForEach(category.tasks) { task in
                        TaskRow(
                            task: task,
                            weekID: week.id,
                            categoryID: category.id,
                            store: store,
                            isEditing: editingTaskID == task.id,
                            editingTitle: editingTaskID == task.id ? $editingTaskTitle : .constant(""),
                            onStartEdit: {
                                editingTaskID = task.id
                                editingTaskTitle = task.title
                            },
                            onEndEdit: {
                                let title = editingTaskTitle.trimmingCharacters(in: .whitespaces)
                                if !title.isEmpty {
                                    store.renameTask(weekID: week.id, categoryID: category.id, taskID: task.id, newTitle: title)
                                }
                                editingTaskID = nil
                            }
                        )
                    }

                    // Add task row
                    addTaskRow
                }
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var addTaskRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.3))

            TextField("Add task", text: $newTaskTitle)
                .textFieldStyle(.plain)
                .font(.body)
                .foregroundStyle(.white)
                .onSubmit {
                    let title = newTaskTitle.trimmingCharacters(in: .whitespaces)
                    if !title.isEmpty {
                        withAnimation(.snappy(duration: 0.2)) {
                            store.addTask(weekID: week.id, categoryID: category.id, title: title)
                        }
                    }
                    newTaskTitle = ""
                }

            Spacer()

            // Carry-forward icon (repeat)
            Image(systemName: "arrow.2.squarepath")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.25))

            // Quick-complete icon
            Image(systemName: "checkmark.square")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.25))
        }
        .padding(.vertical, 6)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.white.opacity(0.1))
                .frame(height: 1)
                .padding(.leading, 36)
        }
    }
}

// MARK: - Task Row

struct TaskRow: View {
    let task: ChecklistTask
    let weekID: UUID
    let categoryID: UUID
    let store: ChecklistStore
    let isEditing: Bool
    @Binding var editingTitle: String
    let onStartEdit: () -> Void
    let onEndEdit: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            // Completion circle
            Button {
                withAnimation(.snappy(duration: 0.2)) {
                    store.toggleTask(weekID: weekID, categoryID: categoryID, taskID: task.id)
                }
            } label: {
                Circle()
                    .fill(task.isCompleted ? Color.green : Color.clear)
                    .strokeBorder(task.isCompleted ? Color.green : Color.white.opacity(0.4), lineWidth: 2)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)

            // Task title
            if isEditing {
                TextField("Task name", text: $editingTitle)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .foregroundStyle(.white)
                    .onSubmit(onEndEdit)
            } else {
                Text(task.title)
                    .font(.body)
                    .foregroundStyle(task.isCompleted ? .white.opacity(0.4) : .white)
                    .strikethrough(task.isCompleted, color: .white.opacity(0.3))
            }

            Spacer()

            // Edit button
            Button(action: onStartEdit) {
                Image(systemName: "pencil")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
            }
            .buttonStyle(.plain)

            // Delete button
            Button {
                withAnimation(.snappy(duration: 0.2)) {
                    store.deleteTask(weekID: weekID, categoryID: categoryID, taskID: task.id)
                }
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
                }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    ContentView()
}
