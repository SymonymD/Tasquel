import SwiftUI

/// Thanksgiving: the day for a region (Canada's second Monday of October; elsewhere the US's
/// fourth Thursday of November), and whether today is in its week (by the week-start setting).
enum Thanksgiving {
    static func day(in year: Int, region: String?) -> DayKey {
        let (month, weekday, nth) = region == "CA" ? (10, 2, 2) : (11, 5, 4)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let first = calendar.date(from: DateComponents(year: year, month: month, day: 1))!
        let firstWeekday = calendar.component(.weekday, from: first)
        let firstMatch = 1 + (weekday - firstWeekday + 7) % 7
        return DayKey(year: year, month: month, day: firstMatch + 7 * (nth - 1))
    }

    static func isWeek(of today: DayKey, firstWeekday: Int, calendar: Calendar, region: String?) -> Bool {
        let weekStart = { (day: DayKey) in
            DayKey(Week.startOfWeek(containing: day.date(in: calendar), firstWeekday: firstWeekday, calendar: calendar), in: calendar)
        }
        return weekStart(today) == weekStart(day(in: today.year, region: region))
    }
}

/// A very small turkey that, in Thanksgiving week, sneaks out from behind the Tasquel mark,
/// turns to face you, screams a little, and runs back behind it (the user's idea, 2026-11-14).
/// Once each time the app is opened that week (launched, or back from a real trip away: not
/// Notification Center or Control Center), a moment after; never on a loop (the user's ask).
/// `-demoTurkey` (Debug) makes any day Thanksgiving week for it. Not with Reduce Motion;
/// never seen by VoiceOver or in the way of a tap.
///
/// Drawn by `TurkeyDrawing` from the time since it started, so the whole run is one smooth
/// timeline (no chained animations). It lives in a strip that starts at the mark: the mark
/// is drawn over it, and it's shown only right of the mark's ring, so it comes from behind.
struct TurkeyCameo: View {
    let retro: Bool
    let tint: Color
    /// Where the mark's ring ends, from the strip's leading edge: the turkey shows past it.
    let markEdge: CGFloat
    /// The mark's middle, where the turkey hides, and how far out it comes.
    let hideX: CGFloat
    let outX: CGFloat

    @Environment(\.scenePhase) private var scenePhase
    @State private var startedAt: Date?
    /// Counts the app's openings; each one brings the turkey out once.
    @State private var opens = 0
    /// Away (in the background) since it was last active; true at launch, which counts.
    @State private var wasAway = true

