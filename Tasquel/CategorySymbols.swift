import SwiftUI

// MARK: - Category Symbols

/// The icons offered for categories, with readable names for menus and VoiceOver.
enum CategorySymbols {
    static let options: [(symbol: String, name: String)] = [
        ("folder", "Folder"), ("star", "Star"), ("heart", "Heart"), ("house", "Home"),
        ("cart", "Shopping"), ("briefcase", "Work"), ("figure.run", "Exercise"),
        ("book", "Reading"), ("paintbrush", "Art"), ("music.note", "Music"),
        ("fork.knife", "Food"), ("airplane", "Travel"), ("gift", "Gift"),
        ("wrench.and.screwdriver", "Tools"), ("leaf", "Nature"), ("pawprint", "Pets"),
        ("calendar.badge.clock", "Appointments"), ("lightbulb", "Ideas"), ("sparkles", "Sparkles"),
    ]

    static func name(for symbol: String) -> String {
        options.first { $0.symbol == symbol }?.name ?? "Icon"
    }
}

/// A menu of category icons; its label is supplied by the caller.
struct CategorySymbolMenu<Label: View>: View {
    @Binding var symbol: String
    @ViewBuilder let label: () -> Label

    var body: some View {
        Menu {
            Picker("Icon", selection: $symbol) {
                ForEach(CategorySymbols.options, id: \.symbol) { option in
                    SwiftUI.Label(option.name, systemImage: option.symbol).tag(option.symbol)
                }
            }
        } label: {
            label()
        }
        .accessibilityLabel("Icon: \(CategorySymbols.name(for: symbol))")
    }
}
