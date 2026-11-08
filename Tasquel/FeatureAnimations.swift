import SwiftUI

// MARK: - Illustration Parts
//
// Shared pieces of the onboarding illustrations, so every page draws its cards,
// checks and task stand-ins the same way.

enum Illustration {
    static let pendingColor = Color(hue: 0.07, saturation: 0.7, brightness: 0.85)
    static let doneColor = Color(hue: 0.33, saturation: 0.7, brightness: 0.75)

    static func cardBackground() -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color(.secondarySystemBackground))
            .shadow(color: .black.opacity(0.1), radius: 6, y: 2)
    }

    static func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 8.5, weight: .bold))
            .kerning(0.6)
            .foregroundStyle(.secondary)
            .frame(height: 10)
    }

    /// Stands in for a task's title; it fades as the task is done and turns orange while pending.
    static func bar(width: CGFloat, check: Double = 0, pending: Double = 0, faint: Bool = false) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.primary.opacity(faint ? 0.08 : 0.22 - 0.12 * check))
                .opacity(1 - pending)
            RoundedRectangle(cornerRadius: 3).fill(pendingColor.opacity(0.45)).opacity(pending)
        }
        .frame(width: width, height: 6)
    }

    /// A finger tap: a soft circle that grows and fades as `tap` goes from 0 to 1.
    static func ripple(_ tap: Double) -> some View {
        Circle()
            .fill(Color.primary.opacity(0.12))
            .frame(width: 36, height: 36)
            .scaleEffect(0.4 + 0.9 * tap)
            .opacity(tap > 0 ? 1 - tap : 0)
    }

    /// A small row icon, like the type and mode icons at the end of a task.
    static func icon(_ symbol: String) -> some View {
        Image(systemName: symbol).font(.system(size: 8, weight: .bold))
    }
}

/// A task's check: a gray ring that `pending` turns orange and `progress` fills like a
/// goal ring, then a green fill with a checkmark as `check` goes to 1.
struct IllustrationCheck: View {
    var check: Double
    var pending: Double = 0
    var progress: Double = 0
    var faint = false
    var size: CGFloat = 15

