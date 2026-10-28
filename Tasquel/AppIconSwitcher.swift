import UIKit

// MARK: - App Icon

/// The home-screen icon can follow the theme (Settings ▸ Appearance ▸ Match App Icon to
/// Theme, on by default): the retro icon (`AppIconRetro`, phosphor green on black) while
/// Retro is chosen, the standard icon otherwise. iOS confirms each change with its own
/// short alert; that can't be hidden. Called only from Settings, so two iPad windows never
/// switch it at once.
enum AppIconSwitcher {
    static let retroIconName = "AppIconRetro"
    /// UserDefaults key for the Settings switch.
    static let matchesThemeKey = "matchAppIconToTheme"

    static var isSupported: Bool { UIApplication.shared.supportsAlternateIcons }

    static func update(for mode: AppearanceMode, matchingTheme: Bool) {
        let wanted = matchingTheme && mode == .retro ? retroIconName : nil
        let app = UIApplication.shared
        guard app.supportsAlternateIcons, app.alternateIconName != wanted else { return }
        Task {
            do {
                try await app.setAlternateIconName(wanted)
            } catch {
                // iOS can refuse a change that comes too soon after another ("resource
                // temporarily unavailable"): try once more.
                try? await Task.sleep(for: .seconds(1))
                guard app.alternateIconName != wanted else { return }
                try? await app.setAlternateIconName(wanted)
            }
        }
    }
}
