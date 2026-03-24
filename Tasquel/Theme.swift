import SwiftUI

// MARK: - Design System

/// Mode-aware theme resolved per-render from the store's appearanceMode.
/// Pass the mode explicitly to each property so SwiftUI re-evaluates when the
/// observable `store.appearanceMode` changes — no stale static var.
enum Theme {
    // Retro color palettes (bright, dim, faint)
    private static func retroPalette(_ c: RetroColor) -> (Color, Color, Color) {
        switch c {
        case .green:
            (Color(red: 0.2, green: 1.0, blue: 0.2),
             Color(red: 0.15, green: 0.7, blue: 0.15),
             Color(red: 0.1, green: 0.4, blue: 0.1))
        case .amber:
            (Color(red: 1.0, green: 0.75, blue: 0.0),
             Color(red: 0.7, green: 0.5, blue: 0.0),
             Color(red: 0.4, green: 0.3, blue: 0.0))
        case .blue:
            (Color(red: 0.3, green: 0.7, blue: 1.0),
             Color(red: 0.2, green: 0.5, blue: 0.7),
             Color(red: 0.1, green: 0.3, blue: 0.4))
        case .white:
            (Color(white: 0.95),
             Color(white: 0.65),
             Color(white: 0.35))
        case .red:
            (Color(red: 1.0, green: 0.3, blue: 0.3),
             Color(red: 0.7, green: 0.2, blue: 0.2),
             Color(red: 0.4, green: 0.1, blue: 0.1))
        case .purple:
            (Color(red: 0.75, green: 0.4, blue: 1.0),
             Color(red: 0.5, green: 0.25, blue: 0.7),
             Color(red: 0.3, green: 0.15, blue: 0.4))
        }
    }

    /// Convenience to get the color for a swatch preview
    static func retroBright(_ c: RetroColor) -> Color { retroPalette(c).0 }

    // Helpers
    static func isRetro(_ m: AppearanceMode) -> Bool { m == .retro }
    static func isDark(_ m: AppearanceMode) -> Bool { m == .dark }
    static func isCustomDark(_ m: AppearanceMode) -> Bool { m == .dark || m == .retro }

    // Core backgrounds
    static func background(_ m: AppearanceMode) -> Color {
        switch m {
        case .retro: .black
        case .dark: Color(red: 0, green: 0, blue: 20.0/255)
        case .system, .light: Color(.systemBackground)
        }
    }
    static func cardFill(_ m: AppearanceMode) -> Color {
        switch m {
        case .retro: Color(white: 0.06)
        case .dark: Color(red: 55.0/255, green: 55.0/255, blue: 84.0/255)
        case .system, .light: Color(.secondarySystemGroupedBackground)
        }
    }
    static func navCapsule(_ m: AppearanceMode) -> Color {
        switch m {
        case .retro: Color(white: 0.1)
        case .dark: Color(white: 33.0/255, opacity: 0.2)
        case .system, .light: Color(.systemGray5)
        }
    }

    // Task dot colors — retro uses the phosphor bright color
    static func dotComplete(_ m: AppearanceMode, rc: RetroColor = .green) -> Color {
        isRetro(m) ? retroPalette(rc).0 : .green
    }
    static func dotIncomplete(_ m: AppearanceMode) -> Color {
        isRetro(m) ? .red.opacity(0.8) : .red
    }

    // Completion icon colors
    static func completionAll(_ m: AppearanceMode, rc: RetroColor = .green) -> Color { isRetro(m) ? retroPalette(rc).0 : .green }
    static func completionPartial(_ m: AppearanceMode) -> Color { isRetro(m) ? .yellow : .orange }
    static func completionNone(_ m: AppearanceMode) -> Color { isRetro(m) ? .red.opacity(0.8) : .red }

    // Accent
    static func accent(_ m: AppearanceMode, rc: RetroColor = .green) -> Color { isRetro(m) ? retroPalette(rc).0 : .blue }
    static func destructive(_ m: AppearanceMode) -> Color { isRetro(m) ? .red.opacity(0.8) : .red }

    // Text
    static func textPrimary(_ m: AppearanceMode, rc: RetroColor = .green) -> Color {
        switch m {
        case .retro: retroPalette(rc).0
        case .dark: .white
        case .system, .light: Color(.label)
        }
    }
    static func textSecondary(_ m: AppearanceMode, rc: RetroColor = .green) -> Color {
        switch m {
        case .retro: retroPalette(rc).1
        case .dark: .white.opacity(0.6)
        case .system, .light: Color(.secondaryLabel)
        }
    }
    static func textTertiary(_ m: AppearanceMode, rc: RetroColor = .green) -> Color {
        switch m {
        case .retro: retroPalette(rc).2
        case .dark: .white.opacity(0.35)
        case .system, .light: Color(.tertiaryLabel)
        }
    }

    // Card
    static func cardCornerRadius(_ m: AppearanceMode) -> CGFloat { isRetro(m) ? 2 : 12 }
    static func cardShadow(_ m: AppearanceMode, rc: RetroColor = .green) -> Color {
        switch m {
        case .retro: retroPalette(rc).2.opacity(0.3)
        case .dark: .black.opacity(0.3)
        case .system, .light: .black.opacity(0.08)
        }
    }
    static func cardBorder(_ m: AppearanceMode, rc: RetroColor = .green) -> Color { isRetro(m) ? retroPalette(rc).1 : .clear }
    static func cardBorderWidth(_ m: AppearanceMode) -> CGFloat { isRetro(m) ? 1 : 0 }

    // Font
    static func primaryFont(_ m: AppearanceMode) -> Font { isRetro(m) ? .system(.subheadline, design: .monospaced).bold() : .subheadline.bold() }
    static func bodyFont(_ m: AppearanceMode) -> Font { isRetro(m) ? .system(.subheadline, design: .monospaced) : .subheadline }
    static func captionFont(_ m: AppearanceMode) -> Font { isRetro(m) ? .system(.caption, design: .monospaced) : .caption }
    static func titleFont(_ m: AppearanceMode) -> Font { isRetro(m) ? .system(.title, design: .monospaced).bold() : .title.bold() }
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
