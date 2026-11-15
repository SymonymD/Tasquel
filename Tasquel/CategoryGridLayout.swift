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
    /// An open card takes half the width (two of four columns, iPad landscape), and the
    /// closed cards after it stack two across beside it (the user, 2026-11-15).
    var halfWidthOpen = false

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
        var frames: [CGRect] = []
        var total: CGFloat = 0
    }

    func makeCache(subviews: Subviews) -> Cache { Cache() }

    func updateCache(_ cache: inout Cache, subviews: Subviews) { cache = Cache() }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        let width = proposal.replacingUnspecifiedDimensions().width
        if halfWidthOpen {
            frames(subviews: subviews, width: width, cache: &cache)
            return CGSize(width: width, height: cache.total)
        }
        measure(subviews: subviews, width: width, cache: &cache)
        let total = cache.heights.reduce(0, +) + spacing * CGFloat(max(cache.heights.count - 1, 0))
        return CGSize(width: width, height: total)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        if halfWidthOpen {
            frames(subviews: subviews, width: bounds.width, cache: &cache)
            for (index, frame) in cache.frames.enumerated() {
                subviews[index].place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), anchor: .topLeading,
                                      proposal: ProposedViewSize(width: frame.width, height: frame.height))
            }
            return
        }
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

    /// No alignment guides come out of the grid. Left to the default, which merges the guides
    /// of every card, the scroll view's sizing measured every card (and every task row in it)
    /// again on each frame of a card opening or closing (2026-11-12).
    func explicitAlignment(of guide: HorizontalAlignment, in bounds: CGRect, proposal: ProposedViewSize,
                           subviews: Subviews, cache: inout Cache) -> CGFloat? { nil }
    func explicitAlignment(of guide: VerticalAlignment, in bounds: CGRect, proposal: ProposedViewSize,
                           subviews: Subviews, cache: inout Cache) -> CGFloat? { nil }

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

extension CategoryGridLayout {
    /// Every card's frame with open cards two columns wide. Cards before the
    /// first open one keep the usual rows. From there the grid is two lanes: the left one two
    /// columns wide, the right one the rest (two columns in landscape, one in portrait). An
    /// open card goes into a two-column lane (the shorter one in landscape, the left one in
    /// portrait); closed cards go, a row at a time, into the shorter lane, as many across as
    /// it has columns.
    fileprivate func frames(subviews: Subviews, width: CGFloat, cache: inout Cache) {
        guard cache.width != width || cache.frames.count != subviews.count else { return }
        let open = subviews.map { $0[CategoryGridFullWidthKey.self] }
        let column = columnWidth(in: width)
        func height(_ i: Int, _ w: CGFloat) -> CGFloat { subviews[i].sizeThatFits(ProposedViewSize(width: w, height: nil)).height }
        var frames = Array(repeating: CGRect.zero, count: subviews.count)
        var y: CGFloat = 0
        var i = 0
        // The usual rows, up to the first open card.
        var row: [Int] = []
        func placeRow(_ items: [Int], x: CGFloat, y: CGFloat) -> CGFloat {
            let h = items.map { height($0, column) }.max() ?? 0
            for (k, index) in items.enumerated() {
                frames[index] = CGRect(x: x + CGFloat(k) * (column + spacing), y: y, width: column, height: h)
            }
            return h
        }
        while i < subviews.count, !open[i] {
            row.append(i)
            if row.count == columns { y += placeRow(row, x: 0, y: y) + spacing; row = [] }
            i += 1
        }
        // Lanes from here; a partial row before the open card goes into them.
        struct Lane { var x: CGFloat; var columns: Int; var y: CGFloat }
        let wide = column * 2 + spacing
        var lanes = [Lane(x: 0, columns: 2, y: y), Lane(x: wide + spacing, columns: max(columns - 2, 1), y: y)]
        var waiting = row
        // The shorter lane; on a tie, open cards take the left and closed cards the right.
        func shorter(_ allowed: [Int], preferLeft: Bool) -> Int {
            allowed.min { lanes[$0].y < lanes[$1].y || (lanes[$0].y == lanes[$1].y && (preferLeft ? $0 < $1 : $0 > $1)) }!
        }
        func placeClosed(_ items: inout [Int], force: Bool) {
            while !items.isEmpty {
                let lane = shorter([0, 1], preferLeft: false)
                let count = lanes[lane].columns
                guard items.count >= count || force else { return }
                let batch = Array(items.prefix(count))
                items.removeFirst(batch.count)
                lanes[lane].y += placeRow(batch, x: lanes[lane].x, y: lanes[lane].y) + spacing
            }
        }
        while i < subviews.count {
            if open[i] {
                // A closed card waiting for a partner keeps waiting: no half-empty row.
                let lane = columns >= 4 ? shorter([0, 1], preferLeft: true) : 0
                let h = height(i, wide)
                frames[i] = CGRect(x: lanes[lane].x, y: lanes[lane].y, width: wide, height: h)
                lanes[lane].y += h + spacing
            } else {
                waiting.append(i)
                placeClosed(&waiting, force: false)
            }
            i += 1
        }
        placeClosed(&waiting, force: true)
        if subviews.isEmpty { y = spacing }
        let bottom = open.contains(true) ? max(lanes[0].y, lanes[1].y) : y + (row.isEmpty ? 0 : placeRow(row, x: 0, y: y) + spacing)
        cache.width = width
        cache.frames = frames
        cache.total = max(bottom - spacing, 0)
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
