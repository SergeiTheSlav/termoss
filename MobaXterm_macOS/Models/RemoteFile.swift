import Foundation

struct RemoteFile: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let path: String
    let isDirectory: Bool
    let size: String
    let modified: String
}
