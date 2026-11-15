import UIKit

// MARK: - Swapping a UIKit method

/// Swaps `original` on `type` for `replacement` (both on `type`), so calling `replacement`
/// afterwards calls the original. If `type` only inherits `original`, it's given its own
/// copy first, so the class it inherits from (every responder, for `keyCommands`) is left
/// alone. Used for the two text-field behaviors below that SwiftUI has no setting for.
enum MethodSwap {
    static func exchange(_ type: AnyClass, _ original: Selector, _ replacement: Selector) {
        guard let originalMethod = class_getInstanceMethod(type, original),
              let replacementMethod = class_getInstanceMethod(type, replacement) else { return }
        if class_addMethod(type, original, method_getImplementation(replacementMethod), method_getTypeEncoding(replacementMethod)) {
            class_replaceMethod(type, replacement, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod))
        } else {
            method_exchangeImplementations(originalMethod, replacementMethod)
        }
    }
}

// MARK: - Escape

/// Escape on a hardware keyboard, in any text field: posted as `pressed`, so the rename
/// field that has the keyboard can put the old name back. SwiftUI's key handlers
/// (`onKeyPress`, a cancel-shortcut button) never heard it in a wrapping field, a text
/// view underneath; a key command on the field itself, put ahead of the system's handling,
/// does. `install` adds it once at launch. Apple-only, like any UIKit behavior.
enum EscapeKey {
    static let pressed = Notification.Name("TasquelEscapeKeyPressed")
    private static var isInstalled = false

    static func install() {
        guard !isInstalled else { return }
        isInstalled = true
        MethodSwap.exchange(UITextView.self, #selector(getter: UIResponder.keyCommands), #selector(UITextView.escapeKeyCommands))
        MethodSwap.exchange(UITextField.self, #selector(getter: UIResponder.keyCommands), #selector(UITextField.escapeKeyCommands))
    }

    static func command(action: Selector) -> UIKeyCommand {
        let command = UIKeyCommand(input: UIKeyCommand.inputEscape, modifierFlags: [], action: action)
        command.wantsPriorityOverSystemBehavior = true
        return command
    }
}

extension UITextView {
    /// After `EscapeKey.install`, this is `keyCommands`: UIKit's, plus Escape.
    @objc fileprivate func escapeKeyCommands() -> [UIKeyCommand]? {
        (escapeKeyCommands() ?? []) + [EscapeKey.command(action: #selector(escapePressed))]
    }

    @objc func escapePressed() {
        NotificationCenter.default.post(name: EscapeKey.pressed, object: self)
    }
}

extension UITextField {
    /// After `EscapeKey.install`, this is `keyCommands`: UIKit's, plus Escape.
    @objc fileprivate func escapeKeyCommands() -> [UIKeyCommand]? {
        (escapeKeyCommands() ?? []) + [EscapeKey.command(action: #selector(escapePressed))]
    }

    @objc func escapePressed() {
        NotificationCenter.default.post(name: EscapeKey.pressed, object: self)
    }
}

