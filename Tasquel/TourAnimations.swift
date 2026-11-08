import SwiftUI

// Animations for the extra Welcome Tour pages (Settings ▸ Show Welcome Tour): features
// added after the first-launch onboarding. Built from the same `Illustration` parts,
// each a 6-second loop with a still frame for Reduce Motion.

// MARK: - Smart Add Animation
//
// "gym 3x per week" is typed, the sparkles button is tapped, and the words become a
// repeating goal of 3, with the "Added … · Undo" note under it.

struct SmartAddAnimation: View {
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
        var typed = 0.0      // how much of the words is typed, 0...1
        var tap = 0.0        // the sparkles tap
        var added = 0.0      // the new goal row
        var note = 0.0       // "Added … · Undo"

        static let finished = Values(opacity: 1, typed: 0, tap: 1, added: 1, note: 1)
    }

    static let words = "gym 3x per week"

    @KeyframesBuilder<Values>
    static var timeline: some Keyframes<Values> {
        KeyframeTrack(\.opacity) {
            LinearKeyframe(1, duration: 0.3)
            LinearKeyframe(1, duration: 5.2)
            LinearKeyframe(0, duration: 0.4)
            LinearKeyframe(0, duration: 0.1)
        }
        KeyframeTrack(\.typed) {
            LinearKeyframe(0, duration: 0.4)
            LinearKeyframe(1, duration: 1.4)
            LinearKeyframe(1, duration: 0.7)
            LinearKeyframe(0, duration: 0.05)
            LinearKeyframe(0, duration: 3.45)
        }
        KeyframeTrack(\.tap) {
            LinearKeyframe(0, duration: 2.1)
            LinearKeyframe(1, duration: 0.45)
            LinearKeyframe(1, duration: 3.45)
        }
        KeyframeTrack(\.added) {
            LinearKeyframe(0, duration: 2.5)
            SpringKeyframe(1, duration: 0.4, spring: .bouncy)
            LinearKeyframe(1, duration: 3.1)
        }
        KeyframeTrack(\.note) {
            LinearKeyframe(0, duration: 2.8)
            LinearKeyframe(1, duration: 0.3)
            LinearKeyframe(1, duration: 2.9)
        }
    }

    func content(_ v: Values) -> some View {
        let shown = String(Self.words.prefix(Int((Double(Self.words.count) * v.typed).rounded())))
        return VStack(alignment: .leading, spacing: 7) {
            Illustration.label("FITNESS")
            row {
                IllustrationCheck(check: 1)
                Illustration.bar(width: 58, check: 1)
            }
            // The goal Smart Add made, and the note under it (their room opens together,
            // as in the app).
            VStack(alignment: .leading, spacing: 0) {
                row {
                    IllustrationCheck(check: 0, progress: 0)
                    Text(verbatim: "Gym").font(.system(size: 8.5, weight: .semibold))
                    Text(verbatim: "0/3").font(.system(size: 7.5, weight: .semibold).monospacedDigit()).foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Illustration.icon("target").foregroundStyle(.secondary)
                    Illustration.icon("repeat").foregroundStyle(Illustration.doneColor)
                }
                .opacity(v.added)
                .scaleEffect(0.9 + 0.1 * v.added, anchor: .leading)
                .frame(height: 16 * v.added, alignment: .top)
                HStack(spacing: 4) {
                    Image(systemName: "sparkles").foregroundStyle(Color.accentColor)
                    Text(verbatim: "Added Gym · repeating goal of 3").foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Text(verbatim: "Undo").fontWeight(.semibold).foregroundStyle(Color.accentColor)
                }
                .font(.system(size: 7))
                .opacity(v.note)
                .frame(height: 10 * v.added, alignment: .top)
                .padding(.top, 5 * v.added)
            }
            .clipped()
            // The add-task row: the words being typed, and the sparkles button.
            HStack(spacing: 6) {
                Image(systemName: "plus.circle").font(.system(size: 9)).foregroundStyle(.secondary)
                HStack(spacing: 1) {
                    Text(verbatim: shown.isEmpty ? " " : shown).font(.system(size: 8.5))
                    RoundedRectangle(cornerRadius: 0.5).fill(Color.accentColor).frame(width: 1, height: 9)
                        .opacity(v.typed > 0 && v.typed < 1 ? 1 : 0.4)
                }
                .padding(.horizontal, 5)
                .frame(maxWidth: .infinity, minHeight: 15, alignment: .leading)
                .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 4))
                Image(systemName: "sparkles").font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 5).padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.15), in: Capsule())
                    .overlay(Capsule().stroke(Color.accentColor.opacity(0.4), lineWidth: 0.75))
                    .overlay { Illustration.ripple(v.tap) }
            }
            .frame(height: 16)
        }
        .padding(12)
        .frame(width: 196, alignment: .leading)
        .background(Illustration.cardBackground())
        .frame(width: 240, height: 160)
        .opacity(v.opacity)
        .accessibilityHidden(true)
    }

    private func row<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 8) { content() }.frame(height: 16)
    }
}

