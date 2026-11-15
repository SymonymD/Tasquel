import SwiftUI

// MARK: - Design System

/// Mode-aware theme resolved per-render from the store's appearanceMode.
/// Pass the mode explicitly to each property so SwiftUI re-evaluates when the
/// observable `store.appearanceMode` changes — no stale static var.
enum Theme {
    /// One retro phosphor color at each brightness. Bright, dim, and faint are text
    /// colors and keep at least 4.5:1 contrast on a retro card; glow is only for the
    /// card shadow.
    private struct RetroPalette {
        let bright: Color
        let dim: Color
        let faint: Color
        let glow: Color

        init(_ bright: (Double, Double, Double), _ dim: (Double, Double, Double),
             _ faint: (Double, Double, Double), glow: (Double, Double, Double)) {
            self.bright = Color(red: bright.0, green: bright.1, blue: bright.2)
            self.dim = Color(red: dim.0, green: dim.1, blue: dim.2)
            self.faint = Color(red: faint.0, green: faint.1, blue: faint.2)
            self.glow = Color(red: glow.0, green: glow.1, blue: glow.2)
        }
    }

    private static func retroPalette(_ c: RetroColor) -> RetroPalette {
        switch c {
        case .green:
            RetroPalette((0.2, 1.0, 0.2), (0.15, 0.7, 0.15), (0.11, 0.57, 0.11), glow: (0.1, 0.4, 0.1))
        case .amber:
            RetroPalette((1.0, 0.75, 0.0), (0.72, 0.54, 0.0), (0.63, 0.47, 0.0), glow: (0.4, 0.3, 0.0))
        case .blue:
            RetroPalette((0.3, 0.7, 1.0), (0.25, 0.59, 0.84), (0.22, 0.52, 0.74), glow: (0.1, 0.3, 0.4))
        case .white:
            RetroPalette((0.95, 0.95, 0.95), (0.65, 0.65, 0.65), (0.49, 0.49, 0.49), glow: (0.35, 0.35, 0.35))
        case .red:
            RetroPalette((1.0, 0.43, 0.43), (0.89, 0.38, 0.38), (0.8, 0.34, 0.34), glow: (0.4, 0.1, 0.1))
        case .purple:
            RetroPalette((0.78, 0.48, 1.0), (0.69, 0.43, 0.89), (0.62, 0.38, 0.8), glow: (0.3, 0.15, 0.4))
        }
    }

    /// Retro's red for unfinished and destructive items; readable (4.5:1) on a retro card.
    private static let retroRed = Color(red: 1.0, green: 0.4, blue: 0.35)

    /// Convenience to get the color for a swatch preview
    static func retroBright(_ c: RetroColor) -> Color { retroPalette(c).bright }

    // Helpers
    static func isRetro(_ m: AppearanceMode) -> Bool { m == .retro }

    /// Retro's decorated words as VoiceOver and Voice Control should have them:
    /// "> Saved Categories" → "Saved Categories", "[TERMINAL_COLOR]" → "Terminal Color",
    /// "> RETRO" → "Retro". The prompt, brackets and underscores are only for the look.
    static func plainRetroLabel(_ text: String) -> String {
        var plain = text.trimmingCharacters(in: .whitespaces)
        if plain.hasPrefix(">") { plain.removeFirst() }
        plain = plain.trimmingCharacters(in: CharacterSet(charactersIn: " []_"))
            .replacingOccurrences(of: "_", with: " ")
        if plain == plain.uppercased(), plain.contains(where: \.isLetter) { plain = plain.capitalized }
        return plain
    }
    static func isDark(_ m: AppearanceMode) -> Bool { m == .dark }
    static func isCustomDark(_ m: AppearanceMode) -> Bool { m == .dark || m == .retro }
    static func isSeasonal(_ m: AppearanceMode) -> Bool { m == .seasonal }
    /// Lists and sheets drawn on the theme's own colors, not the system's grouped grays.
    static func hasOwnBackground(_ m: AppearanceMode) -> Bool { isCustomDark(m) || isSeasonal(m) }
    /// Today's season's colors (Seasonal appearance).
    private static var season: SeasonPalette { Season.current.palette }

