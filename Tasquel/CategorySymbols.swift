import SwiftUI
import UIKit

// MARK: - Category Symbols

/// The icons offered for categories, with readable names for menus and VoiceOver.
/// A category's `symbol` is either one of these SF Symbol names or a single emoji.
enum CategorySymbols {
    static let options: [(symbol: String, name: String)] = [
        ("folder", "Folder"), ("star", "Star"), ("heart", "Heart"), ("house", "Home"),
        ("cart", "Shopping"), ("briefcase", "Work"), ("figure.run", "Exercise"),
        ("book", "Reading"), ("paintbrush", "Art"), ("music.note", "Music"),
        ("fork.knife", "Food"), ("airplane", "Travel"), ("gift", "Gift"),
        ("wrench.and.screwdriver", "Tools"), ("leaf", "Nature"), ("pawprint", "Pets"),
        ("calendar.badge.clock", "Appointments"), ("lightbulb", "Ideas"), ("sparkles", "Sparkles"),
    ]

    /// An emoji's own character is its name: VoiceOver reads it out.
    static func name(for symbol: String) -> String {
        if isEmoji(symbol) { return symbol }
        return options.first { $0.symbol == symbol }?.name ?? "Icon"
    }

    /// Whether `symbol` is a single emoji rather than an SF Symbol name (those are plain
    /// ASCII). Plain digits and `#` count as emoji in Unicode, so a character only counts
    /// when it's drawn as emoji by default or asks to be (U+FE0F).
    static func isEmoji(_ symbol: String) -> Bool {
        guard symbol.count == 1 else { return false }
        return symbol.unicodeScalars.contains { $0.properties.isEmojiPresentation || $0.value == 0xFE0F }
    }
}

/// A category's icon: its SF Symbol, or its emoji as text. Fonts apply to both.
struct CategoryIcon: View {
    let symbol: String

    var body: some View {
        if CategorySymbols.isEmoji(symbol) {
            Text(symbol)
        } else {
            Image(systemName: symbol)
        }
    }
}

/// A menu of category icons, plus a choice of any emoji; its label is supplied by the caller.
struct CategorySymbolMenu<Label: View>: View {
    @Binding var symbol: String
    @ViewBuilder let label: () -> Label
    @State private var isChoosingEmoji = false
    /// The picker of the sheet this menu is in (see `emojiPickerHost`); without one the
    /// menu shows the picker itself.
    @Environment(\.emojiPicker) private var emojiPicker
    /// A sheet doesn't inherit the app's appearance setting, so it's passed on.
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Menu {
            Button {
                // The field with the keyboard lets it go first. Otherwise iOS hands it back as
                // the picker closes and takes it away again a moment later, so the sheet below
                // jumped up with the keyboard and dropped back down.
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                if let emojiPicker {
                    let symbol = $symbol
                    emojiPicker { symbol.wrappedValue = $0 }
                } else {
                    isChoosingEmoji = true
                }
            } label: {
                SwiftUI.Label("Choose Emoji…", systemImage: "face.smiling")
            }
            Divider()
            Picker("Icon", selection: $symbol) {
                ForEach(CategorySymbols.options, id: \.symbol) { option in
                    SwiftUI.Label(option.name, systemImage: option.symbol).tag(option.symbol)
                }
            }
        } label: {
            label()
        }
        .accessibilityLabel("Icon: \(CategorySymbols.name(for: symbol))")
        .sheet(isPresented: $isChoosingEmoji) {
            EmojiPickerSheet { symbol = $0 }
                .preferredColorScheme(colorScheme)
        }
    }
}

// MARK: - Emoji Picker

extension View {
    /// Shows the emoji picker for the icon menus inside this view from here rather than from
    /// the menu. For a sheet whose icon menus sit in List or Form rows: the List removes and
    /// rebuilds rows while another sheet opens over it, and a picker shown from a row was
    /// rebuilt with it (three times as it opened), each new emoji field taking the keyboard
    /// down and up again.
    func emojiPickerHost() -> some View {
        modifier(EmojiPickerHost())
    }
}

extension EnvironmentValues {
    /// Set by `emojiPickerHost`.
    @Entry var emojiPicker: EmojiPickerAction? = nil
}

/// Opens the emoji picker; the emoji chosen goes to `onPick`.
struct EmojiPickerAction {
    fileprivate let open: (@escaping (String) -> Void) -> Void

    func callAsFunction(onPick: @escaping (String) -> Void) { open(onPick) }
}

private struct EmojiPickerHost: ViewModifier {
    @State private var request: Request?
    /// A sheet doesn't inherit the app's appearance setting, so it's passed on.
    @Environment(\.colorScheme) private var colorScheme

    private struct Request: Identifiable {
        let id = UUID()
        let onPick: (String) -> Void
    }

    func body(content: Content) -> some View {
        content
            .environment(\.emojiPicker, EmojiPickerAction { request = Request(onPick: $0) })
            .sheet(item: $request) { request in
                EmojiPickerSheet(onPick: request.onPick)
                    .preferredColorScheme(colorScheme)
            }
    }
}

/// Opens with the emoji keyboard up; the first emoji typed becomes the icon.
private struct EmojiPickerSheet: View {
    let onPick: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                EmojiField { emoji in
                    onPick(emoji)
                    dismiss()
                }
                .frame(width: 72, height: 72)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 16))
                Text("Pick an emoji from the keyboard.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.top, 8)
            .frame(maxWidth: .infinity)
            .navigationTitle("Emoji Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
            }
        }
        .presentationDetents([.height(200)])
    }
}

/// A text field that asks for the emoji keyboard and reports each emoji typed.
/// SwiftUI's TextField can't choose a keyboard, so this wraps UITextField.
private struct EmojiField: UIViewRepresentable {
    let onPick: (String) -> Void

    func makeUIView(context: Context) -> EmojiTextField {
        let field = EmojiTextField()
        field.font = .systemFont(ofSize: 44)
        field.textAlignment = .center
        field.tintColor = .clear
        field.accessibilityLabel = "Emoji"
        field.addTarget(context.coordinator, action: #selector(Coordinator.textChanged(_:)), for: .editingChanged)
        DispatchQueue.main.async { field.becomeFirstResponder() }
        return field
    }

    func updateUIView(_ field: EmojiTextField, context: Context) {
        context.coordinator.onPick = onPick
    }

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject {
        var onPick: (String) -> Void

        init(onPick: @escaping (String) -> Void) { self.onPick = onPick }

        @objc func textChanged(_ field: UITextField) {
            guard let typed = field.text?.last.map(String.init), CategorySymbols.isEmoji(typed) else {
                field.text = ""
                return
            }
            field.text = typed
            onPick(typed)
        }
    }
}

final class EmojiTextField: UITextField {
    /// Opens on the emoji keyboard, when the user has it turned on.
    override var textInputMode: UITextInputMode? {
        UITextInputMode.activeInputModes.first { $0.primaryLanguage == "emoji" } ?? super.textInputMode
    }
}