// MARK: - Tidy Up Animation
//
// A task is deleted and taken back with Undo; then the card is pulled down and let go,
// and it closes.

struct TidyUpAnimation: View {
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
        var trashTap = 0.0
        var deleted = 0.0    // the middle task gone
        var toast = 0.0      // "Deleted · Undo"
        var undoTap = 0.0
        var pull = 0.0       // pulled down past the top
        var closed = 0.0

        static let finished = Values(opacity: 1, trashTap: 1, deleted: 0, toast: 0, undoTap: 1, pull: 0, closed: 1)
    }

    @KeyframesBuilder<Values>
    static var timeline: some Keyframes<Values> {
        KeyframeTrack(\.opacity) {
            LinearKeyframe(1, duration: 0.3)
            LinearKeyframe(1, duration: 5.2)
            LinearKeyframe(0, duration: 0.4)
            LinearKeyframe(0, duration: 0.1)
        }
        KeyframeTrack(\.trashTap) {
            LinearKeyframe(0, duration: 0.6)
            LinearKeyframe(1, duration: 0.4)
            LinearKeyframe(1, duration: 5.0)
        }
        KeyframeTrack(\.deleted) {
            LinearKeyframe(0, duration: 0.85)
            CubicKeyframe(1, duration: 0.3)
            LinearKeyframe(1, duration: 1.1)
            SpringKeyframe(0, duration: 0.35, spring: .bouncy)
            LinearKeyframe(0, duration: 3.4)
        }
        KeyframeTrack(\.toast) {
            LinearKeyframe(0, duration: 1.1)
            CubicKeyframe(1, duration: 0.3)
            LinearKeyframe(1, duration: 0.9)
            CubicKeyframe(0, duration: 0.3)
            LinearKeyframe(0, duration: 3.4)
        }
        KeyframeTrack(\.undoTap) {
            LinearKeyframe(0, duration: 1.8)
            LinearKeyframe(1, duration: 0.45)
            LinearKeyframe(1, duration: 3.75)
        }
        KeyframeTrack(\.pull) {
            LinearKeyframe(0, duration: 2.9)
            CubicKeyframe(1, duration: 0.8)
            LinearKeyframe(1, duration: 0.25)
            SpringKeyframe(0, duration: 0.4, spring: .snappy)
            LinearKeyframe(0, duration: 1.65)
        }
        KeyframeTrack(\.closed) {
            LinearKeyframe(0, duration: 3.95)
            SpringKeyframe(1, duration: 0.5, spring: .smooth)
            LinearKeyframe(1, duration: 1.55)
        }
    }

    func content(_ v: Values) -> some View {
        let open = 1 - v.closed
        return ZStack(alignment: .top) {
            // What letting go will do, in the gap the pull opens.
            Label("Release to close all", systemImage: "arrow.down.right.and.arrow.up.left")
                .font(.system(size: 7.5, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .opacity(v.pull)
                .padding(.top, 4)

            HStack(alignment: .top, spacing: 8 * v.closed) {
            VStack(alignment: .leading, spacing: 7 * open) {
                HStack {
                    Illustration.label("ERRANDS")
                    Spacer(minLength: 0)
                    IllustrationCheck(check: 0, faint: true, size: 11)
                }
                VStack(alignment: .leading, spacing: 7) {
                    taskRow(width: 62, check: 1)
                    taskRow(width: 48, check: 0)
                        .overlay(alignment: .trailing) { Illustration.ripple(v.trashTap).offset(x: 10) }
                        .opacity(1 - v.deleted)
                        .frame(height: 16 * (1 - v.deleted), alignment: .top)
                        .clipped()
                    taskRow(width: 54, check: 0)
                }
                .opacity(open)
                .frame(height: (16 * 3 + 14 - 16 * v.deleted) * open, alignment: .top)
                .clipped()
            }
            .padding(12)
            .frame(width: 196 - 84 * v.closed, alignment: .leading)
            .background(Illustration.cardBackground())
                // The grid's other closed card, beside it once everything has closed.
                HStack {
                    Illustration.label("WORK")
                    Spacer(minLength: 0)
                    IllustrationCheck(check: 0, faint: true, size: 11)
                }
                .padding(12)
                .frame(width: 104 * v.closed, alignment: .leading)
                .background(Illustration.cardBackground())
                .opacity(v.closed)
            }
            .offset(y: 22 + 26 * v.pull)

            // "Deleted · Undo", above the bottom bar.
            HStack(spacing: 6) {
                Image(systemName: "trash").foregroundStyle(.secondary)
                Text(verbatim: "Deleted “Milk”").foregroundStyle(.primary)
                Spacer(minLength: 0)
                Text(verbatim: "Undo").fontWeight(.semibold).foregroundStyle(Color.accentColor)
                    .overlay { Illustration.ripple(v.undoTap) }
            }
            .font(.system(size: 7.5))
            .padding(.horizontal, 10).padding(.vertical, 6)
            .frame(width: 170)
            .background(Capsule().fill(Color(.tertiarySystemBackground)).shadow(color: .black.opacity(0.15), radius: 4, y: 1))
            .opacity(v.toast)
            .offset(y: 130 + 10 * (1 - v.toast))
        }
        .frame(width: 240, height: 160, alignment: .top)
        .opacity(v.opacity)
        .accessibilityHidden(true)
    }

    private func taskRow(width: CGFloat, check: Double) -> some View {
        HStack(spacing: 8) {
            IllustrationCheck(check: check)
            Illustration.bar(width: width, check: check)
            Spacer(minLength: 0)
            Illustration.icon("trash").foregroundStyle(.red.opacity(0.8))
        }
        .frame(height: 16)
    }
}

// MARK: - Goal Steps Animation
//
// A goal of 100 push-ups with a step of 20: + is tapped (40 → 60 → 80), − takes one
// back, then + twice reaches 100 and the goal checks itself off.

struct GoalStepsAnimation: View {
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
        var progress = 0.4   // of the target, 0...1
        var plusTap = 0.0
        var minusTap = 0.0
        var check = 0.0
        var glow = 0.0

        static let finished = Values(opacity: 1, progress: 1, plusTap: 1, minusTap: 1, check: 1, glow: 0.4)
    }

    @KeyframesBuilder<Values>
    static var timeline: some Keyframes<Values> {
        KeyframeTrack(\.opacity) {
            LinearKeyframe(1, duration: 0.3)
            LinearKeyframe(1, duration: 5.2)
            LinearKeyframe(0, duration: 0.4)
            LinearKeyframe(0, duration: 0.1)
        }
        // + at 0.6 and 1.4, − at 2.2, + at 3.0 and 3.7.
        KeyframeTrack(\.plusTap) {
            LinearKeyframe(0, duration: 0.6)
            LinearKeyframe(1, duration: 0.4)
            LinearKeyframe(0, duration: 0.01)
            LinearKeyframe(0, duration: 0.39)
            LinearKeyframe(1, duration: 0.4)
            LinearKeyframe(1, duration: 1.2)
            LinearKeyframe(0, duration: 0.01)
            LinearKeyframe(1, duration: 0.39)
            LinearKeyframe(0, duration: 0.01)
            LinearKeyframe(0, duration: 0.3)
            LinearKeyframe(1, duration: 0.39)
            LinearKeyframe(1, duration: 1.9)
        }
        KeyframeTrack(\.minusTap) {
            LinearKeyframe(0, duration: 2.2)
            LinearKeyframe(1, duration: 0.4)
            LinearKeyframe(1, duration: 3.4)
        }
        KeyframeTrack(\.progress) {
            LinearKeyframe(0.4, duration: 0.7)
            SpringKeyframe(0.6, duration: 0.3, spring: .snappy)
            LinearKeyframe(0.6, duration: 0.5)
            SpringKeyframe(0.8, duration: 0.3, spring: .snappy)
            LinearKeyframe(0.8, duration: 0.5)
            SpringKeyframe(0.6, duration: 0.3, spring: .snappy)
            LinearKeyframe(0.6, duration: 0.5)
            SpringKeyframe(0.8, duration: 0.3, spring: .snappy)
            LinearKeyframe(0.8, duration: 0.4)
            SpringKeyframe(1.0, duration: 0.3, spring: .snappy)
            LinearKeyframe(1.0, duration: 1.9)
        }
        KeyframeTrack(\.check) {
            LinearKeyframe(0, duration: 4.1)
            SpringKeyframe(1, duration: 0.35, spring: .bouncy)
            LinearKeyframe(1, duration: 1.55)
        }
        KeyframeTrack(\.glow) {
            LinearKeyframe(0, duration: 4.2)
            CubicKeyframe(1, duration: 0.3)
            CubicKeyframe(0.4, duration: 0.5)
            LinearKeyframe(0.4, duration: 1.0)
        }
    }

    func content(_ v: Values) -> some View {
        let amount = Int((v.progress * 100 / 20).rounded()) * 20
        return ZStack {
            Circle()
                .fill(Illustration.doneColor.opacity(0.2))
                .frame(width: 170, height: 170)
                .blur(radius: 18)
                .opacity(v.glow)

            VStack(alignment: .leading, spacing: 8) {
                Illustration.label("FITNESS")
                HStack(spacing: 8) {
                    IllustrationCheck(check: v.check, progress: v.progress)
                    Text(verbatim: "Push-ups").font(.system(size: 8.5, weight: .semibold))
                    Spacer(minLength: 0)
                    Illustration.icon("target").foregroundStyle(.secondary)
                }
                .frame(height: 16)
                // The goal's sliders, the bar and the amount; the steps centered under the bar.
                HStack(spacing: 6) {
                    Image(systemName: "slider.horizontal.3").font(.system(size: 7, weight: .medium)).foregroundStyle(.secondary)
                    VStack(spacing: 5) {
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.primary.opacity(0.12))
                            Capsule().fill(v.check > 0.5 ? Illustration.doneColor : Color.accentColor)
                                .frame(width: Self.barWidth * v.progress)
                        }
                        .frame(width: Self.barWidth, height: 6)
                        HStack(spacing: 3) {
                            pill("−", filled: false).overlay { Illustration.ripple(v.minusTap) }
                            // Still there at the target: a goal can be beaten.
                            pill("+20", filled: true).overlay { Illustration.ripple(v.plusTap) }
                        }
                    }
                    .alignmentGuide(VerticalAlignment.center) { $0[.top] + 3 }
                    Text(verbatim: "\(amount)/100").font(.system(size: 7.5, weight: .bold).monospacedDigit())
                    Text(verbatim: "push-ups").font(.system(size: 7)).foregroundStyle(.secondary)
                }
                .lineLimit(1)
                .fixedSize()
                .padding(.leading, 23)
                HStack(spacing: 4) {
                    Text(verbatim: "Step").foregroundStyle(.secondary)
                    Text(verbatim: "20").padding(.horizontal, 4).padding(.vertical, 1)
                        .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 3))
                    Text(verbatim: "set with").foregroundStyle(.secondary)
                    Image(systemName: "slider.horizontal.3").foregroundStyle(.secondary)
                }
                .font(.system(size: 7))
                .padding(.leading, 23)
            }
            .padding(12)
            .frame(width: 196, alignment: .leading)
            .background(Illustration.cardBackground())
        }
        .frame(width: 240, height: 160)
        .opacity(v.opacity)
        .accessibilityHidden(true)
    }

    private static let barWidth: CGFloat = 62

    private func pill(_ title: String, filled: Bool) -> some View {
        Text(verbatim: title)
            .font(.system(size: 7.5, weight: .bold))
            .lineLimit(1)
            .fixedSize()
            .frame(minWidth: 8)
            .padding(.horizontal, 6).padding(.vertical, 3)
            .foregroundStyle(filled ? Color.white : Color.accentColor)
            .background { if filled { Capsule().fill(Color.accentColor) } }
            .overlay { if !filled { Capsule().stroke(Color.accentColor.opacity(0.6), lineWidth: 0.75) } }
    }
}

#Preview("Smart Add") {
    SmartAddAnimation()
}

#Preview("Tidy up") {
    TidyUpAnimation()
}

#Preview("Goal steps") {
    GoalStepsAnimation()
}