    // Core backgrounds
    static func background(_ m: AppearanceMode) -> Color {
        switch m {
        case .retro: .black
        case .dark: Color(red: 0, green: 0, blue: 20.0/255)
        case .seasonal: season.bgBottom.color
        case .system, .light: Color(.systemBackground)
        }
    }
    static func cardFill(_ m: AppearanceMode) -> Color {
        switch m {
        case .retro: Color(white: 0.06)
        case .dark: Color(red: 55.0/255, green: 55.0/255, blue: 84.0/255)
        case .seasonal: season.card.color
        case .system, .light: Color(.secondarySystemGroupedBackground)
        }
    }
    static func navCapsule(_ m: AppearanceMode) -> Color {
        switch m {
        case .retro: Color(white: 0.1)
        case .dark: Color(white: 33.0/255, opacity: 0.2)
        case .seasonal: season.capsule.color
        case .system, .light: Color(.systemGray5)
        }
    }

    // Task dot colors — retro uses the phosphor bright color
    static func dotComplete(_ m: AppearanceMode, rc: RetroColor = .green) -> Color {
        isSeasonal(m) ? season.done.color : isRetro(m) ? retroPalette(rc).bright : .green
    }
    static func dotIncomplete(_ m: AppearanceMode) -> Color {
        isSeasonal(m) ? season.missed.color : isRetro(m) ? retroRed : .red
    }

    // Completion icon colors
    static func completionAll(_ m: AppearanceMode, rc: RetroColor = .green) -> Color { dotComplete(m, rc: rc) }
    static func completionPartial(_ m: AppearanceMode) -> Color { isSeasonal(m) ? season.partial.color : isRetro(m) ? .yellow : .orange }
    static func completionNone(_ m: AppearanceMode) -> Color { dotIncomplete(m) }

    /// Orange that keeps 4:1 on a card: deeper in light mode (system orange is about 2:1 on white).
    private static let strongOrange = Color(UIColor {
        $0.userInterfaceStyle == .dark ? .systemOrange : UIColor(red: 0.78, green: 0.37, blue: 0, alpha: 1)
    })
    /// A pin that's on (a card's or task's in edit mode); the bright color in Retro.
    static func pinned(_ m: AppearanceMode, rc: RetroColor = .green) -> Color {
        isRetro(m) ? retroPalette(rc).bright : strongOrange
    }
    /// A task's day once it has gone by unfinished ("Tue · late"), like the Duplicate mark.
    static func late(_ m: AppearanceMode) -> Color { isRetro(m) ? .yellow : strongOrange }
    /// The Duplicate mark after a task's or item's name (Retro: yellow, like a part-done ring).
    static func duplicate(_ m: AppearanceMode) -> Color { isRetro(m) ? .yellow : strongOrange }
    /// An expiring task's ring (the days gone by) and its clock in a card's edit mode: green,
    /// deeper in light mode so it keeps 4:1 on a card.
    static func expirySet(_ m: AppearanceMode, rc: RetroColor = .green) -> Color {
        if isSeasonal(m) { return season.done.color }
        return isRetro(m) ? retroPalette(rc).bright
            : Color(UIColor { $0.userInterfaceStyle == .dark ? .systemGreen : UIColor(red: 0.12, green: 0.52, blue: 0.2, alpha: 1) })
    }

