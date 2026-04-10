import SwiftUI

@main
struct TermossApp: App {
    @StateObject private var sessionManager = SessionManager()
    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(sessionManager)
                .environmentObject(themeManager)
                .frame(minWidth: 900, minHeight: 600)
                .onAppear {
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(after: .appSettings) {
                Button("Settings…") {
                    NotificationCenter.default.post(name: .openSettings, object: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            CommandMenu("Extras") {
                PlanarityMenuButton()
                ColourMenuButton()
                SoundMenuButton()
            }
        }

        Window("Planarity", id: "planarity") {
            PlanarityView()
                .frame(minWidth: 720, minHeight: 640)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 860, height: 760)

        Window("Colour", id: "colour") {
            ColourGameView()
                .frame(minWidth: 480, minHeight: 520)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 520, height: 600)

        Window("Sound", id: "sound") {
            SoundGameView()
                .frame(minWidth: 480, minHeight: 500)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 520, height: 580)
    }
}

private struct PlanarityMenuButton: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Planarity") {
            openWindow(id: "planarity")
        }
        .keyboardShortcut("p", modifiers: [.command, .shift])
    }
}

private struct ColourMenuButton: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Colour") {
            openWindow(id: "colour")
        }
        .keyboardShortcut("l", modifiers: [.command, .shift])
    }
}

private struct SoundMenuButton: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Sound") {
            openWindow(id: "sound")
        }
        .keyboardShortcut("s", modifiers: [.command, .shift])
    }
}

extension Notification.Name {
    static let openSettings = Notification.Name("openSettings")
}
