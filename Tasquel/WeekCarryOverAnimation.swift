import SwiftUI

// MARK: - Week Carry-Over Animation
//
// Welcome illustration: two tasks get checked off, the third is left unfinished,
// the week slides away beneath it, and it lands in next week's card and gets done.
// The unfinished task never moves sideways — the weeks change under it.

struct WeekCarryOverAnimation: View {
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

    // MARK: Animated values

    struct Values {
        var opacity = 0.0
        var check1 = 0.0
        var check2 = 0.0
        var pending = 0.0          // unfinished task turns orange + shows carry-over arrow
        var thisWeekX = 0.0
        var thisWeekFade = 1.0
        var nextWeekX = 70.0
        var nextWeekFade = 0.0
        var carriedY = Layout.rowCenterY(2)
        var lift = 0.0             // carried task floats above the cards
        var carriedCheck = 0.0
        var glow = 0.0

        static let finished = Values(
            opacity: 1, check1: 1, check2: 1, pending: 1,
            thisWeekX: -80, thisWeekFade: 0, nextWeekX: 0, nextWeekFade: 1,
            carriedY: Layout.rowCenterY(0), lift: 0, carriedCheck: 1, glow: 0.4
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
        // This week: two tasks get done, the third is left.
        KeyframeTrack(\.check1) {
            LinearKeyframe(0, duration: 0.6)
            SpringKeyframe(1, duration: 0.35, spring: .bouncy)
            LinearKeyframe(1, duration: 5.05)
        }
        KeyframeTrack(\.check2) {
            LinearKeyframe(0, duration: 1.15)
            SpringKeyframe(1, duration: 0.35, spring: .bouncy)
            LinearKeyframe(1, duration: 4.5)
        }
        KeyframeTrack(\.pending) {
            LinearKeyframe(0, duration: 1.8)
            CubicKeyframe(1, duration: 0.35)
            LinearKeyframe(1, duration: 3.85)
        }
        // The task lifts, the weeks swap beneath it, and it settles into next week.
        KeyframeTrack(\.lift) {
            LinearKeyframe(0, duration: 2.4)
            CubicKeyframe(1, duration: 0.25)
            LinearKeyframe(1, duration: 0.65)
            SpringKeyframe(0, duration: 0.35)
            LinearKeyframe(0, duration: 2.35)
        }
        KeyframeTrack(\.thisWeekX) {
            LinearKeyframe(0, duration: 2.6)
            CubicKeyframe(-80, duration: 0.6)
            LinearKeyframe(-80, duration: 2.8)
        }
        KeyframeTrack(\.thisWeekFade) {
            LinearKeyframe(1, duration: 2.6)
            CubicKeyframe(0, duration: 0.5)
            LinearKeyframe(0, duration: 2.9)
        }
        KeyframeTrack(\.nextWeekX) {
            LinearKeyframe(70, duration: 2.75)
            SpringKeyframe(0, duration: 0.6)
            LinearKeyframe(0, duration: 2.65)
        }
        KeyframeTrack(\.nextWeekFade) {
            LinearKeyframe(0, duration: 2.75)
            CubicKeyframe(1, duration: 0.4)
            LinearKeyframe(1, duration: 2.85)
        }
        KeyframeTrack(\.carriedY) {
            LinearKeyframe(Layout.rowCenterY(2), duration: 2.55)
            SpringKeyframe(Layout.rowCenterY(0), duration: 0.8)
            LinearKeyframe(Layout.rowCenterY(0), duration: 2.65)
        }
        // Next week: the carried task gets done.
        KeyframeTrack(\.carriedCheck) {
            LinearKeyframe(0, duration: 4.0)
            SpringKeyframe(1, duration: 0.35, spring: .bouncy)
            LinearKeyframe(1, duration: 1.65)
        }
        KeyframeTrack(\.glow) {
            LinearKeyframe(0, duration: 4.1)
            CubicKeyframe(1, duration: 0.3)
            CubicKeyframe(0.4, duration: 0.5)
            LinearKeyframe(0.4, duration: 1.1)
        }
    }

    // MARK: Drawing

    private enum Layout {
        static let cardWidth: CGFloat = 132
        static let padding: CGFloat = 12
        static let labelHeight: CGFloat = 10
        static let rowHeight: CGFloat = 16
        static let rowSpacing: CGFloat = 9
        static let cardHeight = padding * 2 + labelHeight + 3 * (rowSpacing + rowHeight)
        static let rowWidth = cardWidth - padding * 2

        /// Vertical center of row `index`, relative to the card's center.
        static func rowCenterY(_ index: Int) -> Double {
            Double(padding + labelHeight + rowSpacing + rowHeight / 2
                   + CGFloat(index) * (rowHeight + rowSpacing) - cardHeight / 2)
        }
    }