    var body: some View {
        // Rings fade as the green fill grows so no outline shows around a finished check.
        let ringOpacity = max(0, 1 - check)
        ZStack {
            Circle().stroke(Color.secondary.opacity(faint ? 0.35 : 0.6), lineWidth: 1.5)
                .opacity((1 - pending) * ringOpacity)
            Circle().stroke(Illustration.pendingColor, lineWidth: 2).opacity(pending * ringOpacity)
            Circle().trim(from: 0, to: progress)
                .stroke(Illustration.doneColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .opacity(ringOpacity)
            Circle().fill(Illustration.doneColor).scaleEffect(check)
            Image(systemName: "checkmark")
                .font(.system(size: size * 0.53, weight: .heavy))
                .foregroundStyle(.white)
                .scaleEffect(check)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Task Types Animation
//
// One card with the three kinds of task: a checkbox gets ticked, a goal ring fills to
// 50/50 and checks itself off, and a list checks itself off once both its items are done.

struct TaskTypesAnimation: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            content(.finished)
        } else {
            KeyframeAnimator(initialValue: Values(), repeating: true) { values in
                content(values)
            } keyframes: { _ in
                Self.timeline
            }
        }
    }

    struct Values {
        var opacity = 0.0
        var check = 0.0
        var goal = 0.0             // goal progress, 0...1
        var goalCheck = 0.0
        var item1 = 0.0
        var item2 = 0.0
        var listCheck = 0.0
        var glow = 0.0

        static let finished = Values(
            opacity: 1, check: 1, goal: 1, goalCheck: 1, item1: 1, item2: 1, listCheck: 1, glow: 0.4
        )
    }

    // One loop is 6 seconds. Every track sums to the same length so they stay aligned.
    @KeyframesBuilder<Values>
    static var timeline: some Keyframes<Values> {
        KeyframeTrack(\.opacity) {
            LinearKeyframe(1, duration: 0.3)
            LinearKeyframe(1, duration: 5.2)
            LinearKeyframe(0, duration: 0.4)
            LinearKeyframe(0, duration: 0.1)
        }
        KeyframeTrack(\.check) {
            LinearKeyframe(0, duration: 0.6)
            SpringKeyframe(1, duration: 0.35, spring: .bouncy)
            LinearKeyframe(1, duration: 5.05)
        }
        KeyframeTrack(\.goal) {
            LinearKeyframe(0, duration: 1.2)
            CubicKeyframe(1, duration: 1.0)
            LinearKeyframe(1, duration: 3.8)
        }
        KeyframeTrack(\.goalCheck) {
            LinearKeyframe(0, duration: 2.25)
            SpringKeyframe(1, duration: 0.35, spring: .bouncy)
            LinearKeyframe(1, duration: 3.4)
        }
        KeyframeTrack(\.item1) {
            LinearKeyframe(0, duration: 2.9)
            SpringKeyframe(1, duration: 0.35, spring: .bouncy)
            LinearKeyframe(1, duration: 2.75)
        }
        KeyframeTrack(\.item2) {
            LinearKeyframe(0, duration: 3.35)
            SpringKeyframe(1, duration: 0.35, spring: .bouncy)
            LinearKeyframe(1, duration: 2.3)
        }
        KeyframeTrack(\.listCheck) {
            LinearKeyframe(0, duration: 3.85)
            SpringKeyframe(1, duration: 0.35, spring: .bouncy)
            LinearKeyframe(1, duration: 1.8)
        }
        KeyframeTrack(\.glow) {
            LinearKeyframe(0, duration: 3.95)
            CubicKeyframe(1, duration: 0.3)
            CubicKeyframe(0.4, duration: 0.5)
            LinearKeyframe(0.4, duration: 1.25)
        }
    }

    private func content(_ v: Values) -> some View {
        ZStack {
            Circle()
                .fill(Illustration.doneColor.opacity(0.2))
                .frame(width: 170, height: 170)
                .blur(radius: 18)
                .opacity(v.glow)

            VStack(alignment: .leading, spacing: 7) {
                Illustration.label("THIS WEEK")
                row(icon: "checkmark.circle") {
                    IllustrationCheck(check: v.check)
                    Illustration.bar(width: 70, check: v.check)
                }
                row(icon: "target") {
                    IllustrationCheck(check: v.goalCheck, progress: v.goal)
                    Illustration.bar(width: 44, check: v.goalCheck)
                    Text(verbatim: "\(Int((v.goal * 50).rounded()))/50")
                        .font(.system(size: 7.5, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                row(icon: "list.bullet") {
                    IllustrationCheck(check: v.listCheck)
                    Illustration.bar(width: 58, check: v.listCheck)
                }
                listItem(check: v.item1, width: 46)
                listItem(check: v.item2, width: 34)
            }
            .padding(12)
            .frame(width: 176, alignment: .leading)
            .background(Illustration.cardBackground())
        }
        .frame(width: 240, height: 160)
        .opacity(v.opacity)
        .accessibilityHidden(true)
    }

    private func row<Content: View>(icon: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 8) {
            content()
            Spacer(minLength: 0)
            Illustration.icon(icon).foregroundStyle(.secondary)
        }
        .frame(height: 16)
    }

    private func listItem(check: Double, width: CGFloat) -> some View {
        HStack(spacing: 7) {
            IllustrationCheck(check: check, size: 11)
            Illustration.bar(width: width, check: check)
        }
        .padding(.leading, 23)
        .frame(height: 14)
    }
}

// MARK: - Task Modes Animation
//
// What happens when the week ends: the one-time task stays behind, the unfinished
// carry-over task moves to next week, and the repeating task comes back unchecked.

struct TaskModesAnimation: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            content(.finished)
        } else {
            KeyframeAnimator(initialValue: Values(), repeating: true) { values in
                content(values)
            } keyframes: { _ in
                Self.timeline
            }
        }
    }

