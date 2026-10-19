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
        isRetro(m) ? retroPalette(rc).bright : .green
    }
    static func dotIncomplete(_ m: AppearanceMode) -> Color {
        isRetro(m) ? retroRed : .red
    }

    // Completion icon colors
    static func completionAll(_ m: AppearanceMode, rc: RetroColor = .green) -> Color { isRetro(m) ? retroPalette(rc).bright : .green }
    static func completionPartial(_ m: AppearanceMode) -> Color { isRetro(m) ? .yellow : .orange }
    static func completionNone(_ m: AppearanceMode) -> Color { isRetro(m) ? retroRed : .red }

    // Accent
    static func accent(_ m: AppearanceMode, rc: RetroColor = .green) -> Color { isRetro(m) ? retroPalette(rc).bright : .blue }
    /// Each task type and mode has its own color; retro keeps its single phosphor color.
    static func taskType(_ type: TaskType, _ m: AppearanceMode, rc: RetroColor = .green) -> Color {
        if isRetro(m) { return retroPalette(rc).bright }
        switch type {
        case .checkbox: return .blue
        case .goal: return .purple
        case .list: return .pink
        }
    }

    static func taskMode(_ mode: TaskMode, _ m: AppearanceMode, rc: RetroColor = .green) -> Color {
        if isRetro(m) { return retroPalette(rc).bright }
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
        case .system, .light: Color(.label)
        }
    }
    static func textSecondary(_ m: AppearanceMode, rc: RetroColor = .green) -> Color {
        switch m {
        case .retro: retroPalette(rc).dim
        case .dark: .white.opacity(0.6)
        case .system, .light: Color(.secondaryLabel)
        }
    }
    static func textTertiary(_ m: AppearanceMode, rc: RetroColor = .green) -> Color {
        switch m {
        case .retro: retroPalette(rc).faint
        case .dark: .white.opacity(0.35)
        case .system, .light: Color(.tertiaryLabel)
        }
    }

    // Card
    static func cardCornerRadius(_ m: AppearanceMode) -> CGFloat { isRetro(m) ? 2 : 12 }
    static func cardShadow(_ m: AppearanceMode, rc: RetroColor = .green) -> Color {
        switch m {
        case .retro: retroPalette(rc).glow.opacity(0.3)
        case .dark: .black.opacity(0.3)
        case .system, .light: .black.opacity(0.08)
        }
    }
    static func cardBorder(_ m: AppearanceMode, rc: RetroColor = .green) -> Color { isRetro(m) ? retroPalette(rc).dim : .clear }
    static func cardBorderWidth(_ m: AppearanceMode) -> CGFloat { isRetro(m) ? 1 : 0 }

    // Font
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
