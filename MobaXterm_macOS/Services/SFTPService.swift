import Foundation
import SwiftUI

enum TransferStatus: Equatable {
    case idle
    case inProgress(String)   // message like "Downloading foo.txt…"
    case success(String)      // "Downloaded foo.txt"
    case failure(String)      // "Download failed: ..."
}

/// Runs sftp/ssh commands to browse remote filesystems.
/// Uses the system ssh command with expect for password auth.
class SFTPService: ObservableObject {
    @Published var currentPath: String = "/"
    @Published var files: [RemoteFile] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var showHiddenFiles = false
    @Published var transferStatus: TransferStatus = .idle

    let config: SSHSessionConfig
    private let password: String?

    /// Files filtered by hidden-file toggle (computed from @Published props)
    var filteredFiles: [RemoteFile] {
        if showHiddenFiles { return files }
        return files.filter { !$0.name.hasPrefix(".") }
    }

    init(config: SSHSessionConfig) {
        self.config = config
        self.password = KeychainService.getPassword(for: config.id)
    }

    /// List files at the given remote path
    func listFiles(at path: String? = nil) {
        let targetPath = path ?? currentPath
        isLoading = true
        error = nil

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            // Use ssh to run ls -la on the remote host
            let lsCommand = "ls -laF --time-style=long-iso \(targetPath) 2>/dev/null || ls -laF \(targetPath)"
            let result = self.runRemoteCommand(lsCommand)

            DispatchQueue.main.async {
                self.isLoading = false

                switch result {
                case .success(let output):
                    self.currentPath = targetPath
                    self.files = Self.parseLsOutput(output, basePath: targetPath)
                case .failure(let err):
                    self.error = err.localizedDescription
                }
            }
        }
    }

    /// Navigate into a directory
    func navigate(to file: RemoteFile) {
        if file.isDirectory {
            let newPath: String
            if file.name == ".." {
                newPath = (currentPath as NSString).deletingLastPathComponent
            } else {
                newPath = currentPath == "/"
                    ? "/\(file.name)"
                    : "\(currentPath)/\(file.name)"
            }
            listFiles(at: newPath)
        }
    }

    /// Go up one directory
    func goUp() {
        let parent = (currentPath as NSString).deletingLastPathComponent
        listFiles(at: parent.isEmpty ? "/" : parent)
    }

    // MARK: - File Transfer (SCP)

    /// Download a remote file to a local path via SCP
    func downloadFile(_ file: RemoteFile, to localURL: URL) {
        transferStatus = .inProgress("Downloading \(file.name)…")

        let remotePath = file.path
        let localPath = localURL.path

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let result = self.runSCPDownload(remotePath: remotePath, localPath: localPath)
            DispatchQueue.main.async {
                switch result {
                case .success:
                    // Verify the file actually arrived
                    if FileManager.default.fileExists(atPath: localPath) {
                        self.transferStatus = .success("Downloaded \(file.name)")
                    } else {
                        self.transferStatus = .failure("Download finished but file not found")
                    }
                    self.autoDismissStatus()
                case .failure(let err):
                    self.transferStatus = .failure(err.localizedDescription)
                    self.autoDismissStatus(delay: 5)
                }
            }
        }
    }

    /// Upload a local file to the current remote directory via SCP
    func uploadFile(from localURL: URL) {
        let fileName = localURL.lastPathComponent
        let remoteDest = currentPath == "/"
            ? "/\(fileName)"
            : "\(currentPath)/\(fileName)"
        let localPath = localURL.path

        transferStatus = .inProgress("Uploading \(fileName)…")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let result = self.runSCPUpload(localPath: localPath, remotePath: remoteDest)
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.transferStatus = .success("Uploaded \(fileName)")
                    self.autoDismissStatus()
                    self.listFiles() // refresh
                case .failure(let err):
                    self.transferStatus = .failure(err.localizedDescription)
                    self.autoDismissStatus(delay: 5)
                }
            }
        }
    }

    /// Auto-dismiss the transfer status after a delay
    private func autoDismissStatus(delay: Double = 3) {
        let currentStatus = transferStatus
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            // Only dismiss if status hasn't changed (i.e. no new transfer started)
            if self.transferStatus == currentStatus {
                withAnimation(.easeOut(duration: 0.3)) {
                    self.transferStatus = .idle
                }
            }
        }
    }

    // MARK: - Private SSH/SCP Helpers

    /// Run a command on the remote host via SSH
    private func runRemoteCommand(_ command: String) -> Result<String, Error> {
        let process = Process()
        let pipe = Pipe()

        process.standardOutput = pipe
        process.standardError = pipe

        if let password = password, !password.isEmpty {
            let escapedPassword = Self.escapeForExpect(password)

            let expectScript = """
            log_user 0
            spawn ssh -p \(config.port) \(config.username)@\(config.host) {\(command)}
            expect {
                "yes/no" { send "yes\\r"; exp_continue }
                "assword:" { send "\(escapedPassword)\\r" }
                timeout { exit 1 }
            }
            log_user 1
            expect eof
            """

            process.executableURL = URL(fileURLWithPath: "/usr/bin/expect")
            process.arguments = ["-c", expectScript]
        } else {
            let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
            process.executableURL = URL(fileURLWithPath: shell)
            process.arguments = ["-l", "-c",
                "ssh -p \(config.port) \(config.username)@\(config.host) '\(command)'"]
        }

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            if process.terminationStatus != 0 && output.isEmpty {
                return .failure(NSError(domain: "", code: Int(process.terminationStatus),
                    userInfo: [NSLocalizedDescriptionKey: "SSH command failed"]))
            }
            return .success(output)
        } catch {
            return .failure(error)
        }
    }

    /// Download a remote file via SCP
    private func runSCPDownload(remotePath: String, localPath: String) -> Result<Void, Error> {
        // Build scp arguments as an array — avoids all shell quoting issues
        // scp -P port user@host:remotePath localPath
        let scpArgs = [
            "-P", "\(config.port)",
            "-o", "StrictHostKeyChecking=accept-new",
            "\(config.username)@\(config.host):\(remotePath)",
            localPath
        ]
        return runSCPProcess(args: scpArgs)
    }

    /// Upload a local file via SCP
    private func runSCPUpload(localPath: String, remotePath: String) -> Result<Void, Error> {
        let scpArgs = [
            "-P", "\(config.port)",
            "-o", "StrictHostKeyChecking=accept-new",
            localPath,
            "\(config.username)@\(config.host):\(remotePath)"
        ]
        return runSCPProcess(args: scpArgs)
    }

    /// Run an SCP process with the given arguments
    private func runSCPProcess(args: [String]) -> Result<Void, Error> {
        let process = Process()
        let pipe = Pipe()
        let errPipe = Pipe()

        process.standardOutput = pipe
        process.standardError = errPipe

        if let password = password, !password.isEmpty {
            // Use expect for password auth
            let escapedPassword = Self.escapeForExpect(password)

            // Build the spawn command with proper quoting for expect
            let quotedArgs = args.map { arg -> String in
                // Quote each argument for expect's spawn
                if arg.contains(" ") || arg.contains("'") || arg.contains("\"") {
                    return "\"\(arg.replacingOccurrences(of: "\"", with: "\\\""))\""
                }
                return arg
            }
            let spawnCmd = "spawn scp " + quotedArgs.joined(separator: " ")

            let expectScript = """
            set timeout 30
            log_user 0
            \(spawnCmd)
            expect {
                "yes/no" { send "yes\\r"; exp_continue }
                "*assword*" { send "\(escapedPassword)\\r" }
                timeout { puts "TIMEOUT"; exit 1 }
                eof { }
            }
            expect eof
            lassign [wait] pid spawnid os_error status
            exit $status
            """

            process.executableURL = URL(fileURLWithPath: "/usr/bin/expect")
            process.arguments = ["-c", expectScript]
        } else {
            // No password — call scp directly (relies on SSH keys)
            process.executableURL = URL(fileURLWithPath: "/usr/bin/scp")
            process.arguments = args
        }

        do {
            try process.run()
            process.waitUntilExit()

            let exitCode = process.terminationStatus
            if exitCode != 0 {
                let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                let outData = pipe.fileHandleForReading.readDataToEndOfFile()
                let errStr = String(data: errData, encoding: .utf8) ?? ""
                let outStr = String(data: outData, encoding: .utf8) ?? ""
                let msg = (errStr + outStr).trimmingCharacters(in: .whitespacesAndNewlines)
                return .failure(NSError(domain: "SCP", code: Int(exitCode),
                    userInfo: [NSLocalizedDescriptionKey: msg.isEmpty ? "SCP failed (exit \(exitCode))" : msg]))
            }
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    /// Escape a string for use in an expect script
    private static func escapeForExpect(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "[", with: "\\[")
            .replacingOccurrences(of: "]", with: "\\]")
            .replacingOccurrences(of: "$", with: "\\$")
    }

    /// Parse `ls -laF` output into RemoteFile objects
    static func parseLsOutput(_ output: String, basePath: String) -> [RemoteFile] {
        var files: [RemoteFile] = []

        for line in output.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Skip header line, empty lines, and non-listing lines
            if trimmed.isEmpty || trimmed.hasPrefix("total ") { continue }
            // Must start with a permission string (e.g. drwxr-xr-x or -rw-r--r--)
            guard let first = trimmed.first, "dlcbsp-".contains(first) else { continue }

            // Parse ls -la output
            // Formats vary:
            //   --time-style=long-iso: perms links owner group size 2024-01-15 14:30 name
            //   default:               perms links owner group size Jan 15 14:30 name
            // We split liberally and take everything after the size+date fields as the name
            let parts = trimmed.split(separator: " ", omittingEmptySubsequences: true)
            guard parts.count >= 8 else { continue }

            // Find the size field (index 4) — it's numeric
            guard let sizeBytes = Int64(parts[4]) else { continue }

            // The name is everything after the date/time fields
            // With long-iso: parts[5]=date parts[6]=time parts[7...]=name
            // With default:  parts[5]=month parts[6]=day parts[7]=time parts[8...]=name
            // Detect format: if parts[5] looks like a date (contains '-'), it's long-iso
            let nameStartIndex: Int
            if parts[5].contains("-") {
                // long-iso format: date time name
                nameStartIndex = 7
            } else {
                // default format: month day time/year name
                nameStartIndex = 8
            }

            guard parts.count > nameStartIndex else { continue }

            var name = parts[nameStartIndex...].joined(separator: " ")
            let isDirectory = trimmed.hasPrefix("d") || name.hasSuffix("/")

            // Clean up name — remove trailing / or @ or * added by -F flag
            // Also remove symlink targets (e.g. "link -> target")
            if let arrowRange = name.range(of: " -> ") {
                name = String(name[name.startIndex..<arrowRange.lowerBound])
            }
            name = name.trimmingCharacters(in: CharacterSet(charactersIn: "/@*"))

            // Skip . and .. entries
            if name == "." || name == ".." { continue }
            // Skip empty names
            if name.isEmpty { continue }

            let sizeStr = Self.formatFileSize(sizeBytes)

            let path = basePath == "/"
                ? "/\(name)"
                : "\(basePath)/\(name)"

            files.append(RemoteFile(
                name: name,
                path: path,
                isDirectory: isDirectory,
                size: sizeStr,
                modified: ""
            ))
        }

        // Sort: directories first, then alphabetically
        files.sort {
            if $0.isDirectory != $1.isDirectory {
                return $0.isDirectory
            }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }

        return files
    }

    /// Human-readable file size
    private static func formatFileSize(_ bytes: Int64) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        let kb = Double(bytes) / 1024
        if kb < 1024 { return String(format: "%.1f KB", kb) }
        let mb = kb / 1024
        if mb < 1024 { return String(format: "%.1f MB", mb) }
        let gb = mb / 1024
        return String(format: "%.1f GB", gb)
    }
}
