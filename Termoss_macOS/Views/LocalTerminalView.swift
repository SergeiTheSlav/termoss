import SwiftUI
import SwiftTerm

/// Wrapper NSView that adds padding around the terminal so text
/// doesn't render flush against the window edges.
class PaddedTerminalContainer: NSView {
    let terminalView: LocalProcessTerminalView
    let padding: CGFloat = 6
    private var bgColor: NSColor

    init(terminalView: LocalProcessTerminalView, backgroundColor: NSColor) {
        self.terminalView = terminalView
        self.bgColor = backgroundColor
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = bgColor.cgColor
        addSubview(terminalView)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        terminalView.frame = bounds.insetBy(dx: padding, dy: padding)
    }

    override func updateLayer() {
        layer?.backgroundColor = bgColor.cgColor
    }

    func updateBackgroundColor(_ color: NSColor) {
        bgColor = color
        layer?.backgroundColor = color.cgColor
    }
}

struct LocalTerminalView: NSViewRepresentable {
    let sshConfig: SSHSessionConfig?
    let theme: TerminalTheme

    init(sshConfig: SSHSessionConfig? = nil, theme: TerminalTheme = .defaultDark) {
        self.sshConfig = sshConfig
        self.theme = theme
    }

    func makeNSView(context: Context) -> PaddedTerminalContainer {
        let terminalView = LocalProcessTerminalView(frame: .zero)

        applyTheme(theme, to: terminalView)

        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"

        if let config = sshConfig {
            let password = KeychainService.getPassword(for: config.id)

            if let password = password, !password.isEmpty {
                let scriptPath = Self.createAskpassScript(password: password)
                let sshCmd = "SSH_ASKPASS='\(scriptPath)' SSH_ASKPASS_REQUIRE=force ssh -o StrictHostKeyChecking=accept-new -p \(config.port) \(config.username)@\(config.host) ; rm -f '\(scriptPath)'"
                terminalView.startProcess(
                    executable: shell,
                    args: ["-l", "-c", sshCmd],
                    environment: nil,
                    execName: nil
                )
                DispatchQueue.global().asyncAfter(deadline: .now() + 30) {
                    try? FileManager.default.removeItem(atPath: scriptPath)
                }
            } else {
                let sshCmd = "ssh -p \(config.port) \(config.username)@\(config.host)"
                terminalView.startProcess(
                    executable: shell,
                    args: ["-l", "-c", sshCmd],
                    environment: nil,
                    execName: nil
                )
            }
        } else {
            terminalView.startProcess(
                executable: shell,
                args: [], environment: nil, execName: nil
            )
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            terminalView.window?.makeFirstResponder(terminalView)
        }

        let terminalBg = NSColor(hex: theme.backgroundColorHex)
        return PaddedTerminalContainer(terminalView: terminalView, backgroundColor: terminalBg)
    }

    func updateNSView(_ nsView: PaddedTerminalContainer, context: Context) {
        // Update colors when theme changes (without restarting the process)
        let bg = NSColor(hex: theme.backgroundColorHex)
        nsView.updateBackgroundColor(bg)
        nsView.terminalView.nativeBackgroundColor = bg
        nsView.terminalView.nativeForegroundColor = NSColor(hex: theme.foregroundColorHex)
        nsView.terminalView.caretColor = NSColor(hex: theme.caretColorHex)

        // Update font
        let weight = NSFont.Weight(named: theme.fontWeight)
        if let font = NSFont(name: theme.fontName, size: theme.fontSize) {
            nsView.terminalView.font = font
        } else {
            nsView.terminalView.font = NSFont.monospacedSystemFont(ofSize: theme.fontSize, weight: weight)
        }
    }

    private func applyTheme(_ theme: TerminalTheme, to tv: LocalProcessTerminalView) {
        // Font
        let weight = NSFont.Weight(named: theme.fontWeight)
        if let font = NSFont(name: theme.fontName, size: theme.fontSize) {
            tv.font = font
        } else {
            tv.font = NSFont.monospacedSystemFont(ofSize: theme.fontSize, weight: weight)
        }

        // Colors
        tv.nativeBackgroundColor = NSColor(hex: theme.backgroundColorHex)
        tv.nativeForegroundColor = NSColor(hex: theme.foregroundColorHex)
        tv.caretColor = NSColor(hex: theme.caretColorHex)
        tv.selectedTextBackgroundColor = NSColor(hex: theme.selectionColorHex).withAlphaComponent(0.55)
    }

    private static func createAskpassScript(password: String) -> String {
        let scriptPath = NSTemporaryDirectory() + "moba_askpass_\(UUID().uuidString).sh"
        let escaped = password.replacingOccurrences(of: "'", with: "'\\''")
        let script = "#!/bin/sh\necho '\(escaped)'\n"
        try? script.write(toFile: scriptPath, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o700], ofItemAtPath: scriptPath
        )
        return scriptPath
    }
}

struct TerminalContainer: View {
    let tab: TabItem
    @ObservedObject var themeManager = ThemeManager.shared

    private var resolvedTheme: TerminalTheme {
        themeManager.resolvedTheme(for: tab)
    }

    var body: some View {
        LocalTerminalView(sshConfig: tab.sessionConfig, theme: resolvedTheme)
            .id(tab.id)
    }
}
