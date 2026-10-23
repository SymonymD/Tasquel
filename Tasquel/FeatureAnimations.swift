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

    private func content(_ v: Values) -> some View {
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
                Image(systemName: "chevron.down")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(-90 * (1 - expand)))
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
// The week's calendar events beside your tasks: the calendar button in the bottom bar
// is tapped, the bar grows into the events panel, and the events drop in by day.

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
        var tap = 0.0              // touch ripple, 0...1
        var open = 0.0
        var event1 = 0.0
        var event2 = 0.0
        var event3 = 0.0

        static let finished = Values(opacity: 1, tap: 0, open: 1, event1: 1, event2: 1, event3: 1)
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
    }

    private enum Layout {
        static let screenWidth: CGFloat = 200
        static let screenHeight: CGFloat = 156
        static let barHeight: CGFloat = 30
        static let panelHeight: CGFloat = 102
    }

    private func content(_ v: Values) -> some View {
        ZStack(alignment: .bottom) {
            // The app behind the bar: a few closed category cards.
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
            .padding(10)
            .frame(maxHeight: .infinity, alignment: .top)

            VStack(spacing: 0) {
                Rectangle().fill(Color.primary.opacity(0.12)).frame(height: 0.5)
                panel(v)
                    .frame(height: Layout.panelHeight * max(0, v.open), alignment: .top)
                    .clipped()
                bottomBar(v)
            }
            .background(Color(.tertiarySystemBackground))
        }
        .frame(width: Layout.screenWidth, height: Layout.screenHeight)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .background(Illustration.cardBackground())
        .frame(width: 240, height: 160)
        .opacity(v.opacity)
        .accessibilityHidden(true)
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

    private func bottomBar(_ v: Values) -> some View {
        HStack(spacing: 0) {
            Illustration.icon("gearshape").foregroundStyle(.secondary)
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                ZStack {
                    Image(systemName: "calendar").foregroundStyle(.secondary).opacity(1 - v.open)
                    Image(systemName: "calendar.circle.fill").foregroundStyle(.blue).opacity(v.open)
                }
                .font(.system(size: 11, weight: .semibold))
                .overlay { Illustration.ripple(v.tap) }
                Illustration.bar(width: 52)
            }
            Spacer(minLength: 0)
            Illustration.icon("square.grid.2x2").foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .frame(height: Layout.barHeight)
    }

    private func panel(_ v: Values) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Capsule()
                .fill(Color.secondary.opacity(0.5))
                .frame(width: 24, height: 3)
                .frame(maxWidth: .infinity)
            Illustration.label("THIS WEEK'S EVENTS")
            dayLabel("MON")
            eventRow(color: .blue, titleWidth: 74).arriving(v.event1)
            dayLabel("WED")
            eventRow(color: .orange, titleWidth: 58).arriving(v.event2)
            eventRow(color: .purple, titleWidth: 86).arriving(v.event3)
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .opacity(min(1, max(0, v.open * 1.5)))
    }

    private func dayLabel(_ text: String) -> some View {
        Text(verbatim: text)
            .font(.system(size: 7, weight: .bold))
            .foregroundStyle(.secondary)
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
