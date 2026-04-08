import SwiftUI
import UniformTypeIdentifiers

struct FileBrowserView: View {
    @StateObject private var sftp: SFTPService
    @Binding var isVisible: Bool
    @State private var showUploadPicker = false

    init(config: SSHSessionConfig, isVisible: Binding<Bool>) {
        _sftp = StateObject(wrappedValue: SFTPService(config: config))
        _isVisible = isVisible
    }

    var body: some View {
        VStack(spacing: 0) {
            // Path bar
            HStack(spacing: 6) {
                Button(action: { sftp.goUp() }) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 10, weight: .medium))
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Color.white.opacity(0.05)))
                        .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 0.5))
                        .clipShape(Circle())
                }
                .buttonStyle(.borderless)
                .disabled(sftp.currentPath == "/")

                Button(action: { sftp.listFiles(at: "~") }) {
                    Image(systemName: "house")
                        .font(.system(size: 10, weight: .medium))
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Color.white.opacity(0.05)))
                        .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 0.5))
                        .clipShape(Circle())
                }
                .buttonStyle(.borderless)

                Text(sftp.currentPath)
                    .font(.system(size: 11, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(.secondary)

                Spacer()

                // Toggle hidden files
                Button(action: { sftp.showHiddenFiles.toggle() }) {
                    Image(systemName: sftp.showHiddenFiles ? "eye" : "eye.slash")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(sftp.showHiddenFiles ? .primary : .tertiary)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Color.white.opacity(sftp.showHiddenFiles ? 0.1 : 0.05)))
                        .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 0.5))
                        .clipShape(Circle())
                }
                .buttonStyle(.borderless)
                .help(sftp.showHiddenFiles ? "Hide hidden files" : "Show hidden files")

                Button(action: { sftp.listFiles() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10, weight: .medium))
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Color.white.opacity(0.05)))
                        .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 0.5))
                        .clipShape(Circle())
                }
                .buttonStyle(.borderless)

                // Hide panel button
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) { isVisible = false }
                }) {
                    Image(systemName: "sidebar.right")
                        .font(.system(size: 10, weight: .medium))
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Color.white.opacity(0.05)))
                        .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 0.5))
                        .clipShape(Circle())
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(VisualEffectBackground(material: .titlebar, blendingMode: .withinWindow))

            GlassDivider()

            // File list
            Group {
                if sftp.isLoading {
                    Spacer()
                    ProgressView().scaleEffect(0.8)
                    Spacer()
                } else if let error = sftp.error {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.yellow)
                            .font(.system(size: 20, weight: .thin))
                        Text(error)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Retry") { sftp.listFiles() }
                            .font(.system(size: 11))
                    }
                    .padding()
                    Spacer()
                } else if sftp.filteredFiles.isEmpty {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "folder")
                            .font(.system(size: 20, weight: .thin))
                            .foregroundStyle(.tertiary)
                        Text(sftp.files.isEmpty ? "Empty directory" : "No visible files")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                        if !sftp.files.isEmpty && !sftp.showHiddenFiles {
                            Button("Show hidden files") { sftp.showHiddenFiles = true }
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 1) {
                            ForEach(sftp.filteredFiles) { file in
                                FileRowView(file: file)
                                    .contentShape(Rectangle())
                                    .onTapGesture(count: 2) {
                                        if file.isDirectory { sftp.navigate(to: file) }
                                    }
                                    .contextMenu {
                                        if file.isDirectory {
                                            Button {
                                                sftp.navigate(to: file)
                                            } label: {
                                                Label("Open", systemImage: "folder")
                                            }
                                        }

                                        if !file.isDirectory {
                                            Button {
                                                downloadFile(file)
                                            } label: {
                                                Label("Download", systemImage: "arrow.down.circle")
                                            }
                                        }

                                        Divider()

                                        Button {
                                            NSPasteboard.general.clearContents()
                                            NSPasteboard.general.setString(file.path, forType: .string)
                                        } label: {
                                            Label("Copy Path", systemImage: "doc.on.doc")
                                        }
                                    }
                            }
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                    }
                }
            }

            // Bottom bar — transfer status + upload
            GlassDivider()

            VStack(spacing: 0) {
                // Transfer status toast
                if sftp.transferStatus != .idle {
                    transferStatusBar
                        .transition(.move(edge: .bottom).combined(with: .opacity))

                    GlassDivider()
                }

                // Upload button row
                HStack {
                    Spacer()

                    Button(action: { showUploadPicker = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.circle")
                                .font(.system(size: 10, weight: .medium))
                            Text("Upload")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule(style: .continuous).fill(Color.white.opacity(0.06)))
                        .overlay(Capsule(style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 0.5))
                        .clipShape(Capsule(style: .continuous))
                        .contentShape(Capsule(style: .continuous))
                    }
                    .buttonStyle(.borderless)
                    .disabled(isTransferring)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
            .animation(.easeInOut(duration: 0.25), value: sftp.transferStatus != .idle)
        }
        .onAppear { sftp.listFiles(at: "~") }
        .fileImporter(
            isPresented: $showUploadPicker,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                let accessing = url.startAccessingSecurityScopedResource()
                sftp.uploadFile(from: url)
                if accessing { url.stopAccessingSecurityScopedResource() }
            }
        }
    }

    private var isTransferring: Bool {
        if case .inProgress = sftp.transferStatus { return true }
        return false
    }

    @ViewBuilder
    private var transferStatusBar: some View {
        HStack(spacing: 6) {
            switch sftp.transferStatus {
            case .idle:
                EmptyView()
            case .inProgress(let msg):
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 14, height: 14)
                Text(msg)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            case .success(let msg):
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.green)
                Text(msg)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            case .failure(let msg):
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                Text(msg)
                    .font(.system(size: 10))
                    .foregroundStyle(.red.opacity(0.8))
            }
            Spacer()
        }
        .lineLimit(1)
        .truncationMode(.middle)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.03))
    }

    /// Present a save panel and download the file via SCP
    private func downloadFile(_ file: RemoteFile) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = file.name
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            sftp.downloadFile(file, to: url)
        }
    }
}

struct FileRowView: View {
    let file: RemoteFile
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(file.isDirectory ? Color.blue.opacity(0.1) : Color.gray.opacity(0.06))
                    .frame(width: 26, height: 26)
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                    .frame(width: 26, height: 26)
                Image(systemName: file.isDirectory ? "folder.fill" : fileIcon)
                    .foregroundColor(file.isDirectory ? .blue : .secondary)
                    .font(.system(size: 11))
            }

            Text(file.name)
                .font(.system(size: 12))
                .lineLimit(1)

            Spacer()

            if !file.isDirectory {
                Text(file.size)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isHovering ? Color.white.opacity(0.06) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(isHovering ? 0.08 : 0), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onHover { isHovering = $0 }
    }

    private var fileIcon: String {
        switch (file.name as NSString).pathExtension.lowercased() {
        case "txt", "md", "log", "conf", "cfg", "ini", "yml", "yaml", "json", "xml": return "doc.text"
        case "sh", "bash", "zsh", "py", "rb", "js", "ts", "swift", "go", "rs": return "chevron.left.forwardslash.chevron.right"
        case "jpg", "jpeg", "png", "gif", "svg", "bmp": return "photo"
        case "zip", "tar", "gz", "bz2", "xz", "7z", "rar": return "archivebox"
        default: return "doc"
        }
    }
}
