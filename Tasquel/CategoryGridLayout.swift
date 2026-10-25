import SwiftUI

// MARK: - Category Grid Layout

/// Card grid (two columns on iPhone, three on iPad) where expanded cards take a full-width row.
///
/// Every card is a direct subview, so each keeps a stable identity and SwiftUI
/// animates its position and size when cards expand, collapse, or reflow.
/// Mark full-width subviews with `.categoryGridFullWidth(true)`.
struct CategoryGridLayout: Layout {
    var spacing: CGFloat = 8
    var columns = 2

    /// Groups subview indices into rows of up to `columns`. A full-width item gets its
    /// own row; a partly filled row ends early if a full-width item follows.
    nonisolated static func rows(fullWidth: [Bool], columns: Int = 2) -> [[Int]] {
        var rows: [[Int]] = []
        var pending: [Int] = []
        for (index, isFull) in fullWidth.enumerated() {
            if isFull {
                if !pending.isEmpty { rows.append(pending); pending = [] }
                rows.append([index])
            } else {
                pending.append(index)
                if pending.count == max(columns, 1) { rows.append(pending); pending = [] }
            }
        }
        if !pending.isEmpty { rows.append(pending) }
        return rows
    }

    private func columnWidth(in width: CGFloat) -> CGFloat {
        (width - spacing * CGFloat(columns - 1)) / CGFloat(columns)
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
        let columnWidth = columnWidth(in: bounds.width)
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
        let rows = Self.rows(fullWidth: subviews.map { $0[CategoryGridFullWidthKey.self] }, columns: columns)
        let columnWidth = columnWidth(in: width)
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
