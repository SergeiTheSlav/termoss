import SwiftUI

enum SessionEditorMode {
    case create
    case edit(SSHSessionConfig)
}

struct SessionEditorView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @Environment(\.dismiss) var dismiss

    let mode: SessionEditorMode

    @State private var name: String = ""
    @State private var host: String = ""
    @State private var port: String = "22"
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var authMethod: AuthMethod = .password
    @State private var group: String = ""

    // Appearance
    @State private var iconColorHex: String = ""
    @State private var useCustomTheme: Bool = false
    @State private var sessionTheme: TerminalTheme = ThemeManager.shared.globalTheme
    @State private var selectedSavedTheme: String = ThemeManager.shared.globalTheme.name
    @State private var showThemeEditor: Bool = false

    private let presetColors: [(String, String)] = [
        ("Blue",    "#57C7FF"),
        ("Green",   "#5AF78E"),
        ("Red",     "#FF5F56"),
        ("Orange",  "#FF9F43"),
        ("Purple",  "#C792EA"),
        ("Cyan",    "#9AEDFE"),
        ("Yellow",  "#F3F99D"),
        ("Pink",    "#FF6AC1"),
    ]

    var isValid: Bool {
        !host.isEmpty && !username.isEmpty && Int(port) != nil
    }

    init(mode: SessionEditorMode) {
        self.mode = mode
        if case .edit(let config) = mode {
            _name = State(initialValue: config.name)
            _host = State(initialValue: config.host)
            _port = State(initialValue: String(config.port))
            _username = State(initialValue: config.username)
            _authMethod = State(initialValue: config.authMethod)
            _group = State(initialValue: config.group ?? "")
            _password = State(initialValue: KeychainService.getPassword(for: config.id) ?? "")
            _iconColorHex = State(initialValue: config.iconColorHex ?? "")
            _useCustomTheme = State(initialValue: config.themeOverride != nil)
            _sessionTheme = State(initialValue: config.themeOverride ?? ThemeManager.shared.globalTheme)
            _selectedSavedTheme = State(initialValue: config.themeOverride?.name ?? ThemeManager.shared.globalTheme.name)
        }
    }

    private var isCreating: Bool {
        if case .create = mode { return true }
        return false
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 4) {
                Image(systemName: isCreating ? "plus.circle" : "pencil.circle")
                    .font(.system(size: 28, weight: .thin))
                    .foregroundStyle(.secondary)

                Text(isCreating ? "New SSH Session" : "Edit Session")
                    .font(.system(size: 15, weight: .semibold))
            }
            .padding(.top, 20)
            .padding(.bottom, 12)

            Form {
                Section("Connection") {
                    TextField("Session Name (optional)", text: $name)
                    TextField("Host", text: $host)
                    TextField("Port", text: $port)
                    TextField("Username", text: $username)
                    Picker("Authentication", selection: $authMethod) {
                        ForEach(AuthMethod.allCases, id: \.self) { method in
                            Text(method.rawValue).tag(method)
                        }
                    }
                    if authMethod == .password {
                        SecureField("Password", text: $password)
                    }
                }

                Section("Organization") {
                    TextField("Group (optional)", text: $group)
                }

                Section("Appearance") {
                    // Icon color picker
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Icon Color")
                            .font(.system(size: 12))

                        HStack(spacing: 8) {
                            // Default (blue)
                            iconCircle(color: .blue, hex: "")

                            ForEach(presetColors, id: \.1) { _, hex in
                                iconCircle(color: Color(hex: hex), hex: hex)
                            }

                            Divider().frame(height: 20)

                            // Custom hex input joined with preview
                            HStack(spacing: 0) {
                                Circle()
                                    .fill(iconColorHex.isEmpty ? Color.blue : Color(hex: iconColorHex))
                                    .frame(width: 22, height: 22)
                                    .overlay(
                                        Circle().stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                                    )
                                    .padding(.leading, 4)

                                TextField("", text: $iconColorHex)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 11, design: .monospaced))
                                    .frame(width: 72)
                                    .padding(.leading, 6)
                                    .padding(.trailing, 6)
                            }
                            .padding(.vertical, 3)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.white.opacity(0.05))
                            )
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                            )
                            .clipShape(Capsule(style: .continuous))
                        }
                    }

                    // Theme override toggle
                    Toggle("Custom terminal theme", isOn: $useCustomTheme)

                    if useCustomTheme {
                        // Saved theme picker
                        Picker("Base theme", selection: $selectedSavedTheme) {
                            ForEach(ThemeManager.shared.savedThemes, id: \.name) { theme in
                                Text(theme.name).tag(theme.name)
                            }
                        }
                        .onChange(of: selectedSavedTheme) { _, newName in
                            if let theme = ThemeManager.shared.savedThemes.first(where: { $0.name == newName }) {
                                sessionTheme = theme
                            }
                        }

                        Button("Edit Theme…") {
                            showThemeEditor = true
                        }

                        ThemePreview(theme: sessionTheme)
                            .frame(height: 50)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .padding(.horizontal, 4)

            // Actions
            HStack(spacing: 10) {
                GlassPillButton(title: "Cancel", style: .secondary) { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Spacer()

                if isCreating {
                    GlassPillButton(title: "Save & Connect", style: .accent) {
                        let config = buildConfig()
                        savePassword(for: config)
                        sessionManager.addSession(config)
                        sessionManager.newSSHTab(config: config)
                        dismiss()
                    }
                    .disabled(!isValid)
                    .opacity(isValid ? 1 : 0.5)
                }

                GlassPillButton(title: isCreating ? "Save" : "Update", style: .accent) {
                    let config = buildConfig()
                    savePassword(for: config)
                    if isCreating {
                        sessionManager.addSession(config)
                    } else {
                        sessionManager.updateSession(config)
                    }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
                .opacity(isValid ? 1 : 0.5)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .frame(width: 460, height: useCustomTheme ? 620 : 520)
        .background(VisualEffectBackground(material: .sidebar, blendingMode: .withinWindow))
        .animation(.easeInOut(duration: 0.2), value: useCustomTheme)
        .sheet(isPresented: $showThemeEditor) {
            VStack(spacing: 0) {
                HStack {
                    Text("Session Theme")
                        .font(.system(size: 15, weight: .semibold))
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 8)

                GlassDivider()

                ThemeEditorView(theme: $sessionTheme)
                    .padding(.horizontal, 4)

                GlassDivider()

                HStack {
                    Spacer()
                    GlassPillButton(title: "Done", style: .accent) { showThemeEditor = false }
                        .keyboardShortcut(.defaultAction)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
            }
            .frame(width: 520, height: 620)
            .background(VisualEffectBackground(material: .sidebar, blendingMode: .withinWindow))
        }
    }

    // MARK: - Icon color circle

    private func iconCircle(color: Color, hex: String) -> some View {
        Button(action: { iconColorHex = hex }) {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 20, height: 20)
                if iconColorHex == hex {
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                        .frame(width: 20, height: 20)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var customIconColor: Binding<Color> {
        Binding(
            get: {
                if iconColorHex.isEmpty { return .blue }
                return Color(hex: iconColorHex)
            },
            set: { iconColorHex = $0.toHex() }
        )
    }

    // MARK: - Build

    private func savePassword(for config: SSHSessionConfig) {
        if authMethod == .password && !password.isEmpty {
            KeychainService.savePassword(password, for: config.id)
        } else {
            KeychainService.deletePassword(for: config.id)
        }
    }

    private func buildConfig() -> SSHSessionConfig {
        var config: SSHSessionConfig
        if case .edit(let existing) = mode {
            config = existing
        } else {
            config = SSHSessionConfig()
        }
        config.name = name
        config.host = host
        config.port = Int(port) ?? 22
        config.username = username
        config.authMethod = authMethod
        config.group = group.isEmpty ? nil : group
        config.iconColorHex = iconColorHex.isEmpty ? nil : iconColorHex
        config.themeOverride = useCustomTheme ? sessionTheme : nil
        return config
    }
}