    struct Values {
        var opacity = 0.0
        var oneTimeCheck = 0.0
        var repeatingCheck = 0.0
        var pending = 0.0          // the carry-over task is left unfinished
        var thisWeekX = 0.0
        var thisWeekFade = 1.0
        var nextWeekX = 70.0
        var nextWeekFade = 0.0
        var carriedIn = 0.0
        var repeatedIn = 0.0
        var reset = 0.0            // the repeating task unchecks itself

        static let finished = Values(
            opacity: 1, oneTimeCheck: 1, repeatingCheck: 1, pending: 1,
            thisWeekX: -80, thisWeekFade: 0, nextWeekX: 0, nextWeekFade: 1,
            carriedIn: 1, repeatedIn: 1, reset: 1
        )
    }

    // One loop is 6 seconds. Every track sums to the same length so they stay aligned.
    @KeyframesBuilder<Values>
    static var timeline: some Keyframes<Values> {
        KeyframeTrack(\.opacity) {
            LinearKeyframe(1, duration: 0.3)
            LinearKeyframe(1, duration: 5.2)
            LinearKeyframe(0, duration: 0.4)
            LinearKeyframe(0, duration: 0.1)
        }
        // This week: the one-time and repeating tasks get done, the carry-over one doesn't.
        KeyframeTrack(\.oneTimeCheck) {
            LinearKeyframe(0, duration: 0.6)
            SpringKeyframe(1, duration: 0.35, spring: .bouncy)
            LinearKeyframe(1, duration: 5.05)
        }
        KeyframeTrack(\.repeatingCheck) {
            LinearKeyframe(0, duration: 1.05)
            SpringKeyframe(1, duration: 0.35, spring: .bouncy)
            LinearKeyframe(1, duration: 4.6)
        }
        KeyframeTrack(\.pending) {
            LinearKeyframe(0, duration: 1.6)
            CubicKeyframe(1, duration: 0.35)
            LinearKeyframe(1, duration: 4.05)
        }
        // The weeks swap.
        KeyframeTrack(\.thisWeekX) {
            LinearKeyframe(0, duration: 2.4)
            CubicKeyframe(-80, duration: 0.6)
            LinearKeyframe(-80, duration: 3.0)
        }
        KeyframeTrack(\.thisWeekFade) {
            LinearKeyframe(1, duration: 2.4)
            CubicKeyframe(0, duration: 0.5)
            LinearKeyframe(0, duration: 3.1)
        }
        KeyframeTrack(\.nextWeekX) {
            LinearKeyframe(70, duration: 2.55)
            SpringKeyframe(0, duration: 0.6)
            LinearKeyframe(0, duration: 2.85)
        }
        KeyframeTrack(\.nextWeekFade) {
            LinearKeyframe(0, duration: 2.55)
            CubicKeyframe(1, duration: 0.4)
            LinearKeyframe(1, duration: 3.05)
        }
        // Next week: the carry-over task arrives, then the repeating one, which unchecks.
        KeyframeTrack(\.carriedIn) {
            LinearKeyframe(0, duration: 3.0)
            SpringKeyframe(1, duration: 0.4)
            LinearKeyframe(1, duration: 2.6)
        }
        KeyframeTrack(\.repeatedIn) {
            LinearKeyframe(0, duration: 3.3)
            SpringKeyframe(1, duration: 0.4)
            LinearKeyframe(1, duration: 2.3)
        }
        KeyframeTrack(\.reset) {
            LinearKeyframe(0, duration: 3.9)
            CubicKeyframe(1, duration: 0.5)
            LinearKeyframe(1, duration: 1.6)
        }
    }