    // Accent
    static func accent(_ m: AppearanceMode, rc: RetroColor = .green) -> Color {
        isSeasonal(m) ? season.accent.color : isRetro(m) ? retroPalette(rc).bright : .blue
    }
    /// A past day's date on its day pill (blue since 2026-11-15; today's is green): the
    /// accent, but a deeper blue in light mode (System, Light), where the system blue is about
    /// 4:1 on the frosted header and small bold text needs 4.5:1 (review finding 22). The
    /// pill's outline stays the accent.
    static func pastDayDate(_ m: AppearanceMode, rc: RetroColor = .green) -> Color {
        switch m {
        case .system, .light: Color(UIColor { $0.userInterfaceStyle == .dark ? .systemBlue : pastDayDateLight })
        case .dark, .retro, .seasonal: accent(m, rc: rc)
        }
    }
    /// #0060DF: 5.6:1 on white.
    static let pastDayDateLight = UIColor(red: 0, green: 0x60 / 255.0, blue: 0xDF / 255.0, alpha: 1)
    /// Words and icons on a filled accent (a button, a picked day): dark where the accent is
    /// light (Retro, Seasonal at night), else white.
    static func onAccent(_ m: AppearanceMode) -> Color {
        isSeasonal(m) ? season.onAccent.color : isRetro(m) ? .black : .white
    }
    /// Each task type and mode has its own color; retro keeps its single phosphor color.
    static func taskType(_ type: TaskType, _ m: AppearanceMode, rc: RetroColor = .green) -> Color {
        if isRetro(m) { return retroPalette(rc).bright }
        if isSeasonal(m) {
            switch type {
            case .checkbox: return season.checkbox.color
            case .goal: return season.goal.color
            case .list: return season.list.color
            }
        }
        switch type {
        case .checkbox: return .blue
        case .goal: return .purple
        case .list: return .pink
        }
    }

    static func taskMode(_ mode: TaskMode, _ m: AppearanceMode, rc: RetroColor = .green) -> Color {
        if isRetro(m) { return retroPalette(rc).bright }
        if isSeasonal(m) {
            switch mode {
            case .oneTime: return season.oneTime.color
            case .carryOver: return season.carry.color
            case .repeating: return season.repeating.color
            }
        }
        switch mode {
        case .oneTime: return .gray
        case .carryOver: return .orange
        case .repeating: return .teal
        }
    }

    static func destructive(_ m: AppearanceMode) -> Color { isRetro(m) ? retroRed : .red }

    // Text
    static func textPrimary(_ m: AppearanceMode, rc: RetroColor = .green) -> Color {
        switch m {
        case .retro: retroPalette(rc).bright
        case .dark: .white
        case .seasonal: season.text1.color
        case .system, .light: Color(.label)
        }
    }
    static func textSecondary(_ m: AppearanceMode, rc: RetroColor = .green) -> Color {
        switch m {
        case .retro: retroPalette(rc).dim
        case .dark: .white.opacity(0.6)
        case .seasonal: season.text2.color
        case .system, .light: Color(.secondaryLabel)
        }
    }
    static func textTertiary(_ m: AppearanceMode, rc: RetroColor = .green) -> Color {
        switch m {
        case .retro: retroPalette(rc).faint
        case .dark: .white.opacity(0.35)
        case .seasonal: season.text3.color
        case .system, .light: Color(.tertiaryLabel)
        }
    }

    // Card
    static func cardCornerRadius(_ m: AppearanceMode) -> CGFloat { isRetro(m) ? 2 : 12 }
    static func cardShadow(_ m: AppearanceMode, rc: RetroColor = .green) -> Color {
        switch m {
        case .retro: retroPalette(rc).glow.opacity(0.3)
        case .dark: .black.opacity(0.3)
        case .seasonal: season.shadowColor
        case .system, .light: .black.opacity(0.08)
        }
    }
    static func cardBorder(_ m: AppearanceMode, rc: RetroColor = .green) -> Color {
        isSeasonal(m) ? season.border.color : isRetro(m) ? retroPalette(rc).dim : .clear
    }
    static func cardBorderWidth(_ m: AppearanceMode) -> CGFloat { isRetro(m) || isSeasonal(m) ? 1 : 0 }

