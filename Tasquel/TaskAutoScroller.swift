import SwiftUI
import UIKit

// MARK: - Auto-Scrolling While Moving a Task

/// Scrolls the week's grid of cards while a task moved by its handle is held near the top
/// or bottom of what's visible, so a card longer than the screen can be reordered end to
/// end. Faster the closer the finger is to the edge. It moves the grid's own `UIScrollView`
/// a frame at a time (a display link), outside SwiftUI's state, so nothing else redraws.
final class TaskAutoScroller: NSObject {
    /// How far in from the edge the finger starts the scrolling, and the speed at the edge.
    static let zone: CGFloat = 72
    static let maxSpeed: CGFloat = 900  // points a second

    /// A view inside the grid (`TaskAutoScrollAnchor`), to find its scroll view from.
    weak var anchor: UIView?
    private weak var scrollView: UIScrollView?
    private var link: CADisplayLink?
    private var velocity: CGFloat = 0
    private var startOffset: CGFloat = 0
    private var onScroll: (() -> Void)?

    /// How far the grid has scrolled since `begin`, down positive.
    var scrolled: CGFloat { (scrollView?.contentOffset.y ?? startOffset) - startOffset }

    /// A task was lifted: scrolling is measured from here.
    func begin() {
        var view = anchor?.superview
        while let current = view, !(current is UIScrollView) { view = current.superview }
        scrollView = view as? UIScrollView
        startOffset = scrollView?.contentOffset.y ?? 0
    }

    /// The finger is at `fingerY` (window coordinates). Scrolls up or down, where allowed,
    /// while it's near that edge of the visible grid: below the header (the scroll view's
    /// top inset), above the bottom bar (`bottomBar`, measured from the window's bottom).
    /// `onScroll` runs after each step, for the lifted task to keep up with the finger.
    func update(fingerY: CGFloat, canScrollUp: Bool, canScrollDown: Bool, bottomBar: CGFloat,
                onScroll: @escaping () -> Void) {
        self.onScroll = onScroll
        guard let scrollView, let window = scrollView.window else { return stop() }
        let visible = scrollView.convert(scrollView.bounds, to: nil)
        let top = visible.minY + scrollView.adjustedContentInset.top
        let bottom = min(visible.maxY - scrollView.adjustedContentInset.bottom, window.bounds.maxY - bottomBar)
        let speed = Self.velocity(fingerY: fingerY, top: top, bottom: bottom)
        velocity = speed < 0 && canScrollUp || speed > 0 && canScrollDown ? speed : 0
        if velocity == 0 {
            stop()
        } else if link == nil {
            let link = CADisplayLink(target: self, selector: #selector(step))
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
            link.add(to: .main, forMode: .common)
            self.link = link
        }
    }

    /// The task was dropped (or the card went): no more scrolling.
    func end() {
        stop()
        onScroll = nil
        scrollView = nil
    }

    /// Points a second for a finger at `fingerY` between the visible `top` and `bottom`:
    /// up (negative) or down within `zone` of an edge, faster closer to it; 0 elsewhere.
    static func velocity(fingerY: CGFloat, top: CGFloat, bottom: CGFloat) -> CGFloat {
        guard bottom - top > zone * 2 else { return 0 }
        if fingerY < top + zone { return -maxSpeed * min(1, (top + zone - fingerY) / zone) }
        if fingerY > bottom - zone { return maxSpeed * min(1, (fingerY - (bottom - zone)) / zone) }
        return 0
    }

    private func stop() {
        link?.invalidate()
        link = nil
        velocity = 0
    }

    @objc private func step(_ link: CADisplayLink) {
        guard let scrollView, velocity != 0 else { return stop() }
        let seconds = min(max(link.targetTimestamp - link.timestamp, 0), 1.0 / 30)
        let lowest = -scrollView.adjustedContentInset.top
        let highest = max(lowest, scrollView.contentSize.height - scrollView.bounds.height + scrollView.adjustedContentInset.bottom)
        let y = min(max(scrollView.contentOffset.y + velocity * seconds, lowest), highest)
        guard abs(y - scrollView.contentOffset.y) > 0.01 else { return stop() }
        scrollView.contentOffset = CGPoint(x: scrollView.contentOffset.x, y: y)
        onScroll?()
    }
}

/// Puts a plain view inside the grid, so `TaskAutoScroller` can find the scroll view it's
/// in (the viewed week's page). Takes no touches and isn't seen by VoiceOver.
struct TaskAutoScrollAnchor: UIViewRepresentable {
    let scroller: TaskAutoScroller

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.isAccessibilityElement = false
        scroller.anchor = view
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        scroller.anchor = view
    }
}
