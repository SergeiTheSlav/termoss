import SwiftUI

/// A full terminal theme: font, colors, and ANSI color palette.
struct TerminalTheme: Codable, Equatable, Hashable {
    var name: String

    // Font
    var fontName: String
    var fontSize: CGFloat
    var fontWeight: String // "regular", "medium", "bold", "light"

    // Colors
    var backgroundColorHex: String
    var foregroundColorHex: String
    var caretColorHex: String
    var selectionColorHex: String

    // ANSI 16-color palette (optional override)
    var ansiBlack: String
    var ansiRed: String
    var ansiGreen: String
    var ansiYellow: String
    var ansiBlue: String
    var ansiMagenta: String
    var ansiCyan: String
    var ansiWhite: String
    var ansiBrightBlack: String
    var ansiBrightRed: String
    var ansiBrightGreen: String
    var ansiBrightYellow: String
    var ansiBrightBlue: String
    var ansiBrightMagenta: String
    var ansiBrightCyan: String
    var ansiBrightWhite: String

    /// The built-in default — matches the current app look exactly.
    static let defaultDark = TerminalTheme(
        name: "Main Theme: Dark",
        fontName: "Menlo-Regular",
        fontSize: 12,
        fontWeight: "regular",
        backgroundColorHex: "#252932",
        foregroundColorHex: "#FFFFFF",
        caretColorHex: "#CCCCCC",
        selectionColorHex: "#4073D9",
        ansiBlack:         "#1D2028",
        ansiRed:           "#FF5F56",
        ansiGreen:         "#5AF78E",
        ansiYellow:        "#F3F99D",
        ansiBlue:          "#57C7FF",
        ansiMagenta:       "#FF6AC1",
        ansiCyan:          "#9AEDFE",
        ansiWhite:         "#F1F1F0",
        ansiBrightBlack:   "#686868",
        ansiBrightRed:     "#FF6E67",
        ansiBrightGreen:   "#5AF78E",
        ansiBrightYellow:  "#F4F99D",
        ansiBrightBlue:    "#6CBEFF",
        ansiBrightMagenta: "#FF77DD",
        ansiBrightCyan:    "#9AEDFE",
        ansiBrightWhite:   "#FFFFFF"
    )
}

// MARK: - Color conversion helpers

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255.0
            g = Double((int >> 8)  & 0xFF) / 255.0
            b = Double(int         & 0xFF) / 255.0
        default:
            r = 1; g = 1; b = 1
        }
        self.init(red: r, green: g, blue: b)
    }

    func toHex() -> String {
        guard let c = NSColor(self).usingColorSpace(.sRGB) else { return "#FFFFFF" }
        return String(format: "#%02X%02X%02X",
                      Int(c.redComponent * 255),
                      Int(c.greenComponent * 255),
                      Int(c.blueComponent * 255))
    }
}

extension NSColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: CGFloat
        switch hex.count {
        case 6:
            r = CGFloat((int >> 16) & 0xFF) / 255.0
            g = CGFloat((int >> 8)  & 0xFF) / 255.0
            b = CGFloat(int         & 0xFF) / 255.0
        default:
            r = 1; g = 1; b = 1
        }
        self.init(srgbRed: r, green: g, blue: b, alpha: 1.0)
    }
}

extension NSFont.Weight {
    init(named: String) {
        switch named.lowercased() {
        case "light":     self = .light
        case "medium":    self = .medium
        case "bold":      self = .bold
        case "semibold":  self = .semibold
        default:          self = .regular
        }
    }
}
