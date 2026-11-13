import SwiftUI
import UIKit

// MARK: - Season

/// The Seasonal appearance: a palette for each season, in light and dark following the
/// phone's setting, picked by today's date (`Season.current`). Each season has a backdrop
/// behind the cards (`SeasonalBackdrop`): petals, a sun and waves, leaves, snow.
enum Season: String, CaseIterable {
    case spring, summer, fall, winter

    /// The season `date` falls in, by the usual start dates: spring from March 20, summer
    /// June 21, fall September 22, winter December 21. South of the equator (by the phone's
    /// region) they're the other way round: December is summer there.
    static func of(_ date: Date, timeZone: TimeZone = .current, region: Locale.Region? = Locale.current.region) -> Season {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = timeZone
        let parts = gregorian.dateComponents([.month, .day], from: date)
        let monthDay = (parts.month ?? 1) * 100 + (parts.day ?? 1)
        let north: Season = switch monthDay {
        case 320..<621: .spring
        case 621..<922: .summer
        case 922..<1221: .fall
        default: .winter
        }
        guard let code = region?.identifier, southernRegions.contains(code) else { return north }
        return switch north {
        case .spring: .fall
        case .summer: .winter
        case .fall: .spring
        case .winter: .summer
        }
    }

    /// Countries wholly or mostly south of the equator.
    private static let southernRegions: Set<String> = [
        "AU", "NZ", "ZA", "AR", "CL", "UY", "PY", "BR", "BO", "PE", "LS", "SZ", "NA", "BW", "ZW", "ZM", "MZ", "MG", "MW",
        "AO", "FJ", "PG", "NC", "SB", "VU", "WS", "TO", "MU", "RE",
    ]

    /// Today's season. Debug builds take `-demoSeason <spring|summer|fall|winter>`, for
    /// screenshots.
    static var current: Season {
        #if DEBUG
        if let forced { return forced }
        #endif
        return of(Date())
    }

    #if DEBUG
    private static let forced: Season? = {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-demoSeason"), arguments.indices.contains(index + 1) else { return nil }
        return Season(rawValue: arguments[index + 1])
    }()
    #endif

    /// "Fall"
    var label: String { rawValue.capitalized }

    var symbol: String {
        switch self {
        case .spring: "camera.macro"
        case .summer: "sun.max"
        case .fall: "leaf"
        case .winter: "snowflake"
        }
    }

    var palette: SeasonPalette { SeasonPalette.of(self) }
}

// MARK: - Palette

/// A season's colors, each a light and a dark one (`Tone`), shown as the phone's light or
/// dark setting says. Text and accents keep 4.5:1 on the card, icons and rings 3:1, and the
/// words on a filled accent button 4.5:1 (`SeasonTests` checks them all).
struct SeasonPalette {
    /// A color for light mode and one for dark (0xRRGGBB).
    struct Tone {
        let light: UInt32
        let dark: UInt32

