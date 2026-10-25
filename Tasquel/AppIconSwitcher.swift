import UIKit

// MARK: - App Icon

/// The home-screen icon follows the theme: the retro icon (`AppIconRetro`, phosphor green
/// on black) while Retro is chosen, the standard icon otherwise. iOS confirms each change
/// with its own short alert; that can't be hidden.
enum AppIconSwitcher {
    static let retroIconName = "AppIconRetro"

    static func update(for mode: AppearanceMode) {
        let wanted = mode == .retro ? retroIconName : nil
        let app = UIApplication.shared
        guard app.supportsAlternateIcons, app.alternateIconName != wanted else { return }
        app.setAlternateIconName(wanted)
    }
}
