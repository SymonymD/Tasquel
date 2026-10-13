import SwiftUI

// MARK: - Category Grid Layout

/// Two-column card grid where expanded cards take a full-width row.
///
/// Every card is a direct subview, so each keeps a stable identity and SwiftUI
/// animates its position and size when cards expand, collapse, or reflow.
/// Mark full-width subviews with `.categoryGridFullWidth(true)`.
struct CategoryGridLayout: Layout {
    var spacing: CGFloat = 8

    /// Groups subview indices into rows. A full-width item gets its own row; a
    /// half-width item waiting for a partner stays alone if a full-width item follows.
    nonisolated static func rows(fullWidth: [Bool]) -> [[Int]] {
        var rows: [[Int]] = []
        var pending: Int?
        for (index, isFull) in fullWidth.enumerated() {
            if isFull {
                if let left = pending { rows.append([left]); pending = nil }
                rows.append([index])
            } else if let left = pending {
                rows.append([left, index])
                pending = nil
            } else {
                pending = index
            }
        }
        if let left = pending { rows.append([left]) }
        return rows
    }

    /// Row grouping and heights for one width, so a layout pass measures each card once.
    struct Cache {
        var width: CGFloat?
        var rows: [[Int]] = []
        var heights: [CGFloat] = []
    }

    func makeCache(subviews: Subviews) -> Cache { Cache() }

    func updateCache(_ cache: inout Cache, subviews: Subviews) { cache = Cache() }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        let width = proposal.replacingUnspecifiedDimensions().width
        measure(subviews: subviews, width: width, cache: &cache)
        let total = cache.heights.reduce(0, +) + spacing * CGFloat(max(cache.heights.count - 1, 0))
        return CGSize(width: width, height: total)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        measure(subviews: subviews, width: bounds.width, cache: &cache)
        let rows = cache.rows
        let heights = cache.heights
        let columnWidth = (bounds.width - spacing) / 2
        var y = bounds.minY
        for (row, height) in zip(rows, heights) {
            for (column, index) in row.enumerated() {
                let isFull = subviews[index][CategoryGridFullWidthKey.self]
                let width = isFull ? bounds.width : columnWidth
                subviews[index].place(
                    at: CGPoint(x: bounds.minX + CGFloat(column) * (columnWidth + spacing), y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(width: width, height: height)
                )
            }
            y += height + spacing
        }
    }

    /// Cards in the same row share the taller card's height.
    private func measure(subviews: Subviews, width: CGFloat, cache: inout Cache) {
        guard cache.width != width else { return }
        let rows = Self.rows(fullWidth: subviews.map { $0[CategoryGridFullWidthKey.self] })
        let columnWidth = (width - spacing) / 2
        cache.width = width
        cache.rows = rows
        cache.heights = rows.map { row in
            row.map { index in
                let isFull = subviews[index][CategoryGridFullWidthKey.self]
                return subviews[index].sizeThatFits(
                    ProposedViewSize(width: isFull ? width : columnWidth, height: nil)
                ).height
            }.max() ?? 0
        }
    }
}

nonisolated private struct CategoryGridFullWidthKey: LayoutValueKey {
    static let defaultValue = false
}

extension View {
    /// Places this view on its own full-width row in a `CategoryGridLayout`.
    func categoryGridFullWidth(_ isFullWidth: Bool) -> some View {
        layoutValue(key: CategoryGridFullWidthKey.self, value: isFullWidth)
    }
}