    private static let pendingColor = Color(hue: 0.07, saturation: 0.7, brightness: 0.85)
    private static let doneColor = Color(hue: 0.33, saturation: 0.7, brightness: 0.75)

    private func content(_ v: Values) -> some View {
        ZStack {
            Circle()
                .fill(Self.doneColor.opacity(0.2))
                .frame(width: 150, height: 150)
                .blur(radius: 18)
                .opacity(v.glow)

            card(label: "THIS WEEK", rows: [
                AnyView(taskRow(check: v.check1, barWidth: 64)),
                AnyView(taskRow(check: v.check2, barWidth: 48)),
                AnyView(Color.clear),
            ])
            .scaleEffect(1 - 0.12 * (1 - v.thisWeekFade))
            .offset(x: v.thisWeekX)
            .opacity(v.thisWeekFade)

            card(label: "NEXT WEEK", rows: [
                AnyView(Color.clear),
                AnyView(taskRow(check: 0, barWidth: 60, faint: true)),
                AnyView(taskRow(check: 0, barWidth: 46, faint: true)),
            ])
            .offset(x: v.nextWeekX)
            .opacity(v.nextWeekFade)

            carriedRow(v)
                .frame(width: Layout.rowWidth, height: Layout.rowHeight, alignment: .leading)
                .padding(.horizontal, 8 * v.lift)
                .padding(.vertical, 5 * v.lift)
                .background {
                    Capsule()
                        .fill(Color(.secondarySystemBackground))
                        .shadow(color: Self.pendingColor.opacity(0.4), radius: 8, y: 3)
                        .opacity(v.lift)
                }
                .scaleEffect(1 + 0.06 * v.lift)
                .rotationEffect(.degrees(-3 * v.lift))
                .offset(y: v.carriedY)
        }
        .frame(width: 240, height: 160)
        .opacity(v.opacity)
        .accessibilityHidden(true)
    }

    private func card(label: String, rows: [AnyView]) -> some View {
        VStack(alignment: .leading, spacing: Layout.rowSpacing) {
            Text(label)
                .font(.system(size: 8.5, weight: .bold))
                .kerning(0.6)
                .foregroundStyle(.secondary)
                .frame(height: Layout.labelHeight)
            ForEach(rows.indices, id: \.self) { index in
                rows[index].frame(height: Layout.rowHeight)
            }
        }
        .padding(Layout.padding)
        .frame(width: Layout.cardWidth, height: Layout.cardHeight, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: .black.opacity(0.1), radius: 6, y: 2)
        )
    }

    private func taskRow(check: Double, barWidth: CGFloat, faint: Bool = false) -> some View {
        HStack(spacing: 8) {
            checkCircle(check: check, faint: faint)
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.primary.opacity(faint ? 0.08 : 0.22 - 0.12 * check))
                .frame(width: barWidth, height: 6)
        }
    }

    private func carriedRow(_ v: Values) -> some View {
        HStack(spacing: 8) {
            checkCircle(check: v.carriedCheck, pending: v.pending)
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3).fill(Color.primary.opacity(0.22)).opacity(1 - v.pending)
                RoundedRectangle(cornerRadius: 3).fill(Self.pendingColor.opacity(0.45))
                    .opacity(v.pending * max(0, 1 - v.carriedCheck))
                RoundedRectangle(cornerRadius: 3).fill(Self.doneColor.opacity(0.4)).opacity(v.carriedCheck)
            }
            .frame(width: 72, height: 6)
            ZStack {
                Image(systemName: "arrow.uturn.forward").foregroundStyle(Self.pendingColor)
                Image(systemName: "arrow.uturn.forward").foregroundStyle(Self.doneColor).opacity(v.carriedCheck)
            }
            .font(.system(size: 8, weight: .bold))
            .opacity(v.pending)
            .scaleEffect(0.6 + 0.4 * v.pending)
        }
    }

    /// `pending` cross-fades the gray ring to a thicker orange one.
    private func checkCircle(check: Double, pending: Double = 0, faint: Bool = false) -> some View {
        ZStack {
            // Rings fade as the green fill grows so no outline shows around a finished check.
            let ringOpacity = max(0, 1 - check)
            Circle().stroke(Color.secondary.opacity(faint ? 0.35 : 0.6), lineWidth: 1.5)
                .opacity((1 - pending) * ringOpacity)
            Circle().stroke(Self.pendingColor, lineWidth: 2).opacity(pending * ringOpacity)
            Circle().fill(Self.doneColor).scaleEffect(check)
            Image(systemName: "checkmark")
                .font(.system(size: 8, weight: .heavy))
                .foregroundStyle(.white)
                .scaleEffect(check)
        }
        .frame(width: 15, height: 15)
    }
}

#Preview("Week carry-over") {
    WeekCarryOverAnimation()
}
