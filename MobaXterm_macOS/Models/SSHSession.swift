import SwiftUI

struct SSHSessionConfig: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var host: String
    var port: Int
    var username: String
    var authMethod: AuthMethod
    var group: String?
    var lastConnected: Date?

    /// Custom icon color hex (e.g. "#FF5F56"). nil = default blue.
    var iconColorHex: String?

    /// Per-session terminal theme override. nil = use global.
    var themeOverride: TerminalTheme?

    init(
        id: UUID = UUID(),
        name: String = "",
        host: String = "",
        port: Int = 22,
        username: String = "",
        authMethod: AuthMethod = .password,
        group: String? = nil,
        lastConnected: Date? = nil,
        iconColorHex: String? = nil,
        themeOverride: TerminalTheme? = nil
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.username = username
        self.authMethod = authMethod
        self.group = group
        self.lastConnected = lastConnected
        self.iconColorHex = iconColorHex
        self.themeOverride = themeOverride
    }

    var displayName: String {
        if !name.isEmpty { return name }
        if !host.isEmpty { return "\(username)@\(host)" }
        return "New Session"
    }

    /// Resolved icon color as SwiftUI Color.
    var iconColor: Color {
        if let hex = iconColorHex {
            return Color(hex: hex)
        }
        return .blue
    }
}

enum AuthMethod: String, Codable, CaseIterable, Hashable {
    case password = "Password"
    case publicKey = "Public Key"
}
