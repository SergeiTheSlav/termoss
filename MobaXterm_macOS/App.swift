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
        }
    }
}

extension Notification.Name {
    static let openSettings = Notification.Name("openSettings")
}
