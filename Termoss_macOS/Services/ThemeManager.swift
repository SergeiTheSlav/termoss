import SwiftUI

class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    /// The global theme applied everywhere by default.
    @Published var globalTheme: TerminalTheme {
        didSet { persistGlobal() }
    }

    /// Library of saved themes (includes built-ins + user-created).
    @Published var savedThemes: [TerminalTheme] {
        didSet { persistThemes() }
    }

    /// Per-tab theme overrides (keyed by tab UUID).
    @Published var tabOverrides: [UUID: TerminalTheme] = [:]

    private let globalKey = "globalTerminalTheme"
    private let themesKey = "savedTerminalThemes"

    private init() {
        // Load global
        if let data = UserDefaults.standard.data(forKey: globalKey),
           let theme = try? JSONDecoder().decode(TerminalTheme.self, from: data) {
            self.globalTheme = theme
        } else {
            self.globalTheme = .defaultDark
        }

        // Load saved themes
        if let data = UserDefaults.standard.data(forKey: themesKey),
           let themes = try? JSONDecoder().decode([TerminalTheme].self, from: data) {
            // Ensure built-in is always present
            var loaded = themes
            if !loaded.contains(where: { $0.name == TerminalTheme.defaultDark.name }) {
                loaded.insert(.defaultDark, at: 0)
            }
            self.savedThemes = loaded
        } else {
            self.savedThemes = Self.builtInThemes
        }
    }

    // MARK: - Built-in themes

    static let builtInThemes: [TerminalTheme] = [
        .defaultDark,
        TerminalTheme(
            name: "Solarized Dark",
            fontName: "Menlo-Regular", fontSize: 12, fontWeight: "regular",
            backgroundColorHex: "#002B36", foregroundColorHex: "#839496",
            caretColorHex: "#93A1A1", selectionColorHex: "#073642",
            ansiBlack: "#073642", ansiRed: "#DC322F", ansiGreen: "#859900", ansiYellow: "#B58900",
            ansiBlue: "#268BD2", ansiMagenta: "#D33682", ansiCyan: "#2AA198", ansiWhite: "#EEE8D5",
            ansiBrightBlack: "#586E75", ansiBrightRed: "#CB4B16", ansiBrightGreen: "#586E75",
            ansiBrightYellow: "#657B83", ansiBrightBlue: "#839496", ansiBrightMagenta: "#6C71C4",
            ansiBrightCyan: "#93A1A1", ansiBrightWhite: "#FDF6E3"
        ),
        TerminalTheme(
            name: "Monokai",
            fontName: "Menlo-Regular", fontSize: 12, fontWeight: "regular",
            backgroundColorHex: "#272822", foregroundColorHex: "#F8F8F2",
            caretColorHex: "#F8F8F0", selectionColorHex: "#49483E",
            ansiBlack: "#272822", ansiRed: "#F92672", ansiGreen: "#A6E22E", ansiYellow: "#F4BF75",
            ansiBlue: "#66D9EF", ansiMagenta: "#AE81FF", ansiCyan: "#A1EFE4", ansiWhite: "#F8F8F2",
            ansiBrightBlack: "#75715E", ansiBrightRed: "#F92672", ansiBrightGreen: "#A6E22E",
            ansiBrightYellow: "#F4BF75", ansiBrightBlue: "#66D9EF", ansiBrightMagenta: "#AE81FF",
            ansiBrightCyan: "#A1EFE4", ansiBrightWhite: "#F9F8F5"
        ),
        TerminalTheme(
            name: "Nord",
            fontName: "Menlo-Regular", fontSize: 12, fontWeight: "regular",
            backgroundColorHex: "#2E3440", foregroundColorHex: "#D8DEE9",
            caretColorHex: "#D8DEE9", selectionColorHex: "#434C5E",
            ansiBlack: "#3B4252", ansiRed: "#BF616A", ansiGreen: "#A3BE8C", ansiYellow: "#EBCB8B",
            ansiBlue: "#81A1C1", ansiMagenta: "#B48EAD", ansiCyan: "#88C0D0", ansiWhite: "#E5E9F0",
            ansiBrightBlack: "#4C566A", ansiBrightRed: "#BF616A", ansiBrightGreen: "#A3BE8C",
            ansiBrightYellow: "#EBCB8B", ansiBrightBlue: "#81A1C1", ansiBrightMagenta: "#B48EAD",
            ansiBrightCyan: "#8FBCBB", ansiBrightWhite: "#ECEFF4"
        ),
        TerminalTheme(
            name: "Dracula",
            fontName: "Menlo-Regular", fontSize: 12, fontWeight: "regular",
            backgroundColorHex: "#282A36", foregroundColorHex: "#F8F8F2",
            caretColorHex: "#F8F8F2", selectionColorHex: "#44475A",
            ansiBlack: "#21222C", ansiRed: "#FF5555", ansiGreen: "#50FA7B", ansiYellow: "#F1FA8C",
            ansiBlue: "#BD93F9", ansiMagenta: "#FF79C6", ansiCyan: "#8BE9FD", ansiWhite: "#F8F8F2",
            ansiBrightBlack: "#6272A4", ansiBrightRed: "#FF6E6E", ansiBrightGreen: "#69FF94",
            ansiBrightYellow: "#FFFFA5", ansiBrightBlue: "#D6ACFF", ansiBrightMagenta: "#FF92DF",
            ansiBrightCyan: "#A4FFFF", ansiBrightWhite: "#FFFFFF"
        ),
        TerminalTheme(
            name: "Gruvbox Dark",
            fontName: "Menlo-Regular", fontSize: 12, fontWeight: "regular",
            backgroundColorHex: "#282828", foregroundColorHex: "#EBDBB2",
            caretColorHex: "#EBDBB2", selectionColorHex: "#3C3836",
            ansiBlack: "#282828", ansiRed: "#CC241D", ansiGreen: "#98971A", ansiYellow: "#D79921",
            ansiBlue: "#458588", ansiMagenta: "#B16286", ansiCyan: "#689D6A", ansiWhite: "#A89984",
            ansiBrightBlack: "#928374", ansiBrightRed: "#FB4934", ansiBrightGreen: "#B8BB26",
            ansiBrightYellow: "#FABD2F", ansiBrightBlue: "#83A598", ansiBrightMagenta: "#D3869B",
            ansiBrightCyan: "#8EC07C", ansiBrightWhite: "#EBDBB2"
        ),
    ]

    // MARK: - Saved theme management

    func saveTheme(_ theme: TerminalTheme) {
        if let index = savedThemes.firstIndex(where: { $0.name == theme.name }) {
            savedThemes[index] = theme
        } else {
            savedThemes.append(theme)
        }
    }

    func deleteTheme(named name: String) {
        // Don't allow deleting the built-in default
        guard name != TerminalTheme.defaultDark.name else { return }
        savedThemes.removeAll { $0.name == name }
    }

    // MARK: - Resolution

    func resolvedTheme(for tab: TabItem) -> TerminalTheme {
        if let tabTheme = tabOverrides[tab.id] {
            return tabTheme
        }
        if let config = tab.sessionConfig, let sessionTheme = config.themeOverride {
            return sessionTheme
        }
        return globalTheme
    }

    func resolvedTheme(for config: SSHSessionConfig) -> TerminalTheme {
        if let sessionTheme = config.themeOverride {
            return sessionTheme
        }
        return globalTheme
    }

    // MARK: - Tab overrides

    func setTabOverride(_ theme: TerminalTheme, for tabID: UUID) {
        tabOverrides[tabID] = theme
    }

    func clearTabOverride(for tabID: UUID) {
        tabOverrides.removeValue(forKey: tabID)
    }

    // MARK: - Persistence

    private func persistGlobal() {
        if let data = try? JSONEncoder().encode(globalTheme) {
            UserDefaults.standard.set(data, forKey: globalKey)
        }
    }

    private func persistThemes() {
        if let data = try? JSONEncoder().encode(savedThemes) {
            UserDefaults.standard.set(data, forKey: themesKey)
        }
    }
}