    private func content(_ v: Values) -> some View {
        ZStack {
            card(label: "THIS WEEK") {
                row(icon: "1.circle") {
                    IllustrationCheck(check: v.oneTimeCheck)
                    Illustration.bar(width: 60, check: v.oneTimeCheck)
                }
                row(icon: "arrow.uturn.forward", iconColor: Illustration.pendingColor.opacity(v.pending)) {
                    IllustrationCheck(check: 0, pending: v.pending)
                    Illustration.bar(width: 70, pending: v.pending)
                }
                row(icon: "repeat") {
                    IllustrationCheck(check: v.repeatingCheck)
                    Illustration.bar(width: 50, check: v.repeatingCheck)
                }
            }
            .scaleEffect(1 - 0.12 * (1 - v.thisWeekFade))
            .offset(x: v.thisWeekX)
            .opacity(v.thisWeekFade)

            card(label: "NEXT WEEK") {
                row(icon: "arrow.uturn.forward", iconColor: Illustration.pendingColor) {
                    IllustrationCheck(check: 0, pending: 1)
                    Illustration.bar(width: 70, pending: 1)
                }
                .arriving(v.carriedIn)
                row(icon: "repeat", iconRotation: 360 * v.reset) {
                    IllustrationCheck(check: 1 - v.reset)
                    Illustration.bar(width: 50, check: 1 - v.reset)
                }
                .arriving(v.repeatedIn)
                Color.clear.frame(height: 16)
            }
            .offset(x: v.nextWeekX)
            .opacity(v.nextWeekFade)
        }
        .frame(width: 240, height: 160)
        .opacity(v.opacity)
        .accessibilityHidden(true)
    }

    private func card<Content: View>(label: String, @ViewBuilder rows: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Illustration.label(label)
            rows()
        }
        .padding(12)
        .frame(width: 150, alignment: .leading)
        .background(Illustration.cardBackground())
    }

    private func row<Content: View>(
        icon: String, iconColor: Color = .secondary, iconRotation: Double = 0,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 8) {
            content()
            Spacer(minLength: 0)
            ZStack {
                Illustration.icon(icon).foregroundStyle(.secondary)
                Illustration.icon(icon).foregroundStyle(iconColor)
            }
            .rotationEffect(.degrees(iconRotation))
        }
        .frame(height: 16)
    }
}

private extension View {
    /// Drops a row into place as `progress` goes from 0 to 1.
    func arriving(_ progress: Double) -> some View {
        offset(y: -8 * (1 - progress)).opacity(min(1, max(0, progress)))
    }
}

// MARK: - Category Cards Animation
//
// Tasks live in category cards: a card is tapped, opens to a full row while the
// others move down beneath it, and two of its tasks get checked off.

