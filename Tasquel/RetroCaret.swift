import UIKit

/// Retro's text cursor: a blinking underscore one character wide, as in DOS, instead of the
/// thin bar, in every text field while Retro is on (`isOn`, kept by ContentView). SwiftUI's
/// text fields are UIKit's underneath, and UIKit draws the cursor where `caretRect(for:)`
/// says, so `install` swaps that method once at launch for one that answers differently
/// only in Retro. Apple-only, like any UIKit look; nothing else depends on it.
enum RetroCaret {
    static var isOn = false
    private static var isInstalled = false

    static func install() {
        guard !isInstalled else { return }
        isInstalled = true
        MethodSwap.exchange(UITextView.self, #selector(UITextView.caretRect(for:)), #selector(UITextView.retroCaretRect(for:)))
        MethodSwap.exchange(UITextField.self, #selector(UITextField.caretRect(for:)), #selector(UITextField.retroCaretRect(for:)))
    }

    /// The underscore in the character cell where the bar would stand: as wide as a character
    /// (Retro's fonts are monospaced) and about an eighth of the line high, at the line's
    /// bottom. Outside Retro, the bar as it was.
    static func cursor(replacing bar: CGRect, font: UIFont?) -> CGRect {
        guard isOn, let font, bar.height > 0, bar.width < bar.height else { return bar }
        let width = ("M" as NSString).size(withAttributes: [.font: font]).width.rounded(.up)
        let height = max(2, (font.lineHeight * 0.13).rounded())
        return CGRect(x: bar.minX, y: bar.maxY - height, width: width, height: height)
    }
}

extension UITextView {
    /// After `RetroCaret.install`, this is `caretRect(for:)`, and calling it calls UIKit's.
    @objc fileprivate func retroCaretRect(for position: UITextPosition) -> CGRect {
        RetroCaret.cursor(replacing: retroCaretRect(for: position), font: font ?? typingAttributes[.font] as? UIFont)
    }
}

extension UITextField {
    /// After `RetroCaret.install`, this is `caretRect(for:)`, and calling it calls UIKit's.
    @objc fileprivate func retroCaretRect(for position: UITextPosition) -> CGRect {
        RetroCaret.cursor(replacing: retroCaretRect(for: position), font: font ?? defaultTextAttributes[.font] as? UIFont)
    }
}
