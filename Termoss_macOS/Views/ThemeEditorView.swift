import SwiftUI

/// Reusable theme editor used in global settings, session editor, and tab customization.
struct ThemeEditorView: View {
    @Binding var theme: TerminalTheme

    private let availableFonts = [
        "Menlo-Regular", "Monaco", "SF Mono", "Courier New",
        "Andale Mono", "Fira Code", "JetBrains Mono", "Source Code Pro"
    ]

    private let fontWeights = ["light", "regular", "medium", "semibold", "bold"]

    var body: some View {
        Form {
            // MARK: Font
            Section("Font") {
                Picker("Family", selection: $theme.fontName) {
                    ForEach(availableFonts, id: \.self) { font in
                        Text(font).tag(font)
                    }
                }

                HStack {
                    Text("Size")
                    Spacer()
                    Text("\(Int(theme.fontSize)) pt")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 50)
                    Stepper("", value: $theme.fontSize, in: 8...32, step: 1)
                        .labelsHidden()
                }

                Picker("Weight", selection: $theme.fontWeight) {
                    ForEach(fontWeights, id: \.self) { w in
                        Text(w.capitalized).tag(w)
                    }
                }
            }

            // MARK: Colors
            Section("Colors") {
                ThemeColorRow(label: "Background", hex: $theme.backgroundColorHex)
                ThemeColorRow(label: "Foreground", hex: $theme.foregroundColorHex)
                ThemeColorRow(label: "Cursor", hex: $theme.caretColorHex)
                ThemeColorRow(label: "Selection", hex: $theme.selectionColorHex)
            }

            // MARK: ANSI Colors
            Section("ANSI Colors") {
                LazyVGrid(columns: [
                    GridItem(.flexible()), GridItem(.flexible()),
                    GridItem(.flexible()), GridItem(.flexible())
                ], spacing: 8) {
                    AnsiColorCell(label: "Black",   hex: $theme.ansiBlack)
                    AnsiColorCell(label: "Red",     hex: $theme.ansiRed)
                    AnsiColorCell(label: "Green",   hex: $theme.ansiGreen)
                    AnsiColorCell(label: "Yellow",  hex: $theme.ansiYellow)
                    AnsiColorCell(label: "Blue",    hex: $theme.ansiBlue)
                    AnsiColorCell(label: "Magenta", hex: $theme.ansiMagenta)
                    AnsiColorCell(label: "Cyan",    hex: $theme.ansiCyan)
                    AnsiColorCell(label: "White",   hex: $theme.ansiWhite)
                }

                Text("Bright").font(.system(size: 11)).foregroundStyle(.secondary).padding(.top, 4)

                LazyVGrid(columns: [
                    GridItem(.flexible()), GridItem(.flexible()),
                    GridItem(.flexible()), GridItem(.flexible())
                ], spacing: 8) {
                    AnsiColorCell(label: "Black",   hex: $theme.ansiBrightBlack)
                    AnsiColorCell(label: "Red",     hex: $theme.ansiBrightRed)
                    AnsiColorCell(label: "Green",   hex: $theme.ansiBrightGreen)
                    AnsiColorCell(label: "Yellow",  hex: $theme.ansiBrightYellow)
                    AnsiColorCell(label: "Blue",    hex: $theme.ansiBrightBlue)
                    AnsiColorCell(label: "Magenta", hex: $theme.ansiBrightMagenta)
                    AnsiColorCell(label: "Cyan",    hex: $theme.ansiBrightCyan)
                    AnsiColorCell(label: "White",   hex: $theme.ansiBrightWhite)
                }
            }

            // MARK: Preview
            Section("Preview") {
                ThemePreview(theme: theme)
                    .frame(height: 60)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Color Row

struct ThemeColorRow: View {
    let label: String
    @Binding var hex: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            ColorPicker("", selection: colorBinding, supportsOpacity: false)
                .labelsHidden()
            TextField("", text: $hex)
                .frame(width: 80)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11, design: .monospaced))
        }
    }

    private var colorBinding: Binding<Color> {
        Binding(
            get: { Color(hex: hex) },
            set: { hex = $0.toHex() }
        )
    }
}

// MARK: - ANSI Color Cell

struct AnsiColorCell: View {
    let label: String
    @Binding var hex: String

    var body: some View {
        VStack(spacing: 2) {
            ColorPicker("", selection: colorBinding, supportsOpacity: false)
                .labelsHidden()
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
    }

    private var colorBinding: Binding<Color> {
        Binding(
            get: { Color(hex: hex) },
            set: { hex = $0.toHex() }
        )
    }
}

// MARK: - Live Preview

struct ThemePreview: View {
    let theme: TerminalTheme

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(hex: theme.backgroundColorHex))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 0) {
                    Text("user@host ")
                        .foregroundColor(Color(hex: theme.ansiGreen))
                    Text("~ % ")
                        .foregroundColor(Color(hex: theme.foregroundColorHex))
                    Text("ls")
                        .foregroundColor(Color(hex: theme.foregroundColorHex))
                }
                HStack(spacing: 8) {
                    Text("Documents")
                        .foregroundColor(Color(hex: theme.ansiBlue))
                    Text("file.txt")
                        .foregroundColor(Color(hex: theme.foregroundColorHex))
                    Text("error.log")
                        .foregroundColor(Color(hex: theme.ansiRed))
                }
            }
            .font(.system(size: CGFloat(theme.fontSize), design: .monospaced))
            .padding(8)
        }
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}