struct CategoryCardsAnimation: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            content(.finished)
        } else {
            KeyframeAnimator(initialValue: Values(), repeating: true) { values in
                content(values)
            } keyframes: { _ in
                Self.timeline
            }
        }
    }

    struct Values {
        var opacity = 0.0
        var tap = 0.0              // touch ripple, 0...1
        var press = 0.0
        var expand = 0.0
        var check1 = 0.0
        var check2 = 0.0

        static let finished = Values(opacity: 1, tap: 0, press: 0, expand: 1, check1: 1, check2: 1)
    }

    // One loop is 6 seconds. Every track sums to the same length so they stay aligned.
    @KeyframesBuilder<Values>
    static var timeline: some Keyframes<Values> {
        KeyframeTrack(\.opacity) {
            LinearKeyframe(1, duration: 0.3)
            LinearKeyframe(1, duration: 5.2)
            LinearKeyframe(0, duration: 0.4)
            LinearKeyframe(0, duration: 0.1)
        }
        KeyframeTrack(\.tap) {
            LinearKeyframe(0, duration: 0.7)
            LinearKeyframe(1, duration: 0.45)
            LinearKeyframe(0, duration: 0.01)
            LinearKeyframe(0, duration: 4.84)
        }
        KeyframeTrack(\.press) {
            LinearKeyframe(0, duration: 0.75)
            CubicKeyframe(1, duration: 0.12)
            SpringKeyframe(0, duration: 0.3)
            LinearKeyframe(0, duration: 4.83)
        }
        KeyframeTrack(\.expand) {
            LinearKeyframe(0, duration: 1.0)
            SpringKeyframe(1, duration: 0.6, spring: .snappy)
            LinearKeyframe(1, duration: 4.4)
        }
        KeyframeTrack(\.check1) {
            LinearKeyframe(0, duration: 2.2)
            SpringKeyframe(1, duration: 0.35, spring: .bouncy)
            LinearKeyframe(1, duration: 3.45)
        }
        KeyframeTrack(\.check2) {
            LinearKeyframe(0, duration: 2.65)
            SpringKeyframe(1, duration: 0.35, spring: .bouncy)
            LinearKeyframe(1, duration: 3.0)
        }
    }

    // Cards sit in two columns; the open card takes the whole top row.
    private enum Layout {
        static let columnWidth: CGFloat = 110
        static let fullWidth: CGFloat = 228
        static let columnX: CGFloat = 59
        static let closedHeight: CGFloat = 40
        static let openHeight: CGFloat = 106
        static let gap: CGFloat = 8
    }

    func content(_ v: Values) -> some View {
        let e = v.expand
        let growth = Layout.openHeight - Layout.closedHeight
        // Keep the grid centered as it grows.
        let top = -(Layout.closedHeight * 2 + Layout.gap) / 2 - growth / 2 * e
        let rowStep = Layout.closedHeight + Layout.gap
        let openHeight = Layout.closedHeight + growth * e

        return ZStack {
            // Work: top right, moves to the left of the second row.
            card(symbol: "briefcase", name: "Work", expand: 0)
                .frame(width: Layout.columnWidth, height: Layout.closedHeight)
                .offset(x: Layout.columnX * (1 - 2 * e),
                        y: top + Layout.closedHeight / 2 + (rowStep + growth) * e)
            // Fitness: second row left, moves right.
            card(symbol: "figure.run", name: "Fitness", expand: 0)
                .frame(width: Layout.columnWidth, height: Layout.closedHeight)
                .offset(x: -Layout.columnX * (1 - 2 * e),
                        y: top + rowStep + Layout.closedHeight / 2 + growth * e)
            // Errands: tapped, opens to the full row.
            card(symbol: "cart", name: "Errands", expand: e, check1: v.check1, check2: v.check2)
                .frame(width: Layout.columnWidth + (Layout.fullWidth - Layout.columnWidth) * e,
                       height: openHeight)
                .overlay { Illustration.ripple(v.tap) }
                .scaleEffect(1 - 0.05 * v.press)
                .offset(x: -Layout.columnX * (1 - e), y: top + openHeight / 2)
        }
        .frame(width: 240, height: 160)
        .opacity(v.opacity)
        .accessibilityHidden(true)
    }

    /// A card as in the app: its completion ring at the top right (filling as tasks are
    /// checked), and the open or close arrows at the bottom right.
    private func card(symbol: String, name: String, expand: Double,
                      check1: Double = 0, check2: Double = 0) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.blue)
                    .frame(width: 14)
                Text(verbatim: name).font(.system(size: 9.5, weight: .bold))
                Spacer(minLength: 0)
                IllustrationCheck(check: 0, progress: (check1 + check2) / 3, faint: true, size: 10)
            }
            .frame(height: 16)
            Group {
                taskRow(check: check1, width: 80)
                taskRow(check: check2, width: 62)
                taskRow(check: 0, width: 92)
            }
            .opacity(max(0, (expand - 0.4) / 0.6))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
        .overlay(alignment: .bottomTrailing) {
            ZStack {
                Image(systemName: "arrow.up.left.and.arrow.down.right").opacity(1 - expand)
                Image(systemName: "arrow.down.right.and.arrow.up.left").opacity(expand)
            }
            .font(.system(size: 6.5, weight: .semibold))
            .foregroundStyle(.tertiary)
            .padding(6)
        }
        .clipped()
        .background(Illustration.cardBackground())
    }

    private func taskRow(check: Double, width: CGFloat) -> some View {
        HStack(spacing: 8) {
            IllustrationCheck(check: check)
            Illustration.bar(width: width, check: check)
        }
        .padding(.leading, 2)
        .frame(height: 16)
    }
}