    var body: some View {
        ZStack {
            // A timeline of its own for each run: a paused one took most of a second to get
            // going again, and the turkey was first seen already out.
            if let startedAt {
                TimelineView(.animation) { timeline in
                    Canvas { context, size in
                        let t = timeline.date.timeIntervalSince(startedAt)
                        guard t >= 0, t <= TurkeyDrawing.duration else { return }
                        TurkeyDrawing(t: t, retro: retro, tint: tint, hideX: hideX, outX: outX).draw(in: &context, size: size)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .mask(alignment: .leading) {
            HStack(spacing: 0) {
                Color.clear.frame(width: markEdge)
                Rectangle()
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: scenePhase, initial: true) { _, phase in
            switch phase {
            case .background: wasAway = true
            case .active where wasAway:
                wasAway = false
                opens += 1
            default: break
            }
        }
        .task(id: opens) {
            guard opens > 0 else { return }
            // A moment after the screen is up, so it's seen.
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled, scenePhase == .active else { return }
            await run()
        }
    }

    private func run() async {
        startedAt = .now
        try? await Task.sleep(for: .seconds(TurkeyDrawing.duration + 0.1))
        startedAt = nil
    }
}

/// The turkey at a moment of its run, `t` seconds in:
/// - 0–0.95: sneaks out facing right, in two tiptoe steps with a pause between;
/// - 0.95–1.15: stops and bobs its head;
/// - 1.15–1.33: turns to face you;
/// - 1.4–2.0: screams ("AAH!"), shaking, tail puffed, beak open;
/// - 2.0–2.16: turns to face left;
/// - 2.16–2.5: runs back behind the mark.
struct TurkeyDrawing {
    static let duration: Double = 2.5

    let t: Double
    let retro: Bool
    let tint: Color
    let hideX: CGFloat
    let outX: CGFloat

    // Colors: a brown turkey with an orange, red and gold tail; Retro's in its one color.
    private var body: Color { retro ? tint : Color(red: 0.48, green: 0.29, blue: 0.15) }
    private var wing: Color { retro ? tint.opacity(0.55) : Color(red: 0.36, green: 0.22, blue: 0.11) }
    private var head: Color { retro ? tint : Color(red: 0.85, green: 0.70, blue: 0.55) }
    private var beak: Color { retro ? tint : Color(red: 0.95, green: 0.64, blue: 0.23) }
    private var wattle: Color { retro ? tint : Color(red: 0.84, green: 0.15, blue: 0.24) }
    private var legs: Color { retro ? tint.opacity(0.8) : Color(red: 0.93, green: 0.58, blue: 0.20) }
    private var eye: Color { retro ? .black : Color(red: 0.1, green: 0.07, blue: 0.05) }
    private var feathers: [Color] {
        retro ? [tint.opacity(0.5), tint.opacity(0.8), tint.opacity(0.5), tint.opacity(0.8), tint.opacity(0.5), tint.opacity(0.8), tint.opacity(0.5)]
            : [Color(red: 0.55, green: 0.27, blue: 0.10), Color(red: 0.86, green: 0.45, blue: 0.13), Color(red: 0.62, green: 0.16, blue: 0.12),
               Color(red: 0.90, green: 0.68, blue: 0.22), Color(red: 0.62, green: 0.16, blue: 0.12), Color(red: 0.86, green: 0.45, blue: 0.13),
               Color(red: 0.55, green: 0.27, blue: 0.10)]
    }

    private static func easeOut(_ x: Double) -> Double { 1 - pow(1 - min(max(x, 0), 1), 3) }
    private static func easeIn(_ x: Double) -> Double { pow(min(max(x, 0), 1), 2.2) }
    private static func smooth(_ x: Double) -> Double { let c = min(max(x, 0), 1); return c * c * (3 - 2 * c) }

    /// How far out, 0 (hidden) to 1.
    private var progress: Double {
        switch t {
        case ..<0.4: Self.easeOut(t / 0.4) * 0.45
        case ..<0.55: 0.45
        case ..<0.95: 0.45 + Self.easeOut((t - 0.55) / 0.4) * 0.55
        case ..<2.16: 1
        default: 1 - Self.easeIn((t - 2.16) / 0.34)
        }
    }

    /// Side or front, and the horizontal squash of a turn: right (1), front (0), left (-1).
    private var pose: (front: Bool, facing: CGFloat, squash: CGFloat) {
        switch t {
        case ..<1.15: (false, 1, 1)
        case ..<1.24: (false, 1, CGFloat(1 - Self.smooth((t - 1.15) / 0.09)))
        case ..<1.33: (true, 1, CGFloat(Self.smooth((t - 1.24) / 0.09)))
        case ..<2.0: (true, 1, 1)
        case ..<2.08: (true, 1, CGFloat(1 - Self.smooth((t - 2.0) / 0.08)))
        case ..<2.16: (false, -1, CGFloat(Self.smooth((t - 2.08) / 0.08)))
        default: (false, -1, 1)
        }
    }

    /// 0 to 1 while it screams.
    private var scream: Double {
        guard t >= 1.4, t < 2.0 else { return 0 }
        let u = (t - 1.4) / 0.6
        return min(1, u / 0.15) * min(1, (1 - u) / 0.2)
    }

    /// The legs' swing: tiptoeing out, quick running back, still otherwise.
    private var stride: Double {
        switch t {
        case ..<0.4, 0.55..<0.95: sin(t * 18) * 1.6
        case 2.16...: sin(t * 46) * 2.4
        default: 0
        }
    }

    func draw(in context: inout GraphicsContext, size: CGSize) {
        let s = size.height / 44  // drawn for a 44pt-tall strip
        let shake = scream > 0 ? sin(t * 90) * 1.1 * scream : 0
        let bob = (0.95..<1.15).contains(t) ? -abs(sin((t - 0.95) / 0.2 * .pi)) * 1.5 : 0
        let x = hideX + (outX - hideX) * progress + shake
        let ground = size.height - 6 * s
        var c = context
        c.translateBy(x: x, y: ground)
        c.scaleBy(x: s, y: s)
        // Leaning forward as it runs back.
        if t > 2.16 { c.rotate(by: .degrees(8)) }
        let pose = pose
        drawLegs(in: &c, front: pose.front, facing: pose.facing)
        var figure = c
        figure.scaleBy(x: pose.facing * max(pose.squash, 0.02), y: 1)
        if pose.front {
            drawFront(in: &figure, bob: bob)
        } else {
            drawSide(in: &figure, bob: bob)
        }
        if scream > 0 { drawScream(in: &c) }
    }

    // Origin at the feet's ground point, the body above it; side view faces +x.

    private func ellipse(_ cx: CGFloat, _ cy: CGFloat, _ w: CGFloat, _ h: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h))
    }

    private func feather(in c: inout GraphicsContext, pivot: CGPoint, angle: Double, length: CGFloat, width: CGFloat, color: Color) {
        var f = c
        f.translateBy(x: pivot.x, y: pivot.y)
        f.rotate(by: .degrees(angle))
        f.fill(Path(roundedRect: CGRect(x: 0, y: -width / 2, width: length, height: width), cornerRadius: width / 2), with: .color(color))
    }

    private func drawSide(in c: inout GraphicsContext, bob: Double) {
        // Tail fan behind, up and back.
        let pivot = CGPoint(x: -4, y: -13)
        for (i, color) in feathers.prefix(5).enumerated() {
            feather(in: &c, pivot: pivot, angle: -165 + Double(i) * 24, length: 12, width: 5, color: color)
        }
        c.fill(ellipse(0, -12, 15, 12), with: .color(body))
        c.fill(ellipse(-1, -11.5, 8, 6), with: .color(wing))
        // Neck and head.
        c.fill(Path(roundedRect: CGRect(x: 4, y: -21 + bob, width: 3.2, height: 8), cornerRadius: 1.6), with: .color(head))
        c.fill(ellipse(6.5, -21 + bob, 6.4, 6.4), with: .color(head))
        var beakPath = Path()
        beakPath.move(to: CGPoint(x: 9.2, y: -22.2 + bob))
        beakPath.addLine(to: CGPoint(x: 12.2, y: -21.2 + bob))
        beakPath.addLine(to: CGPoint(x: 9.2, y: -20.2 + bob))
        beakPath.closeSubpath()
        c.fill(beakPath, with: .color(beak))
        c.fill(ellipse(9.4, -18.6 + bob, 1.9, 3.4), with: .color(wattle))
        c.fill(ellipse(7.2, -22 + bob, 1.6, 1.6), with: .color(eye))
    }

    private func drawFront(in c: inout GraphicsContext, bob: Double) {
        let puff = 1 + 0.18 * scream
        let pivot = CGPoint(x: 0, y: -13)
        for (i, color) in feathers.enumerated() {
            feather(in: &c, pivot: pivot, angle: -170 + Double(i) * (160.0 / 6), length: 12.5 * puff, width: 5.2, color: color)
        }
        c.fill(ellipse(0, -11.5, 13.5, 13), with: .color(body))
        c.fill(ellipse(0, -10, 8, 7), with: .color(wing))
        c.fill(ellipse(0, -21 + bob, 7, 7), with: .color(head))
        c.fill(ellipse(-1.5, -22 + bob, 1.5, 1.5), with: .color(eye))
        c.fill(ellipse(1.5, -22 + bob, 1.5, 1.5), with: .color(eye))
        let open = 2.6 * scream
        // Beak: upper half up, lower half down while it screams, a dark mouth between.
        if open > 0.1 { c.fill(ellipse(0, -19.6 + bob + open / 2, 2.4, open + 0.6), with: .color(eye)) }
        var upper = Path()
        upper.move(to: CGPoint(x: -1.3, y: -20.4 + bob))
        upper.addLine(to: CGPoint(x: 1.3, y: -20.4 + bob))
        upper.addLine(to: CGPoint(x: 0, y: -19 + bob))
        upper.closeSubpath()
        c.fill(upper, with: .color(beak))
        if open > 0.1 {
            var lower = Path()
            lower.move(to: CGPoint(x: -1, y: -19.2 + bob + open))
            lower.addLine(to: CGPoint(x: 1, y: -19.2 + bob + open))
            lower.addLine(to: CGPoint(x: 0, y: -18 + bob + open))
            lower.closeSubpath()
            c.fill(lower, with: .color(beak))
        }
        c.fill(ellipse(1.9, -18 + bob + open * 0.6, 1.5, 3), with: .color(wattle))
    }

    private func drawLegs(in c: inout GraphicsContext, front: Bool, facing: CGFloat) {
        let swing = CGFloat(stride) * facing
        let hips: [CGFloat] = front ? [-2.6, 2.6] : [-1.8, 1.8]
        for (i, hip) in hips.enumerated() {
            let step = front ? 0 : (i == 0 ? swing : -swing)
            var leg = Path()
            leg.move(to: CGPoint(x: hip, y: -6.5))
            leg.addLine(to: CGPoint(x: hip + step, y: 0))
            leg.addLine(to: CGPoint(x: hip + step + (front ? 0 : 2 * facing), y: 0))
            c.stroke(leg, with: .color(legs), style: StrokeStyle(lineWidth: 1.3, lineCap: .round, lineJoin: .round))
        }
    }

    private func drawScream(in c: inout GraphicsContext) {
        let pop = 0.6 + 0.4 * scream
        // Beside its head, inside the header (above it, the top was cut off).
        var text = c
        text.opacity = scream
        text.translateBy(x: 9, y: -27)
        text.scaleBy(x: pop, y: pop)
        text.rotate(by: .degrees(-8))
        text.draw(Text("AAH!").font(.system(size: 9, weight: .heavy, design: retro ? .monospaced : .rounded))
                      .foregroundStyle(retro ? tint : Color(red: 0.84, green: 0.15, blue: 0.24)),
                  at: .zero, anchor: .leading)
    }
}
