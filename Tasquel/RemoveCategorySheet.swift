import SwiftUI

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
                    withAnimation { store.deleteCategoryEntirely(category.id) }
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