// MARK: - Calendar Events Animation
//
// The week's events, a tap away: the calendar button between the week arrows at the
// bottom is tapped, the calendar sheet rises with Events | Weeks at the top, and the
// week's events drop in by day. Then a swipe on the events pages to next week, the cards
// behind and the week at the top moving with it, and This Week appears to come back.

struct CalendarEventsAnimation: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            content(.finished)
        } else {
            KeyframeAnimator(initialValue: Values(), repeating: true) { values in
                content(values)
            } keyframes: { _ in
                Self.timeline
            }
        }
    }

    struct Values {
        var opacity = 0.0
        var tap = 0.0              // touch ripple on the calendar button, 0...1
        var open = 0.0             // the sheet rising
        var event1 = 0.0
        var event2 = 0.0
        var event3 = 0.0
        var touch = 0.0            // the finger on the events while it swipes
        var swipe = 0.0            // this week → next week

        static let finished = Values(opacity: 1, tap: 0, open: 1, event1: 1, event2: 1, event3: 1,
                                     touch: 0, swipe: 1)
    }

    // One loop is 6 seconds. Every track sums to the same length so they stay aligned.
    @KeyframesBuilder<Values>
    static var timeline: some Keyframes<Values> {
        KeyframeTrack(\.opacity) {
            LinearKeyframe(1, duration: 0.3)
            LinearKeyframe(1, duration: 5.2)
            LinearKeyframe(0, duration: 0.4)
            LinearKeyframe(0, duration: 0.1)
        }
        KeyframeTrack(\.tap) {
            LinearKeyframe(0, duration: 0.7)
            LinearKeyframe(1, duration: 0.45)
            LinearKeyframe(0, duration: 0.01)
            LinearKeyframe(0, duration: 4.84)
        }
        KeyframeTrack(\.open) {
            LinearKeyframe(0, duration: 0.95)
            SpringKeyframe(1, duration: 0.6, spring: .snappy)
            LinearKeyframe(1, duration: 4.45)
        }
        KeyframeTrack(\.event1) {
            LinearKeyframe(0, duration: 1.45)
            SpringKeyframe(1, duration: 0.4)
            LinearKeyframe(1, duration: 4.15)
        }
        KeyframeTrack(\.event2) {
            LinearKeyframe(0, duration: 1.7)
            SpringKeyframe(1, duration: 0.4)
            LinearKeyframe(1, duration: 3.9)
        }
        KeyframeTrack(\.event3) {
            LinearKeyframe(0, duration: 1.95)
            SpringKeyframe(1, duration: 0.4)
            LinearKeyframe(1, duration: 3.65)
        }
        // The finger lands, drags the events to the left, and lifts.
        KeyframeTrack(\.touch) {
            LinearKeyframe(0, duration: 2.8)
            LinearKeyframe(1, duration: 0.15)
            LinearKeyframe(1, duration: 0.65)
            LinearKeyframe(0, duration: 0.2)
            LinearKeyframe(0, duration: 2.2)
        }
        KeyframeTrack(\.swipe) {
            LinearKeyframe(0, duration: 3.0)
            CubicKeyframe(1, duration: 0.6)
            LinearKeyframe(1, duration: 2.4)
        }
    }

    private enum Layout {
        static let screenWidth: CGFloat = 200
        static let screenHeight: CGFloat = 156
        static let headerHeight: CGFloat = 34
        static let sheetHeight: CGFloat = 98
    }

    func content(_ v: Values) -> some View {
        let w = Layout.screenWidth
        return ZStack(alignment: .top) {
            // The week's cards, sliding to next week's with the swipe.
            ZStack(alignment: .top) {
                cards.offset(x: -w * v.swipe)
                cards.offset(x: w * (1 - v.swipe))
            }
            .padding(.top, Layout.headerHeight + 6)

            header(v)

            bottomButtons(v)
                .frame(maxHeight: .infinity, alignment: .bottom)

            // The sheet dims what's behind it.
            Color.black.opacity(0.2 * v.open)

            sheet(v)
                .offset(y: Layout.sheetHeight * (1 - v.open))
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .frame(width: w, height: Layout.screenHeight)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .background(Illustration.cardBackground())
        .frame(width: 240, height: 160)
        .opacity(v.opacity)
        .accessibilityHidden(true)
    }

    // MARK: The screen behind

    /// The frosted header: the Tasquel mark, the week, Open/Close All, and the week's days.
    private func header(_ v: Values) -> some View {
        VStack(spacing: 5) {
            HStack {
                Image("TasquelMark")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 10)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 6.5, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .overlay {
                ZStack {
                    Illustration.label("THIS WEEK").opacity(1 - v.swipe)
                    Illustration.label("NEXT WEEK").opacity(v.swipe)
                }
            }
            HStack(spacing: 3) {
                ForEach(0..<7, id: \.self) { dayPill($0, v) }
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 7)
        .frame(height: Layout.headerHeight, alignment: .top)
        .frame(maxWidth: .infinity)
        .background(Color(.tertiarySystemBackground).opacity(0.92))
        .overlay(alignment: .bottom) { Rectangle().fill(Color.primary.opacity(0.1)).frame(height: 0.5) }
    }

    /// This week: Monday and Tuesday done (green), today Wednesday (outlined, with room for
    /// its date), the rest to come. Next week: every day to come.
    private func dayPill(_ day: Int, _ v: Values) -> some View {
        let past = day < 2, today = day == 2
        let thisWeek = 1 - v.swipe
        return ZStack {
            Capsule().fill(Illustration.doneColor.opacity(0.2)).opacity(past ? thisWeek : 0)
            Capsule().stroke(Illustration.doneColor, lineWidth: 0.75).opacity(past ? thisWeek : 0)
            Capsule().stroke(Color.accentColor, lineWidth: 1).opacity(today ? thisWeek : 0)
            Capsule().stroke(Color.secondary.opacity(0.5), lineWidth: 0.75).opacity(past || today ? v.swipe : 1)
        }
        .frame(width: today ? 7 + 5 * thisWeek : 7, height: 4.5)
    }

    private var cards: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                miniCard(symbol: "cart", name: "Errands")
                miniCard(symbol: "briefcase", name: "Work")
            }
            HStack(spacing: 8) {
                miniCard(symbol: "figure.run", name: "Fitness")
                miniCard(symbol: "book", name: "Study")
            }
        }
        .padding(.horizontal, 10)
    }

    private func miniCard(symbol: String, name: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 8.5, weight: .semibold))
                .foregroundStyle(.blue)
                .frame(width: 12)
            Text(verbatim: name).font(.system(size: 8, weight: .bold))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .frame(height: 26)
        .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    /// Settings, the week selector (‹ calendar ›, green with events on) and Edit, each
    /// floating on its own glass.
    private func bottomButtons(_ v: Values) -> some View {
        HStack(spacing: 0) {
            Illustration.icon("gearshape")
                .foregroundStyle(.secondary)
                .frame(width: 20, height: 20)
                .background(glass(Circle()))
            Spacer(minLength: 0)
            HStack(spacing: 11) {
                Illustration.icon("chevron.left").foregroundStyle(.secondary)
                Image(systemName: "calendar.and.person")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.green)
                    .overlay { Illustration.ripple(v.tap) }
                Illustration.icon("chevron.right").foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .frame(height: 20)
            .background(glass(Capsule()))
            Spacer(minLength: 0)
            Text(verbatim: "Edit")
                .font(.system(size: 7, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .frame(height: 20)
                .background(glass(Capsule()))
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 9)
    }

    private func glass<S: Shape>(_ shape: S) -> some View {
        shape.fill(Color(.tertiarySystemBackground))
            .overlay(shape.stroke(Color.primary.opacity(0.08), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
    }

    // MARK: The calendar sheet

    private func sheet(_ v: Values) -> some View {
        let w = Layout.screenWidth
        return VStack(alignment: .leading, spacing: 4) {
            Capsule()
                .fill(Color.secondary.opacity(0.5))
                .frame(width: 22, height: 3)
                .frame(maxWidth: .infinity)
            // This Week (only on another week), Events | Weeks, Done.
            ZStack {
                HStack {
                    Text(verbatim: "This Week").foregroundStyle(Color.accentColor).opacity(v.swipe)
                    Spacer(minLength: 0)
                    Text(verbatim: "Done").foregroundStyle(Color.accentColor)
                }
                segments
            }
            .font(.system(size: 6.5, weight: .semibold))
            .frame(height: 14)
            ZStack(alignment: .topLeading) {
                eventsPage(v, next: false).offset(x: -w * v.swipe)
                eventsPage(v, next: true).offset(x: w * (1 - v.swipe))
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .overlay {
                // The finger dragging the events along.
                Circle()
                    .fill(Color.primary.opacity(0.15))
                    .frame(width: 18, height: 18)
                    .offset(x: 45 - 90 * v.swipe, y: 6)
                    .opacity(v.touch)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 5)
        .frame(width: w, height: Layout.sheetHeight, alignment: .top)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 14, topTrailingRadius: 14, style: .continuous)
                // Like a sheet: white in light, a raised gray in dark.
                .fill(Color(UIColor { $0.userInterfaceStyle == .dark ? .tertiarySystemBackground : .systemBackground }))
                .shadow(color: .black.opacity(0.15), radius: 6, y: -1)
        )
    }

    /// The sheet's Events | Weeks control, on Events.
    private var segments: some View {
        HStack(spacing: 0) {
            Text(verbatim: "Events")
                .padding(.horizontal, 8)
                .frame(height: 11)
                .background(
                    Capsule().fill(Color(UIColor { $0.userInterfaceStyle == .dark ? .systemGray3 : .systemBackground }))
                        .shadow(color: .black.opacity(0.12), radius: 1, y: 0.5)
                )
            Text(verbatim: "Weeks")
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
        }
        .padding(1.5)
        .background(Capsule().fill(Color.primary.opacity(0.08)))
    }

    @ViewBuilder
    private func eventsPage(_ v: Values, next: Bool) -> some View {
        // No title of its own: the week at the top says which week it is.
        VStack(alignment: .leading, spacing: 3) {
            if next {
                dayLabel("TUE")
                eventRow(color: .orange, titleWidth: 66)
                dayLabel("THU")
                eventRow(color: .blue, titleWidth: 52)
                eventRow(color: .purple, titleWidth: 80)
            } else {
                dayLabel("MON")
                eventRow(color: .blue, titleWidth: 74).arriving(v.event1)
                dayLabel("WED", isToday: true)
                eventRow(color: .orange, titleWidth: 58).arriving(v.event2)
                eventRow(color: .purple, titleWidth: 86).arriving(v.event3)
            }
        }
    }

    private func dayLabel(_ text: String, isToday: Bool = false) -> some View {
        Text(verbatim: text)
            .font(.system(size: 7, weight: .bold))
            .foregroundStyle(isToday ? Color.accentColor : .secondary)
            .frame(height: 8)
    }

    private func eventRow(color: Color, titleWidth: CGFloat) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 6, height: 6)
            RoundedRectangle(cornerRadius: 3).fill(Color.primary.opacity(0.14)).frame(width: 22, height: 5)
            Illustration.bar(width: titleWidth)
        }
        .frame(height: 12)
    }
}

#Preview("Task types") {
    TaskTypesAnimation()
}

#Preview("Task modes") {
    TaskModesAnimation()
}

#Preview("Category cards") {
    CategoryCardsAnimation()
}

#Preview("Calendar events") {
    CalendarEventsAnimation()
}
