import Foundation

struct TabItem: Identifiable, Hashable {
    let id: UUID
    var title: String
    let type: TabType
    let sessionConfig: SSHSessionConfig?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        title: String = "Local Terminal",
        type: TabType = .local,
        sessionConfig: SSHSessionConfig? = nil
    ) {
        self.id = id
        self.title = title
        self.type = type
        self.sessionConfig = sessionConfig
        self.createdAt = Date()
    }

    static func == (lhs: TabItem, rhs: TabItem) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

enum TabType: Hashable {
    case local
    case ssh
}