    // Font
    static func bodyFont(_ m: AppearanceMode) -> Font { isRetro(m) ? .system(.subheadline, design: .monospaced) : .subheadline }
    static func captionFont(_ m: AppearanceMode) -> Font { isRetro(m) ? .system(.caption, design: .monospaced) : .caption }
}

// MARK: - Scanline Overlay (Retro)

struct ScanlineOverlay: View {
    var body: some View {
        Canvas { context, size in
            for y in stride(from: 0, to: size.height, by: 3) {
                let rect = CGRect(x: 0, y: y, width: size.width, height: 1)
                context.fill(Path(rect), with: .color(.black.opacity(0.15)))
            }
        }
    }
}

// MARK: - Card Text Fields

extension View {
    /// The look of every text field in a card: a soft fill with slightly rounded corners; in
    /// Retro, square brackets at its ends, like an input box in an old DOS dialog (with the
    /// DOS cursor, `RetroCaret`). With `outset`, the fill reaches beyond the text instead of
    /// padding it, so swapping a name for its field doesn't move the words.
    @ViewBuilder
    func cardField(_ theme: AppearanceMode, rc: RetroColor, outset: Bool = false) -> some View {
        let frame = FieldFrame(theme: theme, rc: rc)
        let field = Group {
            if outset {
                background { frame.padding(.horizontal, -8).padding(.vertical, -4) }
            } else {
                textFieldStyle(.plain)
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .background { frame }
            }
        }
        if Theme.isRetro(theme) {
            field.tint(Theme.textPrimary(theme, rc: rc))  // the cursor, Retro's color
        } else {
            field
        }
    }
}

/// A card field's frame (`cardField`): a soft fill, or Retro's brackets.
private struct FieldFrame: View {
    let theme: AppearanceMode
    let rc: RetroColor

    var body: some View {
        if Theme.isRetro(theme) {
            DOSFieldBrackets()
                .stroke(Theme.textSecondary(theme, rc: rc), style: StrokeStyle(lineWidth: 1.5, lineCap: .square))
        } else {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Theme.textTertiary(theme, rc: rc).opacity(0.2))
        }
    }
}

/// `[` at a field's leading end and `]` at its trailing end, the full height.
struct DOSFieldBrackets: Shape {
    var serif: CGFloat = 5

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: 0.75, dy: 0.75)  // half the stroke, so it stays inside
        var path = Path()
        path.addLines([CGPoint(x: r.minX + serif, y: r.minY), CGPoint(x: r.minX, y: r.minY),
                       CGPoint(x: r.minX, y: r.maxY), CGPoint(x: r.minX + serif, y: r.maxY)])
        path.addLines([CGPoint(x: r.maxX - serif, y: r.minY), CGPoint(x: r.maxX, y: r.minY),
                       CGPoint(x: r.maxX, y: r.maxY), CGPoint(x: r.maxX - serif, y: r.maxY)])
        return path
    }
}

// MARK: - Sheet Done Button

/// A sheet's Done button: a checkmark in a plain glass circle, still read as "Done".
/// A text button gets squeezed into a small circle on iOS 26.6 when Button Shapes is on.
struct SheetDoneButton: View {
    let action: () -> Void

    var body: some View {
        Button("Done", systemImage: "checkmark", action: action)
            .labelStyle(.iconOnly)
            .accessibilityRemoveTraits(.isSelected)  // a checkmark icon reads as "selected"
    }
}


/// In Retro, a popover (the type/mode/day picker, the expiration calendar) on Retro's own
/// black rather than the system's gray glass; other themes keep the glass.
struct RetroPopoverBackground: ViewModifier {
    let theme: AppearanceMode

    func body(content: Content) -> some View {
        if Theme.isRetro(theme) {
            content.presentationBackground(Theme.background(theme))
        } else {
            content
        }
    }
}
