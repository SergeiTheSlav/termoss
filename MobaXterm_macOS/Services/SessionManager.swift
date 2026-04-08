import SwiftUI

class SessionManager: ObservableObject {
    // MARK: - Saved Sessions
    @Published var savedSessions: [SSHSessionConfig] = [] {
        didSet { persistSessions() }
    }

    // MARK: - Tabs
    @Published var tabs: [TabItem] = []
    @Published var activeTabID: UUID?

    private let sessionsKey = "savedSSHSessions"

    init() {
        loadSessions()
        // Start with one local terminal tab
        let initialTab = TabItem()
        tabs = [initialTab]
        activeTabID = initialTab.id
    }

    // MARK: - Tab Management

    func newLocalTab() {
        let tab = TabItem(title: "Local Terminal", type: .local)
        withAnimation(.easeOut(duration: 0.2)) {
            tabs.append(tab)
            activeTabID = tab.id
        }
    }

    func newSSHTab(config: SSHSessionConfig) {
        let tab = TabItem(
            title: config.displayName,
            type: .ssh,
            sessionConfig: config
        )
        withAnimation(.easeOut(duration: 0.2)) {
            tabs.append(tab)
            activeTabID = tab.id
        }

        // Update last connected
        if let index = savedSessions.firstIndex(where: { $0.id == config.id }) {
            savedSessions[index].lastConnected = Date()
        }
    }

    func closeTab(_ tabID: UUID) {
        guard tabs.count > 1 else { return }

        if let index = tabs.firstIndex(where: { $0.id == tabID }) {
            withAnimation(.easeOut(duration: 0.2)) {
                tabs.remove(at: index)

                if activeTabID == tabID {
                    let newIndex = min(index, tabs.count - 1)
                    activeTabID = tabs[newIndex].id
                }
            }
        }
    }

    func renameTab(_ tabID: UUID, to newTitle: String) {
        if let index = tabs.firstIndex(where: { $0.id == tabID }) {
            tabs[index].title = newTitle
        }
    }

    // MARK: - Session Persistence

    func addSession(_ session: SSHSessionConfig) {
        savedSessions.append(session)
    }

    func deleteSession(_ session: SSHSessionConfig) {
        savedSessions.removeAll { $0.id == session.id }
    }

    func updateSession(_ session: SSHSessionConfig) {
        if let index = savedSessions.firstIndex(where: { $0.id == session.id }) {
            savedSessions[index] = session
        }
    }

    private func persistSessions() {
        if let data = try? JSONEncoder().encode(savedSessions) {
            UserDefaults.standard.set(data, forKey: sessionsKey)
        }
    }

    private func loadSessions() {
        if let data = UserDefaults.standard.data(forKey: sessionsKey),
           let sessions = try? JSONDecoder().decode([SSHSessionConfig].self, from: data) {
            savedSessions = sessions
        }
    }
}
