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
    /// The lanes open cards are in, by card name, shared by every week's page: a page built
    /// again (two weeks away and back) or cards reopened after Edit start with an empty cache,
    /// and dealt afresh, open cards swapped lanes (the 2026-11-15 review). Owned by
    /// ContentView, which forgets a card's lane when it's closed and all of them when the
    /// columns change.
    var laneMemory: CategoryLaneMemory? = nil

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
        /// The lane (0 left, 1 right) each card in the lanes had on the last pass, by card:
        /// kept from pass to pass, so an open card stays in its lane (`halfWidthOpen`).
        var lanes: [UUID: Int] = [:]
    }

    func makeCache(subviews: Subviews) -> Cache { Cache() }

    /// Measured again; the lanes carry on while open cards take half the width.
    func updateCache(_ cache: inout Cache, subviews: Subviews) {
        cache = Cache(lanes: halfWidthOpen ? cache.lanes : [:])
    }

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
    /// Every card's frame with open cards two columns wide, from the subviews (see `laneFrames`).
    fileprivate func frames(subviews: Subviews, width: CGFloat, cache: inout Cache) {
        guard cache.width != width || cache.frames.count != subviews.count else { return }
        let laid = laneFrames(open: subviews.map { $0[CategoryGridFullWidthKey.self] },
                              cards: subviews.map { $0[CategoryGridCardKey.self] },
                              names: subviews.map { $0[CategoryGridCardNameKey.self] }, memory: laneMemory,
                              width: width, lanes: &cache.lanes) { index, width in
            subviews[index].sizeThatFits(ProposedViewSize(width: width, height: nil)).height
        }
        cache.width = width
        cache.frames = laid.frames
        cache.total = laid.total
    }

    /// Every card's frame with open cards two columns wide. Cards before the
    /// first open one keep the usual rows. From there the grid is two lanes: the left one two
    /// columns wide, the right one the rest (two columns in landscape, one in portrait). Closed
    /// cards go, a row at a time, into the shorter lane, as many across as it has columns. An
    /// open card goes into a two-column lane: the one it was in on the last pass (`lanes`, by
    /// card), so a card opens where it sat and stays in its lane while it's open, whatever
    /// opens or closes around it; one that wasn't in a lane (the first opened, or one from the
    /// rows above the lanes) takes the shorter (in landscape; the left one in portrait).
    /// `lanes` comes back with this pass's lanes.
    /// `memory` (by `names`) holds open cards' lanes across pages and Edit; this page's own
    /// pass (`remembered`, by card) comes first, so a card renamed while open keeps its lane.
    func laneFrames(open: [Bool], cards: [UUID?], names: [String?] = [], memory: CategoryLaneMemory? = nil,
                    width: CGFloat, lanes remembered: inout [UUID: Int],
                    height: (Int, CGFloat) -> CGFloat) -> (frames: [CGRect], total: CGFloat) {
        let name = { (index: Int) in names.indices.contains(index) ? names[index] : nil }
        let count = open.count
        let column = columnWidth(in: width)
        var frames = Array(repeating: CGRect.zero, count: count)
        var placedLanes: [UUID: Int] = [:]
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
        while i < count, !open[i] {
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
                for index in batch { if let card = cards[index] { placedLanes[card] = lane } }
            }
        }
        while i < count {
            if open[i] {
                // A closed card waiting for a partner keeps waiting: no half-empty row.
                let lane = columns >= 4
                    ? cards[i].flatMap { remembered[$0] } ?? name(i).flatMap { memory?.lanes[$0] } ?? shorter([0, 1], preferLeft: true)
                    : 0
                if columns >= 4, let key = name(i) { memory?.lanes[key] = lane }
                let h = height(i, wide)
                frames[i] = CGRect(x: lanes[lane].x, y: lanes[lane].y, width: wide, height: h)
                lanes[lane].y += h + spacing
                if let card = cards[i] { placedLanes[card] = lane }
            } else {
                waiting.append(i)
                placeClosed(&waiting, force: false)
            }
            i += 1
        }
        placeClosed(&waiting, force: true)
        if count == 0 { y = spacing }
        let anyOpen = open.contains(true)
        let bottom = anyOpen ? max(lanes[0].y, lanes[1].y) : y + (row.isEmpty ? 0 : placeRow(row, x: 0, y: y) + spacing)
        // With no card open there are no lanes (the last row went into one above, then back).
        remembered = anyOpen ? placedLanes : [:]
        return (frames, max(bottom - spacing, 0))
    }
}

nonisolated private struct CategoryGridFullWidthKey: LayoutValueKey {
    static let defaultValue = false
}

/// The card a subview is (its category's ID), so the grid can keep an open card in its lane.
nonisolated private struct CategoryGridCardKey: LayoutValueKey {
    static let defaultValue: UUID? = nil
}

/// The card's name (and which of that name), the same in every week, for `CategoryLaneMemory`.
nonisolated private struct CategoryGridCardNameKey: LayoutValueKey {
    static let defaultValue: String? = nil
}

/// Open cards' lanes by card name, shared by the grid's pages (see `laneMemory`). A plain
/// class, not observed: the grid reads and writes it while laying out.
final class CategoryLaneMemory {
    var lanes: [String: Int] = [:]
}

extension View {
    /// Places this view on its own full-width row in a `CategoryGridLayout`.
    func categoryGridFullWidth(_ isFullWidth: Bool) -> some View {
        layoutValue(key: CategoryGridFullWidthKey.self, value: isFullWidth)
    }

    /// Names this view's card to a `CategoryGridLayout`, which keeps an open card in the
    /// lane it opened in (four columns) by it.
    func categoryGridCard(_ id: UUID, name: String? = nil) -> some View {
        layoutValue(key: CategoryGridCardKey.self, value: id)
            .layoutValue(key: CategoryGridCardNameKey.self, value: name)
    }
}