        var color: Color {
            Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) })
        }
    }

    let bgTop, bgBottom, card, border, capsule: Tone
    let text1, text2, text3, accent, onAccent: Tone
    let done, partial, missed: Tone
    let checkbox, goal, list: Tone
    let oneTime, carry, repeating: Tone
    let shadow: Tone
    /// The backdrop's motifs (petals, sun and waves, leaves, snow).
    let motifs: [Tone]

    static func of(_ season: Season) -> SeasonPalette {
        switch season {
        case .spring: spring
        case .summer: summer
        case .fall: fall
        case .winter: winter
        }
    }

    /// A blossom morning (blush to mint, leaf green); at night, dusky plum and garden green.
    static let spring = SeasonPalette(
        bgTop: .init(light: 0xFDEEF2, dark: 0x1E1624), bgBottom: .init(light: 0xEAF6E8, dark: 0x102019),
        card: .init(light: 0xFFFCFA, dark: 0x2A2230), border: .init(light: 0xF2D3DC, dark: 0x4A3646),
        capsule: .init(light: 0xF7E3E9, dark: 0x33293A),
        text1: .init(light: 0x2E3A30, dark: 0xF6ECEF), text2: .init(light: 0x5E6E62, dark: 0xC8B3BC),
        text3: .init(light: 0x8E9C91, dark: 0x9A8690), accent: .init(light: 0x2F7D4B, dark: 0x7FD39A),
        onAccent: .init(light: 0xFFFFFF, dark: 0x10201A),
        done: .init(light: 0x3C9A5B, dark: 0x7FD39A), partial: .init(light: 0xD9708F, dark: 0xF2A2BA),
        missed: .init(light: 0xD25C78, dark: 0xF28CA4),
        checkbox: .init(light: 0x2F7D4B, dark: 0x7FD39A), goal: .init(light: 0x9A58AB, dark: 0xD3A0E6),
        list: .init(light: 0xD25C78, dark: 0xF28CA4),
        oneTime: .init(light: 0x7E8D81, dark: 0xA99AA2), carry: .init(light: 0xB8771A, dark: 0xF2C266),
        repeating: .init(light: 0x2F8F87, dark: 0x6FD1C5),
        shadow: .init(light: 0xC47A8C, dark: 0x000000),
        motifs: [.init(light: 0xF4B6C8, dark: 0xC98AA0), .init(light: 0xF9CFDA, dark: 0xA9789A), .init(light: 0xBFE3C3, dark: 0x5F9E73)])

    /// Sky over sand (ocean teal, a sun glow); at night, a deep-sea evening with a sunset.
    static let summer = SeasonPalette(
        bgTop: .init(light: 0xD8F0FA, dark: 0x0B2233), bgBottom: .init(light: 0xFFF1D6, dark: 0x2A2018),
        card: .init(light: 0xFFFFFF, dark: 0x13303F), border: .init(light: 0xC6E6F1, dark: 0x23506A),
        capsule: .init(light: 0xE3F3F8, dark: 0x183A4B),
        text1: .init(light: 0x173A4D, dark: 0xEAF7FB), text2: .init(light: 0x4A687B, dark: 0xA9CCDA),
        text3: .init(light: 0x8299A7, dark: 0x7FA3B4), accent: .init(light: 0x0A7D94, dark: 0x4FD1E8),
        onAccent: .init(light: 0xFFFFFF, dark: 0x0B2233),
        done: .init(light: 0x16937A, dark: 0x49D6A8), partial: .init(light: 0xC27A08, dark: 0xFFC14D),
        missed: .init(light: 0xE0503B, dark: 0xFF8A73),
        checkbox: .init(light: 0x0A7D94, dark: 0x4FD1E8), goal: .init(light: 0xD9651E, dark: 0xFFA05C),
        list: .init(light: 0xD23F6B, dark: 0xFF7BA0),
        oneTime: .init(light: 0x7893A2, dark: 0x8FB2C2), carry: .init(light: 0xC27A08, dark: 0xFFC14D),
        repeating: .init(light: 0x16937A, dark: 0x49D6A8),
        shadow: .init(light: 0x0C8AA3, dark: 0x000000),
        motifs: [.init(light: 0xFFD66B, dark: 0xFF9F5A), .init(light: 0x9ED9EA, dark: 0x2F6E8A)])

    /// Warm parchment (burnt orange, amber, cranberry, olive); in the evening, cozy browns.
    static let fall = SeasonPalette(
        bgTop: .init(light: 0xFBF0E1, dark: 0x1E130C), bgBottom: .init(light: 0xF1DABE, dark: 0x2B1A10),
        card: .init(light: 0xFFF8EF, dark: 0x33231A), border: .init(light: 0xE8C9A2, dark: 0x5A3B26),
        capsule: .init(light: 0xF3E1C9, dark: 0x3B291D),
        text1: .init(light: 0x3A2517, dark: 0xFBEFE3), text2: .init(light: 0x6E4F3B, dark: 0xD9B99C),
        text3: .init(light: 0x9F8572, dark: 0xA88A72), accent: .init(light: 0xAD4A12, dark: 0xF2894A),
        onAccent: .init(light: 0xFFFFFF, dark: 0x1E130C),
        done: .init(light: 0x6B7C22, dark: 0xA9C24E), partial: .init(light: 0xC07612, dark: 0xF2B33D),
        missed: .init(light: 0xA5302B, dark: 0xEC6F67),
        checkbox: .init(light: 0xAD4A12, dark: 0xF2894A), goal: .init(light: 0x8A3961, dark: 0xD889B2),
        list: .init(light: 0xA5302B, dark: 0xEC6F67),
        oneTime: .init(light: 0x8C7561, dark: 0xB39A86), carry: .init(light: 0xC07612, dark: 0xF2B33D),
        repeating: .init(light: 0x5D7A2E, dark: 0x9CBF5A),
        shadow: .init(light: 0x7A3E16, dark: 0x000000),
        motifs: [.init(light: 0xD9822B, dark: 0xD9822B), .init(light: 0xB8452A, dark: 0xB8452A),
                 .init(light: 0x9C6B2E, dark: 0x9C6B2E), .init(light: 0xE0A93B, dark: 0xE0A93B)])

    /// A frosty morning (snow white, deep ice blue); at night, midnight navy and aurora mint.
    static let winter = SeasonPalette(
        bgTop: .init(light: 0xE6F0FA, dark: 0x0A142C), bgBottom: .init(light: 0xF7FAFD, dark: 0x1A2A4B),
        card: .init(light: 0xFFFFFF, dark: 0x1F2E4E), border: .init(light: 0xCFE0F0, dark: 0x37507E),
        capsule: .init(light: 0xE3EEF8, dark: 0x24365A),
        text1: .init(light: 0x1A2B45, dark: 0xEAF2FF), text2: .init(light: 0x52677F, dark: 0xA6BAD8),
        text3: .init(light: 0x8597AE, dark: 0x7D93B6), accent: .init(light: 0x2569B0, dark: 0x7CC4FF),
        onAccent: .init(light: 0xFFFFFF, dark: 0x0A142C),
        done: .init(light: 0x24866F, dark: 0x6CE0BE), partial: .init(light: 0xB08420, dark: 0xF2C766),
        missed: .init(light: 0xC9445F, dark: 0xFF8DA2),
        checkbox: .init(light: 0x2569B0, dark: 0x7CC4FF), goal: .init(light: 0x6B53C9, dark: 0xB7A4FF),
        list: .init(light: 0xC9445F, dark: 0xFF8DA2),
        oneTime: .init(light: 0x7A8BA3, dark: 0x8CA1C2), carry: .init(light: 0xB08420, dark: 0xF2C766),
        repeating: .init(light: 0x24866F, dark: 0x6CE0BE),
        shadow: .init(light: 0x2569B0, dark: 0x000000),
        motifs: [.init(light: 0x8FB8E0, dark: 0xFFFFFF), .init(light: 0xB8D3EE, dark: 0xBFDCFF)])

    /// The card's shadow: tinted and soft in light mode, darker at night.
    var shadowColor: Color {
        let light = shadow.light, dark = shadow.dark
        return Color(UIColor {
            $0.userInterfaceStyle == .dark ? UIColor(hex: dark).withAlphaComponent(0.35) : UIColor(hex: light).withAlphaComponent(0.15)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

// MARK: - Backdrop

/// Behind the cards in the Seasonal appearance: the season's gradient with its motifs drawn
/// faintly (petals; a sun glow and waves; leaves; snow), always in the same places.
struct SeasonalBackdrop: View {
    let season: Season

    private var palette: SeasonPalette { season.palette }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(colors: [palette.bgTop.color, palette.bgBottom.color], startPoint: .top, endPoint: .bottom)
                if season == .summer {
                    RadialGradient(colors: [palette.motifs[0].color.opacity(0.5), .clear], center: UnitPoint(x: 0.92, y: 0.06),
                                   startRadius: 0, endRadius: proxy.size.width * 0.75)
                    waves
                } else {
                    scatter
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var scatter: some View {
        Canvas { context, size in
            var random = SeededRandom(seed: 7)
            let count = season == .winter ? 70 : 26
            for index in 0..<count {
                let x = random.next() * size.width
                let y = random.next() * size.height
                let scale = 0.6 + random.next() * 0.9
                let angle = random.next() * 360
                let color = palette.motifs[index % palette.motifs.count].color
                var place = context
                place.translateBy(x: x, y: y)
                place.rotate(by: .degrees(angle))
                switch season {
                case .spring: Self.petal(&place, scale: scale, color: color)
                case .fall: Self.leaf(&place, scale: scale, color: color)
                case .winter: Self.snow(&place, scale: scale, color: color, isFlake: index % 9 == 0)
                case .summer: break
                }
            }
        }
    }

    private var waves: some View {
        Canvas { context, size in
            for band in 0..<3 {
                var path = Path()
                let baseY = Double(size.height) * (0.84 + Double(band) * 0.05)
                path.move(to: CGPoint(x: 0, y: baseY))
                for x in stride(from: 0.0, through: Double(size.width), by: 4) {
                    path.addLine(to: CGPoint(x: x, y: baseY + sin(x / 38 + Double(band)) * 6))
                }
                path.addLine(to: CGPoint(x: size.width, y: size.height))
                path.addLine(to: CGPoint(x: 0, y: size.height))
                path.closeSubpath()
                context.fill(path, with: .color(palette.motifs[1].color.opacity(0.18 + Double(band) * 0.06)))
            }
        }
    }

    private static func petal(_ context: inout GraphicsContext, scale: Double, color: Color) {
        let r = 7 * scale
        for k in 0..<5 {
            var turned = context
            turned.rotate(by: .degrees(Double(k) * 72))
            turned.fill(Path(ellipseIn: CGRect(x: -r * 0.45, y: -r * 1.6, width: r * 0.9, height: r * 1.4)), with: .color(color.opacity(0.55)))
        }
        context.fill(Path(ellipseIn: CGRect(x: -r * 0.3, y: -r * 0.3, width: r * 0.6, height: r * 0.6)),
                     with: .color(Color(UIColor(hex: 0xF6D66E)).opacity(0.7)))
    }

    private static func leaf(_ context: inout GraphicsContext, scale: Double, color: Color) {
        let w = 16 * scale, h = 26 * scale
        var path = Path()
        path.move(to: CGPoint(x: 0, y: -h / 2))
        path.addQuadCurve(to: CGPoint(x: 0, y: h / 2), control: CGPoint(x: w, y: 0))
        path.addQuadCurve(to: CGPoint(x: 0, y: -h / 2), control: CGPoint(x: -w, y: 0))
        context.fill(path, with: .color(color.opacity(0.32)))
        var vein = Path()
        vein.move(to: CGPoint(x: 0, y: -h / 2))
        vein.addLine(to: CGPoint(x: 0, y: h / 2 + 4 * scale))
        context.stroke(vein, with: .color(color.opacity(0.4)), lineWidth: 1)
    }

    private static func snow(_ context: inout GraphicsContext, scale: Double, color: Color, isFlake: Bool) {
        if isFlake {
            let r = 9 * scale
            for k in 0..<6 {
                var turned = context
                turned.rotate(by: .degrees(Double(k) * 60))
                var arm = Path()
                arm.move(to: .zero); arm.addLine(to: CGPoint(x: 0, y: -r))
                arm.move(to: CGPoint(x: 0, y: -r * 0.6)); arm.addLine(to: CGPoint(x: r * 0.25, y: -r * 0.8))
                arm.move(to: CGPoint(x: 0, y: -r * 0.6)); arm.addLine(to: CGPoint(x: -r * 0.25, y: -r * 0.8))
                turned.stroke(arm, with: .color(color.opacity(0.35)), lineWidth: 1.2)
            }
        } else {
            let r = 1.6 * scale
            context.fill(Path(ellipseIn: CGRect(x: -r, y: -r, width: r * 2, height: r * 2)), with: .color(color.opacity(0.45)))
        }
    }
}

/// The same "random" places every time, so the backdrop doesn't jump between launches.
private struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        let top: UInt64 = state >> 11
        return Double(top) / 9_007_199_254_740_992.0
    }
}

// MARK: - Holiday marks

/// The Tasquel mark's holiday look, in every appearance, by the app's weeks (the week-start
/// setting): string lights for the week before Christmas's week and Christmas's week, then
/// confetti for the week after, New Year's Eve's (or, when Christmas's week holds New Year's
/// Eve too, New Year's Day's). Picked by today.
enum HolidayMark: String {
    case holidaySeason, newYear

    static func of(_ day: DayKey, firstWeekday: Int, calendar: Calendar) -> HolidayMark? {
        let weekStart = { (day: DayKey) in
            DayKey(Week.startOfWeek(containing: day.date(in: calendar), firstWeekday: firstWeekday, calendar: calendar), in: calendar)
        }
        let week = weekStart(day)
        // Early January belongs to the Christmas before it.
        for year in [day.year, day.year - 1] {
            switch weekStart(DayKey(year: year, month: 12, day: 25)).days(to: week) {
            case -7, 0: return .holidaySeason
            case 7: return .newYear
            default: continue
            }
        }
        return nil
    }

    /// The images drawn with the mark, each in its space with 170 more on every side, so it
    /// lines up centered on it (`layerSize`). The usual mark's are in their own colors, behind
    /// and in front of it. Retro's are its own pixel versions round the t in brackets, in one
    /// color (tinted to Retro's), clear of the t: the lights hang under the brackets.
    struct Layers: Equatable {
        var behind: String?
        var front: String
    }

    func layers(retro: Bool) -> Layers {
        switch (self, retro) {
        case (.holidaySeason, false): Layers(front: "HolidaySeasonMarkFront")
        case (.newYear, false): Layers(behind: "NewYearMarkBehind", front: "NewYearMarkFront")
        case (.holidaySeason, true): Layers(front: "HolidaySeasonMarkRetro")
        case (.newYear, true): Layers(front: "NewYearMarkRetro")
        }
    }

    /// A layer's size for a mark `height` tall: the mark's drawing is 443.31 tall and 408.04
    /// wide (Retro's 500, for its brackets), and the layers add 170 on every side.
    static func layerSize(forMarkHeight height: CGFloat, retro: Bool) -> CGSize {
        let markWidth: CGFloat = retro ? 500 : 408.04
        return CGSize(width: height * (markWidth + 340) / 443.31, height: height * (443.31 + 340) / 443.31)
    }
}
