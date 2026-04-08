import Foundation
import CryptoKit

/// Stores SSH passwords locally in Application Support, encrypted with AES-GCM.
/// No Keychain involved — no system prompts.
struct KeychainService {

    private static var storageURL: URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!
        let dir = appSupport.appendingPathComponent("Termoss", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("sessions.dat")
    }

    // Derive a stable key from a machine-specific value (not Keychain)
    private static var encryptionKey: SymmetricKey {
        let machineID = (Host.current().localizedName ?? "Termoss") + "Termoss.v1"
        let keyData = Data(SHA256.hash(data: Data(machineID.utf8)))
        return SymmetricKey(data: keyData)
    }

    // MARK: - Public API

    static func savePassword(_ password: String, for sessionID: UUID) {
        var store = loadStore()
        store[sessionID.uuidString] = password
        saveStore(store)
    }

    static func getPassword(for sessionID: UUID) -> String? {
        loadStore()[sessionID.uuidString]
    }

    static func deletePassword(for sessionID: UUID) {
        var store = loadStore()
        store.removeValue(forKey: sessionID.uuidString)
        saveStore(store)
    }

    // MARK: - Private

    private static func loadStore() -> [String: String] {
        guard let data = try? Data(contentsOf: storageURL) else { return [:] }
        guard let decrypted = try? AES.GCM.open(.init(combined: data), using: encryptionKey),
              let dict = try? JSONDecoder().decode([String: String].self, from: decrypted)
        else { return [:] }
        return dict
    }

    private static func saveStore(_ store: [String: String]) {
        guard let json = try? JSONEncoder().encode(store),
              let sealed = try? AES.GCM.seal(json, using: encryptionKey).combined
        else { return }
        try? sealed.write(to: storageURL, options: .atomic)
        // Restrict to owner read/write only
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o600], ofItemAtPath: storageURL.path
        )
    }
}
